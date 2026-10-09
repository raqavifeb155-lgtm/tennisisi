class_name AiMetrics
extends Node
## Match statistics for balancing with the bot (--autoplay), stream D. Listens to
## GameEvents and reads a little of Main's state (who serves, the service box, where the
## players stand); nothing here changes play. Main creates it only for autoplay runs.
##
## What it counts (see docs/superpowers/specs/2026-10-08-d0-bot-metrics.md):
##   rally length distribution; the player's serve by direction (wide / body / T: in,
##   faults, aces, unreturned); aces per player service game; how points end for each
##   side (ace, winner, forced error, unforced error, double fault) and the "active" share;
##   the CPU's tactics: drop shots, lobs, shots from the net, rallies with a net approach.

const WHO_PLAYER := 0
const WHO_CPU := 1

## Serve direction by where it bounced, as |x| across the box (0 = the T, 4.1 = the sideline).
const SERVE_T_MAX := 1.35
const SERVE_WIDE_MIN := 2.75
## An error is "forced" when the ball that caused it was heavy, a drop or a lob, or the
## hitter had to run this far for it.
const FORCED_SPEED := 30.0       # m/s (~108 km/h) in a rally
const FORCED_SERVE_SPEED := 42.0 # m/s (~150 km/h) for a return
const FORCED_RUN := 3.0          # m
## A CPU contact this close to the net counts as a shot from the net.
const NET_Z := 7.0

const RALLY_BUCKETS := [[1, 1], [2, 2], [3, 4], [5, 8], [9, 16], [17, 999]]

var game: Node                    # Main (or a stand-in with the same fields, in tests)

var points := 0
var rallies: Array[int] = []
var serve := {}                   # dir -> {"n", "in", "fault", "ace", "unret"}
var player_serve_games := 0
var player_aces := 0
var endings := [{}, {}]           # per winner: kind -> count
var cpu := {"shots": 0, "drops": 0, "lobs": 0, "net_shots": 0, "net_rallies": 0}

## The player's drop shots (--bot-drop=): how the CPU answered. n drops; hit = the CPU got a
## racket on it; arrived = ran up to it (<= ARRIVED m) and did not hit (the "doesn't swing" bug of
## D-7); far = could not get there; own_err = the drop itself went out or into the net;
## won = the point ended on the drop in the player's favour; pts / pts_won = points with a drop.
const ARRIVED := 1.3
var pdrop := {"n": 0, "hit": 0, "arrived": 0, "far": 0, "own_err": 0, "won": 0, "pts": 0, "pts_won": 0}
var _cur_drop := {}               # the drop in the air: {"min_d"}
var _pt_drop := false

## F-E (serve hotfix): every serve of either side, one record per attempt:
## {who, attempt, kmh, label (the player's), x (|x| across the box), dir, in, res ("ace" / "unret" / "")}.
## service_pts / oneshot / doubles are per server (0 player, 1 CPU): service points played, won by the
## serve alone (an ace or an unreturned ball) and lost on a double fault; cpu_serve_games counts the CPU's.
const STRONG_KMH := 195.0        # "a strong serve" for the tables (the owner's complaint: 200+ into the corner)
var serves: Array = []
var service_pts := [0, 0]
var oneshot := [0, 0]
var retfail := [0, 0]             # the receiver got a racket on it and missed (rally 2, the server won): "taken" but lost at once
var doubles := [0, 0]
var cpu_serve_games := 0
var _srv := {}                    # the serve in the air

var _shots: Array = []            # this point: {who, contact, speed, drop, lob, pos: [player, cpu]}
var _serve_dir := ""              # this point's player serve direction (last in-box one)
var _cpu_at_net := false
var _last_server := -1


func setup(g: Node) -> void:
	game = g
	var ge := _events()
	if ge:
		ge.shot.connect(on_shot)
		ge.bounce.connect(on_bounce)
		ge.point.connect(on_point)
		ge.player_stroke.connect(on_stroke)
		ge.match_finished.connect(func(_i: Dictionary) -> void: print(report()))


