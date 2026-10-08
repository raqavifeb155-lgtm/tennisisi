extends SceneTree
## The club as the phone sees it (docs/club/H1_SPEC.md 9), for design review:
##   godot --path . --rendering-driver opengl3 -s tools/club_shots.gd [-- --size=1480] [--gfx=1]
## 720x1564 = iPhone 17 Pro Max (440x956), --size=1480 = a small Android (360x740).
## PNGs go to the user data folder (path printed). Never writes the save.
## --gfx=N: graphics preset (1 Low .. 4 Max), and the draw calls are printed per shot.
## --builds: H2 - every construction at every level, the foreman, the build moment, and
## the whole club at the top (its draw calls).

var main: Node
var h := 1564
var gfx := -1
var out := ""
var builds := false
var tag := ""          # --tag=X: club_X_<h>_*.png (other worktrees shoot into the same folder)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--gfx="):
			gfx = int(a.get_slice("=", 1))
		elif a == "--builds":
			builds = true
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://club_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String, settle := 0.8) -> void:
	await create_timer(settle).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	var d := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var t := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	# The club's own budget is for the world: the same frame without the two people.
	var pv: bool = main.player.visible
	var cv: bool = main.cpu.visible
	main.player.visible = false
	main.cpu.visible = false
	await process_frame
	await process_frame
	var wd := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var wt := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	main.player.visible = pv
	main.cpu.visible = cv
	print("saved %s%s.png   draws %d  tris %.1fk   world: draws %d  tris %.1fk" % [out, name, d, t, wd, wt])


func _go(id: String) -> void:
	main.club._travel(id)


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SaveData.enabled = false  # look, don't touch the player's progress
	await create_timer(7.0).timeout  # loading screen
	if gfx >= 0:
		main.graphics.set_preset(gfx)
	SaveData.control_chosen = true
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	Skills.points = 2
	Skills.pending = []
	main._show_menu()
	print("club active=%s location=%s scenery=%s" % [main.club.active, main.location_id, main.scenery.get_script().resource_path])
	if builds:
		await _builds()
		quit()
		return
	await _shot("01_start", 1.6)
	main.club.hud._toggle_travel(true)
	await _shot("02_travel", 0.4)
	main.club.hud._toggle_travel(false)
	_go("coach")
	await _shot("03_coach_room")
	SaveData.played = 1
	main.club._refresh()
	_go("locker")
	await _shot("04_locker_room")
	# Out on the path between the pavilions: the walk, the signs, the arena site.
	main.player.position = Vector3(-6, 0, 31)
	main.club._update_place()
	await _shot("05_path", 1.2)
	main.player.position = Vector3(-14, 0, -18)
	await _shot("06_trophy_sign", 1.6)
	var t := Tournament.new(1)
	t.stage = 3
	SaveData.active = t
	SaveData.club = {"last_location": "clay", "last_format": 1, "met_coach": true}
	_go("court")
	await _shot("07_continue", 1.2)
	SaveData.active = null
	main.club._place = ""
	main.club._update_place()
	await _shot("08_last_tournament", 0.6)
	# B-2: the places.
	_go("machine")
	await _shot("09_machine", 1.0)
	_go("shop")
	await _shot("10_shop_room", 1.0)
	main.club._on_choice("club_shop", 0)
	await _shot("11_shop_screen", 0.8)
	main._on_ui("menu", 0)
	SaveData.titles = 1
	SaveData.gold = 420
	main.club._refresh()
	_go("bar")
	await _shot("12_bar", 1.2)
	main.club._on_choice("club_roulette", 0)
	await _shot("13_roulette", 1.0)
	main.club.spin("red", 25)
	await _shot("14_roulette_spin", 2.2)
	main.club.roulette_skip()
	await _shot("15_roulette_result", 0.5)
	main.club.roulette_close()
	_go("arena")
	await create_timer(0.6).timeout
	main.club._on_choice("club_place", 0)
	await _shot("16_arena_card", 0.8)
	main._on_ui("menu", 0)
	# Hub: the coach's quests, collecting, blackjack, the islands.
	var run := Tournament.new(1)
	SaveData.active = run
	SaveData.club["quests"] = {"run": str(run.rng.seed), "issued": 3, "claimed": 0, "list": [
		ClubQuests._make(ClubQuests.find_template("aces"), 0, false),
		ClubQuests._make(ClubQuests.find_template("rally"), 0, false),
		ClubQuests._make(ClubQuests.find_template("wins"), 0, true)]}
	var ql: Array = ClubQuests.current()
	ql[0]["have"] = ql[0]["need"]
	ql[0]["done"] = true
	ql[1]["have"] = 12
	ql[2]["have"] = 1
	main.club.world.set_board(ClubQuests.board_text())
	_go("coach")
	await _shot("17_coach_board", 1.0)
	main.club._on_choice("club_quests", 0)
	await _shot("18_quests_screen", 0.8)
	main._on_ui("menu", 0)
	main.club._on_choice("club_claim", 0)
	await _shot("19_claimed", 0.6)
	_go("blackjack")
	await _shot("20_blackjack", 1.0)
	_go("court")
	await create_timer(0.4).timeout
	main.club._on_choice("club_locations", 0)
	await _shot("21_islands", 0.8)
	main._on_ui("menu", 0)
	quit()


func _builds() -> void:
	var club = main.club
	SaveData.played = 3
	SaveData.titles = 4
	SaveData.gold = 380
	SaveData.club = {"met_coach": true}
	club._refresh()
	club.hud.say("", 0.0)
	club._travel("gate")
	await create_timer(0.4).timeout
	club._on_choice("club_foreman", 0)
	club.foreman_show("stands")
	await _shot("b01_foreman_stands_ghost", 1.0)
	club.foreman_show("court")
	await _shot("b02_foreman_court", 0.8)
	club.foreman_show("shop")
	await _shot("b02_foreman_shop_ghost", 0.8)
	club.foreman_build()
	await _shot("b03_build_moment", 0.75)
	club.skip_build()
	await _shot("b04_built_court1", 0.8)
	SaveData.gold = 20
	club.foreman_show("gate")
	await _shot("b05_need_more", 0.8)
	SaveData.club["levels"] = {"bar": 3}
	club._refresh()
	club.foreman_show("bar")
	await _shot("b06_maximum", 0.8)
	club.foreman_close()
	# Every level of every construction, framed as on the foreman's card.
	for id in ClubBuilds.ORDER:
		for lv in range(1, ClubBuilds.max_level(id) + 1):
			var levels: Dictionary = SaveData.club.get("levels", {}).duplicate()
			levels[id] = lv
			SaveData.club["levels"] = levels
			if id == "court" and lv >= 3:
				SaveData.club["color"] = 2
			club._refresh()
			var view: Array = club.BUILD_VIEW[id]
			club.cam.frame(view[0], view[1], 0.0)
			club.world.focus_room(id)
			club.hud.visible = false
			await _shot("b_%s_%d" % [id, lv], 0.5)
	# The whole club at the top, from the start: the budget with everything built.
	club.world.focus_room("")
	club.cam.release(0.0)
	club._travel("court")
	await _shot("b99_all_max_start", 1.0)
	main.player.position = Vector3(14.6, 0, 6.0)
	club._update_place()
	await _shot("b99_all_max_east", 1.2)
