class_name TournamentUI
extends CanvasLayer
## Screens around the matches: the Club (main menu) and its rooms, the tournament
## (locations, format, bracket, result, trophy, reward, perk, summary). Built from code
## like the rest of the UI, styled by UiTheme (PRODUCT.md: one brand color, cards after
## Balatro). Every button reports through `chosen(action, arg)`; Main decides.
##
## Every screen has the same frame, so the way in and out is always in the same place:
##   top bar   "← back" on the left, the gold chip on the right (НАСТР sits right of it)
##   middle    the screen's content, scrolling when it doesn't fit
##   bottom    the main action(s), pinned under the thumb

signal chosen(action: String, arg: int)
signal sfx_request(sound: String, volume_db: float, pitch: float)

const GAME_TITLE := "TENNISISI"
# Kept for callers that still read them (Main's tutorial, tests).
const GOLD := UiTheme.GOLD
const WIN := UiTheme.WIN
const LOSE := UiTheme.LOSE
const DIM := UiTheme.MUTED

const VEIL_CLUB := 0.38            # the Club: the court shows through
const VEIL_SCREEN := 0.8           # other screens: content first
const HUD_BUTTON_W := 132.0        # room kept free at the top right for НАСТР / ПАУЗА

var root: Control
var _veil: ColorRect
var _frame: MarginContainer
var _top: HBoxContainer
var _back_slot: HBoxContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _actions: VBoxContainer
var _safe_top := 0.0
var _safe_bottom := 0.0
var _chip: PanelContainer          # gold balance, top right
var _chip_label: Label
var _chip_icon: Control
var _gold_shown := 0
var _busy := false                 # a press animation is playing: ignore other taps
var _rays: Rays
var _look_editor: LookEditor        # the open look editor, if any
var look_result := {}               # what the look editor handed back ("look_done")


## A gold coin, drawn (no textures needed).
class Coin extends Control:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 13.0, Color(0.8, 0.55, 0.08))
		draw_circle(Vector2.ZERO, 10.5, UiTheme.GOLD)
		draw_circle(Vector2(-3.5, -3.5), 3.5, Color(1.0, 1.0, 0.85, 0.9))


## Slowly turning light rays behind a rare trophy.
class Rays extends Control:
	var color := Color.WHITE
	var centre := Vector2.ZERO
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in 14:
			var a := _t * 0.5 + TAU * i / 14.0
			var p1 := centre + Vector2.from_angle(a - 0.1) * 700.0
			var p2 := centre + Vector2.from_angle(a + 0.1) * 700.0
			draw_colored_polygon(PackedVector2Array([centre, p1, p2]), Color(color, 0.13))
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(centre, 150.0 + 12.0 * pulse, Color(color, 0.12))
		draw_circle(centre, 95.0, Color(color, 0.12))


## A small dot with a number: something to do in that room.
class Badge extends Control:
	var count := 0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 17.0, UiTheme.LOSE)
		var s := str(count)
		var f := UiTheme.text_bold()
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(-w * 0.5, 8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UiTheme.theme()
	add_child(root)
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(UiTheme.BASE, VEIL_SCREEN)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_veil)

	_frame = MarginContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_frame)
	_apply_margins()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(col)

	_top = HBoxContainer.new()
	_top.custom_minimum_size = Vector2(0, 84)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_top)
	_back_slot = HBoxContainer.new()
	_back_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_back_slot)
	_build_chip()
	var hud_gap := Control.new()
	hud_gap.custom_minimum_size = Vector2(HUD_BUTTON_W - UiTheme.GUTTER + 14.0, 0)
	hud_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(hud_gap)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 16)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_box)

	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 12)
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_actions)
	root.visible = false


## Below Telegram's buttons and the notch in full screen (see TelegramApp.safe_insets).
func set_safe_area(top: float, bottom: float) -> void:
	_safe_top = top
	_safe_bottom = bottom
	_apply_margins()


func _apply_margins() -> void:
	_frame.add_theme_constant_override("margin_left", UiTheme.GUTTER)
	_frame.add_theme_constant_override("margin_right", UiTheme.GUTTER)
	_frame.add_theme_constant_override("margin_top", 14 + int(_safe_top))
	_frame.add_theme_constant_override("margin_bottom", 26 + int(_safe_bottom))


