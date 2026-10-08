extends SceneTree
## The club (docs/club/H1_SPEC.md): places, walking, the world, the way to a match.
##   godot --headless --path . -s tests/club_test.gd

var failures := 0


func _initialize() -> void:
	SaveData.enabled = false  # never the developer's save: buy() saves
	test_places()
	test_walk()
	test_material()
	test_place_levels()
	test_roulette_physics()
	test_builds()
	test_quests()
	test_shop_locker()
	test_long_build()
	await test_world()
	await test_flow()
	await test_transitions()
	await test_places_flow()
	await test_build_world()
	await test_foreman_flow()
	await test_quests_flow()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func test_places() -> void:
	print("places")
	var ids := []
	for p in ClubPlaces.LIST:
		ids.append(p["id"])
		check(float(p["r"]) > 0.5, "%s has a circle" % p["id"])
		var st0 := ClubPlaces.state(p["id"], 0)
		check(st0.get("action", "") != "" or st0.get("sign", "") != "", "%s has a button or a sign" % p["id"])
	for id in ["court", "machine", "coach", "gate", "locker", "shop", "trophy", "bar", "blackjack", "arena", "board", "academy", "booth"]:
		check(ids.has(id), "place %s exists" % id)
	var overlap := false
	for i in ClubPlaces.LIST.size():
		for j in range(i + 1, ClubPlaces.LIST.size()):
			var a: Dictionary = ClubPlaces.LIST[i]
			var b: Dictionary = ClubPlaces.LIST[j]
			if (a["pos"] as Vector3).distance_to(b["pos"]) < float(a["r"]) + float(b["r"]) + 1.0:
				overlap = true
	check(not overlap, "circles don't overlap")
	var court := ClubPlaces.find("court")
	check(ClubPlaces.is_open(court, 0, 0), "the court is open from the start")
	var locker := ClubPlaces.find("locker")
	check(not ClubPlaces.is_open(locker, 0, 0) and ClubPlaces.is_open(locker, 1, 0), "the locker room opens after the first run")
	check(not ClubPlaces.is_open(ClubPlaces.find("board"), 9, 3), "the board waits for the online game")
	check(ClubPlaces.at(court["pos"] + Vector3(0.5, 0, 0)).get("id", "") == "court", "a point in the court's circle is at the court")
	check(ClubPlaces.at(Vector3(5, 0, 2)).is_empty(), "a point on the court itself is at no place")
	var machine := ClubPlaces.find("machine")
	check(ClubPlaces.is_open(machine, 0, 0) and ClubPlaces.state("machine")["action"] == "practice", "practice is at the ball machine, open from the start")
	check((machine["pos"] as Vector3).z > 0.5 and (machine["pos"] as Vector3).z < Court.HALF_LENGTH, "the machine's circle is on the near half of the main court")


## What a place offers is data: per level, the last level described repeats.
func test_place_levels() -> void:
	print("place levels")
	for p in ClubPlaces.LIST:
		check(p.has("levels") and not (p["levels"] as Array).is_empty(), "%s has levels" % p["id"])
		for lv in 6:
			var st := ClubPlaces.state(p["id"], lv)
			check(st.has("label") and st.has("action") and st["id"] == p["id"], "%s level %d has a button (or none)" % [p["id"], lv])
	check(ClubPlaces.state("shop", 0)["action"] == "club_shop", "the shop opens its screen")
	check(ClubPlaces.state("bar", 0)["action"] == "club_roulette", "the bar's button is the roulette")
	check(ClubPlaces.state("arena", 0)["action"] == "club_place", "the arena site tells what will be there")
	var bj := ClubPlaces.find("blackjack")
	check(ClubPlaces.state("blackjack", 0)["action"] == "club_blackjack" and ClubPlaces.state("blackjack", 0)["label"] == "Блэкджек", "the blackjack table: 'Блэкджек' -> club_blackjack")
	check(bj.get("unlock", "") == "title" and bj.get("build", "") == "bar", "after the first title, like the Totalizator; grows with the bar")
	check((bj["pos"] as Vector3).distance_to(ClubPlaces.find("bar")["pos"]) < 9.0, "on the bar's terrace, by the roulette")
	check(int(ClubPlaces.state("bar", 3)["bet_limit"]) > int(ClubPlaces.state("bar", 0)["bet_limit"]), "a bigger bar takes bigger bets")
	check(ClubPlaces.state("bar", 9)["bet_limit"] == ClubPlaces.state("bar", 5)["bet_limit"], "past the last level the last one holds")
	var shop := ClubPlaces.find("shop")
	check(not ClubPlaces.is_open(shop, 0, 0) and ClubPlaces.is_open(shop, 1, 0), "the shop opens after the first run")
	var bar := ClubPlaces.find("bar")
	check(not ClubPlaces.is_open(bar, 5, 0) and ClubPlaces.is_open(bar, 5, 1), "the bar opens after the first title")
	check(ClubPlaces.find("machine").get("travel", true) == false, "the machine is not in quick travel (it's by the court)")
	SaveData.club = {"levels": {"bar": 2}}
	check(ClubPlaces.level("bar") == 2 and ClubPlaces.level("shop") == 0, "levels come from the club's save")
	SaveData.club = {}


