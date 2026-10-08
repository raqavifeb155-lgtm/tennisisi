extends SceneTree
## Stream G (v0.2): modifiers on everything — the catalog, aura rolls, rewards, the run's
## conditions, and every modifier applied and put back in the live scene.
##   godot --headless --path . -s tests/mods_test.gd

var failures := 0
var main: Node
var RM: GDScript

const PRIMS := ["stat", "stamina_start", "no_ring", "ring_late", "mirror", "tuning", "tuning_x", "gravity",
	"wind", "rubber_net", "surface", "narrow", "ball_scale", "fog", "night", "shot_pace", "serve_pace", "echo",
	"opp", "opp_stamina", "reaction", "cpu_scale", "drain_on_loss", "heal_on_win", "aura_rate", "twins"]


func _initialize() -> void:
	SaveData.enabled = false
	test_catalog()
	test_auras()
	test_rewards()
	test_run()
	test_card()
	_live.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _tun() -> Node:
	return root.get_node("Tuning")


func _done() -> void:
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


# --- Pure logic ---------------------------------------------------------------------

func test_catalog() -> void:
	print("catalog")
	check(Modifiers.LIST.size() >= 30, "%d modifiers (>= 30)" % Modifiers.LIST.size())
	var seen := {}
	var ok_fields := true
	var ok_prims := true
	var ok_reward := true
	for e in Modifiers.LIST:
		for k in ["id", "name", "desc", "rarity", "target", "pools", "fx", "color", "icon", "reward"]:
			if not e.has(k):
				ok_fields = false
				print("    missing %s in %s" % [k, e.get("id", "?")])
		seen[e["id"]] = seen.get(e["id"], 0) + 1
		if not ["run", "opponent", "court", "item"].has(e["target"]):
			check(false, "%s: target %s" % [e["id"], e["target"]])
		for f in e["fx"]:
			if not PRIMS.has(f[0]):
				ok_prims = false
				print("    unknown primitive %s in %s" % [f[0], e["id"]])
		var hard: bool = not e.get("legacy", false) and e["target"] != "item"
		if hard and float(e["reward"]) <= 1.0:
			ok_reward = false
			print("    %s pays nothing" % e["id"])
	check(ok_fields, "every entry has id, name, desc, rarity, target, pools, fx, color, icon, reward")
	check(seen.values().max() == 1, "ids are unique")
	check(ok_prims, "every effect is a known primitive")
	check(ok_reward, "every uncomfortable modifier pays more (reward > 1)")
	var crazy := 0
	for id in ["no_ring", "half_tank", "fog", "giant_ball", "moon", "mirror", "night", "wind", "fast_ball",
			"rubber_net", "narrow", "late_flash", "echo", "marathoner", "crystal", "bomber", "ice", "twins"]:
		crazy += 0 if Modifiers.find(id).is_empty() else 1
	check(crazy == 18, "all 18 named in the spec are in the catalog (%d)" % crazy)
	check(Modifiers.pool("aura").size() >= 15 and Modifiers.pool("run").size() >= 15, "aura pool %d, run pool %d" % [Modifiers.pool("aura").size(), Modifiers.pool("run").size()])
	check(Modifiers.item_templates().size() >= 3, "item affix templates for stream A: %d" % Modifiers.item_templates().size())


func test_auras() -> void:
	print("auras")
	SaveData.played = 5
	var opp := 0
	var with := 0
	var boss_max := 0
	var first := 0
	var aura_ids := {}
	for k in 600:
		var t := Tournament.new(1, k + 1)
		for i in t.rounds():
			var a: Array = t.lineup[i]["mods"].filter(func(id): return not Modifiers.find(id).get("legacy", false))
			if i == 0:
				first += a.size()
				continue
			opp += 1
			with += 1 if not a.is_empty() else 0
			if Opponents.ROSTER[i].get("boss", false):
				boss_max = maxi(boss_max, a.size())
			for id in a:
				aura_ids[id] = true
				if not (Modifiers.find(id)["pools"].has("aura") or Modifiers.find(id)["pools"].has("boss")):
					check(false, "%s may be an aura" % id)
	var share := float(with) / opp
	check(first == 0, "the first (tutorial) opponent never has an aura")
	check(share > 0.03 and share <= 0.10, "auras are rare: %.1f%% of opponents (<= 10%%)" % (share * 100.0))
	check(boss_max == 2, "a boss comes with up to two auras (%d)" % boss_max)
	check(aura_ids.size() >= 10, "%d different auras show up" % aura_ids.size())
	SaveData.played = 0
	var second := 0
	for k in 300:
		var t := Tournament.new(1, k + 1)
		second += t.lineup[1]["mods"].filter(func(id): return not Modifiers.find(id).get("legacy", false)).size()
	check(second == 0, "a new player meets no aura in his first two matches")
	SaveData.played = 5
	var t1 := Tournament.new(1, 77)
	var t2 := Tournament.new(1, 77)
	check(t1.lineup == t2.lineup, "the same seed rolls the same auras")
	# Hidden ones are named "???".
	var hid := 0
	var hid_ok := true
	for k in 400:
		var t := Tournament.new(1, k + 1)
		for lu in t.lineup:
			for id in lu.get("hidden", []):
				hid += 1
				hid_ok = hid_ok and lu["mods"].has(id) and int(Modifiers.find(id)["rarity"]) >= Modifiers.EPIC
	check(hid > 0 and hid_ok, "some epic/mythic auras are «???» until the first point (%d)" % hid)


