class_name BallTrail
extends MeshInstance3D
## A short ribbon behind the ball (the last ~0.25 s of flight), coloured by the last shot:
## topspin orange, slice / drop blue, flat white. Brighter after a PERFECT. It faces the
## camera, so it reads as a streak from any angle, and fades out when the ball is parked.

const LIFE := 0.25        # seconds of flight the ribbon covers
const WIDTH := 0.07       # metres at the ball, thinning to nothing at the tail

var ball: Ball
var _pts: Array = []      # [position, age]
var _color := Color(1, 1, 1)
var _bright := false
var _im := ImmediateMesh.new()


func _ready() -> void:
	mesh = _im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true


func set_color(c: Color, bright: bool) -> void:
	_color = c
	_bright = bright


func _process(delta: float) -> void:
	for p in _pts:
		p[1] += delta
	while not _pts.is_empty() and _pts[0][1] > LIFE:
		_pts.pop_front()
	if ball != null and ball.active:
		_pts.append([ball.render_pos(), 0.0])
	_im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if _pts.size() < 2 or cam == null:
		return
	var eye := cam.global_position
	var alpha := 0.85 if _bright else 0.55
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _pts.size():
		var p: Vector3 = _pts[i][0]
		var nxt: Vector3 = _pts[mini(i + 1, _pts.size() - 1)][0]
		var prv: Vector3 = _pts[maxi(i - 1, 0)][0]
		var along := (nxt - prv)
		if along.length() < 0.0001:
			along = Vector3.FORWARD
		var side := along.cross(eye - p).normalized()
		var k := 1.0 - float(_pts[i][1]) / LIFE   # 1 at the ball, 0 at the tail
		var w := WIDTH * k * (1.4 if _bright else 1.0)
		var c := Color(_color.r, _color.g, _color.b, alpha * k * k)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p + side * w)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p - side * w)
	_im.surface_end()