## The roulette's ball runs on BallPhysics and always ends on the field drawn before.
func test_roulette_physics() -> void:
	print("roulette")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wrong := 0
	var escaped := 0
	var bounced := 0
	var longest := 0.0
	for i in 40:
		var field := rng.randi_range(0, Bets.FIELDS - 1)
		var sim := ClubRoulette.simulate(field, rng.randi())
		var frames: PackedVector3Array = sim["frames"]
		var wheel: PackedFloat32Array = sim["wheel"]
		var last := frames.size() - 1
		if ClubRoulette.pocket_at(frames[last], wheel[last]) != field:
			wrong += 1
		for f in frames:
			var r := Vector2(f.x, f.z).length()
			if r > ClubRoulette.R_OUT + 0.002 or f.y < ClubRoulette.FLOOR_Y + BallPhysics.RADIUS - 0.01:
				escaped += 1
				break
		if int(sim["bounces"]) > 0:
			bounced += 1
		longest = maxf(longest, last * float(sim["dt"]))
	check(wrong == 0, "the ball stops on the field drawn before (%d wrong of 40)" % wrong)
	check(escaped == 0, "the ball never leaves the bowl (%d)" % escaped)
	check(bounced >= 30, "the ball bounces on the way (%d of 40)" % bounced)
	check(longest <= 8.0, "a spin is over in 8 s (%.1f)" % longest)
	var a := ClubRoulette.simulate(7, 123)
	var b := ClubRoulette.simulate(7, 123)
	check(a["frames"] == b["frames"], "the same draw plays the same way")
	check(ClubRoulette.field_color(0) == Bets.color_of(0) and ClubRoulette.field_color(5) == Bets.color_of(5), "the wheel's colours are the desk's")


## H2: the constructions - buying, saving, the perks and their caps (H2_SPEC 9).
func test_builds() -> void:
	print("builds")
	SaveData.club = {}
	SaveData.gold = 1000
	SaveData.played = 1
	SaveData.titles = 1
	var score0 := SaveData._score(SaveData._to_config())
	check(ClubBuilds.next_price("court") == 40, "the court's first level costs 40")
	check(ClubBuilds.buy("court") and SaveData.gold == 960 and ClubBuilds.level("court") == 1, "buy: exactly the price, one level up")
	check(int(SaveData.club["spent"]) == 40, "the spending is counted")
	check(SaveData._score(SaveData._to_config()) >= score0, "a purchase never lowers the save's score (the cloud copy can't undo it)")
	SaveData.gold = 10
	check(not ClubBuilds.buy("stands") and SaveData.gold == 10 and ClubBuilds.level("stands") == 0, "no gold, no building")
	SaveData.gold = 100000
	SaveData.club["levels"] = {"court": 5}
	check(not ClubBuilds.buy("court") and ClubBuilds.next_price("court") == 0 and SaveData.gold == 100000, "nothing above the top level")
	SaveData.club = {"levels": {"court": 2, "gate": 1}, "color": 2, "name": "Клуб Димы", "spent": 220}
	var cf := SaveData._to_config()
	SaveData.club = {}
	SaveData._apply(cf)
	check(ClubBuilds.level("court") == 2 and ClubBuilds.level("gate") == 1 and ClubBuilds.color_index() == 2 and ClubBuilds.club_name() == "Клуб Димы", "save and load: the same levels, colour and name")
	SaveData.club = {}
	check(is_zero_approx(ClubBuilds.gold_win_bonus()), "no stands, no bonus")
	var t := Tournament.new(1, 3)
	t.lineup[1]["golden"] = false
	var plain := t.gold_for_win(1)
	SaveData.club = {"levels": {"stands": 5}}
	check(t.gold_for_win(1) == roundi(plain * 1.10), "full stands: a won match pays +10%% (%d -> %d)" % [plain, t.gold_for_win(1)])
	ClubBuilds.utility_enabled = false
	check(t.gold_for_win(1) == plain, "utility off (online): the stands pay nothing")
	ClubBuilds.utility_enabled = true
	SaveData.club = {}
	var ok := true
	for lv in range(1, 6):
		SaveData.club = {"levels": {"stands": lv}}
		ok = ok and is_equal_approx(ClubBuilds.gold_win_bonus(), 0.02 * lv)
	check(ok and ClubBuilds.gold_win_bonus() <= 0.10, "stands: +2% a level, at most +10%")
	ClubBuilds.utility_enabled = false
	check(is_zero_approx(ClubBuilds.gold_win_bonus()), "no perk online")
	ClubBuilds.utility_enabled = true
	var limits := []
	for lv in 6:
		SaveData.club = {"levels": {"bar": lv}}
		limits.append(ClubBuilds.bet_limit())
	check(limits == [25, 50, 150, 300, 500, 1000], "the bar takes bigger bets as it grows %s" % str(limits))
	SaveData.titles = 0
	SaveData.played = 0
	SaveData.club = {}
	SaveData.gold = 100000
	check(not ClubBuilds.is_open("bar") and not ClubBuilds.can_afford("bar") and not ClubBuilds.can_afford("trophy"), "the bar waits for a title, the trophy room for a run")
	check(ClubBuilds.affordable_count() == 4, "with plenty of gold before a run: court, stands, gate, coach's room (%d)" % ClubBuilds.affordable_count())
	SaveData.played = 1
	SaveData.titles = 1
	check(ClubBuilds.affordable_count() == ClubBuilds.ORDER.size(), "all eight after a title")
	SaveData.gold = 45
	var expect := 0
	for id in ClubBuilds.ORDER:
		if ClubBuilds.next_price(id) <= 45:
			expect += 1
	check(ClubBuilds.affordable_count() == expect, "45 gold: only the first steps that cheap (%d)" % expect)
	SaveData.gold = 0
	check(ClubBuilds.affordable_count() == 0, "no gold: nothing")
	check(ClubBuilds.clean_name("  ") == "", "an empty name stays empty (the default is used)")
	check(ClubBuilds.clean_name("Клуб очень длинного имени игрока").length() <= 16, "a long name is cut to 16")
	check(ClubBuilds.clean_name("Клуб сука") == "", "a rude name is refused")
	check(ClubBuilds.club_name() != "", "there is always a name for the sign")
	check(ClubBuilds.line("gate", 1).contains(ClubBuilds.club_name()), "the coach says the club's name at its sign")
	SaveData.club = {}
	SaveData.played = 0
	SaveData.titles = 0


