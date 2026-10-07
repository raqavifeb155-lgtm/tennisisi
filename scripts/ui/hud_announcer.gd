class_name HudAnnouncer
extends Control
## Everything the match says on screen, laid out by one scheme (UI_FLOW_TZ 5) so that no
## two texts land on each other and none runs off the screen:
##
##   column   under the score, centred, 640 wide: the point's call, then a reserved slot
##            (VAR, the style plate), then up to two level-up toasts. A VBoxContainer: no
##            y is written by hand, each item sits under the one before.
##   centre   one big moment at a time (the opponent's intro, KNOCKOUT!, the trophy card),
##            the rest wait their turn; the column holds still meanwhile; a tap skips.
##   hint     one line on a plate above the joystick (the trophy's rule, serve hints).
##
## Calls are fitted (56 px down to 40, then wrapped to two lines), fonts and colors come
## from UiTheme, and time is real time (slow motion and hit-stop don't stretch it).

const COLUMN_TOP := 130.0       # under the score bug and the pause button (14..110)
const WIDTH := 640.0
const CALL_MAX := 56
const CALL_MIN := 40
const SUB := 28
const TOAST := 28
const MAX_TOASTS := 2
const MOMENT_MAX := 76
const MOMENT_MIN := 48
const CARD_W := 560.0
const HINT_Y := 0.775           # of the screen height, above the joystick zone
const SEP := 10

var _column: VBoxContainer
var _center: CenterContainer
var _hint: PanelContainer
var _hint_label: Label
var _safe_top := 0.0
var _safe_bottom := 0.0
var _pending_toasts: Array[Array] = []    # [text, key, gold] waiting for room
var _moments: Array[Callable] = []        # builders of the moments waiting their turn
var _moment: Control                      # the one on screen
var _moment_tween: Tween
var _tweens := {}                         # column item -> its tween (paused under a moment)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", SEP)
	add_child(_column)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_hint = PanelContainer.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_stylebox_override("panel", _plate(0.8))
	_hint.visible = false
	add_child(_hint)
	_hint_label = _label("", UiTheme.text_bold(), 24, UiTheme.INK)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = WIDTH - 48.0
	_hint.add_child(_hint_label)
	resized.connect(_layout)


func set_safe_area(top: float, bottom: float) -> void:
	_safe_top = top
	_safe_bottom = bottom
	_layout()


func _layout() -> void:
	_column.position = Vector2((size.x - WIDTH) * 0.5, COLUMN_TOP + _safe_top)
	_column.size = Vector2(WIDTH, 0)
	_center.position = Vector2(0, _safe_top)
	_center.size = Vector2(size.x, size.y - _safe_top - _safe_bottom)
	_place_hint()


# --- The column ---------------------------------------------------------------

## The point's verdict: a fitted call and an optional second line. A new call replaces
## the one still on screen (it is old news by then).
func call_point(main: String, sub: String, color: Color) -> void:
	for c in column_items():
		if c.has_meta("call"):
			_drop(c)
	var p := PanelContainer.new()
	p.set_meta("call", true)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _plate(0.85))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(_fitted(main, UiTheme.display(), CALL_MAX, CALL_MIN, color))
	if sub != "":
		v.add_child(_fitted(sub, UiTheme.text_bold(), SUB, 24, Color(color, 0.92)))
	_column.add_child(p)
	_column.move_child(p, 0)
	_pop_in(p, 1.15)
	_hold(p, 1.1, 0.3)


## A level-up (or any progress line). Two on screen at most, the rest wait; the same
## key (a skill) updates its toast in place instead of stacking a new one.
func toast(text: String, key := "", gold := false) -> void:
	if key != "":
		for c in column_items():
			if c.get_meta("key", "") == key:
				(c.get_child(0) as Label).text = text
				_hold(c, 1.6, 0.4)
				return
		for w in _pending_toasts:
			if w[1] == key:
				w[0] = text
				return
	if _toast_count() >= MAX_TOASTS:
		_pending_toasts.append([text, key, gold])
		return
	var p := PanelContainer.new()
	p.set_meta("toast", true)
	p.set_meta("key", key)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _plate(0.8)
	if gold:
		sb.set_border_width_all(2)
		sb.border_color = UiTheme.GOLD
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, UiTheme.text_bold(), TOAST, UiTheme.GOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH - 48.0
	p.add_child(l)
	_column.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_hold(p, 1.6, 0.4)


