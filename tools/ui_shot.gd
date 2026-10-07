extends SceneTree
## Screenshots of the match HUD (score bug) and the settings sheet, for design checks:
##   godot --path . --rendering-driver opengl3 -s tools/ui_shot.gd
## Writes ui_score.png and ui_settings.png into the user data folder (path printed).

func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var path := ProjectSettings.globalize_path("user://%s.png" % name)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	root.size = Vector2i(720, 1560)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	await _shot("ui_loader")
	await create_timer(6.4).timeout  # the loading screen
	main._start_practice()
	await create_timer(1.0).timeout
	main.hud._tutorial.visible = false
	paused = false  # the tutorial pauses the game until it is closed
	main.server = main.Who.PLAYER
	root.get_node("Tuning").tap_controls = true  # shows the serve hint as well
	main._setup_serve()
	await create_timer(0.3).timeout
	var s: MatchScore = MatchScore.new(2, 4, 3, 0, "Рублёв")
	s.set_scores = [[4, 2]]
	s.sets = [1, 0]
	s.games = [3, 2]
	s.points = [2, 3]
	s.server = 1
	main.hud.show_board(s, ["ВЫ", "РУБЛЁВ"])
	if "--safe" in OS.get_cmdline_user_args():  # as in Telegram's full screen on an iPhone
		main.hud.set_safe_area(180.0, 60.0)
		main.ui.set_safe_area(180.0, 60.0)
		root.get_node("Tuning").tap_controls = false  # show the joystick ring
		main.hud.hawkeye(0.012, 0)  # a close call: the VAR panel
		main.stamina = 0.55  # a tired player: the arc has lost its green end
		main.hud.ring.feedback("PERFECT", Color(1.0, 0.85, 0.25), "FOREHAND · TOPSPIN · 124 km/h", 2)
		main.hud.ring.skill_progress("ФОРХЕНД", 3, 0.62)
		main.hud.level_up("+1 ФОРХЕНД  ·  ур. 4")
	main.hud.set_rally("розыгрыш · 7")
	await create_timer(0.25).timeout
	await _shot("ui_score")
	main.hud._toggle_debug()
	await _shot("ui_settings")
	quit()
