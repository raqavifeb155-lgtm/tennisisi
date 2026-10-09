class_name HouseRooms
extends RefCounted
## The academy house's rooms as DATA (docs/superpowers/specs/2026-10-10-academy-house.md 2): eight
## rooms of five levels, what a level puts in the room (the object) and what it gives. No state, no
## 3D: AcademyHouse keeps the levels, HouseWorld draws them, the sheets read the text.
##
## A level's numbers (the keys are read where they are used; the rest wait for the next stages):
##   cap       dorm: seats of the school (the only place that says it)
##   e s m     energy / satiety / mood a day gives the students (AH-2)
##   grow      [{tag, stats, pct}]  more experience in the stats; the same tag in a higher level
##             REPLACES the lower one (a better gym), other tags add up (a cook and a kitchen)
##   ceil      {stat: +n}           a higher ceiling of a stat (Academy.ceiling)
##   injury    percent fewer injuries (all rooms together stay under INJURY_CAP, AH-2)
##   the rest: days (injury lasts), advice (+pp for a right word in a match), camp (percent off a camp),
##             mentor / mentors, focus (training focuses), friend, quarrel (percent), cup, sponsors,
##             rating, scout ... - the effect's own line is in "fx", which the sheet shows.
## Prices: one row for every room (PRICE_BASE x ClubBuilds.CLUB_PRICE_SCALE, rounded to 5).

const ORDER := ["dorm", "canteen", "gym", "lounge", "video", "coach", "med", "hall"]   # the rows of the plan, south to north, west then east

## What a student's total growth from the house can reach (spec 2.2: rooms, form and trust together).
const GROWTH_CAP := 1.45
const INJURY_CAP := 60
const MAX_LEVEL := 5
## Spec 2.1: base price of level 1..5 (x 1 / 2.2 / 5 / 11.5 / 26 of 23).
const PRICE_BASE := [23, 51, 115, 265, 600]
## Levels 4 and 5 are built over runs, like ClubBuilds' `runs`: the gold goes at once, the scaffolding stays.
const RUNS := [0, 0, 0, 2, 3]
## The dorm's seats are its levels' "cap" (2 -> 6, spec 2.2; the school alone gave 1 -> 3, Academy.CAPACITY): the
## ONE TABLE for the owner's decision (spec 11.1) is the dorm's rows below, change the numbers there.

