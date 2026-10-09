extends SceneTree
## The ball machine's drill (scripts/run/ball_machine.gd): the machine feeds by the program,
## a ball counts by the stroke's type (the gesture classifier's) and its landing, the
## experience is half of a match's and a tenth after three laps a day, a lap pays gold and
## is saved, the exit goes back to the club by the machine.
##   godot --headless --path . --fixed-fps 60 -s tests/drill_test.gd

var failures := 0
var main: Node
var drill: BallMachine
var _bounces: Array = []


func _initialize() -> void:
	SaveData.enabled = false  # never the developer's save
	var tuning := root.get_node("Tuning")
	tuning.slowmo_enabled = false  # game time follows frames
	tuning.hitstop = false
	test_pure()
	await test_flow()
	await test_lap()
	await test_cap_and_exit()
	await test_first_run()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


# --- Gestures, drawn like a finger and read by ShotGesture -----------------------------

## Points and times of each stroke in a 720 x 1564 screen (the test's viewport may differ:
## scaled by the height).
func _stroke(kind: String) -> Array:
	var vp := root.get_visible_rect().size
	var k := vp.y / 1564.0
	var pts := PackedVector2Array()
	var times := PackedInt32Array()
	var n := 10
	for i in n:
		var u := float(i) / float(n - 1)
		var p := Vector2.ZERO
		var t := 0
		match kind:
			"flat":
				p = Vector2(360, 1250 - 420 * u)
				t = int(u * 130)
			"topspin":
				if u < 0.7:
					p = Vector2(360, 1250 - 420 * u / 0.7)
				else:
					var a := (u - 0.7) / 0.3 * PI * 0.5
					p = Vector2(360 + 150 * sin(a), 830 + 150 * (1.0 - cos(a)))
				t = int(u * 200)
			"slice":
				p = Vector2(320 + 90 * u, 900 + 380 * u)
				t = int(u * 170)
			"drop":
				p = Vector2(360 + 8 * sin(u * PI), 900 + 70 * u)
				t = int(u * 140)
			"lob":
				p = Vector2(360 - 80 * sin(u * PI), 1250 - 440 * u)
				t = int(u * 900)
		pts.append(Vector2(p.x * vp.x / 720.0, p.y * k))
		times.append(t)
	return [pts, times]


