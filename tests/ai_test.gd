extends SceneTree
## Stream D (difficulty, serve, opponent AI, camera) tests, headless:
##   godot --headless --path . -s tests/ai_test.gd

var failures := 0
var finished := 0                 # tests that ran to their end (a script error stops one short)
var expected := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests := [
		test_metrics_endings,
		test_metrics_serve,
		test_early_difficulty,
		test_serve_reading,
		test_shot_planner,
		test_play_styles,
		test_player_habits,
		test_pressure_errors,
		test_net_and_footwork,
	]
	expected = tests.size()
	for t in tests:
		t.call()
	check(finished == expected, "every test ran to its end: %d of %d" % [finished, expected])
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


## A stand-in for Main with just what the AI and the metrics read.
class FakeGame:
	extends Node
	var player := Node3D.new()
	var cpu := Node3D.new()
	var serve_flight := false
	var box_side := -1.0
	var rally := 0
	var bounces := 0
	var autoplay := false
	var last_serve_kmh := 150.0



func _shot(who: int, contact: Vector3, speed: float, pos_p := Vector3(0, 0, 12), pos_c := Vector3(0, 0, -12), drop := false, lob := false) -> Dictionary:
	return {"who": who, "contact": contact, "speed": speed, "drop": drop, "lob": lob, "pos": [pos_p, pos_c]}


func test_metrics_endings() -> void:
	print("metrics: how points end")
	check(AiMetrics.ending_kind("ACE", []) == "ace", "an ace")
	check(AiMetrics.ending_kind("WINNER", []) == "winner", "a winner")
	check(AiMetrics.ending_kind("DOUBLE FAULT", []) == "double", "a double fault")
	# CPU fed a soft ball, the player (who stood still) netted it: unforced.
	var soft := [_shot(0, Vector3(0.5, 2.8, 12), 40.0), _shot(1, Vector3(0, 1, -12), 20.0), _shot(0, Vector3(0.7, 1, 12), 25.0)]
	check(AiMetrics.ending_kind("NET", soft) == "unforced", "a soft ball missed from where you stood: unforced")
	var heavy := [_shot(0, Vector3(0.5, 2.8, 12), 40.0), _shot(1, Vector3(0, 1, -12), 33.0), _shot(0, Vector3(0.7, 1, 12), 25.0)]
	check(AiMetrics.ending_kind("OUT", heavy) == "forced", "a heavy ball missed: forced")
	var ran := [_shot(0, Vector3(0.5, 2.8, 12), 40.0), _shot(1, Vector3(0, 1, -12), 22.0), _shot(0, Vector3(4.0, 1, 11), 25.0)]
	check(AiMetrics.ending_kind("OUT", ran) == "forced", "missed after a 4 m run: forced")
	var dropped := [_shot(0, Vector3(0, 1, 12), 22.0), _shot(1, Vector3(0, 0.4, -3), 8.0, Vector3(0, 0, 12), Vector3(0, 0, -11)), _shot(0, Vector3(0, 0.3, 2), 10.0)]
	check(AiMetrics.ending_kind("NET", dropped) == "forced", "a drop shot dug out into the net: forced")
	var serve := [_shot(1, Vector3(0, 2.8, -12), 38.0), _shot(0, Vector3(1, 1, 12), 20.0)]
	check(AiMetrics.ending_kind("OUT", serve) == "unforced", "a 137 km/h serve missed from where you stood: unforced")
	finished += 1


