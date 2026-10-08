extends SceneTree
## Stream A (v0.2) economy: prices and selling, item levels, the rarer drops, prize money,
## the run's income lines, the locker, the shop and its strings, the islands.
##   godot --headless --path . -s tests/economy_test.gd

var failures := 0


func _initialize() -> void:
	SaveData.enabled = false
	test_prices()
	test_item_level()
	test_drop_chances()
	test_prize_money()
	test_income()
	test_sell_extra()
	test_locker()
	test_locker_in_run()
	test_goals()
	test_shop()
	test_strings()
	test_islands()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _item(rarity: int, level := 1, slot := "racket") -> Dictionary:
	var it := {"slot": slot, "rarity": rarity, "name": "x", "mods": {"forehand_pace": 0.1}, "lines": ["+10%"]}
	if level > 1:
		it["level"] = level
	return it


# --- A-1 ----------------------------------------------------------------------------

func test_prices() -> void:
	print("prices")
	var buy := []
	var sell := []
	for r in 5:
		buy.append(Items.price(_item(r)))
		sell.append(Items.sell_price(_item(r)))
	check(buy == [15, 45, 120, 360, 1200], "buy prices by rarity %s" % [buy])
	check(sell == [5, 15, 40, 120, 400], "sell = a third %s" % [sell])
	check(Items.price(_item(Gear.EPIC, 3)) == 156, "level 3 epic: 120 x 1.3 = 156 (%d)" % Items.price(_item(Gear.EPIC, 3)))
	check(Items.sell_price(_item(Gear.LEGENDARY, 2)) == 138, "level 2 legendary sells for 414 / 3 = 138 (%d)" % Items.sell_price(_item(Gear.LEGENDARY, 2)))
	check(Gear.price(_item(Gear.RARE)) == Items.sell_price(_item(Gear.RARE)), "Gear.price is the sell price (the bag's «Продать»)")
	check(Items.price({}) == 0 and Items.sell_price({}) == 0, "nothing costs nothing")


func test_item_level() -> void:
	print("item level")
	var rng := _rng(3)
	var a := Gear.roll(Gear.RARE, rng, "racket")
	check(Items.level(a) == 1, "a rolled item is level 1 by default")
	var b := Gear.roll(Gear.RARE, _rng(3), "racket", 3)
	check(Items.level(b) == 3 and b["name"] == a["name"], "the same roll at level 3 (%s)" % b["name"])
	var ok := true
	for k in a["mods"]:
		ok = ok and is_equal_approx(float(b["mods"][k]), float(a["mods"][k]) * 1.2)
	check(ok and not a["mods"].is_empty(), "level 3: stats x1.2 (%s -> %s)" % [a["mods"], b["mods"]])
	check(Gear.describe(b).contains("Уровень 3") and not Gear.describe(a).contains("Уровень"), "the card says the level: %s" % Gear.describe(b).replace("\n", " / "))
	var sun := Items.set_level(Items.instance(Items.find("heavy_frame")), 2)
	check(is_equal_approx(float(sun["mods"]["forehand_pace"]), 0.11), "a catalog item's stats grow with the level too")
	var again := Items.set_level(sun.duplicate(true), 1)
	check(is_equal_approx(float(again["mods"]["forehand_pace"]), 0.10), "levels scale from the base, not on top of each other")


func test_drop_chances() -> void:
	print("drop chances")
	# Per slot of a beaten second-round opponent: what he carries x the drop chance.
	var got := [0, 0, 0, 0, 0]
	var slots := 0
	var rng := _rng(11)
	for k in 6000:
		var t := Tournament.new(1, 500 + k)
		for it in Tournament.drops(t.lineup[1]["gear"], rng, 0.0):
			got[int(it["rarity"])] += 1
		slots += 3
	var per := got.map(func(c): return float(c) / slots)
	check(absf(per[0] - 0.33) < 0.04 and absf(per[1] - 0.18) < 0.03, "common ~35%%, rare ~18%% a slot %s" % [per.map(func(x): return snappedf(x, 0.001))])
	check(per[2] > 0.06 and per[2] < 0.10 and per[3] < 0.03 and per[3] > 0.005 and per[4] < 0.008, "epic ~7-9%%, legendary ~2%%, mythic ~0.4%% a slot (golden ones add legendaries)")
	check(Tournament.DROP_CHANCE[Gear.EPIC] > Tournament.DROP_CHANCE[Gear.LEGENDARY], "a legendary drops less often than an epic")


