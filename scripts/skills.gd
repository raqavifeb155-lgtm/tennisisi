class_name Skills
## Skyrim-style skills: whatever you hit with gets better. They stay forever.
## A new player is weak: a narrow PERFECT window, a lot of scatter, soft pace, slow feet,
## short of breath. Every hit gives experience to the skill it used; every 5 levels you
## pick one perk of that skill out of 2-3, so two players with the same levels can play
## differently. The first levels come quickly and each is a step you feel (the stats lean
## toward the early levels); the cap at 25 takes ~10 thousand experience per skill.
## Saved by SaveData.

const MAX_LEVEL := 25
const START_POINTS := 3           # a new player places a couple of levels where they like
const PERK_EVERY := 5
const BASE_XP := 1.0              # per hit, before timing / opponent / format multipliers
const RUN_XP_PER_M := 0.15        # "Ноги": per metre run during rallies
const TIMING_XP := {"PERFECT": 2.0, "GOOD": 1.0, "EARLY": 0.4, "LATE": 0.4}

const STAMINA_XP := 25.0          # "Выносливость": per whole tank spent (0.25 per 1%)

const LIST := ["forehand", "backhand", "serve", "net", "touch", "feet", "stamina"]
const NAMES := {
	"forehand": "Форхенд", "backhand": "Бэкхенд", "serve": "Подача",
	"net": "Сетка", "touch": "Касание", "feet": "Ноги", "stamina": "Выносливость",
}
const HINTS := {
	"forehand": "удары справа", "backhand": "удары слева", "serve": "подачи",
	"net": "игра с лёта и смэши", "touch": "резаные, укороченные и свечи", "feet": "бег в розыгрышах",
	"stamina": "долгие розыгрыши",
}

