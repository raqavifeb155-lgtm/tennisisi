extends SceneTree
## The adult hero beside a junior (0.7 and 0.85) and the old coach (stream H-8): standing, from
## the front, then walking, from the side.
##   godot --path . --rendering-driver opengl3 -s tools/npc_shots.gd -- --tag=h8
## PNGs: user://npc_<tag>_stand.png, _walk_<n>.png

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	DisplayServer.window_set_position(Vector2i(rng.randi_range(0, 900), rng.randi_range(0, 120)))
	DisplayServer.window_move_to_foreground()
	_run.call_deferred()


func _run() -> void:
	var tag := "npc"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.get_slice("=", 1)
	root.size = Vector2i(900, 520)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SaveData.enabled = false
	await create_timer(3.0).timeout
	for i in 60:
		var loading := false
		for c in main.get_children():
			if c is CanvasLayer and (c as CanvasLayer).layer == 100:
				loading = true
		if not loading:
			break
		await create_timer(0.5).timeout
	SaveData.control_chosen = true
	SaveData.club = {"met_coach": true, "walk_hint": true}
	ClubDaytime.force_hour = 11.0
	main._show_menu()
	await create_timer(0.6).timeout
	main.club.hud.visible = false
	main.club.set_process(false)
	main.club.set_physics_process(false)
	main.cpu.visible = false
	var hero: Athlete = main.player
	hero.area = Rect2(-60, -40, 120, 100)
	var cast: Array[Athlete] = [hero]
	for spec in [["junior", 0.7], ["junior", 0.85], ["elder", 1.0]]:
		var a := Athlete.new()
		root.add_child(a)
		a.setup(-1.0, Color(0.9, 0.4, 0.3), Rect2(-60, -40, 120, 100))
		a.set_look({"skin": 3, "hair": 5, "hair_color": 3, "beard": 0, "head": 0, "shirt": 5, "shorts": 3, "accent": 5} if spec[0] == "junior" else AthleteCasual.ELDER_LOOK)
		if spec[0] == "junior":
			AthleteCasual.set_junior(a, spec[1])
		else:
			AthleteCasual.make_elder(a)
		cast.append(a)
	for i in cast.size():
		cast[i].set_meta("casual", true)
		cast[i].position = Vector3(-2.4 + i * 1.6, 0, 33.0)
		cast[i].rotation.y = PI * 0.0
	await create_timer(0.8).timeout
	var cam := Camera3D.new()
	cam.fov = 36.0
	cam.near = 0.3
	root.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0.0, 1.45, 28.2)
	cam.look_at(Vector3(0.0, 0.95, 33.0), Vector3.UP)
	await create_timer(0.4).timeout
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("user://npc_%s_stand.png" % tag))
	# walking, from the side: three frames of a jog, then a walk
	for i in cast.size():
		cast[i].rotation.y = -PI * 0.5
		cast[i].position = Vector3(-12.0, 0, 31.0 + i * 1.5)
		cast[i].max_speed = 4.4
		cast[i].area = Rect2(-60, -40, 120, 100)
	cam.global_position = Vector3(-10.0, 1.4, 24.5)
	cam.look_at(Vector3(-10.0, 0.95, 31.0 + 2.2), Vector3.UP)
	cam.fov = 48.0
	for mode in ["jog", "walk"]:
		for a in cast:
			a.max_speed = 4.4 if mode == "jog" else 1.4
		for n in 3:
			for a in cast:
				a.move_input = Vector2(1, 0)
			await create_timer(0.28 if n > 0 else 0.9).timeout
			for a in cast:
				cam.global_position.x = lerpf(cam.global_position.x, a.position.x, 0.0)
			var cx := cast[0].position.x
			cam.global_position = Vector3(cx + 0.5, 1.4, 24.8)
			cam.look_at(Vector3(cx + 0.5, 0.95, 33.0), Vector3.UP)
			await process_frame
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("user://npc_%s_%s_%d.png" % [tag, mode, n]))
		for a in cast:
			a.position.x = -12.0
	quit()
