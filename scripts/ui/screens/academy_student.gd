class_name AcademyStudent
## A student's card (spec 3.3, 3.4, 3.8) on the TournamentUI frame: the name and age, the stars
## of the potential (a range until a match has been watched), six bars of stats, the leanings,
## the traits - the shown ones in full, the hidden ones as «???». For a student of the club
## ("card"): his focus (a row: «Фокус · Подача»), how close the next step is, «Сборы» (a run's
## experience at once, once a season, academy level 2+), «Спарринг» (half a run into the focus,
## once a run) and «Отпустить» (asks first: "release"). For a candidate ("hire", from the
## list; "guest", the visitor): the price and the button that takes him.

const KIND_COLORS := {"stat": Color(0.45, 0.8, 1.0), "growth": Color(0.55, 0.9, 0.5), "style": Color(1.0, 0.75, 0.35), "char": Color(0.85, 0.6, 1.0), "synergy": Color(1.0, 0.85, 0.3)}

static var current := ""     # the student whose card is open (AcademyRoom routes by it)
static var back := "menu"    # where «← Назад» of his card leads: the club, or the office


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


## mode: "card" | "hire" | "guest" | "release". `note`: a line on top (what a camp just gave).
static func show(ui: TournamentUI, st: Dictionary, mode := "card", note := "") -> void:
	if mode == "release":
		_release(ui, st)
		return
	var inf := info(st)
	var to := back if mode == "card" else (AcademyHire.back if mode == "guest" else "club_hire")
	ui._open(null, true, to)
	ui._title(inf["name"])
	var sub := "%d лет  ·  %s" % [inf["age"], inf["stars"]]
	if mode == "card":
		sub += "  ·  рейтинг %d" % int(st.get("rating", 1000))
	ui._sub(sub)
	if note != "":
		var n := ui._text(note, UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.WIN)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(n)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 2, UiTheme.RADIUS, 24))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	for k in Opponents.STAT_KEYS:
		v.add_child(OpponentCard._stat_row(ui, k, int(inf["stats"][k])))
	ui._box.add_child(panel)
	if mode == "card":
		var f := Academy.focus_of(st)
		ui._row("Фокус", "Равномерно" if f == Academy.EVEN else String(Opponents.STAT_NAMES[f]), "club_focus")
		var pl := AcademyRoom.lines(st)
		var prog := String(pl["desc"]).get_slice("\n", 1)
		if prog != "":
			ui._box.add_child(_small(ui, prog))
	var lean := ui._text("Склонности: %s" % ", ".join(inf["leanings"]), UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
	lean.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._box.add_child(lean)
	ui._sub("Черты")
	for id in Traits.all_ids(st):
		if Traits.is_shown(st, id):
			var d := Traits.def(id)
			var l := ui._text("%s  ·  %s" % [Traits.name(id), Traits.desc(id)], UiTheme.text_bold(), UiTheme.T_SMALL + 2, KIND_COLORS.get(d.get("kind", ""), UiTheme.INK))
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
		ui._box.add_child(_small(ui, "Тренировок: %d  ·  матчей: %d  ·  потолок роста: %d" % [int(st.get("trainings", 0)), int(st.get("matches", 0)), int(inf["ceiling"])]))
		_card_buttons(ui, st)
		return
	var why := Academy.why_not(st)
	var price := int(inf["price"])
	var b := ui._primary(("ВЗЯТЬ  ·  БЕСПЛАТНО" if price == 0 else "ВЗЯТЬ  ·  %d ●" % price) if why == "" else why, "club_hire_confirm", 0)
	b.disabled = why != ""


## «Сборы» (the main button when it can go), «Спарринг», «Отпустить».
static func _card_buttons(ui: TournamentUI, st: Dictionary) -> void:
	var camp := Academy.why_not_camp(st)
	if camp == "":
		ui._primary("СБОРЫ  ·  %d ●" % Academy.camp_price(st), "club_camp")
	else:
		ui._box.add_child(_small(ui, camp))
	var spar := Academy.why_not_spar(st)
	var b := ui._secondary(("Спарринг  ·  %d ●" % Academy.spar_price(st)) if spar == "" else spar, "club_spar")
	b.disabled = spar != ""
	ui._row("Отпустить из клуба", "", "club_release_ask")


static func _release(ui: TournamentUI, st: Dictionary) -> void:
	var first := String(st.get("name", "")).get_slice(" ", 0)
	ui._open(null, true, "club_student_back")
	ui._title("Отпустить %s?" % first)
	ui._box.add_child(_small(ui, "Он уедет из клуба насовсем, его место освободится. Золото за него не вернётся."))
	ui._primary("ОТПУСТИТЬ", "club_release")


static func _small(ui: TournamentUI, s: String) -> Label:
	var l := ui._text(s, UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
