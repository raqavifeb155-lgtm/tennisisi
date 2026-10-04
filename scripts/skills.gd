class_name Skills
## Skyrim-style skills: whatever you hit with gets better. They stay forever.
## A new player is weak: a narrow PERFECT window, a lot of scatter, soft pace, slow feet.
## Every hit gives experience to the skill it used; every 5 levels you pick one perk of
## that skill out of 2-3, so two players with the same levels can play differently.
## The road is long: about a hundred hits for level 1, hundreds of matches toward 30.
## Saved by SaveData.

const MAX_LEVEL := 30
const PERK_EVERY := 5
const BASE_XP := 1.0              # per hit, before timing / opponent / format multipliers
const RUN_XP_PER_M := 0.15        # "Ноги": per metre run during rallies
const TIMING_XP := {"PERFECT": 2.0, "GOOD": 1.0, "EARLY": 0.4, "LATE": 0.4}

const LIST := ["forehand", "backhand", "serve", "net", "touch", "feet"]
const NAMES := {
	"forehand": "Форхенд", "backhand": "Бэкхенд", "serve": "Подача",
	"net": "Сетка", "touch": "Касание", "feet": "Ноги",
}
const HINTS := {
	"forehand": "удары справа", "backhand": "удары слева", "serve": "подачи",
	"net": "игра с лёта и смэши", "touch": "резаные и укороченные", "feet": "бег в розыгрышах",
}

## Build perks, offered 2-3 at a time at levels 5, 10, 15, 20, 25, 30 of their skill.
## mods: <stroke>_window / _pace / _scatter / _spin are fractions (+0.15 = +15%),
## run_speed and move_penalty belong to "Ноги".
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
}

static var xp := {}               # skill -> total experience
static var perks: Array = []      # taken build perk ids
static var pending: Array = []    # skills waiting for a perk choice (one entry per milestone)


static func reset() -> void:
	xp = {}
	perks = []
	pending = []


## Experience needed to go from level n-1 to n. Level 1 is about a hundred hits;
## near the cap takes hundreds of matches (anti-grind limits come later).
static func cost(n: int) -> float:
	return 100.0 * pow(float(n), 1.25)


static func level(id: String) -> int:
	var total: float = xp.get(id, 0.0)
	var n := 0
	while n < MAX_LEVEL and total >= cost(n + 1):
		total -= cost(n + 1)
		n += 1
	return n


## [xp into the current level, xp needed for the next] for progress bars.
static func progress(id: String) -> Vector2:
	var total: float = xp.get(id, 0.0)
	var n := 0
	while n < MAX_LEVEL and total >= cost(n + 1):
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
	var total := 0.0
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


## How well a stroke family is played: multipliers for the timing windows, pace,
## random scatter and spin. Level 0 is a beginner, level 25 a pro.
static func stroke(id: String) -> Dictionary:
	var k := float(level(id)) / MAX_LEVEL
	return {
		"window": lerpf(0.75, 1.3, k) * (1.0 + mod(id + "_window")),
		"pace": lerpf(0.88, 1.08, k) * (1.0 + mod(id + "_pace")),
		"scatter": maxf(lerpf(1.5, 0.7, k) * (1.0 + mod(id + "_scatter")), 0.3),
		"spin": lerpf(0.8, 1.1, k) * (1.0 + mod(id + "_spin")),
	}


static func run_speed_mult() -> float:
	return lerpf(0.86, 1.08, float(level("feet")) / MAX_LEVEL) * (1.0 + mod("run_speed"))


## How much of the "hitting on the run" penalty remains (1 = all of it).
static func move_penalty_mult() -> float:
	return clampf(lerpf(1.3, 0.7, float(level("feet")) / MAX_LEVEL) * (1.0 + mod("move_penalty")), 0.1, 1.5)


static func total_level() -> int:
	var s := 0
	for id in LIST:
		s += level(id)
	return s
