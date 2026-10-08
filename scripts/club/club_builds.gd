class_name ClubBuilds
## The club's constructions (docs/club/H2_SPEC.md 2, CLUB_BRIEF 3): five places, their
## levels, prices, small perks with caps and the coach's line for each. Data, not the
## building code: ClubWorld builds what a level shows (_level_<id>), this table says what
## it costs and gives. Gold is spent and saved here; the 3D only shows it afterwards.
##
## Saved in SaveData.club: "levels" {id: level}, "color" 0..3, "name", "spent".

static var CLUB_PRICE_SCALE := 2.4   # A-6: with Items.PRICE_SCALE, set by the economy sim (income x0.5, the club ~65-75 h)

## Hub spec 13 (the long build): every construction has 5 levels and its price row is
## base x 1 / 2.2 / 5 / 11.5 / 26 (rounded to 5), the base 30-60 gold; the whole club costs
## about 17 000. Levels 4 and 5 are built over 2 and 3 runs ("runs"): the gold goes at
## once, scaffolding stands, the level is up after that many played tournaments.
const PRICE_STEPS := [1.0, 2.2, 5.0, 11.5, 26.0]

## id -> {name, place (ClubPlaces id where it stands), unlock, start (level 0 as it is),
## levels: [level 1 .. 5]}.
## A level: title, now (what you see), perk ("" = none), price, line (the coach, <= 60),
## runs (levels 4-5: tournaments to wait). Perk numbers live in the arrays below the table.
const TABLE := {
	"court": {
		"name": "Главный корт", "place": "court", "unlock": "", "start": "трещины и выцветшие линии",
		"levels": [
			{"title": "Свежий хард", "now": "свежий хард, яркие линии", "perk": "", "price": 40,
				"line": "Свежая краска! Мяч теперь отскакивает честно"},
			{"title": "Сетка и фонари", "now": "новая сетка и забор, лавки, фонари", "perk": "", "price": 90,
				"line": "Новая сетка. Теперь не стыдно звать соперников"},
			{"title": "Цвет клуба", "now": "покрытие в цвет клуба (4 на выбор)", "perk": "", "price": 200,
				"line": "Наш цвет! Теперь это точно наш корт"},
			{"title": "Логотип", "now": "логотип в центре, имя на заднике", "perk": "", "price": 460, "runs": 2,
				"line": "Логотип на корте. Как у больших"},
			{"title": "Ночной корт", "now": "вышка судьи, мачты с прожекторами, табло", "perk": "", "price": 1040, "runs": 3,
				"line": "Прожекторы и вышка судьи. Это уже турнир!"},
		],
	},
	"stands": {
		"name": "Трибуны", "place": "court", "unlock": "", "start": "колышки с лентой",
		"levels": [
			{"title": "Две скамейки", "now": "две скамейки у корта", "perk": "+2% золота за победы", "bonus": 0.02, "price": 50,
				"line": "Две скамейки. Уже кто-то придёт посмотреть"},
			{"title": "Трибуна", "now": "трибуна вдоль корта", "perk": "+4% золота за победы", "bonus": 0.04, "price": 110,
				"line": "Трибуна! Будет кому хлопать"},
			{"title": "Болельщики", "now": "вторая трибуна, болельщики в цвете клуба", "perk": "+6% золота за победы", "bonus": 0.06, "price": 250,
				"line": "Трибуны готовы. Теперь тебя слышно с набережной"},
			{"title": "Козырёк и флаги", "now": "козырёк и флаги клуба", "perk": "+8% золота за победы", "bonus": 0.08, "price": 575, "runs": 2,
				"line": "Флаги клуба. Красиво же"},
			{"title": "Полные трибуны", "now": "полные трибуны, шумят громче", "perk": "+10% золота за победы", "bonus": 0.10, "price": 1300, "runs": 3,
				"line": "Аншлаг! Слышишь, как шумят?"},
		],
	},
	"gate": {
		"name": "Вход", "place": "gate", "unlock": "", "start": "калитка и табличка «Public Courts»",
		"levels": [
			{"title": "Ворота и вывеска", "now": "ворота с деревянной вывеской с именем клуба", "perk": "", "price": 45,
				"line": "%s. Звучит!"},
			{"title": "Парковка", "now": "парковка и хэтчбек", "perk": "", "price": 100,
				"line": "Своя парковка. Солидно"},
			{"title": "Неон", "now": "каменные ворота, неоновая вывеска", "perk": "", "price": 225,
				"line": "Неон! Вечером нас видно с моста"},
			{"title": "Спорткар", "now": "спорткар на парковке", "perk": "", "price": 520, "runs": 2,
				"line": "Спорткар. Ну ты даёшь"},
			{"title": "Красная дорожка", "now": "красная дорожка, флаги и золотые шары на воротах", "perk": "", "price": 1170, "runs": 3,
				"line": "Красная дорожка. Встречаем как чемпиона!"},
		],
	},
	# The shop (hub spec 2): what the window shows grows with it (SHOP_STOCK, SHOP_RARITY
	# for stream A's Shop.stock(); free rerolls and cheaper strings come from the arrays).
	"shop": {
		"name": "Магазин", "place": "shop", "unlock": "played", "start": "ларёк: 2 вещи, до редкой",
		"levels": [
			{"title": "Лавка", "now": "лавка: 3 вещи до эпической, струны", "perk": "3 вещи, струны", "price": 60,
				"line": "Лавка! Теперь и струны перетянем"},
			{"title": "Бутик", "now": "бутик: до легендарной, витрина светится", "perk": "до легендарной", "price": 130,
				"line": "Бутик. Витрина светится — красота"},
			{"title": "Салон", "now": "салон: 4 вещи, один переброс витрины бесплатно", "perk": "4 вещи, 1 бесплатный переброс", "price": 300,
				"line": "Салон. Первый переброс витрины за мой счёт"},
			{"title": "Пассаж", "now": "пассаж: второй зал и мастерская струн", "perk": "струны на 10% дешевле", "price": 690, "runs": 2,
				"line": "Пассаж! Мастерская перетянет дешевле"},
			{"title": "Универмаг", "now": "универмаг: два зала, неон и стойка струн", "perk": "струны на 20% дешевле, 2 переброса", "price": 1560, "runs": 3,
				"line": "Универмаг. Таких в городе больше нет"},
		],
	},
	# The locker room (hub spec 1): lockers grow with it, up to 4; a better room insures
	# the legendary things cheaper (INSURANCE_DISCOUNT).
	"locker": {
		"name": "Раздевалка", "place": "locker", "unlock": "played", "start": "скамейка и один шкафчик (1 ячейка)",
		"levels": [
			{"title": "Ряд шкафчиков", "now": "ряд шкафчиков и зеркало", "perk": "2 ячейки шкафчика", "price": 40,
				"line": "Ещё шкафчик. Можно хранить две вещи"},
			{"title": "Стена ракеток", "now": "стена ракеток: твои вещи висят", "perk": "3 ячейки, страховка −10%", "price": 90,
				"line": "Стена ракеток. Есть чем похвастаться"},
			{"title": "Гардероб", "now": "гардероб с подсветкой", "perk": "3 ячейки, страховка −10%", "price": 200,
				"line": "Гардероб с подсветкой. Как у профи"},
			{"title": "Душевая", "now": "душевая, вторая стена шкафчиков", "perk": "4 ячейки, страховка −25%", "price": 460, "runs": 2,
				"line": "Душевая и ещё шкафчики. Живём!"},
			{"title": "VIP-раздевалка", "now": "кожаные диваны, зеркала, золотые ручки", "perk": "4 ячейки, страховка −25%", "price": 1040, "runs": 3,
				"line": "VIP-раздевалка. Даже полотенца с вышивкой"},
		],
	},
	# The coach's room (new): rest between points and the quests' gold.
	"coach": {
		"name": "Тренерская", "place": "coach", "unlock": "", "start": "стул и доска с мелом",
		"levels": [
			{"title": "Коврик и гантели", "now": "коврик и гантели", "perk": "отдых +1%, задания +5% золота", "price": 40,
				"line": "Гантели и коврик. Дыхание восстановим быстрее"},
			{"title": "Тренажёры", "now": "беговая дорожка и тренажёр", "perk": "отдых +2%, задания +10% золота", "price": 90,
				"line": "Тренажёры. Выносливость скажет спасибо"},
			{"title": "Видеоразбор", "now": "экран с видеоразбором матчей", "perk": "отдых +3%, задания +15% золота", "price": 200,
				"line": "Видеоразбор. Теперь видно каждую ошибку"},
			{"title": "Массажный стол", "now": "массажный стол и аптечка", "perk": "отдых +4%, задания +20% золота", "price": 460, "runs": 2,
				"line": "Массажный стол. Ноги как новые"},
			{"title": "Штаб", "now": "штаб: тактическая доска, кубки тренера", "perk": "отдых +5%, задания +25% золота", "price": 1040, "runs": 3,
				"line": "Штаб. Тут решаются турниры"},
		],
	},
	"trophy": {
		"name": "Трофейная", "place": "trophy", "unlock": "played", "start": "пустое место",
		"levels": [
			{"title": "Полка", "now": "полка: кубок за каждый титул", "perk": "Кодекс (скоро)", "price": 45,
				"line": "Полка для кубков. Давай её заполним"},
			{"title": "Витрина", "now": "витрина: лучшие вещи светятся", "perk": "счётчик удачи (скоро)", "price": 100,
				"line": "Витрина. Пусть все видят, чем играешь"},
			{"title": "Зал кубков", "now": "зал кубков, прожектор на лучшую вещь", "perk": "", "price": 225,
				"line": "Зал кубков. Тут и музей открыть можно"},
			{"title": "Стена славы", "now": "стена с фото чемпионов и колонны с кубками", "perk": "", "price": 520, "runs": 2,
				"line": "Стена славы. Здесь будет твоё лицо"},
			{"title": "Зал славы", "now": "золотая статуя игрока под прожектором", "perk": "", "price": 1170, "runs": 3,
				"line": "Твоя статуя. Только не зазнавайся"},
		],
	},
	"bar": {
		"name": "Бар", "place": "bar", "unlock": "title", "start": "стол с рулеткой под зонтом",
		"levels": [
			{"title": "Ларёк", "now": "ларёк с газировкой", "perk": "ставка до 50", "price": 50,
				"line": "Газировка есть. Ставки покрупнее"},
			{"title": "Бар", "now": "бар с зонтиками и стульями", "perk": "ставка до 150", "price": 110,
				"line": "Бар с зонтиками. Курорт!"},
			{"title": "Терраса", "now": "терраса у воды, неон", "perk": "ставка до 300", "price": 250,
				"line": "Терраса у воды. Лучшее место в клубе"},
			{"title": "Лаундж", "now": "стойка с табуретами, полка с бутылками", "perk": "ставка до 500", "price": 575, "runs": 2,
				"line": "Лаундж. Ставки по-крупному"},
			{"title": "VIP-зал", "now": "VIP-диваны, пальмы и прожекторы", "perk": "ставка до 1000", "price": 1300, "runs": 3,
				"line": "VIP-зал. Здесь делают большие ставки"},
		],
	},
}
const ORDER := ["court", "stands", "gate", "shop", "locker", "coach", "trophy", "bar"]

