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

## Difficulty modifiers an opponent may come with. Each one makes the match harder and
## raises the chance that the opponent carries rare loot. ("Удвоение" — two opponents
## playing doubles — is the rarest one; it needs a doubles AI and comes later.)
const MODIFIERS := {
	"fast": {"name": "Быстрые ноги", "desc": "бегает на 12% быстрее", "speed": 1.12, "loot": 0.08},
	"steady": {"name": "Железный", "desc": "реже ошибается", "skill": 0.12, "loot": 0.08},
	"bomber": {"name": "Бомбардир", "desc": "подаёт на 12% быстрее", "serve": 1.12, "loot": 0.06},
}
const EPIC_CHANCE := 0.06         # an opponent walks on court with an epic racket
const LEGENDARY_CHANCE := 0.015   # ... or a legendary one
const BOSS_LOOT_BONUS := 0.12

var format := 0                   # index into FORMATS
var location := "park"            # Locations id: scenery, surface and ball physics
var lineup: Array = []            # per opponent: {"mods": [ids], "racket": item or {}}
var racket := {}                  # the player's racket this run (Gear item), {} = the stock one
var pending_loot := {}            # racket dropped by the opponent just beaten
var missed_loot := ""             # name of the racket lost in the trophy mini-game
var banked := false               # the run's gold has been added to the saved total
var rng := RandomNumberGenerator.new()
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


func _init(format_index := 0, seed_value := 0) -> void:
	format = clampi(format_index, 0, FORMATS.size() - 1)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	roll_lineup()


## Rolls every opponent's modifiers and the loot they carry, so it can be shown in the
## bracket before the match. The first opponent is the tutorial: no modifiers.
func roll_lineup() -> void:
	lineup = []
	for i in rounds():
		var mods: Array = []
		if i > 0:
			var n := 0
			var roll := rng.randf()
			if roll < 0.08 + 0.03 * i:
				n = 2
			elif roll < 0.3 + 0.05 * i:
				n = 1
			var ids: Array = MODIFIERS.keys()
			for k in n:
				var id: String = ids[rng.randi_range(0, ids.size() - 1)]
				if not mods.has(id):
					mods.append(id)
		var bonus := 0.0
		for id in mods:
			bonus += float(MODIFIERS[id]["loot"])
		if Opponents.ROSTER[i].get("boss", false):
			bonus += BOSS_LOOT_BONUS
		var item := {}
		var r := rng.randf()
		if r < LEGENDARY_CHANCE + bonus * 0.25:
			item = Gear.roll(Gear.LEGENDARY, rng)
		elif r < LEGENDARY_CHANCE + EPIC_CHANCE + bonus:
			item = Gear.roll(Gear.EPIC, rng)
		lineup.append({"mods": mods, "racket": item})


func current_lineup() -> Dictionary:
	return lineup[mini(stage, lineup.size() - 1)]


## Multiplier / bonus from the current opponent's modifiers ("speed", "serve", "skill").
func modifier_value(key: String) -> float:
	var v := 0.0 if key == "skill" else 1.0
	for id in current_lineup()["mods"]:
		var m: Dictionary = MODIFIERS[id]
		if m.has(key):
			v = v + float(m[key]) if key == "skill" else v * float(m[key])
	return v


func take_loot(equip: bool) -> void:
	if equip and not pending_loot.is_empty():
		racket = pending_loot
	pending_loot = {}


func tier_name() -> String:
	return Locations.find(location)["tour"]


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
func record_match(won: bool, score_text: String, r: RandomNumberGenerator) -> void:
	results.append({"stage": stage, "won": won, "score": score_text})
	missed_loot = ""
	if won:
		pending_loot = current_lineup()["racket"]
		gold += gold_for_win(stage)
		stage += 1
		if stage >= rounds():
			champion = true
			gold += roundi(CHAMPION_BONUS * float(format_info()["reward"]))
			state = State.OVER
		else:
			offer = Rewards.offer(perks, r)
			offer.insert(1, _item_card(r))
			state = State.REWARD
	else:
		state = State.LOST if wildcards > 0 else State.OVER


func take_reward(i: int) -> void:
	if state != State.REWARD or i < 0 or i >= offer.size():
		return
	var card: Dictionary = offer[i]
	if card["kind"] == "wildcard":
		wildcards += 1
	elif card["kind"] == "item":
		racket = card["item"]
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


## The gear card of the reward offer: usually common, sometimes rare.
func _item_card(r: RandomNumberGenerator) -> Dictionary:
	var item := Gear.roll(Gear.RARE if r.randf() < 0.3 else Gear.COMMON, r)
	return {"kind": "item", "item": item, "title": item["name"], "desc": Gear.describe(item)}


func give_up() -> void:
	state = State.OVER


## How far the run got, for the summary screen.
func finish_text() -> String:
	if champion:
		return "Чемпион! %s" % tier_name()
	return "Вылет: %s" % round_name()
