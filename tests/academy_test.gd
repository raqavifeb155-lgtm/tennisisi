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
	for id in Traits.ids():
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
	check(Academy.ceiling(strong) >= Academy.ceiling(weak) + 3, "a talent with a big potential tops out higher (%d / %d)" % [Academy.ceiling(strong), Academy.ceiling(weak)])
	# run_tests: SaveData.record_run calls Academy.on_run(): a played run trains the students
	var before := int(st["trainings"])
	var t := Tournament.new(1)
	t.banked = false
	SaveData.record_run(t)
	check(int(st["trainings"]) == before + 1, "a run banked by SaveData trains the students")


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
	print("the NPC registry")
	ClubNpc.clear()
	var holder := {"p": Vector3(10, 0, 10)}
	ClubNpc.register("a", func() -> Vector3: return holder["p"], "Поговорить", "club_npc_talk:a", {"kind": "student", "r": 0.5})
	ClubNpc.register("b", Vector3(0, 0, 0), "Нанять", "club_npc_hire:b")
	check(ClubNpc.all().size() == 2 and ClubNpc.has("a"), "registered")
	check(ClubNpc.near(Vector3(10, 0, 11.8))["id"] == "a", "within two metres of his edge: he is the one to talk to")
	check(ClubNpc.near(Vector3(10, 0, 14.0)).is_empty(), "farther: nobody")
	holder["p"] = Vector3(30, 0, 30)
	check(ClubNpc.near(Vector3(10, 0, 11.8)).is_empty() and ClubNpc.near(Vector3(30, 0, 31.5))["id"] == "a", "he walks: the button goes with him")
	check(ClubNpc.button("a")["label"] == "ПОГОВОРИТЬ" and ClubNpc.button("a")["action"] == "club_npc_talk:a", "the button's text and action")
	ClubNpc.unregister("a")
	check(not ClubNpc.has("a") and ClubNpc.button("a").is_empty(), "gone")
	ClubNpc.clear()
