extends Node3D
## Game orchestration: rally rules, serve, scoring, player hitting, slow motion,
## feedback, and a bot for automated testing (--autoplay).
##
## Controls (one finger is enough):
##   tap    -> run to that spot (hold the finger to keep running toward it)
##   swipe  -> hit: the ball travels along the swiped line *from the player*;
##             swipe speed = power; depth is chosen automatically (deep, safely in);
##             the swipe's shape picks the stroke: straight = flat, "C" arc = topspin,
##             hook back toward you = slice (see ShotGesture)
##   net    -> balls taken before the bounce are volleys; high balls are smashed
##   timing -> a ring shrinks onto the contact point: swipe when it meets the circle
##   serve  -> tap = toss, swipe = serve (the ring sits on the tossed ball)
## A perfect shot along a line that points into the court lands in; timing and
## position errors are what make balls miss.

enum Who { NONE = -1, PLAYER = 0, CPU = 1 }
enum Phase { WAIT, SERVE, RALLY, OVER, IDLE }  # IDLE: menus are open, no match running
enum ShotType { TOPSPIN, FLAT, SLICE, DROP }

const PLAYER_HOME := Vector3(0.0, 0.0, 12.6)
const CPU_HOME := Vector3(0.0, 0.0, -12.6)
const PLAYER_AREA := Rect2(-9.0, 0.6, 18.0, 17.0)
const CPU_AREA := Rect2(-9.0, -17.6, 18.0, 17.0)
const TOSS_SPEED := 6.0         # m/s straight up from the hand
const TOSS_HAND_H := 1.5
const SERVE_CONTACT_H := 2.85   # ideal contact: on the way down, just below the apex (reaching up)
const SMASH_MIN_H := 2.2        # contact above this height is an overhead smash
const MAX_CONTACT_H := 3.4      # highest ball the player can reach with a jump smash
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
var scoreboard := MatchScore.new(1, 99, 0)  # practice: one endless set

# Tournament / menus (TournamentUI) and skills (Skills)
var ui: TournamentUI
var tournament: Tournament
var tournament_mode := false
var autoplay_tournament := false
var cpu_label := "CPU"
var _match_over := false
var _match_stats := {}
var _after_perks := ""            # screen to open once the pending skill perk choices are made
var _perk_choice := {}
var _practice_skill := 0.5
var _autoplay_format := 0
var _run_dist := 0.0              # metres run this rally (experience for "Ноги")
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
var _close_call := {}
var _dribble_t := 0.0
var _dribble_u := 0.0
var last_serve_kmh := 150.0      # speed of the latest serve (the receiver's return suffers on big serves)            # last close line call, shown after the point

# Movement by taps
var _move_target := Vector3.INF
var _assist_suppressed := false   # the player tapped somewhere: don't auto-position for this ball
var _tap_marker: MeshInstance3D
var _tap_marker_hold := 0.0

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
var _aim_line_origin := Vector3.ZERO
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
var _stats := {"rallies": [], "reasons": {}, "labels": {}, "player_hits": 0, "cpu_hits": 0, "serve": {}}


var graphics: GraphicsQuality

func _ready() -> void:
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		elif a == "--tournament":
			autoplay_tournament = true
		elif a.begins_with("--format="):
			_autoplay_format = int(a.get_slice("=", 1))
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
	hud.touch.swipe_progress.connect(_on_swipe_progress)
	hud.touch.tapped.connect(_on_tap)
	hud.touch.held.connect(_on_hold)
	hud.set_score(scoreboard.point_text())
	hud.menu_requested.connect(_show_menu)

	ui = TournamentUI.new()
	add_child(ui)
	ui.chosen.connect(_on_ui)
	hud.touch.blocked_controls.append(ui.root)

	_build_helpers()
	SaveData.enabled = not autoplay and not _headless()  # test runs never touch the save
	SaveData.load_once()
	_practice_skill = Tuning.ai_skill
	if not autoplay and not _headless():
		sfx.set_ambience(Tuning.ambience)
		Tuning.changed.connect(func() -> void: sfx.set_ambience(Tuning.ambience))
	_last_real_us = Time.get_ticks_usec()
	if autoplay_tournament:
		Skills.reset()  # the bot always starts as a beginner
		_start_tournament(_autoplay_format)
	elif autoplay or _headless():
		_start_practice()
	else:
		_show_menu()


func _build_environment() -> void:
	TelegramApp.init()
	var scenery := Scenery.new()
	add_child(scenery)
	graphics = GraphicsQuality.new()
	graphics.scenery = scenery
	add_child(graphics)


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

	# Where the player tapped to run.
	_tap_marker = MeshInstance3D.new()
	var tmm := TorusMesh.new()
	tmm.inner_radius = 0.22
	tmm.outer_radius = 0.3
	tmm.rings = 24
	tmm.ring_segments = 4
	_tap_marker.mesh = tmm
	_tap_marker.scale = Vector3(1.0, 0.05, 1.0)
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.no_depth_test = true
	tmat.albedo_color = Color(0.6, 0.95, 1.0, 0.8)
	_tap_marker.material_override = tmat
	_tap_marker.visible = false
	add_child(_tap_marker)


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
				if _match_over:
					_finish_match()
				elif _replay_serve:
					_replay_serve = false
					_setup_serve()
				else:
					_reset_point()
	ball.step(delta)
	if phase == Phase.RALLY:
		_run_dist += player.velocity.length() * delta
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
	_update_timing_ring()
	var look := ball.state.pos if ball.visible else Vector3.INF
	player.look_target = look
	cpu.look_target = look
	if phase == Phase.IDLE:
		hud.set_rally("")
	else:
		var mp := ""
		if tournament_mode and phase != Phase.OVER:
			mp = "   ·   МАТЧБОЛ" if scoreboard.match_point_for(0) else ("   ·   матчбол у соперника" if scoreboard.match_point_for(1) else "")
		hud.set_rally("%s   ·   rally %d%s" % [scoreboard.games_text(), rally, mp])
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
	if bp.y > MAX_CONTACT_H or bp.y < 0.04:
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
		_player_hit(err, pending_swing["dir"], pending_swing["pace_k"], pending_swing["type"])


