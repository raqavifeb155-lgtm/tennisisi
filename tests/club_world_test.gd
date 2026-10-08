extends SceneTree
## Stream H: the club as a place (docs/superpowers/specs/2026-10-08-club-world.md): the model
## pack and its simple forms, the props and the ruin that goes with the levels, the hour of
## the day, the camera behind the hero, the racketless walk, the auto-run of quick travel.
##   godot --headless --path . -s tests/club_world_test.gd

var failures := 0


func _initialize() -> void:
	SaveData.enabled = false  # never the developer's save
	test_pack()
	test_layout()
	test_daytime()
	await test_in_the_club()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func test_pack() -> void:
	print("the model pack")
	var host := Node.new()
	root.add_child(host)
	ClubPack.request(host)
	check(ClubPack.state == ClubPack.READY and ClubPack.generation == 1, "the pack loads from res:// off the web")
	var missing := []
	var tris := 0
	for id in ClubPackInfo.IDS:
		var m := ClubPack.mesh(id)
		if m == null or ClubShapes.make(id) == null:
			missing.append(id)
		else:
			tris += ClubPack.tris(id)
	check(missing.is_empty(), "every id has a pack mesh and a simple form (%s)" % ", ".join(missing))
	check(ClubPackInfo.IDS.size() >= 40 and ClubPackInfo.IDS.size() <= 60, "40-60 props picked (%d)" % ClubPackInfo.IDS.size())
	check(tris < 20000, "the whole pack is under 20k triangles (%d)" % tris)
	var size := FileAccess.get_file_as_bytes(ClubPack.RES_PATH).size()
	check(size < 3 * 1024 * 1024, "the pack is under 3 MB (%d KB)" % (size / 1024))
	for id in ["tree_oak", "bench", "car_hatch", "streetlight"]:
		var a := ClubPack.mesh(id).get_aabb()
		var b := ClubShapes.make(id).get_aabb()
		check(absf(a.size.y - b.size.y) < maxf(a.size.y, b.size.y) * 0.35, "%s: the simple form is as tall as the model (%.1f / %.1f m)" % [id, b.size.y, a.size.y])
	var hero_scale := ClubPack.mesh("bench").get_aabb().size.y
	check(hero_scale > 0.5 and hero_scale < 1.3, "a bench is bench-high next to the 1.85 m hero (%.2f m)" % hero_scale)


func test_layout() -> void:
	print("the layout")
	var props := ClubProps.new()
	ClubLayout.fill(props)
	var ruin_level := func(_o: String) -> int: return 0
	var built_level := func(_o: String) -> int: return 9
	var ruin := props.visible(ruin_level, true)
	var built := props.visible(built_level, true)
	check(props.count() > 150, "a lot of props (%d)" % props.count())
	check(ruin.size() > built.size() + 40, "a ruin at level 0 has far more than a built club (%d vs %d)" % [ruin.size(), built.size()])
	var low := props.visible(ruin_level, false)
	check(low.size() < ruin.size() * 0.85, "Low draws fewer props than High (%d vs %d)" % [low.size(), ruin.size()])
	# nothing solid on a place's circle, nothing solid in a gate or a door
	var on_place := 0
	var in_court := 0
	for p in ruin:
		var q := Vector2(p.xf.origin.x, p.xf.origin.z)
		if p.solid > 0.0:
			for pl in ClubPlaces.LIST:
				var c: Vector3 = pl["pos"]
				if Vector2(q.x - c.x, q.y - c.z).length() < float(pl["r"]) + 0.3:
					on_place += 1
			if absf(q.x) < ClubLayout.HX and absf(q.y) < ClubLayout.HZ:
				in_court += 1
	check(on_place == 0, "no solid prop stands in a place's circle (%d)" % on_place)
	check(in_court == 0, "no solid prop stands inside the court's fence (%d)" % in_court)
	# every owner is a real place or construction, and a ruin goes by a real level
	var owners := {}
	for p in props.props:
		if p.owner != "":
			owners[p.owner] = true
	for o in owners:
		check(ClubBuilds.TABLE.has(o) or not ClubPlaces.find(o).is_empty(), "prop owner '%s' is a place" % o)
	var baked := ClubProps.bake(ruin, true)
	check(baked.size() >= 6, "baked into several squares (%d)" % baked.size())
	var any_big := false
	for k in baked:
		for cls in baked[k]:
			any_big = any_big or (baked[k][cls] as ArrayMesh).get_surface_count() > 0
	check(any_big, "squares hold meshes")
	var low_cells := ClubProps.bake(low, false)
	var classes_low := {}
	for k in low_cells:
		for cls in low_cells[k]:
			classes_low[cls] = true
	check(classes_low.keys() == ["big"], "Low folds a square into one mesh (%s)" % str(classes_low.keys()))


