class_name Hud
extends CanvasLayer
## On-screen UI: score, rally counter, hit feedback popups, timing ring, line-call
## replay, the first-launch tutorial and the settings panel. No permanent hints.

signal menu_requested

const GOLD := Color(1.0, 0.85, 0.25)

var touch: TouchInput
var ring: TimingRing
var _hawkeye: HawkEye

var _root: Control
var _top: Control          # the settings button and panel: above the menu screens too
var _gfx_label: Label
var _fps_t := 0.0
var _fps_label: Label
const MESSAGE_TOP := 214.0     # under the rally count (176..206)
var _safe_top := 0.0
var _score: Label
var _bug: ScoreBug
var _tired_edge: TextureRect
var _serve_hint: Label
var _rally: Label
var _message: Label
var _tutorial: Tutorial
var _debug_text: Label
var _debug_panel: PanelContainer
var _debug_btn: Button
var _message_tween: Tween
var _level_ups: Array[Label] = []


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var top_layer := CanvasLayer.new()
	top_layer.layer = 20  # over TournamentUI (10): settings open from the menu as well
	add_child(top_layer)
	_top = Control.new()
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.add_child(_top)

	ring = TimingRing.new()
	_root.add_child(ring)
	_hawkeye = HawkEye.new()
	_root.add_child(_hawkeye)
	touch = TouchInput.new()
	_root.add_child(touch)

	_score = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_top(_score, 18.0, 60.0)
	# Exhausted: a soft red glow creeps in from the edges of the screen.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.05, 0.05, 0.0))
	grad.set_color(1, Color(0.85, 0.05, 0.05, 0.9))
	grad.add_point(0.55, Color(0.85, 0.05, 0.05, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 128
	tex.height = 256
	_tired_edge = TextureRect.new()
	_tired_edge.texture = tex
	_tired_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tired_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tired_edge.stretch_mode = TextureRect.STRETCH_SCALE
	_tired_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tired_edge.modulate.a = 0.0
	_tired_edge.visible = false
	_root.add_child(_tired_edge)
	_bug = ScoreBug.new()
	_bug.position = Vector2(14.0, 14.0)
	_bug.visible = false
	_root.add_child(_bug)
	_rally = _label(22, HORIZONTAL_ALIGNMENT_LEFT)
	_rally.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_rally.offset_left = 18.0
	_rally.offset_top = 176.0
	_rally.offset_right = 400.0
	_rally.offset_bottom = 206.0
	_rally.modulate = Color(1, 1, 1, 0.75)

	_message = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_message.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_place_message()
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
	_debug_btn.process_mode = Node.PROCESS_MODE_ALWAYS  # works while the match is paused
	_top.add_child(_debug_btn)
	touch.blocked_controls.append(_debug_btn)
	# The frame-rate counter (settings: "Счётчик FPS"), under НАСТР.
	_fps_label = _label(22, HORIZONTAL_ALIGNMENT_RIGHT)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -200.0
	_fps_label.offset_right = -16.0
	_fps_label.offset_top = 88.0
	_fps_label.offset_bottom = 118.0
	_fps_label.visible = false

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

	_serve_hint = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_band(_serve_hint, 0.775, 76.0)
	_serve_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_serve_hint.modulate = Color(1, 1, 1, 0.8)
	_serve_hint.visible = false

	_tutorial = Tutorial.new()
	_tutorial.visible = false
	add_child(_tutorial)


## The frame rate next to the graphics preset, so a phone can be checked by eye:
## 60 is the ceiling in Safari and Telegram on iPhone.
func _process(delta: float) -> void:
	_fps_label.visible = Tuning.show_fps
	if not Tuning.show_fps and (_gfx_label == null or not _debug_panel.visible):
		return
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.5
		var fps := Engine.get_frames_per_second()
		if _gfx_label != null:
			_gfx_label.text = "Графика · %d FPS" % fps
		_fps_label.text = "%d FPS" % fps
		_fps_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if fps >= 55 else (Color(1.0, 0.85, 0.3) if fps >= 40 else Color(1.0, 0.45, 0.4)))


## Keeps the HUD clear of Telegram's buttons and the notch (top) and the home bar
## (bottom). Everything anchored to an edge moves with it.
## Only the edge-anchored parts move (score, buttons, labels, the settings sheet): the
## timing ring, the joystick, the swipe trail and the line-call replay are drawn at
## screen positions of things on the court and must stay exactly where they are.
func set_safe_area(top: float, bottom: float) -> void:
	_anchor_top(_score, 18.0 + top, 60.0)
	_bug.position.y = 14.0 + top
	_rally.offset_top = 176.0 + top
	_rally.offset_bottom = 206.0 + top
	_debug_btn.offset_top = 14.0 + top
	_debug_btn.offset_bottom = 84.0 + top
	_fps_label.offset_top = 88.0 + top
	_fps_label.offset_bottom = 118.0 + top
	_debug_text.offset_top = 180.0 + top
	_debug_text.offset_bottom = 580.0 + top
	_debug_panel.offset_top = 96.0 + top
	_debug_panel.offset_bottom = -14.0 - bottom
	_hawkeye.top_inset = top
	ring.top_inset = top
	_safe_top = top
	_place_message()
	_anchor_band(_serve_hint, 0.775, 76.0)
	_serve_hint.offset_top -= bottom
	_serve_hint.offset_bottom -= bottom


## Plain text in place of the score bug (the trophy mini-game, nothing at all).
func set_score(text: String) -> void:
	_score.text = text
	_bug.visible = false
	ring.show_stamina = false


## The match score, broadcast style. names: [player, opponent].
func show_board(s: MatchScore, names: Array) -> void:
	_score.text = ""
	_bug.show_score(s, names)
	ring.show_stamina = true


## Stamina (0..1): the arc inside the timing ring, and the screen's edges reddening
## when the player is close to empty.
func set_stamina(v: float) -> void:
	ring.set_stamina(v)
	var a := clampf((0.25 - v) / 0.25, 0.0, 1.0) * 0.55
	if absf(_tired_edge.modulate.a - a) > 0.01:
		_tired_edge.modulate.a = a
	_tired_edge.visible = a > 0.0


## Before the player's toss, for the first few serves: what the fingers do.
func show_serve_hint(on: bool, tap_controls: bool) -> void:
	if on:
		_serve_hint.text = ("тап ниже игрока — шаг  ·  " if tap_controls else "") + "тап по корту — подброс\nкороткий свайп вниз до подброса — подача снизу"
	if _serve_hint.visible != on:
		_serve_hint.visible = on


func set_rally(text: String) -> void:
	_rally.text = text


func show_tutorial_once() -> void:
	if not Tutorial.is_done():
		_tutorial.open.call_deferred()


func open_tutorial() -> void:
	_debug_panel.visible = false
	_set_paused(false)  # the tutorial pauses the game itself until it is closed
	_tutorial.open()


func set_debug_text(t: String) -> void:
	_debug_text.visible = Tuning.show_debug_text
	if _debug_text.visible:
		_debug_text.text = t


## Hit / miss verdict, shown at the timing ring above the player.
func popup(text: String, color: Color, sub := "") -> void:
	ring.feedback(text, color, sub, 2 if text == "PERFECT" else (1 if text == "GOOD" else 0))


## Skill level-up: a small gold line under the hit verdict ("+1 ФОРХЕНД · ур. 7").
## Several at once stack downward. `milestone` (every 5 levels) adds the perk note.
func level_up(text: String, milestone := false) -> void:
	var l := Label.new()
	l.text = text + ("  ·  перк после матча" if milestone else "")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	var w := get_viewport().get_visible_rect().size.x
	l.size = Vector2(w, 36)
	# "ФОРХЕНД 7 · 104 → 109 км/ч" with the perk note is long: shrunk to fit the width
	# (a glyph is ~0.56 of the font size wide).
	l.add_theme_font_size_override("font_size", clampi(int(w * 0.92 / (l.text.length() * 0.56)), 18, 34))
	l.size.y = 46.0
	# Under the verdict and its skill bar, clear of the score and VAR in full screen.
	var y := _safe_top + 300.0 + 46.0 * _level_ups.size()
	_level_ups.append(l)
	l.position = Vector2(0.0, y + 12.0)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(l, "position:y", y, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		_level_ups.erase(l)
		l.queue_free())


func show_message(text: String, color: Color) -> void:
	if _message_tween:
		_message_tween.kill()
	_message.text = text
	_message.modulate = color
	_message_tween = create_tween()
	_message_tween.set_ignore_time_scale(true)
	_message_tween.tween_interval(1.1)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)


