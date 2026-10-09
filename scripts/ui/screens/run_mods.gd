class_name RunMods
## «Условия забега» (v0.2 G-4, spec hub-economy 11 and 12): after the format the player
## may take 0..3 conditions of their own (Modifiers pool "run"): each makes the run harder
## and pays more (prize x, loot chance +2%), and the preset «Про» takes the two of
## "no difficulty setting" (narrow PERFECT window + opponents a tier up, x1.5) at once -
## each of them can be taken off alone. Built on the TournamentUI frame; actions come
## back through Main._on_ui -> RunMods.ui_action. The picks are made in a static list
## until the run starts: Main._start_tournament(format, picks) hands them to
## Modifiers.set_run before the bracket is drawn.

const GROUPS := [["run", "Ты"], ["opponent", "Соперники"], ["court", "Корт и мяч"]]

static var picked: Array = []
static var format := 1
static var hardcore := false      # G-6: the mode card picked (after the first title)
static var from_club := false  # opened by the club's «Условия» link: «Назад» returns to the club
static var freq := 0           # hub-economy 14: the rate of the opponents' modifiers (Modifiers.FREQS)


# --- Entry: the format was chosen -----------------------------------------------------

## The "format" action (and the Club's quick tournament): the conditions screen, or - for
## a player who has not finished a run yet, or with modifiers off - the run right away.
static func open(m: Node, fmt: int, club := false) -> void:
	format = fmt
	picked = []
	hardcore = false
	from_club = club
	freq = Modifiers.start_freq(-1)  # the rate picked last time
	if not Modifiers.enabled or SaveData.played == 0:
		m._start_tournament(fmt)
		return
	show(m.ui, true)


## Hardcore opens with the first title (like the betting desk).
static func hard_open() -> bool:
	return SaveData.titles >= 1


## What the screen offers: this run's rotation of the run pool (hub-economy 14, seeded by the
## run's number), in the catalog's order; in hardcore without what it already contains.
static func choices() -> Array:
	var rot := Modifiers.rotation(SaveData.played + 1, hardcore)
	return Modifiers.pool("run").filter(func(e): return rot.has(e["id"]))


static func total() -> float:
	return Modifiers.total((["hardcore"] if hardcore else []) + picked, freq)


static func preset() -> Dictionary:
	return Modifiers.PRESETS[0]


static func preset_on() -> bool:
	for id in preset()["mods"]:
		if not picked.has(id):
			return false
	return true


# --- The screen ---------------------------------------------------------------------

static func show(ui: TournamentUI, animate := true) -> void:
	ui._open(null, animate, "mods_back")
	ui._title("Условия забега")
	_modes(ui)
	ui._sub("До трёх условий на весь забег. Чем неудобнее, тем больше золота и лута; каждое снимается одним касанием")
	_freq_row(ui)
	if not hardcore:
		_preset_row(ui)
	var list := choices()
	for g in GROUPS:
		var head := true
		for i in list.size():
			var e: Dictionary = list[i]
			if String(e["target"]) != g[0]:
				continue
			if head:
				var h := ui._note(g[1].to_upper())
				h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				h.add_theme_color_override("font_color", UiTheme.GOLD)
				head = false
			ui._box.add_child(_row(ui, e, i))
	var x := total()
	var chosen := (["hardcore"] if hardcore else []) + picked
	var capped := Modifiers.total_raw(chosen, freq) > x + 0.005
	ui._note("Выбрано %d из %d   ·   награда ×%s%s   ·   лут +%d%%" % [picked.size(), Modifiers.MAX_RUN, _k(x), " (потолок)" if capped else "", roundi(Modifiers.RUN_LOOT * 100.0 * picked.size())])
	ui._primary(("НАЧАТЬ ХАРДКОР  ·  ×%s" % _k(x)) if hardcore else ("НАЧАТЬ ЗАБЕГ" if x < 1.001 else "НАЧАТЬ ЗАБЕГ  ·  ×%s" % _k(x)), "mods_go")


