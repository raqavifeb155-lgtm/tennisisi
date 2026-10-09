extends SceneTree
## Stream L1 (ACADEMY_LEGACY_TZ 3, 8.4, 8.6): the career and the retirement, headless:
##   godot --headless --path . -s tests/career_test.gd
## The season counter in SaveData.record_run, rating points and the place, the season final,
## age and the experience multiplier, the skills profile, the save's score after a
## retirement, what stays and what goes, the heir out of three, the save through text.

var failures := 0
var finished := 0


## _initialize, not _init: the autoloads (Tuning, GameEvents) are in the tree by now.
func _initialize() -> void:
	SaveData.enabled = false  # never the developer's save
	Tournament.BEGINNER_START = 1.0
	test_profile()
	test_migration()
	test_points_and_rank()
	test_season_counter()
	test_season_final()
	test_age_and_xp()
	test_retire_due()
	test_early()
	test_free_agents()
	test_heir_sources()
	test_retire()
	test_save_roundtrip()
	test_screens()
	check(finished == 13, "every test ran to its end: %d of 13" % finished)
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


## A clean slate: a new player with no career section yet.
func _fresh(played := 0) -> void:
	SaveData._apply(ConfigFile.new())
	SaveData.played = played
	SaveData.gold = 0
	SaveData.titles = 0
	SaveData.titles_by_loc = {}
	SaveData.locker = {}
	SaveData.career = {}
	SaveData.lifetime_xp = 0.0
	Skills.reset()
	Career.clear_heir_sources()


## A closed run: out in round `stage` (index), or the title.
func _run(stage: int, champion := false, loc := "park", seed_v := 11) -> Tournament:
	var t := Tournament.new(1, seed_v)
	t.location = loc
	t.results = [{"stage": stage, "won": champion, "score": "6:3"}]
	t.stage = 5 if champion else stage
	t.champion = champion
	t.state = Tournament.State.OVER
	SaveData.record_run(t)
	return t


func test_profile() -> void:
	print("skills profile")
	_fresh()
	Skills.add_xp("serve", 900.0)
	Skills.take_perk("sv_bomb")
	Skills.points = 1
	var p := Skills.to_profile()
	check(p.has_all(["xp", "perks", "pending", "points"]), "the profile has xp, perks, pending, points")
	Skills.xp["serve"] = 0.0
	Skills.perks.append("fh_cannon")
	check(float(p["xp"]["serve"]) == 900.0 and p["perks"] == ["sv_bomb"], "the profile is a copy: later play does not change it")
	Skills.load_profile(p)
	check(float(Skills.xp["serve"]) == 900.0 and Skills.perks == ["sv_bomb"] and Skills.points == 1, "load_profile brings it back")
	var q := Skills.profile_from_levels({"serve": 5, "feet": 2})
	Skills.load_profile(q)
	check(Skills.level("serve") == 5 and Skills.level("feet") == 2 and Skills.level("forehand") == 0, "a profile from levels: exactly those levels")
	check(Skills.points == Skills.START_POINTS and Skills.perks.is_empty(), "...with the starting points, no perks")
	Skills.load_profile({})
	check(Skills.xp.is_empty() and Skills.points == Skills.START_POINTS, "an empty profile = a beginner")
	finished += 1


func test_migration() -> void:
	print("migration")
	_fresh()
	var cf := ConfigFile.new()
	cf.set_value("meta", "played", 37)
	cf.set_value("meta", "titles", 2)
	SaveData._apply(cf)
	var c := SaveData.career
	check(int(c["start_played"]) == 37, "an old save starts its career where it is (start_played = played)")
	check(int(c["season"]) == 1 and int(c["in_season"]) == 0 and int(c["age"]) == 19 and int(c["gen"]) == 1, "season 1, tournament 0, 19 years, generation 1")
	check(Career.runs() == 0, "no career runs yet: the old ones were before the pro career")
	SaveData.career["in_season"] = 2
	var cf2 := ConfigFile.new()
	cf2.parse(SaveData._to_config().encode_to_text())
	SaveData._apply(cf2)
	check(int(SaveData.career["in_season"]) == 2 and int(SaveData.career["start_played"]) == 37, "the career section survives the save")
	_fresh(5)
	check(int(Career.data()["start_played"]) == 5, "no section in memory: made on first use from played")
	finished += 1


