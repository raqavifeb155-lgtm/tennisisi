extends SceneTree
## Stand viewer of the Academy house (stream art, docs/academy/ART_BRIEF.md): every room of the
## house built from the layout of HouseLayout at the levels asked, looked at by the camera of
## the game (the dolls'-house cut: from above and the side, the front and east walls away),
## with a few kids: light figures and one real Athlete in a pose of HousePose.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/academy_room_shots.gd -- --tag=art [options]
##
## options: --room=dorm,gym | all (default all)   --levels=1,3,5 (default)   --size=1564|1480 (the
##   phone's height, 720 wide)   --gfx=low|medium (low: no shadows, no outlines)   --simple (the
##   code forms, not the pack)   --evening   --nocast (no kids)   --clean (no caption)
##   --check: every id of the pack has a code form, every layout id exists; triangles pack vs code
##   --gallery [--room=dorm] [--ids=a,b] [--prefix=bed] [--simple]: the models on a grid
##   --tag=art: files user://academy_<tag>_<size>_<room>_<level>.png (all worktrees share user://)
## Draw calls and triangles are read from the renderer after the frame is drawn, three ways:
## the room alone, with the light figures, with the real Athlete too. The static things of a room
## are folded into ONE mesh (like MeshMerge in the game), so a room costs a few draws alone.

const WALL_H := 2.9

var tag := "art"
var size_h := 1564
var rooms: Array = []
var levels: Array = [1, 3, 5]
var simple := false
var evening := false
var nocast := false
var clean := false
var low := true
var detail := 0
var shadows := false
var hide_decor_off := false   # --decor: keep the small things on Low too
var gallery := false
var check := false
var ids_wanted: Array = []
var room_filter := ""
var prefix := ""

var _env: Environment
var _sun: DirectionalLight3D
var _stage: Node3D
var _cam: Camera3D
var _caption: Label
var _rows: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.get_slice("=", 1)
		elif a.begins_with("--size="):
			size_h = int(a.get_slice("=", 1))
		elif a.begins_with("--room="):
			room_filter = a.get_slice("=", 1)
		elif a.begins_with("--levels="):
			levels = []
			for l in a.get_slice("=", 1).split(","):
				levels.append(int(l))
		elif a.begins_with("--gfx="):
			var g := a.get_slice("=", 1)
			detail = 0 if g == "low" else (1 if g == "medium" else 2)
			low = detail == 0
		elif a == "--shadows":
			shadows = true
		elif a.begins_with("--ids="):
			ids_wanted = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--prefix="):
			prefix = a.get_slice("=", 1)
		elif a == "--simple":
			simple = true
		elif a == "--evening":
			evening = true
		elif a == "--nocast":
			nocast = true
		elif a == "--decor":
			hide_decor_off = true
		elif a == "--clean":
			clean = true
		elif a == "--gallery":
			gallery = true
		elif a == "--check":
			check = true
	rooms = HouseLayout.ROOM_ORDER if (room_filter in ["", "all"] or gallery) else Array(room_filter.split(","))
	_run.call_deferred()


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	HousePack.request(host)
	HousePack.force_simple = simple
	HousePack.detail = detail
	ClubMaterial.set_outlines(not low)
	Athlete.blob_shadows = low
	if gallery:
		await _gallery()
		quit()
		return
	if check:
		_check()
		quit()
		return
	root.size = Vector2i(720, size_h)
	_setup_world()
	for r in rooms:
		for lv in levels:
			await _shoot(String(r), int(lv))
	_print_stats()
	quit()


# --- the world: light, sky, camera ------------------------------------------------------

func _setup_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.11, 0.12, 0.17) if not evening else Color(0.05, 0.05, 0.09)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.86, 0.84, 0.88) if not evening else Color(0.78, 0.62, 0.58)
	_env.ambient_light_energy = 0.6 if not evening else 0.8
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = _env
	root.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, -28, 0)
	_sun.light_color = Color(1.0, 0.92, 0.8) if not evening else Color(1.0, 0.7, 0.45)
	_sun.light_energy = 1.0 if not evening else 0.55
	_sun.shadow_enabled = shadows
	root.add_child(_sun)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 1.0
	_cam.far = 200.0
	root.add_child(_cam)
	_cam.current = true
	var cl := CanvasLayer.new()
	root.add_child(cl)
	_caption = Label.new()
	_caption.position = Vector2(14, 10)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	_caption.custom_minimum_size = Vector2(690, 0)
	cl.add_child(_caption)