func test_metrics_serve() -> void:
	print("metrics: the serve by direction")
	check(AiMetrics.serve_dir(0.5) == "T" and AiMetrics.serve_dir(2.0) == "body" and AiMetrics.serve_dir(3.4) == "wide", "T / body / wide by the bounce across the box")
	var g := FakeGame.new()
	var m := AiMetrics.new()
	m.game = g
	g.player.position = Vector3(0.5, 0, 12)
	g.cpu.position = Vector3(0, 0, -12)
	g.box_side = -1.0
	g.serve_flight = true
	# Player serves wide into the left box (x < 0): in, an ace.
	m.on_shot(0, {"contact": Vector3(0.8, 2.8, 12.3), "speed": 45.0})
	m.on_bounce({"pos": Vector3(-3.5, 0.03, -5.5), "last_hitter": 0})
	g.serve_flight = false
	m.on_point({"winner": 0, "reason": "ACE", "rally": 1, "server": 0})
	# Wide again: a fault past the sideline, then the second serve to the T is returned and lost.
	g.serve_flight = true
	m.on_shot(0, {"contact": Vector3(0.8, 2.8, 12.3), "speed": 45.0})
	m.on_bounce({"pos": Vector3(-4.6, 0.03, -5.5), "last_hitter": 0})
	m.on_shot(0, {"contact": Vector3(0.8, 2.8, 12.3), "speed": 40.0})
	m.on_bounce({"pos": Vector3(-0.4, 0.03, -5.0), "last_hitter": 0})
	g.serve_flight = false
	m.on_shot(1, {"contact": Vector3(0.3, 1.0, -12.0), "speed": 25.0})
	m.on_shot(0, {"contact": Vector3(0.6, 1.0, 12.0), "speed": 25.0})
	m.on_point({"winner": 1, "reason": "OUT", "rally": 3, "server": 0})
	check(m.serve["wide"]["n"] == 2 and m.serve["wide"]["in"] == 1 and m.serve["wide"]["fault"] == 1 and m.serve["wide"]["ace"] == 1, "wide: 2 served, 1 in, 1 fault, 1 ace")
	check(m.serve["T"]["in"] == 1 and m.serve["T"]["ace"] == 0, "T: 1 in, no ace")
	check(m.player_serve_games == 1 and m.player_aces == 1, "one service game, one ace")
	check(m.points == 2 and is_equal_approx(m.avg_rally(), 2.0), "two points, average rally 2")
	check(m.endings[0].get("ace", 0) == 1 and m.endings[1].get("unforced", 0) == 1, "an ace for you, an unforced error for the CPU's point")
	check(is_equal_approx(m.active_share(), 0.5), "half the points won actively")
	check(m.cpu["shots"] == 1, "the CPU's return counts as a rally shot")
	check(m._shots.is_empty(), "the point's shots are cleared for the next one")
	check(m.report().contains("serve wide"), "the report has the serve table")
	m.free()
	g.player.free()
	g.cpu.free()
	g.free()
	finished += 1


## The curves before D-1, to check the late levels did not move.
static func _old_k(lv: int) -> float:
	return 1.0 - pow(1.0 - clampf(float(lv) / 25.0, 0.0, 1.0), 1.6)