## What a level of a construction gives, indexed by the level 0..5.
const SHOP_STOCK := [2, 3, 3, 4, 4, 4]                 # things in the window
const SHOP_RARITY := [1, 2, 3, 3, 3, 3]                # Gear.RARE / EPIC / LEGENDARY
const SHOP_FREE_REROLLS := [0, 0, 0, 1, 1, 2]
const RESTRING_DISCOUNT := [0.0, 0.0, 0.0, 0.0, 0.10, 0.20]
const LOCKER_SLOTS := [1, 2, 3, 3, 4, 4]
const INSURANCE_DISCOUNT := [0.0, 0.0, 0.10, 0.10, 0.25, 0.25]
const RECOVERY_BONUS := [0.0, 0.01, 0.02, 0.03, 0.04, 0.05]  # added to the rest between points
const QUEST_GOLD := [0.0, 0.05, 0.10, 0.15, 0.20, 0.25]

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
	return is_open(id) and not is_building(id) and not next(id).is_empty() and SaveData.gold >= next_price(id)


static func affordable_count() -> int:
	var n := 0
	for id in ORDER:
		if ClubLots.is_placed(id) and can_afford(id):   # a building of a lot is bought on its lot first (ClubLots.build)
			n += 1
	return n


## Buys the next level: the gold goes and the save is written now, before any show. A
## level that takes runs (4 and 5) only puts the scaffolding up: it is ready after that
## many played tournaments (complete_ready, at the next visit to the club).
static func buy(id: String) -> bool:
	if not TABLE.has(id) or not can_afford(id):
		return false
	var price := next_price(id)
	var runs := int(next(id).get("runs", 0))
	SaveData.gold -= price
	SaveData.club["spent"] = int(SaveData.club.get("spent", 0)) + price
	if runs > 0:
		var b: Dictionary = building().duplicate()
		b[id] = {"level": level(id) + 1, "until": SaveData.played + runs}
		SaveData.club["building"] = b
		SaveData.save()
		return true
	var levels: Dictionary = SaveData.club.get("levels", {}).duplicate()
	levels[id] = level(id) + 1
	SaveData.club["levels"] = levels
	if id == "gate" and levels[id] == 1 and String(SaveData.club.get("name", "")) == "":
		SaveData.club["name"] = default_name()
	SaveData.save()
	return true


