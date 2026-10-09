class_name AcademyMatchUi
## The booth's screens (spec 4) on the TournamentUI frame like the club's other screens:
##   booth()   the matches that wait (a card each) and the last results;
##   card()    one match: both players' numbers, what the opponent is like, «СМОТРЕТЬ» / «Итог сразу»;
##   result()  the end: the score, the experience, the rating, the gold, what grew and showed itself.
## Actions come as «club_booth», «club_match_pick» (arg = the card), «club_match_watch»,
## «club_match_total», «club_match_advice»: Club.ui_action hands them to ui_action().

static var picked := ""         # the match whose card is open
static var back := "menu"       # where «назад» of the booth leads ("club_students": from the coach's office)


## The match as data (the tests read it): the lines a card shows.
static func info(m: Dictionary) -> Dictionary:
	var st := Academy.student(String(m["sid"]))
	var opp := JuniorMatch.opponent_of(m)
	var ps: Dictionary = Opponents.play_style(opp)
	var caps := Opponents.captions(Opponents.stats(opp))
	return {
		"name": String(st.get("name", "")), "first_name": String(st.get("name", "")).get_slice(" ", 0),
		"rating": int(st.get("rating", 1000)), "opp": String(opp["name"]), "opp_rating": JuniorMatch.opponent_rating(opp),
		"style": String(ps["name"]), "captions": caps, "stats_a": JuniorGen.stats_line(st), "stats_b": JuniorGen.stats_line({"stats": Opponents.stats(opp)}),
	}


static func booth(ui: TournamentUI) -> void:
	JuniorMatch.sync()
	ui._open(null, true, back)
	ui._title("Будка тренера")
	ui._sub("Тай-брейк до 7 после каждого забега. Матч ждёт тебя здесь и не сгорает до следующего забега")
	var q := JuniorMatch.queue()
	if Academy.students().is_empty():
		ui._note("Пока нет учеников. Первого приводит тренер после первого забега.")
	elif q.is_empty():
		ui._note("Все матчи сыграны. Следующий — после твоего забега.")
	for i in q.size():
		var m: Dictionary = q[i]
		var inf := info(m)
		ui._card({"tag": "Ждёт в будке", "title": "%s  ·  %d" % [inf["name"], inf["rating"]], "desc": "против %s  ·  %s" % [inf["opp"], inf["style"]]}, "club_match_pick", i, UiTheme.GOLD)
	if not Academy.students().is_empty():
		var bonus := JuniorMatch.gold_bonus_pct()
		var rl := ui._text("Рейтинг академии: %d  (три лучших ученика)%s" % [JuniorMatch.academy_rating(), ("  ·  +%d%% золота за победы" % bonus) if bonus > 0 else ""], UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.GOLD)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(rl)
	var log_: Array = JuniorMatch.data()["log"]
	if not log_.is_empty():
		ui._sub("Последние матчи")
		for k in range(log_.size() - 1, maxi(log_.size() - 4, -1), -1):
			var r: Dictionary = log_[k]
			var l := ui._text("%s %s  %s  ·  рейтинг %+d%s" % [r["first_name"], r["score"], "победа" if r["won"] else "поражение", int(r["delta"]), ("  ·  +%d ●" % int(r["gold"])) if int(r["gold"]) > 0 else ""],
				UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.WIN if r["won"] else UiTheme.MUTED)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ui._box.add_child(l)


