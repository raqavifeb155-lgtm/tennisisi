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
	test_paths()
	await test_in_the_club()
	await test_people()
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
	var on_path := []
	for p in ruin:
		if p.solid > 0.0:
			var q2 := Vector2(p.xf.origin.x, p.xf.origin.z)
			if ClubPaths.near(q2, p.solid * 0.5):
				on_path.append("%s@(%.0f,%.0f)" % [p.id, q2.x, q2.y])
	check(on_path.is_empty(), "no solid prop stands on a path (%s)" % ", ".join(on_path.slice(0, 8)))
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


func test_paths() -> void:
	print("the paths")
	check(ClubPaths.connected(), "the path graph is one piece")
	var ids := ClubPaths.ids()
	var unreachable := []
	for a in ids:
		var r := ClubPaths.route(ClubPaths.node(a), ClubPaths.node("gate"))
		if r.is_empty():
			unreachable.append(a)
	check(unreachable.is_empty(), "every node has a way to the gate (%s)" % ", ".join(unreachable))
	var missing := []
	for pl in ClubPlaces.LIST:
		if not ClubPaths.PLACE_NODE.has(pl["id"]):
			missing.append(pl["id"])
	check(missing.is_empty(), "every place has its path (%s)" % ", ".join(missing))
	var no_way := []
	for a in ClubPlaces.LIST:
		for b in ClubPlaces.LIST:
			var na := ClubPaths.node(ClubPaths.PLACE_NODE[a["id"]])
			var nb := ClubPaths.node(ClubPaths.PLACE_NODE[b["id"]])
			if na != nb and ClubPaths.route(na, nb).is_empty():
				no_way.append("%s>%s" % [a["id"], b["id"]])
	check(no_way.is_empty(), "from every place to every place along paths (%s)" % ", ".join(no_way))
	var meshes := ClubPaths.build_meshes(-0.25)
	check((meshes["surface"] as ArrayMesh).get_surface_count() == 1 and (meshes["curb"] as ArrayMesh).get_surface_count() == 1, "one surface mesh and one kerb mesh")
	var holes := []
	var wide := []
	var steps := []
	for i in ClubPaths.EDGES.size():
		var e: Array = ClubPaths.EDGES[i]
		var a := ClubPaths.node(e[0])
		var b := ClubPaths.node(e[1])
		var w: float = e[2]
		var l := a.distance_to(b)
		var d := (b - a) / l
		var nrm := Vector2(-d.y, d.x)
		var s := 0.0
		var prev_y := NAN
		while s <= l:
			var c := a + d * s
			if s > 0.0 and s < l:
				for off: float in [0.0, w * 0.5 - 0.12, -(w * 0.5 - 0.12)]:
					if not ClubPaths.covers(c + nrm * off):
						holes.append("%d@%.0f" % [i, s])
				# beyond the edge of the path: bare, unless another path is there
				if s > 2.2 and s < l - 2.2:
					for off: float in [w * 0.5 + 0.3, -(w * 0.5 + 0.3)]:
						var q := c + nrm * off
						var other := false
						for j in ClubPaths.EDGES.size():
							if j != i:
								var ej: Array = ClubPaths.EDGES[j]
								if q.distance_to(Geometry2D.get_closest_point_to_segment(q, ClubPaths.node(ej[0]), ClubPaths.node(ej[1]))) < float(ej[2]) * 0.5 + 0.9:
									other = true
						if not other and ClubPaths.covers(q):
							wide.append("%d@%.0f" % [i, s])
			var y := ClubPaths.surface_y(c)
			if not is_nan(prev_y) and absf(y - prev_y) > 0.09:
				steps.append("%d@%.0f" % [i, s])
			prev_y = y
			s += 0.5
	check(holes.is_empty(), "the path mesh covers every edge, centre and sides, without a gap (%s)" % ", ".join(holes.slice(0, 6)))
	check(wide.is_empty(), "and no wider than its width (%s)" % ", ".join(wide.slice(0, 6)))
	check(steps.is_empty(), "the ground along every path rises smoothly, no step (%s)" % ", ".join(steps.slice(0, 6)))


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
	check(not scenery._boards.has("shop") or not (scenery._boards["shop"] as Node3D).visible, "the shop stands open from the start (T), no boards")
	check(not scenery._boards.has("locker") or not (scenery._boards["locker"] as Node3D).visible, "a locker room that is not built has no door to board up (T-1: its lot has stakes)")
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
	check(not scenery._boards.has("locker") or not (scenery._boards["locker"] as Node3D).visible, "played once: no boards")
	var door := ClubPlaces.find("locker")["pos"] as Vector3
	check(not w.walk.blocked(Vector2(door.x, door.z + ClubWorld.PAVILION.y * 0.5 + 0.1), 0.2), "and the spot where its door would be is free")
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
	# The ruin belongs to the lot, not to the type (ClubLots.ruin_level): a type on somebody else's
	# lot neither leaves a ruin on its own home nor drags the ruin of its old corner along.
	SaveData.played = 1
	SaveData.titles = 1
	SaveData.club["levels"] = {}
	SaveData.club["lots"] = {}
	club._refresh()
	await _frames(4)
	var home := {}
	for t in ClubLots.ORDER:
		home[t] = [_site_props(scenery, t, true), _site_props(scenery, t, false)]
	for t in ["coach", "stands", "locker", "trophy", "bar", "academy", "arena"]:
		check(home[t][0] > 0 and home[t][1] == 0, "empty lots, a ruin at the home of the %s (%d junk and weeds, no tidy-up)" % [t, home[t][0]])
	SaveData.club["lots"] = {"n1": "bar"}
	SaveData.club["levels"] = {"bar": 2}
	club._refresh()
	await _frames(4)
	check(_site_props(scenery, "locker", true) == 0 and _site_props(scenery, "locker", false) == 0, "a bar on the locker room's lot: the old corner there is cleared of ruin, and no locker's flowers are put up for nobody")
	check(_site_props(scenery, "bar", true) == home["bar"][0], "and the bar's own home is still a ruin (%d)" % home["bar"][0])
	var board_ok := false
	var lot1: Vector3 = ClubLots.lot("n1")["pos"]
	for pr in scenery.visible_props():
		if pr.owner == "bar" and pr.from > 0:
			board_ok = board_ok or Rect2(lot1.x - ClubLots.HALF.x, lot1.z - ClubLots.HALF.y, ClubLots.HALF.x * 2.0, ClubLots.HALF.y * 2.0).has_point(Vector2(pr.xf.origin.x, pr.xf.origin.z))
	check(board_ok, "the bar's menu board went with the bar to its new lot, not left at its old corner")
	check(_site_props(scenery, "trophy", true) == home["trophy"][0] and _site_props(scenery, "stands", true) == home["stands"][0], "the other lots keep their ruin")
	SaveData.club["lots"] = {"n6": "bar", "n7": "coach"}
	SaveData.club["levels"] = {"bar": 1, "coach": 2}
	club._refresh()
	await _frames(4)
	var bar_junk := 0
	for pr in scenery.visible_props():
		if pr.owner == "bar" and pr.need == 1:
			bar_junk += 1
	check(bar_junk == 0 and _site_props(scenery, "bar", false) > 0, "the bar at home, level 1: the junk is gone, the menu board is up")
	check(_site_props(scenery, "academy", true) == 0 and _site_props(scenery, "coach", true) == home["coach"][0], "a coach's room on the academy's lot clears that lot, not his own")
	SaveData.club["levels"] = {"bar": 2, "coach": 2}
	club._refresh()
	await _frames(4)
	check(_site_props(scenery, "bar", true) == 0, "the bar's weeds are gone at level 2")
	var in_site := true
	for pr in scenery.visible_props():
		if pr.owner in ["coach", "academy"]:
			var lot_pos: Vector3 = ClubLots.lot(String(ClubLots.TYPES[pr.owner]["home"]))["pos"]
			in_site = in_site and Rect2(lot_pos.x - ClubLots.HALF.x, lot_pos.z - ClubLots.HALF.y, ClubLots.HALF.x * 2.0, ClubLots.HALF.y * 2.0).has_point(Vector2(pr.xf.origin.x, pr.xf.origin.z))
	check(in_site, "the ruin of the coach's and the academy's lots lies on the lots")
	SaveData.club.erase("lots")
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
	# the pack arriving late (the web): the club first stands on simple forms, then is redrawn
	var verts_pack := _scenery_verts(scenery)
	var saved: Dictionary = ClubPack._pack.duplicate()
	ClubPack._pack.clear()
	ClubPack.generation = 0
	await _frames(3)
	var verts_simple := _scenery_verts(scenery)
	check(verts_simple > 1000 and verts_simple != verts_pack, "without the pack the club stands on simple forms (%d vs %d vertices)" % [verts_simple, verts_pack])
	ClubPack._pack = saved
	ClubPack.generation = 1
	await _frames(3)
	check(_scenery_verts(scenery) == verts_pack, "and when the pack comes the same club is drawn from it")
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
	# the stick: by its deflection, a jog past half, no inertia
	club._travel("court")
	await _frames(3)
	main.hud.touch._stick_vector = Vector2(0, -0.3)
	for i in 30:
		await physics_frame
	var walk_v := Vector2(hero.velocity.x, hero.velocity.z).length()
	check(walk_v > 0.8 and walk_v < 2.3, "a small push of the stick is a walk (%.1f m/s)" % walk_v)
	main.hud.touch._stick_vector = Vector2(0, -0.6)
	for i in 10:
		await physics_frame
	var jog_v := Vector2(hero.velocity.x, hero.velocity.z).length()
	check(jog_v > 3.8, "past half a stick he jogs within a sixth of a second (%.1f m/s)" % jog_v)
	main.hud.touch._stick_vector = Vector2(0, -1.0)
	for i in 20:
		await physics_frame
	var run_v := Vector2(hero.velocity.x, hero.velocity.z).length()
	check(run_v > 5.2 and run_v < 5.7, "a full stick is a run at ~5.5 m/s (%.2f)" % run_v)
	for i in 40:
		await physics_frame
	check(cam.global_position.distance_to(hero.global_position) > 9.7 and cam.global_position.y < 3.8, "running, the camera is a little farther and lower (%.1f m, %.1f high)" % [cam.global_position.distance_to(hero.global_position), cam.global_position.y])
	main.hud.touch._stick_vector = Vector2.ZERO
	for i in 12:
		await physics_frame
	check(Vector2(hero.velocity.x, hero.velocity.z).length() < 0.8, "let go: he stops almost at once")
	# next door: no run at all
	club._travel("court")
	await _frames(2)
	club.travel_run("court")
	check(club.running_to() == "", "a place the hero already stands at is not run to")
	# the fence: the world is shut all round; the gate and the wicket are the ways out
	check(w.walk.route(Vector2(0, 14), Vector2(30, 43.5)).is_empty(), "no way over the south fence beside the gate")
	check(w.walk.blocked(Vector2(20, ClubFence.SOUTH), 0.35) and w.walk.blocked(Vector2(-20, ClubFence.NORTH), 0.35) and w.walk.blocked(Vector2(54.8, 0), 0.35) and w.walk.blocked(Vector2(-54.8, 0), 0.35), "a wall on every side")
	check(not w.walk.route(Vector2(0, 14), Vector2(0, 44.0)).is_empty(), "the gate leads out to the street")
	check(not w.walk.route(Vector2(0, 14), Vector2(-3.0, -42.0)).is_empty(), "the wicket leads to the embankment")
	var fence_draws := 0
	for c in scenery.fence.get_children():
		if c is MultiMeshInstance3D:
			fence_draws += 1
	check(fence_draws == 4, "the fence costs four draws (%d)" % fence_draws)
	# the graph's nodes are free to stand on
	var blocked_nodes := []
	for id in ClubPaths.ids():
		var pn := ClubPaths.node(id)
		if id != "prom" and id != "street" and w.walk.blocked(pn, 0.3):
			blocked_nodes.append(id)
	check(blocked_nodes.is_empty(), "every node of the path graph is walkable (%s)" % ", ".join(blocked_nodes))
	# the routes between the places are still there with all the props
	var from := Vector2(0, 14)
	for id in ["coach", "gate", "locker", "shop", "trophy", "bar", "arena"]:
		var p: Vector3 = ClubPlaces.find(id)["pos"]
		check(not w.walk.route(from, Vector2(p.x, p.z)).is_empty(), "a way from the court to %s" % id)
	# the camera never has a prop, a wall or the gate between it and the hero: the 17 views
	club.world.focus_room("")
	var views := [Vector3(0, 0, 25), Vector3(-9.5, 0, 22), Vector3(-6, 0, -36), Vector3(-8, 0, 3), Vector3(10, 0, -24),
		Vector3(0, 0, 38), Vector3(-14, 0, -12), Vector3(24, 0, 12), Vector3(-26, 0, 30), Vector3(16, 0, 8),
		Vector3(-14, 0, 36), Vector3(22, 0, 10), Vector3(-20, 0, 8), Vector3(-6, 0, 33), Vector3(0, 0, 21),
		Vector3(-14, 0, 3), Vector3(0, 0, 30), Vector3(0, 0, 40), Vector3(1, 0, 39.5), Vector3(-1.5, 0, 37)]
	var yaws := [PI, -PI * 0.5, 0.0, PI * 0.5, -PI * 0.5, 0.0, 0.0, -PI * 0.5, PI, -PI * 0.5, 0.0, 0.0, PI * 0.5, PI, 0.0, -PI * 0.5, 0.0, 0.0, 0.0, 0.0]
	var hits := []
	for i in views.size():
		hero.position = views[i]
		hero.rotation.y = yaws[i]
		cam.release(0.0)
		cam.snap(false)
		var cam_at := Vector2(cam.global_position.x, cam.global_position.z)
		var to := Vector2(hero.position.x, hero.position.z)
		var gate_z: float = ClubLevels.GATE_Z
		var bad: bool = (cam_at.y - gate_z) * (to.y - gate_z) < 0.0 and absf(cam_at.x) < 7.0 and cam.global_position.y < 5.0
		var cam3 := cam.global_position
		var head := Vector3(to.x, 1.5, to.y)
		# walls and boxes are as tall as the camera; props as tall as their models
		var steps := int(cam_at.distance_to(to) / 0.25)
		for k in range(0, steps):
			var t := float(k) / steps
			var q := cam_at.lerp(to, t)
			if q.distance_to(to) > 1.0:
				for b2 in w.walk.boxes:
					if (b2 as Rect2).grow(0.1).has_point(q):
						bad = true
		for pr in scenery.props.visible(scenery.level_of, true):
			if pr.solid <= 0.0:
				continue
			var pc := Vector2(pr.xf.origin.x, pr.xf.origin.z)
			var mesh_top := ClubPack.mesh(pr.id).get_aabb().end.y * pr.xf.basis.get_scale().y + pr.xf.origin.y
			for k in range(0, steps):
				var t := float(k) / steps
				var q := cam_at.lerp(to, t)
				if q.distance_to(to) > 1.0 and q.distance_to(pc) < pr.solid + 0.1:
					var y := lerpf(cam3.y, head.y, t)
					if y < mesh_top + 0.2:
						bad = true
		if bad:
			hits.append("%d@%s" % [i, str(views[i])])
	check(hits.is_empty(), "nothing stands between the camera and the hero in any view (%s)" % ", ".join(hits))
	# people: a person to talk to, and nobody to walk through
	var npc: ClubNpc = club.npc
	check(npc.has("coach") and (npc.entry("coach")["lines"] as Array).size() >= 3, "the coach is registered as a person with lines")
	var acted := []
	npc.acted.connect(func(id: String, action: String) -> void: acted.append([id, action]))
	npc.register("t_guest", Vector3(30.0, 0.0, 30.0), "Поговорить", "club_t_guest", ["один", "два", "три"])
	club._travel("court")
	await _frames(3)
	hero.position = Vector3(30.0, 0.0, 31.0)
	await _frames(6)
	print("   (place %s, npc %s, auto %s, ui %s)" % [club._place, club._npc_btn, club._auto, main.ui.is_open()])
	check(club.hud.current_place() == "npc_t_guest", "a person within 1.2 m: the button (%s)" % club.hud.current_place())
	var said := []
	for k in 4:
		club._on_choice("club_npc_t_guest", 0)
		said.append(club.hud._bubble_label.text)
	check(said[0] == "один" and said[1] == "два" and said[2] == "три" and said[3] == "один", "the lines go round: %s" % str(said))
	check(acted.size() == 4 and acted[0][1] == "club_t_guest", "and each press does the action")
	hero.position = Vector3(30.0, 0.0, 34.0)
	await _frames(4)
	check(club.hud.current_place() != "npc_t_guest", "a step away: the button goes")
	# a body is solid: whoever is put inside it is pushed out to the edge
	var pushed := w.walk.resolve(Vector2(30.0, 30.4), Vector2(30.0, 30.4), 0.35, npc.agent_list())
	var gap := pushed.distance_to(Vector2(30.0, 30.0))
	check(gap > 0.74 and gap < 0.8, "the hero can't stand inside a person's body (%.2f m)" % gap)
	npc.unregister("t_guest")
	# the coach is solid too
	var coach_body: Node3D = main.cpu
	hero.position = coach_body.position + Vector3(0, 0, 3.0)
	cam.snap()
	hero.position = coach_body.position + Vector3(0, 0, 3.0)
	main.hud.touch._stick_vector = Vector2(0, -1)
	for i in 100:
		await physics_frame
	main.hud.touch._stick_vector = Vector2.ZERO
	var cgap := Vector2(hero.position.x - coach_body.position.x, hero.position.z - coach_body.position.z).length()
	check(cgap > 0.6, "and so is the coach (%.2f m)" % cgap)
	# 60 seconds of strolling: nobody gets stuck, nobody walks through anybody
	var crowd: ClubCrowd = scenery.crowd
	var worst_wait := 0.0
	var closest := 9.0
	hero.position = Vector3(0, 0, 36)
	for i in 3600:
		hero.position = Vector3(0, 0, 36.0 - float(i % 1800) / 1800.0 * 20.0)    # the hero walks the main alley and back
		crowd._update(1.0 / 60.0)
		for a in crowd.walker_count():
			worst_wait = maxf(worst_wait, crowd._walkers[a].waiting)
			for b in range(a + 1, crowd.walker_count()):
				var d := (crowd._walkers[a].pos - crowd._walkers[b].pos).length()
				if d < 1.0e4:
					closest = minf(closest, d)
	check(worst_wait < 6.0, "60 s of strolling: nobody is held up for long (%.1f s)" % worst_wait)
	check(closest > 0.55, "and nobody walks through anybody (closest %.2f m)" % closest)
	# the bodies: juniors and the old coach
	var kid := Athlete.new()
	root.add_child(kid)
	kid.setup(-1.0, Color(0.2, 0.5, 0.9), Rect2(-9, -18, 18, 36))
	AthleteCasual.set_junior(kid, 0.7)
	var old := Athlete.new()
	root.add_child(old)
	old.setup(-1.0, Color(0.5, 0.5, 0.5), Rect2(-9, -18, 18, 36))
	AthleteCasual.make_elder(old)
	await _frames(40)
	var adult_head := 1.2 if kid._body == Athlete.Body.SMOOTH else 1.28
	check(kid._model.scale.y < 0.7 and kid._model.scale.y > 0.6 and kid._head.scale.x > adult_head * 1.4, "a junior is 0.7 of the adult, his head bigger (%.2f, head x%.2f)" % [kid._model.scale.y, kid._head.scale.x / adult_head])
	check(old._pitch > 0.1 and (old._bones["chest"] as Node3D).get_child_count() >= 2, "the old coach stoops and wears a whistle on a cord (%.2f)" % old._pitch)
	check(old.look["hair_color"] == 10 and old.look["beard"] == 2, "grey hair, a moustache")
	kid.queue_free()
	old.queue_free()
	# in a room the hero stands on its floor, not under it
	for id in ["locker", "shop", "coach"]:
		var rc: Vector3 = ClubPlaces.find(id)["pos"]
		hero.position = Vector3(rc.x, 0.0, rc.z)
		for i in 30:
			await physics_frame
		check(hero.position.y >= w.walk.floor_at(Vector2(rc.x, rc.z)) - 0.01 and hero.position.y > 0.1, "in the %s room his feet are on the floor (y %.2f)" % [id, hero.position.y])
	# the ground under the feet, everywhere: on the grid, along every path, in a few places for real
	var bad_ground := []
	var count := 0
	for gx in range(-52, 53, 6):
		for gz in range(-38, 41, 4):
			var gp := Vector2(gx, gz)
			var gh := w.walk.floor_at(gp)
			count += 1
			if gh < -0.26 or gh > 0.16:
				bad_ground.append("%d,%d" % [gx, gz])
			elif absf(gx) < 11 and absf(gz) < 19 and absf(gh) > 0.001:
				bad_ground.append("apron %d,%d" % [gx, gz])
	for i in ClubPaths.EDGES.size():
		var ee: Array = ClubPaths.EDGES[i]
		var ea := ClubPaths.node(ee[0])
		var eb := ClubPaths.node(ee[1])
		for k in 8:
			var q := ea.lerp(eb, (k + 0.5) / 8.0)
			count += 1
			if absf(w.walk.floor_at(q) - ClubPaths.surface_y(q)) > 0.01 and w.walk.floor_at(q) < 0.1:
				bad_ground.append("edge %d" % i)
	check(bad_ground.is_empty() and count >= 300, "%d points: the ground has a height everywhere, flat in the court, as the paths say along them (%s)" % [count, ", ".join(bad_ground.slice(0, 5))])
	for gp3 in [Vector3(30, 0, 20), Vector3(0, 0, 36), Vector3(0, 0, 10), Vector3(45, 0, -20), Vector3(-3, 0, -30), Vector3(0, 0, 44)]:
		hero.position = gp3
		for i in 60:
			await physics_frame
		var want := w.walk.floor_at(Vector2(gp3.x, gp3.z))
		check(absf(hero.position.y - want) <= 0.01, "his feet are on the ground at (%.0f, %.0f): %.2f / %.2f" % [gp3.x, gp3.z, hero.position.y, want])
	# the auto-run from the gate to the court, frame by frame: no jump over 3 cm
	club._travel("gate")
	await _frames(3)
	club.travel_run("court")
	var last_y := hero.position.y
	var jump := 0.0
	for i in 400:
		await physics_frame
		jump = maxf(jump, absf(hero.position.y - last_y))
		last_y = hero.position.y
		if club.running_to() == "":
			break
	check(jump <= 0.03, "running from the gate to the court, no jump in the ground over 3 cm (%.3f)" % jump)
	hero.position = Vector3(0, 0, 14)
	# a match takes the racket back
	club._on_choice("practice", 0)
	await _frames(4)
	check(not club.active and (hero.get("_racket") as Node3D).visible, "in a match he has his racket again")
	main.queue_free()
	await _frames(2)


