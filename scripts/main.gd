extends Node3D
## Game orchestration for Phase 1-2 ("tennis toy" + "first satisfying hit"):
## rally rules, player hitting (position + timing + swipe -> shot), slow-motion
## window, hit feedback, and a bot for automated testing (--autoplay).
##
## Hitting model: the swipe expresses intent (direction, depth, pace), the timing
## and body position decide execution quality, the shot solver turns intent into a
## launch, execution errors perturb it, and from then on the ball flies on real physics.

enum Who { NONE = -1, PLAYER = 0, CPU = 1 }
enum Phase { WAIT, SERVE, RALLY, OVER }
enum ShotType { TOPSPIN, FLAT, SLICE }

const PLAYER_HOME := Vector3(0.0, 0.0, 12.6)
const CPU_HOME := Vector3(0.0, 0.0, -12.6)
const PLAYER_AREA := Rect2(-9.0, 0.6, 18.0, 17.0)
const CPU_AREA := Rect2(-9.0, -17.6, 18.0, 17.0)
const TOSS_SPEED := 5.6         # m/s straight up from the hand
const TOSS_HAND_H := 1.5
const SERVE_CONTACT_H := 2.62   # ideal contact: on the way down, just below the apex
const COLOR_GOOD := Color(1, 1, 1)
const COLOR_WARN := Color(1.0, 0.6, 0.25)
const COLOR_BAD := Color(1.0, 0.35, 0.3)
const COLOR_WIN := Color(0.45, 1.0, 0.5)

var ball: Ball
var player: Athlete
var cpu: Athlete
var ai: OpponentAI
var cam: GameCamera
var hud: Hud
var sfx: Sfx
var rng := RandomNumberGenerator.new()

var game_time := 0.0
var phase := Phase.WAIT
var phase_timer := 1.0
var last_hitter := Who.NONE
var bounces := 0
var net_touched := false
var rally := 0
var best_rally := 0
var score := [0, 0]             # total points won (stats)
var scoreboard := TennisScore.new()
var shot_type := ShotType.TOPSPIN

# Serve state
var server := Who.PLAYER
var serve_attempt := 1
var serve_flight := false       # the serve is in the air and hasn't bounced yet
var toss_active := false
var toss_ideal := 0.0           # game time when the toss passes the ideal contact height
var box_side := -1.0            # x sign of the target service box
var _replay_serve := false
var _cpu_serve_timer := 0.0
var _cpu_toss_offset := 0.0
var _points_played := 0

# Player hitting state
var incoming: BallPhysics.Prediction
var t_contact := INF            # predicted game seconds until the ball reaches the contact plane
var contact_pred := Vector3.ZERO
var pending_swing := {}
var late_until := -1.0
var late_cross_time := 0.0
var ball_used := false          # the player already swung/missed at this ball
var last_shot := {}
var _prev_rel := -1.0
var _hitstop_until_ms := 0
var _last_real_us := 0
var _hits_total := 0

# Visual helpers
const AIM_IN := Color(1.0, 0.92, 0.25, 0.9)
const AIM_OUT := Color(1.0, 0.3, 0.25, 0.9)
var _aim: MeshInstance3D
var _aim_mat: StandardMaterial3D
var _aim_hold := 0.0
var _aim_line_target := Vector3.ZERO
var _aim_line_im: ImmediateMesh
var _land_dot: MeshInstance3D
var _land_hold := 0.0
var _path_mesh: MeshInstance3D
var _path_im: ImmediateMesh
var _landing: MeshInstance3D

# Autoplay test bot
var autoplay := false
var autoplay_points := 40
var _bot_armed := false
var _bot_offset := 0.0
var _stats := {"rallies": [], "reasons": {}, "labels": {}, "player_hits": 0, "cpu_hits": 0}


func _ready() -> void:
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		elif a.begins_with("--points="):
			autoplay_points = int(a.get_slice("=", 1))

	_build_environment()
	add_child(Court.new())

	ball = Ball.new()
	add_child(ball)
	ball.bounced.connect(_on_bounce)
	ball.hit_net.connect(_on_net)

	player = Athlete.new()
	add_child(player)
	player.setup(-1.0, Color(0.92, 0.36, 0.26), PLAYER_AREA)
	player.position = PLAYER_HOME

	cpu = Athlete.new()
	add_child(cpu)
	cpu.setup(1.0, Color(0.22, 0.28, 0.42), CPU_AREA)
	cpu.position = CPU_HOME

	ai = OpponentAI.new()
	add_child(ai)
	ai.setup(self, cpu, ball)

	cam = GameCamera.new()
	add_child(cam)
	cam.target = player
	cam.ball = ball
	cam.current = true
	cam.snap()

	sfx = Sfx.new()
	add_child(sfx)

	hud = Hud.new()
	add_child(hud)
	hud.touch.swiped.connect(_on_swipe)
	hud.touch.swipe_moved.connect(_on_swipe_moved)
	hud.touch.swipe_ended.connect(_on_swipe_ended)
	hud.touch.swipe_started.connect(_on_swipe_started)
	hud.shot_type_changed.connect(func(t: int) -> void: shot_type = t as ShotType)
	hud.set_score(scoreboard.point_text())

	_build_helpers()
	_last_real_us = Time.get_ticks_usec()
	_reset_point()


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.53, 0.72, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.82, 0.92)
	e.ambient_light_energy = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)


