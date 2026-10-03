class_name Athlete
extends Node3D
## A tennis player body: momentum-based movement plus a procedural placeholder
## rig (body, legs, head, arm + racket on a shoulder pivot).
## The racket swing is timed so the racket meets the ball at the contact moment
## and tilts toward the actual ball height (a first, very small step toward IK).
## Right-handed: forehand on the player's right side.

const REACH := 1.55            # max horizontal distance body -> ball at contact
const IDEAL_LATERAL := 0.75    # ideal sideways distance of the ball at contact
const CONTACT_FORWARD := 0.45  # contact point in front of the body
const IDEAL_HEIGHT := 0.95
const SHOULDER := Vector3(0.18, 1.32, 0.0)
const ARM_LEN := 1.05          # shoulder -> racket centre

# Racket yaw angles (rad) around the shoulder. 0 = racket pointing to the right side,
# +PI/2 = pointing forward, -PI/2 = pointing backward.
const YAW_READY := 0.75
const YAW_FH_PREP := -1.9
const YAW_FH_CONTACT := 0.25
const YAW_FH_FOLLOW := 2.6
const YAW_BH_PREP := 3.95
const YAW_BH_CONTACT := 2.85
const YAW_BH_FOLLOW := 0.9
const SWING_TO_CONTACT := 0.11
const FOLLOW_TIME := 0.22

var facing := -1.0             # -1 faces -Z (near player), +1 faces +Z (opponent)
var velocity := Vector3.ZERO
var max_speed := 6.2
var accel := 22.0
var decel := 30.0
var move_input := Vector2.ZERO # desired direction in world x/z, length 0..1
var area := Rect2(-9.0, 0.8, 18.0, 17.0)  # allowed region: x, z

var _model: Node3D
var _body: Node3D
var _legs: Array[Node3D] = []
var _pivot: Node3D
var _yaw := YAW_READY
var _yaw_target := YAW_READY
var _tilt := 0.0
var _tilt_target := 0.0
var _swinging := false
var _swing_clock := 0.0
var _swing_contact_at := 0.0
var _swing_side := 1
var _hop := 1.0
var _run_phase := 0.0
var _twist := 0.0


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
	return _swinging


func prepare(side: int) -> void:
	if not _swinging:
		_yaw_target = YAW_FH_PREP if side > 0 else YAW_BH_PREP
		_twist = -0.45 * side


func relax() -> void:
	if not _swinging:
		_yaw_target = YAW_READY
		_twist = 0.0


## Start a swing that reaches the contact pose after time_to_contact (game seconds).
func swing(side: int, time_to_contact: float, contact_height: float) -> void:
	_swinging = true
	_swing_side = side
	_swing_clock = 0.0
	_swing_contact_at = maxf(time_to_contact, 0.05)
	_tilt_target = asin(clampf((contact_height - SHOULDER.y) / ARM_LEN, -0.95, 0.95))
	if _swing_contact_at > SWING_TO_CONTACT:
		_yaw_target = YAW_FH_PREP if side > 0 else YAW_BH_PREP


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


