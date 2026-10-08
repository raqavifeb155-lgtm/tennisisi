class_name OppStaminaView
extends Control
## The opponent's stamina on screen (ROGUELIKE_DESIGN 5.1, "видно, как из него
## выпадает"): a bar over his head that sheds a red chip for every hit (a white trail
## of the loss stays 0.4 s, then the bar catches up), and the number of the hit flying
## out of his chest and falling aside — white for running, yellow for a heavy ball,
## orange for the gear; 25 and up bigger. Below 40% the bar pulses.
## RunHub places it each frame (anchor = the screen point over his head).
##
## Three looks (C-7, the owner found the old bar too big; Tuning.opp_bar_style):
##   1 WORLD   a thin 4 px line right over his head, no frame, narrower when he is far;
##   2 ARC     a 60 px half ring under the score, with the percent below it;
##   3 CORNER  a 120x6 px line under the opponent's name in the score plate; the shards and
##             the number fly from him to it.
## Whatever the look, the bar fades to a quarter while the ball is near it, so it never
## hides the ball; none of them sits in the player's ring or the court's middle.

const POOL := 8
const BAR := Vector2(120, 12)
const TRAIL_HOLD := 0.4
const BIG := 25.0
const WORLD := 1
const ARC := 2
const CORNER := 3
const LEGACY := 0                 # the old 120x12 framed bar with big numbers (only to compare in shots)
const CLEAR := 56.0               # the ball this close to the bar (px): the bar fades
const ARC_R := 30.0               # the half ring: 60 px wide
const CORNER_BAR := Vector2(120, 6)

var value := 100.0                # 0..100
var anchor := Vector2.ZERO        # screen point over his head
var chest := Vector2.ZERO         # where the numbers come out (just over the bar)
var shown := false
var style := WORLD                # which look (RunHub copies Tuning.opp_bar_style)
var unit_px := 100.0              # pixels per meter at the opponent (the world bar's width)
var ball_px := Vector2(-1e4, -1e4)  # the ball on screen, far away when there is none
var board_rect := Rect2(14, 14, 300, 88)  # the score plate (top left)
var name_rect := Rect2()          # the opponent's name cell in it (empty: not known)
var _fade := 1.0
var _trail := 100.0
var _trail_wait := 0.0
var _t := 0.0
var _chips: Array = []            # {x, w, pos, vel, rot, life}
var _numbers: Array[Label] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


static func color_for(kind: String) -> Color:
	match kind:
		"heavy":
			return Color(1.0, 0.86, 0.3)
		"item":
			return Color(1.0, 0.55, 0.15)
		_:
			return Color.WHITE


static func text_for(amount: float) -> String:
	return "−%d" % maxi(1, roundi(amount))


func number_count() -> int:
	return _numbers.size()


func chip_count() -> int:
	return _chips.size()


func reset(v := 100.0) -> void:
	value = v
	_trail = v
	_chips.clear()
	for l in _numbers:
		l.queue_free()
	_numbers.clear()


## The bar's rectangle on screen for the current look (the arc: with its percent).
func bar_rect() -> Rect2:
	match style:
		ARC:
			var c := _arc_center()
			return Rect2(c.x - ARC_R - 4.0, c.y - ARC_R - 6.0, ARC_R * 2.0 + 8.0, ARC_R + 6.0 + 34.0)
		CORNER:
			return Rect2(_corner_pos(), CORNER_BAR)
		LEGACY:
			return Rect2(anchor.x - BAR.x * 0.5, anchor.y - BAR.y, BAR.x, BAR.y)
		_:
			var w := _world_w()
			return Rect2(anchor.x - w * 0.5, anchor.y - 6.0 - 4.0, w, 4.0)


## 0..1: how opaque the bar is now (it fades while the ball is near it).
func bar_alpha() -> float:
	return _fade


func _world_w() -> float:
	return clampf(unit_px * 0.9, 56.0, 110.0)