# --- The long build (hub spec 13) ----------------------------------------------------

## The constructions on scaffolding: {id: {level, until}} (until: the SaveData.played
## value at which the level is ready). Paid already; saved with the club.
static func building() -> Dictionary:
	var b = SaveData.club.get("building", {})
	return b if b is Dictionary else {}


static func is_building(id: String) -> bool:
	return building().has(id)


## Tournaments still to play before the scaffolding comes down (0: ready, or not building).
static func runs_left(id: String) -> int:
	if not is_building(id):
		return 0
	return maxi(int(building()[id].get("until", 0)) - SaveData.played, 0)


## Takes the scaffolding down where the runs are played: the level goes up. Returns the
## ids done; the club shows the build moment for each when it opens.
static func complete_ready() -> Array:
	var done := []
	var b: Dictionary = building().duplicate()
	for id in ORDER:
		if b.has(id) and SaveData.played >= int(b[id].get("until", 0)):
			done.append(id)
	if done.is_empty():
		return done
	var levels: Dictionary = SaveData.club.get("levels", {}).duplicate()
	for id in done:
		levels[id] = maxi(int(levels.get(id, 0)), int(b[id].get("level", 0)))
		b.erase(id)
	SaveData.club["levels"] = levels
	SaveData.club["building"] = b
	SaveData.save()
	return done


