class_name JuniorGen
extends RefCounted
## Candidates for the academy (spec 3.3, 3.8): a name, an age, six stats 1..10 (the keys of
## Opponents.STAT_KEYS, so one dictionary feeds OpponentAI and AiProfile), a hidden
## potential 0..1 that the card shows as stars, two leanings (they grow x1.5), traits (one or
## two shown, up to two hidden), a look and a price. Everything is drawn from a seed: the
## same set every time the screen opens.

const FIRST := ["Миша", "Саша", "Даня", "Ваня", "Артём", "Кирилл", "Тимур", "Лёва", "Матвей", "Егор", "Рома", "Никита",
	"Аня", "Лена", "Соня", "Маша", "Катя", "Ира", "Варя", "Алиса", "Милана", "Ксюша", "Ярик", "Глеб", "Стёпа", "Макар"]
const LAST := ["Петров", "Соколов", "Орлов", "Волков", "Зайцев", "Белов", "Громов", "Ершов", "Жуков", "Карпов", "Лебедев", "Морозов",
	"Новиков", "Попов", "Румянцев", "Седов", "Тихонов", "Ушаков", "Фомин", "Чернов", "Шилов", "Юдин", "Яковлев", "Мартынов", "Крылов", "Назаров"]
## Age 13 -> 0.70 ... 18 -> 1.0 (the model's size, spec 2.2; the model code is stream H's, this is the data).
const GROWTH_AGES := [[13, 0.70], [14, 0.76], [15, 0.83], [16, 0.90], [17, 0.96], [18, 1.0]]
const PRICE_BASE := 60.0
const STAT_NAMES_SHORT := {"serve": "ПОД", "forehand": "ФОР", "backhand": "БЭК", "net": "СЕТ", "speed": "СКР", "stamina": "ВЫН"}


## The model's size at an age (smooth between the key ages).
static func junior_t(age: float) -> float:
	if age <= GROWTH_AGES[0][0]:
		return float(GROWTH_AGES[0][1])
	for i in range(1, GROWTH_AGES.size()):
		if age <= GROWTH_AGES[i][0]:
			var a: Array = GROWTH_AGES[i - 1]
			var b: Array = GROWTH_AGES[i]
			return lerpf(float(a[1]), float(b[1]), (age - float(a[0])) / (float(b[0]) - float(a[0])))
	return 1.0


## 1..5 stars of a potential.
static func stars(pot: float) -> int:
	return clampi(ceili(pot * 5.0 - 0.001), 1, 5)


## What the card says about the potential before a match has been watched: "3–4 ★".
static func stars_text(st: Dictionary) -> String:
	var s := stars(float(st.get("pot", 0.5)))
	if int(st.get("watched", 0)) > 0 or int(st.get("matches", 0)) >= 3:
		return "★".repeat(s) + "☆".repeat(5 - s)
	var lo := maxi(1, s - 1)
	var hi := mini(5, s)
	if s < 5 and (int(st.get("seed", 0)) % 2 == 0):
		lo = s
		hi = mini(5, s + 1)
	return "%d–%d ★" % [lo, hi]


static func price(st: Dictionary) -> int:
	var p := PRICE_BASE * (0.6 + float(st.get("pot", 0.5))) * (1.0 + 0.15 * float(Traits.rarity(st)))
	if int(st.get("age", 15)) >= 18:
		p *= 1.3
	return maxi(10, roundi(p / 5.0) * 5)


## One candidate. tier 0..3: how strong he is to begin with. `adult`: a visitor from the
## world (18+, higher stats, a lower ceiling).
static func make(rng: RandomNumberGenerator, tier: int, adult := false) -> Dictionary:
	var st := {}
	st["seed"] = rng.randi()
	st["name"] = "%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]
	st["age"] = rng.randi_range(18, 23) if adult else rng.randi_range(13, 17)
	st["pot"] = snappedf(rng.randf_range(0.35, 1.0) if not adult else rng.randf_range(0.3, 0.8), 0.01)
	st["look"] = Looks.random(rng)
	var keys: Array = Opponents.STAT_KEYS.duplicate()
	var lean: Array = []
	var pool := keys.duplicate()
	for i in 2:
		lean.append(pool.pop_at(rng.randi() % pool.size()))
	st["leanings"] = lean
	# Six stats from 1, the points thrown by weight (a leaning counts double), none past 8.
	var points := 14 + 4 * tier + (6 if adult else 0) + rng.randi_range(-2, 3)
	var stats := {}
	for k in keys:
		stats[k] = 1
	while points > 0:
		var weights: Array[float] = []
		for k in keys:
			weights.append(0.0 if int(stats[k]) >= 8 else (2.0 if lean.has(k) else 1.0))
		var total := 0.0
		for w in weights:
			total += w
		if total <= 0.0:
			break
		var r := rng.randf() * total
		for i in keys.size():
			r -= weights[i]
			if r <= 0.0 and weights[i] > 0.0:
				stats[keys[i]] = int(stats[keys[i]]) + 1
				break
		points -= 1
	st["stats"] = stats
	var n_vis := 1 + (1 if rng.randf() < 0.35 + 0.1 * tier else 0)
	var n_hid := (1 if rng.randf() < 0.5 else 0) + (1 if rng.randf() < 0.15 + 0.1 * tier else 0)
	st["traits"] = Traits.roll_student(rng, tier, n_vis, n_hid)
	st["revealed"] = []
	st["matches"] = 0
	st["watched"] = 0
	st["trainings"] = 0
	st["xp"] = {}
	st["rating"] = 1000
	st["focus"] = String(lean[0])
	st["price"] = price(st)
	return st


## `n` candidates of a seed (set of 3 or 4).
static func candidates(seed_v: int, n: int, tier: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out: Array = []
	for i in n:
		var c := make(rng, tier, false)
		c["id"] = "c%d_%d" % [absi(seed_v) % 100000, i]
		out.append(c)
	return out


## A card's lines for a stats row: "ПОД 6 · ФОР 7 · …".
static func stats_line(st: Dictionary) -> String:
	var parts: Array[String] = []
	for k in Opponents.STAT_KEYS:
		parts.append("%s %d" % [STAT_NAMES_SHORT[k], int(st["stats"][k])])
	return " · ".join(parts)