func _build_helpers() -> void:
	_path_im = ImmediateMesh.new()
	_path_mesh = MeshInstance3D.new()
	_path_mesh.mesh = _path_im
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(1.0, 0.95, 0.3, 0.8)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mesh.material_override = pm
	add_child(_path_mesh)

	_landing = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.22
	tm.rings = 24
	tm.ring_segments = 4
	_landing.mesh = tm
	_landing.scale = Vector3(1.0, 0.05, 1.0)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.55)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_landing.material_override = lm
	_landing.visible = false
	add_child(_landing)

	# Aim marker: where the current swipe is aiming (yellow = in, red = out).
	_aim = MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 0.30
	am.outer_radius = 0.42
	am.rings = 28
	am.ring_segments = 4
	_aim.mesh = am
	_aim.scale = Vector3(1.0, 0.05, 1.0)
	_aim_mat = StandardMaterial3D.new()
	_aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_mat.no_depth_test = true
	_aim_mat.render_priority = 2
	_aim_mat.albedo_color = AIM_IN
	_aim.material_override = _aim_mat
	_aim.visible = false
	add_child(_aim)
	var dot := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.09
	dm.bottom_radius = 0.09
	dm.height = 0.02
	dot.mesh = dm
	dot.material_override = _aim_mat
	_aim.add_child(dot)

	# Thin ground line from the player to the aim point.
	_aim_line_im = ImmediateMesh.new()
	var line := MeshInstance3D.new()
	line.mesh = _aim_line_im
	var lm2 := StandardMaterial3D.new()
	lm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm2.no_depth_test = true
	lm2.albedo_color = Color(1, 1, 1, 0.35)
	line.material_override = lm2
	add_child(line)

	# Where the player's last shot actually landed.
	_land_dot = MeshInstance3D.new()
	var ld := CylinderMesh.new()
	ld.top_radius = 0.16
	ld.bottom_radius = 0.16
	ld.height = 0.01
	_land_dot.mesh = ld
	var ldm := StandardMaterial3D.new()
	ldm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ldm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ldm.no_depth_test = true
	ldm.albedo_color = Color(1, 1, 1, 0.85)
	_land_dot.material_override = ldm
	_land_dot.visible = false
	add_child(_land_dot)


# --- Main loop --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	game_time += delta
	match phase:
		Phase.WAIT:
			phase_timer -= delta
			if phase_timer <= 0.0:
				_setup_serve()
		Phase.SERVE:
			_update_serve(delta)
		Phase.OVER:
			phase_timer -= delta
			if phase_timer <= 0.0:
				if _replay_serve:
					_replay_serve = false
					_setup_serve()
				else:
					_reset_point()
	ball.step(delta)
	if phase == Phase.RALLY and ball.state.rolling:
		_end_point(last_hitter, "WINNER")
	_update_player_hitting()
	if phase == Phase.SERVE:
		cpu.move_input = Vector2.ZERO
	else:
		ai.tick(delta, phase == Phase.RALLY and last_hitter == Who.PLAYER and ball.active)
	_update_player_movement()
	if autoplay:
		_autoplay_tick()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var rd := clampf((now - _last_real_us) / 1000000.0, 0.0, 0.1)
	_last_real_us = now
	_update_slowmo(rd)
	_update_helpers()
	hud.set_rally("%s   ·   rally %d   ·   best %d" % [scoreboard.games_text(), rally, best_rally])
	if Tuning.show_debug_text:
		hud.set_debug_text(_debug_string())
	else:
		hud.set_debug_text("")


# --- Player -------------------------------------------------------------------

func _player_can_hit() -> bool:
	return phase == Phase.RALLY and last_hitter == Who.CPU and ball.active and not ball_used


func _update_player_hitting() -> void:
	var zp := player.position.z - Athlete.CONTACT_FORWARD
	var rel := ball.state.pos.z - zp
	if not _player_can_hit():
		t_contact = INF
		incoming = null
		_prev_rel = rel
		return

	incoming = BallPhysics.predict(ball.state, 2.5, 1.0 / 120.0, 2)
	t_contact = INF
	var pts := incoming.points
	var last_i := pts.size() - 1
	if incoming.bounce_indices.size() >= 2:
		last_i = incoming.bounce_indices[1]
	for i in range(1, last_i + 1):
		var za := pts[i - 1].z - zp
		var zb := pts[i].z - zp
		if za < 0.0 and zb >= 0.0:
			var f := -za / (zb - za)
			t_contact = lerpf(incoming.times[i - 1], incoming.times[i], f)
			contact_pred = pts[i - 1].lerp(pts[i], f)
			break

	if t_contact < 1.2 and pending_swing.is_empty():
		player.prepare(1 if player.lateral_of(contact_pred) >= 0.0 else -1)

	if _prev_rel < 0.0 and rel >= 0.0 and ball.state.vel.z > 0.0:
		_on_ball_crossed()
	_prev_rel = rel

	if late_until > 0.0 and game_time > late_until:
		late_until = -1.0
		ball_used = true


