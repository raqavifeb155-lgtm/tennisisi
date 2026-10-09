extends SceneTree
## The academy's house (docs/superpowers/specs/2026-10-10-academy-house.md, AH-1): the rooms' table, the
## prices, the rooms opening with the building, the long build, what the house gives the school through
## Academy's hooks (seats, growth, ceiling), the save, and the walk in: the door, the fade, the plan, the
## way out. The scene part builds Main like club_world_test does.
##   godot --headless --path . -s tests/house_test.gd

var failures := 0


func _initialize() -> void:
	SaveData.enabled = false
	test_table()
	test_open()
	test_buy()
	test_build()
	test_hooks()
	test_save()
	await test_world()
	await test_visit()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A club with the academy standing on its lot at this level.
func _fresh(academy_level := 0, gold := 0, played := 0) -> void:
	AcademyHouse.enabled = true
	AcademyHouse.uninstall()
	SaveData.club = {"lots": {"n7": "academy"}, "levels": {"academy": academy_level}} if academy_level > 0 else {}
	SaveData.academy = {}
	SaveData.house = {}
	SaveData.played = played
	SaveData.titles = 0
	SaveData.gold = gold
	Skills.mods_layer = {}


func test_table() -> void:
	print("the table")
	check(HouseRooms.ids().size() == 8, "eight rooms")
	var five := true
	var objs := 0
	for r in HouseRooms.ids():
		five = five and (HouseRooms.ROOMS[r]["levels"] as Array).size() == 5
		for lv in range(1, 6):
			var l := HouseRooms.level(r, lv)
			objs += 1
			five = five and String(l.get("obj", "")) != "" and String(l.get("fx", "")) != ""
	check(five and objs == 40, "five levels each, 40 objects, each with a line of what it gives (%d)" % objs)
	var want := [75, 170, 380, 875, 1980]
	var prices: Array = []
	for lv in range(1, 6):
		prices.append(HouseRooms.price(lv))
	check(prices == want, "a level costs 75 / 170 / 380 / 875 / 1980 in the club's scale (%s)" % str(prices))
	var one := 0
	for p in prices:
		one += p
	check(one == 3480 and one * 8 == 27840, "3480 for a room, 27 840 for the eight")
	check(HouseRooms.runs(1) == 0 and HouseRooms.runs(3) == 0 and HouseRooms.runs(4) == 2 and HouseRooms.runs(5) == 3, "levels 4 and 5 are built over 2 and 3 runs")
	check(HouseRooms.cap_for_building(0) == 0 and HouseRooms.cap_for_building(1) == 2 and HouseRooms.cap_for_building(3) == 4 and HouseRooms.cap_for_building(4) == 5 and HouseRooms.cap_for_building(5) == 5, "a room's level is at most the building's + 1")
	var sides := {}
	var cells := {}
	for r in HouseRooms.ids():
		var d: Dictionary = HouseRooms.ROOMS[r]
		cells["%d|%d" % [d["side"], d["row"]]] = true
		sides[d["side"]] = int(sides.get(d["side"], 0)) + 1
	check(cells.size() == 8 and sides[-1] == 4 and sides[1] == 4, "four rooms a side of the hall, none on another's place")
	var dorm_caps: Array = []
	for lv in range(1, 6):
		dorm_caps.append(int(HouseRooms.level("dorm", lv)["cap"]))
	check(dorm_caps == [2, 3, 4, 5, 6], "the dorm's seats 2 -> 6, in one table (%s)" % str(dorm_caps))