## Room in the column right under the call, for something drawn elsewhere (the VAR
## panel, the style plate): returns the y of its top in screen space.
func reserve(height: float, seconds: float) -> float:
	var slot := Control.new()
	slot.set_meta("slot", true)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(WIDTH, height)
	var at := 0
	for c in column_items():
		if c.has_meta("call") or c.has_meta("slot"):
			at += 1
	var y := _column.global_position.y
	var items := column_items()
	for i in at:
		y += items[i].get_combined_minimum_size().y + SEP
	_column.add_child(slot)
	_column.move_child(slot, at)
	_hold(slot, seconds, 0.0)
	return y


func column_items() -> Array[Control]:
	var out: Array[Control] = []
	for c in _column.get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
	return out


func waiting_toasts() -> int:
	return _pending_toasts.size()


# --- The centre ---------------------------------------------------------------

## The opponent before the match, as a TV plate: the round, then the full name.
func intro(round_name: String, player: String) -> void:
	_queue_moment(func() -> Array:
		var p := PanelContainer.new()
		var sb := _plate(0.92)
		sb.set_border_width_all(2)
		sb.border_color = Color(UiTheme.GOLD, 0.6)
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		v.add_child(_fitted(round_name, UiTheme.text_bold(), SUB, 24, UiTheme.GOLD))
		v.add_child(_fitted(player, UiTheme.display(), 48, 32, UiTheme.INK))
		return [p, 1.6])


## A big word in the middle (KNOCKOUT!, TROPHY LOST) with an optional Russian line.
func moment(text: String, color: Color, sub := "", hold := 1.2) -> void:
	_queue_moment(func() -> Array:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		var big := _fitted(text, UiTheme.display(), MOMENT_MAX, MOMENT_MIN, color)
		big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		big.add_theme_constant_override("outline_size", 10)
		v.add_child(big)
		if sub != "":
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", _plate(0.85))
			p.add_child(_fitted(sub, UiTheme.text_bold(), SUB, 24, UiTheme.INK))
			v.add_child(p)
		return [v, hold])


## A gear item as a card (frame, shine and glow of its rarity), e.g. the trophy.
func item_card(item: Dictionary, head: String, hold := 1.6) -> void:
	_queue_moment(func() -> Array:
		var card := GameCard.new()
		var r := int(item.get("rarity", 0))
		card.rarity = r
		card.tag = "%s  ·  %s" % [head, UiTheme.RARITY_NAMES[clampi(r, 0, UiTheme.RARITY_NAMES.size() - 1)]]
		card.title = String(item.get("name", ""))
		card.desc = Gear.describe(item) if not item.is_empty() else ""
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size = Vector2(CARD_W, 0)
		return [card, hold])


## A tap during a moment: the next one, or the column moves on again.
func skip() -> void:
	if _moment == null:
		return
	if _moment_tween:
		_moment_tween.kill()
	_center.remove_child(_moment)
	_moment.queue_free()
	_moment = null
	_next_moment()


func center_item() -> Control:
	return _moment


func waiting_moments() -> int:
	return _moments.size()


# --- The hint -----------------------------------------------------------------

func set_hint(text: String) -> void:
	_hint_label.text = text
	_hint.visible = text != ""
	_place_hint()


func hint_text() -> String:
	return _hint_label.text if _hint.visible else ""


func _place_hint() -> void:
	_hint.reset_size()
	var w := WIDTH
	_hint.size = Vector2(w, 0)
	_hint.reset_size()
	_hint.position = Vector2((size.x - w) * 0.5, size.y * HINT_Y - _safe_bottom - _hint.size.y * 0.5)


