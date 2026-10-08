class_name GameCard
extends Button
## A card you handle, after Balatro: a physical object rather than a settings row.
## It sways a little at rest, tilts toward the finger while pressed, and can lie face
## down and flip over. A rarity card (0..4, see UiTheme.RARITY) wears its color as the
## frame; from epic up a band of light sweeps across it and it glows; mythic pulses.
## Cards without a rarity (choices, perks) use a quiet frame or a given accent.
##
## v0.2 L (docs/superpowers/specs/2026-10-08-v02-L-loot-cards.md): a card of a thing wears
## its picture (ItemThumb); a face-down card shows nothing readable, only its back in the
## rarity's colour with a pattern, and turns over (flip) with a flash from the tap or by
## turns; a card that needs no turning rides in from below with a bounce (enter).

signal flipped                    # in the middle of the turn: the face has just been swapped
signal revealed                   # the turn is over, the card can be taken

var tag := ""
var title := ""
var desc := ""
var accent := Color(0, 0, 0, 0)   # frame color for a card without a rarity
var rarity := -1                  # -1 none, 0..4 gray .. mythic
var face_down := false
var selected := false             # a lit choice (e.g. the current control scheme)
var item := {}                    # a thing: its picture sits on the card ({} + item_slot = the stock one)
var item_slot := ""
var flipping := false             # the card is turning right now

var _content: VBoxContainer
var _back: Control
var _shine: Control
var _thumb: Control
var _flip_tw: Tween
var _t := 0.0
var _phase := 0.0
var _hold := false
var _tilt := 0.0


const THUMB := 132.0               # the picture of a thing on its card


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
	if not item.is_empty() or item_slot != "":
		_thumb = ItemThumb.view(item, item_slot, THUMB)
		(_thumb as ItemThumb.ThumbView).dim = item.is_empty()
		_thumb.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		_thumb.offset_left = 18
		_thumb.offset_right = 18 + THUMB
		_thumb.offset_top = -THUMB * 0.5
		_thumb.offset_bottom = THUMB * 0.5
		add_child(_thumb)
		_content.offset_left = 30 + THUMB + 6
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

	_shine = Shine.new()  # epic and up: always; the others only when the card is shown (sweep)
	(_shine as Shine).always = rarity >= 2
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shine)
	_back = Back.new()
	(_back as Back).color = _frame_color() if rarity >= 0 else (accent if accent.a > 0.3 else UiTheme.GOLD)
	(_back as Back).rarity = rarity
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
	if rarity >= 2:  # a face-down card already glows in its colour: that is the waiting
		normal.shadow_color = Color(c, (0.42 if rarity < 4 else 0.6) * (0.7 if face_down else 1.0))
		normal.shadow_size = (20 if rarity < 4 else 30) if not face_down else 14
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", normal)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.06)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", normal)


func _apply_face() -> void:
	if _content:
		# Not `visible = false`: a hidden box is not laid out, its wrapped text would measure
		# one letter a line and the card would grow tall. The back covers it, and it is clear.
		_content.modulate.a = 0.0 if face_down else 1.0
	if _thumb:
		_thumb.visible = not face_down
	if _back:
		_back.visible = face_down
	if _shine:
		_shine.visible = not face_down


## Turns a face-down card over: it narrows to an edge, swaps sides, opens. `delay` waits
## first; `quick` is the turn of a tap that opens the whole row at once.
func flip(delay := 0.0, quick := false) -> void:
	if not face_down:
		return
	if _flip_tw != null and _flip_tw.is_valid():
		_flip_tw.kill()  # a turn that still waits starts over, faster
	flipping = true
	_flip_tw = create_tween()
	var tw := _flip_tw
	tw.set_ignore_time_scale(true)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(self, "scale:x", 0.0, 0.06 if quick else 0.12).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tw.tween_callback(func() -> void:
		face_down = false
		_apply_face()
		_restyle()
		sweep()
		flipped.emit())
	tw.tween_property(self, "scale:x", 1.0, 0.09 if quick else 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_callback(func() -> void:
		flipping = false
		revealed.emit())


## Face up and not turning: the card can be chosen.
func is_open() -> bool:
	return not face_down and not flipping


## What a player can read on the card right now (a face-down card: nothing).
func visible_text() -> String:
	var out: Array[String] = []
	for l in find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text != "" and _alpha_to_card(l) > 0.05:
			out.append((l as Label).text)
	return "  ".join(out)


## How opaque a node is on the card: the product of its own and its parents' alpha.
func _alpha_to_card(n: Node) -> float:
	var a := 1.0
	while n != null and n != self:
		if n is CanvasItem:
			a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


## One band of light across the card (every rarity: the epic and up have it again and again).
func sweep() -> void:
	if _shine:
		(_shine as Shine).burst()


## A pop of the whole card with a white flash over it: the moment of a win.
func pop(color := Color.WHITE) -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "scale", Vector2(1.07, 1.07), 0.09).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fl := Flash.new()
	fl.color = color
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fl)
	var ft := fl.create_tween()
	ft.set_ignore_time_scale(true)
	ft.tween_property(fl, "modulate:a", 0.0, 0.45).from(1.0)
	ft.tween_callback(fl.queue_free)