## `mark` = the ball mark (half-length, half-width, |cos| of its angle to the line's
## normal), see Main._line_call; zero = a round mark of the ball's size.
func hawkeye(margin: float, axis: int, mark := Vector3.ZERO) -> void:
	_hawkeye.show_call(margin, axis, mark)


func _toggle_debug() -> void:
	_debug_panel.visible = not _debug_panel.visible
	if _debug_panel.visible:
		for sync in _syncs:  # the menu may have changed a setting since the last look
			sync.call()
	_set_paused(_debug_panel.visible and in_match)


## Opening the sheet during a match pauses it: the ball, the players and the clock stop
## until "Продолжить" (or "Выйти в меню").
func _set_paused(on: bool) -> void:
	_paused_by_sheet = on
	get_tree().paused = on
	_sheet_title.text = "Пауза" if on else "Настройки"
	_sheet_done.text = "Продолжить" if on else "Готово"


## Main tells the HUD whether a match is on: the button reads ПАУЗА and opening the
## sheet pauses the game; in the menus it is just the settings.
func set_in_match(on: bool) -> void:
	if on == in_match:
		return
	in_match = on
	_debug_btn.text = "ПАУЗА" if on else "НАСТР"
	if not on and _paused_by_sheet:
		_set_paused(false)


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


