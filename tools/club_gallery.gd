extends SceneTree
## Every prop of the model pack (and its simple form, behind) on a grid, lit like the
## club: to check colours, sizes and which way each one faces (stream H).
##   godot --path . --rendering-driver opengl3 -s tools/club_gallery.gd [-- --simple]
## --simple: the forms made in code (ClubShapes) instead of the pack.
## PNG: user://club_gallery.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 900)
	var simple := "--simple" in OS.get_cmdline_user_args()
	var host := Node.new()
	root.add_child(host)
	if not simple:
		ClubPack.request(host)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.84, 0.86, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 1.1
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.62, 0.34)
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	var ids: Array = ClubPackInfo.IDS
	var cols := 8
	var gap := 3.2
	var y_of := {}
	for i in ids.size():
		var id: String = ids[i]
		var m: ArrayMesh = ClubShapes.make(id) if simple else ClubPack.mesh(id)
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = ClubScenery.prop_material()
		var big := m.get_aabb().size.length() > 7.0
		var sc := 0.3 if big else 1.0
		mi.scale = Vector3.ONE * sc
		mi.position = Vector3((i % cols) * gap, 0.0, (i / cols) * gap)
		root.add_child(mi)
		var l := Label3D.new()
		l.text = id
		l.font_size = 40
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = mi.position + Vector3(0, -0.0, 1.4)
		l.rotation_degrees.x = -90
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		l.modulate = Color.BLACK
		root.add_child(l)
	var cam := Camera3D.new()
	var rows := int(ceil(ids.size() / float(cols)))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rows * gap * 1.05
	var cx := (cols - 1) * gap * 0.5
	var cz := (rows - 1) * gap * 0.5
	cam.position = Vector3(cx, 30.0, cz + 22.0)
	root.add_child(cam)
	cam.look_at(Vector3(cx, 0.0, cz + 1.0), Vector3.UP)
	cam.current = true
	await create_timer(1.0).timeout
	await process_frame
	var path := ProjectSettings.globalize_path("user://club_gallery%s.png" % ("_simple" if simple else ""))
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	quit()
