class_name ShotPlanner
extends RefCounted
## The CPU's choice of shot, made once per hit (HANDOFF 9.5, 7.6): from where the player
## stands, how stretched they are, how good our own contact is and whether the ball is
## short, pick a tactic and a target. Pure: a situation and a play style in, a plan out.
##
## Situation (Dictionary): q (our contact 0..1), skill (0..1), me (our position), contact,
##   player (their position), player_vel, player_contact (where they hit their last ball
##   from), player_q (how well they hit it), volley (we take it out of the air), short
##   (the ball sat up inside our baseline), rally (hits so far), bh_x (x sign of the
##   player's backhand side), bh_weak (-1..1, + = their backhand is the weaker wing).
## Style: Opponents.PLAY_STYLES entry.
## Plan: kind, tx, tz (target on the player's half), pace, top, lob, drop, approach (come
##   in / stay at the net after it), risk (extra error chance of going for it).

const NET_Z := 6.5                # the player is "at the net" in front of this
const DEEP_Z := 12.3              # the player is "deep" from here (0.4 m behind the line) ..
const DEEP_SPAN := 1.7            # .. fully deep this much further back
const WIDE_X := 2.2               # the player is pulled wide past this ..
const WIDE_HIT_X := 3.0           # .. or had to hit their last ball from out here
const WEAK_Q := 0.5               # their last ball was weak below this contact quality
const WIDTH := 3.7                # how close to the sideline a target may go
const VARIETY_DROP := 0.04        # a calm rally ball becomes a drop shot with style.drop x this
const KINDS := ["defend", "volley", "lob", "pass", "drop", "approach", "attack", "neutral", "change"]