## The point's verdict ("WINNER!", "CPU OUT" + "GAME ВЫ": up to two lines) hangs under the
## score and the rally count, below whatever Telegram's buttons take at the top. At a
## fixed share of the screen it landed on the score once full screen pushed that down.
func _place_message() -> void:
	_anchor_top(_message, MESSAGE_TOP + _safe_top, 170.0)


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


# --- Settings sheet ---------------------------------------------------------

## The settings: a sheet with sections. Every option says in plain words what it does,
## sliders show human values ("35 мс", "средне"), and the developer knobs sit folded
## under "Тонкая настройка" so a player never has to wonder what "hook_min" is.

const SHEET_BG := Color(0.06, 0.08, 0.11, 0.97)
const ROW_LINE := Color(1, 1, 1, 0.07)
const INK := Color(0.96, 0.97, 0.98)
const SUB := Color(1, 1, 1, 0.62)
const ACCENT := Color(1.0, 0.85, 0.25)
const GFX_NOTES := [
	"Сама подстраивается под телефон: если кадры проседают, качество снижается.",
	"Для старых телефонов: меньше пикселей, без сглаживания, простые тени.",
	"Баланс: картинка чуть мягче, тени жёсткие, без лишних деталей сцены.",
	"Чёткая картинка, мягкие тени, все детали сцены.",
	"Для флагманов: родное разрешение экрана, сглаживание 4x, мягкие и дальние тени. Телефон может греться.",
	"Своя настройка: части графики выставлены вручную ниже.",
]

var _syncs: Array[Callable] = []    # re-read every control from Tuning when the sheet opens
var in_match := false               # a match is on (Main): the sheet doubles as the pause menu
var _paused_by_sheet := false
var _sheet_title: Label
var _sheet_done: Button
var _gfx_buttons: Array[Button] = []
var _gfx_note: Label


