class_name Opponents
## Tournament roster: one tennis player per level, the boss in the final. Each one
## teaches a lesson. A profile sets the AI skill (the format is chosen per run), the stats
## 1..10 ("stats": serve, forehand, backhand, net, speed, stamina; see stats(): missing
## ones come from the skill tier and the style; OpponentAI plays by them) and the
## play style ("play_style", one of PLAY_STYLES: how often the AI attacks, comes to the
## net, plays drop shots and lobs, how much it risks; see scripts/ai/shot_planner.gd).
## The boss phases come with the opponent profiles step of the roadmap.
## Names live only here, so they are easy to swap. "look" dresses them (see Looks).

const ROSTER := [
	{
		"id": "dzumhur", "name": "Дамир Джумхур", "short": "ДЖУМХУР", "short_en": "DZUMHUR", "title": "Уровень 1",
		"lesson": "Мягкий темп, прощает ошибки. Обучение", "skill": 0.0, "play_style": "netrusher",
		"stats": {"serve": 3, "forehand": 4, "backhand": 3, "net": 5, "speed": 4, "stamina": 4},
		"shirt": Color(0.2, 0.45, 0.8),
		"look": {"skin": 3, "hair": Looks.Hair.SHORT, "hair_color": 1, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.NONE, "shirt": 5, "shorts": 3, "accent": 5},
	},
	{
		"id": "basilashvili", "name": "Николоз Басилашвили", "short": "БАСИЛАШВИЛИ", "short_en": "BASILASHVILI", "title": "Уровень 2",
		"lesson": "Лупит всё подряд и ошибается. Урок обороны", "skill": 0.25, "play_style": "attacker",
		"stats": {"serve": 6, "forehand": 7, "backhand": 5, "net": 4, "speed": 5, "stamina": 4},
		"shirt": Color(0.85, 0.85, 0.88),
		"look": {"skin": 3, "hair": Looks.Hair.SHORT, "hair_color": 0, "beard": Looks.Beard.SHORT, "head": Looks.Head.NONE, "shirt": 0, "shorts": 3, "accent": 0},
	},
	{
		"id": "rublev", "name": "Андрей Рублёв", "short": "РУБЛЁВ", "short_en": "RUBLEV", "title": "Уровень 3",
		"lesson": "Тяжёлый форхенд. Урок терпения", "skill": 0.45, "play_style": "attacker",
		"stats": {"serve": 7, "forehand": 9, "backhand": 6, "net": 5, "speed": 7, "stamina": 7},
		"shirt": Color(0.75, 0.2, 0.18),
		"look": {"skin": 1, "hair": Looks.Hair.MESSY, "hair_color": 8, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.HEADBAND, "shirt": 13, "shorts": 3, "accent": 11},
	},
	{
		"id": "zverev", "name": "Саша Зверев", "short": "ЗВЕРЕВ", "short_en": "ZVEREV", "title": "Уровень 4",
		"lesson": "Подача за 220 км/ч. Урок приёма", "skill": 0.62, "play_style": "bomber",
		"stats": {"serve": 10, "forehand": 7, "backhand": 8, "net": 5, "speed": 7, "stamina": 7},
		"shirt": Color(0.12, 0.12, 0.16),
		"look": {"skin": 1, "hair": Looks.Hair.BUN, "hair_color": 5, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.HEADBAND, "shirt": 3, "shorts": 3, "accent": 3},
	},
	{
		"id": "djokovic", "name": "Новак Джокович", "short": "ДЖОКОВИЧ", "short_en": "DJOKOVIC", "title": "Босс · Король Корта",
		"lesson": "Возвращает всё. Финал турнира", "skill": 0.85, "boss": true, "play_style": "counter",
		"stats": {"serve": 8, "forehand": 9, "backhand": 10, "net": 7, "speed": 10, "stamina": 10},
		"shirt": Color(0.95, 0.75, 0.2),
		"look": {"skin": 3, "hair": Looks.Hair.SHORT, "hair_color": 1, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.NONE, "shirt": 10, "shorts": 3, "accent": 10},
	},
]

