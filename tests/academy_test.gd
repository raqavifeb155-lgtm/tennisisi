extends SceneTree
## The school (docs/superpowers/specs/2026-10-09-tycoon.md 3): the traits catalog, the
## candidates, hiring, growth, the visitor, the save, the NPC registry.
##   godot --headless --path . -s tests/academy_test.gd

var failures := 0


func _initialize() -> void:
	SaveData.enabled = false
	test_traits()
	test_traits_work()
	test_gen()
	test_academy()
	test_growth()
	test_guest()
	test_save()
	test_building()
	test_training()
	test_sync()
	test_hooks()
	test_registry()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _fresh() -> void:
	SaveData.club = {}
	SaveData.academy = {}
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0
	Skills.mods_layer = {}


func test_traits() -> void:
	print("the catalog")
	var known := {}
	for id in Skills.PERKS:
		for p in Skills.PERKS[id]:
			for k in p.get("mods", {}):
				known[k] = true
	var base := Traits.base_ids()
	check(base.size() >= 28, "about thirty traits besides the synergies (%d)" % base.size())
	var fine := true
	var kinds := {}
	for id in Traits.student_ids():
		var d := Traits.def(id)
		fine = fine and d.has("name") and String(d["desc"]).length() <= 60 and int(d["tier"]) >= 1 and int(d["tier"]) <= 3 and Traits.KIND_NAMES.has(d["kind"]) and d.has("reveal")
		kinds[d["kind"]] = true
		for k in d.get("mods", {}):
			if not known.has(k):
				fine = false
				print("   unknown mod key ", k, " in ", id)
	check(fine, "every trait: a name, a line of 60 letters at most, a tier 1..3, a known kind, a reveal rule, mods of Skills.PERKS keys")
	check(kinds.size() == 5, "all five kinds: stat, growth, style, char, synergy")
	var syn_ok := true
	for s in Traits.SYNERGIES:
		syn_ok = syn_ok and Traits.CATALOG.has(s[0]) and Traits.CATALOG.has(s[1]) and Traits.def(s[2])["kind"] == "synergy" and Traits.def(s[0])["kind"] != "synergy"
	check(syn_ok and Traits.SYNERGIES.size() >= 6, "six synergies: two traits, a third that is a synergy")
	check(Traits.synergies_of(["serve_cannon", "long_reach", "tall"]) == ["ace_machine"] and Traits.synergies_of(["tall"]).is_empty(), "two together make the third, one alone doesn't")