func _on_ball_crossed() -> void:
	if serve_flight:
		return  # the receiver must let the serve bounce
	var bp := ball.state.pos
	if bp.y > 2.6 or bp.y < 0.04:
		return
	var flat_d := Vector2(bp.x - player.position.x, bp.z - player.position.z).length()
	if flat_d > Athlete.REACH + 0.6:
		if not pending_swing.is_empty():
			_miss("TOO FAR")
		return
	if pending_swing.is_empty():
		late_until = game_time + Tuning.late_limit
		late_cross_time = game_time
	else:
		var err: float = pending_swing["time"] - game_time
		if err < -Tuning.early_limit:
			_miss("TOO EARLY")
		else:
			_player_hit(err, pending_swing["vec"], pending_swing["dur"])


func _on_swipe(vec: Vector2, dur: float) -> void:
	hud.hide_hint()
	if phase == Phase.SERVE:
		if server == Who.PLAYER and toss_active:
			_player_serve(vec, dur)
		return
	if not _player_can_hit():
		return
	if late_until > 0.0:
		_player_hit(game_time - late_cross_time, vec, dur)
		return
	if pending_swing.is_empty() and t_contact < Tuning.early_limit + 0.25:
		pending_swing = {"time": game_time, "vec": vec, "dur": dur}
		var side := 1 if player.lateral_of(contact_pred) >= 0.0 else -1
		player.swing(side, t_contact, contact_pred.y)
		sfx.play("swing", -12.0, rng.randf_range(0.95, 1.1))


func _player_hit(err: float, vec: Vector2, dur: float) -> void:
	var bp := ball.state.pos
	pending_swing = {}
	late_until = -1.0
	var lateral := player.lateral_of(bp)
	var flat_d := Vector2(bp.x - player.position.x, bp.z - player.position.z).length()
	if flat_d > Athlete.REACH:
		_miss("TOO FAR")
		return
	var side := 1 if lateral >= 0.0 else -1
	var tq := timing_quality(err)
	var q_t: float = tq[0]
	var label: String = tq[1]
	var q_p := position_quality(lateral, bp.y)
	var q_m := movement_quality(player.velocity.length())
	var q := q_t * q_p * q_m

	var intent := swipe_intent(vec, dur)
	var tx: float = intent["tx"]
	var tz: float = intent["tz"]
	var pace_k: float = intent["pace_k"]
	var pace: float
	var top: float
	match shot_type:
		ShotType.FLAT:
			pace = lerpf(25.0, 42.0, pace_k)
			top = 40.0
		ShotType.SLICE:
			pace = lerpf(18.0, 28.0, pace_k)
			top = -lerpf(140.0, 210.0, pace_k)
		_:
			pace = lerpf(22.0, 36.0, pace_k)
			top = lerpf(180.0, 340.0, pace_k)

	if not player.is_swinging():
		player.swing(side, 0.02, bp.y)
	var r := execute_shot(Who.PLAYER, player, bp, Vector3(tx, BallPhysics.RADIUS, tz), pace, top, q, err, side)
	ai.on_player_hit()
	_hits_total += 1
	_stats["player_hits"] += 1
	_stats["labels"][label] = _stats["labels"].get(label, 0) + 1

	# Feedback
	var color := COLOR_GOOD
	if label == "PERFECT":
		color = Hud.GOLD
	elif label == "EARLY" or label == "LATE":
		color = COLOR_WARN
	var notes := []
	if q_p < 0.75:
		notes.append("bad position")
	if q_m < 0.85:
		notes.append("on the run")
	var sub := "%d km/h  ·  %d%%" % [roundi(r.speed * 3.6), roundi(q * 100.0)]
	if not notes.is_empty():
		sub += "  ·  " + ", ".join(notes)
	hud.popup(label, color, sub)
	if label == "PERFECT":
		cam.impulse(1.0)
		if Tuning.hitstop and not autoplay:
			_hitstop_until_ms = Time.get_ticks_msec() + 70
		Input.vibrate_handheld(35)
	else:
		cam.impulse(0.4 * q)

	last_shot = {
		"label": label, "err_ms": err * 1000.0, "q_t": q_t, "q_p": q_p, "q_m": q_m, "q": q,
		"side": "FH" if side > 0 else "BH", "speed": r.speed * 3.6, "elev": r.elevation_deg,
		"target": Vector2(tx, tz), "type": Hud.SHOT_NAMES[shot_type],
	}


