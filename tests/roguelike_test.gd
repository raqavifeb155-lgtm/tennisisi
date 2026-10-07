extends SceneTree
## Stream A (v0.2) logic: style points, gear, opponent stamina, bets, golden opponents.
##   godot --headless --path . -s tests/roguelike_test.gd

var failures := 0


func _init() -> void:
	SaveData.enabled = false
	test_style_rules()
	test_style_meter()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


# --- A-1: style points ------------------------------------------------------------

func _stroke(type: String, label := "GOOD", curl := 1.0, diving := false) -> Dictionary:
	return {"type": type, "label": label, "curl_k": curl, "diving": diving, "smash": type == "SMASH"}


func _ctx(over := {}) -> Dictionary:
	var c := {"won": true, "reason": "WINNER", "rally": 5, "serve_kmh": 0.0,
		"last": _stroke("FLAT"), "labels": ["GOOD", "GOOD"], "line_margin": -1.0, "opp_net_dist": 12.0,
		"second_bounce_z": -1.0, "knocked": false, "comeback": false, "cannon_kmh": 200.0}
	c.merge(over, true)
	return c


func _ids(r: Dictionary) -> Array:
	return r["tricks"].map(func(t): return t["id"])


func test_style_rules() -> void:
	print("style rules")
	var r := StyleRules.evaluate(_ctx())
	check(r["points"] == 0 and r["tricks"].is_empty(), "a plain winner has no tricks")
	r = StyleRules.evaluate(_ctx({"reason": "ACE", "rally": 1, "serve_kmh": 214.0, "last": _stroke("SERVE", "PERFECT"), "labels": ["PERFECT"]}))
	check(_ids(r) == ["ace", "cannon"], "ace at 214 km/h: ace + cannon (%s)" % [_ids(r)])
	check(is_equal_approx(r["mult"], 1.95) and r["points"] == 20, "1.3 x 1.5 = 1.95 -> 20 points (%.2f, %d)" % [r["mult"], r["points"]])
	var perfect3 := ["PERFECT", "PERFECT", "PERFECT"]
	r = StyleRules.evaluate(_ctx({"last": _stroke("TOPSPIN", "PERFECT", 1.35), "labels": perfect3, "rally": 22, "line_margin": 0.04}))
	check(_ids(r) == ["on_line", "marathon", "curl", "perfect"], "line + marathon + curl + perfect (%s)" % [_ids(r)])
	check(r["mult"] > 3.4 and r["mult"] < 5.0, "mult %.2f, no masterpiece yet" % r["mult"])
	r = StyleRules.evaluate(_ctx({"last": _stroke("TOPSPIN", "PERFECT", 1.35, true), "labels": perfect3, "rally": 22, "line_margin": 0.04, "comeback": true}))
	check(_ids(r).has("masterpiece") and r["mult"] >= 10.0, "5x and up doubles: masterpiece (%.2f)" % r["mult"])
	r = StyleRules.evaluate(_ctx({"last": _stroke("DROP SHOT"), "second_bounce_z": 4.0}))
	check(_ids(r) == ["dead_ball"], "drop shot dying before the service line")
	r = StyleRules.evaluate(_ctx({"last": _stroke("DROP SHOT"), "second_bounce_z": 7.0}))
	check(r["points"] == 0, "a drop shot dying past the service line is no dead ball")
	r = StyleRules.evaluate(_ctx({"last": _stroke("LOB"), "opp_net_dist": 3.0}))
	check(_ids(r) == ["lob_over"], "lob over a net player")
	r = StyleRules.evaluate(_ctx({"won": false, "rally": 25}))
	check(r["points"] == 0, "a lost point scores nothing")
	r = StyleRules.evaluate(_ctx({"reason": "OUT", "last": _stroke("SLICE")}))
	check(not _ids(r).has("knife"), "knife needs a clean winner, not an opponent error")
	r = StyleRules.evaluate(_ctx({"last": _stroke("SLICE")}), {"knife": 1.5})
	check(is_equal_approx(r["mult"], 1.8), "an item boost multiplies the trick's x (1.2 x 1.5)")
	r = StyleRules.evaluate(_ctx({"last": _stroke("SLICE")}), {"all": 1.5})
	check(is_equal_approx(r["mult"], 1.8), "'all' scales every trick")
	r = StyleRules.evaluate(_ctx({"reason": "ACE", "rally": 1, "serve_kmh": 195.0, "last": _stroke("SERVE"), "cannon_kmh": 190.0}))
	check(_ids(r).has("cannon"), "a lower cannon threshold (gear) counts 195 km/h")
	var hidden: Array = StyleRules.TRICKS.filter(func(t): return t["hidden"])
	check(hidden.size() >= 4, "a third of the tricks are hidden (%d of %d)" % [hidden.size(), StyleRules.TRICKS.size()])


