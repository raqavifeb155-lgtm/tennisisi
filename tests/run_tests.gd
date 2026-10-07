extends SceneTree
## Headless physics sanity tests:
##   godot --headless --path . -s tests/run_tests.gd

var failures := 0


func _init() -> void:
	test_drop_bounce()
	test_topspin_dips()
	test_topspin_kicks_on_bounce()
	test_solver_accuracy()
	test_net_collision()
	test_scoring()
	test_tiebreak_match()
	test_short_sets()
	test_classic_set()
	test_tournament_flow()
	test_tournament_save()
	test_progress_copies()
	test_skills()
	test_gear_and_loot()
	test_timing_ring_stays_put()
	test_surfaces()
	test_service_box()
	test_gestures()
	test_topspin_curl()
	test_player_lob()
	test_net_cord()
	test_sidespin_solver()
	test_drop_shot()
	test_stamina_breaks()
	test_stamina_tank()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


## ITF: dropped from 254 cm a ball must rebound 135-147 cm.
func test_drop_bounce() -> void:
	print("drop bounce")
	var s := BallPhysics.State.new(Vector3(0, 2.54, 5), Vector3.ZERO, Vector3.ZERO)
	var bounced := false
	var apex := 0.0
	for i in 2400:
		var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
		if ev == BallPhysics.Event.BOUNCE:
			if bounced:
				break
			bounced = true
		if bounced:
			apex = maxf(apex, s.pos.y)
	check(apex > 1.30 and apex < 1.50, "rebound height %.2f m (ITF 1.35-1.47)" % apex)


func flight_range(v: Vector3, spin_rad: float) -> float:
	var dir := Vector3(0, 0, -1)
	var s := BallPhysics.State.new(Vector3(0, 1.0, 11.0), v, BallPhysics.topspin_vector(dir, spin_rad))
	for i in 4000:
		if BallPhysics.substep(s, BallPhysics.MAX_STEP) == BallPhysics.Event.BOUNCE:
			return 11.0 - s.pos.z
	return INF


func test_topspin_dips() -> void:
	print("topspin dips, slice floats")
	var v := Vector3(0, 4.0, -25.0)
	var flat := flight_range(v, 0.0)
	var top := flight_range(v, 300.0)
	var slice := flight_range(v, -200.0)
	check(top < flat - 2.0, "topspin lands shorter: top %.1f m vs flat %.1f m" % [top, flat])
	check(slice > flat, "slice carries further: slice %.1f m vs flat %.1f m" % [slice, flat])


func test_topspin_kicks_on_bounce() -> void:
	print("bounce behaviour vs spin")
	var results := {}
	for spin in [300.0, 0.0, -200.0]:
		var s := BallPhysics.State.new(Vector3(0, 0.5, 0), Vector3(0, -6.0, -20.0), BallPhysics.topspin_vector(Vector3(0, 0, -1), spin))
		for i in 400:
			if BallPhysics.substep(s, BallPhysics.MAX_STEP) == BallPhysics.Event.BOUNCE:
				break
		results[spin] = s.vel
	var top: Vector3 = results[300.0]
	var flat: Vector3 = results[0.0]
	var slc: Vector3 = results[-200.0]
	check(-top.z > -flat.z, "topspin keeps more forward speed: %.1f vs flat %.1f m/s" % [-top.z, -flat.z])
	check(-slc.z <= -flat.z + 0.5, "slice does not kick forward: %.1f vs flat %.1f m/s" % [-slc.z, -flat.z])
	check(top.y > slc.y, "topspin bounces steeper than slice: vy %.2f vs %.2f" % [top.y, slc.y])


func test_solver_accuracy() -> void:
	print("shot solver lands on target")
	var cases := [
		[Vector3(1.0, 0.9, 11.5), Vector3(-3.0, 0.033, -10.0), 28.0, 250.0],
		[Vector3(-2.0, 0.6, 12.5), Vector3(3.5, 0.033, -9.0), 35.0, 40.0],
		[Vector3(0.0, 1.2, 10.0), Vector3(0.0, 0.033, -4.0), 15.0, -150.0],
		[Vector3(0.5, 1.0, -12.0), Vector3(2.0, 0.033, 10.5), 24.0, 200.0],
		# Low ball (55 cm) hit hard and flat to a short target: must still clear the net.
		[Vector3(2.0, 0.55, 9.9), Vector3(3.5, 0.033, -6.2), 32.0, 40.0],
	]
	for c in cases:
		var p0: Vector3 = c[0]
		var target: Vector3 = c[1]
		var t0 := Time.get_ticks_usec()
		var r := ShotSolver.solve(p0, target, c[2], c[3], 0.3)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var s := BallPhysics.State.new(p0, r.velocity, r.spin)
		var landing := Vector3.ZERO
		var netted := false
		for i in 4000:
			var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
			if ev == BallPhysics.Event.NET:
				netted = true
			if ev == BallPhysics.Event.BOUNCE:
				landing = s.pos
				break
		var err := Vector2(landing.x - target.x, landing.z - target.z).length()
		check(r.ok and not netted and err < 0.35,
			"target %s: err %.2f m, speed %.1f->%.1f m/s, elev %.1f deg, %.1f ms" % [target, err, c[2], r.speed, r.elevation_deg, ms])


