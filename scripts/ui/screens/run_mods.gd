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


# --- Entry: the format was chosen -----------------------------------------------------

## The "format" action (and the Club's quick tournament): the conditions screen, or - for
## a player who has not finished a run yet, or with modifiers off - the run right away.
static func open(m: Node, fmt: int) -> void:
	format = fmt
	picked = []
	if not Modifiers.enabled or SaveData.played == 0:
		m._start_tournament(fmt)
		return
	show(m.ui, true)


static func choices() -> Array:
	return Modifiers.pool("run")


static func total() -> float:
	return Modifiers.reward(picked)


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
	ui._sub("До трёх условий на весь забег. Чем неудобнее, тем больше золота и лута; каждое снимается одним касанием")
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
	ui._note("Выбрано %d из %d   ·   награда ×%s   ·   лут +%d%%" % [picked.size(), Modifiers.MAX_RUN, _k(x), roundi(Modifiers.RUN_LOOT * 100.0 * picked.size())])
	ui._primary("НАЧАТЬ ЗАБЕГ" if picked.is_empty() else "НАЧАТЬ ЗАБЕГ  ·  ×%s" % _k(x), "mods_go")


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

## "Условия: Узкий корт, Туман · награда ×1.68" under the bracket's header.
static func bracket_extra(ui: TournamentUI, t: Tournament) -> void:
	if t.run_modifiers.is_empty():
		return
	var names: Array[String] = []
	for id in t.run_modifiers:
		names.append(Modifiers.name(id))
	ui._note("Условия забега: %s   ·   награда ×%s" % [", ".join(names), _k(Modifiers.reward(t.run_modifiers))])


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
		"mods_go":
			m._start_tournament(format, picked.duplicate())
		"mods_back":
			m.ui.show_formats()