func test_prize_money() -> void:
	print("prize money")
	var t := Tournament.new(1, 5)
	t.record_match(false, "2:6", _rng(1))
	check(t.state == Tournament.State.OVER and t.gold == 20, "out in the first round: 20 gold of prize money (%d)" % t.gold)
	t = Tournament.new(1, 5)
	t.wildcards = 1
	t.record_match(false, "2:6", _rng(1))
	check(t.gold == 0 and t.state == Tournament.State.LOST, "a loss with a wildcard pays nothing yet")
	t.give_up()
	check(t.gold == 20, "...giving up after it pays the round (%d)" % t.gold)
	t = Tournament.new(1, 5)
	t.give_up()
	check(t.gold == 0, "giving up before playing pays nothing")
	var by_round := []
	for out in 6:
		var u := Tournament.new(1, 9)
		u.drop_bonus = -1.0
		for i in out:
			u.record_match(true, "6:1", _rng(i))
			if u.state == Tournament.State.REWARD:
				u.take_reward(0)  # a perk: no wildcard, the loss ends the run
		if out < 5:
			u.record_match(false, "1:6", _rng(9))
		by_round.append(u.gold)
	check(by_round == [20, 35, 60, 95, 150, 225], "income by the round of exit %s" % [by_round])
	var quick := Tournament.new(0, 5)
	quick.record_match(false, "2:7", _rng(1))
	check(quick.gold == 8, "the quick format pays x0.4 (%d)" % quick.gold)


func test_income() -> void:
	print("income lines")
	var t := Tournament.new(1, 21)
	t.earn("style", 6)
	t.drop_bonus = 1.0
	t.record_match(true, "6:2", _rng(2))
	t.earn("bonus", 5)
	for k in Tournament.BAG_SIZE + 2:
		t.add_to_bag(_item(Gear.COMMON, 1, "band"))
	if t.bag.size() > 0:
		t.sell_from_bag(0)
	var sum := 0
	for k in t.income:
		sum += int(t.income[k])
	check(sum == t.gold, "the lines add up to the run's gold (%s = %d)" % [t.income, t.gold])
	check(int(t.income["prize"]) == 10 and int(t.income["style"]) == 6 and int(t.income["sell"]) > 0, "prize, style, sell each on its line")
	var back := Tournament.from_dict(t.to_dict())
	check(back.income == t.income, "the lines survive a save")


func test_sell_extra() -> void:
	print("sell everything extra")
	var t := Tournament.new(1, 4)
	t.equip["racket"] = _item(Gear.RARE)
	t.bag = [_item(Gear.COMMON, 1, "shoes"), _item(Gear.COMMON, 1, "racket"), _item(Gear.RARE, 1, "band"),
		_item(Gear.EPIC, 1, "racket"), _item(Gear.RARE, 1, "racket")]
	var extra := t.extra_items()
	check(extra.size() == 2, "extra: the commons only (a rare as good as the worn one stays) %d" % extra.size())
	var g := t.sell_extra()
	check(g == 10 and t.bag.size() == 3 and t.gold == 10, "sold for 5 + 5 (%d), three left" % g)
	t.equip["band"] = _item(Gear.EPIC, 1, "band")
	check(t.extra_items().size() == 1, "a rare under a worn epic of its slot is extra")
	t.sell_extra()
	var epics := t.bag.filter(func(it): return int(it["rarity"]) >= Gear.EPIC)
	check(epics.size() == 1, "an epic is never sold by the one button")


# --- A-2: the locker -----------------------------------------------------------------

func _reset_save() -> void:
	SaveData.gold = 0
	SaveData.locker = {}
	SaveData.club = {}
	SaveData.titles = 0
	SaveData.titles_by_loc = {}
	SaveData.played = 0


