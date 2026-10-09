class_name AcademyHire
## «Новый ученик» (spec 3.8): three or four candidates as cards - the stars, the price, the
## six stats in a line, the shown traits and a «???» for each hidden one. A tap opens the
## candidate's full card with «Взять»; the others leave when one is taken. The first one is
## free (the coach brings him after the first run). A rare talent (academy level 3+) is marked.
## Built on the TournamentUI frame.

static var picked := ""     # the candidate whose card is open
static var back := "menu"   # where «← Назад» leads: the club, or the coach's office ("club_students")


## A candidate's lines for his card in the list (data: tests read them).
static func lines(st: Dictionary) -> Dictionary:
	var parts: Array[String] = []
	for id in Traits.shown(st):
		parts.append(Traits.name(id))
	for i in Traits.hidden_count(st):
		parts.append("???")
	var price := int(st.get("price", 0))
	var tag := "%s  ·  %s" % [JuniorGen.stars_text(st), "бесплатно" if price == 0 else "%d ●" % price]
	if bool(st.get("rare", false)):
		tag = "РЕДКИЙ ТАЛАНТ  ·  " + tag
	return {
		"tag": tag,
		"title": "%s  ·  %d" % [st["name"], int(st.get("age", 15))],
		"desc": "%s\n%s" % [JuniorGen.stats_line(st), "Черты: " + ("  ·  ".join(parts) if not parts.is_empty() else "нет")],
	}


static func show(ui: TournamentUI) -> void:
	var list := Academy.candidates()
	ui._open(null, true, back)
	ui._title("Новый ученик")
	if Academy.free_ready():
		ui._sub("Первый ученик — бесплатно. Выбери одного, остальные уедут")
	else:
		ui._sub("Мест %d из %d. Выбери одного, остальные уедут" % [Academy.students().size(), Academy.capacity()])
	if list.is_empty():
		ui._note("Пока никого. Новые приедут в следующем сезоне.")
		return
	for i in list.size():
		var st: Dictionary = list[i]
		var l := lines(st)
		var affordable := Academy.why_not(st) == ""
		ui._card(l, "club_hire_pick", i, (UiTheme.RARITY[3] if bool(st.get("rare", false)) else UiTheme.GOLD) if affordable else UiTheme.MUTED)
	if Academy.level() >= Academy.SCOUT_HINT_FROM and not Academy.free_ready():
		var l := ui._text("Скаут академии подсказал по одной скрытой черте", UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(l)
	if not Academy.free_ready():
		var b := ui._secondary("Обновить набор  ·  %d ●" % Academy.reroll_cost(), "club_hire_reroll")
		b.disabled = SaveData.gold < Academy.reroll_cost()
