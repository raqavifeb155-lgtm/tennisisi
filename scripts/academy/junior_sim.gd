class_name JuniorSim
extends RefCounted
## The instant result of a junior's tiebreak (spec 4, ACADEMY_LEGACY_TZ 6.5): no scene, no
## frames, a pure function of two stat dictionaries and a seed. A match that nobody came to
## watch, the «Итог» button, and a match left midway (it goes on from the score it had) all end
## here. Points are drawn one by one:
##
##   p(the server wins the point) = P0 + sum of COEF * (what the server has - what the other has)
##
## COEF/P0 were fitted to live `--junior-duel` tiebreaks (Bot against OpponentAI, 4 stat grids)
## and checked on cases the fit never saw: the table is in the spec (T-4), the share of points
## stays within 3 percentage points of the live match. A setup of the coach changes the share of
## the student's points for four points by `JuniorBot.effect_pp(fit)` (fading over two), the
## same numbers the live match is calibrated to.
##
## The tiebreak is the game's own (MatchScore): to 7, two clear, the first server serves one
## point, then two each.

const P0 := 0.60
## serve vs the returner's hands and legs / rallying / legs / net / stamina
const C_SERVE := 0.030
const C_RALLY := 0.020
const C_SPEED := 0.012
const C_NET := 0.008
const C_STAMINA := 0.004
const P_MIN := 0.30
const P_MAX := 0.88
const TO := 7


## The student's stats as the sim reads them.
static func _pack(stats: Dictionary) -> Dictionary:
	var fh := float(stats.get("forehand", 3))
	var bh := float(stats.get("backhand", 3))
	var sp := float(stats.get("speed", 3))
	return {"serve": float(stats.get("serve", 3)), "rally": (fh + bh) * 0.5, "speed": sp, "net": float(stats.get("net", 3)),
		"stamina": float(stats.get("stamina", 3)), "ret": (fh + bh + sp) / 3.0}


## The chance the server takes the point.
static func p_server(s: Dictionary, r: Dictionary) -> float:
	var p := P0 + C_SERVE * (float(s["serve"]) - float(r["ret"])) + C_RALLY * (float(s["rally"]) - float(r["rally"])) \
		+ C_SPEED * (float(s["speed"]) - float(r["speed"])) + C_NET * (float(s["net"]) - float(r["net"])) \
		+ C_STAMINA * (float(s["stamina"]) - float(r["stamina"]))
	return clampf(p, P_MIN, P_MAX)


## Who serves point number i (0-based) when `first` serves the first: 1-2-2-2...
static func server_of(i: int, first: int) -> int:
	return first if ((i + 1) / 2) % 2 == 0 else 1 - first


## The student's chance (side 0) at the point `i`, before any setup.
static func p_student(a: Dictionary, b: Dictionary, i: int, first: int) -> float:
	var pa := _pack(a)
	var pb := _pack(b)
	if server_of(i, first) == 0:
		return p_server(pa, pb)
	return 1.0 - p_server(pb, pa)


## Plays a tiebreak. a: the student (stats, traits), b: the opponent profile (Opponents-like).
## opts: seed (default 1), first (0 = the student serves first), from [pa, pb] (the score to go
## on from), setups [{at: points played when it was chosen, id}] (the live match's advice so far),
## autopilot (true: the coach picks his own setups by the rules of the live match).
## Returns {pa, pb, winner (0 student), log [winner per point], served_first, stances [..],
##          match_point (a match point stood at some moment)}.
static func simulate(a: Dictionary, b: Dictionary, opts := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	var first := int(opts.get("first", 0))
	var from: Array = opts.get("from", [0, 0])
	var pa := int(from[0])
	var pb := int(from[1])
	var sa: Dictionary = a.get("stats", {})
	var sb: Dictionary = Opponents.stats(b)
	var setups: Array = (opts.get("setups", []) as Array).duplicate(true)
	var autopilot := bool(opts.get("autopilot", false))
	var tired := float(opts.get("tired", 0.0))
	var log_: Array = []
	var match_point := false
	var streak_b := 0
	var count := setups.size()
	var last_at := -99
	for s in setups:
		last_at = maxi(last_at, int(s["at"]))
	var played := pa + pb
	var fit_cache := {}
	while true:
		if (pa >= TO or pb >= TO) and absi(pa - pb) >= 2:
			break
		var i := played
		var p := p_student(sa, sb, i, first)
		# A setup of the coach in force: 4 points at full weight, then 2 fading out.
		for s in setups:
			var age := i - int(s["at"])
			if age < 0:
				continue
			var w := 1.0 if age < JuniorBot.POINTS_PER_STANCE else maxf(1.0 - float(age - JuniorBot.POINTS_PER_STANCE + 1) / float(JuniorBot.FADE_POINTS + 1), 0.0)
			if w <= 0.0:
				continue
			var id := String(s["id"])
			if not fit_cache.has(id):
				fit_cache[id] = JuniorBot.fit(id, a, b, tired)
			p += JuniorBot.effect_pp(float(fit_cache[id])) / 100.0 * w
		p = clampf(p, 0.05, 0.95)
		var won_a := rng.randf() < p
		if won_a:
			pa += 1
			streak_b = 0
		else:
			pb += 1
			streak_b += 1
		played += 1
		log_.append(0 if won_a else 1)
		if maxi(pa, pb) >= TO - 1 and absi(pa - pb) >= 1:
			match_point = true
		if autopilot and not ((pa >= TO or pb >= TO) and absi(pa - pb) >= 2):
			var sit := JuniorBot.situation(pa, pb, streak_b, 1.0, played - last_at, count, 0.35, pb >= TO - 1 and pb - pa >= 1)
			if sit != "":
				var opts_ := JuniorBot.options_for(sit, server_of(played, first) == 0)
				var id := JuniorBot.pick(opts_, a, b, 1, tired)
				setups.append({"at": played, "id": id})
				last_at = played
				count += 1
	return {"pa": pa, "pb": pb, "winner": 0 if pa > pb else 1, "log": log_, "first": first, "stances": setups, "match_point": match_point}


## Share of the student's points in a result.
static func share(r: Dictionary) -> float:
	return float(r["pa"]) / maxf(float(int(r["pa"]) + int(r["pb"])), 1.0)


## The student's chance to win the tiebreak (a few hundred plays of the same pair).
static func win_chance(a: Dictionary, b: Dictionary, n := 200) -> float:
	var w := 0
	for k in n:
		if int(simulate(a, b, {"seed": 7919 * (k + 1), "first": k % 2})["winner"]) == 0:
			w += 1
	return float(w) / float(n)