func test_net_collision() -> void:
	print("net collision")
	var s := BallPhysics.State.new(Vector3(0, 0.5, 5.0), Vector3(0, 0.5, -20.0), Vector3.ZERO)
	var got_net := false
	for i in 2000:
		var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
		if ev == BallPhysics.Event.NET:
			got_net = true
		if ev == BallPhysics.Event.BOUNCE:
			break
	check(got_net and s.pos.z > 0.0, "low ball hits the net and drops on hitter's side (z=%.2f)" % s.pos.z)


func test_scoring() -> void:
	print("tennis scoring")
	var sc := TennisScore.new()
	for i in 3:
		sc.add_point(0)
	check(sc.point_text() == "YOU  40 : 0  CPU", "40-0: '%s'" % sc.point_text())
	for i in 3:
		sc.add_point(1)
	check(sc.point_text() == "DEUCE", "deuce: '%s'" % sc.point_text())
	sc.add_point(1)
	check(sc.point_text() == "AD CPU" and not sc.deuce_side(), "advantage CPU served from ad side")
	sc.add_point(0)
	check(sc.point_text() == "DEUCE", "back to deuce")
	sc.add_point(0)
	var game := sc.add_point(0)
	check(game and sc.games == [1, 0] and sc.server == 1, "game to player, server switches")


func _win_points(sc: MatchScore, w: int, n: int) -> int:
	var ev := MatchScore.Event.POINT
	for i in n:
		ev = sc.add_point(w)
	return ev


func test_tiebreak_match() -> void:
	print("tiebreak format")
	var sc := MatchScore.new(1, 0, 0, 0, "OPP")
	check(sc.in_tiebreak and sc.server == 0 and sc.deuce_side(), "first point: player serves from deuce side")
	sc.add_point(0)
	check(sc.server == 1 and not sc.deuce_side(), "after 1 point: opponent serves from ad side")
	sc.add_point(1)
	check(sc.server == 1 and sc.deuce_side(), "after 2 points: opponent still serves, deuce side")
	sc.add_point(1)
	check(sc.server == 0, "after 3 points: player serves again")
	_win_points(sc, 0, 5)
	_win_points(sc, 1, 4)  # 6:6
	check(sc.point_text() == "YOU  6 : 6  OPP" and not sc.is_over(), "6:6 goes on (win by two)")
	check(not sc.match_point_for(0), "6:6 is not a match point")
	sc.add_point(0)
	check(sc.match_point_for(0), "7:6 is a match point")
	var ev := sc.add_point(0)
	check(ev == MatchScore.Event.MATCH and sc.winner == 0 and sc.final_text() == "8:6", "8:6 wins the match: '%s'" % sc.final_text())
	var fin := MatchScore.new(2, 0, 0, 0)
	_win_points(fin, 0, 7)
	check(not fin.is_over() and fin.sets == [1, 0] and fin.server == 1, "final: first tiebreak won, the other player opens the second")


func test_short_sets() -> void:
	print("best of three short sets (to 4, tiebreak at 3:3)")
	var sc := MatchScore.new(2, 4, 3, 0)
	var ev := _win_points(sc, 0, 4)
	check(ev == MatchScore.Event.GAME and sc.games == [1, 0] and sc.server == 1, "game to player, server switches")
	for i in 3:
		_win_points(sc, 0, 4)
	check(sc.sets == [1, 0] and sc.games == [0, 0] and sc.set_scores[0] == [4, 0], "4:0 takes the set")
	for i in 3:
		_win_points(sc, 0, 4)
		_win_points(sc, 1, 4)
	check(sc.in_tiebreak and sc.games == [3, 3], "3:3 -> tiebreak")
	var tb_first := sc.server
	_win_points(sc, 1, 7)
	check(sc.sets == [1, 1] and sc.set_scores[1] == [3, 4], "tiebreak gives the set 4:3: %s" % str(sc.set_scores[1]))
	check(sc.server == 1 - tb_first and not sc.in_tiebreak, "the tiebreak receiver serves the next set")
	for i in 4:
		_win_points(sc, 0, 4)
	check(sc.winner == 0 and sc.final_text() == "4:0 · 3:4 · 4:0", "match 2-1: '%s'" % sc.final_text())


func test_classic_set() -> void:
	print("one set to 6, tiebreak at 6:6")
	var sc := MatchScore.new(1, 6, 6, 0)
	for i in 5:
		_win_points(sc, 0, 4)
		_win_points(sc, 1, 4)
	_win_points(sc, 0, 4)
	check(not sc.in_tiebreak and sc.games == [6, 5] and not sc.is_over(), "6:5 is not enough")
	_win_points(sc, 1, 4)
	check(sc.in_tiebreak, "6:6 -> tiebreak")
	_win_points(sc, 0, 6)
	check(sc.match_point_for(0), "6:0 in the tiebreak is a match point")
	sc.add_point(0)
	check(sc.winner == 0 and sc.final_text() == "7:6", "tiebreak wins the set 7:6: '%s'" % sc.final_text())
	var b := MatchScore.new(1, 6, 6, 0)
	for i in 5:
		_win_points(b, 0, 4)
		_win_points(b, 1, 4)
	_win_points(b, 1, 8)
	check(b.winner == 1 and b.final_text() == "5:7", "7:5 also wins: '%s'" % b.final_text())


