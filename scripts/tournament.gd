class_name Tournament
extends RefCounted
## One run = one knockout tournament: four opponents, then the boss in the final.
## Win -> pick a reward -> next stage. Lose -> a wildcard replays the match,
## without one the run is over. Pure state, no nodes: the UI and Main drive it.

enum State { BRACKET, REWARD, LOST, OVER }

const TIER_NAME := "Клубный турнир"
const GOLD_PER_WIN := [10, 15, 20, 30, 50]
const CHAMPION_BONUS := 50

## Match formats, chosen when the tournament starts. Longer matches pay more: the
## multipliers scale gold now and skill experience once skills exist.
## In the quick format the final is best of three tiebreaks.
const FORMATS := [
	{
		"id": "tiebreak", "name": "Тай-брейк", "desc": "Один тай-брейк до 7. Быстро, но опыта и золота мало",
		"sets": 1, "games": 0, "tb_at": 0, "final_sets": 2, "reward": 0.4,
	},
	{
		"id": "set6", "name": "Сет до 6", "desc": "Один сет до 6 геймов, тай-брейк при 6:6",
		"sets": 1, "games": 6, "tb_at": 6, "final_sets": 1, "reward": 1.0,
	},
	{
		"id": "fast4", "name": "Два сета до 4", "desc": "До двух выигранных сетов по 4 гейма, тай-брейк при 3:3",
		"sets": 2, "games": 4, "tb_at": 3, "final_sets": 2, "reward": 1.25,
	},
]

var format := 0                   # index into FORMATS
var state := State.BRACKET
var stage := 0                    # index into Opponents.ROSTER
var wildcards := 0
var perks: Array = []             # ids of the run perks taken
var results: Array = []           # per match: {"stage", "won", "score"}
var gold := 0
var champion := false
var offer: Array = []             # reward cards on the REWARD screen


func opponent() -> Dictionary:
	return Opponents.ROSTER[mini(stage, Opponents.ROSTER.size() - 1)]


func round_name(i := -1) -> String:
	return Opponents.ROUND_NAMES[stage if i < 0 else i]


func rounds() -> int:
	return Opponents.ROSTER.size()


func _init(format_index := 0) -> void:
	format = clampi(format_index, 0, FORMATS.size() - 1)


func format_info() -> Dictionary:
	return FORMATS[format]


## A fresh scoreboard for the current match.
func new_score(first_server: int) -> MatchScore:
	var f := format_info()
	var sets_needed: int = f["final_sets"] if opponent().get("boss", false) else f["sets"]
	return MatchScore.new(sets_needed, f["games"], f["tb_at"], first_server, opponent()["short"])


func gold_for_win(i: int) -> int:
	return roundi(GOLD_PER_WIN[i] * float(format_info()["reward"]))


## Records a finished match and moves the run on.
func record_match(won: bool, score_text: String, rng: RandomNumberGenerator) -> void:
	results.append({"stage": stage, "won": won, "score": score_text})
	if won:
		gold += gold_for_win(stage)
		stage += 1
		if stage >= rounds():
			champion = true
			gold += roundi(CHAMPION_BONUS * float(format_info()["reward"]))
			state = State.OVER
		else:
			offer = Rewards.offer(perks, rng)
			state = State.REWARD
	else:
		state = State.LOST if wildcards > 0 else State.OVER


func take_reward(i: int) -> void:
	if state != State.REWARD or i < 0 or i >= offer.size():
		return
	var card: Dictionary = offer[i]
	if card["kind"] == "wildcard":
		wildcards += 1
	elif card["kind"] == "perk":
		perks.append(card["id"])
	offer = []
	state = State.BRACKET


## Spend a wildcard after a loss: the same match is replayed.
func use_wildcard() -> bool:
	if state != State.LOST or wildcards <= 0:
		return false
	wildcards -= 1
	state = State.BRACKET
	return true


func give_up() -> void:
	state = State.OVER


## How far the run got, for the summary screen.
func finish_text() -> String:
	if champion:
		return "Чемпион! %s" % TIER_NAME
	return "Вылет: %s" % round_name()
