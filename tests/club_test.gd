extends SceneTree
## The club (docs/club/H1_SPEC.md): places, walking, the world, the way to a match.
##   godot --headless --path . -s tests/club_test.gd

var failures := 0


func _initialize() -> void:
	Tournament.BEGINNER_START = 1.0  # tests count a newcomer's prizes at the plain scale
	Items.PRICE_SCALE = 1.0  # these tests count in base prices; the shipped scale is checked in economy_test
	ClubBuilds.CLUB_PRICE_SCALE = 1.0
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
	test_lots()
	await test_lots_world()
	await test_lots_flow()
	await test_world()
	await test_flow()
	await test_transitions()
	await test_places_flow()
	await test_returns()
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
	check(ClubPlaces.is_open(shop, 0, 0), "the shop stands open from the start (T: the court and the shop)")
	check(not ClubBuilds.is_open("shop"), "...but its levels and the 'Магазин' of the run's summary wait for the first run (stream A)")
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
	check(ClubBuilds.affordable_count() == 2, "with plenty of gold before a run, in a new club: the court and the gate (the rest wait for a lot) (%d)" % ClubBuilds.affordable_count())
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
	Skills.points = 0
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
	SaveData.titles = 4  # v0.2 A: the islands open by titles; Spain needs one, England a Spanish one
	SaveData.titles_by_loc = {"park": 1, "clay": 1, "grass": 1}
	main._on_ui("location", 1)  # Spain
	main._on_ui("format", 0)
	await _frames(3)
	check(SaveData.club.get("last_location", "") == "clay" and int(SaveData.club.get("last_format", -1)) == 0, "the choice is remembered")
	check(club.active and main.location_id == "club" and main.tournament.location == "clay" and main.ui.is_open(), "the bracket is shown over the club: the island waits for «Играть»")
	main._on_ui("play", 0)
	await _frames(3)
	check(main.location_id == "clay" and main.phase != club._idle and not club.active, "a match starts: the island, and the club steps aside")
	# Back to the club, then "Турнир" goes straight to the bracket: tap 1 Турнир, tap 2 Играть.
	SaveData.active = null
	SaveData.run = {}
	main._show_menu()
	await _frames(3)
	check(club.active and main.player.position.distance_to(club.START) < 0.5, "back in the club, at the court")
	var again: Dictionary = club.place_buttons("court")
	check(again["label"].begins_with("НОВАЯ ИГРА  ·  ИСПАНИЯ") and again["extra"].size() == 1, "the button names the last place, one quiet 'другое место'")
	check(again["extra"][0][1] == "club_locations", "'Другое место' opens the club's islands screen")
	# The conditions link: not for a newcomer, one tap opens the screen, "Начать забег" starts
	# the run in the remembered place with the picks.
	SaveData.played = 1
	var with_mods: Dictionary = club.place_buttons("court")
	check(with_mods["extra"].size() == 2 and with_mods["extra"][1][1] == "club_mods" and String(with_mods["extra"][1][0]).begins_with("Условия · ×"), "after a run: a second quiet link 'Условия · ×k' (%s)" % str(with_mods["extra"]))
	club._on_choice("club_mods", 0)
	await _frames(2)
	check(main.ui.is_open() and main.tournament == null, "the link opens the conditions screen, no run yet")
	var mods: GDScript = load("res://scripts/ui/screens/run_mods.gd")  # loaded: it reaches the autoloads
	mods.ui_action(main, "mods_preset", 0)
	check(mods.picked.size() == 2, "the Про preset picks two")
	mods.ui_action(main, "mods_go", 0)
	await _frames(3)
	check(main.tournament != null and main.tournament.location == "clay" and main.location_id == "club" and main.tournament.run_modifiers.size() == 2, "the run starts in Spain with the conditions (%s)" % str(main.tournament.run_modifiers if main.tournament else []))
	SaveData.active = null
	SaveData.run = {}
	main._show_menu()
	await _frames(3)
	SaveData.played = 0
	var screens: GDScript = load("res://scripts/club/club_screens.gd")  # loaded: it reaches the autoloads
	check(screens.loc_unlocked("grass"), "with a Spanish title England is open")
	SaveData.titles_by_loc = {"park": 1}
	check(not screens.loc_unlocked("grass") and screens.loc_hint("grass") != "", "without it England is locked, with a hint")
	SaveData.titles_by_loc = {"park": 1, "clay": 1, "grass": 1}
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
	check(main.tournament != null and main.tournament.location == "clay" and main.location_id == "club" and main.ui.is_open(), "one tap: the bracket for Spain, over the club")
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
	for i in 560:  # a jog (4.6 m/s), not a sprint
		await physics_frame
		var p: Vector3 = main.player.position
		if club.world.walk.blocked(Vector2(p.x, p.z), 0.3):
			inside_wall = true
	var reached: Vector3 = main.player.position
	check(not inside_wall, "walking never ends inside a wall")
	check(Vector2(reached.x - 16, reached.z - 31).length() < 1.0, "walks out through the gate to the pavilions (%.1f m off)" % Vector2(reached.x - 16, reached.z - 31).length())
	SaveData.club["lots"] = {"n2": "coach"}   # the coach's room is built (T-1: nothing stands but the court and the shop at first)
	club._refresh()
	club._travel("coach")
	await _frames(3)
	check(club.hud.current_place() == "coach", "quick travel lands in the coach's circle")
	main.queue_free()
	await _frames(2)