func test_tournament_flow() -> void:
	print("tournament")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t := Tournament.new(0)
	check(t.opponent()["id"] == "dzumhur" and t.new_score(0).sets_to_win == 1, "level 1: Джумхур, one tiebreak")
	t.record_match(true, "7:3", rng)
	check(t.state == Tournament.State.REWARD and t.offer.size() == 3 and t.offer[2]["kind"] == "wildcard", "win -> 3 rewards incl. wildcard")
	check(t.gold == 4, "quick format pays 40%% gold: %d" % t.gold)
	t.take_reward(2)
	check(t.wildcards == 1 and t.state == Tournament.State.BRACKET and t.stage == 1, "wildcard taken, round 2")
	t.record_match(false, "5:7", rng)
	check(t.state == Tournament.State.LOST, "loss with a wildcard can be replayed")
	check(t.use_wildcard() and t.stage == 1 and t.wildcards == 0, "wildcard spent, same opponent again")
	t.record_match(false, "5:7", rng)
	check(t.state == Tournament.State.OVER and not t.champion, "loss without a wildcard ends the run")
	var w := Tournament.new(2)
	for i in w.rounds():
		if i == w.rounds() - 1:
			check(w.opponent()["id"] == "djokovic" and w.new_score(0).sets_to_win == 2 and w.new_score(0).games_per_set == 4, "final: Джокович, best of three short sets")
		w.record_match(true, "4:2 · 4:1", rng)
		if w.state == Tournament.State.REWARD:
			w.take_reward(0)
	check(w.champion and w.state == Tournament.State.OVER and w.perks.size() == 4, "five wins = champion, perks collected")


func test_tournament_save() -> void:
	print("tournament survives a reload")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t := Tournament.new(1)
	t.location = "clay"
	t.record_match(true, "6:3", rng)
	var d := t.to_dict()
	var cf := ConfigFile.new()  # through the same file format the game saves to
	cf.set_value("run", "data", d)
	var back := ConfigFile.new()
	back.parse(cf.encode_to_text())
	var r := Tournament.from_dict(back.get_value("run", "data"))
	check(r.state == Tournament.State.REWARD and r.stage == t.stage and r.location == "clay" and r.format == 1, "state, round, place and format come back")
	check(r.offer.size() == 3 and r.gold == t.gold and r.results.size() == 1, "reward cards, gold and results come back")
	check(r.rng.state == t.rng.state, "the random sequence continues where it was")
	r.take_reward(0)
	check(r.state == Tournament.State.BRACKET and r.stage == 1, "and the run goes on")


func test_progress_copies() -> void:
	print("progress: the copy with more progress wins, a save round-trips")
	var little := ConfigFile.new()
	little.set_value("meta", "gold", 500)
	var more := ConfigFile.new()
	more.set_value("meta", "played", 3)
	more.set_value("meta", "gold", 120)
	more.set_value("skills", "xp", {"forehand": 400.0})
	check(SaveData._score(more) > SaveData._score(little), "3 tournaments and skill xp beat a pile of gold")
	SaveData._apply(more)
	var back := ConfigFile.new()
	back.parse(SaveData._to_config().encode_to_text())
	check(back.get_value("meta", "played") == 3 and float((back.get_value("skills", "xp") as Dictionary)["forehand"]) == 400.0, "applied, written and read back the same")
	SaveData._apply(ConfigFile.new())  # leave the statics clean for the other tests