func test_locker() -> void:
	print("locker")
	_reset_save()
	check(Locker.slots() == 1, "one slot before the changing room is built")
	SaveData.club = {"levels": {"locker": 2}}
	check(Locker.slots() == 3, "+1 a level of the changing room (%d)" % Locker.slots())
	SaveData.club = {"levels": {"locker": 9}}
	check(Locker.slots() == 4, "at most 4")
	SaveData.club = {}
	var caps := []
	for r in 6:
		caps.append(Locker.cap(r))
	check(caps == [Gear.RARE, Gear.RARE, Gear.EPIC, Gear.EPIC, Gear.LEGENDARY, Gear.MYTHIC], "the ceiling by the round of exit %s" % [caps])
	check(Locker.insurance(_item(Gear.LEGENDARY)) == 36 and Locker.insurance(_item(Gear.MYTHIC)) == 120, "insurance 36 / 120")
	check(Locker.insurance(_item(Gear.LEGENDARY, 3)) == 47 and Locker.insurance(_item(Gear.EPIC)) == 0, "the level counts (360 x 1.3 x 10%% = 47), an epic needs none")
	check(Locker.put(_item(Gear.EPIC), 1) != "", "an epic out in the second round: above the ceiling")
	check(Locker.put(_item(Gear.LEGENDARY), 5) == "нужно ещё 36", "a legendary with no gold: «%s»" % Locker.put(_item(Gear.LEGENDARY), 5))
	SaveData.gold = 50
	check(Locker.put(_item(Gear.LEGENDARY), 5) == "" and SaveData.gold == 14 and Locker.items().size() == 1, "...with gold: kept, 36 paid")
	check(Locker.put(_item(Gear.RARE), 0).begins_with("шкафчик полон"), "full: «%s»" % Locker.put(_item(Gear.RARE), 0))
	var g := SaveData.gold
	check(Locker.put(_item(Gear.RARE, 1, "band"), 0, 0) == "" and SaveData.gold == g + 120 and Locker.items()[0]["slot"] == "band", "replace: the old one is sold into the bank (+120)")
	var it: Dictionary = Locker.take(0)
	check(it["slot"] == "band" and Locker.items().is_empty(), "take: out of the locker")
	SaveData.locker = {}
	SaveData.gold = 0


func test_locker_in_run() -> void:
	print("locker in a run")
	_reset_save()
	SaveData.club = {"levels": {"locker": 1}}
	SaveData.gold = 100
	Locker.put(_item(Gear.RARE, 1, "shoes"), 0)
	Locker.put(_item(Gear.RARE, 1, "racket"), 0)
	SaveData.locker["next"] = [_item(Gear.COMMON, 1, "band")]
	var t := Tournament.new(1, 3)
	Locker.board(t)
	check(t.equip["band"]["rarity"] == Gear.COMMON and Locker.next_items().is_empty(), "what was bought comes along by itself (put on)")
	check(t.can_take_locker(), "before the first match the locker is open")
	t.take_from_locker(0)
	check(t.equip["shoes"]["slot"] == "shoes" and Locker.items().size() == 1, "taken into the run: worn, gone from the locker")
	t.equip["racket"] = _item(Gear.COMMON)
	t.take_from_locker(0)
	check(t.bag.size() == 1 and t.bag[0]["rarity"] == Gear.RARE, "the slot is taken: into the bag")
	t.record_match(false, "1:6", _rng(1))
	check(not t.can_take_locker(), "after a match: no more")
	check(Locker.exit_round(t) == 0, "out in the first round")
	var cands := Locker.candidates(t)
	check(cands.size() == 4, "the candidates: worn + bag (%d)" % cands.size())
	check(Locker.save_from(t, 0) == "" and t.locker_done, "one item into the locker on the summary")
	check(Locker.save_from(t, 1) != "", "only one per run")
	var back := Tournament.from_dict(t.to_dict())
	check(back.locker_done, "the choice survives a save")
	_reset_save()


func test_goals() -> void:
	print("goals")
	_reset_save()
	SaveData.played = 1
	SaveData.gold = 10
	var g := Goals.next_goal()
	check(not g.is_empty() and int(g["left"]) > 0 and int(g["left"]) == int(g["price"]) - 10, "a next goal and how far: %s" % [g])
	SaveData.gold = 100000
	check(not Goals.affordable().is_empty(), "rich: things within reach")
	_reset_save()