func test_early_difficulty() -> void:
	print("D-1: a harder start, the same late game")
	Skills.reset()
	check(is_equal_approx(Skills.early(0), 1.0) and Skills.early(5) > 0.2 and Skills.early(5) < 0.5 and Skills.early(10) == 0.0 and Skills.early(25) == 0.0, "the early penalty: 1 at level 0, fades out by level 10")
	var b0 := Skills.stroke("forehand", 0)
	check(b0["window"] < 0.55 * 0.8, "level 0: PERFECT window narrower than before (%.2f < 0.44)" % b0["window"])
	check(b0["ring_speed"] > 1.4 * 1.15 and b0["ring"] < 0.6, "level 0: the ring shows later and closes faster (%.2f, %.2f)" % [b0["ring"], b0["ring_speed"]])
	check(b0["scatter"] > 1.8 * 1.25, "level 0: more scatter (%.2f)" % b0["scatter"])
	check(Skills.run_speed_mult(0) < 0.75 * 0.92, "level 0: slower feet (%.3f)" % Skills.run_speed_mult(0))
	var same := true
	var worst := ""
	for lv in range(12, 26):
		var t := _old_k(lv)
		var s := Skills.stroke("serve", lv)
		var old := {"window": lerpf(0.55, 1.5, t), "good": lerpf(0.9, 1.3, t), "ring": lerpf(0.6, 0.95, t), "ring_speed": lerpf(1.4, 0.9, t),
			"pace": lerpf(0.70, 1.25, t), "scatter": maxf(lerpf(1.8, 0.5, t), 0.3), "spin": lerpf(0.75, 1.2, t)}
		for key in old:
			if absf(float(s[key]) / float(old[key]) - 1.0) > 0.03:
				same = false
				worst = "%s at %d: %.3f vs %.3f" % [key, lv, s[key], old[key]]
		if absf(Skills.run_speed_mult(lv) / lerpf(0.75, 1.15, t) - 1.0) > 0.03:
			same = false
			worst = "run speed at %d" % lv
	check(same, "levels 12-25 within 3%% of the old curves %s" % worst)
	var mono := true
	for lv in range(0, 25):
		var a := Skills.stroke("backhand", lv)
		var b := Skills.stroke("backhand", lv + 1)
		if b["window"] < a["window"] or b["scatter"] > a["scatter"] or b["ring_speed"] > a["ring_speed"] or Skills.run_speed_mult(lv + 1) < Skills.run_speed_mult(lv):
			mono = false
	check(mono, "every level is a step up: window, scatter, ring and feet only improve")
	check(Skills.stroke("forehand", 8)["window"] > b0["window"] * 1.8, "level 8 feels much easier than level 0 (window x%.1f)" % (Skills.stroke("forehand", 8)["window"] / b0["window"]))
	finished += 1


func _receiver_x(ai: Node, server_x: float, box_side: float) -> float:
	ai.game.player.position = Vector3(server_x, 0.0, 12.3)
	var sum := 0.0
	for i in 20:
		sum += ai.receive_position(box_side).x
	return sum / 20.0


func test_serve_reading() -> void:
	print("D-2: the receiver reads the wide serve")
	var m := PlayerModel.new()
	check(absf(m.wide_bias(-1.0)) < 0.01, "no serves seen: no lean")
	for i in 3:
		m.note_serve(-1.0, 3.6)
	check(m.wide_bias(-1.0) > 0.3, "three wide serves to the left box: expects wide there (%.2f)" % m.wide_bias(-1.0))
	check(absf(m.wide_bias(1.0)) < 0.01, "the other box is read separately")
	for i in 6:
		m.note_serve(-1.0, 0.4)
	check(m.wide_bias(-1.0) < 0.0, "then six to the T: expects the T (%.2f)" % m.wide_bias(-1.0))
	m.reset()
	check(absf(m.wide_bias(-1.0)) < 0.01, "a new match forgets")

	var g := FakeGame.new()
	# Loaded at run time: OpponentAI uses the Tuning autoload, which a -s script can't
	# see while it is being compiled.
	var ai: Node = load("res://scripts/opponent_ai.gd").new()
	ai.game = g
	ai.rng.seed = 3
	var neutral := _receiver_x(ai, 0.9, -1.0)
	check(neutral < -2.75 and neutral > -3.8, "neutral: stands on the bisector of wide and T, wider than before (x %.2f)" % neutral)
	var from_wide := _receiver_x(ai, 3.6, -1.0)
	var from_mid := _receiver_x(ai, 0.3, -1.0)
	check(from_wide < from_mid - 0.6, "the server standing wide pulls the receiver wider (%.2f vs %.2f)" % [from_wide, from_mid])
	for i in 4:
		ai.model.note_serve(-1.0, 3.7)
	var read_wide := _receiver_x(ai, 0.9, -1.0)
	ai.model.reset()
	for i in 4:
		ai.model.note_serve(-1.0, 0.3)
	var read_t := _receiver_x(ai, 0.9, -1.0)
	check(read_wide < read_t - 0.4, "after wide serves it shades wide, after T serves to the T (%.2f vs %.2f)" % [read_wide, read_t])
	var right := _receiver_x(ai, -0.9, 1.0)
	check(right > 2.75, "the mirror box works too (x %.2f)" % right)
	var tuning := root.get_node("Tuning")
	var s0: float = tuning.ai_skill
	tuning.ai_skill = 0.0
	check(ai.return_reach() >= 1.35, "returning: the weakest AI reaches %.2f m (was 1.15)" % ai.return_reach())
	tuning.ai_skill = s0
	Skills.reset()
	check(Skills.serve_edge_margin(0) < 0.05 and is_equal_approx(Skills.serve_edge_margin(12), 0.2), "a beginner's wide serve is aimed at the line itself (%.2f), a trained one 0.2 m inside" % Skills.serve_edge_margin(0))
	ai.free()
	g.player.free()
	g.cpu.free()
	g.free()
	finished += 1


