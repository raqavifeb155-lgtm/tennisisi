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
	var build: String = p.get("build", "")
	if st.get("soon", false):
		ui._note("Скоро.")
	elif ClubBuilds.TABLE.has(build):
		ui._note("Стройка — у прораба на входе в клуб.")
	else:
		ui._note("Построить можно будет в следующем обновлении.")


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


# --- The islands (hub spec 4): stream A's Locations API, read through the script so the
# club works before it exists (then everything is open).

static func _loc_api(method: String) -> bool:
	var scr: GDScript = load("res://scripts/locations.gd")
	for m in scr.get_script_method_list():
		if m["name"] == method:
			return true
	return false


static func loc_unlocked(id: String) -> bool:
	return bool(load("res://scripts/locations.gd").call("unlocked", id)) if _loc_api("unlocked") else true


static func loc_hint(id: String) -> String:
	return String(load("res://scripts/locations.gd").call("unlock_hint", id)) if _loc_api("unlock_hint") else ""


## "Куда едем?": the tournament places, the closed ones with a lock and what opens them.
## A pick is Main's "location" (then the formats, as before). unlocked / hint: for tests.
static func locations(ui: TournamentUI, unlocked := Callable(), hint := Callable()) -> void:
	if not unlocked.is_valid():
		unlocked = loc_unlocked
	if not hint.is_valid():
		hint = loc_hint
	ui._open(null, true, "menu")
	ui._title("Куда едем?")
	ui._sub("Каждый остров сильнее и щедрее предыдущего")
	for i in Locations.LIST.size():
		var l: Dictionary = Locations.LIST[i]
		var id: String = l["id"]
		var tier := ClubQuests.tier_of(id)
		var stars := "★".repeat(tier + 1)
		if unlocked.call(id):
			# _row reports arg 0: point it at this island.
			var b := ui._row("%s  %s" % [l["name"], stars], l["surface_name"], "location")
			for c in b.pressed.get_connections():
				b.pressed.disconnect(c["callable"])
			b.pressed.connect(func() -> void: ui._press(b, "location", i))
		else:
			var h: String = hint.call(id)
			var b := ui._row("✕  %s" % l["name"], h if h != "" else "закрыто", "location")
			b.disabled = true
			b.modulate.a = 0.6