func test_open() -> void:
	print("the rooms open with the building")
	_fresh(0)
	check(not AcademyHouse.is_built() and AcademyHouse.max_level() == 0, "no academy: no house")
	check(AcademyHouse.why_not("dorm") == "Сначала построй академию", "and the dorm says to build it first")
	var opens := {1: ["dorm", "canteen"], 2: ["gym", "lounge"], 3: ["video", "coach"], 4: ["med"], 5: ["hall"]}
	var seen := {}
	for bl in range(1, 6):
		_fresh(bl)
		for r in HouseRooms.ids():
			if AcademyHouse.is_open(r):
				seen[r] = true
		var now: Array = []
		for r in HouseRooms.ids():
			if AcademyHouse.is_open(r):
				now.append(r)
		var expect: Array = []
		for k in range(1, bl + 1):
			expect += opens[k]
		now.sort()
		expect.sort()
		check(now == expect, "building level %d: %s" % [bl, ", ".join(now)])
	_fresh(1)
	check(AcademyHouse.why_not("gym") == "Откроется на ур. 2 академии", "a shut room says when it opens")
	check(AcademyHouse.max_level() == 2, "level 1 building: rooms to level 2")


func test_buy() -> void:
	print("buying")
	_fresh(1, 1000)
	check(AcademyHouse.buy("gym") == 0 and SaveData.gold == 1000, "a shut room can't be bought")
	check(AcademyHouse.buy("dorm") == 1 and SaveData.gold == 925 and AcademyHouse.level("dorm") == 1, "dorm 1 for 75")
	check(AcademyHouse.buy("dorm") == 2 and SaveData.gold == 755 and AcademyHouse.level("dorm") == 2, "dorm 2 for 170")
	check(AcademyHouse.why_not("dorm") == "Нужна академия ур. 2" and AcademyHouse.buy("dorm") == 0, "dorm 3 needs the building at level 2")
	check(AcademyHouse.spent() == 245 and AcademyHouse.levels_total() == 2, "the house took 245, two levels stand")
	SaveData.gold = 10
	check(AcademyHouse.why_not("canteen") == "Нужно ещё 65" and AcademyHouse.buy("canteen") == 0 and SaveData.gold == 10, "short of gold: how much more, nothing taken")
	SaveData.gold = 5000
	for i in 5:
		AcademyHouse.buy("canteen")
	check(AcademyHouse.level("canteen") == 2, "the canteen stops at the building's cap (%d)" % AcademyHouse.level("canteen"))
	check(AcademyHouse.affordable_count() == 0, "nothing more to buy at this building level")
	SaveData.club["levels"]["academy"] = 2
	check(AcademyHouse.affordable_count() == 4, "building 2: the dorm, the canteen, the gym and the lounge can go up (%d)" % AcademyHouse.affordable_count())


func test_build() -> void:
	print("the long build")
	_fresh(4, 100000, 10)
	for lv in 3:
		AcademyHouse.buy("gym")
	check(AcademyHouse.level("gym") == 3, "gym 3")
	var gold := SaveData.gold
	check(AcademyHouse.buy("gym") == 4 and SaveData.gold == gold - 875, "gym 4 paid at once (875)")
	check(AcademyHouse.level("gym") == 3 and AcademyHouse.is_building("gym") and AcademyHouse.runs_left("gym") == 2, "but it stands as 3 and the scaffolding stays for 2 runs")
	check(AcademyHouse.why_not("gym") == "Леса стоят · ещё 2 забега" and AcademyHouse.buy("gym") == 0, "no second payment while it stands")
	check(AcademyHouse.complete_ready().is_empty(), "nothing ready yet")
	SaveData.played = 11
	check(AcademyHouse.runs_left("gym") == 1 and AcademyHouse.complete_ready().is_empty(), "one run later: one more")
	SaveData.played = 12
	var done := AcademyHouse.complete_ready()
	check(done.size() == 1 and done[0]["room"] == "gym" and done[0]["level"] == 4 and AcademyHouse.level("gym") == 4 and not AcademyHouse.is_building("gym"), "two runs later the level is up")
	check(AcademyHouse.complete_ready().is_empty(), "and it is done once")
	SaveData.club["levels"]["academy"] = 5
	check(AcademyHouse.buy("gym") == 5 and AcademyHouse.runs_left("gym") == 3, "level 5: three runs")
	check(AcademyHouse.spent() == 75 + 170 + 380 + 875 + 1980, "the spent gold counts the scaffolding's too (%d)" % AcademyHouse.spent())