func test_skills() -> void:
	print("skills")
	Skills.reset()
	check(Skills.level("forehand") == 0, "a new player starts at level 0")
	var weak := Skills.stroke("forehand")
	check(weak["window"] < 1.0 and weak["scatter"] > 1.0 and weak["pace"] < 1.0, "beginner: narrow window, more scatter, less pace")
	check(weak["good"] > weak["window"] and weak["good"] >= 0.9, "beginner's GOOD window stays forgiving")
	check(weak["ring"] < 0.7 and weak["ring_speed"] > 1.2, "beginner's ring shows late and closes fast")
	var lv := Skills.add_xp("forehand", Skills.cost(1))
	check(lv == 1 and Skills.level("forehand") == 1, "first level costs %.0f xp" % Skills.cost(1))
	var to5 := 0.0
	for n in range(2, 6):
		to5 += Skills.cost(n)
	Skills.add_xp("forehand", to5)
	check(Skills.level("forehand") == 5 and Skills.pending == ["forehand"], "level 5 -> a perk choice is pending")
	var rng := RandomNumberGenerator.new()
	var c := Skills.next_pending(rng)
	check(c["skill"] == "forehand" and c["offer"].size() == 3, "3 forehand perks offered")
	var before: float = Skills.stroke("forehand")["window"]
	Skills.take_perk("fh_clean")
	check(Skills.pending.is_empty() and Skills.stroke("forehand")["window"] > before * 1.15, "perk widens the forehand window")
	var total := 0.0
	var to8 := 0.0
	for n in range(1, Skills.MAX_LEVEL + 1):
		total += Skills.cost(n)
		if n <= 8:
			to8 += Skills.cost(n)
	check(Skills.MAX_LEVEL == 25 and total > 8000.0 and total < 13000.0, "level 25 takes %.0f xp: a long road" % total)
	check(is_equal_approx(Skills.cost(1), 12.0) and absf(to8 - 780.0) < 30.0, "level 1 is a dozen hits, level 8 ~%.0f xp" % to8)
	Skills.add_xp("backhand", total * 2.0)
	check(Skills.level("backhand") == Skills.MAX_LEVEL and Skills.pending.size() == 5, "capped at 25, five perk choices on the way")
	for id in Skills.LIST:
		check(Skills.PERKS[id].size() >= 5, "%s has a perk for every milestone" % id)
	# Felt steps: a beginner is weak, a pro strong, and the early levels move the most.
	check(is_equal_approx(Skills.k(0), 0.0) and is_equal_approx(Skills.k(25), 1.0) and Skills.k(5) > 0.3, "early levels count most (k5 = %.2f)" % Skills.k(5))
	Skills.reset()
	var b0 := Skills.stroke("forehand", 0)
	var b25 := Skills.stroke("forehand", 25)
	check(is_equal_approx(b0["pace"], 0.70) and is_equal_approx(b0["scatter"], 1.8) and is_equal_approx(b0["window"], 0.55), "beginner: pace 0.70, scatter 1.8, window 0.55")
	check(is_equal_approx(b25["pace"], 1.25) and is_equal_approx(b25["scatter"], 0.5) and is_equal_approx(b25["window"], 1.5), "pro: pace 1.25, scatter 0.5, window 1.5")
	check(Skills.stroke("forehand", 1)["pace"] - b0["pace"] > 0.02, "one level is a step you feel (+%.0f%% pace)" % ((Skills.stroke("forehand", 1)["pace"] - b0["pace"]) * 100.0))
	check(Skills.headline("forehand", 7).ends_with("км/ч") and Skills.headline("forehand", 8) != Skills.headline("forehand", 7), "level-up shows a number: %s -> %s" % [Skills.headline("forehand", 7), Skills.headline("forehand", 8)])
	# Old saves: the xp stays, levels are recounted on the new curve, missing perk choices appear.
	Skills.reset()
	Skills.xp = {"forehand": total + 50.0}
	Skills.perks = ["fh_clean"]
	Skills.pending = ["forehand", "forehand", "forehand", "forehand", "forehand", "forehand"]
	Skills.rebuild_pending()
	check(Skills.level("forehand") == 25 and Skills.pending.size() == 4, "a save past the cap: level 25, 4 perk choices left (%d)" % Skills.pending.size())
	Skills.reset()


func test_gear_and_loot() -> void:
	print("gear and loot")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var leg := Gear.roll(Gear.LEGENDARY, rng)
	check(leg["slot"] == "racket" and leg.has("id") and int(Items.find(leg["id"])["rarity"]) == Gear.LEGENDARY, "a legendary racket is a catalog item with an effect '%s'" % leg["name"])
	check(Gear.glow(leg) > 1.0 and Gear.glow(Gear.roll(Gear.COMMON, rng)) == 0.0, "legendary glows, common does not")
	check(Gear.AFFIXES.size() >= 20, "%d affixes in the pool" % Gear.AFFIXES.size())
	var t := Tournament.new(0, 11)
	check(t.lineup.size() == 5 and t.lineup[0]["mods"].is_empty(), "lineup rolled up front, the tutorial opponent has no modifiers")
	# v0.2: each of his items drops by chance (30/20/12/6/3%); drop_bonus 1 = a sure drop.
	t.lineup[0]["gear"]["racket"] = leg
	t.drop_bonus = 1.0
	t.record_match(true, "7:2", rng)
	check(t.pending_loot == leg, "a dropped epic or better goes to the trophy game")
	t.take_loot(true)
	check(t.racket == leg and t.pending_loot.is_empty(), "trophy equipped")
	check(t.offer[1]["kind"] == "item", "reward offer: perk, item, wildcard")
	var rw: Dictionary = t.offer[1]["item"]
	t.take_reward(1)
	check(t.equip[rw["slot"]] == rw or t.bag.has(rw), "a reward item is put on (empty slot) or goes into the bag")
	t.lineup[1]["gear"]["racket"] = leg
	t.record_match(false, "3:7", rng)
	check(t.state == Tournament.State.OVER and t.pending_loot.is_empty(), "lose and the racket is gone")
	# Every opponent wears three items; epic and up are rare, likelier later and on the boss.
	var items := 0
	var epics := 0
	var boss_items := 0
	var boss_epics := 0
	var mods_seen := 0
	for k in 400:
		var tt := Tournament.new(1, k + 1)
		for i in tt.rounds():
			for slot in tt.lineup[i]["gear"]:
				var it: Dictionary = tt.lineup[i]["gear"][slot]
				items += 1
				var epic := int(it["rarity"]) >= Gear.EPIC
				epics += 1 if epic else 0
				if i == tt.rounds() - 1:
					boss_items += 1
					boss_epics += 1 if epic else 0
			mods_seen += tt.lineup[i]["mods"].size()
	check(items == 6000 and epics > 300 and epics < 1500, "epic gear shows up now and then: %d of %d items" % [epics, items])
	check(float(boss_epics) / boss_items > 1.5 * float(epics) / items, "the boss carries epic gear more often: %d of %d" % [boss_epics, boss_items])
	check(mods_seen > 300, "opponents come with modifiers: %d" % mods_seen)
	var tm := Tournament.new(1, 5)
	tm.lineup[0]["mods"] = ["fast", "steady"]
	check(is_equal_approx(tm.modifier_value("speed"), 1.12) and is_equal_approx(tm.modifier_value("skill"), 0.12) and tm.modifier_value("serve") == 1.0, "modifier values")
	Skills.reset()
	check(Skills.points == Skills.START_POINTS, "a new player gets %d starting points" % Skills.START_POINTS)
	Skills.spend_point("serve")
	check(Skills.level("serve") == 1 and Skills.points == Skills.START_POINTS - 1, "a point buys one level")
	Skills.gear = leg["mods"]
	var key: String = leg["mods"].keys()[0]
	check(Skills.mod(key) == leg["mods"][key], "the racket's affixes feed the stroke model")
	Skills.reset()


