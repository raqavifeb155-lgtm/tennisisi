class_name CareerUi
## The career's screens (L1, spec docs/superpowers/specs/2026-10-10-l1-career.md): the season's
## calendar in the bracket and the Тренерская, the season's summary, the farewell ceremony
## (the numbers -> what stays and what goes -> the relic -> the heir out of three -> the new
## player of the club) and the quiet «Завершить карьеру» from the 3rd season. The logic is
## Career; this is only how it looks, on the TournamentUI frame.
##
## Hooks (one line each): TournamentUI.show_bracket / show_summary / show_character call
## bracket_extra / summary_extra / character_extra; Main._on_ui hands "career_*" to route();
## Main._start_tournament asks gate() first (a due retirement comes before any new run).
##
## Actions: career_season, career_retire, career_relic_go, career_relic i (-1 = none),
## career_heir i, career_heir_go, career_early, career_early_yes, career_done.

const CELL_H := 112.0
const ISLAND_SHORT := {"park": "Нью-Йорк", "clay": "Испания", "grass": "Англия", "paris": "Париж", "club": "Свой клуб"}

static var _relic := -1            # the relic option picked (-1 = none)
static var _heir := -1             # the heir card picked (-1 = none yet)


## Main._on_ui calls this first: true = the action was ours.
static func route(m: Node, action: String, arg: int) -> bool:
	if not action.begins_with("career_"):
		return false
	var ui: TournamentUI = m.ui
	var t: Tournament = m.get("tournament")
	match action:
		"career_season":
			show_season(ui)
		"career_retire":
			_preview(m, {})
			show_retire(ui, t)
		"career_relic_go":
			_preview(m, {})
			show_relic(ui, t)
		"career_relic":
			_relic = arg
			_heir = -1
			show_heirs(ui)
		"career_heir":
			_heir = arg
			var hs := Career.heir_candidates()
			_preview(m, hs[arg]["look"] if arg >= 0 and arg < hs.size() else {})  # the court behind shows him
			show_heirs(ui, false)
		"career_heir_go":
			finish(m)
		"career_early":
			show_early(ui)
		"career_early_yes":
			Career.request_early()
			SaveData.save()
			show_retire(ui, t)
		"career_done":
			m._on_ui("menu", 0)
	return true


## Main._start_tournament: a due retirement first. true = the start is held (the ceremony
## opened); the bot retires on its own and the start goes on.
static func gate(m: Node) -> bool:
	if not Career.retire_due():
		return false
	if m.get("autoplay"):
		CareerBot.auto_retire(m)
		return false
	show_retire(m.ui, m.get("tournament"))
	return true


## The player on the court behind the screen wears the candidate's look ({} = the hero's own).
static func _preview(m: Node, look: Dictionary) -> void:
	var p = m.get("player")
	if p != null:
		p.set_look(look if not look.is_empty() else SaveData.look)


## The relic and the heir picked on the screens become the retirement (one step).
static func finish(m: Node) -> void:
	var heirs := Career.heir_candidates()
	if heirs.is_empty():
		return
	var t: Tournament = m.get("tournament")
	var opts := Career.relic_options(t)
	var relic: Dictionary = opts[_relic] if _relic >= 0 and _relic < opts.size() else {}
	Career.retire(heirs[clampi(_heir, 0, heirs.size() - 1)], relic, t)
	_relic = -1
	_heir = -1
	var p = m.get("player")
	if p != null:
		p.set_look(SaveData.look)
	show_welcome(m.ui)


# --- The calendar -----------------------------------------------------------------------

## «Сезон 2 · турнир 3 из 4 · Дима, 22 года»
static func season_line() -> String:
	var c := Career.data()
	var n := mini(int(c["in_season"]) + 1, Career.PER_SEASON)
	return "Сезон %d · турнир %d из %d · %s, %d %s" % [Career.season(), n, Career.PER_SEASON, Career.hero_name(), int(c["age"]), _years(int(c["age"]))]


static func _years(n: int) -> String:
	var d := n % 10
	if n % 100 >= 11 and n % 100 <= 14:
		return "лет"
	return "год" if d == 1 else ("года" if d >= 2 and d <= 4 else "лет")