## "СТРОИТСЯ · ещё 2 забега" over the scaffolding.
static func scaffold_text(id: String) -> String:
	var n := ClubBuilds.runs_left(id)
	if n <= 0:
		return "ГОТОВО"
	return "СТРОИТСЯ\nещё %d %s" % [n, runs_word(n)]


static func runs_word(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "забег"
	if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20):
		return "забега"
	return "забегов"


# --- What the levels give -------------------------------------------------------------

static func _at(arr: Array, id: String):
	return arr[clampi(level(id), 0, arr.size() - 1)]


## The stands' perk: more gold for a won match (0.02 a level, at most 0.10).
static func gold_win_bonus() -> float:
	if not utility_enabled:
		return 0.0
	var lv := level("stands")
	return minf(float(TABLE["stands"]["levels"][lv - 1].get("bonus", 0.0)) if lv > 0 else 0.0, 0.10)


## The coach's room: extra rest between points (added to Skills.stamina_rest "point").
static func recovery_bonus() -> float:
	return float(_at(RECOVERY_BONUS, "coach")) if utility_enabled else 0.0


## The coach's room: the quests pay this much more gold (0.05 a level).
static func quest_gold_bonus() -> float:
	return float(_at(QUEST_GOLD, "coach"))


## Locker slots (hub spec 1): 1 at the start, growing to 4.
static func locker_slots() -> int:
	return int(_at(LOCKER_SLOTS, "locker"))


## The locker room cuts the insurance of a legendary thing (0.10 / 0.25).
static func insurance_discount() -> float:
	return float(_at(INSURANCE_DISCOUNT, "locker"))


## How many things the shop's window shows (hub spec 2): 2 / 3 / 3 / 4.
static func shop_stock() -> int:
	return int(_at(SHOP_STOCK, "shop"))


## The rarest thing the shop sells (Gear.RARE / EPIC / LEGENDARY; never mythic).
static func shop_max_rarity() -> int:
	return int(_at(SHOP_RARITY, "shop"))


## Free window rerolls a run gives (the salon and above).
static func shop_free_rerolls() -> int:
	return int(_at(SHOP_FREE_REROLLS, "shop"))


## The strings cost this much less (0.10 / 0.20 at the top of the shop).
static func restring_discount() -> float:
	return float(_at(RESTRING_DISCOUNT, "shop"))


## The chips the bar puts on the desk at its level: the bigger the bar, the bigger the chips.
const BAR_CHIPS := [10, 25, 50, 100, 250, 500, 1000]


static func bar_chips() -> Array:
	var limit := bet_limit()
	return BAR_CHIPS.filter(func(c): return c <= limit)


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
