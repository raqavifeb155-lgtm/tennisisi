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
## High is the golden middle on a computer: sharp, soft shadows, all details. Auto starts
## there and steps down if the frame rate drops under 50. On a phone Auto starts at Medium
## and never goes above it: in Telegram anything above Medium gave an unsteady frame rate
## (HANDOFF 9.6, players' telemetry); the settings mark High and Max for that.

enum { AUTO, LOW, MEDIUM, HIGH, MAX, CUSTOM }

const NAMES := ["Авто", "Низкая", "Средняя", "Высокая", "Максимум"]
const CUSTOM_NAME := "Своя"
const WARN_TG := "Может тормозить в Telegram."
## What each preset does, for the settings sheet (one line under the buttons).
const NOTES := [
	"Сама подстраивается под устройство: если кадры проседают, качество снижается.",
	"Для старых телефонов: меньше пикселей, без сглаживания, простые тени.",
	"Баланс: картинка чуть мягче, тени жёсткие, без лишних деталей сцены.",
	"Чёткая картинка, мягкие тени, все детали сцены. " + WARN_TG,
	"Для флагманов: родное разрешение, сглаживание 4x, мягкие и дальние тени. Телефон может греться. " + WARN_TG,
	"Своя настройка: части графики выставлены вручную ниже.",
]
const AUTO_PHONE_NOTE := " На телефоне — не выше «Средней»."
const PRESETS := {
	LOW: {"pixels": 700000.0, "aa": 0, "shadows": 1, "reach": 0.7, "details": false},
	MEDIUM: {"pixels": 1100000.0, "aa": 1, "shadows": 1, "reach": 0.85, "details": false},
	HIGH: {"pixels": 1800000.0, "aa": 1, "shadows": 2, "reach": 1.0, "details": true},
	MAX: {"pixels": 0.0, "aa": 2, "shadows": 3, "reach": 1.35, "details": true},
}
const AUTO_STEPS := [HIGH, MEDIUM, LOW]
const AUTO_STEPS_PHONE := [MEDIUM, LOW]
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
var _steps: Array = AUTO_STEPS

static var _phone := -1             # -1 not checked yet, 0 no, 1 yes


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_steps = auto_steps(is_phone())
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
		if fps < MIN_FPS and _auto_step < _steps.size() - 1:
			_auto_step += 1
			_apply()


## A preset's button in the settings: short, with "!" where Telegram may stutter.
static func caption(i: int) -> String:
	match i:
		HIGH:
			return "Выс !"
		MAX:
			return "Макс !"
		MEDIUM:
			return "Сред"
		LOW:
			return "Низк"
	return NAMES[i]


## What the chosen preset does, in one line (and the phone's cap for "Авто").
static func note(i: int, phone: bool) -> String:
	var n: String = NOTES[clampi(i, 0, NOTES.size() - 1)]
	return n + (AUTO_PHONE_NOTE if i == AUTO and phone else "")


## The levels "Авто" walks down, from the first.
static func auto_steps(phone: bool) -> Array:
	return AUTO_STEPS_PHONE if phone else AUTO_STEPS


## A phone or a tablet: Android or iOS, native or in a browser / Telegram (iPadOS Safari
## says "Macintosh", its touch points give it away). `-- --phone` pretends, for tests.
static func is_phone() -> bool:
	if _phone < 0:
		_phone = 1 if _detect_phone() else 0
	return _phone == 1


static func _detect_phone() -> bool:
	if "--phone" in OS.get_cmdline_user_args():
		return true
	for f in ["android", "ios", "web_android", "web_ios"]:
		if OS.has_feature(f):
			return true
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("(function () { var u = navigator.userAgent || '', h = (location.hash || '') + (location.search || ''); return /Android|iPhone|iPad|iPod|Mobile/i.test(u) || (navigator.maxTouchPoints > 1 && /Macintosh/.test(u)) || /tgWebAppPlatform=(ios|android)/.test(h); })()", true) == true
	return false


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
		level = _steps[_auto_step] if preset == AUTO else preset
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
