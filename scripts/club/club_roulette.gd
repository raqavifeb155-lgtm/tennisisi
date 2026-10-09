class_name ClubRoulette
extends Node3D
## The Totalizator's wheel at the club's bar (HANDOFF 9.1): a 3D roulette with 37 pockets
## (0 = the net, odd blue, even red - Bets.color_of) and a real tennis ball that runs on
## our ball physics. The bet's logic is Bets' (stream A): the field is drawn first, the
## spin only shows it.
##
## How the ball lands on a field drawn in advance, honestly: the whole run is simulated
## before it plays, with BallPhysics (flight: integrate_free, every touch of the bowl, the
## cone or the spinning pocket floor: bounce, in the frame of that surface). The wheel is
## 37 identical pockets, so the run is the same whatever whole number of pockets the
## wheel is turned by; the wheel is then turned so that the pocket the ball settled in is
## the drawn field. Nothing is nudged.
##
## Local frame: the wheel's centre at the origin, y up, angles about +y
## (p = (cos a, 0, -sin a)), as Godot turns nodes.

signal finished

const R_OUT := 0.95           # the bowl's wall (inside)
const R_CONE_IN := 0.62       # where the cone ends and the pocket ring begins
const R_HUB := 0.40           # the hub in the middle (a little court on top)
const CONE_DEG := 14.0
const CONE_Y0 := 0.06         # the cone's lower edge, above the pocket floor
const FLOOR_Y := 0.0
const FRET_H := 0.032         # the pockets' separators
const DEFLECTORS := 8         # little bumps on the cone that make the ball jump
const DEFLECTOR_R := 0.79
const H := 1.0 / 240.0        # physics step (BallPhysics.MAX_STEP)
const REC := 4                # a frame recorded every REC steps (60 per second)
const RIM_DECEL := 0.85       # m/s^2: the ball rubbing along the wall
const SPIN_W0 := 2.0          # the wheel's spin at the start, rad/s
const SPIN_TAU := 9.0         # its slow-down (s)
const LOCK_AFTER := 0.25      # s at rest in a pocket
const MAX_T := 6.5            # a run is decided by then at the latest
const TAIL := 1.0             # s of the wheel turning on with the ball in its pocket

static var STEP := TAU / Bets.FIELDS

var _wheel: Node3D
var _ball: MeshInstance3D
var _sim := {}
var _t := -1.0


static func field_color(i: int) -> String:
	return Bets.color_of(i)


static func cone_y(r: float) -> float:
	return CONE_Y0 + (r - R_CONE_IN) * tan(deg_to_rad(CONE_DEG))


static func wheel_angle(t: float) -> float:
	return SPIN_W0 * SPIN_TAU * (1.0 - exp(-t / SPIN_TAU))


static func wheel_speed(t: float) -> float:
	return SPIN_W0 * exp(-t / SPIN_TAU)


static func angle_of(p: Vector3) -> float:
	return atan2(-p.z, p.x)


static func at_angle(a: float, r: float, y: float) -> Vector3:
	return Vector3(cos(a) * r, y, -sin(a) * r)


## The pocket under a ball at `p` while the wheel is turned by `wheel`.
static func pocket_at(p: Vector3, wheel: float) -> int:
	return posmod(roundi((angle_of(p) - wheel) / STEP), Bets.FIELDS)


