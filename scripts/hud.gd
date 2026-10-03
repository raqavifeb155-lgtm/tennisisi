class_name Hud
extends CanvasLayer
## On-screen UI: score, rally counter, hit feedback popups, shot-type selector,
## controls hint, and the debug/tuning panel.

signal shot_type_changed(t: int)

const SHOT_NAMES := ["TOPSPIN", "FLAT", "SLICE"]
const GOLD := Color(1.0, 0.85, 0.25)

var touch: TouchInput
var ring: TimingRing

var _root: Control
var _score: Label
var _rally: Label
var _popup: Label
var _popup_sub: Label
var _message: Label
var _hint: Label
var _serve_hint: Label
var _debug_text: Label
var _debug_panel: PanelContainer
var _debug_btn: Button
var _shot_buttons: Array[Button] = []
var _popup_tween: Tween
var _message_tween: Tween


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	ring = TimingRing.new()
	_root.add_child(ring)
	touch = TouchInput.new()
	_root.add_child(touch)

	_score = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_top(_score, 18.0, 60.0)
	_rally = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_top(_rally, 74.0, 34.0)
	_rally.modulate = Color(1, 1, 1, 0.85)

	_message = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_band(_message, 0.15, 90.0)
	_message.modulate.a = 0.0
	_popup = _label(56, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_band(_popup, 0.205, 70.0)
	_popup.modulate.a = 0.0
	_popup_sub = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_band(_popup_sub, 0.205, 40.0)
	_popup_sub.offset_top += 52.0
	_popup_sub.offset_bottom += 52.0
	_popup_sub.modulate.a = 0.0

	_hint = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.text = "ТАП — бежать туда   ·   СВАЙП — удар по линии от игрока\nсвайпни, когда кольцо сожмётся до круга · быстрый свайп = сильнее"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 16.0
	_hint.offset_right = -16.0
	_hint.offset_top = -120.0
	_hint.offset_bottom = -30.0
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate.a = 1.0

	_serve_hint = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_band(_serve_hint, 0.70, 90.0)
	_serve_hint.offset_left = 24.0
	_serve_hint.offset_right = -24.0
	_serve_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_serve_hint.modulate = Color(1.0, 0.95, 0.7)
	_serve_hint.visible = false

	# Shot type selector: a row under the score, above the far court.
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -246.0
	box.offset_right = 246.0
	box.offset_top = 116.0
	box.offset_bottom = 166.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_root.add_child(box)
	for i in SHOT_NAMES.size():
		var b := Button.new()
		b.text = SHOT_NAMES[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 50)
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_shot_pressed.bind(i))
		box.add_child(b)
		_shot_buttons.append(b)
		touch.blocked_controls.append(b)
	_shot_buttons[0].button_pressed = true

	# Debug toggle + panel
	_debug_btn = Button.new()
	_debug_btn.text = "НАСТР"
	_debug_btn.add_theme_font_size_override("font_size", 20)
	_debug_btn.focus_mode = Control.FOCUS_NONE
	_debug_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug_btn.offset_left = -120.0
	_debug_btn.offset_right = -14.0
	_debug_btn.offset_top = 14.0
	_debug_btn.offset_bottom = 84.0
	_debug_btn.pressed.connect(_toggle_debug)
	_root.add_child(_debug_btn)
	touch.blocked_controls.append(_debug_btn)

	_debug_text = _label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_debug_text.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_debug_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_debug_text.offset_left = 12.0
	_debug_text.offset_top = 180.0
	_debug_text.offset_right = 520.0
	_debug_text.offset_bottom = 580.0
	_debug_text.visible = Tuning.show_debug_text

	_build_debug_panel()


func set_score(text: String) -> void:
	_score.text = text


func set_rally(text: String) -> void:
	_rally.text = text


func set_serve_hint(text: String) -> void:
	_serve_hint.text = text
	_serve_hint.visible = text != ""


func set_debug_text(t: String) -> void:
	_debug_text.visible = Tuning.show_debug_text
	if _debug_text.visible:
		_debug_text.text = t


func hide_hint() -> void:
	if _hint.modulate.a > 0.0:
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(_hint, "modulate:a", 0.0, 0.8)


