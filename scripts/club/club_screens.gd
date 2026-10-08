class_name ClubScreens
## The club's own 2D screens on TournamentUI's frame (its veil, title, rows, cards and
## "← Назад", which comes back to the club where the hero stood: action "menu"). What
## they list comes from the place's data (ClubPlaces.state), so a place's content
## changes there, not here.


## The shop (HANDOFF 9.1): buy, sell, change mods. The trade is stream A's; until it
## exists the rows are shown and marked "скоро".
static func shop(ui: TournamentUI, st: Dictionary) -> void:
	ui._open(null, true, "menu")
	ui._title(st.get("name", "Магазин"))
	ui._sub(st.get("note", ""))
	for o in st.get("offers", []):
		var action: String = o.get("action", "")
		var b := ui._row(o["title"], o["desc"] if action != "" else "скоро", action if action != "" else "club_soon")
		b.disabled = action == ""
	ui._note("Здесь будут вещи между забегами: купить, продать по цене редкости и уровня, сменить моды.")


## A place's card: what is here now and what the next level brings.
static func place(ui: TournamentUI, st: Dictionary) -> void:
	ui._open(null, true, "menu")
	ui._title(st.get("name", ""))
	var p := ClubPlaces.find(st.get("id", ""))
	var levels: Array = p.get("levels", [])
	var lv := int(st.get("level", 0))
	if levels.size() > 1:
		var dots := ""
		for i in levels.size() - 1:
			dots += "●" if i < lv else "○"
		ui._sub("Уровень %d  %s" % [lv, dots])
	ui._card({"tag": "Сейчас", "title": st.get("name", ""), "desc": st.get("note", "")}, "", 0, UiTheme.GOLD)
	if lv + 1 < levels.size():
		ui._card({"tag": "Дальше", "title": "Уровень %d" % (lv + 1), "desc": levels[lv + 1].get("note", "")}, "", 1, UiTheme.MUTED)
	ui._note("Стройка — у прораба на входе в клуб.")


## The coach's board: this run's quests with progress and reward (hub spec 5).
static func quests(ui: TournamentUI) -> void:
	ui._open(null, true, "menu")
	ui._title("Задания тренера")
	ui._sub("Три на турнир. Невыполненные сгорают с забегом")
	var list := ClubQuests.current()
	if list.is_empty():
		ui._note("Начни турнир — тренер даст задания.")
		return
	for q in list:
		if q["claimed"]:
			continue
		var have := ClubQuests._num(q["have"])
		var need := ClubQuests._num(q["need"])
		var reward := "+%d золота%s" % [int(q["gold"]), " и вещь" if q["item"] else ""]
		var tag := "Готово — забери у тренера" if q["done"] else "%s / %s" % [have, need]
		ui._card({"tag": tag, "title": q["text"], "desc": reward}, "", 0, UiTheme.GOLD if q["done"] else UiTheme.MUTED, -1, q["done"])
	var waiting: Array = SaveData.club.get("quest_items", [])
	if not waiting.is_empty():
		ui._note("Вещи за задания ждут шкафчика: %d" % waiting.size())
