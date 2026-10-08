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
const BOSS_LOOT_BONUS := 0.12
## v0.2 gear (ROGUELIKE_DESIGN 6.7): every opponent wears a racket, shoes and a wristband,
## each with its own rarity (common .. mythic), rolled up front and not shown in the
## bracket. Later rounds, modifiers and the boss move the odds up (ROUND_SHIFT + loot).
const GEAR_CHANCE := [0.62, 0.27, 0.08, 0.025, 0.005]
const SHIFT_SPLIT := [0.5, 0.3, 0.15, 0.05]   # where the shifted share goes: rare .. mythic
const ROUND_SHIFT := 0.04
## Beaten, each of his items drops on its own with this chance by rarity.
const DROP_CHANCE := [0.30, 0.20, 0.12, 0.06, 0.03]
const BAG_SIZE := 6
const SKILL_PER_RARITY := 0.01    # his gear makes him a little stronger

var format := 0                   # index into FORMATS
var location := "park"            # Locations id: scenery, surface and ball physics
var lineup: Array = []            # per opponent: {"mods": [ids], "gear": {slot: item}, "racket": gear.racket}
var equip := {"racket": {}, "shoes": {}, "band": {}}   # what the player wears ({} = the stock one)
## The player's racket: equip["racket"] (older code and old saves use this name).
var racket: Dictionary:
	get:
		return equip.get("racket", {})
	set(v):
		equip["racket"] = v
var bag: Array = []               # spare items (BAG_SIZE)
var new_items: Array = []         # what the last win put into the bag
var auto_sold := 0                # gold from items sold because the bag was full (last win)
var run_mods := {}                # mods that last the run (RunEffects run_mod, e.g. Корона)
var mythic_rolled := false        # a mythic already showed up this run (one per run)
var drop_bonus := 0.0             # added to the drop chances (1 = everything drops)
var bet := {}                     # a bet on the coming match (Bets): stake, odds, sweep
var pending_loot := {}            # the best epic+ item dropped by the opponent just beaten
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


const SAVED := ["format", "location", "lineup", "racket", "pending_loot", "missed_loot", "banked",
	"state", "stage", "wildcards", "perks", "results", "gold", "champion", "offer",
	"equip", "bag", "new_items", "auto_sold", "run_mods", "mythic_rolled", "drop_bonus", "bet"]


## The run as plain data, for the save file: a phone that reloads the page (Telegram
## in the background, low memory) must not lose a tournament in progress.
func to_dict() -> Dictionary:
	var d := {"rng_seed": rng.seed, "rng_state": rng.state}
	for k in SAVED:
		d[k] = get(k)
	return d


static func from_dict(d: Dictionary) -> Tournament:
	var t := Tournament.new(int(d.get("format", 0)), 1)
	for k in SAVED:
		if d.has(k):
			t.set(k, d[k])
	t.rng.seed = int(d.get("rng_seed", 1))
	t.rng.state = int(d.get("rng_state", 0))
	return t


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
		var gear := {}
		for slot in Gear.SLOTS:
			var rar := Gear.COMMON if i == 0 else _roll_rarity(ROUND_SHIFT * i + bonus)
			if rar == Gear.MYTHIC:
				if mythic_rolled:
					rar = Gear.LEGENDARY
				mythic_rolled = true
			gear[slot] = Gear.roll(rar, rng, slot)
		# A golden one (1 in 50, never the first): a legendary or better in his hand.
		var golden := i > 0 and rng.randf() < Golden.CHANCE
		if golden and int(gear["racket"]["rarity"]) < Gear.LEGENDARY:
			gear["racket"] = Gear.roll(Gear.LEGENDARY, rng, "racket")
		lineup.append({"mods": mods, "gear": gear, "racket": gear["racket"], "golden": golden})


## A rarity for an opponent's item: GEAR_CHANCE with `shift` moved from common upward.
func _roll_rarity(shift: float) -> int:
	var c: Array = GEAR_CHANCE.duplicate()
	var moved := minf(shift, c[0] - 0.1)
	c[0] -= moved
	for k in SHIFT_SPLIT.size():
		c[k + 1] += moved * SHIFT_SPLIT[k]
	var x := rng.randf()
	for r in range(Gear.MYTHIC, Gear.COMMON, -1):
		if x < c[r]:
			return r
		x -= c[r]
	return Gear.COMMON


func current_lineup() -> Dictionary:
	return lineup[mini(stage, lineup.size() - 1)]