## The coach's quests (hub spec 5): three a run from a pool of 15, progress by events,
## rewards by the island, every third one an item.
func test_quests() -> void:
	print("quests")
	SaveData.club = {}
	SaveData.gold = 0
	check(ClubQuests.TEMPLATES.size() >= 12, "a pool of at least 12 (%d)" % ClubQuests.TEMPLATES.size())
	var fine := true
	for t in ClubQuests.TEMPLATES:
		fine = fine and (t["n"] as Array).size() == 3 and int(t["gold"]) >= 20 and int(t["gold"]) <= 60 and t["event"] != ""
	check(fine, "every template: three thresholds, 20..60 gold, an event")
	ClubQuests.start_run("111", 0)
	var q: Array = ClubQuests.current()
	check(q.size() == 3, "three quests a run")
	check(q[0]["tpl"] != q[1]["tpl"] and q[1]["tpl"] != q[2]["tpl"] and q[0]["tpl"] != q[2]["tpl"], "three different ones")
	var again := ClubQuests.current().duplicate(true)
	ClubQuests.start_run("111", 0)
	check(ClubQuests.current() == again, "the same run: the same quests")
	SaveData.club = {}
	ClubQuests.start_run("111", 0)
	check(ClubQuests.current() == again, "the same run's seed gives the same quests")
	# Progress: drive the first quest to its end by its own event.
	var first: Dictionary = ClubQuests.current()[0]
	var ev: String = first["event"]
	var need := float(first["need"])
	if first["kind"] == "max":
		ClubQuests.note(ev, need - 0.5 if need > 1.0 else 0.0)
		check(not ClubQuests.progress(0)["done"], "short of the mark: not done")
		ClubQuests.note(ev, need)
	else:
		for k in int(need) - 1:
			ClubQuests.note(ev, 1.0)
		check(not ClubQuests.progress(0)["done"], "one short: not done")
		ClubQuests.note(ev, 1.0)
	check(ClubQuests.progress(0)["done"], "done when the count is reached (%s)" % ev)
	check(ClubQuests.claimable_count() == 1, "one to collect")
	var gold0 := SaveData.gold
	var reward := ClubQuests.claim(0)
	check(int(reward["gold"]) >= 20 and SaveData.gold == gold0 + int(reward["gold"]), "the gold comes on 'Забрать' (+%d)" % int(reward["gold"]))
	check(ClubQuests.claim(0).is_empty() and ClubQuests.claim(1).is_empty(), "no claiming twice, nothing for an unfinished one")
	# A match-scope count starts again each match.
	SaveData.club = {"quests": {"run": "x", "issued": 0, "claimed": 0, "list": [
		{"tpl": "aces", "text": "", "event": "ace", "kind": "count", "scope": "match", "need": 3, "have": 0, "done": false, "claimed": false, "gold": 40, "item": false, "tier": 0}]}}
	ClubQuests.note("ace")
	ClubQuests.note("ace")
	ClubQuests.match_started()
	check(int(ClubQuests.progress(0)["have"]) == 0, "aces in a match: counted afresh each match")
	# A new run burns what wasn't done; done-but-not-collected stays.
	SaveData.club = {}
	ClubQuests.start_run("A", 0)
	var l: Array = ClubQuests.current()
	l[0]["have"] = l[0]["need"]
	l[0]["done"] = true
	ClubQuests.start_run("B", 0)
	check(ClubQuests.current().size() == 4 and ClubQuests.claimable_count() == 1, "a new run: the old unfinished go, the finished one waits to be collected")
	# Rewards by island; every third quest an item.
	SaveData.club = {}
	ClubQuests.start_run("C", 3)
	var paris: Dictionary = ClubQuests.current()[0]
	var tpl := ClubQuests.find_template(paris["tpl"])
	check(int(paris["gold"]) == roundi(int(tpl["gold"]) * ClubQuests.GOLD_MULT[3]), "Paris pays x2")
	check(not ClubQuests.current()[0]["item"] and not ClubQuests.current()[1]["item"] and ClubQuests.current()[2]["item"], "the third quest carries an item")
	var third: Dictionary = ClubQuests.current()[2]
	third["have"] = third["need"]
	third["done"] = true
	SaveData.active = null
	SaveData.run = {}
	var r3 := ClubQuests.claim(2)
	var item: Dictionary = r3.get("item", {})
	check(not item.is_empty() and int(item["rarity"]) >= Gear.RARE, "an item, rare or better")
	check(r3["to"] == "locker" or (r3["to"] == "club" and (SaveData.club.get("quest_items", []) as Array).size() == 1), "with no run the item goes to the locker (or waits in the club until stream A's locker)")
	check(ClubQuests.tier_of("park") == 0 and ClubQuests.tier_of("paris") == 3, "islands: New York 0 .. Paris 3")
	SaveData.club = {}
	SaveData.gold = 0


## The shop and the locker room are constructions too (hub spec 1, 2).
func test_shop_locker() -> void:
	print("shop and locker")
	SaveData.club = {}
	check(ClubBuilds.max_level("shop") == 5 and ClubBuilds.max_level("locker") == 5, "shop and locker room: 5 levels")
	var stock := []
	var rar := []
	for lv in 6:
		SaveData.club = {"levels": {"shop": lv}}
		stock.append(ClubBuilds.shop_stock())
		rar.append(ClubBuilds.shop_max_rarity())
	check(stock == [2, 3, 3, 4, 4, 4] and rar == [Gear.RARE, Gear.EPIC, Gear.LEGENDARY, Gear.LEGENDARY, Gear.LEGENDARY, Gear.LEGENDARY], "the shop's window grows: %s" % str(stock))
	var slots := []
	for lv in 6:
		SaveData.club = {"levels": {"locker": lv}}
		slots.append(ClubBuilds.locker_slots())
	check(slots == [1, 2, 3, 3, 4, 4], "locker slots grow to 4: %s" % str(slots))
	SaveData.club = {}
	SaveData.played = 0
	check(not ClubBuilds.is_open("shop") and not ClubBuilds.is_open("locker"), "both after the first run")
	check(ClubPlaces.find("shop").get("build", "") == "shop" and ClubPlaces.find("locker").get("build", "") == "locker", "the places grow with their constructions")
	check(ClubPlaces.state("locker", 0)["action"] == "club_locker", "the locker room's button: club_locker (stream A's screen)")