func test_traits_work() -> void:
	print("what traits do")
	_fresh()
	var st := {"traits": [{"id": "serve_cannon", "hidden": false}, {"id": "long_reach", "hidden": true}, {"id": "cool", "hidden": true}], "revealed": [], "matches": 0, "trainings": 0}
	check(Traits.all_ids(st).has("ace_machine") and Traits.all_ids(st).size() == 4, "the synergy works from the start")
	check(Traits.shown(st) == ["serve_cannon"] and Traits.hidden_count(st) == 3, "one shown, two hidden and the synergy not found: three «???»")
	check(Traits.line(st, "long_reach") == "???" and Traits.line(st, "serve_cannon").begins_with("Пушка подачи"), "the card says «???» for a hidden one")
	check(Traits.reveal(st, "").is_empty(), "no matches yet: nothing shows")
	st["matches"] = 2
	var r := Traits.reveal(st, "")
	check(r.has("ace_machine") and not r.has("long_reach") and not r.has("cool"), "after two matches the synergy shows, «Дальний мяч» waits for three, «Хладнокровный» for a break point (%s)" % str(r))
	st["matches"] = 3
	check(Traits.reveal(st, "").has("long_reach"), "three matches: «Дальний мяч»")
	check(Traits.reveal(st, "tiebreak").is_empty() and Traits.reveal(st, "breakpoint") == ["cool"], "an event reveals its own trait only")
	check(Traits.hidden_count(st) == 0, "everything shown now")
	var m := Traits.mods_of(Traits.all_ids(st))
	check(is_equal_approx(float(m["serve_pace"]), 0.10 + 0.08) and is_equal_approx(float(m["net_window"]), 0.10 + 0.0), "the mods add up, the synergy's too (serve_pace %.2f)" % float(m["serve_pace"]))
	var undo := Traits.apply_side(["serve_cannon", "tall"])
	check(is_equal_approx(Skills.mod("serve_pace"), 0.18) and is_equal_approx(float(Skills.mods_layer["run_speed"]), -0.03), "applied to the side: Skills.mod sees it")
	Traits.undo_side(undo)
	check(Skills.mods_layer.is_empty() and Skills.mod("serve_pace") == 0.0, "undone: nothing is left on the layer")
	check(is_equal_approx(Traits.ctx(["cool", "nervous"], "start"), 0.03) and is_equal_approx(Traits.ctx(["cool"], "breakpoint"), 0.12), "situational: start -5% and +8%, break point +12%")
	check(is_equal_approx(float(Traits.growth_of(["late_bloom"], 3)["xp_mult"]), 0.7) and is_equal_approx(float(Traits.growth_of(["late_bloom"], 10)["xp_mult"]), 1.5), "a late bloomer: slow, then x1.5 after ten trainings")
	check(int(Traits.growth_of(["talent", "hard_worker"])["ceiling_add"]) == 0 and int(Traits.growth_of(["cut_diamond"], 5)["ceiling_add"]) == 0 and int(Traits.growth_of(["cut_diamond"], 10)["ceiling_add"]) == 2, "talent +1, a hard worker -1; the diamond +2 only after ten trainings")


func test_gen() -> void:
	print("candidates")
	_fresh()
	var a := JuniorGen.candidates(77, 3, 1)
	var b := JuniorGen.candidates(77, 3, 1)
	check(a.size() == 3 and str(a) == str(b), "three candidates, the same for the same seed")
	check(str(JuniorGen.candidates(78, 3, 1)) != str(a), "another seed, other people")
	var fine := true
	var traits_ok := true
	var price_ok := true
	var sums: Array[int] = []
	for seed_v in range(1, 41):
		for c in JuniorGen.candidates(seed_v, 4, seed_v % 4):
			var sum := 0
			for k in Opponents.STAT_KEYS:
				var v := int(c["stats"][k])
				fine = fine and v >= 1 and v <= 8
				sum += v
			sums.append(sum)
			var vis := 0
			var hid := 0
			var ids := []
			for t in c["traits"]:
				ids.append(t["id"])
				if t["hidden"]:
					hid += 1
				else:
					vis += 1
			traits_ok = traits_ok and vis >= 1 and vis <= 2 and hid <= 2 and ids.size() == (Array(ids).filter(func(x): return ids.count(x) == 1)).size()
			traits_ok = traits_ok and not (ids.has("tall") and ids.has("short")) and not (ids.has("clay_lover") and ids.has("grass_lover"))
			price_ok = price_ok and int(c["price"]) % 5 == 0 and int(c["price"]) >= 10 and (c["leanings"] as Array).size() == 2 and c["leanings"][0] != c["leanings"][1]
			price_ok = price_ok and int(c["age"]) >= 13 and int(c["age"]) <= 17 and float(c["pot"]) >= 0.35 and float(c["pot"]) <= 1.0
	check(fine, "six stats, 1..8 (the top two are for the special ones)")
	check(traits_ok, "one or two shown, up to two hidden, no repeats, no tall-and-short")
	check(price_ok, "ages 13-17, a potential 0.35..1, two leanings, a price in fives")
	sums.sort()
	check(sums[0] >= 12 and sums[sums.size() - 1] <= 40, "stats of a beginner: %d..%d in all" % [sums[0], sums[sums.size() - 1]])
	var c1: Dictionary = a[0]
	var cheap := c1.duplicate(true)
	cheap["traits"] = []
	var dear := c1.duplicate(true)
	dear["traits"] = [{"id": "talent", "hidden": true}, {"id": "late_bloom", "hidden": true}]
	check(JuniorGen.price(dear) > JuniorGen.price(cheap), "rare traits (even hidden) make a candidate dearer")
	check(JuniorGen.stars(0.0) == 1 and JuniorGen.stars(1.0) == 5 and JuniorGen.stars(0.5) == 3, "potential to stars")
	check(JuniorGen.stars_text({"pot": 0.7, "seed": 2}).contains("–") and not JuniorGen.stars_text({"pot": 0.7, "watched": 1}).contains("–"), "a range of stars until a match is watched, then exact")
	check(is_equal_approx(JuniorGen.junior_t(13), 0.70) and is_equal_approx(JuniorGen.junior_t(18), 1.0) and JuniorGen.junior_t(15.5) > JuniorGen.junior_t(15) and JuniorGen.junior_t(30) == 1.0, "the model grows 0.70 -> 1.0 from 13 to 18")


