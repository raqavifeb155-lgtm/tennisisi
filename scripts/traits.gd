class_name Traits
## Passive traits (v0.2 G-7): the one catalog of small, readable perks for people on the
## court: the run's opponents now, the academy's juniors and the hero later (stream T adds
## the growth and the character traits to LIST and uses the same API).
##
## A trait is a light aura (an entry like Modifiers.LIST, with trait: true) that every
## opponent of a run comes with, so each of them plays a little differently:
##   id, name, desc          what the card and the TV strip show
##   rarity                  0 common .. 1 rare (the rare auras of Modifiers are 1..3)
##   needs                   {stat, min | max}: tied to his stats (Opponents.stats); he can
##                           only get the trait when it holds, and gets it more often then
##   style                   a play style ("attacker", "counter"...) the trait belongs to
##   named                   a boss's own trait: always his, never rolled for others
##   fx                      ModEffects primitives, applied to the match (and undone)
##   reward                  prize x for beating him (1.05 .. 1.15; fitted so traits add <= 10% to a run)
##   growth                  {stat: +n}: what the trait gives a junior over time (T fills)
##   hidden                  true: the player finds it out on court (T: academy secrets)
##
## Opponent traits live in the lineup next to the auras: lineup[i]["mods"] holds ids of
## both; Modifiers.find / name / desc / card know the traits, so Main's hooks, the card of
## stream D and the bracket need nothing else. Rolled from the run's seed: the same run
## shows the same traits.

const COMMON := 0
const RARE := 1

const SECOND_BASE := 0.15         # a second trait: from round 2 on, this chance + SECOND_STEP a round
const SECOND_STEP := 0.07
const SECOND_MAX := 0.36
const NEED_WEIGHT := 4.0          # a trait that fits his stats is this much likelier

const LIST := [
	# --- Tied to his stats
	{"id": "serve_cannon", "name": "Пушка подачи", "desc": "Подаёт на 10% сильнее", "rarity": RARE, "needs": {"stat": "serve", "min": 7},
		"fx": [["serve_pace", 1, 1.1]], "color": Color(1.0, 0.55, 0.3), "icon": "Пп", "reward": 1.07},
	{"id": "soft_serve", "name": "Подача вполсилы", "desc": "Первый мяч мягче, но точнее", "rarity": COMMON, "needs": {"stat": "serve", "max": 4},
		"fx": [["serve_pace", 1, 0.93], ["opp", "skill", 0.04]], "color": Color(0.75, 0.8, 0.85), "icon": "По", "reward": 1.05},
	{"id": "hole_left", "name": "Дыра слева", "desc": "Слабый бэкхенд: твой виннер ему в бэкхенд — приём стиля", "rarity": COMMON, "needs": {"stat": "backhand", "max": 4},
		"fx": [["style_hole"]], "color": Color(0.45, 0.8, 1.0), "icon": "Дл", "reward": 1.05},
	{"id": "iron_forehand", "name": "Железный форхенд", "desc": "Его удары на 8% быстрее", "rarity": RARE, "needs": {"stat": "forehand", "min": 8},
		"fx": [["shot_pace", 1, 1.08]], "color": Color(0.95, 0.4, 0.3), "icon": "Жф", "reward": 1.07},
	{"id": "net_hawk", "name": "Ястреб у сетки", "desc": "Реагирует на твой удар на 0.04 с раньше", "rarity": RARE, "needs": {"stat": "net", "min": 6},
		"fx": [["reaction", -0.04]], "color": Color(0.7, 0.55, 1.0), "icon": "Яс", "reward": 1.07},
	{"id": "sprinter", "name": "Спринтер", "desc": "Бегает на 8% быстрее", "rarity": COMMON, "needs": {"stat": "speed", "min": 7},
		"fx": [["opp", "speed", 1.08]], "color": Color(1.0, 0.75, 0.3), "icon": "Сп", "reward": 1.06},
	{"id": "short_breath", "name": "Одышка", "desc": "Выносливость на треть меньше", "rarity": COMMON, "needs": {"stat": "stamina", "max": 4},
		"fx": [["opp_stamina", 0.67]], "color": Color(0.55, 0.8, 0.9), "icon": "Од", "reward": 1.05},
	{"id": "iron_lungs", "name": "Железные лёгкие", "desc": "Выносливость в полтора раза больше", "rarity": COMMON, "needs": {"stat": "stamina", "min": 7},
		"fx": [["opp_stamina", 1.5]], "color": Color(0.4, 0.85, 0.6), "icon": "Жл", "reward": 1.06},
	# --- Tied to his play style
	{"id": "counter_punch", "name": "Контратака", "desc": "Читает розыгрыш на 0.03 с раньше, бьёт мягче", "rarity": COMMON, "style": "counter",
		"fx": [["reaction", -0.03], ["shot_pace", 1, 0.96]], "color": Color(0.7, 0.72, 0.78), "icon": "Кн", "reward": 1.05},
	{"id": "gambler", "name": "Рисковый", "desc": "Бьёт на 10% сильнее, но чаще ошибается", "rarity": COMMON, "style": "attacker",
		"fx": [["shot_pace", 1, 1.1], ["opp", "skill", -0.05]], "color": Color(0.95, 0.5, 0.45), "icon": "Рс", "reward": 1.05},
	{"id": "net_rusher", "name": "Атакует сетку", "desc": "Укороченные каждым пятым ударом", "rarity": COMMON, "style": "netrusher",
		"fx": [["echo", 5]], "color": Color(0.8, 0.6, 1.0), "icon": "Ас", "reward": 1.05},
	# --- Anyone
	{"id": "steady_hand", "name": "Ровная рука", "desc": "Реже ошибается", "rarity": COMMON,
		"fx": [["opp", "skill", 0.06]], "color": Color(0.7, 0.85, 0.7), "icon": "Рр", "reward": 1.05},
	{"id": "crowd_fav", "name": "Любимец публики", "desc": "На подъёме: удары на 4% сильнее, ошибается реже", "rarity": COMMON,
		"fx": [["shot_pace", 1, 1.04], ["opp", "skill", 0.04]], "color": Color(1.0, 0.85, 0.35), "icon": "Лп", "reward": 1.05},
	{"id": "mind_reader", "name": "Читает игру", "desc": "Реагирует на твой удар на 0.05 с раньше", "rarity": RARE,
		"fx": [["reaction", -0.05]], "color": Color(0.65, 0.5, 1.0), "icon": "Чи", "reward": 1.08},
	{"id": "hot_head", "name": "Вспыльчивый", "desc": "Подаёт на 6% сильнее, ошибается чаще", "rarity": COMMON,
		"fx": [["serve_pace", 1, 1.06], ["opp", "skill", -0.06]], "color": Color(1.0, 0.45, 0.35), "icon": "Вс", "reward": 1.05},
	# --- A boss's own
	{"id": "king_court", "name": "Король Корта", "desc": "Ничего не отдаёт даром: реагирует раньше, ошибается реже", "rarity": RARE, "named": "djokovic",
		"fx": [["reaction", -0.04], ["opp", "skill", 0.05]], "color": Color(1.0, 0.8, 0.25), "icon": "Кк", "reward": 1.12},
]

