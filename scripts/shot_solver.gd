class_name ShotSolver
## Finds a launch velocity that makes the ball land on a target point,
## given a desired pace and topspin, using the real flight model.
##
## The swipe/AI chooses *intent* (target, pace, spin); this solver turns it into
## physics; execution errors are applied by the caller on top. If the requested
## pace cannot land on target (too fast to come down in time / too slow to reach),
## pace is adjusted — like a real player taking pace off to make the shot.

const SIM_DT := 1.0 / 90.0
const ELEV_MIN := -20.0
const ELEV_MAX := 48.0
const BISECT_STEPS := 13


class Result:
	var velocity := Vector3.ZERO
	var spin := Vector3.ZERO
	var speed := 0.0
	var elevation_deg := 0.0
	var ok := false


## Returns Vector2(landing distance along dir, net clearance in meters).
static func _simulate(p0: Vector3, v0: Vector3, spin: Vector3, dir: Vector3) -> Vector2:
	var s := BallPhysics.State.new(p0, v0, spin)
	var clearance := INF
	var crossed := false
	var t := 0.0
	while t < 5.0:
		var prev_z := s.pos.z
		BallPhysics.integrate_free(s, SIM_DT)
		t += SIM_DT
		if not crossed and (prev_z > 0.0) != (s.pos.z > 0.0):
			crossed = true
			clearance = s.pos.y - BallPhysics.RADIUS - Court.net_height(s.pos.x)
		if s.pos.y <= BallPhysics.RADIUS and s.vel.y < 0.0:
			break
	if not crossed:
		# Landed before reaching the net (every shot here must cross it): treat as netted.
		clearance = -10.0
	var d := s.pos - p0
	d.y = 0.0
	return Vector2(d.dot(dir), clearance)


static func _launch(dir: Vector3, speed: float, elev_deg: float) -> Vector3:
	var e := deg_to_rad(elev_deg)
	return dir * (cos(e) * speed) + Vector3.UP * (sin(e) * speed)


## status: 0 = solved (elevation in out_elev[0]), +1 = too fast (overshoots), -1 = too slow.
static func _solve_elevation(p0: Vector3, dir: Vector3, dist: float, speed: float, spin: Vector3, net_margin: float, out_elev: Array) -> int:
	# 1) lowest elevation that clears the net with the margin
	var lo := ELEV_MIN
	var hi := ELEV_MAX
	var r_lo := _simulate(p0, _launch(dir, speed, lo), spin, dir)
	var elev_net := lo
	if r_lo.y < net_margin:
		var r_hi := _simulate(p0, _launch(dir, speed, hi), spin, dir)
		if r_hi.y < net_margin:
			return -1
		for i in BISECT_STEPS:
			var mid := (lo + hi) * 0.5
			if _simulate(p0, _launch(dir, speed, mid), spin, dir).y >= net_margin:
				hi = mid
			else:
				lo = mid
		elev_net = hi
	var d_net := _simulate(p0, _launch(dir, speed, elev_net), spin, dir).x
	if d_net > dist:
		return 1
	# 2) elevation in [elev_net, ELEV_MAX] that lands at dist (low-arc branch)
	lo = elev_net
	hi = ELEV_MAX
	if _simulate(p0, _launch(dir, speed, hi), spin, dir).x < dist:
		return -1
	for i in BISECT_STEPS:
		var mid := (lo + hi) * 0.5
		if _simulate(p0, _launch(dir, speed, mid), spin, dir).x < dist:
			lo = mid
		else:
			hi = mid
	out_elev[0] = (lo + hi) * 0.5
	return 0


## top_spin: rad/s, positive = topspin, negative = backspin (slice).
## side_spin (rad/s around the vertical) curves the ball sideways; the aim is corrected
## so it still lands on target.
static func solve(p0: Vector3, target: Vector3, speed: float, top_spin: float, net_margin := 0.12, side_spin := 0.0) -> Result:
	var res := _solve_straight(p0, target, speed, top_spin, net_margin, side_spin, Vector3.ZERO)
	if side_spin == 0.0:
		return res
	var aim := target
	for i in 2:
		var landing := _landing(p0, res.velocity, res.spin)
		aim += Vector3(target.x - landing.x, 0.0, target.z - landing.z)
		res = _solve_straight(p0, aim, speed, top_spin, net_margin, side_spin, Vector3.ZERO)
	return res


static func _landing(p0: Vector3, v0: Vector3, spin: Vector3) -> Vector3:
	var s := BallPhysics.State.new(p0, v0, spin)
	for i in 600:
		BallPhysics.integrate_free(s, SIM_DT)
		if s.pos.y <= BallPhysics.RADIUS and s.vel.y < 0.0:
			break
	return s.pos


static func _solve_straight(p0: Vector3, target: Vector3, speed: float, top_spin: float, net_margin: float, side_spin: float, _unused: Vector3) -> Result:
	var res := Result.new()
	var flat := target - p0
	flat.y = 0.0
	var dist := flat.length()
	if dist < 0.5:
		flat = Vector3(0, 0, -signf(p0.z) if p0.z != 0.0 else -1.0)
		dist = 1.0
	var dir := flat / dist
	var spin := BallPhysics.topspin_vector(dir, top_spin) + Vector3.UP * side_spin
	var spd := speed
	var elev := [0.0]
	for i in 30:
		var status := _solve_elevation(p0, dir, dist, spd, spin, net_margin, elev)
		if status == 0:
			res.ok = true
			break
		spd *= 0.92 if status > 0 else 1.08
		spd = clampf(spd, 5.0, 60.0)
	if not res.ok:
		elev[0] = 12.0
	res.speed = spd
	res.elevation_deg = elev[0]
	res.velocity = _launch(dir, spd, elev[0])
	res.spin = spin
	return res


## Lob: a high, slow arc. Elevation is fixed and the speed is solved for the distance.
## max_speed only caps the search; a lob is as slow as it needs to be.
static func solve_lob(p0: Vector3, target: Vector3, top_spin: float, max_speed := 30.0, elev_deg := 40.0) -> Result:
	var res := Result.new()
	var flat := target - p0
	flat.y = 0.0
	var dist := maxf(flat.length(), 1.0)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3(0, 0, -signf(p0.z))
	var spin := BallPhysics.topspin_vector(dir, top_spin)
	var lo := 5.0
	var hi := maxf(max_speed, 8.0)
	for i in 18:
		var mid := (lo + hi) * 0.5
		if _simulate(p0, _launch(dir, mid, elev_deg), spin, dir).x < dist:
			lo = mid
		else:
			hi = mid
	res.speed = (lo + hi) * 0.5
	res.elevation_deg = elev_deg
	res.velocity = _launch(dir, res.speed, elev_deg)
	res.spin = spin
	res.ok = true
	return res


## Drop shot: the lowest arc that still clears the net with the margin and lands on
## target. Lower is better (less time for the opponent), so elevations are tried from
## flat upward and the first safe one wins.
static func solve_drop(p0: Vector3, target: Vector3, top_spin: float, net_margin := 0.25) -> Result:
	var flat := target - p0
	flat.y = 0.0
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3(0, 0, -signf(p0.z))
	var best: Result = null
	var elev := 8.0
	while elev <= 66.0:
		var r := solve_lob(p0, target, top_spin, 40.0, elev)
		best = r
		if _simulate(p0, r.velocity, r.spin, dir).y >= net_margin:
			return r
		elev += 2.0
	return best