## id -> {name, short, opens (the academy's level), side (-1 west, +1 east of the hall), row (0 = by the door),
##        look {floor, wall, trim}, levels [{obj, fx, ...numbers}]}
const ROOMS := {
	"dorm": {
		"name": "Спальня", "short": "Спальня", "opens": 1, "side": -1, "row": 0, "effect": "вместимость и сон",
		"look": {"floor": Color("b99a73"), "wall": Color("e9d9c3"), "trim": Color("a9c5a0")},
		"levels": [
			{"obj": "Две койки и тумбочка", "fx": "вместимость 2 · энергия +26", "cap": 2, "e": 26},
			{"obj": "Двухъярусная кровать, шкаф", "fx": "вместимость 3 · энергия +32", "cap": 3, "e": 32},
			{"obj": "Тумбочки с лампами, шторы", "fx": "вместимость 4 · энергия +38", "cap": 4, "e": 38},
			{"obj": "Ортопедические матрасы, коврик", "fx": "вместимость 5 · энергия +46 · «выспался»: настроение +4", "cap": 5, "e": 46, "m": 4},
			{"obj": "Отдельные «номера» с ночником и балконом", "fx": "вместимость 6 · энергия +58", "cap": 6, "e": 58},
		],
	},
	"canteen": {
		"name": "Столовая и кухня", "short": "Столовая", "opens": 1, "side": 1, "row": 0, "effect": "питание",
		"look": {"floor": Color("c9b79a"), "wall": Color("f0e3c8"), "trim": Color("e8b84a")},
		"levels": [
			{"obj": "Стол, лавки, холодильник", "fx": "сытость +30", "s": 30},
			{"obj": "Плита, посуда, чайник", "fx": "сытость +38 · общий завтрак: дружба пары +1 за день", "s": 38, "friend": 1},
			{"obj": "Кухонный остров, стойка раздачи", "fx": "сытость +46 · блюдо дня: настроение +3", "s": 46, "m": 3},
			{"obj": "Витрина с фруктами, меню диетолога", "fx": "сытость +54 · рост скорости и выносливости +6%", "s": 54,
				"grow": [{"tag": "food", "stats": ["speed", "stamina"], "pct": 6}]},
			{"obj": "Шеф-повар в колпаке, зал на 8 мест", "fx": "сытость +60 · блюдо дня +6 · рост всем +5%", "s": 60, "m": 6,
				"grow": [{"tag": "chef", "stats": ["*"], "pct": 5}]},
		],
	},
	"gym": {
		"name": "Зал ОФП", "short": "Зал ОФП", "opens": 2, "side": -1, "row": 1, "effect": "физика",
		"look": {"floor": Color("5e6670"), "wall": Color("d9dde0"), "trim": Color("2a54a3")},
		"levels": [
			{"obj": "Коврик, гантели, фитболы", "fx": "рост скорости и выносливости +4%",
				"grow": [{"tag": "phys", "stats": ["speed", "stamina"], "pct": 4}]},
			{"obj": "Турник, скакалки, лестница", "fx": "+8% · травмы −5%", "injury": 5,
				"grow": [{"tag": "phys", "stats": ["speed", "stamina"], "pct": 8}]},
			{"obj": "Две беговые дорожки", "fx": "+12%",
				"grow": [{"tag": "phys", "stats": ["speed", "stamina"], "pct": 12}]},
			{"obj": "Силовая рама, зеркала, штанги", "fx": "+16% · травмы −15%", "injury": 15,
				"grow": [{"tag": "phys", "stats": ["speed", "stamina"], "pct": 16}]},
			{"obj": "Кроссфит-зал с табло и музыкой", "fx": "+20% · потолок скорости и выносливости +1", "injury": 15,
				"grow": [{"tag": "phys", "stats": ["speed", "stamina"], "pct": 20}], "ceil": {"speed": 1, "stamina": 1}},
		],
	},
	"lounge": {
		"name": "Комната отдыха", "short": "Отдых", "opens": 2, "side": 1, "row": 1, "effect": "настроение, дружба, ссоры",
		"look": {"floor": Color("b5654a"), "wall": Color("e8d3b8"), "trim": Color("3fb8af")},
		"levels": [
			{"obj": "Диван и телевизор", "fx": "настроение +10 · ссоры −10%", "m": 10, "quarrel": 10},
			{"obj": "Стол для настольного тенниса", "fx": "настроение +14 · дружба растёт на 1 быстрее", "m": 14, "friend_fast": 1, "quarrel": 10},
			{"obj": "Приставка и пуфы", "fx": "настроение +18 · ссоры −25%", "m": 18, "quarrel": 25},
			{"obj": "Библиотека и аквариум", "fx": "настроение +22 · в разговорах третий вариант ответа", "m": 22, "quarrel": 25, "third_answer": true},
			{"obj": "Терраса с видом на корт, мини-бар", "fx": "настроение +26 · ссоры −50% · «Любимое место»", "m": 26, "quarrel": 50, "third_answer": true, "favorite": true},
		],
	},
	"video": {
		"name": "Видеозал", "short": "Видеозал", "opens": 3, "side": -1, "row": 2, "effect": "разбор матчей и черты",
		"look": {"floor": Color("5a4a5c"), "wall": Color("6b5a7a"), "trim": Color("1e2a44")},
		"levels": [
			{"obj": "Телевизор на тумбе, диван", "fx": "«Разбор» последнего матча: слабое место и точки", "analysis": true},
			{"obj": "Проектор и экран", "fx": "скрытые черты раскрываются на матч раньше · рост сетки и бэкхенда +4%", "analysis": true, "reveal_early": 1,
				"grow": [{"tag": "tact", "stats": ["net", "backhand"], "pct": 4}]},
			{"obj": "Тактическая доска с магнитами", "fx": "верный совет в матче: +1 п.п.", "analysis": true, "reveal_early": 1, "advice": 1,
				"grow": [{"tag": "tact", "stats": ["net", "backhand"], "pct": 4}]},
			{"obj": "Монтажная: два монитора", "fx": "видно 1 скрытую черту соперника · верный совет +2 п.п.", "analysis": true, "reveal_early": 1, "advice": 2, "spy": 1,
				"grow": [{"tag": "tact", "stats": ["net", "backhand"], "pct": 4}]},
			{"obj": "Кинозал, кресла, статистика на стене", "fx": "лучшие очки в повторах · совет +3 п.п. · рост форхенда, бэкхенда, сетки +8%", "analysis": true, "reveal_early": 1, "advice": 3, "spy": 1, "replays": 3,
				"grow": [{"tag": "tact", "stats": ["forehand", "backhand", "net"], "pct": 8}]},
		],
	},
	"coach": {
		"name": "Кабинет тренера", "short": "Кабинет", "opens": 3, "side": 1, "row": 2, "effect": "программа и наставники",
		"look": {"floor": Color("a98764"), "wall": Color("e3d6c3"), "trim": Color("6b4a32")},
		"levels": [
			{"obj": "Стол, стул, доска с режимами", "fx": "режим нагрузки: отдых / обычная / усиленная", "modes": true, "focus": 1},
			{"obj": "Компьютер, папки с делами", "fx": "фокус тренировки: 2 навыка вместо 1", "modes": true, "focus": 2},
			{"obj": "Стенд с графиками роста", "fx": "«Сборы» дешевле на 15% · виден прогноз выпуска", "modes": true, "focus": 2, "camp": 15},
			{"obj": "Книжный шкаф, дипломы", "fx": "наставник даёт +25% (было +20%)", "modes": true, "focus": 2, "camp": 15, "mentor": 25},
			{"obj": "Штаб: стратегическая карта, кубки", "fx": "два наставника сразу · «Сборы» дешевле на 30%", "modes": true, "focus": 2, "camp": 30, "mentor": 25, "mentors": 2},
		],
	},
	"med": {
		"name": "Медпункт и спа", "short": "Медпункт", "opens": 4, "side": -1, "row": 3, "effect": "травмы и восстановление",
		"look": {"floor": Color("cfd8dc"), "wall": Color("eef4f4"), "trim": Color("4a8f87")},
		"levels": [
			{"obj": "Кушетка, аптечка", "fx": "травмы −10% · срок 3 забега", "injury": 10, "days": 3},
			{"obj": "Лампа и физиоаппарат", "fx": "травмы −20% · срок 3 забега", "injury": 20, "days": 3},
			{"obj": "Массажный стол", "fx": "травмы −30% · срок 2 забега", "injury": 30, "days": 2},
			{"obj": "Ванны со льдом", "fx": "травмы −45% · срок 2 забега · энергия +6", "injury": 45, "days": 2, "e": 6},
			{"obj": "Спа-бассейн", "fx": "травмы −60% · срок 1 забег · настроение +5", "injury": 60, "days": 1, "e": 6, "m": 5},
		],
	},
	"hall": {
		"name": "Приёмная и зал славы", "short": "Приёмная", "opens": 5, "side": 1, "row": 3, "effect": "карьеры, спонсоры, слава",
		"look": {"floor": Color("8f8a80"), "wall": Color("f4ead5"), "trim": Color("2a54a3")},
		"levels": [
			{"obj": "Стойка и доска кандидатов", "fx": "скаут: +1 кандидат в наборе · 1 заявка на юниорский кубок", "scout": 1, "cup": 1},
			{"obj": "Стенд со спонсором", "fx": "1 слот спонсора", "scout": 1, "cup": 1, "sponsors": 1},
			{"obj": "Шкаф с кубками академии", "fx": "кубок за каждый титул · рейтинг академии +2% · 2 заявки на кубок", "scout": 1, "cup": 2, "sponsors": 1, "rating": 2},
			{"obj": "Агентский стол", "fx": "контракты профи · 2-й слот спонсора", "scout": 1, "cup": 2, "sponsors": 2, "rating": 2, "contracts": true},
			{"obj": "Зал славы: стена выпускников, ракетки", "fx": "рейтинг академии до +5% · кандидаты скаута +½ звезды · 3 заявки на кубок", "scout": 1, "cup": 3, "sponsors": 2, "rating": 5, "contracts": true, "scout_star": 0.5},
		],
	},
}


