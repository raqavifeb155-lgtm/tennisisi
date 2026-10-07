extends SceneTree
## Stream A (v0.2) logic: style points, gear, opponent stamina, bets, golden opponents.
##   godot --headless --path . -s tests/roguelike_test.gd

var failures := 0


func _init() -> void:
	SaveData.enabled = false
	test_style_rules()
	test_style_meter()
	test_style_save()
	test_style_plate()
	test_point_recorder()
	test_share_caption()
	test_items_catalog()
	test_gear_slots()
	test_run_effects()
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
	check(m.gold(1.0, 0) == 3 and m.gold(1.25, 0) == 4 and m.gold(0.4, 0) == 1, "33 points -> 3 gold (x1.0), 4 (x1.25), 1 (x0.4)")
	check(m.gold(1.0, 2) == 5, "later rounds pay more, like experience (+25% a round)")
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


func test_style_save() -> void:
	print("style records")
	SaveData.style = {}
	SaveData.note_style({"mult": 2.5, "points": 25})
	SaveData.note_style({"mult": 1.3, "points": 13})
	check(is_equal_approx(float(SaveData.style["best_mult"]), 2.5) and int(SaveData.style["best_points"]) == 25, "the best point is kept")
	check(int(SaveData.style["total"]) == 38, "every style point adds to the total")
	var cf := SaveData._to_config()
	SaveData.style = {}
	SaveData._apply(cf)
	check(int(SaveData.style.get("total", 0)) == 38, "style records survive save and load")


func test_style_plate() -> void:
	print("style plate")
	var plate := StylePlate.new()
	root.add_child(plate)
	check(not plate.visible, "hidden until a point is scored")
	plate.show_result({"tricks": [{"name": "Эйс", "x": 1.3}, {"name": "Пушка", "x": 1.5}], "mult": 2.34, "points": 23})
	check(plate.visible and plate.trick_count() == 2, "shows every trick")
	plate.finish_now()
	check(plate.mult_text() == "×2.3" and plate.points_text() == "+23", "ends on the full multiplier and the points (%s %s)" % [plate.mult_text(), plate.points_text()])
	plate.show_result({"tricks": [{"name": "Слайс-нож", "x": 1.2}], "mult": 1.2, "points": 12})
	check(plate.trick_count() == 1, "a new point replaces the old plate")
	plate.queue_free()


func test_point_recorder() -> void:
	print("point recorder")
	var a := Node3D.new()
	var b := Node3D.new()
	a.add_child(b)
	root.add_child(a)
	var rec := PointRecorder.new([a] as Array[Node3D])
	rec.begin()
	for i in 3:
		a.position = Vector3(i, 0, 0)
		b.position = Vector3(0, i * 2, 0)
		rec.capture(Vector3(0, 1, -i), i != 1)
	check(rec.frame == 3, "three frames recorded (%d)" % rec.frame)
	var frames := rec.end_point()
	rec.keep_best(frames)
	rec.begin()
	a.position = Vector3(9, 9, 9)
	rec.capture(Vector3.ZERO, true)
	check(PointRecorder.length(rec.best_frames) == 3, "the best point is a copy, the next rally doesn't touch it")
	var ball := Node3D.new()
	root.add_child(ball)
	rec.apply(rec.best_frames, 1, ball)
	check(a.position == Vector3(1, 0, 0) and b.position == Vector3(0, 2, 0), "frame 1 puts both nodes back")
	check(ball.position == Vector3(0, 1, -1) and not ball.visible, "the ball goes where it was, hidden when it was")
	var snap := rec.snapshot()
	a.position = Vector3(5, 5, 5)
	rec.restore(snap)
	check(a.position == Vector3(1, 0, 0), "a snapshot restores the live pose after a replay")
	a.queue_free()
	ball.queue_free()


