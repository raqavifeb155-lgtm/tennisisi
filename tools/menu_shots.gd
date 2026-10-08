extends SceneTree
## Every menu screen as the phone sees it, for design review (UI_MENU_TZ 10, 12):
##   godot --path . --rendering-driver opengl3 -s tools/menu_shots.gd [-- --size=1564]
## The project stretches to a 720-wide canvas, so a phone's height in that canvas is
## 720 * h / w: iPhone 17 Pro Max 440x956 -> 720x1564 (default), a small Android
## 360x740 -> 720x1480 (--size=1480). PNGs go to the user data folder (path printed).
## The first shot is the club (the main screen since v0.2 B); -- --old-menu: the old list.

var main: Node
var h := 1564
var out := ""
var tag := ""                     # --tag=d: the shots of one stream go into their own files (all worktrees share user://)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://%smenu_%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String) -> void:
	await create_timer(0.7).timeout  # entrance animations and card flips settle
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout  # loading screen
	SaveData.control_chosen = true
	SaveData.enabled = false  # look, don't touch the player's progress
	Skills.points = 2
	Skills.pending = []
	main._show_menu()  # the club (scripts/club); with -- --old-menu the old list
	await _shot("01_club")
	main.ui.show_locker()
	await _shot("02_locker")
	main.ui.show_character()
	await _shot("03_coach")
	main.ui.show_controls(false)
	await _shot("04_controls")
	main.ui.show_locations()
	await _shot("05_locations")
	main.ui.show_formats()
	await _shot("06_formats")
	var t := Tournament.new(1)
	main.tournament = t
	main.ui.show_bracket(t)
	await _shot("07_bracket")
	t.lineup[0]["golden"] = true
	main.ui.show_opponent_card(t, 0)  # D-5: the card of the opponent, golden, before "Играть"
	await _shot("07b_opponent_card")
	t.lineup[0]["golden"] = false
	t.lineup[4]["mods"] = ["fast", "steady"]
	main.ui.show_opponent_card(t, 4)  # the boss with auras (the strongest stats, a long list)
	await _shot("07c_boss_card")
	t.lineup[4]["mods"] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	t.lineup[0]["racket"] = Gear.roll(Gear.EPIC, rng)
	t.record_match(true, "6:3", rng)
	main.ui.show_result(t, true, "6:3", {"perfect": 12, "aces": 3, "best_rally": 14})
	await _shot("08_result")
	main.ui.show_loot(t)
	await _shot("09_loot")
	t.take_loot(false)
	main.ui.show_reward(t)
	await create_timer(1.0).timeout
	await _shot("10_reward")
	main.ui.show_skill_perk("forehand", Skills.PERKS["forehand"].slice(0, 3))
	await _shot("11_perk")
	t.state = Tournament.State.OVER
	main.ui.show_summary(t)
	await _shot("12_summary")
	main.ui.show_look_editor(Looks.sanitize(SaveData.look))
	await _shot("13_look")
	quit()