func test_academy() -> void:
	print("hiring")
	_fresh()
	check(not Academy.free_ready() and Academy.capacity() == 1, "before the first run: nobody is brought, room for one")
	SaveData.played = 1
	check(Academy.free_ready(), "after the first run the coach brings the first student")
	var list := Academy.candidates()
	var free_all := true
	for c in list:
		free_all = free_all and int(c["price"]) == 0
	check(list.size() == 3 and free_all, "three candidates, all free")
	check(str(Academy.candidates()) == str(list), "the set stays the same when asked again")
	check(Academy.why_not(list[1]) == "", "can take one")
	check(Academy.reroll() == false, "the first set can't be changed")
	var st := Academy.hire(list[1]["id"])
	check(not st.is_empty() and Academy.students().size() == 1 and SaveData.gold == 0 and st["id"] == "s1", "hired: free, in the list")
	check(bool(Academy.data()["free_given"]) and not Academy.free_ready() and Academy.candidates().size() == 0, "the others left, the free one is used")
	check(st["name"] == list[1]["name"] and st["stats"] == list[1]["stats"] and st["traits"] == list[1]["traits"], "he is who the card showed")
	check(Academy.is_full() and Academy.why_not(JuniorGen.candidates(5, 1, 0)[0]).begins_with("Нет мест"), "room for one only: the next one can't come")
	# Next season: a new set, for gold.
	SaveData.played = 5
	var next := Academy.candidates()
	Academy.release("s1")
	next = Academy.candidates()
	check(next.size() == 3 and int(next[0]["price"]) > 0, "next season a new set at a price (%d)" % int(next[0]["price"]))
	check(Academy.why_not(next[0]).begins_with("Нужно ещё") and Academy.hire(next[0]["id"]).is_empty(), "no gold: no hire")
	SaveData.gold = 1000
	var c0: Dictionary = next[0]
	var s2 := Academy.hire(c0["id"])
	check(not s2.is_empty() and SaveData.gold == 1000 - int(c0["price"]) and s2["id"] == "s2", "gold goes, ids go on")
	check(Academy.candidates().is_empty(), "taken: the rest leave")
	Academy.release("s2")
	var c1: int = Academy.reroll_cost()
	check(Academy.reroll() and Academy.reroll_cost() == c1 * 2 and SaveData.gold == 1000 - int(c0["price"]) - c1, "a new set costs 30, then 60")
	check(Academy.candidates().size() == 3, "...three new ones")
	check(Academy.age(s2) == int(s2["age0"]) and Academy.capacity() == 1, "age counts the seasons since he came")
	SaveData.played += 8
	check(Academy.age(s2) == int(s2["age0"]) + 2, "two seasons later two years older")


