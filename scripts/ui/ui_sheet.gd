class_name UiSheet
extends Control
## A modal sheet (UI_FLOW_TZ 5.5): a full-screen dimming veil that takes every tap, and a
## panel rising from the bottom (or, with `full`, the whole height). A tap on the veil is
## `veil_tapped` (the pause: continue; a confirmation: stay). Built from code, styled by
## UiTheme. Works while the game is paused. Subclasses fill `body` and `actions`.

signal veil_tapped

const VEIL := 0.6

var full := false                 # the whole height (the settings sheet), else at the bottom
var body: VBoxContainer           # the content
var actions: VBoxContainer        # the buttons, pinned at the bottom of the panel
var panel: PanelContainer
var _veil: ColorRect
var _pad: MarginContainer
var _safe_top := 0.0
var _safe_bottom := 0.0


func _init(whole := false) -> void:
	full = whole


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.theme()
	visible = false
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(UiTheme.BASE, VEIL)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.gui_input.connect(func(e: InputEvent) -> void:
		var up: bool = (e is InputEventMouseButton and not (e as InputEventMouseButton).pressed) \
			or (e is InputEventScreenTouch and not (e as InputEventScreenTouch).pressed)
		if up and visible:
			veil_tapped.emit())
	add_child(_veil)
	_pad = MarginContainer.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.BASE, 0.98), UiTheme.LINE, 2, UiTheme.RADIUS, 26))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # a tap on the panel is not a tap on the veil
	panel.size_flags_vertical = Control.SIZE_FILL if full else Control.SIZE_SHRINK_END
	_pad.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL if full else Control.SIZE_FILL
	col.add_child(body)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	_margins()


func set_safe_area(top: float, bottom: float) -> void:
	_safe_top = top
	_safe_bottom = bottom
	if _pad:
		_margins()


func _margins() -> void:
	_pad.add_theme_constant_override("margin_left", 14)
	_pad.add_theme_constant_override("margin_right", 14)
	_pad.add_theme_constant_override("margin_top", 14 + int(_safe_top))
	_pad.add_theme_constant_override("margin_bottom", 14 + int(_safe_bottom))


## Shows the sheet: it fades in (real time, no springs: UI_FLOW_TZ 5.3).
func open() -> void:
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false


# --- Building blocks --------------------------------------------------------------

func label(t: String, font: Font, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A button of the theme: "Primary" (gold, one per sheet), "" (secondary) or "Quiet".
func button(caption: String, on_press: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = caption
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiTheme.TAP + (12.0 if variation == "Primary" else 0.0))
	b.pressed.connect(on_press)
	return b