## Two big cards on top: «ОБЫЧНЫЙ» (all the conditions below) and «ХАРДКОР» (a fixed hard set).
static func _modes(ui: TournamentUI) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var opened := hard_open()
	var defs := [
		{"title": "ОБЫЧНЫЙ", "tag": "как всегда", "desc": "Любые условия ниже", "accent": UiTheme.GOLD, "on": not hardcore, "arg": 0, "action": "mods_mode"},
		{"title": "ХАРДКОР", "tag": "золото ×%s" % _k(float(Modifiers.find("hardcore")["reward"])) if opened else "закрыто",
			"desc": "Без помощи в беге, замедления и прицела; кольцо уже; соперники сильнее" if opened else "Нужен первый титул",
			"accent": Color(0.9, 0.25, 0.25), "on": hardcore, "arg": 1, "action": "mods_mode" if opened else ""},
	]
	for d in defs:
		var c := GameCard.new()
		c.tag = d["tag"]
		c.title = d["title"]
		c.desc = d["desc"]
		c.accent = d["accent"]
		c.selected = d["on"]
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size = Vector2(0, 250)
		if d["action"] == "":
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.modulate = Color(1, 1, 1, 0.5)
		else:
			var act: String = d["action"]
			var arg: int = d["arg"]
			c.pressed.connect(func() -> void: ui._press(c, act, arg, true))
		row.add_child(c)
	ui._box.add_child(row)


## «Модификаторы соперников: Редко / Обычно / Часто» (hub-economy 14): three plates in a row,
## the picked one with the gold frame; under them what the picked one means.
static func _freq_row(ui: TournamentUI) -> void:
	var h := ui._note("МОДИФИКАТОРЫ СОПЕРНИКОВ")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h.add_theme_color_override("font_color", UiTheme.GOLD)
	var row := HBoxContainer.new()
	row.name = "FreqRow"
	row.add_theme_constant_override("separation", 12)
	for f in Modifiers.FREQS.size():
		var fr: Dictionary = Modifiers.FREQS[f]
		var b := _plate(ui, "mods_freq", f, f == freq, UiTheme.GOLD)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := b.get_child(0) as HBoxContainer
		v.offset_left = 10
		v.offset_right = -10
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 8)
		v.add_child(_label(String(fr["name"]), UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD if f == freq else UiTheme.INK))
		v.add_child(_label("×%s" % _k(float(fr["reward"])), UiTheme.display(), UiTheme.T_BODY, UiTheme.GOLD if f == freq else UiTheme.MUTED))
		row.add_child(b)
	ui._box.add_child(row)
	var d := ui._note(String(Modifiers.FREQS[freq]["desc"]))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## The rate's three buttons on screen (tests, the overlay probe).
static func freq_buttons(ui: TournamentUI) -> Array:
	var row := ui._box.find_child("FreqRow", false, false)
	return [] if row == null else row.get_children()


static func _preset_row(ui: TournamentUI) -> void:
	var p := preset()
	var on := preset_on()
	var names: Array[String] = []
	for id in p["mods"]:
		names.append(Modifiers.name(id))
	var b := _plate(ui, "mods_preset", 0, on, UiTheme.GOLD)
	var v := b.get_child(0) as HBoxContainer
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 2)
	left.add_child(_label(("Снять «%s»" if on else "Пресет «%s»") % p["name"], UiTheme.display(), UiTheme.T_HEAD - 4, UiTheme.INK))
	left.add_child(_label(", ".join(names), UiTheme.text(), UiTheme.T_SMALL, UiTheme.MUTED, true))
	v.add_child(left)
	v.add_child(_label("×%s" % _k(Modifiers.reward(p["mods"])), UiTheme.display(), UiTheme.T_HEAD, UiTheme.GOLD))
	ui._box.add_child(b)


