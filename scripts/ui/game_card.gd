class_name GameCard
extends Button
## A card you handle, after Balatro: a physical object rather than a settings row.
## It sways a little at rest, tilts toward the finger while pressed, and can lie face
## down and flip over. A rarity card (0..4, see UiTheme.RARITY) wears its color as the
## frame; from epic up a band of light sweeps across it and it glows; mythic pulses.
## Cards without a rarity (choices, perks) use a quiet frame or a given accent.

signal flipped

var tag := ""
var title := ""
var desc := ""
var accent := Color(0, 0, 0, 0)   # frame color for a card without a rarity
var rarity := -1                  # -1 none, 0..4 gray .. mythic
var face_down := false
var selected := false             # a lit choice (e.g. the current control scheme)

var _content: VBoxContainer
var _back: Control
var _shine: Control
var _t := 0.0
var _phase := 0.0
var _hold := false
var _tilt := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # the shine stays inside the card
	_phase = randf() * TAU


func _ready() -> void:
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = 30
	_content.offset_right = -30
	_content.offset_top = 22
	_content.offset_bottom = -22
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 6)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	if tag != "":
		var tl := _line(tag, UiTheme.text_bold(), UiTheme.T_SMALL, _frame_color() if _frame_color().a > 0.2 else UiTheme.MUTED)
		_content.add_child(tl)
	var tt := _line(title, UiTheme.display(), UiTheme.T_HEAD, UiTheme.INK)
	tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(tt)
	if desc != "":
		var d := _line(desc, UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(d)

	if rarity >= 2:
		_shine = Shine.new()
		_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_shine)
	_back = Back.new()
	(_back as Back).color = _frame_color() if rarity >= 0 else UiTheme.GOLD
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_back)
	_apply_face()
	_restyle()
	resized.connect(func() -> void:
		pivot_offset = size * 0.5
		_fit.call_deferred())
	_content.minimum_size_changed.connect(_fit)
	custom_minimum_size = Vector2(0, 170)
	_fit.call_deferred()
	button_down.connect(func() -> void: _hold = true)
	button_up.connect(func() -> void: _hold = false)
	mouse_exited.connect(func() -> void: _hold = false)


## The card is as tall as its text (wrapped lines included), never shorter than 170.
func _fit() -> void:
	if _content == null:
		return
	var h := maxf(170.0, _content.get_combined_minimum_size().y + 44.0)
	if absf(custom_minimum_size.y - h) > 0.5:
		custom_minimum_size = Vector2(0, h)


func _line(s: String, f: Font, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _frame_color() -> Color:
	if rarity >= 0:
		return UiTheme.rarity_color(rarity)
	if selected:
		return UiTheme.GOLD
	return accent if accent.a > 0.0 else UiTheme.LINE


func _restyle() -> void:
	var c := _frame_color()
	var w := 4 if rarity >= 0 or selected or accent.a > 0.0 else 2
	var bg := UiTheme.SURFACE.lerp(c, 0.07) if rarity >= 0 else UiTheme.SURFACE
	var normal := UiTheme.box(bg, c, w, UiTheme.RADIUS, 0)
	if rarity >= 2 and not face_down:
		normal.shadow_color = Color(c, 0.42 if rarity < 4 else 0.6)
		normal.shadow_size = 20 if rarity < 4 else 30
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", normal)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.06)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", normal)


func _apply_face() -> void:
	if _content:
		_content.visible = not face_down
	if _back:
		_back.visible = face_down
	if _shine:
		_shine.visible = not face_down


## Turns the card over (face down -> up): it narrows to an edge, swaps sides, opens.
func flip(delay := 0.0) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_property(self, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tw.tween_callback(func() -> void:
		face_down = not face_down
		_apply_face()
		_restyle()
		flipped.emit())
	tw.tween_property(self, "scale:x", 1.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)


func _gui_input(event: InputEvent) -> void:
	# Pressed and dragged: the card leans toward the finger, like a card held by a corner.
	if event is InputEventMouseMotion and _hold and size.x > 0.0:
		_tilt = clampf((event.position.x - size.x * 0.5) / size.x, -0.5, 0.5)


func _process(delta: float) -> void:
	_t += delta
	var target := _tilt * 0.07 if _hold else sin(_t * 1.3 + _phase) * 0.006
	if not _hold:
		_tilt = lerpf(_tilt, 0.0, 1.0 - exp(-8.0 * delta))
	rotation = lerpf(rotation, target, 1.0 - exp(-12.0 * delta))
	if _shine and _shine.visible:
		(_shine as Shine).t = fmod(_t + _phase, 2.8 if rarity < 4 else 1.8)
		_shine.queue_redraw()
	if rarity >= 4 and not face_down:
		modulate = Color(1, 1, 1).lerp(Color(1.12, 1.0, 1.0), 0.5 + 0.5 * sin(_t * 3.0))


## A diagonal band of light that crosses the card now and then (epic and up).
class Shine extends Control:
	var t := 0.0

	func _draw() -> void:
		var k := t / 0.7  # crosses in 0.7 s, then waits
		if k > 1.0:
			return
		var w := size.x
		var h := size.y
		var x := lerpf(-0.4 * w, 1.4 * w, k)
		var band := 0.16 * w
		var pts := PackedVector2Array([Vector2(x - band, h), Vector2(x, h), Vector2(x + h * 0.45, 0), Vector2(x + h * 0.45 - band, 0)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.13))


## The back of a face-down card: a quiet diamond lattice in the card's color.
class Back extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BASE.lerp(color, 0.1))
		var step := 34.0
		var c := Color(color, 0.22)
		var n := int((size.x + size.y) / step) + 2
		for i in n:
			var o := i * step - size.y
			draw_line(Vector2(o, size.y), Vector2(o + size.y, 0), c, 2.0)
			draw_line(Vector2(o, 0), Vector2(o + size.y, size.y), c, 2.0)
		var mid := size * 0.5
		draw_circle(mid, 34.0, UiTheme.BASE)
		draw_arc(mid, 34.0, 0.0, TAU, 40, color, 4.0, true)
		draw_string(UiTheme.display(), mid + Vector2(-9, 13), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, color)