## The camera of the game: from the south-east, 48 degrees down; the room fits the width, a little
## above the middle (the lower third is for the panels).
func _frame_camera(extra := Vector3.ZERO) -> void:
	var az := deg_to_rad(32.0)
	var pitch := deg_to_rad(48.0)
	var corners: Array[Vector3] = []
	for x in [-3.1, 3.1]:
		for y in [-0.3, WALL_H]:
			for z in [-3.1, 3.1]:
				corners.append(Vector3(x, y, z))
	if extra != Vector3.ZERO:
		for z in [-extra.z, extra.z]:
			corners.append(Vector3(extra.x, 0.4, z))
	var target := Vector3(0, 0.9, 0)
	var dist := 14.0
	var dir := Vector3(sin(az) * cos(pitch), sin(pitch), cos(az) * cos(pitch))
	for step in 40:
		_cam.position = target + dir * dist
		_cam.look_at(target, Vector3.UP)
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for c in corners:
			var p := _cam.unproject_position(c)
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		if (hi.x - lo.x) / 720.0 <= 0.96:
			break
		dist *= 1.04
	var lo2 := Vector2(1e9, 1e9)
	var hi2 := Vector2(-1e9, -1e9)
	for c in corners:
		var p := _cam.unproject_position(c)
		lo2 = Vector2(minf(lo2.x, p.x), minf(lo2.y, p.y))
		hi2 = Vector2(maxf(hi2.x, p.x), maxf(hi2.y, p.y))
	var mid := (lo2 + hi2) * 0.5
	var shift_px := mid.y - size_h * 0.44
	var m_per_px := 2.0 * dist * tan(deg_to_rad(_cam.fov * 0.5)) / float(size_h)
	target += _cam.global_transform.basis.y * shift_px * m_per_px
	_cam.position = target + dir * dist
	_cam.look_at(target, Vector3.UP)


# --- a room ---------------------------------------------------------------------------

func _shoot(room: String, level: int) -> void:
	if _stage != null:
		_stage.queue_free()
		await process_frame
	_stage = Node3D.new()
	root.add_child(_stage)
	var statics: Array = []
	var look: Dictionary = HouseLayout.LOOK[room]
	_shell(room, level, look, statics)
	_items(room, level, statics)
	var mi := MeshInstance3D.new()
	mi.mesh = _merge(statics)
	mi.material_override = ClubScenery.prop_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(mi)
	_windows(room)
	var kids := Node3D.new()
	_stage.add_child(kids)
	var cast_nodes: Array = []
	if not nocast:
		cast_nodes = _cast(room, level, kids)
	_frame_camera(Vector3(4.9, 0, 2.6) if room in ["dorm", "lounge"] and level >= 5 else Vector3.ZERO)
	var titles: Array = HouseLayout.TITLES[room]
	_caption.text = "%s · ур. %d · %s" % [room, level, titles[level - 1]]
	_caption.visible = not clean
	for i in 3:
		await process_frame
	await create_timer(0.3).timeout
	await process_frame
	var d_all := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var t_all := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	var path := ProjectSettings.globalize_path("user://academy_%s_%d_%s_%d.png" % [tag, size_h, room, level])
	root.get_texture().get_image().save_png(path)
	kids.visible = false
	await process_frame
	await process_frame
	var d_room := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var t_room := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	kids.visible = true
	for n in cast_nodes:
		if n.has_meta("real"):
			(n as Node3D).visible = false
	await process_frame
	await process_frame
	var d_light := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var t_light := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	for n in cast_nodes:
		(n as Node3D).visible = true
	print("saved %s   draws %d  tris %.1fk   (room only: %d / %.1fk, +light figures: %d / %.1fk)" % [path, d_all, t_all, d_room, t_room, d_light, t_light])
	_rows.append([room, level, d_room, t_room, d_light, t_light, d_all, t_all])


func _print_stats() -> void:
	if _rows.is_empty():
		return
	print("--- %s%s, %s: draws / triangles(k) ---" % [["Low", "Medium", "High"][detail], " + shadows" if shadows else "", "code forms" if simple else "pack"])
	print("room    lvl   room only     + light figures    + real Athlete")
	for r in _rows:
		print("%-7s %d    %3d / %5.1f     %3d / %5.1f      %3d / %5.1f" % [r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7]])