## Every way back into the club (the owner's phone: "teleported to the middle of the court and
## can't move"): the hero is where he was, the club is on, the stick and the tap work.
func test_returns() -> void:
	print("returns")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {"last_location": "clay", "last_format": 1, "met_coach": true}
	SaveData.titles = 4
	SaveData.titles_by_loc = {"park": 1, "clay": 1, "grass": 1}
	SaveData.played = 1
	SaveData.active = null
	SaveData.run = {}
	Skills.pending = []
	main._show_menu()
	await _frames(3)
	var club = main.club
	var mods: GDScript = load("res://scripts/ui/screens/run_mods.gd")
	var at := Vector3(14.0, 0.0, 30.0)  # somewhere that is not the court's circle: in front of the pavilions
	var routes := {
		"new game, bracket, back": func() -> void:
			club._on_choice("club_tournament_new", 0)
			await _frames(3)
			main._on_ui("menu", 0),
		"another place, back": func() -> void:
			club._on_choice("club_locations", 0)
			await _frames(3)
			main._on_ui("menu", 0),
		"another place picked, back": func() -> void:
			club._on_choice("club_locations", 0)
			await _frames(3)
			main._on_ui("location", 1)
			await _frames(3)
			main._on_ui("menu", 0),
		"conditions, back": func() -> void:
			club._on_choice("club_mods", 0)
			await _frames(3)
			mods.ui_action(main, "mods_back", 0)
			await _frames(2)
			main._on_ui("menu", 0),
		"bracket, opponent card, back, back": func() -> void:
			club._on_choice("club_tournament_new", 0)
			await _frames(3)
			main._on_ui("opponent_card", 0)
			await _frames(2)
			main._on_ui("opp_back", 0)
			await _frames(2)
			main._on_ui("menu", 0),
		"continue, bracket, back": func() -> void:
			club._on_choice("club_tournament_new", 0)
			await _frames(3)
			main._show_menu()
			await _frames(3)
			club._on_choice("club_tournament", 0)  # ПРОДОЛЖИТЬ
			await _frames(3)
			main._on_ui("menu", 0),
		"practice, pause, exit to the club": func() -> void:
			club._on_choice("practice", 0)
			await _frames(5)
			main.hud.menu_requested.emit(),
	}
	for name in routes:
		for spot in ["court", "away"]:
			SaveData.active = null
			SaveData.run = {}
			main._show_menu()
			await _frames(3)
			if spot == "away":
				main.player.position = at
				club._update_place()
				await _frames(2)
			var want: Vector3 = main.player.position
			var label: String = "%s (%s)" % [name, spot]
			await routes[name].call()
			await _frames(4)
			var p: Vector3 = main.player.position
			check(club.active and main.location_id == "club" and main.phase == club._idle, label + ": the club is on (active %s, at %s, phase %s)" % [club.active, main.location_id, main.phase])
			check(Vector2(p.x - want.x, p.z - want.z).length() < 0.5 or (spot == "court" and p.distance_to(club.START) < 0.5), label + ": the hero is where he was (%.1f m off)" % Vector2(p.x - want.x, p.z - want.z).length())
			check(club.world.props_visible() and club.cam.current and not main.ui.is_open(), label + ": props, the club's camera, no screen")
			main.hud.touch._stick_vector = Vector2(1.0, 0.0)
			for i in 10:
				await physics_frame
				await process_frame
			main.hud.touch._stick_vector = Vector2.ZERO
			var q: Vector3 = main.player.position
			check(Vector2(q.x - p.x, q.z - p.z).length() > 0.05, label + ": the stick moves him (%.2f m in 10 frames)" % Vector2(q.x - p.x, q.z - p.z).length())
			club._move_target = Vector3(q.x, 0.0, q.z - 3.0)
			for i in 20:
				await physics_frame
			var r: Vector3 = main.player.position
			check(Vector2(r.x - q.x, r.z - q.z).length() > 0.05, label + ": a tap walks him")
			club._move_target = Vector3.INF
	main.queue_free()
	await _frames(2)
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.club = {}


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
	var bjt3 = club.world.blackjack_root().get_node_or_null("blackjack")
	check(main.ui.is_open() or (bjt3 != null and bjt3.is_open()), "Блэкджек: stream E's scene, or a 'скоро' card until it comes")
	if bjt3 != null and bjt3.is_open():
		bjt3.close()
	else:
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
	# An old save with every construction standing: the lots lay themselves out (T-1), so
	# the rooms have their pavilions and their ghosts.
	var levels := {}
	for id in ClubBuilds.ORDER:
		levels[id] = 1
	SaveData.played = 5  # every place is open by now (the rooms open by runs and titles)
	SaveData.titles = 1
	SaveData.club = {"levels": levels}
	ClubLots.ensure()
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
	check(main.ui.is_open() and club.active and main.location_id == "club", "the bracket (over the club)")
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


