class_name Athlete
extends Node3D
## A tennis player: momentum-based movement plus a procedural rig.
##
## The rig is built from simple capsules but moves like a body: two-bone IK arms
## (shoulder -> elbow -> hand) and legs (hip -> knee -> foot), a torso that turns for
## the unit turn and unwinds through the shot, and a racket held in the hand.
## Each stroke has its own racket path, reaching the real contact point on time:
##   topspin  low-to-high, finishing over the opposite shoulder
##   flat     level through the ball, finishing across the chest
##   slice    high-to-low, the racket face open, finishing out toward the net
##   smash / serve  trophy pose, racket drop behind the back, up and through, down across
## Right-handed: forehand on the player's right side. Local space: forward = -Z, right = +X.

enum Style { TOPSPIN, FLAT, SLICE, SMASH, SERVE }

const REACH := 1.55            # max horizontal distance body -> ball at contact
const IDEAL_LATERAL := 0.75    # ideal sideways distance of the ball at contact
const CONTACT_FORWARD := 0.45  # contact point in front of the body
const IDEAL_HEIGHT := 0.95

const HIP_H := 0.92
const THIGH := 0.46
const SHIN := 0.46
const SHOULDER_H := 1.42
const SHOULDER_W := 0.2
const UPPER_ARM := 0.3
const FOREARM := 0.28
const RACKET_REACH := 0.52     # hand -> racket head centre
const SWING_TO_CONTACT := 0.16
const FOLLOW_TIME := 0.26

var facing := -1.0             # -1 faces -Z (near player), +1 faces +Z (opponent)
var velocity := Vector3.ZERO
var max_speed := 6.2
var accel := 22.0
var decel := 30.0
var move_input := Vector2.ZERO # desired direction in world x/z, length 0..1
var area := Rect2(-9.0, 0.8, 18.0, 17.0)  # allowed region: x, z

# Pose state (model-local): racket hand position + racket direction, left hand, torso twist
var _hand := Vector3(0.25, 1.05, -0.35)
var _rdir := Vector3(-0.4, 0.5, -0.8).normalized()
var _lhand := Vector3(0.1, 1.1, -0.4)
var _twist := 0.0
var _crouch := 0.06

var _mode := 0                 # 0 ready, 1 prepared, 2 swinging, 3 serve setup
var _side := 1
var _style := Style.TOPSPIN
var _clock := 0.0
var _contact_at := 0.0
var _contact_h := 1.0
var _swing_from_hand := Vector3.ZERO
var _swing_from_dir := Vector3.ZERO

var _hop := 1.0
var _run_phase := 0.0

# Visual nodes
var _model: Node3D
var _bones := {}
var _racket: Node3D
var _head: MeshInstance3D


func setup(face: float, shirt: Color, region: Rect2) -> void:
	facing = face
	area = region
	_build(shirt)
	rotation.y = 0.0 if facing < 0.0 else PI


func right() -> Vector3:
	return Vector3(-facing, 0.0, 0.0)


func forward() -> Vector3:
	return Vector3(0.0, 0.0, facing)


## Signed sideways offset of p relative to the body: + = forehand side.
func lateral_of(p: Vector3) -> float:
	return (p - global_position).dot(right())


## Where the body should stand to meet a ball at contact point p on the given side.
func stance_for(p: Vector3, side: int) -> Vector3:
	var s := p - right() * (IDEAL_LATERAL * side) - forward() * CONTACT_FORWARD
	s.y = 0.0
	return s


func is_swinging() -> bool:
	return _mode == 2


## Unit turn toward the side the ball is coming to.
func prepare(side: int, style := Style.TOPSPIN) -> void:
	if _mode == 2:
		return
	_mode = 1
	_side = side
	_style = style


## Serve setup: sideways stance, tossing arm ready.
func prepare_serve() -> void:
	if _mode == 2:
		return
	_mode = 3
	_side = 1
	_style = Style.SERVE


func relax() -> void:
	if _mode != 2:
		_mode = 0