## Hub spec 13: 5 levels everywhere, geometric prices, levels 4-5 take runs to build.
func test_long_build() -> void:
	print("long build")
	SaveData.club = {}
	var total := 0
	var series := true
	var first_ok := true
	for id in ClubBuilds.ORDER:
		check(ClubBuilds.max_level(id) == 5, "%s has 5 levels" % id)
		var lv: Array = ClubBuilds.TABLE[id]["levels"]
		var p0 := float(lv[0]["price"])
		first_ok = first_ok and p0 >= 30 and p0 <= 60
		for i in lv.size():
			var want: float = p0 * ClubBuilds.PRICE_STEPS[i]
			series = series and absf(float(lv[i]["price"]) - want) <= maxf(5.0, want * 0.03)
			total += int(lv[i]["price"])
	check(ClubBuilds.ORDER.has("coach"), "the coach's room is a construction too")
	check(first_ok, "the first step is cheap (30..60)")
	check(series, "prices follow p x 1, 2.2, 5, 11.5, 26")
	check(total >= 16000 and total <= 18000, "the whole club ~17 000 (%d)" % total)
	check(int(ClubBuilds.TABLE["court"]["levels"][3].get("runs", 0)) == 2 and int(ClubBuilds.TABLE["court"]["levels"][4].get("runs", 0)) == 3, "levels 4 and 5 take 2 and 3 runs")
	var bon := []
	for l in 6:
		SaveData.club = {"levels": {"coach": l}}
		bon.append(snappedf(ClubBuilds.recovery_bonus(), 0.001))
	check(bon == [0.0, 0.01, 0.02, 0.03, 0.04, 0.05], "the coach's room: +1..+5%% recovery %s" % str(bon))
	# A level that takes runs: paid now, scaffolding until N more runs are played.
	SaveData.club = {"levels": {"court": 3}}
	SaveData.played = 7
	SaveData.titles = 1
	SaveData.gold = 100000
	var price := ClubBuilds.next_price("court")
	var score0 := SaveData._score(SaveData._to_config())
	check(ClubBuilds.buy("court") and SaveData.gold == 100000 - price, "level 4 paid at once")
	check(ClubBuilds.level("court") == 3 and ClubBuilds.runs_left("court") == 2, "scaffolding: still level 3, two runs to go")
	check(not ClubBuilds.can_afford("court") and not ClubBuilds.buy("court"), "nothing more to buy while it's being built")
	check(SaveData._score(SaveData._to_config()) >= score0, "the cloud can't undo paid scaffolding (_score counts it)")
	var cf := SaveData._to_config()
	SaveData.club = {}
	SaveData._apply(cf)
	check(ClubBuilds.runs_left("court") == 2 and ClubBuilds.level("court") == 3, "save and load keep the building in progress")
	SaveData.played = 8
	check(ClubBuilds.complete_ready().is_empty() and ClubBuilds.runs_left("court") == 1, "one run later: one to go")
	SaveData.played = 9
	check(ClubBuilds.complete_ready() == ["court"] and ClubBuilds.level("court") == 4 and ClubBuilds.runs_left("court") == 0, "two runs later: level 4 is up")
	check(ClubBuilds.buy("court") and ClubBuilds.runs_left("court") == 3, "level 5 takes three runs")
	# What the levels give: shop, locker room, bar chips, quests, the words on the scaffolding.
	var free := []
	var disc := []
	var ins := []
	for l in 6:
		SaveData.club = {"levels": {"shop": l, "locker": l}}
		free.append(ClubBuilds.shop_free_rerolls())
		disc.append(snappedf(ClubBuilds.restring_discount(), 0.01))
		ins.append(snappedf(ClubBuilds.insurance_discount(), 0.01))
	check(free == [0, 0, 0, 1, 1, 2] and disc == [0.0, 0.0, 0.0, 0.0, 0.1, 0.2], "the shop: free rerolls %s, cheaper strings %s" % [str(free), str(disc)])
	check(ins == [0.0, 0.0, 0.1, 0.1, 0.25, 0.25], "the locker room: insurance %s" % str(ins))
	var chips := []
	for l in 6:
		SaveData.club = {"levels": {"bar": l}}
		chips.append(ClubBuilds.bar_chips().back())
	check(chips == [25, 50, 100, 250, 500, 1000], "the bar's biggest chip grows with it %s" % str(chips))
	SaveData.club = {"levels": {"coach": 5}}
	var q := ClubQuests._make(ClubQuests.find_template("aces"), 0, false)
	SaveData.club = {}
	var q0 := ClubQuests._make(ClubQuests.find_template("aces"), 0, false)
	check(int(q["gold"]) > int(q0["gold"]), "the coach's room: quests pay more (%d vs %d)" % [q["gold"], q0["gold"]])
	check(ClubBuilds.scaffold_text("court") == "ГОТОВО", "no scaffolding text without a build")
	check(ClubBuilds.runs_word(1) == "забег" and ClubBuilds.runs_word(2) == "забега" and ClubBuilds.runs_word(5) == "забегов" and ClubBuilds.runs_word(11) == "забегов", "the word for runs")
	# Two levels in progress at once, the second one's runs counted from its own purchase.
	SaveData.club = {"levels": {"court": 3, "stands": 3}}
	SaveData.played = 4
	SaveData.titles = 1
	SaveData.gold = 100000
	ClubBuilds.buy("court")
	SaveData.played = 5
	ClubBuilds.buy("stands")
	check(ClubBuilds.runs_left("court") == 1 and ClubBuilds.runs_left("stands") == 2, "each building counts its own runs")
	SaveData.played = 6
	check(ClubBuilds.complete_ready() == ["court"] and ClubBuilds.is_building("stands") and ClubBuilds.level("court") == 4, "only the one whose runs are played is done")
	SaveData.club = {}
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0


