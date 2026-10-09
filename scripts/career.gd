class_name Career
## The hero's career (ACADEMY_LEGACY_TZ 3, stage L1; spec docs/superpowers/specs/2026-10-10-l1-career.md):
## 5 seasons of 4 tournaments, the 4th is the season final, rating points by the round of the
## exit, age 19 -> 31 and the experience multiplier it brings, the farewell season, the
## retirement (what stays with the club, what goes with the hero, one relic) and the heir out of
## three. Pure logic over SaveData.career; the screens are CareerUi
## (scripts/ui/screens/career_screens.gd). Counted from SaveData.record_run (on_run_banked).
##
## For the academy (stream T): register_heir_source() adds graduates to the heir pick, the
## retired heroes are SaveData.career["retired"] (future coaches), and the functions that take
## a career dictionary (new_career, bank_into, xp_mult_of) serve a pupil's own career too.

const VERSION := 1
const SEASONS := 5
const PER_SEASON := 4
const START_AGE := 19
const AGE_STEP := 3
const XP_MULT := [1.25, 1.15, 1.0, 0.85, 0.7]       # owner 08.10: growth slows, stats never fall
const SEASON_NAMES := ["Новичок тура", "Восходящая звезда", "Пик", "Опыт", "Прощальный сезон"]
const EARLY_FROM := 3                                # the early retirement: from the 3rd season
## Rating points by the round the run ended in (index), like the ATP; the title is TITLE_PTS.
const ROUND_PTS := [10, 45, 90, 180, 300]
const TITLE_PTS := 500
const FINAL_PTS := 2                                 # the season final counts double...
const FINAL_PRIZE := 1.5                             # ...and pays x1.5 (on the best open island)
const FAREWELL_PRIZE := 1.2                          # the farewell season's ovation
## The place among the top-100 for a season's points: ceil((RANK_TOP / pts) ^ RANK_POW).
## ~675 points (quarter- and semi-finals all season) is about 30th; 2600 is the first.
const RANK_TOP := 2600.0
const RANK_POW := 2.5
const RANK_NONE := 999
const AUCTION := 0.5                                 # the farewell auction: half the price
const HEIRS := 3
const FREE_TIERS := ["E", "E", "D"]                  # a free agent's tier, by the candidate's place
const NAME_MAX := 14                                 # the hero's name: fits the plate, the card, the ceremony
const RENAME_COST := 100                             # gold from the bank for a new name (the first hero's first change is free)

## The heir sources (register_heir_source): [{"id", "fn": Callable, "prio": int}].
static var _sources: Array = []


# --- The data -------------------------------------------------------------------------

## A fresh career dictionary (the hero's, or a pupil's: tycoon 3.7).
static func new_career(name := "", gen := 1, start_played := 0) -> Dictionary:
	return {
		"v": VERSION, "gen": gen, "id": "p%d" % gen, "name": name, "start_played": start_played,
		"season": 1, "in_season": 0, "age": START_AGE, "season_pts": 0, "cells": [], "seasons": [],
		"runs": 0, "titles": 0, "career_pts": 0, "best_rank": RANK_NONE, "season_due": 0,
		"retire_due": false, "early": false, "heirs": [], "origin": "start", "relic": {},
		"final_loc": "", "retired": [], "renames": 0,
	}


## Fills what an older or missing section lacks (ACADEMY_LEGACY_TZ 3.7: a save from before
## the career starts season 1, tournament 0, where it is now). Returns the same dictionary.
static func migrate(c: Dictionary, played: int) -> Dictionary:
	var base := new_career("", 1, played)
	for k in base:
		if not c.has(k):
			c[k] = base[k]
	if String(c["name"]) == "":
		c["name"] = default_name()  # an older save's first hero gets one: Telegram's, else a random one
	return c


## The active hero's career (SaveData.career), made on first use.
static func data() -> Dictionary:
	if not SaveData.career.has("v"):
		migrate(SaveData.career, SaveData.played)
	return SaveData.career


static func season() -> int:
	return clampi(int(data()["season"]), 1, SEASONS)


static func runs() -> int:
	return int(data()["runs"])


static func age_of(s: int) -> int:
	return START_AGE + AGE_STEP * (clampi(s, 1, SEASONS) - 1)


static func hero_name() -> String:
	var n := String(data()["name"])
	return n if n != "" else "Ты"


## The name on the match board (the little plate): the first word, upper case.
static func hero_short() -> String:
	return hero_name().get_slice(" ", 0).to_upper()


# --- The hero's name ------------------------------------------------------------------------