func test_growth() -> void:
	print("growth")
	_fresh()
	SaveData.played = 1
	var st := Academy.hire(Academy.candidates()[0]["id"])
	st["traits"] = [{"id": "hard_worker", "hidden": false}, {"id": "iron_lungs", "hidden": true}]
	st["revealed"] = []
	var sum0 := 0
	for k in Opponents.STAT_KEYS:
		sum0 += int(st["stats"][k])
	var grew := 0
	for i in 12:
		SaveData.played += 1
		grew += Academy.on_run().size()
	var sum1 := 0
	var over := false
	for k in Opponents.STAT_KEYS:
		sum1 += int(st["stats"][k])
		over = over or int(st["stats"][k]) > Academy.ceiling(st)
	check(sum1 > sum0 and grew == sum1 - sum0, "twelve runs: the stats grow (%d -> %d)" % [sum0, sum1])
	check(not over and int(st["trainings"]) == 12, "never past the ceiling; the trainings are counted")
	check(Traits.is_shown(st, "iron_lungs"), "four trainings showed «Железные лёгкие»")
	check(Academy.cost(1) == 40 and Academy.cost(5) == roundf(40.0 * pow(5.0, 1.4)) and Academy.cost(9) > 800, "a step costs 40 x n^1.4")
	var weak := {"pot": 0.2, "traits": [], "trainings": 0}
	var strong := {"pot": 1.0, "traits": [{"id": "talent", "hidden": false}], "trainings": 0}
	check(Academy.potential_ceiling(strong) >= Academy.potential_ceiling(weak) + 3, "a talent with a big potential tops out higher (%d / %d)" % [Academy.potential_ceiling(strong), Academy.potential_ceiling(weak)])
	check(Academy.ceiling(strong) == 7 and Academy.ceiling(weak) == Academy.potential_ceiling(weak), "without the academy nobody grows past 7")
	# A run banked by SaveData: the school catches up when the club asks (Academy.sync), once.
	var before := int(st["trainings"])
	var t := Tournament.new(1)
	t.banked = false
	SaveData.record_run(t)
	check(int(st["trainings"]) == before, "the save itself does not touch the school")
	Academy.sync()
	check(int(st["trainings"]) == before + 1, "sync: one more training for the run banked")
	Academy.sync()
	check(int(st["trainings"]) == before + 1, "sync again: nothing more")


func test_guest() -> void:
	print("the visitor")
	_fresh()
	var found := -1
	for p in range(2, 80):
		SaveData.played = p
		Academy.roll_visit()
		if not Academy.guest().is_empty():
			found = p
			break
	check(found > 0, "now and then a famous player drops by (run %d)" % found)
	var g := Academy.guest()
	check(String(g["name"]) != "" and int(g["until"]) == found + Academy.GUEST_RUNS, "a name from the roster, two runs")
	var cand := Academy.guest_candidate()
	check(cand["id"] == "guest" and int(cand["age"]) >= 18 and int(cand["price"]) > 0 and cand["stats"].size() == 6, "he can be hired: adult, a price, six stats")
	SaveData.played = found + 1
	check(not Academy.guest().is_empty(), "still here the next run")
	SaveData.played = found + 2
	check(Academy.guest().is_empty(), "gone after two runs")
	SaveData.played = found
	Academy.data()["guest"] = g
	SaveData.gold = 5000
	var st := Academy.hire("guest")
	check(not st.is_empty() and Academy.guest().is_empty() and Academy.students().size() == 1, "hired: the visitor becomes a student")


func test_save() -> void:
	print("the save")
	_fresh()
	SaveData.played = 1
	var st := Academy.hire(Academy.candidates()[2]["id"])
	st["revealed"] = ["x"]
	var cf := SaveData._to_config()
	var keep: Dictionary = SaveData.academy.duplicate(true)
	SaveData.academy = {}
	SaveData._apply(cf)
	check(str(SaveData.academy["students"]) == str(keep["students"]) and bool(SaveData.academy["free_given"]), "saved and loaded: the student, his traits, his stats")
	var s0 := SaveData._score(SaveData._to_config())
	SaveData.academy = {}
	check(SaveData._score(SaveData._to_config()) < s0, "a save with a student scores above the same without (a cloud copy can't undo the hire)")


