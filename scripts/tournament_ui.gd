class_name TournamentUI
extends CanvasLayer
## Screens around the matches: menu -> bracket -> (match) -> result -> reward -> bracket
## ... -> summary. Built from code like the rest of the UI. The court stays visible
## behind a dark veil. Every button reports through `chosen(action, arg)`; Main decides.

signal chosen(action: String, arg: int)

const GAME_TITLE := "МАТЧБОЛ"
const GOLD := Color(1.0, 0.85, 0.25)
const WIN := Color(0.45, 1.0, 0.5)
const LOSE := Color(1.0, 0.4, 0.35)
const DIM := Color(1, 1, 1, 0.6)

var root: Control
var _box: VBoxContainer


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.03, 0.05, 0.08, 0.72)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 110)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_box)
	root.visible = false


func is_open() -> bool:
	return root.visible


func close() -> void:
	root.visible = false


# --- Screens ------------------------------------------------------------------

func show_menu() -> void:
	_open()
	SaveData.load_once()
	_label(GAME_TITLE, 88, GOLD)
	_label("теннисный рогалик", 28, DIM)
	_gap(40)
	_button("ТУРНИР", "start_tournament", 0, true)
	_button("ИГРОК  ·  уровень %d" % Skills.total_level(), "character")
	_button("ТРЕНИРОВКА", "practice")
	_button("УПРАВЛЕНИЕ: %s" % ("ТАПЫ" if Tuning.tap_controls else "ДЖОЙСТИК"), "controls_menu")
	_gap(30)
	var best: String = "—" if SaveData.best_round < 0 else Opponents.ROUND_NAMES[SaveData.best_round]
	_label("Золото: %d   ·   Титулы: %d" % [SaveData.gold, SaveData.titles], 24, DIM)
	_label("Турниров: %d   ·   Лучший результат: %s" % [SaveData.played, best], 22, DIM)


## Control scheme, asked on the first launch (and from the menu). Can be changed later.
func show_controls() -> void:
	_open()
	_label("УПРАВЛЕНИЕ", 52, GOLD)
	_label("Как удобнее бегать? Удар в обоих режимах — свайп", 24, DIM, true)
	_gap(10)
	_card({"tag": "ГЕЙМПАД", "title": "Джойстик", "desc": "Большой палец внизу, под игроком: веди — игрок бежит. Отпустил — сам подстроится под мяч."}, "controls", 0, GOLD if not Tuning.tap_controls else DIM)
	_card({"tag": "ТАПЫ", "title": "Тап по корту", "desc": "Тапни по корту — игрок бежит туда. Держи палец — бежит за пальцем."}, "controls", 1, GOLD if Tuning.tap_controls else DIM)
	_gap(8)
	_label("Поменять можно в меню и в «НАСТР»", 20, DIM)


func show_bracket(t: Tournament) -> void:
	_open()
	_label(Tournament.TIER_NAME.to_upper(), 40, GOLD)
	var info := "Ракетка: %s   ·   Вайлд-карды: %d" % ["стандартная" if t.racket.is_empty() else t.racket["name"], t.wildcards]
	if not t.perks.is_empty():
		var names: Array[String] = []
		for id in t.perks:
			names.append(Rewards.find_perk(id)["title"])
		info += "   ·   Перки: " + ", ".join(names)
	_label(info, 21, DIM, true)
	_gap(8)
	for i in t.rounds():
		_bracket_row(t, i)
	_gap(16)
	var opp := t.opponent()
	_button("НА КОРТ: %s" % opp["name"].to_upper(), "play", 0, true)
	_button("СДАТЬСЯ", "give_up")


func show_result(t: Tournament, won: bool, score_text: String, stats: Dictionary) -> void:
	_open()
	var opp: Dictionary = Opponents.ROSTER[t.results.back()["stage"]]
	_label("ПОБЕДА" if won else "ПОРАЖЕНИЕ", 80, WIN if won else LOSE)
	_label("против: %s" % opp["name"], 28, DIM)
	_label(score_text, 56, Color.WHITE)
	_gap(10)
	_label("PERFECT: %d   ·   эйсы: %d   ·   лучший розыгрыш: %d" % [stats.get("perfect", 0), stats.get("aces", 0), stats.get("best_rally", 0)], 22, DIM, true)
	if won:
		_label("+%d золота" % t.gold_for_win(t.stage - 1), 28, GOLD)
	if won and not t.pending_loot.is_empty():
		_label("Трофей: %s" % t.pending_loot["name"], 26, Gear.color(t.pending_loot), true)
	_gap(30)
	if won and not t.pending_loot.is_empty():
		_button("ЗАБРАТЬ ТРОФЕЙ", "to_loot", 0, true)
		return
	match t.state:
		Tournament.State.REWARD:
			_button("ВЫБРАТЬ НАГРАДУ", "to_reward", 0, true)
		Tournament.State.LOST:
			_button("ВАЙЛД-КАРД: ПЕРЕИГРАТЬ (%d)" % t.wildcards, "wildcard", 0, true)
			_button("ЗАКОНЧИТЬ ТУРНИР", "give_up")
		_:
			_button("ИТОГИ", "to_summary", 0, true)


