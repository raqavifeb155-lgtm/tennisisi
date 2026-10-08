extends SceneTree
## One trial of the strength measurement (v0.2 A-5, spec 3: "growth is felt"): the real bot
## plays N points of a real tournament match against a FIXED opponent, with experience and
## gear set by the arguments; prints the share of points it won. tools/power_bot.sh runs
## the matrix in parallel and averages it.
##   godot --headless --path . --fixed-fps 60 -s tools/power_bot.gd -- --autoplay --bot-sd=0.07 \
##       --points=100 --p-xp=1930 --p-gear=epic3 --p-stage=2 --p-seed=7
## --p-xp     experience in every skill (280 ~ level 5, 1930 ~ level 12)
## --p-gear   none | rare3 | epic3 | epic1 | legend3 (worn: a racket, shoes, a wristband)
## --p-stage  the opponent (0 first round .. 4 the boss), --p-loc the island
## Prints:  POWER xp=1930 gear=epic3 stage=2 seed=7 won=57 lost=43

var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return default


func _run() -> void:
	var xp := float(_arg("p-xp", "0"))
	var gear := _arg("p-gear", "none")
	var stage := int(_arg("p-stage", "2"))
	var seed_value := int(_arg("p-seed", "1"))
	var loc := _arg("p-loc", "park")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	SaveData.enabled = false
	SaveData.locker = {}
	SaveData.club = {}
	SaveData.titles_by_loc = {}
	Skills.reset()  # like --autoplay --tournament: a beginner who spends the starting points...
	for id in ["forehand", "backhand", "serve"]:
		Skills.spend_point(id)
	if xp > 0.0:
		for id in Skills.LIST:
			Skills.add_xp(id, xp)  # ...and then has this much experience
		Skills.pending = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + 5
	var rarity := {"none": -1, "rare3": Gear.RARE, "epic3": Gear.EPIC, "epic1": Gear.EPIC, "legend3": Gear.LEGENDARY}.get(gear, -1) as int
	var worn: Array = []
	if rarity >= 0:
		for slot in (["racket"] if gear == "epic1" else Gear.SLOTS):
			worn.append(Gear.roll(rarity, rng, slot, 1))
	var t := Tournament.new(1, seed_value)
	t.location = loc
	t.stage = stage
	main.tournament = t
	main.tournament_mode = true
	main._next_location = loc
	for it in worn:
		t.join(it)
	main._play_match()
	# A match with no end: the trial stops at --points (Main's autoplay summary).
	main.scoreboard = MatchScore.new(1, 99, 0, main.scoreboard.server, t.opponent()["short"])
	main.hud.show_board(main.scoreboard, ["ВЫ", main.cpu_label])
	var names: Array[String] = []
	for it in worn:
		names.append(String(it["name"]))
	print("POWER setup xp=%d gear=%s stage=%d seed=%d items=%s" % [int(xp), gear, stage, seed_value, ", ".join(names)])
	main.tree_exited.connect(func() -> void:
		var won: int = main.score[0]
		var lost: int = main.score[1]
		print("POWER xp=%d gear=%s stage=%d seed=%d won=%d lost=%d" % [int(xp), gear, stage, seed_value, won, lost]))