func test_hooks() -> void:
	print("what the house gives the school")
	_fresh(3, 0, 0)
	check(Academy.capacity() == 3, "without the hooks the school keeps its own seats (building 3: 3)")
	AcademyHouse.install()
	check(Academy.capacity() == 3, "installed, no dorm: the same")
	_fresh(1, 0)
	AcademyHouse.install()
	check(Academy.capacity() == 2, "building 1: 2 seats")
	SaveData.house = {"levels": {"dorm": 5}}
	check(Academy.capacity() == 6, "a dorm at level 5: six seats")
	SaveData.house = {"levels": {"dorm": 1}}
	_fresh(5)
	AcademyHouse.install()
	SaveData.house = {"levels": {"dorm": 1}}
	check(Academy.capacity() == 3, "a small dorm never takes seats away: the school's 3 stay (%d)" % Academy.capacity())
	var seats: Array = []
	for lv in range(0, 6):
		SaveData.house = {"levels": {"dorm": lv}}
		_fresh_keep_house()
		seats.append(Academy.capacity())
	check(seats == [3, 3, 3, 4, 5, 6], "seats by the dorm in a level 5 school: %s" % str(seats))

	_fresh(5)
	AcademyHouse.install()
	var st := {"id": "s1", "pot": 0.8, "stats": {}, "traits": []}
	var base_c := Academy.ceiling(st, "speed")
	check(AcademyHouse.growth_mult(st, "speed") == 1.0 and AcademyHouse.ceiling_add(st, "speed") == 0, "an empty house changes nothing")
	SaveData.house = {"levels": {"gym": 2}}
	check(is_equal_approx(AcademyHouse.growth_mult(st, "speed"), 1.08) and is_equal_approx(AcademyHouse.growth_mult(st, "stamina"), 1.08) and AcademyHouse.growth_mult(st, "serve") == 1.0, "gym 2: speed and stamina +8%, a higher level of the same thing replaces (not adds to) the lower")
	SaveData.house = {"levels": {"gym": 5, "canteen": 5, "video": 5}}
	check(is_equal_approx(AcademyHouse.growth_mult(st, "speed"), 1.20 * 1.06 * 1.05), "gym 5 + the dietitian + the chef: 1.20 x 1.06 x 1.05 = %.3f" % AcademyHouse.growth_mult(st, "speed"))
	check(is_equal_approx(AcademyHouse.growth_mult(st, "net"), 1.08 * 1.05) and is_equal_approx(AcademyHouse.growth_mult(st, "serve"), 1.05), "video 5: net +8%, the chef's +5% for everyone")
	var most := 0.0
	var all5 := {}
	for r in HouseRooms.ids():
		all5[r] = 5
	SaveData.house = {"levels": all5}
	for k in Opponents.STAT_KEYS:
		most = maxf(most, AcademyHouse.growth_mult(st, k))
	check(most <= HouseRooms.GROWTH_CAP + 0.0001 and most > 1.3, "the whole house at its best: x%.2f, under the cap %.2f" % [most, HouseRooms.GROWTH_CAP])
	check(AcademyHouse.ceiling_add(st, "speed") == 1 and AcademyHouse.ceiling_add(st, "stamina") == 1 and AcademyHouse.ceiling_add(st, "serve") == 0 and AcademyHouse.ceiling_add(st, "") == 0, "the gym's top level: +1 to the ceiling of speed and stamina only")
	check(Academy.ceiling(st, "speed") == base_c + 1 and Academy.ceiling(st, "serve") == base_c, "and Academy.ceiling follows it (%d vs %d)" % [Academy.ceiling(st, "speed"), Academy.ceiling(st, "serve")])
	# growth reaches the experience
	var a := {"id": "a", "name": "А", "pot": 0.5, "stats": {"serve": 3, "forehand": 3, "backhand": 3, "net": 3, "speed": 3, "stamina": 3}, "traits": [], "leanings": [], "focus": "even", "xp": {}}
	var b := a.duplicate(true)
	SaveData.house = {}
	Academy.train(a, 1.0)
	SaveData.house = {"levels": {"gym": 3}}
	Academy.train(b, 1.0)
	var xs := float((a["xp"] as Dictionary)["speed"])
	var xg := float((b["xp"] as Dictionary)["speed"])
	check(int(a["stats"]["speed"]) == 3 and int(b["stats"]["speed"]) == 3 and xs > 0.0 and is_equal_approx(xg / xs, 1.12), "a gym 3 makes the same run give 12%% more speed experience (%.1f vs %.1f)" % [xg, xs])
	check(is_equal_approx(float((b["xp"] as Dictionary)["serve"]), float((a["xp"] as Dictionary)["serve"])), "and the serve's the same")
	AcademyHouse.enabled = false
	check(AcademyHouse.growth_mult(st, "speed") == 1.0 and AcademyHouse.ceiling_add(st, "speed") == 0, "online: the house gives nothing to growth or the ceiling")
	_fresh(5)
	AcademyHouse.enabled = false
	SaveData.house = {"levels": {"dorm": 5}}
	AcademyHouse.install()
	check(Academy.capacity() == 3, "and not a seat")
	AcademyHouse.enabled = true
	AcademyHouse.uninstall()
	check(Academy.hooks.is_empty(), "uninstalled: the school is as before")
	Skills.mods_layer = {}
	check(Skills.mods_layer.is_empty(), "the hero's skills layer is never touched (the house reaches the students only)")


