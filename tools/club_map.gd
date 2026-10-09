extends SceneTree
## The whole club from straight above (an orthographic camera), without trees, props and people,
## to see how the paths lie (stream H-7).
##   godot --path . --rendering-driver opengl3 -s tools/club_map.gd -- --tag=h7 [--gfx=3]
## PNG: user://map_<tag>_1564.png (720 x 1564, the club in the middle)

var main: Node


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	DisplayServer.window_set_position(Vector2i(rng.randi_range(0, 900), rng.randi_range(0, 120)))
	DisplayServer.window_move_to_foreground()
	_run.call_deferred()


func _run() -> void:
	var tag := "map"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.get_slice("=", 1)
	root.size = Vector2i(720, 1564)
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
	SaveData.control_chosen = true
	SaveData.club = {"met_coach": true, "walk_hint": true}
	SaveData.played = 1
	var dt := "res://scripts/club/world/club_daytime.gd"
	if ResourceLoader.exists(dt):
		(load(dt) as GDScript).set("force_hour", 11.0)   # the morning, not the clock's evening
	main._show_menu()
	main.graphics.set_preset(3)
	await create_timer(1.0).timeout
	main.club.hud.visible = false
	main.player.visible = false
	main.cpu.visible = false
	var cs = main.scenery.get_node_or_null("ClubScenery")
	if cs:
		for c in cs.get_children():
			if c is MeshInstance3D and (c.name.begins_with("props_") or c.name == "islands"):
				c.visible = false
			elif c.name in ["crowd", "backdrop"]:
				c.visible = false
	for c in main.scenery.get_children():
		if c is MultiMeshInstance3D:
			c.visible = false     # the old park's trees and bushes
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 128.0
	cam.far = 400.0
	root.add_child(cam)
	cam.global_position = Vector3(0, 120, 4)
	cam.look_at(Vector3(0, 0, 4), Vector3(0, 0, -1))
	cam.current = true
	await create_timer(1.2).timeout
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("user://map_%s_1564.png" % tag))
	print("saved map ", tag)
	quit()
