extends SceneTree
## Every HUD state over the court as the phone sees it, for design review (UI_FLOW_TZ):
##   godot --path . --rendering-driver opengl3 -s tools/hud_shots.gd [-- --size=1480] [-- --safe]
## Same sizes as tools/menu_shots.gd: 720x1564 (iPhone 17 Pro Max, default) and 720x1480
## (a small Android). --safe adds Telegram's full-screen insets (180 top, 60 bottom).
## The real code paths run where they can (the trophy mini-game, the point verdicts, the
## pause sheet), so a shot shows what a player sees, overlaps included. PNGs go to the
## user data folder as hud_<size>_<name>.png (paths printed).

var main: Node
var h := 1564
var out := ""
var tag := ""  # --tag=X: X_ in the file names (other worktrees shoot into the same folder)
var safe := false
var only := ""  # --only=smash: just the racket smash (the thread R shots)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		if a == "--safe":
			safe = true
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	out = ProjectSettings.globalize_path("user://hud_%s%d%s_" % [tag, h, "_safe" if safe else ""])
	_run.call_deferred()


func _shot(name: String, wait := 0.25) -> void:
	await create_timer(wait, true, false, true).timeout  # also while the tree is paused
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


## A player-side point verdict exactly as Main builds it (see Main._end_point).
func _verdict(text: String, good: bool) -> void:
	main.hud.show_message(text, main.COLOR_WIN if good else main.COLOR_BAD)


## C-7: the three looks of the opponent's stamina bar at the same moment of a tournament
## match (the serve, the score on, three hits just landed; then calm and tired).
## godot --path . --rendering-driver opengl3 -s tools/hud_shots.gd -- --tag=c7 [--size=1480]
func _opp_bar_shots() -> void:
	var tm := Tournament.new(1)
	SaveData.active = tm
	SaveData.enabled = false
	main.tournament = tm
	main.tournament_mode = true
	main._play_match()
	await create_timer(1.2).timeout
	main.hud._tutorial.visible = false
	paused = false
	main.server = main.Who.PLAYER
	main._setup_serve()
	await create_timer(0.5).timeout
	var s: MatchScore = MatchScore.new(2, 4, 3, 0, "ДЖУМХУР")
	s.games = [3, 2]
	s.points = [2, 3]
	s.server = 0
	main.hud.show_board(s, ["ВЫ", "ДЖУМХУР"])
	var view: OppStaminaView = main.run_hub.view
	view.shown = true
	for st in [0, 1]:  # was (the old bar) / now; 2 and 3 are the other looks to try
		root.get_node("Tuning").opp_bar_style = st
		view.style = st
		paused = false
		Engine.time_scale = 1.0
		view.reset(100.0)
		view.hit(12.0, "run", 88.0)
		view.hit(30.0, "heavy", 58.0)
		view.hit(8.0, "item", 50.0)
		await _shot("c7_style%d_hits" % st, 0.2)
		await create_timer(1.2).timeout
		await _shot("c7_style%d_calm" % st, 0.3)
		view.hit(20.0, "run", 30.0)
		await create_timer(1.3).timeout
		await _shot("c7_style%d_tired" % st, 0.3)