## Play styles: the proportions of the AI's decisions (scripts/ai/shot_planner.gd).
##   aggr      chance of going for the open court when the player is pulled wide
##   patience  neutral rally: share of safe cross-court balls
##   change    neutral rally: chance of changing direction down the line
##   approach  a short ball: chance of an approach shot and coming in
##   net_rush  a good neutral ball: chance of coming in behind it anyway
##   drop      the player far behind the baseline: drop shot chance (x how deep)
##   lob       the player at the net: lob (else a passing shot)
##   read      how much it plays on the player's weaker wing once it has seen it
##   risk      error multiplier (going for more misses more)
##   pace      rally pace multiplier; serve: first serve pace multiplier
const PLAY_STYLES := {
	"allcourt": {"name": "Универсал", "aggr": 0.55, "patience": 0.6, "change": 0.3, "approach": 0.4, "net_rush": 0.03, "drop": 0.35, "lob": 0.45, "read": 0.6, "risk": 1.0, "pace": 1.0, "serve": 1.0},
	"attacker": {"name": "Атакующий", "aggr": 0.9, "patience": 0.35, "change": 0.45, "approach": 0.45, "net_rush": 0.04, "drop": 0.15, "lob": 0.3, "read": 0.5, "risk": 1.15, "pace": 1.08, "serve": 1.0},
	"counter": {"name": "Контрпанчер", "aggr": 0.35, "patience": 0.85, "change": 0.25, "approach": 0.15, "net_rush": 0.0, "drop": 0.4, "lob": 0.7, "read": 0.85, "risk": 0.7, "pace": 0.95, "serve": 0.97},
	"netrusher": {"name": "Сетевик", "aggr": 0.6, "patience": 0.4, "change": 0.3, "approach": 0.85, "net_rush": 0.22, "drop": 0.25, "lob": 0.3, "read": 0.5, "risk": 1.05, "pace": 1.0, "serve": 1.0},
	"bomber": {"name": "Бомбардир", "aggr": 0.75, "patience": 0.45, "change": 0.35, "approach": 0.35, "net_rush": 0.05, "drop": 0.12, "lob": 0.3, "read": 0.4, "risk": 1.1, "pace": 1.05, "serve": 1.1},
}
const DEFAULT_STYLE := "allcourt"


## The play style of a roster entry (or of a practice opponent: the all-rounder).
static func play_style(opp: Dictionary) -> Dictionary:
	return PLAY_STYLES.get(String(opp.get("play_style", DEFAULT_STYLE)), PLAY_STYLES[DEFAULT_STYLE])


static func find(id: String) -> Dictionary:
	var all := roster()
	for i in ROSTER.size():
		if all[i]["id"] == id:
			return all[i]
	if id.length() == 4 and id.begins_with("p") and id.substr(1).is_valid_int():
		var r := id.substr(1).to_int()
		if r >= 1 and r <= RosterData.PLAYERS.size():
			return all[ROSTER.size() + r - 1]
	return {}


## Everybody: the five fixed opponents (ROSTER, the tutorial and the boss) and the top-100 of
## RosterData as profiles (ids p001..p100; the twins of the fixed ones carry alias_of). Built
## once; the stats and styles of the hundred are made up from the rank, the same every run.
static var _roster: Array = []


static func roster() -> Array:
	if _roster.is_empty():
		var tier_ranks := {}
		for r in RosterData.PLAYERS:
			var t: Array = tier_ranks.get(r["tier"], [])
			t.append(r["rank"])
			tier_ranks[r["tier"]] = t
		for k in tier_ranks:
			tier_ranks[k].sort()
		var all: Array = []
		for o in ROSTER:
			var named: Dictionary = o.duplicate()
			named["stats"] = stats(o)
			named["tier"] = NAMED_TIERS.get(o["id"], "D")
			all.append(named)
		for r in RosterData.PLAYERS:
			all.append(OpponentGen.from_record(r, tier_ranks))
		_roster = all
	return _roster


## The fixed ones' place in the tiers (the research puts a player of skill .45 in C).
const NAMED_TIERS := {"dzumhur": "E", "basilashvili": "D", "rublev": "C", "zverev": "B", "djokovic": "S"}


## A random player: name, stats, style, looks by seed and tier (OpponentGen.random). opts:
## overpowered, op_chance, weakness (true or a stat key), country, style.
static func random(seed_v: int, tier := "D", opts := {}) -> Dictionary:
	return OpponentGen.random(seed_v, tier, opts)


## The players of a tier of the top-100 (not the twins of the fixed ones).
static func of_tier(tier: String) -> Array:
	var out: Array = []
	for o in roster():
		if o.get("tier", "") == tier and o.has("rank") and not o.has("alias_of"):
			out.append(o)
	return out


