class_name ClubBuilds
## The club's constructions (docs/club/H2_SPEC.md 2, CLUB_BRIEF 3): five places, their
## levels, prices, small perks with caps and the coach's line for each. Data, not the
## building code: ClubWorld builds what a level shows (_level_<id>), this table says what
## it costs and gives. Gold is spent and saved here; the 3D only shows it afterwards.
##
## Saved in SaveData.club: "levels" {id: level}, "color" 0..3, "name", "spent".

const CLUB_PRICE_SCALE := 1.0

## id -> {name, place (ClubPlaces id where it stands), unlock, start (level 0 as it is),
## levels: [level 1, 2, ...]}.
## A level: title, now (what you see), perk ("" = none), price, line (the coach, <= 60).
const TABLE := {
	"court": {
		"name": "Главный корт", "place": "court", "unlock": "", "start": "трещины и выцветшие линии",
		"levels": [
			{"title": "Свежий хард", "now": "свежий хард, яркие линии", "perk": "", "price": 40,
				"line": "Свежая краска! Мяч теперь отскакивает честно"},
			{"title": "Сетка и фонари", "now": "новая сетка и забор, лавки, фонари", "perk": "", "price": 120,
				"line": "Новая сетка. Теперь не стыдно звать соперников"},
			{"title": "Цвет клуба", "now": "покрытие в цвет клуба (4 на выбор)", "perk": "", "price": 300,
				"line": "Наш цвет! Теперь это точно наш корт"},
			{"title": "Логотип", "now": "логотип в центре, имя на заднике", "perk": "", "price": 550,
				"line": "Логотип на корте. Как у больших"},
		],
	},
	"stands": {
		"name": "Трибуны", "place": "court", "unlock": "", "start": "колышки с лентой",
		"levels": [
			{"title": "Две скамейки", "now": "две скамейки у корта", "perk": "+2% золота за победы", "bonus": 0.02, "price": 50,
				"line": "Две скамейки. Уже кто-то придёт посмотреть"},
			{"title": "Трибуна", "now": "трибуна вдоль корта", "perk": "+4% золота за победы", "bonus": 0.04, "price": 150,
				"line": "Трибуна! Будет кому хлопать"},
			{"title": "Болельщики", "now": "вторая трибуна, болельщики в цвете клуба", "perk": "+6% золота за победы", "bonus": 0.06, "price": 300,
				"line": "Трибуны готовы. Теперь тебя слышно с набережной"},
			{"title": "Козырёк и флаги", "now": "козырёк и флаги клуба", "perk": "+8% золота за победы", "bonus": 0.08, "price": 500,
				"line": "Флаги клуба. Красиво же"},
			{"title": "Полные трибуны", "now": "полные трибуны, шумят громче", "perk": "+10% золота за победы", "bonus": 0.10, "price": 800,
				"line": "Аншлаг! Слышишь, как шумят?"},
		],
	},
	"gate": {
		"name": "Вход", "place": "gate", "unlock": "", "start": "калитка и табличка «Public Courts»",
		"levels": [
			{"title": "Ворота и вывеска", "now": "ворота с деревянной вывеской с именем клуба", "perk": "", "price": 60,
				"line": "%s. Звучит!"},
			{"title": "Парковка", "now": "парковка и хэтчбек", "perk": "", "price": 200,
				"line": "Своя парковка. Солидно"},
			{"title": "Неон", "now": "каменные ворота, неоновая вывеска", "perk": "", "price": 450,
				"line": "Неон! Вечером нас видно с моста"},
			{"title": "Спорткар", "now": "спорткар на парковке", "perk": "", "price": 800,
				"line": "Спорткар. Ну ты даёшь"},
		],
	},
	"trophy": {
		"name": "Трофейная", "place": "trophy", "unlock": "played", "start": "пустое место",
		"levels": [
			{"title": "Полка", "now": "полка: кубок за каждый титул", "perk": "Кодекс (скоро)", "price": 60,
				"line": "Полка для кубков. Давай её заполним"},
			{"title": "Витрина", "now": "витрина: лучшие вещи светятся", "perk": "счётчик удачи (скоро)", "price": 220,
				"line": "Витрина. Пусть все видят, чем играешь"},
			{"title": "Зал кубков", "now": "зал кубков, прожектор на лучшую вещь", "perk": "", "price": 550,
				"line": "Зал кубков. Тут и музей открыть можно"},
		],
	},
	"bar": {
		"name": "Бар", "place": "bar", "unlock": "title", "start": "стол с рулеткой под зонтом",
		"levels": [
			{"title": "Ларёк", "now": "ларёк с газировкой", "perk": "ставка до 50", "price": 100,
				"line": "Газировка есть. Ставки покрупнее"},
			{"title": "Бар", "now": "бар с зонтиками и стульями", "perk": "ставка до 150", "price": 300,
				"line": "Бар с зонтиками. Курорт!"},
			{"title": "Терраса", "now": "терраса у воды, неон", "perk": "ставка до 500", "price": 650,
				"line": "Терраса у воды. Лучшее место в клубе"},
		],
	},
	# The shop (hub spec 2): what the window shows grows with it. stock, max_rarity: for
	# stream A's Shop.stock() (ClubBuilds.shop_stock / shop_max_rarity).
	"shop": {
		"name": "Магазин", "place": "shop", "unlock": "played", "start": "ларёк: 2 вещи, до редкой",
		"stock0": 2, "rarity0": 1,
		"levels": [
			{"title": "Лавка", "now": "лавка: 3 вещи до эпической, струны", "perk": "3 вещи, струны", "price": 150,
				"stock": 3, "max_rarity": 2, "line": "Лавка! Теперь и струны перетянем"},
			{"title": "Бутик", "now": "бутик: 4 вещи до легендарной, витрина светится", "perk": "4 вещи, до легендарной", "price": 450,
				"stock": 4, "max_rarity": 3, "line": "Бутик. Витрина светится — красота"},
		],
	},
	# The locker room (hub spec 1): one more locker slot a level, up to 4.
	"locker": {
		"name": "Раздевалка", "place": "locker", "unlock": "played", "start": "скамейка и один шкафчик (1 ячейка)",
		"levels": [
			{"title": "Ряд шкафчиков", "now": "ряд шкафчиков и зеркало", "perk": "2 ячейки шкафчика", "price": 80,
				"line": "Ещё шкафчик. Можно хранить две вещи"},
			{"title": "Стена ракеток", "now": "стена ракеток: твои вещи висят", "perk": "3 ячейки шкафчика", "price": 250,
				"line": "Стена ракеток. Есть чем похвастаться"},
			{"title": "Гардероб", "now": "гардероб с подсветкой", "perk": "4 ячейки шкафчика", "price": 550,
				"line": "Гардероб с подсветкой. Как у профи"},
		],
	},
}
const ORDER := ["court", "stands", "gate", "shop", "locker", "trophy", "bar"]