func test_share_caption() -> void:
	print("share")
	var best := {"mult": 5.2, "tricks": [{"name": "Эйс"}, {"name": "Пушка"}]}
	check(RunShare.caption(best) == "СТИЛЬ ×5.2 · Эйс · Пушка — TENNISISI", "caption: %s" % RunShare.caption(best))
	var url := RunShare.tg_share_path(best)
	check(url.begins_with("/share/url?url=https%3A%2F%2Ft.me%2FTennisisiBot%3Fstartapp%3Dstyle&text="), "a t.me share link with the game link: %s" % url)
	check(not url.contains(" "), "the text is URL-encoded")


# --- A-2: gear --------------------------------------------------------------------

func test_items_catalog() -> void:
	print("items catalog")
	check(Items.LIST.size() == 25, "25 items (%d)" % Items.LIST.size())
	var ids := {}
	for e in Items.LIST:
		ids[e["id"]] = true
	check(ids.size() == Items.LIST.size(), "ids are unique")
	for slot in Gear.SLOTS:
		for r in range(Gear.RARE, Gear.MYTHIC + 1):
			check(not Items.pool(slot, r).is_empty(), "%s has a %s item" % [slot, UiTheme.RARITY_NAMES[r]])
	var plain_epics := 0
	for e in Items.LIST:
		if int(e["rarity"]) >= Gear.EPIC and not (e.has("triggers") or e.has("style") or e.has("rules") or e.has("cond_mods")):
			plain_epics += 1
	check(plain_epics == 0, "every epic and up does something, not only stats")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var sun := Items.instance(Items.find("sun"))
	check(sun["slot"] == "racket" and sun["rarity"] == Gear.MYTHIC and sun["id"] == "sun", "an instance keeps id, slot, rarity")
	check(Items.describe(sun).contains("PERFECT"), "describe: %s" % Items.describe(sun))
	var heavy := Items.instance(Items.find("heavy_frame"))
	check(is_equal_approx(float(heavy["mods"]["forehand_pace"]), 0.1), "mods come with the instance")
	var terry := Items.instance(Items.find("terry_band"))
	check(terry["mods"].has("serve_window") and terry["mods"].has("touch_window"), "'all windows' expands to every stroke")
	var e := Items.roll("shoes", Gear.LEGENDARY, rng)
	check(e["slot"] == "shoes" and e["rarity"] == Gear.LEGENDARY, "roll by slot and rarity")


func test_gear_slots() -> void:
	print("gear slots")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	check(Gear.RARITIES.size() == 5 and Gear.MYTHIC == 4, "five rarities, mythic is the fifth")
	check(Gear.color({"rarity": 3}) == UiTheme.RARITY[3], "rarity colors come from UiTheme (legendary orange)")
	for slot in Gear.SLOTS:
		for r in 5:
			var it := Gear.roll(r, rng, slot)
			var ok: bool = it["slot"] == slot and int(it["rarity"]) == r
			if r >= Gear.EPIC:
				ok = ok and it.has("id")
			elif not it.has("id"):
				for k in it["mods"]:
					ok = ok and Gear.AFFIX_KEYS[slot].has(k)
			check(ok, "%s %d: %s" % [slot, r, it["name"]])
	check(Gear.roll(Gear.EPIC, rng)["slot"] == "racket", "the old call still rolls a racket")
	var prices := []
	for r in 5:
		prices.append(Gear.price({"rarity": r}))
	check(prices == [3, 6, 12, 25, 50], "sell prices %s" % [prices])
	var gen := Gear.roll(Gear.COMMON, rng, "shoes")
	while gen.has("id"):
		gen = Gear.roll(Gear.COMMON, rng, "shoes")
	check(gen["name"].begins_with("Обычные кроссовки"), "names agree with the slot: %s" % gen["name"])


func _wear(ids: Array) -> Dictionary:
	var eq := {}
	for id in ids:
		var it := Items.instance(Items.find(id))
		eq[it["slot"]] = it
	return eq