## Who stands in the draw of an island, round by round (the last one is the fixed boss): tiers
## by island, a share of the places goes to random players (some of them overpowered, now and
## then with a marked weak spot). A spec per round: {"id": ..} or {"rnd": seed, "tier": .., "opts": ..},
## so a run saves five small dictionaries and gets the same field back (resolve()).
const ISLANDS := {
	"park": {"slots": [["E"], ["E", "D"], ["D"], ["D"]], "random": 0.35, "tutor": "dzumhur"},
	"clay": {"slots": [["D"], ["D", "C"], ["C"], ["C"]], "random": 0.3},
	"grass": {"slots": [["C", "B"], ["B"], ["B"], ["B", "A"]], "random": 0.3},
	"paris": {"slots": [["B", "A"], ["A"], ["A"], ["A", "S"]], "random": 0.25},
}
const BOSS_ID := "djokovic"


static func draw(location: String, seed_v: int, newbie := false) -> Array:
	var isl: Dictionary = ISLANDS.get(location, ISLANDS["park"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out: Array = []
	var used := {}
	var slots: Array = isl["slots"]
	for i in slots.size():
		var tiers: Array = slots[i]
		var tier: String = tiers[rng.randi_range(0, tiers.size() - 1)]
		if i == 0 and isl.has("tutor") and (newbie or rng.randf() < 0.25):
			out.append({"id": isl["tutor"]})  # the first match of the first island: the old tutorial
			continue
		if rng.randf() < float(isl["random"]):
			var opts := {"weakness": rng.randf() < 0.5}
			if i < 2:
				opts["overpowered"] = false  # nobody is a monster in the first two rounds
			out.append({"rnd": rng.randi() % 1000000 + 1, "tier": tier, "opts": opts})
			continue
		var pool := of_tier(tier)
		var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var guard := 0
		while used.has(pick["id"]) and guard < 20:
			pick = pool[rng.randi_range(0, pool.size() - 1)]
			guard += 1
		used[pick["id"]] = true
		out.append({"id": pick["id"]})
	out.append({"id": BOSS_ID})
	return out


static func resolve(spec: Dictionary) -> Dictionary:
	if spec.has("rnd"):
		return random(int(spec["rnd"]), String(spec.get("tier", "D")), spec.get("opts", {}))
	return find(String(spec.get("id", BOSS_ID)))


## The opponent's stats, 1..10 (D-5, hub-economy spec 10). OpponentAI plays by them:
##   serve     pace and placement (weak: slow, to the middle of the box; strong: corners, the T)
##   forehand, backhand  per wing: timing, contact, pace and errors
##   net       how often it comes in, how well it volleys
##   speed     run speed, reaction, reach on the return
##   stamina   how fast the stamina "health" (scripts/run) drains
const STAT_KEYS := ["serve", "forehand", "backhand", "net", "speed", "stamina"]
const STAT_NAMES := {"serve": "Подача", "forehand": "Форхенд", "backhand": "Бэкхенд", "net": "Сетка", "speed": "Скорость", "stamina": "Выносливость"}
## A style leans the tier's stats (when the profile does not set them).
const STYLE_STATS := {
	"allcourt": {},
	"attacker": {"forehand": 2, "backhand": -1, "stamina": -1},
	"counter": {"speed": 2, "backhand": 1, "stamina": 2, "serve": -1, "net": -1},
	"netrusher": {"net": 3, "serve": 1, "backhand": -1, "stamina": -1},
	"bomber": {"serve": 3, "forehand": 1, "speed": -1, "net": -1, "stamina": -1},
}
## The card's captions: "Слабая подача" at or below WEAK, "Сильный форхенд" at or above STRONG.
const WEAK := 3
const STRONG := 8
const WEAK_WORDS := {"serve": "Слабая подача", "forehand": "Слабый форхенд", "backhand": "Слабый бэкхенд", "net": "Не любит сетку", "speed": "Медленный", "stamina": "Быстро устаёт"}
const STRONG_WORDS := {"serve": "Сильная подача", "forehand": "Сильный форхенд", "backhand": "Сильный бэкхенд", "net": "Опасен у сетки", "speed": "Быстрые ноги", "stamina": "Железные лёгкие"}


## Stats 1..10 of a roster entry. Missing ones: 2 + 7 x skill (the tier; `skill` is used
## for a profile without one, e.g. practice), leaned by the play style.
static func stats(opp: Dictionary, skill := 0.5) -> Dictionary:
	var sk := float(opp.get("skill", skill))
	var lean: Dictionary = STYLE_STATS.get(String(opp.get("play_style", DEFAULT_STYLE)), {})
	var given: Dictionary = opp.get("stats", {})
	var out := {}
	for k in STAT_KEYS:
		var v: float = given.get(k, roundf(2.0 + 7.0 * sk) + float(lean.get(k, 0)))
		out[k] = clampi(roundi(v), 1, 10)
	return out


## The opponents keep up with the player (D-5): a veteran of level 8 is not a beginner, and
## the first island's opponent must not be a punching bag for him. From ADAPT_FROM on, every
## opponent is at least as strong as the FLOOR for the player's average skill level (the weak
## ones are lifted to it, the strong ones stay), and everybody gains a little on top (ADD).
## It moves the AI skill, and with it all six stats (OpponentAI.stat() follows
## Tuning.ai_skill). A beginner is spared the other way round (EASE): the stats of the
## roster are tuned for a player who has levelled, and D-1's numbers must stand for the new one.
const ADAPT_FROM := 2.0
const EASE_UNTIL := 4.0            # a beginner is spared up to this average level (D-1: he must be able to win points)
const FLOOR_MAX := 0.7
static var round_floor := 0.3      # extra floor per round (--adapt-round=)
const ADD_MAX := 0.1
static var floor_slope := 0.055    # floor of the AI skill per skill level above ADAPT_FROM
static var add_slope := 0.014      # and the gain for all (--adapt-floor= / --adapt-add= for the bot)
static var ease_max := 0.25        # what a level-0 player is spared: the AI skill below the roster's (--adapt-ease=)


## The player's strength as the opponents see it: the average level of the skills.
static func player_level() -> float:
	var sum := 0.0
	for id in Skills.LIST:
		sum += float(Skills.level(id))
	return sum / float(Skills.LIST.size())


## The AI skill an opponent of this roster skill plays with against a player of this level
## (-1: the current one). Modifiers and gear come on top (Tournament.modifier_value).
## The boss only gets the floor (he is the top of the roster already: no gain on top).
## D-8: the draw's opponents of an island are all of its tiers, so the floor grows with the round
## (x round_floor per round): the later the round, the more of a veteran's level it asks.
static func adapted_skill(skill: float, level := -1.0, boss := false, round_i := 0) -> float:
	var lv := player_level() if level < 0.0 else level
	var over := maxf(lv - ADAPT_FROM, 0.0)
	var gain := 0.0 if boss else minf(over * add_slope, ADD_MAX)
	var floor_k := 1.0 + round_floor * float(round_i)
	return clampf(maxf(skill, minf(over * floor_slope * floor_k, FLOOR_MAX)) + gain, 0.0, 1.0)


## What a beginner is spared: stats points x 1/9 taken off every stat of the opponent (OpponentAI
## keeps it apart from the skill: the weakest opponent's skill is already 0, his stats can still drop).
static func spared(level := -1.0) -> float:
	var lv := player_level() if level < 0.0 else level
	return ease_max * clampf(1.0 - lv / EASE_UNTIL, 0.0, 1.0)


## The stats as the opponent plays them against this player (what the card shows).
static func shown_stats(opp: Dictionary, level := -1.0, round_i := 0) -> Dictionary:
	var st := stats(opp)
	var sk := float(opp.get("skill", 0.5))
	var shift := (adapted_skill(sk, level, bool(opp.get("boss", false)), round_i) - sk - spared(level)) * 9.0
	for k in STAT_KEYS:
		st[k] = clampi(roundi(float(st[k]) + shift), 1, 10)
	return st


## "Слабая подача · Сильный форхенд": the weakest and the strongest points worth a word.
static func captions(st: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var lo := ""
	var hi := ""
	for k in STAT_KEYS:
		if int(st[k]) <= WEAK and (lo == "" or int(st[k]) < int(st[lo])):
			lo = k
		if int(st[k]) >= STRONG and (hi == "" or int(st[k]) > int(st[hi])):
			hi = k
	if lo != "":
		out.append(WEAK_WORDS[lo])
	if hi != "":
		out.append(STRONG_WORDS[hi])
	return out


const ROUND_NAMES := ["Первый круг", "Второй круг", "Четвертьфинал", "Полуфинал", "Финал"]