## Swipe -> intent. Direction = aim (absolute court x), length = depth, gesture speed = pace.
func swipe_intent(vec: Vector2, dur: float) -> Dictionary:
	var fwd := maxf(-vec.y, 0.02)
	var ang := rad_to_deg(atan2(vec.x, fwd))
	var length := vec.length()
	var tx := clampf(ang / Tuning.swipe_side_angle, -1.6, 1.6) * (Court.SINGLES_HALF_WIDTH - 0.35)
	var depth_k := (length - 0.05) / maxf(Tuning.swipe_deep_len - 0.05, 0.01)
	var tz := -lerpf(4.2, Court.HALF_LENGTH - 0.7, clampf(depth_k, 0.0, 1.0))
	if depth_k > 1.0:
		tz -= (depth_k - 1.0) * 3.0
	return {"tx": tx, "tz": tz, "pace_k": clampf((length / dur - 0.6) / 2.9, 0.0, 1.0)}


func _on_swipe_moved(vec: Vector2) -> void:
	if not Tuning.show_aim:
		return
	if phase == Phase.SERVE:
		if server != Who.PLAYER:
			return
		var si := serve_intent(vec, 1.0)
		var sp := Vector3(si["tx"], 0.0, si["tz"])
		_set_aim(sp, Court.in_service_box(sp, -1, box_side, 0.0))
	else:
		var it := swipe_intent(vec, 1.0)
		var p := Vector3(it["tx"], 0.0, it["tz"])
		_set_aim(p, Court.is_in_singles(p, -1, 0.0))
	_aim_hold = INF


func _on_swipe_ended() -> void:
	_aim_hold = 0.6  # keep the aim visible briefly so it can be compared with the landing spot


func _set_aim(p: Vector3, inside: bool) -> void:
	_aim.visible = true
	_aim.global_position = Vector3(p.x, 0.012, p.z)
	_aim_mat.albedo_color = AIM_IN if inside else AIM_OUT
	_aim_line_target = p


func _miss(reason: String) -> void:
	pending_swing = {}
	late_until = -1.0
	ball_used = true
	hud.popup(reason, COLOR_BAD)
	if autoplay:
		print("  player miss: %s" % reason)


func _ideal_contact() -> Vector3:
	# After the bounce: prefer the ball coming down through waist/chest height,
	# but take it on the rise rather than retreating far behind the baseline.
	if incoming == null:
		return contact_pred
	var pts := incoming.points
	var start := 0
	var stop := pts.size() - 1
	if bounces == 0:
		if incoming.bounce_indices.is_empty():
			return contact_pred
		start = incoming.bounce_indices[0]
		if incoming.bounce_indices.size() > 1:
			stop = incoming.bounce_indices[1]
	elif not incoming.bounce_indices.is_empty():
		stop = incoming.bounce_indices[0]
	var fallback := Vector3.INF
	for i in range(start + 1, stop):
		var p := pts[i]
		if p.y < 0.5 or p.y > 1.5:
			continue
		if fallback == Vector3.INF:
			fallback = p
		if pts[i + 1].y < p.y:
			if p.z <= Court.HALF_LENGTH + 2.2:
				return p
			break
	if fallback != Vector3.INF:
		return fallback
	return contact_pred


func _update_player_movement() -> void:
	player.max_speed = Tuning.player_speed
	var mv := hud.touch.move_vector
	if phase == Phase.SERVE and server == Who.PLAYER:
		# Serving: slide along the baseline until the toss.
		player.move_input = Vector2(mv.x, 0.0) if not toss_active and not autoplay else Vector2.ZERO
		return
	var assist := Tuning.assist
	if autoplay:
		mv = Vector2.ZERO
		assist = 1.0
	if assist > 0.0 and _player_can_hit() and t_contact < 2.5:
		var ideal := _ideal_contact()
		var side := 1 if player.lateral_of(ideal) >= 0.0 else -1
		if autoplay or absf(player.lateral_of(ideal)) > 0.25:
			var stance := player.stance_for(ideal, side)
			var d := Vector2(stance.x - player.position.x, stance.z - player.position.z)
			if not autoplay:
				d.y *= 0.35  # forward/back is mostly the player's job
			var a := d.normalized() * clampf(d.length() / 0.6, 0.0, 1.0) if d.length() > 0.02 else Vector2.ZERO
			var w := assist * (0.4 if mv.length() > 0.1 else 1.0)
			mv = (mv + a * w).limit_length(1.0)
	elif autoplay and phase == Phase.RALLY:
		var home := Vector2(clampf(ball.state.pos.x * 0.3, -1.5, 1.5) - player.position.x, 12.4 - player.position.z)
		mv = home.limit_length(1.0)
	player.move_input = mv
	if not _player_can_hit() and pending_swing.is_empty():
		player.relax()


# --- Quality model (shared with the AI) ---------------------------------------

## Returns [quality 0..1, label].
func timing_quality(err: float) -> Array:
	var a := absf(err)
	var pw := Tuning.perfect_window
	var gw := Tuning.good_window
	if a <= pw:
		return [1.0, "PERFECT"]
	if a <= gw:
		return [lerpf(0.85, 0.62, (a - pw) / maxf(gw - pw, 0.001)), "GOOD"]
	var limit := Tuning.early_limit if err < 0.0 else Tuning.late_limit
	var k := clampf((a - gw) / maxf(limit - gw, 0.01), 0.0, 1.0)
	return [lerpf(0.5, 0.15, k), "EARLY" if err < 0.0 else "LATE"]


