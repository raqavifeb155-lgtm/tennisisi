class_name Traits
extends RefCounted
## Passive traits: ONE catalog for the people on court (docs/superpowers/specs/2026-10-09-tycoon.md
## 3.9) - the run's opponents (stream G-7), the academy's students (stream T) and later the hero
## through the legacy (ACADEMY_LEGACY_TZ 5). Two sections of the same file and class:
##
## 1. On court, the opponents' auras (G-7, `src: "G"`): LIST, rolled on the drawn opponent from
##    the run's seed (roll), applied to the match's ModsHub (apply). find / has / all / ids / name /
##    desc / roll keep stream G's meaning (Modifiers, ModsHub, the bracket, D-5's card use them).
## 2. The students (T): CATALOG of stat, growth, style and character traits, SYNERGIES (two make a
##    third, hidden) and hidden ones revealed by matches, trainings or events (def / text / shown /
##    reveal / mods_of / growth_of / ctx / apply_side / roll_student).
##
## def(id) reads both: a student's record, or an opponent's in the same shape (kind "opp", `opp`:
## its fx, src "G"). An id in both (serve_cannon, iron_lungs) is the same trait: its student record
## on the student's side, its G entry (fx) when an opponent has it.
##
## --- Opponents' traits (G-7):
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
##
## --- Students' records. A trait is data:
##
##   name, desc   what the card says (desc <= 60 characters)
##   kind         "stat" | "growth" | "style" | "char" | "synergy"
##   tier         1..3: how rare and how dear (the price of a student, the weight when rolled)
##   mods         the keys of Skills.PERKS (serve_pace, forehand_spin, stamina_pool...): added to
##                Skills.mods_layer for a match (apply_side)
##   style        deltas of OpponentAI.style / JuniorBot (aggr, patience, approach, net_rush, drop...)
##   growth       the academy's: xp_mult, ceiling_add, late_after + late_mult, camp_discount
##   ctx          situational (the match asks Traits.ctx): breakpoint, tiebreak, start, crowd,
##                surface.<id>: a multiplier on the timing window while the situation holds
##   reveal       when a hidden one shows itself: {matches: N, trainings: N, event: "breakpoint"}
##                (every given condition must hold); the trait works before that, the card says «???»
##
## A student keeps {"traits": [{"id", "hidden"}], "revealed": [ids]}; the synergies are not
## stored: two traits together make a third (SYNERGIES), hidden until they show.

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


## What an id nobody knows is called on screen: a code word is never shown (owner, 10.10).
const UNKNOWN_NAME := "Особая черта"
const UNKNOWN_DESC := "Подробности раскроются в игре"


## The shown name of any trait id (an opponent's, a student's), or UNKNOWN_NAME: never the id.
static func name(id: String) -> String:
	var d := def(id)
	return UNKNOWN_NAME if d.is_empty() else String(d.get("name", UNKNOWN_NAME))


static func desc(id: String) -> String:
	var d := def(id)
	return "" if d.is_empty() else String(d.get("desc", ""))


static func _full(e: Dictionary) -> Dictionary:
	var out: Dictionary = e.duplicate()
	out["trait"] = true
	out["kind"] = "opp"
	out["src"] = "G"
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


# === The students' traits (stream T) =================================================================