## Start a swing that reaches the contact pose after time_to_contact (game seconds).
func swing(side: int, time_to_contact: float, contact_height: float, style := Style.TOPSPIN) -> void:
	_mode = 2
	_side = side
	_style = style
	_clock = 0.0
	_contact_at = maxf(time_to_contact, 0.05)
	_contact_h = contact_height
	_swing_from_hand = _hand
	_swing_from_dir = _rdir


func split_step() -> void:
	_hop = 0.0


func _physics_process(delta: float) -> void:
	var target_v := Vector3(move_input.x, 0.0, move_input.y).limit_length(1.0) * max_speed
	var speeding_up := target_v.length() > velocity.length() and target_v.dot(velocity) >= 0.0
	var rate := accel if speeding_up else decel
	velocity += (target_v - velocity).limit_length(rate * delta)
	var p := position + velocity * delta
	var cx := clampf(p.x, area.position.x, area.end.x)
	var cz := clampf(p.z, area.position.y, area.end.y)
	if cx != p.x:
		velocity.x = 0.0
	if cz != p.z:
		velocity.z = 0.0
	position = Vector3(cx, 0.0, cz)


# --- Stroke keyframes ------------------------------------------------------------

## Racket hand position and racket direction for a named phase of a stroke, in model space.
## side mirrors x (forehand +1, backhand -1).
func _key(style: int, phase: String, side: int, h: float) -> Array:
	var s := float(side)
	var hand: Vector3
	var dir: Vector3
	match style:
		Style.SMASH, Style.SERVE:
			match phase:
				"prep":
					hand = Vector3(0.38, 1.55, 0.25)
					dir = Vector3(0.15, 0.75, 0.6)
				"drop":
					hand = Vector3(0.32, 1.85, 0.28)
					dir = Vector3(0.05, -0.9, 0.45)
				"contact":
					hand = Vector3(0.3, h - RACKET_REACH * 0.95, -0.3)
					dir = Vector3(0.05, 1.0, -0.25)
				_:
					hand = Vector3(-0.35, 0.85, -0.3)
					dir = Vector3(-0.35, -0.75, -0.45)
			return [hand, dir.normalized()]
		Style.SLICE:
			match phase:
				"prep":
					hand = Vector3(0.42 * s, 1.45, 0.38)
					dir = Vector3(0.25 * s, 0.85, 0.45)
				"drop":
					hand = Vector3(0.4 * s, maxf(h + 0.2, 0.9), 0.12)
					dir = Vector3(0.75 * s, 0.35, 0.3)
				"contact":
					dir = Vector3(1.0 * s, 0.18, -0.25)
					hand = _contact_point(s, h) - dir.normalized() * RACKET_REACH
				_:
					hand = Vector3(0.0, 0.8, -0.7)
					dir = Vector3(0.35 * s, -0.05, -1.0)
			return [hand, dir.normalized()]
		Style.FLAT:
			match phase:
				"prep":
					hand = Vector3(0.5 * s, 1.15, 0.45)
					dir = Vector3(0.25 * s, 0.35, 0.9)
				"drop":
					hand = Vector3(0.48 * s, h, 0.15)
					dir = Vector3(0.6 * s, 0.05, 0.7)
				"contact":
					dir = Vector3(1.0 * s, 0.03, -0.25)
					hand = _contact_point(s, h) - dir.normalized() * RACKET_REACH
				_:
					hand = Vector3(-0.42 * s, 1.15, -0.4)
					dir = Vector3(-0.65 * s, 0.15, 0.6)
			return [hand, dir.normalized()]
		_:  # TOPSPIN
			match phase:
				"prep":
					hand = Vector3(0.48 * s, 1.05, 0.45)
					dir = Vector3(0.2 * s, 0.35, 0.95)
				"drop":
					hand = Vector3(0.45 * s, maxf(h - 0.4, 0.45), 0.12)
					dir = Vector3(0.55 * s, -0.55, 0.55)
				"contact":
					dir = Vector3(1.0 * s, -0.05, -0.25)
					hand = _contact_point(s, h) - dir.normalized() * RACKET_REACH
				_:
					hand = Vector3(-0.32 * s, 1.6, -0.15)
					dir = Vector3(-0.3 * s, 0.35, 0.9)
			return [hand, dir.normalized()]