func test_rewards() -> void:
	print("rewards")
	var t := Tournament.new(1, 5)
	t.lineup[2]["mods"] = []
	var plain := t.gold_for_win(2)
	t.lineup[2]["mods"] = ["fog"]
	check(t.gold_for_win(2) == roundi(plain * Modifiers.find("fog")["reward"]) or absi(t.gold_for_win(2) - roundi(plain * Modifiers.find("fog")["reward"])) <= 1, "an aura pays more: %d -> %d" % [plain, t.gold_for_win(2)])
	t.lineup[2]["mods"] = ["showman", "fog", "crystal"]
	check(Modifiers.gold_mult(t, 2) <= Modifiers.MAX_REWARD + 0.001, "the multiplier stops at x%s" % Modifiers.MAX_REWARD)
	check(Modifiers.loot_bonus("fog") > 0.0 and is_equal_approx(Modifiers.loot_bonus("fast"), 0.08), "auras move his loot up; the old ones keep theirs")
	t.lineup[t.stage]["mods"] = ["wall"]
	check(is_equal_approx(t.modifier_value("skill") - Tournament.new(1, 5).modifier_value("skill"), 0.14) or t.modifier_value("skill") > 0.13,
		"«Стена» makes him steadier through modifier_value (%.2f)" % t.modifier_value("skill"))
	t.lineup[t.stage]["mods"] = ["giant"]
	check(is_equal_approx(t.modifier_value("serve"), 1.12) and is_equal_approx(t.modifier_value("speed"), 0.92), "«Гигант»: serve x1.12, speed x0.92")
	t.lineup[t.stage]["mods"] = ["fast", "fog"]
	check(is_equal_approx(t.modifier_value("speed"), 1.12), "old and new modifiers live together in lineup mods")


func test_run() -> void:
	print("run conditions")
	var t := Tournament.new(1, 9)
	var bonus := t.drop_bonus
	Modifiers.set_run(t, ["no_ring", "half_tank", "fog", "mirror", "crystal"])
	check(t.run_modifiers == ["no_ring", "half_tank", "fog"], "three at most, only from the run pool: %s" % [t.run_modifiers])
	check(is_equal_approx(t.drop_bonus, bonus + 0.06), "each adds to the loot chances")
	t.lineup[1]["mods"] = []
	var x := Modifiers.reward(t.run_modifiers)
	check(absf(Modifiers.gold_mult(t, 1) - x) < 0.001 and x > 2.0, "the run pays x%.2f for every match" % x)
	var d := t.to_dict()
	var back := Tournament.from_dict(d)
	check(back.run_modifiers == t.run_modifiers, "the conditions are saved with the run")
	var pro: Dictionary = Modifiers.PRESETS[0]
	check(absf(Modifiers.reward(pro["mods"]) - 1.5) < 0.001, "the «Про» preset pays x1.5 (%.2f)" % Modifiers.reward(pro["mods"]))
	var p := Tournament.new(1, 9)
	Modifiers.set_run(p, pro["mods"])
	p.lineup[p.stage]["mods"] = []
	check(p.modifier_value("skill") >= 0.099, "«Про»: opponents one tier stronger (+%.2f skill)" % p.modifier_value("skill"))
	SaveData.played = 5
	var a0 := 0
	var a1 := 0
	for k in 200:
		var e := Tournament.new(1, k + 1)
		for i in range(1, 5):
			a0 += e.lineup[i]["mods"].filter(func(id): return not Modifiers.find(id).get("legacy", false)).size()
		Modifiers.set_run(e, ["elite"])
		for i in range(1, 5):
			a1 += e.lineup[i]["mods"].filter(func(id): return not Modifiers.find(id).get("legacy", false)).size()
	check(a1 > a0 * 2, "«Элитные чаще»: auras %d -> %d" % [a0, a1])


