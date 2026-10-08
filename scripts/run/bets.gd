class_name Bets
## The betting desk of the Club, «Тотализатор» (v0.2 A-3, HOW_TO_FISH_TAKEAWAYS 3.2):
## the «Мяч в поле» wheel and the bookmaker (bets on a match, for and against yourself). Game gold only — never Stars, never
## money, nothing to cash out. The odds are honest and written on the table; the wheel's
## field is drawn before the animation, which only shows it. Opens after the first title.
## After three lost bets in a row the desk suggests a break (betting stays open).

const FIELDS := 37                # 0 is the net, odd fields blue, even fields red
const PAYS := {"blue": 2, "red": 2, "net": 35}
const CHIPS := [10, 25, 50, 100]
const MAX_SHARE := 0.25           # a stake is at most a quarter of the gold
const BREAK_AFTER := 3

# --- The bookmaker: a bet on a match (v0.2 E-5) -----------------------------------------
# The odds come from the chance of winning, like a betting shop: k = (1 - MARGIN) / p,
# rounded to 0.01 and kept in K_MIN..K_MAX. Both sides are on the board: on yourself
# (k_you) and against yourself (k_opp, the opponent's side). Betting against yourself is
# a risk: after the match there is a chance of a disqualification (DQ_ON_LOSS when the
# match was lost, DQ_ON_WIN when it was won) unless the player has the «Ушлый» trait.
# `market(match)` takes any match as plain data (a pupil, a final, a guest): see there.

const MARGIN := 0.08              # the house keeps 8%: k = 0.92 / p
const K_MIN := 1.05
const K_MAX := 9.0
const P_MIN := 0.04               # the chance stays honest but never a sure thing
const P_MAX := 0.96
const LEVEL_SLOPE := 0.45         # logit of the chance per skill level over the opponent's rating
const FORM_WEIGHT := 1.2          # logit of a full streak of wins (history of the last matches)
const FORM_KEEP := 10
const FORM_MIN := 3               # fewer matches in the book: no form yet
const DQ_ON_LOSS := 0.35          # against yourself, the match lost (the bet wins)
const DQ_ON_WIN := 0.10           # against yourself, the match won (the bet burns)
const DQ_FINE := 0.20             # of the saved gold
const HISTORY_KEEP := 12
const SIDES := ["self", "against"]
const SHADY := "shady"            # the trait's key: Skills.mod("shady") (perk «Ушлый») or club traits


static var last_result := {}      # the last settled bet: won, paid, side, dq, fine, stake


## A roster opponent's rating in skill levels: the level at which the player wins about
## half of his matches. From his stats (1.4 x mean - 2.2) and his tier (3 + 8.5 x skill)
## half and half; calibrated on the D-5 bot table (all skills level 8: 80/83/57/92/35%).
static func rating(opp: Dictionary, extra := 0.0) -> float:
	var st := Opponents.stats(opp)
	var sum := 0.0
	for k in Opponents.STAT_KEYS:
		sum += float(st[k])
	var by_stats := 1.4 * sum / float(Opponents.STAT_KEYS.size()) - 2.2
	var by_tier := 3.0 + 8.5 * float(opp.get("skill", 0.5))
	return 0.5 * (by_stats + by_tier) + extra


## The chance that side A (the player) wins: level against rating, a little for the form
## (`form`: his share of wins in the last matches, `form_n` of them).
static func p_win(level: float, rating_b: float, form := 0.5, form_n := 0) -> float:
	var x := LEVEL_SLOPE * (level - rating_b)
	if form_n >= FORM_MIN:
		x += FORM_WEIGHT * (form - 0.5)
	return clampf(1.0 / (1.0 + exp(-x)), P_MIN, P_MAX)


## The odds for a chance p (the stake comes back inside it): 0.92 / p, 0.01 steps, 1.05..9.
static func odds_from_p(p: float) -> float:
	return clampf(snappedf((1.0 - MARGIN) / clampf(p, 0.001, 1.0), 0.01), K_MIN, K_MAX)