## Folds [mesh, transform] pairs into one ArrayMesh (colours kept).
func _merge(list: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for e in list:
		var m: ArrayMesh = e[0]
		var xf: Transform3D = e[1]
		var arr := m.surface_get_arrays(0)
		var av: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var an: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ac: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var ai: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base := v.size()
		var nb := xf.basis.inverse().transposed()
		for k in av.size():
			v.append(xf * av[k])
			n.append((nb * an[k]).normalized())
			c.append(ac[k])
		for k in ai:
			idx.append(base + k)
	var out := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func _xf(spot: Vector4) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(spot.z)), Vector3(spot.x, spot.w, spot.y))


## Floor slab, the back and west walls (the door gap), skirting, stains and cracks when it is worn
## out, the paint, a band and a stripe when it is fresh: the room's level shows in its walls too.
func _shell(room: String, level: int, look: Dictionary, out: Array) -> void:
	var k := float(level - 1) / 4.0                     # 0 worn out .. 1 fresh
	var floor_c: Color = look["floor"]
	var wall_c: Color = look["wall"]
	var trim_c: Color = look["trim"]
	var dingy := Color(0.62, 0.58, 0.52)
	floor_c = floor_c.lerp(dingy, 0.35 * (1.0 - k)).darkened(0.12 * (1.0 - k))
	wall_c = wall_c.lerp(dingy, 0.5 * (1.0 - k)).darkened(0.1 * (1.0 - k))
	var s := ClubShapes.new()
	s.box(Vector3(6.6, 0.3, 6.6), Vector3(0, -0.15, 0), floor_c.darkened(0.25))
	s.box(Vector3(6.2, 0.04, 6.2), Vector3(0, 0.0, 0), floor_c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room)
	for i in 8:
		s.box(Vector3(6.2, 0.045, 0.025), Vector3(0, 0.0, -2.6 + i * 0.75), floor_c.darkened(0.09))
	if room in ["gym", "med", "hall"]:
		for i in 7:
			s.box(Vector3(0.025, 0.045, 6.2), Vector3(-2.7 + i * 0.9, 0.0, 0), floor_c.darkened(0.07))
	if level <= 2:
		for i in 3:
			s.box(Vector3(rng.randf_range(0.3, 0.9), 0.05, 0.03), Vector3(rng.randf_range(-2.4, 2.4), 0.001, rng.randf_range(-2.4, 2.4)), Color("5e5a54"), rng.randf_range(0, PI))
	var wall := wall_c
	s.box(Vector3(6.6, WALL_H, 0.2), Vector3(0, WALL_H * 0.5, -3.1), wall)
	s.box(Vector3(0.2, WALL_H, 3.9), Vector3(-3.1, WALL_H * 0.5, -1.15), wall)
	s.box(Vector3(0.2, WALL_H, 1.05), Vector3(-3.1, WALL_H * 0.5, 2.575), wall)
	s.box(Vector3(0.2, WALL_H - 2.15, 1.3), Vector3(-3.1, 2.15 + (WALL_H - 2.15) * 0.5, 1.425), wall)
	var top := trim_c.darkened(0.1 + 0.2 * (1.0 - k))
	s.box(Vector3(6.7, 0.08, 0.3), Vector3(0, WALL_H + 0.04, -3.1), top)
	s.box(Vector3(0.3, 0.08, 6.7), Vector3(-3.1, WALL_H + 0.04, 0), top)
	var skirt := trim_c.lerp(dingy, 0.4 * (1.0 - k))
	s.box(Vector3(6.0, 0.14, 0.04), Vector3(0, 0.07, -2.98), skirt)
	s.box(Vector3(0.04, 0.14, 5.9), Vector3(-2.98, 0.07, 0), skirt)
	s.box(Vector3(0.12, 2.15, 0.1), Vector3(-3.0, 1.075, 0.8), WOODD_)
	s.box(Vector3(0.12, 2.15, 0.1), Vector3(-3.0, 1.075, 2.05), WOODD_)
	s.box(Vector3(0.12, 0.1, 1.35), Vector3(-3.0, 2.15, 1.425), WOODD_)
	s.box(Vector3(0.1, 0.03, 1.2), Vector3(-2.9, 0.02, 1.425), trim_c)
	if k > 0.45:
		var band := trim_c.lerp(wall_c, 0.55)
		s.box(Vector3(5.9, 0.9, 0.03), Vector3(0, 0.55, -2.97), band)
		s.box(Vector3(0.03, 0.9, 3.8), Vector3(-2.97, 0.55, -1.1), band)
		s.box(Vector3(5.9, 0.04, 0.05), Vector3(0, 1.02, -2.96), trim_c)
		s.box(Vector3(0.05, 0.04, 3.8), Vector3(-2.96, 1.02, -1.1), trim_c)
	if k > 0.95:
		s.box(Vector3(5.9, 0.06, 0.06), Vector3(0, WALL_H - 0.1, -2.96), trim_c)
		s.box(Vector3(0.06, 0.06, 5.9), Vector3(-2.96, WALL_H - 0.1, 0), trim_c)
	if level <= 2:
		for i in 3:
			s.box(Vector3(rng.randf_range(0.3, 0.8), rng.randf_range(0.2, 0.5), 0.02), Vector3(rng.randf_range(-2.7, 2.7), rng.randf_range(1.0, 2.3), -2.985), wall_c.darkened(0.22))
		s.box(Vector3(0.02, 0.4, 0.5), Vector3(-2.985, 1.7, -1.8), wall_c.darkened(0.2))
	var w: Array = HouseLayout.WINDOWS[room]
	if float(w[1]) > 0.0:
		var wx := float(w[0])
		var ww := float(w[1])
		var fr: Color = WOODD_ if k < 0.5 else Color("f2f0ea")
		s.box(Vector3(ww + 0.2, 1.5, 0.08), Vector3(wx, 1.65, -2.97), fr)
		s.box(Vector3(ww + 0.3, 0.06, 0.2), Vector3(wx, 0.88, -2.9), fr)
	out.append([s.build(), Transform3D.IDENTITY])


