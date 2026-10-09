class_name RunLocker
## The locker room's screen (v0.2 A-2, spec 1): the cells with what is kept in them, what
## the shop sold for the next run, and how the locker works. The club's «Раздевалка» place
## sends `club_locker` here (stream B). Also the locker's piece of the in-run bag: before
## the first match the kept things can be taken into the run.
##
## Actions: club_locker (open), locker_take i (into the run, from the bag screen),
## locker_look (the old look / controls screen).


## Main (via RunShop.route) and the club (club_locker) end up here.
static func ui_action(m: Node, action: String, arg: int) -> void:
	var ui: TournamentUI = m.ui
	match action:
		"club_locker":
			RunShop.picked = -1
			RunShop._from = "locker"
			show_locker(ui)
		"locker_take":
			var t: Tournament = m.tournament
			if t != null:
				t.take_from_locker(arg)
				SaveData.save()
				RunBag.show_bag(ui, t)
		"locker_look":
			m._on_ui("locker", 0)


static func show_locker(ui: TournamentUI) -> void:
	RunShop._from = "locker"
	RunShop.back_to = "menu"
	ui._open(null, true, "menu")
	var li := Locker.items()
	ui.show_stash(RunShop.stash_count())  # v0.2 L-3
	ui._title("Шкафчик")
	ui._sub("Ячеек: %d из %d  ·  одну вещь с каждого забега, потолок редкости зависит от круга" % [li.size(), Locker.slots()])
	RunShop.show_msg(ui)
	var goal := Goals.line()
	if goal != "":
		ui._note(goal)
	for i in Locker.slots():
		if i < li.size():
			RunShop.item_card(ui, li[i], "Ячейка %d" % (i + 1), "Продать +%d" % Items.sell_price(li[i]), "shop_owned", i)
		else:
			ui._card({"tag": "Ячейка %d" % (i + 1), "title": "Пусто", "desc": "На итоге забега положи сюда лучшую вещь.\nВ следующем забеге её можно взять с собой"}, "", 0, UiTheme.MUTED)
	if Locker.slots() < Locker.MAX_SLOTS:
		var n: Dictionary = ClubBuilds.next("locker")
		if not n.is_empty():
			ui._note("Следующая ячейка: «%s», %d — у прораба на входе" % [n["title"], ClubBuilds.next_price("locker")])
	var nx := Locker.next_items()
	if not nx.is_empty():
		ui._sub("Куплено · поедет в следующий турнир")
		for i in nx.size():
			RunShop.item_card(ui, nx[i], "Из магазина", "Продать +%d" % Items.sell_price(nx[i]), "shop_owned", 10 + i)
	var k := Locker.INSURANCE * (1.0 - ClubApi.insurance_discount())
	ui._note("Страховка: легендарную и мифическую кладут за %d%% цены — от %d и от %d золота" % [roundi(k * 100.0), roundi(Items.BUY[3] * Items.PRICE_SCALE * k), roundi(Items.BUY[4] * Items.PRICE_SCALE * k)])
	ui._primary("МАГАЗИН", "club_shop")
	ui._secondary("Внешность и управление", "locker_look")


## The in-run bag's locker part: the kept things, «Взять в забег» until the first match.
static func bag_section(ui: TournamentUI, t: Tournament) -> void:
	var li := Locker.items()
	if li.is_empty():
		return
	var open := t.can_take_locker()
	ui._sub("Шкафчик  ·  %s" % ("можно взять в забег до первого матча" if open else "после первого матча уже нельзя"))
	for i in li.size():
		if open:
			RunShop.item_card(ui, li[i], "Взять в забег", "Под риском: сохранить заново на итоге", "locker_take", i)
		else:
			var c := RunShop.item_card(ui, li[i], "Шкафчик", "")
			c.modulate = Color(1, 1, 1, 0.55)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