func position_quality(lateral: float, height: float) -> float:
	var lat_err := absf(absf(lateral) - Athlete.IDEAL_LATERAL)
	var q := clampf(1.0 - maxf(0.0, lat_err - 0.2) * 0.75, 0.35, 1.0)
	var h_pen := maxf(0.0, 0.55 - height) * 1.1 + maxf(0.0, height - 1.35) * 0.45
	return q * clampf(1.0 - h_pen, 0.45, 1.0)


func movement_quality(speed: float) -> float:
	return clampf(1.0 - maxf(0.0, speed - 2.5) * 0.07, 0.65, 1.0)


## Turns intent into a launched ball, adding execution error that scales with (1 - quality).
## Timing error is deterministic: early contact pulls the ball, late contact pushes it.
func execute_shot(who: int, hitter: Athlete, contact: Vector3, target: Vector3, pace: float, top: float, q: float, t_err: float, side: int) -> ShotSolver.Result:
	var flat := target - contact
	flat.y = 0.0
	var dist := flat.length()
	var bias := clampf(t_err / Tuning.good_window, -2.5, 2.5) * deg_to_rad(3.0) * float(side)
	target += hitter.right() * (tan(bias) * dist)
	target += hitter.right() * rng.randfn(0.0, 0.1 + (1.0 - q) * 1.3)
	target += hitter.forward() * rng.randfn(0.0, 0.15 + (1.0 - q) * 1.7)
	pace *= lerpf(0.72, 1.06, q)
	top *= lerpf(0.6, 1.0, q)
	var r := ShotSolver.solve(contact, target, pace, top)
	var v := r.velocity
	var axis := Vector3.UP.cross(v).normalized()
	if axis.length() > 0.5:
		v = v.rotated(axis, deg_to_rad(rng.randfn(0.0, 0.3 + (1.0 - q) * 2.2)))
	ball.launch(contact, v, r.spin)
	last_hitter = who as Who
	bounces = 0
	net_touched = false
	if who == Who.CPU:
		ball_used = false
		_stats["cpu_hits"] += 1
	rally += 1
	var vol := lerpf(-9.0, 0.0, clampf(r.speed / 35.0, 0.0, 1.0))
	sfx.play("hit_perfect" if q > 0.9 else "hit", vol, rng.randf_range(0.96, 1.04) * lerpf(0.92, 1.06, q))
	return r


# --- Rules --------------------------------------------------------------------

func _on_bounce(pos: Vector3, speed: float) -> void:
	sfx.play("bounce", lerpf(-22.0, -6.0, clampf(speed / 30.0, 0.0, 1.0)), rng.randf_range(0.9, 1.1))
	if phase != Phase.RALLY:
		return
	bounces += 1
	var receiver_half := 1 if last_hitter == Who.CPU else -1
	if bounces == 1 and last_hitter == Who.PLAYER and Tuning.show_aim:
		_land_dot.global_position = Vector3(pos.x, 0.01, pos.z)
		_land_dot.visible = true
		_land_hold = 1.2
	if serve_flight:
		serve_flight = false
		if not Court.in_service_box(pos, receiver_half, box_side, BallPhysics.RADIUS):
			_fault("NET" if net_touched else "FAULT")
		elif net_touched:
			_let()
		return
	if bounces == 1:
		if not Court.is_in_singles(pos, receiver_half, BallPhysics.RADIUS):
			_end_point(_other(last_hitter), "NET" if net_touched else "OUT")
	else:
		_end_point(last_hitter, "WINNER")


func _on_net(_pos: Vector3) -> void:
	net_touched = true
	sfx.play("net", -6.0)


func _other(w: int) -> int:
	return Who.CPU if w == Who.PLAYER else Who.PLAYER


func _end_point(winner: int, reason: String) -> void:
	if phase != Phase.RALLY:
		return
	phase = Phase.OVER
	phase_timer = 0.4 if autoplay else 1.9
	score[winner] += 1
	_points_played += 1
	best_rally = maxi(best_rally, rally)
	pending_swing = {}
	late_until = -1.0
	serve_flight = false
	if reason == "WINNER" and rally == 1 and winner == server:
		reason = "ACE"
	var text: String
	if winner == Who.PLAYER:
		text = {"OUT": "CPU OUT", "NET": "CPU NET", "WINNER": "WINNER!", "ACE": "ACE!", "DOUBLE FAULT": "CPU DOUBLE FAULT"}[reason]
	else:
		text = {"OUT": "OUT", "NET": "NET", "WINNER": "MISSED", "ACE": "CPU ACE", "DOUBLE FAULT": "DOUBLE FAULT"}[reason]
	var game_over := scoreboard.add_point(winner)
	if game_over:
		text += "\nGAME " + ("YOU" if winner == Who.PLAYER else "CPU")
		server = scoreboard.server as Who
	hud.show_message(text, COLOR_WIN if winner == Who.PLAYER else COLOR_BAD)
	sfx.play("point" if winner == Who.PLAYER else "miss", -8.0 if winner == Who.PLAYER else -10.0)
	hud.set_score(scoreboard.point_text())

	_stats["rallies"].append(rally)
	var key := ("YOU " if winner == Who.PLAYER else "CPU ") + "wins: " + text.split("\n")[0]
	_stats["reasons"][key] = _stats["reasons"].get(key, 0) + 1
	if autoplay:
		print("point %d: %s (rally %d) -> %s %s" % [_points_played, key, rally, scoreboard.point_text(), scoreboard.games_text()])
		if _points_played >= autoplay_points:
			_print_autoplay_summary()
			get_tree().quit()


