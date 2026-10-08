extends SceneTree
## The match cameras as the phone sees them (D-4): the bot plays a practice rally and
## the frame is saved with the normal and the TV framing.
##   godot --path . --rendering-driver opengl3 -s tools/camera_shots.gd [-- --size=1480]
## PNGs go to the user data folder as camera_<size>_<mode>_<n>.png (paths printed).

var main: Node
var h := 1564
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
	out = ProjectSettings.globalize_path("user://camera_%d_" % h)
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _run() -> void:
	root.size = Vector2i(720, h)
	var tuning := root.get_node("Tuning")
	main = load("res://scenes/main.tscn").instantiate()
	main.autoplay = true
	root.add_child(main)
	await create_timer(3.0).timeout
	for i in 2:
		for tv in [false, true]:
			tuning.tv_camera = tv
			main.cam.snap()
			await _shot("%s_%d" % ["tv" if tv else "normal", i])
		await create_timer(1.3).timeout
	quit()
