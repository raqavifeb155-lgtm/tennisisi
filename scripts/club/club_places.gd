class_name ClubPlaces
## The places of the club (docs/club/CLUB_BRIEF.md 2, HANDOFF 9.1): where each stands,
## its circle on the ground, when it opens and - per level - the one button it shows.
## Data only; ClubWorld builds them, Club and ClubHud use them. What a place does at a
## level is still being decided with the owner: change it here, not in the code.
##
## Coordinates: the main court's centre is the origin, -z toward the river (as in
## scenery.gd). The camera looks north from the gate, as the old menu did.
##   unlock  ""        open from the start
##           "played"  after the first run
##           "title"   after the first title
##           "never"   not yet (a sign stands there instead of a button)
##   cam     a room's own camera framing (pavilions): "pos" and "look", else the follow cam
##   travel  false: not in quick travel
##   build   the construction (ClubBuilds, H2) whose level is this place's level
##   levels  what the place offers at level i: label, action ("" = no button: the sign
##           shows), note (what is here now), sign, and its own keys (bar: bet_limit,
##           shop: offers). A level inherits the keys of the levels below it; a level
##           past the list repeats the last one.

const LIST := [
	{
		"id": "court", "name": "Главный корт", "pos": Vector3(0, 0, 14.0), "r": 2.2,
		"unlock": "", "sign": "", "build": "court",
		"levels": [
			# The main screen: Club.place_buttons turns it into Новая игра / Продолжить.
			{"label": "Новая игра", "action": "club_tournament", "note": "Облезлый общественный корт: трещины, выцветшие линии"},
		],
	},
	{
		# The ball machine (ClubWorld.ball_machine() on the far half shoots at this
		# baseline): its drill (BallMachine), every stroke in turn, trains a little. The
		# free game on the club court is the quiet button above it (Club.place_buttons).
		"id": "machine", "name": "Пушка", "pos": Vector3(3.0, 0, 8.5), "r": 1.6,
		"unlock": "", "sign": "", "travel": false,
		"levels": [
			{"label": "Пушка", "action": "drill", "note": "Тренировка с пушкой: каждый удар по очереди"},
		],
	},
	{
		"id": "coach", "name": "Тренерская", "pos": Vector3(16, 0, 26), "r": 1.8,
		"unlock": "", "sign": "", "build": "coach",
		"cam": {"pos": Vector3(16, 10.5, 35.0), "look": Vector3(16, 0.4, 25.6)},
		"levels": [
			{"label": "Навыки", "action": "character", "note": "Стул и доска с мелом"},
			{"note": "Коврик и гантели"},
			{"note": "Беговая дорожка и тренажёр"},
			{"note": "Экран с видеоразбором"},
			{"note": "Массажный стол и аптечка"},
			{"note": "Штаб: тактическая доска и кубки тренера"},
		],
	},
	{
		# The stands are a building of a lot now (ClubLots). The circle is in front of them,
		# on the court's side (they are drawn at x 9.8..13.2, facing the court; the circle is
		# the pivot, so on a lot it is the lot's centre and the stands sit behind it). No lot,
		# no such place.
		"id": "stands", "name": "Трибуны", "pos": Vector3(8.0, 0, -9.0), "r": 2.0,
		"unlock": "", "sign": "", "build": "stands",
		"levels": [
			{"label": "Трибуны", "action": "club_place", "note": "Колышки с лентой"},
			{"note": "Две скамейки у корта"},
			{"note": "Трибуна вдоль корта"},
			{"note": "Вторая трибуна, болельщики в цвете клуба"},
			{"note": "Козырёк и флаги клуба"},
			{"note": "Полные трибуны, шумят громче"},
		],
	},
	{
		"id": "gate", "name": "Вход", "pos": Vector3(0, 0, 36), "r": 1.8,
		"unlock": "", "sign": "Стройка · скоро", "build": "gate",
		"levels": [
			{"label": "Прораб", "action": "club_foreman", "note": "Калитка и табличка «Public Courts»"},
		],
	},
	{
		"id": "locker", "name": "Раздевалка", "pos": Vector3(-14, 0, 26), "r": 1.8,
		"unlock": "played", "sign": "Раздевалка · после первого забега", "build": "locker",
		"cam": {"pos": Vector3(-14, 10.5, 35.0), "look": Vector3(-14, 0.4, 25.6)},
		"levels": [
			# club_locker: stream A's locker screen (RunLocker.ui_action) when it exists,
			# else the look / backhand / controls screen as before.
			{"label": "Раздевалка", "action": "club_locker", "note": "Скамейка и один шкафчик"},
			{"label": "Раздевалка", "action": "club_locker", "note": "Ряд шкафчиков и зеркало"},
			{"label": "Раздевалка", "action": "club_locker", "note": "Стена ракеток"},
			{"label": "Раздевалка", "action": "club_locker", "note": "Гардероб с подсветкой"},
			{"label": "Раздевалка", "action": "club_locker", "note": "Душевая, вторая стена шкафчиков"},
			{"label": "Раздевалка", "action": "club_locker", "note": "VIP: кожаные диваны, золотые ручки"},
		],
	},
	{
		# New in v0.2 (HANDOFF 9.1): buy, sell, change mods. The trade itself is stream
		# A's; until then the rows say "скоро".
		"id": "shop", "name": "Магазин вещей", "pos": Vector3(22, 0, 2), "r": 1.8,
		"unlock": "", "sign": "", "build": "shop",   # T: the shop stands from the start (the owner: court + shop)
		"cam": {"pos": Vector3(22, 10.5, 11.0), "look": Vector3(22, 0.4, 1.6)},
		"levels": [
			{"label": "Магазин", "action": "club_shop", "note": "Прилавок и стойка с ракетками",
				"offers": [
					{"id": "buy", "title": "Купить", "desc": "вещи на следующий забег", "action": ""},
					{"id": "sell", "title": "Продать", "desc": "цена по редкости и уровню вещи", "action": ""},
					{"id": "mods", "title": "Струны", "desc": "перебросить свойство вещи", "action": ""},
				]},
			{"label": "Магазин", "action": "club_shop", "note": "Лавка: 3 вещи до эпической, струны"},
			{"label": "Магазин", "action": "club_shop", "note": "Бутик: до легендарной, витрина светится"},
			{"label": "Магазин", "action": "club_shop", "note": "Салон: 4 вещи, один переброс бесплатно"},
			{"label": "Магазин", "action": "club_shop", "note": "Пассаж: мастерская струн, струны дешевле на 10%"},
			{"label": "Магазин", "action": "club_shop", "note": "Универмаг: два зала, струны дешевле на 20%"},
		],
	},
	{
		"id": "trophy", "name": "Трофейная", "pos": Vector3(-18, 0, -26), "r": 1.8,
		"unlock": "played", "sign": "Трофейная · после первого забега", "build": "trophy",
		"levels": [
			{"label": "", "action": "", "sign": "Трофейная · строится у прораба", "note": "Пустое место"},
			{"label": "Трофейная", "action": "club_place", "note": "Полка: кубок за каждый титул"},
			{"label": "Трофейная", "action": "club_place", "note": "Витрина: лучшие вещи светятся цветом редкости"},
			{"label": "Трофейная", "action": "club_place", "note": "Зал кубков, прожектор на лучшую вещь"},
			{"label": "Трофейная", "action": "club_place", "note": "Стена славы: фото чемпионов, колонны с кубками"},
			{"label": "Трофейная", "action": "club_place", "note": "Зал славы: золотая статуя под прожектором"},
		],
	},
	{
		# The Totalizator: a table with a 3D roulette (ClubRoulette) at the bar. bet_limit:
		# the biggest chip the bar takes (and never more than Bets.max_stake).
		"id": "bar", "name": "Бар-Тотализатор", "pos": Vector3(20, 0, -30), "r": 1.8,
		"unlock": "title", "sign": "Бар · после первого титула", "build": "bar",
		"levels": [
			{"label": "Тотализатор", "action": "club_roulette", "note": "Стол с рулеткой под зонтом", "bet_limit": 25},
			{"label": "Тотализатор", "action": "club_roulette", "note": "Ларёк с газировкой", "bet_limit": 50},
			{"label": "Тотализатор", "action": "club_roulette", "note": "Бар с зонтиками и стульями", "bet_limit": 150},
			{"label": "Тотализатор", "action": "club_roulette", "note": "Терраса у воды, неон", "bet_limit": 300},
			{"label": "Тотализатор", "action": "club_roulette", "note": "Лаундж: стойка с табуретами", "bet_limit": 500},
			{"label": "Тотализатор", "action": "club_roulette", "note": "VIP-зал: диваны, пальмы, прожекторы", "bet_limit": 1000},
		],
	},
	{
		# Blackjack on the bar's terrace, right of the roulette (hub spec 6). The scene and
		# the game are stream E's (ClubBlackjack.open(club)); until then a 'скоро' card.
		"id": "blackjack", "name": "Блэкджек", "pos": Vector3(26.5, 0, -29.6), "r": 1.6,
		"unlock": "title", "sign": "", "build": "bar",
		"levels": [
			{"label": "Блэкджек", "action": "club_blackjack", "note": "Стол на террасе бара: 6 колод, блэкджек 3:2, Perfect Pairs и 21+3", "soon": true},
		],
	},
	{
		"id": "arena", "name": "Площадка арены", "pos": Vector3(-22, 0, 0), "r": 2.0,
		"unlock": "", "sign": "Арена · скоро",
		"levels": [
			{"label": "Арена", "action": "club_place", "note": "Забор стройки и гравий. Здесь будет крытая арена: свои матчи, покрытие на выбор, онлайн у себя"},
			{"label": "Арена", "action": "club_place", "note": "Ангар, один фонарь, корт хард"},
			{"label": "Арена", "action": "club_place", "note": "Зал, трибуна на одну сторону, грунт"},
			{"label": "Арена", "action": "club_place", "note": "Арена: трибуны по кругу, табло, трава"},
		],
	},
	{
		# The academy (T-3): a building of a lot (ClubLots, home: the east lawn n7), its own
		# levels (Academy.LEVELS). The button opens the coach's office: the students.
		"id": "academy", "name": "Академия", "pos": Vector3(32, 0, 14), "r": 2.0,
		"unlock": "", "sign": "", "build": "academy",
		"levels": [
			{"label": "Ученики", "action": "club_students", "note": "Лужайка под академию"},
			{"note": "Детская площадка: мини-корт, лавка, стенка"},
			{"note": "Домик-раздевалка и корзина мячей"},
			{"note": "Корт академии с фонарями, доска расписания"},
			{"note": "Общежитие: два этажа, флаги клуба"},
			{"note": "Центр подготовки: стеклянный зал, табло с именами"},
		],
	},
	{
		# Reserved (ACADEMY_LEGACY_TZ 6): the coach's booth behind the near baseline, at the
		# court's corner, for the juniors' matches. A sign only.
		"id": "booth", "name": "Будка тренера", "pos": Vector3(-6.8, 0, 15.6), "r": 1.4,
		"unlock": "never", "sign": "Будка тренера · скоро", "travel": false,
		"levels": [{"label": "Будка", "action": "", "note": "Место под будку тренера"}],
	},
	{
		"id": "board", "name": "Доска-табло", "pos": Vector3(22, 0, -14), "r": 1.8,
		"unlock": "never", "sign": "Онлайн · скоро",
		"levels": [
			{"label": "Онлайн", "action": "", "note": "Пробковая доска с листками"},
		],
	},
]