func _sit(over := {}) -> Dictionary:
	var d := {"q": 0.8, "skill": 0.5, "me": Vector3(-2.0, 0, -12.4), "contact": Vector3(-1.3, 1.0, -12.0),
		"player": Vector3(0.0, 0, 12.6), "player_vel": Vector3.ZERO, "volley": false, "short": false,
		"rally": 4, "bh_x": -1.0, "bh_weak": 0.0}
	d.merge(over, true)
	return d


## Share of each plan kind over n tries of the same situation.
func _kinds(sit: Dictionary, style_id: String, n := 400) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var out := {}
	for i in n:
		var p := ShotPlanner.choose(sit, Opponents.PLAY_STYLES[style_id], rng)
		out[p["kind"]] = out.get(p["kind"], 0.0) + 1.0 / n
	return out


func test_shot_planner() -> void:
	print("D-3: the shot fits the situation")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ok_targets := true
	for i in 600:
		var sit := _sit({"q": rng.randf_range(0.2, 1.0), "player": Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(3, 15)),
			"me": Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-14, -3)), "short": rng.randf() < 0.3, "volley": rng.randf() < 0.1})
		var p := ShotPlanner.choose(sit, Opponents.PLAY_STYLES[Opponents.PLAY_STYLES.keys()[i % 5]], rng)
		if absf(p["tx"]) > 3.75 or p["tz"] < 1.5 or p["tz"] > 11.0 or not ShotPlanner.KINDS.has(p["kind"]):
			ok_targets = false
	check(ok_targets, "every target lands inside the singles court, every kind is known")
	var neutral := _kinds(_sit(), "allcourt")
	check(neutral.get("neutral", 0.0) + neutral.get("change", 0.0) > 0.9, "neutral rally: patience and a change of direction (%s)" % str(neutral))
	var short := _kinds(_sit({"short": true, "me": Vector3(-1, 0, -8.8), "contact": Vector3(-0.3, 1, -8.4)}), "allcourt")
	check(short.get("approach", 0.0) > 0.25, "a short ball: approach and come in (%.0f%%)" % (short.get("approach", 0.0) * 100.0))
	var deep := _kinds(_sit({"player": Vector3(0.5, 0, 14.4), "me": Vector3(-1, 0, -10.6)}), "allcourt")
	check(deep.get("drop", 0.0) > 0.15, "the player camped deep, we are inside: drop shot (%.0f%%)" % (deep.get("drop", 0.0) * 100.0))
	var net := _kinds(_sit({"player": Vector3(1.0, 0, 4.0)}), "allcourt")
	check(is_equal_approx(net.get("lob", 0.0) + net.get("pass", 0.0), 1.0) and net.get("lob", 0.0) > 0.2, "the player at the net: lob or pass, nothing else (%s)" % str(net))
	var pulled := _kinds(_sit({"player": Vector3(3.6, 0, 12.4)}), "allcourt")
	check(pulled.get("attack", 0.0) > 0.35, "the player pulled wide: go for the open court (%.0f%%)" % (pulled.get("attack", 0.0) * 100.0))
	var p := ShotPlanner.choose(_sit({"player": Vector3(3.6, 0, 12.4)}), {"aggr": 1.0}, rng)
	check(p["kind"] == "attack" and p["tx"] < -2.5, "the attack goes to the open side (tx %.1f)" % p["tx"])
	var poor := ShotPlanner.choose(_sit({"q": 0.3}), Opponents.PLAY_STYLES["attacker"], rng)
	check(poor["kind"] == "defend" and poor["tz"] >= 8.0 and absf(poor["tx"]) <= 1.5, "stretched: high, deep and central")
	var vol := ShotPlanner.choose(_sit({"volley": true, "me": Vector3(0, 0, -4.2)}), Opponents.PLAY_STYLES["allcourt"], rng)
	check(vol["kind"] == "volley" and vol["tz"] < 8.5 and vol["approach"], "at the net: an angled volley, and stay in")
	var weak := _kinds(_sit({"bh_weak": 1.0, "me": Vector3(0.0, 0, -12.4)}), "counter")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 3
	var to_bh := 0
	for i in 300:
		var pl := ShotPlanner.choose(_sit({"bh_weak": 1.0, "me": Vector3(0.0, 0, -12.4)}), Opponents.PLAY_STYLES["counter"], rng2)
		if pl["tx"] < 0.0:
			to_bh += 1
	check(to_bh > 300 * 0.7, "a weak backhand seen: most neutral balls go to it (%d of 300)" % to_bh)
	finished += 1


