class_name Opponents
## Tournament roster: one tennis player per level, the boss in the final. Each one
## teaches a lesson. A profile sets the AI skill (the format is chosen per run) and the
## play style ("play_style", one of PLAY_STYLES: how often the AI attacks, comes to the
## net, plays drop shots and lobs, how much it risks; see scripts/ai/shot_planner.gd).
## The boss phases come with the opponent profiles step of the roadmap.
## Names live only here, so they are easy to swap. "look" dresses them (see Looks).

const ROSTER := [
	{
		"id": "dzumhur", "name": "Дамир Джумхур", "short": "ДЖУМХУР", "short_en": "DZUMHUR", "title": "Уровень 1",
		"lesson": "Мягкий темп, прощает ошибки. Обучение", "skill": 0.0, "play_style": "netrusher",
		"shirt": Color(0.2, 0.45, 0.8),
		"look": {"skin": 3, "hair": Looks.Hair.SHORT, "hair_color": 1, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.NONE, "shirt": 5, "shorts": 3, "accent": 5},
	},
	{
		"id": "basilashvili", "name": "Николоз Басилашвили", "short": "БАСИЛАШВИЛИ", "short_en": "BASILASHVILI", "title": "Уровень 2",
		"lesson": "Лупит всё подряд и ошибается. Урок обороны", "skill": 0.25, "play_style": "attacker",
		"shirt": Color(0.85, 0.85, 0.88),
		"look": {"skin": 3, "hair": Looks.Hair.SHORT, "hair_color": 0, "beard": Looks.Beard.SHORT, "head": Looks.Head.NONE, "shirt": 0, "shorts": 3, "accent": 0},
	},
	{
		"id": "rublev", "name": "Андрей Рублёв", "short": "РУБЛЁВ", "short_en": "RUBLEV", "title": "Уровень 3",
		"lesson": "Тяжёлый форхенд. Урок терпения", "skill": 0.45, "play_style": "attacker",
		"shirt": Color(0.75, 0.2, 0.18),
		"look": {"skin": 1, "hair": Looks.Hair.MESSY, "hair_color": 8, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.HEADBAND, "shirt": 13, "shorts": 3, "accent": 11},
	},
	{
		"id": "zverev", "name": "Саша Зверев", "short": "ЗВЕРЕВ", "short_en": "ZVEREV", "title": "Уровень 4",
		"lesson": "Подача за 220 км/ч. Урок приёма", "skill": 0.62, "play_style": "bomber",
		"shirt": Color(0.12, 0.12, 0.16),
		"look": {"skin": 1, "hair": Looks.Hair.BUN, "hair_color": 5, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.HEADBAND, "shirt": 3, "shorts": 3, "accent": 3},
	},
	{
		"id": "djokovic", "name": "Новак Джокович", "short": "ДЖОКОВИЧ", "short_en": "DJOKOVIC", "title": "Босс · Король Корта",
		"lesson": "Возвращает всё. Финал турнира", "skill": 0.85, "boss": true, "play_style": "counter",
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
	for o in ROSTER:
		if o["id"] == id:
			return o
	return {}


const ROUND_NAMES := ["Первый круг", "Второй круг", "Четвертьфинал", "Полуфинал", "Финал"]
