class_name Bets
## The betting desk of the Club, «Тотализатор» (v0.2 A-3, HOW_TO_FISH_TAKEAWAYS 3.2):
## the «Мяч в поле» wheel and a bet on your own match. Game gold only — never Stars, never
## money, nothing to cash out. The odds are honest and written on the table; the wheel's
## field is drawn before the animation, which only shows it. Opens after the first title.
## After three lost bets in a row the desk suggests a break (betting stays open).

const FIELDS := 37                # 0 is the net, odd fields blue, even fields red
const PAYS := {"blue": 2, "red": 2, "net": 35}
const CHIPS := [10, 25, 50, 100]
const MAX_SHARE := 0.25           # a stake is at most a quarter of the gold
const BREAK_AFTER := 3
## A bet on your own match: the odds by round (Джумхур .. Джокович); a clean sweep (the
## opponent takes at most one game, two points in the quick format) pays SWEEP_X more.
const MATCH_ODDS := [1.3, 1.8, 2.5, 3.5, 6.0]
const SWEEP_X := 2.5


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


static func max_stake(gold: int) -> int:
	return floori(gold * MAX_SHARE)


## The chips the player may put down with this much gold.
static func chips_for(gold: int) -> Array:
	return CHIPS.filter(func(c): return c <= max_stake(gold))


static func match_odds(stage: int, sweep: bool) -> float:
	var k: float = MATCH_ODDS[clampi(stage, 0, MATCH_ODDS.size() - 1)]
	return k * SWEEP_X if sweep else k


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
## can't take it back). One per match; at most a quarter of the gold.
static func place_match(t: Tournament, stake: int, sweep: bool) -> bool:
	if not t.bet.is_empty() or stake <= 0 or stake > max_stake(SaveData.gold):
		return false
	SaveData.gold -= stake
	t.bet = {"stake": stake, "odds": match_odds(t.stage, sweep), "sweep": sweep, "stage": t.stage}
	SaveData.save()
	return true


## The match is over (sb: its final board): pays the bet out or lets it go. Returns the
## gold paid (0 = lost).
static func settle_match(t: Tournament, sb: MatchScore) -> int:
	if t.bet.is_empty():
		return 0
	var won := sb.winner == 0 and (not bool(t.bet["sweep"]) or swept(sb))
	var paid := roundi(int(t.bet["stake"]) * float(t.bet["odds"])) if won else 0
	SaveData.gold += paid
	note(SaveData.bets, won)
	t.bet = {}
	SaveData.save()
	return paid