## The board for ANY match, as plain data. `m` is either {"p": chance of side A} or
## {"level": A's skill level, "rating": B's rating, "form": share, "form_n": n}; extras
## ("name", "stage", ...) are carried through. Returns {p, p_opp, you, opp, overround}:
## `you` pays on A (yourself), `opp` pays on B. No UI here: a pupil's match, a tournament
## final or a guest's can use it as it is.
static func market(m: Dictionary) -> Dictionary:
	var p: float
	if m.has("p"):
		p = clampf(float(m["p"]), P_MIN, P_MAX)
	else:
		p = p_win(float(m.get("level", 0.0)), float(m.get("rating", 5.0)), float(m.get("form", 0.5)), int(m.get("form_n", 0)))
	var out := {"p": p, "p_opp": 1.0 - p, "you": odds_from_p(p), "opp": odds_from_p(1.0 - p)}
	out["overround"] = 1.0 / float(out["you"]) + 1.0 / float(out["opp"])
	for k in m:
		if not out.has(k) and k != "level" and k != "rating":
			out[k] = m[k]
	return out


## The coming match (or round i) of a run as a match for `market`.
static func match_for(t: Tournament, i := -1) -> Dictionary:
	var idx := t.stage if i < 0 else i
	var o: Dictionary = Opponents.ROSTER[clampi(idx, 0, Opponents.ROSTER.size() - 1)]
	var lu: Dictionary = t.lineup[idx] if idx < t.lineup.size() else {}
	var extra := 0.0
	if lu.get("golden", false):
		extra += 1.0
	extra += 0.3 * float((lu.get("mods", []) as Array).size())
	var f := form_of(SaveData.bets)
	return {"level": Opponents.player_level(), "rating": rating(o, extra), "form": f[0], "form_n": f[1],
		"name": String(o["name"]), "stage": idx}


static func match_market(t: Tournament, i := -1) -> Dictionary:
	return market(match_for(t, i))


## The player's last matches (1 won, 0 lost) as the desk remembers them: [share, count].
static func form_of(state: Dictionary) -> Array:
	var l: Array = state.get("form", [])
	if l.is_empty():
		return [0.5, 0]
	var w := 0
	for r in l:
		w += int(r)
	return [float(w) / float(l.size()), l.size()]


static func note_form(state: Dictionary, won: bool) -> void:
	var l: Array = state.get("form", [])
	l.append(1 if won else 0)
	while l.size() > FORM_KEEP:
		l.pop_front()
	state["form"] = l


## The trait that takes the disqualification risk away (the perk «Ушлый» of the Касание
## skill; the traits catalog of the academy, when it is in the game, can put "shady" into
## the club's traits too).
static func is_shady() -> bool:
	return Skills.mod(SHADY) > 0.0 or (SaveData.club.get("traits", []) as Array).has(SHADY)


## The chance of a disqualification after this match for a bet on this side.
static func dq_chance(side: String, player_won: bool) -> float:
	if side != "against" or is_shady():
		return 0.0
	return DQ_ON_WIN if player_won else DQ_ON_LOSS


## The roll for a match, fixed by the run's seed and the round (a reload gives the same):
## true = disqualified.
static func dq_roll(seed_value: int, stage: int, chance: float) -> bool:
	if chance <= 0.0:
		return false
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, stage, "dq"])
	return r.randf() < chance


static func unlocked() -> bool:
	return SaveData.titles >= 1


static func color_of(field: int) -> String:
	if field == 0:
		return "net"
	return "blue" if field % 2 == 1 else "red"


static func spin(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, FIELDS - 1)


## What a bet returns (the stake included); 0 = lost.
static func payout(bet: String, stake: int, field: int) -> int:
	return stake * int(PAYS[bet]) if color_of(field) == bet else 0


## The biggest stake: a quarter of the gold, but never less than the table's smallest chip
## (`min_chip`) while the gold covers that chip: with 10-39 gold one smallest chip can go.
static func max_stake(gold: int, min_chip := 0) -> int:
	var q := floori(gold * MAX_SHARE)
	if min_chip > 0 and gold >= min_chip:
		return maxi(q, min_chip)
	return q


