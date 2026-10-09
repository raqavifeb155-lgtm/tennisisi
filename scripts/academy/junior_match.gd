class_name JuniorMatch
extends RefCounted
## The students' matches as data (spec 4): the schedule, the opponent, the booth's queue, the
## result and what it pays. Saved in the academy's section: SaveData.academy["jm"]
##   queue    [match]    waiting in the booth (never burns; one that was not watched before the
##                       next run is played out instantly, JuniorSim)
##   marks    {student id: the last run a match was scheduled for}
##   news     [text]     results nobody has been told yet (the TV strip, the coach)
##   log      [result]   the last RESULTS_KEPT results
##   advice   bool       the coach asks in the pauses (false: the autopilot decides)
##   seq      int        match ids
## A match: {id, sid, run, seed, first, tier, opp: {seed, tier, mean}, state ("wait" | "live"),
##           pa, pb (the score it was left at), played (points the player has watched), setups [{at, id}]}.
## Nothing runs in the background: the schedule is made when somebody asks (`sync`, from the club
## and from the booth), by the runs the hero has closed, the same every time (seeds).

const RESULTS_KEPT := 12
const WATCHED := 0.8                 # this share of the points seen = «просмотрен»
const BASE_XP := 40.0
const WATCH_MULT := 1.5
const STANCE_BONUS_XP := 10.0
const GOLD_MIN := 10
const GOLD_MAX := 25
const RATING_MIN := 800
const RATING_MAX := 1800
const CATCH_UP := 6                  # runs back that still get a match
## A setup that chimes with a leaning pays a little experience into that stat.
const STANCE_STAT := {"aggr": "forehand", "patient": "stamina", "net": "net", "body": "serve", "weak": "backhand", "change": "speed", "lob": "net", "legs": "stamina"}
## The tier of the island of the last run -> how much stronger than the student his opponent is.
const TIER_SHIFT := [-0.6, 0.0, 0.6, 1.2]
const TIER_LETTER := ["E", "D", "C", "B"]


static func data() -> Dictionary:
	var a := Academy.data()
	if not a.has("jm"):
		a["jm"] = {}
	var d: Dictionary = a["jm"]
	for k in {"queue": [], "marks": {}, "news": [], "log": [], "seq": 0}:
		if not d.has(k):
			d[k] = {"queue": [], "marks": {}, "news": [], "log": [], "seq": 0}[k]
	if not d.has("advice"):
		d["advice"] = true
	return d


static func advice_on() -> bool:
	return bool(data()["advice"])


static func set_advice(on: bool) -> void:
	data()["advice"] = on
	SaveData.save()


static func queue() -> Array:
	return data()["queue"]


static func find(id: String) -> Dictionary:
	for m in queue():
		if m["id"] == id:
			return m
	return {}


static func of_student(sid: String) -> Dictionary:
	for m in queue():
		if m["sid"] == sid:
			return m
	return {}


# --- Schedule ---------------------------------------------------------------------------------------------

## The tier (0..3) of the last run's island.
static func island_tier() -> int:
	var loc := String(SaveData.club.get("last_location", ""))
	if loc == "":
		return clampi(Academy.tier(), 0, 3)
	return clampi(ClubQuests.tier_of(loc), 0, 3)


## Whose turn it is after run `r`: everybody up to two students, two of three after that, by turns.
static func plays_after(index: int, count: int, r: int) -> bool:
	if count <= 2:
		return true
	return (index - r % count + count) % count < 2


static func mean_stat(stats: Dictionary) -> float:
	var s := 0.0
	for k in Opponents.STAT_KEYS:
		s += float(stats.get(k, 3))
	return s / float(Opponents.STAT_KEYS.size())


static func _make(st: Dictionary, r: int) -> Dictionary:
	var d := data()
	d["seq"] = int(d["seq"]) + 1
	var seed_v := absi(hash("jm_%s_%d_%d" % [st["id"], r, int(st.get("seed", 0))])) % 1000000 + 1
	var tier := island_tier()
	return {"id": "jm%d" % int(d["seq"]), "sid": st["id"], "run": r, "seed": seed_v, "first": seed_v % 2, "tier": tier,
		"opp": {"seed": seed_v + 17, "tier": tier, "mean": snappedf(mean_stat(st["stats"]), 0.01)},
		"state": "wait", "pa": 0, "pb": 0, "played": 0, "setups": []}


