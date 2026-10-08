class_name Tournament
extends RefCounted
## One run = one knockout tournament: four opponents, then the boss in the final.
## Win -> pick a reward -> next stage. Lose -> a wildcard replays the match,
## without one the run is over. Pure state, no nodes: the UI and Main drive it.

enum State { BRACKET, REWARD, LOST, OVER }

const TIER_NAME := "Клубный турнир"
const GOLD_PER_WIN := [10, 15, 20, 30, 50]
## One knob for every prize and style gold of a run (v0.2 A-5, tools/economy_sim.gd): the
## whole club (B's table, ~16 900 gold) must take 60-80 hours (hub spec 13), so what a run pays
## is about a fifth of the first design in the long run. A newcomer is paid fully at first
## and the scale falls to INCOME_SCALE over BEGINNER_RUNS runs, so the first build comes in
## run 1-2. Item prices, the shop and the club's table are not touched by it.
static var INCOME_SCALE := 0.5
const BEGINNER_RUNS := 8
static var BEGINNER_START := 2.0      # a newcomer's first run pays x2 and it falls to INCOME_SCALE by run 8


static func income_scale() -> float:
	var k := clampf(1.0 - float(SaveData.played) / BEGINNER_RUNS, 0.0, 1.0)
	return INCOME_SCALE + (BEGINNER_START - INCOME_SCALE) * k
const CHAMPION_BONUS := 100
## Prize money of the round you went out in (v0.2 A economy): like real tennis, a lost run
## still pays, so even a beginner who loses the first round earns toward the club. Paid for
## a match played and lost (no wildcard left, or giving up after the loss), never for
## giving up before playing.
const PRIZE_ON_LOSS := [20, 25, 35, 50, 75]
## The run's gold by where it came from (the summary shows them line by line).
const INCOME_KINDS := ["prize", "chest", "style", "sell", "quests", "bonus"]

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
const GEAR_CHANCE := [0.60, 0.27, 0.08, 0.025, 0.018]
const SHIFT_SPLIT := [0.5, 0.3, 0.15, 0.05]   # where the shifted share goes: rare .. mythic
const ROUND_SHIFT := 0.04
## Beaten, each of his items drops on its own with this chance by its rarity. v0.2 A
## economy (spec 3, tools/drop_sim.gd): what he carries (GEAR_CHANCE) times this gives
## about 35 / 18 / 7 / 2 / 0.4% per slot in the second round, so a beginner over 10 runs
## sees ~5 epics, ~1.2 legendaries and ~0.3 mythics drop (1 in 2, 1 in 8, 1 in 30 runs).
## (Before: 30/20/12/6/3% of what he carried — an epic once in 14 runs, a mythic in 670.)
const DROP_CHANCE := [0.55, 0.65, 0.85, 0.48, 0.6]
## How much of the island's strength multiplier the opponent gets (see modifier_value).
const ISLAND_POWER_SHARE := 0.5
## v0.2 A-7 (owner: «призы не после каждого противника»): no «1 из 3» after a win. Instead a
## win may leave a chest by the net: the chance by the round just won (1-2: 35%, QF/SF: 55%,
## the final: always), and never more than CHEST_PITY won matches in a row with no prize
## (a chest or a trophy). Inside: gold and / or an item, sometimes a wildcard.
const CHEST_CHANCE := [0.35, 0.35, 0.55, 0.55, 1.0]
const CHEST_PITY := 2
const CHEST_GOLD := [15, 22, 32, 48, 80]                # x the prize multiplier, 0.7..1.3
## Item rarity by the round: common, rare, epic, legendary (no mythics from a chest).
const CHEST_RARITY := [[20.0, 36.0, 32.0, 12.0], [16.0, 34.0, 36.0, 14.0], [12.0, 32.0, 40.0, 16.0], [7.0, 28.0, 45.0, 20.0], [3.0, 20.0, 48.0, 29.0]]
const BAG_SIZE := 6
const SKILL_PER_RARITY := 0.01    # his gear makes him a little stronger

var format := 0                   # index into FORMATS
## Locations id: scenery, surface and ball physics. v0.2 A-4: also the island's tier, so
## choosing it re-rolls the opponents' gear (their level and odds depend on the tier).
var location := "park":
	set(v):
		if v == location:
			return
		location = v
		mythic_rolled = false
		roll_field()  # D-8: every island has its own tiers of opponents
		roll_lineup()
var field: Array = []:            # the draw: a spec per round (Opponents.draw), saved with the run
	set(v):
		field = v
		_opps = []
