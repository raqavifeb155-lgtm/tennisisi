class_name RunBag
## The bag (v0.2 A-2, ROGUELIKE_DESIGN 6.1, 9.0): what the player wears in three slots and
## the spare items, as cards with their rarity. A tap opens an item: its card, how it
## compares with what is worn in that slot, "Надеть" and "Продать". Built on the
## TournamentUI frame; actions come back through Main._on_ui -> RunBag.ui_action.
## Also the small pieces other tournament screens need: the bracket's bag row and the
## hint of what an opponent carries, the reward card's tag, a slot-aware item card.

const BAG_ARG := 10               # bag_item arg: 0..2 = a worn slot, 10+ = the bag's i-th

## Stat names for the comparison (Skills mod keys).
const STROKE_NAMES := {"forehand": "форхенд", "backhand": "бэкхенд", "serve": "подача", "net": "у сетки", "touch": "касание"}
const STAT_NAMES := {"pace": "Сила", "window": "Окно PERFECT", "scatter": "Разброс", "spin": "Вращение"}
const OTHER_NAMES := {
	"run_speed": "Скорость бега", "move_penalty": "Штраф за удар на бегу", "stamina_pool": "Запас выносливости",
	"stamina_drain": "Расход выносливости", "stamina_rest": "Отдых между очками",
}
const SHRINK := ["move_penalty", "stamina_drain"]   # and every *_scatter: less is better


static func stat_name(key: String) -> String:
	if OTHER_NAMES.has(key):
		return OTHER_NAMES[key]
	var stroke := key.get_slice("_", 0)
	var stat := key.get_slice("_", 1)
	return "%s: %s" % [STAT_NAMES.get(stat, stat), STROKE_NAMES.get(stroke, stroke)]


static func better_when_lower(key: String) -> bool:
	return key.ends_with("_scatter") or SHRINK.has(key)


## "Сила справа  +8% → +10%  ↑" for every stat either item touches.
static func compare(new_item: Dictionary, worn: Dictionary) -> Array[String]:
	var a: Dictionary = new_item.get("mods", {})
	var b: Dictionary = worn.get("mods", {})
	var keys: Array = a.keys()
	for k in b:
		if not keys.has(k):
			keys.append(k)
	var out: Array[String] = []
	for k in keys:
		var nv := float(a.get(k, 0.0))
		var ov := float(b.get(k, 0.0))
		if is_equal_approx(nv, ov):
			continue
		var up := (nv < ov) if better_when_lower(k) else (nv > ov)
		out.append("%s  %s → %s  %s" % [stat_name(k), _pct(ov), _pct(nv), "↑" if up else "↓"])
	return out


static func _pct(v: float) -> String:
	if is_zero_approx(v):
		return "0"
	return "%+d%%" % roundi(v * 100.0)


## The empty slot's card text: what you play with when nothing is worn there.
static func stock_name(slot: String) -> String:
	return {"racket": "Стандартная ракетка", "shoes": "Свои кроссовки", "band": "Без напульсника"}.get(slot, "—")


## How many things the player has: worn and in the bag (the bag chip's number).
static func carried(t: Tournament) -> int:
	var n := t.bag.size()
	for s in Gear.SLOTS:
		n += 0 if t.equip.get(s, {}).is_empty() else 1
	return n


static func item_card(ui: TournamentUI, item: Dictionary, what: String, slot: String, action := "", arg := 0, thumb := true) -> GameCard:
	if item.is_empty():
		var empty_tag := Gear.slot_name(slot) if what == "" else "%s  ·  %s" % [what, Gear.slot_name(slot)]
		return ui._card({"tag": empty_tag, "title": stock_name(slot), "desc": "без бонусов", "slot": slot if slot != "" else "racket"}, action, arg, Color(0, 0, 0, 0))
	var r := int(item["rarity"])
	var tag := "%s  ·  %s  ·  %s" % [what, Gear.slot_name(String(item["slot"])), UiTheme.RARITY_NAMES[r]] if what != "" \
		else "%s  ·  %s" % [Gear.slot_name(String(item["slot"])), UiTheme.RARITY_NAMES[r]]
	return ui._card({"tag": tag, "title": item["name"], "desc": Gear.describe(item), "item": item if thumb else {}, "uniform": true}, action, arg, Color(0, 0, 0, 0), r)


# --- Hooks into the tournament screens ------------------------------------------

## The bracket's row "Сумка": how much is worn and carried; opens the bag.
static func bracket_extra(ui: TournamentUI, t: Tournament) -> void:
	var worn := 0
	for s in Gear.SLOTS:
		worn += 0 if t.equip.get(s, {}).is_empty() else 1
	ui._row("Сумка", "надето %d из 3 · в сумке %d" % [worn, t.bag.size()], "bag")
	if t.can_take_locker():  # v0.2 A-2: the locker's things can come along until the first match
		if not Locker.items().is_empty() and Locker.take_left(t) > 0:
			ui._row("Шкафчик", "%d · в забег ещё %d" % [Locker.items().size(), Locker.take_left(t)], "bag")
		if not Locker.boarded.is_empty():
			ui._note("С тобой из магазина: %s" % ", ".join(Locker.boarded))