const CATALOG := {
	# --- stats ---
	"serve_cannon": {"name": "Пушка подачи", "desc": "Подача +10% скорости", "kind": "stat", "tier": 2, "mods": {"serve_pace": 0.10}, "reveal": {"matches": 2}},
	"serve_precise": {"name": "Точная подача", "desc": "Разброс подачи −25%", "kind": "stat", "tier": 1, "mods": {"serve_scatter": -0.25}, "reveal": {"matches": 2}},
	"heavy_fh": {"name": "Тяжёлый форхенд", "desc": "Вращение справа +25%", "kind": "stat", "tier": 1, "mods": {"forehand_spin": 0.25}, "reveal": {"matches": 3}},
	"flat_bh": {"name": "Плоский бэкхенд", "desc": "Бэкхенд +10% скорости", "kind": "stat", "tier": 1, "mods": {"backhand_pace": 0.10}, "reveal": {"matches": 3}},
	"soft_hands": {"name": "Чуткие руки", "desc": "Окно касания +20%", "kind": "stat", "tier": 1, "mods": {"touch_window": 0.20}, "reveal": {"matches": 3}},
	"fast_legs": {"name": "Быстрые ноги", "desc": "Бег +6%", "kind": "stat", "tier": 2, "mods": {"run_speed": 0.06}, "reveal": {"trainings": 4}},
	"iron_lungs": {"name": "Железные лёгкие", "desc": "Выносливость +15%", "kind": "stat", "tier": 2, "mods": {"stamina_pool": 0.15}, "reveal": {"trainings": 4}},
	"long_reach": {"name": "Дальний мяч", "desc": "Сетка: скорость и окно +10%", "kind": "stat", "tier": 1, "mods": {"net_pace": 0.10, "net_window": 0.10}, "reveal": {"matches": 3}},
	"tall": {"name": "Высокий", "desc": "Подача +8%, бег −3%", "kind": "stat", "tier": 1, "mods": {"serve_pace": 0.08, "run_speed": -0.03}, "reveal": {"trainings": 2}},
	"short": {"name": "Невысокий", "desc": "Бег +5%, подача −5%", "kind": "stat", "tier": 1, "mods": {"run_speed": 0.05, "serve_pace": -0.05}, "reveal": {"trainings": 2}},
	"marathon": {"name": "Марафонец", "desc": "Выносливость +10%, форхенд −4%", "kind": "stat", "tier": 1, "mods": {"stamina_pool": 0.10, "forehand_pace": -0.04}, "reveal": {"trainings": 3}},
	# --- growth ---
	"late_bloom": {"name": "Поздний расцвет", "desc": "Медленно, после 10 тренировок ×1,5", "kind": "growth", "tier": 3, "growth": {"xp_mult": 0.7, "late_after": 10, "late_mult": 1.5}, "reveal": {"trainings": 6}},
	"talent": {"name": "Талант", "desc": "Потолок роста +1", "kind": "growth", "tier": 3, "growth": {"ceiling_add": 1}, "reveal": {"trainings": 5}},
	"hard_worker": {"name": "Трудяга", "desc": "Рост +15%, потолок −1", "kind": "growth", "tier": 1, "growth": {"xp_mult": 1.15, "ceiling_add": -1}, "reveal": {"trainings": 3}},
	"prodigy": {"name": "Вундеркинд", "desc": "Быстрый старт +30%, потолок −1", "kind": "growth", "tier": 2, "growth": {"xp_mult": 1.3, "ceiling_add": -1}, "reveal": {"trainings": 2}},
	"coachs_pet": {"name": "Любимец тренера", "desc": "Сборы дешевле на 25%", "kind": "growth", "tier": 1, "growth": {"camp_discount": 0.25}, "reveal": {"trainings": 3}},
	"fragile": {"name": "Хрупкий", "desc": "Рост +20%, выносливость −10%", "kind": "growth", "tier": 1, "mods": {"stamina_pool": -0.10}, "growth": {"xp_mult": 1.2}, "reveal": {"trainings": 3}},
	# --- style ---
	"netrusher": {"name": "Сетевик", "desc": "Часто выходит к сетке", "kind": "style", "tier": 1, "style": {"approach": 0.35, "net_rush": 0.10}, "reveal": {"matches": 2}},
	"bomber": {"name": "Бомбардир", "desc": "Атакует и бьёт подачей", "kind": "style", "tier": 2, "style": {"aggr": 0.25, "serve": 0.05}, "reveal": {"matches": 2}},
	"counter": {"name": "Контрпанчер", "desc": "Терпелив, редко ошибается", "kind": "style", "tier": 1, "style": {"patience": 0.30, "risk": -0.15}, "reveal": {"matches": 2}},
	"allround": {"name": "Универсал", "desc": "Все окна +3%", "kind": "style", "tier": 2, "mods": {"forehand_window": 0.03, "backhand_window": 0.03, "serve_window": 0.03, "net_window": 0.03, "touch_window": 0.03}, "reveal": {"matches": 3}},
	"drop_master": {"name": "Мастер укороток", "desc": "Любит укоротки, касание +10%", "kind": "style", "tier": 2, "style": {"drop": 0.30}, "mods": {"touch_window": 0.10}, "reveal": {"matches": 3}},
	"clay_lover": {"name": "Любит грунт", "desc": "+8% на грунте, −5% на траве", "kind": "style", "tier": 1, "ctx": {"surface.clay": 0.08, "surface.grass": -0.05}, "reveal": {"matches": 4}},
	"grass_lover": {"name": "Любит траву", "desc": "+8% на траве, −5% на грунте", "kind": "style", "tier": 1, "ctx": {"surface.grass": 0.08, "surface.clay": -0.05}, "reveal": {"matches": 4}},
	# --- character ---
	"cool": {"name": "Хладнокровный", "desc": "Брейк-пойнты +12%, старт −5%", "kind": "char", "tier": 2, "ctx": {"breakpoint": 0.12, "start": -0.05}, "reveal": {"event": "breakpoint"}},
	"nervous": {"name": "Нервный", "desc": "Старт +8%, тай-брейк −10%", "kind": "char", "tier": 1, "ctx": {"start": 0.08, "tiebreak": -0.10}, "reveal": {"event": "tiebreak"}},
	"fighter": {"name": "Боец", "desc": "Быстрее отдыхает между очками", "kind": "char", "tier": 2, "mods": {"stamina_rest": 0.03}, "reveal": {"matches": 4}},
	"showman": {"name": "Звёздная болезнь", "desc": "+10% при зрителях, −5% без них", "kind": "char", "tier": 2, "ctx": {"crowd": 0.10, "alone": -0.05}, "reveal": {"matches": 3}},
	"crowd_fav": {"name": "Любит публику", "desc": "Трибуны дают ×2 золота", "kind": "char", "tier": 1, "club": {"stands_bonus": 1.0}, "reveal": {"matches": 3}},
	# --- synergies (two traits make a third, hidden until they show) ---
	"ace_machine": {"name": "Ас-машина", "desc": "Подача +8%, окно подачи +15%", "kind": "synergy", "tier": 3, "mods": {"serve_pace": 0.08, "serve_window": 0.15}, "reveal": {"matches": 2}},
	"net_predator": {"name": "Хищник у сетки", "desc": "Сетка: окно +20%, чаще выходит", "kind": "synergy", "tier": 3, "mods": {"net_window": 0.20}, "style": {"approach": 0.15}, "reveal": {"matches": 2}},
	"steel_nerves": {"name": "Стальные нервы", "desc": "Брейк-пойнты +10%, усталость −", "kind": "synergy", "tier": 3, "ctx": {"breakpoint": 0.10}, "mods": {"stamina_drain": -0.10}, "reveal": {"matches": 2}},
	"cut_diamond": {"name": "Огранённый алмаз", "desc": "Потолок +2 после 10 тренировок", "kind": "synergy", "tier": 3, "growth": {"ceiling_add": 2, "ceiling_after": 10}, "reveal": {"trainings": 8}},
	"the_wall": {"name": "Стена", "desc": "Ошибки −15% в долгих розыгрышах", "kind": "synergy", "tier": 3, "mods": {"forehand_scatter": -0.15, "backhand_scatter": -0.15}, "reveal": {"matches": 2}},
	"sparks": {"name": "Спички", "desc": "Форхенд +12%, разброс +10%", "kind": "synergy", "tier": 3, "mods": {"forehand_pace": 0.12, "forehand_scatter": 0.10}, "reveal": {"matches": 2}},
}