static func choose(sit: Dictionary, style: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var q: float = sit.get("q", 0.7)
	var s: float = sit.get("skill", 0.5)
	var me: Vector3 = sit.get("me", Vector3(0, 0, -12.4))
	var pl: Vector3 = sit.get("player", Vector3(0, 0, 12.6))
	var pv: Vector3 = sit.get("player_vel", Vector3.ZERO)
	var pace_k: float = style.get("pace", 1.0)
	var base_pace := lerpf(22.0, 32.0, s) * rng.randf_range(0.88, 1.1) * pace_k
	var open_side := -signf(pl.x) if absf(pl.x) > 0.8 else (1.0 if rng.randf() < 0.5 else -1.0)
	var plan := {"kind": "neutral", "tx": 0.0, "tz": 9.5, "pace": base_pace, "top": rng.randf_range(160.0, 300.0),
		"lob": false, "drop": false, "approach": false, "risk": 0.0}

	# 1. Stretched or a poor contact: buy time. High, deep, central; a lob over a net rusher.
	if q < 0.45:
		plan["kind"] = "defend"
		if pl.z < NET_Z and rng.randf() < float(style.get("lob", 0.4)):
			return _lob(plan, rng)
		plan["tx"] = rng.randf_range(-1.5, 1.5)
		plan["tz"] = rng.randf_range(8.0, 10.0)
		plan["pace"] = rng.randf_range(18.0, 21.0)
		plan["top"] = 240.0
		return plan

	# 2. At the net: punch the volley into the open court, short and angled; stay in.
	if sit.get("volley", false) or me.z > -NET_Z:
		plan["kind"] = "volley"
		plan["tx"] = open_side * rng.randf_range(2.0, WIDTH)
		plan["tz"] = rng.randf_range(4.5, 8.0) if pl.z > NET_Z else rng.randf_range(5.0, 7.0)
		plan["pace"] = lerpf(20.0, 28.0, s) * pace_k
		plan["top"] = 60.0
		plan["approach"] = true
		plan["risk"] = 0.02
		return plan

	# 3. The player came in: lob over them or pass them down the open side.
	if pl.z < NET_Z:
		if rng.randf() < float(style.get("lob", 0.4)):
			return _lob(plan, rng)
		plan["kind"] = "pass"
		plan["tx"] = (-signf(pl.x) if absf(pl.x) > 0.3 else open_side) * rng.randf_range(2.8, WIDTH)
		plan["tz"] = rng.randf_range(6.0, 9.0)
		plan["pace"] = base_pace * 1.1
		plan["risk"] = 0.03
		return plan

	var contact: Vector3 = sit.get("contact", me)
	var inside := contact.z > -12.2 or me.z > -11.5  # on or inside our baseline
	# 4. The player camped far behind the baseline and we are inside: drop shot.
	var deep := clampf((pl.z - DEEP_Z) / DEEP_SPAN, 0.0, 1.0)
	if q >= 0.6 and inside and deep > 0.0 and rng.randf() < float(style.get("drop", 0.2)) * deep:
		return _drop(plan, open_side, s, rng)
	# 4b. Every match has a few: a drop shot out of a calm rally, whoever the player is (D-5).
	if q >= 0.7 and inside and sit.get("rally", 0) >= 3 and rng.randf() < float(style.get("drop", 0.2)) * VARIETY_DROP:
		return _drop(plan, open_side, s, rng)

	# 5. A short ball: approach shot deep (to the weaker wing, or down the line) and come in.
	var net_k: float = sit.get("net_k", 1.0)  # the net stat: how keen it is to come in
	if sit.get("short", false) and q >= 0.55 and rng.randf() < float(style.get("approach", 0.3)) * net_k * lerpf(0.6, 1.0, q):
		plan["kind"] = "approach"
		plan["tx"] = _side_to(sit, style, open_side, rng) * rng.randf_range(2.0, 3.4)
		plan["tz"] = rng.randf_range(8.6, 10.6)
		plan["pace"] = base_pace * 1.03
		plan["approach"] = true
		plan["risk"] = 0.02
		return plan

	# 6. The player is pulled wide (standing there, running, or just hit from out there),
	# or their last ball was weak: go for the open court.
	var pc: Vector3 = sit.get("player_contact", pl)
	var pulled := absf(pl.x) > WIDE_X or absf(pv.x) > 3.0 or absf(pc.x) > WIDE_HIT_X
	var weak := float(sit.get("player_q", 0.7)) < WEAK_Q
	var go := float(style.get("aggr", 0.5)) * (1.0 if pulled else (0.45 if weak else 0.0))
	if q >= 0.6 and rng.randf() < go:
		plan["kind"] = "attack"
		var ref := pl.x if absf(pl.x) > 0.5 else (pc.x if absf(pc.x) > 0.5 else pv.x)
		var away := -signf(ref) if absf(ref) > 0.01 else open_side
		plan["tx"] = away * rng.randf_range(2.6, WIDTH)
		plan["tz"] = rng.randf_range(7.4, 10.4)
		plan["pace"] = base_pace * 1.1
		plan["approach"] = rng.randf() < (float(style.get("approach", 0.3)) * 0.5 + float(style.get("net_rush", 0.0))) * net_k
		plan["risk"] = 0.03 * float(style.get("risk", 1.0))
		return plan

	# 7. Neutral: patience (cross-court from a corner), a change of direction now and then,
	# the weaker wing once it is known.
	plan["kind"] = "neutral"
	var side := open_side
	if absf(pl.x) <= 0.8 and absf(me.x) > 1.0 and rng.randf() < float(style.get("patience", 0.6)):
		side = -signf(me.x)  # cross-court: more net to clear in the middle, more court on the diagonal
	elif rng.randf() < float(style.get("change", 0.3)):
		side = -side
		plan["kind"] = "change"
	if rng.randf() < float(style.get("read", 0.5)) * clampf(float(sit.get("bh_weak", 0.0)), 0.0, 1.0):
		side = float(sit.get("bh_x", -1.0))  # their weaker backhand
	plan["tx"] = side * lerpf(1.2, 3.6, rng.randf() * (0.4 + s * 0.6))
	plan["tz"] = lerpf(6.8, 10.8, clampf(rng.randf_range(0.3, 1.0) * (0.55 + 0.45 * s), 0.0, 1.0))
	if q >= 0.7 and rng.randf() < float(style.get("net_rush", 0.0)) * net_k:
		plan["kind"] = "approach"
		plan["tz"] = maxf(plan["tz"], 8.8)
		plan["approach"] = true
	return plan


static func _drop(plan: Dictionary, open_side: float, s: float, rng: RandomNumberGenerator) -> Dictionary:
	plan["kind"] = "drop"
	plan["tx"] = clampf(open_side * rng.randf_range(0.5, 2.5), -2.5, 2.5)
	plan["tz"] = rng.randf_range(1.6, 2.6)
	plan["pace"] = 9.0
	plan["top"] = -280.0
	plan["drop"] = true
	plan["approach"] = rng.randf() < 0.5  # follow it in to cover the reply
	plan["risk"] = lerpf(0.06, 0.02, s)
	return plan


static func _lob(plan: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	plan["kind"] = "lob"
	plan["lob"] = true
	plan["tx"] = rng.randf_range(-2.5, 2.5)
	plan["tz"] = rng.randf_range(9.0, 10.8)
	plan["pace"] = 30.0
	plan["top"] = 220.0
	plan["risk"] = 0.02
	return plan


## Which side to send an approach to: the weaker wing if it is known, else down the line.
static func _side_to(sit: Dictionary, style: Dictionary, open_side: float, rng: RandomNumberGenerator) -> float:
	if rng.randf() < float(style.get("read", 0.5)) * clampf(float(sit.get("bh_weak", 0.0)), 0.0, 1.0):
		return float(sit.get("bh_x", -1.0))
	var me: Vector3 = sit.get("me", Vector3.ZERO)
	return signf(me.x) if absf(me.x) > 0.5 and rng.randf() < 0.5 else open_side  # down the line