# --- A-3: the shop -------------------------------------------------------------------

func test_shop() -> void:
	print("shop")
	_reset_save()
	SaveData.played = 3
	var s := Shop.stock()
	check(s.size() == 2, "the stall: 2 items (%d)" % s.size())
	var max_r := 0
	for k in 40:
		SaveData.played = 100 + k
		for it in Shop.stock():
			max_r = maxi(max_r, int(it["rarity"]))
	check(max_r == Gear.RARE, "the stall sells up to rare")
	SaveData.club = {"levels": {"shop": 2}}
	max_r = 0
	var mythic := false
	for k in 300:
		SaveData.played = 200 + k
		for it in Shop.stock():
			max_r = maxi(max_r, int(it["rarity"]))
			mythic = mythic or int(it["rarity"]) == Gear.MYTHIC
	check(Shop.stock().size() == 4 and max_r == Gear.LEGENDARY and not mythic, "the boutique: 4 items up to legendary, never a mythic")
	SaveData.played = 7
	var a := Shop.stock()
	check(a == Shop.stock(), "the same run: the same showcase (a reload rerolls nothing)")
	SaveData.played = 8
	check(a != Shop.stock(), "a new run: a new showcase")
	SaveData.gold = 100
	var prices := []
	for k in 3:
		prices.append(Shop.reroll_price())
		Shop.reroll()
	check(prices == [20, 30, 45] and SaveData.gold == 5, "reroll 20 -> 30 -> 45 (%s), paid" % [prices])
	SaveData.played = 9
	check(Shop.reroll_price() == 20, "after a run the reroll is 20 again")
	SaveData.gold = 0
	check(Shop.buy(0).begins_with("ещё"), "no gold: «%s»" % Shop.buy(0))
	SaveData.gold = 5000
	var it0: Dictionary = Shop.stock()[0]
	check(Shop.buy(0) == "" and SaveData.gold == 5000 - Items.price(it0) and Locker.next_items().size() == 1, "bought for its price, waits for the next run")
	check(Shop.stock()[0].is_empty() and Shop.buy(0) == "продано", "its place is empty")
	Shop.buy(1)
	Shop.buy(2)
	check(Shop.buy(3).begins_with("сумка на турнир полна"), "at most 3 bought items wait")
	var g := SaveData.gold
	var p := Items.sell_price(Locker.next_items()[0])
	check(Shop.sell("next", 0) == p and SaveData.gold == g + p and Locker.next_items().size() == 2, "sell: a third back into the bank")
	SaveData.played = 3
	SaveData.titles_by_loc = {"park": 1, "clay": 1}
	check(Shop.item_level() == 3, "items come at the level of the best open island (England: 3)")
	_reset_save()


func test_strings() -> void:
	print("strings")
	_reset_save()
	SaveData.gold = 1000
	SaveData.locker = {"items": [Items.instance(Items.find("cutter")), Gear._affix_item(Gear.RARE, _rng(4), "band")]}
	check(not Shop.can_restring() and Shop.restring("items", 0) != "", "strings open with the «Лавка»")
	SaveData.club = {"levels": {"shop": 1}}
	var cutter: Dictionary = Locker.items()[0]
	check(Shop.restring_price(cutter) == 90 and Shop.restring_price(_item(Gear.MYTHIC)) == 600, "25%% of the price, a mythic 50%%")
	check(Shop.string_pool(cutter).size() == Gear.AFFIXES_BY_SLOT["racket"].size(), "the pool: the slot's affixes, e.g. «%s»" % Shop.string_pool(cutter)[0])
	var spin0 := float(cutter["mods"].get("touch_spin", 0.0))
	check(Shop.restring("items", 0, _rng(1)) == "" and SaveData.gold == 910, "paid 90")
	cutter = Locker.items()[0]
	check(cutter["strings"]["mods"].size() == 2 and cutter["id"] == "cutter" and int(cutter["rarity"]) == Gear.LEGENDARY, "a legendary gets 2 string lines, stays itself")
	check(float(cutter["mods"].get("touch_spin", 0.0)) >= spin0 - 0.0001 and Gear.describe(cutter).contains("Струны: "), "its own stats stay, the card shows the strings")
	var before: Dictionary = cutter["strings"]["mods"].duplicate()
	Shop.restring("items", 0, _rng(1))
	check(Locker.items()[0]["strings"]["mods"] != before, "a restring never gives the same back")
	var band: Dictionary = Locker.items()[1]
	var m0: Dictionary = band["mods"].duplicate()
	var name0: String = band["name"]
	Shop.restring("items", 1, _rng(2))
	check(Locker.items()[1]["mods"] != m0 and Locker.items()[1]["name"] == name0 and Locker.items()[1]["mods"].size() == 2, "a generated rare: new affixes, the same name")
	_reset_save()