## [a, b, the one they make]
const SYNERGIES := [
	["serve_cannon", "long_reach", "ace_machine"],
	["netrusher", "fast_legs", "net_predator"],
	["cool", "iron_lungs", "steel_nerves"],
	["talent", "late_bloom", "cut_diamond"],
	["counter", "fast_legs", "the_wall"],
	["bomber", "nervous", "sparks"],
]

const KIND_NAMES := {"stat": "Игра", "growth": "Рост", "style": "Стиль", "char": "Характер", "synergy": "Синергия", "opp": "Соперник"}


## A trait by id from the one catalog: a student's record, or else an opponent's (G) in the
## same shape ({name, desc, kind: "opp", tier, opp: its fx, src: "G"}); {} if neither.
static func def(id: String) -> Dictionary:
	if CATALOG.has(id):
		return CATALOG[id]
	var e := find(id)
	if e.is_empty():
		return {}
	return {"name": e["name"], "desc": e["desc"], "kind": "opp", "tier": 1 + int(e.get("rarity", COMMON)) * 2,
		"opp": e.get("fx", []), "src": "G", "hidden": false, "reveal": {}}


## The ids of the students' records (ids() is the opponents' list, kept for stream G).
static func student_ids() -> Array:
	return CATALOG.keys()


static func base_ids() -> Array:
	return CATALOG.keys().filter(func(i: String) -> bool: return CATALOG[i]["kind"] != "synergy")