## The data of a place as written in LIST (where it stood before lots).
static func base(id: String) -> Dictionary:
	for p in LIST:
		if p["id"] == id:
			return p
	return {}


## The place now. A building of a lot is where its lot is (once built); an empty lot is a
## place too, "lot_<id>"; an unbuilt type is found where it would have stood.
static func find(id: String) -> Dictionary:
	if id.begins_with("lot_"):
		var l := ClubLots.lot(id.substr(4))
		return ClubLots.lot_place(l) if not l.is_empty() else {}
	var p := base(id)
	var t := ClubLots.owner_type(id) if not p.is_empty() else ""
	if t != "" and ClubLots.lot_of(t) != "":
		return ClubLots.moved(p, t)
	return p


## The places of the club as they are: the fixed ones, the buildings of lots on their lots
## (the ones not built are not there), and the empty lots (each a place: «Построить»).
static func all() -> Array:
	var out: Array = []
	for p in LIST:
		var t := ClubLots.owner_type(p["id"])
		if t == "":
			out.append(p)
		elif ClubLots.lot_of(t) != "":
			out.append(ClubLots.moved(p, t))
	for l in ClubLots.LOTS:
		if ClubLots.type_at(String(l["id"])) == "":
			out.append(ClubLots.lot_place(l))
	return out


