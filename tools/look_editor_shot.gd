extends SceneTree
## Screenshots of the character editor (the hair tab, the kit tab) in the real game,
## and a check that "done" dresses the player on court:
##   godot --path . --rendering-driver opengl3 -s tools/look_editor_shot.gd -- --out=/tmp/shots
## Writes ui_look_hair.png and ui_look_kit.png.

var out_dir := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var path := ("%s/%s.png" % [out_dir, name]) if out_dir != "" else ProjectSettings.globalize_path("user://%s.png" % name)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	root.size = Vector2i(720, 1560)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var save_data: GDScript = load("res://scripts/save_data.gd")  # loaded late: it needs the autoloads
	save_data.enabled = false  # a tool run never writes the save
	await create_timer(7.0).timeout  # the loading screen
	main.ui.show_look_editor({"hair": Looks.Hair.CURLY, "hair_color": 3, "skin": 5, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.HEADBAND, "accent": 10, "shirt": 7, "shorts": 0})
	await create_timer(1.2).timeout
	await _shot("ui_look_hair")
	var ed: Node = null
	for c in main.ui._box.get_children():
		if c.has_method("_pick"):
			ed = c
	ed._tab = 6  # the shirt
	ed._refresh()
	await create_timer(1.2).timeout
	await _shot("ui_look_kit")
	ed._pick("shirt", 13)
	ed.done.emit(ed.look.duplicate())
	await create_timer(0.3).timeout
	var worn: Dictionary = main.player.look
	print("LOOK_CHECK worn shirt=%d hair=%d · saved shirt=%d" % [worn["shirt"], worn["hair"], int(save_data.look.get("shirt", -1))])
	quit()