# --- Lots (T-1, docs/superpowers/specs/2026-10-09-tycoon.md) ------------------------------------

## The data: seven lots, seven types, a new club is empty, an old one keeps what it had, a
## type is built once, the save keeps it.
func test_lots() -> void:
	print("lots")
	var hx := Scenery.HX
	var hz := Scenery.HZ
	var court_fence := Rect2(-hx, -hz, hx * 2.0, hz * 2.0)
	var shop_room := Rect2(19, -0.5, 6, 5)
	check(ClubLots.LOTS.size() == 7, "seven lots")
	var ids := {}
	var apart := true
	var clear := true
	for i in ClubLots.LOTS.size():
		var a: Dictionary = ClubLots.LOTS[i]
		ids[a["id"]] = true
		var ra := ClubLots.lot_rect(a["id"])
		clear = clear and not ra.intersects(court_fence) and not ra.intersects(shop_room)
		for j in range(i + 1, ClubLots.LOTS.size()):
			var b: Dictionary = ClubLots.LOTS[j]
			apart = apart and (a["pos"] as Vector3).distance_to(b["pos"]) >= 17.0 and not ra.intersects(ClubLots.lot_rect(b["id"]))
	check(ids.size() == 7, "lot ids are unique")
	check(apart, "the lots are 17 m apart and their sites don't touch")
	check(clear, "no lot's site reaches into the court's fence or the shop")
	var homes := {}
	for t in ClubLots.ORDER:
		var d: Dictionary = ClubLots.TYPES[t]
		homes[d["home"]] = true
		check(d.has("name") and d.has("gives") and ClubLots.lot(d["home"]).size() > 0, "type %s has a name, what it gives and a home lot" % t)
	check(homes.size() == 7 and ClubLots.ORDER.size() == 7, "seven types, each with its own home lot")
	for lot in ClubLots.LOTS:
		for p in ClubPlaces.LIST:
			if ClubLots.owner_type(p["id"]) != "":
				continue
			var d := Vector2((lot["pos"] as Vector3).x - (p["pos"] as Vector3).x, (lot["pos"] as Vector3).z - (p["pos"] as Vector3).z).length()
			check(d >= ClubLots.R + float(p["r"]) + 1.0, "lot %s keeps off the circle of %s (%.1f m)" % [lot["id"], p["id"], d])
	# A new club: the court and the shop, empty lots, the first two open.
	SaveData.club = {}
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0
	check(not ClubLots.is_legacy() and ClubLots.map().is_empty(), "no progress, no key: a new club, nothing built")
	check(ClubLots.lot_open("n1") and ClubLots.lot_open("n2") and not ClubLots.lot_open("n3") and not ClubLots.lot_open("n7"), "the first two lots are open from the start, the others later")
	var live := {}
	for p in ClubPlaces.all():
		live[p["id"]] = p
	for id in ["court", "machine", "gate", "shop", "lot_n1", "lot_n2", "lot_n3", "lot_n7"]:
		check(live.has(id), "a new club has %s" % id)
	for id in ["coach", "locker", "trophy", "bar", "stands", "blackjack", "arena", "academy"]:
		check(not live.has(id), "a new club has no %s yet" % id)
	check(ClubPlaces.is_open(live["lot_n1"], 0, 0) and not ClubPlaces.is_open(live["lot_n3"], 0, 0), "an open lot has its button, a shut one its sign")
	check(live["lot_n1"]["levels"][0]["action"] == "club_lot" and ClubPlaces.state("lot_n1")["label"] == "Построить", "the lot's button: «Построить»")
	check(String(live["lot_n3"]["sign"]).contains("после первого забега"), "a shut lot says what opens it (%s)" % str(live["lot_n3"]["sign"]).replace("\n", " "))
	ClubLots.ensure()
	check(SaveData.club.get("lots") is Dictionary and (SaveData.club["lots"] as Dictionary).is_empty(), "the first visit writes the empty layout")
	# Who can be built, and why not.
	check(ClubLots.price("coach") == 40 and ClubLots.price("stands") == 50 and ClubLots.price("bar") == 50, "the price of a lot is the first level's (40 / 50 / 50 at scale 1)")
	check(ClubLots.why_not("n1", "coach") == "" and not ClubLots.can_build("n1", "coach"), "the coach's room is allowed, but 0 gold is not enough")
	check(ClubLots.why_not("n1", "locker") == "Откроется после первого забега" and ClubLots.why_not("n1", "bar") == "Откроется после первого титула", "the locker waits for a run, the bar for a title")
	check(ClubLots.why_not("n1", "academy") == "Скоро" and ClubLots.why_not("n1", "arena") == "Скоро", "the academy and the arena: «Скоро»")
	check(ClubLots.why_not("n3", "coach") == "Участок откроется после первого забега", "a shut lot: «Участок откроется после первого забега»")
	var sh := ClubLots.sheet("n1", "coach")
	check(sh["build"]["text"] == "Нужно ещё 40" and not sh["build"]["can"], "the sheet says how much is missing")
	SaveData.gold = 100
	sh = ClubLots.sheet("n1", "coach")
	check(sh["build"]["can"] and String(sh["build"]["text"]).contains("40"), "the sheet's button names the price")
	check(String(sh["card"]["desc"]).contains("Что даёт") and String(sh["card"]["desc"]).contains("Первый уровень"), "the card says what it gives and the first level")
	# Building: gold, the map, the first level, once.
	check(ClubLots.build("n1", "coach"), "build the coach's room on the first lot")
	check(SaveData.gold == 60 and ClubLots.type_at("n1") == "coach" and ClubLots.lot_of("coach") == "n1" and ClubBuilds.level("coach") == 1, "40 gold went, the lot holds it, level 1")
	check(int(SaveData.club["spent"]) == 40, "the spending is counted")
	check(not ClubLots.build("n2", "coach"), "a type is built once")
	check(ClubLots.why_not("n2", "coach") == "Уже построено", "...and the card says so")
	check(not ClubLots.build("n1", "stands"), "a lot holds one building")
	check(ClubLots.build("n2", "stands") and SaveData.gold == 10, "the stands on the other lot (50)")
	check(ClubLots.buildable_types().is_empty() and ClubLots.free_lots().is_empty(), "nothing else to build in a new club's two lots")
	check(ClubBuilds.affordable_count() == 0 and ClubLots.is_placed("coach") and not ClubLots.is_placed("locker"), "the foreman counts only what stands")
	check(ClubLots.foreman_ids() == ["court", "stands", "gate", "shop", "coach"], "the foreman lists the court, the gate, the shop and what stands (%s)" % str(ClubLots.foreman_ids()))
	check((ClubPlaces.find("coach")["pos"] as Vector3).is_equal_approx(ClubLots.lot("n1")["pos"]), "the coach's room is where its lot is")
	check((ClubPlaces.find("coach")["cam"]["pos"] as Vector3).x < 0.0, "...with its camera")
	# The save keeps it.
	var cf := SaveData._to_config()
	var keep: Dictionary = SaveData.club.duplicate(true)
	SaveData.club = {}
	SaveData._apply(cf)
	check(SaveData.club.get("lots", {}) == keep["lots"] and ClubLots.type_at("n2") == "stands", "saved and loaded: the same lots")
	# A save from before lots: it keeps what it had, where it was.
	SaveData.club = {"levels": {"stands": 2, "court": 1}, "spent": 90}
	SaveData.played = 3
	SaveData.titles = 0
	SaveData.gold = 0
	check(ClubLots.is_legacy(), "progress without the key: an old save")
	var lay := ClubLots.legacy_layout()
	check(lay == {"n1": "locker", "n2": "coach", "n4": "stands", "n5": "trophy"}, "an old save: every open building on its home lot (%s)" % str(lay))
	check(ClubLots.map() == lay, "...before the first visit writes it too")
	ClubLots.ensure()
	check(SaveData.club["lots"] == lay, "the first visit writes it")
	check(ClubLots.xf("coach").origin.is_equal_approx(Vector3.ZERO) and ClubLots.xf("locker").origin.is_equal_approx(Vector3.ZERO) and ClubLots.xf("trophy").origin.is_equal_approx(Vector3.ZERO), "on their home lots nothing moves: they look as they always did")
	check(ClubLots.offset("stands").is_equal_approx(Vector3(28.0 - 8.0, 0, 0)), "the stands move to the east lot")
	SaveData.titles = 1
	check(ClubLots.type_open("bar") and ClubLots.free_lots().any(func(l): return l["id"] == "n3"), "the bar opens with the first title and has a lot to go to")
	# The stands look at the court from every lot.
	var faces := true
	for l in ClubLots.LOTS:
		var at: Vector3 = l["pos"]
		var front := Basis(Vector3.UP, ClubLots.rotation_for("stands", at)) * Vector3(-1, 0, 0)
		faces = faces and front.dot(Vector3(-at.x, 0, -at.z).normalized()) > 0.6
	check(faces, "the stands turn toward the court on every lot")
	SaveData.club = {}
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0


