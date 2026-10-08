class_name RunBets
## «Тотализатор» screens (v0.2 A-3): the «Мяч в поле» wheel in the Club and the bet on
## your own match from the bracket. Logic and rules in Bets (honest odds, game gold only,
## a quarter of the gold at most, a break suggested after three losses in a row). Built
## on the TournamentUI frame; actions come back through Main._on_ui -> RunBets.ui_action.

const BETS := ["blue", "red", "net"]
const BET_NAMES := {"blue": "Синее", "red": "Красное", "net": "Сетка"}
const BLUE := Color(0.27, 0.47, 0.86)
const RED := Color(0.86, 0.32, 0.3)
const NET := Color(0.2, 0.55, 0.35)

static var chip := 10             # the chip picked on the desk


# --- Hooks into the Club and the bracket --------------------------------------------

## The Club: the desk opens after the first title (B's bar will host it later: "bets").
static func menu_extra(ui: TournamentUI) -> void:
	if Bets.unlocked():
		ui._secondary("Тотализатор  ·  рулетка и ставки", "bets")


## The bracket: the bookmaker's line for the coming match, or the bet already placed.
static func bracket_extra(ui: TournamentUI, t: Tournament) -> void:
	if not Bets.unlocked():
		return
	if t.bet.is_empty():
		var mk := Bets.match_market(t)
		ui._row("Букмекер", "%s / %s" % [_x(float(mk["you"])), _x(float(mk["opp"]))], "bet_match")
	else:
		ui._note(bet_line(t.bet))


## "Ставка: 50 на себя ×1.75" / "... против себя ×2.10".
static func bet_line(b: Dictionary) -> String:
	return "Ставка: %d золота %s %s" % [int(b["stake"]), "против себя" if String(b.get("side", "self")) == "against" else "на себя", _x(float(b["odds"]))]


static func _k(x: float) -> String:
	return "%.2f" % x


static func _x(x: float) -> String:
	return "×" + _k(x)


## From the club's bar: the bookmaker's screen for the run in progress (or a word that
## there is no match to bet on yet).
static func club_open(m: Node) -> void:
	_from_club = true
	var t := _run(m)
	if t == null or t.state != Tournament.State.BRACKET:
		m.ui._open(null, true, "bet_back")
		m.ui._title("Букмекер")
		m.ui._note("Ставки принимаются на ближайший матч турнира. Начни турнир или вернись к сетке")
		_history(m.ui)
		return
	show_match_bet(m.ui, t)


static var _from_club := false


## The run to bet in: the saved one in progress, else the one Main holds.
static func _run(m: Node) -> Tournament:
	var t := SaveData.resumable()
	return t if t != null else m.tournament


# --- The chips --------------------------------------------------------------------

