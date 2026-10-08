class_name SettingsSheet
extends UiSheet
## The settings (UI_FLOW_TZ 6.2): one sheet the whole height, opened by ⚙ anywhere and
## from the pause. Ordered by what people change most; what is not for players is folded
## at the end. Every option says in plain words what it does, sliders show human values
## ("35 мс", "средне"). ГОТОВО is pinned at the bottom. Moved out of Hud (it was the pause
## as well); "Выйти в меню", "Как играть" and the backhand switch live elsewhere now (the
## pause, the club's "?", the Раздевалка: P1-5, P2-8).

const ROW_LINE := Color(1, 1, 1, 0.07)
const CAPTION := 26
const ABOUT := UiTheme.T_SMALL
const WARN_TG := "Может тормозить в Telegram."
const GFX_NOTES := [
	"Сама подстраивается под устройство: если кадры проседают, качество снижается.",
	"Для старых телефонов: меньше пикселей, без сглаживания, простые тени.",
	"Баланс: картинка чуть мягче, тени жёсткие, без лишних деталей сцены.",
	"Чёткая картинка, мягкие тени, все детали сцены. " + WARN_TG,
	"Для флагманов: родное разрешение, сглаживание 4x, мягкие и дальние тени. Телефон может греться. " + WARN_TG,
	"Своя настройка: части графики выставлены вручную ниже.",
]
const AUTO_PHONE_NOTE := " На телефоне — не выше «Средней»."

var _syncs: Array[Callable] = []    # re-read every control from Tuning when the sheet opens
var _gfx_buttons: Array[Button] = []
var _gfx_note: Label
var scroll: ScrollContainer
var done: Button


func _init() -> void:
	super._init(true)


func _ready() -> void:
	super._ready()
	body.add_child(label("Настройки", UiTheme.display(), UiTheme.T_TITLE - 6, UiTheme.INK))
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	scroll.add_child(v)
	_build(v)
	done = button("ГОТОВО", func() -> void: veil_tapped.emit(), "Primary")
	actions.add_child(done)


## Re-reads every control (the menu or the game may have changed a setting).
func sync() -> void:
	for s in _syncs:
		s.call()


func open() -> void:
	sync()
	scroll.scroll_vertical = 0
	super.open()


func _build(v: VBoxContainer) -> void:
	_section(v, "Управление")
	_choice(v, "Бег", "Джойстик — большой палец внизу. Тапы — тапни по корту, игрок бежит туда", "tap_controls", ["Джойстик", "Тапы"], [false, true])
	_slider(v, "Помощь в беге", "Игрок сам подбегает к мячу. 0 — бегаешь полностью сам", "assist", 0.0, 1.0, 0.05)
	_slider(v, "Соперник в тренировке", "Только для тренировки: в турнире у каждого своя сила", "ai_skill", 0.0, 1.0, 0.05)

	_section(v, "Подсказки на корте")
	_switch(v, "Прицел", "Показывает, куда полетит мяч, пока ведёшь пальцем", "show_aim")
	_switch(v, "Точка приземления", "Где мяч коснётся корта", "show_landing")
	_switch(v, "Траектория мяча", "Линия полёта целиком — для тренировки", "show_path")
	_switch(v, "Замедление перед ударом", "Время замедляется, когда мяч подлетает: проще поймать кольцо", "slowmo_enabled")
	_switch(v, "Стоп-кадр на PERFECT", "Короткая пауза в момент идеального удара — чувствуется сила", "hitstop")

	_section(v, "Звук")
	_switch(v, "Звуки окружения", "Море, город, колокол и игра на соседнем корте", "ambience")
	_switch(v, "Музыка в меню", "Только в меню, в матче — тишина корта", "music")
	_switch(v, "Вибрация при ударе", "Отдача в руку на каждом ударе (Android и Telegram)", "vibration")

	_section(v, "Графика")
	_graphics_choice(v)
	_graphics_manual(v)
	_switch(v, "Счётчик FPS", "Частота кадров в углу экрана: 60 — идеально, ниже 40 — снизь графику", "show_fps")

	var fine := VBoxContainer.new()
	fine.add_theme_constant_override("separation", 0)
	fine.visible = false
	v.add_child(_space(18))
	var fold := _flat_button("Для разработчика  ▸")
	fold.pressed.connect(func() -> void:
		fine.visible = not fine.visible
		fold.text = "Для разработчика  ▾" if fine.visible else "Для разработчика  ▸")
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
	if SaveData.crashes > 0:
		var c := label("Сбоев страницы: %d · последний: %s" % [SaveData.crashes, SaveData.last_crash], UiTheme.text(), ABOUT, UiTheme.MUTED)
		fine.add_child(c)
	v.add_child(_space(10))


## Human-readable value of a slider.
static func value_text(prop: String, val: float) -> String:
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


## The caption of a preset's button: short, with "!" where Telegram may stutter.
static func preset_caption(i: int) -> String:
	match i:
		GraphicsQuality.HIGH:
			return "Выс !"
		GraphicsQuality.MAX:
			return "Макс !"
		GraphicsQuality.MEDIUM:
			return "Сред"
		GraphicsQuality.LOW:
			return "Низк"
	return GraphicsQuality.NAMES[i]


## What the chosen preset does, in one line (and the phone's cap for "Авто").
static func preset_note(i: int, phone: bool) -> String:
	var n: String = GFX_NOTES[clampi(i, 0, GFX_NOTES.size() - 1)]
	return n + (AUTO_PHONE_NOTE if i == GraphicsQuality.AUTO and phone else "")


func _section(parent: Control, caption: String) -> void:
	parent.add_child(_space(26))
	parent.add_child(label(caption, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD))
	parent.add_child(_space(4))