func _hit(fx: RunEffects, n: int, label := "GOOD", type := "FLAT") -> Array:
	var out := fx.fire("on_hit", {"type": type, "label": label, "rally_n": n})
	if label == "PERFECT":
		out += fx.fire("on_perfect", {"type": type, "label": label, "rally_n": n})
	return out


func test_run_effects() -> void:
	print("run effects")
	var fx := RunEffects.new(_wear(["sledgehammer"]))
	var dmg := []
	for n in range(1, 9):
		dmg.append(_hit(fx, n))
	check(dmg[3] == [["opp_stamina", 8.0]] and dmg[7] == [["opp_stamina", 8.0]] and dmg[2].is_empty() and dmg[4].is_empty(), "sledgehammer: every 4th stroke (%s)" % [dmg])
	fx = RunEffects.new(_wear(["sun"]))
	var a := _hit(fx, 1, "PERFECT")
	var b := _hit(fx, 2, "PERFECT")
	var c := _hit(fx, 3, "PERFECT")
	check(a == [["opp_stamina", 6.0]] and b == [["opp_stamina", 6.0]], "sun: every PERFECT burns 6")
	check(c.has(["opp_stamina", 30.0]) and is_equal_approx(fx.point_style(), 2.0), "the third PERFECT in a row: meteor, style x2")
	_hit(fx, 4, "GOOD")
	var d := _hit(fx, 5, "PERFECT") + _hit(fx, 6, "PERFECT")
	check(not d.has(["opp_stamina", 30.0]), "a GOOD breaks the streak")
	fx.end_point()
	check(is_equal_approx(fx.point_style(), 1.0), "the point's style bonus ends with the point")
	fx = RunEffects.new(_wear(["cold_pack"]))
	check(not fx.mods({"tiebreak": false}).has("serve_window") and is_equal_approx(float(fx.mods({"tiebreak": true})["serve_window"]), 0.25), "cold pack only in a tiebreak")
	fx = RunEffects.new(_wear(["berserk", "heavy_frame"]))
	var base := float(fx.mods()["forehand_pace"])
	_hit(fx, 1)
	_hit(fx, 2)
	check(is_equal_approx(float(fx.mods()["forehand_pace"]), base + 0.06), "berserk: +3%% a stroke (%.2f)" % float(fx.mods()["forehand_pace"]))
	fx.end_point()
	check(is_equal_approx(float(fx.mods()["forehand_pace"]), base), "berserk resets on the point")
	var run_mods := {}
	fx = RunEffects.new(_wear(["crown"]), run_mods)
	fx.fire("on_break", {})
	fx.fire("on_break", {})
	check(is_equal_approx(float(run_mods.get("forehand_pace", 0.0)), 0.04) and is_equal_approx(float(fx.mods()["run_speed"]), 0.04), "crown: +2% a break for the rest of the run")
	fx = RunEffects.new(_wear(["golden_hand", "knife_string"]))
	var bo := fx.style_boosts()
	check(is_equal_approx(float(bo["all"]), 1.5) and is_equal_approx(float(bo["knife"]), 1.5), "style boosts from the gear %s" % [bo])
	fx = RunEffects.new(_wear(["cannon_frame"]))
	check(is_equal_approx(fx.rule("cannon_kmh"), 190.0) and fx.rule("dive_free") == 0.0, "rules")
	fx = RunEffects.new(_wear(["cutter", "lucky_coin"]))
	var won := fx.fire("on_point_won", {"type": "SLICE", "reason": "WINNER", "tricks": [{"id": "knife"}]})
	check(won.has(["opp_stamina", 25.0]) and won.has(["money", 1]), "cutter and lucky coin on a slice winner (%s)" % [won])
	won = fx.fire("on_point_won", {"type": "FLAT", "reason": "OUT", "tricks": []})
	check(won.is_empty(), "nothing on an opponent error without tricks")
	check(RunEffects.new({}).fire("on_ace", {}).is_empty() and RunEffects.new({}).mods().is_empty(), "no gear, no effects")
