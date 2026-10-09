class_name Footwork
## The player's auto-positioning picks the wing (Main._update_player_movement): with time
## to spare, a ball coming to the backhand near the middle is run around and taken on the
## forehand (the inside-out forehand), like the pros do; a wide backhand stays a backhand.
## Old debt from main.gd (HANDOFF 7.6).

const RUN_AROUND_MAX := 1.6       # m: how far to the backhand side of the body a ball may be
const SPARE_TIME := 0.35          # s: time left over after getting to the forehand stance


## Which wing to set up for: `side` is the natural one (+1 forehand, -1 backhand from
## where the ball meets the body), `lateral` the ball's sideways offset from the body (+ =
## forehand side), `fh_dist` the run to the forehand stance (m), `t_contact` the time left.
static func auto_side(side: int, lateral: float, fh_dist: float, t_contact: float, max_speed: float) -> int:
	if side > 0:
		return side
	if -lateral > RUN_AROUND_MAX or t_contact > 5.0:
		return side
	if fh_dist / maxf(max_speed, 0.1) + SPARE_TIME <= t_contact:
		return 1
	return side


## D-10: a drop shot (or any short ball) lands in front of the player and never reaches the contact
## plane, so `t_contact` stays INF and the auto-positioning (Main._update_player_movement) stood
## still — the point was lost with the ball in plain sight. Returns where to run to meet such a
## ball (the point of its fall between the bounces), or Vector3.INF if the ball is not that kind:
## it has bounced on the player's half and ends its prediction in front of `plane_z` (the contact
## plane, `player.z - CONTACT_FORWARD`): after its second bounce, or hanging (< HANG_SPEED m/s along
## the court) while the 2.5 s of the prediction run out before the second one.
const HANG_SPEED := 3.0           # m/s: slower along the court than this, and it hangs
const HANG_GAP := 0.6             # m: it ends at least this far in front of the plane (else the plane gets it)
const HANG_NET_GAP := 0.3         # m: and on the near side of the net
static var chase := true          # --no-chase (the bot): the way it was before D-10, for the before/after numbers
const LONG_LOOK := 4.5            # s: how far ahead a short ball is followed to its second bounce

## `state` is the ball now: a drop is seen 2.5 s ahead only up to its first bounce, the second
## comes later, so the prediction is run longer here (this is rare: only a short ball gets so far).
static func hanging_contact(pred: BallPhysics.Prediction, plane_z: float, state: BallPhysics.State = null) -> Vector3:
	if not chase or pred == null or pred.points.size() < 3 or pred.bounce_indices.is_empty():
		return Vector3.INF
	if pred.bounce_points[0].z < HANG_NET_GAP:
		return Vector3.INF  # it bounced on the other side: not ours yet
	if pred.bounce_indices.size() < 2 and state != null and pred.points[pred.points.size() - 1].z < plane_z - HANG_GAP:
		pred = BallPhysics.predict(state, LONG_LOOK, 1.0 / 90.0, 2)
	var pts := pred.points
	var n := pts.size()
	var last := pts[n - 1]
	if last.z < HANG_NET_GAP or last.z > plane_z - HANG_GAP or absf(last.x) > Court.DOUBLES_HALF_WIDTH:
		return Vector3.INF
	if pred.bounce_indices.size() < 2:
		var dt := maxf(pred.times[n - 1] - pred.times[n - 2], 0.0001)
		if (last.z - pts[n - 2].z) / dt > HANG_SPEED:
			return Vector3.INF
	# the fall between the bounces through chest height; otherwise the last point
	var from: int = pred.bounce_indices[0]
	for i in range(from + 1, n - 1):
		if pts[i].y >= 0.5 and pts[i].y <= 1.3 and pts[i + 1].y < pts[i].y and pts[i].z < plane_z - HANG_GAP:
			return pts[i]
	return last