## ClubMaterial: one soft toon material per colour, outlines only where they pay.
func test_material() -> void:
	print("material")
	check(ClubMaterial.PALETTE.size() == 32, "the palette has 32 colours")
	var a := ClubMaterial.get_mat(ClubMaterial.PALETTE[ClubMaterial.BRICK])
	var b := ClubMaterial.get_mat(ClubMaterial.PALETTE[ClubMaterial.BRICK])
	check(a == b, "one material per colour (MeshMerge folds them together)")
	check(a.diffuse_mode == BaseMaterial3D.DIFFUSE_LAMBERT_WRAP and a.specular_mode == BaseMaterial3D.SPECULAR_TOON, "the players' soft toon look")
	var small := ClubMaterial.get_mat(ClubMaterial.PALETTE[ClubMaterial.BRICK], false)
	check(small != a, "small things get their own material")
	ClubMaterial.set_outlines(true)
	check(a.next_pass != null and small.next_pass == null, "outline on big things only")
	ClubMaterial.set_outlines(false)
	check(a.next_pass == null, "no outline on Low")
	ClubMaterial.set_outlines(true)
	var tex := ClubMaterial.palette_texture()
	check(tex != null and tex.get_width() == 32 and tex.get_height() == 1, "palette texture 32x1")


func test_walk() -> void:
	print("walking")
	var w := ClubWalk.new()
	w.bounds = Rect2(-40, -40, 80, 80)
	w.add_box(Rect2(-2, -2, 4, 4))
	w.add_circle(Vector2(10, 0), 1.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var p := Vector2(-6, -6)
	var stuck_inside := false
	for i in 2000:
		var step := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.4)
		if i % 50 < 25:
			step = (Vector2.ZERO - p).normalized() * 0.3  # push into the box now and then
		p = w.resolve(p, p + step)
		if w.blocked(p):
			stuck_inside = true
	check(not stuck_inside, "never ends up inside an obstacle")
	# Sliding: walking diagonally into the box's left wall keeps going along it.
	var s := w.resolve(Vector2(-2.5, 0), Vector2(-2.1, 0.4))
	check(s.y > 0.3 and s.x <= -2.3, "slides along a wall (%.2f, %.2f)" % [s.x, s.y])
	check(w.resolve(Vector2(39.5, 0), Vector2(41, 0)).x <= 40.0, "stays inside the bounds")
	var q := Vector2(-20, -20)
	var target := Vector2(20, 18)
	for i in 600:
		var d := w.steer(q, target)
		if d == Vector2.ZERO:
			break
		q = w.resolve(q, q + d * 0.1)
	check(q.distance_to(target) < 0.3, "steers to a target (%.1f m off)" % q.distance_to(target))


func test_world() -> void:
	print("world")
	# Loaded at run time: ClubWorld and Club reach Athlete, which needs the autoloads
	# (a test script compiles before they exist).
	var w = load("res://scripts/club/club_world.gd").new()
	root.add_child(w)
	await process_frame
	var bm: Transform3D = w.ball_machine()
	check(bm.origin.z < -5.0 and absf(bm.origin.x) < Court.SINGLES_HALF_WIDTH, "ball machine on the far half of the main court")
	check((-bm.basis.z).z > 0.9, "the ball machine shoots toward the near baseline")
	for p in ClubPlaces.LIST:
		check(w.place_node(p["id"]) != null, "%s has its node" % p["id"])
		var c: Vector3 = p["pos"]
		check(not w.walk.blocked(Vector2(c.x, c.z)), "%s circle is walkable" % p["id"])
	# From the court's circle through the gate in the fence to the coach's pavilion.
	var pos := Vector2(0, 14)
	var goal := Vector2(16, 26)
	var via := [Vector2(0, 22), Vector2(0, 31), Vector2(16, 31), goal]
	for target in via:
		for i in 400:
			var d: Vector2 = w.walk.steer(pos, target)
			if d == Vector2.ZERO:
				break
			pos = w.walk.resolve(pos, pos + d * 0.1)
	check(pos.distance_to(goal) < 0.4, "walks from the court to the coach (%.1f m off)" % pos.distance_to(goal))
	check(Locations.find("club")["id"] == "club", "the club is a location")
	var listed := false
	for l in Locations.LIST:
		listed = listed or l["id"] == "club"
	check(not listed, "the club is not on the tournament map")
	w.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