## «Разбить ракетку»: the button after an out ball, the three swipes, the wind-up, the blow, the
## shards in the air and on the court, through SmashHub's own code (a practice match).
func _smash_shots() -> void:
	main._start_practice()
	await create_timer(1.0).timeout
	main.hud._tutorial.visible = false
	paused = false
	main.hud.modals.clear()
	var hub = main.smash_hub
	var sm: RacketSmash = hub.smash
	main.server = main.Who.PLAYER
	main._setup_serve()
	await create_timer(0.6).timeout
	main.phase = main.Phase.RALLY
	main.last_hitter = main.Who.PLAYER
	main.rally = 7
	main.stamina = 0.6
	main._end_point(main.Who.CPU, "OUT")
	await _shot("r1_button", 0.5)
	hub.press()
	await _shot("r2_ready", 0.45)
	sm.progress(0.7)
	await _shot("r3_pulling", 0.3)
	sm.swipe(-1, 0.9)
	await _shot("r4_windup", 0.55)
	sm.swipe(1, 0.9)
	var guard := 0
	while sm.state == RacketSmash.S.STRIKE and guard < 200:
		guard += 1
		await process_frame
	await _shot("r5_blow", 0.0)
	while sm.state != RacketSmash.S.HELD and guard < 600:
		guard += 1
		await process_frame
	await create_timer(0.2).timeout
	sm.swipe(1, 1.0)
	while sm.state != RacketSmash.S.BREAK and guard < 900:
		guard += 1
		await process_frame
	await _shot("r6_shards_fly", 0.12)
	await _shot("r7_shards_fall", 0.35)
	await _shot("r8_handle_left", 1.6)
	await create_timer(1.5).timeout


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	await _shot("00_loader", 0.0)
	await create_timer(6.2).timeout  # the loading screen
	SaveData.control_chosen = true
	if safe:
		main.hud.set_safe_area(180.0, 60.0)
		main.ui.set_safe_area(180.0, 60.0)

	if tag == "c7_":
		await _opp_bar_shots()


	if only == "smash":
		await _smash_shots()
		quit()
		return

	# --- First launch and the Club states the menu shots don't cover -----------
	main.ui.show_controls(true)
	await _shot("01_first_controls", 0.7)
	var resumable := Tournament.new(1)
	SaveData.active = resumable
	main.ui.show_menu()
	await _shot("02_club_resume", 0.7)
	SaveData.active = null
	# "? Как играть" on the Club, as Main._on_ui("howto") does it: the menu stays open.
	main.ui.show_menu()
	await create_timer(0.5).timeout
	main._on_ui("howto", 0)
	await _shot("02b_club_howto")
	main.hud._tutorial.visible = false
	paused = false

	# --- Settings from the Club, then the pause in a match ------------------------
	main.ui.show_menu()
	await create_timer(0.5).timeout
	main.hud._toggle_debug()
	await _shot("03_settings_menu")
	var sheet_scroll: ScrollContainer = main.hud.settings_sheet.scroll
	sheet_scroll.scroll_vertical = 1400
	await _shot("04_settings_scrolled")
	sheet_scroll.scroll_vertical = 100000
	await _shot("05_settings_end")
	sheet_scroll.scroll_vertical = 0
	main.hud._toggle_debug()

	main._start_practice()
	await create_timer(1.0).timeout
	main.hud._tutorial.visible = false
	paused = false
	main.server = main.Who.PLAYER
	main._setup_serve()
	await create_timer(0.4).timeout
	main.hud.show_board(main.scoreboard, ["ВЫ", "CPU"])
	await _shot("06_serve_hint")
	main.hud._toggle_debug()  # in a match: the short pause
	await _shot("07_pause")
	main.hud.open_settings()  # the pause's "Настройки": the sheet over it
	await _shot("07b_pause_settings")
	main.hud.close_settings()
	main.hud._tournament_match = true  # leaving a tournament match asks first
	main.hud._leave()
	await _shot("07c_pause_confirm")
	main.hud._tournament_match = false
	main.hud.resume()

	# --- A match: the score, the ring verdict, level-ups, point verdicts -----------
	var s: MatchScore = MatchScore.new(2, 4, 3, 0, "БАСИЛАШВИЛИ")
	s.set_scores = [[4, 2]]
	s.sets = [1, 0]
	s.games = [3, 2]
	s.points = [2, 3]
	s.server = 1
	main.hud.show_board(s, ["ВЫ", "БАСИЛАШВИЛИ"])
	main.hud.set_rally("розыгрыш · 7")
	main.hud.ring.feedback("PERFECT", Color(1.0, 0.85, 0.25), "FOREHAND · TOPSPIN ×1.3  ·  124 KM/H  ·  92%", 2)
	main.hud.ring.skill_progress("ФОРХЕНД", 4, 0.62)
	main.hud.level_up("ФОРХЕНД 5  ·  104 → 109 км/ч", true)
	main.hud.level_up("НОГИ 3  ·  бег 75% → 78%")
	main.hud.level_up("ВЫНОСЛИВОСТЬ 2  ·  запас 100% → 104%")  # the third waits its turn
	await _shot("08_rally_levelup", 0.3)
	await create_timer(2.5).timeout
	# The longest call there is, with VAR in its reserved slot (Main: verdict, then VAR).
	_verdict("BASILASHVILI DOUBLE FAULT\nGAME · BASILASHVILI", true)
	main.hud.hawkeye(0.012, 0)
	await _shot("09_point_long_hawkeye", 0.2)
	await create_timer(2.8).timeout
	_verdict("BASILASHVILI ACE\nSET · BASILASHVILI", false)
	await _shot("10_point_set_cpu", 0.2)
	await create_timer(2.0).timeout
	# Main._end_point grows "Ноги" / "Выносливость" and shows the verdict in one frame.
	main.hud.level_up("НОГИ 4  ·  бег 78% → 81%")
	_verdict("WINNER!\nGAME · YOU", true)
	await _shot("10b_point_and_levelup", 0.25)
	await create_timer(2.0).timeout
	main.hud.announcer.intro("ВТОРОЙ КРУГ", "Николоз Басилашвили")  # Main._play_match
	await _shot("11_match_intro", 0.3)
	await create_timer(2.2).timeout
	# Stream A's style plate after a won point, as RunHub plays it (its own TOP anchor).
	_verdict("WINNER!", true)
	main.run_hub.plate.show_result({"tricks": [{"name": "С лёта", "x": 1.3}, {"name": "Обводящий", "x": 1.5}], "mult": 1.95, "points": 20})
	await _shot("11b_style_plate", 0.8)
	await create_timer(2.0).timeout
	main.hud.popup("EARLY", main.COLOR_WARN, "свайпни, когда кольцо дойдёт до круга")
	main.stamina = 0.1
	main.hud.set_stamina(0.1)
	await _shot("12_early_tired", 0.2)
	main.stamina = 1.0
	main.hud.set_stamina(1.0)

	# --- The trophy mini-game, through Main's own code ------------------------------
	var t := Tournament.new(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	t.lineup[0]["racket"] = Gear.roll(Gear.LEGENDARY, rng)
	t.record_match(true, "6:3", rng)
	main.tournament = t
	main.tournament_mode = true
	main._stop_match()
	main._start_bonus()
	await _shot("13_trophy_start", 0.3)
	await create_timer(2.0).timeout
	main._bonus_balls = 2
	main._bonus_miss()
	await _shot("14_trophy_miss", 0.25)
	await create_timer(2.0).timeout
	main._bonus_hit()
	await _shot("15_trophy_knockout", 0.25)
	# The player runs over and picks the racket up (Main._bonus_pickup, <= 5 s).
	var waited := 0.0
	while main._bonus_state == 3 and waited < 6.0:
		await process_frame
		waited += 1.0 / 60.0
	await _shot("16_trophy_got_it", 0.15)
	await create_timer(2.5).timeout
	main.ui.close()  # _end_bonus has opened the result by now
	main.tournament.pending_loot = Gear.roll(Gear.EPIC, rng)
	main._start_bonus()
	await create_timer(2.0).timeout
	main._bonus_balls = 1
	main._bonus_miss()
	await _shot("17_trophy_lost", 0.25)
	await create_timer(2.5).timeout

	# --- The result screens the menu shots don't cover -------------------------
	main._stop_match()
	var lost := Tournament.new(1)
	lost.wildcards = 1
	lost.record_match(false, "3:6", rng)
	main.tournament = lost
	var tl: MatchTally = main.hud.tally  # the match stats table (C-5): typical numbers
	tl.start()
	tl.aces = [3, 1]
	tl.doubles = [1, 2]
	tl.winners = [9, 5]
	tl.unforced = [7, 12]
	tl.serve_points = [30, 28]
	tl.first_faults = [10, 12]
	tl.forehands = [41, 38]
	tl.backhands = [22, 30]
	tl.best_rally = 14
	tl.points = 58
	tl.finish()
	main.ui.show_result(lost, false, "3:6", {"perfect": 2, "aces": 0, "best_rally": 6})
	await _shot("18_result_lost", 0.7)
	var champ := Tournament.new(1)
	for i in champ.rounds():
		champ.record_match(true, "6:2", rng)
		if champ.state == Tournament.State.REWARD:
			champ.take_reward(2)
		champ.pending_loot = {}
	main.tournament = champ
	main.ui.show_summary(champ)
	await _shot("19_summary_champion", 0.7)

	# --- The tutorial, the three wordiest pages ------------------------------------
	main.ui.close()
	main.hud.open_tutorial()
	await _shot("20_tutorial_1_run")
	main.hud._tutorial._advance()
	main.hud._tutorial._advance()
	await _shot("21_tutorial_3_spin")
	main.hud._tutorial._advance()
	await _shot("22_tutorial_4_serve")
	quit()