## Set by the "style_hole" primitive and read by StyleMeter: the last stroke of the point
## went to the opponent's backhand side.
static var hole_hit := false


# --- The catalog ----------------------------------------------------------------------

## The entry of an id (with the trait's fixed fields filled in), or {}.
static func find(id: String) -> Dictionary:
	for e in LIST:
		if e["id"] == id:
			return _full(e)
	return {}


## The same under the name stream T asked for. (A static "get" would hide Object.get.)
static func entry(id: String) -> Dictionary:
	return find(id)


static func has(id: String) -> bool:
	for e in LIST:
		if e["id"] == id:
			return true
	return false


static func all() -> Array:
	return LIST.map(func(e): return _full(e))


static func ids() -> Array:
	return LIST.map(func(e): return e["id"])


static func name(id: String) -> String:
	var e := find(id)
	return id if e.is_empty() else String(e["name"])


static func desc(id: String) -> String:
	var e := find(id)
	return "" if e.is_empty() else String(e["desc"])


static func _full(e: Dictionary) -> Dictionary:
	var out: Dictionary = e.duplicate()
	out["trait"] = true
	out["target"] = "opponent"
	out["pools"] = ["trait"]
	out["growth"] = e.get("growth", {})
	out["hidden"] = e.get("hidden", false)
	return out


# --- Apply and revert (on the match's ModsHub; the academy will pass its own target) ------

## Runs the trait's primitives on a ModsHub (or anything with its `undo` journal).
static func apply(entry_or_id, target: Node) -> void:
	var e: Dictionary = find(String(entry_or_id)) if entry_or_id is String else entry_or_id
	for f in e.get("fx", []):
		ModEffects.apply(target, f)


static func revert(target: Node) -> void:
	target.revert()


# --- Rolling the opponents' traits ----------------------------------------------------------

## Does a stat condition of a trait hold for these stats?
static func fits(e: Dictionary, stats: Dictionary) -> bool:
	var n: Dictionary = e.get("needs", {})
	if n.is_empty():
		return true
	var v := int(stats.get(n["stat"], 5))
	return v >= int(n.get("min", 0)) and v <= int(n.get("max", 99))


## The traits of opponent i for a run seed: at least one (a boss: his own, always), from
## round 2 on a chance of a second. The same seed gives the same traits.
static func roll(seed_value: int, i: int, opp: Dictionary) -> Array:
	var out: Array = []
	if not Modifiers.enabled or not Modifiers.forced.is_empty():
		return out
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, i, "trait"])
	var stats := Opponents.stats(opp)
	var style := String(opp.get("play_style", ""))
	if opp.get("boss", false):
		for e in LIST:
			if e.get("named", "") == String(opp.get("id", "")):
				out.append(e["id"])
	var n := 1 if out.is_empty() else 0
	if i >= 1 and r.randf() < minf(SECOND_BASE + SECOND_STEP * float(i - 1), SECOND_MAX):
		n += 1
	for k in n:
		var pick := _pick(r, stats, style, out)
		if pick != "":
			out.append(pick)
	return out


static func _pick(r: RandomNumberGenerator, stats: Dictionary, style: String, taken: Array) -> String:
	var weights: Array = []
	var total := 0.0
	for e in LIST:
		var w := 0.0
		if not e.has("named") and not taken.has(e["id"]) and fits(e, stats) and (not e.has("style") or e["style"] == style):
			w = NEED_WEIGHT if (e.has("needs") or e.has("style")) else 1.0
		weights.append(w)
		total += w
	if total <= 0.0:
		return ""
	var x := r.randf() * total
	for k in LIST.size():
		x -= float(weights[k])
		if x <= 0.0 and float(weights[k]) > 0.0:
			return LIST[k]["id"]
	return ""