func _fault(kind: String) -> void:
	var by := server
	if serve_attempt == 1:
		serve_attempt = 2
		_replay_serve = true
		phase = Phase.OVER
		phase_timer = 0.5 if autoplay else 1.2
		hud.show_message("FAULT" if kind != "NET" else "NET · FAULT", COLOR_WARN)
		sfx.play("miss", -14.0)
		if autoplay:
			print("  fault by %s" % ("YOU" if by == Who.PLAYER else "CPU"))
	else:
		_end_point(_other(by), "DOUBLE FAULT")


func _let() -> void:
	_replay_serve = true
	phase = Phase.OVER
	phase_timer = 0.5 if autoplay else 1.2
	hud.show_message("LET", COLOR_GOOD)


func _reset_point() -> void:
	phase = Phase.WAIT
	phase_timer = 0.2 if autoplay else 0.5
	serve_attempt = 1
	ball.park()


# --- Serve ----------------------------------------------------------------------

func _server_athlete() -> Athlete:
	return player if server == Who.PLAYER else cpu


func _hand_position(a: Athlete) -> Vector3:
	return a.position + a.right() * 0.25 + a.forward() * 0.35 + Vector3.UP * TOSS_HAND_H


## Place both players for the serve: server behind the baseline on the deuce/ad side,
## receiver diagonally opposite.
func _setup_serve() -> void:
	phase = Phase.SERVE
	last_hitter = Who.NONE
	bounces = 0
	rally = 0
	ball_used = false
	pending_swing = {}
	late_until = -1.0
	serve_flight = false
	toss_active = false
	net_touched = false
	incoming = null
	t_contact = INF
	var srv := _server_athlete()
	var rcv := cpu if server == Who.PLAYER else player
	var side := 1.0 if scoreboard.deuce_side() else -1.0
	var sx := srv.right().x * side * 0.9
	box_side = -signf(sx)
	var srv_z := 12.3 if server == Who.PLAYER else -12.3
	srv.position = Vector3(sx, 0.0, srv_z)
	rcv.position = Vector3(box_side * 2.4, 0.0, -signf(srv_z) * 12.7)
	srv.velocity = Vector3.ZERO
	rcv.velocity = Vector3.ZERO
	srv.relax()
	rcv.relax()
	if server == Who.PLAYER:
		var x0 := 0.3 if sx > 0.0 else -4.0
		player.area = Rect2(x0, srv_z, 3.7, 0.01)
		hud.set_serve_hint("ПОДАЧА%s: зажми справа — подброс, веди — прицел в квадрат, отпусти в верхней точке" % ("  (2-я)" if serve_attempt == 2 else ""))
	else:
		player.area = PLAYER_AREA
		_cpu_serve_timer = 0.5 if autoplay else 1.2
		hud.set_serve_hint("")
	ball.hold(_hand_position(srv))
	ai.on_cpu_hit(0.0)


func _update_serve(delta: float) -> void:
	var srv := _server_athlete()
	if not toss_active:
		ball.hold(_hand_position(srv))
		if server == Who.CPU:
			_cpu_serve_timer -= delta
			if _cpu_serve_timer <= 0.0:
				_start_toss()
		return
	if server == Who.CPU:
		if game_time >= toss_ideal + _cpu_toss_offset:
			_cpu_serve_hit()
		return
	# The toss fell too low without a swing: catch it and toss again (no fault).
	if ball.state.vel.y < 0.0 and ball.state.pos.y < 1.7:
		toss_active = false
		hud.popup("TOSS AGAIN", COLOR_WARN)


func _start_toss() -> void:
	var srv := _server_athlete()
	var hand := _hand_position(srv)
	ball.launch(hand, Vector3(0.0, TOSS_SPEED, 0.0), Vector3.ZERO)
	toss_active = true
	var g := BallPhysics.GRAVITY
	var disc := maxf(0.0, TOSS_SPEED * TOSS_SPEED - 2.0 * g * (SERVE_CONTACT_H - hand.y))
	toss_ideal = game_time + (TOSS_SPEED + sqrt(disc)) / g
	srv.prepare(1)
	if server == Who.CPU:
		_cpu_toss_offset = rng.randfn(0.0, lerpf(0.06, 0.02, Tuning.ai_skill))
	elif autoplay:
		_bot_offset = rng.randfn(0.0, 0.03)