static func _chips(ui: TournamentUI, action: String) -> bool:
	var allowed := Bets.chips_for(SaveData.gold)
	if allowed.is_empty():
		ui._note(Bets.need_text(Bets.CHIPS[0]))
		return false
	if not allowed.has(chip):
		chip = allowed.back()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for c in Bets.CHIPS:
		var b := ui._make_button(str(c), action, c, "Primary" if c == chip else "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not allowed.has(c)
		row.add_child(b)
	ui._box.add_child(row)
	return true


# --- The bookmaker: a bet on the coming match -------------------------------------------

static func show_match_bet(ui: TournamentUI, t: Tournament) -> void:
	ui._open(t, true, "bet_back")
	ui._title("Букмекер")
	var mk := Bets.match_market(t)
	ui._sub("%s · %s" % [t.round_name(), t.opponent()["name"]])
	ui._note("Шансы по статам, уровню и форме: ты %d%% · соперник %d%%. Коэффициент = 0,92 / шанс, маржа 8%%" % [roundi(float(mk["p"]) * 100.0), roundi(float(mk["p_opp"]) * 100.0)])
	if not t.bet.is_empty():
		ui._note(bet_line(t.bet))
	elif _chips(ui, "bet_chip"):
		ui._card({"tag": "На себя", "title": "%s  ·  %d → %d" % [_x(float(mk["you"])), chip, roundi(chip * float(mk["you"]))],
			"desc": "Выиграй матч — получишь по коэффициенту"}, "bet_win", chip, UiTheme.GOLD)
		var risk := "Ты ушлый: риска дисквалификации нет" if Bets.is_shady() else \
			"Риск дисквалификации после матча: %d%% при проигрыше, %d%% при победе. Штраф %d%% золота, забег кончается" % [roundi(Bets.DQ_ON_LOSS * 100.0), roundi(Bets.DQ_ON_WIN * 100.0), roundi(Bets.DQ_FINE * 100.0)]
		ui._card({"tag": "Против себя", "title": "%s  ·  %d → %d" % [_x(float(mk["opp"])), chip, roundi(chip * float(mk["opp"]))],
			"desc": "Проиграй матч — получишь по коэффициенту. " + risk}, "bet_against", chip, UiTheme.LOSE)
	ui._note("Только игровое золото. Ставка уходит сразу, выигрыш — после матча. Вайлд-кард ставку не спасает.")
	if Bets.needs_break(SaveData.bets):
		ui._note("Три ставки мимо подряд. Перерыв? Корт ждёт.")
	_history(ui)


## The last bets, newest first: who, which side, how it ended.
static func _history(ui: TournamentUI) -> void:
	var h: Array = SaveData.bets.get("history", [])
	if h.is_empty():
		return
	ui._sub("История ставок")
	var shown := 0
	for i in range(h.size() - 1, -1, -1):
		var e: Dictionary = h[i]
		var res := "дисквалификация" if e.get("dq", false) else ("+%d" % int(e["paid"]) if e.get("won", false) else "мимо")
		var col := UiTheme.WIN if e.get("won", false) else UiTheme.LOSE
		var l := ui._text("%s · %s %s %d · %s" % [e.get("name", ""), "против себя" if e.get("side", "") == "against" else "на себя", _x(float(e.get("odds", 1.0))), int(e.get("stake", 0)), res],
			UiTheme.text_bold(), UiTheme.T_SMALL + 2, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(l)
		shown += 1
		if shown >= 5:
			break
	ui._note("Поставлено %d · выиграно %d" % [int(SaveData.bets.get("placed", 0)), int(SaveData.bets.get("won", 0))])


# --- The wheel --------------------------------------------------------------------

## The desk. spin: {} or the last spin {field, bet, stake, paid} (its ball rolls now).
static func show_wheel(ui: TournamentUI, spin := {}) -> void:
	ui._open(null, spin.is_empty(), "menu")
	ui._title("Тотализатор")
	ui._sub("Мяч в поле: синее и красное ×2, сетка ×35")
	var wheel := Wheel.new()
	wheel.custom_minimum_size = Vector2(0, 400)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui._box.add_child(wheel)
	ui._note("Шансы: синее 18 из 37 · красное 18 из 37 · сетка 1 из 37")
	var result := ui._text("", UiTheme.display(), UiTheme.T_HEAD, UiTheme.INK)
	ui._box.add_child(result)
	var can := _chips(ui, "wheel_chip")
	var buttons: Array[Button] = []
	if can:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		ui._actions.add_child(row)
		for i in BETS.size():
			var b := ui._make_button("%s ×%d" % [BET_NAMES[BETS[i]], Bets.PAYS[BETS[i]]], "spin", i, "")
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_color_override("font_color", [BLUE, RED, NET][i].lightened(0.35))
			row.add_child(b)
			buttons.append(b)
	if Bets.needs_break(SaveData.bets):
		ui._note("Три ставки мимо подряд. Перерыв? Корт ждёт.")
	if spin.is_empty():
		return
	# The ball rolls to the field drawn before; the result shows when it stops.
	for b in buttons:
		b.disabled = true
	ui._set_chip(SaveData.gold - int(spin["paid"]))
	wheel.roll_to(int(spin["field"]), func() -> void:
		var won := int(spin["paid"]) > 0
		result.text = ("+%d золота" % int(spin["paid"])) if won else "Мимо: %s" % BET_NAMES[Bets.color_of(int(spin["field"]))].to_lower()
		result.add_theme_color_override("font_color", UiTheme.WIN if won else UiTheme.LOSE)
		ui._set_chip(SaveData.gold)
		ui.sfx_request.emit("point" if won else "miss", -8.0, 1.0)
		for b in buttons:
			if is_instance_valid(b):
				b.disabled = false)


## Main._on_ui hands the desk's actions here.
static func ui_action(m: Node, action: String, arg: int) -> void:
	var t: Tournament = m.tournament
	match action:
		"bets":
			show_wheel(m.ui)
		"wheel_chip":
			chip = arg
			show_wheel(m.ui)
		"spin":
			var bet: String = BETS[arg]
			if chip > Bets.max_stake(SaveData.gold, Bets.CHIPS[0]):
				show_wheel(m.ui)
				return
			var field := Bets.spin(m.rng)
			var paid := Bets.payout(bet, chip, field)
			SaveData.gold += paid - chip
			Bets.note(SaveData.bets, paid > 0)
			if bet == "net" and paid > 0:
				SaveData.bets["net_hits"] = int(SaveData.bets.get("net_hits", 0)) + 1
			SaveData.save()
			show_wheel(m.ui, {"field": field, "bet": bet, "stake": chip, "paid": paid})
		"bet_match":
			_from_club = false
			show_match_bet(m.ui, _run(m))
		"bet_chip":
			chip = arg
			show_match_bet(m.ui, _run(m))
		"bet_win", "bet_against":
			var rt := _run(m)
			Bets.place_match(rt, arg, "against" if action == "bet_against" else "self")
			show_match_bet(m.ui, rt) if _from_club else m.ui.show_bracket(rt)
		"bet_back":
			if _from_club:
				_from_club = false
				m._on_ui("menu", 0)
			else:
				m.ui.show_bracket(_run(m))


## The wheel: 37 fields around a court-green hub; the ball runs around and slows down
## onto its field.
class Wheel extends Control:
	var _ball := 0.0              # angle of the ball (rad, 0 = top)
	var _spin_tw: Tween

	func roll_to(field: int, done: Callable) -> void:
		var step := TAU / Bets.FIELDS
		var target := field * step
		var from := fmod(_ball, TAU)
		var to := target + TAU * 4.0
		_ball = from
		_spin_tw = create_tween()
		_spin_tw.set_ignore_time_scale(true)
		_spin_tw.tween_method(func(a: float) -> void:
			_ball = a
			queue_redraw(), from, to, 2.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_spin_tw.tween_callback(done)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		var step := TAU / Bets.FIELDS
		for i in Bets.FIELDS:
			var col: Color = {"net": RunBets.NET, "blue": RunBets.BLUE, "red": RunBets.RED}[Bets.color_of(i)]
			var a0 := -PI * 0.5 + (i - 0.5) * step
			var pts := PackedVector2Array([c])
			for k in 5:
				pts.append(c + Vector2.from_angle(a0 + step * k / 4.0) * r)
			draw_colored_polygon(pts, col)
		for i in Bets.FIELDS:
			var a := -PI * 0.5 + (i - 0.5) * step
			draw_line(c + Vector2.from_angle(a) * r * 0.55, c + Vector2.from_angle(a) * r, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(c, r * 0.55, UiTheme.SURFACE)
		draw_arc(c, r, 0, TAU, 96, Color(1, 1, 1, 0.5), 3.0, true)
		# The net field's mark and the hub: a tiny court.
		var hub := Rect2(c - Vector2(r * 0.22, r * 0.34), Vector2(r * 0.44, r * 0.68))
		draw_rect(hub, RunBets.NET)
		draw_rect(hub, Color.WHITE, false, 2.0)
		draw_line(Vector2(hub.position.x, c.y), Vector2(hub.end.x, c.y), Color.WHITE, 3.0)
		# The ball on its field.
		var bp := c + Vector2.from_angle(-PI * 0.5 + _ball) * r * 0.78
		draw_circle(bp + Vector2(3, 4), 13, Color(0, 0, 0, 0.35))
		draw_circle(bp, 13, Color(0.86, 0.95, 0.3))
		draw_arc(bp, 13, 0.4, 2.6, 12, Color.WHITE, 2.0, true)