## Under an opponent in the bracket: not what he carries, only a hint — the glow of his
## best epic or legendary item. A mythic looks like nothing here (found out on court).
static func opponent_hint(ui: TournamentUI, box: VBoxContainer, lu: Dictionary) -> void:
	if lu.get("golden", false):
		box.add_child(ui._left(ui._text("ЗОЛОТОЙ  ·  ×2 золота за победу", UiTheme.display(), UiTheme.T_SMALL + 2, UiTheme.GOLD)))
		return
	var best := -1
	for s in lu.get("gear", {}):
		var it: Dictionary = lu["gear"][s]
		if not it.is_empty() and int(it["rarity"]) < Gear.MYTHIC:
			best = maxi(best, int(it["rarity"]))
	if best < Gear.EPIC:
		return
	var word: String = ["", "", "фиолетовым", "оранжевым"][best]
	var l := ui._left(ui._text("Что-то светится %s" % word, UiTheme.text_bold(), UiTheme.T_SMALL, UiTheme.rarity_color(best)))
	box.add_child(l)


## The reward card's tag: the slot, the rarity, where it goes.
static func reward_tag(t: Tournament, item: Dictionary) -> String:
	var slot := String(item.get("slot", "racket"))
	var tag := "%s  ·  %s" % [Gear.slot_name(slot), UiTheme.RARITY_NAMES[int(item["rarity"])]]
	return tag + ("  ·  в сумку" if not t.equip.get(slot, {}).is_empty() else "  ·  наденешь сразу")


# --- The screens ----------------------------------------------------------------

static func show_bag(ui: TournamentUI, t: Tournament) -> void:
	ui._open(t, true, "bag_back")
	ui._title("Сумка")  # no bag chip on this screen: with «Назад», the run's gold and the bank it would not fit 720 px
	RunLocker.bag_section(ui, t)  # v0.2 A-2: the kept things, until the first match
	ui._sub("Надето")
	for i in Gear.SLOTS.size():
		var slot: String = Gear.SLOTS[i]
		item_card(ui, t.equip.get(slot, {}), "", slot, "bag_item", i)
	ui._sub("В сумке  ·  %d из %d" % [t.bag.size(), Tournament.BAG_SIZE])
	if t.bag.is_empty():
		ui._note("Пусто. Вещи падают с побеждённых соперников и приходят в наградах.")
	for i in t.bag.size():
		item_card(ui, t.bag[i], "", "", "bag_item", BAG_ARG + i)
	var extra := t.extra_items()
	if not extra.is_empty():
		var sum := 0
		for it in extra:
			sum += Gear.price(it)
		var b := ui._secondary("Продать всё лишнее (%d)  +%d" % [extra.size(), sum], "sell_extra")
		b.add_theme_color_override("font_color", UiTheme.GOLD)
		ui.carry_coins(b, b, sum, t.gold + sum)  # v0.2 L-3: the coins pour into the run's chip
	ui._primary("К СЕТКЕ", "bag_back")


## One item: its card, the comparison with the slot, put on / sell.
static func show_item(ui: TournamentUI, t: Tournament, arg: int) -> void:
	var in_bag := arg >= BAG_ARG
	var item: Dictionary = t.bag[arg - BAG_ARG] if in_bag else t.equip.get(Gear.SLOTS[arg], {})
	ui._open(t, true, "bag")
	if item.is_empty():
		show_bag(ui, t)
		return
	var slot := String(item["slot"])
	ui._title(Gear.slot_name(slot), UiTheme.rarity_color(int(item["rarity"])))
	var card := item_card(ui, item, "", slot)
	if in_bag:
		var worn: Dictionary = t.equip.get(slot, {})
		var lines := compare(item, worn)
		ui._sub("Против надетого: %s" % (worn.get("name", stock_name(slot))))
		for line in lines:
			var l := ui._text(line, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.WIN if line.ends_with("↑") else UiTheme.LOSE)
			ui._box.add_child(l)
		if lines.is_empty():
			ui._note("Статы те же — разница в эффекте")
		ui._primary("НАДЕТЬ", "equip", arg - BAG_ARG)
		var sell := ui._secondary("Продать  +%d" % Gear.price(item), "sell", arg - BAG_ARG)
		ui.carry_coins(sell, card, Gear.price(item), t.gold + Gear.price(item))  # v0.2 L-3
	else:
		ui._note("Надето. Заменить можно вещью из сумки.")


## Main._on_ui hands the bag's actions here.
static func ui_action(m: Node, action: String, arg: int) -> void:
	var t: Tournament = m.tournament
	if t == null:
		m.ui.show_menu()
		return
	match action:
		"bag":
			show_bag(m.ui, t)
		"bag_back":
			m.ui.show_bracket(t)
		"bag_item":
			show_item(m.ui, t, arg)
		"equip":
			t.equip_from_bag(arg)
			SaveData.save()
			show_bag(m.ui, t)
		"sell":
			t.sell_from_bag(arg)
			SaveData.save()
			show_bag(m.ui, t)
		"sell_extra":
			t.sell_extra()
			SaveData.save()
			show_bag(m.ui, t)