## Four cells: the closed runs (island, points or the title), the one now, the final (★).
## cells: a season's cells ([] = the current season's).
static func calendar(ui: TournamentUI, cells: Array = [], current := -1) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Career.PER_SEASON:
		var cell: Dictionary = cells[i] if i < cells.size() else {}
		var now := i == current
		var final := i == Career.PER_SEASON - 1
		var border := UiTheme.GOLD if now else (Color(UiTheme.GOLD, 0.45) if final else UiTheme.LINE)
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(0, CELL_H)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE_HI if now else UiTheme.SURFACE, border, 3 if now else 2, 16, 8))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(v)
		var head := ("★ ФИНАЛ" if final else str(i + 1)) + ("  ✓" if not cell.is_empty() else "")
		v.add_child(ui._text(head, UiTheme.text_bold(), UiTheme.T_SMALL - 2, UiTheme.GOLD if final or now else UiTheme.INK))
		var where := String(ISLAND_SHORT.get(String(cell.get("loc", "")), "")) if not cell.is_empty() else ("сейчас" if now else "·")
		v.add_child(ui._text(where, UiTheme.text(), UiTheme.T_SMALL - 4, UiTheme.MUTED))
		var what := ""
		if not cell.is_empty():
			what = "титул" if cell.get("champion", false) else "+%d" % int(cell.get("pts", 0))
		elif final:
			what = "×2 очки"
		if what != "":
			v.add_child(ui._text(what, UiTheme.text_bold(), UiTheme.T_SMALL - 2, UiTheme.GOLD if cell.get("champion", false) else UiTheme.INK))
		row.add_child(p)
	return row


## The bracket: the season's line and calendar; the final says what it pays.
static func bracket_extra(ui: TournamentUI, t: Tournament) -> void:
	var c := Career.data()
	if Career.retire_due():
		return
	ui._box.add_child(ui._text(season_line(), UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.GOLD))
	ui._box.add_child(calendar(ui, c["cells"], int(c["in_season"])))
	if Career.is_final_next():
		var fl := Career.final_loc()
		if t != null and Career.is_final(t):
			ui._note("Финал сезона: призовые ×%s, очки рейтинга ×%d" % [_x(Career.FINAL_PRIZE), Career.FINAL_PTS])
		else:
			ui._note("Финал сезона даёт бонус только на острове %s" % String(Locations.find(fl).get("name", fl)))
	if Career.season() == Career.SEASONS:
		ui._note("Прощальный сезон: призовые ×%s" % _x(Career.FAREWELL_PRIZE))


static func _x(v: float) -> String:
	return str(v).replace(".", ",")


# --- The run's summary ------------------------------------------------------------------

