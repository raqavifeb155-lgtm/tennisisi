extends SceneTree
## The club as the phone sees it (docs/club/H1_SPEC.md 9), for design review:
##   godot --path . --rendering-driver opengl3 -s tools/club_shots.gd [-- --size=1480] [--gfx=1]
## 720x1564 = iPhone 17 Pro Max (440x956), --size=1480 = a small Android (360x740).
## PNGs go to the user data folder (path printed). Never writes the save.
## --gfx=N: graphics preset (1 Low .. 4 Max), and the draw calls are printed per shot.
## --builds: H2 - every construction at every level, the foreman, the build moment, and
## the whole club at the top (its draw calls).

var main: Node
var h := 1564
var gfx := -1
var out := ""
var builds := false
var stats := false
var views := false
var census := false
var hour := -1.0
var tag := ""          # --tag=X: club_X_<h>_*.png (other worktrees shoot into the same folder)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--gfx="):
			gfx = int(a.get_slice("=", 1))
		elif a == "--builds":
			builds = true
		elif a == "--stats":
			stats = true
		elif a == "--views":
			views = true
		elif a == "--census":
			census = true
		elif a.begins_with("--hour="):
			hour = float(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://club_%s%d_" % [tag, h])
	_keep_visible()
	_run.call_deferred()


func _shot(name: String, settle := 0.8) -> void:
	await create_timer(settle).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	var d := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var t := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	# The club's own budget is for the world: the same frame without the two people.
	var pv: bool = main.player.visible
	var cv: bool = main.cpu.visible
	main.player.visible = false
	main.cpu.visible = false
	await process_frame
	await process_frame
	var wd := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var wt := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	main.player.visible = pv
	main.cpu.visible = cv
	print("saved %s%s.png   draws %d  tris %.1fk   world: draws %d  tris %.1fk  (frame %d)" % [out, name, d, t, wd, wt, Engine.get_frames_drawn()])


## Triangles and draw calls the club's nodes would cost if all were in view: by top-level
## child of the scenery, the biggest first (--stats).
func _tri_report() -> void:
	var rows: Array = []
	var kids: Array = []
	for c in main.scenery.get_children():
		if c.name == "ClubScenery":
			kids.append_array(c.get_children())
			for g in c.get_children():
				for gg in g.get_children():
					kids.append(gg)
		else:
			kids.append(c)
	for c in kids:
		var t := [0, 0]
		_count(c, t)
		if t[1] > 0:
			var what := ""
			if c is MultiMeshInstance3D and c.multimesh:
				what = " x%d %s" % [c.multimesh.instance_count, c.multimesh.mesh.get_class() if c.multimesh.mesh else ""]
			elif c is MeshInstance3D and c.mesh:
				what = " " + c.mesh.get_class()
			rows.append([t[0], t[1], "%s %s%s" % [c.get_class(), c.name, what]])
	rows.sort_custom(func(a, b) -> bool: return a[1] > b[1])
	var all_t := 0
	var all_d := 0
	for r in rows:
		all_t += r[1]
		all_d += r[0]
	print("scenery total (no culling): %d nodes-with-geometry draws, %.1fk tris" % [all_d, all_t / 1000.0])
	for r in rows.slice(0, 22):
		print("  %-40s draws %3d  tris %6.1fk" % [r[2], r[0], r[1] / 1000.0])
	var cs = main.scenery.get_node_or_null("ClubScenery")
	if cs:
		var st: Dictionary = cs.prop_stats()
		var list: Array = []
		var total := 0
		for id in st:
			list.append([id, st[id][0], st[id][1]])
			total += st[id][1]
		list.sort_custom(func(a, b) -> bool: return a[2] > b[2])
		print("props: %d prop triangles in all" % total)
		for r in list.slice(0, 18):
			print("  %-16s x%-3d %6.1fk tris" % [r[0], r[1], r[2] / 1000.0])


func _count(n: Node, t: Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm and mm.mesh:
			t[0] += 1
			t[1] += mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			t[1] = t[1] - mm.instance_count + mm.instance_count * _mesh_tris(mm.mesh)
	elif n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			var k := _mesh_tris(mi.mesh)
			t[0] += mi.mesh.get_surface_count()
			t[1] += k
	for c in n.get_children():
		_count(c, t)


func _mesh_tris(m: Mesh) -> int:
	var k := 0
	for i in m.get_surface_count():
		var arr := m.surface_get_arrays(i)
		if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
			k += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		elif arr[Mesh.ARRAY_VERTEX] != null:
			k += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return k


func _go(id: String) -> void:
	main.club._travel(id)


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SaveData.enabled = false  # look, don't touch the player's progress
	await create_timer(3.0).timeout  # loading screen (it can take longer on a busy machine: wait it out)
	for i in 60:
		var loading := false
		for c in main.get_children():
			if c is CanvasLayer and (c as CanvasLayer).layer == 100:
				loading = true
		if not loading:
			break
		await create_timer(0.5).timeout
	await create_timer(0.5).timeout
	if gfx >= 0:
		main.graphics.set_preset(gfx)
	SaveData.control_chosen = true
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	Skills.points = 2
	Skills.pending = []
	main._show_menu()
	if stats:
		_tri_report()
		quit()
		return
	print("club active=%s location=%s scenery=%s" % [main.club.active, main.location_id, main.scenery.get_script().resource_path])
	if hour >= 0.0:
		ClubDaytime.force_hour = hour
	if views:
		await _views()
		quit()
		return
	if census:
		await _census()
		quit()
		return
	if builds:
		await _builds()
		quit()
		return
	await _shot("01_start", 1.6)
	main.club.hud._toggle_travel(true)
	await _shot("02_travel", 0.4)
	main.club.hud._toggle_travel(false)
	_go("coach")
	await _shot("03_coach_room")
	SaveData.played = 1
	main.club._refresh()
	_go("locker")
	await _shot("04_locker_room")
	# Out on the path between the pavilions: the walk, the signs, the arena site.
	main.player.position = Vector3(-6, 0, 31)
	main.club._update_place()
	await _shot("05_path", 1.2)
	main.player.position = Vector3(-14, 0, -18)
	await _shot("06_trophy_sign", 1.6)
	var t := Tournament.new(1)
	t.stage = 3
	SaveData.active = t
	SaveData.club = {"last_location": "clay", "last_format": 1, "met_coach": true}
	_go("court")
	await _shot("07_continue", 1.2)
	SaveData.active = null
	main.club._place = ""
	main.club._update_place()
	await _shot("08_last_tournament", 0.6)
	# B-2: the places.
	_go("machine")
	await _shot("09_machine", 1.0)
	_go("shop")
	await _shot("10_shop_room", 1.0)
	main.club._on_choice("club_shop", 0)
	await _shot("11_shop_screen", 0.8)
	main._on_ui("menu", 0)
	SaveData.titles = 1
	SaveData.gold = 420
	main.club._refresh()
	_go("bar")
	await _shot("12_bar", 1.2)
	main.club._on_choice("club_roulette", 0)
	await _shot("13_roulette", 1.0)
	main.club.spin("red", 25)
	await _shot("14_roulette_spin", 2.2)
	main.club.roulette_skip()
	await _shot("15_roulette_result", 0.5)
	main.club.roulette_close()
	_go("arena")
	await create_timer(0.6).timeout
	main.club._on_choice("club_place", 0)
	await _shot("16_arena_card", 0.8)
	main._on_ui("menu", 0)
	# Hub: the coach's quests, collecting, blackjack, the islands.
	var run := Tournament.new(1)
	SaveData.active = run
	SaveData.club["quests"] = {"run": str(run.rng.seed), "issued": 3, "claimed": 0, "list": [
		ClubQuests._make(ClubQuests.find_template("aces"), 0, false),
		ClubQuests._make(ClubQuests.find_template("rally"), 0, false),
		ClubQuests._make(ClubQuests.find_template("wins"), 0, true)]}
	var ql: Array = ClubQuests.current()
	ql[0]["have"] = ql[0]["need"]
	ql[0]["done"] = true
	ql[1]["have"] = 12
	ql[2]["have"] = 1
	main.club.world.set_board(ClubQuests.board_text())
	_go("coach")
	await _shot("17_coach_board", 1.0)
	main.club._on_choice("club_quests", 0)
	await _shot("18_quests_screen", 0.8)
	main._on_ui("menu", 0)
	main.club._on_choice("club_claim", 0)
	await _shot("19_claimed", 0.6)
	_go("blackjack")
	await _shot("20_blackjack", 1.0)
	_go("court")
	await create_timer(0.4).timeout
	main.club._on_choice("club_locations", 0)
	await _shot("21_islands", 0.8)
	main._on_ui("menu", 0)
	# H: quick travel is a run along the path with the camera behind the hero; a tap skips.
	_go("court")
	await create_timer(0.4).timeout
	main.club.travel_run("trophy")
	await _shot("22_run_start", 0.5)
	await _shot("23_run_middle", 1.6)
	main.club.skip_run()
	await _shot("24_run_skipped", 0.8)
	quit()


## The club from where a walker would see it: the hero put somewhere, looking some way,
## the camera right behind him (--views).
func _views() -> void:
	SaveData.played = 1
	SaveData.titles = 1
	SaveData.club = {"met_coach": true, "walk_hint": true}
	main.club._refresh()
	main.club.hud.say("", 0.0)
	var list := [
		["v01_gate_south", Vector3(0, 0, 25), PI],
		["v02_court_east", Vector3(-9.5, 0, 22), -PI * 0.5],
		["v03_promenade", Vector3(-6, 0, -36), 0.0],
		["v04_west_arena", Vector3(-8, 0, 3), PI * 0.5],
		["v05_east_bar", Vector3(10, 0, -24), -PI * 0.5],
		["v06_gate_path", Vector3(0, 0, 38), 0.0],
		["v07_trophy", Vector3(-14, 0, -12), 0.0],
		["v08_east_lawn", Vector3(24, 0, 12), -PI * 0.5],
		["v09_west_south", Vector3(-26, 0, 30), PI],
		["v10_shop", Vector3(16, 0, 8), -PI * 0.5],
	]
	for v in list:
		var p: Athlete = main.player
		p.position = v[1]
		p.rotation.y = v[2]
		p.velocity = Vector3.ZERO
		main.club.cam.release(0.0)
		main.club.cam.snap(false)
		main.club._update_place()
		await _shot(v[0], 0.9)


## Which node costs how many draws and triangles from where the hero stands at the gate
## looking north (the longest view): each top-level node hidden in turn (--census).
func _census() -> void:
	SaveData.played = 1
	SaveData.titles = 1
	SaveData.club = {"met_coach": true, "walk_hint": true}
	main.club._refresh()
	main.club.hud.say("", 0.0)
	var p: Athlete = main.player
	p.position = Vector3(0, 0, 38)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			p.position = Vector3(float(a.get_slice("=", 1).get_slice(",", 0)), 0, float(a.get_slice("=", 1).get_slice(",", 1)))
	p.rotation.y = 0.0
	main.club.cam.release(0.0)
	main.club.cam.snap(false)
	main.player.visible = false
	main.cpu.visible = false
	var base := await _measure()
	print("census at the gate looking north: world draws %d tris %.1fk" % [base.x, base.y / 1000.0])
	for g in main.scenery.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 0.0
	for l in main.find_children("*", "Light3D", true, false):
		print("light: %s %s visible=%s in tree=%s energy=%.2f" % [l.get_class(), l.name, (l as Light3D).visible, (l as Light3D).is_visible_in_tree(), (l as Light3D).light_energy])
	for k in 4:
		var mm := await _measure()
		print("repeat base: draws %d tris %.1fk" % [mm.x, mm.y / 1000.0])
	var target = null
	for g in main.scenery.get_children():
		if str(g.name).begins_with("@MeshInstance3D@1169"):
			target = g
	if target:
		print("target aabb ", (target as MeshInstance3D).get_aabb(), " mat ", (target as MeshInstance3D).material_override, " pos ", (target as Node3D).global_position)
		for k in 3:
			target.visible = false
			var mh := await _measure()
			target.visible = true
			var ms := await _measure()
			print("hidden: draws %d   shown: draws %d" % [mh.x, ms.x])
	var m_nr := await _measure()
	print("with the draw ranges taken off: draws %d tris %.1fk" % [m_nr.x, m_nr.y / 1000.0])
	var sun: DirectionalLight3D = main.scenery.get("_sun")
	print("shadow distance now %.1f" % sun.directional_shadow_max_distance)
	for d in [60.0, 40.0, 30.0, 24.0, 18.0, 12.0]:
		sun.directional_shadow_max_distance = d
		var m0 := await _measure()
		print("  shadow distance %.0f: draws %d tris %.1fk" % [d, m0.x, m0.y / 1000.0])
	sun.shadow_enabled = false
	var m1 := await _measure()
	print("  no shadows: draws %d tris %.1fk" % [m1.x, m1.y / 1000.0])
	sun.directional_shadow_max_distance = 50.0
	base = await _measure()
	print("without shadows: draws %d tris %.1fk" % [base.x, base.y / 1000.0])
	var nodes: Array = []
	for c in main.scenery.get_children():
		if c.name == "ClubScenery":
			for g in c.get_children():
				if g is Node3D:
					nodes.append(g)
		elif c is Node3D:
			nodes.append(c)
	nodes.append(main.court)
	var cam: Camera3D = main.club.cam
	var kinds := {}
	for g in main.scenery.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree() or not cam.is_position_in_frustum(gi.global_transform * gi.get_aabb().get_center()):
			continue
		if gi is Label3D or (gi is MeshInstance3D and (gi as MeshInstance3D).mesh == null):
			continue
		var surfaces := 1
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			surfaces = (gi as MeshInstance3D).mesh.get_surface_count()
		var par := gi.get_parent()
		var key := "%s <%s> parent %s" % [gi.get_class(), gi.name.left(18), par.name.left(18)]
		if gi.name.begins_with("@"):
			key = "%s anon  parent %s" % [gi.get_class(), par.name.left(22)]
		var e: Array = kinds.get(key, [0, 0, 0])
		e[0] += 1
		e[1] += surfaces
		if gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh.mesh:
			e[2] += (gi as MultiMeshInstance3D).multimesh.instance_count * _mesh_tris((gi as MultiMeshInstance3D).multimesh.mesh)
		elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			e[2] += _mesh_tris((gi as MeshInstance3D).mesh)
		kinds[key] = e
	print("the world's own meshes in view:")
	for g in main.scenery.get_children():
		var gi := g as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree() or gi is Label3D or (gi is MeshInstance3D and (gi as MeshInstance3D).mesh == null) or not cam.is_position_in_frustum(gi.global_transform * gi.get_aabb().get_center()):
			continue
		var mat := ""
		if gi.material_override is StandardMaterial3D:
			var sm := gi.material_override as StandardMaterial3D
			mat = "%s tex=%s tr=%d next=%s" % [sm.albedo_color.to_html(false), sm.albedo_texture != null, sm.transparency, sm.next_pass != null]
		elif gi.material_override != null:
			mat = gi.material_override.get_class()
		var what := gi.get_class()
		if gi is MeshInstance3D:
			what = (gi as MeshInstance3D).mesh.get_class() if (gi as MeshInstance3D).mesh else "?"
			if (gi as MeshInstance3D).mesh is BoxMesh:
				what += " " + str(((gi as MeshInstance3D).mesh as BoxMesh).size)
		elif gi is MultiMeshInstance3D:
			what = "MM x%d %s" % [(gi as MultiMeshInstance3D).multimesh.instance_count, (gi as MultiMeshInstance3D).multimesh.mesh.get_class()]
		print("     %-40s %-44s shadow=%d %s surf=%d" % [what, mat, gi.cast_shadow, gi.name, (gi as MeshInstance3D).mesh.get_surface_count() if gi is MeshInstance3D and (gi as MeshInstance3D).mesh else 0])
	print("visible geometry by kind (nodes, surfaces) - no shadows:")
	var kl: Array = []
	for k in kinds:
		kl.append([k, kinds[k][0], kinds[k][1], kinds[k][2]])
	kl.sort_custom(func(a, b) -> bool: return a[3] > b[3])
	for r in kl.slice(0, 16):
		print("   %-60s %3d nodes %3d surf %6.1fk tris" % [r[0], r[1], r[2], r[3] / 1000.0])
	var rows: Array = []
	for n in nodes:
		if not is_instance_valid(n) or not (n as Node3D).visible:
			continue
		(n as Node3D).visible = false
		var m := await _measure()
		(n as Node3D).visible = true
		var what := ""
		if n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
			what = " x%d %s" % [n.multimesh.instance_count, n.multimesh.mesh.get_class()]
		rows.append([base.x - m.x, base.y - m.y, "%s %s%s" % [n.get_class(), n.name, what]])
	rows.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for r in rows.slice(0, 40):
		print("  -%3d draws  -%5.1fk tris  %s" % [r[0], r[1] / 1000.0, r[2]])


func _measure() -> Vector2:
	await process_frame
	await process_frame
	await process_frame
	return Vector2(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func _builds() -> void:
	var club = main.club
	SaveData.played = 3
	SaveData.titles = 4
	SaveData.gold = 380
	SaveData.club = {"met_coach": true}
	club._refresh()
	club.hud.say("", 0.0)
	club._travel("gate")
	await create_timer(0.4).timeout
	club._on_choice("club_foreman", 0)
	club.foreman_show("stands")
	await _shot("b01_foreman_stands_ghost", 1.0)
	club.foreman_show("court")
	await _shot("b02_foreman_court", 0.8)
	club.foreman_show("shop")
	await _shot("b02_foreman_shop_ghost", 0.8)
	club.foreman_build()
	await _shot("b03_build_moment", 0.75)
	club.skip_build()
	await _shot("b04_built_court1", 0.8)
	SaveData.gold = 20
	club.foreman_show("gate")
	await _shot("b05_need_more", 0.8)
	SaveData.club["levels"] = {"bar": 3}
	club._refresh()
	club.foreman_show("bar")
	await _shot("b06_maximum", 0.8)
	club.foreman_close()
	# Every level of every construction, framed as on the foreman's card.
	for id in ClubBuilds.ORDER:
		for lv in range(1, ClubBuilds.max_level(id) + 1):
			var levels: Dictionary = SaveData.club.get("levels", {}).duplicate()
			levels[id] = lv
			SaveData.club["levels"] = levels
			if id == "court" and lv >= 3:
				SaveData.club["color"] = 2
			club._refresh()
			var view: Array = club.BUILD_VIEW[id]
			club.cam.frame(view[0], view[1], 0.0)
			club.world.focus_room(id)
			club.hud.visible = false
			await _shot("b_%s_%d" % [id, lv], 0.5)
	# The whole club at the top, from the start: the budget with everything built.
	club.world.focus_room("")
	club.cam.release(0.0)
	club._travel("court")
	await _shot("b99_all_max_start", 1.0)
	main.player.position = Vector3(14.6, 0, 6.0)
	club._update_place()
	await _shot("b99_all_max_east", 1.2)


## Several streams shoot at once and every Godot window opens in the same place: a window
## fully covered by another is not drawn on macOS, and the shots come out frozen. Open
## this one somewhere of its own and bring it forward.
func _keep_visible() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	DisplayServer.window_set_position(Vector2i(rng.randi_range(0, 900), rng.randi_range(0, 120)))
	DisplayServer.window_move_to_foreground()