## A name as the player may keep it: only letters (Cyrillic, Latin), digits, a space and a
## hyphen, no doubled spaces, at most NAME_MAX; "" = nothing usable or a rude word.
static func clean_name(s: String) -> String:
	var t := ""
	for ch in s:
		var u := ch.unicode_at(0)
		var ok := (u >= 0x30 and u <= 0x39) or (u >= 0x41 and u <= 0x5A) or (u >= 0x61 and u <= 0x7A) \
			or (u >= 0x410 and u <= 0x44F) or u == 0x401 or u == 0x451 or u == 0x20 or u == 0x2D
		if ok and not (u == 0x20 and t.ends_with(" ")):
			t += ch
	t = t.strip_edges()
	if t.length() > NAME_MAX:
		t = t.left(NAME_MAX).strip_edges()
	while t.begins_with("-") or t.ends_with("-"):
		t = t.trim_prefix("-").trim_suffix("-").strip_edges()
	var low := t.to_lower()
	for w in ClubBuilds.BAD_WORDS:
		if low.contains(w):
			return ""
	return t


## A long name (the generator's «Властимил Кратохвил») made to fit: the first name alone, then cut.
static func fit_name(s: String) -> String:
	var t := s.strip_edges()
	if t.length() > NAME_MAX and t.contains(" "):
		t = t.get_slice(" ", 0)
	return clean_name(t)


