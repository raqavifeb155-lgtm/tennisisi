extends Node3D
## Game orchestration: rally rules, serve, scoring, player hitting, slow motion,
## feedback, and a bot for automated testing (--autoplay).
##
## Controls (one finger is enough):
##   tap    -> run to that spot (hold the finger to keep running toward it)
##   swipe  -> hit: the ball travels along the swiped line *from the player*;
##             swipe speed = power; depth is chosen automatically (deep, safely in);
##             the swipe's shape picks the stroke: up straight = flat, up and a turn
##             of the wrist = topspin, down = slice, short down = drop (see ShotGesture)
##   net    -> balls taken before the bounce are volleys; high balls are smashed
##   timing -> a ring shrinks onto the contact point: swipe when it meets the circle
##   serve  -> tap = toss, swipe = serve (the ring sits on the tossed ball)
## A perfect shot along a line that points into the court lands in; timing and
## position errors are what make balls miss.

enum Who { NONE = -1, PLAYER = 0, CPU = 1 }
enum Phase { WAIT, SERVE, RALLY, OVER, IDLE, BONUS }  # IDLE: menus open; BONUS: trophy mini-game
enum ShotType { TOPSPIN, FLAT, SLICE, DROP, LOB }

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
var run_hub: RunHub
var mods_hub: ModsHub             # v0.2 G: modifiers of the match (scripts/mods)
var club: Club                    # v0.2 B: the club as the main screen (scripts/club)
var tournament: Tournament
var tournament_mode := false
var autoplay_tournament := false
var cpu_label := "CPU"
var cpu_call := "CPU"            # the same in Latin, for the court calls (Calls, UI_FLOW_TZ 5.6)
var _match_over := false
var _match_stats := {}
var _after_perks := ""            # screen to open once the pending skill perk choices are made
var _perk_choice := {}
var _practice_skill := 0.5
var _autoplay_format := 0
var _bot_dive_test := false
var _bot_sd := 0.035
var _bot_xp := -1.0
var _bot_measure := 0        # v0.2 G: --measure=N: the bot plays N points against the same opponent (--stage, --seed) and reports its share
var _bot_stage := 1
var _bot_seed := 0
var _bot_pts := [0, 0]
var _cpu_serve_mult := 1.0        # difficulty modifier "Бомбардир"
var _run_dist := 0.0              # metres run this rally (experience for "Ноги")
var shot_type := ShotType.TOPSPIN
var _curl_k := 1.0              # topspin strength from the last swipe's turn of the wrist (ShotGesture)
var trail: BallTrail

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
const TRAIL_TOPSPIN := Color(1.0, 0.55, 0.15)
const TRAIL_SLICE := Color(0.45, 0.8, 1.0)
const TRAIL_FLAT := Color(1.0, 1.0, 1.0)
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
var court: Court
var scenery: Scenery
var location_id := "park"
var _next_location := "park"      # chosen on the location screen (and used for practice)
var _mark_tick := 0
var _step_dist := [0.0, 0.0]       # metres run since the last footprint, per player
var _step_side := [1.0, 1.0]       # which foot comes down next
var _mark_reach := Vector2(BallPhysics.RADIUS, BallPhysics.RADIUS)  # the last bounce's mark (Court.mark_reach)

# Trophy mini-game (after beating an opponent who carries a rare racket): the net sinks,
# the opponent runs around their half, and the player has a few serves to hit them.
const BONUS_BALLS := 5
var _bonus_balls := 0
var _bonus_state := 0             # 0 waiting / toss, 1 ball in flight, 2 decided
var _bonus_t := 0.0
var _bonus_wait := 0.0
var _bonus_bounces := 0
var _bonus_success := false
var _bonus_score := ""            # the match score, for the result screen afterwards
var _bonus_rounds := 0            # --bonus-test: rounds left / hits
var _bonus_hits := 0
var _runner_goal := Vector3.ZERO
var _runner_timer := 0.0
var _drop: Node3D                 # the racket knocked out of the runner's hand
var _drop_from := Vector3.ZERO
var _drop_to := Vector3.ZERO
var _drop_t := 0.0

