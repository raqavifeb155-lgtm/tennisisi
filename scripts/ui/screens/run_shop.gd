class_name RunShop
## The club's shop screen (v0.2 A-3, spec 2026-10-08-v02-hub-economy 2 and 3): the showcase
## as cards that glow with their rarity, the paid reroll, a two-step purchase (tap a card,
## then «Купить»), the player's things with «Продать» and the «Струны» gamble. The logic is
## Shop / Locker; this is only how it looks. Built on the TournamentUI frame.
##
## Actions (Main._on_ui hands every "shop_*", "locker_*" and "sum_*" to RunShop.route):
##   club_shop    the club's «Магазин» place button (stream B already sends it)
##   shop_pick i  a showcase card is chosen; shop_buy i  paid; shop_reroll
##   shop_owned a  one of the player's things: a = where * 10 + i (0 = locker, 1 = bought)
##   shop_sell a, shop_strings a, shop_strings_go a, shop_back (back to the list we came from)

static var back_to := "menu"        # where «← Назад» of the shop goes: the club ("menu") or the summary
static var msg := ""                # a line shown once on the next screen: what the last tap did
static var msg_good := true
static var picked := -1             # the chosen showcase card
static var _confirm := -1           # an owned thing waiting for the second tap of «Продать»
static var _cur := 0                # the owned thing on screen (see _decode)
static var _from := "shop"          # the list «shop_back» returns to: "shop" or "locker"


## Main._on_ui calls this first: true = the action was ours.
static func route(m: Node, action: String, arg: int) -> bool:
	if action == "club_shop" or action.begins_with("shop_"):
		ui_action(m, action, arg)
		return true
	if action == "club_locker" or action.begins_with("locker_"):
		RunLocker.ui_action(m, action, arg)
		return true
	if action.begins_with("sum_"):
		RunResult.ui_action(m, action, arg)
		return true
	return false


## "выше потолка: до редкой" -> "Выше потолка: до редкой" (capitalize() would shout every word).
static func sentence(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1) if s != "" else s


static func say(text: String, good := true) -> void:
	msg = text
	msg_good = good


static func show_msg(ui: TournamentUI) -> void:
	if msg != "":
		ui._box.add_child(ui._text(msg, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.WIN if msg_good else UiTheme.LOSE))
		msg = ""


static func where_name(where: int) -> String:
	return "items" if where == 0 else "next"


## The shop's and the locker's chip: the things kept in the locker and those riding to the next run.
static func stash_count() -> int:
	return Locker.items().size() + Locker.next_items().size()


static func level_name() -> String:
	var lv := Shop.level()
	return "Ларёк" if lv <= 0 else String(ClubBuilds.TABLE["shop"]["levels"][lv - 1]["title"])


## "Ракетка · Эпическая · ур. 3" for a card's tag.
static func item_tag(item: Dictionary, what := "") -> String:
	var parts: Array[String] = []
	if what != "":
		parts.append(what)
	parts.append(Gear.slot_name(String(item.get("slot", "racket"))))
	parts.append(UiTheme.RARITY_NAMES[clampi(int(item.get("rarity", 0)), 0, 4)])
	if Items.level(item) > 1:
		parts.append("ур. %d" % Items.level(item))
	return "  ·  ".join(parts)


## An item as a card with its price line under the stats.
static func item_card(ui: TournamentUI, item: Dictionary, what: String, extra: String, action := "", arg := 0, selected := false) -> GameCard:
	var desc := Gear.describe(item)
	if extra != "":
		desc += "\n" + extra
	return ui._card({"tag": item_tag(item, what), "title": item["name"], "desc": desc, "item": item}, action, arg, Color(0, 0, 0, 0), int(item["rarity"]), selected)


# --- The showcase -------------------------------------------------------------------

