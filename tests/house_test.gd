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
	print("the plan")
	_fresh(5, 0, 0)
	var w := HouseWorld.new()
	root.add_child(w)
	await _frames(3)
	var rects: Array = []
	for r in HouseRooms.ids():
		rects.append(HouseWorld.room_rect(r))
	var clean := true
	for i in rects.size():
		var rc: Rect2 = rects[i]
		clean = clean and is_equal_approx(rc.size.x, 6.0) and is_equal_approx(rc.size.y, 6.0)
		for j in range(i + 1, rects.size()):
			clean = clean and not rc.intersects(rects[j])
		clean = clean and HouseWorld.bounds().encloses(rc)
	check(clean, "eight rooms of 6 x 6 m, none on another, all inside the house")
	var hall := Rect2(HouseWorld.ORIGIN.x - 2.0, HouseWorld.ORIGIN.z + HouseWorld.NORTH, 4.0, -HouseWorld.NORTH + HouseWorld.FRONT)
	var apart := true
	for rc in rects:
		apart = apart and not hall.intersects(rc)
	check(apart and HouseWorld.NORTH < -24.0 and HouseWorld.NORTH > -27.0, "and a hall 4 m wide between the rows, %.0f m long" % (-HouseWorld.NORTH + HouseWorld.FRONT))
	var wk := w.walk
	check(not wk.blocked(Vector2(HouseWorld.spawn().x, HouseWorld.spawn().z)), "the hero comes in on free ground")
	check(not wk.blocked(Vector2(HouseWorld.exit_center().x, HouseWorld.exit_center().z)) and HouseWorld.at_exit(HouseWorld.spawn()), "the way out's circle is free and the hero comes in at it")
	var reach := 0
	var lost: Array = []
	var from := Vector2(HouseWorld.spawn().x, HouseWorld.spawn().z)
	for r in HouseRooms.ids():
		var door := HouseWorld.door_point(r)
		var inner := Vector2(HouseWorld.room_center(r).x, HouseWorld.room_center(r).z)
		# in front of the room's stuff: a free spot in the room near the door
		var d: Dictionary = HouseRooms.ROOMS[r]
		var spot := Vector2(HouseWorld.room_center(r).x - int(d["side"]) * 1.6, HouseWorld.room_center(r).z + HouseWorld.DOOR_DZ)
		var route := wk.route(from, spot)
		if not route.is_empty() and not wk.blocked(spot):
			reach += 1
		else:
			lost.append(r)
		check(HouseWorld.room_at(Vector3(inner.x, 0, inner.y)) == r, "%s: the centre of its floor is its own" % r)
		var _unused := door
	check(reach == 8, "every room can be walked into from the door (%s lost)" % ", ".join(lost))
	# rooms shut at a low building level: the door is a wall
	_fresh(1, 0, 0)
	w.sync()
	var shut := []
	for r in HouseRooms.ids():
		var d2: Dictionary = HouseRooms.ROOMS[r]
		var spot2 := Vector2(HouseWorld.room_center(r).x - int(d2["side"]) * 1.6, HouseWorld.room_center(r).z + HouseWorld.DOOR_DZ)
		if wk.route(from, spot2).is_empty() or wk.blocked(spot2):
			shut.append(r)
	shut.sort()
	check(shut == ["coach", "gym", "hall", "lounge", "med", "video"], "building 1: the dorm and the canteen open, the six others are shut (%s)" % ", ".join(shut))
	check(w.sign_of("gym").text.contains("ур. 2") and w.sign_of("hall").text.contains("ур. 5") and w.sign_of("dorm").text.contains("○"), "the sign on a shut door says when it opens")
	check(not w.stuff("gym").visible and w.stuff("dorm").visible, "nothing is drawn in a shut room")
	# what the levels put in
	_fresh(5, 0, 0)
	var tris: Array = []
	for lv in range(0, 6):
		SaveData.house = {"levels": {"gym": lv}}
		w.sync()
		var m := w.stuff("gym").mesh
		tris.append(0 if m == null or m.get_surface_count() == 0 else (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
	var every_level := true
	for r in HouseRooms.ids():
		for lv in range(1, 6):
			every_level = every_level and not HouseProps.items(r, lv).is_empty() and not HouseProps.marks(r, lv).is_empty()
	check(every_level, "every one of the 40 levels adds an object, and has a place for its chalk mark")
	check(tris[0] > 0 and tris[5] > tris[2] and tris[3] > tris[1], "the gym's mesh grows with its levels: %s triangles (level 0 is only the chalk mark of the first)" % str(tris))
	var box_all := 0
	for r in HouseRooms.ids():
		SaveData.house = {"levels": {r: 5}}
		w.sync()
		var arr := w.stuff(r).mesh.surface_get_arrays(0)
		box_all += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		check((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 < 3000, "%s at level 5 is under 3000 triangles (%d)" % [r, (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
	SaveData.house = {"levels": {"dorm": 2}, "building": {"gym": {"level": 4, "until": 99}}}
	_fresh_keep_levels_3()
	w.sync()
	check(w.sign_of("gym").text.contains("стройка"), "a room on scaffolding says so by its door")
	w.set_inside("gym")
	check(not w.fade_of("gym").visible and w.fade_of("dorm").visible, "the hero in a room: its front wall steps aside")
	w.set_inside("")
	check(w.fade_of("gym").visible, "and comes back when he leaves")
	w.queue_free()
	await _frames(2)


func _fresh_keep_levels_3() -> void:
	var h := SaveData.house.duplicate(true)
	_fresh(3, 0, 5)
	SaveData.house = h


func test_visit() -> void:
	print("in the house")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	var hooked: bool = Academy.hooks.has("capacity") and Academy.hooks.has("growth_mult") and Academy.hooks.has("ceiling_add")
	_fresh(1, 5000, 4)
	SaveData.club["met_coach"] = true
	SaveData.club["walk_hint"] = true
	SaveData.active = null
	SaveData.run = {}
	Skills.pending = []
	ClubDaytime.force_hour = 11.0
	main._show_menu()
	await _frames(6)
	var club = main.club
	var hero: Athlete = main.player
	var cam: ClubCamera = club.cam
	var door: Vector3 = ClubPlaces.find("academy")["pos"]
	AcademyHouse.install()
	check(hooked, "the club put the house into the school at its start (3 hooks)")
	check(club.house != null and not club.house.inside, "the house is not entered yet")
	hero.position = door
	club._update_place()
	await _frames(3)
	check(club.hud.current_place() == "academy", "at the academy's door the club shows its button")
	var b: Dictionary = club.place_buttons("academy")
	check(b["action"] == "club_house" and b["label"] == "В ДОМ АКАДЕМИИ" and b["extra"][0][1] == "club_students", "which is «В дом», the students one quiet tap away")
	# the door
	var t0 := Time.get_ticks_msec()
	club.ui_action("club_house", 0)
	var waited := 0
	while not club.house.inside and waited < 200:
		await process_frame
		waited += 1
	var took := float(Time.get_ticks_msec() - t0) / 1000.0
	check(club.house.inside, "the door takes the hero in")
	check(took < HouseVisit.ENTER_BUDGET - HouseVisit.FADE, "to the controls in %.2f s: the fade out %.2f s and the house (budget %.1f s with the fade in)" % [took, HouseVisit.FADE, HouseVisit.ENTER_BUDGET])
	check(club.house.build_ms < 250.0, "the house builds in %.0f ms the first time" % club.house.build_ms)
	await _frames(4)
	var w: HouseWorld = club.house.world
	check(not club.world.visible and club.world.process_mode == Node.PROCESS_MODE_DISABLED, "the club behind is not drawn and not processed")
	check(not main.cpu.visible and cam.walk_override == w.walk and cam.environment == w.env, "the coach is away, the camera has the house's walls and light")
	check(w.bounds().has_point(Vector2(hero.position.x, hero.position.z)) and absf(hero.position.y) < 0.01, "the hero stands in the house")
	check(cam.global_position.distance_to(hero.global_position) < 12.0 and cam.global_position.y > 2.0, "and the camera is behind him (%.1f m)" % cam.global_position.distance_to(hero.global_position))
	check(not club.hud._travel_btn.visible, "the quick travel button is put away")
	check(club.hud.current_place() == "house_exit", "at the door out: «Выйти из дома»")
	# walk to the dorm
	var spot := Vector3(HouseWorld.room_center("dorm").x + 1.6, 0, HouseWorld.room_center("dorm").z + HouseWorld.DOOR_DZ)
	club._move_target = spot
	waited = 0
	while club.house._room != "dorm" and waited < 400:
		await process_frame
		waited += 1
	check(club.house._room == "dorm", "a tap on the floor walks him into the dorm (%d frames)" % waited)
	await _frames(30)
	check(club.hud.current_place() == "house_dorm" and not w.fade_of("dorm").visible, "its button shows and its front wall is out of the way")
	check(cam.is_flying() or cam.global_position.z > HouseWorld.room_center("dorm").z + 6.0, "the camera frames the room from the south")
	# buy in the room
	var gold := SaveData.gold
	club.ui_action("club_house_up:dorm", 0)
	check(AcademyHouse.level("dorm") == 1 and SaveData.gold == gold - 75, "the quiet button buys level 1 for 75")
	club.ui_action("club_house_room:dorm", 0)
	await _frames(3)
	check(main.ui.is_open(), "the room's button opens its sheet")
	var sheet = load("res://scripts/ui/screens/house_room.gd")   # by path: it leans on TournamentUI, which compiles after the autoloads
	var inf: Dictionary = sheet.info("dorm")
	check(inf["level"] == 1 and (inf["rows"] as Array).size() == 5 and String(inf["button"]).begins_with("УЛУЧШИТЬ  ·  170"), "the sheet: level 1 of 5, the next costs 170 (%s)" % inf["button"])
	club.ui_action("club_house_buy:dorm", 0)
	check(AcademyHouse.level("dorm") == 2 and SaveData.gold == gold - 245, "and buys from the sheet")
	inf = sheet.info("dorm")
	check(not inf["why"].is_empty() and String(inf["button"]).begins_with("Нужна академия ур. 2"), "the third level needs the building at level 2 (%s)" % inf["button"])
	club.ui_action("club_house_back", 0)
	check(not main.ui.is_open(), "«Назад» closes the sheet")
	check(Academy.capacity() == 3, "the school's seats follow the dorm: building 1 gives 2, a dorm at 2 gives 3 (%d)" % Academy.capacity())
	# the shut door
	var gym_door := HouseWorld.door_point("gym")
	hero.position = Vector3(gym_door.x, 0, gym_door.z)
	club._move_target = Vector3(HouseWorld.room_center("gym").x, 0, HouseWorld.room_center("gym").z)
	await _frames(60)
	check(HouseWorld.room_at(hero.position) != "gym", "a shut room keeps the hero out")
	# out
	hero.position = HouseWorld.exit_center()
	await _frames(3)
	check(club.hud.current_place() == "house_exit", "back at the door out")
	t0 = Time.get_ticks_msec()
	club.ui_action("club_house_exit", 0)
	waited = 0
	while club.house.inside and waited < 200:
		await process_frame
		waited += 1
	await _frames(20)
	check(not club.house.inside and club.world.visible and club.world.process_mode == Node.PROCESS_MODE_INHERIT, "the way out brings the club back")
	check(main.cpu.visible and cam.walk_override == null and cam.environment == null, "the coach, the club's camera and its sky too")
	check(Vector2(hero.position.x - door.x, hero.position.z - door.z).length() < 1.0, "the hero stands at the academy's door")
	check(club.hud._travel_btn.visible and club.hud.current_place() == "academy", "the club's buttons are back")
	# the second visit: the house is only hidden
	var w1: HouseWorld = club.house.world
	club.ui_action("club_house", 0)
	waited = 0
	while not club.house.inside and waited < 200:
		await process_frame
		waited += 1
	check(club.house.world == w1 and w1.visible, "the second visit is the same house, shown (nothing built again)")
	await _frames(10)
	# a match or a bracket frees it
	club.close()
	check(not club.house.inside and club.house.world == null and main.cpu.visible, "the club closing frees the house and puts everything back")
	check(club.world.visible and cam.walk_override == null, "(and the club is as it was)")
	main.queue_free()
	await _frames(2)