func _ready() -> void:
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		elif a.begins_with("--bonus-test"):
			_bonus_rounds = int(a.get_slice("=", 1)) if "=" in a else 8
		elif a == "--dive-test":
			_bot_dive_test = true  # the bot stands still and swings early: far balls get dived for
		elif a == "--tournament":
			autoplay_tournament = true
		elif a.begins_with("--location="):
			_next_location = a.get_slice("=", 1)
		elif a.begins_with("--format="):
			_autoplay_format = int(a.get_slice("=", 1))
		elif a.begins_with("--points="):
			autoplay_points = int(a.get_slice("=", 1))
		elif a.begins_with("--gfx="):
			_force_gfx = int(a.get_slice("=", 1))  # profiling: 1 low .. 4 max
		elif a.begins_with("--profile"):
			_profile_t = 5.0  # print frame statistics every 5 s (a profiling run, not headless)
		elif a.begins_with("--bot-sd="):
			_bot_sd = float(a.get_slice("=", 1))  # bot timing error (s): ~0.035 sharp, ~0.07 a thumb on a phone
		elif a.begins_with("--measure="):
			_bot_measure = int(a.get_slice("=", 1))
		elif a.begins_with("--stage="):
			_bot_stage = int(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			_bot_seed = int(a.get_slice("=", 1))
		elif a.begins_with("--xp="):
			_bot_xp = float(a.get_slice("=", 1))  # every skill starts with this much experience

	_build_environment()
	court = Court.new()
	add_child(court)

	ball = Ball.new()
	add_child(ball)
	ball.bounced.connect(_on_bounce)
	ball.hit_net.connect(_on_net)
	trail = BallTrail.new()
	trail.ball = ball
	add_child(trail)

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
	hud.show_board(scoreboard, ["ВЫ", cpu_label])
	hud.menu_requested.connect(_show_menu)

	ui = TournamentUI.new()
	add_child(ui)
	ui.chosen.connect(_on_ui)
	run_hub = RunHub.new()  # v0.2 A: style, gear effects, opponent stamina, bets (scripts/run)
	add_child(run_hub)
	run_hub.setup(self)
	mods_hub = ModsHub.new()  # v0.2 G: auras, the run's conditions (after RunHub: its match comes first)
	add_child(mods_hub)
	mods_hub.setup(self)
	club = Club.new()  # v0.2 B: the walkable club replaces the menu list (scripts/club)
	add_child(club)
	club.setup(self)
	# UI sounds: a dropped-in coin/reward/click sound if there is one, else a built-in.
	ui.sfx_request.connect(func(sound: String, db: float, pitch: float) -> void:
		var alt: String = {"bounce": "coin", "hit": "click"}.get(sound, "")
		if alt != "" and sfx.has(alt):
			sfx.play(alt, db + 6.0, 1.0)
		else:
			sfx.play(sound, db, pitch))
	hud.touch.blocked_controls.append(ui.root)

	_build_helpers()
	SaveData.enabled = not autoplay and not _headless()  # test runs never touch the save
	SaveData.load_once()
	if SaveData.control_chosen:
		Tuning.tap_controls = SaveData.tap_controls
	Tuning.one_handed_bh = SaveData.one_handed_bh
	player.set_look(SaveData.look)
	Tuning.ambience = SaveData.ambience
	Tuning.music = SaveData.music
	Tuning.graphics = SaveData.graphics
	for k in SaveData.gfx:
		Tuning.set(k, SaveData.gfx[k])
	if _force_gfx >= 0:
		Tuning.graphics = _force_gfx
	graphics.set_preset(Tuning.graphics)
	_practice_skill = Tuning.ai_skill
	if not autoplay and not _headless():
		sfx.set_ambience(Tuning.ambience)
		sfx.set_music_enabled(Tuning.music)
		Tuning.changed.connect(func() -> void:
			sfx.set_ambience(Tuning.ambience)
			sfx.set_music_enabled(Tuning.music)
			graphics.set_preset(Tuning.graphics))
		Tuning.changed.connect(func() -> void:
			var gfx := {"show_fps": Tuning.show_fps}
			if Tuning.graphics == GraphicsQuality.CUSTOM:
				for k in ["gfx_res", "gfx_aa", "gfx_shadows", "gfx_reach", "gfx_details"]:
					gfx[k] = Tuning.get(k)
			var now := [Tuning.tap_controls, Tuning.one_handed_bh, Tuning.ambience, Tuning.music, Tuning.graphics, gfx]
			if now != [SaveData.tap_controls, SaveData.one_handed_bh, SaveData.ambience, SaveData.music, SaveData.graphics, SaveData.gfx]:
				SaveData.gfx = gfx
				SaveData.tap_controls = Tuning.tap_controls
				SaveData.one_handed_bh = Tuning.one_handed_bh
				SaveData.ambience = Tuning.ambience
				SaveData.music = Tuning.music
				SaveData.graphics = Tuning.graphics
				SaveData.save())
	_last_real_us = Time.get_ticks_usec()
	perf = PerfMeter.new()
	add_child(perf)
	if _bonus_rounds > 0:
		# Test: the trophy mini-game over and over, the bot aiming at the runner.
		tournament = Tournament.new(0, 1)
		tournament_mode = true
		_start_bonus()
	elif autoplay_tournament:
		Skills.reset()  # the bot always starts as a beginner, spending its starting points
		for id in ["forehand", "backhand", "serve"]:
			Skills.spend_point(id)
		if _bot_xp >= 0.0:
			for id in Skills.LIST:
				Skills.add_xp(id, _bot_xp)  # --xp: a player some tournaments in
			Skills.pending = []
		_start_tournament(_autoplay_format)
	elif autoplay or _headless():
		_start_practice()
	else:
		_show_menu()
		# The menu and the scene render under the loading screen while shaders
		# compile: the first rally plays without hitches.
		add_child(BootLoader.new())


func _build_environment() -> void:
	TelegramApp.init()
	scenery = Scenery.new()
	add_child(scenery)
	_trim_shadows.call_deferred(scenery)
	graphics = GraphicsQuality.new()
	graphics.scenery = scenery
	add_child(graphics)


## Far scenery (city, trees, stands beyond the court's surroundings) casts no shadow:
## its shadow pass doubled the draw calls (+180) and triangles (+80k) in a match, a big
## share of a phone's frame in WebGL, while those shadows mostly fall outside the
## camera's view. Players, net, fences and near props keep theirs.
const SHADOW_KEEP_RADIUS := 22.0


func _trim_shadows(root_node: Node) -> void:
	if not is_instance_valid(root_node):
		return
	for n in root_node.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var box := g.global_transform * g.get_aabb()
		var c := box.get_center()
		if Vector2(c.x, c.z).length() > SHADOW_KEEP_RADIUS or box.size.y > 25.0:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Then fold the static little boxes into one mesh per material (draw calls).
	# Everything the scenery keeps a reference to (birds, boats, clouds, nodes it hides on
	# Low) may move or change later: those stay as they are.
	var keep: Array = []
	for prop in root_node.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = root_node.get(prop["name"])
		if v is Node3D:
			keep.append(v)
		elif v is Array:
			for e in v:
				if e is Node3D:
					keep.append(e)
	var folded := MeshMerge.merge_static(root_node as Node3D, keep)
	if autoplay or _profile_t > 0.0:
		print("scenery: folded %d static meshes" % folded)


## Slides and falls leave marks on clay.
func _leave_marks() -> void:
	if court.surface != "clay":
		return
	_mark_tick += 1
	var dt := get_physics_process_delta_time()
	for i in 2:
		var ath: Athlete = player if i == 0 else cpu
		# Footprints every stride while running, left and right of the line of travel.
		var speed := ath.velocity.length()
		if speed > 1.2 and not ath.is_down():
			_step_dist[i] += speed * dt
			if _step_dist[i] > 0.8:
				_step_dist[i] = 0.0
				_step_side[i] = -_step_side[i]
				var aside: Vector3 = ath.velocity.normalized().cross(Vector3.UP) * (0.12 * float(_step_side[i]))
				court.add_step(ath.global_position + aside, ath.velocity)
		if ath.take_landing():
			court.add_mark(ath.global_position + ath.velocity.normalized() * 0.8, ath.velocity, 1.3, 0.45)
		if ath.is_sliding() and _mark_tick % 3 == 0:
			court.add_mark(ath.global_position, ath.velocity, 0.32, 0.14)


## Moves the game to a location: its scenery, court surface and ball physics.
func set_location(id: String) -> void:
	var loc := Locations.find(id)
	if id == location_id and scenery != null:
		return
	location_id = loc["id"]
	var next: Scenery = null
	if ResourceLoader.exists(loc["scenery"]):
		var scr := load(loc["scenery"]) as GDScript
		if scr != null and scr.can_instantiate():
			next = scr.new() as Scenery
	if next == null:
		next = Scenery.new()  # the location's own scenery isn't there: keep the park look
	if scenery:
		scenery.queue_free()
	scenery = next
	add_child(scenery)
	_trim_shadows.call_deferred(scenery)
	graphics.scenery = scenery
	graphics.refresh()
	court.set_surface(loc["surface"])
	Athlete.surface = loc["surface"]
	sfx.set_location(loc.get("sound", location_id))


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
	if club.active:
		return  # the club walks the hero itself
	game_time += delta
	match phase:
		Phase.WAIT:
			phase_timer -= delta
			if phase_timer <= 0.0:
				_setup_serve()
		Phase.SERVE:
			_update_serve(delta)
		Phase.BONUS:
			_update_bonus(delta)
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
	_update_stamina(delta)
	_leave_marks()
	if phase == Phase.RALLY and ball.state.rolling:
		_end_point(last_hitter, "WINNER")
	_update_player_hitting()
	if phase == Phase.BONUS:
		pass  # the runner is steered by _update_bonus
	elif phase == Phase.SERVE:
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
	hud.set_in_match(phase != Phase.IDLE)
	if _profile_t > 0.0:
		_profile_t -= rd
		if _profile_t <= 0.0:
			_profile_t = 5.0
			print("PERF %s %s" % ["match" if phase != Phase.IDLE else "menu", str(perf.take())])
	_update_slowmo(rd)
	_update_helpers()
	_update_safe_area(rd)
	_update_persistence(rd)
	if club.active:
		return
	sfx.rally = phase == Phase.RALLY or phase == Phase.SERVE
	player.stance_style = 1 if phase == Phase.SERVE and server == Who.CPU else 0
	cpu.stance_style = 1 if phase == Phase.SERVE and server == Who.PLAYER else 0
	var before_toss := phase == Phase.SERVE and server == Who.PLAYER and not toss_active and not autoplay
	hud.show_serve_hint(before_toss and _own_serves < SERVE_HINTS, Tuning.tap_controls)
	hud.touch.shot_window = phase == Phase.RALLY and _player_can_hit() and t_contact < 0.7
	_update_timing_ring()
	var look := ball.state.pos if ball.visible else Vector3.INF
	player.look_target = look
	cpu.look_target = look
	if phase == Phase.IDLE:
		hud.set_rally("")
	else:
		# Match point, break point and the tiebreak are on the score bug now.
		hud.set_rally("розыгрыш · %d" % rally if rally >= 2 else "")
	if Tuning.show_debug_text:
		hud.set_debug_text(_debug_string())
	else:
		hud.set_debug_text("")


# --- Player -------------------------------------------------------------------

func _player_can_hit() -> bool:
	return phase == Phase.RALLY and last_hitter == Who.CPU and ball.active and not ball_used and (not player.is_down() or player.is_diving())


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

	# Out of reach but within a dive, with a swing on the way: throw the body at it.
	if not pending_swing.is_empty() and not player.is_down() and t_contact < Athlete.DIVE_TIME * 0.8 and contact_pred.y < 1.7:
		var reach_d := Vector2(contact_pred.x - player.position.x, contact_pred.z - player.position.z).length()
		if reach_d > Athlete.REACH and reach_d < Athlete.REACH + Athlete.DIVE_REACH:
			player.dive(contact_pred)
			_spend_stamina(STAMINA_DIVE)
			_stats["dives"] = _stats.get("dives", 0) + 1

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
	if flat_d > Athlete.REACH + 0.6 + (Athlete.DIVE_REACH if player.is_diving() else 0.0):
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
	if club.active:
		return
	if phase == Phase.BONUS:
		if _bonus_state == 0 and not toss_active:
			_start_toss()
		return
	if phase == Phase.SERVE and server == Who.PLAYER:
		# Tap controls: anything below the server's head (the player, the strip behind
		# the baseline, the bottom of the screen) is a step sideways; the court above
		# is the toss.
		if Tuning.tap_controls and not toss_active and _is_serve_step_zone(pos):
			_set_serve_step(pos)
			return
		if not toss_active:
			_start_toss()
		return
	if Tuning.tap_controls:
		_set_move_target(pos)


func _on_hold(pos: Vector2) -> void:
	if club.active:
		return
	if phase == Phase.SERVE and server == Who.PLAYER:
		if Tuning.tap_controls and not toss_active and _is_serve_step_zone(pos):
			_set_serve_step(pos)  # the finger held low: the server follows it along the line
		return
	if Tuning.tap_controls:
		_set_move_target(pos)


## Before the serve, the screen is split at the server's head: below it is for
## stepping sideways, above it (the court) is the toss. A tap on the player himself
## is a step, never an accidental toss.
func _is_serve_step_zone(screen_pos: Vector2) -> bool:
	var head := cam.unproject_position(player.position + Vector3.UP * 1.9)
	return screen_pos.y > head.y


## Walks the server along the baseline to the finger's side position.
func _set_serve_step(screen_pos: Vector2) -> void:
	var g := _screen_to_ground(screen_pos)
	var x := player.position.x
	if g != Vector3.INF:
		x = g.x
	else:  # (cannot happen below the head, but keep the old place if it does)
		return
	var a := player.area
	_move_target = Vector3(clampf(x, a.position.x, a.end.x), 0.0, player.position.z)
	_assist_suppressed = true
	_tap_marker.global_position = Vector3(_move_target.x, 0.05, _move_target.z)
	_tap_marker.visible = true
	_tap_marker_hold = 0.6


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
	if mods_hub.mirror:
		d.x = -d.x  # v0.2 G: «Зеркало»
	if d.z > -0.3:  # always toward the opponent
		d = Vector3(d.x, 0.0, -0.3).normalized() if absf(d.x) > 0.01 else Vector3(0, 0, -1)
	return d


func _pace_from_speed(speed: float) -> float:
	return clampf((speed - 0.8) / 3.2, 0.0, 1.0)


func _read_gesture(points: PackedVector2Array, times: PackedInt32Array) -> ShotGesture.Result:
	return ShotGesture.classify(points, times, get_viewport().get_visible_rect().size.y, Tuning.curl_min, Tuning.curl_turn, Tuning.drop_len, 12.0, 0.6, Tuning.lob_speed)


func _on_swipe(points: PackedVector2Array, times: PackedInt32Array) -> void:
	if club.active:
		return
	var g := _read_gesture(points, times)
	var dir := _swipe_world_dir(g.start, g.apex)
	var pace_k := _pace_from_speed(g.speed)
	shot_type = g.type as ShotType
	_curl_k = g.curl_k
	if shot_type == ShotType.LOB and (phase == Phase.SERVE or phase == Phase.BONUS):
		shot_type = ShotType.TOPSPIN  # no lob on the serve: a slow scoop up is a kick
	_aim_hold = 0.7
	if phase == Phase.BONUS:
		if toss_active and _bonus_state == 0:
			_bonus_serve(dir, pace_k, shot_type)
		return
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
			hud.popup("EARLY", COLOR_WARN, "свайпни, когда кольцо дойдёт до круга")
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
	var w := Court.half_width() - 0.6
	var zt := -(Court.HALF_LENGTH - lerpf(2.6, 1.5, pace_k))
	var p := origin + d * ((zt - origin.z) / d.z)
	if absf(p.x) > w:
		var ps := origin + d * ((signf(p.x) * w - origin.x) / d.x) if absf(d.x) > 0.001 else p
		# Crosses the sideline deep in the other half: angled shot. Otherwise: into the deep corner.
		p = ps if ps.z <= -5.0 and ps.z >= zt else Vector3(signf(p.x) * w, 0.0, zt)
	p.y = BallPhysics.RADIUS
	return p


## Lob target: along the aim line, deep behind a player at the net. A clean scoop lands
## a couple of metres inside the baseline; a poor one drops short, where it gets smashed.
func lob_target(origin: Vector3, d: Vector3, q: float) -> Vector3:
	var w := Court.half_width() - 0.8
	var depth := Court.HALF_LENGTH - lerpf(5.0, 2.0, q)
	var p := origin + d * ((-depth - origin.z) / d.z)
	p.x = clampf(p.x, -w, w)
	p.z = -depth
	p.y = BallPhysics.RADIUS
	return p


## Drop shot target: along the aim line, just over the net. A clean touch dies close to
## the net; a poor one sits up deeper, where the opponent can punish it.
func drop_target(origin: Vector3, d: Vector3, pace_k: float, q: float) -> Vector3:
	var w := Court.half_width() - 0.6
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
	var hi := Court.half_width() - 0.2
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
	if club.active:
		return
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
	return [Athlete.Style.TOPSPIN, Athlete.Style.FLAT, Athlete.Style.SLICE, Athlete.Style.DROP, Athlete.Style.TOPSPIN][type]


func _player_hit(err: float, dir: Vector3, pace_k: float, type: int) -> void:
	var bp := ball.state.pos
	pending_swing = {}
	late_until = -1.0
	var lateral := player.lateral_of(bp)
	var flat_d := Vector2(bp.x - player.position.x, bp.z - player.position.z).length()
	var diving := player.is_diving()
	if flat_d > Athlete.REACH + (Athlete.DIVE_REACH if diving else 0.0):
		_miss("TOO FAR")
		return
	var incoming_speed := ball.state.vel.length()
	var side := 1 if lateral >= 0.0 else -1
	var smash := bp.y > SMASH_MIN_H
	var volley := bounces == 0 and not smash
	var skill := stroke_skill(side, type, smash, volley)
	var sk := Skills.stroke(skill)
	var one_hander := skill == "backhand" and Tuning.one_handed_bh
	if one_hander:
		# One-handed backhand: more punch down the line, a slightly narrower window.
		sk["window"] *= 0.9
		sk["pace"] *= 1.06
	sk["window"] *= lerpf(1.0, 0.7, _tired())
	var tq := timing_quality(err, sk["window"], sk["good"])
	var q_t: float = tq[0]
	var label: String = tq[1]
	var q_p := position_quality(lateral, minf(bp.y, 1.2) if smash else bp.y)
	var q_m := movement_quality(player.velocity.length(), Skills.move_penalty_mult())
	var q := q_t * q_p * q_m
	if diving:
		q *= 0.7  # a dive gets it back, rarely with interest

	var origin := Vector3(bp.x, 0.0, bp.z)
	var drop := type == ShotType.DROP and not smash
	var lob := type == ShotType.LOB and not smash
	var target := drop_target(origin, dir, pace_k, q) if drop else (lob_target(origin, dir, q) if lob else rally_target(origin, dir, pace_k))
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
				# A knifed slice: not slow, backspin that keeps it low over the net and
				# skidding after the bounce (it used to float, too slow for the spin).
				pace = lerpf(20.0, 29.0, pace_k)
				top = -lerpf(150.0, 230.0, pace_k)
			ShotType.DROP:
				# Soft hands, heavy backspin: just over the net and it dies.
				pace = 9.0
				top = -lerpf(260.0, 320.0, q)
			ShotType.LOB:
				# Scooped up high and deep with a little topspin, over a player at the net.
				# pace caps the launch speed; the lob's arc is fixed by the solver.
				pace = 30.0
				top = lerpf(120.0, 260.0, q)
			_:
				# Heavy topspin (Nadal): fast and with a lot of spin, so the ball clears the
				# net high, dives and kicks up. Slower with this spin it was a half-lob.
				pace = lerpf(26.0, 38.0, pace_k)
				top = lerpf(300.0, 470.0, pace_k) * _curl_k
		if volley and not drop and not lob:
			# Punch volleys: shorter swing, less pace and spin, more control.
			pace *= 0.8
			top *= 0.5
	if not drop and not lob:
		pace *= sk["pace"] * lerpf(1.0, 0.85, _tired())
	top *= sk["spin"]
	_spend_stroke(pace_k)

	if not player.is_swinging():
		player.swing(side, 0.02, bp, _swing_style(type, bp.y))
	player.update_contact(bp)
	var r := execute_shot(Who.PLAYER, player, bp, target, pace, top, q, err, side, lob, 0.0, drop, 0.3, sk["scatter"] * lerpf(1.0, 1.8, _tired()))
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
	if diving:
		notes.append("в прыжке")
	elif q_m < 0.85:
		notes.append("на бегу")
	# A heavy ball taken badly knocks the player off balance for a moment.
	if not diving and not smash and incoming_speed > 28.0 and q < 0.4:
		player.stumble(-float(side))
		GameEvents.knocked.emit(Who.PLAYER)
		notes.append("выбило")
		_stats["stumbles"] = _stats.get("stumbles", 0) + 1
	var stroke: String = "SMASH" if smash else (("VOLLEY " if volley else "") + ShotGesture.NAMES[type])
	var big_curl := type == ShotType.TOPSPIN and not smash and _curl_k >= 1.2
	if type == ShotType.TOPSPIN and not smash:
		stroke += " ×%.1f" % _curl_k
	if big_curl:
		sfx.play("swing", -3.0, 0.8)  # the whip of a full turn of the wrist
	var sub := "%s  ·  %d KM/H  ·  %d%%" % [stroke, roundi(r.speed * 3.6), roundi(q * 100.0)]
	if not notes.is_empty():
		sub += "  ·  " + ", ".join(notes)
	hud.popup(label, color, sub)
	if label == "PERFECT":
		cam.impulse(1.0)
		if Tuning.hitstop and not autoplay:
			_hitstop_until_ms = Time.get_ticks_msec() + 70
	else:
		cam.impulse(0.4 * q)
	_haptic("heavy" if smash or big_curl else ("perfect" if label == "PERFECT" else ("medium" if label == "GOOD" else "light")))

	last_shot = {
		"label": label, "err_ms": err * 1000.0, "q_t": q_t, "q_p": q_p, "q_m": q_m, "q": q,
		"side": "FH" if side > 0 else "BH", "speed": r.speed * 3.6, "elev": r.elevation_deg,
		"target": Vector2(target.x, target.z), "type": stroke,
	}
	GameEvents.player_stroke.emit({
		"type": "SMASH" if smash else ShotGesture.NAMES[type], "label": label, "kmh": r.speed * 3.6, "q": q,
		"curl_k": _curl_k if type == ShotType.TOPSPIN else 1.0, "volley": volley, "smash": smash,
		"diving": diving, "serve": false, "skill": skill, "side": side,
	})


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


## 0 fresh .. 1 exhausted: how much the low stamina bites (nothing above Skills.tired_below()).
func _tired() -> float:
	var below := Skills.tired_below()
	return clampf((below - stamina) / below, 0.0, 1.0)


func _update_stamina(delta: float) -> void:
	if phase != Phase.RALLY:
		return  # the breather between points is given in one go (_setup_serve)
	var top_speed := maxf(Tuning.player_speed * Skills.run_speed_mult(), 0.1)
	var f := clampf(player.velocity.length() / top_speed, 0.0, 1.0)
	# A sprint costs much more than a jog; standing still in a rally gives a little back.
	_spend_stamina(STAMINA_SPRINT * f * f * delta)
	if f < 0.25:
		stamina = minf(stamina + STAMINA_STAND * delta, 1.0)


## Spends stamina at the "Выносливость" rate; what was spent pays that skill's experience
## at the end of the point.
func _spend_stamina(base: float) -> void:
	var before := stamina
	stamina = clampf(stamina - base * Skills.stamina_drain(), 0.0, 1.0)
	_stamina_spent += before - stamina


## A hard stroke takes a little out of the legs.
func _spend_stroke(pace_k: float) -> void:
	_spend_stamina(STAMINA_STROKE + STAMINA_PACE * pace_k)


func _update_player_movement() -> void:
	if phase == Phase.BONUS and _bonus_state == 3:
		return  # running to pick up the trophy (steered by _bonus_pickup)
	var legs := lerpf(1.0, 0.7, _tired())
	if stamina <= 0.001:
		legs = minf(legs, 0.6)  # empty: a jog at best
	player.max_speed = Tuning.player_speed * Skills.run_speed_mult() * legs
	player.one_handed_backhand = Tuning.one_handed_bh
	player.tired = phase != Phase.RALLY and phase != Phase.IDLE and phase != Phase.BONUS and stamina < Skills.tired_below()
	var serving := (phase == Phase.SERVE and server == Who.PLAYER) or phase == Phase.BONUS
	if serving:
		player.max_speed *= 0.4  # placing for the serve is a calm sideways walk
	if serving and (toss_active or autoplay):
		player.move_input = Vector2.ZERO
		return
	var mv := hud.touch.move_vector
	if mods_hub.mirror:
		mv.x = -mv.x  # v0.2 G: «Зеркало»
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
		assist = 0.25 if _bot_dive_test else 1.0
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
## `window_scale` / `good_scale` widen or narrow the PERFECT and GOOD windows (the
## player's skill level; the GOOD one defaults to the same scale).
func timing_quality(err: float, window_scale := 1.0, good_scale := -1.0) -> Array:
	var a := absf(err)
	var pw := Tuning.perfect_window * window_scale
	var gw := maxf(Tuning.good_window * (window_scale if good_scale < 0.0 else good_scale), pw + 0.005)
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
## Chance that a rally shot is simply missed (net, long or wide): a little even on an
## easy ball, much more under a heavy ball or with a poor contact. Stronger players
## (CPU skill, the player's levels) miss less. PERFECT contact almost never misses.
func error_chance(who: int, q: float, incoming_speed: float) -> float:
	var pressure := clampf((incoming_speed - 16.0) / 22.0, 0.0, 1.0)
	var steady: float
	if who == Who.CPU:
		steady = Tuning.ai_skill
	else:
		steady = clampf(float(Skills.total_level()) / (Skills.LIST.size() * Skills.MAX_LEVEL), 0.0, 1.0) * 0.8 + 0.2
	var base := lerpf(0.09, 0.02, steady)
	var forced := pressure * (1.0 - q) * lerpf(0.6, 0.35, steady)
	var poor := pow(1.0 - q, 2.0) * 0.35
	var p := base * (1.0 - q * 0.7) + forced + poor
	if who == Who.CPU:
		p *= 0.8  # the AI's contact model is harsher than a thumb's: keep it from spraying
	return clampf(p, 0.0, 0.6)


func execute_shot(who: int, hitter: Athlete, contact: Vector3, target: Vector3, pace: float, top: float, q: float, t_err: float, side: int, lob := false, side_spin := 0.0, drop := false, net_margin := 0.3, scatter := 1.0) -> ShotSolver.Result:
	trail.set_color(TRAIL_TOPSPIN if top >= 200.0 else (TRAIL_SLICE if top < 0.0 else TRAIL_FLAT), who == Who.PLAYER and q >= 0.9)
	# An unforced or forced error: decided before the shot, shown as a real miss.
	var incoming := ball.state.vel.length()
	var err_kind := 0  # 0 none, 1 net, 2 long, 3 wide
	if incoming > 3.0 and rng.randf() < error_chance(who, q, incoming):
		var roll := rng.randf()
		err_kind = 1 if roll < 0.4 else (2 if roll < 0.75 else 3)
		_stats["errors"] = _stats.get("errors", 0) + 1
	var half := -signf(contact.z) if absf(contact.z) > 0.1 else -1.0  # the half the ball goes to
	if err_kind == 2:
		# Long: lands past the baseline.
		target.z = half * (Court.HALF_LENGTH + rng.randf_range(0.25, 1.5))
	elif err_kind == 3:
		# Wide: lands past the sideline on the side it was going to.
		var sx := signf(target.x) if absf(target.x) > 0.3 else (1.0 if rng.randf() < 0.5 else -1.0)
		target.x = sx * (Court.half_width() + rng.randf_range(0.2, 1.1))
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
	if err_kind == 1 and absf(v.z) > 1.0:
		# Into the net: launched so it reaches the net plane below the tape.
		var t_net := absf(contact.z) / absf(v.z)
		var h_net := Court.net_height(contact.x + v.x * t_net) * rng.randf_range(0.35, 0.8)
		v.y = (h_net - contact.y + 0.5 * BallPhysics.gravity() * t_net * t_net) / t_net
	ball.launch(contact, v, r.spin)
	last_hitter = who as Who
	bounces = 0
	net_touched = false
	if who == Who.CPU:
		ball_used = false
		_assist_suppressed = false
		_stats["cpu_hits"] += 1
	rally += 1
	GameEvents.shot.emit(who, {"contact": contact, "speed": r.speed, "top": top, "q": q, "lob": lob, "drop": drop})
	var vol := lerpf(-9.0, 0.0, clampf(r.speed / 35.0, 0.0, 1.0))
	sfx.play("hit_perfect" if q > 0.9 else "hit", vol, rng.randf_range(0.96, 1.04) * lerpf(0.92, 1.06, q))
	return r


# --- Rules --------------------------------------------------------------------

func _on_bounce(pos: Vector3, speed: float) -> void:
	GameEvents.bounce.emit({"pos": pos, "speed": speed, "bounces": bounces, "last_hitter": last_hitter})
	sfx.play("bounce", lerpf(-22.0, -6.0, clampf(speed / 30.0, 0.0, 1.0)), rng.randf_range(0.9, 1.1))
	if phase == Phase.BONUS:
		_bonus_bounces += 1
	# Clay keeps the ball's mark: round from a ball coming down steeply, a long oval from
	# a fast flat one. The line call reads the same mark (it touches the line = in).
	var mark := Court.mark_size(ball.impact_vel)
	court.add_mark(pos, ball.impact_vel, mark.x, mark.y)
	_mark_reach = Court.mark_reach(ball.impact_vel)
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
		if Court.in_service_box_mark(pos, receiver_half, box_side, _mark_reach):
			_close_call = {}  # a good serve: the call only matters if it decides something
		if not Court.in_service_box_mark(pos, receiver_half, box_side, _mark_reach):
			_fault("NET" if net_touched else "FAULT")
		elif net_touched:
			_let()
		return
	if bounces == 1:
		if not Court.is_in_singles_mark(pos, receiver_half, _mark_reach):
			_end_point(_other(last_hitter), "NET" if net_touched else "OUT")
	else:
		_end_point(last_hitter, "WINNER")


## Hawk-Eye: distance from the ball mark to the nearest line that decides the call
## (positive = in). Close calls get the top-down replay panel.
func _line_call(pos: Vector3, half: int) -> void:
	# The mark's reach from its centre: sideways for the side and centre lines, along the
	# court for the baseline and the service line (see Court.mark_reach).
	var rx := _mark_reach.x
	var rz := _mark_reach.y
	var margin: float
	var line_axis := 0  # 0 = the deciding line runs along z (a sideline), 1 = along x
	var z := pos.z * half
	if serve_flight:
		var x := pos.x * box_side
		var m_service := Court.SERVICE_LINE + rz - z
		var m_center := x + rx
		var m_side := Court.half_width() + rx - x
		margin = minf(m_service, minf(m_center, m_side))
		line_axis = 1 if margin == m_service else 0
	else:
		var m_side := Court.half_width() + rx - absf(pos.x)
		var m_base := Court.HALF_LENGTH + rz - z
		margin = minf(m_side, m_base)
		line_axis = 1 if m_base < m_side else 0
	if z < 0.0:
		return  # landed on the wrong half: not a line call
	# The mark for the replay: half-length, half-width and how square the flight met the
	# deciding line (|cos| of the angle to its normal), so VAR draws the very same oval.
	var size := Court.mark_size(ball.impact_vel) * 0.5
	var flight := Vector2(ball.impact_vel.x, ball.impact_vel.z)
	flight = flight.normalized() if flight.length() > 0.001 else Vector2(0, 1)
	var square := absf(flight.y) if line_axis == 1 else absf(flight.x)
	# Remembered with the shot it belongs to: shown only if that bounce decided the point.
	_close_call = {"margin": margin, "axis": line_axis, "rally": rally, "mark": Vector3(size.x, size.y, square)} if absf(margin) <= Tuning.hawkeye_range else {}


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
	GameEvents.point.emit({"winner": winner, "reason": reason, "rally": rally, "server": server, "close_call": _close_call.duplicate(), "best": rally >= best_rally})
	var text := Calls.point(winner == Who.PLAYER, reason, cpu_call)
	if winner == Who.PLAYER and reason == "ACE":
		_match_stats["aces"] = _match_stats.get("aces", 0) + 1
	_match_stats["best_rally"] = maxi(_match_stats.get("best_rally", 0), rally)
	if _run_dist > 0.0:
		_gain_xp("feet", "", _run_dist * Skills.RUN_XP_PER_M)
		_run_dist = 0.0
	if _stamina_spent > 0.0:
		_gain_xp("stamina", "", _stamina_spent * Skills.STAMINA_XP)
		_stamina_spent = 0.0
	var ev: int = scoreboard.add_point(winner)
	match scoreboard.break_after(ev):
		MatchScore.Break.CHANGE_ENDS:
			var rest := Skills.stamina_rest("change")
			stamina = minf(stamina + (rest if not scoreboard.in_tiebreak else rest * 0.5), 1.0)
		MatchScore.Break.SET_BREAK:
			stamina = minf(stamina + Skills.stamina_rest("set"), 1.0)
	if ev != MatchScore.Event.POINT and not autoplay:
		SaveData.save()  # the skills grown this game survive a crash or a reload
	var line2 := Calls.score(ev, winner == Who.PLAYER, cpu_call)
	if line2 != "":
		text += "\n" + line2
	server = scoreboard.server as Who
	if tournament_mode and scoreboard.is_over():
		_match_over = true
		phase_timer = 0.4 if autoplay else 2.4
	hud.show_message(text, COLOR_WIN if winner == Who.PLAYER else COLOR_BAD)
	var close_call := not _close_call.is_empty() and int(_close_call.get("rally", -1)) == rally
	if close_call and reason != "NET":
		hud.hawkeye(_close_call["margin"], _close_call["axis"], _close_call.get("mark", Vector3.ZERO))
	_close_call = {}
	sfx.play("point" if winner == Who.PLAYER else "miss", -8.0 if winner == Who.PLAYER else -10.0)
	# The stands: applause for a good point, an "ooh" for a close call.
	if not autoplay:
		if close_call:
			sfx.crowd("crowd_ooh", -6.0)
		elif winner == Who.PLAYER and (rally >= 6 or reason == "ACE" or reason == "WINNER"):
			sfx.crowd("applause", -8.0 + minf(rally, 12.0) * 0.4)
	hud.show_board(scoreboard, ["ВЫ", cpu_label])

	_stats["rallies"].append(rally)
	var srv_key := ("YOU" if server == Who.PLAYER else "CPU") + " serve: "
	var outcome := "ace" if reason == "ACE" else ("double fault" if reason == "DOUBLE FAULT" else ("unreturned" if rally == 1 and winner == server else ("return error" if rally == 2 and winner == server else "rally")))
	_stats["serve"][srv_key + outcome] = _stats["serve"].get(srv_key + outcome, 0) + 1
	var key := ("YOU " if winner == Who.PLAYER else "CPU ") + "wins: " + text.split("\n")[0]
	_stats["reasons"][key] = _stats["reasons"].get(key, 0) + 1
	if autoplay and autoplay_tournament and _bot_measure > 0:
		_bot_pts[winner] += 1
		if _bot_pts[0] + _bot_pts[1] >= _bot_measure:
			print("BOTPTS you=%d cpu=%d share=%.3f" % [_bot_pts[0], _bot_pts[1], float(_bot_pts[0]) / float(_bot_measure)])
			get_tree().quit()
	if autoplay and not autoplay_tournament:
		print("point %d: %s (rally %d) -> %s %s  stamina %d%%" % [_points_played, key, rally, scoreboard.point_text(), scoreboard.games_text(), roundi(stamina * 100.0)])
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
		hud.show_message(Calls.fault(kind), COLOR_WARN)
		if not _close_call.is_empty() and kind != "NET" and int(_close_call.get("rally", -1)) == rally:
			hud.hawkeye(_close_call["margin"], _close_call["axis"], _close_call.get("mark", Vector3.ZERO))
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
	hud.show_message(Calls.LET, COLOR_GOOD)


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
	srv.dribble = u if cycle % 4 != 3 else -1.0
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
	stamina = minf(stamina + Skills.stamina_rest("point"), 1.0)  # the breather between points
	sfx.settle_crowd()  # the stands quieten as the server gets ready
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
	srv.recover()
	rcv.recover()
	srv.relax()
	rcv.relax()
	srv.serve_ready()
	if server == Who.PLAYER:
		# Rules: behind the baseline, between the centre mark and the sideline on this side.
		var x0 := 0.15 if sx > 0.0 else -Court.half_width()
		player.area = Rect2(x0, Court.HALF_LENGTH + 0.08, Court.half_width() - 0.15, 1.6)
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


const SERVE_HINTS := 5          # the serve hint shows for this many of the player's serves
var _own_serves := 0


func _start_toss() -> void:
	if server == Who.PLAYER:
		_own_serves += 1
	var srv := _server_athlete()
	srv.dribble = -1.0
	var hand := _ball_in_hand(srv)
	ball.launch(hand, Vector3(0.0, TOSS_SPEED, 0.0), Vector3.ZERO)
	toss_active = true
	var g := BallPhysics.gravity()  # v0.2 G: «Лунная гравитация» slows the toss too
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
	var tq := timing_quality(err, sk["window"], sk["good"])
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
			top = lerpf(300.0, 420.0, pace_k) * _curl_k  # kick: dives in, jumps up high
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
	var kind: String = ["KICK ×%.1f" % _curl_k, "FLAT", "SLICE"][type]
	hud.popup(label, color, "SERVE %s  ·  %d KM/H" % [kind, roundi(r.speed * 3.6)])
	cam.impulse(1.0 if label == "PERFECT" else 0.4)
	_haptic("perfect" if label == "PERFECT" else "medium")
	last_shot = {
		"label": label, "err_ms": err * 1000.0, "q_t": q, "q_p": 1.0, "q_m": 1.0, "q": q,
		"side": "SRV", "speed": r.speed * 3.6, "elev": r.elevation_deg,
		"target": Vector2(target.x, target.z), "type": ["KICK", "FLAT", "SLICE"][type],
	}
	GameEvents.player_stroke.emit({
		"type": "SERVE", "label": label, "kmh": r.speed * 3.6, "q": q, "curl_k": _curl_k if type == ShotType.TOPSPIN else 1.0,
		"volley": false, "smash": false, "diving": false, "serve": true, "skill": "serve", "side": 1,
	})


## Underarm drop serve (Bublik / Kyrgios): no toss, the ball is struck from the hand
## low and soft, landing just over the net. Deadly when the receiver stands deep.
## The hook drawn before the toss (the drop-shot gesture): a soft underarm serve.
func _player_underarm_serve(dir: Vector3, pace_k: float) -> void:
	_own_serves += 1
	var contact := player.position + player.right() * 0.55 + player.forward() * 0.45 + Vector3.UP * 0.75
	var origin := Vector3(contact.x, 0.0, contact.z)
	var depth := lerpf(1.4, 2.6, pace_k)
	var target := origin + dir * ((-depth - origin.z) / dir.z)
	var lo := 0.4
	var hi := Court.half_width() - 0.4
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
	hud.popup("UNDERARM", COLOR_GOOD, "UNDERARM SERVE  ·  %d KM/H" % roundi(r.speed * 3.6))
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
		pace = lerpf(32.0, 46.0, s) * rng.randf_range(0.9, 1.05) * _cpu_serve_mult
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
	if type == ShotType.SLICE or type == ShotType.DROP or type == ShotType.LOB:
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
	if skill != "feet" and skill != "stamina":
		var pr := Skills.progress(skill)
		hud.ring.skill_progress(String(Skills.NAMES[skill]).to_upper(), Skills.level(skill), pr.x / maxf(pr.y, 1.0))
	if lv > 0:
		# The step shown as a number: "ФОРХЕНД 7 · 104 → 109 км/ч".
		var was := Skills.headline(skill, lv - 1)
		var now := Skills.headline(skill, lv)
		var unit := now.get_slice(" ", 1) if now.ends_with("км/ч") else ""
		var step := ("%s → %s" % [was.get_slice(" ", 0), now]) if unit != "" else ("%s → %s" % [was, now.get_slice(" ", now.get_slice_count(" ") - 1)])
		hud.level_up("%s %d  ·  %s" % [String(Skills.NAMES[skill]).to_upper(), lv, step], lv % Skills.PERK_EVERY == 0)
		if autoplay:
			print("  LEVEL UP %s %d: %s" % [skill, lv, step])
		_haptic("perfect")
		cam.impulse(0.6)
		SaveData.save()


func _show_menu() -> void:
	sfx.set_music(true)
	tournament = null
	tournament_mode = false
	_stop_match()
	_set_opponent_mods(1.0, 1.0, {})
	Rewards.restore()
	Tuning.ai_skill = _practice_skill
	cpu_label = "CPU"
	cpu_call = "CPU"
	_next_screen("menu")


func _stop_match() -> void:
	if not BallPhysics.net_enabled:
		court.set_net_up(true)
	cpu.recover()
	_match_over = false
	_replay_serve = false
	phase = Phase.IDLE
	ball.park()
	pending_swing = {}
	late_until = -1.0
	Engine.time_scale = 1.0
	hud.set_score("")
	hud.announcer.set_hint("")


func _start_practice() -> void:
	tournament = null
	tournament_mode = false
	set_location("club" if club.active else _next_location)  # from the club: its own court
	Rewards.restore()
	cpu.set_look(Looks.from_shirt(Color(0.22, 0.28, 0.42)))
	_set_opponent_mods(1.0, 1.0, {})
	Tuning.ai_skill = _practice_skill
	cpu_label = "CPU"
	cpu_call = "CPU"
	scoreboard = MatchScore.new(1, 99, 0, Who.PLAYER, cpu_label)
	ui.close()
	_begin_match()


func _start_tournament(format_index: int, run_conditions: Array = []) -> void:
	tournament = Tournament.new(format_index, _bot_seed)
	if autoplay and _bot_measure > 0:
		tournament.stage = clampi(_bot_stage, 0, tournament.rounds() - 1)
		tournament.current_lineup()["mods"] = []  # the same opponent every time: only --mods differs
	if not run_conditions.is_empty():
		Modifiers.set_run(tournament, run_conditions)  # v0.2 G: the run's conditions (RunMods screen)
	tournament.location = _next_location
	SaveData.active = tournament
	SaveData.save()
	set_location(_next_location)
	tournament_mode = true
	Rewards.restore()
	if autoplay:
		_play_match()
	else:
		ui.show_bracket(tournament)


## Stamina is a short tank: a beginner sprinting flat out is empty in ~15 s, and a long
## rally takes a third of it. A breather between points gives a little back in one go,
## the real rest comes at the change of ends and between sets (Skills.stamina_rest).
## Every cost below is multiplied by Skills.stamina_drain(): x2 for a beginner, x0.5 at
## the cap of "Выносливость". Below Skills.tired_below() the player is tired.
var stamina := 1.0              # 0..1
var _stamina_spent := 0.0       # this point, for the "Выносливость" experience
const STAMINA_SPRINT := 0.0333  # per second at full sprint during a point (jogging costs far less)
const STAMINA_STROKE := 0.003   # a stroke, plus up to STAMINA_PACE more for a hard one
const STAMINA_PACE := 0.003
const STAMINA_DIVE := 0.03
const STAMINA_STAND := 0.002    # per second back standing still in a rally

var perf: PerfMeter               # frame statistics for the telemetry beat and --profile runs
var _profile_t := -1.0
var _force_gfx := -1
var _cloud_t := 0.0
var _beat_t := 5.0
var _cloud_poll_t := 0.0
var _boot_logged := false
var _alive_t := 0.0


## The Telegram cloud copy of the progress (taken if it has more), and the heartbeat
## that tells a crash from Telegram unloading a minimised game.
func _update_persistence(dt: float) -> void:
	if autoplay or _headless():
		return
	_cloud_t += dt
	_cloud_poll_t -= dt
	if _cloud_t < 20.0 and _cloud_poll_t <= 0.0 and SaveData.poll_cloud():
		Tuning.tap_controls = SaveData.tap_controls
		Tuning.one_handed_bh = SaveData.one_handed_bh
		if phase == Phase.IDLE:
			_show_menu()
	if _cloud_poll_t <= 0.0:
		_cloud_poll_t = 0.5
	if not _boot_logged:
		_boot_logged = true
		TelegramApp.log_event("boot", {"crashes": SaveData.crashes, "last": SaveData.last_crash.left(60),
			"played": SaveData.played, "src": SaveData.source, "gfx": graphics.level_name()})
	_beat_t -= dt
	if _beat_t <= 0.0:
		_beat_t = 20.0
		var beat := {"gfx": graphics.level_name(), "sc": snappedf(graphics.scale_3d, 0.01), "loc": location_id,
			"ph": phase, "pts": _points_played, "tour": tournament_mode, "snd": sfx.plays,
			"ui": ui.is_open(), "pause": get_tree().paused}
		beat.merge(perf.take())  # fps, low, worst, cpu, draws, tris, px: see PerfMeter
		TelegramApp.log_event("beat", beat)
	_alive_t -= dt
	if _alive_t <= 0.0:
		_alive_t = 15.0
		var where := "меню" if phase == Phase.IDLE else ("турнир" if tournament_mode else "тренировка")
		SaveData.mark_alive("%s · %s · %s" % [where, Locations.find(location_id)["name"], graphics.level_name()])


var _safe_t := 0.0
var _safe := Vector2(-1.0, -1.0)


## Telegram's full screen covers the top of the page with its buttons: twice a second
## the safe area is read and the HUD and menus are moved inside it.
func _update_safe_area(dt: float) -> void:
	_safe_t -= dt
	if _safe_t > 0.0:
		return
	_safe_t = 0.5
	var ins := TelegramApp.safe_insets(get_viewport().get_visible_rect().size.y)
	if ins.is_equal_approx(_safe):
		return
	_safe = ins
	hud.set_safe_area(ins.x, ins.y)
	ui.set_safe_area(ins.x, ins.y)


## Back to a tournament left through the menu or lost to a page reload: same place,
## same screen (a match in progress starts over).
func _continue_tournament() -> void:
	var t := SaveData.resumable()
	if t == null:
		_open_menu()
		return
	tournament = t
	tournament_mode = true
	_next_location = t.location
	set_location(t.location)
	Rewards.restore()
	if not t.pending_loot.is_empty():
		ui.show_loot(t)
	elif t.state == Tournament.State.REWARD:
		ui.show_reward(t)
	elif t.state == Tournament.State.LOST:
		var last: Dictionary = t.results.back()
		ui.show_result(t, false, String(last.get("score", "")), {"perfect": 0, "aces": 0, "best_rally": 0})
	else:
		ui.show_bracket(t)


func _play_match() -> void:
	var opp := tournament.opponent()
	Rewards.apply(tournament.perks)
	Tuning.ai_skill = clampf(float(opp["skill"]) + tournament.modifier_value("skill"), 0.0, 1.0)
	cpu.set_look(opp.get("look", Looks.from_shirt(opp.get("shirt", Color(0.22, 0.28, 0.42)))))
	_set_opponent_mods(tournament.modifier_value("speed"), tournament.modifier_value("serve"), tournament.current_lineup()["racket"])
	cpu_label = opp["short"]
	cpu_call = opp.get("short_en", "CPU")
	scoreboard = tournament.new_score(rng.randi_range(0, 1))
	ui.close()
	_begin_match()
	hud.announcer.intro(tournament.round_name().to_upper(), opp["name"])


## Opponent difficulty modifiers and the racket in their hand; the player's racket too.
func _set_opponent_mods(speed: float, serve: float, cpu_racket: Dictionary) -> void:
	ai.speed_mult = speed
	_cpu_serve_mult = serve
	cpu.set_racket_look(Gear.color(cpu_racket), Gear.glow(cpu_racket))
	var mine: Dictionary = tournament.racket if tournament_mode and tournament != null else {}
	Skills.gear = mine.get("mods", {})
	player.set_racket_look(Gear.color(mine), Gear.glow(mine))


func _begin_match() -> void:
	GameEvents.match_started.emit({"tournament": tournament_mode, "opponent": tournament.opponent()["id"] if tournament_mode and tournament != null else ""})
	sfx.set_music(false)
	stamina = mods_hub.start_stamina  # v0.2 G: 1.0, or «Полбака»
	score = [0, 0]
	rally = 0
	best_rally = 0
	_points_played = 0
	_match_over = false
	_replay_serve = false
	_run_dist = 0.0
	_match_stats = {"perfect": 0, "aces": 0, "best_rally": 0}
	court.clear_marks()  # the court is swept before a match
	server = scoreboard.server as Who
	player.area = PLAYER_AREA
	player.position = PLAYER_HOME
	cpu.position = CPU_HOME
	hud.show_board(scoreboard, ["ВЫ", cpu_label])
	if not autoplay and not _headless():
		hud.show_tutorial_once()
	_reset_point()


func _finish_match() -> void:
	var won: bool = scoreboard.winner == Who.PLAYER
	var st: String = scoreboard.final_text()
	GameEvents.match_finished.emit({"won": won, "score": st, "tournament": tournament_mode})
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
	if won and not tournament.pending_loot.is_empty():
		_bonus_score = st
		_start_bonus()
		return
	sfx.play("victory" if won else "defeat", -4.0)
	ui.show_result(tournament, won, st, _match_stats)


func _on_ui(action: String, arg: int) -> void:
	match action:
		"start_tournament":
			ui.show_locations()
		"continue":
			_continue_tournament()
		"location":
			_next_location = Locations.LIST[arg]["id"]
			set_location(_next_location)
			ui.show_formats()
		"format":
			club.remember(_next_location, arg)  # the club's "Турнир" goes straight to the bracket next time
			RunMods.open(self, arg)  # v0.2 G: the run's conditions screen, then _start_tournament
		"practice":
			_start_practice()
		"character":
			ui.show_character()
		"locker":
			ui.show_locker()
		"howto":
			hud.open_tutorial()
		"look":
			ui.show_look_editor(Looks.sanitize(SaveData.look))
		"look_done", "look_back":
			SaveData.look = ui.look_result if action == "look_done" else ui.editing_look()
			SaveData.save()
			player.set_look(SaveData.look)
			ui.show_locker()
		"controls_menu":
			ui.show_controls(false)
		"bh_style":
			Tuning.one_handed_bh = not Tuning.one_handed_bh
			SaveData.one_handed_bh = Tuning.one_handed_bh
			SaveData.save()
			Tuning.notify_changed()
			ui.show_locker(false)
		"controls":
			var first := not SaveData.control_chosen
			Tuning.tap_controls = arg == 1
			SaveData.tap_controls = Tuning.tap_controls
			SaveData.control_chosen = true
			SaveData.save()
			Tuning.notify_changed()
			if first:
				_open_menu()
			else:
				ui.show_locker()
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
			sfx.play("reward", -6.0)
			_next_screen("reward")
		"to_summary":
			_next_screen("summary")
		"reward":
			tournament.take_reward(arg)
			SaveData.save()
			ui.show_bracket(tournament)
		"wildcard":
			if tournament.use_wildcard():
				SaveData.save()
				ui.show_bracket(tournament)
		"to_loot":
			sfx.play("reward", -4.0)
			ui.show_loot(tournament)
		"loot":
			tournament.take_loot(arg == 1)
			SaveData.save()
			_next_screen("summary" if tournament.state == Tournament.State.OVER else "reward")
		"point":
			Skills.spend_point(Skills.LIST[arg])
			SaveData.save()
			ui.show_character(false)
		"bets", "wheel_chip", "spin", "bet_match", "bet_chip", "bet_win", "bet_sweep", "bet_back":
			RunBets.ui_action(self, action, arg)  # v0.2 A: the betting desk
		"mods_toggle", "mods_preset", "mods_go", "mods_back":
			RunMods.ui_action(self, action, arg)  # v0.2 G: the run's conditions
		"bag", "bag_item", "bag_back", "equip", "sell":
			RunBag.ui_action(self, action, arg)  # v0.2 A: the bag between matches
		"replay", "share":
			RunHub.ui_action(self, action)  # v0.2 A: the best point's replay and sharing it
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
			if SaveData.control_chosen or not SaveData.enabled:
				_open_menu()
			else:
				ui.show_controls(true)  # first launch: pick the controls before anything else


## The main screen: the club (v0.2 B), or the old list with --old-menu, in autoplay, or if
## the club can't be built.
func _open_menu() -> void:
	if Club.enabled() and not autoplay and club.open():
		return
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
	if _bot_measure > 0:  # measuring: the same opponent again, nothing carried over
		tournament.pending_loot = {}
		tournament.stage = clampi(_bot_stage, 0, tournament.rounds() - 1)
		tournament.state = Tournament.State.BRACKET
		tournament.champion = false
		_play_match()
		return
	while true:
		var c := Skills.next_pending(rng)
		if c.is_empty():
			break
		Skills.take_perk(c["offer"][0]["id"])
		print("  build perk (%s): %s" % [Skills.NAMES[c["skill"]], c["offer"][0]["title"]])
	if not tournament.pending_loot.is_empty():
		print("  loot: %s" % tournament.pending_loot["name"])
		tournament.take_loot(true)
	if tournament.results.size() > 25:
		tournament.give_up()
	match tournament.state:
		Tournament.State.REWARD:
			var pick := 2 if tournament.wildcards == 0 else (1 if tournament.racket.is_empty() else 0)
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


# --- Trophy mini-game -------------------------------------------------------------

func _start_bonus() -> void:
	phase = Phase.BONUS
	server = Who.PLAYER
	_bonus_balls = BONUS_BALLS
	_bonus_state = 0
	_bonus_success = false
	_bonus_bounces = 0
	court.set_net_up(false)
	ball.park()
	toss_active = false
	pending_swing = {}
	late_until = -1.0
	player.recover()
	cpu.recover()
	player.area = Rect2(-4.0, 12.1, 8.0, 1.2)
	player.position = Vector3(0.5, 0.0, 12.4)
	player.velocity = Vector3.ZERO
	cpu.position = Vector3(0.0, 0.0, -8.0)
	cpu.velocity = Vector3.ZERO
	cpu.relax()
	_runner_timer = 0.0
	if not tournament.pending_loot.is_empty():
		cpu.set_racket_look(Gear.color(tournament.pending_loot), Gear.glow(tournament.pending_loot))
	hud.announcer.item_card(tournament.pending_loot, "НОКАУТИРУЙ И ЗАБЕРИ")
	hud.announcer.set_hint("Подача по бегущему: попади в него мячом")
	_bonus_hud()


func _bonus_hud() -> void:
	hud.set_trophy(_bonus_balls, BONUS_BALLS)


func _update_bonus(delta: float) -> void:
	_bonus_t += delta
	_bonus_runner(delta)
	match _bonus_state:
		0:
			if not toss_active:
				player.serve_ready()
				ball.hold(_ball_in_hand(player))
			elif ball.state.vel.y < 0.0 and ball.state.pos.y < 1.7:
				toss_active = false
				hud.popup("TOSS AGAIN", COLOR_WARN)
		1:
			var bp := ball.state.pos
			var d := Vector2(bp.x - cpu.position.x, bp.z - cpu.position.z).length()
			if d < 0.5 and bp.y > 0.05 and bp.y < 1.95 and not cpu.is_down():
				_bonus_hit()
			elif bp.z < -19.0 or absf(bp.x) > 12.0 or _bonus_bounces >= 2 or ball.state.rolling or _bonus_t > 3.5:
				_bonus_miss()
		2:
			_bonus_wait -= delta
			if _bonus_wait <= 0.0:
				_end_bonus()
		3:
			_bonus_pickup(delta)


## The beaten opponent runs around their half in zigzags.
func _bonus_runner(delta: float) -> void:
	if cpu.is_down():
		cpu.move_input = Vector2.ZERO
		return
	cpu.max_speed = lerpf(3.8, 5.6, Tuning.ai_skill)
	_runner_timer -= delta
	if _runner_timer <= 0.0 or cpu.position.distance_to(_runner_goal) < 0.4:
		_runner_goal = Vector3(rng.randf_range(-3.8, 3.8), 0.0, rng.randf_range(-11.5, -5.0))
		_runner_timer = rng.randf_range(0.7, 1.4)
	var to := _runner_goal - cpu.position
	cpu.move_input = Vector2(to.x, to.z).normalized() if to.length() > 0.05 else Vector2.ZERO


## A serve aimed along the swipe line, landing deep in the other half: the runner is
## somewhere on the way.
func _bonus_serve(dir: Vector3, pace_k: float, type: int) -> void:
	var bp := ball.state.pos
	if bp.y < 1.7:
		return
	var err := game_time - toss_ideal
	var sk := Skills.stroke("serve")
	var tq := timing_quality(err, sk["window"], sk["good"])
	var q: float = tq[0]
	var label: String = tq[1]
	var origin := Vector3(bp.x, 0.0, bp.z)
	if dir.z > -0.2:
		dir = Vector3(dir.x, 0.0, -0.2).normalized()
	var target := origin + dir * ((-12.5 - origin.z) / dir.z)
	target.x = clampf(target.x, -7.0, 7.0)
	target.y = BallPhysics.RADIUS
	var pace := lerpf(30.0, 48.0, pace_k) * float(sk["pace"])
	var top := 300.0 if type == ShotType.TOPSPIN else 120.0
	player.swing(1, 0.02, bp, Athlete.Style.SERVE)
	execute_shot(Who.PLAYER, player, bp, target, pace, top, q, err, 1, false, 0.0, false, 0.05, sk["scatter"])
	toss_active = false
	hud.announcer.set_hint("")
	_bonus_state = 1
	_bonus_t = 0.0
	_bonus_bounces = 0
	var color := Hud.GOLD if label == "PERFECT" else (COLOR_WARN if label == "EARLY" or label == "LATE" else COLOR_GOOD)
	hud.popup(label, color)
	_haptic("perfect" if label == "PERFECT" else "medium")


func _bonus_hit() -> void:
	_bonus_success = true
	_bonus_hits += 1
	cpu.knockout(ball.state.vel)
	ball.state.vel = Vector3(-ball.state.vel.x * 0.2, 3.5, -ball.state.vel.z * 0.15)  # pops off the body
	cpu.set_racket_look(Gear.color({}), 0.0)
	sfx.play("hit_perfect", -2.0)
	cam.impulse(1.0)
	_haptic("heavy")
	hud.announcer.moment("KNOCKOUT!", UiTheme.GOLD)
	# The racket flies out of their hand and lands on the court; go and pick it up.
	_drop_from = cpu.position + Vector3(0.0, 1.1, 0.0)
	_drop_to = cpu.position + Vector3(rng.randf_range(-1.2, 1.2), 0.04, rng.randf_range(0.6, 1.4))
	_drop_to.x = clampf(_drop_to.x, -5.0, 5.0)
	_drop_t = 0.0
	_drop = _make_drop_racket(tournament.pending_loot)
	add_child(_drop)
	_drop.global_position = _drop_from
	player.area = Rect2(-8.0, -17.0, 16.0, 31.0)  # no net now: the whole court is open
	_bonus_t = 0.0
	_bonus_state = 3


## The knocked-out racket: a spinning arc onto the court, then the player runs over and
## picks it up (a flash, and it is in their hand).
func _bonus_pickup(delta: float) -> void:
	_bonus_t += delta
	_drop_t = minf(_drop_t + delta / 0.65, 1.0)
	var p := _drop_from.lerp(_drop_to, _drop_t)
	p.y = lerpf(_drop_from.y, _drop_to.y, _drop_t) + sin(_drop_t * PI) * 1.4
	_drop.global_position = p
	if _drop_t < 1.0:
		_drop.rotate_object_local(Vector3.FORWARD, delta * 14.0)
	else:
		_drop.rotation = Vector3(-PI * 0.5, 0.6, 0.0)  # lying flat on the court
	var to := _drop_to - player.position
	to.y = 0.0
	player.move_input = Vector2(to.x, to.z).normalized() * clampf(to.length(), 0.3, 1.0) if to.length() > 0.5 else Vector2.ZERO
	if (_drop_t >= 1.0 and to.length() < 0.8) or _bonus_t > 5.0:
		_drop.queue_free()
		_drop = null
		player.move_input = Vector2.ZERO
		player.set_racket_look(Gear.color(tournament.pending_loot), Gear.glow(tournament.pending_loot))
		player.split_step()
		hud.announcer.item_card(tournament.pending_loot, "ТРОФЕЙ")
		sfx.play("point", -4.0, 1.25)
		cam.impulse(0.8)
		_haptic("perfect")
		_bonus_state = 2
		_bonus_wait = 0.4 if autoplay else 1.6


func _make_drop_racket(item: Dictionary) -> Node3D:
	var root := Node3D.new()
	var c := Gear.color(item)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = Gear.glow(item) > 0.0
	mat.emission = c
	mat.emission_energy_multiplier = maxf(Gear.glow(item), 0.4)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.105 * 1.6
	tm.outer_radius = 0.128 * 1.6
	ring.mesh = tm
	ring.material_override = mat
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	ring.position = Vector3(0, 0.5 * 1.6, 0)
	root.add_child(ring)
	var handle := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.02 * 1.6
	cm.height = 0.34 * 1.6
	handle.mesh = cm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.1, 0.1, 0.1)
	handle.material_override = hm
	handle.position = Vector3(0, 0.15 * 1.6, 0)
	root.add_child(handle)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 1.2
	light.omni_range = 2.0
	light.position = ring.position
	root.add_child(light)
	return root


