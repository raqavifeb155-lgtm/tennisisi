class_name BallPhysics
## Tennis ball flight model: gravity, quadratic drag, Magnus lift, spin decay,
## impulse-based bounce with court friction (spin <-> velocity exchange), net collision.
##
## Spin is an angular velocity vector in rad/s. For a ball travelling along
## horizontal direction d, topspin is UP.cross(d) * magnitude.

const RADIUS := 0.033
const MASS := 0.057
const GRAVITY := 9.81
const AIR_DENSITY := 1.21
const DRAG_CD := 0.55
const LIFT_GAIN := 1.0
const AREA := PI * RADIUS * RADIUS
const K_DRAG := 0.5 * AIR_DENSITY * DRAG_CD * AREA / MASS
const K_MAGNUS := 0.5 * AIR_DENSITY * AREA * RADIUS * LIFT_GAIN / MASS
const SPIN_DECAY := 0.05
const COURT_FRICTION := 0.62
const ROLL_DECEL := 1.5
const MAX_STEP := 1.0 / 240.0

enum Event { NONE, BOUNCE, NET }


class State:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var rolling := false

	func _init(p := Vector3.ZERO, v := Vector3.ZERO, s := Vector3.ZERO) -> void:
		pos = p
		vel = v
		spin = s

	func copy() -> State:
		var c := State.new(pos, vel, spin)
		c.rolling = rolling
		return c


class Prediction:
	var points := PackedVector3Array()
	var times := PackedFloat32Array()
	var bounce_points := PackedVector3Array()
	var bounce_times := PackedFloat32Array()
	var bounce_indices := PackedInt32Array()
	var net_hit := false


static func acceleration(vel: Vector3, spin: Vector3) -> Vector3:
	return Vector3(0.0, -GRAVITY, 0.0) - K_DRAG * vel.length() * vel + K_MAGNUS * spin.cross(vel)


## Free flight only (no collisions). Used by the shot solver.
static func integrate_free(s: State, h: float) -> void:
	s.vel += acceleration(s.vel, s.spin) * h
	s.pos += s.vel * h
	s.spin *= 1.0 - SPIN_DECAY * h


## Advances the state by h seconds (callers keep h <= MAX_STEP for accuracy). Returns an Event.
static func substep(s: State, h: float) -> int:
	if s.rolling:
		var hv := Vector3(s.vel.x, 0.0, s.vel.z)
		var sp := maxf(0.0, hv.length() - ROLL_DECEL * h)
		s.vel = hv.normalized() * sp if hv.length() > 0.0001 else Vector3.ZERO
		s.pos += s.vel * h
		s.pos.y = RADIUS
		return Event.NONE

	var prev := s.pos
	integrate_free(s, h)

	# Net: the ball centre crossed z = 0 below the net top.
	if (prev.z > 0.0) != (s.pos.z > 0.0):
		var t := prev.z / (prev.z - s.pos.z)
		var cross := prev.lerp(s.pos, t)
		if absf(cross.x) <= Court.NET_HALF_WIDTH and cross.y - RADIUS < Court.net_height(cross.x):
			var side := 1.0 if prev.z > 0.0 else -1.0
			s.pos = Vector3(cross.x, maxf(cross.y, RADIUS), side * (RADIUS + 0.01))
			s.vel = Vector3(s.vel.x * 0.25, minf(s.vel.y, 0.0) * 0.2, -s.vel.z * 0.08)
			s.spin *= 0.2
			return Event.NET

	if s.pos.y < RADIUS and s.vel.y < 0.0:
		s.pos.y = RADIUS
		bounce(s)
		return Event.BOUNCE
	return Event.NONE


## Bounce with normal restitution and Coulomb friction at the contact point.
## The ball is treated as a thin spherical shell (I = 2/3 m r^2), so stopping the
## contact-point slip needs a tangential impulse of |slip| / 2.5 (per unit mass).
static func bounce(s: State) -> void:
	var vn := -s.vel.y
	var e := clampf(0.84 - 0.010 * vn, 0.6, 0.82)
	var vt := Vector3(s.vel.x, 0.0, s.vel.z)
	var slip := vt + s.spin.cross(Vector3(0.0, -RADIUS, 0.0))
	var jn := (1.0 + e) * vn
	var jt := minf(COURT_FRICTION * jn, slip.length() / 2.5)
	var dvt := Vector3.ZERO
	if slip.length() > 0.00001:
		dvt = -slip.normalized() * jt
	s.vel = vt + dvt + Vector3(0.0, e * vn, 0.0)
	s.spin += Vector3.UP.cross(dvt) * (-1.5 / RADIUS)
	if e * vn < 0.35:
		s.vel.y = 0.0
		s.rolling = true


## Simulates forward from a copy of start. Stops after max_bounces bounces, when rolling, or at max_time.
static func predict(start: State, max_time: float, dt := 1.0 / 120.0, max_bounces := 2) -> Prediction:
	var s := start.copy()
	var p := Prediction.new()
	var t := 0.0
	p.points.append(s.pos)
	p.times.append(0.0)
	while t < max_time:
		var ev := substep(s, dt)
		t += dt
		p.points.append(s.pos)
		p.times.append(t)
		if ev == Event.BOUNCE:
			p.bounce_points.append(s.pos)
			p.bounce_times.append(t)
			p.bounce_indices.append(p.points.size() - 1)
			if p.bounce_points.size() >= max_bounces:
				break
		elif ev == Event.NET:
			p.net_hit = true
		if s.rolling:
			break
	return p


static func topspin_vector(direction: Vector3, rad_per_sec: float) -> Vector3:
	var d := Vector3(direction.x, 0.0, direction.z).normalized()
	return Vector3.UP.cross(d) * rad_per_sec
