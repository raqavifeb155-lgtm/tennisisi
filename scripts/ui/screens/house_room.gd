class_name HouseRoomSheet
## A room of the academy's house, the sheet (AH-1): its five levels with what each puts in the room and what it gives,
## where the room stands now, and the one button - «Улучшить · цена». Built on the TournamentUI frame
## like the other club screens (AcademyRoom); the house's walk and the quiet button by the room open and buy
## through the same actions: route() takes every «club_house_*» one.
##
##   club_house_room:<id>   the sheet          club_house_up:<id>   buy (from the quiet button), no sheet
##   club_house_buy:<id>    buy from the sheet  club_house_back      close the sheet
##   club_house               go in (from the academy's door)       club_house_exit   go out (from the door in the hall)

## The sheet as data (tests read it): the lines the screen shows.
static func info(room: String) -> Dictionary:
	var lv := AcademyHouse.level(room)
	var rows: Array = []
	for i in range(1, HouseRooms.MAX_LEVEL + 1):
		var state := "built" if i <= lv else ("building" if AcademyHouse.is_building(room) and int(AcademyHouse.building()[room].get("level", 0)) == i else "todo")
		rows.append({"level": i, "obj": String(HouseRooms.level(room, i)["obj"]), "fx": HouseRooms.effect_text(room, i), "state": state,
			"price": HouseRooms.price(i), "runs": HouseRooms.runs(i)})
	var why := AcademyHouse.why_not(room)
	return {
		"room": room,
		"name": HouseRooms.name_of(room),
		"effect": String(HouseRooms.ROOMS[room]["effect"]),
		"level": lv,
		"open": AcademyHouse.is_open(room),
		"rows": rows,
		"why": why,
		"price": AcademyHouse.next_price(room),
		"button": ("УЛУЧШИТЬ  ·  %d ●" % AcademyHouse.next_price(room)) if why == "" else why,
	}


static func show(ui: TournamentUI, room: String, note := "") -> void:
	var inf := info(room)
	ui._open(null, true, "club_house_back")
	ui._title(String(inf["name"]))
	var dots := ""
	for i in HouseRooms.MAX_LEVEL:
		dots += "●" if i < int(inf["level"]) else "○"
	ui._sub("%s  ·  %s  ·  академия ур. %d" % [dots, inf["effect"], AcademyHouse.building_level()])
	if note != "":
		var n := ui._text(note, UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.WIN)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(n)
	for r in inf["rows"]:
		ui._box.add_child(_row(ui, r))
	var runs_note := "Уровни 4 и 5 строятся несколько забегов: золото сразу, леса стоят, пока забеги не сыграны"
	var l := ui._text(runs_note, UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._box.add_child(l)
	var b := ui._primary(String(inf["button"]), "club_house_buy:" + room)
	b.disabled = String(inf["why"]) != ""


static func _row(ui: TournamentUI, r: Dictionary) -> Control:
	var built := String(r["state"]) == "built"
	var building := String(r["state"]) == "building"
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := UiTheme.GOLD if built else (Color(UiTheme.GOLD, 0.5) if building else UiTheme.LINE)
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, edge, 2, UiTheme.RADIUS, 16))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var mark := ui._text(str(r["level"]), UiTheme.display(), UiTheme.T_HEAD, UiTheme.GOLD if built else UiTheme.MUTED)
	mark.custom_minimum_size = Vector2(44, 0)
	h.add_child(mark)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := ui._left(ui._text(String(r["obj"]), UiTheme.text_bold(), UiTheme.T_BODY - 2, UiTheme.INK if built or building else UiTheme.MUTED))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var f := ui._left(ui._text(String(r["fx"]), UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED))
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(f)
	var tail := "✓" if built else ("строится" if building else "%d ●" % int(r["price"]))
	var p := ui._text(tail, UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.WIN if built else (UiTheme.GOLD if building else UiTheme.MUTED))
	h.add_child(p)
	return panel


# --- Routing -------------------------------------------------------------------------------------

## The house's actions, from the academy's door, the hall, the rooms and the sheet. True if it was one.
static func route(club: Node, action: String, _arg: int) -> bool:
	if not action.begins_with("club_house"):
		return false
	var house = club.get("house")
	if house == null:
		return true
	var ui: TournamentUI = club.main.ui
	if action == "club_house":
		house.enter()
	elif action == "club_house_exit":
		house.leave()
	elif action == "club_house_back":
		ui.close()
	elif action.begins_with("club_house_room:"):
		show(ui, action.get_slice(":", 1))
	elif action.begins_with("club_house_up:"):
		house.buy(action.get_slice(":", 1))
	elif action.begins_with("club_house_buy:"):
		var room := action.get_slice(":", 1)
		var n: int = house.buy(room)
		show(ui, room, _bought_note(room, n) if n > 0 else "")
	else:
		return false
	return true


## «Двухъярусная кровать, шкаф - готово» / «Леса стоят: ещё 2 забега».
static func _bought_note(room: String, lv: int) -> String:
	if AcademyHouse.is_building(room):
		var left := AcademyHouse.runs_left(room)
		return "Леса стоят: ещё %d %s" % [left, ClubBuilds.runs_word(left)]
	return "Готово: %s" % String(HouseRooms.level(room, lv)["obj"]).to_lower()