func _on_swipe_started() -> void:
	if phase == Phase.SERVE and server == Who.PLAYER and not toss_active:
		_start_toss()


## Serve aim: straight swipe = near the T, sideways toward the box's outer side = wide,
## length = depth in the box (too long = long fault). Gesture speed = pace.
func serve_intent(vec: Vector2, dur: float) -> Dictionary:
	var fwd := maxf(-vec.y, 0.02)
	var ang := rad_to_deg(atan2(vec.x, fwd))
	var length := vec.length()
	var tx := box_side * 0.7 + clampf(ang / Tuning.swipe_side_angle, -1.5, 1.5) * 3.6
	var depth_k := (length - 0.05) / maxf(Tuning.swipe_deep_len - 0.05, 0.01)
	var dz := lerpf(3.4, 6.1, clampf(depth_k, 0.0, 1.0))
	if depth_k > 1.0:
		dz += (depth_k - 1.0) * 3.0
	return {"tx": tx, "tz": -dz, "pace_k": clampf((length / dur - 0.6) / 2.9, 0.0, 1.0)}


func _player_serve(vec: Vector2, dur: float) -> void:
	var bp := ball.state.pos
	if bp.y < 1.7:
		return
	var err := game_time - toss_ideal
	var tq := timing_quality(err)
	var q: float = tq[0]
	var label: String = tq[1]
	var it := serve_intent(vec, dur)
	var pace_k: float = it["pace_k"]
	var pace: float
	var top: float
	match shot_type:
		ShotType.FLAT:
			pace = lerpf(38.0, 54.0, pace_k)
			top = 60.0
		ShotType.SLICE:
			pace = lerpf(30.0, 40.0, pace_k)
			top = 120.0
		_:
			pace = lerpf(30.0, 42.0, pace_k)
			top = lerpf(280.0, 380.0, pace_k)
	player.swing(1, 0.02, bp.y)
	var r := execute_shot(Who.PLAYER, player, bp, Vector3(it["tx"], BallPhysics.RADIUS, it["tz"]), pace, top, q, err, 1)
	_after_serve_hit()
	ai.on_player_hit()
	_stats["labels"][label] = _stats["labels"].get(label, 0) + 1
	var color := Hud.GOLD if label == "PERFECT" else (COLOR_WARN if label == "EARLY" or label == "LATE" else COLOR_GOOD)
	hud.popup(label, color, "serve %d km/h" % roundi(r.speed * 3.6))
	cam.impulse(1.0 if label == "PERFECT" else 0.4)
	if label == "PERFECT":
		Input.vibrate_handheld(35)
	last_shot = {
		"label": label, "err_ms": err * 1000.0, "q_t": q, "q_p": 1.0, "q_m": 1.0, "q": q,
		"side": "SRV", "speed": r.speed * 3.6, "elev": r.elevation_deg,
		"target": Vector2(it["tx"], it["tz"]), "type": Hud.SHOT_NAMES[shot_type],
	}


func _cpu_serve_hit() -> void:
	var s := Tuning.ai_skill
	var bp := ball.state.pos
	var q: float = timing_quality(_cpu_toss_offset)[0]
	var tx: float
	var tz: float
	var pace: float
	var top: float
	if serve_attempt == 1:
		var wide := rng.randf() < 0.5
		tx = box_side * (rng.randf_range(2.6, 3.6) if wide else rng.randf_range(0.4, 1.2))
		tz = rng.randf_range(4.6, 5.9)
		pace = lerpf(32.0, 46.0, s) * rng.randf_range(0.9, 1.05)
		top = 120.0
	else:
		tx = box_side * rng.randf_range(0.9, 2.6)
		tz = rng.randf_range(4.2, 5.4)
		pace = lerpf(26.0, 34.0, s)
		top = 320.0
	cpu.swing(1, 0.02, bp.y)
	execute_shot(Who.CPU, cpu, bp, Vector3(tx, BallPhysics.RADIUS, tz), pace, top, q, _cpu_toss_offset, 1)
	_after_serve_hit()
	ai.on_cpu_hit(tx)
	player.split_step()


func _after_serve_hit() -> void:
	phase = Phase.RALLY
	serve_flight = true
	toss_active = false
	player.area = PLAYER_AREA
	hud.set_serve_hint("")


# --- Slow motion, helpers, debug ----------------------------------------------

func _update_slowmo(rd: float) -> void:
	if Time.get_ticks_msec() < _hitstop_until_ms:
		Engine.time_scale = 0.04
		return
	var want := false
	if Tuning.slowmo_enabled and not autoplay and _player_can_hit():
		if late_until > 0.0:
			want = true
		elif t_contact <= Tuning.slowmo_lead:
			want = absf(player.lateral_of(contact_pred)) < 2.8 and contact_pred.y < 2.7
	var target := Tuning.slowmo_scale if want else 1.0
	if Tuning.slowmo_enabled and not autoplay and phase == Phase.SERVE and server == Who.PLAYER and toss_active:
		if game_time > toss_ideal - 0.35:
			target = lerpf(1.0, Tuning.slowmo_scale, 0.6)
	var rate := 7.0 if target < Engine.time_scale else 3.5
	Engine.time_scale = move_toward(Engine.time_scale, target, rd * rate)


