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
const COLOR_SURROUND := Color(0.17, 0.33, 0.27)
const COLOR_RUNOFF := Color(0.24, 0.50, 0.40)
const COLOR_COURT := Color(0.20, 0.38, 0.66)
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


func _ready() -> void:
	_box(Vector3(40.0, 0.02, 60.0), Vector3(0, -0.012, 0), COLOR_SURROUND)
	_box(Vector3(DOUBLES_HALF_WIDTH * 2.0 + 7.0, 0.02, HALF_LENGTH * 2.0 + 12.0), Vector3(0, -0.008, 0), COLOR_RUNOFF)
	_box(Vector3(DOUBLES_HALF_WIDTH * 2.0, 0.02, HALF_LENGTH * 2.0), Vector3(0, -0.006, 0), COLOR_COURT)

	var lw := LINE_WIDTH
	var y := 0.002
	# Baselines (a bit wider, like real courts)
	for s in [-1.0, 1.0]:
		_box(Vector3(DOUBLES_HALF_WIDTH * 2.0, 0.004, lw * 1.6), Vector3(0, y, s * HALF_LENGTH), COLOR_LINE)
		_box(Vector3(lw, 0.004, 0.25), Vector3(0, y, s * (HALF_LENGTH - 0.125)), COLOR_LINE)
	# Sidelines
	for s in [-1.0, 1.0]:
		_box(Vector3(lw, 0.004, HALF_LENGTH * 2.0), Vector3(s * DOUBLES_HALF_WIDTH, y, 0), COLOR_LINE)
		_box(Vector3(lw, 0.004, HALF_LENGTH * 2.0), Vector3(s * SINGLES_HALF_WIDTH, y, 0), COLOR_LINE)
	# Service lines + center service line
	for s in [-1.0, 1.0]:
		_box(Vector3(SINGLES_HALF_WIDTH * 2.0, 0.004, lw), Vector3(0, y, s * SERVICE_LINE), COLOR_LINE)
	_box(Vector3(lw, 0.004, SERVICE_LINE * 2.0), Vector3(0, y, 0), COLOR_LINE)

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


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
