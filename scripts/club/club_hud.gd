class_name ClubHud
extends CanvasLayer
## What the club puts on the screen (docs/club/CLUB_BRIEF.md 4): the gold chip, quick
## travel in the bottom left corner, the one button of the place the hero stands in, red
## counts over the places and the coach's speech bubble. Nothing else: the rest is the
## world. Settings stay on Hud's НАСТР button (top right). Styled by UiTheme.

signal chosen(action: String, arg: int)
signal travel(place_id: String)

const HUD_BUTTON_W := 132.0      # room kept free at the top right for НАСТР (as TournamentUI)
const TRAVEL := 92.0             # the quick-travel button (a circle)

var root: Control
var buttons: Array[Control] = []    # what the touch layer must leave alone (TouchInput.blocked_controls)
var _chip_label: Label
var _bottom: HBoxContainer
var _place_box: VBoxContainer
var _primary: Button
var _second_row: HBoxContainer
var _travel_btn: Button
var _travel_list: VBoxContainer
var _badges := {}                   # place id -> TournamentUI.Badge
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_t := 0.0
var _place_id := ""
var _place_tw: Tween
var _safe_top := 0.0
var _safe_bottom := 0.0


func _ready() -> void:
	layer = 9  # under the menus (TournamentUI 10) and the settings (20)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	add_child(root)
	_build_chip()
	_build_bottom()
	_build_bubble()
	_layout()
	visible = false


func set_safe_area(top: float, bottom: float) -> void:
	_safe_top = top
	_safe_bottom = bottom
	_layout()


func _layout() -> void:
	if _bottom == null:
		return
	_bottom.offset_left = UiTheme.GUTTER
	_bottom.offset_right = -UiTheme.GUTTER
	_bottom.offset_bottom = -26.0 - _safe_bottom
	var chip := _chip_label.get_parent().get_parent() as Control
	chip.offset_top = 14.0 + _safe_top + 8.0
	chip.offset_right = -HUD_BUTTON_W - 14.0


# --- Gold ---------------------------------------------------------------------------

func _build_chip() -> void:
	var chip := PanelContainer.new()
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.55), 2, 40, 14)
	sb.content_margin_left = 18
	sb.content_margin_right = 22
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(chip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(h)
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(28, 28)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_box)
	var coin := TournamentUI.Coin.new()
	coin.position = Vector2(14, 14)
	icon_box.add_child(coin)
	_chip_label = Label.new()
	_chip_label.add_theme_font_override("font", UiTheme.display())
	_chip_label.add_theme_font_size_override("font_size", 30)
	_chip_label.add_theme_color_override("font_color", UiTheme.GOLD)
	h.add_child(_chip_label)


func set_gold(v: int) -> void:
	_chip_label.text = str(v)


# --- The bottom: quick travel and the place's button ------------------------------------

func _build_bottom() -> void:
	_bottom = HBoxContainer.new()
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.alignment = BoxContainer.ALIGNMENT_BEGIN
	_bottom.add_theme_constant_override("separation", 14)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bottom)

	var travel_col := VBoxContainer.new()
	travel_col.alignment = BoxContainer.ALIGNMENT_END
	travel_col.add_theme_constant_override("separation", 12)
	travel_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(travel_col)
	_travel_list = VBoxContainer.new()
	_travel_list.add_theme_constant_override("separation", 10)
	_travel_list.visible = false
	travel_col.add_child(_travel_list)
	buttons.append(_travel_list)
	_travel_btn = TravelButton.new()
	_travel_btn.custom_minimum_size = Vector2(TRAVEL, TRAVEL)
	_travel_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_travel_btn.focus_mode = Control.FOCUS_NONE
	_travel_btn.pressed.connect(func() -> void: _toggle_travel(not _travel_list.visible))
	travel_col.add_child(_travel_btn)
	buttons.append(_travel_btn)

	_place_box = VBoxContainer.new()
	_place_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place_box.alignment = BoxContainer.ALIGNMENT_END
	_place_box.add_theme_constant_override("separation", 12)
	_place_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(_place_box)
	_second_row = HBoxContainer.new()
	_second_row.add_theme_constant_override("separation", 12)
	_place_box.add_child(_second_row)
	buttons.append(_second_row)
	_primary = Button.new()
	_primary.theme_type_variation = "Primary"
	_primary.custom_minimum_size = Vector2(0, TRAVEL)
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.pressed.connect(func() -> void:
		var a: String = _primary.get_meta("action", "")
		if a != "":
			_tap(_primary)
			chosen.emit(a, int(_primary.get_meta("arg", 0))))
	_place_box.add_child(_primary)
	buttons.append(_primary)
	_place_box.modulate.a = 0.0


