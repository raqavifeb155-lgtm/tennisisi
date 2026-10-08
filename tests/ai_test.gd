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