## A card that needs no turning rides in from below and settles with a bounce, with one
## sweep of light. Waits for the layout to settle first (the container owns the position).
func enter(delay := 0.0, rise := 240.0) -> void:
	for i in 3:
		await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var to := position.y
	position.y = to + rise
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_property(self, "position:y", to, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(sweep)


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
		(_shine as Shine).tick(delta, fmod(_t + _phase, 2.8 if rarity < 4 else 1.8))
	if _back and _back.visible:
		(_back as Back).t = _t
		_back.queue_redraw()
	if rarity >= 4 and not face_down:
		modulate = Color(1, 1, 1).lerp(Color(1.12, 1.0, 1.0), 0.5 + 0.5 * sin(_t * 3.0))


## A diagonal band of light: again and again from epic up (`always`), else on burst().
class Shine extends Control:
	var t := 0.0
	var always := false
	var _burst := -1.0

	func burst() -> void:
		_burst = 0.0

	func tick(delta: float, cycle: float) -> void:
		if always:
			t = cycle
		elif _burst >= 0.0:
			t = _burst
			_burst += delta
			if _burst > 0.9:
				_burst = -1.0
		elif t < 90.0:
			t = 99.0  # one last redraw to clear the band
		else:
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.7  # crosses in 0.7 s, then waits
		if k > 1.0:
			return
		var w := size.x
		var h := size.y
		var x := lerpf(-0.4 * w, 1.4 * w, k)
		var band := 0.16 * w
		var pts := PackedVector2Array([Vector2(x - band, h), Vector2(x, h), Vector2(x + h * 0.45, 0), Vector2(x + h * 0.45 - band, 0)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.13 if always else 0.2))


## A white flash laid over the card for a moment.
class Flash extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(color.lerp(Color.WHITE, 0.5), 0.55))


## The back of a face-down card: no words, a diamond lattice and an emblem in the card's
## colour. The higher the rarity, the more is on it (a second ring, a crown of diamonds,
## turning rays, a flickering edge) and the more it pulses: the waiting is part of the win.
class Back extends Control:
	var color := Color.WHITE
	var rarity := -1
	var t := 0.0

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		var strong := maxi(rarity, 0)
		var fill := 0.1 + (0.05 + 0.07 * pulse if rarity >= 2 else 0.0)
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BASE.lerp(color, fill))
		var step := 34.0
		var c := Color(color, 0.22)
		var n := int((size.x + size.y) / step) + 2
		for i in n:
			var o := i * step - size.y
			draw_line(Vector2(o, size.y), Vector2(o + size.y, 0), c, 2.0)
			draw_line(Vector2(o, 0), Vector2(o + size.y, size.y), c, 2.0)
		var mid := size * 0.5
		if rarity >= 3:  # rays turn behind the emblem
			var rays := 12 if rarity == 3 else 18
			for i in rays:
				var a := t * (0.5 if rarity == 3 else 0.9) + TAU * i / rays
				draw_line(mid + Vector2.from_angle(a) * 62.0, mid + Vector2.from_angle(a) * (size.x * 0.5), Color(color, 0.16 + 0.1 * pulse), 3.0)
		draw_rect(Rect2(Vector2(12, 12), size - Vector2(24, 24)), Color(color, 0.35 + (0.3 * pulse if rarity >= 2 else 0.0)), false, 3.0)
		if rarity >= 4:  # a flickering edge
			var jag := PackedVector2Array()
			var steps := int(size.x / 22.0)
			for i in steps + 1:
				jag.append(Vector2(i * 22.0, 4.0 + 8.0 * absf(sin(t * 7.0 + i * 1.7))))
			draw_polyline(jag, Color(color, 0.7), 3.0)
			var jag2 := PackedVector2Array()
			for i in steps + 1:
				jag2.append(Vector2(i * 22.0, size.y - 4.0 - 8.0 * absf(sin(t * 6.0 + i * 2.3))))
			draw_polyline(jag2, Color(color, 0.7), 3.0)
		draw_circle(mid, 44.0, UiTheme.BASE)
		draw_arc(mid, 44.0, 0.0, TAU, 40, color, 4.0, true)
		if strong >= 1:
			draw_arc(mid, 54.0, 0.0, TAU, 40, Color(color, 0.5), 2.0, true)
		if strong >= 2:  # a crown of small diamonds round the second ring
			for i in 8:
				var a2 := TAU * i / 8.0 + t * 0.4
				var p := mid + Vector2.from_angle(a2) * 66.0
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(6, 0), p + Vector2(0, 8), p + Vector2(-6, 0)]), Color(color, 0.8))
		# The emblem: a four-point star (drawn, not written).
		var r1 := 24.0
		var r2 := 8.0
		var pts := PackedVector2Array()
		for i in 8:
			var a3 := -PI * 0.5 + TAU * i / 8.0
			pts.append(mid + Vector2.from_angle(a3) * (r1 if i % 2 == 0 else r2))
		draw_colored_polygon(pts, Color(color, 0.85 + 0.15 * pulse))
