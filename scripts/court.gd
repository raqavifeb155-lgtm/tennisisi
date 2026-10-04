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


var _net_root: Node3D
var _net_tween: Tween
var _surround_mat: StandardMaterial3D
var _runoff_mat: StandardMaterial3D
var _court_mat: StandardMaterial3D
var surface := "hard"

# Marks on clay: ball marks and slide streaks, one MultiMesh (one draw call), recycled.
const MAX_MARKS := 160
var _marks: MultiMeshInstance3D
var _mark_next := 0

## Colours per surface: [surround, run-off, court].
const SURFACE_COLORS := {
	"hard": [Color(0.56, 0.54, 0.50), Color(0.24, 0.50, 0.40), Color(0.16, 0.33, 0.64)],
	"clay": [Color(0.55, 0.30, 0.2), Color(0.74, 0.38, 0.22), Color(0.76, 0.4, 0.23)],
	"grass": [Color(0.22, 0.36, 0.18), Color(0.3, 0.5, 0.24), Color(0.33, 0.55, 0.26)],
}


func _ready() -> void:
	_surround_mat = _slab(Vector2(DOUBLES_HALF_WIDTH * 2.0 + 13.0, HALF_LENGTH * 2.0 + 18.0), 0.0, COLOR_SURROUND)  # apron; the park around is Scenery
	_runoff_mat = _slab(Vector2(DOUBLES_HALF_WIDTH * 2.0 + 7.0, HALF_LENGTH * 2.0 + 12.0), Y_RUNOFF, COLOR_RUNOFF)
	_court_mat = _slab(Vector2(DOUBLES_HALF_WIDTH * 2.0, HALF_LENGTH * 2.0), Y_COURT, COLOR_COURT)
	_build_marks()

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
	_net_root = Node3D.new()
	add_child(_net_root)
	_net_root.add_child(net)
	_net_root.add_child(_unparent(_box(Vector3(NET_HALF_WIDTH * 2.0, 0.06, 0.03), Vector3(0, NET_HEIGHT_CENTER, 0), COLOR_LINE)))
	for s in [-1.0, 1.0]:
		_net_root.add_child(_unparent(_box(Vector3(0.08, NET_HEIGHT_POST, 0.08), Vector3(s * (NET_HALF_WIDTH + 0.05), NET_HEIGHT_POST * 0.5, 0), Color(0.15, 0.15, 0.17))))
	set_surface(surface)

func _slab(size: Vector2, top_y: float, color: Color) -> StandardMaterial3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var mat := _flat(color)
	mi.material_override = mat
	mi.position = Vector3(0, top_y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mat


## Switches the court to hard, clay or grass: colours, texture and the ball's bounce.
func set_surface(id: String) -> void:
	surface = id if SURFACE_COLORS.has(id) else "hard"
	if _court_mat == null:
		return  # applied in _ready
	var c: Array = SURFACE_COLORS[surface]
	for pair in [[_surround_mat, c[0]], [_runoff_mat, c[1]], [_court_mat, c[2]]]:
		var m: StandardMaterial3D = pair[0]
		m.albedo_color = pair[1]
		m.albedo_texture = null
	match surface:
		"clay":
			# Fine brick dust: a grainy texture, a touch darker where it was swept.
			_court_mat.albedo_color = Color.WHITE
			_court_mat.albedo_texture = _clay_texture()
			_runoff_mat.albedo_color = Color.WHITE
			_runoff_mat.albedo_texture = _clay_texture(0.97)
		"grass":
			# Mowing stripes across the court and worn patches behind the baselines.
			_court_mat.albedo_color = Color.WHITE
			_court_mat.albedo_texture = _grass_texture()
	BallPhysics.set_surface(surface)
	clear_marks()


func _clay_texture(shade := 1.0) -> ImageTexture:
	var img := Image.create(128, 256, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var base := Color(0.76, 0.4, 0.23) * shade
	for y in 256:
		for x in 128:
			var n := r.randf_range(-0.035, 0.035)
			img.set_pixel(x, y, Color(base.r + n, base.g + n * 0.7, base.b + n * 0.5))
	var tex := ImageTexture.create_from_image(img)
	return tex


func _grass_texture() -> ImageTexture:
	var img := Image.create(64, 256, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for y in 256:
		var stripe := (y / 20) % 2 == 0
		# Distance from the nearer baseline: the grass is worn bare where players stand.
		var from_base := minf(y, 255 - y) / 255.0 * 2.0
		var wear := clampf(1.0 - from_base * 9.0, 0.0, 1.0)
		for x in 64:
			var g := Color(0.36, 0.58, 0.27) if stripe else Color(0.3, 0.5, 0.23)
			var n := r.randf_range(-0.03, 0.03)
			var centre := 1.0 - absf(x - 31.5) / 32.0
			var w := wear * clampf(centre * 1.6, 0.0, 1.0) * r.randf_range(0.6, 1.0)
			g = g.lerp(Color(0.6, 0.52, 0.33), w * 0.75)
			img.set_pixel(x, y, Color(g.r + n, g.g + n, g.b + n * 0.5))
	return ImageTexture.create_from_image(img)


func _build_marks() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.2, 0.1, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = MAX_MARKS
	mm.visible_instance_count = 0
	_marks = MultiMeshInstance3D.new()
	_marks.multimesh = mm
	_marks.material_override = mat
	_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marks)


## A mark on clay: a ball mark (small oval) or a slide streak. Ignored on other surfaces.
func add_mark(pos: Vector3, dir: Vector3, length: float, width: float) -> void:
	if surface != "clay":
		return
	var mm := _marks.multimesh
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	var x := d.cross(Vector3.UP).normalized()
	var b := Basis(x * width, Vector3.UP, d * length)
	mm.set_instance_transform(_mark_next, Transform3D(b, Vector3(pos.x, Y_LINES + 0.004, pos.z)))
	_mark_next = (_mark_next + 1) % MAX_MARKS
	mm.visible_instance_count = mini(mm.visible_instance_count + 1, MAX_MARKS) if mm.visible_instance_count < MAX_MARKS else MAX_MARKS


## The court is swept: all marks gone (new match).
func clear_marks() -> void:
	if _marks:
		_marks.multimesh.visible_instance_count = 0
		_mark_next = 0


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


## The net sinks into the court (the trophy mini-game) or rises back. Also switches the
## net's collision off/on (BallPhysics.net_enabled).
func set_net_up(up: bool) -> void:
	BallPhysics.net_enabled = up
	if _net_tween:
		_net_tween.kill()
	_net_root.visible = true
	_net_tween = create_tween()
	_net_tween.tween_property(_net_root, "position:y", 0.0 if up else -1.2, 0.6).set_trans(Tween.TRANS_BACK)
	if not up:
		_net_tween.tween_callback(func() -> void: _net_root.visible = false)


func _unparent(n: Node) -> Node:
	n.get_parent().remove_child(n)
	return n


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
