class_name GameCamera
extends Camera3D
## Elevated behind-the-player camera. Follows the player smoothly, keeps the whole
## far court in view, and supports small hit impulses (shake + FOV kick).
## Two framings (Tuning.tv_camera, saved as SaveData.camera; --camera=tv for the bot):
##   normal  low behind the player, the far court ahead;
##   booth   (D-6, watching an academy match: --camera=booth or `booth = true`) the coach's booth
##           behind the baseline at the corner, 2.2 m up, the court running away into the
##           frame like the normal view; `booth_wide` pulls back to the TV frame between points.
##   tv      the broadcast view (ATP Finals): high behind the baseline, the whole court in
##           the frame, the players small; it only drifts a little with the player.

var target: Node3D
var ball: Ball
var height := 8.0
var back := 6.0
var look_ahead := 9.0

var booth := false
var booth_wide := false           # between the points: the whole court (the TV frame)

var _shake := 0.0
var _fov_kick := 0.0
var _base_fov := 52.0
var _last_us := 0

## The TV framing: where the camera hangs (behind and above the near baseline) and where
## it looks (just past the net), per screen shape.
const TV_PORTRAIT := {"height": 7.0, "z": 22.0, "look_z": -2.0, "fov": 40.0, "follow": 0.12}  # D-9: closer and lower: the player ~1/10 of the screen, the singles court still in the frame
const TV_LANDSCAPE := {"height": 7.0, "z": 22.0, "look_z": -2.0, "fov": 32.0, "follow": 0.18}

## The coach's booth: behind the near baseline, at the corner, low; looks at the far court.
const BOOTH_POS := Vector3(5.2, 2.4, 17.2)
const BOOTH_LOOK := Vector3(-1.0, 0.2, 0.5)
const BOOTH_FOV := 72.0


func tv() -> bool:
	return Tuning.tv_camera


func _ready() -> void:
	if "--closecam" in OS.get_cmdline_user_args():
		# Debug: close-up on the player to inspect animation.
		height = 2.6
		back = 3.6
		look_ahead = 1.0
	if "--camera=tv" in OS.get_cmdline_user_args():
		Tuning.tv_camera = true
	if "--camera=booth" in OS.get_cmdline_user_args():
		booth = true
	Tuning.changed.connect(_remember_mode)
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep framing the player behind the paused tutorial
	fov = _base_fov
	near = 1.0
	far = 700.0
	_last_us = Time.get_ticks_usec()


func impulse(strength: float) -> void:
	_shake = maxf(_shake, strength)
	_fov_kick = maxf(_fov_kick, strength * 4.0)


## The settings sheet switched the framing: keep it in the save (a new key, SaveData.camera).
func _remember_mode() -> void:
	var want := "tv" if Tuning.tv_camera else "normal"
	if SaveData.camera != want:
		SaveData.camera = want
		SaveData.save()


func _tv_frame() -> Dictionary:
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(720, 1564)
	return TV_PORTRAIT if vp.x < vp.y else TV_LANDSCAPE


func snap() -> void:
	if target:
		global_position = _desired_position()
		look_at(_look_point(), Vector3.UP)


func _wide() -> bool:
	return tv() or (booth and booth_wide)


func _desired_position() -> Vector3:
	var p := target.global_position
	if booth and not booth_wide:
		return BOOTH_POS
	if _wide():
		var f := _tv_frame()
		return Vector3(p.x * float(f["follow"]), float(f["height"]), float(f["z"]))
	return Vector3(p.x * (0.7 if look_ahead > 3.0 else 1.0), height, p.z + back)


func _look_point() -> Vector3:
	var p := target.global_position
	if booth and not booth_wide:
		var bx0 := ball.state.pos.x * 0.25 if ball and ball.active else 0.0
		return BOOTH_LOOK + Vector3(bx0, 0.0, 0.0)
	if _wide():
		return Vector3(p.x * float(_tv_frame()["follow"]) * 0.5, 0.0, float(_tv_frame()["look_z"]))
	var bx := ball.state.pos.x if ball and ball.active else 0.0
	return Vector3(p.x * 0.35 + bx * 0.12, 0.0 if look_ahead > 3.0 else 1.0, p.z - look_ahead)


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
	if _wide():
		_base_fov = float(_tv_frame()["fov"])
	elif booth:
		_base_fov = BOOTH_FOV

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
