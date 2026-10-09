extends SceneTree
## The students' matches as the phone sees them (T-4): the booth (list, card), the match in both
## cameras, the coach's pause with four setups, the plate «Установка», the result, the coach's office
## with its button. A student of two stands in the academy, one run is played.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/junior_shots.gd -- --tag=m [--size=1564]
## PNGs go to the user data folder as junior_<tag>_<h>_<name>.png (path printed). Nothing is saved.

var main: Node
var h := 1564
var tag := ""
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://junior_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String, wait := 0.8) -> void:
	await create_timer(wait, true, false, true).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _run() -> void:
	root.size = Vector2i(720, h)
	SaveData.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	var boot := 0.0
	while boot < 60.0 and not main.find_children("*", "BootLoader", false, false).is_empty():
		await create_timer(0.1).timeout
		boot += 0.1
	await create_timer(1.0).timeout
	SaveData.control_chosen = true
	Skills.pending = []
	SaveData.club = {}
	SaveData.academy = {}
	SaveData.played = 3
	var list := JuniorGen.candidates(77, 3, 1)
	for i in 2:
		var st: Dictionary = (list[i] as Dictionary).duplicate(true)
		st["id"] = "s%d" % (i + 1)
		st["age0"] = int(st["age"])
		st["since"] = 1
		(Academy.data()["students"] as Array).append(st)
	JuniorMatch.sync()
	main._show_menu()
	await create_timer(1.5).timeout
	var club = main.club
	club.ui_action("club_students", 0)
	await _shot("office", 1.0)
	club.ui_action("club_booth", 0)
	await _shot("booth", 1.0)
	club.ui_action("club_match_pick", 0)
	await _shot("card", 1.0)
	club.ui_action("club_match_watch", 0)
	var w: JuniorWatch = main.get_node("JuniorWatch")
	await _shot("live_booth_a", 4.0)
	await _shot("live_booth_b", 3.0)
	w._toggle_camera()
	await _shot("live_match_a", 2.5)
	await _shot("live_match_b", 3.0)
	w._toggle_camera()
	var options := JuniorBot.options_for("behind", true)
	w._ask("behind", options)
	await _shot("advice", 1.0)
	w._on_picked(String(options[1]))
	await _shot("plate_a", 1.5)
	await _shot("plate_b", 3.0)
	w.finish_instant(false)
	await _shot("result", 1.2)
	quit()
