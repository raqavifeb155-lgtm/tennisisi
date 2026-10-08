class_name HudAnnouncer
extends Control
## Everything the match says between points, as one TV caption strip under the score
## (UI_FLOW_TZ 5, the owner's choice "ТВ-строка"): the point's call, then the level-ups,
## the opponent's intro, KNOCKOUT!, the trophy, one after another in the same narrow
## strip. The far court and the opponent are never covered; nothing lands on anything.
##
##   strip   one line (two at most), as wide as its text, ~60 px tall, under the score
##           bug's status chips. One item at a time from a queue; a new call cuts in.
##   hint    one line on a plate above the joystick (the trophy's rule, serve hints).
##
## Text is fitted (40 px down to 28, then the tail goes to a second line), fonts and
## colors come from UiTheme, time is real time (slow motion and hit-stop don't stretch it).

const STRIP_TOP := 150.0        # under the score bug, its status chips and the pause button
const WIDTH := 680.0            # the most the strip may take
const BIG := 40                 # the call, KNOCKOUT!, the name
const SMALL := 28               # the floor for the strip
const HINT := 24
const HINT_Y := 0.775           # of the screen height, above the joystick zone
const CALL_HOLD := 1.1
const TOAST_HOLD := 1.0
const MOMENT_HOLD := 1.2
const FADE := 0.2

var _strip: PanelContainer
var _box: VBoxContainer
var _hint: PanelContainer
var _hint_label: Label
var _hint_relaid := false
var _safe_top := 0.0
var _safe_bottom := 0.0
var _queue: Array[Dictionary] = []   # items waiting: {kind, main, tail, color, frame, key, hold, rarity}
var _current := {}                   # the item on screen ({} = none)
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip = PanelContainer.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.visible = false
	add_child(_strip)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(_box)
	_hint = PanelContainer.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_stylebox_override("panel", _plate(0.6, Color(0, 0, 0, 0)))
	_hint.visible = false
	add_child(_hint)
	_hint_label = _label("", UiTheme.text_bold(), HINT, UiTheme.INK)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_child(_hint_label)
	resized.connect(_layout)


func set_safe_area(top: float, bottom: float) -> void:
	_safe_top = top
	_safe_bottom = bottom
	_layout()


func _layout() -> void:
	_place_strip()
	_place_hint()


# --- What the match says ------------------------------------------------------

## The point's call ("WINNER!") and its tail ("GAME · YOU"). It cuts in: an older call on
## screen is old news and goes, a level-up on screen waits for its turn again.
func call_point(main: String, sub: String, color: Color) -> void:
	var item := {"kind": "call", "main": main, "tail": sub, "color": color, "hold": CALL_HOLD}
	_queue = _queue.filter(func(q: Dictionary) -> bool: return q["kind"] != "call")
	if not _current.is_empty() and _current["kind"] != "call":
		_queue.push_front(_current)
	_queue.push_front(item)
	_current = {}
	_next()


## A level-up (or any progress line), gold. The same key (a skill) updates the line
## already waiting or on screen instead of queueing another.
func toast(text: String, key := "", gold := false) -> void:
	if key != "":
		if _current.get("key", "") == key:
			_current["main"] = text
			_show(_current)
			return
		for q in _queue:
			if q.get("key", "") == key:
				q["main"] = text
				return
	_enqueue({"kind": "toast", "main": text, "tail": "", "color": UiTheme.GOLD, "key": key,
		"frame": UiTheme.GOLD if gold else Color(0, 0, 0, 0), "hold": TOAST_HOLD})


## The opponent before the match, TV style: "ВТОРОЙ КРУГ · Николоз Басилашвили".
func intro(round_name: String, player: String) -> void:
	_enqueue({"kind": "moment", "main": round_name, "tail": player, "color": UiTheme.GOLD,
		"tail_font": "display", "hold": 1.6})


## A big word (KNOCKOUT!, TROPHY LOST) with an optional Russian tail.
func moment(text: String, color: Color, sub := "", hold := MOMENT_HOLD) -> void:
	_enqueue({"kind": "moment", "main": text, "tail": sub, "color": color, "hold": hold})


## A gear item in its rarity's color and frame: "ТРОФЕЙ · Легендарная «Громовержец»".
## The full card (effects, compare) is on the result screen; the court stays clear.
func item_card(item: Dictionary, head: String, hold := 1.6) -> void:
	var r := clampi(int(item.get("rarity", 0)), 0, UiTheme.RARITY_NAMES.size() - 1)
	var c := UiTheme.rarity_color(r)
	_enqueue({"kind": "item", "main": head, "tail": String(item.get("name", "")), "color": c,
		"frame": c, "rarity": r, "hold": hold, "tail_font": "display"})


## A tap: the item on screen goes, the next one comes.
func skip() -> void:
	if _current.is_empty():
		return
	_current = {}
	_next()