func _contact_point(s: float, h: float) -> Vector3:
	return Vector3(IDEAL_LATERAL * s, clampf(h, 0.3, 2.0), -CONTACT_FORWARD)


func _process(delta: float) -> void:
	if _model == null:
		return
	var speed := velocity.length()
	var k := 1.0 - exp(-12.0 * delta)

	# --- Racket arm, left arm, torso ---
	if _mode == 2:
		_clock += delta
		var start := _contact_at - SWING_TO_CONTACT
		var prep: Array = _key(_style, "prep", _side, _contact_h)
		var drop: Array = _key(_style, "drop", _side, _contact_h)
		var con: Array = _key(_style, "contact", _side, _contact_h)
		var fol: Array = _key(_style, "follow", _side, _contact_h)
		if _clock < start:
			# Still loading: settle into the backswing.
			_hand = _hand.lerp(prep[0], k)
			_rdir = _rdir.lerp(prep[1], k).normalized()
			_twist = lerpf(_twist, -0.75 * _side, k)
		elif _clock < _contact_at:
			var u := clampf((_clock - start) / SWING_TO_CONTACT, 0.0, 1.0)
			var from_h: Vector3 = prep[0] if start > 0.0 else _swing_from_hand
			var from_d: Vector3 = prep[1] if start > 0.0 else _swing_from_dir
			var e := u * u * (3.0 - 2.0 * u)
			# Racket path: from the backswing through the drop to the ball (a curve, not a line).
			if e < 0.5:
				var w := e * 2.0
				_hand = from_h.cubic_interpolate(drop[0], from_h, con[0], w)
				_rdir = from_d.lerp(drop[1], w).normalized()
			else:
				var w := (e - 0.5) * 2.0
				_hand = (drop[0] as Vector3).cubic_interpolate(con[0], from_h, fol[0], w)
				_rdir = (drop[1] as Vector3).lerp(con[1], w).normalized()
			_twist = lerpf(-0.75 * _side, 0.0, e)
		else:
			var u := clampf((_clock - _contact_at) / FOLLOW_TIME, 0.0, 1.0)
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			_hand = (con[0] as Vector3).cubic_interpolate(fol[0], drop[0], fol[0], e)
			_rdir = (con[1] as Vector3).lerp(fol[1], e).normalized()
			_twist = lerpf(0.0, 0.7 * _side, e)
			if u >= 1.0:
				_mode = 0
	else:
		var target: Array
		var t_twist := 0.0
		match _mode:
			1:
				target = _key(_style, "prep", _side, IDEAL_HEIGHT)
				t_twist = -0.75 * _side
			3:
				target = _key(Style.SERVE, "prep", 1, 2.6)
				t_twist = -0.9
			_:
				target = [Vector3(0.22, 1.02, -0.38), Vector3(-0.45, 0.55, -0.7).normalized()]
		var kk := 1.0 - exp(-9.0 * delta)
		_hand = _hand.lerp(target[0], kk)
		_rdir = _rdir.lerp(target[1], kk).normalized()
		_twist = lerpf(_twist, t_twist, kk)

	# Left hand: on the throat in ready/backhand, pointing at the ball in the forehand
	# unit turn, up in the air for the toss, tucked in on the follow-through.
	var lh := _hand + _rdir * 0.18 + Vector3(-0.06, 0.0, 0.0)
	if _mode == 3 or (_mode == 2 and (_style == Style.SERVE or _style == Style.SMASH) and _clock < _contact_at):
		lh = Vector3(0.0, 1.95, -0.42)
	elif (_mode == 1 or (_mode == 2 and _clock < _contact_at)) and _side > 0:
		lh = Vector3(0.25, 1.3, -0.5)
	elif _mode == 2 and _clock >= _contact_at:
		lh = Vector3(-0.3, 1.05, 0.05) if _side > 0 else Vector3(-0.5, 1.2, 0.2)
	_lhand = _lhand.lerp(lh, k)

	# --- Legs and body ---
	_run_phase += delta * (5.0 + speed * 2.2)
	var amt := clampf(speed / 4.0, 0.0, 1.0)
	var target_crouch := 0.06 + (0.08 if _mode == 1 or _mode == 2 else 0.0) - amt * 0.03
	if _mode == 3:
		target_crouch = 0.04
	_crouch = lerpf(_crouch, target_crouch, k)
	var lift := 0.0
	if _hop < 1.0:
		_hop = minf(1.0, _hop + delta / 0.28)
		lift = sin(_hop * PI) * 0.13
	var bob := absf(sin(_run_phase)) * 0.04 * amt
	_model.position.y = lift + bob

	var local_v := global_basis.inverse() * velocity
	_model.rotation.x = lerpf(_model.rotation.x, -local_v.z * 0.03, k)
	_model.rotation.z = lerpf(_model.rotation.z, -local_v.x * 0.025, k)

	_pose(local_v, amt)