var _opps: Array = []             # the specs resolved to profiles
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
var run_modifiers: Array = []     # v0.2 G: the run's conditions picked before it (Modifiers ids)
var hardcore := false             # v0.2 G-6: the hardcore run ("hardcore" is also first in run_modifiers)
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
var income := {}                  # gold by kind (INCOME_KINDS): adds up to `gold`
var last_prize := 0               # prize money the last record_match / give_up paid (the result shows it)
var locker_done := false          # the summary's one item went into the locker (Locker)
var champion := false
var chest := {}                   # the chest by the net after the last win ({} = none), see make_chest
var dry := 0                      # won matches in a row without a prize (the pity counter)
var offer: Array = []             # reward cards on the REWARD screen


func opponent() -> Dictionary:
	return opp(mini(stage, rounds() - 1))


## The opponent of round i (a profile as in Opponents.ROSTER: the fixed ones, the top-100, random).
func opp(i: int) -> Dictionary:
	if _opps.size() != field.size():
		_opps = []
		for sp in field:
			_opps.append(Opponents.resolve(sp))
	return _opps[clampi(i, 0, _opps.size() - 1)]


## D-8: the draw of this island, by the run's seed (the same run, the same field).
func roll_field() -> void:
	field = Opponents.draw(location, ("%d:%s" % [rng.seed, location]).hash(), SaveData.played == 0)


func round_name(i := -1) -> String:
	return Opponents.ROUND_NAMES[stage if i < 0 else i]


func rounds() -> int:
	return Opponents.ROUND_NAMES.size()


func _init(format_index := 0, seed_value := 0, hardcore_run := false) -> void:
	hardcore = hardcore_run
	format = clampi(format_index, 0, FORMATS.size() - 1)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	roll_field()
	roll_lineup()


const SAVED := ["format", "location", "field", "lineup", "racket", "pending_loot", "missed_loot", "banked",
	"state", "stage", "wildcards", "perks", "results", "gold", "champion", "offer",
	"equip", "bag", "new_items", "auto_sold", "run_mods", "mythic_rolled", "drop_bonus", "bet",
	"income", "locker_done", "run_modifiers", "chest", "dry", "hardcore"]


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
	if not d.has("field"):  # a run saved before D-8: the old five
		var legacy: Array = []
		for o in Opponents.ROSTER:
			legacy.append({"id": o["id"]})
		t.field = legacy
	t.rng.seed = int(d.get("rng_seed", 1))
	t.rng.state = int(d.get("rng_state", 0))
	return t


## Rolls every opponent's modifiers and the loot they carry, so it can be shown in the
## bracket before the match. The first opponent is the tutorial: no modifiers.
func roll_lineup() -> void:
	lineup = []
	var lvl := item_level()
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
		# v0.2 G: rare auras (scripts/mods), "???" ones named on the first point.
		mods += Traits.roll(rng.seed, i, opp(i))  # v0.2 G-7: his traits (at least one)
		var aur := Modifiers.roll_auras(rng.seed, i, opp(i).get("boss", false), 1.0, SaveData.played == 0)
		mods += aur["mods"]
		var bonus := 0.0
		for id in mods:
			bonus += Modifiers.loot_bonus(id)
		if opp(i).get("boss", false):
			bonus += BOSS_LOOT_BONUS
		var gear := {}
		for slot in Gear.SLOTS:
			var rar := Gear.COMMON if i == 0 else _roll_rarity(ROUND_SHIFT * i + bonus)
			if rar == Gear.MYTHIC:
				if mythic_rolled:
					rar = Gear.LEGENDARY
				mythic_rolled = true
			gear[slot] = Gear.roll(rar, rng, slot, lvl)
		# A golden one (1 in 50, never the first): a legendary or better in his hand, a level up.
		var golden := i > 0 and rng.randf() < Golden.CHANCE
		if golden and int(gear["racket"]["rarity"]) < Gear.LEGENDARY:
			gear["racket"] = Gear.roll(Gear.LEGENDARY, rng, "racket", lvl + 1)
		elif golden:
			gear["racket"] = Items.set_level(gear["racket"], lvl + 1)
		lineup.append({"mods": mods, "hidden": aur["hidden"], "gear": gear, "racket": gear["racket"], "golden": golden})


## The level of the gear opponents wear here: 1 + the island's tier (v0.2 A-4).
func item_level() -> int:
	return 1 + Locations.tier(location)