func _on_tap(pos: Vector2) -> void:
	if phase == Phase.SERVE and server == Who.PLAYER:
		if not toss_active and serve_attempt == 1 and rng.randf() < 0.08:
			var to_box_u := Vector3(box_side * 2.0 - player.position.x, 0.0, -2.0 - player.position.z).normalized()
			_player_underarm_serve(to_box_u, rng.randf_range(0.0, 0.6))
		elif not toss_active:
			_start_toss()
		return
	_set_move_target(pos)


func _on_hold(pos: Vector2) -> void:
	if phase == Phase.SERVE and server == Who.PLAYER and toss_active:
		return
	_set_move_target(pos)


func _set_move_target(screen_pos: Vector2) -> void:
	var g := _screen_to_ground(screen_pos)
	if g == Vector3.INF:
		return
	var a := player.area
	_move_target = Vector3(clampf(g.x, a.position.x, a.end.x), 0.0, clampf(g.z, a.position.y, a.end.y))
	_assist_suppressed = true
	_tap_marker.global_position = Vector3(_move_target.x, 0.05, _move_target.z)
	_tap_marker.visible = true
	_tap_marker_hold = 0.6


func _screen_to_ground(screen_pos: Vector2) -> Vector3:
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if dir.y > -0.01:
		return Vector3.INF
	return from + dir * (-from.y / dir.y)


## The swipe drawn on screen, mapped onto the court: the direction the ball will travel.
func _swipe_world_dir(start: Vector2, end: Vector2) -> Vector3:
	var a := _screen_to_ground(start)
	var d := Vector3.ZERO
	if a != Vector3.INF:
		for k in [1.0, 0.75, 0.5, 0.3]:
			var b := _screen_to_ground(start.lerp(end, k))
			if b != Vector3.INF:
				d = b - a
				break
	d.y = 0.0
	if d.length() < 0.05:
		var v := end - start
		d = Vector3(v.x, 0.0, v.y)
	d = d.normalized()
	if d.z > -0.3:  # always toward the opponent
		d = Vector3(d.x, 0.0, -0.3).normalized() if absf(d.x) > 0.01 else Vector3(0, 0, -1)
	return d


func _pace_from_speed(speed: float) -> float:
	return clampf((speed - 0.8) / 3.2, 0.0, 1.0)


func _read_gesture(points: PackedVector2Array, times: PackedInt32Array) -> ShotGesture.Result:
	return ShotGesture.classify(points, times, get_viewport().get_visible_rect().size.y, Tuning.curve_min, Tuning.hook_min, Tuning.drop_len)


func _on_swipe(points: PackedVector2Array, times: PackedInt32Array) -> void:
	var g := _read_gesture(points, times)
	var dir := _swipe_world_dir(g.start, g.apex)
	var pace_k := _pace_from_speed(g.speed)
	shot_type = g.type as ShotType
	_aim_hold = 0.7
	if phase == Phase.SERVE:
		if server == Who.PLAYER:
			if shot_type == ShotType.DROP and not toss_active:
				_player_underarm_serve(dir, pace_k)
			elif toss_active:
				_player_serve(dir, pace_k, ShotType.SLICE if shot_type == ShotType.DROP else shot_type)
		return
	_swing_input(dir, pace_k, shot_type)


func _swing_input(dir: Vector3, pace_k: float, type: int) -> void:
	if not _player_can_hit():
		return
	if late_until > 0.0:
		_player_hit(game_time - late_cross_time, dir, pace_k, type)
		return
	if t_contact > Tuning.early_limit:
		if t_contact < 3.0:
			hud.popup("РАНО", COLOR_WARN, "свайпни, когда кольцо дойдёт до круга")
		return
	if pending_swing.is_empty():
		pending_swing = {"time": game_time, "dir": dir, "pace_k": pace_k, "type": type}
		var side := 1 if player.lateral_of(contact_pred) >= 0.0 else -1
		player.swing(side, t_contact, contact_pred, _swing_style(type, contact_pred.y))
		sfx.play("swing", -12.0, rng.randf_range(0.95, 1.1))


## Rally target: along the line from the contact point, landing deep but safely inside.
## A line that crosses a sideline deep in the other half becomes an angled shot landing
## just inside it; a wider line goes into that deep corner. So with perfect timing the
## ball goes where the line points and stays in; errors are what make it miss.
func rally_target(origin: Vector3, d: Vector3, pace_k: float) -> Vector3:
	var w := Court.SINGLES_HALF_WIDTH - 0.6
	var zt := -(Court.HALF_LENGTH - lerpf(2.6, 1.5, pace_k))
	var p := origin + d * ((zt - origin.z) / d.z)
	if absf(p.x) > w:
		var ps := origin + d * ((signf(p.x) * w - origin.x) / d.x) if absf(d.x) > 0.001 else p
		# Crosses the sideline deep in the other half: angled shot. Otherwise: into the deep corner.
		p = ps if ps.z <= -5.0 and ps.z >= zt else Vector3(signf(p.x) * w, 0.0, zt)
	p.y = BallPhysics.RADIUS
	return p


## Drop shot target: along the aim line, just over the net. A clean touch dies close to
## the net; a poor one sits up deeper, where the opponent can punish it.
func drop_target(origin: Vector3, d: Vector3, pace_k: float, q: float) -> Vector3:
	var w := Court.SINGLES_HALF_WIDTH - 0.6
	var depth := lerpf(1.3, 2.3, pace_k) + (1.0 - q) * 3.5
	var p := origin + d * ((-depth - origin.z) / d.z)
	p.x = clampf(p.x, -w, w)
	p.z = -depth
	p.y = BallPhysics.RADIUS
	return p


## Serve target: along the line from the server into the diagonal box, near the service line.
## A wide line is pulled onto the box's outer edge and a line slightly toward the
## wrong box onto the T; only a line clearly into the wrong box faults.
func serve_target(origin: Vector3, d: Vector3, pace_k: float) -> Vector3:
	var zt := -(Court.SERVICE_LINE - lerpf(1.1, 0.6, pace_k))
	var p := origin + d * ((zt - origin.z) / d.z)
	var lo := 0.25
	var hi := Court.SINGLES_HALF_WIDTH - 0.2
	var bx := p.x * box_side
	if bx < lo and bx > lo - 1.5:
		p.x = box_side * lo
	elif bx > hi:
		p.x = box_side * hi
	p.y = BallPhysics.RADIUS
	return p


