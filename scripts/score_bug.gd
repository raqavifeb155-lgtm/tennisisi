class_name ScoreBug
extends VBoxContainer
## The match score as a TV broadcast shows it, top left:
##
##   ● ВЫ        6  4 │ 40 │
##     РУБЛЁВ    3  2 │ 15 │
##   [ТАЙ-БРЕЙК] [БРЕЙК-ПОЙНТ]
##
## A ball marks the server. Finished sets are small (the winner's number bright), the
## current set's games stand out, the points sit in a gold cell that pulses when they
## change. In the quick format (tiebreaks only) there are no games: the points are the
## tiebreak points. The status line names the moment: tiebreak, break point, set/match
## point.

const SURFACE := Color(0.06, 0.08, 0.11, 0.92)
const EDGE := Color(1, 1, 1, 0.1)
const INK := Color(0.96, 0.97, 0.98)
const MUTED := Color(1, 1, 1, 0.45)
const GOLD := Color(1.0, 0.85, 0.25)
const GOLD_INK := Color(0.12, 0.1, 0.04)
const BALL := Color(0.86, 0.95, 0.3)
const NAME_W := 150.0
const SET_W := 34.0
const GAMES_W := 44.0
const POINTS_W := 66.0
const ROW_H := 44.0

var _rows: Array[Dictionary] = []   # per side: {serve, name, sets: HBox, games, points, points_bg}
var _status: HBoxContainer
var _last_points := ["", ""]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows)
	for side in 2:
		rows.add_child(_build_row())
	_status = HBoxContainer.new()
	_status.add_theme_constant_override("separation", 6)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)


func _build_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_H
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ball := _ball()
	row.add_child(ball)
	row.add_child(_gap(10))
	var who := _cell("", 24, NAME_W, HORIZONTAL_ALIGNMENT_LEFT, INK)
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(who)
	var sets := HBoxContainer.new()
	sets.add_theme_constant_override("separation", 0)
	sets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sets)
	var games := _cell("", 27, GAMES_W, HORIZONTAL_ALIGNMENT_CENTER, INK)
	row.add_child(games)
	row.add_child(_gap(8))
	var bg := PanelContainer.new()
	bg.custom_minimum_size = Vector2(POINTS_W, ROW_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = GOLD
	# Square inside, rounded where it meets the bug's own corner.
	if _rows.is_empty():
		bsb.corner_radius_top_right = 9
	else:
		bsb.corner_radius_bottom_right = 9
	bg.add_theme_stylebox_override("panel", bsb)
	var points := _cell("", 28, POINTS_W, HORIZONTAL_ALIGNMENT_CENTER, GOLD_INK)
	bg.add_child(points)
	row.add_child(bg)
	_rows.append({"serve": ball, "name": who, "sets": sets, "games": games, "points": points, "points_bg": bg, "style": bsb})
	return row


## Shows a match. Index 0 is the player, 1 the opponent (MatchScore order).
func show_score(s: MatchScore, names: Array) -> void:
	visible = true
	var pts := _points_text(s)
	var tiebreak_only := s.games_per_set == 0
	for side in 2:
		var r: Dictionary = _rows[side]
		(r["name"] as Label).text = String(names[side]).to_upper()
		(r["serve"] as Control).modulate.a = 1.0 if s.server == side and not s.is_over() else 0.0
		var sets: HBoxContainer = r["sets"]
		while sets.get_child_count() < s.set_scores.size():
			sets.add_child(_cell("", 22, SET_W, HORIZONTAL_ALIGNMENT_CENTER, INK))
		while sets.get_child_count() > s.set_scores.size():
			var c := sets.get_child(sets.get_child_count() - 1)
			sets.remove_child(c)
			c.queue_free()
		for i in s.set_scores.size():
			var sc: Array = s.set_scores[i]
			var l := sets.get_child(i) as Label
			l.text = str(sc[side])
			l.add_theme_color_override("font_color", INK if int(sc[side]) > int(sc[1 - side]) else MUTED)
		var games: Label = r["games"]
		games.visible = not tiebreak_only
		games.text = str(s.games[side])
		var p: Label = r["points"]
		if pts[side] != _last_points[side] and _last_points[side] != "":
			_pulse(r["points_bg"])
		p.text = pts[side]
	_last_points = pts.duplicate()
	_show_status(s)


func _points_text(s: MatchScore) -> Array:
	var a: int = s.points[0]
	var b: int = s.points[1]
	if s.is_over():
		return ["", ""]
	if s.in_tiebreak:
		return [str(a), str(b)]
	if a >= 3 and b >= 3:
		if a == b:
			return ["40", "40"]
		return ["AD", "40"] if a > b else ["40", "AD"]
	var names := ["0", "15", "30", "40"]
	return [names[mini(a, 3)], names[mini(b, 3)]]


func _show_status(s: MatchScore) -> void:
	for c in _status.get_children():
		c.queue_free()
	if s.is_over():
		return
	if s.in_tiebreak and s.games_per_set > 0:
		_chip("ТАЙ-БРЕЙК", INK, Color(1, 1, 1, 0.14))
	if s.match_point_for(0):
		_chip("МАТЧБОЛ", GOLD_INK, GOLD)
	elif s.match_point_for(1):
		_chip("МАТЧБОЛ СОПЕРНИКА", INK, Color(0.85, 0.25, 0.22, 0.9))
	elif not s.in_tiebreak:
		var recv := 1 - s.server
		var rp: int = s.points[recv]
		var sp: int = s.points[s.server]
		if rp >= 3 and rp > sp:
			_chip("БРЕЙК-ПОЙНТ", INK, Color(0.85, 0.25, 0.22, 0.9) if recv == 1 else Color(0.2, 0.55, 0.3, 0.95))


func _chip(text: String, ink: Color, bg: Color) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", ink)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	_status.add_child(p)


## The points cell brightens and settles: the score changed, without shouting.
func _pulse(bg: PanelContainer) -> void:
	bg.pivot_offset = bg.size * 0.5
	bg.scale = Vector2(1.12, 1.12)
	bg.modulate = Color(1.25, 1.25, 1.25)
	var tw := bg.create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(bg, "scale", Vector2.ONE, 0.22)
	tw.tween_property(bg, "modulate", Color.WHITE, 0.3)


func _cell(text: String, font: int, w: float, align: HorizontalAlignment, ink: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(w, ROW_H)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", ink)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _gap(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The server's ball: a small round dot.
func _ball() -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(12, 12)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BALL
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	return p
