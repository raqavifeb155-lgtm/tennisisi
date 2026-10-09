class_name Academy
extends RefCounted
## The club's school (docs/superpowers/specs/2026-10-09-tycoon.md 3): the students (1-3), the
## candidates the player picks from, a visiting star, the academy building's levels, growth
## after every run of the hero, the camps and the sparring. Logic and data only - no UI, no
## world: the screens (scripts/ui/screens/academy_*.gd), the club's people (ClubNpcLife) and
## later the academy's house read this. Saved in SaveData.academy:
##   students   [student]            (JuniorGen.make: + id, since, age0, focus, xp, trainings...)
##   cands      {key, list, rerolls}  the set on offer (the key says which season it is for)
##   free_given bool                  the first student is free, once
##   guest      {} | {name, until, ...} a visitor from the roster, for two runs
##   trained_at int                   the last run the students have trained for (sync)
##   news       [{id, name, stat, to}] what grew since the club last told it (take_news)
## The school is on the main court from the start: no building is needed for the first
## student. The academy (a building of a lot, its level in SaveData.club.levels.academy) adds
## room 1 -> 2 -> 3, a higher ceiling, faster growth, the camps, the scout's hint, rare students.

const SEASON := 4                   # runs a season (age and the set of candidates change)

# --- What the academy's level gives (index 0: no building) ---------------------------------
const CAPACITY := [1, 2, 2, 3, 3, 3]
const CEILING := [7, 7, 8, 9, 10, 10]           # no stat grows past this here
const XP_MULT := [1.0, 1.0, 1.1, 1.2, 1.3, 1.4]
const SET_SIZE := [3, 3, 3, 4, 4, 4]            # candidates in a set
const CAMP_FROM := 2                            # «Сборы» from this level
const SCOUT_HINT_FROM := 2                      # the scout tells one hidden trait of each
const RARE_FROM := 3                            # a rare (OP) candidate now and then

## The building's five levels (the first is what a lot costs: ClubLots.TYPES academy price).
## price is before ClubBuilds.CLUB_PRICE_SCALE, like the club's table.
const LEVELS := [
	{"title": "Детская площадка", "now": "мини-корт с низкой сеткой, лавка, стенка", "perk": "2 места",
		"price": 150, "line": "Своя площадка! Теперь учеников двое"},
	{"title": "Домик", "now": "домик-раздевалка и корзина мячей", "perk": "«Сборы», скаут видит скрытую черту, потолок 8",
		"price": 400, "line": "Домик готов. Можно устраивать сборы"},
	{"title": "Корт академии", "now": "корт с фонарями, доска расписания", "perk": "3 места, 4 кандидата, потолок 9, редкие таланты",
		"price": 750, "line": "Корт академии! Места на троих"},
	{"title": "Общежитие", "now": "двухэтажный корпус и флаги клуба", "perk": "потолок 10, рост ×1,3",
		"price": 1150, "line": "Общежитие. Ребята живут при клубе"},
	{"title": "Центр подготовки", "now": "стеклянный зал и табло с именами", "perk": "рост ×1,4",
		"price": 1700, "line": "Центр подготовки. Как у больших академий"},
]

# --- Growth --------------------------------------------------------------------------------
const RUN_XP := 120.0               # experience a run of the hero gives a student (spec 3.4)
const FOCUS_SHARE := 0.6            # into the focus; the rest shared by the other five
const LEAN_MULT := 1.5
const EVEN := "even"                # the focus «Равномерно»
const CAMP_PRICES := [60, 120, 200] # by how far he is (the mean of his stats < 4, < 6.5, else)
const CAMP_RUNS := 1.0              # a camp = one run of experience at once, once a season
const SPAR_RUNS := 0.5              # a sparring = half a run, all into the focus, once a run
const REROLL_COST := 30             # a new set: 30, 60, 120 within a season
const GUEST_CHANCE := 0.25
const GUEST_RUNS := 2
const RARE_CHANCE := 0.5            # in every second season, at the academy level 3+
const RARE_PRICE := 6.0
const NEWS_MAX := 12