func _aim_origin() -> Vector3:
	if phase == Phase.SERVE:
		return Vector3(player.position.x, 0.0, player.position.z - 0.3)
	if t_contact < 10.0:
		return Vector3(contact_pred.x, 0.0, contact_pred.z)
	return player.position + player.forward() * Athlete.CONTACT_FORWARD


func _on_swipe_progress(points: PackedVector2Array) -> void:
	var times := PackedInt32Array()
	times.resize(points.size())
	var g := _read_gesture(points, times)
	if not Tuning.show_aim:
		return
	var dir := _swipe_world_dir(g.start, g.apex)
	var origin := _aim_origin()
	if phase == Phase.SERVE:
		if server != Who.PLAYER:
			return
		var sp := serve_target(origin, dir, 0.5)
		_set_aim(origin, sp, Court.in_service_box(sp, -1, box_side, 0.0))
	else:
		var p := rally_target(origin, dir, 0.5)
		_set_aim(origin, p, Court.is_in_singles(p, -1, 0.0))
	_aim_hold = INF


func _set_aim(origin: Vector3, p: Vector3, inside: bool) -> void:
	_aim.visible = true
	_aim.global_position = Vector3(p.x, 0.05, p.z)
	_aim_mat.albedo_color = AIM_IN if inside else AIM_OUT
	_aim_line_origin = origin
	_aim_line_target = p


func _swing_style(type: int, height: float) -> int:
	if height > SMASH_MIN_H:
		return Athlete.Style.SMASH
	return [Athlete.Style.TOPSPIN, Athlete.Style.FLAT, Athlete.Style.SLICE, Athlete.Style.DROP][type]


func _player_hit(err: float, dir: Vector3, pace_k: float, type: int) -> void:
	var bp := ball.state.pos
	pending_swing = {}
	late_until = -1.0
	var lateral := player.lateral_of(bp)
	var flat_d := Vector2(bp.x - player.position.x, bp.z - player.position.z).length()
	if flat_d > Athlete.REACH:
		_miss("TOO FAR")
		return
	var side := 1 if lateral >= 0.0 else -1
	var smash := bp.y > SMASH_MIN_H
	var volley := bounces == 0 and not smash
	var skill := stroke_skill(side, type, smash, volley)
	var sk := Skills.stroke(skill)
	var tq := timing_quality(err, sk["window"])
	var q_t: float = tq[0]
	var label: String = tq[1]
	var q_p := position_quality(lateral, minf(bp.y, 1.2) if smash else bp.y)
	var q_m := movement_quality(player.velocity.length(), Skills.move_penalty_mult())
	var q := q_t * q_p * q_m

	var origin := Vector3(bp.x, 0.0, bp.z)
	var drop := type == ShotType.DROP and not smash
	var target := drop_target(origin, dir, pace_k, q) if drop else rally_target(origin, dir, pace_k)
	var pace: float
	var top: float
	if smash:
		pace = lerpf(30.0, 44.0, pace_k)
		top = 40.0
	else:
		match type:
			ShotType.FLAT:
				pace = lerpf(24.0, 40.0, pace_k)
				top = 40.0
			ShotType.SLICE:
				# Slice floats: slower, lots of backspin, stays low after the bounce.
				pace = lerpf(15.0, 23.0, pace_k)
				top = -lerpf(180.0, 270.0, pace_k)
			ShotType.DROP:
				# Soft hands, heavy backspin: just over the net and it dies.
				pace = 9.0
				top = -lerpf(260.0, 320.0, q)
			_:
				pace = lerpf(21.0, 35.0, pace_k)
				top = lerpf(190.0, 340.0, pace_k)
		if volley and not drop:
			# Punch volleys: shorter swing, less pace and spin, more control.
			pace *= 0.8
			top *= 0.5
	if not drop:
		pace *= sk["pace"]
	top *= sk["spin"]

	if not player.is_swinging():
		player.swing(side, 0.02, bp, _swing_style(type, bp.y))
	player.update_contact(bp)
	var r := execute_shot(Who.PLAYER, player, bp, target, pace, top, q, err, side, false, 0.0, drop, 0.3, sk["scatter"])
	_gain_xp(skill, label)
	if label == "PERFECT":
		_match_stats["perfect"] = _match_stats.get("perfect", 0) + 1
	ai.on_player_hit()
	_assist_suppressed = false
	_hits_total += 1
	_stats["player_hits"] += 1
	_stats["labels"][label] = _stats["labels"].get(label, 0) + 1
	if Tuning.show_aim:
		_set_aim(origin, target, Court.is_in_singles(target, -1, 0.0))
		_aim_hold = 0.8

	# Feedback
	var color := COLOR_GOOD
	if label == "PERFECT":
		color = Hud.GOLD
	elif label == "EARLY" or label == "LATE":
		color = COLOR_WARN
	var notes := []
	if q_p < 0.75:
		notes.append("далеко от мяча")
	if q_m < 0.85:
		notes.append("на бегу")
	var stroke: String = "SMASH" if smash else (("VOLLEY " if volley else "") + ShotGesture.NAMES[type])
	var sub := "%s  ·  %d km/h  ·  %d%%" % [stroke, roundi(r.speed * 3.6), roundi(q * 100.0)]
	if not notes.is_empty():
		sub += "  ·  " + ", ".join(notes)
	hud.popup(label, color, sub)
	if label == "PERFECT":
		cam.impulse(1.0)
		if Tuning.hitstop and not autoplay:
			_hitstop_until_ms = Time.get_ticks_msec() + 70
	else:
		cam.impulse(0.4 * q)
	_haptic("heavy" if smash else ("perfect" if label == "PERFECT" else ("medium" if label == "GOOD" else "light")))

	last_shot = {
		"label": label, "err_ms": err * 1000.0, "q_t": q_t, "q_p": q_p, "q_m": q_m, "q": q,
		"side": "FH" if side > 0 else "BH", "speed": r.speed * 3.6, "elev": r.elevation_deg,
		"target": Vector2(target.x, target.z), "type": stroke,
	}