static func _row(ui: TournamentUI, e: Dictionary, index: int) -> Button:
	var on := picked.has(e["id"])
	var full := picked.size() >= Modifiers.MAX_RUN and not on
	var rc: Color = Modifiers.rarity_color(int(e["rarity"]))
	var b := _plate(ui, "mods_toggle", index, on, rc)
	b.disabled = full
	if full:
		b.modulate = Color(1, 1, 1, 0.45)
	var h := b.get_child(0) as HBoxContainer
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 2)
	var n := _label(("✓  " if on else "") + String(e["name"]), UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD if on else UiTheme.INK)
	left.add_child(n)
	left.add_child(_label("%s  ·  %s" % [Modifiers.RARITY_NAMES[int(e["rarity"])], e["desc"]], UiTheme.text(), UiTheme.T_SMALL - 2, UiTheme.MUTED, true))
	h.add_child(left)
	h.add_child(_label("×%s" % _k(float(e["reward"])), UiTheme.display(), UiTheme.T_HEAD - 6, rc.lightened(0.25)))
	return b


## A tappable plate: its first child is the HBox to fill.
static func _plate(ui: TournamentUI, action: String, arg: int, on: bool, accent: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 112)
	var bg := Color(accent, 0.14) if on else UiTheme.SURFACE
	var line := UiTheme.GOLD if on else Color(accent, 0.55)
	for s in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(s, UiTheme.box(bg, line, 4 if on else 2, UiTheme.RADIUS, 16))
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.SURFACE_HI, line, 4, UiTheme.RADIUS, 16))
	b.pressed.connect(func() -> void: ui._press(b, action, arg))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.offset_right = -22
	h.offset_top = 10
	h.offset_bottom = -10
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	return b


static func _label(s: String, f: Font, fs: int, c: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
	return l


static func _k(x: float) -> String:
	return str(snappedf(x, 0.01)).trim_suffix(".0")


# --- The bracket's line ---------------------------------------------------------------

## «ХАРДКОР» under the title of the bracket, a result and the summary; at: its place in the box.
static func badge(ui: TournamentUI, t: Tournament, at := -1) -> void:
	if t == null or not t.hardcore:
		return
	var l := ui._text("ХАРДКОР   ·   золото ×%s" % _k(Modifiers.run_mult(t)), UiTheme.display(), UiTheme.T_BODY, Color(1.0, 0.35, 0.3))
	ui._box.add_child(l)
	if at >= 0:
		ui._box.move_child(l, mini(at, ui._box.get_child_count() - 1))


## "Условия: Узкий корт, Туман · награда ×1.68" under the bracket's header.
static func bracket_extra(ui: TournamentUI, t: Tournament) -> void:
	var shown: Array = t.run_modifiers.filter(func(id): return id != "hardcore")
	var line := Modifiers.freq_line(t)  # hub-economy 14: the rate, always once the player has finished a run
	if not shown.is_empty():
		var names: Array[String] = []
		for id in shown:
			names.append(Modifiers.name(id))
		line = "Условия забега: %s   ·   %s   ·   награда ×%s" % [", ".join(names), line.replace("Модификаторы соперников", "модификаторы"), _k(Modifiers.run_mult(t))]
	elif t.freq == 0 and SaveData.played == 0:
		return  # a new player's first run: nothing was chosen, nothing to say
	ui._note(line)


# --- Actions --------------------------------------------------------------------------

static func ui_action(m: Node, action: String, arg: int) -> void:
	match action:
		"mods_toggle":
			var id: String = choices()[arg]["id"]
			if picked.has(id):
				picked.erase(id)
			elif picked.size() < Modifiers.MAX_RUN:
				picked.append(id)
			show(m.ui, false)
		"mods_preset":
			if preset_on():
				for id in preset()["mods"]:
					picked.erase(id)
			else:
				for id in preset()["mods"]:
					if not picked.has(id) and picked.size() < Modifiers.MAX_RUN:
						picked.append(id)
			show(m.ui, false)
		"mods_freq":
			freq = clampi(arg, 0, Modifiers.FREQS.size() - 1)
			show(m.ui, false)
		"mods_mode":
			hardcore = arg == 1 and hard_open()
			var keep := picked.filter(func(id): return not hardcore or not Modifiers.HARD_HAS.has(id))
			picked = keep
			show(m.ui, false)
		"mods_go":
			SaveData.mods_freq = freq  # the next run's screen opens on it (saved with the run's start)
			m._start_tournament(format, picked.duplicate(), hardcore, freq)
		"mods_back":
			if from_club:
				m._open_menu()  # back to the club, where the link was
			else:
				m.ui.show_formats()
