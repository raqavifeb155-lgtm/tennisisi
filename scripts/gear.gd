class_name Gear
## Gear (Path of Exile style): a racket, shoes and a wristband, each with a rarity. Gear
## lives one tournament. Commons and rares are rolled here from random affixes (or are
## one of the catalog's simple items); epic and up are always a unique item from Items
## with an effect (v0.2, ROGUELIKE_DESIGN 6). Affixes use the same keys as the skill
## perks (see Skills.stroke), so an item simply adds to them: "+8% к силе форхенда" is
## {"forehand_pace": 0.08}.
##
## Five rarities: gray, blue, purple, orange (legendary), red (mythic) — UiTheme.RARITY.

const RARITIES := [
	{"id": "common", "name": "Обычная", "affixes": 1, "power": 0.8, "glow": 0.0},
	{"id": "rare", "name": "Редкая", "affixes": 2, "power": 1.0, "glow": 0.0},
	{"id": "epic", "name": "Эпическая", "affixes": 3, "power": 1.15, "glow": 0.7},
	{"id": "legendary", "name": "Легендарная", "affixes": 4, "power": 1.35, "glow": 1.6},
	{"id": "mythic", "name": "Мифическая", "affixes": 4, "power": 1.5, "glow": 2.2},
]
const COMMON := 0
const RARE := 1
const EPIC := 2
const LEGENDARY := 3
const MYTHIC := 4

const SLOTS := ["racket", "shoes", "band"]
const SLOT_NAMES := {"racket": "Ракетка", "shoes": "Кроссовки", "band": "Напульсник"}
## The rarity word agreeing with the slot's noun: ракетка (f), кроссовки (pl), напульсник (m).
const FORMS := {
	"racket": ["Обычная", "Редкая", "Эпическая", "Легендарная", "Мифическая"],
	"shoes": ["Обычные", "Редкие", "Эпические", "Легендарные", "Мифические"],
	"band": ["Обычный", "Редкий", "Эпический", "Легендарный", "Мифический"],
}
const NOUNS := {"racket": "ракетка", "shoes": "кроссовки", "band": "напульсник"}
const UNIQUE_SHARE := 0.35             # a common or rare is a catalog item this often

## [key, text with %d, min, max] — percentages; negative keys (scatter, penalties) shrink.
const AFFIXES_BY_SLOT := {
	"racket": [
		["forehand_pace", "+%d%% к силе форхенда", 4, 10],
		["backhand_pace", "+%d%% к силе бэкхенда", 4, 10],
		["serve_pace", "+%d%% к скорости подачи", 3, 8],
		["net_pace", "+%d%% к силе с лёта и смэша", 5, 12],
		["touch_pace", "+%d%% к скорости резаного", 4, 8],
		["forehand_scatter", "−%d%% к разбросу форхенда", 8, 20],
		["backhand_scatter", "−%d%% к разбросу бэкхенда", 8, 20],
		["serve_scatter", "−%d%% к разбросу подачи", 8, 20],
		["net_scatter", "−%d%% к разбросу у сетки", 8, 20],
		["touch_scatter", "−%d%% к разбросу касания", 8, 20],
		["forehand_spin", "+%d%% к вращению справа", 8, 20],
		["backhand_spin", "+%d%% к вращению слева", 8, 20],
		["serve_spin", "+%d%% к вращению подачи", 8, 20],
		["touch_spin", "+%d%% к вращению резаного", 8, 20],
	],
	"shoes": [
		["run_speed", "+%d%% к скорости бега", 2, 5],
		["move_penalty", "−%d%% к штрафу за удар на бегу", 10, 30],
		["stamina_pool", "+%d%% к запасу выносливости", 5, 12],
		["stamina_drain", "−%d%% к расходу выносливости", 5, 12],
		["stamina_rest", "+%d%% к отдыху между очками", 2, 4],
	],
	"band": [
		["forehand_window", "+%d%% к окну PERFECT справа", 8, 20],
		["backhand_window", "+%d%% к окну PERFECT слева", 8, 20],
		["serve_window", "+%d%% к окну PERFECT на подаче", 10, 25],
		["net_window", "+%d%% к окну PERFECT у сетки", 10, 25],
		["touch_window", "+%d%% к окну PERFECT на касании", 10, 25],
		["serve_pace", "+%d%% к скорости подачи", 2, 5],
	],
}
## Every affix of every slot (the size of the pool, older code and tests).
static var AFFIXES: Array = AFFIXES_BY_SLOT["racket"] + AFFIXES_BY_SLOT["shoes"] + AFFIXES_BY_SLOT["band"]
## slot -> the mod keys its generated items can carry.
static var AFFIX_KEYS := {
	"racket": AFFIXES_BY_SLOT["racket"].map(func(a): return a[0]),
	"shoes": AFFIXES_BY_SLOT["shoes"].map(func(a): return a[0]),
	"band": AFFIXES_BY_SLOT["band"].map(func(a): return a[0]),
}