func _pose(local_v: Vector3, amt: float) -> void:
	var hip_y := HIP_H - _crouch
	var tw := Basis(Vector3.UP, _twist)
	var pelvis := Vector3(0, hip_y, 0)
	var chest := Vector3(0, SHOULDER_H - _crouch * 0.6, 0)
	var r_sh := chest + tw * Vector3(SHOULDER_W, 0, 0)
	var l_sh := chest + tw * Vector3(-SHOULDER_W, 0, 0)

	# Legs: feet step along the running direction, knees bend forward.
	var stride := Vector3(local_v.x, 0, local_v.z).normalized() * 0.32 * amt if amt > 0.05 else Vector3.ZERO
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var phase := _run_phase + (0.0 if i == 0 else PI)
		var hip := pelvis + tw * Vector3(0.11 * sgn, 0, 0) * 0.5 + Vector3(0.11 * sgn, 0, 0) * 0.5
		var foot := Vector3(0.17 * sgn, 0.05, 0.0) + stride * sin(phase)
		foot.y += maxf(0.0, cos(phase)) * 0.14 * amt
		var knee := _ik(hip, foot, THIGH, SHIN, hip + Vector3(0, 0, -1.0))
		var foot_reached := _reach(hip, knee, foot, SHIN)
		_set_bone("thigh%d" % i, hip, knee)
		_set_bone("shin%d" % i, knee, foot_reached)
		_set_bone("shoe%d" % i, foot_reached + Vector3(0, -0.02, 0.02), foot_reached + Vector3(0, -0.02, -0.12))

	_set_bone("torso", pelvis + Vector3(0, 0.05, 0), chest + Vector3(0, -0.06, 0))
	_set_bone("shorts", pelvis + Vector3(-0.12, -0.02, 0), pelvis + Vector3(0.12, -0.02, 0))
	_set_bone("shoulders", l_sh, r_sh)
	_head.position = chest + Vector3(0, 0.3, 0)
	_head.rotation.y = _twist * 0.4

	# Racket arm: hand on its path, elbow down and out.
	var elbow := _ik(r_sh, _hand, UPPER_ARM, FOREARM, r_sh + Vector3(0.4, -0.9, 0.35))
	var hand := _reach(r_sh, elbow, _hand, FOREARM)
	_set_bone("upper_r", r_sh, elbow)
	_set_bone("fore_r", elbow, hand)
	var l_elbow := _ik(l_sh, _lhand, UPPER_ARM, FOREARM, l_sh + Vector3(-0.4, -0.9, 0.2))
	_set_bone("upper_l", l_sh, l_elbow)
	_set_bone("fore_l", l_elbow, _reach(l_sh, l_elbow, _lhand, FOREARM))

	# Racket: handle along the racket direction, face turned toward the shot (open for slice).
	var y := _rdir
	var face := Vector3(0, 0, -1)
	if _style == Style.SLICE:
		face = Vector3(0, 0.45, -1)
	face = (face - y * face.dot(y))
	if face.length() < 0.05:
		face = Vector3(0, 1, 0) - y * y.y
	face = face.normalized()
	var x := y.cross(face).normalized()
	_racket.transform = Transform3D(Basis(x, y, x.cross(y)), hand)