func test_timing_ring_stays_put() -> void:
	print("timing ring")
	var ring := TimingRing.new()
	ring.show_ring(Vector2(300, 400), 0.5, 0.035, 0.09)
	ring.show_ring(Vector2(355, 396), 0.4, 0.035, 0.09)
	ring.show_ring(Vector2(245, 403), 0.3, 0.035, 0.09)
	check(ring._pos == Vector2(300, 400), "the ring stays where it appeared (no shake)")
	ring.hide_ring()
	ring.show_ring(Vector2(250, 410), 0.2, 0.035, 0.09)
	check(ring._pos == Vector2(300, 400) and ring.is_shown(), "a one-frame gap doesn't move it")
	ring.free()


## The same shot on each surface: clay is slow and high, grass fast and low.
func test_surfaces() -> void:
	print("surfaces")
	var res := {}
	for id in ["clay", "hard", "grass"]:
		BallPhysics.set_surface(id)
		var s := BallPhysics.State.new(Vector3(0, 1.2, -1.0), Vector3(0, -3.0, -24.0), BallPhysics.topspin_vector(Vector3(0, 0, -1), 120.0))
		var bounced := false
		var apex := 0.0
		var speed_after := 0.0
		for i in 4000:
			var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
			if ev == BallPhysics.Event.BOUNCE:
				if bounced:
					break
				bounced = true
				speed_after = Vector2(s.vel.x, s.vel.z).length()
			if bounced:
				apex = maxf(apex, s.pos.y)
		res[id] = [speed_after, apex]
	BallPhysics.set_surface("hard")
	check(res["clay"][0] < res["hard"][0] and res["hard"][0] < res["grass"][0], "speed after the bounce: clay %.1f < hard %.1f < grass %.1f m/s" % [res["clay"][0], res["hard"][0], res["grass"][0]])
	check(res["clay"][1] > res["hard"][1] and res["hard"][1] > res["grass"][1], "bounce height: clay %.2f > hard %.2f > grass %.2f m" % [res["clay"][1], res["hard"][1], res["grass"][1]])
	check(Locations.LIST.size() == 4 and Locations.find("clay")["surface"] == "clay" and Locations.find("paris")["surface"] == "clay", "four locations (Paris is clay too)")
	var lob := Court.mark_size(Vector3(0, -12.0, -5.0))
	var flat := Court.mark_size(Vector3(0, -6.0, -30.0))
	check(lob.x < lob.y * 1.15, "a ball from above leaves a round mark (%.0f x %.0f mm)" % [lob.x * 1000.0, lob.y * 1000.0])
	check(flat.x > flat.y * 2.0, "a fast flat ball leaves a long oval (%.0f x %.0f mm)" % [flat.x * 1000.0, flat.y * 1000.0])
	var reach := Court.mark_reach(Vector3(0, -6.0, -30.0))
	check(absf(reach.x - BallPhysics.RADIUS) < 0.002 and reach.y > BallPhysics.RADIUS * 2.0, "an oval along the court reaches far along it, a ball's width sideways")
	check(Court.is_in_singles_mark(Vector3(0, 0, -(Court.HALF_LENGTH + 0.06)), -1, reach) and not Court.is_in_singles(Vector3(0, 0, -(Court.HALF_LENGTH + 0.06)), -1, BallPhysics.RADIUS), "a long skid touching the baseline is in where a round ball would be out")