## Hooks for the academy's house (docs/superpowers/specs/2026-10-10-academy-house.md 9.4): its
## rooms change these without editing this file. Each is a Callable, unset = no effect:
##   "capacity"     () -> int                   the seats (replaces the CAPACITY row)
##   "growth_mult"  (student, stat) -> float    on the experience of a stat (x)
##   "ceiling_add"  (student, stat) -> int      on the ceiling of a stat (+), the academy's cap too
##   "on_day"       (run: int) -> void          after a run's training (the house's day)
static var hooks := {}


static func set_hook(name: String, fn: Callable) -> void:
	if fn.is_valid():
		hooks[name] = fn
	else:
		hooks.erase(name)


static func _hook(name: String) -> Callable:
	var fn: Callable = hooks.get(name, Callable())
	return fn if fn.is_valid() else Callable()


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
	if not d.has("trained_at"):
		d["trained_at"] = SaveData.played
	return d


static func students() -> Array:
	return data()["students"]


static func student(id: String) -> Dictionary:
	for s in students():
		if s["id"] == id:
			return s
	return {}


# --- The building -------------------------------------------------------------------------------

static func is_built() -> bool:
	return ClubLots.is_placed("academy") and int(SaveData.club.get("levels", {}).get("academy", 0)) > 0


## 0 without the building, else 1..5.
static func level() -> int:
	return clampi(int(SaveData.club.get("levels", {}).get("academy", 0)), 0, LEVELS.size()) if ClubLots.is_placed("academy") else 0


static func _at(arr: Array) -> Variant:
	return arr[clampi(level(), 0, arr.size() - 1)]


static func level_title(lv := -1) -> String:
	var l := level() if lv < 0 else lv
	return "без здания" if l <= 0 else String(LEVELS[mini(l, LEVELS.size()) - 1]["title"])


## The next level's record ({} at the top or without the building: the first is bought on a lot).
static func next_level() -> Dictionary:
	var lv := level()
	if not is_built() or lv >= LEVELS.size():
		return {}
	return LEVELS[lv]


static func level_price(lv: int) -> int:
	return roundi(float(LEVELS[clampi(lv, 1, LEVELS.size()) - 1]["price"]) * ClubBuilds.CLUB_PRICE_SCALE)


static func next_price() -> int:
	return level_price(level() + 1) if not next_level().is_empty() else 0


## "" when the next level can be bought now; else why not, short, for the button.
static func why_not_upgrade() -> String:
	if not is_built():
		return "Сначала построй академию на участке"
	if next_level().is_empty():
		return "Академия построена целиком"
	if SaveData.gold < next_price():
		return "Нужно ещё %d" % (next_price() - SaveData.gold)
	return ""


## Buys the next level of the building: the gold goes, the level is up and saved.
static func upgrade() -> bool:
	if why_not_upgrade() != "":
		return false
	var price := next_price()
	SaveData.gold -= price
	SaveData.club["spent"] = int(SaveData.club.get("spent", 0)) + price
	var levels: Dictionary = SaveData.club.get("levels", {}).duplicate()
	levels["academy"] = level() + 1
	SaveData.club["levels"] = levels
	SaveData.save()
	return true


## The coach's line for a level just built.
static func level_line(lv: int) -> String:
	return String(LEVELS[lv - 1]["line"]) if lv >= 1 and lv <= LEVELS.size() else ""


static func capacity() -> int:
	var fn := _hook("capacity")
	return int(fn.call()) if fn.is_valid() else int(_at(CAPACITY))


static func is_full() -> bool:
	return students().size() >= capacity()


static func camps_open() -> bool:
	return level() >= CAMP_FROM


