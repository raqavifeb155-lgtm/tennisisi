extends SceneTree
## The club (docs/club/H1_SPEC.md): places, walking, the world, the way to a match.
##   godot --headless --path . -s tests/club_test.gd

var failures := 0


func _initialize() -> void:
	test_places()
	test_walk()
	await test_world()
	await test_flow()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func test_places() -> void:
	print("places")
	var ids := []
	for p in ClubPlaces.LIST:
		ids.append(p["id"])
		check(float(p["r"]) > 0.5, "%s has a circle" % p["id"])
		check(p["action"] != "" or p["sign"] != "", "%s has a button or a sign" % p["id"])
	for id in ["court", "coach", "gate", "locker", "trophy", "bar", "arena", "board"]:
		check(ids.has(id), "place %s exists" % id)
	var overlap := false
	for i in ClubPlaces.LIST.size():
		for j in range(i + 1, ClubPlaces.LIST.size()):
			var a: Dictionary = ClubPlaces.LIST[i]
			var b: Dictionary = ClubPlaces.LIST[j]
			if (a["pos"] as Vector3).distance_to(b["pos"]) < float(a["r"]) + float(b["r"]) + 1.0:
				overlap = true
	check(not overlap, "circles don't overlap")
	var court := ClubPlaces.find("court")
	check(ClubPlaces.is_open(court, 0, 0), "the court is open from the start")
	var locker := ClubPlaces.find("locker")
	check(not ClubPlaces.is_open(locker, 0, 0) and ClubPlaces.is_open(locker, 1, 0), "the locker room opens after the first run")
	check(not ClubPlaces.is_open(ClubPlaces.find("bar"), 9, 3), "the bar is not built in H1")
	check(ClubPlaces.at(court["pos"] + Vector3(0.5, 0, 0)).get("id", "") == "court", "a point in the court's circle is at the court")
	check(ClubPlaces.at(Vector3(5, 0, 5)).is_empty(), "a point on the court itself is at no place")


func test_walk() -> void:
	print("walking")
	var w := ClubWalk.new()
	w.bounds = Rect2(-40, -40, 80, 80)
	w.add_box(Rect2(-2, -2, 4, 4))
	w.add_circle(Vector2(10, 0), 1.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var p := Vector2(-6, -6)
	var stuck_inside := false
	for i in 2000:
		var step := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.4)
		if i % 50 < 25:
			step = (Vector2.ZERO - p).normalized() * 0.3  # push into the box now and then
		p = w.resolve(p, p + step)
		if w.blocked(p):
			stuck_inside = true
	check(not stuck_inside, "never ends up inside an obstacle")
	# Sliding: walking diagonally into the box's left wall keeps going along it.
	var s := w.resolve(Vector2(-2.5, 0), Vector2(-2.1, 0.4))
	check(s.y > 0.3 and s.x <= -2.3, "slides along a wall (%.2f, %.2f)" % [s.x, s.y])
	check(w.resolve(Vector2(39.5, 0), Vector2(41, 0)).x <= 40.0, "stays inside the bounds")
	var q := Vector2(-20, -20)
	var target := Vector2(20, 18)
	for i in 600:
		var d := w.steer(q, target)
		if d == Vector2.ZERO:
			break
		q = w.resolve(q, q + d * 0.1)
	check(q.distance_to(target) < 0.3, "steers to a target (%.1f m off)" % q.distance_to(target))