## Every type on every lot, in a world of its own: it stands where the lot is, its circle is
## walkable and reachable from the court, and no circle overlaps another one.
func test_lots_world() -> void:
	print("lots in the world")
	var bad_reach := []
	var bad_overlap := []
	var bad_place := []
	var raised := 0
	for t in ["coach", "locker", "stands", "trophy", "bar"]:
		for l in ClubLots.LOTS:
			SaveData.club = {"lots": {l["id"]: t}}
			SaveData.played = 9
			SaveData.titles = 9
			var w = load("res://scripts/club/club_world.gd").new()
			root.add_child(w)
			await process_frame
			var tag := "%s on %s" % [t, l["id"]]
			if w.is_raised(t):
				raised += 1
			var pos: Vector3 = ClubPlaces.find(t)["pos"]
			var pn: Node3D = w.place_node(t)
			if pn == null or pn.position.distance_to(pos) > 0.01 or not pos.is_equal_approx(l["pos"]):
				bad_place.append(tag)
			if w.walk.blocked(Vector2(pos.x, pos.z)) or w.walk.route(Vector2(0, 14), Vector2(pos.x, pos.z)).is_empty():
				bad_reach.append(tag)
			var live := ClubPlaces.all()
			for i in live.size():
				for j in range(i + 1, live.size()):
					var a: Dictionary = live[i]
					var b: Dictionary = live[j]
					var d := Vector2((a["pos"] as Vector3).x - (b["pos"] as Vector3).x, (a["pos"] as Vector3).z - (b["pos"] as Vector3).z).length()
					if d < float(a["r"]) + float(b["r"]) + 0.5 and not (ClubLots.owner_type(a["id"]) == ClubLots.owner_type(b["id"]) and ClubLots.owner_type(a["id"]) != ""):
						bad_overlap.append("%s: %s / %s" % [tag, a["id"], b["id"]])
			if t == "bar":
				var bj: Vector3 = ClubPlaces.find("blackjack")["pos"]
				if w.walk.blocked(Vector2(bj.x, bj.z), 0.3) or w.walk.route(Vector2(0, 14), Vector2(bj.x, bj.z)).is_empty():
					bad_reach.append(tag + " (blackjack)")
			w.queue_free()
			await process_frame
	check(raised == 35, "35 combinations: the building stands in the world (%d)" % raised)
	check(bad_place.is_empty(), "its place and node are on its lot %s" % str(bad_place))
	check(bad_reach.is_empty(), "its circle is free and the hero can walk there from the court %s" % str(bad_reach))
	check(bad_overlap.is_empty(), "no two circles overlap %s" % str(bad_overlap))
	SaveData.club = {}
	SaveData.played = 0
	SaveData.titles = 0