func test_pure() -> void:
	print("pure")
	var vp := Vector2(720, 1564)
	var want := {"flat": ShotGesture.Type.FLAT, "topspin": ShotGesture.Type.TOPSPIN, "slice": ShotGesture.Type.SLICE, "drop": ShotGesture.Type.DROP, "lob": ShotGesture.Type.LOB}
	for kind in want:
		var s := _stroke(kind)
		var r := ShotGesture.classify(s[0], s[1], root.get_visible_rect().size.y, 0.12, 45.0, 0.11, 12.0, 0.6, 1.4)
		check(r.type == want[kind], "the %s gesture reads as %s (%d)" % [kind, ShotGesture.NAMES[want[kind]], r.type])
	check(vp.x > 0.0, "(viewport known)")
	# Programme: the eight exercises in the order the owner asked for.
	var ids := []
	for t in BallMachine.TYPES:
		ids.append(t["id"])
	check(ids == ["flat", "topspin", "slice", "drop", "lob", "volley", "smash", "serve"], "the program: flat, topspin, slice, drop, lob, volley, smash, serve")
	check(BallMachine.PER_TYPE == 3 and BallMachine.PER_TYPE_FIRST == 1, "three of each, the first lap one")
	# What counts as which exercise.
	var m := BallMachine.new()
	var base := {"type": "TOPSPIN", "volley": false, "smash": false, "serve": false}
	check(m._matches("topspin", base) and not m._matches("flat", base) and not m._matches("slice", base), "a topspin counts as topspin only")
	var vol := {"type": "FLAT", "volley": true, "smash": false, "serve": false}
	check(m._matches("volley", vol) and m._matches("flat", vol) and not m._matches("volley", base), "a volley counts as a volley (and as its stroke), a ground stroke is no volley")
	var sm := {"type": "SMASH", "volley": false, "smash": true, "serve": false}
	check(m._matches("smash", sm) and not m._matches("flat", sm) and not m._matches("volley", sm), "a smash is a smash")
	var sv := {"type": "SERVE", "volley": false, "smash": false, "serve": true}
	check(m._matches("serve", sv) and not m._matches("flat", sv), "a serve is a serve")
	check(m._matches("drop", {"type": "DROP SHOT"}) and m._matches("lob", {"type": "LOB"}), "drop shot and lob by their names")
	m.free()
	# The ball through a point: in the real flight model, drag included.
	var from := Vector3(2.5, 0.85, -9.8)
	var goal := Vector3(0.5, 2.75, 5.5)
	var v := BallMachine.through(from, goal, 2.15)
	var s := BallPhysics.State.new(from, v, Vector3.ZERO)
	for i in int(2.15 * 240.0):
		BallPhysics.integrate_free(s, 2.15 / int(2.15 * 240.0))
	check(s.pos.distance_to(goal) < 0.08, "the smash feed passes the point it is aimed at (%.3f m off)" % s.pos.distance_to(goal))
	# The save: defaults, the daily count rolls over, the pay follows it.
	SaveData.club = {}
	BallMachine.fake_day = "2026-10-08"
	var d := BallMachine.data()
	check(not d["done"] and not d["later"] and int(d["today"]) == 0 and int(d["circles"]) == 0, "a fresh save: nothing done, nothing today")
	check(is_equal_approx(BallMachine.xp_factor(), 0.5) and not BallMachine.capped(), "experience x0.5 while the day's laps are not used up")
	d["today"] = 3
	check(BallMachine.capped() and is_equal_approx(BallMachine.xp_factor(), 0.1), "after three laps a day: x0.1")
	BallMachine.fake_day = "2026-10-09"
	check(not BallMachine.capped() and int(BallMachine.data()["today"]) == 0, "the next day it is full pay again")
	SaveData.club["last_location"] = "paris"
	check(BallMachine.gold_for_lap() == 20, "gold for a lap: 10 x the island's multiplier (Paris x2)")
	SaveData.club["last_location"] = "park"
	check(BallMachine.gold_for_lap() == 10, "New York: 10")


# --- The machine in the club ---------------------------------------------------------------

func _boot() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 0
	SaveData.gold = 0
	Skills.reset()
	Skills.pending = []
	BallMachine.fake_day = "2026-10-08"
	main.rng.seed = 20261008
	main.ai.rng.seed = 20261008
	var ge := root.get_node("GameEvents")
	ge.bounce.connect(func(i: Dictionary) -> void: _bounces.append(i))
	main._show_menu()
	await _frames(3)
	drill = main.drill


func _xp_total() -> float:
	var t := 0.0
	for id in Skills.LIST:
		t += float(Skills.xp.get(id, 0.0))
	return t


## Waits for the verdict of the next ball (or false after `max_frames`), hitting it with
## `kind` when the ring is about to close. kind "" = lets it go by.
func _play_ball(kind: String, max_frames := 1500) -> bool:
	var before: int = drill._tries[drill._step] if not drill._tries.is_empty() else 0
	var swiped := false
	for f in max_frames:
		await physics_frame
		await process_frame
		if drill._state == BallMachine.St.SERVE and kind != "":
			if not main.toss_active and main.phase == main.Phase.SERVE:
				main._on_tap(Vector2(360, 700))
			elif main.toss_active and main.game_time >= main.toss_ideal - 0.04 and not swiped:
				swiped = true
				var vp := root.get_visible_rect().size
				var pts := PackedVector2Array([Vector2(vp.x * 0.5, vp.y * 0.75), Vector2(vp.x * 0.5 + main.box_side * vp.x * 0.05, vp.y * 0.65), Vector2(vp.x * 0.5 + main.box_side * vp.x * 0.1, vp.y * 0.55)])
				main._on_swipe(pts, PackedInt32Array([0, 40, 80]))
		elif kind != "" and not swiped and main._player_can_hit() and main.t_contact < 0.06:
			swiped = true
			var s := _stroke(kind)
			main._on_swipe(s[0], s[1])
		if drill._tries[drill._step] > before and drill._state != BallMachine.St.FLIGHT:
			return true
		if drill._state == BallMachine.St.SUMMARY:
			return true
	return false