func test_registry() -> void:
	print("the NPC registry (stream H's ClubNpc with what T-2 adds)")
	var reg := ClubNpc.new()
	var holder := {"p": Vector3(10, 0, 10)}
	var line_said := {"n": 0}
	var fn := func() -> String:
		line_said["n"] += 1
		return "" if line_said["n"] == 1 else "Моё — подача"
	reg.register("a", func() -> Vector3: return holder["p"], "Тренировать · Миша", "club_train:s1", ["Привет"],
		{"kind": "student", "name": "Миша", "radius": 0.3, "head": 1.6, "extra": [["Поговорить", "club_say_a"]],
		"line": fn})
	reg.register("coach", Vector3(0, 0, 0), "Поговорить", "", ["Готов?"], {"head": 2.25})
	check(reg.has("a") and reg.entry("a")["kind"] == "student" and reg.entry("a")["name"] == "Миша" and (reg.entry("a")["extra"] as Array).size() == 1, "registered with his kind, name and a quiet button")
	check(reg.position_of("a") == Vector3(10, 0, 10) and is_equal_approx(reg.head_of("a").y, 1.6), "where he is and where his bubble goes")
	holder["p"] = Vector3(30, 0, 30)
	check(reg.position_of("a") == Vector3(30, 0, 30), "he walks: the registry follows")
	var ag := reg.agent_list("coach")
	check(ag.size() == 1 and is_equal_approx(float(ag[0][1]), 0.3), "a body for the hero (his radius)")
	check(reg._next_line(reg.entry("a")) == "Привет" and reg._next_line(reg.entry("a")) == "Моё — подача", "his own line when he has one, else the list")
	reg.set_button("coach", "Выбрать ученика", "club_hire", [["Поговорить", "club_say_coach"]])
	check(reg.entry("coach")["label"] == "Выбрать ученика" and reg.entry("coach")["action"] == "club_hire" and reg.entry("coach")["lines"] == ["Готов?"], "a new button keeps his lines")
	reg.set_button("nobody", "x", "y")
	check(not reg.has("nobody"), "a button for nobody: nothing")
	reg.unregister("a")
	check(not reg.has("a") and reg.position_of("a") == Vector3.INF, "gone")


func _lot_academy(lv: int) -> void:
	SaveData.club["lots"] = {"n7": "academy"}
	SaveData.club["levels"] = {"academy": lv}


