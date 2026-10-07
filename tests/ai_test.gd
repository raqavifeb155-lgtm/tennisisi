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