static func show_shop(ui: TournamentUI) -> void:
	ui._open(null, true, back_to)
	ui.show_stash(stash_count())  # v0.2 L-3: a purchase flies into it
	ui._title("Магазин · %s" % level_name())
	var stock := Shop.stock()
	ui._sub("Витрина новая после каждого забега  ·  вещи уровня %d" % Shop.item_level())
	show_msg(ui)
	var goal := Goals.line()
	if goal != "":
		ui._note(goal)
	var picked_card: GameCard = null
	for i in stock.size():
		var it: Dictionary = stock[i]
		if it.is_empty():
			ui._card({"tag": "Продано", "title": "—", "desc": "Место свободно до следующего забега"}, "", 0, UiTheme.MUTED)
			continue
		var price := Items.price(it)
		var left := price - SaveData.gold
		var line := "Цена %d  ·  %s" % [price, "по карману" if left <= 0 else "ещё %d" % left]
		var c := item_card(ui, it, "", line, "shop_pick", i, i == picked)
		if left > 0:
			c.modulate = Color(1, 1, 1, 0.62)
		if i == picked:
			picked_card = c
	_teaser(ui)
	_owned_list(ui, "Твои вещи", "shop_owned")
	if picked >= 0 and picked < stock.size() and not (stock[picked] as Dictionary).is_empty():
		var it2: Dictionary = stock[picked]
		var why := Shop.why_not(picked)
		if why == "":
			var buy := ui._primary("КУПИТЬ ЗА %d" % Items.price(it2), "shop_buy", picked)
			ui.carry(buy, it2, picked_card, stash_count() + 1, "", Items.price(it2))  # v0.2 L-3: the thing flies, the gold counts down
		else:
			var b := ui._primary("НЕЛЬЗЯ: %s" % why.to_upper(), "shop_pick", picked)
			b.disabled = true
	else:
		ui._primary("ГОТОВО", back_to)
	var rp := Shop.reroll_price()
	var rb := ui._secondary("Переброс витрины  %s" % ("бесплатно (%d)" % Shop.free_left() if rp == 0 else str(rp)), "shop_reroll")
	rb.disabled = SaveData.gold < rp
	rb.add_theme_color_override("font_color", UiTheme.GOLD)


## The closed places of the showcase: what the next level of the shop brings.
static func _teaser(ui: TournamentUI) -> void:
	var lv := Shop.level()
	if lv >= ClubBuilds.max_level("shop"):
		return
	var n: Dictionary = ClubBuilds.next("shop")
	var next_rarity := int(n.get("max_rarity", Gear.EPIC if lv == 0 else Gear.LEGENDARY))
	var glow := "фиолетовым" if next_rarity <= Gear.EPIC else "оранжевым"
	var color := UiTheme.rarity_color(clampi(next_rarity, Gear.EPIC, Gear.LEGENDARY))
	ui._card({"tag": "Закрыто  ·  «%s»  ·  %d" % [n["title"], ClubBuilds.next_price("shop")],
		"title": "Что-то светится %s" % glow, "desc": "%s\nСтройка — у прораба на входе" % sentence(String(n.get("now", "")))}, "", 0, color)


## The player's things (the locker and what waits for the next run) as cards to open.
static func _owned_list(ui: TournamentUI, heading: String, action: String) -> void:
	var li := Locker.items()
	var nx := Locker.next_items()
	if li.is_empty() and nx.is_empty():
		return
	ui._sub("%s  ·  шкафчик %d из %d  ·  едут в забег %d" % [heading, li.size(), Locker.slots(), nx.size()])
	for i in li.size():
		item_card(ui, li[i], "Шкафчик", "Продать +%d" % Items.sell_price(li[i]), action, i)
	for i in nx.size():
		item_card(ui, nx[i], "В следующий турнир", "Продать +%d" % Items.sell_price(nx[i]), action, 10 + i)


# --- One of the player's things -----------------------------------------------------

static func _decode(a: int) -> Array:
	return [0 if a < 10 else 1, a % 10]