## While a drop is in the air: how close the CPU gets to the ball.
func _process(_delta: float) -> void:
	if _cur_drop.is_empty() or game == null:
		return
	var ball = game.get("ball")
	if ball == null or not ball.active:
		return
	var d := Vector2(ball.state.pos.x - game.cpu.position.x, ball.state.pos.z - game.cpu.position.z).length()
	_cur_drop["min_d"] = minf(float(_cur_drop["min_d"]), d)


func _events() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameEvents")


func reset() -> void:
	points = 0
	rallies = []
	serve = {}
	player_serve_games = 0
	player_aces = 0
	endings = [{}, {}]
	cpu = {"shots": 0, "drops": 0, "lobs": 0, "net_shots": 0, "net_rallies": 0}
	pdrop = {"n": 0, "hit": 0, "arrived": 0, "far": 0, "own_err": 0, "won": 0, "pts": 0, "pts_won": 0}
	_cur_drop = {}
	_pt_drop = false
	_shots = []
	_serve_dir = ""
	_cpu_at_net = false
	_last_server = -1
	serves = []
	service_pts = [0, 0]
	oneshot = [0, 0]
	retfail = [0, 0]
	doubles = [0, 0]
	cpu_serve_games = 0
	_srv = {}


static func serve_dir(x_across: float) -> String:
	var a := absf(x_across)
	if a <= SERVE_T_MAX:
		return "T"
	if a >= SERVE_WIDE_MIN:
		return "wide"
	return "body"


func on_shot(who: int, info: Dictionary) -> void:
	var rec := {
		"who": who, "contact": info.get("contact", Vector3.ZERO), "speed": float(info.get("speed", 0.0)),
		"drop": bool(info.get("drop", false)), "lob": bool(info.get("lob", false)),
		"pos": [game.player.position, game.cpu.position] if game else [Vector3.ZERO, Vector3.ZERO],
	}
	_shots.append(rec)
	if bool(info.get("serve", false)):
		var att = game.get("serve_attempt") if game else null
		_srv = {"who": who, "attempt": int(att) if att != null else 1, "kmh": rec["speed"] * 3.6, "label": ""}
	if who == WHO_PLAYER and rec["drop"] and not bool(info.get("serve", false)):
		pdrop["n"] += 1
		_pt_drop = true
		_cur_drop = {"min_d": INF}
	elif who == WHO_CPU and not _cur_drop.is_empty():
		pdrop["hit"] += 1  # the CPU answered the drop
		_cur_drop = {}
	if who == WHO_CPU and _shots.size() > 1:  # rally shots, not the CPU's serve
		cpu["shots"] += 1
		if rec["drop"]:
			cpu["drops"] += 1
		if rec["lob"]:
			cpu["lobs"] += 1
		if absf((rec["contact"] as Vector3).z) < NET_Z:
			cpu["net_shots"] += 1
			_cpu_at_net = true


## The player's stroke right after the shot: a serve takes its timing label.
func on_stroke(info: Dictionary) -> void:
	if bool(info.get("serve", false)) and not _srv.is_empty() and int(_srv["who"]) == WHO_PLAYER:
		_srv["label"] = String(info.get("label", ""))


## A bounce while a serve is in the air: a fault is forgotten (the point starts with the
## next serve); the player's serve is counted by direction, in or out.
func on_bounce(info: Dictionary) -> void:
	if game == null or not game.serve_flight:
		return
	var hitter := int(info.get("last_hitter", -1))
	var pos: Vector3 = info.get("pos", Vector3.ZERO)
	var inside := Court.in_service_box(pos, -1 if hitter == WHO_PLAYER else 1, float(game.box_side), BallPhysics.RADIUS)
	if not _srv.is_empty():
		var xs := pos.x * float(game.box_side)
		_srv["x"] = absf(xs)
		_srv["dir"] = "net" if (pos.z > 0.0) == (hitter == WHO_PLAYER) else serve_dir(xs if xs > 0.0 else 0.0)
		_srv["in"] = inside
		_srv["res"] = ""
		serves.append(_srv)
		_srv = {}
	if not inside:
		_shots.clear()
	if hitter != WHO_PLAYER:
		return
	var x := pos.x * float(game.box_side)
	var dir := "net" if pos.z > 0.0 else (serve_dir(x) if x > 0.0 else "T")
	var s: Dictionary = serve.get(dir, {"n": 0, "in": 0, "fault": 0, "ace": 0, "unret": 0})
	s["n"] += 1
	if inside:
		s["in"] += 1
		_serve_dir = dir
	else:
		s["fault"] += 1
	serve[dir] = s