func test_daytime() -> void:
	print("the hour of the day")
	check(ClubDaytime.evening(10.0) == Vector2(0, 0), "10:00 is day")
	check(ClubDaytime.evening(15.0).x == 0.0, "15:00 is still day")
	check(ClubDaytime.evening(18.5).x > 0.2 and ClubDaytime.evening(18.5).x < 0.9, "18:30 is the golden hour")
	check(ClubDaytime.evening(21.0).x == 1.0 and ClubDaytime.evening(21.0).y < 0.5, "21:00 is evening")
	check(ClubDaytime.evening(23.5).y == 1.0, "23:30 is night")
	check(ClubDaytime.evening(2.0).y == 1.0 and ClubDaytime.evening(2.0).x == 1.0, "02:00 is night")
	check(ClubDaytime.evening(8.0).x == 0.0, "08:00 is morning")
	check(ClubDaytime.evening(6.0).x > 0.0 and ClubDaytime.evening(6.0).x < 1.0, "06:00 is dawn")


func test_in_the_club() -> void:
	print("in the club")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {"met_coach": true, "walk_hint": true}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 0
	SaveData.titles = 0
	Skills.pending = []
	ClubDaytime.force_hour = 11.0
	main._show_menu()
	await _frames(6)
	var club = main.club
	var w: ClubWorld = club.world
	var scenery := w.get_node_or_null("ClubScenery") as ClubScenery
	check(scenery != null, "ClubWorld grew its scenery with one call")
	if scenery == null:
		main.queue_free()
		return
	# camera: behind the hero, low
	var hero: Node3D = main.player
	var cam: Camera3D = club.cam
	check(cam.global_position.z > hero.global_position.z + 4.0, "the camera stands behind the hero's back (%.1f m)" % (cam.global_position.z - hero.global_position.z))
	check(cam.global_position.y < 5.0 and cam.global_position.y > 2.0, "and low, not over the map (%.1f m)" % cam.global_position.y)
	check(cam.global_position.distance_to(hero.global_position) < 12.0, "and close (%.1f m)" % cam.global_position.distance_to(hero.global_position))
	# no racket, a casual walk
	check(hero.has_meta("casual") and hero.get_meta("casual"), "the hero walks casually in the club")
	check(not (hero.get("_racket") as Node3D).visible, "no racket in his hand")
	# ruin: boards on the shut shop and locker room, a sagging net, rusty fence
	check(scenery._boards.has("shop") and (scenery._boards["shop"] as Node3D).visible, "the shop is boarded up while it is shut")
	check(scenery._boards.has("locker") and (scenery._boards["locker"] as Node3D).visible, "so is the locker room")
	var door := ClubPlaces.find("shop")["pos"] as Vector3
	check(w.walk.blocked(Vector2(door.x, door.z + ClubWorld.PAVILION.y * 0.5 + 0.1), 0.35), "a boarded door can't be walked through")
	var court = main.court
	var net_root: Node3D = court.get("_net_root")
	check(net_root.get_node_or_null("sag_net") != null, "the net sags at level 0")
	var rusty := false
	for m in scenery._fence_mats:
		rusty = rusty or m.albedo_color.r > 0.4
	check(rusty, "the fence is rusty at level 0")
	var props_ruin := scenery.prop_stats()
	var n_ruin := 0
	for id in props_ruin:
		n_ruin += int(props_ruin[id][0])
	# the first run is played: the rooms open and the boards come off
	SaveData.played = 1
	club._refresh()
	await _frames(4)
	check(not (scenery._boards["shop"] as Node3D).visible, "played once: the boards are off the shop")
	check(not w.walk.blocked(Vector2(door.x, door.z + ClubWorld.PAVILION.y * 0.5 + 0.1), 0.2), "and the door is free")
	# built: the ruin around the construction goes
	SaveData.club["levels"] = {"court": 3, "gate": 2, "stands": 2, "trophy": 1, "bar": 1, "shop": 1, "locker": 1}
	club._refresh()
	await _frames(6)
	var props_built := scenery.prop_stats()
	var n_built := 0
	for id in props_built:
		n_built += int(props_built[id][0])
	check(n_built < n_ruin - 40, "built: the weeds and junk around the places are gone (%d -> %d props)" % [n_ruin, n_built])
	check(scenery.crowd._fan_n == 4, "stands level 2: four watchers at the fence (%d)" % scenery.crowd._fan_n)
	check(net_root.get_node_or_null("sag_net") == null, "a new net at court level 2")
	var green := false
	for m in scenery._fence_mats:
		green = green or m.albedo_color.r < 0.3
	check(green, "and a new fence")
	SaveData.club["levels"] = {}
	club._refresh()
	await _frames(4)
	# evening: the lamps glow
	check(not scenery.daytime._glows.visible, "11:00: the lamps are out")
	ClubDaytime.force_hour = 21.0
	await _frames(4)
	check(scenery.daytime._glows.visible and scenery.daytime._glows.multimesh.instance_count > 6, "21:00: the lamps are lit (%d)" % scenery.daytime._glows.multimesh.instance_count)
	check(w.sun().light_color.r > w.sun().light_color.b, "the sun goes orange")
	ClubDaytime.force_hour = -1.0
	# the stick is read against the camera
	check(is_equal_approx(cam.stick_yaw(), cam.yaw), "the stick follows the camera's heading")
	# the auto-run: along the path, a tap skips it
	club._travel("court")
	await _frames(4)
	var start: Vector3 = hero.position
	club.travel_run("trophy")
	check(club.running_to() == "trophy", "quick travel is a run to the place")
	var moved := 0.0
	for i in 90:
		await physics_frame
	moved = hero.position.distance_to(start)
	check(moved > 6.0, "the hero runs (%.1f m in 1.5 s)" % moved)
	check(cam.run_mode, "the camera follows him at the run")
	check(not w.walk.blocked(Vector2(hero.position.x, hero.position.z), 0.3), "never through a wall")
	club._on_tap(Vector2(300, 600))
	check(club.running_to() == "", "a tap skips the run")
	var trophy: Vector3 = ClubPlaces.find("trophy")["pos"]
	check(Vector2(hero.position.x - trophy.x, hero.position.z - trophy.z).length() < 2.5, "the hero is at the place")
	# a finger on the stick takes the run back
	club._travel("court")
	await _frames(3)
	club.travel_run("bar")
	for i in 20:
		await physics_frame
	main.hud.touch.move_vector = Vector2(0, 1)
	for i in 3:
		await physics_frame
	main.hud.touch.move_vector = Vector2.ZERO
	check(club.running_to() == "", "the stick takes the hero back from the run")
	# next door: no run at all
	club._travel("court")
	await _frames(2)
	club.travel_run("court")
	check(club.running_to() == "", "a place the hero already stands at is not run to")
	# the routes between the places are still there with all the props
	var from := Vector2(0, 14)
	for id in ["coach", "gate", "locker", "shop", "trophy", "bar", "arena"]:
		var p: Vector3 = ClubPlaces.find(id)["pos"]
		check(not w.walk.route(from, Vector2(p.x, p.z)).is_empty(), "a way from the court to %s" % id)
	# a match takes the racket back
	club._on_choice("practice", 0)
	await _frames(4)
	check(not club.active and (hero.get("_racket") as Node3D).visible, "in a match he has his racket again")
	main.queue_free()
	await _frames(2)