## The opponent of a match as an OpponentAI profile: a junior of the island (a random player's
## name, look and style) whose stats stand about where the student's stood when the match was
## made, moved by the island's tier (spec 4: «юниор острова»).
static func opponent_of(m: Dictionary) -> Dictionary:
	var o: Dictionary = m["opp"]
	var tier := clampi(int(o["tier"]), 0, 3)
	var p := Opponents.random(int(o["seed"]), String(TIER_LETTER[tier]), {"overpowered": false})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o["seed"])
	var lean: Dictionary = Opponents.STYLE_STATS.get(String(p["play_style"]), {})
	var stats := {}
	for k in Opponents.STAT_KEYS:
		var v := float(o["mean"]) + float(TIER_SHIFT[tier]) + 0.5 * float(lean.get(k, 0)) + rng.randf_range(-1.5, 1.5)
		stats[k] = clampi(roundi(v), 1, 10)
	p["stats"] = stats
	p["skill"] = clampf((mean_stat(stats) - 2.0) / 7.0, 0.0, 1.0)
	p["title"] = "Юниор"
	return p


## The rating of an opponent as the Elo sees it.
static func opponent_rating(opp: Dictionary) -> int:
	return clampi(roundi(600.0 + 130.0 * mean_stat(Opponents.stats(opp))), RATING_MIN, RATING_MAX)


## Makes the schedule current: a match for each student after each run the hero has closed (the
## ones no one came to are played out instantly), dropping the matches of those who left.
## Returns the results made now (the news).
static func sync() -> Array:
	Academy.sync()   # the school first: the runs that were played train the students
	var d := data()
	var out: Array = []
	var played := SaveData.played
	var studs := Academy.students()
	var q: Array = d["queue"]
	for i in range(q.size() - 1, -1, -1):
		if Academy.student(String(q[i]["sid"])).is_empty():
			q.remove_at(i)
	# Those waiting since an earlier run are played out now.
	for i in range(q.size() - 1, -1, -1):
		var m: Dictionary = q[i]
		if int(m["run"]) < played:
			out.append(play_out(m))
	var marks: Dictionary = d["marks"]
	for idx in studs.size():
		var st: Dictionary = studs[idx]
		var sid := String(st["id"])
		var mark := int(marks.get(sid, int(st.get("since", played)) - 1))
		for r in range(maxi(mark + 1, played - CATCH_UP), played + 1):
			if r != int(st.get("since", -1)) and not plays_after(idx, studs.size(), r):
				continue
			var m := _make(st, r)
			if r < played:
				out.append(resolve(m, st, {"mode": "sim"}))
			elif of_student(sid).is_empty():
				(d["queue"] as Array).append(m)
		marks[sid] = played
	if not out.is_empty():
		SaveData.save()
	return out


## A waiting match played out at once (nobody came, «Итог сразу», the next run began).
static func play_out(m: Dictionary, mode := "sim") -> Dictionary:
	var st := Academy.student(String(m["sid"]))
	if st.is_empty():
		(queue() as Array).erase(m)
		return {}
	return resolve(m, st, {"mode": mode})


## The tiebreak of a match to its end by the sim: from the score it was left at, by the setups
## made so far, the coach's autopilot after that. Completes it.
static func resolve(m: Dictionary, st: Dictionary, opts := {}) -> Dictionary:
	var opp := opponent_of(m)
	var r := JuniorSim.simulate(st, opp, {"seed": int(m["seed"]), "first": int(m["first"]), "from": [int(m["pa"]), int(m["pb"])],
		"setups": m.get("setups", []), "autopilot": true})
	var total := (r["log"] as Array).size() + int(m["pa"]) + int(m["pb"])
	return complete(m, st, int(r["pa"]), int(r["pb"]), {"mode": String(opts.get("mode", "sim")), "watched_points": int(m.get("played", 0)) + int(opts.get("watched_extra", 0)),
		"total_points": total, "setups": r["stances"], "match_point": bool(r["match_point"])})