func test_points_and_rank() -> void:
	print("points and rank")
	var t := Tournament.new(1, 3)
	check(Career.points_for(t) == 0, "no match played: no points")
	t.results = [{"stage": 0, "won": false, "score": ""}]
	t.stage = 0
	check(Career.points_for(t) == 10, "out in the first round: 10")
	t.stage = 2
	check(Career.points_for(t) == 90, "out in the quarter-final: 90")
	t.stage = 4
	check(Career.points_for(t) == 300, "out in the final: 300")
	t.champion = true
	t.stage = 5
	check(Career.points_for(t) == 500, "the title: 500")
	check(Career.rank_for(0) == 999 and Career.rank_for(2600) == 1, "no points 999th, 2600 points first")
	check(Career.rank_for(700) < Career.rank_for(300) and Career.rank_for(300) < Career.rank_for(100), "more points, a higher place")
	check(Career.rank_for(675) <= 35 and Career.rank_for(675) >= 25, "QF-SF all season (~675) is about 30th: %d" % Career.rank_for(675))
	check(Career.season_gold(5) == 300 and Career.season_gold(100) == 100 and Career.season_gold(150) == 40, "gold for the place: top-10 300, 100th 100, outside 40")
	check(Career.season_gold(45) > Career.season_gold(95), "a higher place in the top-100 pays more")
	finished += 1


func test_season_counter() -> void:
	print("season counter")
	_fresh()
	_run(0)
	var c := SaveData.career
	check(int(c["in_season"]) == 1 and Career.runs() == 1 and int(c["season_pts"]) == 10, "one run: tournament 1 of 4, 10 points")
	check((c["cells"] as Array).size() == 1 and String(c["cells"][0]["loc"]) == "park", "the calendar has the run's cell")
	_run(2)
	_run(1, true)
	check(int(c["in_season"]) == 3 and int(c["season"]) == 1, "three runs: still season 1")
	check(Career.is_final_next(), "the 4th tournament is the season final")
	var gold0 := SaveData.gold
	_run(1)
	check(int(c["season"]) == 2 and int(c["in_season"]) == 0 and int(c["age"]) == 22, "four runs: season 2, 22 years")
	var s: Dictionary = c["seasons"][0]
	check(int(s["pts"]) == 10 + 90 + 500 + 45 * 2, "season points: the final counts x2 (%d)" % int(s["pts"]))
	check(int(s["rank"]) == Career.rank_for(int(s["pts"])) and int(s["titles"]) == 1, "the season's place and titles")
	check(SaveData.gold - gold0 >= Career.season_gold(int(s["rank"])), "the place's gold went to the bank")
	check(int(c["season_due"]) == 1, "the season's summary waits to be shown")
	check(int(c["season_pts"]) == 0 and (c["cells"] as Array).is_empty(), "the new season starts empty")
	check(int(c["best_rank"]) == int(s["rank"]) and int(c["titles"]) == 1, "the career keeps the best place and the titles")
	finished += 1


func test_season_final() -> void:
	print("season final")
	_fresh()
	SaveData.titles = 1
	SaveData.titles_by_loc = {"park": 1}  # Spain is open
	for i in 3:
		_run(0)
	check(String(SaveData.career["final_loc"]) == "clay", "the final goes to the best open island")
	var t := Tournament.new(1, 5)
	t.location = "clay"
	check(is_equal_approx(Career.prize_mult(t), 1.5), "the season final on the best island: prizes x1.5")
	var t2 := Tournament.new(1, 6)
	t2.location = "park"
	check(is_equal_approx(Career.prize_mult(t2), 1.0), "a lower island: no bonus")
	var base := t.prize_mult() / 1.5
	check(is_equal_approx(t.prize_mult(), base * 1.5), "Tournament.prize_mult takes the career's multiplier")
	SaveData.career["season"] = 5
	check(is_equal_approx(Career.prize_mult(t2), 1.2), "the farewell season: prizes x1.2")
	check(is_equal_approx(Career.prize_mult(t), 1.8), "the farewell final: x1.5 x1.2")
	t.banked = true
	t.set_meta("career_mult", 1.5)
	check(is_equal_approx(Career.prize_mult(t), 1.5), "a banked run keeps the multiplier it was played with")
	finished += 1


func test_age_and_xp() -> void:
	print("age and experience")
	_fresh()
	var want := [1.25, 1.15, 1.0, 0.85, 0.7]
	var ages := [19, 22, 25, 28, 31]
	var ok := true
	for s in 5:
		SaveData.career["season"] = s + 1
		ok = ok and is_equal_approx(Career.xp_mult(), want[s]) and Career.age_of(s + 1) == ages[s]
	check(ok, "seasons 1..5: x1.25 1.15 1.0 0.85 0.7, ages 19 22 25 28 31")
	check(Career.SEASON_NAMES.size() == 5, "every season has a name")
	finished += 1


func test_retire_due() -> void:
	print("retirement after 5 seasons")
	_fresh()
	for i in 19:
		_run(0)
	check(not Career.retire_due() and int(SaveData.career["season"]) == 5 and int(SaveData.career["in_season"]) == 3, "19 runs: the farewell season's last tournament is next")
	_run(0)
	check(Career.retire_due(), "20 runs: the retirement is due")
	check(int(SaveData.career["season"]) == 5 and (SaveData.career["seasons"] as Array).size() == 5, "five seasons in the books")
	check(Career.runs() == 20, "20 career runs")
	finished += 1