const NAMES := {
	"common": ["Клуб", "Прокат", "Тренировка", "Двор"],
	"rare": ["Синяя молния", "Штиль", "Прибой", "Лёд"],
}


## A random item of the given rarity for a slot (a racket when no slot is given), at a
## level (v0.2 A economy: the island's tier, the shop's best island).
static func roll(rarity: int, rng: RandomNumberGenerator, slot := "racket", level := 1) -> Dictionary:
	rarity = clampi(rarity, COMMON, MYTHIC)
	var it := {}
	if rarity >= EPIC or rng.randf() < UNIQUE_SHARE:
		it = Items.roll(slot, rarity, rng)
	if it.is_empty():
		it = _affix_item(rarity, rng, slot)
	return Items.set_level(it, level) if level > 1 else it


static func _affix_item(rarity: int, rng: RandomNumberGenerator, slot: String) -> Dictionary:
	var r: Dictionary = RARITIES[rarity]
	var aff := affixes(slot, rarity, int(r["affixes"]), rng)
	var names: Array = NAMES.get(r["id"], NAMES["rare"])
	return {
		"slot": slot, "rarity": rarity,
		"name": "%s %s «%s»" % [FORMS[slot][rarity], NOUNS[slot], names[rng.randi_range(0, names.size() - 1)]],
		"mods": aff["mods"], "lines": aff["lines"],
	}


## n random affixes of the slot at the rarity's power: {"mods": {...}, "lines": [...]}
## (also the shop's strings, v0.2 A-3).
static func affixes(slot: String, rarity: int, n: int, rng: RandomNumberGenerator) -> Dictionary:
	var r: Dictionary = RARITIES[clampi(rarity, COMMON, MYTHIC)]
	var pool: Array = AFFIXES_BY_SLOT[slot].duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var mods := {}
	var lines: Array[String] = []
	for a in pool.slice(0, mini(n, pool.size())):
		var pct := maxi(1, roundi(rng.randf_range(a[2], a[3]) * float(r["power"])))
		var key: String = a[0]
		var shrink := key.ends_with("_scatter") or key == "move_penalty" or key == "stamina_drain"
		mods[key] = (-1.0 if shrink else 1.0) * pct / 100.0
		lines.append(String(a[1]) % pct)
	return {"mods": mods, "lines": lines}


## The slot's affixes as the shop shows the strings' pool: "+4–10% к силе форхенда".
static func affix_pool(slot: String, rarity: int) -> Array[String]:
	var k := float(RARITIES[clampi(rarity, COMMON, MYTHIC)]["power"])
	var out: Array[String] = []
	for a in AFFIXES_BY_SLOT.get(slot, []):
		var lo := maxi(1, roundi(a[2] * k))
		var hi := maxi(1, roundi(a[3] * k))
		out.append(String(a[1]).replace("%d", "%d–%d" % [lo, hi]).replace("%%", "%"))
	return out


static func color(item: Dictionary) -> Color:
	if item.is_empty():
		return Color(0.15, 0.15, 0.2)
	return UiTheme.rarity_color(int(item["rarity"]))


static func glow(item: Dictionary) -> float:
	return 0.0 if item.is_empty() else float(RARITIES[int(item["rarity"])]["glow"])


## What the item sells for (v0.2 A economy: a third of its buy price, Items.sell_price).
static func price(item: Dictionary) -> int:
	return Items.sell_price(item)


static func slot_name(slot: String) -> String:
	return SLOT_NAMES.get(slot, slot)


static func describe(item: Dictionary) -> String:
	return Items.describe(item)