func _arc_center() -> Vector2:
	# Under the score plate and the status chips (tiebreak, break point) that hang off it.
	return Vector2(board_rect.position.x + 14.0 + ARC_R, board_rect.position.y + 2.0 * ScoreBug.ROW_H + 52.0 + ARC_R)


func _corner_pos() -> Vector2:
	if name_rect.size.x > 0.0:
		return Vector2(name_rect.position.x, name_rect.end.y - CORNER_BAR.y - 2.0)
	return board_rect.position + Vector2(36.0, 2.0 * ScoreBug.ROW_H - CORNER_BAR.y - 6.0)


## Where the lost piece is drawn and where the numbers go, by look.
func _bar_len() -> float:
	match style:
		ARC:
			return PI * ARC_R
		CORNER:
			return CORNER_BAR.x
		LEGACY:
			return BAR.x
		_:
			return _world_w()


func _piece_pos(frac: float) -> Vector2:
	match style:
		ARC:
			var a := PI + clampf(frac, 0.0, 1.0) * PI
			return _arc_center() + Vector2(cos(a), sin(a)) * ARC_R
		CORNER:
			var r := bar_rect()
			return Vector2(r.position.x + r.size.x * frac, r.position.y + r.size.y * 0.5)
		_:
			var r := bar_rect()
			return Vector2(r.position.x + r.size.x * frac, r.position.y + r.size.y * 0.5)


## Where the numbers come out: just over the head (the corner look: they fly to the bar).
func _chest() -> Vector2:
	if style == ARC:
		return _arc_center() + Vector2(ARC_R + 10.0, -ARC_R * 0.5)
	if style == LEGACY:
		return anchor - Vector2(0, BAR.y + 26.0)
	return anchor - Vector2(0, 20.0)


## A hit of `amount` from `kind`; `now` = the stamina after it.
func hit(amount: float, kind: String, now: float) -> void:
	var before := value
	value = now
	_trail = maxf(_trail, before)
	_trail_wait = TRAIL_HOLD
	# The chip: the lost piece of the bar falls off with a spin (the corner look: it
	# flies in from him).
	var mid := (before + now) * 0.5 / 100.0
	var w := maxf((before - now) / 100.0 * _bar_len(), 3.0)
	var c := {"frac": mid, "w": w, "off": Vector2.ZERO, "vel": Vector2(randf_range(-40, 40), -60),
		"rot": 0.0, "spin": randf_range(-6.0, 6.0), "life": 0.8, "fly": style == CORNER, "from": _chest()}
	_chips.append(c)
	_number(amount, kind)