## The summary: the run's points in the season; a closed season or a due retirement takes
## over the way out (the season's summary first).
static func summary_extra(ui: TournamentUI, t: Tournament) -> void:
	var c := Career.data()
	var cells: Array = c["cells"]
	var last: Dictionary = cells.back() if not cells.is_empty() else {}
	if int(c["season_due"]) > 0 or Career.retire_due():
		last = (Career.last_season().get("cells", []) as Array).back() if not (Career.last_season().get("cells", []) as Array).is_empty() else {}
	if not last.is_empty() and t != null and t.banked:
		var l := ui._text("Рейтинг: +%d очков%s" % [int(last["pts"]), "  ·  финал сезона ×2" if last.get("final", false) else ""], UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(l)
	if int(c["season_due"]) <= 0 and not Career.retire_due():
		if not cells.is_empty():
			ui._note(season_line())
		return
	for b in ui._actions.get_children():
		ui._actions.remove_child(b)
		b.queue_free()
	if int(c["season_due"]) > 0:
		ui._primary("ИТОГИ СЕЗОНА %d" % int(c["season_due"]), "career_season")
	else:
		ui._primary("ПРОЩАНИЕ С КАРЬЕРОЙ", "career_retire")


# --- The Тренерская ---------------------------------------------------------------------

## The career's card: season, age, the experience multiplier, the calendar, the coaches of
## the club; from the 3rd season the quiet «Завершить карьеру сейчас».
static func character_extra(ui: TournamentUI) -> void:
	var c := Career.data()
	ui._box.add_child(ui._text(season_line(), UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD))
	ui._note("%s  ·  опыт навыков ×%s  ·  навыки не падают" % [Career.SEASON_NAMES[Career.season() - 1], _x(Career.xp_mult())])
	if not Career.retire_due():
		ui._box.add_child(calendar(ui, c["cells"], int(c["in_season"])))
	var line := "Рейтинг сезона: %d очков" % int(c["season_pts"])
	if int(c["best_rank"]) < Career.RANK_NONE:
		line += "  ·  лучшее место: %s" % Career.rank_text(int(c["best_rank"]))
	ui._note(line)
	ui._note("Пенсия после %d сезонов: клуб, золото и шкафчик остаются, навыки уходят" % Career.SEASONS)
	var ret: Array = c["retired"]
	if not ret.is_empty():
		var names: Array[String] = []
		for r in ret:
			names.append(String(r["name"]))
		ui._note("Тренеры клуба: " + ", ".join(names))
	if Career.retire_due():
		ui._primary("ПРОЩАНИЕ С КАРЬЕРОЙ", "career_retire")
	elif Career.can_retire_early():
		ui._quiet("Завершить карьеру сейчас", "career_early")


static func show_early(ui: TournamentUI) -> void:
	ui._open(null, true, "character")
	ui._title("Завершить карьеру?")
	ui._sub("%s уйдёт на пенсию и станет тренером клуба. Вернуть нельзя." % Career.hero_name())
	_stays_goes(ui)
	ui._primary("ЗАВЕРШИТЬ КАРЬЕРУ", "career_early_yes")
	ui._secondary("Ещё поиграть", "character")


# --- The season's summary ---------------------------------------------------------------

static func show_season(ui: TournamentUI) -> void:
	var c := Career.data()
	var s := Career.last_season()
	c["season_due"] = 0
	SaveData.save()
	ui._open(null)
	ui._title("ИТОГИ СЕЗОНА %d" % int(s.get("season", 1)))
	ui._sub("%s · %s" % [Career.hero_name(), Career.SEASON_NAMES[clampi(int(s.get("season", 1)), 1, 5) - 1]])
	var rank := int(s.get("rank", Career.RANK_NONE))
	ui._box.add_child(ui._text(Career.rank_text(rank), UiTheme.display(), UiTheme.T_TITLE, UiTheme.GOLD if rank <= 100 else UiTheme.INK))
	ui._note("Рейтинг сезона: %d очков  ·  титулов: %d" % [int(s.get("pts", 0)), int(s.get("titles", 0))])
	ui._box.add_child(calendar(ui, s.get("cells", [])))
	ui._box.add_child(ui._text("+%d золота за место" % int(s.get("gold", 0)), UiTheme.display(), UiTheme.T_HEAD, UiTheme.GOLD))
	if Career.retire_due():
		ui._gap(8)
		ui._sub("Карьера окончена: %d турниров, %d сезонов" % [Career.runs(), (c["seasons"] as Array).size()])
		ui._primary("ПРОЩАНИЕ С КАРЬЕРОЙ", "career_retire")
		return
	var nxt := Career.season()
	ui._gap(8)
	ui._sub("Следующий сезон: %s, %d %s  ·  опыт ×%s" % [Career.hero_name(), int(c["age"]), _years(int(c["age"])), _x(Career.xp_mult())])
	if nxt == Career.SEASONS:
		var fw := ui._text("ПРОЩАЛЬНЫЙ СЕЗОН", UiTheme.display(), UiTheme.T_HEAD, UiTheme.GOLD)
		ui._box.add_child(fw)
		ui._note("Четыре последних турнира. Призовые ×%s. После них — пенсия: %s станет тренером клуба, а играть будет новый игрок." % [_x(Career.FAREWELL_PRIZE), Career.hero_name()])
		_stays_goes(ui)
	ui._primary("ЕЩЁ ТУРНИР", "start_tournament")
	ui._secondary("В клуб", "menu")


# --- The farewell -----------------------------------------------------------------------

## What stays with the club and what goes with the hero (ACADEMY_LEGACY_TZ 3.5).
static func _stays_goes(ui: TournamentUI) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for col in [["Остаётся", "золото, постройки, шкафчик, острова, титулы клуба, рекорды", UiTheme.WIN],
			["Уходит", "навыки и перки, надетое и сумка (½ цены в банк), кроме одной реликвии", UiTheme.LOSE]]:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, Color(col[2], 0.5), 2, 18, 16))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(v)
		v.add_child(ui._text(col[0], UiTheme.text_bold(), UiTheme.T_BODY, col[2]))
		var d := ui._text(col[1], UiTheme.text(), UiTheme.T_SMALL - 2, UiTheme.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		row.add_child(p)
	ui._box.add_child(row)


## 1. The career in numbers and what stays.
static func show_retire(ui: TournamentUI, _t: Tournament) -> void:
	var c := Career.data()
	ui._open(null)
	ui._title("Конец карьеры")
	ui._sub("%s · %d %s · поколение %d" % [Career.hero_name(), int(c["age"]), _years(int(c["age"])), int(c["gen"])])
	var rec := Career.record()
	var lines := [
		["Турниров", str(int(rec["runs"]))], ["Сезонов", str(int(rec["seasons"]))], ["Титулов", str(int(rec["titles"]))],
		["Лучшее место", Career.rank_text(int(rec["best_rank"])) if int(rec["best_rank"]) < Career.RANK_NONE else "—"],
		["Очков рейтинга", str(int(rec["career_pts"]))], ["Лучший навык", "%s %d" % [Skills.NAMES[rec["best_skill"]], int(rec["levels"][rec["best_skill"]])]],
	]
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 2, UiTheme.RADIUS, 20))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	for ln in lines:
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := ui._left(ui._text(ln[0], UiTheme.text(), UiTheme.T_BODY, UiTheme.MUTED))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(ui._text(ln[1], UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.INK))
		v.add_child(h)
	ui._box.add_child(panel)
	ui._note("%s станет тренером клуба. Играть дальше будет новый игрок." % Career.hero_name())
	_stays_goes(ui)
	ui._primary("ЗАВЕЩАНИЕ: РЕЛИКВИЯ", "career_relic_go")