## Phone vibration on contact: Telegram haptics inside the Mini App (iPhone too),
## the browser Vibration API elsewhere (Android). See TelegramApp.
func _haptic(kind: String) -> void:
	if Tuning.vibration and not autoplay:
		TelegramApp.haptic(kind)


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
	# At the net (or under a high ball): take it out of the air.
	if bounces == 0 and t_contact < 10.0 and contact_pred.y > 0.3 and contact_pred.y < MAX_CONTACT_H:
		if player.position.z < 8.0 or contact_pred.y > SMASH_MIN_H:
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
	player.max_speed = Tuning.player_speed * Skills.run_speed_mult()
	var serving := phase == Phase.SERVE and server == Who.PLAYER
	if serving and (toss_active or autoplay):
		player.move_input = Vector2.ZERO
		return
	var mv := hud.touch.move_vector
	if hud.touch.stick_active:
		_assist_suppressed = true  # the thumb is steering: no auto-positioning this ball
	if mv != Vector2.ZERO:
		_move_target = Vector3.INF
	elif _move_target != Vector3.INF:
		var d := Vector2(_move_target.x - player.position.x, _move_target.z - player.position.z)
		if d.length() < 0.15:
			_move_target = Vector3.INF
		else:
			mv = d.normalized() * clampf(d.length() / 0.7, 0.3, 1.0)
	var assist := Tuning.assist
	if autoplay:
		mv = Vector2.ZERO
		assist = 1.0
	var free := mv == Vector2.ZERO and (autoplay or not _assist_suppressed) and not serving
	if free and assist > 0.0 and _player_can_hit() and t_contact < 2.5:
		# Auto-positioning toward a comfortable contact point.
		var ideal := _ideal_contact()
		var side := 1 if player.lateral_of(ideal) >= 0.0 else -1
		var stance := player.stance_for(ideal, side)
		var d := Vector2(stance.x - player.position.x, stance.z - player.position.z)
		if d.length() > 0.05:
			mv = d.normalized() * clampf(d.length() / 0.6, 0.0, 1.0) * assist
	elif free and assist > 0.0 and phase == Phase.RALLY and last_hitter == Who.PLAYER:
		# Recover toward the middle of the baseline while the opponent plays.
		var home := Vector2(clampf(ball.state.pos.x * 0.3, -1.5, 1.5) - player.position.x, 12.4 - player.position.z)
		if home.length() > 0.3:
			mv = home.limit_length(1.0) * (0.6 + 0.4 * assist)
	player.move_input = mv
	if not _player_can_hit() and pending_swing.is_empty():
		player.relax()


# --- Quality model (shared with the AI) ---------------------------------------

## Returns [quality 0..1, label].
## `window_scale` widens or narrows the PERFECT/GOOD windows (the player's skill level).
func timing_quality(err: float, window_scale := 1.0) -> Array:
	var a := absf(err)
	var pw := Tuning.perfect_window * window_scale
	var gw := Tuning.good_window * window_scale
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


## `penalty` scales the cost of hitting on the run (the player's "Ноги" skill).
func movement_quality(speed: float, penalty := 1.0) -> float:
	return clampf(1.0 - maxf(0.0, speed - 2.5) * 0.07 * penalty, 0.65, 1.0)


## Turns intent into a launched ball, adding execution error that scales with (1 - quality).
## Timing error is deterministic: early contact pulls the ball, late contact pushes it.
## `scatter` scales the random part of the error (the player's skill level).
func execute_shot(who: int, hitter: Athlete, contact: Vector3, target: Vector3, pace: float, top: float, q: float, t_err: float, side: int, lob := false, side_spin := 0.0, drop := false, net_margin := 0.3, scatter := 1.0) -> ShotSolver.Result:
	var flat := target - contact
	flat.y = 0.0
	var dist := flat.length()
	# Deterministic pull/push grows outside the perfect window; random scatter grows
	# steeply as quality drops, so PERFECT/GOOD stay in and EARLY/LATE start to miss.
	var off := maxf(absf(t_err) - Tuning.perfect_window, 0.0) * signf(t_err)
	var bias := clampf(off / Tuning.good_window, -2.5, 2.5) * deg_to_rad(1.3) * float(side)
	target += hitter.right() * (tan(bias) * dist)
	var miss := pow(1.0 - q, 1.5)
	target += hitter.right() * rng.randfn(0.0, (0.06 + miss * 1.6) * scatter)
	target += hitter.forward() * rng.randfn(0.0, (0.1 + miss * 2.0) * scatter)
	pace *= lerpf(0.72, 1.06, q)
	top *= lerpf(0.6, 1.0, q)
	var r: ShotSolver.Result
	if drop:
		r = ShotSolver.solve_drop(contact, target, top)
	elif lob:
		r = ShotSolver.solve_lob(contact, target, top, pace)
	else:
		r = ShotSolver.solve(contact, target, pace, top, net_margin, side_spin)
	var v := r.velocity
	var axis := Vector3.UP.cross(v).normalized()
	if axis.length() > 0.5:
		v = v.rotated(axis, deg_to_rad(rng.randfn(0.0, (0.12 + pow(1.0 - q, 1.5) * 2.0) * scatter)))
	ball.launch(contact, v, r.spin)
	last_hitter = who as Who
	bounces = 0
	net_touched = false
	if who == Who.CPU:
		ball_used = false
		_assist_suppressed = false
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
		_land_dot.global_position = Vector3(pos.x, 0.05, pos.z)
		_land_dot.visible = true
		_land_hold = 1.2
	if bounces == 1:
		_line_call(pos, receiver_half)
	if serve_flight:
		serve_flight = false
		if Court.in_service_box(pos, receiver_half, box_side, BallPhysics.RADIUS):
			_close_call = {}  # a good serve: the call only matters if it decides something
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


