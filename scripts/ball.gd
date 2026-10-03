class_name Ball
extends Node3D
## The ball node: owns the physics state, steps it with fixed substeps,
## and renders the ball plus a ground shadow (the main depth cue on a phone).

signal bounced(pos: Vector3, speed: float)
signal hit_net(pos: Vector3)

const VISUAL_SCALE := 2.3  # the real ball is tiny on a phone screen

var state := BallPhysics.State.new()
var active := false

var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _shadow_mat: StandardMaterial3D
var _spin_visual := Basis()


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BallPhysics.RADIUS * VISUAL_SCALE
	sm.height = sm.radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.95, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.4, 0.05)
	mat.roughness = 0.6
	_mesh.material_override = mat
	add_child(_mesh)

	_shadow = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = BallPhysics.RADIUS * VISUAL_SCALE * 1.1
	cm.bottom_radius = cm.top_radius
	cm.height = 0.002
	cm.radial_segments = 16
	_shadow.mesh = cm
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.albedo_color = Color(0, 0, 0, 0.5)
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = _shadow_mat
	_shadow.top_level = true
	add_child(_shadow)
	visible = false


func launch(pos: Vector3, vel: Vector3, spin: Vector3) -> void:
	state = BallPhysics.State.new(pos, vel, spin)
	active = true
	visible = true


func park() -> void:
	active = false
	visible = false


func step(delta: float) -> void:
	if not active:
		return
	var remaining := delta
	while remaining > 0.000001:
		var h := minf(remaining, BallPhysics.MAX_STEP)
		remaining -= h
		var impact_speed := state.vel.length()
		var ev := BallPhysics.substep(state, h)
		if ev == BallPhysics.Event.BOUNCE:
			bounced.emit(state.pos, impact_speed)
		elif ev == BallPhysics.Event.NET:
			hit_net.emit(state.pos)
		if not active:
			return


func speed_kmh() -> float:
	return state.vel.length() * 3.6


func spin_rpm() -> float:
	return state.spin.length() * 60.0 / TAU


func _process(delta: float) -> void:
	global_position = state.pos
	if state.spin.length() > 0.1:
		_spin_visual = Basis(state.spin.normalized(), state.spin.length() * delta) * _spin_visual
		_mesh.basis = _spin_visual.orthonormalized()
	var h := state.pos.y
	_shadow.global_position = Vector3(state.pos.x, 0.004, state.pos.z)
	var k := clampf(1.0 - h / 6.0, 0.25, 1.0)
	_shadow.scale = Vector3.ONE * (1.0 + (1.0 - k) * 1.2)
	_shadow_mat.albedo_color.a = 0.55 * k
	_shadow.visible = visible