static func ids() -> Array:
	return ORDER


static func has(room: String) -> bool:
	return ROOMS.has(room)


static func name_of(room: String) -> String:
	return String(ROOMS[room]["name"])


static func short_of(room: String) -> String:
	return String(ROOMS[room]["short"])


## The academy's level that opens the room.
static func opens(room: String) -> int:
	return int(ROOMS[room]["opens"])


## The record of a level 1..5 ({} out of range).
static func level(room: String, lv: int) -> Dictionary:
	var levels: Array = ROOMS[room]["levels"]
	return levels[lv - 1] if lv >= 1 and lv <= levels.size() else {}


## The price of level `lv` (1..5) in the club's scale: base x CLUB_PRICE_SCALE, rounded to 5.
static func price(lv: int) -> int:
	return roundi(float(PRICE_BASE[clampi(lv, 1, MAX_LEVEL) - 1]) * ClubBuilds.CLUB_PRICE_SCALE / 5.0) * 5


## Runs a level takes to build (0: at once).
static func runs(lv: int) -> int:
	return int(RUNS[clampi(lv, 1, MAX_LEVEL) - 1])


## What the sheet says a level gives, short.
static func effect_text(room: String, lv: int) -> String:
	return String(level(room, lv).get("fx", ""))


## The highest room level the academy's building allows (spec 2.1: a room's level <= the building's + 1).
static func cap_for_building(building_level: int) -> int:
	return clampi(building_level + 1, 0, MAX_LEVEL) if building_level >= 1 else 0


## The grow effects of a room at a level, one per tag (a higher level of the same tag replaces the lower).
static func grow_of(room: String, lv: int) -> Array:
	var by_tag := {}
	for i in range(1, lv + 1):
		for g in level(room, i).get("grow", []):
			by_tag[g["tag"]] = g
	return by_tag.values()


## The ceiling additions of a room at a level ({stat: +n}).
static func ceil_of(room: String, lv: int) -> Dictionary:
	var out := {}
	for i in range(1, lv + 1):
		var c: Dictionary = level(room, i).get("ceil", {})
		for k in c:
			out[k] = maxi(int(out.get(k, 0)), int(c[k]))
	return out
