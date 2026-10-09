extends SceneTree
## End-to-end input test: feeds real touch events (tap / swipe) through TouchInput
## into the running game, like a player would, and checks that serving, hitting and
## tap-to-move work.
##   godot --headless --path . --fixed-fps 60 -s tests/input_test.gd

var main: Node
var frame := 0
var script_steps: Array = []    # queued [frame, event]
var serves := 0
var serve_faults := 0
var player_hits := 0
var swipes_sent := 0
var moved_ok := false
var tap_test_done := false
var stick_test_done := false
var stick_ok := false
var _last_rally := 0
var _move_check_until := -1     # frame until which the tap-to-move result is watched
var _move_before_x := 0.0
var _swipe_armed := false
var flick_checked := false
var flick_ok := false
var hold_ok := false
var underarm_done := false
var underarm_ok := false
var _underarm_until := -1
var serve_walk_done := false
var serve_walk_ok := false
var _serve_walk_x := 0.0
var _serve_walk_until := -1
var smash_state := 0            # 0 waiting for a lost point, 1 pressed, 2 swiping, 3 done
var smash_last := -99           # frame of the last smash swipe
var smash_info := {}
var smash_points := -1
var smash_ok := false
var smash_next := false         # after the smash the next point started (the serve)
var ev := {"stroke": 0, "point": 0, "shot": 0, "bounce": 0}