## Build perks, offered 2-3 at a time at levels 5, 10, 15, 20, 25 of their skill.
## mods: <stroke>_window / _pace / _scatter / _spin are fractions (+0.15 = +15%),
## run_speed and move_penalty belong to "Ноги"; stamina_pool / _drain / _rest /
## _change are fractions too, stamina_tired moves the tiredness threshold (absolute).
const PERKS := {
	"forehand": [
		{"id": "fh_cannon", "title": "Пушечный форхенд", "desc": "Форхенд +10% скорости", "mods": {"forehand_pace": 0.10}},
		{"id": "fh_clean", "title": "Чистый контакт", "desc": "Окно PERFECT справа +20%", "mods": {"forehand_window": 0.20}},
		{"id": "fh_control", "title": "Контроль справа", "desc": "Разброс форхенда −25%", "mods": {"forehand_scatter": -0.25}},
		{"id": "fh_heavy", "title": "Тяжёлый мяч", "desc": "Вращение справа +25%", "mods": {"forehand_spin": 0.25}},
		{"id": "fh_whip", "title": "Хлыст", "desc": "Форхенд +6% скорости и +10% окна", "mods": {"forehand_pace": 0.06, "forehand_window": 0.10}},
		{"id": "fh_rock", "title": "Надёжный", "desc": "Разброс −15%, вращение +10%", "mods": {"forehand_scatter": -0.15, "forehand_spin": 0.10}},
	],
	"backhand": [
		{"id": "bh_flat", "title": "Плоский бэкхенд", "desc": "Бэкхенд +10% скорости", "mods": {"backhand_pace": 0.10}},
		{"id": "bh_clean", "title": "Двуручник", "desc": "Окно PERFECT слева +20%", "mods": {"backhand_window": 0.20}},
		{"id": "bh_control", "title": "Контроль слева", "desc": "Разброс бэкхенда −25%", "mods": {"backhand_scatter": -0.25}},
		{"id": "bh_spin", "title": "Крутка слева", "desc": "Вращение слева +25%", "mods": {"backhand_spin": 0.25}},
		{"id": "bh_line", "title": "По линии", "desc": "Бэкхенд +6% скорости, разброс −10%", "mods": {"backhand_pace": 0.06, "backhand_scatter": -0.10}},
		{"id": "bh_wall", "title": "Стена слева", "desc": "Окно +10%, разброс −15%", "mods": {"backhand_window": 0.10, "backhand_scatter": -0.15}},
	],
	"serve": [
		{"id": "sv_bomb", "title": "Бомба", "desc": "Подача +8% скорости", "mods": {"serve_pace": 0.08}},
		{"id": "sv_rhythm", "title": "Ритм подброса", "desc": "Окно PERFECT на подаче +25%", "mods": {"serve_window": 0.25}},
		{"id": "sv_sniper", "title": "Снайпер", "desc": "Разброс подачи −25%", "mods": {"serve_scatter": -0.25}},
		{"id": "sv_kick", "title": "Кик-машина", "desc": "Вращение подачи +25%", "mods": {"serve_spin": 0.25}},
		{"id": "sv_ace", "title": "Охотник за эйсами", "desc": "Подача +5% скорости, разброс −10%", "mods": {"serve_pace": 0.05, "serve_scatter": -0.10}},
		{"id": "sv_calm", "title": "Холодная голова", "desc": "Окно +15%, разброс −10%", "mods": {"serve_window": 0.15, "serve_scatter": -0.10}},
	],
	"net": [
		{"id": "nt_hands", "title": "Быстрые руки", "desc": "Окно PERFECT у сетки +25%", "mods": {"net_window": 0.25}},
		{"id": "nt_smash", "title": "Молот", "desc": "Смэш и удар с лёта +12% скорости", "mods": {"net_pace": 0.12}},
		{"id": "nt_soft", "title": "Мягкие руки", "desc": "Разброс у сетки −25%", "mods": {"net_scatter": -0.25}},
		{"id": "nt_punch", "title": "Удар-тычок", "desc": "Скорость +6%, окно +10%", "mods": {"net_pace": 0.06, "net_window": 0.10}},
		{"id": "nt_wall", "title": "Сетевик", "desc": "Разброс −15%, окно +10%", "mods": {"net_scatter": -0.15, "net_window": 0.10}},
		{"id": "nt_reflex", "title": "Реакция", "desc": "Окно +15%, скорость +5%", "mods": {"net_window": 0.15, "net_pace": 0.05}},
	],
	"touch": [
		{"id": "tc_knife", "title": "Нож", "desc": "Резаный крутится на 25% сильнее", "mods": {"touch_spin": 0.25}},
		{"id": "tc_feather", "title": "Пёрышко", "desc": "Разброс резаных и укороченных −25%", "mods": {"touch_scatter": -0.25}},
		{"id": "tc_feel", "title": "Чувство мяча", "desc": "Окно PERFECT на касании +25%", "mods": {"touch_window": 0.25}},
		{"id": "tc_skid", "title": "Стелющийся", "desc": "Резаный +8% скорости", "mods": {"touch_pace": 0.08}},
		{"id": "tc_artist", "title": "Художник", "desc": "Окно +10%, вращение +10%", "mods": {"touch_window": 0.10, "touch_spin": 0.10}},
		{"id": "tc_shady", "title": "Ушлый", "desc": "Ставки против себя без риска дисквалификации", "mods": {"shady": 1.0}},
		{"id": "tc_ghost", "title": "Призрак", "desc": "Разброс −15%, вращение +10%", "mods": {"touch_scatter": -0.15, "touch_spin": 0.10}},
	],
	"feet": [
		{"id": "ft_sprint", "title": "Спринтер", "desc": "Скорость бега +6%", "mods": {"run_speed": 0.06}},
		{"id": "ft_balance", "title": "Баланс", "desc": "Удар на бегу почти без штрафа", "mods": {"move_penalty": -0.5}},
		{"id": "ft_marathon", "title": "Марафонец", "desc": "Скорость +3%, штраф на бегу −25%", "mods": {"run_speed": 0.03, "move_penalty": -0.25}},
		{"id": "ft_cat", "title": "Кошка", "desc": "Скорость бега +4%", "mods": {"run_speed": 0.04}},
		{"id": "ft_dancer", "title": "Танцор", "desc": "Штраф на бегу −35%", "mods": {"move_penalty": -0.35}},
		{"id": "ft_split", "title": "Сплит-степ", "desc": "Скорость +2%, штраф на бегу −20%", "mods": {"run_speed": 0.02, "move_penalty": -0.20}},
	],
	"stamina": [
		{"id": "st_second", "title": "Второе дыхание", "desc": "Между очками +5% выносливости", "mods": {"stamina_rest": 0.05}},
		{"id": "st_lungs", "title": "Железные лёгкие", "desc": "Запас выносливости +15%", "mods": {"stamina_pool": 0.15}},
		{"id": "st_thrift", "title": "Экономный", "desc": "Расход выносливости −15%", "mods": {"stamina_drain": -0.15}},
		{"id": "st_champ", "title": "Пауза чемпиона", "desc": "Смена сторон +10% выносливости", "mods": {"stamina_change": 0.10}},
		{"id": "st_marathon", "title": "Марафон", "desc": "Запас +8%, расход −8%", "mods": {"stamina_pool": 0.08, "stamina_drain": -0.08}},
		{"id": "st_cold", "title": "Холодный пот", "desc": "Усталость наступает с 30%, а не с 40%", "mods": {"stamina_tired": -0.10}},
	],
}