const WOODD_ := Color("6b4a32")


func _windows(room: String) -> void:
	var w: Array = HouseLayout.WINDOWS[room]
	if float(w[1]) <= 0.0:
		return
	var q := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(float(w[1]), 1.3, 0.02)
	q.mesh = bm
	q.material_override = ClubMaterial.glow(Color(1.0, 0.8, 0.45) if evening else Color(0.65, 0.85, 1.0), 1.0 if evening else 0.9)
	q.position = Vector3(float(w[0]), 1.65, -2.92)
	_stage.add_child(q)


func _items(room: String, level: int, out: Array) -> void:
	for it in HouseLayout.items(room):
		var id := HouseLayout.id_at(it, level)
		if low and id in HouseShapes.DECOR and not hide_decor_off:
			continue
		if id == "":
			if level < int(it["from"]):
				_chalk(it, out)
			continue
		var m: ArrayMesh = HousePack.mesh(id)
		if m == null:
			push_warning("no mesh for " + id)
			continue
		for sp in it["spots"]:
			out.append([m, _xf(sp)])


## "Здесь будет": a dark patch with a chalk outline where the next levels put something (floor things only).
func _chalk(it: Dictionary, out: Array) -> void:
	var ids = it["ids"]
	var id := String(ids) if ids is String else String(ids[ids.keys()[0]])
	var m: ArrayMesh = HousePack.mesh(id)
	if m == null:
		return
	var bb := m.get_aabb()
	var ys: float = 0.0
	for sp in it["spots"]:
		ys = maxf(ys, (sp as Vector4).w)
	if bb.position.y > 0.3 or bb.size.y > 2.3 or (bb.size.x < 0.5 and bb.size.z < 0.5) or ys > 0.0 or absf((it["spots"][0] as Vector4).x) > 3.0 or absf((it["spots"][0] as Vector4).y) > 3.0:
		return
	var chalk := HouseShapes.make("chalk_here")
	for sp in it["spots"]:
		var xf := _xf(Vector4(sp.x, sp.y, sp.z, 0.0))
		xf.basis = xf.basis * Basis.from_scale(Vector3(maxf(bb.size.x, 0.5) / 1.2, 1, maxf(bb.size.z, 0.5) / 1.2))
		out.append([chalk, xf])