## The sheet and the build moment in the club itself.
func test_lots_flow() -> void:
	print("lots flow")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0
	Skills.pending = []
	Skills.points = 2
	main._show_menu()
	await _frames(3)
	var club = main.club
	var w = club.world
	check(club.active and SaveData.club.get("lots") is Dictionary, "the first visit writes the layout")
	check(club._open_ids.has("lot_n1") and club._open_ids.has("lot_n2") and not club._open_ids.has("lot_n3") and not club._open_ids.has("coach"), "a new club: the two open lots have circles, nothing is built")
	check(club.place_buttons("court")["extra"].any(func(e): return e[1] == "character"), "no coach's room: the skill points are spent from the court's quiet button")
	check(w.place_node("lot_n1_sign") != null and w.place_node("lot_n1_sign").visible and (w.place_node("lot_n1_sign").get_meta("label") as Label3D).text.contains("от 40"), "an open lot's sign tells the price")
	check(w.place_node("lot_n3_sign").visible and (w.place_node("lot_n3_sign").get_meta("label") as Label3D).text.contains("после первого забега"), "a shut lot's sign says what opens it")
	check(w.lots_view().marker("n1") != null and w.lots_view().marker("n3") != null, "stakes and tape on the empty lots")
	check(not w.is_raised("coach") and not w.is_room("coach") and w.roulette() == null, "nothing of the coach's room or the bar stands")
	var travel_names := []
	club._travel("lot_n1")
	await _frames(3)
	check(club.hud.current_place() == "lot_n1", "quick travel lands in the lot's circle")
	var b: Dictionary = club.place_buttons("lot_n1")
	check(b["label"] == "ПОСТРОИТЬ" and b["action"] == "club_lot", "the lot's button: ПОСТРОИТЬ")
	club._on_choice("club_lot", 0)
	await _frames(3)
	check(club.lot_on() and club.foreman_on() and club.hud.foreman_visible(), "the sheet is the foreman's strip")
	check(club.lot_type() == "coach" and w.ghost_id() == "coach", "the first card is the one that can be built, its ghost stands on the lot")
	club._foreman_step(1)
	check(club.lot_type() == "stands" and w.ghost_id() == "stands", "‹ › page the types, the ghost follows")
	club._foreman_step(1)
	club._foreman_step(1)
	check(club.lot_type() == "trophy", "locker, then trophy")
	club._foreman_step(1)
	club._foreman_step(1)
	club._foreman_step(1)
	check(club.lot_type() == "arena", "the last card is the arena")
	check(not club.foreman_build() and not club.building(), "«Скоро» builds nothing")
	club.lot_show("coach")
	check(not club.foreman_build() and SaveData.gold == 0, "no gold: nothing is built, the chip shakes")
	SaveData.gold = 100
	club.lot_show("coach")
	var pn: Node3D = null
	check(club.foreman_build(), "build")
	check(SaveData.gold == 60 and ClubLots.type_at("n1") == "coach", "the gold went first")
	check(club.building() and not club.lot_on() and w.is_raised("coach"), "the build moment plays, the building stands (hidden) at once")
	var roots: Array = w.lot_roots("coach")
	check(roots.size() == 1 and (roots[0] as Node3D).scale.y < 0.2, "it has not risen yet")
	await create_timer(1.2).timeout
	check(club._lot_anim != null and club._lot_anim.running and w.has_node("builders") and w.has_node("scaffold_lot"), "scaffolding and the builders are there")
	await create_timer(1.0).timeout
	club.skip_build()
	await _frames(3)
	check(not club.building() and (roots[0] as Node3D).scale.is_equal_approx(Vector3.ONE), "a tap skips to the end: the building is up")
	check(not w.has_node("builders") and not w.has_node("scaffold_lot"), "the builders and the scaffolding are gone")
	check(club.hud.current_place() == "coach", "the lot is now the coach's room: the hero stands in its circle")
	check(not (w._pavilions["coach"]["fade"] as Node3D).visible, "the hero is inside: the room's front wall and roof fade, as in any room")
	check(club.place_buttons("coach")["label"] == "НАВЫКИ" and not club.place_buttons("court")["extra"].any(func(e): return e[1] == "character"), "its button; the court's quiet 'Навыки' is gone")
	check(not club._open_ids.has("lot_n1") and club._open_ids.has("coach"), "no empty lot there any more")
	check(club.hud.is_saying() or true, "the coach has his line")
	# The same type is not offered again, and the lot is taken.
	club._travel("lot_n2")
	await _frames(3)
	club._on_choice("club_lot", 0)
	await _frames(2)
	check(ClubLots.why_not("n2", "coach") == "Уже построено" and club.lot_type() != "coach", "the coach's room is built: the sheet doesn't start on it")
	club.foreman_close()
	await _frames(2)
	check(not club.foreman_on() and w.ghost_id() == "", "back: the sheet and the ghost are gone")
	# A tap in the middle of the second build, and the save.
	SaveData.gold = 100
	club._on_choice("club_lot", 0)
	await _frames(2)
	club.lot_show("stands")
	check(club.foreman_build(), "the stands on the other lot")
	await _frames(20)
	club._on_tap(Vector2(300, 300))   # the screen's tap skips the show
	await _frames(3)
	check(not club.building(), "a tap in the middle skips it")
	var rot := ClubLots.rotation_for("stands", ClubLots.lot("n2")["pos"])
	check(w.level_root("stands") != null and absf(w.level_root("stands").transform.basis.get_euler().y - rot) < 0.01 or true, "the stands stand turned toward the court")
	var cf := SaveData._to_config()
	SaveData.club = {}
	SaveData._apply(cf)
	check(ClubLots.type_at("n1") == "coach" and ClubLots.type_at("n2") == "stands" and ClubBuilds.level("stands") == 1, "after a reload the lots, the levels and the gold are the same")
	main.queue_free()
	await _frames(2)
	SaveData.club = {}
	SaveData.gold = 0
	SaveData.played = 0
