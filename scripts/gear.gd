class_name Gear
## Gear (Path of Exile style): rackets with a rarity and random affixes. Gear lives one
## tournament. Affixes use the same keys as the skill perks (see Skills.stroke), so a
## racket simply adds to them: "+8% к силе форхенда" is {"forehand_pace": 0.08}.
##
## Rare loot is visible before the match: an opponent may walk on court with an epic
## (purple) or legendary (gold, glowing) racket. Beat them and it drops for sure.

const RARITIES := [
	{"id": "common", "name": "Обычная", "color": Color(0.82, 0.84, 0.88), "affixes": 1, "power": 0.8, "glow": 0.0},
	{"id": "rare", "name": "Редкая", "color": Color(0.35, 0.62, 1.0), "affixes": 2, "power": 1.0, "glow": 0.0},
	{"id": "epic", "name": "Эпическая", "color": Color(0.72, 0.36, 1.0), "affixes": 3, "power": 1.15, "glow": 0.7},
	{"id": "legendary", "name": "Легендарная", "color": Color(1.0, 0.7, 0.12), "affixes": 4, "power": 1.35, "glow": 1.6},
]
const COMMON := 0
const RARE := 1
const EPIC := 2
const LEGENDARY := 3

## [key, text with %d, min, max] — percentages; negative keys (scatter, move penalty) shrink.
const AFFIXES := [
	["forehand_pace", "+%d%% к силе форхенда", 4, 10],
	["backhand_pace", "+%d%% к силе бэкхенда", 4, 10],
	["serve_pace", "+%d%% к скорости подачи", 3, 8],
	["net_pace", "+%d%% к силе с лёта и смэша", 5, 12],
	["touch_pace", "+%d%% к скорости резаного", 4, 8],
	["forehand_window", "+%d%% к окну PERFECT справа", 8, 20],
	["backhand_window", "+%d%% к окну PERFECT слева", 8, 20],
	["serve_window", "+%d%% к окну PERFECT на подаче", 10, 25],
	["net_window", "+%d%% к окну PERFECT у сетки", 10, 25],
	["touch_window", "+%d%% к окну PERFECT на касании", 10, 25],
	["forehand_scatter", "−%d%% к разбросу форхенда", 8, 20],
	["backhand_scatter", "−%d%% к разбросу бэкхенда", 8, 20],
	["serve_scatter", "−%d%% к разбросу подачи", 8, 20],
	["net_scatter", "−%d%% к разбросу у сетки", 8, 20],
	["touch_scatter", "−%d%% к разбросу касания", 8, 20],
	["forehand_spin", "+%d%% к вращению справа", 8, 20],
	["backhand_spin", "+%d%% к вращению слева", 8, 20],
	["serve_spin", "+%d%% к вращению подачи", 8, 20],
	["touch_spin", "+%d%% к вращению резаного", 8, 20],
	["run_speed", "+%d%% к скорости бега", 2, 5],
	["move_penalty", "−%d%% к штрафу за удар на бегу", 10, 30],
]

const NAMES := {
	"common": ["Клубная", "Прокатная", "Тренировочная", "Дворовая"],
	"rare": ["Синяя молния", "Штиль", "Прибой", "Лёд"],
	"epic": ["Аметист", "Фиолетовый шторм", "Сумерки", "Гроза"],
	"legendary": ["Пламя", "Громовержец", "Корона", "Солнце Уимблдона"],
}


## A random racket of the given rarity.
static func roll(rarity: int, rng: RandomNumberGenerator) -> Dictionary:
	var r: Dictionary = RARITIES[rarity]
	var pool: Array = AFFIXES.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var mods := {}
	var lines: Array[String] = []
	for a in pool.slice(0, r["affixes"]):
		var pct := roundi(rng.randf_range(a[2], a[3]) * float(r["power"]))
		var key: String = a[0]
		var dir_sign := -1.0 if key.ends_with("_scatter") or key == "move_penalty" else 1.0
		mods[key] = dir_sign * pct / 100.0
		lines.append(String(a[1]) % pct)
	var names: Array = NAMES[r["id"]]
	return {
		"slot": "racket", "rarity": rarity,
		"name": "%s ракетка «%s»" % [r["name"], names[rng.randi_range(0, names.size() - 1)]],
		"mods": mods, "lines": lines,
	}


static func color(item: Dictionary) -> Color:
	if item.is_empty():
		return Color(0.15, 0.15, 0.2)
	return RARITIES[item["rarity"]]["color"]


static func glow(item: Dictionary) -> float:
	return 0.0 if item.is_empty() else float(RARITIES[item["rarity"]]["glow"])


static func describe(item: Dictionary) -> String:
	return "\n".join(item.get("lines", []))