## The club's people (stream H-8, with T-2's students and the visiting star): 40 s of the club on its
## own with the hero standing by the court - nobody inside anybody, a body stays with its figure,
## nobody floats or is sunk (as drawn: the sample is taken before a frame's first tick), the hero is never moved by them -
## then 20 s with the hero walking through them.
func test_people() -> void:
	print("the people of the club")
	SaveData.played = 9
	SaveData.titles = 2
	SaveData.gold = 3000
	SaveData.academy = {}
	SaveData.club = {"met_coach": true, "walk_hint": true, "hire_hint": true, "lots": {"n7": "academy", "n2": "coach"}, "levels": {"academy": 3, "coach": 2}}
	SaveData.run = {}
	SaveData.active = null
	Skills.pending = []
	ClubDaytime.force_hour = 11.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	main._show_menu()
	await _frames(6)
	var club = main.club
	var w: ClubWorld = club.world
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	Academy.data()["free_given"] = true
	for i in 3:
		var st: Dictionary = JuniorGen.make(rng, 1)
		st["id"] = "s%d" % (i + 1)
		st["age0"] = [12, 15, 18][i]
		st["since"] = SaveData.played - 3
		st["trainings"] = 3
		(Academy.students() as Array).append(st)
	Academy.data()["guest"] = {"roster": "rublev", "name": "Андрей Рублёв", "until": SaveData.played + 2, "seed": 5}
	club._refresh()
	await _frames(4)
	var hero: Athlete = main.player
	var people: Array = club.npc_life.people()
	check(people.size() == 4, "three students and a visiting star (%d)" % people.size())
	hero.position = Vector3(0.0, 0.0, 14.0)
	club._place = ""
	club._update_place()
	var starts := [Vector2(-4.5, 10.5), Vector2(3.8, 6.0), Vector2(-3.0, 17.0), Vector2(4.0, 16.0)]   # near him: all four are real bodies
	for k in people.size():
		var n = people[k]
		n.pos = Vector3(starts[k].x, 0.0, starts[k].y)
		n.dwell = 1.0
		n.route = []
	var worst := {"gap": 9.0, "float": 0.0, "lag": 0.0, "lag_sum": 0.0, "lag_n": 0, "hero_moved": 0.0, "moving": 0.0}
	var hero_at := Vector2(hero.position.x, hero.position.z)
	var seen_frame := -1
	for i in 2400:
		await physics_frame   # (it fires before the tick: what stands here is what the last frame drew, if a frame came between)
		if i % 6 == 0 and Engine.get_process_frames() != seen_frame:
			_look_at_people(club, w, worst)
		seen_frame = Engine.get_process_frames()
	worst["hero_moved"] = Vector2(hero.position.x, hero.position.z).distance_to(hero_at)
	print("   (gap %.2f, float %.3f, lag max %.2f mean %.3f over %d, hero moved %.3f)" % [worst["gap"], worst["float"], worst["lag"], float(worst["lag_sum"]) / maxf(1.0, float(worst["lag_n"])), worst["lag_n"], worst["hero_moved"]])
	check(worst["gap"] > -0.07, "40 s: nobody inside anybody (the bodies count 4 cm wider each than they are; %.3f m)" % worst["gap"])
	check(worst["float"] < 0.05, "nobody floats or is sunk: a body stands on the ground it is drawn on (%.3f m)" % worst["float"])
	check(worst["lag_n"] > 20 and float(worst["lag_sum"]) / worst["lag_n"] < 0.12 and worst["lag"] < 0.35, "a body keeps up with its figure (mean %.3f, worst %.2f m)" % [float(worst["lag_sum"]) / maxf(1.0, float(worst["lag_n"])), worst["lag"]])
	check(worst["hero_moved"] < 0.01, "and the hero standing still is not moved by them (%.3f m)" % worst["hero_moved"])
	# the hero walks up and down the court's side through them
	var worst2 := {"gap": 9.0, "float": 0.0, "lag": 0.0, "lag_sum": 0.0, "lag_n": 0}
	var last := Vector2(hero.position.x, hero.position.z)
	var jump := 0.0
	for i in 1200:
		main.hud.touch._stick_vector = Vector2(0.15 * sin(float(i) / 40.0), -1.0 if int(float(i) / 240.0) % 2 == 0 else 1.0).normalized()
		await physics_frame
		var now := Vector2(hero.position.x, hero.position.z)
		jump = maxf(jump, now.distance_to(last))
		last = now
		if i % 3 == 0 and Engine.get_process_frames() != seen_frame:
			_look_at_people(club, w, worst2)
		seen_frame = Engine.get_process_frames()
	main.hud.touch._stick_vector = Vector2.ZERO
	check(worst2["gap"] > -0.07, "20 s of the hero walking among them: nobody inside anybody (%.3f m)" % worst2["gap"])
	check(worst2["float"] < 0.05, "and nobody floats or is sunk (%.3f m)" % worst2["float"])
	check(jump < 0.11, "and he is never shoved (largest step %.3f m a frame)" % jump)
	main.queue_free()
	await _frames(2)
	SaveData.club = {}
	SaveData.academy = {}
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0


