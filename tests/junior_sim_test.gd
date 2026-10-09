extends SceneTree
## The students' matches (docs/superpowers/specs/2026-10-09-tycoon.md 4, plan 2026-10-10-t4):
## the instant result (JuniorSim), the setups and the advice rules (JuniorBot), the schedule,
## the result and the rewards (JuniorMatch).
##   godot --headless --path . -s tests/junior_sim_test.gd

var failures := 0


func _initialize() -> void:
	SaveData.enabled = false
	test_levels()
	test_sim()
	test_stances()
	test_advice_rules()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _student(v: int, extra := {}) -> Dictionary:
	var st := {"id": "s1", "name": "Аня Орлова", "age": 15, "stats": {}, "traits": [], "revealed": [], "leanings": ["net", "serve"], "rating": 1000, "xp": {}, "focus": "net", "matches": 0, "watched": 0, "trainings": 0}
	for k in Opponents.STAT_KEYS:
		st["stats"][k] = v
	st.merge(extra, true)
	return st


func _opp(v: int, style := "allcourt", extra := {}) -> Dictionary:
	var o := {"id": "x", "name": "Юниор", "skill": 0.4, "play_style": style, "stats": {}}
	for k in Opponents.STAT_KEYS:
		o["stats"][k] = v
	o.merge(extra, true)
	return o


func test_levels() -> void:
	print("stats become skills")
	var st := _student(5)
	st["stats"]["serve"] = 9
	st["stats"]["speed"] = 2
	var lv := JuniorBot.levels(st)
	check(lv["serve"] > lv["forehand"] and lv["feet"] < lv["forehand"], "serve 9 is a higher level than forehand 5, speed 2 a lower one (%s)" % str(lv))
	var prof := JuniorBot.skill_profile(st)
	var ok := true
	for id in lv:
		ok = ok and Skills.level_of(prof, id) == int(lv[id])
	check(ok, "the profile Main plays with holds exactly those levels")
	var mono := true
	for i in range(1, 10):
		mono = mono and JuniorBot.LEVEL_OF_STAT[i] > JuniorBot.LEVEL_OF_STAT[i - 1]
	check(mono and JuniorBot.LEVEL_OF_STAT.back() <= Skills.MAX_LEVEL, "a higher stat is a higher level, none past the cap")
	check(JuniorBot.sd_of(_student(1)) > JuniorBot.sd_of(_student(10)) and JuniorBot.sd_of(_student(10)) >= JuniorBot.SD_MIN - 0.0001, "a beginner's thumb is shakier than a pro's")
	var cannon := _student(5, {"traits": [{"id": "bomber", "hidden": false}]})
	check(float(JuniorBot.style_of(cannon)["aggr"]) > float(JuniorBot.style_of(_student(5))["aggr"]), "the trait «Бомбардир» leans the style")
	var s0 := {}
	for k in Skills.mods_layer:
		s0[k] = 1
	var bot := JuniorBot.new(_student(5, {"traits": [{"id": "serve_cannon", "hidden": false}]}), _opp(5), 3)
	bot.begin()
	check(is_equal_approx(Skills.mod("serve_pace"), 0.10), "begin(): the traits stand on the layer")
	bot.set_stance("aggr", 1.0)
	bot.end()
	check(Skills.mods_layer.is_empty(), "end(): nothing is left on the layer")


