class_name ClubNpcWorkers
extends Node3D
## Two builders for a lot's build moment (docs/superpowers/specs/2026-10-09-tycoon.md 1.5,
## the first of the club's NPCs; T-2 adds the coach's walks and the hired players on the
## same light figures): the people of ClubCrowd's meshes (a body and legs with a head, two
## MultiMeshes), an orange vest and a yellow hard hat each. They walk in to the front of
## the lot, hammer, wave and walk off. Nothing here is an Athlete: four draw calls.

const VEST := Color("f08a3c")
const HAT := Color("ffd642")
const SPEED := 4.2            # m/s on the way in
const SPEED_OUT := 5.0        # and running off

var _body: MultiMeshInstance3D
var _legs: MultiMeshInstance3D
var _hats: MultiMeshInstance3D
var _centre := Vector3.ZERO
var _phase := "away"          # "in", "work", "out", "away"
var _t := 0.0
var _clock := 0.0
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []


## Builders stand by at the sides of the lot (not shown yet).
func start(centre: Vector3) -> void:
	_centre = centre
	_body = _mm(ClubCrowd._body_mesh(), VEST)
	_legs = _mm(ClubCrowd._legs_mesh(), Color.WHITE)
	var hat := ClubShapes.new()
	hat.ball(0.17, Vector3(0, 1.84, 0), Color.WHITE, Vector3(1.0, 0.62, 1.0), 8, 3)
	hat.box(Vector3(0.34, 0.03, 0.2), Vector3(0, 1.74, -0.17), Color.WHITE)
	_hats = _mm(hat.build(), HAT)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_from.append(centre + Vector3(side * 6.2, 0, 4.6))
		_to.append(centre + Vector3(side * 2.8, 0, 3.3))
	_phase = "away"
	_apply(0.0)


func arrive() -> void:
	_phase = "in"
	_t = 0.0


func work() -> void:
	_phase = "work"
	_t = 0.0


func leave() -> void:
	_phase = "out"
	_t = 0.0


func phase() -> String:
	return _phase


func _process(delta: float) -> void:
	_clock += delta
	_t += delta
	_apply(delta)


func _mm(mesh: Mesh, col: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 2
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ClubScenery.prop_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-20, -1, -20), Vector3(40, 4, 40))
	add_child(mmi)
	for i in 2:
		mm.set_instance_color(i, col)
	return mmi


func _apply(_delta: float) -> void:
	for i in 2:
		var a: Vector3 = _from[i]
		var b: Vector3 = _to[i]
		var pos := a
		var lean := 0.0
		var yaw := 0.0
		var sc := 1.0
		var walk_len := a.distance_to(b)
		match _phase:
			"away":
				sc = 0.0
			"in":
				var u := clampf(_t * SPEED / walk_len, 0.0, 1.0)
				pos = a.lerp(b, u)
				yaw = atan2(-(b.x - a.x), -(b.z - a.z))
				lean = sin(_clock * 12.0 + float(i)) * 0.04
				if u >= 1.0:
					_phase = "work"
					_t = 0.0
			"work":
				pos = b
				# Face the building and swing: a lean forward at the hammer's beat, offset per worker.
				var beat := maxf(0.0, sin(_clock * 9.0 + float(i) * PI))
				lean = 0.28 * beat
				pos.y = 0.03 * beat
			"out":
				var u := clampf(_t * SPEED_OUT / walk_len, 0.0, 1.0)
				pos = b.lerp(a, u)
				yaw = atan2(-(a.x - b.x), -(a.z - b.z))
				lean = sin(_clock * 14.0 + float(i)) * 0.05
				sc = 1.0 - smoothstep(0.55, 1.0, u)
				if u >= 1.0:
					_phase = "away"
		var basis := Basis.from_euler(Vector3(-lean, yaw, 0.0)) * Basis.from_scale(Vector3.ONE * sc)
		var xf := Transform3D(basis, pos)
		_body.multimesh.set_instance_transform(i, xf)
		_legs.multimesh.set_instance_transform(i, xf)
		_hats.multimesh.set_instance_transform(i, Transform3D(basis, pos + Vector3(0, 0, 0)))
