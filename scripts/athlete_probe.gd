class_name AthleteProbe
## Geometry checks and scripted scenarios for the stance change (stream M). Used by
## tools/stance_shots.gd (contact sheets) and tests/anim_test.gd (checks): where the hands
## and elbows are relative to the torso, in the torso's own frame, frame by frame.
##
## The torso is the chest piece drawn from the pelvis to the shoulders: an ellipse about
## its axis (TORSO_A wide, TORSO_B deep), its back is the plane z = +TORSO_B in the
## chest's frame (+Z = behind the back). A hand, an elbow or a forearm's middle must
## stay outside that ellipse (R from the axis) and never go behind the back plane.

const TORSO_A := 0.22    # half width of the chest as drawn (m)
const TORSO_B := 0.15    # half depth
const THROUGH_Q := 0.9   # ellipse value below which a limb point is inside the trunk
const BEHIND_Z := 0.18   # a hand's centre this far behind the axis is behind the back plane
const BEHIND_W := 0.28   # ... when it is within this half width of the axis
const SCENARIOS := ["back", "fwd", "still", "side", "side_keep", "back_swing"]
const SWITCH_AT := 0.7   # seconds into a scenario where the stance changes
const SETTLE_AT := 0.2   # the first stance is taken at this moment


## The torso's frame as drawn: [yaw basis, pelvis point, chest point], model space.
static func torso(a: Athlete) -> Array:
	var ends: Array = a._ends["chest"]
	var yaw: float = lerpf(a._hip_twist, a._twist, 0.75) if a._body == Athlete.Body.TOON else a._twist
	return [Basis(Vector3.UP, yaw), ends[0], ends[1]]


## The limb points that must stay clear of the trunk, in model space: [name, point].
static func arm_points(a: Athlete) -> Array:
	var out := []
	for sd in ["r", "l"]:
		var up: Array = a._ends["upper_" + sd]
		var fo: Array = a._ends["fore_" + sd]
		var sh: Vector3 = up[0]
		var el: Vector3 = up[1]
		var hd: Vector3 = fo[1]
		out.append(["hand_" + sd, hd])
		out.append(["elbow_" + sd, el])
		out.append(["forearm_" + sd, el.lerp(hd, 0.5)])
		out.append(["upper_" + sd, sh.lerp(el, 0.75)])
	return out


## One point in the torso frame: x across, z behind (+), and q = the ellipse value
## (< 1 inside the trunk). Returns Vector3(x, z, q); q = 99 above or below the trunk.
static func in_torso_frame(t: Array, p: Vector3) -> Vector3:
	var pel: Vector3 = t[1]
	var chest: Vector3 = t[2]
	if p.y < pel.y - 0.1 or p.y > chest.y + 0.12:
		return Vector3(0.0, 0.0, 99.0)
	var ctr := pel.lerp(chest, clampf((p.y - pel.y) / maxf(chest.y - pel.y, 0.01), 0.0, 1.0))
	var lp: Vector3 = (t[0] as Basis).inverse() * Vector3(p.x - ctr.x, 0.0, p.z - ctr.z)
	return Vector3(lp.x, lp.z, (lp.x / TORSO_A) * (lp.x / TORSO_A) + (lp.z / TORSO_B) * (lp.z / TORSO_B))


## What is wrong right now: Array of "name:kind" with kind "through" (inside the trunk),
## "behind" (round behind the back plane). Empty when the arms are clear. Arms in the
## serve (trophy, racket drop) and a dive are out of scope and return [].
static func problems(a: Athlete) -> Array:
	var bad := []
	if a._down >= 0.0 or ((a._mode == 2 or a._mode == 3) and a._serve_style()) or a._mode == 3:
		return bad
	var t := torso(a)
	for item in arm_points(a):
		var f := in_torso_frame(t, item[1])
		if f.z >= 99.0:
			continue
		if f.z < THROUGH_Q:
			bad.append("%s:%s" % [item[0], "behind" if f.y > 0.0 else "through"])
		elif f.y > BEHIND_Z and absf(f.x) < BEHIND_W:
			bad.append("%s:behind" % item[0])
	return bad


# --- Scenarios -------------------------------------------------------------------

## Where a scenario starts (world), on the baseline side with room to run.
static func start_of(sc: String) -> Vector3:
	return Vector3(0.0, 0.0, 14.0) if sc == "fwd" else Vector3(0.0, 0.0, 8.0)


## Applies a scenario's inputs at frame f (60 per second). `first` is the side taken
## first (1 forehand, -1 backhand); at SWITCH_AT it flips.
static func drive(a: Athlete, sc: String, f: int, first: int) -> void:
	var run := Vector2.ZERO
	match sc:
		"back", "back_swing":
			run = Vector2(0, 1)       # +Z is back from the net for the near player
		"fwd":
			run = Vector2(0, -1)
		"side", "side_keep":
			run = Vector2(1, 0)
	var sw := roundi(SWITCH_AT * 60.0)
	if f == 0:
		a.move_input = run
	if f == roundi(SETTLE_AT * 60.0):
		a.prepare(first)
	if f == sw:
		a.prepare(-first)
		if sc == "side":
			a.move_input = -run       # the ball went to the other wing: turn round and go there
	if sc == "back_swing" and f == sw + 18:
		var c := Vector3(-0.72 * first, 0.95, -0.42)
		a.swing(-first, 0.25, a.to_global(c), Athlete.Style.TOPSPIN)