func _build_chip() -> void:
	_chip = PanelContainer.new()
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.55), 2, 40, 14)
	sb.content_margin_left = 18
	sb.content_margin_right = 22
	_chip.add_theme_stylebox_override("panel", sb)
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_chip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_chip.add_child(h)
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(28, 28)
	h.add_child(icon_box)
	var coin := Coin.new()
	coin.position = Vector2(14, 14)
	icon_box.add_child(coin)
	_chip_icon = icon_box
	_chip_label = Label.new()
	_chip_label.add_theme_font_override("font", UiTheme.display())
	_chip_label.add_theme_font_size_override("font_size", 30)
	_chip_label.add_theme_color_override("font_color", UiTheme.GOLD)
	h.add_child(_chip_label)


## Gold to show: saved gold plus what the current run has earned but not banked yet.
func _balance(t: Tournament) -> int:
	return SaveData.gold + (t.gold if t != null and not t.banked else 0)


func _set_chip(v: int) -> void:
	_gold_shown = v
	_chip_label.text = str(v)


func is_open() -> bool:
	return root.visible


func close() -> void:
	root.visible = false


# --- The Club and its rooms -----------------------------------------------------

## The Club: the live court behind, the player's plate at the top, the way to play and
## the rooms under the thumb.
func show_menu() -> void:
	_open(null, true, "", VEIL_CLUB)
	SaveData.load_once()
	var brand := _text(GAME_TITLE, UiTheme.display(), UiTheme.T_HERO, UiTheme.GOLD)
	brand.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	brand.add_theme_constant_override("outline_size", 10)
	_box.add_child(brand)
	_box.add_child(_player_plate())

	var run := SaveData.resumable()
	if run != null:
		_primary("ПРОДОЛЖИТЬ  ·  %s" % run.round_name().to_lower(), "continue")
		_secondary("Новый турнир", "start_tournament")
	else:
		_primary("ТУРНИР", "start_tournament")
	var rooms := HBoxContainer.new()
	rooms.add_theme_constant_override("separation", 12)
	_actions.add_child(rooms)
	rooms.add_child(_tile("Тренировка", "свободная игра", "practice"))
	rooms.add_child(_tile("Раздевалка", "внешность, стиль", "locker"))
	var todo := Skills.points + Skills.pending.size()
	rooms.add_child(_tile("Тренерская", "навыки и перки", "character", todo))
	var how := _secondary("?  Как играть: удары и подача", "howto")
	how.add_theme_color_override("font_color", UiTheme.GOLD)
	how.custom_minimum_size = Vector2(0, 72)


