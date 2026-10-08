class_name Academy
extends RefCounted
## The club's school (spec 3): the students (1-3), the candidates the player picks from, a
## visiting star, growth after every run of the hero. Saved in SaveData.academy:
##   students   [student]            (JuniorGen.make: + id, since, age0, focus, xp...)
##   cands      {key, list, rerolls}  the set on offer (the key says which season it is for)
##   free_given bool                  the first student is free, once
##   guest      {} | {name, until, ...} a visitor from the roster, for two runs
## The school is on the main court from the start: no building needed for the first student
## (the academy building, T-3 on, adds room: 1 -> 2 -> 3).

const CAPACITY := [1, 2, 2, 3, 3, 3]
const SEASON := 4                   # runs a season (age and the set of candidates change)
const REROLL_COST := 30
const GUEST_CHANCE := 0.25
const GUEST_RUNS := 2


static func data() -> Dictionary:
	var d: Dictionary = SaveData.academy
	if not d.has("students"):
		d["students"] = []
	if not d.has("cands"):
		d["cands"] = {"key": "", "list": [], "rerolls": 0}
	if not d.has("free_given"):
		d["free_given"] = false
	if not d.has("guest"):
		d["guest"] = {}
	return d


static func students() -> Array:
	return data()["students"]


static func student(id: String) -> Dictionary:
	for s in students():
		if s["id"] == id:
			return s
	return {}


static func level() -> int:
	return int(SaveData.club.get("levels", {}).get("academy", 0)) if ClubLots.is_placed("academy") else 0


static func capacity() -> int:
	return int(CAPACITY[clampi(level(), 0, CAPACITY.size() - 1)])


static func is_full() -> bool:
	return students().size() >= capacity()


## The coach brings the first student after the first run, for nothing.
static func free_ready() -> bool:
	return SaveData.played >= 1 and not bool(data()["free_given"]) and students().is_empty()


## The season the club is in (4 runs each).
static func season() -> int:
	return SaveData.played / SEASON


static func age(st: Dictionary) -> int:
	return int(st.get("age0", st.get("age", 15))) + (SaveData.played - int(st.get("since", SaveData.played))) / SEASON


static func tier() -> int:
	return mini(SaveData.played / 8, 3)


## What is on offer now (made once for the season, kept in the save).
static func candidates() -> Array:
	if SaveData.played < 1:
		return []   # nobody comes before the first run
	var d := data()
	var c: Dictionary = d["cands"]
	var key := "free" if free_ready() else "s%d" % season()
	if String(c["key"]) != key:
		d["cands"] = {"key": key, "list": _make_set(key, 0), "rerolls": 0}
		c = d["cands"]
	return c["list"]


static func _make_set(key: String, reroll: int) -> Array:
	var n := 4 if level() >= 3 else 3
	var seed_v := hash("academy_%s_%d_%d" % [key, reroll, students().size()])
	var list := JuniorGen.candidates(seed_v, n, 0 if key == "free" else tier())
	if key == "free":
		for s in list:
			s["price"] = 0
	return list


static func reroll_cost() -> int:
	return REROLL_COST * (1 << mini(int(data()["cands"].get("rerolls", 0)), 3))


## A fresh set for gold (the first student's set can't be changed).
static func reroll() -> bool:
	var d := data()
	if free_ready() or SaveData.gold < reroll_cost():
		return false
	SaveData.gold -= reroll_cost()
	var c: Dictionary = d["cands"]
	var n := int(c.get("rerolls", 0)) + 1
	d["cands"] = {"key": c["key"], "list": _make_set(String(c["key"]), n), "rerolls": n}
	SaveData.save()
	return true


## Why a candidate can't be taken ("" = can): no room, no gold.
static func why_not(c: Dictionary) -> String:
	if is_full():
		return "Нет мест: %d из %d" % [students().size(), capacity()]
	var pr := int(c.get("price", 0))
	if SaveData.gold < pr:
		return "Нужно ещё %d" % (pr - SaveData.gold)
	return ""