## The club as the main screen: two taps to a match, practice on the club court, walking.
func test_flow() -> void:
	print("flow")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 0
	Skills.pending = []
	main._show_menu()
	await _frames(3)
	var club = main.club
	check(club.active and main.location_id == "club", "the menu is the club")
	check(main.player.position.distance_to(club.START) < 0.5, "the hero starts in the court's circle")
	check(club.hud.current_place() == "court", "the court's button is up")
	var first: Dictionary = club.place_buttons("court")
	check(first["label"] == "НОВАЯ ИГРА" and first["extra"].is_empty(), "first time: just НОВАЯ ИГРА")
	check(club.hud.buttons.has(club.hud.gear), "the gear is a button the joystick leaves alone")
	check(main.hud.has_method("_toggle_debug"), "the gear opens Hud's settings sheet")
	# Tap 1: no tournament remembered -> the location screen (the old way).
	club._on_choice("club_tournament", 0)
	await _frames(2)
	check(main.ui.is_open() and main.tournament == null, "no last tournament: the location screen")
	main._on_ui("location", 1)  # Spain
	main._on_ui("format", 0)
	await _frames(3)
	check(SaveData.club.get("last_location", "") == "clay" and int(SaveData.club.get("last_format", -1)) == 0, "the choice is remembered")
	check(not club.active, "a tournament's bracket closes the club")
	# Back to the club, then "Турнир" goes straight to the bracket: tap 1 Турнир, tap 2 Играть.
	SaveData.active = null
	SaveData.run = {}
	main._show_menu()
	await _frames(3)
	check(club.active and main.player.position.distance_to(club.START) < 0.5, "back in the club, at the court")
	var again: Dictionary = club.place_buttons("court")
	check(again["label"].begins_with("НОВАЯ ИГРА  ·  ИСПАНИЯ") and again["extra"].size() == 1, "the button names the last place, one quiet 'другое место'")
	check(again["extra"][0][1] == "club_locations", "'Другое место' opens the club's islands screen")
	var screens: GDScript = load("res://scripts/club/club_screens.gd")  # loaded: it reaches the autoloads
	check(screens.loc_unlocked("grass") and screens.loc_hint("grass") == "", "no Locations.unlocked yet: everything open (a stub)")
	club._on_choice("club_locations", 0)
	await _frames(2)
	check(main.ui.is_open(), "the islands screen opens")
	screens.locations(main.ui, func(id: String) -> bool: return id == "park", func(id: String) -> String: return "за титул в Испании")
	await _frames(1)
	var locked := 0
	for c in main.ui._box.get_children():
		if c is Button and (c as Button).disabled:
			locked += 1
	check(locked == Locations.LIST.size() - 1, "locked islands show a lock and can't be picked (%d)" % locked)
	main._on_ui("location", 0)
	await _frames(2)
	check(main.ui.is_open(), "an open island: on to the formats, as before")
	main._on_ui("menu", 0)
	await _frames(2)
	club._on_choice("club_tournament", 0)
	await _frames(3)
	check(main.tournament != null and main.location_id == "clay" and main.ui.is_open(), "one tap: the bracket in Spain")
	var run_buttons: Dictionary = club.place_buttons("court")
	check(run_buttons["action"] == "continue" and run_buttons["extra"].size() == 1, "a run: ПРОДОЛЖИТЬ and one 'Новая игра'")
	SaveData.active = null
	SaveData.run = {}
	main._show_menu()
	await _frames(3)
	# Practice from the club plays on the club's own court.
	club._on_choice("practice", 0)
	await _frames(3)
	check(main.location_id == "club" and not club.active and main.phase != club._idle, "practice on the club court")
	check(main.player.area == main.PLAYER_AREA and is_equal_approx(main.player.rotation.y, 0.0), "the match gets its player back")
	main._show_menu()
	await _frames(3)
	# Walking by a tap: the hero heads there and never ends up in a wall.
	club._move_target = Vector3(16, 0, 31)
	var inside_wall := false
	for i in 400:
		await physics_frame
		var p: Vector3 = main.player.position
		if club.world.walk.blocked(Vector2(p.x, p.z), 0.3):
			inside_wall = true
	var reached: Vector3 = main.player.position
	check(not inside_wall, "walking never ends inside a wall")
	check(Vector2(reached.x - 16, reached.z - 31).length() < 1.0, "walks out through the gate to the pavilions (%.1f m off)" % Vector2(reached.x - 16, reached.z - 31).length())
	club._travel("coach")
	await _frames(3)
	check(club.hud.current_place() == "coach", "quick travel lands in the coach's circle")
	main.queue_free()
	await _frames(2)


## The places' own actions: the shop's screen, a place's card, the roulette at the bar.
func test_places_flow() -> void:
	print("places flow")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 1
	SaveData.titles = 1
	SaveData.gold = 400
	SaveData.bets = {}
	Skills.pending = []
	main._show_menu()
	await _frames(3)
	var club = main.club
	var w = club.world
	check(not w.walk.route(Vector2(0, 14), Vector2(22, 2)).is_empty(), "a way from the court to the shop")
	check(not w.walk.route(Vector2(0, 14), Vector2(20, -30)).is_empty(), "a way from the court to the bar")
	var bjp: Vector3 = ClubPlaces.find("blackjack")["pos"]
	check(not w.walk.route(Vector2(0, 14), Vector2(bjp.x, bjp.z)).is_empty(), "a way from the court to the blackjack table")
	var bjt: Transform3D = w.blackjack()
	check(bjt.origin.distance_to(bjp) < 3.5 and (-bjt.basis.z).z < -0.9, "the blackjack table's marker: by its circle, the dealer's side toward the river")
	check(w.blackjack_root() != null and w.blackjack_root().name == "blackjack_table", "stream E's scene has a node to stand in")
	club._travel("shop")
	await _frames(3)
	check(club.hud.current_place() == "shop", "quick travel to the shop")
	var before: int = w.place_node("shop").get_child_count()
	w.set_level("shop", 2)
	await _frames(1)
	check(w.place_node("shop") != null, "the shop rebuilds for a new level")
	club._on_choice("club_shop", 0)
	await _frames(3)
	check(main.ui.is_open(), "the shop's screen opens")
	main._on_ui("menu", 0)
	await _frames(3)
	check(club.active and not main.ui.is_open() and club.hud.current_place() == "shop", "back from the shop: still at the shop")
	club._travel("arena")
	await _frames(2)
	club._on_choice("club_place", 0)
	await _frames(2)
	check(main.ui.is_open(), "the arena site tells what will be there")
	main._on_ui("menu", 0)
	await _frames(2)
	# The bar: the roulette in 3D.
	club._travel("bar")
	await _frames(3)
	check(club.hud.current_place() == "bar", "quick travel to the bar")
	club._on_choice("club_roulette", 0)
	await _frames(3)
	check(club.roulette_on() and not main.ui.is_open(), "the roulette is a 3D scene at the bar, not a screen")
	var limit: int = int(ClubPlaces.state("bar", 0)["bet_limit"])
	check(club.chips().all(func(c): return c <= limit and c <= Bets.max_stake(SaveData.gold)), "chips within the bar's limit and a quarter of the gold")
	var gold0: int = SaveData.gold
	var spin: Dictionary = club.spin("blue", 10)
	check(not spin.is_empty(), "a spin goes")
	check(SaveData.gold == gold0 - 10 + int(spin["paid"]), "the stake goes, the win comes (Bets.payout)")
	check(int(spin["paid"]) == Bets.payout("blue", 10, int(spin["field"])), "paid as the desk pays")
	check(club.spin("red", 10).is_empty(), "no second spin while the ball rolls")
	club.roulette_skip()
	await _frames(2)
	check(not club.roulette_busy(), "a tap shows the end at once")
	check(club.spin("red", 100000).is_empty(), "no stake over the limit")
	club.roulette_close()
	await _frames(2)
	check(not club.roulette_on() and club.hud.current_place() == "bar", "back from the roulette: at the bar")
	club._travel("blackjack")
	await _frames(2)
	check(club.hud.current_place() == "blackjack", "quick travel to the blackjack table")
	club._on_choice("club_blackjack", 0)
	await _frames(2)
	check(main.ui.is_open() or club.get("blackjack_on") == true, "Блэкджек: stream E's scene, or a 'скоро' card until it comes")
	main._on_ui("menu", 0)
	await _frames(2)
	main.queue_free()
	await _frames(2)
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0


