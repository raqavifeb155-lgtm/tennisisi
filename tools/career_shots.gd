extends SceneTree
## The career's screens (L1) as the phone sees them:
##   godot --path . --rendering-driver opengl3 -s tools/career_shots.gd [-- --size=1480] [--tag=l]
## The bracket with the season's calendar, the Тренерская with the career card and the quiet
## «Завершить карьеру», the run's summary that leads to the season's summary, the season's
## summary before the farewell season, and the ceremony: the numbers, the relic, the heir out
## of three, the new player of the club. PNGs go to the user data folder (path printed).

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
	out = ProjectSettings.globalize_path("user://career_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String) -> void:
	await create_timer(0.9).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


## A closed run through SaveData.record_run (the career counts it).
func _close(stage: int, champion := false, loc := "park") -> Tournament:
	var t := Tournament.new(1, 100 + stage)
	t.location = loc
	t.results = [{"stage": stage, "won": champion, "score": "6:3"}]
	t.stage = 5 if champion else stage
	t.champion = champion
	t.state = Tournament.State.OVER
	SaveData.record_run(t)
	return t


func _item(rarity: int, slot: String, seed_v: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return Gear.roll(rarity, r, slot)


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	SaveData.enabled = false  # look, don't touch the player's progress
	Skills.pending = []
	SaveData.career = {}
	SaveData.titles = 1
	SaveData.titles_by_loc = {"park": 1}
	for id in Skills.LIST:
		Skills.add_xp(id, 1500.0)
	Skills.pending = []
	# Season 2, two runs in: the bracket's calendar.
	for st in [1, 2, 0, 3]:
		_close(st)
	SaveData.career["season_due"] = 0
	_close(2, false, "clay")
	_close(5, true, "clay")
	var t := Tournament.new(1, 7)
	t.location = "clay"
	main.tournament = t
	main.tournament_mode = true
	main.ui.show_bracket(t)
	await _shot("01_bracket")
	_close(1)  # the 3rd: the final is next
	var tf := Tournament.new(1, 8)
	tf.location = Career.final_loc()
	main.ui.show_bracket(tf)
	await _shot("02_bracket_final")
	# The 4th run closes the season: the summary leads to the season's summary.
	var t4 := _close(3, false, Career.final_loc())
	main.tournament = t4
	main.ui.show_summary(t4)
	await create_timer(2.5).timeout
	await _shot("03_summary_season")
	main._on_ui("career_season", 0)
	await _shot("04_season")
	# Season 3: the Тренерская with the quiet early retirement.
	for st in [0, 1]:
		_close(st)
	main.ui.show_character()
	await _shot("05_coach")
	# Season 4 over: the summary before the farewell season.
	for st in [1, 0, 2, 4, 2, 1]:
		_close(st)
	main._on_ui("career_season", 0)
	await _shot("06_season_farewell")
	# The ceremony after the 20th.
	for st in [2, 1, 3, 0]:
		_close(st, false, Career.final_loc() if Career.is_final_next() else "park")
	Locker.items().append(_item(Gear.RARE, "band", 3))
	var last := Tournament.new(1, 77)
	last.equip["racket"] = _item(Gear.EPIC, "racket", 4)
	last.equip["shoes"] = _item(Gear.RARE, "shoes", 5)
	last.bag = [_item(Gear.LEGENDARY, "racket", 6)]
	last.banked = true
	last.state = Tournament.State.OVER
	main.tournament = last
	main.ui.show_summary(last)
	await create_timer(2.5).timeout
	await _shot("07_summary_farewell")
	main._on_ui("career_retire", 0)
	await _shot("08_retire")
	main._on_ui("career_relic_go", 0)
	await _shot("09_relic")
	main._on_ui("career_relic", 2)
	await _shot("10_heirs")
	main._on_ui("career_heir", 1)
	await _shot("11_heir_picked")
	main._on_ui("career_heir_go", 0)
	await _shot("12_welcome")
	quit()