## The kids: light figures (HouseShapes) and one real Athlete in a pose (HousePose).
func _cast(_room: String, level: int, parent: Node3D) -> Array:
	var made: Array = []
	var shown_real := false
	for c in HouseLayout.cast(_room):
		if level < int(c.get("from", 1)):
			continue
		var at: Vector4 = c["at"]
		if c["kind"] == "kid":
			var n := MeshInstance3D.new()
			n.mesh = HousePack.mesh(String(c["id"]))
			n.material_override = ClubScenery.prop_material()
			n.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(at.z)), Vector3(at.x, HouseLayout.y_at(c, level), at.y))
			parent.add_child(n)
			made.append(n)
		elif not shown_real:
			shown_real = true
			var pivot := Node3D.new()
			pivot.set_meta("real", true)
			pivot.position = Vector3(at.x, at.w, at.y)
			pivot.rotation.y = deg_to_rad(at.z) + PI
			parent.add_child(pivot)
			var a := Athlete.new()
			pivot.add_child(a)
			a.setup(-1.0, Color(0.9, 0.4, 0.3), Rect2(-20, -20, 40, 40))
			if bool(c.get("elder", false)):
				AthleteCasual.make_elder(a)
			else:
				a.set_look({"skin": 3, "hair": 5, "hair_color": 3, "beard": 0, "head": 0, "shirt": 5, "shorts": 3, "accent": 5})
			AthleteCasual.set_junior(a, float(c.get("junior", 0.85)))
			var pose := String(c["id"])
			if pose == "swing":
				a.prepare(1)
			else:
				HousePose.attach(a, pose, 0.7)
			made.append(pivot)
	return made


# --- the check ---

func _check() -> void:
	var bad := 0
	var rows: Array = []
	for id in HousePackInfo.IDS:
		var code := HouseShapes.make(id)
		if code == null:
			print("NO CODE FORM for pack id ", id)
			bad += 1
			continue
		var pack_n := HousePack.tris(id) if HousePack.has_pack() else -1
		var code_n := (code.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		rows.append([id, pack_n, code_n, HousePackInfo.SIZES.get(id, Vector3.ZERO)])
	for room in HouseLayout.ROOM_ORDER:
		for it in HouseLayout.items(room):
			var ids = it["ids"]
			for id in ([ids] if ids is String else ids.values()):
				if HousePack.mesh(String(id)) == null:
					print("LAYOUT: no mesh for ", id, " in ", room)
					bad += 1
	var tot_pack := 0
	var tot_code := 0
	for r in rows:
		tot_pack += maxi(r[1], 0)
		tot_code += r[2]
	print("pack ids %d, with code forms %d, pack triangles %d, the same ids as code %d, problems %d" % [HousePackInfo.IDS.size(), rows.size(), tot_pack, tot_code, bad])
	var all := HouseShapes.ids()
	var worst := ""
	var worst_n := 0
	for id in all:
		var n := HousePack.tris(id)
		if n > worst_n:
			worst_n = n
			worst = id
	print("%d code ids, heaviest %s (%d triangles in the current mode)" % [all.size(), worst, worst_n])


# --- the gallery -----------------------------------------------------------------------

func _gallery() -> void:
	root.size = Vector2i(1500, 1000)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.84, 0.86, 0.9)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var all: Array = HouseShapes.ids().duplicate()
	for id in HousePackInfo.IDS:
		if not id in all:
			all.append(id)
	var ids: Array = []
	for id in all:
		if String(id).begins_with(prefix) and (room_filter == "" or HouseShapes.room_of(id) == room_filter):
			ids.append(id)
	if ids_wanted.size() > 0:
		ids = ids_wanted
	var big := false
	for id in ids:
		if HouseShapes.room_of(id) == "outside":
			big = true
	var cols := mini(ids.size(), 8 if not big else 3)
	var gap := 3.2 if not big else 16.0
	for i in ids.size():
		var m := HousePack.mesh(ids[i])
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = ClubScenery.prop_material()
		mi.position = Vector3((i % cols) * gap, 0, (i / cols) * gap)
		root.add_child(mi)
		var l := Label3D.new()
		l.text = String(ids[i]) + ("*" if HousePack.in_pack(ids[i]) else "")
		l.font_size = 36
		l.pixel_size = 0.006 * (gap / 3.2) * 0.6
		l.position = mi.position + Vector3(0, 0, gap * 0.4)
		l.rotation = Vector3(-PI * 0.5, 0, 0)
		l.modulate = Color.BLACK
		root.add_child(l)
	var rows := int(ceil(ids.size() / float(cols)))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var cx := (cols - 1) * gap * 0.5
	var cz := (rows - 1) * gap * 0.5
	cam.size = maxf(rows * gap * (0.7 if big else 0.9) + 2.0, cols * gap / 1.5 * 1.05)
	root.add_child(cam)
	var pitch := 24.0 if big else 42.0
	cam.rotation_degrees = Vector3(-pitch, 0, 0)
	cam.position = Vector3(cx, 30.0, cz + 30.0 / tan(deg_to_rad(pitch)))
	cam.current = true
	await create_timer(1.0).timeout
	await process_frame
	var path := ProjectSettings.globalize_path("user://academy_%s_gallery.png" % tag)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