func _bonus_miss() -> void:
	_bonus_balls -= 1
	ball.park()
	_bonus_hud()
	if _bonus_balls <= 0:
		hud.announcer.moment("TROPHY LOST", UiTheme.LOSE, "ракетка осталась у соперника")
		_bonus_state = 2
		_bonus_wait = 0.5 if autoplay else 2.0
	else:
		hud.popup("MISS", COLOR_WARN, "осталось мячей: %d" % _bonus_balls)
		_bonus_state = 0


func _end_bonus() -> void:
	var loot: Dictionary = tournament.pending_loot
	if _drop:
		_drop.queue_free()
		_drop = null
	if not _bonus_success:
		tournament.missed_loot = loot.get("name", "")
		tournament.pending_loot = {}
	player.area = PLAYER_AREA
	_set_opponent_mods(1.0, 1.0, {})
	_stop_match()
	if _bonus_rounds > 0:
		_bonus_rounds -= 1
		print("bonus round: %s (balls left %d)" % ["HIT" if _bonus_success else "MISSED", _bonus_balls])
		if _bonus_rounds == 0:
			print("BONUS TEST: %d hits" % _bonus_hits)
			get_tree().quit()
			return
		tournament.pending_loot = Gear.roll(Gear.EPIC, rng)
		_start_bonus()
		return
	sfx.play("victory", -4.0)
	ui.show_result(tournament, true, _bonus_score, _match_stats)


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
	if Tuning.slowmo_enabled and not autoplay and ((phase == Phase.SERVE and server == Who.PLAYER) or phase == Phase.BONUS) and toss_active:
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
	if show_landing:
		# Placed once per ball: the prediction wobbles by a few centimetres every tick.
		# Only a real change (a net cord) moves it.
		var b := incoming.bounce_points[0]
		var spot := Vector3(b.x, 0.05, b.z)
		if not _landing.visible or _landing.global_position.distance_to(spot) > 0.35:
			_landing.global_position = spot
	_landing.visible = show_landing
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
	# Game time between physics ticks, so the ring shrinks smoothly in slow motion too.
	var lag := Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
	# The ring hangs above the player (never over the body or the ball's path) and
	# leans toward the side of the stroke: right for forehands, left for backhands.
	var anchor := cam.unproject_position(player.global_position + Vector3(0.0, 2.35, 0.0)) + Vector2(0.0, -70.0)
	ring.anchor = anchor
	hud.set_stamina(stamina if phase != Phase.IDLE else 1.0)
	# Everything below the player's feet is the joystick zone for the left thumb.
	var vh := get_viewport().get_visible_rect().size.y
	if Tuning.tap_controls:
		hud.touch.stick_zone_top = INF  # tap mode: no joystick, the whole screen is court
	else:
		hud.touch.stick_zone_top = clampf(cam.unproject_position(player.global_position).y + 28.0, vh * 0.66, vh * 0.9)
	if autoplay or mods_hub.no_ring:  # v0.2 G: «Без кольца»
		ring.hide_ring()
		return
	if ((phase == Phase.SERVE and server == Who.PLAYER) or phase == Phase.BONUS) and toss_active and toss_ideal - game_time < mods_hub.ring_late:
		var ss := Skills.stroke("serve")
		ring.show_ring(anchor, toss_ideal - game_time - lag, Tuning.perfect_window * float(ss["window"]), Tuning.good_window * float(ss["good"]), ss["ring_speed"])
		return
	if _player_can_hit():
		var fh := player.lateral_of(contact_pred) >= 0.0
		var lean := 55.0 if fh else -55.0
		# The stronger the stroke, the earlier the ring shows and the slower it closes.
		var sk := Skills.stroke("forehand" if fh else "backhand")
		var pw := Tuning.perfect_window * float(sk["window"])
		var gw := Tuning.good_window * float(sk["good"])
		if late_until > 0.0:
			ring.show_ring(anchor + Vector2(lean, 0.0), late_cross_time - game_time - lag, pw, gw, sk["ring_speed"])
			return
		if t_contact < minf(float(sk["ring"]), mods_hub.ring_late) and absf(player.lateral_of(contact_pred)) < 3.0 and contact_pred.y < MAX_CONTACT_H:
			ring.show_ring(anchor + Vector2(lean, 0.0), t_contact - lag, pw, gw, sk["ring_speed"])
			return
	ring.hide_ring()


