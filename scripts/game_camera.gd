class_name GameCamera
extends Camera3D
## Elevated behind-the-player camera. Follows the player smoothly, keeps the whole
## far court in view, and supports small hit impulses (shake + FOV kick).

var target: Node3D
var ball: Ball
var height := 11.0
var back := 9.0
var look_ahead := 6.0

var _shake := 0.0
var _fov_kick := 0.0
var _base_fov := 52.0
var _last_us := 0


func _ready() -> void:
	fov = _base_fov
	near = 1.0
	far = 90.0
	_last_us = Time.get_ticks_usec()


func impulse(strength: float) -> void:
	_shake = maxf(_shake, strength)
	_fov_kick = maxf(_fov_kick, strength * 4.0)


func snap() -> void:
	if target:
		global_position = _desired_position()
		look_at(_look_point(), Vector3.UP)


func _desired_position() -> Vector3:
	var p := target.global_position
	return Vector3(p.x * 0.7, height, p.z + back)


func _look_point() -> Vector3:
	var p := target.global_position
	var bx := ball.state.pos.x if ball and ball.active else 0.0
	return Vector3(p.x * 0.35 + bx * 0.12, 0.0, p.z - look_ahead)


func _process(_delta: float) -> void:
	if target == null:
		return
	# Real (unscaled) time so slow-motion and hit-stop don't make the camera sluggish.
	var now := Time.get_ticks_usec()
	var rd := clampf((now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now

	var vp := get_viewport().get_visible_rect().size
	keep_aspect = Camera3D.KEEP_WIDTH if vp.x < vp.y else Camera3D.KEEP_HEIGHT
	_base_fov = 52.0 if vp.x < vp.y else 48.0

	global_position = global_position.lerp(_desired_position(), 1.0 - exp(-5.0 * rd))
	look_at(_look_point(), Vector3.UP)
	if _shake > 0.001:
		h_offset = randf_range(-1.0, 1.0) * _shake * 0.06
		v_offset = randf_range(-1.0, 1.0) * _shake * 0.06
		_shake = maxf(0.0, _shake - rd * 3.0)
	else:
		h_offset = 0.0
		v_offset = 0.0
	_fov_kick = maxf(0.0, _fov_kick - rd * 20.0)
	fov = _base_fov - _fov_kick