## The whole run, decided before it plays. Returns {frames: ball positions, spins: ball
## spin, wheel: the wheel's angle per frame, dt, field, bounces, lock: frame}.
static func simulate(field: int, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var frames := PackedVector3Array()
	var spins := PackedVector3Array()
	var times := PackedFloat32Array()
	var tan_a := tan(deg_to_rad(CONE_DEG))
	var cos_a := cos(deg_to_rad(CONE_DEG))
	var r_rim := R_OUT - BallPhysics.RADIUS
	var a := rng.randf_range(0.0, TAU)
	var u := -rng.randf_range(3.0, 3.7)              # along the rim, against the wheel
	var s := BallPhysics.State.new(at_angle(a, r_rim, cone_y(r_rim) + BallPhysics.RADIUS / cos_a))
	var on_rim := true
	var bounces := 0
	var rest := 0.0
	var lock_rel := INF                              # the pocket's angle on the wheel once settled
	var lock_frame := -1
	var lock_from := Vector3.ZERO
	var t := 0.0
	var step := 0
	var end_t := INF
	var deflect_cool := 0.0
	while t < end_t:
		var w := wheel_angle(t)
		var wv := wheel_speed(t)
		if lock_rel != INF:
			# Settled: the ball rides in its pocket (eased onto the pocket's middle).
			var k := clampf((t - times[lock_frame]) / 0.2, 0.0, 1.0)
			var home := at_angle(lock_rel + w, (R_HUB + R_CONE_IN) * 0.5, FLOOR_Y + BallPhysics.RADIUS)
			var from := at_angle(angle_of(lock_from) - wheel_angle(times[lock_frame]) + w, Vector2(lock_from.x, lock_from.z).length(), lock_from.y)
			s.pos = from.lerp(home, k * k * (3.0 - 2.0 * k))
			s.vel = Vector3.ZERO
			s.spin = Vector3.ZERO
		elif on_rim:
			# 1. Along the wall: rubbing and air slow it; when it's too slow for the
			# banking it leaves the wall and runs down the cone.
			u += -signf(u) * (RIM_DECEL + BallPhysics.K_DRAG * u * u) * H
			a += u / r_rim * H
			s.pos = at_angle(a, r_rim, cone_y(r_rim) + BallPhysics.RADIUS / cos_a)
			var tangent := Vector3(-sin(a), 0.0, -cos(a))       # d(at_angle)/da
			s.vel = tangent * u
			s.spin = Vector3.UP.cross(s.vel) / BallPhysics.RADIUS  # rolling without slipping
			if u * u / r_rim < BallPhysics.GRAVITY * tan_a:
				on_rim = false
				s.vel -= at_angle(a, 1.0, 0.0) * 0.2  # off the wall, down the cone
		else:
			_free_step(s, t, w, wv, tan_a, cos_a)
			var r := Vector2(s.pos.x, s.pos.z).length()
			deflect_cool -= H
			# The cone's deflectors: a bump that throws the ball up.
			if r > DEFLECTOR_R - 0.035 and r < DEFLECTOR_R + 0.035 and deflect_cool <= 0.0:
				var ang := angle_of(s.pos)
				var nearest := roundf(ang / (TAU / DEFLECTORS)) * (TAU / DEFLECTORS)
				if absf(angle_difference(ang, nearest)) * r < 0.03 and s.pos.y - BallPhysics.RADIUS < cone_y(r) + 0.012:
					var ht := Vector3(s.vel.x, 0.0, s.vel.z)
					s.vel.y = absf(s.vel.y) * 0.3 + 0.25 + ht.length() * rng.randf_range(0.18, 0.32)
					s.vel.x *= 0.85
					s.vel.z *= 0.85
					s.vel += at_angle(ang, 1.0, 0.0) * rng.randf_range(-0.25, 0.1)
					deflect_cool = 0.15
					bounces += 1
			bounces += _consume_bounce(s)
			# 3-4. In the pocket ring: at rest against the floor long enough -> settled.
			if r < R_CONE_IN:
				var floor_v := Vector3(s.pos.z, 0.0, -s.pos.x) * wv
				var rel := s.vel - floor_v
				if s.pos.y < FLOOR_Y + BallPhysics.RADIUS + 0.004 and Vector2(rel.x, rel.z).length() < 0.09 and absf(s.vel.y) < 0.1:
					rest += H
				else:
					rest = 0.0
			else:
				rest = 0.0
			if rest >= LOCK_AFTER or (t >= MAX_T and r < R_CONE_IN):
				lock_rel = roundf((angle_of(s.pos) - w) / STEP) * STEP
				lock_frame = maxi(frames.size() - 1, 0)
				lock_from = s.pos
				end_t = t + TAIL
			elif t >= MAX_T + 1.0:
				# Still on the cone (never seen in tests): drop it into the nearest pocket.
				lock_rel = roundf((angle_of(s.pos) - w) / STEP) * STEP
				lock_frame = maxi(frames.size() - 1, 0)
				lock_from = at_angle(angle_of(s.pos), R_CONE_IN - BallPhysics.RADIUS, FLOOR_Y + BallPhysics.RADIUS)
				end_t = t + TAIL
		if step % REC == 0:
			frames.append(s.pos)
			spins.append(s.spin)
			times.append(t)
		step += 1
		t += H
	# Turn the wheel by whole pockets so the settled pocket is the drawn field.
	var p0 := posmod(roundi(lock_rel / STEP), Bets.FIELDS)
	var w0 := float(p0 - field) * STEP
	var wheel := PackedFloat32Array()
	for tt in times:
		wheel.append(wheel_angle(tt) + w0)
	return {"frames": frames, "spins": spins, "wheel": wheel, "dt": H * REC, "field": field,
		"bounces": bounces, "lock": lock_frame}


## One step of the ball off the rim: flight by BallPhysics, then every surface it touches.
static func _free_step(s: BallPhysics.State, _t: float, w: float, wv: float, tan_a: float, cos_a: float) -> void:
	var prev := s.pos
	BallPhysics.integrate_free(s, H)
	var rad := BallPhysics.RADIUS
	var flat := Vector2(s.pos.x, s.pos.z)
	var r := flat.length()
	var rhat := Vector3(s.pos.x / maxf(r, 0.0001), 0.0, s.pos.z / maxf(r, 0.0001))
	# The bowl's wall.
	if r > R_OUT - rad:
		s.pos = Vector3(rhat.x * (R_OUT - rad), s.pos.y, rhat.z * (R_OUT - rad))
		var vr := s.vel.dot(rhat)
		if vr > 0.0:
			s.vel -= rhat * vr * 1.5
		r = R_OUT - rad
	# The hub.
	if r < R_HUB + rad:
		s.pos = Vector3(rhat.x * (R_HUB + rad), s.pos.y, rhat.z * (R_HUB + rad))
		var vr := s.vel.dot(rhat)
		if vr < 0.0:
			s.vel -= rhat * vr * 1.45
		r = R_HUB + rad
	if r >= R_CONE_IN:
		# 2. The cone (still): its normal leans inward.
		var n := (Vector3.UP - rhat * tan_a).normalized()
		var d := (s.pos.y - cone_y(r)) * cos_a
		if d < rad:
			s.pos += n * (rad - d)
			if s.vel.dot(n) < 0.0:
				_bounce(s, n, Vector3.ZERO)
				# Rolling on the cloth: rolling resistance along the surface.
				var vt := s.vel - n * s.vel.dot(n)
				var l := vt.length()
				if l > 0.0001:
					s.vel -= vt / l * minf(l, BallPhysics.ROLL_DECEL * 0.5 * H)
	else:
		# The pocket ring's outer wall (the cone's lower edge).
		if r > R_CONE_IN - rad and s.pos.y - rad < CONE_Y0:
			s.pos = Vector3(rhat.x * (R_CONE_IN - rad), s.pos.y, rhat.z * (R_CONE_IN - rad))
			var vr := s.vel.dot(rhat)
			if vr > 0.0:
				s.vel -= rhat * vr * 1.4
		var floor_v := Vector3(s.pos.z, 0.0, -s.pos.x) * wv
		# The frets: crossing one low down knocks the ball back and up.
		if s.pos.y - rad < FLOOR_Y + FRET_H:
			var a0 := angle_of(prev) - w
			var a1 := angle_of(s.pos) - w
			var b0 := floorf(a0 / STEP + 0.5)
			var b1 := floorf(a1 / STEP + 0.5)
			if b0 != b1 and absf(a1 - a0) < PI:
				var rel := s.vel - floor_v
				var tang := Vector3(-rhat.z, 0.0, rhat.x)   # perpendicular to the radius
				var vt := rel.dot(tang)
				s.vel -= tang * vt * 1.35
				s.vel.y = maxf(s.vel.y, 0.0) + absf(vt) * 0.45
				s.pos = Vector3(prev.x, s.pos.y, prev.z)
				s.set_meta("bounced", int(s.get_meta("bounced", 0)) + (1 if absf(vt) > 0.25 else 0))
		# The pocket floor turns with the wheel: the bounce is in its frame.
		if s.pos.y < FLOOR_Y + rad:
			s.pos.y = FLOOR_Y + rad
			if s.vel.y < 0.0:
				_bounce(s, Vector3.UP, floor_v)
				# Rolling on the floor: a little resistance on the speed over the floor.
				var rel := s.vel - floor_v
				var rel_h := Vector3(rel.x, 0.0, rel.z)
				var l := rel_h.length()
				if l > 0.0001 and absf(s.vel.y) < 0.05:
					s.vel -= rel_h / l * minf(l, BallPhysics.ROLL_DECEL * 1.2 * H)


## BallPhysics.bounce in the frame of a surface with normal `n` moving at `surf_v`.
static func _bounce(s: BallPhysics.State, n: Vector3, surf_v: Vector3) -> void:
	var b := Basis(Quaternion(Vector3.UP, n)) if n.dot(Vector3.UP) < 0.9999 else Basis.IDENTITY
	var inv := b.inverse()
	var loc := BallPhysics.State.new(Vector3.ZERO, inv * (s.vel - surf_v), inv * s.spin)
	var vn := -loc.vel.y
	BallPhysics.bounce(loc)
	s.vel = b * loc.vel + surf_v
	s.spin = b * loc.spin
	if vn > 0.3:
		s.set_meta("bounced", int(s.get_meta("bounced", 0)) + 1)


static func _consume_bounce(s: BallPhysics.State) -> int:
	var n := int(s.get_meta("bounced", 0))
	if n > 0:
		s.set_meta("bounced", 0)
	return n


# --- The 3D wheel ---------------------------------------------------------------------

func _ready() -> void:
	_build()


func _build() -> void:
	var tinted := ClubMaterial.tinted()
	# The bowl: wall and cone (still), one mesh.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 48
	var wood := ClubMaterial.PALETTE[ClubMaterial.WOOD_DARK]
	var felt := Color(0.16, 0.36, 0.27)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		_quad(st, at_angle(a0, R_CONE_IN, cone_y(R_CONE_IN)), at_angle(a1, R_CONE_IN, cone_y(R_CONE_IN)),
			at_angle(a1, R_OUT, cone_y(R_OUT)), at_angle(a0, R_OUT, cone_y(R_OUT)), felt, Vector3.UP)
		_quad(st, at_angle(a0, R_OUT, cone_y(R_OUT)), at_angle(a1, R_OUT, cone_y(R_OUT)),
			at_angle(a1, R_OUT, cone_y(R_OUT) + 0.12), at_angle(a0, R_OUT, cone_y(R_OUT) + 0.12), wood.lightened(0.1), -at_angle(a0, 1.0, 0.0))
		_quad(st, at_angle(a0, R_OUT, cone_y(R_OUT) + 0.12), at_angle(a1, R_OUT, cone_y(R_OUT) + 0.12),
			at_angle(a1, R_OUT + 0.14, cone_y(R_OUT) + 0.12), at_angle(a0, R_OUT + 0.14, cone_y(R_OUT) + 0.12), wood, Vector3.UP)
		_quad(st, at_angle(a0, R_OUT + 0.14, cone_y(R_OUT) + 0.12), at_angle(a1, R_OUT + 0.14, cone_y(R_OUT) + 0.12),
			at_angle(a1, R_OUT + 0.14, -0.1), at_angle(a0, R_OUT + 0.14, -0.1), wood.darkened(0.15), at_angle(a0, 1.0, 0.0))
	for k in DEFLECTORS:
		var a := TAU * k / DEFLECTORS
		var c := at_angle(a, DEFLECTOR_R, cone_y(DEFLECTOR_R) + 0.004)
		var t := Vector3(-sin(a), 0, -cos(a)) * 0.022
		var rr := at_angle(a, 1.0, 0.0) * 0.03
		_quad(st, c - t - rr, c + t - rr, c + t + rr + Vector3.UP * 0.012, c - t + rr + Vector3.UP * 0.012, UiTheme.GOLD)
	st.generate_normals()
	var bowl := MeshInstance3D.new()
	bowl.mesh = st.commit()
	bowl.material_override = tinted
	bowl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bowl)
	# The wheel: pockets, frets and the hub, turning together.
	_wheel = Node3D.new()
	add_child(_wheel)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := {"blue": Color(0.27, 0.47, 0.86), "red": Color(0.86, 0.32, 0.3), "net": Color(0.2, 0.55, 0.35)}
	for i in Bets.FIELDS:
		var a0 := (i - 0.5) * STEP
		var a1 := (i + 0.5) * STEP
		var col: Color = cols[field_color(i)]
		_quad(st, at_angle(a0, R_HUB, FLOOR_Y), at_angle(a1, R_HUB, FLOOR_Y), at_angle(a1, R_CONE_IN, FLOOR_Y), at_angle(a0, R_CONE_IN, FLOOR_Y), col)
		# The pocket's back wall up to the cone's edge, in the field's colour, darker.
		_quad(st, at_angle(a1, R_CONE_IN, FLOOR_Y), at_angle(a0, R_CONE_IN, FLOOR_Y), at_angle(a0, R_CONE_IN, CONE_Y0), at_angle(a1, R_CONE_IN, CONE_Y0), col.darkened(0.3), -at_angle(a0, 1.0, 0.0))
		# The fret on the pocket's edge: a thin silver blade.
		var e0 := at_angle(a0, R_HUB, FLOOR_Y)
		var e1 := at_angle(a0, R_CONE_IN, FLOOR_Y)
		var up := Vector3.UP * FRET_H
		var side := Vector3(-sin(a0), 0, -cos(a0)) * 0.004
		_quad(st, e0 - side, e1 - side, e1 - side + up, e0 - side + up, Color(0.85, 0.86, 0.88), -side)
		_quad(st, e1 + side, e0 + side, e0 + side + up, e1 + side + up, Color(0.85, 0.86, 0.88), side)
		_quad(st, e0 - side + up, e1 - side + up, e1 + side + up, e0 + side + up, Color(0.95, 0.95, 0.96))
	# The hub: a little green court with white lines (the net is the "net" field's mark).
	var hub_h := 0.07
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		_quad(st, at_angle(a1, R_HUB, FLOOR_Y), at_angle(a0, R_HUB, FLOOR_Y), at_angle(a0, R_HUB, hub_h), at_angle(a1, R_HUB, hub_h), Color(0.85, 0.86, 0.88), at_angle(a0, 1.0, 0.0))
		_tri(st, Vector3(0, hub_h, 0), at_angle(a0, R_HUB, hub_h), at_angle(a1, R_HUB, hub_h), Color(0.2, 0.55, 0.35), Vector3.UP)
	var lw := 0.012
	var lines := [[Vector3(-0.14, 0, -0.26), Vector3(0.14, 0, -0.26)], [Vector3(-0.14, 0, 0.26), Vector3(0.14, 0, 0.26)],
		[Vector3(-0.14, 0, -0.26), Vector3(-0.14, 0, 0.26)], [Vector3(0.14, 0, -0.26), Vector3(0.14, 0, 0.26)],
		[Vector3(-0.17, 0, 0), Vector3(0.17, 0, 0)]]
	for l in lines:
		var p0: Vector3 = l[0] + Vector3.UP * (hub_h + 0.002)
		var p1: Vector3 = l[1] + Vector3.UP * (hub_h + 0.002)
		var dir := (p1 - p0).normalized()
		var off := Vector3(-dir.z, 0, dir.x) * lw
		_quad(st, p0 - off, p1 - off, p1 + off, p0 + off, Color.WHITE)
	st.generate_normals()
	var wheel_mesh := MeshInstance3D.new()
	wheel_mesh.mesh = st.commit()
	wheel_mesh.material_override = tinted
	wheel_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wheel.add_child(wheel_mesh)
	# The ball: a tennis ball, with its seam so the spin shows.
	_ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BallPhysics.RADIUS
	sm.height = BallPhysics.RADIUS * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	_ball.mesh = sm
	_ball.material_override = ClubMaterial.get_mat(Color(0.86, 0.95, 0.3), false)
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var seam := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = BallPhysics.RADIUS * 0.98
	tm.outer_radius = BallPhysics.RADIUS * 1.04
	tm.rings = 12
	tm.ring_segments = 3
	seam.mesh = tm
	seam.material_override = ClubMaterial.get_mat(Color(0.97, 0.97, 0.92), false)
	seam.rotation = Vector3(0.5, 0, 0.3)
	_ball.add_child(seam)
	_ball.position = at_angle(0.3, R_HUB + 0.1, FLOOR_Y + BallPhysics.RADIUS)
	_wheel.add_child(_ball)  # resting in a pocket until the first spin