## A rarity for an opponent's item: GEAR_CHANCE with `shift` moved from common upward;
## the island's tier adds its own epic / legendary points (Locations.TIERS).
func _roll_rarity(shift: float) -> int:
	var c: Array = GEAR_CHANCE.duplicate()
	var ti := Locations.tier_info(location)
	c[Gear.EPIC] += float(ti["epic"])
	c[Gear.LEGENDARY] += float(ti["legendary"])
	c[0] -= float(ti["epic"]) + float(ti["legendary"])
	if hardcore:  # G-6: a little more above epic
		c[Gear.LEGENDARY] += Modifiers.HARD_RARITY
		c[0] -= Modifiers.HARD_RARITY
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
	# v0.2 A-4: the island's strength (Locations.TIERS power: 1 / 1.12 / 1.25 / 1.4) -
	# half of it into running and serving, half of it into the AI's mastery.
	var extra := (Locations.power(location) - 1.0) * ISLAND_POWER_SHARE
	if key == "skill":
		v += extra
	else:
		v *= 1.0 + extra
	for id in current_lineup()["mods"]:
		var m: Dictionary = MODIFIERS.get(id, {})  # auras (v0.2 G) are not in here
		if m.has(key):
			v = v + float(m[key]) if key == "skill" else v * float(m[key])
	if key == "skill":
		var gear: Dictionary = current_lineup().get("gear", {})
		for slot in gear:
			if not gear[slot].is_empty():
				v += SKILL_PER_RARITY * int(gear[slot]["rarity"])
	return Modifiers.opp_value(self, key, v)  # v0.2 G: auras and the run's conditions


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


## Run gold with where it came from (INCOME_KINDS): every gain of the run goes through here.
func earn(kind: String, n: int) -> void:
	if n == 0:
		return
	if kind == "prize":
		last_prize += n
	gold += n
	income[kind] = int(income.get(kind, 0)) + n


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
		earn("sell", p)
		auto_sold += p


## An item joining the run from outside (the locker, the shop): on if its slot is empty,
## else into the bag.
func join(item: Dictionary) -> void:
	if item.is_empty():
		return
	if equip.get(String(item.get("slot", "racket")), {}).is_empty():
		_wear(item)
	else:
		add_to_bag(item)


## The locker is open until the first match is played.
func can_take_locker() -> bool:
	return results.is_empty() and stage == 0 and state == State.BRACKET


func take_from_locker(i: int) -> void:
	if can_take_locker():
		join(Locker.take(i))


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
	earn("sell", p)
	return p


## What «Продать всё лишнее» sells: the commons, and anything below what is worn in its
## slot. Never an epic or better.
func extra_items() -> Array:
	return bag.filter(func(it): return _is_extra(it))


func _is_extra(it: Dictionary) -> bool:
	var r := int(it.get("rarity", 0))
	if r >= Gear.EPIC:
		return false
	if r == Gear.COMMON:
		return true
	var worn: Dictionary = equip.get(String(it.get("slot", "racket")), {})
	return not worn.is_empty() and int(worn["rarity"]) > r


## Sells every extra item for run gold; returns the gold.
func sell_extra() -> int:
	var total := 0
	for i in range(bag.size() - 1, -1, -1):
		if _is_extra(bag[i]):
			total += sell_from_bag(i)
	return total


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


## The island's prize multiplier (Locations.TIERS) times the format's reward.
func prize_mult() -> float:
	return float(format_info()["reward"]) * Locations.prize_mult(location) * income_scale()


func champion_bonus() -> int:
	return roundi(CHAMPION_BONUS * prize_mult())


## Prize money for going out in round i (a played and lost match).
func prize_on_loss(i: int) -> int:
	return roundi(PRIZE_ON_LOSS[clampi(i, 0, PRIZE_ON_LOSS.size() - 1)] * prize_mult())


func gold_for_win(i: int) -> int:
	var golden: bool = i < lineup.size() and lineup[i].get("golden", false)
	var base := roundi(GOLD_PER_WIN[i] * prize_mult()) * (Golden.GOLD_X if golden else 1)
	# v0.2 B hook: the club's stands pay a little more for a won match (ClubBuilds, off online).
	# v0.2 G: his auras and the run's conditions pay more (Modifiers.gold_mult, x3 at most).
	return roundi(float(base) * (1.0 + ClubBuilds.gold_win_bonus()) * Modifiers.gold_mult(self, i))


