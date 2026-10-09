extends SceneTree
## The bookmaker (stream E, E-5) as the phone sees it:
##   godot --path . --rendering-driver opengl3 -s tools/bookie_shots.gd [-- --size=1480] [--tag=e]
## 720x1564 = iPhone 17 Pro Max, --size=1480 = a small Android. PNGs go to the user data
## folder: bookie_<tag>_<h>_*.png (path printed). Never writes the save.
##   1 the bar's bookmaker over the club, a run in the bracket (both sides, the history)
##   2 the same after a bet against yourself
##   3 the opponent's card with the odds line
##   4 the match result after a disqualification
##   5 the run's summary with the run's bets

var main: Node
var h := 1564
var tag := ""
var out := ""
var wait := 7.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--wait="):
			wait = float(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://bookie_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String, settle := 1.0) -> void:
	await create_timer(settle).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved %s%s.png" % [out, name])


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SaveData.enabled = false
	await create_timer(wait).timeout
	var waited := 0.0
	while waited < 150.0 and main.get_children().any(func(n): return n is BootLoader):
		await create_timer(1.0).timeout
		waited += 1.0
	await create_timer(1.0).timeout
	SaveData.control_chosen = true
	SaveData.played = 6
	SaveData.titles = 1
	SaveData.gold = 1200
	Skills.pending = []
	Skills.perks = []
	# A desk with a past: three earlier bets, one of them a disqualification.
	SaveData.bets = {"placed": 3, "won": 1, "loss_streak": 0, "form": [1, 0, 1, 1],
		"history": [
			{"name": "Андрей Рублёв", "side": "self", "stake": 50, "odds": 2.35, "won": true, "paid": 118, "dq": false, "run": 1},
			{"name": "Саша Зверев", "side": "self", "stake": 25, "odds": 3.10, "won": false, "paid": 0, "dq": false, "run": 1},
			{"name": "Томаш Мохач", "side": "against", "stake": 50, "odds": 2.80, "won": false, "paid": 0, "dq": true, "run": 2},
		]}
	SaveData.run = {}
	main._show_menu()
	await create_timer(2.0).timeout
	var club = main.get("club")
	var t := Tournament.new(1, 7)
	t.stage = 2
	SaveData.active = t
	main.tournament = t
	# 1-2: the bookmaker at the bar, then a bet against yourself.
	club.ui_action("club_bookie", 0)
	await _shot("1_sides")
	main._on_ui("bet_against", 50)
	await _shot("2_against")
	# 3: the opponent's card with the line.
	t.bet = {}
	main.ui.show_opponent_card(t, t.stage)
	await _shot("3_card")
	# 4: the result of a match after a disqualification (the run is over).
	var d := Tournament.new(1, 9)
	d.stage = 2
	d.results = [{"stage": 0, "won": true, "score": "6:2"}, {"stage": 1, "won": true, "score": "7:5"}]
	d.gold = 140
	d.income = {"prize": 120, "style": 20}
	SaveData.active = d
	main.tournament = d
	main.tournament_mode = true
	Bets.place_match(d, 50, "against")
	var sb := MatchScore.new(1, 6, 6, 0)
	sb.set_scores = [[4, 6]]
	sb.winner = 1
	var won_dq := false
	for sd in range(1, 300):  # a seed whose dice disqualify (any: the run's seed fixes the roll)
		if Bets.dq_roll(sd, 2, Bets.DQ_ON_LOSS):
			d.rng.seed = sd
			won_dq = true
			break
	var paid := Bets.settle_match(d, sb)
	main.run_hub.last_match = {"points": 0, "gold": 0, "bet": {"stake": 50, "paid": paid}.merged(Bets.last_result)}
	d.record_match(false, "4:6 3:6", RandomNumberGenerator.new())
	print("disqualified: %s (seed found %s), state %d" % [d.disqualified, won_dq, d.state])
	main.ui.show_result(d, false, "4:6 3:6", {"perfect": 2, "aces": 0, "best_rally": 7})
	await _shot("4_result_dq", 1.6)
	# 5: the run's summary: this run's bets only (not the desk's old ones).
	main.ui.show_summary(d)
	await _shot("5_summary", 3.0)
	quit()