## Graphics: five presets in a row (one tap, the current one lit) and a line saying what
## the chosen one does.
func _graphics_choice(parent: Control) -> void:
	parent.add_child(_space(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_gfx_buttons.clear()
	for i in GraphicsQuality.NAMES.size():
		var b := _flat_button(preset_caption(i))
		b.pressed.connect(func() -> void:
			Tuning.graphics = i
			Tuning.notify_changed()  # the preset fills the manual parts in...
			sync())                  # ...and the controls below show them
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", ABOUT)
		row.add_child(b)
		_gfx_buttons.append(b)
	parent.add_child(row)
	_gfx_note = label("", UiTheme.text(), ABOUT, UiTheme.MUTED)
	parent.add_child(_space(8))
	parent.add_child(_gfx_note)
	parent.add_child(_line())
	_syncs.append(_sync_graphics)
	_sync_graphics()


func _sync_graphics() -> void:
	for i in _gfx_buttons.size():
		_lit(_gfx_buttons[i], i == Tuning.graphics)  # "Своя": none lit
	_gfx_note.text = preset_note(Tuning.graphics, false)


## The parts of the graphics by hand, folded under the presets. Touching any of them
## makes the preset "Своя".
func _graphics_manual(parent: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.visible = false
	var fold := _flat_button("Настроить вручную  ▸")
	fold.pressed.connect(func() -> void:
		box.visible = not box.visible
		fold.text = "Настроить вручную  ▾" if box.visible else "Настроить вручную  ▸")
	parent.add_child(_space(10))
	parent.add_child(fold)
	parent.add_child(box)
	_slider(box, "Чёткость", "Разрешение 3D-картинки. Интерфейс всегда чёткий. Самое заметное для FPS", "gfx_res", 0.4, 1.0, 0.05)
	_choice(box, "Тени", "Мягкие — красивее, «Лучшие» — для флагманов, «Выкл» — быстрее всего", "gfx_shadows", ["Выкл", "Простые", "Мягкие", "Лучшие"], [0, 1, 2, 3])
	_slider(box, "Дальность теней", "Как далеко от камеры видны тени: трибуны, деревья, дома", "gfx_reach", 0.5, 1.5, 0.05)
	_choice(box, "Сглаживание краёв", "Убирает «лесенку» на линиях корта и сетке", "gfx_aa", ["Выкл", "2x", "4x"], [0, 1, 2])
	_switch(box, "Детали сцены", "Тени облаков и мелкие предметы вокруг корта", "gfx_details")
	parent.add_child(_space(6))


## A row of choices for one setting, the current one lit. `values` are what each button
## writes into Tuning (bools for an on/off choice, ints for a level).
func _choice(parent: Control, caption: String, about: String, prop: String, labels: Array, values: Array) -> void:
	parent.add_child(_space(12))
	parent.add_child(label(caption, UiTheme.text_bold(), CAPTION, UiTheme.INK))
	parent.add_child(label(about, UiTheme.text(), ABOUT, UiTheme.MUTED))
	parent.add_child(_space(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var buttons: Array[Button] = []
	var paint := func() -> void:
		for i in buttons.size():
			_lit(buttons[i], Tuning.get(prop) == values[i])
	for i in labels.size():
		var b := _flat_button(labels[i])
		b.pressed.connect(func() -> void:
			Tuning.set(prop, values[i])
			_changed(prop)
			paint.call())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", ABOUT)
		row.add_child(b)
		buttons.append(b)
	parent.add_child(row)
	parent.add_child(_space(12))
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
## right (84 px: a thumb, not the stock switch).
func _switch(parent: Control, caption: String, about: String, prop: String) -> void:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	pad.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.add_child(label(caption, UiTheme.text_bold(), CAPTION, UiTheme.INK))
	texts.add_child(label(about, UiTheme.text(), ABOUT, UiTheme.MUTED))
	row.add_child(texts)
	var b := _flat_button("")
	b.custom_minimum_size = Vector2(124, UiTheme.TAP)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", ABOUT)
	var paint := func() -> void:
		var on: bool = Tuning.get(prop)
		b.text = "ВКЛ" if on else "ВЫКЛ"
		_lit(b, on)
	paint.call()
	b.pressed.connect(func() -> void:
		Tuning.set(prop, not bool(Tuning.get(prop)))
		paint.call()
		_changed(prop))
	row.add_child(b)
	parent.add_child(pad)
	parent.add_child(_line())
	_syncs.append(paint)


func _slider(parent: Control, caption: String, about: String, prop: String, mn: float, mx: float, step: float) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(_space(12))
	var head := HBoxContainer.new()
	var title := label(caption, UiTheme.text_bold(), CAPTION, UiTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var value := label("", UiTheme.display(), CAPTION, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(value)
	box.add_child(head)
	box.add_child(label(about, UiTheme.text(), ABOUT, UiTheme.MUTED))
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = Tuning.get(prop)
	s.custom_minimum_size = Vector2(0, 64)
	s.focus_mode = Control.FOCUS_NONE
	box.add_child(s)
	value.text = value_text(prop, s.value)
	s.value_changed.connect(func(val: float) -> void:
		Tuning.set(prop, val)
		value.text = value_text(prop, val)
		_changed(prop))
	parent.add_child(box)
	parent.add_child(_line())
	_syncs.append(func() -> void:
		s.set_value_no_signal(Tuning.get(prop))
		value.text = value_text(prop, s.value))


## A secondary button of the sheet (84 px tall).
func _flat_button(caption: String) -> Button:
	var b := Button.new()
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiTheme.TAP)
	b.add_theme_font_size_override("font_size", UiTheme.T_BODY - 3)
	return b


## The current choice is gold, the others the quiet surface.
func _lit(b: Button, on: bool) -> void:
	b.theme_type_variation = "Primary" if on else ""


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