func _build_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_panel.offset_left = 14.0
	_debug_panel.offset_right = -14.0
	_debug_panel.offset_top = 96.0
	_debug_panel.offset_bottom = -14.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = SHEET_BG
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_debug_panel.add_theme_stylebox_override("panel", sb)
	_debug_panel.visible = false
	_debug_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # usable while the match is paused
	_top.add_child(_debug_panel)
	touch.blocked_controls.append(_debug_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_debug_panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	scroll.add_child(v)

	var head := HBoxContainer.new()
	_sheet_title = _text("Настройки", 40, INK)
	_sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_sheet_title)
	_sheet_done = _button("Готово", _toggle_debug, true)
	head.add_child(_sheet_done)
	v.add_child(head)
	v.add_child(_space(14))
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 10)
	var tut := _button("Как играть", open_tutorial)
	tut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.add_child(tut)
	var menu := _button("Выйти в меню", func() -> void:
		_debug_panel.visible = false
		_set_paused(false)
		menu_requested.emit())
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.add_child(menu)
	v.add_child(quick)

	_section(v, "Картинка и звук")
	_graphics_choice(v)
	_graphics_manual(v)
	if SaveData.crashes > 0:
		var c := _text("Сбоев страницы: %d · последний: %s" % [SaveData.crashes, SaveData.last_crash], 19, SUB)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(c)
	_switch(v, "Счётчик FPS", "Частота кадров в углу экрана: 60 — идеально, ниже 40 — снизь графику", "show_fps")
	_switch(v, "Звуки окружения", "Море, город, колокол и игра на соседнем корте", "ambience")
	_switch(v, "Музыка в меню", "Только в меню, в матче — тишина корта", "music")
	_switch(v, "Вибрация при ударе", "Отдача в руку на каждом ударе (Android и Telegram)", "vibration")

	_section(v, "Игра")
	_switch(v, "Бег тапами", "Вкл: тапни по корту — игрок бежит туда. Выкл: джойстик под большим пальцем", "tap_controls")
	_switch(v, "Замедление перед ударом", "Время замедляется, когда мяч подлетает: проще поймать кольцо", "slowmo_enabled")
	_switch(v, "Стоп-кадр на PERFECT", "Короткая пауза в момент идеального удара — чувствуется сила", "hitstop")
	_switch(v, "Одноручный бэкхенд", "Удар слева одной рукой, как у Вавринки. Только вид, сила та же", "one_handed_bh")
	_slider(v, "Помощь в беге", "Игрок сам подбегает к мячу. 0 — бегаешь полностью сам", "assist", 0.0, 1.0, 0.05)
	_slider(v, "Сила соперника", "Только для тренировки: в турнире у каждого своя сила", "ai_skill", 0.0, 1.0, 0.05)

	_section(v, "Подсказки на корте")
	_switch(v, "Прицел", "Показывает, куда полетит мяч, пока ведёшь пальцем", "show_aim")
	_switch(v, "Точка приземления", "Где мяч коснётся корта", "show_landing")
	_switch(v, "Траектория мяча", "Линия полёта целиком — для тренировки", "show_path")

	var fine := VBoxContainer.new()
	fine.add_theme_constant_override("separation", 0)
	fine.visible = false
	v.add_child(_space(18))
	var fold := _button("Тонкая настройка  ▸", func() -> void: pass)
	fold.pressed.connect(func() -> void:
		fine.visible = not fine.visible
		fold.text = "Тонкая настройка  ▾" if fine.visible else "Тонкая настройка  ▸")
	v.add_child(fold)
	v.add_child(fine)
	_slider(fine, "Окно PERFECT", "Сколько длится идеальный момент удара. Больше — проще", "perfect_window", 0.01, 0.1, 0.005)
	_slider(fine, "Окно GOOD", "Хороший, но не идеальный удар. Больше — меньше промахов", "good_window", 0.03, 0.2, 0.005)
	_slider(fine, "Сила замедления", "Во сколько раз замедляется время перед ударом", "slowmo_scale", 0.1, 1.0, 0.01)
	_slider(fine, "Когда замедлять", "За сколько до удара начинается замедление", "slowmo_lead", 0.1, 0.8, 0.01)
	_slider(fine, "Выкрут для крутки", "Насколько длинный выкрут в конце свайпа вверх нужен для TOPSPIN", "curl_min", 0.05, 0.4, 0.01)
	_slider(fine, "Поворот выкрута, °", "Насколько резко повернуть палец, чтобы это был выкрут", "curl_turn", 25.0, 80.0, 1.0)
	_slider(fine, "Медленная дуга = свеча", "Насколько медленно вести дугу вверх, чтобы вышла свеча (LOB)", "lob_speed", 0.6, 2.5, 0.05)
	_slider(fine, "Скорость игрока", "Максимальная скорость бега", "player_speed", 3.0, 9.0, 0.1)
	_switch(fine, "Отладочный текст", "FPS, скорость мяча, вращение — для разработки", "show_debug_text")
	v.add_child(_space(10))