## winner, reason, rally, server (GameEvents.point).
func on_point(info: Dictionary) -> void:
	var winner := int(info.get("winner", 0))
	var reason := String(info.get("reason", ""))
	var rally := int(info.get("rally", 0))
	var server := int(info.get("server", 0))
	points += 1
	rallies.append(rally)
	if server == WHO_PLAYER and _last_server != WHO_PLAYER:
		player_serve_games += 1
	if server == WHO_CPU and _last_server != WHO_CPU:
		cpu_serve_games += 1
	_last_server = server
	if server == WHO_PLAYER or server == WHO_CPU:
		service_pts[server] += 1
		if reason == "DOUBLE FAULT":
			doubles[server] += 1
		elif rally == 2 and winner == server:
			retfail[server] += 1
			if not serves.is_empty() and int(serves[-1]["who"]) == server:
				serves[-1]["res"] = "retfail"
		elif rally == 1 and winner == server:
			oneshot[server] += 1
			if not serves.is_empty() and int(serves[-1]["who"]) == server:
				serves[-1]["res"] = "ace" if reason == "ACE" else "unret"
	if server == WHO_PLAYER and _serve_dir != "" and rally == 1 and winner == WHO_PLAYER:
		var s: Dictionary = serve[_serve_dir]
		if reason == "ACE":
			s["ace"] += 1
		else:
			s["unret"] += 1
	if server == WHO_PLAYER and winner == WHO_PLAYER and reason == "ACE":
		player_aces += 1
	if not _cur_drop.is_empty():  # the point ended with the drop unanswered
		if winner == WHO_CPU:
			pdrop["own_err"] += 1
		else:
			pdrop["won"] += 1
			pdrop["arrived" if float(_cur_drop["min_d"]) <= ARRIVED else "far"] += 1
	if _pt_drop:
		pdrop["pts"] += 1
		if winner == WHO_PLAYER:
			pdrop["pts_won"] += 1
	_cur_drop = {}
	_pt_drop = false
	var kind := ending_kind(reason, _shots)
	endings[winner][kind] = int(endings[winner].get(kind, 0)) + 1
	if _cpu_at_net:
		cpu["net_rallies"] += 1
	_shots = []
	_serve_dir = ""
	_cpu_at_net = false


## How a point ended, for the side that won it: "ace", "winner", "forced", "unforced",
## "double". `shots` are the point's shots in order (see on_shot).
static func ending_kind(reason: String, shots: Array) -> String:
	match reason:
		"ACE":
			return "ace"
		"WINNER":
			return "winner"
		"DOUBLE FAULT":
			return "double"
	# OUT / NET: the last hitter missed. Forced if the ball before was heavy, a drop, a
	# lob, or they had to run for it.
	if shots.size() < 2:
		return "unforced"
	var miss: Dictionary = shots[-1]
	var cause: Dictionary = shots[-2]
	var heavy := FORCED_SERVE_SPEED if shots.size() == 2 else FORCED_SPEED
	if float(cause["speed"]) >= heavy or cause["drop"] or cause["lob"]:
		return "forced"
	var was: Vector3 = cause["pos"][int(miss["who"])]
	var at: Vector3 = miss["contact"]
	if Vector2(at.x - was.x, at.z - was.z).length() >= FORCED_RUN:
		return "forced"
	return "unforced"


func avg_rally() -> float:
	var t := 0
	for r in rallies:
		t += r
	return float(t) / maxf(rallies.size(), 1)