static func card(ui: TournamentUI, m: Dictionary) -> void:
	picked = String(m["id"])
	var inf := info(m)
	ui._open(null, true, "club_match_list")
	ui._title("%s  против  %s" % [inf["first_name"], inf["opp"]])
	ui._sub("Тай-брейк до 7  ·  рейтинг %d  против  %d" % [inf["rating"], inf["opp_rating"]])
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 2, UiTheme.RADIUS, 22))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	for pair in [[inf["first_name"], inf["stats_a"]], [inf["opp"], inf["stats_b"]]]:
		v.add_child(ui._text(String(pair[0]), UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD))
		var l := ui._text(String(pair[1]), UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	ui._box.add_child(panel)
	var line := "Стиль соперника: %s" % inf["style"]
	if not (inf["captions"] as Array).is_empty():
		line += "  ·  " + ", ".join(inf["captions"]).to_lower()
	var t := ui._text(line, UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._box.add_child(t)
	var n := ui._text("В паузах тренер спросит, что делать: четыре установки, одна действует четыре очка. Подходящая против этого соперника поднимает долю очков, неподходящая — снижает.", UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._box.add_child(n)
	ui._primary("СМОТРЕТЬ", "club_match_watch")
	ui._secondary("Итог сразу", "club_match_total")
	ui._quiet("Советы в паузах: %s" % ("да" if JuniorMatch.advice_on() else "нет, решает тренер"), "club_match_advice")


static func result(ui: TournamentUI, res: Dictionary) -> void:
	ui._open(null, true, "")
	ui._title(("Победа  %s" if res["won"] else "Поражение  %s") % res["score"], UiTheme.WIN if res["won"] else UiTheme.LOSE)
	ui._sub("%s против %s" % [res["name"], res["opp"]])
	var lines: Array[String] = []
	lines.append("%s +%d опыта%s" % [Opponents.STAT_NAMES.get(res["focus"], res["focus"]), roundi(float(res["xp"])), "  (×1,5 за просмотр)" if res["watched"] else ""])
	if String(res["bonus_stat"]) != "":
		lines.append("Установка совпала со склонностью: %s +%d" % [Opponents.STAT_NAMES.get(res["bonus_stat"], res["bonus_stat"]), roundi(JuniorMatch.STANCE_BONUS_XP)])
	for g in res["grew"]:
		lines.append("▸ %s вырос до %d" % [Opponents.STAT_NAMES.get(g["stat"], g["stat"]), int(g["to"])])
	lines.append("Рейтинг %d → %d  (%+d)" % [res["rating_before"], res["rating_after"], res["delta"]])
	if int(res["gold"]) > 0:
		lines.append("Призовые академии: +%d ●" % int(res["gold"]))
	for id in res["revealed"]:
		lines.append("Проявилась черта: %s" % String(Traits.def(id).get("name", id)))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 2, UiTheme.RADIUS, 24))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	for l in lines:
		var lb := ui._text(l, UiTheme.text_bold(), UiTheme.T_BODY - 2, UiTheme.INK)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lb)
	ui._box.add_child(panel)
	ui._primary("В КЛУБ", "menu")


## The club's actions of the booth (Club.ui_action hands them here).
static func ui_action(main: Node, action: String, arg: int) -> void:
	match action:
		"club_booth", "club_match_office":
			back = "club_students" if action == "club_match_office" else "menu"
			booth(main.ui)
		"club_match_list":
			booth(main.ui)
		"club_match_pick":
			var q := JuniorMatch.queue()
			if arg >= 0 and arg < q.size():
				card(main.ui, q[arg])
		"club_match_advice":
			JuniorMatch.set_advice(not JuniorMatch.advice_on())
			var m := JuniorMatch.find(picked)
			if not m.is_empty():
				card(main.ui, m)
		"club_match_watch":
			var m := JuniorMatch.find(picked)
			if not m.is_empty():
				watcher(main).start(m)
		"club_match_total":
			var m := JuniorMatch.find(picked)
			if not m.is_empty():
				var res := JuniorMatch.play_out(m, "sim")
				if not res.is_empty():
					result(main.ui, res)


## The one JuniorWatch of the game (made on the first match).
static func watcher(main: Node) -> JuniorWatch:
	var w := main.get_node_or_null("JuniorWatch") as JuniorWatch
	if w == null:
		w = JuniorWatch.new()
		w.name = "JuniorWatch"
		main.add_child(w)
		w.setup(main)
	return w
