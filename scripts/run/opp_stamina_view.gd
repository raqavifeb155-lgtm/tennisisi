class_name OppStaminaView
extends Control
## The opponent's stamina on screen (ROGUELIKE_DESIGN 5.1, "видно, как из него
## выпадает"): a bar over his head that sheds a red chip for every hit (a white trail
## of the loss stays 0.4 s, then the bar catches up), and the number of the hit flying
## out of his chest and falling aside — white for running, yellow for a heavy ball,
## orange for the gear; 25 and up bigger. Below 40% the bar pulses.
## RunHub places it each frame (anchor = the screen point over his head).

const POOL := 8
const BAR := Vector2(120, 12)
const TRAIL_HOLD := 0.4
const BIG := 25.0

var value := 100.0                # 0..100
var anchor := Vector2.ZERO        # screen point over his head
var chest := Vector2.ZERO         # where the numbers come out (just over the bar)
var shown := false
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


## A hit of `amount` from `kind`; `now` = the stamina after it.
func hit(amount: float, kind: String, now: float) -> void:
	var before := value
	value = now
	_trail = maxf(_trail, before)
	_trail_wait = TRAIL_HOLD
	# The chip: the lost piece of the bar falls off with a spin.
	var x0 := now / 100.0 * BAR.x
	var w := maxf((before - now) / 100.0 * BAR.x, 3.0)
	_chips.append({"x": x0, "w": w, "pos": Vector2(x0 + w * 0.5 - BAR.x * 0.5, 0), "vel": Vector2(randf_range(-40, 40), -60),
		"rot": 0.0, "spin": randf_range(-6.0, 6.0), "life": 0.8})
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
	l.add_theme_font_size_override("font_size", UiTheme.T_TITLE if big else UiTheme.T_HEAD)
	l.add_theme_constant_override("outline_size", 12 if big else 8)
	l.add_theme_color_override("font_color", color_for(kind))
	l.modulate = Color.WHITE
	l.reset_size()
	var side := -1.0 if randf() < 0.5 else 1.0
	var start := chest - l.size * 0.5
	l.position = start
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(l, "position", start + Vector2(side * 30.0, -46.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", start + Vector2(side * 70.0, 40.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_numbers.erase(l)
		l.queue_free())
	l.set_meta("tweens", [tw])


func _process(delta: float) -> void:
	_t += delta
	if _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		_trail = move_toward(_trail, value, delta * 60.0)
	for c in _chips:
		c["vel"].y += 520.0 * delta
		c["pos"] += c["vel"] * delta
		c["rot"] += c["spin"] * delta
		c["life"] -= delta
	_chips = _chips.filter(func(c): return c["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	if not shown:
		return
	var top_left := anchor - Vector2(BAR.x * 0.5, BAR.y)
	var r := Rect2(top_left, BAR)
	draw_rect(r.grow(3.0), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(1, 1, 1, 0.12))
	draw_rect(Rect2(top_left, Vector2(BAR.x * _trail / 100.0, BAR.y)), Color(1, 1, 1, 0.85))
	var tired := value < OppStamina.TIRED_BELOW
	var fill := UiTheme.WIN if not tired else UiTheme.LOSE
	if tired:
		fill = fill.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 9.0))
	draw_rect(Rect2(top_left, Vector2(BAR.x * value / 100.0, BAR.y)), fill)
	for c in _chips:
		var a := clampf(c["life"] / 0.8, 0.0, 1.0)
		draw_set_transform(anchor + Vector2(0, -BAR.y * 0.5) + c["pos"], c["rot"], Vector2.ONE)
		draw_rect(Rect2(Vector2(-c["w"] * 0.5, -BAR.y * 0.5), Vector2(c["w"], BAR.y)), Color(UiTheme.LOSE, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