func test_building() -> void:
	print("the academy building")
	_fresh()
	SaveData.club = {"lots": {}}
	check(Academy.level() == 0 and not Academy.is_built() and Academy.capacity() == 1, "no building: level 0, one seat")
	check(not ClubLots.sheet_types().has("academy"), "a newcomer's lot sheet doesn't show it")
	SaveData.played = 4
	SaveData.titles = 2
	check(ClubLots.sheet_types().has("academy") and ClubLots.why_not("n7", "academy") == "", "after four runs it can be built on a lot")
	var pr := ClubLots.price("academy")
	check(pr == roundi(150.0 * ClubBuilds.CLUB_PRICE_SCALE) and pr == Academy.level_price(1), "the lot costs the first level (%d)" % pr)
	check(String(ClubLots.sheet("n7", "academy")["card"]["desc"]).contains("Детская") or String(ClubLots.sheet("n7", "academy")["card"]["desc"]).contains("мини-корт"), "the sheet tells the first level")
	SaveData.gold = pr + 10
	check(ClubLots.build("n7", "academy") and SaveData.gold == 10 and Academy.level() == 1 and Academy.is_built(), "built: the gold went, level 1")
	check(ClubBuilds.level("academy") == 1 and ClubPlaces.level("academy") == 1 and not ClubPlaces.find("academy").is_empty(), "the club sees it: a place at its lot")
	check(ClubPlaces.state("academy")["action"] == "club_students", "its button opens the coach's office")
	check(Academy.capacity() == 2 and not Academy.camps_open(), "level 1: two seats, no camps yet")
	check(Academy.why_not_upgrade().begins_with("Нужно ещё") and not Academy.upgrade(), "level 2 costs gold")
	SaveData.gold = 100000
	var p2 := Academy.next_price()
	check(p2 == Academy.level_price(2) and Academy.upgrade() and Academy.level() == 2 and SaveData.gold == 100000 - p2, "level 2 bought (%d)" % p2)
	check(Academy.camps_open() and Academy.capacity() == 2 and int(Academy._at(Academy.CEILING)) == 8, "level 2: camps, the ceiling 8")
	Academy.upgrade()
	check(Academy.level() == 3 and Academy.capacity() == 3 and int(Academy._at(Academy.SET_SIZE)) == 4, "level 3: three seats, four candidates")
	Academy.upgrade()
	Academy.upgrade()
	check(Academy.level() == 5 and Academy.next_level().is_empty() and Academy.why_not_upgrade() != "" and not Academy.upgrade(), "five levels, then no more")
	check(Academy.level_line(5) != "" and Academy.level_title(3) == "Корт академии", "each level has its title and the coach's line")
	# The scout's hint and the rare talents.
	_fresh()
	_lot_academy(2)
	SaveData.played = 9
	Academy.data()["free_given"] = true
	var set2 := Academy.candidates()
	var hinted := true
	for c in set2:
		var had_hidden := (c["traits"] as Array).any(func(t): return bool(t["hidden"]))
		hinted = hinted and (not had_hidden or (c.has("scouted") and Traits.is_shown(c, String(c["scouted"]))))
	check(set2.size() == 3 and hinted, "level 2: the scout shows one hidden trait of each candidate")
	var rare_seasons: Array = []
	_lot_academy(3)
	for se in range(1, 21):
		if Academy.rare_due("s%d" % se):
			rare_seasons.append(se)
	var spaced := true
	for i in range(1, rare_seasons.size()):
		spaced = spaced and int(rare_seasons[i]) - int(rare_seasons[i - 1]) >= 2
	check(rare_seasons.size() >= 2 and rare_seasons.size() <= 10 and spaced, "a rare talent at most once in two seasons (%s)" % str(rare_seasons))
	_lot_academy(2)
	check(not Academy.rare_due("s%d" % int(rare_seasons[0])), "not before level 3")
	_lot_academy(3)
	SaveData.played = int(rare_seasons[0]) * Academy.SEASON
	Academy.data()["cands"] = {"key": "", "list": [], "rerolls": 0}
	var set3 := Academy.candidates()
	var rare: Array = set3.filter(func(c): return bool(c.get("rare", false)))
	check(set3.size() == 5 and rare.size() == 1, "his season: four and a rare one (%d)" % set3.size())
	if not rare.is_empty():
		var r: Dictionary = rare[0]
		var top := 0
		for k in Opponents.STAT_KEYS:
			if int(r["stats"][k]) >= 8:
				top += 1
		var plain: Dictionary = set3[0]
		check(top >= 3 and float(r["pot"]) == 1.0 and int(r["price"]) >= int(plain["price"]) * 3, "rare: three stats 8-10, five stars, five-ten times dearer (%d vs %d)" % [int(r["price"]), int(plain["price"])])
		var AH = load("res://scripts/ui/screens/academy_hire.gd")   # a screen: loaded when the autoloads are up
		check(String(AH.lines(r)["tag"]).begins_with("РЕДКИЙ"), "his card says so")