## Everything off the screen at once (the match ended, the menus open).
func finish_now() -> void:
	_queue.clear()
	_current = {}
	if _tween:
		_tween.kill()
	_strip.visible = false
	set_hint("")


func current() -> Dictionary:
	return _current


func waiting() -> int:
	return _queue.size()


func strip() -> Control:
	return _strip


# --- The hint -----------------------------------------------------------------

func set_hint(text: String) -> void:
	_hint_label.text = text
	_hint.visible = text != ""
	_place_hint()


func hint_text() -> String:
	return _hint_label.text if _hint.visible else ""


# --- Inside -------------------------------------------------------------------

func _enqueue(item: Dictionary) -> void:
	_queue.append(item)
	if _current.is_empty():
		_next()


func _next() -> void:
	if _tween:
		_tween.kill()
	if _queue.is_empty():
		_current = {}
		if _strip.visible:
			_tween = _strip.create_tween()
			_tween.set_ignore_time_scale(true)
			_tween.tween_property(_strip, "modulate:a", 0.0, FADE)
			_tween.tween_callback(func() -> void: _strip.visible = false)
		return
	_current = _queue.pop_front()
	_show(_current)


## Builds the strip for an item and runs its clock: in, hold, then the next one.
func _show(item: Dictionary) -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var main_font := UiTheme.display() if item["kind"] != "toast" else UiTheme.text_bold()
	var tail_font := UiTheme.display() if item.get("tail_font", "") == "display" else UiTheme.text_bold()
	var main: String = item["main"]
	var tail: String = item["tail"]
	var inner := WIDTH - 40.0
	var sep := "  ·  "
	var one_line := main + (sep + tail if tail != "" else "")
	var s := UiText.fit_size(main_font, one_line, inner, BIG if item["kind"] != "toast" else 32, SMALL)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	row.add_child(_label(main, main_font, s, item["color"]))
	var tail_color: Color = UiTheme.INK if item["kind"] != "item" else item["color"]
	if tail != "" and UiText.fits(main_font, one_line, inner, s):
		row.add_child(_label(sep, UiTheme.text_bold(), s, Color(UiTheme.INK, 0.6)))
		row.add_child(_label(tail, tail_font, s, tail_color))
	elif tail != "":
		# Too long for one line even at the floor: the tail goes under, a size smaller.
		var ts := UiText.fit_size(tail_font, tail, inner, SMALL, 24)
		var t := _label(tail, tail_font, ts, tail_color)
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.clip_text = true
		t.custom_minimum_size.x = minf(inner, tail_font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x)
		_box.add_child(t)
	_strip.add_theme_stylebox_override("panel", _plate(0.72, item.get("frame", Color(0, 0, 0, 0))))
	if item.has("rarity"):
		_strip.set_meta("rarity", item["rarity"])
	elif _strip.has_meta("rarity"):
		_strip.remove_meta("rarity")
	_strip.visible = true
	_place_strip()
	_strip.modulate.a = 0.0
	_tween = _strip.create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(_strip, "modulate:a", 1.0, FADE).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(float(item["hold"]))
	_tween.tween_callback(func() -> void:
		if _current == item:
			_current = {}
			_next())


func _place_strip() -> void:
	_strip.reset_size()
	var w := _strip.get_combined_minimum_size().x
	_strip.size = Vector2(w, 0)
	_strip.reset_size()
	_strip.position = Vector2(((size.x - _strip.size.x) * 0.5), STRIP_TOP + _safe_top)


func _place_hint() -> void:
	var inner := WIDTH - 40.0
	var font := UiTheme.text_bold()
	var text := _hint_label.text
	# Lines that fit stay unwrapped (the plate is exactly as wide as the text). A wrapping
	# label measures its height from its last layout, so a narrow first layout made the
	# plate a screen tall (it showed as a dark box behind the serve hint): wrap only when a
	# line is too long, and lay out once more next frame when it does.
	var fits := UiText.fits(font, text, inner - 8.0, HINT)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF if fits else TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = 0.0 if fits else inner
	_hint_label.size = Vector2(inner if not fits else 0.0, 0.0)
	_hint.size = Vector2.ZERO
	_hint.reset_size()
	_hint.position = Vector2((size.x - _hint.size.x) * 0.5, size.y * HINT_Y - _safe_bottom - _hint.size.y * 0.5)
	if not fits and not _hint_relaid:
		_hint_relaid = true
		_relay_hint.call_deferred()


func _relay_hint() -> void:
	_place_hint()
	_hint_relaid = false


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


## A thin dark band, like a TV caption; a colored frame for a rarity or a perk level-up.
func _plate(alpha: float, frame: Color) -> StyleBoxFlat:
	var sb := UiTheme.box(Color(UiTheme.SURFACE, alpha), Color(0, 0, 0, 0), 0, 12, 6)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	if frame.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = frame
	return sb
