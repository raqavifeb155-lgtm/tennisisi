class_name OpponentGen
## Opponents by the hundred (v0.2 D-8): the top-100 of RosterData turned into opponent profiles
## (the same keys as Opponents.ROSTER) and a generator of random players with random stats,
## now and then overpowered. Everything is deterministic by seed: the same run, the same field.
## Used by Opponents.roster() / Opponents.random() / Opponents.draw(); the academy takes its
## pupils from Opponents.random too.

## AI skill band of every tier (docs/roster/TOP100_RESEARCH.md 4): S is the best.
const TIERS := ["E", "D", "C", "B", "A", "S"]
const TIER_BAND := {"E": [0.0, 0.2], "D": [0.2, 0.35], "C": [0.35, 0.5], "B": [0.5, 0.65], "A": [0.65, 0.8], "S": [0.8, 0.95]}
## Share of the random players who are overpowered (opts.op_chance overrides).
const OP_CHANCE := 0.03
## The spread of a stat around the tier's: +-SPREAD, and a lean from the play style.
const SPREAD := 1.6

## First names and surnames (Cyrillic, Latin for the court calls) by country. Made up: common
## sounding, nobody in particular.
const NAMES := {
	"ITA": {"first": ["Марко", "Лука", "Паоло", "Джанни", "Стефано", "Маттео", "Чиро"], "last": [["Росселли", "ROSSELLI"], ["Феранти", "FERANTI"], ["Моретто", "MORETTO"], ["Бианчи", "BIANCHI"], ["Конти", "CONTI"], ["Ломбарди", "LOMBARDI"], ["Греко", "GRECO"]]},
	"ESP": {"first": ["Пабло", "Диего", "Рауль", "Серхио", "Мигель", "Адриан", "Икер"], "last": [["Наварро", "NAVARRO"], ["Кастильо", "CASTILLO"], ["Ортега", "ORTEGA"], ["Рамос", "RAMOS"], ["Бланко", "BLANCO"], ["Видал", "VIDAL"], ["Серрано", "SERRANO"]]},
	"FRA": {"first": ["Люк", "Тео", "Антуан", "Матис", "Реми", "Гаспар", "Бенуа"], "last": [["Дюваль", "DUVAL"], ["Моро", "MOREAU"], ["Лавинь", "LAVIGNE"], ["Фонтен", "FONTAINE"], ["Руссо", "ROUSSEAU"], ["Берже", "BERGER"], ["Лакур", "LACOURT"]]},
	"USA": {"first": ["Тайлер", "Брэд", "Кайл", "Джейк", "Остин", "Колтон", "Райан"], "last": [["Миллер", "MILLER"], ["Хадсон", "HUDSON"], ["Кармайкл", "CARMICHAEL"], ["Бейкер", "BAKER"], ["Тёрнер", "TURNER"], ["Фостер", "FOSTER"], ["Рэндалл", "RANDALL"]]},
	"GER": {"first": ["Ян", "Лукас", "Фабиан", "Тило", "Маркус", "Йонас", "Ларс"], "last": [["Хартман", "HARTMANN"], ["Бауэр", "BAUER"], ["Кнолль", "KNOLL"], ["Брандт", "BRANDT"], ["Штейнер", "STEINER"], ["Фогель", "VOGEL"], ["Лангер", "LANGER"]]},
	"RUS": {"first": ["Артём", "Глеб", "Роман", "Тимур", "Егор", "Платон", "Ильдар"], "last": [["Воронов", "VORONOV"], ["Лазарев", "LAZAREV"], ["Беляков", "BELYAKOV"], ["Гаврилов", "GAVRILOV"], ["Селезнёв", "SELEZNEV"], ["Ковалёв", "KOVALEV"], ["Тарасов", "TARASOV"]]},
	"ARG": {"first": ["Матиас", "Федерико", "Николас", "Факундо", "Лаутаро", "Сантьяго", "Эмилио"], "last": [["Пересо", "PERESO"], ["Ривера", "RIVERA"], ["Сабатини", "SABATINI"], ["Монтес", "MONTES"], ["Гальярдо", "GALLARDO"], ["Ибаньес", "IBANEZ"], ["Кордеро", "CORDERO"]]},
	"GBR": {"first": ["Оливер", "Гарри", "Джек", "Эдвард", "Чарли", "Руфус", "Нил"], "last": [["Эшфорд", "ASHFORD"], ["Беннет", "BENNETT"], ["Хиллман", "HILLMAN"], ["Престон", "PRESTON"], ["Уэллс", "WELLS"], ["Кроуфорд", "CRAWFORD"], ["Дрэйк", "DRAKE"]]},
	"AUS": {"first": ["Джош", "Лиам", "Кэмерон", "Блейк", "Дилан", "Мэтт", "Тревор"], "last": [["Салливан", "SULLIVAN"], ["Макгрэт", "MCGRATH"], ["Харпер", "HARPER"], ["Дуглас", "DOUGLAS"], ["Эллиот", "ELLIOT"], ["Купер", "COOPER"], ["Нолан", "NOLAN"]]},
	"SRB": {"first": ["Душан", "Милош", "Никола", "Лазар", "Предраг", "Бранко", "Огнен"], "last": [["Попович", "POPOVIC"], ["Стоянович", "STOJANOVIC"], ["Лукич", "LUKIC"], ["Мариянович", "MARIJANOVIC"], ["Ристич", "RISTIC"], ["Янкович", "JANKOVIC"], ["Милетич", "MILETIC"]]},
	"CZE": {"first": ["Томаш", "Ондржей", "Мартин", "Властимил", "Якуб", "Зденек", "Павел"], "last": [["Новак", "NOVAK"], ["Кратохвил", "KRATOCHVIL"], ["Прохазка", "PROCHAZKA"], ["Влчек", "VLCEK"], ["Горак", "HORAK"], ["Бенеш", "BENES"], ["Урбан", "URBAN"]]},
	"JPN": {"first": ["Кэнта", "Рёта", "Юто", "Сота", "Хаято", "Дайки", "Кэйсукэ"], "last": [["Такаяма", "TAKAYAMA"], ["Исикава", "ISHIKAWA"], ["Нагата", "NAGATA"], ["Морита", "MORITA"], ["Хаяси", "HAYASHI"], ["Фудзимото", "FUJIMOTO"], ["Ямада", "YAMADA"]]},
	"BRA": {"first": ["Гуилерме", "Рафаэл", "Бруно", "Тьяго", "Лукас", "Диого", "Матеус"], "last": [["Силва", "SILVA"], ["Баррозу", "BARROSO"], ["Фрейтас", "FREITAS"], ["Карвалью", "CARVALHO"], ["Моура", "MOURA"], ["Пиньейру", "PINHEIRO"], ["Азеведу", "AZEVEDO"]]},
	"CAN": {"first": ["Итан", "Ной", "Логан", "Гэвин", "Люк", "Оуэн", "Расс"], "last": [["Тремблей", "TREMBLAY"], ["Макдональд", "MACDONALD"], ["Грэм", "GRAHAM"], ["Бушар", "BOUCHARD"], ["Сен-Пьер", "SAINT-PIERRE"], ["Кэмпбелл", "CAMPBELL"], ["Лавуа", "LAVOIE"]]},
	"NED": {"first": ["Йорис", "Тим", "Кес", "Рюд", "Сандер", "Бас", "Мартейн"], "last": [["Янсен", "JANSEN"], ["Влеминг", "VLEMING"], ["Ван Дейк", "VAN DIJK"], ["Бёйс", "BUIJS"], ["Схоутен", "SCHOUTEN"], ["Хофман", "HOFMAN"], ["Мейер", "MEIJER"]]},
	"SWE": {"first": ["Эрик", "Густав", "Нильс", "Оскар", "Йохан", "Альвин", "Андерс"], "last": [["Линдберг", "LINDBERG"], ["Экстрём", "EKSTROM"], ["Бергман", "BERGMAN"], ["Нюберг", "NYBERG"], ["Хольм", "HOLM"], ["Сандберг", "SANDBERG"], ["Викстрём", "WIKSTROM"]]},
}
## The countries a random player may come from, with the weight of the real top-100.
const COUNTRY_WEIGHT := {"USA": 5, "FRA": 4, "ITA": 4, "ESP": 4, "ARG": 3, "GBR": 3, "GER": 3, "RUS": 3, "AUS": 2, "CZE": 2, "SRB": 2, "CAN": 1, "NED": 1, "JPN": 2, "BRA": 1, "SWE": 1}

