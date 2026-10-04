class_name Court
extends Node3D
## Regulation tennis court. The player's half is z > 0, the opponent's half is z < 0.
## Net plane is z = 0. Units are meters.

const HALF_LENGTH := 11.885
const SINGLES_HALF_WIDTH := 4.115
const DOUBLES_HALF_WIDTH := 5.485
const SERVICE_LINE := 6.40
const NET_HEIGHT_CENTER := 0.914
const NET_HEIGHT_POST := 1.07
const NET_HALF_WIDTH := 6.40

const LINE_WIDTH := 0.08
const COLOR_SURROUND := Color(0.56, 0.54, 0.50)  # concrete around a city court
const COLOR_RUNOFF := Color(0.24, 0.50, 0.40)
const COLOR_COURT := Color(0.16, 0.33, 0.64)
const COLOR_LINE := Color(0.96, 0.96, 0.96)


static func net_height(x: float) -> float:
	var t := clampf(absf(x) / NET_HALF_WIDTH, 0.0, 1.0)
	return lerpf(NET_HEIGHT_CENTER, NET_HEIGHT_POST, t * t)


## True if a ball touching the ground at p is in the singles court of the given half.
## half: +1 = player half (z > 0), -1 = opponent half (z < 0). Touching a line counts as in.
static func is_in_singles(p: Vector3, half: int, radius: float) -> bool:
	if absf(p.x) > SINGLES_HALF_WIDTH + radius:
		return false
	var z := p.z * half
	return z >= 0.0 and z <= HALF_LENGTH + radius


## True if a ball touching the ground at p is inside the service box of the given half.
## box_side: sign of x for the box (-1 = x < 0 box, +1 = x > 0 box).
static func in_service_box(p: Vector3, half: int, box_side: float, radius: float) -> bool:
	var z := p.z * half
	if z < 0.0 or z > SERVICE_LINE + radius:
		return false
	var x := p.x * box_side
	return x >= -radius and x <= SINGLES_HALF_WIDTH + radius


## Visual layers are separated by whole centimetres so phones (low depth precision)
## never z-fight: surround 0.00, run-off 0.01, court 0.02, lines 0.03.
## Physics still treats the ground as y = 0; the offset is invisible.
const Y_RUNOFF := 0.01
const Y_COURT := 0.02
const Y_LINES := 0.03


func _ready() -> void:
	_slab(Vector2(DOUBLES_HALF_WIDTH * 2.0 + 13.0, HALF_LENGTH * 2.0 + 18.0), 0.0, COLOR_SURROUND)  # apron; the park around is Scenery
	_slab(Vector2(DOUBLES_HALF_WIDTH * 2.0 + 7.0, HALF_LENGTH * 2.0 + 12.0), Y_RUNOFF, COLOR_RUNOFF)
	_slab(Vector2(DOUBLES_HALF_WIDTH * 2.0, HALF_LENGTH * 2.0), Y_COURT, COLOR_COURT)

	var lw := LINE_WIDTH
	# Baselines (a bit wider, like real courts) + centre marks
	for s in [-1.0, 1.0]:
		_line(Vector2(DOUBLES_HALF_WIDTH * 2.0, lw * 1.6), Vector2(0, s * HALF_LENGTH))
		_line(Vector2(lw, 0.25), Vector2(0, s * (HALF_LENGTH - 0.125)))
	# Sidelines
	for s in [-1.0, 1.0]:
		_line(Vector2(lw, HALF_LENGTH * 2.0), Vector2(s * DOUBLES_HALF_WIDTH, 0))
		_line(Vector2(lw, HALF_LENGTH * 2.0), Vector2(s * SINGLES_HALF_WIDTH, 0))
	# Service lines + centre service line
	for s in [-1.0, 1.0]:
		_line(Vector2(SINGLES_HALF_WIDTH * 2.0, lw), Vector2(0, s * SERVICE_LINE))
	_line(Vector2(lw, SERVICE_LINE * 2.0), Vector2(0, 0))

	# Net: mesh panel, white tape, posts
	var net_mat := StandardMaterial3D.new()
	net_mat.albedo_color = Color(0.05, 0.05, 0.07, 0.55)
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var net := MeshInstance3D.new()
	var net_mesh := BoxMesh.new()
	net_mesh.size = Vector3(NET_HALF_WIDTH * 2.0, NET_HEIGHT_CENTER, 0.02)
	net.mesh = net_mesh
	net.material_override = net_mat
	net.position = Vector3(0, NET_HEIGHT_CENTER * 0.5, 0)
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)
	_box(Vector3(NET_HALF_WIDTH * 2.0, 0.06, 0.03), Vector3(0, NET_HEIGHT_CENTER, 0), COLOR_LINE)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.08, NET_HEIGHT_POST, 0.08), Vector3(s * (NET_HALF_WIDTH + 0.05), NET_HEIGHT_POST * 0.5, 0), Color(0.15, 0.15, 0.17))


func _slab(size: Vector2, top_y: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = _flat(color)
	mi.position = Vector3(0, top_y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _line(size: Vector2, center: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = _flat(COLOR_LINE)
	mi.position = Vector3(center.x, Y_LINES, center.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _flat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