static var xp := {}               # skill -> total experience
static var perks: Array = []      # taken build perk ids
static var pending: Array = []    # skills waiting for a perk choice (one entry per milestone)
static var points := START_POINTS # starting points: each buys one level of any skill
static var gear := {}             # mods from the racket in hand this run (Gear item "mods")
static var mods_layer := {}       # stream G: this match's modifiers (scripts/mods), never online


static func reset() -> void:
	xp = {}
	perks = []
	pending = []
	points = START_POINTS
	gear = {}


## Spends a starting point: the skill goes straight to its next level.
static func spend_point(id: String) -> bool:
	if points <= 0 or level(id) >= MAX_LEVEL:
		return false
	var pr := progress(id)
	points -= 1
	add_xp(id, pr.y - pr.x + 0.001)
	return true


## Experience needed to go from level n-1 to n. Level 1 is about a dozen hits, level 8
## ~780 experience (two or three tournaments), the cap ~10 thousand.
static func cost(n: int) -> float:
	return 12.0 * pow(float(n), 1.35)


## How far along a level is, 0 (beginner) .. 1 (cap), leaning toward the early levels:
## the first levels move the stats the most, so growth is felt right away.
static func k(lv: int) -> float:
	return 1.0 - pow(1.0 - clampf(float(lv) / MAX_LEVEL, 0.0, 1.0), 1.6)


## The beginner's handicap (HANDOFF 9.3): 1 at level 0, fading to nothing by level
## EARLY_UNTIL. The first levels are harder and clumsier than the base curves alone (a
## narrower window, a faster ring, more scatter, slower feet); from level 10 on the curves
## are exactly as before.
const EARLY_UNTIL := 10


static func early(lv: int) -> float:
	if lv >= EARLY_UNTIL:
		return 0.0
	return pow(1.0 - float(maxi(lv, 0)) / EARLY_UNTIL, 1.5)


static func level(id: String) -> int:
	var total: float = xp.get(id, 0.0)
	var n := 0
	while n < MAX_LEVEL and total >= cost(n + 1) - 0.001:
		total -= cost(n + 1)
		n += 1
	return n


## [xp into the current level, xp needed for the next] for progress bars.
static func progress(id: String) -> Vector2:
	var total: float = xp.get(id, 0.0)
	var n := 0
	while n < MAX_LEVEL and total >= cost(n + 1) - 0.001:
		total -= cost(n + 1)
		n += 1
	if n >= MAX_LEVEL:
		return Vector2(1, 1)
	return Vector2(total, cost(n + 1))


## Adds experience; returns the new level if the skill levelled up, else -1.
static func add_xp(id: String, amount: float) -> int:
	if amount <= 0.0:
		return -1
	var before := level(id)
	xp[id] = float(xp.get(id, 0.0)) + amount
	SaveData.lifetime_xp += amount  # never reset: a monotonic measure of progress (ACADEMY_LEGACY_TZ)
	var after := level(id)
	if after == before:
		return -1
	for n in range(before + 1, after + 1):
		if n % PERK_EVERY == 0:
			pending.append(id)
	return after


## Up to 3 untaken perks of the skill for the next pending choice.
static func perk_offer(id: String, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for p in PERKS[id]:
		if not perks.has(p["id"]):
			pool.append(p)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, 3)


static func take_perk(perk_id: String) -> void:
	if not perks.has(perk_id):
		perks.append(perk_id)
	if not pending.is_empty():
		pending.pop_front()


## Recounts the perk choices owed from the levels (after a load: an old save's
## experience lands on a different curve). Owed per skill = milestones reached - perks taken.
static func rebuild_pending() -> void:
	pending = []
	for id in LIST:
		var taken := 0
		for p in PERKS[id]:
			if perks.has(p["id"]):
				taken += 1
		for i in maxi(level(id) / PERK_EVERY - taken, 0):
			pending.append(id)


## Drops pending choices whose skill has no perks left.
static func next_pending(rng: RandomNumberGenerator) -> Dictionary:
	while not pending.is_empty():
		var id: String = pending[0]
		var offer := perk_offer(id, rng)
		if not offer.is_empty():
			return {"skill": id, "offer": offer}
		pending.pop_front()
	return {}


static func mod(key: String) -> float:
	var total := float(gear.get(key, 0.0)) + float(mods_layer.get(key, 0.0))
	for id in perks:
		var p := find_perk(id)
		total += float(p.get("mods", {}).get(key, 0.0))
	return total