func _number(amount: float, kind: String) -> void:
	var l: Label
	if _numbers.size() >= POOL:
		l = _numbers.pop_front()
		for tw in l.get_meta("tweens", []):
			if tw.is_valid():
				tw.kill()
	else:
		l = Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override("font", UiTheme.display())
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		add_child(l)
	_numbers.append(l)
	var big := amount >= BIG
	l.text = text_for(amount)
	# Next to the score the numbers stay small: they are not over the court.
	var fs := UiTheme.T_TITLE if big else UiTheme.T_HEAD
	if style != LEGACY and style != CORNER:
		fs = UiTheme.T_HEAD if big else UiTheme.T_SMALL + 4  # smaller: the bar is not the show
	var ol := 12 if big else 8
	if style != LEGACY and style != CORNER:
		ol = 6
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_constant_override("outline_size", ol)
	l.add_theme_color_override("font_color", color_for(kind))
	l.modulate = Color.WHITE
	l.reset_size()
	var side := -1.0 if randf() < 0.5 else 1.0
	var start := _chest() - l.size * 0.5
	l.position = start
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	if style == CORNER:
		# Out of him, then to the bar, shrinking into it.
		var to := bar_rect().get_center() - l.size * 0.5
		tw.tween_property(l, "position", start + Vector2(side * 24.0, -34.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position", to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.12)
	elif style == ARC:
		tw.tween_property(l, "position", start + Vector2(side * 6.0, -14.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position", start + Vector2(side * 10.0, 36.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif style == LEGACY:
		tw.tween_property(l, "position", start + Vector2(side * 30.0, -46.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position", start + Vector2(side * 70.0, 40.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(l, "position", start + Vector2(side * 16.0, -24.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position", start + Vector2(side * 36.0, 18.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_numbers.erase(l)
		l.queue_free())
	l.set_meta("tweens", [tw])


## The ball is near the bar (a rect grown by CLEAR px)?
func ball_near() -> bool:
	return bar_rect().grow(CLEAR).has_point(ball_px)


func _process(delta: float) -> void:
	_t += delta
	if _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		_trail = move_toward(_trail, value, delta * 60.0)
	_fade = move_toward(_fade, 0.25 if (shown and ball_near()) else 1.0, delta * 6.0)
	for c in _chips:
		if c["fly"]:
			c["life"] -= delta
		else:
			c["vel"].y += 520.0 * delta
			c["off"] += c["vel"] * delta
			c["rot"] += c["spin"] * delta
			c["life"] -= delta
	_chips = _chips.filter(func(c): return c["life"] > 0.0)
	queue_redraw()


func _fill_color() -> Color:
	var tired := value < OppStamina.TIRED_BELOW
	var fill := UiTheme.WIN if not tired else UiTheme.LOSE
	if tired:
		fill = fill.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 9.0))
	return fill


func _draw() -> void:
	if not shown:
		return
	var a := _fade
	var fill := _fill_color()
	if style == ARC:
		_draw_arc(a, fill)
	else:
		var r := bar_rect()
		if style == CORNER:
			draw_rect(r.grow(1.0), Color(0, 0, 0, 0.5 * a))
		elif style == LEGACY:
			draw_rect(r.grow(3.0), Color(0, 0, 0, 0.55 * a))
		draw_rect(r, Color(1, 1, 1, 0.14 * a))
		draw_rect(Rect2(r.position, Vector2(r.size.x * _trail / 100.0, r.size.y)), Color(1, 1, 1, 0.85 * a))
		draw_rect(Rect2(r.position, Vector2(r.size.x * value / 100.0, r.size.y)), Color(fill, a))
	for c in _chips:
		var k := clampf(c["life"] / 0.8, 0.0, 1.0)
		var pos: Vector2
		if c["fly"]:
			pos = (c["from"] as Vector2).lerp(_piece_pos(c["frac"]), ease(1.0 - k, 0.4))
			k = minf(1.0, k * 2.0)
		else:
			pos = _piece_pos(c["frac"]) + c["off"]
		var h := 3.0 if style == WORLD else (12.0 if style == LEGACY else 6.0)
		draw_set_transform(pos, c["rot"], Vector2.ONE)
		draw_rect(Rect2(Vector2(-minf(c["w"], 16.0 if style == WORLD else 28.0) * 0.5, -h * 0.5), Vector2(minf(c["w"], 16.0 if style == WORLD else 28.0), h)), Color(UiTheme.LOSE, k * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The half ring: an arch of 60 px, the trail white, the stamina colored, the percent under.
func _draw_arc(a: float, fill: Color) -> void:
	var c := _arc_center()
	draw_arc(c, ARC_R, PI, TAU, 24, Color(0, 0, 0, 0.5 * a), 12.0, true)
	draw_arc(c, ARC_R, PI, TAU, 24, Color(1, 1, 1, 0.14 * a), 8.0, true)
	if _trail > 0.5:
		draw_arc(c, ARC_R, PI, PI + PI * _trail / 100.0, 24, Color(1, 1, 1, 0.85 * a), 8.0, true)
	if value > 0.5:
		draw_arc(c, ARC_R, PI, PI + PI * value / 100.0, 24, Color(fill, a), 8.0, true)
	var font := UiTheme.display()
	var txt := "%d%%" % roundi(value)
	var fs := UiTheme.T_BODY - 2
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string_outline(font, c + Vector2(-w * 0.5, 30.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.7 * a))
	draw_string(font, c + Vector2(-w * 0.5, 30.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