func test_world() -> void:
	print("world")
	# Loaded at run time: ClubWorld and Club reach Athlete, which needs the autoloads
	# (a test script compiles before they exist).
	var w = load("res://scripts/club/club_world.gd").new()
	root.add_child(w)
	await process_frame
	var bm: Transform3D = w.ball_machine()
	check(bm.origin.z < -5.0 and absf(bm.origin.x) < Court.SINGLES_HALF_WIDTH, "ball machine on the far half of the main court")
	check((-bm.basis.z).z > 0.9, "the ball machine shoots toward the near baseline")
	for p in ClubPlaces.LIST:
		check(w.place_node(p["id"]) != null, "%s has its node" % p["id"])
		var c: Vector3 = p["pos"]
		check(not w.walk.blocked(Vector2(c.x, c.z)), "%s circle is walkable" % p["id"])
	# From the court's circle through the gate in the fence to the coach's pavilion.
	var pos := Vector2(0, 14)
	var goal := Vector2(16, 26)
	var via := [Vector2(0, 22), Vector2(0, 31), Vector2(16, 31), goal]
	for target in via:
		for i in 400:
			var d: Vector2 = w.walk.steer(pos, target)
			if d == Vector2.ZERO:
				break
			pos = w.walk.resolve(pos, pos + d * 0.1)
	check(pos.distance_to(goal) < 0.4, "walks from the court to the coach (%.1f m off)" % pos.distance_to(goal))
	check(Locations.find("club")["id"] == "club", "the club is a location")
	var listed := false
	for l in Locations.LIST:
		listed = listed or l["id"] == "club"
	check(not listed, "the club is not on the tournament map")
	w.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


## The club as the main screen: two taps to a match, practice on the club court, walking.
func test_flow() -> void:
	print("flow")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 0
	Skills.pending = []
	main._show_menu()
	await _frames(3)
	var club = main.club
	check(club.active and main.location_id == "club", "the menu is the club")
	check(main.player.position.distance_to(club.START) < 0.5, "the hero starts in the court's circle")
	check(club.hud.current_place() == "court", "the court's button is up")
	check(club.place_buttons("court")["label"] == "ТУРНИР", "first time: ТУРНИР")
	# Tap 1: no tournament remembered -> the location screen (the old way).
	club._on_choice("club_tournament", 0)
	await _frames(2)
	check(main.ui.is_open() and main.tournament == null, "no last tournament: the location screen")
	main._on_ui("location", 1)  # Spain
	main._on_ui("format", 0)
	await _frames(3)
	check(SaveData.club.get("last_location", "") == "clay" and int(SaveData.club.get("last_format", -1)) == 0, "the choice is remembered")
	check(not club.active, "a tournament's bracket closes the club")
	# Back to the club, then "Турнир" goes straight to the bracket: tap 1 Турнир, tap 2 Играть.
	SaveData.active = null
	SaveData.run = {}
	main._show_menu()
	await _frames(3)
	check(club.active and main.player.position.distance_to(club.START) < 0.5, "back in the club, at the court")
	check(club.place_buttons("court")["label"].begins_with("ТУРНИР  ·  ИСПАНИЯ"), "the button names the last place")
	club._on_choice("club_tournament", 0)
	await _frames(3)
	check(main.tournament != null and main.location_id == "clay" and main.ui.is_open(), "one tap: the bracket in Spain")
	SaveData.active = null
	SaveData.run = {}
	main._show_menu()
	await _frames(3)
	# Practice from the club plays on the club's own court.
	club._on_choice("practice", 0)
	await _frames(3)
	check(main.location_id == "club" and not club.active and main.phase != club._idle, "practice on the club court")
	check(main.player.area == main.PLAYER_AREA and is_equal_approx(main.player.rotation.y, 0.0), "the match gets its player back")
	main._show_menu()
	await _frames(3)
	# Walking by a tap: the hero heads there and never ends up in a wall.
	club._move_target = Vector3(16, 0, 31)
	var inside_wall := false
	for i in 400:
		await physics_frame
		var p: Vector3 = main.player.position
		if club.world.walk.blocked(Vector2(p.x, p.z), 0.3):
			inside_wall = true
	var reached: Vector3 = main.player.position
	check(not inside_wall, "walking never ends inside a wall")
	check(Vector2(reached.x - 16, reached.z - 31).length() < 1.0, "walks out through the gate to the pavilions (%.1f m off)" % Vector2(reached.x - 16, reached.z - 31).length())
	club._travel("coach")
	await _frames(3)
	check(club.hud.current_place() == "coach", "quick travel lands in the coach's circle")
	main.queue_free()
	await _frames(2)