# --- Candidates ---------------------------------------------------------------------------------

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
	var seed_v := hash("academy_%s_%d_%d" % [key, reroll, students().size()])
	var list := JuniorGen.candidates(seed_v, int(_at(SET_SIZE)), 0 if key == "free" else tier())
	if key == "free":
		for s in list:
			s["price"] = 0
		return list
	if level() >= SCOUT_HINT_FROM:
		for s in list:
			scout_hint(s)
	if rare_due(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("academy_rare_%s_%d" % [key, reroll])
		var op := JuniorGen.make_rare(rng, tier())
		op["id"] = "r%d_%d" % [absi(seed_v) % 100000, reroll]
		list.append(op)
	return list


## The scout's word: one hidden trait of the candidate shows on his card already.
static func scout_hint(c: Dictionary) -> void:
	for t in c.get("traits", []):
		if bool(t.get("hidden", false)):
			var rev: Array = c.get("revealed", [])
			if not rev.has(t["id"]):
				rev.append(t["id"])
			c["revealed"] = rev
			c["scouted"] = t["id"]
			return


## A rare, overpowered talent in this season's set: at the academy level 3+, in every second
## season, one time in two (so never more than one in two seasons), by the season's seed.
static func rare_due(key: String) -> bool:
	if level() < RARE_FROM or not key.begins_with("s"):
		return false
	var s := int(key.substr(1))
	if s % 2 != 0:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("academy_rare_season_%d" % s)
	return rng.randf() < RARE_CHANCE


## A new set costs 30, 60, 120 (and 120 again) within a season.
static func reroll_cost() -> int:
	return REROLL_COST * (1 << mini(int(data()["cands"].get("rerolls", 0)), 2))


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
	sync()   # the ones already here train for the runs played first: he starts from now
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


## A famous player drops by (after run `run`: GUEST_CHANCE, seeded by the run's number).
static func roll_visit(run := -1) -> void:
	var at := SaveData.played if run < 0 else run
	var d := data()
	var g: Dictionary = d["guest"]
	if (not g.is_empty() and at < int(g.get("until", 0))) or at < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guest_%d" % at)
	if rng.randf() >= GUEST_CHANCE:
		return
	var o: Dictionary = Opponents.ROSTER[rng.randi() % Opponents.ROSTER.size()]
	d["guest"] = {"roster": o["id"], "name": o["name"], "until": at + GUEST_RUNS, "seed": rng.randi()}


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
	st["traits"] = Traits.roll_student(rng, 2, 1, 1)
	st["price"] = roundi(JuniorGen.price(st) * 1.5 / 5.0) * 5
	return st


# --- Growth ---------------------------------------------------------------------------------------------

## The XP a stat step costs: n -> n+1.
static func cost(n: int) -> float:
	return roundf(40.0 * pow(float(n), 1.4))


## How high his stats can grow by his potential and traits alone (4 + 6 x potential).
static func potential_ceiling(st: Dictionary) -> int:
	var g := Traits.growth_of(Traits.all_ids(st), int(st.get("trainings", 0)))
	return clampi(4 + roundi(6.0 * float(st.get("pot", 0.5))) + int(g["ceiling_add"]), 3, 10)


## How high they grow here: his own ceiling, never past the academy's (spec 3.4). `stat`: one
## stat's (the house may lift a stat's ceiling, "ceiling_add").
static func ceiling(st: Dictionary, stat := "") -> int:
	var add := 0
	var fn := _hook("ceiling_add")
	if fn.is_valid():
		add = int(fn.call(st, stat))
	return mini(potential_ceiling(st) + add, int(_at(CEILING)) + add)


static func focus_of(st: Dictionary) -> String:
	return String(st.get("focus", EVEN))


## The focus: a stat key (60% of the experience goes there) or EVEN.
static func set_focus(id: String, key: String) -> bool:
	var st := student(id)
	if st.is_empty() or not (key == EVEN or Opponents.STAT_KEYS.has(key)):
		return false
	st["focus"] = key
	SaveData.save()
	return true


## [experience gathered, experience the next step costs] of a stat (need 0 at his ceiling).
static func progress(st: Dictionary, k: String) -> Array:
	var n := int(st["stats"][k])
	var have := float((st.get("xp", {}) as Dictionary).get(k, 0.0))
	return [have, 0.0 if n >= ceiling(st, k) else cost(n)]


## `runs` runs' worth of experience for one student: 60% into the focus and 40% shared (or all
## into the focus: `focus_only`), x1.5 on his leanings, x his potential, traits and the
## academy. The stats go up as the steps are paid, never past the ceiling. [{id, name, stat, to}].
static func train(st: Dictionary, runs: float, focus_only := false) -> Array:
	var grew: Array = []
	var g := Traits.growth_of(Traits.all_ids(st), int(st.get("trainings", 0)))
	var pot_mult := 0.8 + 0.5 * float(st.get("pot", 0.5))
	var xp := RUN_XP * runs * pot_mult * float(g["xp_mult"]) * float(_at(XP_MULT))
	var keys: Array = Opponents.STAT_KEYS
	var focus := focus_of(st)
	var leans: Array = st.get("leanings", [])
	var main_k := focus if focus != EVEN else (String(leans[0]) if not leans.is_empty() else String(keys[0]))
	var xps: Dictionary = st.get("xp", {})
	for k in keys:
		var share := 1.0 / float(keys.size())
		if focus != EVEN:
			share = FOCUS_SHARE if k == focus else (1.0 - FOCUS_SHARE) / float(keys.size() - 1)
		if focus_only:
			share = 1.0 if k == main_k else 0.0
		if (st.get("leanings", []) as Array).has(k):
			share *= LEAN_MULT
		var gm := _hook("growth_mult")
		xps[k] = float(xps.get(k, 0.0)) + xp * share * (float(gm.call(st, k)) if gm.is_valid() else 1.0)
		var cap := ceiling(st, k)
		while int(st["stats"][k]) < cap and float(xps[k]) >= cost(int(st["stats"][k])):
			xps[k] = float(xps[k]) - cost(int(st["stats"][k]))
			st["stats"][k] = int(st["stats"][k]) + 1
			grew.append({"id": st["id"], "name": String(st.get("name", "")), "stat": k, "to": int(st["stats"][k])})
		if int(st["stats"][k]) >= cap:
			xps[k] = minf(float(xps[k]), cost(int(st["stats"][k])))   # no hoard past the ceiling
	st["xp"] = xps
	return grew


## Experience after a run of the hero: every student who was here trains, a hidden trait may
## show, a visitor may come. `run`: which run this is (the latest by default). Returns what grew
## (it is also kept for the club's news).
static func on_run(run := -1) -> Array:
	var at := SaveData.played if run < 0 else run
	var d := data()
	var grew: Array = []
	for st in students():
		if int(st.get("since", 0)) >= at:
			continue   # came after that run
		st["trainings"] = int(st.get("trainings", 0)) + 1
		grew += train(st, 1.0)
		Traits.reveal(st, "")
	roll_visit(at)
	d["trained_at"] = maxi(int(d["trained_at"]), at)
	_add_news(grew)
	var day := _hook("on_day")
	if day.is_valid():
		day.call(at)
	return grew


## Catches the school up with the hero: one training for every run played since the last
## (the club and the screens call it; nothing in the match or the save has to). Saves.
static func sync() -> Array:
	var d := data()
	var grew: Array = []
	var from := int(d["trained_at"])
	if from >= SaveData.played:
		d["trained_at"] = SaveData.played   # an older copy of the save came back: count from it
		return grew
	for r in range(from + 1, SaveData.played + 1):
		grew += on_run(r)
	SaveData.save()
	return grew


static func _add_news(grew: Array) -> void:
	if grew.is_empty():
		return
	var d := data()
	var n: Array = d.get("news", [])
	n += grew
	d["news"] = n.slice(maxi(0, n.size() - NEWS_MAX))


## What grew since the club last said it, taken (the list empties).
static func take_news() -> Array:
	var d := data()
	var n: Array = d.get("news", [])
	d["news"] = []
	return n


## «Миша: подача 5, форхенд 4 · Аня: сетка 3» (the last value of each stat).
static func news_text(news: Array) -> String:
	var by := {}
	var order: Array = []
	for g in news:
		var nm := String(g.get("name", "")).get_slice(" ", 0)
		if not by.has(nm):
			by[nm] = {}
			order.append(nm)
		(by[nm] as Dictionary)[g["stat"]] = int(g["to"])
	var parts: Array[String] = []
	for nm in order:
		var stats: Array[String] = []
		for k in by[nm]:
			stats.append("%s %d" % [String(Opponents.STAT_NAMES[k]).to_lower(), int(by[nm][k])])
		parts.append("%s: %s" % [nm, ", ".join(stats)])
	return " · ".join(parts)


# --- Paid training ----------------------------------------------------------------------------------

static func _mean(st: Dictionary) -> float:
	var s := 0.0
	for k in Opponents.STAT_KEYS:
		s += float(st["stats"][k])
	return s / float(Opponents.STAT_KEYS.size())


## «Сборы»: a run's experience at once, once a season per student; dearer the further he is.
static func camp_price(st: Dictionary) -> int:
	var m := _mean(st)
	var p := float(CAMP_PRICES[0 if m < 4.0 else (1 if m < 6.5 else 2)])
	p *= 1.0 - float(Traits.growth_of(Traits.all_ids(st))["camp_discount"])
	return maxi(5, roundi(p / 5.0) * 5)


static func why_not_camp(st: Dictionary) -> String:
	if not camps_open():
		return "Сборы — с академии «%s»" % String(LEVELS[CAMP_FROM - 1]["title"])
	if int(st.get("camp_season", -1)) == season():
		return "Сборы уже были в этом сезоне"
	if SaveData.gold < camp_price(st):
		return "Нужно ещё %d" % (camp_price(st) - SaveData.gold)
	return ""


static func camp(id: String) -> Array:
	var st := student(id)
	if st.is_empty() or why_not_camp(st) != "":
		return []
	SaveData.gold -= camp_price(st)
	st["camp_season"] = season()
	st["trainings"] = int(st.get("trainings", 0)) + 1
	var grew := train(st, CAMP_RUNS)
	Traits.reveal(st, "")
	SaveData.save()
	return grew


## A sparring with the hero or the coach: half a run into the focus, once a run, for the
## coach's hour.
static func spar_price(st: Dictionary) -> int:
	return roundi((15.0 + 5.0 * _mean(st)) / 5.0) * 5


static func why_not_spar(st: Dictionary) -> String:
	if int(st.get("spar_run", -1)) == SaveData.played:
		return "Спарринг уже был после этого забега"
	if SaveData.gold < spar_price(st):
		return "Нужно ещё %d" % (spar_price(st) - SaveData.gold)
	return ""


static func spar(id: String) -> Array:
	var st := student(id)
	if st.is_empty() or why_not_spar(st) != "":
		return []
	SaveData.gold -= spar_price(st)
	st["spar_run"] = SaveData.played
	var grew := train(st, SPAR_RUNS, true)
	SaveData.save()
	return grew


# --- T-4: experience from a match ------------------------------------------------------------------------

## Experience into one stat of a student (a match, a coach's setup): the steps are paid as in
## on_run, never past the ceiling. Returns [{id, stat, to}] of what grew.
static func give_xp(st: Dictionary, key: String, amount: float) -> Array:
	var grew: Array = []
	if amount <= 0.0 or not (st.get("stats", {}) as Dictionary).has(key):
		return grew
	var xps: Dictionary = st.get("xp", {})
	xps[key] = float(xps.get(key, 0.0)) + amount
	var cap := ceiling(st)
	while int(st["stats"][key]) < cap and float(xps[key]) >= cost(int(st["stats"][key])):
		xps[key] = float(xps[key]) - cost(int(st["stats"][key]))
		st["stats"][key] = int(st["stats"][key]) + 1
		grew.append({"id": st["id"], "stat": key, "to": int(st["stats"][key])})
	st["xp"] = xps
	return grew