## Hawk-Eye: distance from the ball mark to the nearest line that decides the call
## (positive = in). Close calls get the top-down replay panel.
func _line_call(pos: Vector3, half: int) -> void:
	var r := BallPhysics.RADIUS
	var margin: float
	var line_axis := 0  # 0 = the deciding line runs along z (a sideline), 1 = along x
	var z := pos.z * half
	if serve_flight:
		var x := pos.x * box_side
		var m_service := Court.SERVICE_LINE + r - z
		var m_center := x + r
		var m_side := Court.SINGLES_HALF_WIDTH + r - x
		margin = minf(m_service, minf(m_center, m_side))
		line_axis = 1 if margin == m_service else 0
	else:
		var m_side := Court.SINGLES_HALF_WIDTH + r - absf(pos.x)
		var m_base := Court.HALF_LENGTH + r - z
		margin = minf(m_side, m_base)
		line_axis = 1 if m_base < m_side else 0
	if z < 0.0:
		return  # landed on the wrong half: not a line call
	_close_call = {"margin": margin, "axis": line_axis} if absf(margin) <= Tuning.hawkeye_range else {}


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
	var o := cpu_label
	if winner == Who.PLAYER:
		text = {"OUT": o + " OUT", "NET": o + " NET", "WINNER": "WINNER!", "ACE": "ACE!", "DOUBLE FAULT": o + " DOUBLE FAULT"}[reason]
	else:
		text = {"OUT": "OUT", "NET": "NET", "WINNER": "MISSED", "ACE": o + " ACE", "DOUBLE FAULT": "DOUBLE FAULT"}[reason]
	if winner == Who.PLAYER and reason == "ACE":
		_match_stats["aces"] = _match_stats.get("aces", 0) + 1
	_match_stats["best_rally"] = maxi(_match_stats.get("best_rally", 0), rally)
	if _run_dist > 0.0:
		_gain_xp("feet", "", _run_dist * Skills.RUN_XP_PER_M)
		_run_dist = 0.0
	var who := "YOU" if winner == Who.PLAYER else o
	var ev: int = scoreboard.add_point(winner)
	match ev:
		MatchScore.Event.GAME:
			text += "\nGAME " + who
		MatchScore.Event.SET:
			text += "\nСЕТ " + who
		MatchScore.Event.MATCH:
			text += "\nМАТЧ " + who
	server = scoreboard.server as Who
	if tournament_mode and scoreboard.is_over():
		_match_over = true
		phase_timer = 0.4 if autoplay else 2.4
	hud.show_message(text, COLOR_WIN if winner == Who.PLAYER else COLOR_BAD)
	if not _close_call.is_empty() and reason != "NET":
		hud.hawkeye(_close_call["margin"], _close_call["axis"])
	_close_call = {}
	sfx.play("point" if winner == Who.PLAYER else "miss", -8.0 if winner == Who.PLAYER else -10.0)
	hud.set_score(scoreboard.point_text())

	_stats["rallies"].append(rally)
	var srv_key := ("YOU" if server == Who.PLAYER else "CPU") + " serve: "
	var outcome := "ace" if reason == "ACE" else ("double fault" if reason == "DOUBLE FAULT" else ("unreturned" if rally == 1 and winner == server else ("return error" if rally == 2 and winner == server else "rally")))
	_stats["serve"][srv_key + outcome] = _stats["serve"].get(srv_key + outcome, 0) + 1
	var key := ("YOU " if winner == Who.PLAYER else "CPU ") + "wins: " + text.split("\n")[0]
	_stats["reasons"][key] = _stats["reasons"].get(key, 0) + 1
	if autoplay and not autoplay_tournament:
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
		if not _close_call.is_empty() and kind != "NET":
			hud.hawkeye(_close_call["margin"], _close_call["axis"])
		_close_call = {}
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


## Before the toss the server bounces the ball: three bounces, a short pause in the
## hand, again, until the toss. Each touch on the court plays a real bounce recording.
func _dribble(srv: Athlete, delta: float) -> void:
	var hand := _ball_in_hand(srv)
	_dribble_t += delta
	var period := 0.85
	var cycle := int(_dribble_t / period)
	var u := fmod(_dribble_t, period) / period
	var y := hand.y
	if cycle % 4 != 3:
		if u < 0.5:
			var k := u / 0.5
			y = lerpf(hand.y, BallPhysics.RADIUS, k * k)
		else:
			var k := (u - 0.5) / 0.5
			y = lerpf(BallPhysics.RADIUS, hand.y, 1.0 - (1.0 - k) * (1.0 - k))
		if u >= 0.5 and _dribble_u < 0.5:
			sfx.play("bounce", -9.0 if server == Who.PLAYER else -17.0, rng.randf_range(0.95, 1.05))
	_dribble_u = u
	ball.hold(Vector3(hand.x, y, hand.z))


## The ball rests on the server's left hand until the toss.
func _ball_in_hand(a: Athlete) -> Vector3:
	return a.left_hand_world() + Vector3(0.0, 0.07, 0.0)


func _hand_position(a: Athlete) -> Vector3:
	# Toss from the left hand, just in front and slightly right of the head (right-hander).
	return a.position + a.right() * 0.1 + a.forward() * 0.4 + Vector3.UP * TOSS_HAND_H


## Place both players for the serve: server behind the baseline on the deuce/ad side,
## receiver diagonally opposite.
func _setup_serve() -> void:
	phase = Phase.SERVE
	_dribble_t = 0.0
	_dribble_u = 0.0
	_close_call = {}
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
	if server == Who.CPU:
		sx = signf(sx) * rng.randf_range(0.4, 2.2)  # the CPU varies where it serves from
	srv.position = Vector3(sx, 0.0, srv_z)
	rcv.position = ai.receive_position(box_side) if server == Who.PLAYER else Vector3(box_side * 2.4, 0.0, 12.7)
	srv.velocity = Vector3.ZERO
	rcv.velocity = Vector3.ZERO
	srv.relax()
	rcv.relax()
	srv.serve_ready()
	if server == Who.PLAYER:
		# Rules: behind the baseline, between the centre mark and the sideline on this side.
		var x0 := 0.15 if sx > 0.0 else -Court.SINGLES_HALF_WIDTH
		player.area = Rect2(x0, Court.HALF_LENGTH + 0.08, Court.SINGLES_HALF_WIDTH - 0.15, 1.6)
		_move_target = Vector3.INF
		pass
	else:
		player.area = PLAYER_AREA
		_cpu_serve_timer = 0.5 if autoplay else 1.9
	ball.hold(_ball_in_hand(srv))
	ai.on_cpu_hit(0.0)