## One look at the club's people as they are drawn: the smallest gap between any two bodies (the hero's,
## the club's), how far a body stands above or below the ground, how far it trails its figure.
func _look_at_people(club: Node, w: ClubWorld, m: Dictionary) -> void:
	var list: Array = club.npc.agent_list()
	list.append([Vector2(club.main.player.position.x, club.main.player.position.z), 0.35])
	for i in list.size():
		for j in range(i + 1, list.size()):
			var gp := (list[i][0] as Vector2).distance_to(list[j][0]) - float(list[i][1]) - float(list[j][1])
			if gp < -0.07:
				print("   overlap %s %s r %s %s" % [list[i][0], list[j][0], list[i][1], list[j][1]])
			m["gap"] = minf(m["gap"], gp)
	for n in club.npc_life.people():
		if n.body != null and n.body.visible:
			m["float"] = maxf(m["float"], _off_ground(w, n.body.position))
			var lag := Vector2(n.body.position.x - n.pos.x, n.body.position.z - n.pos.z).length()
			m["lag"] = maxf(m["lag"], lag)
			m["lag_sum"] += lag
			m["lag_n"] += 1
	var hp: Vector3 = club.main.player.position
	m["float"] = maxf(m["float"], _off_ground(w, hp))


## How far a walker's feet are from the ground drawn under him. A step in the ground (the court's edge,
## a room's floor) is eased like the hero's (1.6 m/s), so anywhere between the grounds within half a metre is standing on it.
func _off_ground(w: ClubWorld, p: Vector3) -> float:
	var lo := 9.0
	var hi := -9.0
	for k in 9:
		var o := Vector2.ZERO if k == 0 else Vector2.from_angle(float(k) * TAU / 8.0) * 0.5
		var f := w.walk.floor_at(Vector2(p.x, p.z) + o)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	return maxf(0.0, maxf(lo - p.y, p.y - hi))


## How many props of `owner` there are now: its ruin (junk and weeds) or its tidy-up (flowers...).
func _site_props(scenery: ClubScenery, owner: String, ruin: bool) -> int:
	var n := 0
	for pr in scenery.visible_props():
		if pr.owner == owner and ((pr.need > 0) if ruin else (pr.from > 0)):
			n += 1
	return n


func _scenery_verts(scenery: ClubScenery) -> int:
	var n := 0
	for key in scenery._cells:
		for k in scenery._cells[key]:
			var mi: MeshInstance3D = scenery._cells[key][k]
			if mi.mesh != null:
				n += (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n
