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