func _pstroke(type: String, label := "GOOD", kmh := 120.0, skill := "forehand") -> Dictionary:
	return {"type": type, "label": label, "kmh": kmh, "curl_k": 1.0, "diving": false, "smash": false,
		"serve": type == "SERVE", "skill": skill}


func test_style_meter() -> void:
	print("style meter")
	var m := StyleMeter.new()
	m.start_match()
	m.on_stroke(_pstroke("SERVE", "PERFECT", 210.0, "serve"), Vector3(0, 0, -12), 3)
	var r := m.on_point({"winner": 0, "reason": "ACE", "rally": 1, "close_call": {}}, false)
	check(r["points"] == 20 and r["skill"] == "serve" and r["stroke_frame"] == 3, "ace 210 -> 20 points, serve, frame 3")
	m.on_stroke(_pstroke("DROP SHOT", "GOOD", 40.0, "touch"), Vector3(0, 0, -11), 10)
	m.on_bounce({"pos": Vector3(0, 0, -2.0), "bounces": 0, "last_hitter": 0})
	m.on_bounce({"pos": Vector3(0, 0, -4.5), "bounces": 1, "last_hitter": 0})
	r = m.on_point({"winner": 0, "reason": "WINNER", "rally": 4, "close_call": {}}, false)
	check(r["tricks"].size() == 1 and r["tricks"][0]["id"] == "dead_ball", "drop shot: second bounce 4.5 m from the net")
	check(m.match_points == 33 and m.best_index == 0, "match 20 + 13 = 33, best is the ace (%d, %d)" % [m.match_points, m.best_index])
	r = m.on_point({"winner": 1, "reason": "WINNER", "rally": 30, "close_call": {}}, false)
	check(r["points"] == 0 and m.match_points == 33, "a lost point adds nothing")
	check(m.gold(1.0) == 2 and m.gold(1.25) == 2 and m.gold(0.4) == 1, "33 points -> 2 gold (x1.0)")
	m.on_stroke(_pstroke("FLAT"), Vector3(0, 0, -11), 40)
	r = m.on_point({"winner": 0, "reason": "WINNER", "rally": 3, "close_call": {"margin": 0.03, "axis": 0, "rally": 3}}, false)
	check(not r["tricks"].is_empty() and r["tricks"][0]["id"] == "on_line", "VAR 3 cm inside -> on the line")
	m.on_stroke(_pstroke("FLAT"), Vector3(0, 0, -11), 50)
	r = m.on_point({"winner": 0, "reason": "WINNER", "rally": 7, "close_call": {"margin": 0.03, "axis": 0, "rally": 3}}, false)
	check(r["points"] == 0, "an old call from earlier in the rally does not count")
	m.on_stroke(_pstroke("FLAT"), Vector3(0, 0, -11), 60)
	r = m.on_point({"winner": 0, "reason": "WINNER", "rally": 4, "close_call": {}}, true)
	check(r["tricks"].size() == 1 and r["tricks"][0]["id"] == "comeback", "won at 0:40 -> comeback")
	m.on_stroke(_pstroke("SLICE"), Vector3(0, 0, -11), 70)
	r = m.on_point({"winner": 0, "reason": "WINNER", "rally": 4, "close_call": {}}, false, {"knife": 2.0})
	check(is_equal_approx(r["mult"], 2.4), "gear boosts reach the rules (knife x2 -> 2.4)")
	m.start_match()
	check(m.match_points == 0 and m.best.is_empty() and m.best_index == -1, "a new match starts clean")
