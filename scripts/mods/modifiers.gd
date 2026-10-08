class_name Modifiers
## Modifiers on everything (v0.2 stream G, spec 2026-10-08-v02-mods.md): one catalog for
## the opponents' auras, the run's conditions the player picks before a run, and the
## templates for item affixes. Pure data and the decisions made outside a match (which
## auras an opponent rolls, what a run pays, what the card shows); ModsHub applies them
## during a match through the primitives of ModEffects and puts everything back after.
##
## An entry: id, name, desc (one line, shown before the match), rarity (0 common, 1 rare,
## 2 epic, 3 mythic), target ("run" the player, "opponent", "court" the court and the ball,
## "item" an affix template), pools ("aura": an opponent may roll it; "run": the player
## may pick it), fx (primitives, see ModEffects), color and icon (the aura on court and
## on the card), reward (prize money x for an aura's match / for the whole run).
## legacy: the old Tournament.MODIFIERS (fast, steady, bomber) — the tournament applies
## them; here they only get a name and a look.

const COMMON := 0
const RARE := 1
const EPIC := 2
const MYTHIC := 3
const RARITY_NAMES := ["Обычный", "Редкий", "Эпический", "Мифический"]

const AURA_CHANCE := 0.05         # an ordinary opponent comes with an aura
const BOSS_CHANCE := 0.22         # the boss...
const BOSS_TWO := 0.33            # ...and of those, this share with two
const RARITY_WEIGHT := [50.0, 30.0, 15.0, 5.0]
const HIDE_EPIC := 0.5            # an epic aura is "???" until the first point this often (mythic: always)
const MAX_REWARD := 3.0
const MAX_HARD := 4.0             # the cap with «Хардкор» (its own x2.5 on top of the conditions)
const HARD_STYLE := 1.5           # «Хардкор»: the match's style gold x
const HARD_RARITY := 0.02         # «Хардкор»: +2 points to the chance of a legendary item (above epic)
## The bot has no thumb: its auto-positioning (1.0 in an ordinary run) is cut to this in a
## hardcore one, as a stand-in for a player steering the legs alone (G-6, table in the spec).
const BOT_HARD_ASSIST := 0.5
## What «Хардкор» already contains: not offered again on top of it.
const HARD_HAS := ["tier_up", "short_ring", "no_slowmo", "blind", "late_flash"]
const MAX_RUN := 3                # conditions a run may take
const RUN_LOOT := 0.02            # each run condition adds this to the drop chances
const AURA_LOOT := 0.04           # each aura moves his gear rarity up by this x (rarity + 1)

## Presets of the run screen: a set picked at once, each one can be taken off alone.
## "Про" (owner, spec 12.2: no difficulty setting, this instead): x1.25 x1.2 = x1.5.
const PRESETS := [
	{"id": "pro", "name": "Про", "desc": "Узкое окно PERFECT и соперники на тир сильнее", "mods": ["short_ring", "tier_up"]},
]

## Off where the rules must be equal (online, when it comes): nothing rolls, nothing applies.
static var enabled := true
## --mods=a,b (bot runs and tests): these apply to every match, and no aura is rolled.
static var forced: Array = []