func _update_helpers() -> void:
	var rd := 1.0 / maxf(Engine.get_frames_per_second(), 30.0)
	if _aim_hold != INF:
		_aim_hold -= rd
		if _aim_hold <= 0.0:
			_aim.visible = false
	if _land_hold > 0.0:
		_land_hold -= rd
		_land_dot.visible = _land_hold > 0.0
	_aim_line_im.clear_surfaces()
	if _aim.visible:
		var a := player.global_position + Vector3(0, 0.012, 0)
		var b := Vector3(_aim_line_target.x, 0.012, _aim_line_target.z)
		_aim_line_im.surface_begin(Mesh.PRIMITIVE_LINES)
		var n := 24
		for i in n:
			if i % 2 == 0:
				_aim_line_im.surface_add_vertex(a.lerp(b, float(i) / n))
				_aim_line_im.surface_add_vertex(a.lerp(b, float(i + 1) / n))
		_aim_line_im.surface_end()
	var show_landing := Tuning.show_landing and incoming != null and bounces == 0 and not incoming.bounce_points.is_empty()
	_landing.visible = show_landing
	if show_landing:
		var b := incoming.bounce_points[0]
		_landing.global_position = Vector3(b.x, 0.006, b.z)
	_path_im.clear_surfaces()
	if Tuning.show_path and ball.active:
		var pr := incoming if incoming != null else BallPhysics.predict(ball.state, 2.5, 1.0 / 60.0, 2)
		if pr.points.size() >= 2:
			_path_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for p in pr.points:
				_path_im.surface_add_vertex(p)
			_path_im.surface_end()


func _debug_string() -> String:
	var s := "FPS %d   time x%.2f\n" % [Engine.get_frames_per_second(), Engine.time_scale]
	s += "ball %.0f km/h  spin %.0f rpm  h %.2f m\n" % [ball.speed_kmh(), ball.spin_rpm(), ball.state.pos.y]
	s += "player %.1f m/s   t_contact %s\n" % [player.velocity.length(), ("%.2f s" % t_contact) if t_contact < 10.0 else "-"]
	if not last_shot.is_empty():
		s += "last: %s %s %s  err %+.0f ms\n" % [last_shot["type"], last_shot["side"], last_shot["label"], last_shot["err_ms"]]
		s += "  q %.2f = timing %.2f x pos %.2f x move %.2f\n" % [last_shot["q"], last_shot["q_t"], last_shot["q_p"], last_shot["q_m"]]
		s += "  %.0f km/h  elev %.1f°  aim (%.1f, %.1f)\n" % [last_shot["speed"], last_shot["elev"], last_shot["target"].x, last_shot["target"].y]
	return s


# --- Autoplay bot (automated testing) ------------------------------------------

func _autoplay_tick() -> void:
	if phase == Phase.SERVE and server == Who.PLAYER:
		if not toss_active:
			_start_toss()
		elif game_time >= toss_ideal + _bot_offset:
			var want_x := box_side * rng.randf_range(0.8, 3.2)
			var ang := deg_to_rad((want_x - box_side * 0.7) / 3.6 * Tuning.swipe_side_angle)
			var length := 0.05 + rng.randf_range(0.4, 0.75) * (Tuning.swipe_deep_len - 0.05)
			_on_swipe(Vector2(sin(ang), -cos(ang)) * length, 0.12)
		return
	if not _player_can_hit():
		_bot_armed = false
		return
	if not _bot_armed:
		_bot_armed = true
		_bot_offset = rng.randfn(0.0, 0.035)  # bot timing error, + = late
	var vec := Vector2(rng.randf_range(-0.12, 0.12), -rng.randf_range(0.17, 0.27))
	if late_until > 0.0:
		if game_time - late_cross_time >= _bot_offset:
			_on_swipe(vec, 0.13)
	elif _bot_offset <= 0.0 and pending_swing.is_empty() and t_contact <= -_bot_offset:
		_on_swipe(vec, 0.13)


func _print_autoplay_summary() -> void:
	var rallies: Array = _stats["rallies"]
	var total := 0
	for r in rallies:
		total += r
	print("\n=== AUTOPLAY SUMMARY ===")
	print("points: %d  won YOU %d : %d CPU   %s" % [rallies.size(), score[0], score[1], scoreboard.games_text()])
	print("avg rally (hits incl. CPU): %.1f   best: %d" % [float(total) / maxf(rallies.size(), 1), best_rally])
	print("player hits: %d   cpu hits: %d" % [_stats["player_hits"], _stats["cpu_hits"]])
	print("timing labels: %s" % str(_stats["labels"]))
	print("point outcomes: %s" % str(_stats["reasons"]))