func test_play_styles() -> void:
	print("D-3: play styles decide differently")
	for o in Opponents.ROSTER:
		check(Opponents.PLAY_STYLES.has(String(o.get("play_style", ""))) and o.has("skill") and o.has("lesson"), "%s: a play style, the old fields kept" % o["id"])
	var ids := []
	for o in Opponents.ROSTER:
		if not ids.has(o["play_style"]):
			ids.append(o["play_style"])
	check(ids.size() >= 4, "at least four styles in the roster: %s" % str(ids))
	var short := _sit({"short": true, "me": Vector3(-1, 0, -8.8)})
	check(_kinds(short, "netrusher").get("approach", 0.0) > _kinds(short, "counter").get("approach", 0.0) + 0.3, "the net rusher comes in far more than the counter-puncher")
	var neutral := _sit({"q": 0.85})
	check(_kinds(neutral, "netrusher").get("approach", 0.0) > 0.1 and _kinds(neutral, "counter").get("approach", 0.0) == 0.0, "the net rusher comes in behind good neutral balls too")
	var pulled := _sit({"player": Vector3(3.4, 0, 12.4)})
	check(_kinds(pulled, "attacker").get("attack", 0.0) > _kinds(pulled, "counter").get("attack", 0.0) + 0.3, "the attacker goes for the open court far more often")
	var net := _sit({"player": Vector3(1.0, 0, 4.0)})
	check(_kinds(net, "counter").get("lob", 0.0) > _kinds(net, "attacker").get("lob", 0.0) + 0.2, "the counter-puncher lobs a net rusher, the attacker passes")
	check(Opponents.PLAY_STYLES["bomber"]["serve"] > 1.05 and Opponents.PLAY_STYLES["attacker"]["risk"] > Opponents.PLAY_STYLES["counter"]["risk"], "the bomber serves bigger, the attacker risks more")
	check(Opponents.play_style({}) == Opponents.PLAY_STYLES["allcourt"] and Opponents.find("zverev")["play_style"] == "bomber", "practice: the all-rounder; Zverev: the bomber")
	finished += 1


