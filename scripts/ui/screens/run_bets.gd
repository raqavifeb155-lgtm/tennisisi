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


## The bracket: a bet on the coming match, or the bet already placed.
static func bracket_extra(ui: TournamentUI, t: Tournament) -> void:
	if not Bets.unlocked():
		return
	if t.bet.is_empty():
		ui._row("Ставка на себя", "победа ×%s · всухую ×%s" % [_k(Bets.match_odds(t.stage, false)), _k(Bets.match_odds(t.stage, true))], "bet_match")
	else:
		ui._note("Ставка: %d золота на %s ×%s" % [int(t.bet["stake"]), "победу всухую" if t.bet["sweep"] else "победу", _k(float(t.bet["odds"]))])


static func _k(x: float) -> String:
	return str(snappedf(x, 0.01)).trim_suffix(".0")


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


# --- The bet on your own match -------------------------------------------------------

static func show_match_bet(ui: TournamentUI, t: Tournament) -> void:
	ui._open(t, true, "bet_back")
	ui._title("Ставка на себя")
	ui._sub("%s · %s" % [t.round_name(), t.opponent()["name"]])
	if not _chips(ui, "bet_chip"):
		return
	ui._card({"tag": "На победу", "title": "×%s  ·  %d → %d" % [_k(Bets.match_odds(t.stage, false)), chip, roundi(chip * Bets.match_odds(t.stage, false))],
		"desc": "Выиграй матч"}, "bet_win", chip, UiTheme.GOLD)
	ui._card({"tag": "Всухую", "title": "×%s  ·  %d → %d" % [_k(Bets.match_odds(t.stage, true)), chip, roundi(chip * Bets.match_odds(t.stage, true))],
		"desc": "Соперник возьмёт не больше одного гейма" if t.format_info()["games"] > 0 else "Соперник возьмёт не больше двух очков"}, "bet_sweep", chip, UiTheme.GOLD)
	ui._note("Только игровое золото. Ставка уходит сразу, выигрыш — после матча. Вайлд-кард ставку не спасает.")


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
			show_match_bet(m.ui, t)
		"bet_chip":
			chip = arg
			show_match_bet(m.ui, t)
		"bet_win", "bet_sweep":
			Bets.place_match(t, arg, action == "bet_sweep")
			m.ui.show_bracket(t)
		"bet_back":
			m.ui.show_bracket(t)


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