## A quad facing `facing` (front faces are clockwise seen from the front in Godot).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, facing := Vector3.UP) -> void:
	_tri(st, a, b, c, col, facing)
	_tri(st, a, c, d, col, facing)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, facing: Vector3) -> void:
	st.set_color(col)
	if (b - a).cross(c - a).dot(facing) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Plays a run decided by simulate(). `finished` when the ball has settled.
func play(sim: Dictionary) -> void:
	_sim = sim
	_t = 0.0
	if _ball.get_parent() != self:
		_ball.reparent(self, false)


func busy() -> bool:
	return _t >= 0.0


## Straight to the end (a tap): the same result, no waiting.
func skip() -> void:
	if _t < 0.0:
		return
	_t = INF
	_process(0.0)


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var frames: PackedVector3Array = _sim["frames"]
	var wheel: PackedFloat32Array = _sim["wheel"]
	var dt: float = _sim["dt"]
	var f := minf(_t / dt, float(frames.size()))   # skip() sets INF: int(INF) is not the last frame on every CPU
	var i := mini(int(f), frames.size() - 1)
	var j := mini(i + 1, frames.size() - 1)
	var k := clampf(f - i, 0.0, 1.0)
	_wheel.rotation.y = lerpf(wheel[i], wheel[j], k)
	_ball.position = frames[i].lerp(frames[j], k)
	var spins: PackedVector3Array = _sim["spins"]
	var sp: Vector3 = spins[i]
	if sp.length() > 0.01:
		_ball.rotate(sp.normalized(), sp.length() * delta)
	if i >= frames.size() - 1:
		# Settled: the ball stays in its pocket and turns with the wheel from now on.
		_t = -1.0
		_ball.reparent(_wheel, true)
		finished.emit()