## The result of a match: experience, rating, gold, the news. info: mode ("live" | "sim" | "left"),
## watched_points, total_points, setups, match_point. Removes it from the queue.
static func complete(m: Dictionary, st: Dictionary, pa: int, pb: int, info := {}) -> Dictionary:
	var d := data()
	var opp := opponent_of(m)
	var won := pa > pb
	var rating := int(st.get("rating", 1000))
	var orat := opponent_rating(opp)
	var k := clampf(0.5 + float(orat - rating) / 400.0, 0.0, 1.0)
	var delta := roundi(lerpf(15.0, 40.0, k)) if won else -roundi(lerpf(15.0, 5.0, k))
	var new_rating := clampi(rating + delta, RATING_MIN, RATING_MAX)
	var total := maxi(int(info.get("total_points", pa + pb)), 1)
	var seen := float(int(info.get("watched_points", 0))) / float(total)
	var watched := seen >= WATCHED and String(info.get("mode", "sim")) != "sim"
	var focus := Academy.focus_of(st)
	if focus == Academy.EVEN or not Opponents.STAT_KEYS.has(focus):
		var leans: Array = st.get("leanings", [])
		focus = String(leans[0]) if not leans.is_empty() else "serve"   # "Равномерно": the first leaning takes the match's experience
	var xp := BASE_XP * (WATCH_MULT if watched else 1.0)
	var grew: Array = Academy.give_xp(st, focus, xp)
	var bonus := ""
	for s in info.get("setups", []):
		var stat := String(STANCE_STAT.get(String(s["id"]), ""))
		if stat != "" and (st.get("leanings", []) as Array).has(stat):
			bonus = stat
	if bonus != "":
		grew.append_array(Academy.give_xp(st, bonus, STANCE_BONUS_XP))
	var gold := (GOLD_MIN + roundi(float(GOLD_MAX - GOLD_MIN) * k)) if won else 0
	SaveData.gold += gold
	st["rating"] = new_rating
	st["peak"] = maxi(int(st.get("peak", 0)), new_rating)
	st["matches"] = int(st.get("matches", 0)) + 1
	if watched:
		st["watched"] = int(st.get("watched", 0)) + 1
	var revealed: Array = Traits.reveal(st, "")
	revealed.append_array(Traits.reveal(st, "tiebreak"))
	if bool(info.get("match_point", true)):
		revealed.append_array(Traits.reveal(st, "breakpoint"))
	var name_a := String(st["name"]).get_slice(" ", 0)
	var score := "%d:%d" % [pa, pb]
	var res := {"id": m["id"], "sid": st["id"], "name": st["name"], "first_name": name_a, "opp": opp["name"], "opp_short": opp.get("short", opp["name"]),
		"opp_rating": orat, "pa": pa, "pb": pb, "score": score, "won": won, "rating_before": rating, "rating_after": new_rating, "delta": new_rating - rating,
		"gold": gold, "xp": xp, "focus": focus, "bonus_stat": bonus, "grew": grew, "revealed": revealed, "watched": watched, "seen": snappedf(seen, 0.01),
		"mode": String(info.get("mode", "sim")), "run": m["run"], "setups": (info.get("setups", []) as Array).size()}
	res["text"] = news_text(res)
	var q: Array = d["queue"]
	for i in q.size():
		if q[i]["id"] == m["id"]:
			q.remove_at(i)
			break
	(d["news"] as Array).append(res["text"])
	var lg: Array = d["log"]
	lg.append(res)
	while lg.size() > RESULTS_KEPT:
		lg.pop_front()
	SaveData.save()
	return res


## «Миша 7:5 у Тайлера Миллера» for the strip and the coach.
static func news_text(res: Dictionary) -> String:
	return "%s %s %s  ·  рейтинг %+d" % [res["first_name"], res["score"], "победа" if res["won"] else "поражение", int(res["delta"])]


## One line for the TV strip in the hero's match: «Академия: Миша 7:5 Тайлер Миллер».
static func strip_text(res: Dictionary) -> String:
	return "Академия: %s %s %s" % [res["first_name"], res["score"], res["opp_short"]]


## Results nobody has been told yet; they are marked told.
static func take_news() -> Array:
	var d := data()
	var out: Array = (d["news"] as Array).duplicate()
	d["news"] = []
	return out


# --- The academy's rating ----------------------------------------------------------------------------------

## The sum of the three best ratings of the students (spec 4).
static func academy_rating() -> int:
	var r: Array[int] = []
	for st in Academy.students():
		r.append(int(st.get("rating", 1000)))
	r.sort()
	r.reverse()
	var s := 0
	for i in mini(3, r.size()):
		s += r[i]
	return s


## The share of gold on the hero's wins the rating pays (T-5 reads it): +1% a step, up to +5%.
static func gold_bonus_pct() -> int:
	return clampi((academy_rating() - 3000) / 150, 0, 5)
