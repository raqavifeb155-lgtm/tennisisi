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
var _last_rally := 0
var _swipe_armed := false


func _initialize() -> void:
	# Slow motion and hit-stop run on real time; headless frames run much faster than
	# real time, so they're switched off here to keep game time in step with frames.
	var tuning := root.get_node("Tuning")
	tuning.slowmo_enabled = false
	tuning.hitstop = false
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	_flush_events()
	if main == null or not main.is_inside_tree() or main.hud == null:
		return false
	var vp := root.get_visible_rect().size

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
		var before: Vector3 = main.player.position
		_tap(Vector2(vp.x * 0.85, vp.y * 0.62))
		_check_move_later(before)

	if frame >= 60 * 50:
		_report()
		return true
	return false


func _check_move_later(before: Vector3) -> void:
	await create_timer(0.6).timeout
	if main.player.position.x > before.x + 0.5:
		moved_ok = true


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
	var ok := player_hits >= 8 and moved_ok
	print("INPUT TEST %s" % ("PASSED" if ok else "FAILED"))
