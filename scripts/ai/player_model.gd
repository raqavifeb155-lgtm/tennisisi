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