## A short list of words a club's name can't have (the sign is seen by friends).
const BAD_WORDS := ["хуй", "хуе", "пизд", "ебат", "ебан", "ёбан", "бляд", "сука", "муда", "пидор", "fuck", "shit", "dick", "cunt"]
const NAME_MAX := 16

## Off in an online match: the club gives nothing to strength or gold there.
static var utility_enabled := true


static func level(id: String) -> int:
	var levels: Dictionary = SaveData.club.get("levels", {})
	return clampi(int(levels.get(id, 0)), 0, max_level(id))


static func max_level(id: String) -> int:
	return (TABLE[id]["levels"] as Array).size() if TABLE.has(id) else 0


static func is_open(id: String) -> bool:
	match String(TABLE[id].get("unlock", "")):
		"played":
			return SaveData.played >= 1
		"title":
			return SaveData.titles >= 1
	return true


## The next level's record, {} at the top.
static func next(id: String) -> Dictionary:
	var lv := level(id)
	if lv >= max_level(id):
		return {}
	return TABLE[id]["levels"][lv]


static func next_price(id: String) -> int:
	var n := next(id)
	return roundi(float(n["price"]) * CLUB_PRICE_SCALE) if not n.is_empty() else 0


static func can_afford(id: String) -> bool:
	return is_open(id) and not next(id).is_empty() and SaveData.gold >= next_price(id)


