class_name GraphicsQuality
extends Node
## Graphics presets, chosen in the settings (saved), "Auto" for everyone else, and
## "Своя" (custom) when the player sets the parts by hand.
##
## Every preset is five parts, the same ones the settings sheet shows as controls:
##   sharpness  share of the screen's own resolution the 3D view is drawn at (the UI
##              always stays sharp); presets ask for a pixel budget, so a phone with a
##              huge screen is not punished: 1.8 MP is ~75% on an iPhone Pro
##   shadows    0 off, 1 hard, 2 soft, 3 the softest (with a 4096 shadow map)
##   reach      how far from the camera shadows are drawn, x the scenery's own
##   edges      MSAA: off, 2x, 4x
##   details    the scenery's small extras (cloud shadows, little props)
## High is the golden middle: sharp, soft shadows, all details, still light. Auto
## starts there and steps down if the frame rate drops under 50.

enum { AUTO, LOW, MEDIUM, HIGH, MAX, CUSTOM }

const NAMES := ["Авто", "Низкая", "Средняя", "Высокая", "Максимум"]
const CUSTOM_NAME := "Своя"
const PRESETS := {
	LOW: {"pixels": 700000.0, "aa": 0, "shadows": 1, "reach": 0.7, "details": false},
	MEDIUM: {"pixels": 1100000.0, "aa": 1, "shadows": 1, "reach": 0.85, "details": false},
	HIGH: {"pixels": 1800000.0, "aa": 1, "shadows": 2, "reach": 1.0, "details": true},
	MAX: {"pixels": 0.0, "aa": 2, "shadows": 3, "reach": 1.35, "details": true},
}
const AUTO_STEPS := [HIGH, MEDIUM, LOW]
const MIN_FPS := 50.0
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const SOFT := [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_HARD,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]

var scenery: Scenery
var preset := AUTO
var level := HIGH            # the preset actually drawn (Auto may step it down)
var scale_3d := 1.0

var _auto_step := 0
var _frames := 0
var _window_start := 0
var _started := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_apply)
	_started = Time.get_ticks_msec()
	_apply()


func set_preset(p: int) -> void:
	p = clampi(p, AUTO, CUSTOM)
	if p == preset and p != CUSTOM:
		return
	preset = p
	_auto_step = 0
	_started = Time.get_ticks_msec()  # Auto measures afresh
	_apply()


func _process(_delta: float) -> void:
	if preset != AUTO:
		return
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
		if fps < MIN_FPS and _auto_step < AUTO_STEPS.size() - 1:
			_auto_step += 1
			_apply()


## The share of the screen's resolution a pixel budget means on this screen.
func _scale_for(budget: float) -> float:
	var size := Vector2(get_window().size)
	var pixels := maxf(size.x * size.y, 1.0)
	return 1.0 if budget <= 0.0 else clampf(sqrt(budget / pixels), 0.4, 1.0)


## The settings singleton, looked up when needed: this script is also compiled by
## test scripts that run before autoloads exist.
func _tuning() -> Node:
	return get_tree().root.get_node("Tuning")


func _apply() -> void:
	var tuning := _tuning()
	var q: Dictionary
	if preset == CUSTOM:
		level = CUSTOM
		q = {"scale": tuning.gfx_res, "aa": tuning.gfx_aa, "shadows": tuning.gfx_shadows,
			"reach": tuning.gfx_reach, "details": tuning.gfx_details}
	else:
		level = AUTO_STEPS[_auto_step] if preset == AUTO else preset
		q = PRESETS[level].duplicate()
		q["scale"] = _scale_for(q["pixels"])
		# The settings sheet shows what the preset really does on this phone.
		tuning.gfx_res = q["scale"]
		tuning.gfx_aa = q["aa"]
		tuning.gfx_shadows = q["shadows"]
		tuning.gfx_reach = q["reach"]
		tuning.gfx_details = q["details"]
	var shadows: int = clampi(q["shadows"], 0, 3)
	var vp := get_viewport()
	scale_3d = clampf(q["scale"], 0.4, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale_3d
	vp.msaa_3d = MSAA[clampi(q["aa"], 0, 2)]
	RenderingServer.directional_shadow_atlas_set_size(4096 if shadows == 3 else (1024 if shadows == 1 and float(q["reach"]) < 0.8 else 2048), true)
	if scenery:
		# The scenery sets its own shadow reach and extras; the preset scales them.
		scenery.set_high_quality(q["details"])
		var sun := scenery.sun()
		if sun:
			sun.shadow_enabled = shadows > 0
			sun.directional_shadow_max_distance *= float(q["reach"])
	RenderingServer.directional_soft_shadow_filter_set_quality(SOFT[shadows])


## Re-applies the quality level (a new scenery was swapped in).
func refresh() -> void:
	_apply()


func level_name() -> String:
	return CUSTOM_NAME if level == CUSTOM else NAMES[level]


func describe() -> String:
	return "gfx %s%s  3D x%.2f" % [level_name(), " (авто)" if preset == AUTO else "", scale_3d]