## 2. One thing stays with the family: the relic rides with the heir's first run.
static func show_relic(ui: TournamentUI, t: Tournament) -> void:
	ui._open(null, true, "career_retire")
	ui._title("Реликвия")
	ui._sub("Одна вещь перейдёт наследнику и приедет с ним на первый турнир")
	var opts := Career.relic_options(t)
	if opts.is_empty():
		ui._note("Вещей нет: надетое ушло с последним турниром, шкафчик пуст")
	var where := {"equip": "Надето", "bag": "В сумке", "locker": "Шкафчик"}
	for i in opts.size():
		var it: Dictionary = opts[i]["item"]
		RunShop.item_card(ui, it, String(where.get(opts[i]["from"], "")), "Оставить наследнику", "career_relic", i)
	ui._note("Остальное надетое и сумка уйдут на прощальном аукционе за ½ цены, шкафчик останется клубу")
	ui._secondary("Без реликвии", "career_relic", -1)


## 3. The heir out of three.
static func show_heirs(ui: TournamentUI, animate := true) -> void:
	ui._open(null, animate, "career_relic_go")
	ui._title("Новый игрок клуба")
	ui._sub("Выбери, за кого играть следующие %d сезонов" % Career.SEASONS)
	var heirs := Career.heir_candidates()
	for i in heirs.size():
		var h: Dictionary = heirs[i]
		var tag := "Воспитанник академии" if String(h["origin"]) == "academy" else ("Свободный агент" if String(h["origin"]) == "free" else String(h["origin"]))
		ui._card({"tag": tag, "title": "%s · %d %s" % [h["name"], Career.START_AGE, _years(Career.START_AGE)],
			"desc": "%s\n%s" % [levels_text(h["levels"]), String(h.get("note", ""))]}, "career_heir", i, UiTheme.GOLD if i == _heir else Color(0, 0, 0, 0), -1, i == _heir)
	if _heir >= 0 and _heir < heirs.size():
		ui._primary("ИГРАТЬ ЗА: %s" % String(heirs[_heir]["name"]).to_upper(), "career_heir_go")
	else:
		ui._note("Тапни по карточке")


## "Под 3 · Фор 2 · Бэк 1 · ..." (zeros left out) + the starting points.
static func levels_text(levels: Dictionary) -> String:
	var parts: Array[String] = []
	var short := {"forehand": "Фор", "backhand": "Бэк", "serve": "Под", "net": "Сет", "touch": "Кас", "feet": "Ноги", "stamina": "Вын"}
	for id in Skills.LIST:
		if int(levels.get(id, 0)) > 0:
			parts.append("%s %d" % [short[id], int(levels[id])])
	parts.append("+%d очка" % Skills.START_POINTS)
	return " · ".join(parts)


## 4. The new player of the club.
static func show_welcome(ui: TournamentUI) -> void:
	var c := Career.data()
	var ret: Array = c["retired"]
	ui._open(null)
	ui._title("Новый сезон")
	ui._sub("%s, %d %s · поколение %d" % [Career.hero_name(), int(c["age"]), _years(int(c["age"])), int(c["gen"])])
	if not ret.is_empty():
		ui._note("Тренер клуба — %s. «Покажи им, %s»." % [String(ret.back()["name"]), Career.hero_name().get_slice(" ", 0)])
	var relic: Dictionary = c["relic"]
	if not relic.is_empty():
		RunShop.item_card(ui, relic, "Реликвия", "Приедет с тобой на первый турнир")
	ui._note("Опыт навыков ×%s  ·  стартовые очки: %d — в Тренерской" % [_x(Career.xp_mult()), Skills.points])
	ui._primary("В КЛУБ", "career_done")