static func text(id: String) -> String:
	var d := def(id)
	return "%s · %s" % [d["name"], d["desc"]] if not d.is_empty() else UNKNOWN_NAME


# --- A student's traits ------------------------------------------------------------------------

## The synergies two or more of `base` make.
static func synergies_of(base: Array) -> Array:
	var out: Array = []
	for s in SYNERGIES:
		if base.has(s[0]) and base.has(s[1]) and not out.has(s[2]):
			out.append(s[2])
	return out


static func _base(st: Dictionary) -> Array:
	var out: Array = []
	for t in st.get("traits", []):
		out.append(String(t["id"]))
	return out


## Every trait that works: what the student has and the synergies of it.
static func all_ids(st: Dictionary) -> Array:
	var b := _base(st)
	return b + synergies_of(b)


## Does the card show it? A trait that was never hidden does; a hidden one (and any synergy)
## once it has revealed itself.
static func is_shown(st: Dictionary, id: String) -> bool:
	if (st.get("revealed", []) as Array).has(id):
		return true
	for t in st.get("traits", []):
		if t["id"] == id:
			return not bool(t.get("hidden", false))
	return false


static func shown(st: Dictionary) -> Array:
	return all_ids(st).filter(func(i: String) -> bool: return is_shown(st, i))


## How many are still «???» (the base ones hidden and the synergies not found).
static func hidden_count(st: Dictionary) -> int:
	return all_ids(st).size() - shown(st).size()


## Shows a hidden trait the moment its condition holds. `event` is "" for the plain check
## after a match or a training, else what has just happened ("breakpoint", "tiebreak").
## Returns the ids that came out now.
static func reveal(st: Dictionary, event := "") -> Array:
	var out: Array = []
	var rev: Array = st.get("revealed", [])
	for id in all_ids(st):
		if is_shown(st, id):
			continue
		var r: Dictionary = def(id).get("reveal", {})
		var ok := not r.is_empty()
		if r.has("matches") and int(st.get("matches", 0)) < int(r["matches"]):
			ok = false
		if r.has("trainings") and int(st.get("trainings", 0)) < int(r["trainings"]):
			ok = false
		if r.has("event") and String(r["event"]) != event:
			ok = false
		if ok:
			rev.append(id)
			out.append(id)
	st["revealed"] = rev
	return out


## An entry of the student's card for a trait: "Пушка подачи · подача +10%" or "???".
static func line(st: Dictionary, id: String) -> String:
	return text(id) if is_shown(st, id) else "???"


# --- What they do ------------------------------------------------------------------------------

## The sum of the Skills mods of the traits.
static func mods_of(trait_ids: Array) -> Dictionary:
	var out := {}
	for id in trait_ids:
		for k in def(id).get("mods", {}):
			out[k] = float(out.get(k, 0.0)) + float(def(id)["mods"][k])
	return out


static func style_of(trait_ids: Array) -> Dictionary:
	var out := {}
	for id in trait_ids:
		for k in def(id).get("style", {}):
			out[k] = float(out.get(k, 0.0)) + float(def(id)["style"][k])
	return out