## Human-readable value of a slider.
func _value_text(prop: String, val: float) -> String:
	match prop:
		"perfect_window", "good_window":
			return "%d мс" % roundi(val * 1000.0)
		"slowmo_scale":
			return "×%.2f" % val
		"gfx_res", "gfx_reach":
			return "%d%%" % roundi(val * 100.0)
		"slowmo_lead":
			return "%.2f с" % val
		"player_speed":
			return "%.1f м/с" % val
		"assist", "ai_skill":
			var word := "выкл" if val < 0.05 else ("слабо" if val < 0.35 else ("средне" if val < 0.7 else "сильно"))
			if prop == "ai_skill":
				word = "легко" if val < 0.35 else ("средне" if val < 0.7 else "сложно")
			return "%s · %d%%" % [word, roundi(val * 100.0)]
	return str(snappedf(val, 0.01))


func _section(parent: Control, caption: String) -> void:
	parent.add_child(_space(26))
	parent.add_child(_text(caption, 27, ACCENT))
	parent.add_child(_space(6))


## Graphics: five buttons in a row (one tap, the current one lit) and a line saying
## what the chosen preset does, with the live frame rate in the title.
func _graphics_choice(parent: Control) -> void:
	_gfx_label = _text("Графика", 26, INK)
	parent.add_child(_gfx_label)
	parent.add_child(_space(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_gfx_buttons.clear()
	for i in GraphicsQuality.NAMES.size():
		var caption: String = GraphicsQuality.NAMES[i]
		var b := _button("Макс" if i == GraphicsQuality.MAX else caption, func() -> void:
			Tuning.graphics = i
			Tuning.notify_changed()  # the preset fills the manual parts in...
			for sync in _syncs:      # ...and the controls below show them
				sync.call())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 21)
		b.custom_minimum_size.y = 64
		row.add_child(b)
		_gfx_buttons.append(b)
	parent.add_child(row)
	_gfx_note = _text("", 21, SUB)
	_gfx_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_space(6))
	parent.add_child(_gfx_note)
	parent.add_child(_line())
	_syncs.append(_sync_graphics)
	_sync_graphics()


func _sync_graphics() -> void:
	for i in _gfx_buttons.size():
		_style_button(_gfx_buttons[i], i == Tuning.graphics)  # "Своя": none lit
	_gfx_note.text = GFX_NOTES[clampi(Tuning.graphics, 0, GFX_NOTES.size() - 1)]


