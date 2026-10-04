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
	test_skills()
	test_gear_and_loot()
	test_timing_ring_stays_put()
	test_surfaces()
	test_service_box()
	test_gestures()
	test_net_cord()
	test_sidespin_solver()
	test_drop_shot()
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
	for n in range(1, Skills.MAX_LEVEL + 1):
		total += Skills.cost(n)
	check(Skills.MAX_LEVEL == 30 and total > 80000.0, "level 30 takes %.0f xp: hundreds of matches" % total)
	check(Skills.cost(1) == 100.0, "level 1 is about a hundred hits")
	Skills.add_xp("backhand", total * 2.0)
	check(Skills.level("backhand") == Skills.MAX_LEVEL and Skills.pending.size() == 6, "capped at 30, six perk choices on the way")
	for id in Skills.LIST:
		check(Skills.PERKS[id].size() >= 6, "%s has a perk for every milestone" % id)
	Skills.reset()


func test_gear_and_loot() -> void:
	print("gear and loot")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var leg := Gear.roll(Gear.LEGENDARY, rng)
	check(leg["mods"].size() == 4 and leg["lines"].size() == 4 and leg["name"].begins_with("Легендарная"), "legendary racket: 4 affixes '%s'" % leg["name"])
	check(Gear.glow(leg) > 1.0 and Gear.glow(Gear.roll(Gear.COMMON, rng)) == 0.0, "legendary glows, common does not")
	check(Gear.AFFIXES.size() >= 20, "%d affixes in the pool" % Gear.AFFIXES.size())
	var t := Tournament.new(0, 11)
	check(t.lineup.size() == 5 and t.lineup[0]["mods"].is_empty(), "lineup rolled up front, the tutorial opponent has no modifiers")
	t.lineup[0]["racket"] = leg
	t.record_match(true, "7:2", rng)
	check(t.pending_loot == leg, "beating the opponent drops their racket for sure")
	t.take_loot(true)
	check(t.racket == leg and t.pending_loot.is_empty(), "trophy equipped")
	check(t.offer[1]["kind"] == "item", "reward offer: perk, racket, wildcard")
	t.take_reward(1)
	check(t.racket.get("rarity", -1) <= Gear.RARE, "a reward racket replaces the one in hand")
	t.lineup[1]["racket"] = leg
	t.record_match(false, "3:7", rng)
	check(t.state == Tournament.State.OVER and t.pending_loot.is_empty(), "lose and the racket is gone")
	# Modifiers make loot likelier: count carried rackets over many lineups.
	var with_loot := 0
	var boss_loot := 0
	var mods_seen := 0
	for k in 400:
		var tt := Tournament.new(1, k + 1)
		for i in tt.rounds():
			if not tt.lineup[i]["racket"].is_empty():
				with_loot += 1
				if i == tt.rounds() - 1:
					boss_loot += 1
			mods_seen += tt.lineup[i]["mods"].size()
	check(with_loot > 100 and with_loot < 900, "rare rackets show up now and then: %d of 2000 opponents" % with_loot)
	check(boss_loot > 400 * 0.12, "the boss carries loot more often: %d of 400" % boss_loot)
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
	check(Locations.LIST.size() == 3 and Locations.find("clay")["surface"] == "clay", "three locations")


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
	var straight := _path(func(u: float) -> Vector2: return Vector2(360 + 40 * u, 1000 - 380 * u))
	var arc := _path(func(u: float) -> Vector2: return Vector2(360 + 120 * sin(u * PI), 1000 - 380 * u))
	var hook := _path(func(u: float) -> Vector2:
		if u < 0.65:
			return Vector2(360 - 30 * u, 1000 - 380 * (u / 0.65))
		return Vector2(340 - 80 * (u - 0.65), 620 + 330 * (u - 0.65)))
	var g1 := ShotGesture.classify(straight[0], straight[1], h)
	var g2 := ShotGesture.classify(arc[0], arc[1], h)
	var g3 := ShotGesture.classify(hook[0], hook[1], h)
	check(g1.type == ShotGesture.Type.FLAT, "straight swipe = FLAT (curve %.2f)" % g1.curve)
	check(g2.type == ShotGesture.Type.TOPSPIN, "C arc = TOPSPIN (curve %.2f)" % g2.curve)
	check(g3.type == ShotGesture.Type.SLICE, "hook back = SLICE (hook %.2f)" % g3.hook)
	check(g3.apex.y < 640.0, "slice aims at the forward point, not the hooked end")
	var small_hook := _path(func(u: float) -> Vector2:
		if u < 0.65:
			return Vector2(360, 1000 - 110 * (u / 0.65))
		return Vector2(360 - 40 * (u - 0.65), 890 + 120 * (u - 0.65)))
	var g4 := ShotGesture.classify(small_hook[0], small_hook[1], h)
	check(g4.type == ShotGesture.Type.DROP, "short small hook = DROP SHOT")


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