## Everything off the screen at once (the match ended, the menus open).
func finish_now() -> void:
	for c in column_items():
		_column.remove_child(c)
		c.queue_free()
	_tweens.clear()
	_pending_toasts.clear()
	_moments.clear()
	if _moment:
		if _moment_tween:
			_moment_tween.kill()
		_center.remove_child(_moment)
		_moment.queue_free()
		_moment = null
	set_hint("")


# --- Inside -------------------------------------------------------------------

func _queue_moment(build: Callable) -> void:
	_moments.append(build)
	if _moment == null:
		_next_moment()


func _next_moment() -> void:
	if _moments.is_empty():
		_pause_column(false)
		return
	var build: Callable = _moments.pop_front()
	var made: Array = build.call()
	_moment = made[0]
	var hold: float = made[1]
	_moment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_moment)
	_pause_column(true)
	_moment.modulate.a = 0.0
	_moment.scale = Vector2(0.85, 0.85)
	_moment.resized.connect(func() -> void: _moment.pivot_offset = _moment.size * 0.5)
	var m := _moment
	_moment_tween = m.create_tween()
	_moment_tween.set_ignore_time_scale(true)
	_moment_tween.tween_property(m, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_moment_tween.parallel().tween_property(m, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_moment_tween.tween_interval(hold)
	_moment_tween.tween_property(m, "modulate:a", 0.0, 0.25)
	_moment_tween.tween_callback(func() -> void:
		if _moment == m:
			skip())


func _pause_column(on: bool) -> void:
	for tw in _tweens.values():
		if tw is Tween and (tw as Tween).is_valid():
			if on:
				(tw as Tween).pause()
			else:
				(tw as Tween).play()


func _toast_count() -> int:
	var n := 0
	for c in column_items():
		if c.has_meta("toast"):
			n += 1
	return n


## Stays `hold` seconds, fades in `fade`, leaves; a toast leaving lets a waiting one in.
func _hold(c: Control, hold: float, fade: float) -> void:
	if _tweens.has(c) and (_tweens[c] as Tween).is_valid():
		(_tweens[c] as Tween).kill()
	if c.modulate.a > 0.0:
		c.modulate.a = 1.0  # an updated toast comes back to full
	var tw := c.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(hold)
	if fade > 0.0:
		tw.tween_property(c, "modulate:a", 0.0, fade)
	tw.tween_callback(func() -> void: _drop(c))
	_tweens[c] = tw
	if _moment != null:
		tw.pause()


func _drop(c: Control) -> void:
	if not is_instance_valid(c) or c.is_queued_for_deletion():
		return
	var was_toast := c.has_meta("toast")
	if _tweens.has(c):
		var tw: Tween = _tweens[c]
		if tw.is_valid():
			tw.kill()
		_tweens.erase(c)
	_column.remove_child(c)
	c.queue_free()
	if was_toast and not _pending_toasts.is_empty():
		var w: Array = _pending_toasts.pop_front()
		toast(w[0], w[1], w[2])


func _pop_in(c: Control, from: float) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	c.scale = Vector2(from, from)
	var tw := c.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## A centred label as big as fits the column (wrapped to two lines below the floor).
func _fitted(text: String, font: Font, max_size: int, min_size: int, color: Color) -> Label:
	var inner := WIDTH - 48.0
	var s := UiText.fit_size(font, text, inner, max_size, min_size)
	var l := _label(text, font, s, color)
	if not UiText.fits(font, text, inner, s):
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 2
		l.custom_minimum_size = Vector2(inner, font.get_height(s) * 2.0)
	return l


func _label(text: String, font: Font, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _plate(alpha: float) -> StyleBoxFlat:
	var sb := UiTheme.box(Color(UiTheme.SURFACE, alpha), Color(0, 0, 0, 0), 0, 18, 12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	return sb