const LIST := [
	# --- The player (the run's conditions, a few also as auras)
	{"id": "no_ring", "name": "Без кольца", "desc": "Кольца тайминга нет совсем", "rarity": EPIC,
		"target": "run", "pools": ["run"], "fx": [["no_ring"]],
		"color": Color(0.95, 0.35, 0.3), "icon": "О", "reward": 1.6},
	{"id": "half_tank", "name": "Полбака", "desc": "Матч начинаешь с половиной выносливости", "rarity": RARE,
		"target": "run", "pools": ["run", "aura"], "fx": [["stamina_start", 0.5]],
		"color": Color(1.0, 0.55, 0.2), "icon": "½", "reward": 1.2},
	{"id": "mirror", "name": "Зеркало", "desc": "Свайп и джойстик отражены влево-вправо", "rarity": MYTHIC,
		"target": "run", "pools": ["run"], "fx": [["mirror"]],
		"color": Color(0.8, 0.85, 0.95), "icon": "З", "reward": 1.6},
	{"id": "late_flash", "name": "Поздняя вспышка", "desc": "Кольцо вспыхивает за миг до удара", "rarity": RARE,
		"target": "run", "pools": ["run", "aura"], "fx": [["ring_late", 0.28]],
		"color": Color(1.0, 0.9, 0.4), "icon": "В", "reward": 1.3},
	{"id": "heat", "name": "Жара", "desc": "Выносливость тратится на 30% быстрее", "rarity": COMMON,
		"target": "run", "pools": ["run", "aura"], "fx": [["stat", "stamina_drain", 0.3]],
		"color": Color(1.0, 0.45, 0.15), "icon": "Ж", "reward": 1.15},
	{"id": "short_ring", "name": "Короткое кольцо", "desc": "Окно PERFECT на 20% уже", "rarity": RARE,
		"target": "run", "pools": ["run"], "fx": [["stat", "all_window", -0.2]],
		"color": Color(0.95, 0.75, 0.3), "icon": "К", "reward": 1.25},
	{"id": "no_var", "name": "Без VAR", "desc": "Повтор Hawk-Eye не показывается", "rarity": COMMON,
		"target": "run", "pools": ["run"], "fx": [["tuning", "hawkeye_range", -1.0]],
		"color": Color(0.6, 0.65, 0.75), "icon": "V", "reward": 1.05},
	{"id": "blind", "name": "Вслепую", "desc": "Нет метки прицела и места отскока", "rarity": RARE,
		"target": "run", "pools": ["run"], "fx": [["tuning", "show_aim", false], ["tuning", "show_landing", false]],
		"color": Color(0.55, 0.6, 0.7), "icon": "Сл", "reward": 1.2},
	{"id": "no_slowmo", "name": "Без замедления", "desc": "Перед ударом время не замедляется", "rarity": RARE,
		"target": "run", "pools": ["run"], "fx": [["tuning", "slowmo_enabled", false]],
		"color": Color(0.4, 0.8, 1.0), "icon": "Зм", "reward": 1.3},
	{"id": "heavy_legs", "name": "Ватные ноги", "desc": "Бегаешь на 8% медленнее", "rarity": COMMON,
		"target": "run", "pools": ["run"], "fx": [["stat", "run_speed", -0.08]],
		"color": Color(0.7, 0.6, 0.5), "icon": "Н", "reward": 1.15},
	{"id": "soft_arm", "name": "Мягкая рука", "desc": "Твои удары на 8% слабее", "rarity": COMMON,
		"target": "run", "pools": ["run"], "fx": [["stat", "all_pace", -0.08], ["stat", "serve_pace", -0.08]],
		"color": Color(0.75, 0.7, 0.65), "icon": "Р", "reward": 1.1},
	{"id": "tier_up", "name": "Соперники +1 тир", "desc": "Каждый соперник сильнее на тир: точнее, быстрее, подача сильнее", "rarity": RARE,
		"target": "opponent", "pools": ["run"], "fx": [["opp", "skill", 0.1], ["opp", "speed", 1.05], ["opp", "serve", 1.05]],
		"color": Color(1.0, 0.5, 0.3), "icon": "+1", "reward": 1.2},
	# --- The hardcore mode (G-6): a fixed set, chosen before the run instead of the usual conditions.
	{"id": "hardcore", "name": "Хардкор", "desc": "Без помощи в беге, замедления и прицела, кольцо уже на 30%, соперники на тир сильнее",
		"rarity": MYTHIC, "target": "run", "pools": [],
		"fx": [["tuning", "assist", 0.0], ["tuning", "slowmo_enabled", false], ["tuning", "show_aim", false], ["tuning", "show_landing", false],
			["stat", "all_window", -0.3], ["opp", "skill", 0.1], ["opp", "speed", 1.05], ["opp", "serve", 1.05]],
		"color": Color(0.9, 0.2, 0.2), "icon": "Х", "reward": 2.5},
	{"id": "elite", "name": "Элитные чаще", "desc": "Ауры у соперников в 2.5 раза чаще", "rarity": RARE,
		"target": "run", "pools": ["run"], "fx": [["aura_rate", 2.5]],
		"color": Color(0.7, 0.38, 1.0), "icon": "Э", "reward": 1.15},
	# --- The opponent
	{"id": "fast", "name": "Быстрые ноги", "desc": "Бегает на 12% быстрее", "rarity": COMMON,
		"target": "opponent", "pools": [], "fx": [], "legacy": true,
		"color": Color(1.0, 0.6, 0.35), "icon": "Б", "reward": 1.0},
	{"id": "steady", "name": "Железный", "desc": "Реже ошибается", "rarity": COMMON,
		"target": "opponent", "pools": [], "fx": [], "legacy": true,
		"color": Color(1.0, 0.6, 0.35), "icon": "Ж", "reward": 1.0},
	{"id": "bomber", "name": "Бомбардир", "desc": "Подаёт на 12% быстрее", "rarity": COMMON,
		"target": "opponent", "pools": [], "fx": [], "legacy": true,
		"color": Color(1.0, 0.6, 0.35), "icon": "П", "reward": 1.0},
	{"id": "marathoner", "name": "Марафонец", "desc": "Его выносливость вдвое больше", "rarity": RARE,
		"target": "opponent", "pools": ["aura", "run"], "fx": [["opp_stamina", 2.0], ["opp", "skill", 0.04]],
		"color": Color(0.35, 0.85, 0.55), "icon": "М", "reward": 1.2},
	{"id": "crystal", "name": "Хрустальный", "desc": "Выносливость вдвое меньше, бьёт на 40% сильнее", "rarity": EPIC,
		"target": "opponent", "pools": ["aura"], "fx": [["opp_stamina", 0.5], ["shot_pace", 1, 1.4]],
		"color": Color(0.6, 0.95, 1.0), "icon": "Х", "reward": 1.15},
	{"id": "echo", "name": "Эхо", "desc": "Каждый его третий удар — укороченный", "rarity": EPIC,
		"target": "opponent", "pools": ["aura", "run"], "fx": [["echo", 3]],
		"color": Color(0.75, 0.55, 1.0), "icon": "Эх", "reward": 1.4},
	{"id": "wall", "name": "Стена", "desc": "Возвращает почти всё, но без силы", "rarity": RARE,
		"target": "opponent", "pools": ["aura"], "fx": [["opp", "skill", 0.14], ["shot_pace", 1, 0.88]],
		"color": Color(0.65, 0.67, 0.7), "icon": "С", "reward": 1.2},
	{"id": "giant", "name": "Гигант", "desc": "Ростом 2.1 м: подача +12%, бег −8%", "rarity": EPIC,
		"target": "opponent", "pools": ["aura"], "fx": [["cpu_scale", 1.16], ["opp", "serve", 1.12], ["opp", "speed", 0.92]],
		"color": Color(0.85, 0.75, 0.55), "icon": "Г", "reward": 1.15},
	{"id": "seer", "name": "Ясновидец", "desc": "Реагирует на твой удар на 0.08 с раньше", "rarity": RARE,
		"target": "opponent", "pools": ["aura", "run"], "fx": [["reaction", -0.08]],
		"color": Color(0.7, 0.4, 1.0), "icon": "Я", "reward": 1.15},
	{"id": "cannon", "name": "Пушка", "desc": "Его удары на 15% быстрее", "rarity": RARE,
		"target": "opponent", "pools": ["aura", "run"], "fx": [["shot_pace", 1, 1.15]],
		"color": Color(1.0, 0.4, 0.3), "icon": "Пу", "reward": 1.15},
	{"id": "vampire", "name": "Вампир", "desc": "Его виннер забирает 10% твоей выносливости", "rarity": RARE,
		"target": "opponent", "pools": ["aura"], "fx": [["drain_on_loss", 0.1]],
		"color": Color(0.85, 0.12, 0.2), "icon": "Ва", "reward": 1.1},
	{"id": "showman", "name": "Шоумен", "desc": "Играет на публику: сильнее на 10%, золото ×2", "rarity": MYTHIC,
		"target": "opponent", "pools": ["aura"], "fx": [["shot_pace", 1, 1.1], ["opp", "skill", 0.05]],
		"color": Color(1.0, 0.84, 0.26), "icon": "Ш", "reward": 1.6},
	{"id": "twins", "name": "Близнецы", "desc": "На его половине корта — двое", "rarity": MYTHIC,
		"target": "opponent", "pools": [], "fx": [["twins"]],
		"color": Color(1.0, 0.3, 0.6), "icon": "2", "reward": 2.0},
	# --- The court and the ball
	{"id": "fog", "name": "Туман", "desc": "Мяч виден только рядом с тобой", "rarity": EPIC,
		"target": "court", "pools": ["aura", "run"], "fx": [["fog", 0.05]],
		"color": Color(0.85, 0.88, 0.92), "icon": "Ту", "reward": 1.3},
	{"id": "night", "name": "Ночь", "desc": "Тёмный корт, светится только мяч", "rarity": EPIC,
		"target": "court", "pools": ["aura", "run"], "fx": [["night"]],
		"color": Color(0.35, 0.45, 1.0), "icon": "Но", "reward": 1.2},
	{"id": "wind", "name": "Ветер", "desc": "Боковой ветер сносит мяч", "rarity": RARE,
		"target": "court", "pools": ["aura", "run"], "fx": [["wind", 1.8]],
		"color": Color(0.6, 0.9, 0.85), "icon": "Ве", "reward": 1.3},
	{"id": "moon", "name": "Лунная гравитация", "desc": "Тяжесть 55%: высокие медленные отскоки", "rarity": MYTHIC,
		"target": "court", "pools": ["aura", "run"], "fx": [["gravity", 0.55]],
		"color": Color(0.85, 0.85, 1.0), "icon": "Л", "reward": 1.2},
	{"id": "giant_ball", "name": "Гигантский мяч", "desc": "Мяч втрое больше", "rarity": EPIC,
		"target": "court", "pools": ["aura", "run"], "fx": [["ball_scale", 3.0]],
		"color": Color(0.86, 0.95, 0.2), "icon": "Ги", "reward": 1.05},
	{"id": "fast_ball", "name": "Быстрый мяч", "desc": "Все удары на 20% быстрее", "rarity": RARE,
		"target": "court", "pools": ["aura", "run"], "fx": [["shot_pace", -1, 1.2], ["serve_pace", -1, 1.08]],
		"color": Color(1.0, 0.7, 0.2), "icon": "Бм", "reward": 1.15},
	{"id": "rubber_net", "name": "Резиновая сетка", "desc": "Мяч в сетку перепрыгивает её", "rarity": RARE,
		"target": "court", "pools": ["aura", "run"], "fx": [["rubber_net"]],
		"color": Color(0.95, 0.5, 0.85), "icon": "Рс", "reward": 1.05},
	{"id": "narrow", "name": "Узкий корт", "desc": "Корт на метр уже", "rarity": RARE,
		"target": "court", "pools": ["aura", "run"], "fx": [["narrow", 0.5]],
		"color": Color(0.95, 0.95, 0.95), "icon": "У", "reward": 1.1},
	{"id": "ice", "name": "Ледяной корт", "desc": "Мяч скользит после отскока: низко и быстро", "rarity": EPIC,
		"target": "court", "pools": ["aura", "run"], "fx": [["surface", 0.3, 1.1, -0.06, Color(0.72, 0.86, 1.0)]],
		"color": Color(0.55, 0.85, 1.0), "icon": "Лё", "reward": 1.15},
	{"id": "trampoline", "name": "Батут", "desc": "Мяч отскакивает выше", "rarity": RARE,
		"target": "court", "pools": ["aura", "run"], "fx": [["surface", 1.0, 1.0, 0.09, Color(1, 1, 1)]],
		"color": Color(0.5, 1.0, 0.6), "icon": "Ба", "reward": 1.05},
	# --- Item affix templates (stream A builds items from these; never rolled here)
	{"id": "heavy_ball_t", "name": "Тяжёлый мяч", "desc": "Твои удары на 6% быстрее", "rarity": RARE,
		"target": "item", "pools": [], "fx": [["shot_pace", 0, 1.06]],
		"color": Color(0.33, 0.6, 1.0), "icon": "Т", "reward": 1.0},
	{"id": "deep_focus_t", "name": "Глубокий фокус", "desc": "Замедление перед ударом глубже", "rarity": RARE,
		"target": "item", "pools": [], "fx": [["tuning_x", "slowmo_scale", 0.8]],
		"color": Color(0.33, 0.6, 1.0), "icon": "Ф", "reward": 1.0},
	{"id": "leech_t", "name": "Пиявка", "desc": "Твой виннер: +5% выносливости", "rarity": EPIC,
		"target": "item", "pools": [], "fx": [["heal_on_win", 0.05]],
		"color": Color(0.7, 0.38, 1.0), "icon": "Пи", "reward": 1.0},
	{"id": "early_eye_t", "name": "Ранний глаз", "desc": "Окно PERFECT на подаче +10%", "rarity": COMMON,
		"target": "item", "pools": [], "fx": [["stat", "serve_window", 0.1]],
		"color": Color(0.7, 0.73, 0.78), "icon": "Г", "reward": 1.0},
]