func _update_serve(delta: float) -> void:
	var srv := _server_athlete()
	if not toss_active:
		srv.serve_ready()
		_dribble(srv, delta)
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
	var hand := _ball_in_hand(srv)
	ball.launch(hand, Vector3(0.0, TOSS_SPEED, 0.0), Vector3.ZERO)
	toss_active = true
	var g := BallPhysics.GRAVITY
	var disc := maxf(0.0, TOSS_SPEED * TOSS_SPEED - 2.0 * g * (SERVE_CONTACT_H - hand.y))
	toss_ideal = game_time + (TOSS_SPEED + sqrt(disc)) / g
	srv.prepare_serve()
	if server == Who.CPU:
		_cpu_toss_offset = rng.randfn(0.0, lerpf(0.06, 0.02, Tuning.ai_skill))
	elif autoplay:
		_bot_offset = rng.randfn(0.0, 0.03)


func _player_serve(dir: Vector3, pace_k: float, type: int) -> void:
	var bp := ball.state.pos
	if bp.y < 1.7:
		return
	var err := game_time - toss_ideal
	var sk := Skills.stroke("serve")
	var tq := timing_quality(err, sk["window"])
	var q: float = tq[0]
	var label: String = tq[1]
	var origin := Vector3(bp.x, 0.0, bp.z)
	var target := serve_target(origin, dir, pace_k)
	var pace: float
	var top: float
	var side_spin := 0.0
	match type:
		ShotType.FLAT:
			pace = lerpf(40.0, 58.0, pace_k)
			top = 150.0
		ShotType.SLICE:
			pace = lerpf(31.0, 42.0, pace_k)
			top = 80.0
			side_spin = 330.0  # curves to the server's left and keeps sliding away after the bounce
		_:
			pace = lerpf(30.0, 42.0, pace_k)
			top = lerpf(300.0, 420.0, pace_k)  # kick: dives in, jumps up high
	pace *= sk["pace"]
	top *= sk["spin"]
	player.swing(1, 0.02, bp, Athlete.Style.SERVE)
	var r := execute_shot(Who.PLAYER, player, bp, target, pace, top, q, err, 1, false, side_spin, false, 0.12, sk["scatter"])
	_after_serve_hit()
	_gain_xp("serve", label)
	if label == "PERFECT":
		_match_stats["perfect"] = _match_stats.get("perfect", 0) + 1
	last_serve_kmh = r.speed * 3.6
	ai.on_player_serve(last_serve_kmh, false)
	_stats["labels"][label] = _stats["labels"].get(label, 0) + 1
	if Tuning.show_aim:
		_set_aim(origin, target, Court.in_service_box(target, -1, box_side, 0.0))
		_aim_hold = 0.8
	var color := Hud.GOLD if label == "PERFECT" else (COLOR_WARN if label == "EARLY" or label == "LATE" else COLOR_GOOD)
	hud.popup(label, color, "подача %s  ·  %d km/h" % [["KICK", "FLAT", "SLICE"][type], roundi(r.speed * 3.6)])
	cam.impulse(1.0 if label == "PERFECT" else 0.4)
	_haptic("perfect" if label == "PERFECT" else "medium")
	last_shot = {
		"label": label, "err_ms": err * 1000.0, "q_t": q, "q_p": 1.0, "q_m": 1.0, "q": q,
		"side": "SRV", "speed": r.speed * 3.6, "elev": r.elevation_deg,
		"target": Vector2(target.x, target.z), "type": ["KICK", "FLAT", "SLICE"][type],
	}


## Underarm drop serve (Bublik / Kyrgios): no toss, the ball is struck from the hand
## low and soft, landing just over the net. Deadly when the receiver stands deep.
func _player_underarm_serve(dir: Vector3, pace_k: float) -> void:
	var contact := player.position + player.right() * 0.55 + player.forward() * 0.45 + Vector3.UP * 0.75
	var origin := Vector3(contact.x, 0.0, contact.z)
	var depth := lerpf(1.4, 2.6, pace_k)
	var target := origin + dir * ((-depth - origin.z) / dir.z)
	var lo := 0.4
	var hi := Court.SINGLES_HALF_WIDTH - 0.4
	target.x = box_side * clampf(target.x * box_side, lo, hi)
	target.z = -depth
	target.y = BallPhysics.RADIUS
	var q := 0.9
	player.swing(1, 0.02, contact, Athlete.Style.UNDERARM)
	var r := execute_shot(Who.PLAYER, player, contact, target, 9.0, -220.0, q, 0.0, 1, false, 0.0, true)
	_after_serve_hit()
	last_serve_kmh = r.speed * 3.6
	ai.on_player_serve(last_serve_kmh, true)
	if Tuning.show_aim:
		_set_aim(origin, target, Court.in_service_box(target, -1, box_side, 0.0))
		_aim_hold = 0.8
	hud.popup("UNDERARM", COLOR_GOOD, "подача снизу  ·  %d km/h" % roundi(r.speed * 3.6))
	_haptic("light")


func _cpu_serve_hit() -> void:
	var s := Tuning.ai_skill
	var bp := ball.state.pos
	var q: float = timing_quality(_cpu_toss_offset)[0]
	var tx: float
	var tz: float
	var pace: float
	var top: float
	var side_spin := 0.0
	if serve_attempt == 1:
		var wide := rng.randf() < 0.5
		tx = box_side * (rng.randf_range(2.6, 3.6) if wide else rng.randf_range(0.4, 1.2))
		tz = rng.randf_range(4.6, 5.9)
		pace = lerpf(32.0, 46.0, s) * rng.randf_range(0.9, 1.05)
		top = 120.0
		if wide and rng.randf() < 0.5:
			pace *= 0.85
			side_spin = 240.0 * -box_side  # slice curving out wide
	else:
		tx = box_side * rng.randf_range(0.9, 2.6)
		tz = rng.randf_range(4.2, 5.4)
		pace = lerpf(26.0, 34.0, s)
		top = 320.0
	cpu.swing(1, 0.02, bp, Athlete.Style.SERVE)
	var r := execute_shot(Who.CPU, cpu, bp, Vector3(tx, BallPhysics.RADIUS, tz), pace, top, q, _cpu_toss_offset, 1, false, side_spin, false, 0.12)
	last_serve_kmh = r.speed * 3.6
	_after_serve_hit()
	ai.on_cpu_hit(tx)
	player.split_step()


