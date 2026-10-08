class_name PlayerModel
extends RefCounted
## What the opponent has learned about the player this match (HANDOFF 9.4, 9.5): where
## they serve into each box, and (D-3) their rally habits. Old observations fade, so a
## player who changes their pattern is read again in a few points. Forgotten between
## matches (reset on GameEvents.match_started).

const FADE := 0.8                 # each new serve into a box: the older ones count x0.8
const PRIOR := 1.0                # pseudo-count per direction: no lean before evidence

## box side (-1 / 1) -> {"wide", "body", "T"} weights
var serves := {}


func reset() -> void:
	serves = {}
	reset_wings()


## A serve of the player bounced in the box on `box_side` (x sign of the box), `x_across`
## metres from the centre line (0 = the T, 4.1 = the sideline).
func note_serve(box_side: float, x_across: float) -> void:
	var key := int(signf(box_side))
	var w: Dictionary = serves.get(key, {"wide": 0.0, "body": 0.0, "T": 0.0})
	for d in w:
		w[d] *= FADE
	var dir := AiMetrics.serve_dir(x_across)
	w[dir] += 1.0
	serves[key] = w


## -1 (expects the T) .. +1 (expects wide), for serves into the box on `box_side`.
func wide_bias(box_side: float) -> float:
	var w: Dictionary = serves.get(int(signf(box_side)), {})
	if w.is_empty():
		return 0.0
	var total: float = w["wide"] + w["body"] + w["T"] + 3.0 * PRIOR
	return (w["wide"] - w["T"]) / total


# --- Rally habits (D-3) ---------------------------------------------------------

const WING_FADE := 0.97           # older strokes count a little less
const WING_MIN := 6.0             # strokes seen before a weaker wing is trusted

## +1 forehand / -1 backhand -> {"n", "q", "err"} (faded counts)
var wings := {1: {"n": 0.0, "q": 0.0, "err": 0.0}, -1: {"n": 0.0, "q": 0.0, "err": 0.0}}


func reset_wings() -> void:
	wings = {1: {"n": 0.0, "q": 0.0, "err": 0.0}, -1: {"n": 0.0, "q": 0.0, "err": 0.0}}


## The player hit a rally ball with this wing (+1 forehand, -1 backhand), quality q.
func note_stroke(side: int, q: float) -> void:
	var key := 1 if side >= 0 else -1
	for k in wings:
		for f in wings[k]:
			wings[k][f] *= WING_FADE
	wings[key]["n"] += 1.0
	wings[key]["q"] += q


## That wing's last ball was an error (out or into the net).
func note_error(side: int) -> void:
	wings[1 if side >= 0 else -1]["err"] += 1.0


## -1 (the forehand is the weaker wing) .. +1 (the backhand is): from the error rate and
## the contact quality of each wing; 0 until enough strokes are seen.
func backhand_weakness() -> float:
	var f: Dictionary = wings[1]
	var b: Dictionary = wings[-1]
	if f["n"] + b["n"] < WING_MIN or f["n"] < 1.0 or b["n"] < 1.0:
		return 0.0
	var ef: float = (f["err"] + 0.5) / (f["n"] + 3.0)
	var eb: float = (b["err"] + 0.5) / (b["n"] + 3.0)
	var qf: float = f["q"] / f["n"]
	var qb: float = b["q"] / b["n"]
	return clampf((eb - ef) * 3.0 + (qf - qb) * 2.0, -1.0, 1.0)