func test_card() -> void:
	print("card data")
	var lu := {"mods": ["fast", "fog", "moon"], "hidden": ["moon"]}
	var c := Modifiers.card(lu)
	check(c.size() == 3 and c[2]["name"] == "???" and c[1]["name"] == "Туман", "the card: names, «???» for the hidden one")
	check(Modifiers.bracket_text(lu).contains("???") and Modifiers.bracket_text(lu).contains("×"), "bracket line: %s" % Modifiers.bracket_text(lu))
	check(Modifiers.match_set(null) == [], "no tournament, nothing forced: no modifiers")
	check(Modifiers.name("fog") == "Туман" and Modifiers.desc("fast") == "Бегает на 12% быстрее" and Modifiers.name("nope") == "nope" and Modifiers.desc("nope") == "",
		"Modifiers.name / desc: new, old and unknown ids (for the opponent card)")


# --- The live scene -----------------------------------------------------------------

func _snap() -> Dictionary:
	var h: ModsHub = main.mods_hub
	var env: Environment = h.environment()
	var mat := (main.ball._mesh as MeshInstance3D).material_override as StandardMaterial3D
	var s := {
		"tuning": [_tun().perfect_window, _tun().good_window, _tun().slowmo_enabled, _tun().slowmo_scale, _tun().show_aim,
			_tun().show_landing, _tun().hawkeye_range, snappedf(_tun().ai_skill, 0.0001)],
		"physics": [BallPhysics.gravity_scale, BallPhysics.wind, BallPhysics.rubber_net, BallPhysics.friction, BallPhysics.pace, BallPhysics.bounce_offset],
		"court": [Court.inset, main.court._court_mat.albedo_color, main.court.get_child_count()],
		"skills": Skills.mods_layer.duplicate(),
		"ball": [main.ball._mesh.scale, main.ball._shadow.scale, main.ball._mesh.transparency, mat.emission, mat.emission_energy_multiplier],
		"env": [env.fog_density, env.tonemap_exposure, env.ambient_light_energy] if env else [],
		"cpu": [main.cpu.scale, main.ai.speed_mult, main._cpu_serve_mult],
		"hub": [h.start_stamina, h.no_ring, h.ring_late, h.mirror, h.pace.duplicate(), h.serve_pace.duplicate(), h.echo_every,
			h.reaction_add, h.drain_on_loss, h.heal_on_win, h.fog, h.night],
		"opp": main.run_hub.match_fx.opp if main.run_hub.match_fx else null,
	}
	return s


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k in a:
		if str(a[k]) != str(b[k]) or (k == "opp" and a[k] != b[k]):
			out.append(k)
	return out