## The place under the hero: its main action and up to two small ones above it.
## `extra`: [[label, action], ...].
func show_place(id: String, label: String, action: String, extra: Array = []) -> void:
	_primary.text = label
	_primary.set_meta("action", action)
	for c in _second_row.get_children():
		c.queue_free()
	for e in extra:
		var b := Button.new()
		b.text = e[0]
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", UiTheme.T_BODY - 2)
		var act: String = e[1]
		b.pressed.connect(func() -> void:
			_tap(b)
			chosen.emit(act, 0))
		_second_row.add_child(b)
	_second_row.visible = not extra.is_empty()
	if id == _place_id:
		return
	_place_id = id
	_slide(true)


func hide_place() -> void:
	if _place_id == "":
		return
	_place_id = ""
	_slide(false)


func current_place() -> String:
	return _place_id


## The button rises into place (0.2 s) or drops away; it can't be pressed while hidden.
func _slide(on: bool) -> void:
	if _place_tw:
		_place_tw.kill()
	_place_box.visible = true
	_primary.disabled = not on
	_place_tw = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_place_tw.tween_property(_place_box, "modulate:a", 1.0 if on else 0.0, 0.2)
	_place_tw.tween_property(_place_box, "position:y", 0.0 if on else 40.0, 0.2).from(40.0 if on else 0.0)
	if not on:
		_place_tw.chain().tween_callback(func() -> void: _place_box.visible = false)


func _tap(b: Control) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(0.96, 0.96), 0.06)
	tw.tween_property(b, "scale", Vector2.ONE, 0.1)


## The places quick travel offers (only the open ones), plus "how to play".
func set_places(places: Array) -> void:
	for c in _travel_list.get_children():
		c.queue_free()
	for p in places:
		var b := Button.new()
		b.text = p["name"]
		b.custom_minimum_size = Vector2(300, 84)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var id: String = p["id"]
		b.pressed.connect(func() -> void:
			_toggle_travel(false)
			travel.emit(id))
		_travel_list.add_child(b)
	var how := Button.new()
	how.text = "?  Как играть"
	how.custom_minimum_size = Vector2(300, 76)
	how.alignment = HORIZONTAL_ALIGNMENT_LEFT
	how.focus_mode = Control.FOCUS_NONE
	how.add_theme_color_override("font_color", UiTheme.GOLD)
	how.pressed.connect(func() -> void:
		_toggle_travel(false)
		chosen.emit("howto", 0))
	_travel_list.add_child(how)


func _toggle_travel(on: bool) -> void:
	_travel_list.visible = on
	(_travel_btn as TravelButton).open = on
	_travel_btn.queue_redraw()


func travel_open() -> bool:
	return _travel_list.visible


# --- Badges and the coach's words ---------------------------------------------------------

## Red counts over places. `screen`: place id -> screen position (absent = not on screen).
func place_badges(counts: Dictionary, screen: Dictionary) -> void:
	for id in counts:
		var b: TournamentUI.Badge = _badges.get(id)
		if b == null:
			b = TournamentUI.Badge.new()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(b)
			_badges[id] = b
		b.count = counts[id]
		b.visible = counts[id] > 0 and screen.has(id)
		if b.visible:
			b.position = screen[id]
			b.queue_redraw()
	for id in _badges:
		if not counts.has(id):
			(_badges[id] as Control).visible = false


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.96), Color(UiTheme.GOLD, 0.5), 2, 26, 18)
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.visible = false
	_bubble.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_bubble.visible = false)
	root.add_child(_bubble)
	buttons.append(_bubble)
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_override("font", UiTheme.text_bold())
	_bubble_label.add_theme_font_size_override("font_size", UiTheme.T_BODY)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(380, 0)
	_bubble.add_child(_bubble_label)


## The coach says a line (up to ~60 characters) over his head for a few seconds.
func say(text: String, seconds := 3.5) -> void:
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.reset_size()
	_bubble_t = seconds


func is_saying() -> bool:
	return _bubble.visible


## Where the coach's head is on screen (the bubble hangs above it, kept on screen).
func bubble_at(head: Vector2, on_screen: bool) -> void:
	if not _bubble.visible:
		return
	var vp := root.get_viewport_rect().size
	var s := _bubble.size
	var x := clampf(head.x - s.x * 0.5, UiTheme.GUTTER, vp.x - UiTheme.GUTTER - s.x)
	var y := clampf(head.y - s.y - 24.0, 120.0 + _safe_top, vp.y * 0.6)
	_bubble.position = Vector2(x, y)
	_bubble.modulate.a = 1.0 if on_screen else 0.0


func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false


## The quick-travel button: a dark disc with a gold map pin (a cross when open).
class TravelButton extends Button:
	var open := false

	func _ready() -> void:
		var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.55), 2, 46, 0)
		for k in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(k, sb)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var g := UiTheme.GOLD
		if open:
			draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), g, 5.0, true)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), g, 5.0, true)
			return
		var head := c + Vector2(0, -6)
		draw_circle(head, 14.0, g)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-12, 7), head + Vector2(12, 7), head + Vector2(0, 26)]), g)
		draw_circle(head, 6.0, UiTheme.SURFACE)
