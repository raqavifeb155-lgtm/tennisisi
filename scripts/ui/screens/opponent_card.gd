class_name OpponentCard
## The opponent's card before a match (v0.2 D-5, hub-economy spec 10): the name, the style,
## six bars of stats (Подача .. Выносливость), a caption for the weakest and the strongest
## point ("Слабая подача", "Сильный форхенд"), the modifier auras (lineup[i]["mods"]: stream G
## fills them; empty now apart from the old Tournament.MODIFIERS), a hint about his gear,
## the golden mark and the prize. Built on the TournamentUI frame (show_opponent_card, one
## line there); it opens on a tap on an opponent in the bracket and always before "Играть".

const BAR_H := 22.0


## The numbers the card shows, as data (tests read them): stats, captions, mods, prize.
static func info(t: Tournament, i: int) -> Dictionary:
	var o: Dictionary = Opponents.ROSTER[clampi(i, 0, Opponents.ROSTER.size() - 1)]
	var lu: Dictionary = t.lineup[i] if i < t.lineup.size() else {}
	var mods: Array[String] = []
	for m in lu.get("mods", []):
		mods.append(mod_text(String(m)))
	var st := Opponents.stats(o)
	return {
		"name": String(o["name"]),
		"style": String(Opponents.play_style(o)["name"]),
		"stats": st,
		"captions": Opponents.captions(st),
		"mods": mods,
		"golden": bool(lu.get("golden", false)),
		"prize": t.gold_for_win(i),
	}


## A modifier id as a line: "Железный · реже ошибается". Ids this class does not know (the
## catalog of stream G) are shown as they are, so a new aura never breaks the card.
static func mod_text(id: String) -> String:
	if Tournament.MODIFIERS.has(id):
		var m: Dictionary = Tournament.MODIFIERS[id]
		return "%s · %s" % [m["name"], m["desc"]]
	return id


## Just the name, for the bracket's line.
static func mod_name(id: String) -> String:
	return String(Tournament.MODIFIERS[id]["name"]) if Tournament.MODIFIERS.has(id) else id


static func show(ui: TournamentUI, t: Tournament, i: int) -> void:
	var inf := info(t, i)
	var o: Dictionary = Opponents.ROSTER[clampi(i, 0, Opponents.ROSTER.size() - 1)]
	var boss: bool = o.get("boss", false)
	ui._open(t, true, "opp_back")
	ui._title(inf["name"])
	ui._sub("%s  ·  %s" % [Opponents.ROUND_NAMES[i], inf["style"]])
	var st: Dictionary = inf["stats"]
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.GOLD if boss else UiTheme.LINE, 3 if boss else 2, UiTheme.RADIUS, 24))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	for k in Opponents.STAT_KEYS:
		v.add_child(_stat_row(ui, k, int(st[k])))
	ui._box.add_child(panel)
	for c in inf["captions"]:
		var weak: bool = Opponents.WEAK_WORDS.values().has(c)
		ui._box.add_child(ui._text(c, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.LOSE if weak else UiTheme.WIN))
	var lesson := ui._text(String(o.get("lesson", "")), UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED)
	lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._box.add_child(lesson)
	# Auras and gear: what the bracket says in a line, in full here.
	var mods: Array = inf["mods"]
	if not mods.is_empty():
		ui._sub("Модификаторы")
		for m in mods:
			var l := ui._text(m, UiTheme.text_bold(), UiTheme.T_SMALL + 2, Color(1.0, 0.6, 0.35))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ui._box.add_child(l)
	if i < t.lineup.size():
		var hint := VBoxContainer.new()
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		RunBag.opponent_hint(ui, hint, t.lineup[i])
		if hint.get_child_count() > 0:
			ui._box.add_child(hint)
		else:
			hint.free()
	ui._box.add_child(ui._text("За победу: +%d золота" % int(inf["prize"]), UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD))
	if i == t.stage:
		ui._primary("ИГРАТЬ", "play")
	else:
		ui._primary("К СЕТКЕ", "opp_back")


## One stat: the name, a bar of ten ticks, the number. Weak (<= WEAK) red, strong gold-green.
static func _stat_row(ui: TournamentUI, key: String, value: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := ui._left(ui._text(Opponents.STAT_NAMES[key], UiTheme.text(), UiTheme.T_SMALL + 3, UiTheme.INK))
	n.custom_minimum_size = Vector2(212, 0)
	h.add_child(n)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 10.0
	bar.value = float(value)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, BAR_H)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := UiTheme.LOSE if value <= Opponents.WEAK else (UiTheme.WIN if value >= Opponents.STRONG else UiTheme.GOLD)
	bar.add_theme_stylebox_override("fill", UiTheme.box(c, Color(0, 0, 0, 0), 0, 8, 0))
	bar.add_theme_stylebox_override("background", UiTheme.box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 8, 0))
	h.add_child(bar)
	var num := ui._text(str(value), UiTheme.display(), UiTheme.T_BODY + 2, c)
	num.custom_minimum_size = Vector2(44, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(num)
	return h
