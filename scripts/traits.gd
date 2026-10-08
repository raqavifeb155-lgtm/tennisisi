class_name Traits
extends RefCounted
## One catalog of passive traits for everybody (docs/superpowers/specs/2026-10-09-tycoon.md
## 3.9): the club's students, the roster's opponents (stream G adds its auras to CATALOG
## with "src": "G") and the hero through the legacy. A trait is data:
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

const KIND_NAMES := {"stat": "Игра", "growth": "Рост", "style": "Стиль", "char": "Характер", "synergy": "Синергия"}


static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})


static func ids() -> Array:
	return CATALOG.keys()


static func base_ids() -> Array:
	return CATALOG.keys().filter(func(i: String) -> bool: return CATALOG[i]["kind"] != "synergy")


static func text(id: String) -> String:
	var d := def(id)
	return "%s · %s" % [d["name"], d["desc"]] if not d.is_empty() else id


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
static func roll(rng: RandomNumberGenerator, tier: int, n_vis: int, n_hid: int) -> Array:
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