func test_sim() -> void:
	print("the instant result")
	var a := _student(5)
	var b := _opp(5)
	var r1 := JuniorSim.simulate(a, b, {"seed": 11, "first": 0})
	var r2 := JuniorSim.simulate(a, b, {"seed": 11, "first": 0})
	check(str(r1) == str(r2), "the same seed, the same tiebreak")
	var differ := false
	for s in range(12, 30):
		differ = differ or str(JuniorSim.simulate(a, b, {"seed": s, "first": 0})["log"]) != str(r1["log"])
	check(differ, "another seed, another tiebreak")
	var valid := true
	for s in range(1, 120):
		var r := JuniorSim.simulate(a, b, {"seed": s, "first": s % 2})
		var hi := maxi(int(r["pa"]), int(r["pb"]))
		var lo := mini(int(r["pa"]), int(r["pb"]))
		valid = valid and hi >= 7 and hi - lo >= 2 and (hi == 7 or hi - lo == 2) and (r["log"] as Array).size() == hi + lo and (int(r["winner"]) == 0) == (int(r["pa"]) > int(r["pb"]))
	check(valid, "a tiebreak to 7 with two clear, 7:x or a two-point margin after 6:6, the log holds every point")
	# The serve pattern is the game's own (MatchScore).
	var sc := MatchScore.new(1, 0, 0, 0, "x")
	var same := true
	for i in 14:
		same = same and sc.server == JuniorSim.server_of(i, 0)
		sc.add_point(i % 2)
		if sc.is_over():
			break
	check(same, "who serves: 1-2-2-2... as MatchScore does it")
	var strong := JuniorSim.win_chance(_student(8), _opp(3), 200)
	var weak := JuniorSim.win_chance(_student(3), _opp(8), 200)
	var even := JuniorSim.win_chance(_student(5), _opp(5), 400)
	check(strong > 0.9 and weak < 0.1, "8 against 3 wins almost always, 3 against 8 almost never (%.2f / %.2f)" % [strong, weak])
	check(even > 0.4 and even < 0.6, "the same stats, about even (%.2f)" % even)
	# From a score: it goes on from there.
	var cont := JuniorSim.simulate(a, b, {"seed": 5, "first": 0, "from": [6, 3]})
	check(int(cont["pa"]) >= 6 and int(cont["pb"]) >= 3 and (cont["log"] as Array).size() == int(cont["pa"]) + int(cont["pb"]) - 9, "left at 6:3 it goes on from 6:3 (%d:%d)" % [cont["pa"], cont["pb"]])
	var done := JuniorSim.simulate(a, b, {"seed": 5, "first": 0, "from": [7, 2]})
	check(int(done["pa"]) == 7 and int(done["pb"]) == 2 and (done["log"] as Array).is_empty(), "a finished score is not played again")
	check(bool(JuniorSim.simulate(a, b, {"seed": 9, "first": 0})["match_point"]), "a tiebreak always has a match point (for the break-point trait)")


