class_name MatchStats
## The match's numbers on the result screen (HANDOFF 7.3, UI_FLOW_TZ 4.7): you on the left,
## the opponent on the right, the row's name in the middle; the best rally and PERFECT
## under the table. TournamentUI.show_result calls block() once; the numbers are Hud's
## MatchTally, which heard the match through GameEvents.


static func tally(ui: TournamentUI) -> MatchTally:
	var m := ui.get_parent()
	var h = m.get("hud") if m != null else null
	return h.tally if h != null else null


## Adds the table to the screen; false when there is nothing to show (a run continued
## after a reload): the caller keeps its one-line summary.
static func block(ui: TournamentUI, stats: Dictionary, opponent: String) -> bool:
	var t := tally(ui)
	if t == null or not t.has_data():
		return false
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.9), UiTheme.LINE, 2, UiTheme.RADIUS, 18))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	v.add_child(_row(ui, Career.hero_short(), "", opponent.to_upper(), true))
	for r in t.rows():
		v.add_child(_row(ui, r[0], r[1], r[2]))
	ui._box.add_child(panel)
	var foot := "Лучший розыгрыш: %d   ·   PERFECT: %d" % [t.best_rally, int(stats.get("perfect", 0))]
	ui._sub(foot)
	return true


## One line: the left number, the caption, the right number.
static func _row(ui: TournamentUI, caption: String, you: String, them: String, head := false) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := UiTheme.text_bold() if head else UiTheme.display()
	var size := UiTheme.T_SMALL if head else UiTheme.T_BODY
	var left_t := caption if head else you
	var right_t := them
	var mid_t := "" if head else caption
	var a := ui._text(left_t, font, size, UiTheme.GOLD if head else UiTheme.INK)
	a.custom_minimum_size.x = 150
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.clip_text = true
	var mid := ui._text(mid_t, UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := ui._text(right_t, font, size, UiTheme.MUTED if head else UiTheme.INK)
	b.custom_minimum_size.x = 150
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.clip_text = true
	h.add_child(a)
	h.add_child(mid)
	h.add_child(b)
	return h