# --- A-4: the islands ----------------------------------------------------------------

func test_islands() -> void:
	print("islands")
	_reset_save()
	check(Locations.tier("park") == 0 and Locations.tier("clay") == 1 and Locations.tier("grass") == 2 and Locations.tier("paris") == 3, "tiers: New York, Spain, England, Paris")
	check(Locations.unlocked("park") and not Locations.unlocked("clay") and not Locations.unlocked("grass") and not Locations.unlocked("paris"), "a new player: New York only")
	check(Locations.unlock_hint("clay") == "за первый титул" and Locations.unlock_hint("grass") == "за титул в Испании" and Locations.unlock_hint("paris") == "за титул в Англии", "the lock's hints")
	SaveData.titles = 1  # an old save: a title with no island recorded
	check(Locations.unlocked("clay") and not Locations.unlocked("grass"), "any title opens Spain (old saves too)")
	SaveData.note_title("park")
	check(int(SaveData.titles_by_loc["park"]) == 1 and not Locations.unlocked("grass"), "a title in New York does not open England")
	SaveData.note_title("clay")
	check(Locations.unlocked("grass") and not Locations.unlocked("paris"), "a title in Spain opens England")
	SaveData.note_title("grass")
	check(Locations.unlocked("paris") and Locations.best_unlocked() == "paris", "a title in England opens Paris")
	var before := SaveData._score(SaveData._to_config())
	SaveData.note_title("paris")
	check(SaveData._score(SaveData._to_config()) >= before, "the save's score never falls with a title")
	# opponents get stronger, richer, better geared
	var park := Tournament.new(1, 11)
	var paris := Tournament.new(1, 11)
	paris.location = "paris"
	park.stage = 2
	paris.stage = 2
	park.lineup[2]["mods"] = []
	paris.lineup[2]["mods"] = []
	check(paris.modifier_value("skill") > park.modifier_value("skill") + 0.15, "Paris: the AI's mastery +0.2 (%.2f vs %.2f)" % [paris.modifier_value("skill"), park.modifier_value("skill")])
	var sp := paris.modifier_value("speed") / park.modifier_value("speed")
	check(absf(sp - 1.2) < 0.001 and absf(paris.modifier_value("serve") / park.modifier_value("serve") - 1.2) < 0.001, "Paris: +20%% running and serving (x%.2f)" % sp)
	check(paris.item_level() == 4 and park.item_level() == 1, "gear levels: 4 in Paris, 1 in New York")
	var lv_ok := true
	for l in paris.lineup:
		for slot in Gear.SLOTS:
			lv_ok = lv_ok and Items.level(l["gear"][slot]) >= 4
	check(lv_ok, "every item an opponent wears in Paris is level 4+")
	check(absf(park.prize_mult() - 1.0) < 0.001 and absf(paris.prize_mult() - 2.0) < 0.001, "prizes x1 / x2 (format 'Сет до 6')")
	# rarer gear on a higher island, over many lineups
	var epic := [0, 0]
	for k in 400:
		for j in 2:
			var t := Tournament.new(1, 5000 + k)
			if j == 1:
				t.location = "paris"
			for l in t.lineup:
				for slot in Gear.SLOTS:
					if int(l["gear"][slot]["rarity"]) >= Gear.EPIC:
						epic[j] += 1
	check(epic[1] > epic[0] * 1.15, "Paris wears more epic+ gear than New York (%d vs %d)" % [epic[1], epic[0]])
	var back := Tournament.from_dict(paris.to_dict())
	check(back.location == "paris" and back.lineup == paris.lineup, "a saved Paris run comes back the same")
	_reset_save()