func test_stances() -> void:
	print("the setups")
	check(JuniorBot.STANCES.size() == 8 and JuniorBot.STANCE_ORDER.size() == 8, "eight setups")
	var fine := true
	for id in JuniorBot.STANCES:
		var d: Dictionary = JuniorBot.STANCES[id]
		fine = fine and d.has("name") and d.has("hint") and (d["d"] as Dictionary).size() >= 1 and String(d["hint"]).length() <= 60
		for k in d["d"]:
			fine = fine and Opponents.PLAY_STYLES["allcourt"].has(k)
	check(fine, "each has a name, a line of 60 letters, and changes known style keys")
	var base := JuniorBot.style_of(_student(5))
	var aggr := JuniorBot.styled(base, "aggr", 1.0)
	check(is_equal_approx(float(aggr["aggr"]) - float(base["aggr"]), 0.30) and is_equal_approx(float(aggr["risk"]) - float(base["risk"]), 0.15), "«Агрессивнее»: aggr +0.30, risk +0.15")
	var half := JuniorBot.styled(base, "patient", 0.5)
	check(is_equal_approx(float(half["patience"]) - float(base["patience"]), 0.15), "a half-weight setup changes the style by half")
	check(JuniorBot.styled(base, "net", 0.0) == base, "weight 0: nothing changes")
	# fit is -1..+1 and follows the columns of the table.
	var in_range := true
	for id in JuniorBot.STANCES:
		for v in [2, 5, 9]:
			for style in Opponents.PLAY_STYLES:
				var f := JuniorBot.fit(id, _student(v), _opp(5, style))
				in_range = in_range and f >= -1.0 and f <= 1.0
	check(in_range, "fit stays within -1..+1")
	var slow := _opp(3, "counter", {"stats": {"serve": 3, "forehand": 6, "backhand": 6, "net": 2, "speed": 2, "stamina": 3}})
	var fast := _opp(8, "attacker", {"stats": {"serve": 9, "forehand": 8, "backhand": 8, "net": 8, "speed": 9, "stamina": 9}})
	check(JuniorBot.fit("aggr", _student(5), slow) > 0.5 and JuniorBot.fit("aggr", _student(5), fast) < 0.0, "aggression pays against a slow counter-puncher with a weak serve, not against a fast hitter")
	check(JuniorBot.fit("patient", _student(5), fast) > JuniorBot.fit("patient", _student(5), slow), "patience beats a hitter with... a tank: the hitter more than the counter-puncher")
	var skew := _opp(5, "allcourt", {"stats": {"serve": 5, "forehand": 8, "backhand": 2, "net": 5, "speed": 5, "stamina": 5}})
	check(JuniorBot.fit("weak", _student(5), skew) > 0.7 and JuniorBot.fit("weak", _student(5), _opp(5)) < -0.5, "the weak wing pays against a lopsided player, not against an even one")
	check(JuniorBot.fit("legs", _student(5), _opp(5), 1.0) > JuniorBot.fit("legs", _student(5), _opp(5), 0.0), "«Береги ноги» pays when the student is spent")
	check(JuniorBot.effect_pp(1.0) >= 10.0 and JuniorBot.effect_pp(1.0) <= 15.0, "the right setup: +10...15 points of the share (%.1f)" % JuniorBot.effect_pp(1.0))
	check(JuniorBot.effect_pp(-1.0) <= -5.0 and JuniorBot.effect_pp(-1.0) >= -10.0, "the wrong one: -5...-10 (%.1f)" % JuniorBot.effect_pp(-1.0))
	# In the instant result the right setup helps and the wrong one costs.
	var st := _student(5)
	var o := slow
	var best := JuniorBot.pick(["aggr", "patient", "net", "legs"], st, o, 0)
	var worst := JuniorBot.pick(["aggr", "patient", "net", "legs"], st, o, 3)
	var n := 600
	var sum_base := 0.0
	var sum_best := 0.0
	var sum_worst := 0.0
	for k in n:
		sum_base += JuniorSim.share(JuniorSim.simulate(st, o, {"seed": 100 + k, "first": k % 2}))
		sum_best += JuniorSim.share(JuniorSim.simulate(st, o, {"seed": 100 + k, "first": k % 2, "setups": [{"at": 0, "id": best}]}))
		sum_worst += JuniorSim.share(JuniorSim.simulate(st, o, {"seed": 100 + k, "first": k % 2, "setups": [{"at": 0, "id": worst}]}))
	check(sum_best > sum_base and sum_worst < sum_base, "the right setup lifts the share of points, the wrong one lowers it (%.3f / %.3f / %.3f)" % [sum_best / n, sum_base / n, sum_worst / n])


func test_advice_rules() -> void:
	print("when the coach is asked")
	check(JuniorBot.situation(2, 4, 0, 1.0, 99, 0) == "behind", "two points down: behind")
	check(JuniorBot.situation(3, 4, 0, 1.0, 99, 0) == "", "one point down: no stop")
	check(JuniorBot.situation(5, 6, 0, 1.0, 99, 0) == "critical", "the opponent at 6 and ahead: set point against")
	check(JuniorBot.situation(6, 6, 0, 1.0, 99, 0) == "", "6:6 is not a stop")
	check(JuniorBot.situation(4, 4, 0, 0.30, 99, 0) == "tired", "tired below 35%")
	check(JuniorBot.situation(4, 4, 3, 1.0, 99, 0) == "streak", "three points in a row")
	check(JuniorBot.situation(2, 4, 0, 1.0, 3, 1) == "", "not twice within four points")
	check(JuniorBot.situation(2, 4, 0, 1.0, 4, 1) == "behind", "four points later: again")
	check(JuniorBot.situation(2, 5, 0, 1.0, 99, 3) == "", "three pieces of advice at most")
	for sit in JuniorBot.OFFER:
		for serves in [true, false]:
			var opts := JuniorBot.options_for(sit, serves)
			var uniq := {}
			for id in opts:
				uniq[id] = true
			check(opts.size() == 4 and uniq.size() == 4 and (serves or not opts.has("body")), "%s (%s): four different setups%s" % [sit, "serving" if serves else "receiving", "" if serves else ", no serve target"])
	var sim_adv := JuniorSim.simulate(_student(4), _opp(7), {"seed": 3, "first": 0, "autopilot": true})
	check((sim_adv["stances"] as Array).size() <= 3, "the autopilot asks at most three times (%d)" % (sim_adv["stances"] as Array).size())
