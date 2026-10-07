class_name StyleMeter
extends RefCounted
## Follows one match through GameEvents (RunHub feeds it) and scores every point the
## player wins with StyleRules: what the last stroke was, where the ball died, how long
## the rally ran. Keeps the match's style points and its best point (for the replay).

const GOLD_PER_POINT := 0.1       # style points -> run gold (x the format's reward, x the round)
const GOLD_PER_ROUND := 0.25      # +25% a round, like the experience (Main._xp_mult)

var match_points := 0
var best := {}                    # the best point: StyleRules result + rally, skill, stroke_frame
var best_index := -1              # which point of the match it was
var _points := 0                  # points played this match
var _last := {}                   # the player's last stroke this rally
var _labels: Array[String] = []
var _serve_kmh := 0.0
var _opp_dist := 99.0             # |z| of the opponent when the player last hit
var _second_bounce := -1.0        # |z| where the player's ball bounced twice, -1 = it didn't
var _knocked := false
var _frame := -1                  # PointRecorder frame of the player's last stroke


func start_match() -> void:
	match_points = 0
	best = {}
	best_index = -1
	_points = 0
	start_point()


func start_point() -> void:
	_last = {}
	_labels = []
	_serve_kmh = 0.0
	_opp_dist = 99.0
	_second_bounce = -1.0
	_knocked = false
	_frame = -1


## GameEvents.player_stroke, with where the opponent stood and the replay frame.
func on_stroke(info: Dictionary, opp_pos: Vector3, frame: int) -> void:
	_last = info
	_labels.append(String(info.get("label", "")))
	if info.get("serve", false):
		_serve_kmh = float(info.get("kmh", 0.0))
	_opp_dist = absf(opp_pos.z)
	_second_bounce = -1.0
	_frame = frame


## GameEvents.bounce: "bounces" counts the bounces before this one.
func on_bounce(info: Dictionary) -> void:
	var p: Vector3 = info.get("pos", Vector3.ZERO)
	if int(info.get("last_hitter", -1)) == 0 and int(info.get("bounces", 0)) == 1 and p.z < 0.0:
		_second_bounce = absf(p.z)


## The player's last stroke this rally ({} = none yet).
func last_stroke() -> Dictionary:
	return _last


func on_knocked(who: int) -> void:
	if who == 1:
		_knocked = true


## GameEvents.point. comeback: the player was 0:40 down; boosts: from the gear
## (StyleRules.evaluate, plus "cannon_kmh").
func on_point(info: Dictionary, comeback: bool, boosts := {}) -> Dictionary:
	var cc: Dictionary = info.get("close_call", {})
	var rally := int(info.get("rally", 0))
	var ctx := {
		"won": int(info.get("winner", -1)) == 0, "reason": String(info.get("reason", "")),
		"rally": rally, "serve_kmh": _serve_kmh, "last": _last, "labels": _labels,
		"line_margin": float(cc.get("margin", -1.0)) if int(cc.get("rally", -1)) == rally else -1.0,
		"opp_net_dist": _opp_dist, "second_bounce_z": _second_bounce, "knocked": _knocked,
		"comeback": comeback, "cannon_kmh": float(boosts.get("cannon_kmh", 200.0)),
	}
	var r := StyleRules.evaluate(ctx, boosts)
	r["rally"] = rally
	r["skill"] = String(_last.get("skill", ""))
	r["stroke_frame"] = _frame
	match_points += int(r["points"])
	if r["points"] > 0 and (best.is_empty() or r["points"] > best["points"] or (r["points"] == best["points"] and rally > best["rally"])):
		best = r
		best_index = _points
	_points += 1
	start_point()
	return r


## The match's style as run gold: a stylish match adds about half the round's prize.
func gold(reward: float, stage: int) -> int:
	return roundi(match_points * GOLD_PER_POINT * reward * (1.0 + GOLD_PER_ROUND * stage))