func _after_serve_hit() -> void:
	phase = Phase.RALLY
	serve_flight = true
	toss_active = false
	player.area = PLAYER_AREA


# --- Tournament flow, menus and skills -------------------------------------------

func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Which skill a stroke trains (and is played with).
func stroke_skill(side: int, type: int, smash: bool, volley: bool) -> String:
	if smash or volley:
		return "net"
	if type == ShotType.SLICE or type == ShotType.DROP:
		return "touch"
	return "forehand" if side > 0 else "backhand"


## Experience multiplier: tougher opponents and longer formats pay more; practice pays little.
func _xp_mult() -> float:
	if not tournament_mode or tournament == null:
		return 0.3
	return (1.0 + 0.25 * tournament.stage) * float(tournament.format_info()["reward"])


## Experience for a hit (by timing label) or a raw amount (running).
func _gain_xp(skill: String, label: String, raw := -1.0) -> void:
	if phase == Phase.IDLE:
		return
	var amount := raw if raw >= 0.0 else Skills.BASE_XP * float(Skills.TIMING_XP.get(label, 1.0))
	var lv := Skills.add_xp(skill, amount * _xp_mult())
	if lv > 0:
		hud.level_up("+1 %s  ·  ур. %d" % [String(Skills.NAMES[skill]).to_upper(), lv], lv % Skills.PERK_EVERY == 0)
		_haptic("perfect")
		cam.impulse(0.6)
		SaveData.save()


func _show_menu() -> void:
	tournament = null
	tournament_mode = false
	_stop_match()
	Rewards.restore()
	Tuning.ai_skill = _practice_skill
	cpu_label = "CPU"
	_next_screen("menu")


func _stop_match() -> void:
	_match_over = false
	_replay_serve = false
	phase = Phase.IDLE
	ball.park()
	pending_swing = {}
	late_until = -1.0
	Engine.time_scale = 1.0
	hud.set_score("")


func _start_practice() -> void:
	tournament = null
	tournament_mode = false
	Rewards.restore()
	Tuning.ai_skill = _practice_skill
	cpu_label = "CPU"
	scoreboard = MatchScore.new(1, 99, 0, Who.PLAYER, cpu_label)
	ui.close()
	_begin_match()


func _start_tournament(format_index: int) -> void:
	tournament = Tournament.new(format_index)
	tournament_mode = true
	Rewards.restore()
	if autoplay:
		_play_match()
	else:
		ui.show_bracket(tournament)


func _play_match() -> void:
	var opp := tournament.opponent()
	Rewards.apply(tournament.perks)
	Tuning.ai_skill = opp["skill"]
	cpu_label = opp["short"]
	scoreboard = tournament.new_score(rng.randi_range(0, 1))
	ui.close()
	_begin_match()
	hud.show_message("%s\n%s" % [tournament.round_name(), opp["name"]], Color.WHITE)


func _begin_match() -> void:
	score = [0, 0]
	rally = 0
	best_rally = 0
	_points_played = 0
	_match_over = false
	_replay_serve = false
	_run_dist = 0.0
	_match_stats = {"perfect": 0, "aces": 0, "best_rally": 0}
	server = scoreboard.server as Who
	player.area = PLAYER_AREA
	player.position = PLAYER_HOME
	cpu.position = CPU_HOME
	hud.set_score(scoreboard.point_text())
	if not autoplay and not _headless():
		hud.show_tutorial_once()
	_reset_point()


func _finish_match() -> void:
	var won: bool = scoreboard.winner == Who.PLAYER
	var st: String = scoreboard.final_text()
	_stop_match()
	tournament.record_match(won, st, rng)
	if tournament.state == Tournament.State.OVER:
		SaveData.record_run(tournament)
		Rewards.restore()
	else:
		SaveData.save()
	if autoplay:
		_autoplay_after_match(won, st)
		return
	ui.show_result(tournament, won, st, _match_stats)


func _on_ui(action: String, arg: int) -> void:
	match action:
		"start_tournament":
			ui.show_formats()
		"format":
			_start_tournament(arg)
		"practice":
			_start_practice()
		"character":
			ui.show_character()
		"menu":
			_show_menu()
		"play":
			_play_match()
		"give_up":
			if tournament.state != Tournament.State.OVER:
				tournament.give_up()
				SaveData.record_run(tournament)
				Rewards.restore()
			_next_screen("summary")
		"to_reward":
			_next_screen("reward")
		"to_summary":
			_next_screen("summary")
		"reward":
			tournament.take_reward(arg)
			ui.show_bracket(tournament)
		"wildcard":
			if tournament.use_wildcard():
				ui.show_bracket(tournament)
		"perk":
			Skills.take_perk(_perk_choice["offer"][arg]["id"])
			SaveData.save()
			_next_screen(_after_perks)


## Opens a screen, but first lets the player pick the build perks they earned.
func _next_screen(target: String) -> void:
	_perk_choice = Skills.next_pending(rng)
	if not _perk_choice.is_empty():
		_after_perks = target
		ui.show_skill_perk(_perk_choice["skill"], _perk_choice["offer"])
		return
	match target:
		"reward":
			ui.show_reward(tournament)
		"summary":
			ui.show_summary(tournament)
		_:
			ui.show_menu()


func _levels_text() -> String:
	var parts: Array[String] = []
	for id in Skills.LIST:
		parts.append("%s %d" % [Skills.NAMES[id], Skills.level(id)])
	return ", ".join(parts)