## Every level of every construction builds (and its ghost), headless.
func test_build_world() -> void:
	print("build world")
	var w = load("res://scripts/club/club_world.gd").new()
	root.add_child(w)
	await process_frame
	var fine := true
	var ghosts := true
	for id in ClubBuilds.ORDER:
		for lv in ClubBuilds.max_level(id) + 1:
			w.set_level(id, lv)
			if w.level_built(id) != lv:
				fine = false
		w.show_ghost(id, ClubBuilds.max_level(id))
		ghosts = ghosts and w.ghost_id() == id
		w.show_ghost("", 0)
	check(ghosts, "every construction has its ghost (the rooms too)")
	var scaff := true
	for id in ClubBuilds.ORDER:
		w.set_scaffold(id, true)
		scaff = scaff and w.scaffold_visible(id)
		w.set_scaffold(id, false)
		scaff = scaff and not w.scaffold_visible(id)
	check(scaff, "scaffolding stands at every construction while it's being built")
	check(fine, "every level of the five constructions builds")
	w.set_club_color(1)
	check(true, "the club's colour paints without errors")
	w.queue_free()
	await process_frame


## The foreman's cards and the build moment: the gold goes first, a tap skips the show.
func test_foreman_flow() -> void:
	print("foreman")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 1
	SaveData.titles = 1
	SaveData.gold = 1000
	Skills.pending = []
	main._show_menu()
	await _frames(3)
	var club = main.club
	club._travel("gate")
	await _frames(2)
	check(club.place_buttons("gate")["action"] == "club_foreman", "the gate's button is the foreman")
	club._on_choice("club_foreman", 0)
	await _frames(2)
	check(club.foreman_on() and club.hud.foreman_visible(), "the foreman's cards are up")
	club.foreman_show("stands")
	await _frames(2)
	check(club.world.ghost_id() == "stands", "the next level of the card in the middle stands as a ghost")
	check(club.foreman_build(), "build the stands")
	check(SaveData.gold == 950 and ClubBuilds.level("stands") == 1, "the gold goes at once")
	check(club.building(), "the build moment plays")
	club.skip_build()
	await _frames(2)
	check(not club.building() and club.world.level_built("stands") == 1, "a tap: straight to the new level")
	check(club.foreman_build() and ClubBuilds.level("stands") == 2, "build again")
	await create_timer(2.6).timeout  # Club.BUILD_TIME + a little
	check(not club.building() and club.world.level_built("stands") == 2, "without a tap: the same end")
	SaveData.gold = 0
	club.foreman_show("bar")
	check(not club.foreman_build() and ClubBuilds.level("bar") == 0, "no gold: no build")
	club.foreman_close()
	await _frames(2)
	check(not club.foreman_on() and club.world.ghost_id() == "", "back: no ghost, the club as it is")
	# Level 4 takes runs: scaffolding now, the build moment when the club opens after them.
	SaveData.club["levels"] = {"stands": 3}
	SaveData.gold = 5000
	club._refresh()
	club.foreman_open("stands")
	check(club.foreman_build() and ClubBuilds.runs_left("stands") == 2, "level 4 of the stands: paid, scaffolding")
	club.skip_build()
	await _frames(2)
	check(club.world.scaffold_visible("stands") and club.world.level_built("stands") == 3, "scaffolding stands, the level not yet")
	club.foreman_close()
	SaveData.played += 2
	club.open()
	await _frames(2)
	check(ClubBuilds.level("stands") == 4 and club.building(), "after two runs, entering the club: the build moment")
	club.skip_build()
	await _frames(2)
	check(not club.world.scaffold_visible("stands") and club.world.level_built("stands") == 4, "the scaffolding goes, level 4 stands")
	SaveData.gold = 500
	SaveData.club["levels"] = {}
	club._refresh()
	club._travel("bar")
	await _frames(2)
	check(club.upgrade_price("bar") == 50, "an affordable upgrade shows by its place (↑ 50)")
	check(club.upgrade_price("court") == 0, "never on the main screen: Новая игра / Продолжить stay alone")
	main.queue_free()
	await _frames(2)
	SaveData.club = {}
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0