func _debug_string() -> String:
	var s := "FPS %d   time x%.2f   %s\n" % [Engine.get_frames_per_second(), Engine.time_scale, graphics.describe()]
	s += "ball %.0f km/h  spin %.0f rpm  h %.2f m  stamina %d%%\n" % [ball.speed_kmh(), ball.spin_rpm(), ball.state.pos.y, roundi(stamina * 100.0)]
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
	if phase == Phase.BONUS:
		if _bonus_state != 0:
			return
		if not toss_active:
			_start_toss()
		elif game_time >= toss_ideal + _bot_offset:
			# Lead the runner: where they will be when the ball gets there.
			var lead := cpu.position + cpu.velocity * 0.5
			var d := lead - player.position
			d.y = 0.0
			_bonus_serve(d.normalized(), 0.6, ShotType.FLAT)
		return
	if phase == Phase.SERVE and server == Who.PLAYER:
		if not toss_active:
			_start_toss()
		elif game_time >= toss_ideal + _bot_offset:
			var to_box := Vector3(box_side * 2.0 - player.position.x, 0.0, -5.2 - player.position.z).normalized()
			_curl_k = rng.randf_range(0.9, 1.3)
			_player_serve(to_box.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-6.0, 6.0))), rng.randf_range(0.3, 1.0), rng.randi_range(0, 2))
		return
	if not _player_can_hit():
		_bot_armed = false
		return
	if not _bot_armed:
		_bot_armed = true
		_bot_offset = rng.randfn(0.0, _bot_sd)  # bot timing error, + = late
	var dir := _bot_dir(22.0)
	var pk := rng.randf_range(0.2, 0.7)
	var ty := rng.randi_range(0, 2)
	if rng.randf() < 0.06:
		ty = ShotType.LOB
	_curl_k = rng.randf_range(0.9, 1.3) if ty == ShotType.TOPSPIN else 1.0
	if late_until > 0.0:
		if game_time - late_cross_time >= _bot_offset:
			_swing_input(dir, pk, ty)
	elif _bot_offset <= 0.0 and pending_swing.is_empty() and t_contact <= -_bot_offset:
		_swing_input(dir, pk, ty)
	elif _bot_dive_test and pending_swing.is_empty() and t_contact < 0.24:
		_swing_input(dir, pk, ty)  # swing early so a dive can start in time


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
	print("dives: %d   stumbles: %d   errors: %d" % [_stats.get("dives", 0), _stats.get("stumbles", 0), _stats.get("errors", 0)])