func popup(text: String, color: Color, sub := "") -> void:
	if _popup_tween:
		_popup_tween.kill()
	_popup.text = text
	_popup.modulate = color
	_popup_sub.text = sub
	_popup_sub.modulate = Color(1, 1, 1, 1)
	_popup.pivot_offset = _popup.size * 0.5
	_popup.scale = Vector2(1.35, 1.35)
	_popup_tween = create_tween()
	_popup_tween.set_ignore_time_scale(true)
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_popup, "modulate:a", 0.0, 0.35).set_delay(0.55)
	_popup_tween.tween_property(_popup_sub, "modulate:a", 0.0, 0.35).set_delay(0.55)


func show_message(text: String, color: Color) -> void:
	if _message_tween:
		_message_tween.kill()
	_message.text = text
	_message.modulate = color
	_message_tween = create_tween()
	_message_tween.set_ignore_time_scale(true)
	_message_tween.tween_interval(1.1)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)


func _on_shot_pressed(i: int) -> void:
	for j in _shot_buttons.size():
		_shot_buttons[j].set_pressed_no_signal(j == i)
	shot_type_changed.emit(i)


func _toggle_debug() -> void:
	_debug_panel.visible = not _debug_panel.visible


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _anchor_top(c: Control, top: float, height: float) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_WIDE)
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = top
	c.offset_bottom = top + height


func _anchor_band(c: Control, anchor_y: float, height: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = anchor_y
	c.anchor_bottom = anchor_y
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = -height * 0.5
	c.offset_bottom = height * 0.5


# --- Debug / tuning panel -------------------------------------------------

func _build_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_debug_panel.offset_left = 0.0
	_debug_panel.offset_right = 470.0
	_debug_panel.offset_top = 180.0
	_debug_panel.offset_bottom = -20.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.88)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	_debug_panel.add_theme_stylebox_override("panel", sb)
	_debug_panel.visible = false
	_root.add_child(_debug_panel)
	touch.blocked_controls.append(_debug_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_debug_panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)

	var title := Label.new()
	title.text = "Настройки ощущений"
	title.add_theme_font_size_override("font_size", 26)
	v.add_child(title)

	_check(v, "Замедление (slow-mo)", "slowmo_enabled")
	_slider(v, "Сила замедления", "slowmo_scale", 0.1, 1.0, 0.01)
	_slider(v, "Когда включать (с до удара)", "slowmo_lead", 0.1, 0.8, 0.01)
	_slider(v, "Окно PERFECT (с)", "perfect_window", 0.01, 0.1, 0.005)
	_slider(v, "Окно GOOD (с)", "good_window", 0.03, 0.2, 0.005)
	_slider(v, "Длина свайпа до задней линии", "swipe_deep_len", 0.12, 0.5, 0.01)
	_slider(v, "Угол свайпа до боковой (°)", "swipe_side_angle", 15.0, 60.0, 1.0)
	_slider(v, "Скорость игрока (м/с)", "player_speed", 3.0, 9.0, 0.1)
	_slider(v, "Автопомощь в беге", "assist", 0.0, 1.0, 0.05)
	_slider(v, "Сила соперника", "ai_skill", 0.0, 1.0, 0.05)
	_check(v, "Hit-stop на PERFECT", "hitstop")
	_check(v, "Прицел при свайпе", "show_aim")
	_check(v, "Маркер приземления", "show_landing")
	_check(v, "Траектория мяча", "show_path")
	_check(v, "Debug-текст", "show_debug_text")


func _slider(parent: Control, caption: String, prop: String, mn: float, mx: float, step: float) -> void:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 19)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = Tuning.get(prop)
	s.custom_minimum_size = Vector2(400, 40)
	s.focus_mode = Control.FOCUS_NONE
	parent.add_child(s)
	var refresh := func(val: float) -> void:
		l.text = "%s: %s" % [caption, str(snappedf(val, step))]
	refresh.call(s.value)
	s.value_changed.connect(func(val: float) -> void:
		Tuning.set(prop, val)
		refresh.call(val)
		Tuning.notify_changed())


func _check(parent: Control, caption: String, prop: String) -> void:
	var c := CheckButton.new()
	c.text = caption
	c.add_theme_font_size_override("font_size", 19)
	c.button_pressed = Tuning.get(prop)
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool) -> void:
		Tuning.set(prop, on)
		Tuning.notify_changed())
	parent.add_child(c)
