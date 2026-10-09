class_name TimingRing
extends Control
## Top Spin-style timing cue: a ring shrinks onto a fixed circle hanging above the player.
## The circle stays where it appeared until it is gone: it does not follow the player's
## small steps or the forehand/backhand side, so it never shakes.
## Swipe when the ring meets the circle. The ring runs on game time, so it slows down
## together with the slow-motion window.
##
## The hit verdict (PERFECT / GOOD / LATE ...) appears in a compact strip at the top,
## under the score, so it never covers the court: a PERFECT bursts in gold with small
## sparks, a GOOD gives a soft green pulse.

const INNER := 30.0          # target circle radius (px)
const PX_PER_SEC := 105.0    # ring radius per game second remaining
const GOLD := Color(1.0, 0.85, 0.25)
const GOOD := Color(0.55, 1.0, 0.6)
const LATE := Color(1.0, 0.55, 0.25)
const FEEDBACK_TIME := 0.95  # seconds (real time, unaffected by slow-motion)
const FB_RISE := 46.0        # the verdict sits this far above the ring, where the eyes are at the hit
const FB_FX := 0.55          # size of the verdict's rings and sparks relative to the ring
const STAMINA_TIRED := 0.4   # the arc turns orange (Skills.tired_below(): the legs start to feel it)
const STAMINA_LOW := 0.25    # ...and blinks red
const STAMINA_FRESH := Color(0.92, 0.95, 1.0)
const STAMINA_HALF := Color(1.0, 0.6, 0.2)
const STAMINA_EMPTY := Color(0.95, 0.25, 0.2)

## Where the ring hangs (screen px). Updated every frame.
var scale_k := 1.0         # D-9: the ring follows the player's size on screen (Main sets it; 1 = the normal view)
var anchor := Vector2.ZERO
var top_inset := 0.0         # Telegram's buttons and the notch (HUD sets it): the verdict moves down
var stamina := 1.0           # 0..1, drawn as an arc inside the target circle (HUD sets it)
var show_stamina := false    # during a match
var _blink := 0.0
var _xp_name := ""           # the skill the last stroke trained, with its progress bar
var _xp_level := 0
var _xp_frac := 0.0
var _fb_pos := Vector2.ZERO   # where the verdict appears: at the ring of the stroke it judges

var _active := false
var _hide_left := 0.0        # a brief grace before hiding, so a one-frame gap doesn't move the ring
var _pos := Vector2.ZERO
var _t_left := 0.0
var _perfect := 0.035
var _good := 0.09
var _speed := 1.0            # how fast the ring closes (a beginner's flies in)

var _fb_text := ""
var _fb_sub := ""
var _fb_color := Color.WHITE
var _fb_kind := 0            # 0 plain, 1 good pulse, 2 perfect burst
var _fb_age_s := 100.0
var _sparks: Array[Vector2] = []  # (angle, speed) per spark


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_ring(pos: Vector2, t_left: float, perfect_window: float, good_window: float, speed := 1.0) -> void:
	_speed = speed
	if not _active:
		_pos = pos  # locked here until the ring is hidden
	_active = true
	_hide_left = 0.0
	_t_left = t_left
	_perfect = perfect_window
	_good = good_window
	queue_redraw()


func hide_ring() -> void:
	if _active and _hide_left <= 0.0:
		_hide_left = 0.12


func is_shown() -> bool:
	return _active


## Show a verdict at the ring. kind: 0 plain text, 1 soft pulse, 2 PERFECT burst.
func feedback(text: String, color: Color, sub := "", kind := 0) -> void:
	_fb_text = text
	_fb_sub = sub
	_fb_color = color
	_fb_kind = kind
	_fb_age_s = 0.0
	# At the ring, not in a strip at the top (that one covered the score in Telegram's
	# full screen); the ball has just been hit away, so nothing needed is underneath.
	var vp := get_viewport_rect().size
	var at := (_pos if _active else anchor) - Vector2(0.0, FB_RISE)
	_fb_pos = Vector2(clampf(at.x, 150.0, vp.x - 150.0), clampf(at.y, top_inset + 300.0, vp.y - 200.0))
	_sparks.clear()
	if kind == 2:
		for i in 14:
			_sparks.append(Vector2(TAU * i / 14.0 + randf_range(-0.12, 0.12), randf_range(110.0, 190.0)))
	queue_redraw()


## Under the verdict: the skill this stroke trained and how far it is to the next level.
func skill_progress(skill_name: String, level: int, frac: float) -> void:
	_xp_name = skill_name
	_xp_level = level
	_xp_frac = clampf(frac, 0.0, 1.0)