static func show_owned(ui: TournamentUI, a: int) -> void:
	_cur = a
	var d := _decode(a)
	var where := where_name(d[0])
	var list := Shop.owned(where)
	var i: int = d[1]
	if i >= list.size():
		_back(ui)
		return
	var it: Dictionary = list[i]
	ui._open(null, true, "shop_back")
	ui.show_stash(stash_count())  # v0.2 L-3
	ui._title(Gear.slot_name(String(it["slot"])), UiTheme.rarity_color(int(it["rarity"])))
	ui._sub("В шкафчике" if d[0] == 0 else "Едет в следующий турнир (наденется само)")
	show_msg(ui)
	var card := item_card(ui, it, "", "")
	var p := Items.sell_price(it)
	var sure := _confirm == a
	var label := "Точно продать?  +%d" % p if sure else "Продать  +%d" % p
	var sell := ui._secondary(label, "shop_sell", a)
	sell.add_theme_color_override("font_color", UiTheme.GOLD)
	if sure or int(it["rarity"]) < Gear.EPIC:  # v0.2 L-3: the sale goes through: coins pour into the bank chip
		ui.carry_coins(sell, card, p, SaveData.gold + p, false)
	if Shop.can_restring():
		var sp := Shop.restring_price(it)
		var b := ui._primary("СТРУНЫ  %d" % sp, "shop_strings", a)
		b.disabled = SaveData.gold < sp
	else:
		ui._note("Струны — перебросить статы за четверть цены — открываются с «Лавки».")
		ui._primary("НАЗАД", "shop_back")


static func show_strings(ui: TournamentUI, a: int) -> void:
	var d := _decode(a)
	var list := Shop.owned(where_name(d[0]))
	var i: int = d[1]
	if i >= list.size():
		_back(ui)
		return
	var it: Dictionary = list[i]
	var rc := UiTheme.rarity_color(int(it["rarity"]))
	ui._open(null, true, "shop_owned_back")
	ui._title("Струны", rc)
	ui._sub("Перетянуть = перебросить статы вещи. Эффект, имя, редкость и уровень остаются")
	show_msg(ui)
	item_card(ui, it, "Сейчас", "")
	ui._sub("Что может выпасть  ·  результат не видно, в этом риск")
	var pool := Shop.string_pool(it)
	var lines := "•  " + "\n•  ".join(pool)
	ui._box.add_child(ui._left(ui._text(lines, UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.INK)))
	var sp := Shop.restring_price(it)
	var b := ui._primary("ПЕРЕТЯНУТЬ ЗА %d" % sp, "shop_strings_go", a)
	b.disabled = SaveData.gold < sp
	ui._secondary("Не надо", "shop_owned_back", a)


static func _back(ui: TournamentUI) -> void:
	picked = -1
	if _from == "locker":
		RunLocker.show_locker(ui)
	else:
		show_shop(ui)


## Main._on_ui -> route -> here.
static func ui_action(m: Node, action: String, arg: int) -> void:
	var ui: TournamentUI = m.ui
	match action:
		"club_shop":
			back_to = "menu"
			picked = -1
			_from = "shop"
			show_shop(ui)
		"shop_open":  # from the summary
			back_to = "to_summary"
			picked = -1
			_from = "shop"
			show_shop(ui)
		"shop_pick":
			picked = arg if picked != arg else -1
			show_shop(ui)
		"shop_buy":
			var why := Shop.buy(arg)
			if why == "":
				var bought: Dictionary = Locker.next_items().back()
				say("Куплено: %s. Поедет в следующий турнир" % bought["name"])
				SaveData.save()
			else:
				say(why, false)
			picked = -1
			show_shop(ui)
		"shop_reroll":
			if Shop.reroll():
				say("Витрина обновлена")
				SaveData.save()
			else:
				say("Не хватает золота", false)
			picked = -1
			show_shop(ui)
		"shop_owned":
			_confirm = -1
			show_owned(ui, arg)
		"shop_owned_back":
			show_owned(ui, _cur)
		"shop_sell":
			var d := _decode(arg)
			var list := Shop.owned(where_name(d[0]))
			if d[1] < list.size():
				var it: Dictionary = list[d[1]]
				if int(it["rarity"]) >= Gear.EPIC and _confirm != arg:
					_confirm = arg
					show_owned(ui, arg)
					return
				var p := Shop.sell(where_name(d[0]), d[1])
				SaveData.save()
				say("Продано за %d" % p)
			_confirm = -1
			_back(ui)
		"shop_strings":
			show_strings(ui, arg)
		"shop_strings_go":
			var d2 := _decode(arg)
			var why2 := Shop.restring(where_name(d2[0]), d2[1])
			if why2 == "":
				SaveData.save()
				say("Новые струны натянуты")
			else:
				say(why2, false)
			if why2 != "":
				show_owned(ui, arg)
			else:
				show_strings(ui, arg)
		"shop_back":
			_back(ui)
