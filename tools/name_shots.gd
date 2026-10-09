extends SceneTree
## The hero's name as the phone sees it:
##   godot --path . --rendering-driver opengl3 -s tools/name_shots.gd [-- --size=1480] [--tag=n]
## The club plate, the Раздевалка row, the look editor's name row (free change, paid, too poor),
## the rename screen (free, typed, paid, too poor, a long name), the match board with the hero's name.

var main: Node
var h := 1564
var out := ""
var tag := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
	out = ProjectSettings.globalize_path("user://name_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String) -> void:
	await create_timer(0.9).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	SaveData.enabled = false
	Skills.pending = []
	SaveData.career = {}
	SaveData.gold = 240
	Career.data()["name"] = "Александрович"
	main.ui.show_menu()
	await _shot("01_menu")
	main.ui.show_locker()
	await _shot("02_locker")
	main._on_ui("look", 0)
	await _shot("03_look_free")
	main._on_ui("career_rename", 1)
	await _shot("04_rename_free")
	var edit: LineEdit = main.ui.root.find_children("*", "LineEdit", true, false)[0]
	edit.text = "Тимур"
	edit.text_changed.emit("Тимур")
	await _shot("05_rename_typed")
	main._on_ui("career_rename_ok", 0)  # the free one: back to the look editor
	await _shot("06_look_paid")
	main._on_ui("career_rename", 1)
	edit = main.ui.root.find_children("*", "LineEdit", true, false)[0]
	edit.text = "Анна-Мария 7"
	edit.text_changed.emit(edit.text)
	await _shot("07_rename_paid")
	SaveData.gold = 40
	main._on_ui("career_rename_back", 0)
	await _shot("08_look_poor")
	main._on_ui("career_rename", 1)
	await _shot("09_rename_poor")
	SaveData.gold = 240
	main._on_ui("career_rename_back", 0)
	main.ui.show_menu()
	Career.data()["name"] = "Александрович"
	main.player.set_look(SaveData.look)
	main._start_practice()
	await create_timer(2.0).timeout
	await _shot("10_match_board")
	quit()