func set_stamina(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if absf(v - stamina) > 0.004:
		stamina = v
		queue_redraw()


func _process(delta: float) -> void:
	if show_stamina and stamina < 0.995:
		_blink += delta * 6.0
		queue_redraw()  # the faint arc follows the player between balls
	if _hide_left > 0.0:
		_hide_left -= minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
		if _hide_left <= 0.0:
			_active = false
			queue_redraw()
	if _fb_age_s < FEEDBACK_TIME:
		# Unscaled time: slow-motion and hit-stop must not stretch the animation.
		_fb_age_s += minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
		queue_redraw()
	elif _xp_name != "":
		_xp_name = ""  # the skill bar goes with the verdict


func _fb_age() -> float:
	return _fb_age_s


func _draw() -> void:
	if _active:
		_scaled_about(_pos)
		_draw_ring()
	if show_stamina and (_active or stamina < 0.995):
		var c := _pos if _active else anchor
		_scaled_about(c)
		_draw_stamina(c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var age := _fb_age()
	if age < FEEDBACK_TIME and _fb_text != "":
		_draw_feedback(age)


## D-9: everything round is drawn scale_k times as big, about its centre c.
func _scaled_about(c: Vector2) -> void:
	draw_set_transform(c * (1.0 - scale_k), 0.0, Vector2(scale_k, scale_k))


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
	var r := INNER + _t_left * PX_PER_SEC * _speed
	if r > 6.0:
		draw_arc(_pos, r, 0.0, TAU, 64, col, 6.0, true)
	if a <= _perfect:
		draw_arc(_pos, INNER + 9.0, 0.0, TAU, 48, Color(GOLD, 0.5), 3.0, true)


## Stamina: an arc inside the target circle, emptying clockwise from the top. Inside,
## because the closing ring sweeps the outside right before the hit, and two rings
## there would fight at the one moment that matters. Never green or gold (those mean
## GOOD and PERFECT): calm white while fresh, orange once it bites, blinking red near
## empty. Between balls it stays faint over the player.
func _draw_stamina(c: Vector2) -> void:
	var r := INNER - 9.0
	var v := clampf(stamina, 0.0, 1.0)
	var col := STAMINA_FRESH
	if v < STAMINA_LOW:
		col = STAMINA_EMPTY
	elif v < STAMINA_TIRED:
		col = STAMINA_EMPTY.lerp(STAMINA_HALF, (v - STAMINA_LOW) / (STAMINA_TIRED - STAMINA_LOW))
	var alpha := 0.95 if _active else 0.45
	if v < STAMINA_LOW:
		alpha *= 0.55 + 0.45 * absf(sin(_blink))
	draw_arc(c, r, 0.0, TAU, 40, Color(0, 0, 0, 0.3 * alpha), 6.0, true)
	if v > 0.0:
		var start := -PI * 0.5
		draw_arc(c, r, start, start + TAU * v, maxi(4, int(40 * v)), Color(col, alpha), 4.0, true)


func _draw_feedback(age: float) -> void:
	var vp := get_viewport_rect().size
	var c := _fb_pos
	var fade := 1.0 - clampf((age - 0.6) / 0.35, 0.0, 1.0)
	draw_set_transform(c, 0.0, Vector2(FB_FX, FB_FX) * scale_k)
	c = Vector2.ZERO

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
	draw_set_transform(Vector2.ZERO)
	c = _fb_pos

	# The word: pops in (overshoot), sits in the strip, fades out.
	var font := UiTheme.display()       # the menus' faces, not the engine's (UI_FLOW_TZ P2-3)
	var small := UiTheme.text_bold()
	var size := 38 if _fb_kind == 2 else 32
	var pop := 1.0
	if age < 0.22:
		var t := age / 0.22
		pop = lerpf(1.6 if _fb_kind == 2 else 1.3, 1.0, 1.0 - pow(1.0 - t, 3.0)) + sin(t * PI) * 0.08
	var base := Vector2(c.x, c.y + size * 0.35 - age * 6.0)
	var col := Color(_fb_color, fade)
	draw_set_transform(base, 0.0, Vector2(pop, pop))
	var tw := font.get_string_size(_fb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, Vector2(-tw * 0.5, 0.0), _fb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0, 0, 0, 0.8 * fade))
	draw_string(font, Vector2(-tw * 0.5, 0.0), _fb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	draw_set_transform(Vector2.ZERO)

	# Details (stroke, speed) in small print just below.
	if _fb_sub != "":
		var ss := 24  # the HUD's floor: 18 px was ~11 pt on a phone
		var sw := small.get_string_size(_fb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		var sx := clampf(c.x - sw * 0.5, 10.0, vp.x - sw - 10.0)
		var sp := Vector2(sx, c.y + size * 0.35 + 30.0)
		draw_string_outline(small, sp, _fb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, 6, Color(0, 0, 0, 0.75 * fade))
		draw_string(small, sp, _fb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(1, 1, 1, 0.95 * fade))
	if _xp_name != "":
		# The trained skill and its bar, under the verdict (screen space, unscaled).
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var y := _fb_pos.y + 78.0
		var w := 220.0
		var x0 := _fb_pos.x - w * 0.5
		var al := fade
		draw_string_outline(small, Vector2(x0, y - 8.0), "%s %d" % [_xp_name, _xp_level], HORIZONTAL_ALIGNMENT_CENTER, w, 24, 6, Color(0, 0, 0, 0.7 * al))
		draw_string(small, Vector2(x0, y - 8.0), "%s %d" % [_xp_name, _xp_level], HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(1, 1, 1, 0.9 * al))
		draw_rect(Rect2(x0, y, w, 8.0), Color(0, 0, 0, 0.4 * al))
		draw_rect(Rect2(x0, y, w * _xp_frac, 8.0), Color(GOLD, 0.95 * al))