static func find_perk(perk_id: String) -> Dictionary:
	for id in PERKS:
		for p in PERKS[id]:
			if p["id"] == perk_id:
				return p
	return {}


## How well a stroke family is played. Level 0 is an amateur, level 25 a pro.
##   window      PERFECT window: narrow for a beginner, so PERFECTs are rare at first
##   good        GOOD window: stays forgiving, so a beginner still gets the ball back
##   ring        how early the timing ring appears (s): late for a beginner
##   ring_speed  how fast it closes: a beginner's ring flies in
##   pace, scatter, spin  power, aim error and spin of the shot
## lv: a level to look at (for "104 -> 109 km/h" on a level-up); -1 = the current one.
static func stroke(id: String, lv := -1) -> Dictionary:
	var n := level(id) if lv < 0 else lv
	var t := k(n)
	var e := early(n)
	return {
		"window": lerpf(0.55, 1.5, t) * (1.0 - 0.30 * e) * (1.0 + mod(id + "_window")),
		"good": lerpf(0.9, 1.3, t) * (1.0 + mod(id + "_window") * 0.5),
		"ring": lerpf(0.6, 0.95, t) * (1.0 - 0.15 * e),
		"ring_speed": lerpf(1.4, 0.9, t) * (1.0 + 0.30 * e),
		"pace": lerpf(0.70, 1.25, t) * (1.0 + mod(id + "_pace")),
		"scatter": maxf(lerpf(1.8, 0.5, t) * (1.0 + 0.35 * e) * (1.0 + mod(id + "_scatter")), 0.3),
		"spin": lerpf(0.75, 1.2, t) * (1.0 + mod(id + "_spin")),
	}


## How far inside the sideline a serve aimed wide is pulled (Main.serve_target): a
## beginner aims at the line itself, so the scatter puts many wide serves out (HANDOFF
## 9.4); from level 10 the old 0.2 m. lv: -1 = the current serve level.
static func serve_edge_margin(lv := -1) -> float:
	return 0.2 * (1.0 - early(level("serve") if lv < 0 else lv))


static func run_speed_mult(lv := -1) -> float:
	var n := level("feet") if lv < 0 else lv
	return lerpf(0.75, 1.15, k(n)) * (1.0 - 0.10 * early(n)) * (1.0 + mod("run_speed"))


## How much of the "hitting on the run" penalty remains (1 = all of it).
static func move_penalty_mult() -> float:
	var n := level("feet")
	return clampf(lerpf(1.3, 0.7, k(n)) * (1.0 + 0.30 * early(n)) * (1.0 + mod("move_penalty")), 0.1, 2.0)


## Stamina spend multiplier (cost / tank size): a beginner burns it twice as fast with a
## small tank; at the cap it lasts four times longer. lv: -1 = the current level.
static func stamina_drain(lv := -1) -> float:
	var t := k(level("stamina") if lv < 0 else lv)
	var pool := lerpf(1.0, 1.6, t) * (1.0 + mod("stamina_pool"))
	return lerpf(2.0, 0.8, t) * (1.0 + mod("stamina_drain")) / pool


## Stamina given back: "point" between points, "change" at the change of ends, "set"
## between sets.
static func stamina_rest(kind: String) -> float:
	var t := k(level("stamina"))
	match kind:
		"change":
			return lerpf(0.30, 0.45, t) * (1.0 + mod("stamina_change"))
		"set":
			return lerpf(0.50, 0.70, t)
		_:
			return lerpf(0.10, 0.20, t) + mod("stamina_rest") + ClubBuilds.recovery_bonus()  # + the coach's room (v0.2 B)


## Below this much stamina the player is tired: slower, wilder, softer.
static func tired_below() -> float:
	return clampf(0.4 + mod("stamina_tired"), 0.1, 0.6)


## The number a level-up shows for a skill at level lv, e.g. "104 км/ч".
static func headline(id: String, lv: int) -> String:
	match id:
		"serve":
			return "%d км/ч" % roundi(50.0 * 3.6 * stroke(id, lv)["pace"])
		"touch":
			return "вращение %d%%" % roundi(100.0 * stroke(id, lv)["spin"])
		"feet":
			return "бег %d%%" % roundi(100.0 * run_speed_mult(lv))
		"stamina":
			return "запас %d%%" % roundi(200.0 / stamina_drain(lv))
		_:
			return "%d км/ч" % roundi(36.0 * 3.6 * stroke(id, lv)["pace"])


static func total_level() -> int:
	var s := 0
	for id in LIST:
		s += level(id)
	return s