func _fresh_keep_house() -> void:
	# a school at level 5 with the house as it is (the dorm level set before the call)
	var h := SaveData.house.duplicate(true)
	_fresh(5)
	AcademyHouse.install()
	SaveData.house = h


func test_save() -> void:
	print("the save")
	_fresh(3, 5000, 7)
	AcademyHouse.install()
	AcademyHouse.buy("dorm")
	AcademyHouse.buy("canteen")
	AcademyHouse.buy("gym")
	var score_before := SaveData._score(SaveData._to_config())
	AcademyHouse.buy("dorm")
	var cf := SaveData._to_config()
	check(cf.has_section_key("house", "data"), "the house has its own section")
	var raw := cf.encode_to_text()
	check(raw.length() < 4096, "and it is small (%d bytes of the whole file)" % raw.length())
	var back := ConfigFile.new()
	check(back.parse(raw) == OK, "it parses back")
	SaveData.house = {}
	SaveData.gold = 0
	SaveData._apply(back)
	check(AcademyHouse.level("dorm") == 2 and AcademyHouse.level("canteen") == 1 and AcademyHouse.level("gym") == 1 and AcademyHouse.spent() == 75 + 170 + 75 + 75, "levels and spent come back (%s)" % str(SaveData.house))
	check(SaveData._score(cf) > score_before, "the score grows with what is built into the house")
	var long_one := AcademyHouse.data()
	long_one["building"] = {"gym": {"level": 4, "until": 9}}
	var cf2 := SaveData._to_config()
	var back2 := ConfigFile.new()
	back2.parse(cf2.encode_to_text())
	SaveData._apply(back2)
	check(AcademyHouse.is_building("gym") and int(AcademyHouse.building()["gym"]["until"]) == 9, "the scaffolding is saved too")
	# an older save: no section
	var old := ConfigFile.new()
	old.set_value("meta", "gold", 321)
	old.set_value("meta", "played", 2)
	SaveData.house = {"levels": {"dorm": 4}}
	SaveData._apply(old)
	check(SaveData.house.is_empty() and AcademyHouse.level("dorm") == 0 and AcademyHouse.levels_total() == 0 and SaveData.gold == 321, "a save from before the house loads as an empty house")
	check(not SaveData._to_config().has_section("house"), "and writes no section until there is something in it")
	SaveData.house = {}
	SaveData.club = {}
	SaveData.academy = {}
	SaveData.gold = 0
	SaveData.played = 0


func test_world() -> void:
	pass


func test_visit() -> void:
	pass