## The place's level: its construction's level (H2), 0 while nothing is built.
static func level(id: String) -> int:
	var p := base(id)
	if p.is_empty() and id.begins_with("lot_"):
		return 0
	var levels: Dictionary = SaveData.club.get("levels", {})
	return int(levels.get(p.get("build", id), 0))


## What the place offers at a level: its base keys with the level's on top (the last
## level described repeats). Always has id, label and action.
static func state(id: String, lv := -1) -> Dictionary:
	var p := find(id)
	if p.is_empty():
		return {}
	if lv < 0:
		lv = level(id)
	var out := {}
	for k in p:
		if k != "levels":
			out[k] = p[k]
	# A level inherits the ones below it and overrides what it names.
	var levels: Array = p.get("levels", [])
	for i in range(0, clampi(lv, 0, levels.size() - 1) + 1 if not levels.is_empty() else 0):
		var l: Dictionary = levels[i]
		for k in l:
			out[k] = l[k]
	out["level"] = lv
	out["label"] = out.get("label", "")
	out["action"] = out.get("action", "")
	return out


## Whether the place works yet (has its button) for a player with this progress.
static func is_open(place: Dictionary, played: int, titles: int) -> bool:
	match String(place.get("unlock", "never")):
		"":
			return true
		"played":
			return played >= 1
		"title":
			return titles >= 1
	return false


## The place whose circle holds `pos`, or {}.
static func at(pos: Vector3) -> Dictionary:
	for p in all():
		var c: Vector3 = p["pos"]
		if Vector2(pos.x - c.x, pos.z - c.z).length() <= float(p["r"]):
			return p
	return {}
