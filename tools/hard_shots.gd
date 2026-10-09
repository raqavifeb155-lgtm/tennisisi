extends SceneTree
## G-6: the mode cards of the conditions screen and the hardcore bracket:
##   godot --path . --rendering-driver opengl3 -s tools/hard_shots.gd -- --tag=g6 [--size=1480]
## PNGs: user://hard_<tag>_<size>_*.png

var main: Node
var RM: GDScript
var h := 1564
var out := ""


func _initialize() -> void:
	var tag := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://hard_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String, wait := 0.7) -> void:
	await create_timer(wait).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	RM = load("res://scripts/ui/screens/run_mods.gd")
	SaveData.control_chosen = true
	SaveData.enabled = false
	SaveData.played = 4
	SaveData.titles = 0
	main._show_menu()
	main.club.close()
	main.ui.show_formats()
	RM.open(main, 1)
	await _shot("01_locked")
	SaveData.titles = 1
	RM.open(main, 1)
	await _shot("02_normal")
	RM.ui_action(main, "mods_mode", 1)
	print("hardcore=", RM.hardcore, " titles=", SaveData.titles, " rows=", main.ui._box.get_child_count())
	await _shot("03_hardcore")
	RM.ui_action(main, "mods_toggle", 3)
	RM.ui_action(main, "mods_toggle", RM.choices().size() - 1)  # the rotation shows 6..8
	main.ui._scroll.scroll_vertical = 500
	await _shot("04_hardcore_picks", 0.5)
	RM.ui_action(main, "mods_go", 0)
	await _shot("05_bracket", 1.0)
	var t: Tournament = main.tournament
	t.record_match(true, "6:3", RandomNumberGenerator.new())
	main.ui.show_result(t, true, "6:3", {"perfect": 5, "aces": 2, "best_rally": 9})
	await _shot("06_result", 1.0)
	quit()
