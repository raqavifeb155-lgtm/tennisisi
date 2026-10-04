class_name TimingRing
extends Control
## Top Spin-style timing cue: a ring shrinks onto a fixed circle hanging above the player.
## Swipe when the ring meets the circle. The ring runs on game time, so it slows down
## together with the slow-motion window.
##
## The hit verdict (PERFECT / GOOD / LATE ...) appears right there, where the eyes
## already are: a PERFECT bursts in gold with sparks, a GOOD gives a soft green pulse.

const INNER := 30.0          # target circle radius (px)
const PX_PER_SEC := 105.0    # ring radius per game second remaining
const GOLD := Color(1.0, 0.85, 0.25)
const GOOD := Color(0.55, 1.0, 0.6)
const LATE := Color(1.0, 0.55, 0.25)
const FEEDBACK_TIME := 0.95  # seconds (real time, unaffected by slow-motion)

## Where the ring hangs (screen px). Updated every frame, so the verdict follows the player.
var anchor := Vector2.ZERO

var _active := false
var _pos := Vector2.ZERO
var _t_left := 0.0
var _perfect := 0.035
var _good := 0.09

var _fb_text := ""
var _fb_sub := ""
var _fb_color := Color.WHITE
var _fb_kind := 0            # 0 plain, 1 good pulse, 2 perfect burst
var _fb_age_s := 100.0
var _fb_offset := Vector2.ZERO
var _sparks: Array[Vector2] = []  # (angle, speed) per spark


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_ring(pos: Vector2, t_left: float, perfect_window: float, good_window: float) -> void:
	_active = true
	_pos = pos
	_fb_offset = pos - anchor
	_t_left = t_left
	_perfect = perfect_window
	_good = good_window
	queue_redraw()


func hide_ring() -> void:
	if _active:
		_active = false
		queue_redraw()


## Show a verdict at the ring. kind: 0 plain text, 1 soft pulse, 2 PERFECT burst.
func feedback(text: String, color: Color, sub := "", kind := 0) -> void:
	_fb_text = text
	_fb_sub = sub
	_fb_color = color
	_fb_kind = kind
	_fb_age_s = 0.0
	if not _active:
		_fb_offset = Vector2.ZERO if _fb_offset.length() > 80.0 else _fb_offset
	_sparks.clear()
	if kind == 2:
		for i in 14:
			_sparks.append(Vector2(TAU * i / 14.0 + randf_range(-0.12, 0.12), randf_range(110.0, 190.0)))
	queue_redraw()


func _process(delta: float) -> void:
	if _fb_age_s < FEEDBACK_TIME:
		# Unscaled time: slow-motion and hit-stop must not stretch the animation.
		_fb_age_s += minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
		queue_redraw()


func _fb_age() -> float:
	return _fb_age_s


func _draw() -> void:
	if _active:
		_draw_ring()
	var age := _fb_age()
	if age < FEEDBACK_TIME and _fb_text != "":
		_draw_feedback(age)


func _draw_ring() -> void:
	var a := absf(_t_left)
	var col := Color(1, 1, 1, 0.95)
	if a <= _perfect:
		col = GOLD
	elif a <= _good:
		col = GOOD
	elif _t_left < 0.0:
		col = LATE
	# Target circle + centre dot
	draw_circle(_pos, INNER, Color(0, 0, 0, 0.18))
	draw_arc(_pos, INNER, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 4.0, true)
	draw_circle(_pos, 5.0, Color(1, 1, 1, 0.9))
	# Shrinking ring
	var r := INNER + _t_left * PX_PER_SEC
	if r > 6.0:
		draw_arc(_pos, r, 0.0, TAU, 64, col, 6.0, true)
	if a <= _perfect:
		draw_arc(_pos, INNER + 9.0, 0.0, TAU, 48, Color(GOLD, 0.5), 3.0, true)


func _draw_feedback(age: float) -> void:
	var c := anchor + _fb_offset
	var fade := 1.0 - clampf((age - 0.6) / 0.35, 0.0, 1.0)

	# Rings and sparks around the circle.
	if _fb_kind == 2:
		draw_circle(c, INNER * (1.0 + age * 1.5), Color(GOLD, 0.45 * clampf(1.0 - age * 2.6, 0.0, 1.0)))
		for k in 2:
			var t := clampf((age - k * 0.09) / 0.5, 0.0, 1.0)
			if t > 0.0 and t < 1.0:
				var e := 1.0 - pow(1.0 - t, 3.0)
				draw_arc(c, INNER + e * (70.0 + k * 30.0), 0.0, TAU, 64, Color(GOLD, (1.0 - t) * 0.9), 6.0 - k * 2.0, true)
		var st := clampf(age / 0.55, 0.0, 1.0)
		if st < 1.0:
			var ease_s := 1.0 - pow(1.0 - st, 2.0)
			for s in _sparks:
				var dir := Vector2.from_angle(s.x)
				var d0 := INNER + 6.0 + ease_s * s.y
				var p0 := c + dir * d0
				var p1 := c + dir * maxf(INNER + 4.0, d0 - 16.0 * (1.0 - st))
				draw_line(p1, p0, Color(1.0, 0.95, 0.6, 1.0 - st), 3.0, true)
				draw_circle(p0, 2.5 * (1.0 - st) + 0.5, Color(1, 1, 0.85, 1.0 - st))
	elif _fb_kind == 1:
		var t := clampf(age / 0.45, 0.0, 1.0)
		if t < 1.0:
			draw_arc(c, INNER + (1.0 - pow(1.0 - t, 2.0)) * 45.0, 0.0, TAU, 64, Color(GOOD, (1.0 - t) * 0.8), 4.0, true)

	# The word: pops in (overshoot), sits on the circle, fades out.
	var font := get_theme_default_font()
	var size := 50 if _fb_kind == 2 else 40
	var pop := 1.0
	if age < 0.22:
		var t := age / 0.22
		pop = lerpf(1.6 if _fb_kind == 2 else 1.3, 1.0, 1.0 - pow(1.0 - t, 3.0)) + sin(t * PI) * 0.08
	var w := font.get_string_size(_fb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * pop
	var vp := get_viewport_rect().size
	var cx := clampf(c.x, w * 0.5 + 12.0, vp.x - w * 0.5 - 12.0)
	var base := Vector2(cx, c.y + size * 0.35 - age * 18.0)
	var col := Color(_fb_color, fade)
	draw_set_transform(base, 0.0, Vector2(pop, pop))
	var tw := font.get_string_size(_fb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, Vector2(-tw * 0.5, 0.0), _fb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0, 0, 0, 0.8 * fade))
	draw_string(font, Vector2(-tw * 0.5, 0.0), _fb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	draw_set_transform(Vector2.ZERO)

	# Details (stroke, speed) in small print just above.
	if _fb_sub != "":
		var ss := 21
		var sw := font.get_string_size(_fb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		var sx := clampf(c.x - sw * 0.5, 10.0, vp.x - sw - 10.0)
		var sp := Vector2(sx, base.y - size * 0.95)
		draw_string_outline(font, sp, _fb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, 6, Color(0, 0, 0, 0.75 * fade))
		draw_string(font, sp, _fb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(1, 1, 1, 0.95 * fade))