func test_service_box() -> void:
	print("service boxes")
	# Player serving from the deuce side (x > 0) must land in the CPU box with x < 0.
	check(Court.in_service_box(Vector3(-2.0, 0, -5.0), -1, -1.0, BallPhysics.RADIUS), "diagonal box: in")
	check(not Court.in_service_box(Vector3(2.0, 0, -5.0), -1, -1.0, BallPhysics.RADIUS), "wrong box: fault")
	check(not Court.in_service_box(Vector3(-2.0, 0, -7.0), -1, -1.0, BallPhysics.RADIUS), "past service line: fault")
	check(Court.in_service_box(Vector3(0.01, 0, -6.42), -1, -1.0, BallPhysics.RADIUS), "touching lines: in")


func _path(fn: Callable, n := 20) -> Array:
	var pts := PackedVector2Array()
	var times := PackedInt32Array()
	for i in n:
		var u := float(i) / (n - 1)
		pts.append(fn.call(u))
		times.append(i * 12)
	return [pts, times]


func test_gestures() -> void:
	print("swipe shape -> stroke")
	var h := 1280.0
	var T := ShotGesture.Type
	# Up: straight is FLAT, aimed where it points.
	var straight := _path(func(u: float) -> Vector2: return Vector2(360 + 40 * u, 1000 - 380 * u))
	var g1 := ShotGesture.classify(straight[0], straight[1], h)
	check(g1.type == T.FLAT and g1.apex.x > 380.0, "straight up = FLAT, aimed up-right")
	# Up and a turn of the wrist at the top: TOPSPIN, aimed by the upward part only.
	var curl_r := _path(func(u: float) -> Vector2:
		if u < 0.7:
			return Vector2(360, 1000 - 380 * (u / 0.7))
		var a := (u - 0.7) / 0.3 * PI * 0.5
		return Vector2(360 + 90 * sin(a), 620 + 90 * (1.0 - cos(a))))
	var g2 := ShotGesture.classify(curl_r[0], curl_r[1], h)
	check(g2.type == T.TOPSPIN and absf(g2.apex.x - 360.0) < 38.0, "up + curl right = TOPSPIN aimed straight (apex x %.0f)" % g2.apex.x)
	var curl_l := _path(func(u: float) -> Vector2:
		if u < 0.75:
			return Vector2(360, 1000 - 380 * (u / 0.75))
		return Vector2(360 - 240 * (u - 0.75), 620 + 40 * (u - 0.75)))
	var g3 := ShotGesture.classify(curl_l[0], curl_l[1], h)
	check(g3.type == T.TOPSPIN and absf(g3.apex.x - 360.0) < 38.0, "up + curl left = TOPSPIN aimed straight")
	var small_curl := _path(func(u: float) -> Vector2:
		if u < 0.85:
			return Vector2(360, 1000 - 380 * (u / 0.85))
		return Vector2(360 + 400 * (u - 0.85), 620))
	var g4 := ShotGesture.classify(small_curl[0], small_curl[1], h)
	check(g4.type == T.TOPSPIN and g2.curl_k > g4.curl_k and g4.curl_k >= 0.8 and g2.curl_k <= 1.4 and g2.curl_k >= 1.1, "a bigger curl spins more (%.2f > %.2f)" % [g2.curl_k, g4.curl_k])
	check(g1.curl_k == 1.0, "no curl, no spin bonus")
	# The "C" that curls back at the end used to read as a slice: now it is TOPSPIN.
	var hook := _path(func(u: float) -> Vector2:
		if u < 0.65:
			return Vector2(360 - 30 * u, 1000 - 380 * (u / 0.65))
		return Vector2(340 - 80 * (u - 0.65), 620 + 330 * (u - 0.65)))
	check(ShotGesture.classify(hook[0], hook[1], h).type == T.TOPSPIN, "up, then hooked back = TOPSPIN, never SLICE")
	# Down: SLICE, aimed where the finger goes (mirrored up); a near-vertical one goes straight.
	var cut_r := _path(func(u: float) -> Vector2: return Vector2(360 + 120 * u, 600 + 300 * u))
	var g5 := ShotGesture.classify(cut_r[0], cut_r[1], h)
	check(g5.type == T.SLICE and g5.apex.x > g5.start.x + 10.0 and g5.apex.y < g5.start.y, "long down-right = SLICE aimed right")
	var cut_l := _path(func(u: float) -> Vector2: return Vector2(360 - 120 * u, 600 + 300 * u))
	var g6 := ShotGesture.classify(cut_l[0], cut_l[1], h)
	check(g6.type == T.SLICE and g6.apex.x < g6.start.x - 10.0, "long down-left = SLICE aimed left")
	var drift := _path(func(u: float) -> Vector2: return Vector2(360 + 300 * tan(deg_to_rad(10.0)) * u, 600 + 300 * u))
	var g7 := ShotGesture.classify(drift[0], drift[1], h)
	check(g7.type == T.SLICE and is_equal_approx(g7.apex.x, g7.start.x), "down with a 10° drift = SLICE straight")
	check(absf(g5.apex.x - g5.start.x) < 120.0 * 0.8, "the sideways part of a slice is softened")
	var steep := _path(func(u: float) -> Vector2: return Vector2(360 + 300 * u, 600 + 300 * tan(deg_to_rad(30.0)) * u))
	check(ShotGesture.classify(steep[0], steep[1], h).type == T.SLICE, "a slanted cut (60° off vertical) is still SLICE")
	var back_c := _path(func(u: float) -> Vector2: return Vector2(360 - 90 * sin(u * PI), 640 + 300 * u))
	check(ShotGesture.classify(back_c[0], back_c[1], h).type == T.SLICE, "a C drawn downward = SLICE")
	var little := _path(func(u: float) -> Vector2: return Vector2(360 + 30 * sin(u * PI), 800 + 80 * u))
	check(ShotGesture.classify(little[0], little[1], h).type == T.DROP, "a short little stroke down = DROP SHOT")
	var side := _path(func(u: float) -> Vector2: return Vector2(200 + 300 * u, 800 - 10 * u))
	check(ShotGesture.classify(side[0], side[1], h).type == T.FLAT, "almost sideways = FLAT")
	# LOB: a slow lift up along an arc. The same arc drawn fast is a TOPSPIN / FLAT.
	var arc := func(u: float) -> Vector2: return Vector2(360 + 110 * sin(u * PI), 1000 - 380 * u)
	var slow := _path(arc, 20)
	for i in slow[1].size():
		slow[1][i] = i * 45  # ~0.85 s for the whole lift
	var g8 := ShotGesture.classify(slow[0], slow[1], h)
	check(g8.type == T.LOB and absf(g8.apex.x - 360.0) < 40.0, "a slow arc up = LOB, aimed along the lift (apex x %.0f)" % g8.apex.x)
	var fast := _path(arc, 20)
	check(ShotGesture.classify(fast[0], fast[1], h).type != T.LOB, "the same arc drawn fast is not a LOB")
	var slow_line := _path(func(u: float) -> Vector2: return Vector2(360, 1000 - 380 * u), 20)
	for i in slow_line[1].size():
		slow_line[1][i] = i * 45
	check(ShotGesture.classify(slow_line[0], slow_line[1], h).type == T.FLAT, "a slow straight push up is FLAT, not a LOB")


