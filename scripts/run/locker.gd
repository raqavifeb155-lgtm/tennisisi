class_name Locker
## The locker (v0.2 A-2, spec 2026-10-08-v02-hub-economy 1, ROGUELIKE_DESIGN 11.0): what a
## run leaves behind. On the summary the player keeps ONE item worn or in the bag; how rare
## it may be depends on how far the run went (the ceiling), and a legendary or mythic needs
## an insurance of 10% of its price. A kept item can be taken into the next run before its
## first match — and is at risk again there. What the shop sold ("next") comes along by
## itself: it was bought for that run.
##
## Club-side data (survives a retired player, ACADEMY_LEGACY_TZ): SaveData.locker =
## {"items": [...], "next": [...], "shop": {...}} (the shop's state is Shop's).

const MAX_SLOTS := 4
const NEXT_MAX := 3               # bought items waiting for the next run
const INSURANCE := 0.10
## The ceiling by the round the run ended in (index; 5 = the title): ROGUELIKE 11.0.
const CAPS := [Gear.RARE, Gear.RARE, Gear.EPIC, Gear.EPIC, Gear.LEGENDARY, Gear.MYTHIC]


static var boarded: Array = []    # names of what the last board() put into the run (the bracket says so)


static func _list(key: String) -> Array:
	if not SaveData.locker.has(key):
		SaveData.locker[key] = []
	return SaveData.locker[key]


## Gold out of the bank on the locker / shop side. Counted in locker["spent"] so the save's
## score (SaveData._score) never falls when gold is spent: a spend is progress too.
static func spend(n: int) -> void:
	SaveData.gold -= n
	SaveData.locker["spent"] = int(SaveData.locker.get("spent", 0)) + n


static func items() -> Array:
	return _list("items")


static func next_items() -> Array:
	return _list("next")


## One slot, +1 a level of the changing room (ClubBuilds "locker", stream B), at most 4.
static func slots() -> int:
	return clampi(ClubBuilds.locker_slots(), 1, MAX_SLOTS)


static func cap(round_i: int) -> int:
	return CAPS[clampi(round_i, 0, CAPS.size() - 1)]


static func cap_text(round_i: int) -> String:
	return ["до редкой", "до редкой", "до эпической", "до эпической", "до легендарной", "любая"][clampi(round_i, 0, 5)]


static func insurance(item: Dictionary) -> int:
	if item.is_empty() or int(item.get("rarity", 0)) < Gear.LEGENDARY:
		return 0
	return roundi(Items.price(item) * INSURANCE * (1.0 - ClubApi.insurance_discount()))


## Where the run ended for the ceiling: the title = 5, else the round it went out in.
static func exit_round(t: Tournament) -> int:
	return 5 if t.champion else clampi(t.stage, 0, 4)


## Why the item can't go in ("" = it can). replace: the locker slot it would take.
static func check(item: Dictionary, round_i: int, replace := -1) -> String:
	if item.is_empty():
		return "пусто"
	if int(item.get("rarity", 0)) > cap(round_i):
		return "выше потолка: %s" % cap_text(round_i)
	var gain := Items.sell_price(items()[replace]) if replace >= 0 and replace < items().size() else 0
	var need := insurance(item) - SaveData.gold - gain
	if need > 0:
		return "нужно ещё %d" % need
	if replace < 0 and items().size() >= slots():
		return "шкафчик полон: замени вещь"
	return ""


## Keeps the item ("" = done, else why not). replace >= 0: that slot's item is sold into the
## bank first. The insurance is paid from the bank.
static func put(item: Dictionary, round_i: int, replace := -1) -> String:
	var why := check(item, round_i, replace)
	if why != "":
		return why
	if replace >= 0 and replace < items().size():
		SaveData.gold += Items.sell_price(items()[replace])
		items().remove_at(replace)
	spend(insurance(item))
	items().append(item.duplicate(true))
	return ""


## A reward (the coach's quests): never refused — into a free slot, else it comes along
## with the next run like a bought item.
static func gift(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	if items().size() < slots():
		items().append(item.duplicate(true))
		return "locker"
	next_items().append(item.duplicate(true))
	return "next"


static func take(i: int) -> Dictionary:
	if i < 0 or i >= items().size():
		return {}
	var it: Dictionary = items()[i]
	items().remove_at(i)
	return it


# --- With a run ---------------------------------------------------------------------

## Before the first match: what was bought joins the run (put on into an empty slot, else
## into the bag). Called when the bracket first shows.
static func board(t: Tournament) -> void:
	boarded = []
	if not t.can_take_locker():
		return
	var bought := next_items()
	while not bought.is_empty():
		var it: Dictionary = bought.pop_front()
		boarded.append(String(it["name"]))
		t.join(it)


## What the summary offers for the locker: worn first, then the bag.
## [{"item", "from": "equip"|"bag", "i": slot index or bag index}]
static func candidates(t: Tournament) -> Array:
	var out: Array = []
	for i in Gear.SLOTS.size():
		var it: Dictionary = t.equip.get(Gear.SLOTS[i], {})
		if not it.is_empty():
			out.append({"item": it, "from": "equip", "i": i})
	for i in t.bag.size():
		out.append({"item": t.bag[i], "from": "bag", "i": i})
	return out


## The summary's choice: candidate i into the locker (once a run).
static func save_from(t: Tournament, i: int, replace := -1) -> String:
	if t.locker_done:
		return "уже выбрано"
	var c := candidates(t)
	if i < 0 or i >= c.size():
		return "нет такой вещи"
	var why := put(c[i]["item"], exit_round(t), replace)
	if why == "":
		t.locker_done = true
	return why