func test_early() -> void:
	print("early retirement")
	_fresh()
	for i in 4:
		_run(0)
	check(not Career.can_retire_early(), "season 2: no early retirement")
	for i in 4:
		_run(0)
	check(Career.can_retire_early(), "season 3: the quiet link is there")
	Career.request_early()
	check(Career.retire_due() and bool(SaveData.career["early"]), "asked: the retirement is due, marked early")
	check(not Career.can_retire_early(), "and not offered twice")
	finished += 1


func test_free_agents() -> void:
	print("free agents")
	var a := Career.free_agents(3, 1234)
	var b := Career.free_agents(3, 1234)
	check(a.size() == 3 and a == b, "three by the seed, the same twice")
	var ok := true
	for c in a:
		ok = ok and String(c["name"]) != "" and not (c["look"] as Dictionary).is_empty() and String(c["origin"]) == "free"
		for id in Skills.LIST:
			var lv := int(c["levels"].get(id, 0))
			ok = ok and lv >= 0 and lv <= 3
	check(ok, "each has a name, a look, levels 0..3 in every skill")
	check(a[0]["name"] != a[1]["name"] or a[1]["name"] != a[2]["name"], "they are different people")
	finished += 1


func test_heir_sources() -> void:
	print("heir sources")
	_fresh()
	SaveData.career["retire_due"] = true
	var calls := [0]
	Career.register_heir_source("academy", func(ctx: Dictionary) -> Array:
		calls[0] += 1
		return [{"id": "j7", "name": "Миша Петров", "levels": {"serve": 6}, "look": {}, "origin": "academy"}], 10)
	Career.register_heir_source("bad", func(_ctx: Dictionary) -> Array:
		return [{"name": ""}, "not a dict"])
	var h := Career.heir_candidates()
	check(h.size() == 3, "always three")
	check(String(h[0]["id"]) == "j7" and String(h[0]["origin"]) == "academy", "the academy's graduate first (priority)")
	check(String(h[1]["origin"]) == "free" and String(h[2]["origin"]) == "free", "the rest are free agents")
	check(not (h[0]["look"] as Dictionary).is_empty(), "a candidate with no look gets one")
	var h2 := Career.heir_candidates()
	check(h2 == h and calls[0] == 1, "fixed for this retirement: the sources are not asked again")
	Career.register_heir_source("academy", func(_ctx: Dictionary) -> Array: return [], 10)
	check(Career.heir_candidates() == h, "a source changing later does not reroll them")
	finished += 1


