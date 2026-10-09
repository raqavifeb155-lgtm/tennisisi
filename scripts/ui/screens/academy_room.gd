class_name AcademyRoom
## «Кабинет тренера» (spec 3, T-3): the sheet of the academy's students - one card each (age,
## stars, focus, the stats, how close the next step is), a free seat with the candidates, the
## building's next level. A tap on a student opens his card (AcademyStudent): the focus, the
## camp, the sparring, letting him go. Built on the TournamentUI frame like the other screens,
## so the academy's house (another stream) can open the same sheet from its office later.
##
## Every «club_*» action of the academy's screens is routed here (route), so Club only hands
## them over: the list, the cards, hiring, focus, camp, sparring, release, the next level.

const FOCUS_KEYS := ["serve", "forehand", "backhand", "net", "speed", "stamina", "even"]


## A student's card in the list (data: tests read it).
static func lines(st: Dictionary) -> Dictionary:
	var f := Academy.focus_of(st)
	var focus := "равномерно" if f == Academy.EVEN else String(Opponents.STAT_NAMES[f]).to_lower()
	var desc := JuniorGen.stats_line(st)
	if f != Academy.EVEN:
		var pr := Academy.progress(st, f)
		if float(pr[1]) > 0.0:
			desc += "\nДо следующего: %s %d → %d · %d%%" % [String(Opponents.STAT_NAMES[f]).to_lower(), int(st["stats"][f]), int(st["stats"][f]) + 1, roundi(100.0 * float(pr[0]) / float(pr[1]))]
		else:
			desc += "\n%s — на потолке (%d)" % [String(Opponents.STAT_NAMES[f]), Academy.ceiling(st)]
	return {
		"tag": "%d лет  ·  %s  ·  фокус: %s" % [Academy.age(st), JuniorGen.stars_text(st), focus],
		"title": String(st.get("name", "")),
		"desc": desc,
	}


static func show(ui: TournamentUI) -> void:
	Academy.sync()
	ui._open(null, true, "menu")
	ui._title("Кабинет тренера")
	var list := Academy.students()
	if Academy.is_built():
		ui._sub("Академия «%s»  ·  мест %d из %d" % [Academy.level_title(), list.size(), Academy.capacity()])
	else:
		ui._sub("Академии пока нет: место для одного ученика, тренируется на главном корте")
	for i in list.size():
		ui._card(lines(list[i]), "club_student", i, UiTheme.GOLD)
	if not Academy.is_full():
		var cands := Academy.candidates()
		if not cands.is_empty():
			var desc := "Первый — бесплатно" if Academy.free_ready() else "Скаут привёз %d %s" % [cands.size(), "кандидата" if cands.size() < 5 else "кандидатов"]
			ui._card({"tag": "Свободное место", "title": "Новый ученик", "desc": desc}, "club_hire_office", 0, UiTheme.WIN)
		elif list.is_empty():
			ui._note("Первого ученика тренер приведёт после первого забега")
		else:
			var left := Academy.SEASON - SaveData.played % Academy.SEASON
			ui._note("Свободное место. Новые кандидаты — в следующем сезоне (через %d %s)" % [left, ClubBuilds.runs_word(left)])
	if not list.is_empty():
		var waiting := JuniorMatch.queue().size()
		ui._secondary("Матчи в будке  ·  ждут %d" % waiting if waiting > 0 else "Матчи в будке", "club_match_office")
	# What the academy gives, and its next level.
	var info := "Потолок роста %d  ·  опыт за забег ×%s" % [int(Academy._at(Academy.CEILING)), str(snappedf(float(Academy._at(Academy.XP_MULT)), 0.1))]
	ui._box.add_child(_small(ui, info))
	if Academy.is_built():
		var nx := Academy.next_level()
		if not nx.is_empty():
			ui._box.add_child(_small(ui, "Следующий уровень «%s»: %s" % [nx["title"], nx["perk"]]))
			var why := Academy.why_not_upgrade()
			var b := ui._secondary(("Улучшить академию  ·  %d ●" % Academy.next_price()) if why == "" else why, "club_academy_up")
			b.disabled = why != ""
	elif ClubLots.type_open("academy"):
		ui._box.add_child(_small(ui, "Построй академию на свободном участке: больше мест, рост выше и быстрее, сборы"))


