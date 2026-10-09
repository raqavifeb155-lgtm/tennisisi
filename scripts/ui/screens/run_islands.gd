class_name RunIslands
## «Куда едем?» (v0.2 A-4, spec 4; one screen with the club's old «Куда едем?», loop review P2): the islands in the order they open, each with its level
## (stronger opponents, richer prizes, better gear); a closed one is dark with a drawn lock
## and what opens it, and can't be pressed. TournamentUI.show_locations hands over here;
## a pick is Main's "location" action with the index in Locations.LIST.

const SURFACE_COLORS := {"hard": Color(0.4, 0.62, 1.0), "clay": Color(0.95, 0.55, 0.3), "grass": Color(0.5, 0.85, 0.4)}


## A padlock, drawn: a body and a shackle (no textures, no emoji font needed).
class Lock extends Control:
	func _draw() -> void:
		var c := Color(UiTheme.MUTED, 0.9)
		draw_arc(Vector2(0, -9), 11.0, PI, TAU, 16, c, 4.0, true)
		draw_line(Vector2(-11, -9), Vector2(-11, 0), c, 4.0, true)
		draw_line(Vector2(11, -9), Vector2(11, 0), c, 4.0, true)
		draw_rect(Rect2(-17, 0, 34, 26), c)
		draw_circle(Vector2(0, 11), 4.0, UiTheme.SURFACE)


static func stars(id: String) -> String:
	return "★".repeat(Locations.tier(id) + 1)


## «Призовые ×1.3 · соперники сильнее · вещи уровня 2».
static func level_text(id: String) -> String:
	var t := Locations.tier(id)
	var s := "Призовые ×%s" % str(snappedf(Locations.prize_mult(id), 0.1))
	if t > 0:
		s += "  ·  соперники сильнее"
	return s + "  ·  вещи уровня %d" % (t + 1)


## The one islands screen (the 2D menu, the result's «Острова» and the club's «Другое место» all
## come here): a card for each island in the order they open, a closed one dark with a drawn
## lock and «за титул в …», its prize multiplier under every name. A pick is Main's "location".
## `unlocked(id) -> bool` and `hint(id) -> String`: for tests, default to Locations.
static func show_locations(ui: TournamentUI, unlocked := Callable(), hint := Callable()) -> void:
	if not unlocked.is_valid():
		unlocked = Locations.unlocked
	if not hint.is_valid():
		hint = Locations.unlock_hint
	ui._open(null, true, "menu")
	ui._title("Куда едем?")
	ui._sub("Каждый остров сильнее и щедрее предыдущего. Новый открывается за титул")
	for id in Locations.ORDER:
		var i := -1
		for k in Locations.LIST.size():
			if Locations.LIST[k]["id"] == id:
				i = k
		var l: Dictionary = Locations.LIST[i]
		var open: bool = unlocked.call(id)
		var color: Color = SURFACE_COLORS.get(l["surface"], UiTheme.LINE)
		var tag := "%s  ·  %s  %s" % [String(l["surface_name"]).capitalize(), "остров %d из %d" % [Locations.tier(id) + 1, Locations.ORDER.size()], stars(id)]
		if open:
			ui._card({"tag": tag, "title": l["name"], "desc": "%s\n%s" % [l["desc"], level_text(id)]}, "location", i, color)
		else:
			var h: String = hint.call(id)
			var c := ui._card({"tag": ("Закрыто  ·  %s" % h) if h != "" else "Закрыто", "title": l["name"], "desc": "%s\n%s" % [l["desc"], level_text(id)]}, "", i, UiTheme.MUTED)
			c.modulate = Color(0.6, 0.6, 0.66, 0.9)
			var lock := Lock.new()
			lock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			lock.position = Vector2(-52, 40)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(lock)