func _item(rarity: int, slot: String, seed_v: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return Gear.roll(rarity, r, slot)


func test_retire() -> void:
	print("retirement")
	_fresh()
	SaveData.titles_by_loc = {"park": 2}
	SaveData.titles = 2
	SaveData.club = {"spent": 400, "builds": {"court": 2}}
	SaveData.look = Looks.random(RandomNumberGenerator.new())
	for id in Skills.LIST:
		Skills.add_xp(id, 2000.0)
	Skills.add_xp("serve", 6000.0)
	Skills.take_perk("sv_bomb")
	for i in 19:
		_run(1)
	var kept := _item(Gear.RARE, "band", 3)
	Locker.items().append(kept.duplicate(true))
	var last := Tournament.new(1, 77)
	last.equip["racket"] = _item(Gear.EPIC, "racket", 4)
	last.equip["shoes"] = _item(Gear.RARE, "shoes", 5)
	last.bag = [_item(Gear.LEGENDARY, "racket", 6)]
	last.results = [{"stage": 2, "won": false, "score": ""}]
	last.stage = 2
	last.state = Tournament.State.OVER
	SaveData.record_run(last)
	check(Career.retire_due(), "the 20th run: retirement due")
	Locker.items().append(last.equip["shoes"].duplicate(true))  # the summary kept the shoes in the locker
	var score0 := SaveData._score(SaveData._to_config())
	var gold0 := SaveData.gold
	var serve_lv := Skills.level("serve")
	var relics := Career.relic_options(last)
	check(relics.size() == 4, "relic options: worn, the bag and the locker (%d)" % relics.size())
	var leg := -1
	for i in relics.size():
		if int(relics[i]["item"].get("rarity", 0)) == Gear.LEGENDARY:
			leg = i
	var heirs := Career.heir_candidates()
	var got := []
	var ev: Node = root.get_node("GameEvents")
	ev.career_retired.connect(func(info: Dictionary) -> void: got.append(info))
	var rec := Career.retire(heirs[1], relics[leg], last)
	check(got.size() == 1 and got[0]["record"] == rec, "GameEvents.career_retired tells the academy")
	# The retired hero, for stream T (the coach NPC).
	var ret: Array = SaveData.career["retired"]
	check(ret.size() == 1 and ret[0] == rec, "the hero went into career.retired")
	check(int(rec["gen"]) == 1 and int(rec["runs"]) == 20 and int(rec["seasons"]) == 5, "the record: generation, runs, seasons")
	check(String(rec["best_skill"]) == "serve" and int(rec["levels"]["serve"]) == serve_lv, "the record: levels and the best skill (the coach's)")
	check(rec["perks"] == ["sv_bomb"] and not (rec["look"] as Dictionary).is_empty(), "the record: perks and look")
	# What goes.
	var heir: Dictionary = heirs[1]
	var lv_ok := true
	for id in Skills.LIST:
		lv_ok = lv_ok and Skills.level(id) == int(heir["levels"].get(id, 0))
	check(lv_ok and Skills.perks.is_empty() and Skills.points == Skills.START_POINTS, "skills: the heir's levels, no perks, the starting points")
	check(SaveData.look == Looks.sanitize(heir["look"]), "the look is the heir's")
	var auction := roundi(Items.price(last.equip["racket"]) * 0.5)
	check(SaveData.gold - gold0 == auction, "the farewell auction sold the worn racket for half its price (not the relic, not the kept shoes): +%d" % (SaveData.gold - gold0))
	check(last.equip["racket"].is_empty() and last.bag.is_empty(), "the last run's things are gone")
	# What stays.
	check(SaveData.titles_by_loc == {"park": 2} and SaveData.titles == 2 and int(SaveData.club["spent"]) == 400, "titles, islands and the club stay")
	check(Locker.items().size() == 2, "the locker stays (2 things)")
	var nx := Locker.next_items()
	check(nx.size() == 1 and bool(nx[0].get("relic", false)) and int(nx[0]["rarity"]) == Gear.LEGENDARY, "the relic rides with the heir's first run, flagged relic")
	check(String(nx[0].get("relic_of", "")) != "", "...signed with the hero's name")
	# The new career.
	var c := SaveData.career
	check(int(c["gen"]) == 2 and int(c["season"]) == 1 and int(c["in_season"]) == 0 and int(c["age"]) == 19, "generation 2: season 1, 19 years")
	check(String(c["name"]) == String(heir["name"]) and not Career.retire_due() and (c["heirs"] as Array).is_empty(), "the heir's name, nothing due")
	check(int(c["start_played"]) == SaveData.played and Career.runs() == 0, "the heir's career starts now")
	check(not (c["relic"] as Dictionary).is_empty(), "the heir knows his relic")
	# The cloud can't undo it.
	var score1 := SaveData._score(SaveData._to_config())
	check(score1 > score0, "the save's score after the retirement beats the copy before it (%.0f > %.0f)" % [score1, score0])
	finished += 1


func test_save_roundtrip() -> void:
	print("save through text")
	var before := SaveData.career.duplicate(true)
	var prof := Skills.to_profile()
	var look := SaveData.look.duplicate(true)
	var nx := Locker.next_items().duplicate(true)
	var cf := ConfigFile.new()
	cf.parse(SaveData._to_config().encode_to_text())
	SaveData._apply(cf)
	check(SaveData.career == before, "the career section comes back the same (retired, gen, season)")
	check(Skills.to_profile()["xp"] == prof["xp"] and SaveData.look == look, "the heir's skills and look come back")
	check(Locker.next_items() == nx, "the relic waits in the locker's 'next'")
	finished += 1


func test_screens() -> void:
	print("screens")
	var ui: CanvasLayer = load("res://scripts/tournament_ui.gd").new()
	root.add_child(ui)
	_fresh()
	for i in 4:
		_run(i % 3)
	var t := Tournament.new(1, 9)
	var screens := load("res://scripts/ui/screens/career_screens.gd")
	screens.bracket_extra(ui, t)
	check(_has_text(ui, "Сезон 2"), "the bracket shows the season line")
	screens.show_season(ui)
	check(_has_text(ui, "ИТОГИ СЕЗОНА") and int(SaveData.career["season_due"]) == 0, "the season's summary opens and is marked seen")
	SaveData.career["retire_due"] = true
	screens.show_retire(ui, null)
	check(_has_text(ui, "Остаётся"), "the ceremony says what stays")
	screens.show_heirs(ui)
	var cards: Array = ui._box.get_children().filter(func(c): return c is GameCard)
	check(cards.size() == 3, "three heir cards")
	ui.queue_free()
	finished += 1


func _has_text(ui: CanvasLayer, s: String) -> bool:
	for l in ui.root.find_children("*", "Label", true, false):
		if s in (l as Label).text:
			return true
	for c in ui.root.find_children("*", "", true, false):
		if c is GameCard and (s in String(c.title) or s in String(c.desc) or s in String(c.tag)):
			return true
	return false