func test_flow() -> void:
	print("flow")
	await _boot()
	var club = main.club
	club._travel("machine")
	await _frames(3)
	check(club.hud.current_place() == "machine", "the hero stands at the machine")
	var b: Dictionary = club.place_buttons("machine")
	check(b["action"] == "drill" and b["label"] == "ПУШКА" and b["extra"].size() == 1 and b["extra"][0][1] == "practice", "the machine's button starts the drill, the free game stays as a quiet link")
	var at_machine: Vector3 = main.player.position
	club._on_choice("drill", 0)
	await _frames(4)
	check(drill.active and not club.active and main.phase != club._idle, "the drill is on, the club stepped aside")
	check(main.location_id == "club" and club.world.get_node("machine_model").visible, "on the club court, the machine in place")
	check(not club.world.props_visible(), "the place circles are off")
	check(main.cpu.position.distance_to(BallMachine.COACH_POS) < 0.5, "the coach stands by the machine")
	check(drill.hud.visible and drill.hud.rects().size() >= 3, "the drill's card, hint and exit are up")
	check(drill.hud.buttons()[0].text == "Позже" and drill._need == 1, "the first lap: one of each, the exit says «Позже»")
	# The first ball comes by the program: from the machine's side, to the player's half.
	_bounces.clear()
	var launched := false
	for i in 400:
		await physics_frame
		if drill._state == BallMachine.St.FLIGHT:
			launched = true
			break
	check(launched, "the machine fired")
	check(main.ball.state.pos.z < -8.0 and main.ball.state.vel.z > 5.0 and main.last_hitter == main.Who.CPU, "from the far end, toward the player")
	check(main.phase == main.Phase.RALLY and drill.step_id() == "flat", "the ball plays in the rally phase; the first exercise is the flat one")
	for i in 200:
		await physics_frame
		if not _bounces.is_empty():
			break
	var first: Dictionary = _bounces[0] if not _bounces.is_empty() else {"pos": Vector3.ZERO}
	check(not _bounces.is_empty() and Court.is_in_singles(first["pos"], 1, 0.0), "it lands inside the player's half (%s)" % str(first["pos"]))
	# Let it go by: a miss, no experience, the exercise stays.
	var xp0 := _xp_total()
	var done := await _play_ball("")
	check(done and drill.last_verdict == "miss" and drill.progress().x == 0, "a ball let by is a miss, nothing counted")
	check(is_equal_approx(_xp_total(), xp0), "and it pays nothing")
	# The wrong stroke: a slice to the flat ball.
	done = await _play_ball("slice")
	check(done and drill.last_verdict == "wrong" and drill.progress().x == 0, "a slice to the flat exercise: not that stroke (%s)" % drill.last_verdict)
	check(drill.hud.flash_text() == "НЕ ТОТ УДАР" and "слайс" in drill.last_detail, "the card says so and names the stroke (%s)" % drill.last_detail)
	check(is_equal_approx(_xp_total(), xp0), "a wrong stroke pays nothing either")
	# The right one, until it lands: counted, PERFECT apart, experience x0.5 of a match.
	var counted := false
	for i in 8:
		done = await _play_ball("flat")
		if drill.last_verdict == "ok":
			counted = true
			break
	check(counted and drill.progress().x == 1, "a flat stroke that lands is counted (1 / 1)")
	var gain := _xp_total() - xp0
	check(gain > 0.2 and gain <= 1.0 + 0.001, "it pays half a match's experience, %.2f (timing 0.4..2.0 x BASE x 0.5)" % gain)
	check(drill.hud.flash_text() == "ЗАСЧИТАНО", "the card flashes ЗАСЧИТАНО")


