class_name AcademyStudent
## A student's card (spec 3.3, 3.8) on the TournamentUI frame: the name and age, the stars of
## the potential (a range until a match has been watched), six bars of stats, the leanings,
## the traits - the shown ones in full, the hidden ones as «???» - and, for a candidate,
## the price and the button that takes him. One screen for the student of the club ("card")
## and for a candidate ("hire", from the list; "guest", the visitor).

const KIND_COLORS := {"stat": Color(0.45, 0.8, 1.0), "growth": Color(0.55, 0.9, 0.5), "style": Color(1.0, 0.75, 0.35), "char": Color(0.85, 0.6, 1.0), "synergy": Color(1.0, 0.85, 0.3)}


## The card as data (the tests read it): the lines the screen shows.
static func info(st: Dictionary) -> Dictionary:
	var shown: Array = []
	for id in Traits.shown(st):
		shown.append(Traits.text(id))
	return {
		"name": String(st.get("name", "")),
		"age": Academy.age(st) if st.has("since") else int(st.get("age", 15)),
		"stars": JuniorGen.stars_text(st),
		"stats": st["stats"],
		"traits": shown,
		"hidden": Traits.hidden_count(st),
		"leanings": (st.get("leanings", []) as Array).map(func(k): return String(Opponents.STAT_NAMES[k])),
		"ceiling": Academy.ceiling(st),
		"price": int(st.get("price", 0)),
	}


## mode: "card" | "hire" | "guest". `back`: the action of «← Назад».
static func show(ui: TournamentUI, st: Dictionary, mode := "card") -> void:
	var inf := info(st)
	var back := "menu" if mode == "card" else ("club_hire" if mode == "hire" else "menu")
	ui._open(null, true, back)
	ui._title(inf["name"])
	var sub := "%d лет  ·  %s" % [inf["age"], inf["stars"]]
	if mode == "card":
		sub += "  ·  рейтинг %d" % int(st.get("rating", 1000))
	ui._sub(sub)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 2, UiTheme.RADIUS, 24))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	for k in Opponents.STAT_KEYS:
		v.add_child(OpponentCard._stat_row(ui, k, int(inf["stats"][k])))
	ui._box.add_child(panel)
	var lean := ui._text("Склонности: %s" % ", ".join(inf["leanings"]), UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
	lean.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._box.add_child(lean)
	ui._sub("Черты")
	for id in Traits.all_ids(st):
		if Traits.is_shown(st, id):
			var d := Traits.def(id)
			var l := ui._text("%s  ·  %s" % [d["name"], d["desc"]], UiTheme.text_bold(), UiTheme.T_SMALL + 2, KIND_COLORS.get(d["kind"], UiTheme.INK))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ui._box.add_child(l)
	var hid := int(inf["hidden"])
	if hid > 0:
		var l := ui._text("???  ·  скрытых: %d. Проявятся в матчах и тренировках" % hid, UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(l)
	elif Traits.all_ids(st).is_empty():
		ui._box.add_child(ui._text("Без особых черт", UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED))
	if mode == "card":
		var note := ui._text("Тренировок: %d  ·  матчей: %d  ·  потолок роста: %d" % [int(st.get("trainings", 0)), int(st.get("matches", 0)), int(inf["ceiling"])], UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(note)
		ui._primary("К ТРЕНЕРУ", "menu")
		return
	var why := Academy.why_not(st)
	var price := int(inf["price"])
	var b := ui._primary(("ВЗЯТЬ  ·  БЕСПЛАТНО" if price == 0 else "ВЗЯТЬ  ·  %d ●" % price) if why == "" else why, "club_hire_confirm", 0)
	b.disabled = why != ""