func _initialize() -> void:
	# Slow motion and hit-stop run on real time; headless frames run much faster than
	# real time, so they're switched off here to keep game time in step with frames.
	var tuning := root.get_node("Tuning")
	tuning.slowmo_enabled = false
	tuning.hitstop = false
	tuning.ai_skill = 0.2  # D-5: a gentler CPU (stats make the default one hard) - long rallies for the swipes to land in
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	# GameEvents: the bus other systems (style points, gear) listen to must fire.
	var ge := root.get_node("GameEvents")
	ge.player_stroke.connect(func(_i: Dictionary) -> void: ev["stroke"] += 1)
	ge.point.connect(func(_i: Dictionary) -> void: ev["point"] += 1)
	ge.shot.connect(func(_w: int, _i: Dictionary) -> void: ev["shot"] += 1)
	ge.bounce.connect(func(_i: Dictionary) -> void: ev["bounce"] += 1)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		# The same rallies every run: the test checks input, not luck (once Main is ready).
		main.rng.seed = 20261007
		main.ai.rng.seed = 20261007
	_flush_events()
	if main == null or not main.is_inside_tree() or main.hud == null:
		return false
	var vp := root.get_visible_rect().size

	# «Разбить ракетку»: a point is lost to an error, the button shows beside the ring, a tap
	# on it starts the mini-game (the match stands), three real swipes (up, down, down) break the
	# racket, and the next point is played.
	_smash_step(vp)

	# A fresh TouchInput: a quick flick up from the joystick zone is a shot, a held
	# drag there is the joystick.
	if not flick_checked and frame == 5:
		flick_checked = true
		var ti := TouchInput.new()
		root.add_child(ti)
		ti.stick_zone_top = vp.y * 0.7
		var shots := [0]
		ti.swiped.connect(func(_p: PackedVector2Array, _t: PackedInt32Array) -> void: shots[0] += 1)
		var a := Vector2(vp.x * 0.5, vp.y * 0.85)
		ti._input(_touch(a, true))
		for i in range(1, 5):
			ti._input(_drag(a + Vector2(10 * i, -40 * i)))
		ti._input(_touch(a + Vector2(40, -160), false))
		flick_ok = shots[0] == 1
		ti._input(_touch(a, true))
		ti._input(_drag(a + Vector2(60, 0)))
		hold_ok = ti.stick_active and ti._stick_vector.x > 0.3 and shots[0] == 1
		ti._input(_touch(a + Vector2(60, 0), false))
		# the hit window: the same upward drag, held 0.5 s, still a shot
		ti.shot_window = true
		ti._input(_touch(a, true))
		ti._stick_ms -= 500
		ti._input(_drag(a + Vector2(0, -170)))
		ti._input(_touch(a + Vector2(0, -170), false))
		flick_ok = flick_ok and shots[0] == 2
		ti.queue_free()

	# Tap controls at the serve: a tap behind the baseline walks there instead of tossing.
	if not serve_walk_done and frame > 60 and main.phase == main.Phase.SERVE and main.server == main.Who.PLAYER and not main.toss_active and script_steps.is_empty():
		serve_walk_done = true
		root.get_node("Tuning").tap_controls = true
		_serve_walk_x = main.player.position.x
		var a: Rect2 = main.player.area
		var goal := Vector3(a.end.x - 0.3 if _serve_walk_x < a.get_center().x else a.position.x + 0.3, 0.0, main.player.position.z)
		_tap(main.cam.unproject_position(goal))
		_serve_walk_until = frame + 90
	if frame <= _serve_walk_until:
		if main.toss_active:
			_serve_walk_until = -1  # it tossed: the tap was misread
		elif absf(main.player.position.x - _serve_walk_x) > 0.6:
			serve_walk_ok = true
			_serve_walk_until = -1
		if _serve_walk_until == -1 or frame == _serve_walk_until:
			root.get_node("Tuning").tap_controls = false
		return false

	# A short stroke down before the toss (the drop-shot gesture) serves underarm, without a toss.
	if serve_walk_done and _serve_walk_until == -1 and not underarm_done and main.phase == main.Phase.SERVE and main.server == main.Who.PLAYER and not main.toss_active and script_steps.is_empty():
		underarm_done = true
		main.last_serve_kmh = -1.0
		var k := vp.y / 1280.0  # the gesture test's short little stroke down, in this viewport
		var pts: Array[Vector2] = []
		for i in 12:
			var u := float(i) / 11.0
			var p := Vector2(360 + 30 * sin(u * PI), 800 + 80 * u)
			pts.append(Vector2(p.x * vp.x / 720.0, p.y * k))
		_swipe_path(pts)
		_underarm_until = frame + 40
	if frame <= _underarm_until:
		if main.toss_active:
			_underarm_until = -1
		elif main.last_serve_kmh > 0.0:
			underarm_ok = main.last_serve_kmh < 80.0
			_underarm_until = -1
		return false

	# Serve: tap to toss, then swipe toward the diagonal box when the ball reaches the ideal height.
	if main.phase == main.Phase.SERVE and main.server == main.Who.PLAYER and script_steps.is_empty():
		if not main.toss_active:
			_tap(Vector2(vp.x * 0.5, vp.y * 0.6))
			serves += 1
		elif main.game_time >= main.toss_ideal - 0.05:
			var dir_x: float = main.box_side * vp.x * 0.12
			_swipe(Vector2(vp.x * 0.5, vp.y * 0.75), Vector2(vp.x * 0.5 + dir_x, vp.y * 0.55), 3)

	# Rally: swipe straight up when the ring closes.
	if main._player_can_hit() and main.t_contact < 0.07 and script_steps.is_empty() and not _swipe_armed:
		_swipe_armed = true
		_swipe(Vector2(vp.x * 0.55, vp.y * 0.8), Vector2(vp.x * 0.52, vp.y * 0.6), 3)
	if not main._player_can_hit():
		_swipe_armed = false

	if main.rally > _last_rally and main.last_hitter == main.Who.PLAYER:
		player_hits += 1
	_last_rally = main.rally

	# Tap-to-move check, once, while the CPU is serving or the rally runs.
	if not tap_test_done and frame > 900 and main.phase == main.Phase.RALLY and main.last_hitter == main.Who.PLAYER:
		tap_test_done = true
		root.get_node("Tuning").tap_controls = true
		_move_before_x = main.player.position.x
		_tap(Vector2(vp.x * 0.85, vp.y * 0.62))
		_move_check_until = frame + 42
	# Watched frame by frame for 0.7 s of game time: real-time timers run far ahead of
	# headless frames, and a short point would already have reset the players.
	if frame <= _move_check_until and main.player.position.x > _move_before_x + 0.5:
		moved_ok = true

	# Joystick check: left thumb lands under the player and slides right.
	if tap_test_done and not stick_test_done and frame > 1500 and main.phase == main.Phase.RALLY and main.last_hitter == main.Who.PLAYER:
		stick_test_done = true
		root.get_node("Tuning").tap_controls = false
		var before_s: Vector3 = main.player.position
		var a := Vector2(vp.x * 0.5, vp.y * 0.96)
		var e := _touch(a, true)
		e.index = 1
		script_steps.append([frame, e])
		for i in range(1, 4):
			var d := _drag(a + Vector2(30.0 * i, 0.0))
			d.index = 1
			script_steps.append([frame + i, d])
		var up := _touch(a + Vector2(90.0, 0.0), false)
		up.index = 1
		script_steps.append([frame + 30, up])
		_check_stick_later(before_s)

	if frame >= 60 * 50:
		_report()
		return true
	return false