## A full turn of the wrist (curl 1.4) on a topspin: the ball kicks up well above a flat
## shot of the same pace aimed at the same spot.
func test_topspin_curl() -> void:
	print("curled topspin kicks")
	var heights := {}
	for spin in [40.0, lerpf(300.0, 470.0, 0.75) * 1.4]:
		var p0 := Vector3(0.5, 1.0, 11.0)
		var r := ShotSolver.solve(p0, Vector3(0.0, BallPhysics.RADIUS, -9.0), 34.0, spin, 0.3)
		var s := BallPhysics.State.new(p0, r.velocity, r.spin)
		var bounced := false
		var top := 0.0
		for i in 6000:
			var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
			if ev == BallPhysics.Event.BOUNCE:
				if bounced:
					break
				bounced = true
			elif bounced:
				top = maxf(top, s.pos.y)
				if s.vel.y < 0.0:
					break
		heights[spin] = top
	var flat: float = heights[40.0]
	var curled: float = heights[heights.keys()[1]]
	check(curled >= flat * 1.3, "curled topspin bounces %.2f m vs flat %.2f m (x%.2f)" % [curled, flat, curled / maxf(flat, 0.01)])


## The player's lob (solver as main uses it): high over a player at the net, deep in.
func test_player_lob() -> void:
	print("lob over the net player")
	var p0 := Vector3(1.0, 0.9, 11.5)
	var target := Vector3(-1.0, BallPhysics.RADIUS, -(Court.HALF_LENGTH - 2.0))
	var r := ShotSolver.solve_lob(p0, target, 200.0, 30.0)
	var s := BallPhysics.State.new(p0, r.velocity, r.spin)
	var peak := 0.0
	var h_at_net_player := 0.0
	var landing := Vector3.INF
	for i in 8000:
		var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
		peak = maxf(peak, s.pos.y)
		if s.pos.z < -2.0 and h_at_net_player == 0.0:
			h_at_net_player = s.pos.y
		if ev == BallPhysics.Event.BOUNCE:
			landing = s.pos
			break
	check(h_at_net_player > 3.2, "passes 2 m past the net at %.1f m: out of a volleyer's reach" % h_at_net_player)
	check(peak > 4.5 and Court.is_in_singles(landing, -1, 0.0) and absf(landing.z - target.z) < 1.0, "peaks %.1f m, lands in at z %.1f" % [peak, landing.z])


func test_net_cord() -> void:
	print("net cord")
	var over := 0
	var back := 0
	for i in 12:
		var y := Court.NET_HEIGHT_CENTER + BallPhysics.RADIUS * (-0.5 + i * 0.13)
		var s := BallPhysics.State.new(Vector3(0, y, 0.15), Vector3(0, 0.0, -9.0), Vector3.ZERO)
		var touched := false
		for k in 2000:
			var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
			if ev == BallPhysics.Event.NET:
				touched = true
			if ev == BallPhysics.Event.BOUNCE:
				break
		if touched:
			if s.pos.z < 0.0:
				over += 1
			else:
				back += 1
	check(over > 0 and back > 0, "clipping the tape: %d rolled over, %d dropped back" % [over, back])