## Quests in play: GameEvents move them, the coach's room shows them, 'Забрать' pays.
func test_quests_flow() -> void:
	print("quests flow")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {"last_location": "park", "last_format": 0}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 1
	SaveData.gold = 0
	Skills.pending = []
	Skills.points = 0
	main._show_menu()
	await _frames(3)
	var club = main.club
	club._on_choice("club_tournament", 0)   # a run starts: its bracket
	await _frames(2)
	main.tournament_mode = true
	var ev: Node = root.get_node("GameEvents")  # by path: the test compiles before autoloads
	ev.match_started.emit({"tournament": true, "opponent": ""})
	await _frames(1)
	var q: Array = ClubQuests.current()
	check(q.size() == 3 and SaveData.club["quests"]["run"] == str(main.tournament.rng.seed), "the run's first match deals three quests")
	# Force a known quest in slot 0 and play its events through GameEvents.
	q[0] = {"tpl": "aces", "text": "Подай 2 эйса за матч", "event": "ace", "kind": "count", "scope": "match", "need": 2, "have": 0, "done": false, "claimed": false, "gold": 40, "item": false, "tier": 0}
	var got := []
	ev.quest_done.connect(func(info: Dictionary) -> void: got.append(info))
	for k in 2:
		ev.point.emit({"winner": 0, "reason": "ACE", "rally": 1, "server": 0, "close_call": {}, "best": false})
	await _frames(1)
	check(ClubQuests.progress(0)["done"] and got.any(func(x): return int(x["index"]) == 0), "two aces by GameEvents: done, quest_done fired")
	q[1] = {"tpl": "streak", "text": "", "event": "streak", "kind": "max", "scope": "run", "need": 3, "have": 0, "done": false, "claimed": false, "gold": 35, "item": false, "tier": 0}
	ev.point.emit({"winner": 0, "reason": "OUT", "rally": 3, "server": 1, "close_call": {}, "best": false})
	check(ClubQuests.progress(1)["done"], "points in a row are counted across reasons")
	main.tournament_mode = false
	main._show_menu()
	await _frames(3)
	club._travel("coach")
	await _frames(2)
	var b: Dictionary = club.place_buttons("coach")
	check(b["action"] == "club_claim" and String(b["label"]).begins_with("ЗАБРАТЬ"), "at the coach's: ЗАБРАТЬ")
	check(club.badge_counts()["coach"] >= 2, "the badge over the coach's room counts what's to collect")
	check(club.world.board_text().contains("✓"), "the chalkboard shows the quests")
	var g0: int = SaveData.gold
	club._on_choice("club_claim", 0)
	await _frames(2)
	check(SaveData.gold >= g0 + 75 and ClubQuests.claimable_count() == 0, "Забрать: all the rewards at once")
	check(club.place_buttons("coach")["action"] == "character", "then the button is НАВЫКИ again")
	club._on_choice("club_quests", 0)
	await _frames(2)
	check(main.ui.is_open(), "the quests' board screen")
	main._on_ui("menu", 0)
	main.queue_free()
	await _frames(2)
	SaveData.club = {}
	SaveData.played = 0
	SaveData.gold = 0


## The owner's phone test (08.10): taps walk, never press; the club's props leave the
## court for a match; every way out of the club comes back to it.
func test_transitions() -> void:
	print("transitions")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {"last_location": "clay", "last_format": 0, "met_coach": true}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 1
	Skills.pending = []
	main._show_menu()
	await _frames(3)
	var club = main.club
	# 1. A tap on a place (the machine's circle on the court) walks there; it never starts
	# practice. Only the button does.
	var mp: Vector3 = ClubPlaces.find("machine")["pos"]
	var screen: Vector2 = club.cam.unproject_position(mp)
	club._on_tap(screen)
	await _frames(3)
	check(club.active and main.phase == club._idle, "a tap on the machine's circle doesn't start a match")
	check(club._move_target != Vector3.INF and Vector2(club._move_target.x - mp.x, club._move_target.z - mp.z).length() < 0.5, "it walks the hero to the place")
	for i in 240:
		await physics_frame
		if club.hud.current_place() == "machine":
			break
	check(club.hud.current_place() == "machine", "arrived: the place's button shows (%s)" % club.hud.current_place())
	check(not club.hud.buttons.has(club.hud._bubble) and club.hud._bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the coach's bubble never eats a tap")
	# Hold to walk (tap mode): the hero follows the finger.
	club._move_target = Vector3.INF
	club._on_hold(club.cam.unproject_position(Vector3(-4, 0, 12)))
	check(club._move_target != Vector3.INF, "holding the finger walks the hero toward it")
	club._move_target = Vector3.INF
	# 3. Leaving the court's circle: the buttons go, a hint once.
	club._travel("court")
	await _frames(2)
	check(club.hud.current_place() == "court", "the main screen's buttons in the court's circle")
	SaveData.club.erase("walk_hint")
	main.player.position = Vector3(0, 0, 20.5)
	await _frames(3)
	check(club.hud.current_place() == "", "out of the circle: Новая игра / Продолжить ride away")
	check(club.hud.hint_shown(), "a hint how to walk, the first time")
	check(SaveData.club.get("walk_hint", false), "only once")
	club._travel("court")
	await _frames(2)
	# Club -> the bracket -> back: in the club, the hero where he was.
	var before: Vector3 = main.player.position
	club._on_choice("club_tournament", 0)
	await _frames(3)
	check(main.ui.is_open() and not club.active, "the bracket")
	main._on_ui("menu", 0)
	await _frames(3)
	check(club.active and main.location_id == "club" and main.player.position.distance_to(before) < 0.6, "back from the bracket: the club, the hero where he was")
	SaveData.active = null
	SaveData.run = {}
	# 2. Practice on the club's court: no machine, coach props or circles on it.
	club._on_choice("practice", 0)
	await _frames(3)
	check(main.phase != club._idle and main.location_id == "club", "practice on the club court")
	check(not club.world.props_visible(), "the machine and the circles leave the court for the match")
	check(not main.cpu.get_meta("club_coach", false), "the opponent is not the coach in his cap")
	# Pause in the match -> 'Выйти в клуб'.
	main.hud.menu_requested.emit()
	await _frames(3)
	check(club.active and main.phase == club._idle and not main.get_tree().paused, "Выйти в клуб from a match: the club, not paused")
	check(club.world.props_visible(), "the props are back")
	# A tournament match to its end -> the result -> the club.
	club._on_choice("club_tournament", 0)
	await _frames(2)
	main._on_ui("play", 0)
	await _frames(3)
	check(main.phase != club._idle and not club.active, "a tournament match")
	main.scoreboard.winner = 0
	main._finish_match()
	await _frames(3)
	check(main.ui.is_open(), "its result")
	main._on_ui("menu", 0)
	await _frames(3)
	check(club.active and main.location_id == "club" and club.world.props_visible(), "from the result: back in the club")
	main.queue_free()
	await _frames(2)
	SaveData.club = {}
	SaveData.played = 0
	SaveData.active = null
	SaveData.run = {}