func _smash_step(vp: Vector2) -> void:
	var hub = main.smash_hub
	var sm: RacketSmash = hub.smash
	var btn: Control = main.hud.smash_btn
	if smash_state == 0 and frame > 60 * 25 and main.phase == main.Phase.RALLY and script_steps.is_empty():
		# The bot-like swipes may not throw a point away on their own in the time given (a better
		# returner, F-E): the flow under test starts from a point lost to an error, so lose one.
		main._end_point(main.Who.CPU, "OUT")
	if smash_state == 0 and main.phase == main.Phase.OVER and hub.offer_left > 0.0 and script_steps.is_empty():
		smash_info["button_visible"] = btn.is_visible_in_tree() and btn.size.x >= 84.0
		smash_info["tournament"] = main.tournament_mode
		smash_info["phase_waits"] = main.phase_timer >= hub.offer_left - 0.1  # the next serve waits for the window
		smash_state = 1
		btn.pressed.emit()
		smash_info["match_stands"] = main.phase == main.Phase.SMASH
		smash_points = main._points_played
	elif smash_state == 1 and main.phase == main.Phase.SMASH:
		smash_state = 2
	if smash_state == 3 and not smash_next and (main.phase == main.Phase.SERVE or main.phase == main.Phase.RALLY):
		smash_next = true
	if smash_state == 2:
		if main.phase == main.Phase.SMASH:
			if script_steps.is_empty() and frame - smash_last > 6:
				var want := sm.expects()
				if want < 0 and sm.state == RacketSmash.S.READY:
					smash_last = frame
					_swipe(Vector2(vp.x * 0.5, vp.y * 0.62), Vector2(vp.x * 0.5, vp.y * 0.34), 4)
				elif want > 0 and sm.state == RacketSmash.S.HELD:
					smash_last = frame
					_swipe(Vector2(vp.x * 0.5, vp.y * 0.34), Vector2(vp.x * 0.5, vp.y * 0.66), 4)  # from the middle down: no joystick zone
		else:
			smash_state = 3
			smash_info["swipes"] = sm.swipes
			smash_info["smashed"] = hub.smashed
			smash_info["stock_racket"] = main.player.gear().get("racket", {}).is_empty()
			smash_info["bonus"] = Skills.mods_layer.has("forehand_window") and hub.perfect_left == 3
			smash_info["racket_back"] = main.player.racket_node().visible and not main.player.smashing()


func _check_stick_later(before: Vector3) -> void:
	await create_timer(0.45).timeout
	if main.player.position.x > before.x + 0.5:
		stick_ok = true


func _flush_events() -> void:
	while not script_steps.is_empty() and int(script_steps[0][0]) <= frame:
		var ev: InputEvent = script_steps.pop_front()[1]
		# Delivered straight to the game's touch handler, in canvas coordinates
		# (headless runs have no real window to transform OS events from).
		main.hud.touch._input(ev)


func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	return e


func _drag(pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	return e


func _tap(pos: Vector2) -> void:
	script_steps.append([frame, _touch(pos, true)])
	script_steps.append([frame + 2, _touch(pos, false)])


## A drawn shape: one point per frame, like a finger.
func _swipe_path(pts: Array[Vector2]) -> void:
	swipes_sent += 1
	script_steps.append([frame, _touch(pts[0], true)])
	for i in range(1, pts.size()):
		script_steps.append([frame + i, _drag(pts[i])])
	script_steps.append([frame + pts.size() - 1, _touch(pts[-1], false)])


func _swipe(a: Vector2, b: Vector2, frames: int) -> void:
	swipes_sent += 1
	script_steps.append([frame, _touch(a, true)])
	for i in range(1, frames + 1):
		script_steps.append([frame + i, _drag(a.lerp(b, float(i) / frames))])
	script_steps.append([frame + frames, _touch(b, false)])


func _report() -> void:
	var labels: Dictionary = main._stats["labels"]
	var outcomes: Dictionary = main._stats["reasons"]
	print("\n=== INPUT TEST ===")
	print("tosses: %d  swipes: %d  player hits (incl. serves): %d" % [serves, swipes_sent, player_hits])
	print("timing labels: %s" % str(labels))
	print("point outcomes: %s" % str(outcomes))
	print("score: %s  %s" % [main.scoreboard.point_text(), main.scoreboard.games_text()])
	print("tap-to-move: %s" % ("OK" if moved_ok else "FAILED"))
	print("joystick: %s" % ("OK" if stick_ok else "FAILED"))
	print("tap-to-walk before the serve: %s" % ("OK" if serve_walk_ok else ("FAILED" if serve_walk_done else "NOT RUN")))
	print("hook before the toss = underarm: %s" % ("OK" if underarm_ok else ("FAILED" if underarm_done else "NOT RUN")))
	print("flick from the joystick zone = shot: %s, drag there = run: %s" % ["OK" if flick_ok else "FAILED", "OK" if hold_ok else "FAILED"])
	smash_ok = smash_state == 3 and smash_info.get("button_visible", false) and smash_info.get("match_stands", false) and smash_info.get("phase_waits", false) \
		and int(smash_info.get("swipes", 0)) == 3 and smash_info.get("smashed", false) and smash_info.get("stock_racket", false) \
		and smash_info.get("bonus", false) and smash_info.get("racket_back", false) and smash_next
	print("racket smash (lost point -> button -> up, down, down -> broken -> next point): %s %s, next point started: %s" % ["OK" if smash_ok else ("FAILED" if smash_state > 0 else "NOT RUN"), str(smash_info), str(smash_next)])
	print("game events: %s" % str(ev))
	var events_ok: bool = ev["stroke"] == player_hits and ev["point"] >= 1 and ev["shot"] >= ev["stroke"] and ev["bounce"] >= 1
	var ok := events_ok and player_hits >= 8 and moved_ok and stick_ok and serve_walk_ok and underarm_ok and flick_ok and hold_ok and smash_ok
	print("INPUT TEST %s" % ("PASSED" if ok else "FAILED"))
