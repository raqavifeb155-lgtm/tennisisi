class_name BootLoader
extends CanvasLayer
## The loading screen after the engine starts: WebGL compiles a shader the first time
## something is drawn with it, which would hitch the first rally. The scene keeps
## rendering under this screen, so the court, the scenery and the players are compiled
## before the screen goes away. It waits until frames come out steady. (Sounds need no
## warming: they stream, see Sfx._voice().)

signal finished

const MIN_FRAMES := 20
const STEADY_FRAMES := 8         # this many frames in a row under STEADY_MS...
const STEADY_MS := 24.0
const MAX_SECONDS := 6.0         # ...or give up waiting: a slow phone still gets in

var _bar: ProgressBar
var _frames := 0
var _steady := 0
var _t := 0.0
var _last_us := 0
var _done := false


func _ready() -> void:
	layer = UiTheme.LAYER_LOADING
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # no taps reach the game while loading
	add_child(bg)
	# Exactly the page's loading screen (the web shell): the logo across the full
	# width in the middle, a thin bar at 10% from the bottom, half the width. The page,
	# the engine's splash and this screen then read as one loading, not two.
	var logo := TextureRect.new()
	logo.texture = load("res://assets/brand/splash.png")
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(logo)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.anchor_left = 0.25
	_bar.anchor_right = 0.75
	_bar.anchor_top = 0.9
	_bar.anchor_bottom = 0.9
	_bar.offset_top = -6.0
	_bar.offset_bottom = 6.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.85, 0.25)
	fill.set_corner_radius_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", track)
	_bar.value = 100.0  # the page has filled it: this screen only holds it full
	bg.add_child(_bar)
	_last_us = Time.get_ticks_usec()


func _process(delta: float) -> void:
	if _done:
		return
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_us) / 1000.0
	_last_us = now
	_t += delta
	_frames += 1
	if frame_ms < STEADY_MS:
		_steady += 1
	else:
		_steady = 0
	var ready := _frames >= MIN_FRAMES and _steady >= STEADY_FRAMES
	if ready or _t > MAX_SECONDS:
		_done = true
		var tw := create_tween()
		tw.tween_property(get_child(0), "modulate:a", 0.0, 0.35)
		tw.tween_callback(func() -> void:
			finished.emit()
			queue_free())