func test_player_habits() -> void:
	print("D-3: it reads the player's weaker wing")
	var m := PlayerModel.new()
	check(m.backhand_weakness() == 0.0, "nothing seen: no weak wing")
	for i in 10:
		m.note_stroke(1, 0.85)
		m.note_stroke(-1, 0.55)
		if i % 3 == 0:
			m.note_error(-1)
	check(m.backhand_weakness() > 0.3, "a shaky backhand is read (%.2f)" % m.backhand_weakness())
	m.reset()
	for i in 10:
		m.note_stroke(1, 0.5)
		m.note_error(1)
		m.note_stroke(-1, 0.85)
	check(m.backhand_weakness() < -0.3, "a shaky forehand is read too (%.2f)" % m.backhand_weakness())
	finished += 1


func test_pressure_errors() -> void:
	print("D-3: errors come from pressure")
	var tuning := root.get_node("Tuning")
	var s0: float = tuning.ai_skill
	tuning.ai_skill = 0.45
	var ai: Node = load("res://scripts/opponent_ai.gd").new()
	var easy: float = ai.error_chance(0.85, 18.0, 0.0)
	var stretched: float = ai.error_chance(0.85, 18.0, 1.0)
	var heavy: float = ai.error_chance(0.6, 34.0, 0.0)
	var both: float = ai.error_chance(0.6, 34.0, 1.0)
	check(easy < 0.05, "an easy ball from where it stands: rarely missed (%.3f)" % easy)
	check(stretched > easy * 3.0, "stretched for it: misses much more (%.3f)" % stretched)
	check(heavy > easy * 2.5, "a heavy ball: misses more (%.3f)" % heavy)
	check(both > stretched and both > heavy and both <= 0.6, "both: the most (%.3f)" % both)
	# The old model for an easy ball (Main.error_chance, CPU): base 0.0585 x (1 - 0.6) + ...
	var old_easy := (lerpf(0.09, 0.02, 0.45) * (1.0 - 0.85 * 0.7) + clampf((18.0 - 16.0) / 22.0, 0.0, 1.0) * 0.15 * lerpf(0.6, 0.35, 0.45) + pow(0.15, 2.0) * 0.35) * 0.8
	check(easy < old_easy, "fewer cheap errors than before (%.3f < %.3f)" % [easy, old_easy])
	ai.set_profile(Opponents.find("basilashvili"))
	check(ai.error_chance(0.85, 18.0, 0.0) > easy, "the attacker risks more on the same ball")
	tuning.ai_skill = s0
	ai.free()
	finished += 1


func test_net_and_footwork() -> void:
	print("D-3: the AI comes in; the player runs around the backhand")
	var g := FakeGame.new()
	var ai: Node = load("res://scripts/opponent_ai.gd").new()
	ai.game = g
	ai.on_cpu_hit(2.0, true)
	check(ai._recovery.z > -5.0 and ai._at_net, "after an approach it closes in on the net (z %.1f)" % ai._recovery.z)
	ai.on_cpu_hit(2.0)
	check(ai._recovery.z < -12.0 and not ai._at_net, "after a rally ball it goes back to the baseline")
	check(ai.serve_mult() == 1.0, "the all-rounder's serve as before")
	ai.set_profile(Opponents.find("zverev"))
	check(ai.serve_mult() > 1.05 and ai.style_id == "bomber", "Zverev serves bigger")
	ai.free()
	g.player.free()
	g.cpu.free()
	g.free()
	check(Footwork.auto_side(-1, -0.6, 1.4, 1.2, 6.0) == 1, "a backhand near the middle with time: run around it")
	check(Footwork.auto_side(-1, -2.5, 3.0, 1.2, 6.0) == -1, "a wide backhand stays a backhand")
	check(Footwork.auto_side(-1, -0.6, 1.4, 0.4, 6.0) == -1, "no time: the backhand")
	check(Footwork.auto_side(1, 0.6, 0.0, 1.0, 6.0) == 1, "a forehand stays a forehand")
	finished += 1