## Records a finished match and moves the run on.
func record_match(won: bool, score_text: String, r: RandomNumberGenerator) -> void:
	results.append({"stage": stage, "won": won, "score": score_text})
	last_prize = 0
	missed_loot = ""
	new_items = []
	auto_sold = 0
	if won:
		var round_i := stage
		_take_drops(r)
		earn("prize", gold_for_win(stage))
		stage += 1
		chest = _roll_chest(round_i)
		offer = []
		if stage >= rounds():
			champion = true
			earn("prize", champion_bonus())
			SaveData.note_title(location)  # v0.2 A-4: the islands open title by title
			state = State.OVER
		else:
			state = State.REWARD if not chest.is_empty() else State.BRACKET
	else:
		state = State.LOST if wildcards > 0 else State.OVER
		if state == State.OVER:
			earn("prize", prize_on_loss(stage))


## The chest a win leaves, or {}: the chance by round, the pity, the contents from a seed of
## the run (the same run and match give the same chest). Counts the trophy as a prize.
func _roll_chest(round_i: int) -> Dictionary:
	var cr := RandomNumberGenerator.new()
	cr.seed = rng.seed * 7919 + results.size() * 104729 + round_i * 31 + 7
	var prize := not pending_loot.is_empty()
	var c := {}
	if dry >= CHEST_PITY or cr.randf() < CHEST_CHANCE[clampi(round_i, 0, CHEST_CHANCE.size() - 1)]:
		c = make_chest(round_i, cr)
	dry = 0 if (prize or not c.is_empty()) else dry + 1
	return c


## {"round", "gold", "item", "perk", "wildcard", "opened"}: gold only 15%, an item 40%, both
## 35%, and 10% a wildcard with a little gold. No run perks (temporary +X%): the owner wants
## strength to grow only with the skills' levels; the `perk` field stays for old saves.
func make_chest(round_i: int, cr: RandomNumberGenerator) -> Dictionary:
	var ri := clampi(round_i, 0, CHEST_GOLD.size() - 1)
	var c := {"round": round_i, "gold": 0, "item": {}, "perk": "", "wildcard": false, "opened": false}
	var gold := maxi(1, roundi(CHEST_GOLD[ri] * prize_mult() * cr.randf_range(0.7, 1.3)))
	var x := cr.randf()
	if x < 0.15:
		c["gold"] = gold
	elif x < 0.55:
		c["item"] = _chest_item(ri, cr)
	elif x < 0.90:
		c["gold"] = gold
		c["item"] = _chest_item(ri, cr)
	else:
		c["gold"] = maxi(1, gold / 3)
		c["wildcard"] = true  # (no temporary perks any more: owner 08.10, strength only grows with levels)
	return c


func _chest_item(ri: int, cr: RandomNumberGenerator) -> Dictionary:
	var w: Array = CHEST_RARITY[ri]
	var total := 0.0
	for v in w:
		total += v
	var y := cr.randf() * total
	var rar := Gear.LEGENDARY
	for k in w.size():
		if y < w[k]:
			rar = k
			break
		y -= w[k]
	return Gear.roll(rar, cr, Gear.SLOTS[cr.randi_range(0, Gear.SLOTS.size() - 1)], item_level())


## Opens the chest: gold, perk and wildcard come at once (the item waits for take_chest).
func open_chest() -> Dictionary:
	if chest.is_empty() or chest.get("opened", false):
		return chest
	chest["opened"] = true
	var g := int(chest["gold"])
	if g > 0:
		earn("chest", g)
		if banked:
			SaveData.gold += g  # the run was banked already (the final's chest): straight into the bank
	if String(chest["perk"]) != "":
		perks.append(chest["perk"])
	if chest["wildcard"]:
		wildcards += 1
	return chest


## Takes it all and goes on: the item is worn (empty slot) or goes into the bag.
func take_chest() -> void:
	if chest.is_empty():
		return
	open_chest()
	var it: Dictionary = chest["item"]
	if not it.is_empty():
		join(it)
	chest = {}
	if state == State.REWARD:
		state = State.BRACKET


func take_reward(i: int) -> void:
	if offer.is_empty() and not chest.is_empty():
		take_chest()  # (the autoplay bot and old callers)
		return
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
	var item := Gear.roll(Gear.RARE if r.randf() < 0.3 else Gear.COMMON, r, Gear.SLOTS[r.randi_range(0, Gear.SLOTS.size() - 1)], item_level())
	return {"kind": "item", "item": item, "title": item["name"], "desc": Gear.describe(item)}


func give_up() -> void:
	last_prize = 0
	if state == State.LOST:
		earn("prize", prize_on_loss(stage))  # the match was played and lost: its round pays
	state = State.OVER


## How far the run got, for the summary screen.
func finish_text() -> String:
	if champion:
		return "Чемпион! %s" % tier_name()
	return "Вылет: %s" % round_name()