static func affordable_count() -> int:
	var n := 0
	for id in ORDER:
		if can_afford(id):
			n += 1
	return n


## Buys the next level: the gold goes and the save is written now, before any show.
static func buy(id: String) -> bool:
	if not TABLE.has(id) or not can_afford(id):
		return false
	var price := next_price(id)
	SaveData.gold -= price
	var levels: Dictionary = SaveData.club.get("levels", {}).duplicate()
	levels[id] = level(id) + 1
	SaveData.club["levels"] = levels
	SaveData.club["spent"] = int(SaveData.club.get("spent", 0)) + price
	if id == "gate" and levels[id] == 1 and String(SaveData.club.get("name", "")) == "":
		SaveData.club["name"] = default_name()
	SaveData.save()
	return true


## The stands' perk: more gold for a won match (0.02 a level, at most 0.10).
static func gold_win_bonus() -> float:
	if not utility_enabled:
		return 0.0
	var lv := level("stands")
	return minf(float(TABLE["stands"]["levels"][lv - 1].get("bonus", 0.0)) if lv > 0 else 0.0, 0.10)


## Locker slots (hub spec 1): 1 at the start, +1 a level of the locker room, up to 4.
static func locker_slots() -> int:
	return mini(1 + level("locker"), 4)


## How many things the shop's window shows (hub spec 2): 2 / 3 / 4.
static func shop_stock() -> int:
	var lv := level("shop")
	return int(TABLE["shop"]["stock0"]) if lv == 0 else int(TABLE["shop"]["levels"][lv - 1]["stock"])


## The rarest thing the shop sells (Gear.RARE / EPIC / LEGENDARY; never mythic).
static func shop_max_rarity() -> int:
	var lv := level("shop")
	return int(TABLE["shop"]["rarity0"]) if lv == 0 else int(TABLE["shop"]["levels"][lv - 1]["max_rarity"])


## The biggest stake the bar takes (its place's data: ClubPlaces "bar" by level).
static func bet_limit() -> int:
	return int(ClubPlaces.state("bar", level("bar")).get("bet_limit", 0))


## The club's colour (main court level 3).
static func color_index() -> int:
	return clampi(int(SaveData.club.get("color", 0)), 0, ClubMaterial.CLUB_COLORS.size() - 1)


static func club_color() -> Color:
	return ClubMaterial.CLUB_COLORS[color_index()]


static func club_name() -> String:
	var n := String(SaveData.club.get("name", ""))
	return n if n != "" else default_name()


## «Клуб Димы» from Telegram's first name, else just «Клуб».
static func default_name() -> String:
	var first := ""
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("(window.Telegram && Telegram.WebApp && Telegram.WebApp.initDataUnsafe && Telegram.WebApp.initDataUnsafe.user) ? Telegram.WebApp.initDataUnsafe.user.first_name : ''", true)
		first = String(r if r != null else "")
	return clean_name("Клуб " + first if first != "" else "Мой клуб")


## A name for the sign: trimmed, at most 16 letters, "" if it has a bad word.
static func clean_name(s: String) -> String:
	var t := s.strip_edges().replace("\n", " ")
	if t.length() > NAME_MAX:
		t = t.left(NAME_MAX).strip_edges()
	var low := t.to_lower()
	for w in BAD_WORDS:
		if low.contains(w):
			return ""
	return t


## The coach's line for a level just built.
static func line(id: String, lv: int) -> String:
	if lv < 1 or lv > max_level(id):
		return ""
	var l: String = TABLE[id]["levels"][lv - 1].get("line", "")
	return l % club_name() if l.contains("%s") else l