func _process(delta: float) -> void:
	if _model == null:
		return
	var speed := velocity.length()

	# Locomotion: leg swing, bob, lean into the run direction
	_run_phase += delta * (4.0 + speed * 2.4)
	var amt := clampf(speed / 4.0, 0.0, 1.0)
	_legs[0].rotation.x = sin(_run_phase) * 0.7 * amt
	_legs[1].rotation.x = -sin(_run_phase) * 0.7 * amt
	var local_v := global_basis.inverse() * velocity
	_model.rotation.x = lerpf(_model.rotation.x, -local_v.z * 0.035, 1.0 - exp(-10.0 * delta))
	_model.rotation.z = lerpf(_model.rotation.z, -local_v.x * 0.03, 1.0 - exp(-10.0 * delta))
	var bob := absf(sin(_run_phase)) * 0.05 * amt
	if _hop < 1.0:
		_hop = minf(1.0, _hop + delta / 0.25)
		bob += sin(_hop * PI) * 0.12
	_model.position.y = bob

	# Racket swing timeline
	if _swinging:
		_swing_clock += delta
		var contact_yaw := YAW_FH_CONTACT if _swing_side > 0 else YAW_BH_CONTACT
		var follow_yaw := YAW_FH_FOLLOW if _swing_side > 0 else YAW_BH_FOLLOW
		var prep_yaw := YAW_FH_PREP if _swing_side > 0 else YAW_BH_PREP
		var start := _swing_contact_at - SWING_TO_CONTACT
		if _swing_clock < start:
			_yaw = lerpf(_yaw, prep_yaw, 1.0 - exp(-14.0 * delta))
		elif _swing_clock < _swing_contact_at:
			var u := clampf((_swing_clock - start) / SWING_TO_CONTACT, 0.0, 1.0)
			var from := prep_yaw if start > 0.0 else _yaw
			_yaw = lerpf(from, contact_yaw, u * u)
			_tilt = lerpf(_tilt, _tilt_target, u)
		else:
			var u := clampf((_swing_clock - _swing_contact_at) / FOLLOW_TIME, 0.0, 1.0)
			_yaw = lerpf(contact_yaw, follow_yaw, 1.0 - (1.0 - u) * (1.0 - u))
			_tilt = lerpf(_tilt_target, 0.5, u)
			if u >= 1.0:
				_swinging = false
				_yaw_target = YAW_READY
				_twist = 0.0
		_twist = (-0.5 if _swing_clock < _swing_contact_at else 0.6) * _swing_side
	else:
		_yaw = lerpf(_yaw, _yaw_target, 1.0 - exp(-9.0 * delta))
		_tilt = lerpf(_tilt, 0.0, 1.0 - exp(-6.0 * delta))
	_pivot.basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.BACK, _tilt)
	_body.rotation.y = lerpf(_body.rotation.y, _twist, 1.0 - exp(-12.0 * delta))


func _build(shirt: Color) -> void:
	_model = Node3D.new()
	add_child(_model)
	var skin := Color(0.93, 0.76, 0.62)

	# Ground shadow
	var sh := _mesh_cyl(0.35, 0.002, Color(0, 0, 0, 0.35), true)
	sh.position.y = 0.004
	add_child(sh)

	for sx in [-0.11, 0.11]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, 0.9, 0)
		_model.add_child(hip)
		var leg := _mesh_capsule(0.075, 0.9, Color(0.95, 0.95, 0.95))
		leg.position = Vector3(0, -0.45, 0)
		hip.add_child(leg)
		_legs.append(hip)

	_body = Node3D.new()
	_model.add_child(_body)
	var torso := _mesh_capsule(0.21, 0.75, shirt)
	torso.position = Vector3(0, 1.22, 0)
	_body.add_child(torso)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.12
	hm.height = 0.24
	head.mesh = hm
	head.material_override = _mat(skin)
	head.position = Vector3(0, 1.74, 0)
	_body.add_child(head)
	var cap := _mesh_cyl(0.125, 0.06, shirt.darkened(0.3))
	cap.position = Vector3(0, 1.83, 0)
	_body.add_child(cap)

	_pivot = Node3D.new()
	_pivot.position = SHOULDER
	_model.add_child(_pivot)
	var arm := _mesh_capsule(0.045, 0.6, skin)
	arm.rotation.z = PI * 0.5
	arm.position = Vector3(0.3, 0, 0)
	_pivot.add_child(arm)
	var handle := _mesh_capsule(0.018, 0.3, Color(0.1, 0.1, 0.1))
	handle.rotation.z = PI * 0.5
	handle.position = Vector3(0.7, 0, 0)
	_pivot.add_child(handle)
	var head_ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.105
	tm.outer_radius = 0.128
	tm.rings = 20
	tm.ring_segments = 6
	head_ring.mesh = tm
	head_ring.material_override = _mat(Color(0.15, 0.15, 0.2))
	head_ring.rotation.x = PI * 0.5
	head_ring.scale = Vector3(1.3, 1.0, 1.0)
	head_ring.position = Vector3(ARM_LEN, 0, 0)
	_pivot.add_child(head_ring)
	var strings := _mesh_cyl(0.105, 0.004, Color(0.95, 0.95, 0.9, 0.45), true)
	strings.rotation.x = PI * 0.5
	strings.scale = Vector3(1.3, 1.0, 1.0)
	strings.position = Vector3(ARM_LEN, 0, 0)
	_pivot.add_child(strings)


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
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 4
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
