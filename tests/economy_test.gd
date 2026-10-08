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