## A random name from the opponents' generator (first name + surname, or the first name alone if too long).
static func random_name(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for _i in 8:
		var n := fit_name(String(Opponents.random(rng.randi() % 1000000 + 1, "E")["name"]))
		if n != "":
			return n
	return "Игрок"


## Telegram's first name (the web build inside Telegram), cleaned; "" outside it or if unusable.
static func telegram_name() -> String:
	if not OS.has_feature("web"):
		return ""
	var r = JavaScriptBridge.eval("(window.Telegram && Telegram.WebApp && Telegram.WebApp.initDataUnsafe && Telegram.WebApp.initDataUnsafe.user) ? Telegram.WebApp.initDataUnsafe.user.first_name : ''", true)
	return fit_name(String(r if r != null else ""))


## The first hero's default name: Telegram's, else a random one.
static func default_name() -> String:
	var n := telegram_name()
	return n if n != "" else random_name()


## What a rename costs now: 0 for the very first hero's first change, else RENAME_COST.
static func rename_cost() -> int:
	var c := data()
	return 0 if int(c["gen"]) == 1 and int(c["renames"]) == 0 else RENAME_COST


## "" = the name may be taken now; else why not: "empty", "same" (no change, no charge), "poor".
static func rename_problem(new_name: String) -> String:
	var n := clean_name(new_name)
	if n == "":
		return "empty"
	if n == String(data()["name"]):
		return "same"
	if SaveData.gold < rename_cost():
		return "poor"
	return ""


## The new name is confirmed: the gold leaves the bank, the name changes, the save is written.
## Returns "" or the problem (nothing changes and nothing is charged then).
static func rename(new_name: String) -> String:
	var why := rename_problem(new_name)
	if why != "":
		return why
	var c := data()
	SaveData.gold -= rename_cost()
	c["name"] = clean_name(new_name)
	c["renames"] = int(c["renames"]) + 1
	SaveData.save()
	return ""


## The experience multiplier of the hero's age (Main._gain_xp).
static func xp_mult() -> float:
	return xp_mult_of(data())


static func xp_mult_of(c: Dictionary) -> float:
	return float(XP_MULT[clampi(int(c.get("season", 1)), 1, SEASONS) - 1])


static func retire_due() -> bool:
	return bool(data()["retire_due"])


static func can_retire_early() -> bool:
	return season() >= EARLY_FROM and not retire_due()


## «Завершить карьеру сейчас» (Тренерская): the ceremony is due from now on.
static func request_early() -> void:
	if not can_retire_early():
		return
	var c := data()
	c["retire_due"] = true
	c["early"] = true


# --- Seasons, points, the place ----------------------------------------------------------

## Rating points of a closed run, before the final's x2: by the round it ended in.
static func points_for(t: Tournament) -> int:
	if t.champion:
		return TITLE_PTS
	if t.results.is_empty():
		return 0
	return ROUND_PTS[clampi(t.stage, 0, ROUND_PTS.size() - 1)]


static func rank_for(pts: int) -> int:
	if pts <= 0:
		return RANK_NONE
	return clampi(ceili(pow(RANK_TOP / float(pts), RANK_POW)), 1, RANK_NONE)


## Gold for the season's place: top-10 300, the top-100 100 + 20 for every 10 places above
## the 100th, outside 40 (every season brings something).
static func season_gold(rank: int) -> int:
	if rank <= 10:
		return 300
	if rank <= 100:
		return 100 + 20 * ((100 - rank) / 10)
	return 40


static func rank_text(rank: int) -> String:
	return "вне топ-100" if rank > 100 else "%d-е место" % rank


## The next tournament is the season final (the 4th of the season).
static func is_final_next() -> bool:
	return int(data()["in_season"]) == PER_SEASON - 1 and not retire_due()


## Where the final pays its bonus: the best island open when the season's 3rd run closed.
static func final_loc() -> String:
	var c := data()
	if String(c["final_loc"]) == "":
		c["final_loc"] = Locations.best_unlocked()
	return String(c["final_loc"])


## The run is the season final with the bonus (prizes x1.5, points x2).
static func is_final(t: Tournament) -> bool:
	return is_final_next() and t.location == final_loc()


## The career's prize multiplier of a run (Tournament.prize_mult): the season final, the
## farewell season. A banked run keeps the one it was played with.
static func prize_mult(t: Tournament) -> float:
	if t.banked and t.has_meta("career_mult"):
		return float(t.get_meta("career_mult"))
	var m := 1.0
	if is_final(t):
		m *= FINAL_PRIZE
	if season() == SEASONS:
		m *= FAREWELL_PRIZE
	return m


## SaveData.record_run: the run counts into the career. Returns what happened:
## {"pts", "final", "season_over": bool, "rank", "gold", "retire": bool}.
static func on_run_banked(t: Tournament) -> Dictionary:
	var c := data()
	if bool(c["retire_due"]):
		return {}  # the ceremony is not done yet: nothing counts twice
	t.set_meta("career_mult", prize_mult(t))
	var r := bank_into(c, t, is_final(t))
	if r.get("season_over", false):
		SaveData.gold += int(r["gold"])
		_emit("season_over", {"season": int(r["season"]), "pts": int(r["pts_season"]), "rank": int(r["rank"]),
			"gold": int(r["gold"]), "retire": bool(r["retire"])})
	if int(c["in_season"]) == PER_SEASON - 1:
		c["final_loc"] = Locations.best_unlocked()  # the final goes to the best island open now
	return r


## One run into a career dictionary (the hero's or a pupil's). final: the run was the
## season final with its bonus.
static func bank_into(c: Dictionary, t: Tournament, final := false) -> Dictionary:
	var pts := points_for(t) * (FINAL_PTS if final else 1)
	c["in_season"] = int(c["in_season"]) + 1
	c["runs"] = int(c["runs"]) + 1
	c["season_pts"] = int(c["season_pts"]) + pts
	c["career_pts"] = int(c["career_pts"]) + pts
	if t.champion:
		c["titles"] = int(c["titles"]) + 1
	var cells: Array = c["cells"]
	cells.append({"loc": t.location, "pts": pts, "round": Locker.exit_round(t), "champion": t.champion, "final": final})
	var r := {"pts": pts, "final": final, "season_over": false, "retire": false}
	if int(c["in_season"]) < PER_SEASON:
		return r
	var s := clampi(int(c["season"]), 1, SEASONS)
	var spts := int(c["season_pts"])
	var rank := rank_for(spts)
	var titles := 0
	for cell in cells:
		if cell["champion"]:
			titles += 1
	var gold := season_gold(rank)
	(c["seasons"] as Array).append({"season": s, "pts": spts, "rank": rank, "titles": titles, "gold": gold, "cells": cells.duplicate(true)})
	c["best_rank"] = mini(int(c["best_rank"]), rank)
	c["season_due"] = s
	r.merge({"season_over": true, "season": s, "pts_season": spts, "rank": rank, "gold": gold}, true)
	if s >= SEASONS:
		c["retire_due"] = true  # the 20th run: the farewell
		r["retire"] = true
		return r
	c["season"] = s + 1
	c["age"] = age_of(s + 1)
	c["in_season"] = 0
	c["season_pts"] = 0
	c["cells"] = []
	c["final_loc"] = ""
	return r


## The last closed season ({} = none yet).
static func last_season() -> Dictionary:
	var ss: Array = data()["seasons"]
	return ss.back() if not ss.is_empty() else {}


# --- Heirs --------------------------------------------------------------------------------

## The academy (stream T) adds its graduates: fn.call(ctx) -> Array of candidates (see the
## spec, 4), ctx = {"gen", "seed", "count", "retiring"}. Higher prio comes first; the same id
## replaces the old entry. Static: register at every start (the academy's setup).
static func register_heir_source(id: String, fn: Callable, prio := 0) -> void:
	for i in range(_sources.size() - 1, -1, -1):
		if _sources[i]["id"] == id:
			_sources.remove_at(i)
	_sources.append({"id": id, "fn": fn, "prio": prio})
	_sources.sort_custom(func(a, b): return int(a["prio"]) > int(b["prio"]))


static func clear_heir_sources() -> void:
	_sources = []


## The three to choose from at this retirement, fixed once made (career.heirs): the sources
## by priority, then free agents.
static func heir_candidates() -> Array:
	var c := data()
	var cached: Array = c["heirs"]
	if not cached.is_empty():
		return cached
	var seed_v := ("heir:%d:%d:%d" % [int(c["gen"]), int(c["start_played"]), int(c["runs"])]).hash()
	var ctx := {"gen": int(c["gen"]), "seed": seed_v, "count": HEIRS, "retiring": record()}
	var out: Array = []
	for src in _sources:
		if out.size() >= HEIRS:
			break
		var got = (src["fn"] as Callable).call(ctx)
		if not got is Array:
			continue
		for cand in got:
			if out.size() >= HEIRS:
				break
			var n := normalize(cand, String(src["id"]), seed_v + out.size())
			if not n.is_empty():
				out.append(n)
	var free := free_agents(HEIRS, seed_v)
	var i := 0
	while out.size() < HEIRS and i < free.size():
		out.append(free[i])
		i += 1
	c["heirs"] = out
	return out


## A source's candidate made safe: the keys the screens and retire() read; {} = unusable.
static func normalize(cand, origin: String, seed_v: int) -> Dictionary:
	if not cand is Dictionary or String((cand as Dictionary).get("name", "")) == "":
		return {}
	var d: Dictionary = (cand as Dictionary).duplicate(true)
	var levels := {}
	for id in Skills.LIST:
		var lv := clampi(int((d.get("levels", {}) as Dictionary).get(id, 0)), 0, Skills.MAX_LEVEL)
		if lv > 0:
			levels[id] = lv
	d["levels"] = levels
	if (d.get("look", {}) as Dictionary).is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		d["look"] = Looks.random(r)
	d["look"] = Looks.sanitize(d["look"])
	d["id"] = String(d.get("id", "%s%d" % [origin, absi(seed_v) % 100000]))
	d["origin"] = String(d.get("origin", origin))
	d["age"] = int(d.get("age", START_AGE))
	d["short"] = String(d.get("short", String(d["name"]).get_slice(" ", 1).to_upper()))
	var fitted := fit_name(String(d["name"]))  # the hero's name has a limit: the heir's too
	var nr := RandomNumberGenerator.new()
	nr.seed = seed_v
	d["name"] = fitted if fitted != "" else random_name(nr)
	d["perk"] = String(d.get("perk", ""))
	d["note"] = String(d.get("note", ""))
	d["traits"] = d.get("traits", [])
	d["stats"] = d.get("stats", {})
	return d


## Players with no academy behind them (ACADEMY_LEGACY_TZ 4.3): a random player by seed
## (Opponents.random, tier E/D), his form of play turned into a few levels (stat - 2, 0..3;
## touch from the forehand, the backhand and the net) on top of the starting points.
static func free_agents(n: int, seed_v: int) -> Array:
	var out: Array = []
	for i in n:
		var o := Opponents.random(absi(("free:%d:%d" % [seed_v, i]).hash()) % 1000000 + 1, FREE_TIERS[i % FREE_TIERS.size()], {"overpowered": false})
		var st: Dictionary = o["stats"]
		var lv := func(v) -> int: return clampi(int(round(float(v))) - 2, 0, 3)
		var levels := {
			"serve": lv.call(st.get("serve", 1)), "forehand": lv.call(st.get("forehand", 1)),
			"backhand": lv.call(st.get("backhand", 1)), "net": lv.call(st.get("net", 1)),
			"feet": lv.call(st.get("speed", 1)), "stamina": lv.call(st.get("stamina", 1)),
			"touch": lv.call((float(st.get("forehand", 1)) + float(st.get("backhand", 1)) + float(st.get("net", 1))) / 3.0),
		}
		out.append(normalize({"id": "free%d" % (absi(seed_v + i) % 100000), "name": o["name"], "short": o["short"],
			"look": o["look"], "levels": levels, "stats": st, "origin": "free", "age": START_AGE,
			"note": "свободный агент · %s" % String(Opponents.play_style(o)["name"]).to_lower()}, "free", seed_v + i))
	return out


# --- The retirement ---------------------------------------------------------------------

## The hero as he leaves: the record for career.retired (a future coach for stream T).
static func record() -> Dictionary:
	var c := data()
	var levels := {}
	var best := ""
	for id in Skills.LIST:
		levels[id] = Skills.level(id)
		if best == "" or int(levels[id]) > int(levels[best]):
			best = id
	return {
		"id": String(c["id"]), "gen": int(c["gen"]),
		"name": String(c["name"]) if String(c["name"]) != "" else "Игрок %d" % int(c["gen"]),
		"look": Looks.sanitize(SaveData.look), "seasons": (c["seasons"] as Array).size(), "runs": int(c["runs"]),
		"titles": int(c["titles"]), "best_rank": int(c["best_rank"]), "career_pts": int(c["career_pts"]),
		"levels": levels, "perks": Skills.perks.duplicate(), "best_skill": best, "relic": {},
		"early": bool(c["early"]), "played_at": SaveData.played,
	}


## What may become the relic: the last run's worn things and bag (not those its summary
## already put into the locker) and the locker's. [{"item", "from": "equip"|"bag"|"locker", "i"}]
static func relic_options(t: Tournament) -> Array:
	var out: Array = []
	for o in _run_things(t):
		out.append(o)
	var li := Locker.items()
	for i in li.size():
		out.append({"item": li[i], "from": "locker", "i": i})
	return out


## The last run's things that still belong to the hero (not banked into the locker).
static func _run_things(t: Tournament) -> Array:
	var out: Array = []
	if t == null:
		return out
	for o in Locker.candidates(t):
		if not Locker.items().has(o["item"]):
			out.append(o)
	return out


## The retirement in one step (a reload before it changes nothing): the hero goes into
## career.retired, the relic rides with the heir's first run, the rest of the last run is
## auctioned at half price, the personal (skills, perks, look) is the heir's from now on,
## and a new career starts. relic: one of relic_options() or {}. Returns the record.
static func retire(heir: Dictionary, relic: Dictionary, t: Tournament) -> Dictionary:
	var c := data()
	var rec := record()
	var item := {}
	var things := _run_things(t)  # before the relic leaves the locker: a copy kept there is not sold
	if not relic.is_empty():
		item = (relic["item"] as Dictionary).duplicate(true)
		if relic["from"] == "locker":
			Locker.take(int(relic["i"]))
	# The farewell auction: what the hero carried and nobody keeps goes for half its price.
	var sold := 0
	for o in things:
		if not item.is_empty() and relic["from"] != "locker" and o["item"] == relic["item"]:
			continue
		sold += roundi(Items.price(o["item"]) * AUCTION)
	if t != null:
		for s in Gear.SLOTS:
			t.equip[s] = {}
		t.bag = []
	SaveData.gold += sold
	if not item.is_empty():
		item["relic"] = true
		item["relic_of"] = rec["name"]
		rec["relic"] = item.duplicate(true)
		Locker.next_items().append(item)
	(c["retired"] as Array).append(rec)
	# The heir.
	var h: Dictionary = heir if not heir.is_empty() else free_agents(1, int(c["runs"]) + 1)[0]
	var prof := Skills.profile_from_levels(h.get("levels", {}))
	if String(h.get("perk", "")) != "" and not Skills.find_perk(String(h["perk"])).is_empty():
		(prof["perks"] as Array).append(String(h["perk"]))
	Skills.load_profile(prof)
	Skills.gear = {}
	Skills.rebuild_pending()
	SaveData.look = Looks.sanitize(h.get("look", {}))
	var hn := String(h.get("name", ""))
	var next := new_career(hn if hn != "" else random_name(), int(c["gen"]) + 1, SaveData.played)
	next["origin"] = String(h.get("origin", "free"))
	next["relic"] = item.duplicate(true)
	next["retired"] = c["retired"]
	for k in next:
		c[k] = next[k]
	_emit("career_retired", {"record": rec, "heir": h})
	SaveData.save()
	return rec


static func _emit(sig: String, info: Dictionary) -> void:
	var ml := Engine.get_main_loop() as SceneTree
	var ev: Node = ml.root.get_node_or_null("GameEvents") if ml != null else null
	if ev != null and ev.has_signal(sig):
		ev.emit_signal(sig, info)