## The text when not even the smallest chip is affordable.
static func need_text(min_chip: int) -> String:
	return "Нужно хотя бы %d золота" % min_chip


## The chips the player may put down with this much gold.
static func chips_for(gold: int) -> Array:
	return CHIPS.filter(func(c): return c <= max_stake(gold, CHIPS[0]))


## The player won and the opponent took at most one game (two points in the quick format).
static func swept(sb: MatchScore) -> bool:
	if sb.winner != 0:
		return false
	var theirs := 0
	for s in sb.set_scores:
		theirs += int(s[1])
	return theirs <= (2 if sb.games_per_set == 0 else 1)


## A settled bet into the desk's record (SaveData.bets): placed, won, loss_streak.
static func note(state: Dictionary, won: bool) -> void:
	state["placed"] = int(state.get("placed", 0)) + 1
	if won:
		state["won"] = int(state.get("won", 0)) + 1
		state["loss_streak"] = 0
	else:
		state["loss_streak"] = int(state.get("loss_streak", 0)) + 1


static func needs_break(state: Dictionary) -> bool:
	return int(state.get("loss_streak", 0)) >= BREAK_AFTER


## A bet on the coming match of the run: the stake leaves the saved gold at once (a reload
## can't take it back). One per match; at most Bets.max_stake. side: "self" or "against"
## (against yourself: the opponent's odds, and the disqualification risk). The odds are
## written down now: they do not move after the bet.
static func place_match(t: Tournament, stake: int, side := "self") -> bool:
	if not t.bet.is_empty() or stake <= 0 or stake > max_stake(SaveData.gold, CHIPS[0]) or not SIDES.has(side):
		return false
	var mk := match_market(t)
	SaveData.gold -= stake
	t.bet = {"stake": stake, "side": side, "odds": float(mk["you"] if side == "self" else mk["opp"]),
		"p": float(mk["p"] if side == "self" else mk["p_opp"]), "stage": t.stage, "name": String(mk["name"])}
	SaveData.save()
	return true


## The match is over (sb: its final board): pays the bet out or lets it go; after a bet
## against yourself the dice of the disqualification roll. Returns the gold paid (0 = lost);
## the rest of what happened is in Bets.last_result.
static func settle_match(t: Tournament, sb: MatchScore) -> int:
	last_result = {}
	if t.bet.is_empty():
		return 0
	var side := String(t.bet.get("side", "self"))
	var player_won := sb.winner == 0
	var won: bool
	if side == "against":
		won = not player_won
	else:
		won = player_won and (not bool(t.bet.get("sweep", false)) or swept(sb))  # old saves: the sweep bet
	var stake := int(t.bet["stake"])
	var paid := roundi(stake * float(t.bet["odds"])) if won else 0
	var dq := dq_roll(t.rng.seed, int(t.bet.get("stage", t.stage)), dq_chance(side, player_won))
	var fine := 0
	if dq:
		paid = 0
		fine = floori(DQ_FINE * SaveData.gold)
		SaveData.gold -= fine
		t.disqualify()
		var cx: Array = SaveData.bets.get("codex", [])
		cx.append({"kind": "dq", "name": String(t.bet.get("name", "")), "stage": int(t.bet.get("stage", 0)), "stake": stake, "fine": fine})
		SaveData.bets["codex"] = cx
	SaveData.gold += paid
	note(SaveData.bets, won and not dq)
	var h: Array = SaveData.bets.get("history", [])
	h.append({"name": String(t.bet.get("name", "")), "side": side, "stake": stake, "odds": float(t.bet["odds"]), "won": won and not dq, "paid": paid, "dq": dq})
	while h.size() > HISTORY_KEEP:
		h.pop_front()
	SaveData.bets["history"] = h
	last_result = {"won": won and not dq, "paid": paid, "side": side, "dq": dq, "fine": fine, "stake": stake, "odds": float(t.bet["odds"])}
	t.bet = {}
	SaveData.save()
	return paid