## --autoplay --tournament: the bot plays a whole tournament, picking rewards itself.
func _autoplay_after_match(won: bool, st: String) -> void:
	var last: Dictionary = tournament.results.back()
	var opp: Dictionary = Opponents.ROSTER[last["stage"]]
	print("MATCH %s vs %s: %s %s   [%s]" % [Opponents.ROUND_NAMES[last["stage"]], opp["name"], "WON" if won else "LOST", st, _levels_text()])
	while true:
		var c := Skills.next_pending(rng)
		if c.is_empty():
			break
		Skills.take_perk(c["offer"][0]["id"])
		print("  build perk (%s): %s" % [Skills.NAMES[c["skill"]], c["offer"][0]["title"]])
	if tournament.results.size() > 25:
		tournament.give_up()
	match tournament.state:
		Tournament.State.REWARD:
			var pick := 2 if tournament.wildcards == 0 else 0
			print("  reward: %s" % tournament.offer[pick]["title"])
			tournament.take_reward(pick)
			_play_match()
		Tournament.State.LOST:
			tournament.use_wildcard()
			print("  wildcard used, replaying")
			_play_match()
		_:
			print("\n=== TOURNAMENT ===\n%s  ·  gold %d  ·  matches %d\nskills: %s" % [tournament.finish_text(), tournament.gold, tournament.results.size(), _levels_text()])
			get_tree().quit()


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
			want = absf(player.lateral_of(contact_pred)) < 2.8 and contact_pred.y < MAX_CONTACT_H
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
	if _tap_marker_hold > 0.0:
		_tap_marker_hold -= rd
		_tap_marker.visible = _tap_marker_hold > 0.0 and _move_target != Vector3.INF
	_aim_line_im.clear_surfaces()
	if _aim.visible:
		var a := Vector3(_aim_line_origin.x, 0.05, _aim_line_origin.z)
		var b := Vector3(_aim_line_target.x, 0.05, _aim_line_target.z)
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
		_landing.global_position = Vector3(b.x, 0.05, b.z)
	_path_im.clear_surfaces()
	if Tuning.show_path and ball.active:
		var pr := incoming if incoming != null else BallPhysics.predict(ball.state, 2.5, 1.0 / 60.0, 2)
		if pr.points.size() >= 2:
			_path_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for p in pr.points:
				_path_im.surface_add_vertex(p)
			_path_im.surface_end()


func _update_timing_ring() -> void:
	var ring := hud.ring
	# The ring hangs above the player (never over the body or the ball's path) and
	# leans toward the side of the stroke: right for forehands, left for backhands.
	var anchor := cam.unproject_position(player.global_position + Vector3(0.0, 2.35, 0.0)) + Vector2(0.0, -70.0)
	ring.anchor = anchor
	# Everything below the player's feet is the joystick zone for the left thumb.
	var vh := get_viewport().get_visible_rect().size.y
	hud.touch.stick_zone_top = clampf(cam.unproject_position(player.global_position).y + 28.0, vh * 0.55, vh * 0.9)
	if autoplay:
		ring.hide_ring()
		return
	if phase == Phase.SERVE and server == Who.PLAYER and toss_active:
		var ws := float(Skills.stroke("serve")["window"])
		ring.show_ring(anchor, toss_ideal - game_time, Tuning.perfect_window * ws, Tuning.good_window * ws)
		return
	if _player_can_hit():
		var fh := player.lateral_of(contact_pred) >= 0.0
		var lean := 55.0 if fh else -55.0
		var w := float(Skills.stroke("forehand" if fh else "backhand")["window"])
		var pw := Tuning.perfect_window * w
		var gw := Tuning.good_window * w
		if late_until > 0.0:
			ring.show_ring(anchor + Vector2(lean, 0.0), late_cross_time - game_time, pw, gw)
			return
		if t_contact < 0.85 and absf(player.lateral_of(contact_pred)) < 3.0 and contact_pred.y < MAX_CONTACT_H:
			ring.show_ring(anchor + Vector2(lean, 0.0), t_contact, pw, gw)
			return
	ring.hide_ring()


func _debug_string() -> String:
	var s := "FPS %d   time x%.2f   %s\n" % [Engine.get_frames_per_second(), Engine.time_scale, graphics.describe()]
	s += "ball %.0f km/h  spin %.0f rpm  h %.2f m\n" % [ball.speed_kmh(), ball.spin_rpm(), ball.state.pos.y]
	s += "player %.1f m/s   t_contact %s\n" % [player.velocity.length(), ("%.2f s" % t_contact) if t_contact < 10.0 else "-"]
	if not last_shot.is_empty():
		s += "last: %s %s %s  err %+.0f ms\n" % [last_shot["type"], last_shot["side"], last_shot["label"], last_shot["err_ms"]]
		s += "  q %.2f = timing %.2f x pos %.2f x move %.2f\n" % [last_shot["q"], last_shot["q_t"], last_shot["q_p"], last_shot["q_m"]]
		s += "  %.0f km/h  elev %.1f°  aim (%.1f, %.1f)\n" % [last_shot["speed"], last_shot["elev"], last_shot["target"].x, last_shot["target"].y]
	return s


# --- Autoplay bot (automated testing) ------------------------------------------

func _bot_dir(max_deg: float) -> Vector3:
	var a := deg_to_rad(rng.randf_range(-max_deg, max_deg))
	return Vector3(sin(a), 0.0, -cos(a))


func _autoplay_tick() -> void:
	if phase == Phase.SERVE and server == Who.PLAYER:
		if not toss_active:
			_start_toss()
		elif game_time >= toss_ideal + _bot_offset:
			var to_box := Vector3(box_side * 2.0 - player.position.x, 0.0, -5.2 - player.position.z).normalized()
			_player_serve(to_box.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-6.0, 6.0))), rng.randf_range(0.3, 1.0), rng.randi_range(0, 2))
		return
	if not _player_can_hit():
		_bot_armed = false
		return
	if not _bot_armed:
		_bot_armed = true
		_bot_offset = rng.randfn(0.0, 0.035)  # bot timing error, + = late
	var dir := _bot_dir(22.0)
	var pk := rng.randf_range(0.2, 0.7)
	var ty := rng.randi_range(0, 2)
	if late_until > 0.0:
		if game_time - late_cross_time >= _bot_offset:
			_swing_input(dir, pk, ty)
	elif _bot_offset <= 0.0 and pending_swing.is_empty() and t_contact <= -_bot_offset:
		_swing_input(dir, pk, ty)


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
	print("serve outcomes: %s" % str(_stats["serve"]))
