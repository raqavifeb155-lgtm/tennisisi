extends SceneTree
## The four tournament locations in a match, as the phone sees them (stream H-6): a
## practice match in each, the game camera, draw calls and triangles with everything and
## with the two players hidden, and a shot.
##   godot --path . --rendering-driver opengl3 -s tools/loc_shots.gd -- --tag=h6 [--gfx=3] [--size=1480] [--hour=11]
## Prints "LOC id gfx draws tris | world draws tris" lines; PNGs: user://loc_<tag>_<h>_<id>.png

var main: Node
var tag := ""
var gfx := 3
var h := 1564
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
		elif a.begins_with("--gfx="):
			gfx = int(a.get_slice("=", 1))
		elif a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--only="):
			only = a.get_slice("=", 1)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	DisplayServer.window_set_position(Vector2i(rng.randi_range(0, 900), rng.randi_range(0, 120)))
	DisplayServer.window_move_to_foreground()
	_run.call_deferred()


func _measure() -> Vector2:
	for i in 14:
		await process_frame
	var d := 0.0
	var t := 0.0
	for i in 6:
		await process_frame
		d += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		t += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return Vector2(d / 6.0, t / 6.0 / 1000.0)


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
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
	await create_timer(0.5).timeout
	SaveData.control_chosen = true
	main.graphics.set_preset(gfx)
	ClubDaytime.force_hour = 11.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hour="):
			ClubDaytime.force_hour = float(a.get_slice("=", 1))
	for id in ["park", "clay", "grass", "paris"]:
		if only != "" and only != id:
			continue
		main._show_menu()
		await create_timer(0.3).timeout
		main._next_location = id
		main.club.close()
		main._start_practice()
		await create_timer(1.6).timeout
		var all := await _measure()
		# the scenery's own share: the same frame with it hidden
		main.scenery.visible = false
		var without := await _measure()
		main.scenery.visible = true
		await process_frame
		await process_frame
		await process_frame
		var path := ProjectSettings.globalize_path("user://loc_%s%d_%s.png" % [tag, h, id])
		root.get_texture().get_image().save_png(path)
		main.player.visible = false
		main.cpu.visible = false
		var world := await _measure()
		main.player.visible = true
		main.cpu.visible = true
		print("LOC %-6s gfx%d  all %3d draws %5.1fk tris | scenery %3d draws %5.1fk tris" % [id, gfx, all.x, all.y, all.x - without.x, all.y - without.y])
		if "--wide" in OS.get_cmdline_user_args():
			var cam := Camera3D.new()
			cam.fov = 62.0
			cam.far = 700.0
			root.add_child(cam)
			cam.global_position = Vector3(0, 13.0, 36.0)
			cam.look_at(Vector3(0, 0.5, -12.0), Vector3.UP)
			cam.current = true
			await create_timer(0.5).timeout
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("user://loc_%s%d_%s_wide.png" % [tag, h, id]))
			cam.queue_free()
			main.cam.current = true
	quit()