## Share of points (0..1) whose rally length is in [lo, hi].
func rally_share(lo: int, hi: int) -> float:
	var n := 0
	for r in rallies:
		if r >= lo and r <= hi:
			n += 1
	return float(n) / maxf(rallies.size(), 1)


## Share of points won actively (ace, winner, forced error) by `who`, or both (-1).
func active_share(who := -1) -> float:
	var act := 0
	var all := 0
	for w in [WHO_PLAYER, WHO_CPU]:
		if who >= 0 and w != who:
			continue
		for k in endings[w]:
			all += int(endings[w][k])
			if k == "ace" or k == "winner" or k == "forced":
				act += int(endings[w][k])
	return float(act) / maxf(all, 1)


## The serve log filtered: n served, in the box, aces, unreturned (not an ace), all by `who` and
## attempt (0 = both). min_kmh: only serves from this speed; label: the player's timing label;
## corner: only the wide / T ones by the bounce.
func serve_stats(who: int, attempt := 1, min_kmh := 0.0, label := "", corner := false) -> Dictionary:
	var r := {"n": 0, "in": 0, "ace": 0, "unret": 0, "retfail": 0, "kmh": 0.0}
	for s in serves:
		if int(s["who"]) != who or (attempt > 0 and int(s["attempt"]) != attempt):
			continue
		if float(s["kmh"]) < min_kmh or (label != "" and String(s["label"]) != label):
			continue
		if corner and not (s["dir"] == "wide" or s["dir"] == "T"):
			continue
		r["n"] += 1
		r["kmh"] += float(s["kmh"])
		if s["in"]:
			r["in"] += 1
			if s["res"] == "ace":
				r["ace"] += 1
			elif s["res"] == "unret":
				r["unret"] += 1
			elif s["res"] == "retfail":
				r["retfail"] += 1
	r["kmh"] = float(r["kmh"]) / maxf(r["n"], 1)
	return r


static func _pc(a: float, b: float) -> String:
	return "%d%%" % roundi(100.0 * a / maxf(b, 1.0))


func _serve_line(label: String, s: Dictionary) -> String:
	return "%s n %3d  in %s  avg %d km/h  ace %d (%s of in)  unreturned %d  return error %d  one-shot %s of in" % [label, s["n"], _pc(s["in"], s["n"]), roundi(s["kmh"]), s["ace"], _pc(s["ace"], s["in"]), s["unret"], s["retfail"], _pc(s["ace"] + s["unret"] + s["retfail"], s["in"])]


## F-E: the serve tables (the player's first and second serve, strong ones into the corner,
## PERFECT ones; the CPU's serve), printed with report().
func serve_report() -> String:
	var lines := PackedStringArray()
	var k := STRONG_KMH
	lines.append("--- serve (F-E): strong = %d+ km/h, corner = wide or T by the bounce ---" % roundi(k))
	lines.append(_serve_line("YOU 1st          ", serve_stats(WHO_PLAYER, 1)))
	lines.append(_serve_line("YOU 1st PERFECT  ", serve_stats(WHO_PLAYER, 1, 0.0, "PERFECT")))
	lines.append(_serve_line("YOU 1st strong   ", serve_stats(WHO_PLAYER, 1, k)))
	lines.append(_serve_line("YOU 1st PERF+strong", serve_stats(WHO_PLAYER, 1, k, "PERFECT")))
	lines.append(_serve_line("YOU 1st strong corner", serve_stats(WHO_PLAYER, 1, k, "", true)))
	lines.append(_serve_line("YOU 2nd          ", serve_stats(WHO_PLAYER, 2)))
	lines.append("YOU won by the serve alone (ace + unreturned) %d, return errors %d of %d service points: one-shot %s, doubles %d" % [oneshot[0], retfail[0], service_pts[0], _pc(oneshot[0] + retfail[0], service_pts[0]), doubles[0]])
	lines.append(_serve_line("CPU 1st          ", serve_stats(WHO_CPU, 1)))
	lines.append(_serve_line("CPU 1st corner   ", serve_stats(WHO_CPU, 1, 0.0, "", true)))
	lines.append(_serve_line("CPU 2nd          ", serve_stats(WHO_CPU, 2)))
	var g := maxf(cpu_serve_games, 1)
	lines.append("CPU won by the serve alone %d, return errors %d of %d service points: one-shot %s, aces/game %.2f, doubles %d (%.2f/game) over %d games" % [oneshot[1], retfail[1], service_pts[1],
		_pc(oneshot[1] + retfail[1], service_pts[1]), float(_cpu_aces()) / g, doubles[1], float(doubles[1]) / g, cpu_serve_games])
	return "\n".join(lines)