func show_formats() -> void:
	_open()
	_label("ФОРМАТ МАТЧЕЙ", 48, GOLD)
	_label("Чем длиннее матч, тем больше опыта и золота", 22, DIM, true)
	_gap(10)
	for i in Tournament.FORMATS.size():
		var f: Dictionary = Tournament.FORMATS[i]
		_card({"tag": "награды ×%s" % str(f["reward"]), "title": f["name"], "desc": f["desc"]}, "format", i, GOLD if i > 0 else Color(0.55, 0.8, 1.0))
	_gap(10)
	_button("НАЗАД", "menu")


func show_character() -> void:
	_open()
	_label("ИГРОК", 52, GOLD)
	_label("Уровень %d  ·  навык растёт от того, чем бьёшь" % Skills.total_level(), 22, DIM, true)
	if Skills.points > 0:
		_label("Стартовые очки: %d — вложи их в навыки (+1)" % Skills.points, 24, GOLD, true)
	_gap(6)
	for id in Skills.LIST:
		_skill_row(id)
	if not Skills.perks.is_empty():
		var names: Array[String] = []
		for p in Skills.perks:
			names.append(Skills.find_perk(p)["title"])
		_label("Билд: " + ", ".join(names), 20, DIM, true)
	_gap(10)
	_button("НАЗАД", "menu")


func show_skill_perk(skill: String, offer: Array) -> void:
	_open()
	_label("%s %d" % [String(Skills.NAMES[skill]).to_upper(), Skills.level(skill)], 52, GOLD)
	_label("Новый перк навыка: выбери один, это навсегда", 24, DIM, true)
	_gap(10)
	for i in offer.size():
		var p: Dictionary = offer[i]
		_card({"tag": "ПЕРК НАВЫКА", "title": p["title"], "desc": p["desc"]}, "perk", i, GOLD)


## The racket the beaten opponent dropped: take it or keep your own.
func show_loot(t: Tournament) -> void:
	_open()
	var item: Dictionary = t.pending_loot
	_label("ТРОФЕЙ", 56, Gear.color(item))
	_label("Ракетка соперника теперь твоя", 24, DIM, true)
	_gap(8)
	_item_panel(item, "ВЫПАЛО")
	_item_panel(t.racket, "СЕЙЧАС В РУКАХ")
	_gap(14)
	_button("ВЗЯТЬ", "loot", 1, true)
	_button("ОСТАВИТЬ СВОЮ", "loot", 0)


func _item_panel(item: Dictionary, tag: String) -> void:
	var c := {"tag": tag, "title": "Стандартная ракетка", "desc": "без бонусов"}
	if not item.is_empty():
		c = {"tag": "%s  ·  %s" % [tag, Gear.RARITIES[item["rarity"]]["name"].to_upper()], "title": item["name"], "desc": Gear.describe(item)}
	_card(c, "", -1, Gear.color(item) if not item.is_empty() else DIM)


func show_reward(t: Tournament) -> void:
	_open()
	_label("НАГРАДА", 56, GOLD)
	_label("Выбери одну", 26, DIM)
	_gap(10)
	for i in t.offer.size():
		var c: Dictionary = t.offer[i]
		match c["kind"]:
			"wildcard":
				_card({"tag": "ВАЙЛД-КАРД", "title": c["title"], "desc": c["desc"]}, "reward", i, Color(0.55, 0.8, 1.0))
			"item":
				var item: Dictionary = c["item"]
				var tag := "РАКЕТКА  ·  %s" % String(Gear.RARITIES[item["rarity"]]["name"]).to_upper()
				if not t.racket.is_empty():
					tag += "  ·  заменит «%s»" % t.racket["name"].get_slice("«", 1).trim_suffix("»")
				_card({"tag": tag, "title": c["title"], "desc": c["desc"]}, "reward", i, Gear.color(item))
			_:
				_card({"tag": "ПЕРК ТУРНИРА", "title": c["title"], "desc": c["desc"]}, "reward", i, GOLD)


func show_summary(t: Tournament) -> void:
	_open()
	_label("ЧЕМПИОН!" if t.champion else "ТУРНИР ОКОНЧЕН", 72, GOLD if t.champion else LOSE)
	_label(t.finish_text(), 30, Color.WHITE, true)
	_gap(10)
	var wins := 0
	for r in t.results:
		if r["won"]:
			wins += 1
	_label("Побед: %d   ·   золото за турнир: +%d" % [wins, t.gold], 26, DIM)
	_label("Всего золота: %d" % SaveData.gold, 24, GOLD)
	_gap(30)
	_button("ЕЩЁ ТУРНИР", "start_tournament", 0, true)
	_button("ИГРОК", "character")
	_button("В МЕНЮ", "menu")


# --- Building blocks ------------------------------------------------------------

func _open() -> void:
	for c in _box.get_children():
		c.queue_free()
	root.visible = true


func _label(text: String, font_size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 7))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(l)
	return l