const CYR_TO_LAT := {"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya", "-": "-", " ": " "}


## A Cyrillic surname in Latin capitals, for the court calls ("СЕНЕР" -> "SENER").
static func translit(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		out += String(CYR_TO_LAT.get(ch, ch))
	return out.to_upper()


static func tier_index(tier: String) -> int:
	return maxi(TIERS.find(tier), 0)


## One RosterData record as an opponent profile. The stats and the style are made up once and
## for all from the rank (the same every run); the tier gives the skill, linear by rank within it.
static func from_record(r: Dictionary, tier_ranks: Dictionary) -> Dictionary:
	var tier := String(r["tier"])
	var band: Array = TIER_BAND[tier]
	var ranks: Array = tier_ranks.get(tier, [r["rank"]])
	var pos := float(ranks.find(r["rank"])) / maxf(float(ranks.size() - 1), 1.0)
	var skill := lerpf(float(band[1]), float(band[0]), pos)  # the best rank of the tier is the strongest
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + int(r["rank"])
	var style := _pick_style(rng, tier)
	var o := {
		"id": "p%03d" % int(r["rank"]), "name": r["name"], "short": r["short"], "short_en": translit(String(r["short"])),
		"title": "Тир %s · №%d" % [tier, int(r["rank"])], "lesson": "", "skill": skill, "play_style": style,
		"tier": tier, "rank": int(r["rank"]), "country": r["country"], "left": r["left"], "one_hand": r["one_hand"],
		"look": r["look"], "shirt": Looks.kit(r["look"], "shirt"),
		"stats": make_stats(rng, skill, style, {}),
	}
	if r.has("alias_of"):
		o["alias_of"] = r["alias_of"]
	o["lesson"] = lesson_of(o["stats"], style)
	return o


## Six stats from the tier's skill, the style's lean and a spread. opts: weak (a stat key: it is
## dropped to 1-2), op (the player is overpowered: +2 all round, one or two stats at 10).
static func make_stats(rng: RandomNumberGenerator, skill: float, style: String, opts: Dictionary) -> Dictionary:
	var lean: Dictionary = Opponents.STYLE_STATS.get(style, {})
	var out := {}
	for k in Opponents.STAT_KEYS:
		var v := 2.0 + 7.0 * skill + float(lean.get(k, 0)) + rng.randf_range(-SPREAD, SPREAD)
		if opts.get("op", false):
			v += 2.0
		out[k] = clampi(roundi(v), 1, 10)
	if opts.get("op", false):
		var keys: Array = Opponents.STAT_KEYS.duplicate()
		for n in rng.randi_range(1, 2):
			var k: String = keys.pop_at(rng.randi_range(0, keys.size() - 1))
			out[k] = 10
	var weak := String(opts.get("weak", ""))
	if weak != "" and out.has(weak):
		out[weak] = rng.randi_range(1, 2)
	return out


static func _pick_style(rng: RandomNumberGenerator, tier: String) -> String:
	var ids: Array = ["allcourt", "attacker", "counter", "netrusher", "bomber"]
	var w: Array = [0.2, 0.25, 0.2, 0.15, 0.2]
	if tier == "S" or tier == "A":
		w = [0.3, 0.2, 0.25, 0.05, 0.2]
	var x := rng.randf()
	for i in ids.size():
		x -= float(w[i])
		if x <= 0.0:
			return ids[i]
	return ids[0]


## "Слабая подача · Сильный форхенд" as the card's one-liner under the name.
static func lesson_of(st: Dictionary, style: String) -> String:
	var caps := Opponents.captions(st)
	var s := String(Opponents.PLAY_STYLES.get(style, Opponents.PLAY_STYLES[Opponents.DEFAULT_STYLE])["name"])
	if caps.is_empty():
		return s
	var text := ", ".join(caps).to_lower()
	return "%s. %s%s" % [s, text.substr(0, 1).to_upper(), text.substr(1)]


static func _weighted_country(rng: RandomNumberGenerator) -> String:
	var total := 0
	for c in COUNTRY_WEIGHT:
		total += int(COUNTRY_WEIGHT[c])
	var x := rng.randi_range(1, total)
	for c in COUNTRY_WEIGHT:
		x -= int(COUNTRY_WEIGHT[c])
		if x <= 0:
			return c
	return "USA"


## A random player of a tier. Deterministic by seed. opts: overpowered (true/false forces it,
## absent = a OP_CHANCE roll, op_chance changes it), weakness (true: a random stat is the explicit
## weak spot, or a stat key), country (a NAMES key), style (a PLAY_STYLES id).
static func random(seed_v: int, tier := "D", opts := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	tier = tier if TIER_BAND.has(tier) else "D"
	var band: Array = TIER_BAND[tier]
	var skill := rng.randf_range(float(band[0]), float(band[1]))
	var country := String(opts.get("country", _weighted_country(rng)))
	if not NAMES.has(country):
		country = "USA"
	var pool: Dictionary = NAMES[country]
	var last: Array = pool["last"][rng.randi_range(0, pool["last"].size() - 1)]
	var name := "%s %s" % [pool["first"][rng.randi_range(0, pool["first"].size() - 1)], last[0]]
	var style := String(opts.get("style", _pick_style(rng, tier)))
	if not Opponents.PLAY_STYLES.has(style):
		style = Opponents.DEFAULT_STYLE
	var op: bool
	if opts.has("overpowered"):
		op = bool(opts["overpowered"])
	else:
		op = rng.randf() < float(opts.get("op_chance", OP_CHANCE))
	var weak := ""
	var wk = opts.get("weakness", false)
	if wk is String and Opponents.STAT_KEYS.has(wk):
		weak = wk
	elif wk == true:
		weak = Opponents.STAT_KEYS[rng.randi_range(0, Opponents.STAT_KEYS.size() - 1)]
	var stats := make_stats(rng, skill + (0.08 if op else 0.0), style, {"op": op, "weak": weak})
	var look := Looks.random(rng)
	look["head"] = rng.randi_range(0, 4) if rng.randf() < 0.55 else 0
	var o := {
		"id": "rnd%d" % seed_v, "name": name, "short": last[0].to_upper(), "short_en": last[1], "title": "Тир %s" % tier,
		"lesson": "", "skill": clampf(skill + (0.08 if op else 0.0), 0.0, 1.0), "play_style": style, "tier": tier, "country": country,
		"left": rng.randf() < 0.12, "one_hand": rng.randf() < 0.1, "look": look, "shirt": Looks.kit(look, "shirt"),
		"stats": stats, "random": true,
	}
	if op:
		o["op"] = true
	if weak != "":
		o["weak_stat"] = weak
	o["lesson"] = lesson_of(stats, style) + ("  Монстр!" if op else "")
	return o