## The player's plate on the Club: level, titles, the best result so far.
func _player_plate() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.9), UiTheme.LINE, 2, UiTheme.RADIUS, 22))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	p.add_child(h)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(lv)
	lv.add_child(_text(str(Skills.total_level()), UiTheme.display(), 64, UiTheme.GOLD))
	lv.add_child(_text("уровень", UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)
	var best: String = "пока нет" if SaveData.best_round < 0 else Opponents.ROUND_NAMES[SaveData.best_round]
	info.add_child(_left(_text("Титулов: %d" % SaveData.titles, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.INK)))
	info.add_child(_left(_text("Лучший результат: %s" % best, UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)))
	info.add_child(_left(_text("Турниров сыграно: %d" % SaveData.played, UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)))
	return p


## Раздевалка: what you look like and how you play (backhand, controls).
func show_locker(animate := true) -> void:
	_open(null, animate, "menu")
	_title("Раздевалка")
	_row("Внешность", "причёска, форма, цвет", "look")
	_row("Бэкхенд", "одноручный" if Tuning.one_handed_bh else "двуручный", "bh_style")
	_note("Одноручный — мощнее по линии (+6% силы), окно PERFECT чуть уже (−10%)")
	_row("Управление", "тапы по корту" if Tuning.tap_controls else "джойстик", "controls_menu")


## Тренерская: the skills, their levels and perks, the build.
func show_character(animate := true) -> void:
	_open(null, animate, "menu")
	_title("Тренерская")
	_sub("Навык растёт от того, чем бьёшь. Каждые %d уровней — перк навыка." % Skills.PERK_EVERY)
	if Skills.points > 0:
		var pts := _text("Стартовые очки: %d — нажми +1 у навыка" % Skills.points, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD)
		pts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(pts)
	for id in Skills.LIST:
		_skill_row(id)
	if not Skills.perks.is_empty():
		var names: Array[String] = []
		for p in Skills.perks:
			names.append(Skills.find_perk(p)["title"])
		_note("Билд: " + ", ".join(names))
	_gap(24)


## The character editor: hair, beard, headwear, skin and kit, with a turning preview.
func show_look_editor(look: Dictionary) -> void:
	_open(null, true, "look_back")  # back keeps what was picked so far, like ГОТОВО
	var ed := LookEditor.new()
	_look_editor = ed
	_title("Внешность")
	ed.ui = self
	ed.look = look
	ed.sfx.connect(func(sound: String, db: float, pitch: float) -> void: sfx_request.emit(sound, db, pitch))
	ed.done.connect(func(l: Dictionary) -> void:
		look_result = l
		chosen.emit("look_done", 0))
	_box.add_child(ed)


## The look being edited right now (for "← Назад" out of the editor).
func editing_look() -> Dictionary:
	return _look_editor.look.duplicate() if is_instance_valid(_look_editor) else look_result


## Control scheme, asked on the first launch (no way back: a choice is needed) and from
## the Раздевалка.
func show_controls(first := false) -> void:
	_open(null, true, "" if first else "locker")
	_title("Управление")
	_sub("Как удобнее бегать? Удар в обоих режимах — свайп")
	_card({"tag": "Джойстик", "title": "Большой палец внизу", "desc": "Веди пальцем под игроком — он бежит. Отпустил — сам подстроится под мяч."}, "controls", 0, Color(0, 0, 0, 0), -1, not Tuning.tap_controls)
	_card({"tag": "Тапы", "title": "Тап по корту", "desc": "Тапни по корту — игрок бежит туда. Держи палец — бежит за пальцем."}, "controls", 1, Color(0, 0, 0, 0), -1, Tuning.tap_controls)
	_note("Поменять можно в Раздевалке и в настройках")


# --- Tournament ------------------------------------------------------------------

func show_locations() -> void:
	_open(null, true, "menu")
	_title("Где играем")
	_sub("У каждого покрытия своя физика мяча")
	var colors := {"hard": Color(0.4, 0.62, 1.0), "clay": Color(0.95, 0.55, 0.3), "grass": Color(0.5, 0.85, 0.4)}
	for i in Locations.LIST.size():
		var l: Dictionary = Locations.LIST[i]
		_card({"tag": String(l["surface_name"]).capitalize(), "title": l["name"], "desc": l["desc"]}, "location", i, colors.get(l["surface"], UiTheme.LINE))


func show_formats() -> void:
	_open(null, true, "start_tournament")
	_title("Формат матчей")
	_sub("Чем длиннее матч, тем больше опыта и золота")
	for i in Tournament.FORMATS.size():
		var f: Dictionary = Tournament.FORMATS[i]
		_card({"tag": "награды ×%s" % str(f["reward"]), "title": f["name"], "desc": f["desc"]}, "format", i, Color(0, 0, 0, 0))


func show_bracket(t: Tournament) -> void:
	_open(t, true, "menu")
	_title(t.tier_name())
	var info := "Ракетка: %s   ·   Вайлд-карды: %d" % ["стандартная" if t.racket.is_empty() else t.racket["name"], t.wildcards]
	if not t.perks.is_empty():
		var names: Array[String] = []
		for id in t.perks:
			names.append(Rewards.find_perk(id)["title"])
		info += "   ·   Перки: " + ", ".join(names)
	_sub(info)
	for i in t.rounds():
		_bracket_row(t, i)
	var opp := t.opponent()
	_primary("НА КОРТ: %s" % String(opp["name"]).to_upper(), "play")
	_quiet("Сдаться и закончить турнир", "give_up")
	_scroll_to_current.call_deferred()


func show_result(t: Tournament, won: bool, score_text: String, stats: Dictionary) -> void:
	_open(t)
	var opp: Dictionary = Opponents.ROSTER[t.results.back()["stage"]]
	_box.add_child(_text("ПОБЕДА" if won else "ПОРАЖЕНИЕ", UiTheme.display(), UiTheme.T_HERO, UiTheme.WIN if won else UiTheme.LOSE))
	_sub("против: %s" % opp["name"])
	_box.add_child(_text(score_text, UiTheme.display(), 64, UiTheme.INK))
	_sub("PERFECT: %d   ·   эйсы: %d   ·   лучший розыгрыш: %d" % [stats.get("perfect", 0), stats.get("aces", 0), stats.get("best_rally", 0)])
	if won:
		var gain := t.gold_for_win(t.stage - 1) + (roundi(Tournament.CHAMPION_BONUS * float(t.format_info()["reward"])) if t.champion else 0)
		var gl := _text("+%d золота" % gain, UiTheme.display(), UiTheme.T_HEAD, UiTheme.GOLD)
		_box.add_child(gl)
		var total := _balance(t)
		_set_chip(total - gain)
		_fly_coins(gl, gain, total)
	if won and not t.pending_loot.is_empty():
		_box.add_child(_text("Трофей: %s" % t.pending_loot["name"], UiTheme.text_bold(), UiTheme.T_BODY, Gear.color(t.pending_loot)))
	elif won and t.missed_loot != "":
		_box.add_child(_text("Трофей упущен: %s" % t.missed_loot, UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.LOSE))
	if won and not t.pending_loot.is_empty():
		_primary("ЗАБРАТЬ ТРОФЕЙ", "to_loot")
		return
	match t.state:
		Tournament.State.REWARD:
			_primary("ВЫБРАТЬ НАГРАДУ", "to_reward")
		Tournament.State.LOST:
			_primary("ВАЙЛД-КАРД: ПЕРЕИГРАТЬ (%d)" % t.wildcards, "wildcard")
			_secondary("Закончить турнир", "give_up")
		_:
			_primary("ИТОГИ", "to_summary")


func show_skill_perk(skill: String, offer: Array) -> void:
	_open()
	_title("%s %d" % [Skills.NAMES[skill], Skills.level(skill)])
	_sub("Новый перк навыка: выбери один, это навсегда")
	for i in offer.size():
		var p: Dictionary = offer[i]
		_card({"tag": "Перк навыка", "title": p["title"], "desc": p["desc"]}, "perk", i, UiTheme.GOLD)


## The racket the beaten opponent dropped: take it or keep your own.
func show_loot(t: Tournament) -> void:
	_open(t)
	var item: Dictionary = t.pending_loot
	_title("Трофей", Gear.color(item))
	_sub("Ракетка соперника теперь твоя")
	var shown := _item_card(item, "Выпало")
	_item_card(t.racket, "Сейчас в руках", "")
	if not item.is_empty() and int(item["rarity"]) >= Gear.EPIC:
		_rays = Rays.new()
		_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rays.color = Gear.color(item)
		root.add_child(_rays)
		root.move_child(_rays, 1)  # behind the cards, over the dark veil
		_place_rays.call_deferred(shown)
	_primary("ВЗЯТЬ", "loot", 1)
	_secondary("Оставить свою", "loot", 0)


func _place_rays(target: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _rays and is_instance_valid(target):
		_rays.centre = target.get_global_rect().get_center()


## A racket as a card: the frame is its rarity. Empty = the standard racket.
func _item_card(item: Dictionary, what: String, action := "") -> GameCard:
	if item.is_empty():
		return _card({"tag": what, "title": "Стандартная ракетка", "desc": "без бонусов"}, action, -1, Color(0, 0, 0, 0))
	var r := int(item["rarity"])
	return _card({"tag": "%s  ·  %s" % [what, UiTheme.RARITY_NAMES[r]], "title": item["name"], "desc": Gear.describe(item)}, action, -1, Color(0, 0, 0, 0), r)


## Pick one of three. The cards come face down and turn over one after another; a tap
## on a card still face down turns it, a tap on an open card takes it.
func show_reward(t: Tournament) -> void:
	_open(t)
	_title("Награда")
	_sub("Выбери одну")
	var cards: Array[GameCard] = []
	for i in t.offer.size():
		var c: Dictionary = t.offer[i]
		var card: GameCard
		match c["kind"]:
			"wildcard":
				card = _card({"tag": "Вайлд-кард", "title": c["title"], "desc": c["desc"]}, "reward", i, Color(0.55, 0.8, 1.0))
			"item":
				var item: Dictionary = c["item"]
				var tag := "Ракетка  ·  %s" % UiTheme.RARITY_NAMES[int(item["rarity"])]
				if not t.racket.is_empty():
					tag += "  ·  заменит «%s»" % t.racket["name"].get_slice("«", 1).trim_suffix("»")
				card = _card({"tag": tag, "title": c["title"], "desc": c["desc"]}, "reward", i, Color(0, 0, 0, 0), int(item["rarity"]))
			_:
				card = _card({"tag": "Перк турнира", "title": c["title"], "desc": c["desc"]}, "reward", i, UiTheme.GOLD)
		card.face_down = true
		cards.append(card)
	for i in cards.size():
		cards[i].flip(0.35 + 0.2 * i)
		cards[i].flipped.connect(func() -> void: sfx_request.emit("hit", -14.0, 1.3 + 0.15 * i))


func show_summary(t: Tournament) -> void:
	_open(t)
	_box.add_child(_text("ЧЕМПИОН!" if t.champion else "Турнир окончен", UiTheme.display(), UiTheme.T_HERO if t.champion else UiTheme.T_TITLE, UiTheme.GOLD if t.champion else UiTheme.INK))
	_sub(t.finish_text())
	var wins := 0
	for r in t.results:
		if r["won"]:
			wins += 1
	_box.add_child(_text("Побед: %d   ·   золото за турнир: +%d" % [wins, t.gold], UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.INK))
	_box.add_child(_text("Всего золота: %d" % SaveData.gold, UiTheme.text(), UiTheme.T_BODY, UiTheme.GOLD))
	_primary("ЕЩЁ ТУРНИР", "start_tournament")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_actions.add_child(row)
	for pair in [["В клуб", "menu"], ["Тренерская", "character"]]:
		var b := _make_button(pair[0], pair[1], 0, "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


# --- Building blocks ------------------------------------------------------------

## Clears the screen for a new one. back: the action of "← Назад" ("" = none).
## animate = false refreshes a screen in place (a point spent, a style switched).
func _open(t: Tournament = null, animate := true, back := "", veil := VEIL_SCREEN) -> void:
	for parent in [_box, _actions, _back_slot]:
		for c in parent.get_children():
			parent.remove_child(c)  # out of the layout now, not at the end of the frame
			c.queue_free()
	if _rays:
		_rays.queue_free()
		_rays = null
	_veil.color = Color(UiTheme.BASE, veil)
	_scroll.scroll_vertical = 0
	root.visible = true
	_busy = false
	SaveData.load_once()
	_set_chip(_balance(t))
	if back != "":
		var b := _make_button("←  Назад", back, 0, "")
		b.custom_minimum_size = Vector2(196, 76)
		b.add_theme_font_size_override("font_size", UiTheme.T_BODY)
		_back_slot.add_child(b)
	if animate:
		_animate_in.call_deferred()


## Screens come in quietly: each block fades up a few pixels, one after another.
func _animate_in() -> void:
	var items: Array[Control] = []
	for parent in [_box, _actions]:
		for c in parent.get_children():
			if c is Control and not c.is_queued_for_deletion():
				items.append(c)
				c.modulate.a = 0.0
	await get_tree().process_frame
	var i := 0
	for c in items:
		if not is_instance_valid(c):
			continue
		var tw := c.create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_interval(0.03 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		i += 1


## A tap: the button dips and comes back (cards flash, the others fade), then reports.
func _press(b: Control, action: String, arg: int, card := false) -> void:
	if _busy:
		return
	_busy = true
	sfx_request.emit("hit", -16.0, 1.6)
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.06).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if card:
		tw.tween_property(b, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "modulate", Color(1.4, 1.4, 1.4), 0.12)
		for c in _box.get_children():
			if c != b and c is Control:
				var f := (c as Control).create_tween()
				f.set_ignore_time_scale(true)
				f.tween_property(c, "modulate:a", 0.25, 0.15)
		tw.tween_interval(0.16)
	tw.tween_property(b, "scale", Vector2.ONE, 0.08)
	await tw.finished
	_busy = false
	chosen.emit(action, arg)


## Coins burst out of `from` and fly into the balance chip, which counts up to `to_value`.
func _fly_coins(from: Control, gain: int, to_value: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(from) or gain <= 0:
		_set_chip(to_value)
		return
	var start := from.get_global_rect().get_center()
	var target := _chip_icon.get_global_rect().get_center()
	var n := clampi(gain / 2, 6, 18)
	var base := _gold_shown
	var landed := [0]
	for i in n:
		var coin := Coin.new()
		coin.position = start
		root.add_child(coin)
		var burst := start + Vector2(randf_range(-110, 110), randf_range(-130, -30))
		var tw := coin.create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(coin, "position", burst, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.03 * i)
		tw.tween_property(coin, "position", target, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(coin, "scale", Vector2(0.7, 0.7), 0.42)
		tw.tween_callback(func() -> void:
			coin.queue_free()
			landed[0] += 1
			_set_chip(base + roundi(float(gain) * landed[0] / n) if landed[0] < n else to_value)
			_chip.pivot_offset = _chip.size * 0.5
			var p := _chip.create_tween()
			p.set_ignore_time_scale(true)
			p.tween_property(_chip, "scale", Vector2(1.12, 1.12), 0.05)
			p.tween_property(_chip, "scale", Vector2.ONE, 0.1)
			sfx_request.emit("bounce", -12.0, 1.7 + 0.02 * landed[0]))


## The old shared box, still used by LookEditor: the theme's shape with a 3 px border.
func _style(bg: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	return UiTheme.box(bg, border, 3, 18, 16)


func _text(s: String, f: Font, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _left(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _title(s: String, c := UiTheme.GOLD) -> Label:
	var l := _text(s, UiTheme.display(), UiTheme.T_TITLE, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	return l


func _sub(s: String) -> Label:
	var l := _text(s, UiTheme.text(), UiTheme.T_SMALL + 3, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	return l


func _gap(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(c)


func _note(s: String) -> Label:
	var l := _text(s, UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	return l


func _make_button(s: String, action: String, arg: int, variation: String) -> Button:
	var b := Button.new()
	b.text = s
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, UiTheme.TAP + (12.0 if variation == "Primary" else 0.0))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _press(b, action, arg))
	return b


## The screen's main action: gold, full width, pinned at the bottom.
func _primary(s: String, action: String, arg := 0) -> Button:
	var b := _make_button(s, action, arg, "Primary")
	_actions.add_child(b)
	return b


func _secondary(s: String, action: String, arg := 0) -> Button:
	var b := _make_button(s, action, arg, "")
	_actions.add_child(b)
	return b


func _quiet(s: String, action: String, arg := 0) -> Button:
	var b := _make_button(s, action, arg, "Quiet")
	b.custom_minimum_size = Vector2(0, 64)
	_actions.add_child(b)
	return b


## A Club room: name, what's inside, a red count when something waits there.
func _tile(name: String, what: String, action: String, badge := 0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 132)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: _press(b, action, 0))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var n := _text(name, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.INK)
	v.add_child(n)
	var w := _text(what, UiTheme.text(), UiTheme.T_SMALL - 2, UiTheme.MUTED)
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(w)
	if badge > 0:
		var d := Badge.new()
		d.count = badge
		d.position = Vector2(0, 0)
		d.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		d.offset_left = -18
		d.offset_top = 18
		b.add_child(d)
	return b


## A settings-like row: name on the left, the current value on the right, the whole
## row tappable.
func _row(name: String, value: String, action: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 104)
	b.pressed.connect(func() -> void: _press(b, action, 0))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 28
	h.offset_right = -28
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var n := _left(_text(name, UiTheme.text_bold(), UiTheme.T_BODY + 2, UiTheme.INK))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(_text(value + "  ›", UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.GOLD))
	_box.add_child(b)
	return b


## A card in the middle of the screen (see GameCard). action "" = shown, not tappable.
func _card(c: Dictionary, action: String, i: int, accent: Color, rarity := -1, selected := false) -> GameCard:
	var card := GameCard.new()
	card.tag = c.get("tag", "")
	card.title = c.get("title", "")
	card.desc = c.get("desc", "")
	card.accent = accent
	card.rarity = rarity
	card.selected = selected
	if action == "":
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		card.pressed.connect(func() -> void:
			if card.face_down:
				card.flip()
			else:
				_press(card, action, i, true))
	_box.add_child(card)
	return card


func _scroll_to_current() -> void:
	await get_tree().process_frame
	for c in _box.get_children():
		if c.has_meta("current"):
			_scroll.ensure_control_visible(c)


func _bracket_row(t: Tournament, i: int) -> void:
	var o: Dictionary = Opponents.ROSTER[i]
	var current := i == t.stage
	var done := i < t.stage
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if current:
		panel.set_meta("current", true)
	var bg := UiTheme.SURFACE if current else Color(UiTheme.SURFACE, 0.7)
	panel.add_theme_stylebox_override("panel", UiTheme.box(bg, UiTheme.GOLD if current else UiTheme.LINE, 4 if current else 2, UiTheme.RADIUS, 22))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(_left(_text("%s  ·  %s" % [Opponents.ROUND_NAMES[i], o["title"]], UiTheme.text(), UiTheme.T_SMALL, UiTheme.GOLD if o.get("boss", false) else UiTheme.MUTED)))
	v.add_child(_left(_text(o["name"], UiTheme.display(), UiTheme.T_HEAD - 2, UiTheme.INK if current or done else Color(UiTheme.INK, 0.7))))
	if not done and i < t.lineup.size():
		var lu: Dictionary = t.lineup[i]
		if not lu["mods"].is_empty():
			var names: Array[String] = []
			for m in lu["mods"]:
				names.append(Tournament.MODIFIERS[m]["name"])
			v.add_child(_left(_text("Модификаторы: " + ", ".join(names), UiTheme.text(), UiTheme.T_SMALL, Color(1.0, 0.6, 0.35))))
		if not lu["racket"].is_empty():
			var rl := _left(_text("В руках: " + lu["racket"]["name"], UiTheme.text_bold(), UiTheme.T_SMALL, Gear.color(lu["racket"])))
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(rl)
	if current:
		var lesson := _left(_text(o["lesson"], UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED))
		lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lesson)
	var status := _text("", UiTheme.display(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if done:
		status.text = _won_score(t, i)
		status.add_theme_color_override("font_color", UiTheme.WIN)
	elif current:
		status.text = "СЕЙЧАС"
		status.add_theme_color_override("font_color", UiTheme.GOLD)
	h.add_child(status)
	_box.add_child(panel)


func _won_score(t: Tournament, i: int) -> String:
	for r in t.results:
		if r["stage"] == i and r["won"]:
			return r["score"]
	return "ПОБЕДА"


func _skill_row(id: String) -> void:
	var lv := Skills.level(id)
	var pr := Skills.progress(id)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 2, UiTheme.RADIUS, 22))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var name_l := _left(_text(Skills.NAMES[id], UiTheme.text_bold(), UiTheme.T_BODY + 2, UiTheme.INK))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_l)
	var lv_l := _text("%d" % lv, UiTheme.display(), UiTheme.T_HEAD, UiTheme.GOLD)
	h.add_child(lv_l)
	h.add_child(_text("/ %d" % Skills.MAX_LEVEL, UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED))
	if Skills.points > 0 and lv < Skills.MAX_LEVEL:
		var plus := Button.new()
		plus.text = "+1"
		plus.theme_type_variation = "Primary"
		plus.custom_minimum_size = Vector2(92, 72)
		plus.focus_mode = Control.FOCUS_NONE
		var idx := Skills.LIST.find(id)
		plus.pressed.connect(func() -> void: chosen.emit("point", idx))
		h.add_child(plus)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = pr.y
	bar.value = pr.x
	bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD, Color(0, 0, 0, 0), 0, 6, 0))
	bar.add_theme_stylebox_override("background", UiTheme.box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 6, 0))
	v.add_child(bar)
	var hint := _left(_text("%s  ·  сейчас %s" % [Skills.HINTS[id], Skills.headline(id, lv)], UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	_box.add_child(panel)