func _gap(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(c)


func _style(bg: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	if border.a > 0.0:
		sb.set_border_width_all(3)
		sb.border_color = border
	return sb


func _button(text: String, action: String, arg := 0, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	var bg := GOLD if primary else Color(0.12, 0.15, 0.2, 0.95)
	var fg := Color(0.1, 0.08, 0.02) if primary else Color.WHITE
	b.add_theme_stylebox_override("normal", _style(bg))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.2)))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.pressed.connect(func() -> void: chosen.emit(action, arg))
	_box.add_child(b)
	return b


func _bracket_row(t: Tournament, i: int) -> void:
	var o: Dictionary = Opponents.ROSTER[i]
	var current := i == t.stage
	var done := i < t.stage
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := GOLD if current else Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.1, 0.13, 0.18, 0.92 if current else 0.7), border))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var head := Label.new()
	head.text = "%s  ·  %s" % [Opponents.ROUND_NAMES[i], o["title"]]
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", GOLD if o.get("boss", false) else DIM)
	v.add_child(head)
	var name_l := Label.new()
	name_l.text = o["name"]
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.add_theme_color_override("font_color", Color.WHITE if current or done else Color(1, 1, 1, 0.75))
	v.add_child(name_l)
	if not done and i < t.lineup.size():
		var lu: Dictionary = t.lineup[i]
		if not lu["mods"].is_empty():
			var names: Array[String] = []
			for m in lu["mods"]:
				names.append(Tournament.MODIFIERS[m]["name"])
			var ml := Label.new()
			ml.text = "Модификаторы: " + ", ".join(names)
			ml.add_theme_font_size_override("font_size", 18)
			ml.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
			v.add_child(ml)
		if not lu["racket"].is_empty():
			var rl := Label.new()
			rl.text = "В руках: " + lu["racket"]["name"]
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.add_theme_font_size_override("font_size", 19)
			rl.add_theme_color_override("font_color", Gear.color(lu["racket"]))
			v.add_child(rl)
	if current:
		var lesson := Label.new()
		lesson.text = o["lesson"]
		lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lesson.add_theme_font_size_override("font_size", 19)
		lesson.add_theme_color_override("font_color", DIM)
		v.add_child(lesson)
	var status := Label.new()
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	if done:
		status.text = _won_score(t, i)
		status.add_theme_color_override("font_color", WIN)
	elif current:
		status.text = "СЕЙЧАС"
		status.add_theme_color_override("font_color", GOLD)
	h.add_child(status)
	_box.add_child(panel)


func _won_score(t: Tournament, i: int) -> String:
	for r in t.results:
		if r["stage"] == i and r["won"]:
			return r["score"]
	return "ПОБЕДА"


## A big tappable card: small coloured tag, title, description.
func _card(c: Dictionary, action: String, i: int, border: Color) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 150)
	b.focus_mode = Control.FOCUS_NONE
	var bg := Color(0.12, 0.15, 0.2, 0.96)
	b.add_theme_stylebox_override("normal", _style(bg, border))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.08), border))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.2), border))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tag := Label.new()
	tag.text = c["tag"]
	tag.add_theme_font_size_override("font_size", 17)
	tag.add_theme_color_override("font_color", border)
	v.add_child(tag)
	var title := Label.new()
	title.text = c["title"]
	title.add_theme_font_size_override("font_size", 32)
	v.add_child(title)
	var desc := Label.new()
	desc.text = c["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 21)
	desc.add_theme_color_override("font_color", DIM)
	v.add_child(desc)
	for l in [tag, title, desc]:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if action == "":
		b.disabled = true
		b.add_theme_stylebox_override("disabled", _style(bg, border))
		b.custom_minimum_size = Vector2(0, 120)
	else:
		b.pressed.connect(func() -> void: chosen.emit(action, i))
	_box.add_child(b)


func _skill_row(id: String) -> void:
	var lv := Skills.level(id)
	var pr := Skills.progress(id)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.1, 0.13, 0.18, 0.85)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var name_l := Label.new()
	name_l.text = Skills.NAMES[id]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 28)
	h.add_child(name_l)
	var lv_l := Label.new()
	lv_l.text = "ур. %d / %d" % [lv, Skills.MAX_LEVEL]
	lv_l.add_theme_font_size_override("font_size", 24)
	lv_l.add_theme_color_override("font_color", GOLD)
	h.add_child(lv_l)
	if Skills.points > 0:
		var plus := Button.new()
		plus.text = " +1 "
		plus.focus_mode = Control.FOCUS_NONE
		plus.add_theme_font_size_override("font_size", 24)
		plus.add_theme_stylebox_override("normal", _style(GOLD))
		plus.add_theme_stylebox_override("pressed", _style(GOLD.darkened(0.2)))
		plus.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.1)))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			plus.add_theme_color_override(k, Color(0.1, 0.08, 0.02))
		var idx := Skills.LIST.find(id)
		plus.pressed.connect(func() -> void: chosen.emit("point", idx))
		h.add_child(plus)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = pr.y
	bar.value = pr.x
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	v.add_child(bar)
	var hint := Label.new()
	hint.text = "качается: %s  ·  перк каждые %d ур." % [Skills.HINTS[id], Skills.PERK_EVERY]
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", DIM)
	v.add_child(hint)
	_box.add_child(panel)