func test_lap() -> void:
	print("lap")
	# Continues in the same game: the flat exercise is done, seven more.
	var order := ["topspin", "slice", "drop", "lob", "volley", "smash", "serve"]
	var gold0: int = SaveData.gold
	for id in order:
		var guard := 0
		while drill.step_id() != id and guard < 400:
			guard += 1
			await _frames(1)
		check(drill.step_id() == id, "next exercise: %s" % id)
		match id:
			"volley":
				main.player.position = Vector3(0.5, 0.0, 5.2)
				main.player.velocity = Vector3.ZERO
			"smash":
				main.player.position = Vector3(0.2, 0.0, 6.4)
				main.player.velocity = Vector3.ZERO
		var xp_skill_before := _xp_total()
		var ok := false
		for i in 12:
			if drill.step_id() != id:
				ok = true
				break
			if id == "volley":
				main.player.position = Vector3(0.5, 0.0, 5.2)
			elif id == "smash":
				main.player.position = Vector3(0.2, 0.0, 6.4)
			await _play_ball(id)
			if drill.last_verdict == "ok":
				ok = true
				break
			if drill._state == BallMachine.St.SUMMARY:
				ok = true
				break
		check(ok, "%s: a ball counted (last verdict %s %s)" % [id, drill.last_verdict, drill.last_detail])
		check(_xp_total() > xp_skill_before, "%s: it trained a skill" % id)
	var guard2 := 0
	while drill._state != BallMachine.St.SUMMARY and guard2 < 300:
		guard2 += 1
		await _frames(1)
	check(drill._state == BallMachine.St.SUMMARY and drill.hud.summary_shown(), "the lap is over: the summary shows")
	check(SaveData.gold == gold0 + 10, "a lap pays 10 gold on New York (%d)" % (SaveData.gold - gold0))
	var d := BallMachine.data()
	check(d["done"] and int(d["circles"]) == 1 and int(d["today"]) == 1 and bool(d["hint"]), "saved: done, one lap, one today, «Новая игра» to pulse")
	check(drill.last_info["ok"] >= 8 and drill.last_info["gold"] == 10 and drill.last_info["first"], "the lap's info: counted, gold, first")
	var typed: Dictionary = d["types"]
	check(typed.size() >= 6, "the counted balls are kept by exercise (%s)" % str(typed))