func _live() -> void:
	print("live: apply and undo every modifier")
	root.size = Vector2i(720, 1564)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	# A tournament match, so the opponent's stamina (MatchEffects) is there too.
	var t := Tournament.new(1, 3)
	t.lineup[t.stage]["mods"] = []
	main.tournament = t
	main.tournament_mode = true
	main._play_match()
	for i in 5:
		await physics_frame
	var h: ModsHub = main.mods_hub
	check(h.active.is_empty() and main.run_hub.match_fx != null, "a tournament match with no modifiers: nothing applied")
	var base := _snap()
	var no_live := ["fast", "steady", "bomber", "elite", "tier_up"]   # applied outside the match (roll, modifier_value)
	for e in Modifiers.LIST:
		var id: String = e["id"]
		h.apply([id])
		var on := _snap()
		var changed := _diff(base, on)
		if not no_live.has(id) and id != "twins":
			check(not changed.is_empty(), "%s changes something: %s" % [id, changed])
		h.revert()
		var back := _diff(base, _snap())
		check(back.is_empty(), "%s is put back cleanly%s" % [id, "" if back.is_empty() else " — left: %s" % [back]])
	# Everything at once (the run's three + the boss's two), then back.
	h.apply(["fog", "night", "moon", "narrow", "ice", "crystal", "echo", "half_tank"])
	h.revert()
	check(_diff(base, _snap()).is_empty(), "eight at once, put back cleanly")
	# A match with an aura: applied at the start, glow on, TV strip, undone at the end.
	main._stop_match()
	await physics_frame
	t.lineup[t.stage]["mods"] = ["wall", "fog"]
	t.lineup[t.stage]["hidden"] = ["fog"]
	main._play_match()
	await process_frame
	await process_frame
	check(h.active == ["wall", "fog"] and h.fog, "the opponent's auras apply when the match starts")
	check(h._halo.visible and h._column.visible, "his aura glows on court")
	var seen_aura := false
	for k in 3:
		var cur: Dictionary = main.hud.announcer.current()
		if String(cur.get("main", "")) == "АУРА":
			seen_aura = true
		main.hud.announcer.skip()
	check(seen_aura, "the TV strip names the aura at the start")
	check(is_equal_approx(_tun().ai_skill, clampf(float(t.opponent()["skill"]) + t.modifier_value("skill"), 0.0, 1.0)) or _tun().ai_skill > float(t.opponent()["skill"]),
		"«Стена» made him steadier (ai_skill %.2f)" % _tun().ai_skill)
	root.get_node("GameEvents").point.emit({"winner": 0, "reason": "WINNER", "rally": 3, "server": 0})
	check(t.current_lineup()["hidden"].is_empty(), "the «???» aura is named on the first point")
	# Left for the menu mid-match: undone on the next tick.
	main._show_menu()
	await physics_frame
	await physics_frame
	check(h.active.is_empty() and not h.fog and not h._halo.visible, "leaving the match for the menu puts everything back")
	check(_diff(base, _snap()).filter(func(k): return k != "opp" and k != "cpu" and k != "tuning").is_empty(), "...the court, the ball and the physics too")
	await _run_screen()
	_done()


## The «Условия забега» screen: picks, the preset, the cap, the start with them.
func _run_screen() -> void:
	print("run conditions screen")
	RM = load("res://scripts/ui/screens/run_mods.gd")  # loaded, not named: it reaches the autoloads
	if main.club.active:
		main.club.close()
	main._stop_match()
	main.tournament = null
	main.tournament_mode = false
	SaveData.played = 0
	RM.open(main, 1)
	check(main.tournament != null and main.tournament.run_modifiers.is_empty(), "a new player: straight to the run, no screen")
	main.tournament = null
	SaveData.played = 2
	RM.open(main, 1)
	await process_frame
	check(main.tournament == null and main.ui.is_open() and RM.picked.is_empty(), "a returning player gets the screen")
	var rows := 0
	for c in main.ui._box.get_children():
		if c is Button:
			rows += 1
	check(rows == RM.choices().size() + 1, "a row per condition and the preset (%d)" % rows)
	RM.ui_action(main, "mods_preset", 0)
	check(RM.picked == ["short_ring", "tier_up"] and absf(RM.total() - 1.5) < 0.001, "«Про» takes two and pays x1.5")
	RM.ui_action(main, "mods_toggle", RM.choices().find_custom(func(e): return e["id"] == "tier_up"))
	check(RM.picked == ["short_ring"] and not RM.preset_on(), "one condition of the preset comes off alone")
	RM.ui_action(main, "mods_preset", 0)
	RM.ui_action(main, "mods_toggle", 0)
	RM.ui_action(main, "mods_toggle", 1)
	check(RM.picked.size() == 3, "three at most (%s)" % [RM.picked])
	RM.ui_action(main, "mods_preset", 0)
	check(RM.picked.size() == 1 and RM.picked[0] == "no_ring" or RM.picked.size() == 2, "the preset off leaves the others")
	RM.picked = ["short_ring", "tier_up", "night"]
	RM.ui_action(main, "mods_go", 0)
	var t: Tournament = main.tournament
	check(t != null and t.run_modifiers == ["short_ring", "tier_up", "night"] and t.format == 1, "the run starts with the three")
	check(t.modifier_value("skill") >= 0.099 and absf(Modifiers.gold_mult(t, 3) - Modifiers.reward(t.run_modifiers) * Modifiers.reward(t.lineup[3]["mods"])) < 0.001,
		"opponents a tier up and the prize multiplied")
	RM.ui_action(main, "mods_back", 0)
	SaveData.played = 0