func test_sidespin_solver() -> void:
	print("slice serve with sidespin still lands on target")
	var p0 := Vector3(0.9, 2.6, 12.2)
	var target := Vector3(-3.2, 0.033, -5.6)
	var r := ShotSolver.solve(p0, target, 34.0, 80.0, 0.3, 260.0)
	var s := BallPhysics.State.new(p0, r.velocity, r.spin)
	for i in 3000:
		if BallPhysics.substep(s, BallPhysics.MAX_STEP) == BallPhysics.Event.BOUNCE:
			break
	var err := Vector2(s.pos.x - target.x, s.pos.z - target.z).length()
	check(err < 0.4, "landing error %.2f m with %.0f rpm sidespin" % [err, 260.0 * 60.0 / TAU])


func test_drop_shot() -> void:
	print("drop shot from the baseline dies near the net")
	var p0 := Vector3(0.5, 0.9, 12.0)
	var target := Vector3(-1.0, 0.033, -1.8)
	var r := ShotSolver.solve_drop(p0, target, -300.0)
	var s := BallPhysics.State.new(p0, r.velocity, r.spin)
	var bounces: Array[Vector3] = []
	var netted := false
	for i in 6000:
		var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
		if ev == BallPhysics.Event.NET:
			netted = true
		if ev == BallPhysics.Event.BOUNCE:
			bounces.append(s.pos)
			if bounces.size() == 2:
				break
	check(not netted and bounces.size() == 2, "clears the net and bounces twice")
	if bounces.size() == 2:
		var b1: Vector3 = bounces[0]
		var b2: Vector3 = bounces[1]
		check(absf(b1.z - target.z) < 0.5, "first bounce %.1f m past the net (target %.1f)" % [-b1.z, -target.z])
		check(b2.z > -5.0, "second bounce only %.1f m past the net: the receiver must sprint" % -b2.z)


## Breaks for the legs: the change of ends after odd games, the set break, every six
## points of a tiebreak; the even games and plain points give nothing.
func test_stamina_breaks() -> void:
	print("breaks: change of ends and set break")
	var sc := MatchScore.new(2, 4, 3, 0)
	check(sc.break_after(_win_points(sc, 0, 4)) == MatchScore.Break.CHANGE_ENDS, "after game 1 (1:0): change of ends")
	check(sc.break_after(_win_points(sc, 1, 4)) == MatchScore.Break.NONE, "after game 2 (1:1): play on")
	check(sc.break_after(_win_points(sc, 0, 4)) == MatchScore.Break.CHANGE_ENDS, "after game 3 (2:1): change of ends")
	check(sc.break_after(sc.add_point(0)) == MatchScore.Break.NONE, "a plain point gives nothing")
	var sc2 := MatchScore.new(2, 4, 3, 0)
	var ev := 0
	for i in 4:
		ev = _win_points(sc2, 0, 4)
	check(sc2.sets == [1, 0] and sc2.break_after(ev) == MatchScore.Break.SET_BREAK, "a set won: the set break")
	var tb := MatchScore.new(1, 0, 0, 0)
	var rests := 0
	for i in 12:
		if tb.break_after(tb.add_point(i % 2)) == MatchScore.Break.CHANGE_ENDS:
			rests += 1
	check(tb.in_tiebreak and rests == 2, "a tiebreak changes ends every six points (%d in 12)" % rests)


## The tank: a beginner runs dry in ~15 s of sprinting, a pro in ~60 s; rests grow with
## the "Выносливость" skill; the "Холодный пот" perk lowers where tiredness starts.
func test_stamina_tank() -> void:
	print("stamina tank")
	Skills.reset()
	var sprint := 0.0333
	check(absf(1.0 / (sprint * Skills.stamina_drain()) - 15.0) < 1.0, "beginner: dry after %.1f s of sprint" % (1.0 / (sprint * Skills.stamina_drain())))
	check(is_equal_approx(Skills.stamina_rest("point"), 0.10) and is_equal_approx(Skills.stamina_rest("change"), 0.30) and is_equal_approx(Skills.stamina_rest("set"), 0.50), "beginner rests: 10% / 30% / 50%")
	check(is_equal_approx(Skills.tired_below(), 0.4), "tired below 40%")
	Skills.xp = {"stamina": 1000000.0}
	check(absf(1.0 / (sprint * Skills.stamina_drain()) - 60.0) < 3.0, "pro: dry after %.1f s of sprint" % (1.0 / (sprint * Skills.stamina_drain())))
	check(is_equal_approx(Skills.stamina_rest("point"), 0.20) and is_equal_approx(Skills.stamina_rest("change"), 0.45), "pro rests: 20% / 45%")
	Skills.perks = ["st_cold"]
	check(is_equal_approx(Skills.tired_below(), 0.3), "Холодный пот: tired only below 30%")
	check(Skills.LIST.has("stamina") and Skills.PERKS["stamina"].size() >= 5, "Выносливость is a skill with perks")
	Skills.reset()