## Multiplier / bonus from the current opponent's modifiers ("speed", "serve", "skill").
func modifier_value(key: String) -> float:
	var v := 0.0 if key == "skill" else 1.0
	for id in current_lineup()["mods"]:
		var m: Dictionary = MODIFIERS[id]
		if m.has(key):
			v = v + float(m[key]) if key == "skill" else v * float(m[key])
	if key == "skill":
		var gear: Dictionary = current_lineup().get("gear", {})
		for slot in gear:
			if not gear[slot].is_empty():
				v += SKILL_PER_RARITY * int(gear[slot]["rarity"])
	return v


## The trophy: put on (what was worn goes into the bag) or into the bag.
func take_loot(put_on: bool) -> void:
	if not pending_loot.is_empty():
		if put_on:
			_wear(pending_loot)
		else:
			add_to_bag(pending_loot)
	pending_loot = {}


## Puts an item on; what was in that slot goes into the bag.
func _wear(item: Dictionary) -> void:
	var slot := String(item.get("slot", "racket"))
	var old: Dictionary = equip.get(slot, {})
	equip[slot] = item
	if not old.is_empty():
		add_to_bag(old)


## Into the bag; a full bag sells its cheapest item (maybe this one) for run gold.
func add_to_bag(item: Dictionary) -> void:
	if item.is_empty():
		return
	bag.append(item)
	if bag.size() > BAG_SIZE:
		var worst := 0
		for k in bag.size():
			if Gear.price(bag[k]) < Gear.price(bag[worst]):
				worst = k
		var p := Gear.price(bag[worst])
		bag.remove_at(worst)
		gold += p
		auto_sold += p


func equip_from_bag(i: int) -> void:
	if i < 0 or i >= bag.size():
		return
	var item: Dictionary = bag[i]
	bag.remove_at(i)
	_wear(item)


func sell_from_bag(i: int) -> int:
	if i < 0 or i >= bag.size():
		return 0
	var p := Gear.price(bag[i])
	bag.remove_at(i)
	gold += p
	return p


## What a beaten opponent's gear drops: each item on its own (DROP_CHANCE + bonus).
static func drops(gear: Dictionary, r: RandomNumberGenerator, bonus: float) -> Array:
	var out: Array = []
	for slot in Gear.SLOTS:
		var it: Dictionary = gear.get(slot, {})
		if it.is_empty():
			continue
		if r.randf() < DROP_CHANCE[clampi(int(it["rarity"]), 0, 4)] + bonus:
			out.append(it)
	return out


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
	var golden: bool = i < lineup.size() and lineup[i].get("golden", false)
	var base := roundi(GOLD_PER_WIN[i] * float(format_info()["reward"])) * (Golden.GOLD_X if golden else 1)
	# v0.2 B hook: the club's stands pay a little more for a won match (ClubBuilds, off online).
	return roundi(float(base) * (1.0 + ClubBuilds.gold_win_bonus()))


## Records a finished match and moves the run on.
func record_match(won: bool, score_text: String, r: RandomNumberGenerator) -> void:
	results.append({"stage": stage, "won": won, "score": score_text})
	missed_loot = ""
	new_items = []
	auto_sold = 0
	if won:
		_take_drops(r)
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
		var it: Dictionary = card["item"]
		if equip.get(String(it.get("slot", "racket")), {}).is_empty():
			_wear(it)
		else:
			add_to_bag(it)
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


## The beaten opponent's drops: the best epic+ goes to the trophy game, the rest into the bag.
func _take_drops(r: RandomNumberGenerator) -> void:
	var dropped := drops(current_lineup().get("gear", {}), r, drop_bonus)
	var best := -1
	for k in dropped.size():
		if int(dropped[k]["rarity"]) >= Gear.EPIC and (best < 0 or int(dropped[k]["rarity"]) > int(dropped[best]["rarity"])):
			best = k
	if best >= 0:
		pending_loot = dropped[best]
		dropped.remove_at(best)
	for it in dropped:
		new_items.append(it)
		add_to_bag(it)


## The gear card of the reward offer: usually common, sometimes rare, any slot.
func _item_card(r: RandomNumberGenerator) -> Dictionary:
	var item := Gear.roll(Gear.RARE if r.randf() < 0.3 else Gear.COMMON, r, Gear.SLOTS[r.randi_range(0, Gear.SLOTS.size() - 1)])
	return {"kind": "item", "item": item, "title": item["name"], "desc": Gear.describe(item)}


func give_up() -> void:
	state = State.OVER


## How far the run got, for the summary screen.
func finish_text() -> String:
	if champion:
		return "Чемпион! %s" % tier_name()
	return "Вылет: %s" % round_name()
