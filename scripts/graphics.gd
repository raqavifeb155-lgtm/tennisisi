class_name GraphicsQuality
extends Node
## Keeps the game smooth on phones.
##
## Phone screens have 2-3 million pixels; drawing the 3D scene at that resolution is
## what makes a simple scene stutter. The 3D view is rendered at about a million pixels
## and scaled up (the UI stays sharp at full resolution). If the frame rate still drops,
## quality steps down once or twice: softer extras off, then fewer pixels and no MSAA.

const TARGET_PIXELS := 1100000.0
const LEVEL_SCALE := [1.0, 0.85, 0.7]
const MIN_FPS := 50.0

var scenery: Scenery
var level := 0               # 0 high, 1 medium, 2 low
var scale_3d := 1.0

var _frames := 0
var _window_start := 0
var _started := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_apply)
	_started = Time.get_ticks_msec()
	_apply()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _started < 4000:
		_window_start = now  # let loading and shader compilation settle
		_frames = 0
		return
	_frames += 1
	var span := now - _window_start
	if span >= 3000:
		var fps := _frames * 1000.0 / span
		_frames = 0
		_window_start = now
		if fps < MIN_FPS and level < LEVEL_SCALE.size() - 1:
			level += 1
			_apply()


func _apply() -> void:
	var vp := get_viewport()
	var size := Vector2(get_window().size)
	var pixels := maxf(size.x * size.y, 1.0)
	scale_3d = clampf(sqrt(TARGET_PIXELS / pixels), 0.4, 1.0) * float(LEVEL_SCALE[level])
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale_3d
	vp.msaa_3d = Viewport.MSAA_2X if level < 2 else Viewport.MSAA_DISABLED
	if scenery:
		scenery.set_high_quality(level == 0)


## Re-applies the quality level (a new scenery was swapped in).
func refresh() -> void:
	_apply()


func describe() -> String:
	return "gfx L%d  3D x%.2f" % [level, scale_3d]