func test_training() -> void:
	print("focus, camps, sparring")
	_fresh()
	SaveData.played = 1
	var st := Academy.hire(Academy.candidates()[0]["id"])
	st["traits"] = []
	st["pot"] = 0.5
	st["leanings"] = ["serve", "net"]
	for k in Opponents.STAT_KEYS:
		st["stats"][k] = 2
	st["xp"] = {}
	check(Academy.set_focus(st["id"], "backhand") and Academy.focus_of(st) == "backhand", "the focus: a stat")
	check(not Academy.set_focus(st["id"], "nonsense") and Academy.focus_of(st) == "backhand", "nothing else")
	Academy.train(st, 1.0)
	var xp: Dictionary = st["xp"]
	var bh := float(xp.get("backhand", 0.0)) + Academy.cost(2) * (int(st["stats"]["backhand"]) - 2)
	var fh := float(xp.get("forehand", 0.0)) + Academy.cost(2) * (int(st["stats"]["forehand"]) - 2)
	check(bh > fh * 5.0, "60%% into the focus, the rest shared (%.0f vs %.0f)" % [bh, fh])
	Academy.set_focus(st["id"], Academy.EVEN)
	for k in Opponents.STAT_KEYS:
		st["stats"][k] = 2
	st["xp"] = {}
	Academy.train(st, 0.3)
	check(is_equal_approx(float(st["xp"]["forehand"]), float(st["xp"]["backhand"])) and float(st["xp"]["serve"]) > float(st["xp"]["forehand"]), "evenly: the same to each, a leaning more")
	var pr := Academy.progress(st, "forehand")
	check(float(pr[1]) == Academy.cost(2) and float(pr[0]) > 0.0, "progress: gathered / the next step's cost")
	# The camp: from academy level 2, once a season, a run's experience.
	check(Academy.why_not_camp(st).begins_with("Сборы — с академии"), "no camps without the academy's house")
	_lot_academy(2)
	SaveData.gold = 0
	var cp := Academy.camp_price(st)
	check(cp == 60, "a beginner's camp: 60 (%d)" % cp)
	check(Academy.why_not_camp(st).begins_with("Нужно ещё") and Academy.camp(st["id"]).is_empty(), "no gold, no camp")
	SaveData.gold = 500
	var tr := int(st["trainings"])
	Academy.camp(st["id"])
	check(SaveData.gold == 440 and int(st["trainings"]) == tr + 1, "a camp: 60 gold, a training more")
	check(Academy.why_not_camp(st) == "Сборы уже были в этом сезоне", "once a season")
	SaveData.played += Academy.SEASON
	Academy.sync()
	check(Academy.why_not_camp(st) == "", "next season again")
	st["traits"] = [{"id": "coachs_pet", "hidden": false}]
	check(Academy.camp_price(st) == 45, "«Любимец тренера»: a quarter off (%d)" % Academy.camp_price(st))
	for k in Opponents.STAT_KEYS:
		st["stats"][k] = 7
	check(Academy.camp_price(st) == 150, "a strong one's camp is dearer (%d)" % Academy.camp_price(st))
	# Sparring: once a run, half a run, all into the focus.
	for k in Opponents.STAT_KEYS:
		st["stats"][k] = 2
	st["xp"] = {}
	st["traits"] = []
	Academy.set_focus(st["id"], "net")
	var sp := Academy.spar_price(st)
	var g0 := SaveData.gold
	Academy.spar(st["id"])
	check(SaveData.gold == g0 - sp and float(st["xp"].get("forehand", 0.0)) == 0.0 and (int(st["stats"]["net"]) > 2 or float(st["xp"]["net"]) > 0.0), "sparring: %d gold, all into the focus" % sp)
	check(Academy.why_not_spar(st).begins_with("Спарринг уже был"), "once a run")
	SaveData.played += 1
	check(Academy.why_not_spar(st) == "", "after the next run again")
	# The academy makes them grow faster and higher.
	_lot_academy(0)
	SaveData.club["lots"] = {}
	var a0 := st.duplicate(true)
	a0["xp"] = {}
	Academy.train(a0, 1.0)
	_lot_academy(5)
	var a5 := st.duplicate(true)
	a5["xp"] = {}
	Academy.train(a5, 1.0)
	var s0 := 0.0
	var s5 := 0.0
	for k in Opponents.STAT_KEYS:
		s0 += float(a0["xp"][k]) + float(int(a0["stats"][k]) - 2) * 100.0
		s5 += float(a5["xp"][k]) + float(int(a5["stats"][k]) - 2) * 100.0
	check(s5 > s0 * 1.2, "level 5 grows them faster (x1.4)")
	a5["pot"] = 1.0
	check(Academy.ceiling(a5) == 10, "and up to 10")


