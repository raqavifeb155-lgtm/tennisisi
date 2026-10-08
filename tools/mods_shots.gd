extends SceneTree
## Stream G's screens and the court with a modifier on it, as the phone sees them:
##   godot --path . --rendering-driver opengl3 -s tools/mods_shots.gd -- --tag=g [--size=1480]
## 720x1564 (default) or 720x1480; PNGs go to user://mods_<tag>_<size>_*.png (path printed).

var main: Node
var h := 1564
var out := ""
var tag := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://mods_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String, wait := 0.7) -> void:
	await create_timer(wait).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _court(ids: Array, hidden: Array, name: String, wait := 2.2) -> void:
	main._stop_match()
	await create_timer(0.2).timeout
	var t: Tournament = main.tournament
	t.lineup[t.stage]["mods"] = ids
	t.lineup[t.stage]["hidden"] = hidden
	main._play_match()
	await _shot(name, wait)


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	SaveData.enabled = false
	SaveData.played = 3
	main._show_menu()
	main.ui.show_formats()
	RunMods.picked = []
	RunMods.show(main.ui, true)
	await _shot("01_run_none")
	RunMods.ui_action(main, "mods_preset", 0)
	await _shot("02_run_pro")
	RunMods.ui_action(main, "mods_toggle", 8)
	main.ui._scroll.scroll_vertical = 700
	await _shot("03_run_three_full", 0.5)
	main.ui._scroll.scroll_vertical = 2400
	await _shot("04_run_court_group", 0.5)
	var t := Tournament.new(1, 11)
	Modifiers.set_run(t, ["short_ring", "tier_up", "fog"])
	t.lineup[1]["mods"] = ["fast", "wall"]
	t.lineup[2]["mods"] = ["fog", "moon"]
	t.lineup[2]["hidden"] = ["moon"]
	t.lineup[3]["mods"] = ["giant", "showman"]
	main.tournament = t
	main.tournament_mode = true
	main.ui.show_bracket(t)
	await _shot("05_bracket")
	t.stage = 2
	main.ui.show_bracket(t)
	await _shot("06_bracket_hidden")
	t.stage = 1
	await _court(["wall"], [], "07_court_aura_wall")
	await _court(["fog", "marathoner"], [], "08_court_fog", 3.0)
	await _court(["night"], [], "09_court_night", 3.0)
	await _court(["narrow"], [], "10_court_narrow")
	await _court(["moon", "echo"], ["moon"], "11_court_hidden_aura")
	await _court(["giant_ball", "wind"], [], "12_court_giant_ball_wind", 3.0)
	quit()
