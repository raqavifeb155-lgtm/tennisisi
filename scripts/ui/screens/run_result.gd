class_name RunResult
## The roguelike part of the match result (v0.2 A): the style the match earned and the
## best point to watch again and share. TournamentUI.show_result calls extra() once; the
## numbers come from RunHub (Main's child), which saw the match.


static func hub(ui: TournamentUI) -> RunHub:
	var m := ui.get_parent()
	return m.get("run_hub") if m != null else null


## Gold the match's style added to the run (already in Tournament.gold).
static func style_gold(ui: TournamentUI) -> int:
	var h := hub(ui)
	return int(h.last_match.get("gold", 0)) if h != null else 0


## What the win put into the bag (and sold when it was full), the style of the match,
## the replay card, and after a replay "Поделиться".
static func extra(ui: TournamentUI, t: Tournament) -> void:
	if t != null and not t.new_items.is_empty():
		var names: Array[String] = []
		for it in t.new_items:
			names.append(String(it["name"]))
		var l := ui._text("В сумку: " + ", ".join(names), UiTheme.text_bold(), UiTheme.T_SMALL + 2, Gear.color(t.new_items[0]))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(l)
	if t != null and t.auto_sold > 0:
		ui._note("Сумка полна: лишнее продано за %d золота" % t.auto_sold)
	var h := hub(ui)
	if h != null and h.last_match.get("golden", false):
		var gl := ui._text("Золотой пойман!  ·  коллекция %d из %d" % [SaveData.golden.size(), Opponents.ROSTER.size() - 1], UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(gl)
	if h != null and h.last_match.has("bet"):
		var b: Dictionary = h.last_match["bet"]
		var won := int(b["paid"]) > 0
		ui._box.add_child(ui._text("Ставка: +%d золота" % int(b["paid"]) if won else "Ставка %d — мимо" % int(b["stake"]),
			UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.WIN if won else UiTheme.LOSE))
		if bool(b.get("dq", false)):
			var dq := ui._text("Дисквалификация! Ставка против себя: призовых за матч нет, штраф %d золота, забег окончен." % int(b.get("fine", 0)),
				UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.LOSE)
			dq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ui._box.add_child(dq)
			var cl := ui._text("Тренер: «Против себя ставят только те, кто не уважает корт. В клубе такое не прощают.»", UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ui._box.add_child(cl)
	if h == null or int(h.last_match.get("points", 0)) <= 0:
		return
	var best: Dictionary = h.last_match.get("best", {})
	var line := "Стиль: %d очков · лучший ×%s" % [int(h.last_match["points"]), StylePlate._x(float(best.get("mult", 1.0)))]
	var g := int(h.last_match.get("gold", 0))
	if g > 0:
		line += " · +%d золота" % g
	ui._box.add_child(ui._text(line, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD))
	if not h.has_replay():
		return
	var names: Array[String] = []
	for tr in best.get("tricks", []):
		names.append(String(tr["name"]))
	ui._card({"tag": "Повтор", "title": "Лучшее очко  ▶", "desc": "%s  ·  ×%s" % [" · ".join(names), StylePlate._x(float(best["mult"]))]}, "replay", 0, UiTheme.GOLD)
	if h.share_image != null:
		var b := ui._make_button("Поделиться в чат", "share", 0, "")
		b.add_theme_color_override("font_color", UiTheme.GOLD)
		ui._box.add_child(b)


# --- The coach's quests and the islands, where the player is (loop review 10.10) -----------
# The quests used to live only on the club's chalkboard: while playing they were invisible,
# and a finished one was never mentioned on the summary. Now the bracket lists them, a toast
# says when one is done (Main), and the summary says what waits at the coach's.

## The bracket: this run's quests with progress (dealt here at the latest: the first bracket).
static func bracket_quests(ui: TournamentUI, t: Tournament) -> void:
	if t.state == Tournament.State.OVER or t.champion:
		return
	ClubQuests.start_run(str(t.rng.seed), ClubQuests.tier_of(t.location))
	var lines: Array[String] = []
	var any_done := false
	for q in ClubQuests.current():
		if q["claimed"]:
			continue
		var mark := "✓" if q["done"] else "%s/%s" % [ClubQuests._num(q["have"]), ClubQuests._num(q["need"])]
		any_done = any_done or q["done"]
		lines.append("%s  %s  ·  +%d%s" % [mark, q["text"], int(q["gold"]), " и вещь" if q["item"] else ""])
	if lines.is_empty():
		return
	ui._sub("Задания тренера")
	var l := ui._note("\n".join(lines))
	if any_done:
		l.add_theme_color_override("font_color", UiTheme.GOLD)


## The summary: what waits at the coach's (gold is paid there), and what burns.
static func summary_quests(ui: TournamentUI) -> void:
	var left := 0
	for q in ClubQuests.current():
		if not q["done"] and not q["claimed"]:
			left += 1
	var ready := ClubQuests.claimable_count()
	if ready == 0 and left == 0:
		return
	var parts: Array[String] = []
	if ready > 0:
		parts.append("Задания готовы: %d — забери +%d ● у тренера" % [ready, ClubQuests.claimable_gold()])
	if left > 0:
		parts.append("не выполнено %d — сгорят" % left)
	var l := ui._text("  ·  ".join(parts), UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.GOLD if ready > 0 else UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._box.add_child(l)


## The island this title opened (the next one in the order, if it is open now), or "".
static func new_island(t: Tournament) -> String:
	return Locations.opened_by_title(t.location) if t.champion else ""


# --- The run's summary (v0.2 A-2, spec 1 and 9.2) -------------------------------------
# Income by lines with coins, flying into the bank; one item into the locker; the next
# goal. TournamentUI.show_summary hands over to show_summary.

const INCOME_NAMES := {"prize": "Призовые", "chest": "Сундуки", "style": "Стиль", "sell": "Продажа вещей", "quests": "Задания", "bonus": "Бонусы"}
static var _flown: Tournament = null     # the run whose coins already flew into the chip
static var _msg := ""
static var _msg_good := true
static var _replacing := -1              # the candidate waiting for a locker cell to give way


static func _gold_lines(t: Tournament) -> Array:
	var out: Array = []
	var sum := 0
	for k in Tournament.INCOME_KINDS:
		var v := int(t.income.get(k, 0))
		sum += v
		if v != 0:
			out.append([INCOME_NAMES.get(k, k), v])
	if t.gold != sum:  # an older save with no lines for part of the gold
		out.append([INCOME_NAMES["bonus"], t.gold - sum])
	if out.is_empty():
		out.append([INCOME_NAMES["prize"], 0])
	return out


static func show_summary(ui: TournamentUI, t: Tournament) -> void:
	ui._open(t)
	ui._box.add_child(ui._text("ЧЕМПИОН!" if t.champion else "Турнир окончен", UiTheme.display(), UiTheme.T_HERO if t.champion else UiTheme.T_TITLE, UiTheme.GOLD if t.champion else UiTheme.INK))
	ui._sub(t.finish_text())
	var wins := 0
	for r in t.results:
		if r["won"]:
			wins += 1
	ui._note("Побед: %d  ·  матчей: %d" % [wins, t.results.size()])
	if _msg != "":
		ui._box.add_child(ui._text(_msg, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.WIN if _msg_good else UiTheme.LOSE))
		_msg = ""
	var total_label := _income_panel(ui, t)
	summary_quests(ui)
	var news := new_island(t)
	if news != "":
		var nl := ui._text("Открыт остров: %s  ·  %s" % [Locations.find(news)["name"], RunIslands.level_text(news)], UiTheme.display(), UiTheme.T_BODY, UiTheme.GOLD)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(nl)
	var goal := Goals.line()
	if goal != "":
		var gl := ui._text(goal, UiTheme.text_bold(), UiTheme.T_SMALL + 2, UiTheme.GOLD)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(gl)
	_locker_block(ui, t)
	# One tap to the next run in the same place and format (the conditions screen, if any,
	# comes next), the way the club's «Новая игра» goes; a new island is offered first.
	var again_id := news if news != "" else t.location
	var again_i := _island_index(again_id)
	if again_i >= 0:
		ui._primary(("ИДТИ НА ОСТРОВ  ·  " if news != "" else "ЕЩЁ ТУРНИР  ·  ") + String(Locations.LIST[again_i]["name"]).to_upper(), "sum_again", again_i)
	else:
		ui._primary("ЕЩЁ ТУРНИР", "start_tournament")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	ui._actions.add_child(row)
	var pairs := [["В клуб", "menu"], ["Магазин", "sum_shop"]]
	if not ClubBuilds.is_open("shop"):
		pairs = [["В клуб", "menu"], ["Тренерская", "character"]]
	if Locations.best_unlocked() != "park":
		pairs.append(["Острова", "start_tournament"])
	for pair in pairs:
		var b := ui._make_button(pair[0], pair[1], 0, "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	if _flown != t:
		_flown = t
		# The coins fly from the run chip into the bank chip (C-4, TournamentUI.show_summary).


## «Приход»: the run's gold line by line (each appears in turn), then the bank. Returns
## the total's label (the coins fly out of it).
static func _income_panel(ui: TournamentUI, t: Tournament) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 2, UiTheme.RADIUS, 22))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var rows: Array[Control] = []
	for ln in _gold_lines(t):
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := ui._left(ui._text(String(ln[0]), UiTheme.text(), UiTheme.T_BODY, UiTheme.MUTED))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(ui._text("%+d" % int(ln[1]), UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD if int(ln[1]) >= 0 else UiTheme.LOSE))
		v.add_child(h)
		rows.append(h)
	var sep := ColorRect.new()
	sep.color = UiTheme.LINE
	sep.custom_minimum_size = Vector2(0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)
	var tot := HBoxContainer.new()
	tot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tn := ui._left(ui._text("В банк", UiTheme.text_bold(), UiTheme.T_BODY + 2, UiTheme.INK))
	tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tot.add_child(tn)
	var tv := ui._text("+%d" % t.gold, UiTheme.display(), UiTheme.T_HEAD, UiTheme.GOLD)
	tot.add_child(tv)
	v.add_child(tot)
	rows.append(sep)
	rows.append(tot)
	ui._box.add_child(panel)
	if _flown != t:  # the first time: the lines come one after another
		for r in rows:
			r.modulate.a = 0.0
		for i in rows.size():
			var tw := rows[i].create_tween()
			tw.set_ignore_time_scale(true)
			tw.tween_interval(0.35 + 0.28 * i)
			tw.tween_property(rows[i], "modulate:a", 1.0, 0.2)
		var last := rows.size() - 1
		tw_sfx(ui, 0.35 + 0.28 * last)
	return tv


static func tw_sfx(ui: TournamentUI, delay: float) -> void:
	var tw := ui.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: ui.sfx_request.emit("bounce", -12.0, 1.5))


## «Одна вещь в шкафчик»: worn things and the bag as cards; above the ceiling they go
## dark with the reason, a legendary or mythic shows its insurance.
static func _locker_block(ui: TournamentUI, t: Tournament) -> void:
	var cands := Locker.candidates(t)
	if cands.is_empty() and not t.locker_done:
		return
	var round_i := Locker.exit_round(t)
	if t.locker_done:
		_kept_line(ui)
		return
	ui._sub("Одна вещь в шкафчик  ·  потолок: %s" % Locker.cap_text(round_i))
	ui._note("Что не сохранишь — пропадёт с забегом. Ячеек: %d из %d" % [Locker.items().size(), Locker.slots()])
	for i in cands.size():
		var c: Dictionary = cands[i]
		var it: Dictionary = c["item"]
		var why := Locker.check(it, round_i)
		var full := why.begins_with("шкафчик полон")
		var ins := Locker.insurance(it)
		var line := ""
		var ok := why == ""
		if ok:
			line = "В шкафчик" + ("  ·  страховка %d" % ins if ins > 0 else "  ·  бесплатно")
		elif full:
			line = "Шкафчик полон: выбери, что заменить"
		elif why.begins_with("нужно ещё"):
			line = "Страховка %d  ·  %s" % [ins, why]
		else:
			line = RunShop.sentence(why)
		var card := RunShop.item_card(ui, it, "Надето" if c["from"] == "equip" else "В сумке", line, "sum_keep" if ok or full else "", i)
		if not ok and not full:
			card.modulate = Color(0.55, 0.55, 0.6, 0.85)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _kept_line(ui: TournamentUI) -> void:
	ui._note("Вещь в шкафчике. В следующем забеге её можно взять с собой")


## The cells to give way when the locker is full: sells the old one into the bank.
static func _replace_screen(ui: TournamentUI, t: Tournament, cand: int) -> void:
	_replacing = cand
	ui._open(t, true, "to_summary")
	ui._title("Шкафчик полон")
	ui._sub("Какую вещь заменить? Старая продаётся в банк по цене продажи")
	var cands := Locker.candidates(t)
	if cand < 0 or cand >= cands.size():
		return
	var new_item: Dictionary = cands[cand]["item"]
	var ins := Locker.insurance(new_item)
	RunShop.item_card(ui, new_item, "Кладём", "Страховка %d из банка" % ins if ins > 0 else "")
	ui._sub("Заменить")
	var li := Locker.items()
	for i in li.size():
		var gain := Items.sell_price(li[i])
		RunShop.item_card(ui, li[i], "Ячейка %d" % (i + 1), "Продать +%d и положить новую" % gain, "sum_replace", i)


static func _island_index(id: String) -> int:
	for k in Locations.LIST.size():
		if Locations.LIST[k]["id"] == id:
			return k
	return -1


static func ui_action(m: Node, action: String, arg: int) -> void:
	var t: Tournament = m.tournament
	var ui: TournamentUI = m.ui
	if t == null:
		m._on_ui("menu", 0)
		return
	match action:
		"sum_again":
			var id: String = Locations.LIST[arg]["id"]
			if not Locations.unlocked(id):
				return
			m._next_location = id
			m.club.remember(id, t.format)
			RunMods.open(m, t.format)
		"sum_keep":
			var why := Locker.save_from(t, arg)
			if why.begins_with("шкафчик полон"):
				_replace_screen(ui, t, arg)
				return
			if why == "":
				_msg = "В шкафчик: %s" % String(Locker.items().back()["name"])
				_msg_good = true
				SaveData.save()
			else:
				_msg = RunShop.sentence(why)
				_msg_good = false
			ui.show_summary(t)
		"sum_replace":
			var why2 := Locker.save_from(t, _replacing, arg)
			_msg = "Заменено. В шкафчик: %s" % String(Locker.items().back()["name"]) if why2 == "" else why2.capitalize()
			_msg_good = why2 == ""
			if why2 == "":
				SaveData.save()
			ui.show_summary(t)
		"sum_shop":
			RunShop.ui_action(m, "shop_open", 0)