## The academy's growth numbers of the traits at `trainings` done: xp_mult (product),
## ceiling_add, camp_discount.
static func growth_of(trait_ids: Array, trainings := 0) -> Dictionary:
	var out := {"xp_mult": 1.0, "ceiling_add": 0, "camp_discount": 0.0}
	for id in trait_ids:
		var g: Dictionary = def(id).get("growth", {})
		var m := float(g.get("xp_mult", 1.0))
		if g.has("late_after") and trainings >= int(g["late_after"]):
			m = float(g.get("late_mult", 1.0))
		out["xp_mult"] = float(out["xp_mult"]) * m
		if not g.has("ceiling_after") or trainings >= int(g["ceiling_after"]):
			out["ceiling_add"] = int(out["ceiling_add"]) + int(g.get("ceiling_add", 0))
		out["camp_discount"] = float(out["camp_discount"]) + float(g.get("camp_discount", 0.0))
	return out


## A situational multiplier on the timing window: the sum of the traits' `ctx[key]`
## (key "breakpoint", "tiebreak", "start", "crowd", "alone", "surface.clay"...).
static func ctx(trait_ids: Array, key: String) -> float:
	var v := 0.0
	for id in trait_ids:
		v += float(def(id).get("ctx", {}).get(key, 0.0))
	return v


## Puts the traits' mods on Skills.mods_layer for a match; returns what to hand to
## undo_side when it ends (the way ModEffects puts things back).
static func apply_side(trait_ids: Array) -> Array:
	var undo: Array = []
	var m := mods_of(trait_ids)
	for k in m:
		Skills.mods_layer[k] = float(Skills.mods_layer.get(k, 0.0)) + float(m[k])
		undo.append([k, float(m[k])])
	return undo


static func undo_side(undo: Array) -> void:
	for u in undo:
		var k: String = u[0]
		Skills.mods_layer[k] = float(Skills.mods_layer.get(k, 0.0)) - float(u[1])
		if absf(float(Skills.mods_layer[k])) < 0.00001:
			Skills.mods_layer.erase(k)


# --- Rolling ---------------------------------------------------------------------------------------

## `n_vis` shown and `n_hid` hidden base traits for a candidate of this tier (0..3): the
## higher the tier the likelier a rare one; no trait twice and no two of one kind's
## opposites (tall/short, clay/grass, hard_worker/prodigy...).
static func roll_student(rng: RandomNumberGenerator, tier: int, n_vis: int, n_hid: int) -> Array:
	var pool := base_ids()
	var chosen: Array = []
	var out: Array = []
	for i in n_vis + n_hid:
		var weights: Array[float] = []
		for id in pool:
			var t := int(def(id)["tier"])
			var w := 1.0 if t == 1 else (0.6 + 0.25 * tier if t == 2 else 0.15 + 0.2 * tier)
			if chosen.has(id) or _clash(chosen, id):
				w = 0.0
			weights.append(w)
		var pick := _weighted(rng, pool, weights)
		if pick == "":
			break
		chosen.append(pick)
		out.append({"id": pick, "hidden": i >= n_vis})
	return out


const _OPPOSITE := [["tall", "short"], ["clay_lover", "grass_lover"], ["hard_worker", "prodigy"], ["late_bloom", "prodigy"], ["nervous", "cool"], ["counter", "bomber"], ["marathon", "fragile"]]


static func _clash(chosen: Array, id: String) -> bool:
	for o in _OPPOSITE:
		if (o[0] == id and chosen.has(o[1])) or (o[1] == id and chosen.has(o[0])):
			return true
	return false


static func _weighted(rng: RandomNumberGenerator, pool: Array, weights: Array[float]) -> String:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0 and weights[i] > 0.0:
			return pool[i]
	return ""


## How much the traits add to a price: the sum of the tiers of the base ones (hidden too: a
## dear candidate hints at a good secret; the synergies don't count, they are a surprise).
static func rarity(st: Dictionary) -> int:
	var n := 0
	for id in _base(st):
		n += int(def(id).get("tier", 1))
	return n