## Takes the candidate with this id: the gold goes, the others leave. {} if it can't be.
static func hire(cid: String) -> Dictionary:
	var d := data()
	var from_guest := cid == "guest"
	var c: Dictionary = {}
	if from_guest:
		c = guest_candidate()
	else:
		for x in candidates():
			if x["id"] == cid:
				c = x
	if c.is_empty() or why_not(c) != "":
		return {}
	var was_free := free_ready()
	SaveData.gold -= int(c.get("price", 0))
	var st: Dictionary = c.duplicate(true)
	st["id"] = "s%d" % (int(d.get("next_id", 0)) + 1)
	d["next_id"] = int(d.get("next_id", 0)) + 1
	st["age0"] = int(st["age"])
	st["since"] = SaveData.played
	st["hired_for"] = int(c.get("price", 0))
	(d["students"] as Array).append(st)
	if from_guest:
		d["guest"] = {}
	else:
		# This season's set is used up (the free set's key becomes the season's: no new set at once).
		d["cands"] = {"key": "s%d" % season(), "list": [], "rerolls": int(d["cands"].get("rerolls", 0))}
	if was_free:
		d["free_given"] = true
	SaveData.save()
	return st


static func release(id: String) -> bool:
	var list := students()
	for i in list.size():
		if list[i]["id"] == id:
			list.remove_at(i)
			SaveData.save()
			return true
	return false


# --- The visitor ------------------------------------------------------------------------------------

static func guest() -> Dictionary:
	var g: Dictionary = data()["guest"]
	if not g.is_empty() and SaveData.played >= int(g.get("until", 0)):
		data()["guest"] = {}
		return {}
	return g


## A famous player drops by (after a run: GUEST_CHANCE, seeded by the run count).
static func roll_visit() -> void:
	var d := data()
	if not guest().is_empty() or SaveData.played < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guest_%d" % SaveData.played)
	if rng.randf() >= GUEST_CHANCE:
		return
	var o: Dictionary = Opponents.ROSTER[rng.randi() % Opponents.ROSTER.size()]
	d["guest"] = {"roster": o["id"], "name": o["name"], "until": SaveData.played + GUEST_RUNS, "seed": rng.randi()}


## The visitor as a candidate (dearer than a local, adult, the roster's own stats).
static func guest_candidate() -> Dictionary:
	var g := guest()
	if g.is_empty():
		return {}
	var o := Opponents.find(String(g["roster"]))
	if o.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g.get("seed", 1))
	var st := {"id": "guest", "seed": int(g.get("seed", 1)), "name": String(o["name"]), "age": 24, "pot": 0.6, "look": o.get("look", Looks.random(rng)),
		"stats": Opponents.stats(o), "leanings": ["serve", "forehand"], "revealed": [], "matches": 0, "watched": 0, "trainings": 0, "xp": {}, "rating": 1200,
		"focus": "serve", "origin": "guest"}
	st["traits"] = Traits.roll(rng, 2, 1, 1)
	st["price"] = roundi(JuniorGen.price(st) * 1.5 / 5.0) * 5
	return st


# --- Growth ---------------------------------------------------------------------------------------------

## The XP a stat step costs: n -> n+1.
static func cost(n: int) -> float:
	return roundf(40.0 * pow(float(n), 1.4))


static func ceiling(st: Dictionary) -> int:
	var g := Traits.growth_of(Traits.all_ids(st), int(st.get("trainings", 0)))
	var base := 4 + roundi(6.0 * float(st.get("pot", 0.5)))
	return clampi(base + int(g["ceiling_add"]) + (2 if level() >= 3 else 0), 3, 10)


## Experience after a run of the hero: every student trains (60% into the focus, 40% in the
## rest); the numbers go up when the step is paid, never past the ceiling. Returns
## [{id, stat, to}] of what grew (for the club's notice).
static func on_run() -> Array:
	var grew: Array = []
	for st in students():
		st["trainings"] = int(st.get("trainings", 0)) + 1
		var g := Traits.growth_of(Traits.all_ids(st), int(st["trainings"]))
		var pot_mult := 0.8 + 0.5 * float(st.get("pot", 0.5))
		var xp := 120.0 * pot_mult * float(g["xp_mult"])
		var gain := {}
		var keys: Array = Opponents.STAT_KEYS
		for k in keys:
			var share := 0.6 if k == st.get("focus", "serve") else 0.4 / float(keys.size() - 1)
			if (st.get("leanings", []) as Array).has(k):
				share *= 1.5
			gain[k] = xp * share
		var xps: Dictionary = st.get("xp", {})
		for k in keys:
			xps[k] = float(xps.get(k, 0.0)) + float(gain[k])
			var cap := ceiling(st)
			while int(st["stats"][k]) < cap and float(xps[k]) >= cost(int(st["stats"][k])):
				xps[k] = float(xps[k]) - cost(int(st["stats"][k]))
				st["stats"][k] = int(st["stats"][k]) + 1
				grew.append({"id": st["id"], "stat": k, "to": int(st["stats"][k])})
		st["xp"] = xps
		Traits.reveal(st, "")
	roll_visit()
	return grew