static func _small(ui: TournamentUI, s: String) -> Label:
	var l := ui._text(s, UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## «Фокус»: where 60% of his experience goes (or evenly).
static func show_focus(ui: TournamentUI, st: Dictionary) -> void:
	ui._open(null, true, "club_student_back")
	ui._title("Фокус")
	ui._sub("%s: 60%% опыта уходит в фокус, остальное — поровну" % String(st.get("name", "")).get_slice(" ", 0))
	var cur := Academy.focus_of(st)
	for i in FOCUS_KEYS.size():
		var k: String = FOCUS_KEYS[i]
		var name := "Равномерно" if k == Academy.EVEN else String(Opponents.STAT_NAMES[k])
		var val := ""
		if k != Academy.EVEN:
			val = "%d" % int(st["stats"][k])
			if (st.get("leanings", []) as Array).has(k):
				val += "  ▲"
		ui._row(("✓  " if k == cur else "") + name, val, "club_focus_set:%d" % i)


# --- Routing -----------------------------------------------------------------------------------

## The academy's actions, from the club's buttons and from these screens. True if it was one.
static func route(club: Node, action: String, arg: int) -> bool:
	var ui: TournamentUI = club.main.ui
	if action.begins_with("club_focus_set:"):
		var k: String = FOCUS_KEYS[clampi(int(action.get_slice(":", 1)), 0, FOCUS_KEYS.size() - 1)]
		Academy.set_focus(AcademyStudent.current, k)
		_card(club)
		return true
	match action:
		"club_students":
			AcademyStudent.back = "club_students"
			show(ui)
		"club_student":
			var list := Academy.students()
			if arg >= 0 and arg < list.size():
				AcademyStudent.current = String(list[arg]["id"])
				AcademyStudent.back = "club_students"
				_card(club)
		"club_student_back":
			_card(club)
		"club_train":   # from a student in the club (ClubNpc): his card, back to the club
			AcademyStudent.back = "menu"
			_card(club)
		"club_focus":
			var st := Academy.student(AcademyStudent.current)
			if not st.is_empty():
				show_focus(ui, st)
		"club_camp":
			var grew := Academy.camp(AcademyStudent.current)
			club.hud.set_gold(SaveData.gold)
			_card(club, "Сборы прошли" + (": " + Academy.news_text(grew) if not grew.is_empty() else ". Опыт записан"))
		"club_spar":
			var grew := Academy.spar(AcademyStudent.current)
			club.hud.set_gold(SaveData.gold)
			_card(club, "Спарринг сыгран" + (": " + Academy.news_text(grew) if not grew.is_empty() else ". Опыт записан"))
		"club_release_ask":
			var st := Academy.student(AcademyStudent.current)
			if not st.is_empty():
				AcademyStudent.show(ui, st, "release")
		"club_release":
			var st := Academy.student(AcademyStudent.current)
			if not st.is_empty():
				Academy.release(AcademyStudent.current)
				AcademyStudent.current = ""
				club._refresh()
				if AcademyStudent.back == "club_students":
					show(ui)
				else:
					club.main._on_ui("menu", 0)
				club.coach.say("%s уехал. Удачи ему" % String(st["name"]).get_slice(" ", 0), true)
		"club_academy_up":
			if Academy.upgrade():
				club.hud.set_gold(SaveData.gold)
				club.main._on_ui("menu", 0)
				club.academy_built()
		"club_hire", "club_hire_office":   # from the coach (back: the club) or from the office
			AcademyHire.back = "club_students" if action == "club_hire_office" else "menu"
			AcademyHire.show(ui)
		"club_hire_pick":
			var list := Academy.candidates()
			if arg >= 0 and arg < list.size():
				AcademyHire.picked = String(list[arg]["id"])
				AcademyStudent.show(ui, list[arg], "hire")
		"club_hire_reroll":
			if Academy.reroll():
				club.hud.set_gold(SaveData.gold)
			AcademyHire.show(ui)
		"club_hire_confirm":
			var st := Academy.hire(AcademyHire.picked)
			if st.is_empty():
				return true
			AcademyHire.picked = ""
			club.hud.set_gold(SaveData.gold)
			if AcademyHire.back == "club_students":
				show(ui)
				club._refresh()
			else:
				club.main._on_ui("menu", 0)   # back to the club, where the new student arrives
				club._refresh()
			club.coach.say("%s теперь в клубе. Растить будем вместе" % String(st["name"]).get_slice(" ", 0), true)
		"club_guest_hire":
			var g := Academy.guest_candidate()
			if not g.is_empty():
				AcademyHire.picked = "guest"
				AcademyHire.back = "menu"
				AcademyStudent.show(ui, g, "guest")
		_:
			if action.begins_with("club_train:"):
				AcademyStudent.current = action.get_slice(":", 1)
				AcademyStudent.back = "menu"
				_card(club)
				return true
			return false
	return true


static func _card(club: Node, note := "") -> void:
	var st := Academy.student(AcademyStudent.current)
	if st.is_empty():
		show(club.main.ui)
		return
	AcademyStudent.show(club.main.ui, st, "card", note)