static func find(id: String) -> Dictionary:
	for e in LIST:
		if e["id"] == id:
			return e
	return {}


static func ids() -> Array:
	return LIST.map(func(e): return e["id"])


## Entries of a pool ("aura", "run", "boss").
static func pool(name: String) -> Array:
	return LIST.filter(func(e): return e["pools"].has(name))


## The color of a rarity, in UiTheme's five (mythic is the red one).
static func rarity_color(r: int) -> Color:
	return UiTheme.rarity_color([0, 1, 2, 4][clampi(r, 0, 3)])


## For stream D's card and any screen: the shown name and one-line effect of an id
## (the old fast / steady / bomber too). An unknown id gives itself and "".
static func name(id: String) -> String:
	var e := find(id)
	return String(Tournament.MODIFIERS.get(id, {}).get("name", id)) if e.is_empty() else String(e["name"])


static func desc(id: String) -> String:
	var e := find(id)
	return String(Tournament.MODIFIERS.get(id, {}).get("desc", "")) if e.is_empty() else String(e["desc"])


# --- Auras --------------------------------------------------------------------------

## The auras of opponent i, rolled with their own generator from the tournament's seed
## (the gear and golden rolls keep their numbers). elite: the chance x (run condition).
## Returns {"mods": [ids], "hidden": [ids]}.
static func roll_auras(seed_value: int, i: int, boss: bool, elite := 1.0, new_player := false) -> Dictionary:
	var out := {"mods": [], "hidden": []}
	if not enabled or not forced.is_empty() or i == 0 or (new_player and i < 2):
		return out
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, i, "aura"])
	var n := 0
	var x := r.randf()
	if boss:
		if x < BOSS_CHANCE * elite:
			n = 2 if r.randf() < BOSS_TWO else 1
	elif x < AURA_CHANCE * elite:
		n = 1
	var p := pool("aura")
	if boss and r.randf() < 1.0 / 12.0:
		p = p + pool("boss")  # "Близнецы": only a boss, rarely
	for k in n:
		var e := _weighted(p, r)
		if e.is_empty() or out["mods"].has(e["id"]):
			continue
		out["mods"].append(e["id"])
		if int(e["rarity"]) == MYTHIC or (int(e["rarity"]) == EPIC and r.randf() < HIDE_EPIC):
			out["hidden"].append(e["id"])
	return out


