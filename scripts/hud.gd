class_name Hud
extends CanvasLayer
## On-screen UI: score, rally counter, hit feedback popups, timing ring, line-call
## replay, the first-launch tutorial and the settings panel. No permanent hints.

const GOLD := Color(1.0, 0.85, 0.25)

var touch: TouchInput
var ring: TimingRing
var _hawkeye: HawkEye

var _root: Control
var _score: Label
var _rally: Label
var _message: Label
var _tutorial: Tutorial
var _debug_text: Label
var _debug_panel: PanelContainer
var _debug_btn: Button
var _message_tween: Tween


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	ring = TimingRing.new()
	_root.add_child(ring)
	_hawkeye = HawkEye.new()
	_root.add_child(_hawkeye)
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

	_tutorial = Tutorial.new()
	_tutorial.visible = false
	add_child(_tutorial)


func set_score(text: String) -> void:
	_score.text = text


func set_rally(text: String) -> void:
	_rally.text = text


func show_tutorial_once() -> void:
	if not Tutorial.is_done():
		_tutorial.open.call_deferred()


func open_tutorial() -> void:
	_debug_panel.visible = false
	_tutorial.open()


func set_debug_text(t: String) -> void:
	_debug_text.visible = Tuning.show_debug_text
	if _debug_text.visible:
		_debug_text.text = t


## Hit / miss verdict, shown at the timing ring above the player.
func popup(text: String, color: Color, sub := "") -> void:
	ring.feedback(text, color, sub, 2 if text == "PERFECT" else (1 if text == "GOOD" else 0))


func show_message(text: String, color: Color) -> void:
	if _message_tween:
		_message_tween.kill()
	_message.text = text
	_message.modulate = color
	_message_tween = create_tween()
	_message_tween.set_ignore_time_scale(true)
	_message_tween.tween_interval(1.1)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)


func hawkeye(margin: float, axis: int) -> void:
	_hawkeye.show_call(margin, axis)


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

	var tut := Button.new()
	tut.text = "Обучение"
	tut.custom_minimum_size = Vector2(400, 56)
	tut.add_theme_font_size_override("font_size", 22)
	tut.focus_mode = Control.FOCUS_NONE
	tut.pressed.connect(open_tutorial)
	v.add_child(tut)
	_check(v, "Замедление (slow-mo)", "slowmo_enabled")
	_slider(v, "Сила замедления", "slowmo_scale", 0.1, 1.0, 0.01)
	_slider(v, "Когда включать (с до удара)", "slowmo_lead", 0.1, 0.8, 0.01)
	_slider(v, "Окно PERFECT (с)", "perfect_window", 0.01, 0.1, 0.005)
	_slider(v, "Окно GOOD (с)", "good_window", 0.03, 0.2, 0.005)
	_slider(v, "Изгиб дуги для TOPSPIN", "curve_min", 0.05, 0.4, 0.01)
	_slider(v, "Возврат крючка для SLICE", "hook_min", 0.08, 0.6, 0.01)
	_slider(v, "Скорость игрока (м/с)", "player_speed", 3.0, 9.0, 0.1)
	_slider(v, "Автопомощь в беге", "assist", 0.0, 1.0, 0.05)
	_slider(v, "Сила соперника", "ai_skill", 0.0, 1.0, 0.05)
	_check(v, "Hit-stop на PERFECT", "hitstop")
	_check(v, "Вибрация при ударе", "vibration")
	_check(v, "Птицы на фоне", "ambience")
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