## The parts of the graphics by hand, folded under the presets. Touching any of them
## makes the preset "Своя".
func _graphics_manual(parent: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.visible = false
	var fold := _button("Настроить вручную  ▸", func() -> void: pass)
	fold.pressed.connect(func() -> void:
		box.visible = not box.visible
		fold.text = "Настроить вручную  ▾" if box.visible else "Настроить вручную  ▸")
	parent.add_child(_space(10))
	parent.add_child(fold)
	parent.add_child(box)
	_slider(box, "Чёткость", "Разрешение 3D-картинки. Интерфейс всегда чёткий. Самое заметное для FPS", "gfx_res", 0.4, 1.0, 0.05)
	_segments(box, "Тени", "Мягкие — красивее, «Лучшие» — для флагманов, «Выкл» — быстрее всего", "gfx_shadows", ["Выкл", "Простые", "Мягкие", "Лучшие"])
	_slider(box, "Дальность теней", "Как далеко от камеры видны тени: трибуны, деревья, дома", "gfx_reach", 0.5, 1.5, 0.05)
	_segments(box, "Сглаживание краёв", "Убирает «лесенку» на линиях корта и сетке", "gfx_aa", ["Выкл", "2x", "4x"])
	_switch(box, "Детали сцены", "Тени облаков и мелкие предметы вокруг корта", "gfx_details")
	parent.add_child(_space(6))


## A row of choices for one setting, the current one lit.
func _segments(parent: Control, caption: String, about: String, prop: String, labels: Array) -> void:
	parent.add_child(_space(10))
	parent.add_child(_text(caption, 26, INK))
	var sub := _text(about, 21, SUB)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(sub)
	parent.add_child(_space(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var buttons: Array[Button] = []
	var paint := func() -> void:
		for i in buttons.size():
			_style_button(buttons[i], i == int(Tuning.get(prop)))
	for i in labels.size():
		var b := _button(labels[i], func() -> void:
			Tuning.set(prop, i)
			_changed(prop)
			paint.call())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 21)
		row.add_child(b)
		buttons.append(b)
	parent.add_child(row)
	parent.add_child(_space(10))
	parent.add_child(_line())
	paint.call()
	_syncs.append(paint)


## After a setting changes: a graphics part makes the preset "Своя"; then everyone hears.
func _changed(prop: String) -> void:
	if prop.begins_with("gfx_"):
		Tuning.graphics = GraphicsQuality.CUSTOM
	Tuning.notify_changed()
	if prop.begins_with("gfx_"):
		_sync_graphics()


## A row: title and a one-line explanation on the left, a big ВКЛ / ВЫКЛ pill on the
## right (the stock switch is too small for a thumb at this scale).
func _switch(parent: Control, caption: String, about: String, prop: String) -> void:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	pad.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.add_child(_text(caption, 26, INK))
	var sub := _text(about, 21, SUB)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(sub)
	row.add_child(texts)
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 56)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 21)
	var paint := func(on: bool) -> void:
		b.text = "ВКЛ" if on else "ВЫКЛ"
		_style_button(b, on)
	b.set_pressed_no_signal(Tuning.get(prop))
	paint.call(b.button_pressed)
	b.toggled.connect(func(on: bool) -> void:
		paint.call(on)
		if Tuning.get(prop) != on:
			Tuning.set(prop, on)
			_changed(prop))
	row.add_child(b)
	parent.add_child(pad)
	parent.add_child(_line())
	_syncs.append(func() -> void:
		b.set_pressed_no_signal(Tuning.get(prop))
		paint.call(b.button_pressed))


func _slider(parent: Control, caption: String, about: String, prop: String, mn: float, mx: float, step: float) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(_space(10))
	var head := HBoxContainer.new()
	var title := _text(caption, 26, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var value := _text("", 26, ACCENT)
	head.add_child(value)
	box.add_child(head)
	var sub := _text(about, 21, SUB)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = Tuning.get(prop)
	s.custom_minimum_size = Vector2(0, 56)
	s.focus_mode = Control.FOCUS_NONE
	box.add_child(s)
	value.text = _value_text(prop, s.value)
	s.value_changed.connect(func(val: float) -> void:
		Tuning.set(prop, val)
		value.text = _value_text(prop, val)
		_changed(prop))
	parent.add_child(box)
	parent.add_child(_line())
	_syncs.append(func() -> void:
		s.set_value_no_signal(Tuning.get(prop))
		value.text = _value_text(prop, s.value))


func _button(caption: String, on_press: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(on_press)
	_style_button(b, primary)
	return b


func _style_button(b: Button, lit: bool) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		if lit:
			sb.bg_color = ACCENT
		else:
			sb.bg_color = Color(1, 1, 1, 0.08 if state == "normal" or state == "focus" else 0.14)
			sb.border_color = Color(1, 1, 1, 0.1)
			sb.set_border_width_all(1)
		b.add_theme_stylebox_override(state, sb)
	var ink := Color(0.12, 0.1, 0.04) if lit else INK
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _space(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _line() -> ColorRect:
	var r := ColorRect.new()
	r.color = ROW_LINE
	r.custom_minimum_size.y = 1
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
