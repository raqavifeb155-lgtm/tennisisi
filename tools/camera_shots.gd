extends SceneTree
## The match cameras as the phone sees them (D-4): the bot plays a practice rally and
## the frame is saved with the normal and the TV framing.
##   godot --path . --rendering-driver opengl3 -s tools/camera_shots.gd [-- --size=1480]
## PNGs go to the user data folder as camera_<size>_<mode>_<n>.png (paths printed).

var main: Node
var h := 1564
var out := ""
var loc := ""                     # --loc=park|clay|grass|paris: shoot that island
var tag := ""                     # --tag=d: own file names (all worktrees share user://)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--loc="):
			loc = a.get_slice("=", 1)
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://%scamera_%d_%s" % [tag, h, loc + "_" if loc != "" else ""])
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
	if loc != "":
		main.set_location(loc)
	await create_timer(3.0).timeout
	for i in 2:
		for mode in ["normal", "tv", "booth", "booth_wide"]:  # booth: D-6, the coach's booth (and its wide plan between points)
			tuning.tv_camera = mode == "tv"
			main.cam.booth = mode.begins_with("booth")
			main.cam.booth_wide = mode == "booth_wide"
			main.cam.snap()
			await _shot("%s_%d" % [mode, i])
		await create_timer(1.3).timeout
	quit()