func test_cap_and_exit() -> void:
	print("cap and exit")
	var club = main.club
	# A second lap by «Ещё круг»: three of each now.
	drill._on_again()
	await _frames(3)
	check(drill._need == 3 and drill.step_id() == "flat" and drill.active and not drill.hud.summary_shown(), "«Ещё круг»: three of each from the flat one")
	check(drill.hud.buttons()[0].text == "Выйти", "after the first lap the exit says «Выйти»")
	# Daily pay: the third lap of the day is the last at full pay, then x0.1 and no gold.
	var d := BallMachine.data()
	d["today"] = 2
	check(is_equal_approx(BallMachine.xp_factor(), 0.5), "two laps today: still x0.5")
	var gold0: int = SaveData.gold
	drill._ok = [3, 3, 3, 3, 3, 3, 3, 3]
	drill._finish_lap()
	check(SaveData.gold == gold0 + 10 and BallMachine.capped(), "the third lap pays gold and uses up the day")
	check(is_equal_approx(BallMachine.xp_factor(), 0.1) and drill.hud._note.text.contains("на сегодня хватит"), "then x0.1 and «на сегодня хватит» on the card")
	var gold1: int = SaveData.gold
	drill._ok = [3, 3, 3, 3, 3, 3, 3, 3]
	drill._finish_lap()
	check(SaveData.gold == gold1 and drill.last_info["capped"] and int(BallMachine.data()["today"]) == 4, "a fourth lap pays no gold")
	# The same ball pays a fifth of the experience after the cap.
	drill._on_again()
	await _frames(3)
	var xp0 := _xp_total()
	drill.paying = true
	main._gain_xp("forehand", "GOOD")
	drill.paying = false
	var small := _xp_total() - xp0
	d["today"] = 0
	xp0 = _xp_total()
	drill.paying = true
	main._gain_xp("forehand", "GOOD")
	drill.paying = false
	var full := _xp_total() - xp0
	var age := Career.xp_mult()  # L1: the hero's age scales every experience, the drill's too
	check(is_equal_approx(full, 0.5 * age) and is_equal_approx(small, 0.1 * age), "a GOOD ball: 0.5 experience, 0.1 after the cap, x%.2f by age (%.2f / %.2f)" % [age, full, small])
	xp0 = _xp_total()
	main._gain_xp("forehand", "GOOD")
	check(is_equal_approx(_xp_total(), xp0), "outside the drill's own payments Main's per-hit experience is held")
	# Leaving: back in the club by the machine, the machine and the circles back.
	var circles: int = int(BallMachine.data()["circles"])
	main._show_menu()
	await _frames(4)
	check(not drill.active and club.active, "left the drill: the club is back")
	var mp: Vector3 = ClubPlaces.find("machine")["pos"]
	check(Vector2(main.player.position.x - mp.x, main.player.position.z - mp.z).length() <= float(ClubPlaces.find("machine")["r"]), "the hero stands in the machine's circle (%s)" % str(main.player.position))
	check(club.hud.current_place() == "machine" and club.world.props_visible() and club.world.get_node("machine_model").visible, "the machine's button is up, the props are back")
	check(int(BallMachine.data()["circles"]) == circles, "the saved laps stay")
	# The pause's own exit goes the same way.
	club._on_choice("drill", 0)
	await _frames(3)
	check(drill.active, "again into the drill")
	main.hud._exit_to_club()
	await _frames(4)
	check(not drill.active and club.active, "the pause's «Выйти в клуб» leaves the drill too")
	# The free game on the club court still starts from the quiet link.
	club._on_choice("practice", 0)
	await _frames(3)
	check(not club.active and not drill.active and main.location_id == "club", "«Свободная игра»: the old practice match")
	check(not club.world.get_node("machine_model").visible, "the machine does not shoot in a match")
	main._show_menu()
	await _frames(3)
	main.queue_free()
	await _frames(2)


func test_first_run() -> void:
	print("first run")
	await _boot()
	var club = main.club
	SaveData.club = {}
	BallMachine.fake_day = "2026-10-08"
	# A returning player (the old cards seen / a run played) is not led.
	drill.on_club_opened()
	check(drill._first_timer < 0.0, "headless / no save: the coach does not lead on his own")
	drill.on_club_opened(true)
	check(drill._first_timer > 0.0, "first visit: the coach leads to the machine after a moment")
	# The coach says his line, then leads: the drill starts by itself after a few seconds.
	await _frames(60 * 9)
	check(drill.active and drill._onboarding, "after his line the coach leads to the machine by himself")
	check(drill.hud.buttons()[0].text == "Позже" and drill._need == 1, "led to the machine: «Позже» is there, one of each")
	# «Позже» in the first lesson: remembered, the coach does not lead again.
	drill.hud.exit_pressed.emit()
	await _frames(4)
	check(not drill.active and club.active and BallMachine.data()["later"], "«Позже»: back in the club, not led again")
	drill._first_timer = -1.0
	drill.on_club_opened(true)
	check(drill._first_timer < 0.0, "and the machine is still at its place for later")
	# «Новая игра» pulses after the first lap.
	SaveData.club = {}
	club._travel("coach")
	await _frames(4)
	BallMachine.data()["hint"] = true
	club._travel("court")
	await _frames(4)
	check(club.hud.current_place() == "court" and club.hud.pulsing(), "after the lap «Новая игра» pulses")
	check(club.coach._clock >= 0.0, "(the coach's line is the club's)")
	root.get_node("GameEvents").match_started.emit({"tournament": true, "opponent": ""})
	check(not bool(BallMachine.data()["hint"]), "a tournament match puts the pulse out")
	club._travel("coach")
	await _frames(3)
	check(not club.hud.pulsing(), "the pulse is only on the court's button")
	main.queue_free()
