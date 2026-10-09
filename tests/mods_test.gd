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
	test_hardcore()
	test_traits()
	test_rotation()
	test_freq()
	test_card_traits()
	test_human_names()
	_live.call_deferred()


## Owner, 10.10: «иногда пишется на английском кодовое слово». Every id of every catalog has a
## Russian name and description from Modifiers.human_name / human_desc, and an id nobody knows
## still never shows itself.
func test_human_names() -> void:
	print("human names")
	var rx := RegEx.new()
	rx.compile("[a-z]+_[a-z_]+")  # a code word: serve_cannon, net_rusher
	var cyr := RegEx.new()
	cyr.compile("[А-Яа-яЁё]")
	var all_ids: Array = []
	for id in Modifiers.ids():
		all_ids.append(String(id))  # auras, run conditions, old modifiers, item affixes
	for id in Tournament.MODIFIERS.keys():
		all_ids.append(String(id))
	for id in Traits.ids():
		all_ids.append(String(id))  # the opponents' traits
	for id in Traits.student_ids():
		all_ids.append(String(id))  # the students' traits
	var bad := PackedStringArray()
	var seen := {}
	for id in all_ids:
		if seen.has(id):
			continue
		seen[id] = true
		var n := Modifiers.human_name(id)
		var d := Modifiers.human_desc(id)
		if n == "" or d == "" or rx.search(n) != null or rx.search(d) != null or cyr.search(n) == null or cyr.search(d) == null:
			bad.append("%s -> «%s» / «%s»" % [id, n, d])
		if Modifiers.name(id) != n or Modifiers.label(id) != n or OpponentCard.mod_name(id) != n:
			bad.append("%s: the entry points disagree" % id)
		var line := OpponentCard.mod_text(id)
		if rx.search(line) != null or cyr.search(line) == null:
			bad.append("%s: card line «%s»" % [id, line])
	check(bad.is_empty(), "%d ids of the catalogs all have a Russian name and description %s" % [seen.size(), str(bad)])
	for id in ["no_such_mod", "net_rusher_x", "", "ZZ"]:
		var lines := [Modifiers.human_name(id), Modifiers.human_desc(id), Modifiers.label(id), OpponentCard.mod_text(id), OpponentCard.mod_name(id), Traits.name(id), Traits.text(id)]
		check(lines.all(func(l: String) -> bool: return l != id or id == ""), "an unknown id «%s» never shows itself" % id)
		check(lines.all(func(l: String) -> bool: return rx.search(l) == null), "an unknown id «%s»: no code word in %s" % [id, str(lines)])
	check(Modifiers.is_code_word("net_rusher") and not Modifiers.is_code_word("Атакует сетку") and not Modifiers.is_code_word("PERFECT"), "code word detector")
	# Traits and auras of a whole tournament lineup, as the bracket and the card print them.
	var n_lines := 0
	for k in 12:
		var t := Tournament.new(1, 100 + k)
		for lu in t.lineup:
			for id in lu.get("mods", []):
				n_lines += 1
				if rx.search(OpponentCard.mod_text(String(id), lu)) != null:
					bad.append("lineup mod " + String(id))
			if rx.search(Modifiers.bracket_text(lu)) != null:
				bad.append("bracket " + Modifiers.bracket_text(lu))
	check(bad.is_empty(), "no code word in the lineups' card lines and bracket lines %s" % str(bad))
	# The things: the unique items' names and descriptions, and the affix lines of the generated ones.
	var item_bad := PackedStringArray()
	for e in Items.LIST:
		if rx.search(String(e["name"])) != null or rx.search(String(e.get("desc", ""))) != null:
			item_bad.append(String(e["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for slot in ["racket", "shoes", "band"]:
		for r in 5:
			var it := Gear.roll(r, rng, slot)
			if rx.search(String(it["name"]) + Items.describe(it)) != null:
				item_bad.append("%s/%d" % [slot, r])
	check(item_bad.is_empty(), "no code word in item names, descriptions and affix lines %s" % str(item_bad))
	check(n_lines > 0, "the lineup carried mods to check (%d)" % n_lines)


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
			var a: Array = t.lineup[i]["mods"].filter(func(id): return Modifiers.is_aura(id))
			if i == 0:
				first += a.size()
				continue
			opp += 1
			with += 1 if not a.is_empty() else 0
			if t.opp(i).get("boss", false):
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
		second += t.lineup[1]["mods"].filter(func(id): return Modifiers.is_aura(id)).size()
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
			a0 += e.lineup[i]["mods"].filter(func(id): return Modifiers.is_aura(id)).size()
		Modifiers.set_run(e, ["elite"])
		for i in range(1, 5):
			a1 += e.lineup[i]["mods"].filter(func(id): return Modifiers.is_aura(id)).size()
	check(a1 > a0 * 2, "«Элитные чаще»: auras %d -> %d" % [a0, a1])


func test_hardcore() -> void:
	print("hardcore")
	var h := Tournament.new(1, 5, true)
	Modifiers.set_run(h, ["tier_up", "fog", "short_ring", "echo"])
	check(h.hardcore and h.run_modifiers == ["hardcore", "fog", "echo"], "hardcore first, what it holds is not added again: %s" % [h.run_modifiers])
	check(absf(Modifiers.reward(["hardcore"]) - 2.5) < 0.001, "hardcore pays x2.5")
	check(absf(Modifiers.reward(h.run_modifiers) - 3.78) < 0.001 or Modifiers.reward(h.run_modifiers) <= Modifiers.MAX_HARD, "with conditions the cap is x4 (%.2f)" % Modifiers.reward(h.run_modifiers))
	check(Modifiers.reward(["hardcore", "no_ring", "mirror", "fog"]) == Modifiers.MAX_HARD, "x4 at most")
	check(Modifiers.reward(["no_ring", "mirror", "fog"]) == Modifiers.MAX_REWARD, "without hardcore x3 at most")
	h.lineup[h.stage]["mods"] = []
	check(absf(Modifiers.gold_mult(h, h.stage) - Modifiers.reward(h.run_modifiers)) < 0.001, "a win pays x%.2f" % Modifiers.gold_mult(h, h.stage))
	check(Modifiers.style_mult(h) == 1.5 and Modifiers.style_mult(Tournament.new(1, 5)) == 1.0, "style gold x1.5 only in hardcore")
	check(h.modifier_value("skill") >= 0.099, "opponents a tier up (+%.2f)" % h.modifier_value("skill"))
	var back := Tournament.from_dict(h.to_dict())
	check(back.hardcore and back.run_modifiers == h.run_modifiers, "hardcore is saved with the run (%s %s)" % [back.hardcore, back.run_modifiers])
	var a := 0
	var b := 0
	for k in 300:
		var p := Tournament.new(1, k + 1, false)
		var q := Tournament.new(1, k + 1, true)
		for i in range(1, 5):
			for slot in Gear.SLOTS:
				a += 1 if int(p.lineup[i]["gear"][slot]["rarity"]) >= Gear.LEGENDARY else 0
				b += 1 if int(q.lineup[i]["gear"][slot]["rarity"]) >= Gear.LEGENDARY else 0
	check(b > a, "more legendary gear on hardcore opponents (%d -> %d of %d)" % [a, b, 300 * 4 * Gear.SLOTS.size()])


func test_traits() -> void:
	print("traits")
	SaveData.played = 5
	check(Traits.all().size() >= 15 and Traits.all().all(func(e): return e["trait"] and e.has("growth") and e.has("hidden") and e["reward"] >= 1.05 and e["reward"] <= 1.15),
		"%d traits, each with growth / hidden, a prize x1.05..1.15" % Traits.all().size())
	check(Traits.name("hole_left") == "Дыра слева" and Modifiers.name("serve_cannon") == "Пушка подачи" and Modifiers.desc("serve_cannon") != "" and Traits.entry("nope").is_empty(), "name / desc through Traits and Modifiers")
	var no_trait := 0
	var boss_ok := true
	var second := [0, 0, 0, 0, 0]
	var fit := true
	var same := true
	var gain := 0.0
	var base := 0.0
	var runs := 300
	for k in runs:
		var t := Tournament.new(1, k + 1)
		var u := Tournament.new(1, k + 1)
		same = same and t.lineup.map(func(l): return l["mods"]) == u.lineup.map(func(l): return l["mods"])
		for i in t.lineup.size():
			var o: Dictionary = t.opp(i)  # D-8: the drawn opponent, not the fixed roster
			var tr: Array = t.lineup[i]["mods"].filter(func(id): return Traits.has(id))
			if tr.is_empty():
				no_trait += 1
			if o.get("boss", false):
				boss_ok = boss_ok and tr.has("king_court")
			elif tr.has("king_court"):
				boss_ok = false
			if tr.size() > 1 or (o.get("boss", false) and tr.size() > 1):
				second[i] += 1
			var st := Opponents.stats(o)
			for id in tr:
				var e := Traits.find(id)
				fit = fit and Traits.fits(e, st) and (not e.has("style") or e["style"] == String(o.get("play_style", "")))
			if i > 0:
				gain += Modifiers.reward(t.lineup[i]["mods"])
				base += Modifiers.reward(t.lineup[i]["mods"].filter(func(id): return not Traits.has(id)))
	check(no_trait == 0, "every opponent of %d runs has at least one trait" % runs)
	check(boss_ok, "the boss always has his own (Король Корта), nobody else does")
	check(same, "the same seed gives the same traits")
	check(fit, "traits fit his stats and play style")
	check(second[0] == 0 and second[1] > 0 and second[3] > second[1] - 40, "a second trait from round 2 on: %s" % [second])
	var ratio := gain / base
	print("       average prize x with traits / without: %.3f" % ratio)
	check(ratio <= 1.10 and ratio > 1.0, "traits raise the average prize by %.1f%% (<= 10)" % ((ratio - 1.0) * 100.0))
	# Rare auras are still at most 10% of opponents.
	var rare := 0
	for k in runs:
		var t2 := Tournament.new(1, k + 1000)
		for i in range(1, 5):
			rare += 1 if t2.lineup[i]["mods"].any(func(id): return Modifiers.is_aura(id)) else 0
	check(float(rare) / float(runs * 4) <= 0.12, "rare auras: %d of %d opponents" % [rare, runs * 4])
	# «Дыра слева»: a winner into his backhand is a trick.
	var tricks: Array = StyleRules.evaluate({"won": true, "reason": "WINNER", "rally": 5, "hole": true, "last": {"type": "FLAT"}, "labels": []})["tricks"]
	check(tricks.any(func(x): return x["id"] == "hole"), "the style rules know «Дыра слева»")
	check(StyleRules.evaluate({"won": true, "reason": "WINNER", "rally": 5, "hole": false, "last": {"type": "FLAT"}, "labels": []})["tricks"].is_empty(), "...and only with the trait")


func test_card() -> void:
	print("card data")
	var lu := {"mods": ["fast", "fog", "moon"], "hidden": ["moon"]}
	var c := Modifiers.card(lu)
	check(c.size() == 3 and c[2]["name"] == "???" and c[1]["name"] == "Туман", "the card: names, «???» for the hidden one")
	check(Modifiers.bracket_text(lu).contains("???") and Modifiers.bracket_text(lu).contains("×"), "bracket line: %s" % Modifiers.bracket_text(lu))
	check(Modifiers.match_set(null) == [], "no tournament, nothing forced: no modifiers")
	check(Modifiers.name("fog") == "Туман" and Modifiers.desc("fast") == "Бегает на 12% быстрее" and Modifiers.name("nope") == Modifiers.UNKNOWN_NAME and Modifiers.desc("nope") == Modifiers.UNKNOWN_DESC,
		"Modifiers.name / desc: new, old and unknown ids (for the opponent card)")


# --- Spec hub-economy 14: the conditions rotate, the opponents' modifiers have a rate ---------

func test_rotation() -> void:
	print("rotation of the run's conditions")
	var pro: Array = Modifiers.PRESETS[0]["mods"]
	var run_ids: Array = Modifiers.pool("run").map(func(e): return e["id"])
	var sizes_ok := true
	var pro_ok := true
	var pool_ok := true
	var hard_ok := true
	var same := true
	var sets := {}
	var seen := {}
	for n in range(1, 201):
		var r: Array = Modifiers.rotation(n)
		sizes_ok = sizes_ok and r.size() >= 6 and r.size() <= 8
		pro_ok = pro_ok and pro.all(func(id): return r.has(id))
		pool_ok = pool_ok and r.all(func(id): return run_ids.has(id))
		same = same and Modifiers.rotation(n) == r
		var hr: Array = Modifiers.rotation(n, true)
		hard_ok = hard_ok and hr.size() >= 6 and hr.size() <= 8 and hr.all(func(id): return run_ids.has(id) and not Modifiers.HARD_HAS.has(id))
		var key := r.duplicate()
		key.sort()
		sets[str(key)] = true
		for id in r:
			seen[id] = true
	check(sizes_ok, "every run shows 6..8 conditions")
	check(pro_ok, "the «Про» preset's two are always among them")
	check(pool_ok, "only conditions of the run pool")
	check(hard_ok, "hardcore: 6..8 too, none of what it holds")
	check(same, "the same run number, the same set")
	check(sets.size() > 100, "the set changes from run to run (%d different in 200)" % sets.size())
	check(seen.size() == run_ids.size(), "every condition shows up sometimes (%d of %d)" % [seen.size(), run_ids.size()])


## Rates of the opponents' modifiers: the share of auras and second traits by a big sample, the
## pay, the save. «Редко» is the old density (x1, the default): nothing moves for a run without it.
func test_freq() -> void:
	print("modifier rate")
	check(Modifiers.FREQS.size() == 3 and Modifiers.FREQS.map(func(f): return f["name"]) == ["Редко", "Обычно", "Часто"], "three rates: Редко / Обычно / Часто")
	check(Modifiers.FREQS.map(func(f): return f["reward"]) == [1.0, 1.15, 1.35], "they pay x1.0 / x1.15 / x1.35")
	SaveData.played = 5
	var plain := Tournament.new(1, 31)
	check(plain.freq == Modifiers.FREQ_DEFAULT and Modifiers.FREQ_DEFAULT == 0, "a run is «Редко» unless picked")
	var same_rare := true
	var auras := [0, 0, 0]
	var seconds := [0, 0, 0]
	var opps := 0
	var runs := 400
	for k in runs:
		var base := Tournament.new(1, k + 1)
		for f in 3:
			var t := Tournament.new(1, k + 1)
			Modifiers.set_run(t, [], f)
			if f == 0:
				same_rare = same_rare and t.lineup.map(func(l): return l["mods"]) == base.lineup.map(func(l): return l["mods"])
			for i in range(1, t.rounds()):
				var m: Array = t.lineup[i]["mods"]
				auras[f] += 1 if m.any(func(id): return Modifiers.is_aura(id)) else 0
				seconds[f] += 1 if m.filter(func(id): return Traits.has(id)).size() >= 2 else 0
		opps += base.rounds() - 1
	var sh := auras.map(func(a): return float(a) / opps)
	var s2 := seconds.map(func(a): return float(a) / opps)
	print("       auras %.1f%% / %.1f%% / %.1f%%, two traits %.1f%% / %.1f%% / %.1f%%" % [sh[0] * 100, sh[1] * 100, sh[2] * 100, s2[0] * 100, s2[1] * 100, s2[2] * 100])
	check(same_rare, "«Редко» rolls exactly what a run without the choice rolls")
	check(sh[0] <= 0.10 and sh[1] > sh[0] * 1.6 and sh[2] > sh[1] * 1.6, "more auras with a higher rate")
	check(s2[1] > s2[0] * 1.4 and s2[2] > s2[1] * 1.2, "more second traits with a higher rate")
	var a := Tournament.new(1, 7)
	var b := Tournament.new(1, 7)
	Modifiers.set_run(a, [], 2)
	Modifiers.set_run(b, [], 2)
	check(a.lineup == b.lineup and a.freq == 2, "the same seed and rate, the same opponents")
	# The pay: in the one gold_mult with its cap.
	a.lineup[2]["mods"] = []
	check(absf(Modifiers.gold_mult(a, 2) - 1.35) < 0.001, "«Часто» pays x1.35 a win (%.2f)" % Modifiers.gold_mult(a, 2))
	var c := Tournament.new(1, 7)
	Modifiers.set_run(c, ["short_ring", "tier_up"], 1)
	c.lineup[2]["mods"] = []
	check(absf(Modifiers.gold_mult(c, 2) - 1.5 * 1.15) < 0.001 and absf(Modifiers.run_mult(c) - 1.5 * 1.15) < 0.001, "«Про» and «Обычно»: x%.3f" % Modifiers.gold_mult(c, 2))
	var d := Tournament.new(1, 7)
	Modifiers.set_run(d, ["no_ring", "mirror", "fog"], 2)
	d.lineup[2]["mods"] = ["showman"]
	check(Modifiers.gold_mult(d, 2) == Modifiers.MAX_REWARD and Modifiers.run_mult(d) == Modifiers.MAX_REWARD, "the cap holds with the rate")
	var plain_win := plain.gold_for_win(2)
	var often := Tournament.new(1, 31)
	Modifiers.set_run(often, [], 2)
	often.lineup[2]["mods"] = plain.lineup[2]["mods"]
	check(absi(often.gold_for_win(2) - roundi(plain_win * 1.35)) <= 1, "a win pays more: %d -> %d" % [plain_win, often.gold_for_win(2)])
	# Saved with the run and back on «Продолжить».
	check(Tournament.SAVED.has("freq"), "the rate is a saved field")
	var back := Tournament.from_dict(a.to_dict())
	check(back.freq == 2 and back.lineup == a.lineup, "the rate comes back with the run")
	var old := a.to_dict()
	old.erase("freq")
	check(Tournament.from_dict(old).freq == 0, "a run saved before it: «Редко»")
	check(Modifiers.freq_line(a).contains("Часто") and Modifiers.freq_line(a).contains("1.35"), "the bracket's words: %s" % Modifiers.freq_line(a))
	SaveData.played = 0


## The opponent card (D-5) names traits and auras, and keeps «???» hidden.
func test_card_traits() -> void:
	print("opponent card: traits")
	SaveData.played = 5
	var t := Tournament.new(1, 12)
	t.lineup[2]["mods"] = ["serve_cannon", "fog", "moon"]
	t.lineup[2]["hidden"] = ["moon"]
	var m: Array = load("res://scripts/ui/screens/opponent_card.gd").info(t, 2)["mods"]  # loaded: it reaches the autoloads
	check(m.size() == 3 and m[0].begins_with("Пушка подачи") and m[1].begins_with("Туман") and m[2].begins_with("???"), "names, not ids: %s" % [m])
	check(not m.any(func(x): return String(x).contains("serve_cannon") or String(x).contains("Лунная")), "no raw id, the hidden one not given away")
	SaveData.played = 0


# --- The live scene -----------------------------------------------------------------

func _snap() -> Dictionary:
	var h: ModsHub = main.mods_hub
	var env: Environment = h.environment()
	var mat := (main.ball._mesh as MeshInstance3D).material_override as StandardMaterial3D
	var s := {
		"tuning": [_tun().perfect_window, _tun().good_window, _tun().slowmo_enabled, _tun().slowmo_scale, _tun().show_aim,
			_tun().show_landing, _tun().assist, _tun().hawkeye_range, snappedf(_tun().ai_skill, 0.0001)],
		"physics": [BallPhysics.gravity_scale, BallPhysics.wind, BallPhysics.rubber_net, BallPhysics.friction, BallPhysics.pace, BallPhysics.bounce_offset],
		"court": [Court.inset, main.court._court_mat.albedo_color, main.court.get_child_count()],
		"skills": Skills.mods_layer.duplicate(),
		"ball": [main.ball._mesh.scale, main.ball._shadow.scale, main.ball._mesh.transparency, mat.emission, mat.emission_energy_multiplier],
		"env": [env.fog_density, env.tonemap_exposure, env.ambient_light_energy] if env else [],
		"cpu": [main.cpu.scale, main.ai.speed_mult, main._cpu_serve_mult],
		"hub": [h.start_stamina, h.no_ring, h.ring_late, h.mirror, h.pace.duplicate(), h.serve_pace.duplicate(), h.echo_every,
			h.reaction_add, h.drain_on_loss, h.heal_on_win, h.fog, h.night, h.hole, h.traits],
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
	for e in Traits.all():
		h.apply([e["id"]])
		var tc := _diff(base, _snap())
		if not e["fx"].all(func(f): return f[0] == "opp"):  # "opp" is read by Main when the match starts
			check(not tc.is_empty(), "trait %s changes something: %s" % [e["id"], tc])
		h.revert()
		var tb := _diff(base, _snap())
		check(tb.is_empty(), "trait %s is put back cleanly%s" % [e["id"], "" if tb.is_empty() else " — left: %s" % [tb]])
	# «Дыра слева»: the stroke's target against his right().
	h.apply(["hole_left"])
	var rx: float = (main.cpu as Athlete).right().x
	main.last_shot = {"target": Vector2(-rx * 2.5, -10.0)}
	root.get_node("GameEvents").player_stroke.emit({"type": "FLAT", "label": "GOOD", "serve": false})
	check(Traits.hole_hit, "a ball to his backhand side counts")
	main.last_shot = {"target": Vector2(rx * 2.5, -10.0)}
	root.get_node("GameEvents").player_stroke.emit({"type": "FLAT", "label": "GOOD", "serve": false})
	check(not Traits.hole_hit, "a ball to his forehand does not")
	h.revert()
	check(not Traits.hole_hit and not h.hole, "put back")
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
	# The menu is the club now (stream H): it tints the sky by the time of day, so "env" is its.
	var left := _diff(base, _snap()).filter(func(k): return k != "opp" and k != "cpu" and k != "tuning" and not (k == "env" and main.club.active))
	if not left.is_empty():
		for k in left:
			print("    differs: %s  was %s  now %s" % [k, base[k], _snap()[k]])
	check(left.is_empty(), "...the court, the ball and the physics too")
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
	var rot: Array = Modifiers.rotation(SaveData.played + 1)
	check(RM.choices().map(func(e): return e["id"]) == Modifiers.pool("run").map(func(e): return e["id"]).filter(func(id): return rot.has(id)),
		"the screen shows this run's rotation (%d), in the catalog's order" % RM.choices().size())
	var cards: Array = main.ui._box.find_children("*", "GameCard", true, false)
	check(cards.size() == 2, "both mode cards (ОБЫЧНЫЙ / ХАРДКОР) are always there")
	check(RM.freq == SaveData.mods_freq and RM.freq_buttons(main.ui).size() == 3, "the rate: three buttons, the remembered one on")
	RM.ui_action(main, "mods_preset", 0)
	check(RM.picked == ["short_ring", "tier_up"] and absf(RM.total() - 1.5) < 0.001, "«Про» takes two and pays x1.5")
	RM.ui_action(main, "mods_toggle", RM.choices().find_custom(func(e): return e["id"] == "tier_up"))
	check(RM.picked == ["short_ring"] and not RM.preset_on(), "one condition of the preset comes off alone")
	RM.ui_action(main, "mods_preset", 0)
	var others: Array = []  # rows that are not the preset's (the rotation puts them anywhere)
	for k in RM.choices().size():
		if not RM.preset()["mods"].has(RM.choices()[k]["id"]):
			others.append(k)
	RM.ui_action(main, "mods_toggle", others[0])
	RM.ui_action(main, "mods_toggle", others[1])
	check(RM.picked.size() == 3, "three at most (%s)" % [RM.picked])
	RM.ui_action(main, "mods_preset", 0)
	check(RM.picked == [RM.choices()[others[0]]["id"]], "the preset off leaves the others (%s)" % [RM.picked])
	RM.picked = ["short_ring", "tier_up", "night"]
	RM.ui_action(main, "mods_freq", 2)
	check(RM.freq == 2 and absf(RM.total() - minf(Modifiers.reward_raw(RM.picked) * 1.35, 3.0)) < 0.001, "«Часто» joins the total (x%.2f)" % RM.total())
	RM.ui_action(main, "mods_go", 0)
	var t: Tournament = main.tournament
	check(t != null and t.run_modifiers == ["short_ring", "tier_up", "night"] and t.format == 1, "the run starts with the three")
	check(t.freq == 2 and SaveData.mods_freq == 2, "...at the rate picked, remembered for the next run")
	check(t.modifier_value("skill") >= 0.099 and absf(Modifiers.gold_mult(t, 3) - minf(Modifiers.run_mult(t) * Modifiers.reward(t.lineup[3]["mods"]), 3.0)) < 0.001,
		"opponents a tier up and the prize multiplied")
	main.ui.show_bracket(t)
	await process_frame
	check(main.ui._box.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.to_lower().contains("часто")), "the bracket says the rate")
	RM.open(main, 1)
	check(RM.freq == 2, "the screen opens on the remembered rate")
	RM.ui_action(main, "mods_freq", 0)
	SaveData.mods_freq = 0
	RM.ui_action(main, "mods_back", 0)
	# The mode cards: hardcore opens with the first title.
	SaveData.titles = 0
	RM.open(main, 1)
	RM.ui_action(main, "mods_mode", 1)
	check(not RM.hardcore, "no title: hardcore stays locked")
	SaveData.titles = 1
	RM.ui_action(main, "mods_toggle", RM.choices().find_custom(func(e): return e["id"] == "tier_up"))
	RM.ui_action(main, "mods_mode", 1)
	check(RM.hardcore and not RM.picked.has("tier_up") and RM.choices().all(func(e): return not Modifiers.HARD_HAS.has(e["id"])), "hardcore: its own conditions leave the list")
	check(absf(RM.total() - 2.5) < 0.001, "the button says x2.5")
	RM.ui_action(main, "mods_toggle", 0)
	check(absf(RM.total() - minf(2.5 * Modifiers.find(RM.choices()[0]["id"])["reward"], 4.0)) < 0.001, "a condition on top multiplies")
	RM.ui_action(main, "mods_go", 0)
	var hc: Tournament = main.tournament
	check(hc != null and hc.hardcore and hc.run_modifiers[0] == "hardcore", "the run starts hardcore")
	await _hard_match(hc)
	SaveData.titles = 0
	SaveData.played = 0


## A hardcore match: no help, back as before after it.
func _hard_match(hc: Tournament) -> void:
	main.tournament = hc
	main.tournament_mode = true
	var h: ModsHub = main.mods_hub
	var before := [_tun().assist, _tun().slowmo_enabled, _tun().show_aim, _tun().show_landing]
	main._play_match()
	await process_frame
	check(h.active.has("hardcore") and _tun().assist == 0.0 and not _tun().slowmo_enabled and not _tun().show_aim and not _tun().show_landing, "in the match: no assist, no slow-mo, no aim, no landing mark")
	check(float(Skills.mods_layer.get("forehand_window", 0.0)) < -0.29, "the ring's window is 30% narrower")
	main._show_menu()
	await physics_frame
	await physics_frame
	check([_tun().assist, _tun().slowmo_enabled, _tun().show_aim, _tun().show_landing] == before and Skills.mods_layer.is_empty(), "after it everything is back")