## Two-bone IK: returns the middle joint for a chain root -> joint -> end reaching target.
func _ik(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d := target - root
	var dist := clampf(d.length(), 0.02, l1 + l2 - 0.002)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var c := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var perp := pole - root
	perp -= dir * perp.dot(dir)
	if perp.length() < 0.0001:
		perp = Vector3.FORWARD - dir * dir.dot(Vector3.FORWARD)
	perp = perp.normalized()
	return root + dir * (l1 * c) + perp * (l1 * sqrt(1.0 - c * c))


## End of the chain: the target if reachable, otherwise as far as the limb allows.
func _reach(_root: Vector3, joint: Vector3, target: Vector3, l2: float) -> Vector3:
	var d := target - joint
	return joint + d.normalized() * l2 if d.length() > 0.0001 else joint + Vector3.DOWN * l2


func _set_bone(bone: String, a: Vector3, b: Vector3) -> void:
	var mi: MeshInstance3D = _bones[bone]
	var d := b - a
	var len := d.length()
	if len < 0.0001:
		return
	var y := d / len
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	# Limb lengths are fixed by the IK; only rebuild a mesh when its length really changes.
	var cm := mi.mesh as CapsuleMesh
	var h := len + cm.radius * 2.0
	if absf(cm.height - h) > 0.015:
		cm.height = h


# --- Build ----------------------------------------------------------------------

func _build(shirt: Color) -> void:
	_model = Node3D.new()
	add_child(_model)
	var skin := Color(0.93, 0.76, 0.62)
	var shorts := Color(0.14, 0.15, 0.2)
	var white := Color(0.96, 0.96, 0.96)

	var sh := _mesh_cyl(0.38, 0.002, Color(0, 0, 0, 0.35), true)
	sh.position.y = 0.04
	add_child(sh)

	for i in 2:
		_bone_mesh("thigh%d" % i, 0.075, skin)
		_bone_mesh("shin%d" % i, 0.062, white)
		_bone_mesh("shoe%d" % i, 0.055, white.darkened(0.15))
	_bone_mesh("torso", 0.2, shirt)
	_bone_mesh("shorts", 0.14, shorts)
	_bone_mesh("shoulders", 0.085, shirt)
	_bone_mesh("upper_r", 0.055, shirt.lightened(0.1))
	_bone_mesh("fore_r", 0.045, skin)
	_bone_mesh("upper_l", 0.055, shirt.lightened(0.1))
	_bone_mesh("fore_l", 0.045, skin)

	_head = MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.12
	hm.height = 0.24
	_head.mesh = hm
	_head.material_override = _mat(skin)
	_model.add_child(_head)
	var cap := _mesh_cyl(0.125, 0.06, shirt.darkened(0.3))
	cap.position = Vector3(0, 0.09, 0)
	_head.add_child(cap)
	var visor := _mesh_cyl(0.09, 0.015, shirt.darkened(0.3))
	visor.position = Vector3(0, 0.07, -0.1)
	_head.add_child(visor)

	# Racket: local +Y runs from the hand to the head; the face lies in the XY plane.
	_racket = Node3D.new()
	_model.add_child(_racket)
	var handle := _mesh_capsule(0.016, 0.3, Color(0.1, 0.1, 0.1))
	handle.position = Vector3(0, 0.13, 0)
	_racket.add_child(handle)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.105
	tm.outer_radius = 0.128
	tm.rings = 20
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = _mat(Color(0.15, 0.15, 0.2))
	ring.basis = Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 1.3))
	ring.position = Vector3(0, RACKET_REACH - 0.02, 0)
	_racket.add_child(ring)
	var strings := _mesh_cyl(0.105, 0.004, Color(0.95, 0.95, 0.9, 0.45), true)
	strings.basis = ring.basis
	strings.position = ring.position
	_racket.add_child(strings)


func _bone_mesh(bone: String, r: float, c: Color) -> void:
	var mi := _mesh_capsule(r, 0.3, c)
	_model.add_child(mi)
	_bones[bone] = mi


func _mat(c: Color, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh_capsule(r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0 + 0.01)
	cm.radial_segments = 10
	cm.rings = 3
	mi.mesh = cm
	mi.material_override = _mat(c)
	return mi


func _mesh_cyl(r: float, h: float, c: Color, transparent := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = _mat(c, transparent)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