func _cpu_aces() -> int:
	return int(endings[WHO_CPU].get("ace", 0))


func report() -> String:
	var lines := PackedStringArray()
	lines.append("=== AI METRICS ===")
	var buckets := PackedStringArray()
	for b in RALLY_BUCKETS:
		var name := str(b[0]) if b[0] == b[1] else ("%d+" % b[0] if b[1] >= 999 else "%d-%d" % [b[0], b[1]])
		buckets.append("%s:%d%%" % [name, roundi(rally_share(b[0], b[1]) * 100.0)])
	lines.append("points %d  avg rally %.1f  rallies %s" % [points, avg_rally(), " ".join(buckets)])
	lines.append("player aces %d over %d service games = %.2f per game" % [player_aces, player_serve_games, float(player_aces) / maxf(player_serve_games, 1)])
	for dir in ["wide", "body", "T"]:
		var s: Dictionary = serve.get(dir, {"n": 0, "in": 0, "fault": 0, "ace": 0, "unret": 0})
		lines.append("serve %-4s n %3d  in %3d  fault %3d (%2d%%)  ace %3d (%2d%% of in)  unreturned %d" % [dir, s["n"], s["in"], s["fault"],
			roundi(100.0 * s["fault"] / maxf(s["n"], 1)), s["ace"], roundi(100.0 * s["ace"] / maxf(s["in"], 1)), s["unret"]])
	for w in [WHO_PLAYER, WHO_CPU]:
		lines.append("%s wins: %s" % ["YOU" if w == WHO_PLAYER else "CPU", str(endings[w])])
	lines.append("active share: all %d%%  YOU %d%%  CPU %d%%" % [roundi(active_share() * 100.0), roundi(active_share(WHO_PLAYER) * 100.0), roundi(active_share(WHO_CPU) * 100.0)])
	var cs := maxf(cpu["shots"], 1)
	lines.append("cpu shots %d  drops %d (%.1f%%)  lobs %d (%.1f%%)  from net %d (%.1f%%)  net rallies %d (%.1f%% of points)" % [cpu["shots"],
		cpu["drops"], 100.0 * cpu["drops"] / cs, cpu["lobs"], 100.0 * cpu["lobs"] / cs, cpu["net_shots"], 100.0 * cpu["net_shots"] / cs,
		cpu["net_rallies"], 100.0 * cpu["net_rallies"] / maxf(points, 1)])
	if int(pdrop["n"]) > 0:
		var n := float(pdrop["n"])
		lines.append("player drops %d: CPU hit %d (%d%%)  not hit: ran up %d (%d%%), too far %d (%d%%)  own error %d (%d%%)  | drop won outright %d (%d%%)  points with a drop won by YOU %d of %d (%d%%)" % [
			pdrop["n"], pdrop["hit"], roundi(100.0 * pdrop["hit"] / n), pdrop["arrived"], roundi(100.0 * pdrop["arrived"] / n), pdrop["far"], roundi(100.0 * pdrop["far"] / n),
			pdrop["own_err"], roundi(100.0 * pdrop["own_err"] / n), pdrop["won"], roundi(100.0 * pdrop["won"] / n),
			pdrop["pts_won"], pdrop["pts"], roundi(100.0 * pdrop["pts_won"] / maxf(pdrop["pts"], 1))])
	lines.append(serve_report())
	if game and game.get("ai") and game.ai.has_method("report"):
		lines.append(game.ai.report())
	return "\n".join(lines)
