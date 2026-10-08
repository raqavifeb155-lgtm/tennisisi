class_name Shop
## The club's shop (v0.2 A-3, spec 2026-10-08-v02-hub-economy 2): a showcase of random
## items that changes after every run, a paid reroll, buying for the next run, selling
## what the locker holds, and the strings — a paid gamble on an item's stats.
##
## How big and how rare the showcase is comes from the shop's level (ClubBuilds, stream B:
## shop_stock 2/3/4, shop_max_rarity rare/epic/legendary). Never a mythic. Items come at
## the level of the best open island. State in SaveData.locker["shop"]:
## {"run": the run it was rolled for, "rerolls": paid this time, "sold": [showcase indices]}.

const REROLL := 20
const REROLL_GROWTH := 1.5
const WEIGHTS := [55.0, 33.0, 10.0, 2.0]    # common, rare, epic, legendary (within the ceiling)
const RESTRING := 0.25                      # of the price; a mythic 0.5
const RESTRING_MYTHIC := 0.5
const SEED_RUN := 7919
const SEED_REROLL := 104729


static func level() -> int:
	return ClubBuilds.level("shop")


static func _state() -> Dictionary:
	if not SaveData.locker.has("shop"):
		SaveData.locker["shop"] = {}
	var st: Dictionary = SaveData.locker["shop"]
	if int(st.get("run", -1)) != SaveData.played:
		st["run"] = SaveData.played
		st["rerolls"] = 0
		st["sold"] = []
	return st


## The item level of the showcase: 1 + the best open island's tier.
static func item_level() -> int:
	return 1 + Locations.tier(Locations.best_unlocked())


## The showcase: shop_stock() items ({} where one was bought). Same run, same rerolls =
## the same items (a reload can't reroll for free).
static func stock() -> Array:
	var st := _state()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(st["run"]) * SEED_RUN + int(st["rerolls"]) * SEED_REROLL + 1
	var cap := mini(ClubBuilds.shop_max_rarity(), Gear.LEGENDARY)
	var out: Array = []
	for i in ClubBuilds.shop_stock():
		var it := Gear.roll(_rarity(rng, cap), rng, Gear.SLOTS[rng.randi_range(0, 2)], item_level())
		out.append({} if (st["sold"] as Array).has(i) else it)
	return out


static func _rarity(rng: RandomNumberGenerator, cap: int) -> int:
	var total := 0.0
	for r in cap + 1:
		total += WEIGHTS[r]
	var x := rng.randf() * total
	for r in cap + 1:
		if x < WEIGHTS[r]:
			return r
		x -= WEIGHTS[r]
	return cap


static func reroll_price() -> int:
	return roundi(REROLL * pow(REROLL_GROWTH, int(_state()["rerolls"])))


static func reroll() -> bool:
	var p := reroll_price()
	if SaveData.gold < p:
		return false
	Locker.spend(p)
	var st := _state()
	st["rerolls"] = int(st["rerolls"]) + 1
	st["sold"] = []
	return true


## Why showcase item i can't be bought ("" = it can).
static func why_not(i: int) -> String:
	var s := stock()
	if i < 0 or i >= s.size() or (s[i] as Dictionary).is_empty():
		return "продано"
	if Locker.next_items().size() >= Locker.NEXT_MAX:
		return "сумка на турнир полна (%d)" % Locker.NEXT_MAX
	var left := Items.price(s[i]) - SaveData.gold
	if left > 0:
		return "ещё %d" % left
	return ""


## Buys it for the next run ("" = bought, else why not).
static func buy(i: int) -> String:
	var why := why_not(i)
	if why != "":
		return why
	var it: Dictionary = stock()[i]
	Locker.spend(Items.price(it))
	Locker.next_items().append(it)
	(_state()["sold"] as Array).append(i)
	return ""


## The player's things in the club: where = "items" (the locker) or "next" (bought).
static func owned(where: String) -> Array:
	return Locker.items() if where == "items" else Locker.next_items()


## Sells a thing of the locker or the bought ones into the bank; returns the gold.
static func sell(where: String, i: int) -> int:
	var list := owned(where)
	if i < 0 or i >= list.size():
		return 0
	var p := Items.sell_price(list[i])
	list.remove_at(i)
	SaveData.gold += p
	return p


# --- The strings --------------------------------------------------------------------

static func can_restring() -> bool:
	return level() >= 1


static func restring_price(item: Dictionary) -> int:
	var share := RESTRING_MYTHIC if int(item.get("rarity", 0)) >= Gear.MYTHIC else RESTRING
	return roundi(Items.price(item) * share)


## How many string lines a catalog item gets: 1, a legendary or mythic 2.
static func string_count(item: Dictionary) -> int:
	return 2 if int(item.get("rarity", 0)) >= Gear.LEGENDARY else 1


## What can come out: the slot's affixes with their ranges at the item's rarity.
static func string_pool(item: Dictionary) -> Array[String]:
	return Gear.affix_pool(String(item.get("slot", "racket")), int(item.get("rarity", 0)))


## Restrings the item in place: a generated item (no id) gets new affixes, a catalog item
## a new "Струны" line; its effect, name, rarity and level stay. Always different.
static func restring_item(item: Dictionary, rng: RandomNumberGenerator) -> void:
	var slot := String(item.get("slot", "racket"))
	var r := int(item.get("rarity", 0))
	var catalog := item.has("id")
	var old: Dictionary = item.get("strings", {}).get("mods", {}) if catalog else item.get("base", item.get("mods", {}))
	var n := string_count(item) if catalog else int(Gear.RARITIES[r]["affixes"])
	var aff := {}
	for tries in 20:
		aff = Gear.affixes(slot, r, n, rng)
		if aff["mods"] != old:
			break
	if catalog:
		item["strings"] = aff
	else:
		item["base"] = aff["mods"]
		item["lines"] = aff["lines"]
	Items.refresh(item)


## Pays and restrings a thing of the locker or the bought ones ("" = done, else why not).
static func restring(where: String, i: int, rng: RandomNumberGenerator = null) -> String:
	var list := owned(where)
	if i < 0 or i >= list.size():
		return "нет такой вещи"
	if not can_restring():
		return "струны — с «Лавки»"
	var p := restring_price(list[i])
	if SaveData.gold < p:
		return "ещё %d" % (p - SaveData.gold)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	Locker.spend(p)
	restring_item(list[i], rng)
	return ""
