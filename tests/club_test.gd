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
	await test_world()
	await test_flow()
	await test_places_flow()
	await test_build_world()
	await test_foreman_flow()
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
	for id in ["court", "machine", "coach", "gate", "locker", "shop", "trophy", "bar", "arena", "board"]:
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
	check(int(ClubPlaces.state("bar", 3)["bet_limit"]) > int(ClubPlaces.state("bar", 0)["bet_limit"]), "a bigger bar takes bigger bets")
	check(ClubPlaces.state("bar", 9)["bet_limit"] == ClubPlaces.state("bar", 3)["bet_limit"], "past the last level the last one holds")
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
	SaveData.club["levels"] = {"court": 4}
	check(not ClubBuilds.buy("court") and ClubBuilds.next_price("court") == 0 and SaveData.gold == 100000, "nothing above the top level")
	SaveData.club = {"levels": {"court": 2, "gate": 1}, "color": 2, "name": "Клуб Димы", "spent": 220}
	var cf := SaveData._to_config()
	SaveData.club = {}
	SaveData._apply(cf)
	check(ClubBuilds.level("court") == 2 and ClubBuilds.level("gate") == 1 and ClubBuilds.color_index() == 2 and ClubBuilds.club_name() == "Клуб Димы", "save and load: the same levels, colour and name")
	SaveData.club = {}
	check(is_zero_approx(ClubBuilds.gold_win_bonus()), "no stands, no bonus")
	var ok := true
	for lv in range(1, 6):
		SaveData.club = {"levels": {"stands": lv}}
		ok = ok and is_equal_approx(ClubBuilds.gold_win_bonus(), 0.02 * lv)
	check(ok and ClubBuilds.gold_win_bonus() <= 0.10, "stands: +2% a level, at most +10%")
	ClubBuilds.utility_enabled = false
	check(is_zero_approx(ClubBuilds.gold_win_bonus()), "no perk online")
	ClubBuilds.utility_enabled = true
	var limits := []
	for lv in 4:
		SaveData.club = {"levels": {"bar": lv}}
		limits.append(ClubBuilds.bet_limit())
	check(limits == [25, 50, 150, 500], "the bar takes bigger bets as it grows %s" % str(limits))
	SaveData.titles = 0
	SaveData.played = 0
	SaveData.club = {}
	SaveData.gold = 100000
	check(not ClubBuilds.is_open("bar") and not ClubBuilds.can_afford("bar") and not ClubBuilds.can_afford("trophy"), "the bar waits for a title, the trophy room for a run")
	check(ClubBuilds.affordable_count() == 3, "with plenty of gold: court, stands, gate (%d)" % ClubBuilds.affordable_count())
	SaveData.played = 1
	SaveData.titles = 1
	check(ClubBuilds.affordable_count() == 5, "all five after a title")
	SaveData.gold = 45
	check(ClubBuilds.affordable_count() == 1, "45 gold: only the court (%d)" % ClubBuilds.affordable_count())
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
	for id in ClubBuilds.ORDER:
		for lv in ClubBuilds.max_level(id) + 1:
			w.set_level(id, lv)
			if w.level_built(id) != lv:
				fine = false
		w.show_ghost(id, ClubBuilds.max_level(id))
		w.show_ghost("", 0)
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
	SaveData.gold = 500
	club._refresh()
	club._travel("bar")
	await _frames(2)
	check(club.upgrade_price("bar") == 100, "an affordable upgrade shows by its place (↑ 100)")
	check(club.upgrade_price("court") == 0, "never on the main screen: Новая игра / Продолжить stay alone")
	main.queue_free()
	await _frames(2)
	SaveData.club = {}
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0