func test_sync() -> void:
	print("runs, news")
	_fresh()
	SaveData.played = 1
	var st := Academy.hire(Academy.candidates()[0]["id"])
	st["traits"] = []
	st["pot"] = 1.0
	Academy.set_focus(st["id"], "serve")
	Academy.take_news()
	SaveData.played = 6
	var grew := Academy.sync()
	check(int(st["trainings"]) == 5 and int(Academy.data()["trained_at"]) == 6, "five runs played: five trainings at once")
	check(not grew.is_empty(), "and something grew (%d)" % grew.size())
	var news := Academy.take_news()
	check(news.size() == mini(grew.size(), Academy.NEWS_MAX) and Academy.take_news().is_empty(), "the news is kept until the club tells it")
	var txt := Academy.news_text([{"name": "Миша Петров", "stat": "serve", "to": 4}, {"name": "Миша Петров", "stat": "serve", "to": 5}, {"name": "Аня Белова", "stat": "net", "to": 3}])
	check(txt == "Миша: подача 5 · Аня: сетка 3", "«Миша: подача 5 · Аня: сетка 3» (%s)" % txt)
	# Somebody hired after some runs does not train for the runs before him.
	SaveData.played = 10
	Academy.data()["free_given"] = true
	_lot_academy(1)
	SaveData.gold = 10000
	var c: Dictionary = Academy.candidates()[0]
	var s2 := Academy.hire(c["id"])
	check(int(st["trainings"]) == 9 and int(s2.get("trainings", 0)) == 0, "a newcomer starts from his first run here; the others caught up first")
	SaveData.played = 11
	Academy.sync()
	check(int(s2["trainings"]) == 1 and int(st["trainings"]) == 10, "then both train")
	SaveData.club = {}


func test_hooks() -> void:
	print("hooks for the academy's house")
	_fresh()
	SaveData.played = 1
	var st := Academy.hire(Academy.candidates()[0]["id"])
	st["traits"] = []
	st["pot"] = 1.0
	check(Academy.capacity() == 1, "no hook: the table's seats")
	Academy.set_hook("capacity", func() -> int: return 6)
	check(Academy.capacity() == 6, "the house's dorm sets the seats")
	Academy.set_hook("ceiling_add", func(_s, k) -> int: return 1 if k == "speed" else 0)
	check(Academy.ceiling(st, "speed") == Academy.ceiling(st, "serve") + 1, "a stat's ceiling +1 (the gym)")
	for k in Opponents.STAT_KEYS:
		st["stats"][k] = 2
	st["xp"] = {}
	st["leanings"] = []
	Academy.set_focus(st["id"], Academy.EVEN)
	Academy.set_hook("growth_mult", func(_s, k) -> float: return 2.0 if k == "stamina" else 1.0)
	Academy.train(st, 0.2)
	check(is_equal_approx(float(st["xp"]["stamina"]), 2.0 * float(st["xp"]["backhand"])), "a stat's growth x2 (the kitchen)")
	var days: Array = []
	Academy.set_hook("on_day", func(run: int) -> void: days.append(run))
	SaveData.played = 3
	Academy.sync()
	check(days == [2, 3], "the house hears every day of the academy (%s)" % str(days))
	for h in ["capacity", "ceiling_add", "growth_mult", "on_day"]:
		Academy.set_hook(h, Callable())
	check(Academy.hooks.is_empty() and Academy.capacity() == 1, "hooks off: as before")