static func _weighted(p: Array, r: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for e in p:
		total += RARITY_WEIGHT[int(e["rarity"])]
	var x := r.randf() * total
	for e in p:
		x -= RARITY_WEIGHT[int(e["rarity"])]
		if x <= 0.0:
			return e
	return p.back() if not p.is_empty() else {}


## Rolls the auras of every opponent into the lineup (after the old modifiers): called by
## Tournament.roll_lineup and again when "Элитные чаще" is picked.
static func add_auras(t: Tournament) -> void:
	var elite := 1.0
	for id in t.run_modifiers:
		for f in find(id).get("fx", []):
			if f[0] == "aura_rate":
				elite *= float(f[1])
	var newbie := SaveData.played == 0
	for i in t.lineup.size():
		var lu: Dictionary = t.lineup[i]
		var keep: Array = lu["mods"].filter(func(id): return find(id).get("legacy", false) or find(id).is_empty())
		var a := roll_auras(t.rng.seed, i, Opponents.ROSTER[i].get("boss", false), elite, newbie)
		lu["mods"] = keep + a["mods"]
		lu["hidden"] = a["hidden"]


## Loot shift an aura (or an old modifier) gives his gear.
static func loot_bonus(id: String) -> float:
	if Tournament.MODIFIERS.has(id):
		return float(Tournament.MODIFIERS[id]["loot"])
	var e := find(id)
	return 0.0 if e.is_empty() else AURA_LOOT * (int(e["rarity"]) + 1)


# --- Rewards ------------------------------------------------------------------------

## Product of the rewards (an unknown id pays x1), at most MAX_REWARD.
static func reward(list: Array) -> float:
	var x := 1.0
	for id in list:
		x *= float(find(id).get("reward", 1.0))
	return minf(x, MAX_HARD if list.has("hardcore") else MAX_REWARD)


## What beating opponent i pays on top: his auras x the run's conditions.
static func gold_mult(t: Tournament, i: int) -> float:
	if not enabled:
		return 1.0
	var auras: Array = t.lineup[i]["mods"] if i < t.lineup.size() else []
	return minf(reward(auras) * reward(t.run_modifiers), MAX_HARD if t.hardcore else MAX_REWARD)


## «Хардкор»: the match's style gold x.
static func style_mult(t: Tournament) -> float:
	return HARD_STYLE if enabled and t != null and t.hardcore else 1.0


## The run's conditions: picked before the run (0..MAX_RUN), they pay for every match and
## add to the drop chances. "Элитные чаще" rolls the auras again.
static func set_run(t: Tournament, list: Array) -> void:
	var picked: Array = []
	for id in list:
		var e := find(id)
		if t.hardcore and HARD_HAS.has(id):
			continue  # «Хардкор» holds it already
		if not e.is_empty() and e["pools"].has("run") and not picked.has(id) and picked.size() < MAX_RUN:
			picked.append(id)
	t.run_modifiers = (["hardcore"] if t.hardcore else []) + picked
	t.drop_bonus += RUN_LOOT * picked.size()
	add_auras(t)


# --- A match ------------------------------------------------------------------------

## The ids that apply this match: the run's conditions, the opponent's auras, --mods.
static func match_set(t: Tournament) -> Array:
	var out: Array = []
	if not enabled:
		return out
	var src: Array = forced.duplicate()
	if t != null:
		src += t.run_modifiers
		src += t.current_lineup()["mods"]
	for id in src:
		var e := find(id)
		if not e.is_empty() and not e.get("legacy", false) and not out.has(id):
			out.append(id)
	return out


## Tournament.modifier_value hook: the opponent's skill (added), speed and serve (x) from
## this match's modifiers. Main reads them when the match starts and resets them itself.
static func opp_value(t: Tournament, key: String, v: float) -> float:
	for id in match_set(t):
		for f in find(id)["fx"]:
			if f[0] == "opp" and f[1] == key:
				v = v + float(f[2]) if key == "skill" else v * float(f[2])
	return v


# --- How it looks -------------------------------------------------------------------

## Shown name: "???" while hidden.
static func label(id: String, lu := {}) -> String:
	if lu.get("hidden", []).has(id):
		return "???"
	var e := find(id)
	if e.is_empty():
		return String(Tournament.MODIFIERS.get(id, {}).get("name", id))
	return e["name"]


## For the opponent card (stream D) and the bracket: everything he comes with.
## [{id, name, desc, color, icon, rarity, hidden, reward}]
static func card(lu: Dictionary) -> Array:
	var out: Array = []
	for id in lu.get("mods", []):
		var e := find(id)
		if e.is_empty():
			continue
		var hid: bool = lu.get("hidden", []).has(id)
		out.append({"id": id, "name": "???" if hid else e["name"], "desc": "Раскроется на первом очке" if hid else e["desc"],
			"color": e["color"], "icon": "?" if hid else e["icon"], "rarity": int(e["rarity"]), "hidden": hid,
			"reward": float(e["reward"]), "aura": not e.get("legacy", false)})
	return out


## The bracket's line: "Ауры: Туман, ???  ·  призовые ×1.4".
static func bracket_text(lu: Dictionary) -> String:
	var names: Array[String] = []
	for id in lu.get("mods", []):
		names.append(label(id, lu))
	if names.is_empty():
		return ""
	var x := reward(lu["mods"])
	return "Модификаторы: " + ", ".join(names) + ("   ·   призовые ×%s" % _k(x) if x > 1.001 else "")


static func _k(x: float) -> String:
	return str(snappedf(x, 0.01)).trim_suffix(".0")


## Affix templates for stream A's items: {id, name, desc, fx}. ModEffects.apply runs them.
static func item_templates() -> Array:
	return LIST.filter(func(e): return e["target"] == "item")
