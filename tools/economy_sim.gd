extends SceneTree
## The gold curve over many runs (v0.2 A-5, spec 9.3 and 13): a beginner turning into a
## regular, on the REAL logic (Tournament, Locker, Shop, ClubBuilds, Locations), with the
## chance to win a match taken from the bot's measured table (tools/bot_model.gd) and
## the gear / island edges measured by tools/power_bot.sh.
##   godot --headless --path . -s tools/economy_sim.gd [-- --trials=60 --runs=30 --max-runs=500 --min-per-match=4.5 ...]
## Prints: a per-run table (averages), "when what is bought", the income curve by hours
## (so the club's total price can be set for 60-80 hours), and the whole club's time.
##
## The player: spends on the cheapest next club level (shop and locker first), puts SINK of
## his income into the shop (an epic or better for a free slot), keeps the best item in the
## locker, goes to the island that pays most among those he can win on, plays the format
## "Сет до 6". Time: MIN_PER_MATCH a match played (a real set on a phone, with the menus
## between) + MIN_PER_RUN for the summary, shop and club.

const Model := preload("res://tools/bot_model.gd")

## Win-chance edge (bot_model log-odds units, 0.1 = ten points against an even opponent) of
## one worn item by rarity - calibrated on tools/power_bot.sh (3 epics = +2 points of
## the points won at level 12, 3 legendaries +3.6; x5 from points to a match, /4 to the edge).
var gear_edge := [0.005, 0.015, 0.035, 0.06, 0.09]
## The island's edge: opponents are stronger by Locations.TIERS (power) - measured with
## tools/power_bot.sh --loc: points won at level 12 against the quarter-final opponent.
var island_edge := [0.0, -0.31, -0.35, -0.60]

var trials := 40
var runs_print := 30
var max_runs := 600
var min_per_match := 4.5
var min_per_run := 1.5
var quests_done := 1.0            # quests finished a run (of 3), a beginner ~1
var sink := 0.2                   # the share of a run's income spent in the shop
var hardness := 0.0               # the edge shift for harder opponents (stream D): -0.1 = ten points tougher
var table_total := 0              # --total=N: also report the time to earn N gold
var rng := RandomNumberGenerator.new()
var done_at := {}                 # trial -> the run the last club level was bought in


func _initialize() -> void:
	SaveData.enabled = false
	for a in OS.get_cmdline_user_args():
		var k := a.get_slice("=", 0)
		var v := a.get_slice("=", 1)
		match k:
			"--trials": trials = int(v)
			"--runs": runs_print = int(v)
			"--max-runs": max_runs = int(v)
			"--min-per-match": min_per_match = float(v)
			"--min-per-run": min_per_run = float(v)
			"--quests": quests_done = float(v)
			"--sink": sink = float(v)
			"--hardness": hardness = float(v)
			"--total": table_total = int(v)
			"--island-edge": island_edge = (v.split(",") as Array).map(func(s): return float(s))
	_run()
	quit()


func _reset() -> void:
	SaveData.gold = 0
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.titles_by_loc = {}
	SaveData.locker = {}
	SaveData.club = {}


## What one run gives and how it ended.
class RunLog:
	var matches := 0
	var wins := 0
	var income := 0.0
	var quests := 0.0
	var island := "park"
	var xp := 0.0
	var title := false
	var bank := 0
	var bought: Array[String] = []
	var minutes := 0.0


func _gear_edge(t: Tournament) -> float:
	var e := 0.0
	for slot in Gear.SLOTS:
		var it: Dictionary = t.equip.get(slot, {})
		if not it.is_empty():
			e += float(gear_edge[int(it["rarity"])]) * (1.0 + Items.LEVEL_POWER * (Items.level(it) - 1))
	return e


func _win_chance(xp: float, stage: int, t: Tournament) -> float:
	return Model.win_chance(xp, stage, _gear_edge(t) + float(island_edge[Locations.tier(t.location)]) + hardness)


## One run on the island; returns the log. Gold goes through the real Tournament.
func _play_run(xp: float, island: String) -> RunLog:
	var log := RunLog.new()
	log.island = island
	var t := Tournament.new(1, rng.randi() | 1)
	t.location = island
	Locker.board(t)
	while Locker.items().size() > 0 and t.can_take_locker():
		t.take_from_locker(0)
	var guard := 0
	while t.state != Tournament.State.OVER and guard < 30:
		guard += 1
		var won := rng.randf() < _win_chance(xp, t.stage, t)
		xp += Model.XP_PER_MATCH
		log.matches += 1
		t.earn("style", roundi(Model.STYLE_GOLD * rng.randf_range(0.5, 1.5)))
		t.record_match(won, "", rng)
		if not t.pending_loot.is_empty():
			var loot: Dictionary = t.pending_loot
			var worn: Dictionary = t.equip.get(String(loot["slot"]), {})
			t.take_loot(worn.is_empty() or int(loot["rarity"]) > int(worn["rarity"]))
		if won:
			log.wins += 1
		match t.state:
			Tournament.State.REWARD:
				t.take_reward(_pick_reward(t))
			Tournament.State.LOST:
				t.use_wildcard()
	# the end of the run: sell the extras, bank, keep one item
	t.sell_extra()
	log.title = t.champion
	log.xp = xp
	SaveData.gold += t.gold
	SaveData.played += 1
	log.income = t.gold
	if t.champion:
		SaveData.titles += 1
		SaveData.note_title(island)
	# the quests (the coach's board): a few done a run, paid at the coach's
	var q := quests_done * 35.0 * Locations.prize_mult(island) * (0.7 + 0.6 * float(log.wins) / 4.0)
	SaveData.gold += roundi(q)
	log.income += q
	log.quests = q
	# one item into the locker: the best that is allowed
	var cands := Locker.candidates(t)
	var best := -1
	for i in cands.size():
		var it: Dictionary = cands[i]["item"]
		if Locker.check(it, Locker.exit_round(t)) != "" and not Locker.check(it, Locker.exit_round(t)).begins_with("шкафчик полон"):
			continue
		if best < 0 or _item_value(it) > _item_value(cands[best]["item"]):
			best = i
	if best >= 0:
		var it2: Dictionary = cands[best]["item"]
		var why := Locker.save_from(t, best)
		if why.begins_with("шкафчик полон"):  # replace the worst kept one if the new one is better
			var worst := 0
			for k in Locker.items().size():
				if _item_value(Locker.items()[k]) < _item_value(Locker.items()[worst]):
					worst = k
			if _item_value(it2) > _item_value(Locker.items()[worst]):
				Locker.save_from(t, best, worst)
	log.minutes = log.matches * min_per_match + min_per_run
	return log


func _item_value(it: Dictionary) -> float:
	return float(it["rarity"]) * 10.0 + Items.level(it)


func _pick_reward(t: Tournament) -> int:
	for i in t.offer.size():
		var c: Dictionary = t.offer[i]
		if c["kind"] == "item":
			var worn: Dictionary = t.equip.get(String(c["item"]["slot"]), {})
			if worn.is_empty() or int(c["item"]["rarity"]) > int(worn["rarity"]):
				return i
	for i in t.offer.size():
		if t.offer[i]["kind"] == "wildcard":
			return i
	return 0


## The island that pays most among the open ones (the expected gold of a run there).
func _choose_island(xp: float) -> String:
	var best := "park"
	var best_gold := -1.0
	for id in Locations.ORDER:
		if not Locations.unlocked(id):
			continue
		var tier := Locations.tier(id)
		var g := 0.0
		var alive := 1.0
		var m := 1.0 + Model.STYLE_GOLD / 10.0
		for stage in 5:
			var p := Model.win_chance(xp + stage * 70.0, stage, float(island_edge[tier]) + hardness + _typical_gear_edge())
			g += alive * (Tournament.PRIZE_ON_LOSS[stage] * (1.0 - p) + float(Tournament.GOLD_PER_WIN[stage]) * p) * Locations.prize_mult(id)
			alive *= p
		g += alive * Tournament.CHAMPION_BONUS * Locations.prize_mult(id)
		if g > best_gold:
			best_gold = g
			best = id
	return best


func _typical_gear_edge() -> float:
	var e := 0.0
	for it in Locker.items():
		e += float(gear_edge[int(it["rarity"])]) * (1.0 + Items.LEVEL_POWER * (Items.level(it) - 1))
	return e


## The shop: put `budget` into an epic or better that beats what the locker holds.
func _shop(budget: int, log: RunLog) -> void:
	if not ClubBuilds.is_open("shop") or budget < 40:
		return
	var stock := Shop.stock()
	var best := -1
	for i in stock.size():
		var it: Dictionary = stock[i]
		if it.is_empty() or int(it["rarity"]) < Gear.EPIC or Items.price(it) > budget or Items.price(it) > SaveData.gold:
			continue
		if best < 0 or _item_value(it) > _item_value(stock[best]):
			best = i
	if best >= 0 and Shop.buy(best) == "":
		log.bought.append("item:%s" % Gear.RARITIES[int(stock[best]["rarity"])]["id"])


## Builds: first the shop and the locker (the player saves for them), then the cheapest
## next level of anything open. Names go to the log.
func _build(log: RunLog) -> void:
	var again := true
	while again:
		again = false
		var target := ""
		if ClubBuilds.level("shop") == 0 and ClubBuilds.is_open("shop"):
			target = "shop"
		elif ClubBuilds.level("locker") == 0 and ClubBuilds.is_open("locker"):
			target = "locker"
		var cands: Array = []
		for id in ClubBuilds.ORDER:
			if ClubBuilds.is_open(id) and not ClubBuilds.next(id).is_empty():
				cands.append(id)
		cands.sort_custom(func(x, y): return ClubBuilds.next_price(x) < ClubBuilds.next_price(y))
		if target != "" and ClubBuilds.can_afford(target):
			cands = [target]
		for id in cands:
			if not ClubBuilds.can_afford(id):
				continue
			# saving for the target: anything else must leave enough for it
			if target != "" and id != target and SaveData.gold - ClubBuilds.next_price(id) < ClubBuilds.next_price(target):
				continue
			var lv := ClubBuilds.level(id) + 1
			if ClubBuilds.buy(id):
				log.bought.append("%s%d" % [id, lv])
				again = true
				break


func _club_done() -> bool:
	for id in ClubBuilds.ORDER:
		if ClubBuilds.level(id) < ClubBuilds.max_level(id):
			return false
	return true


func _run() -> void:
	rng.seed = 20261008
	var all_logs: Array = []      # per trial: [RunLog...]
	var club_total := 0
	done_at = {}
	for id in ClubBuilds.ORDER:
		for lv in ClubBuilds.TABLE[id]["levels"]:
			club_total += int(lv["price"])
	for tr in trials:
		_reset()
		var xp := 0.0
		var logs: Array = []
		var hours := 0.0
		for run in max_runs:
			var island := _choose_island(xp)
			var lg := _play_run(xp, island)
			xp = lg.xp
			lg.bank = SaveData.gold
			_shop(roundi(float(lg.income) * sink * 2.0), lg)
			_build(lg)
			lg.bank = SaveData.gold
			if _club_done() and not done_at.has(tr):
				done_at[tr] = run + 1
			logs.append(lg)
		all_logs.append(logs)

	_print_runs(all_logs)
	_print_milestones(all_logs)
	_print_income(all_logs, club_total)


func _avg(logs_by_trial: Array, run: int, f: Callable) -> float:
	var s := 0.0
	var n := 0
	for logs in logs_by_trial:
		if run < logs.size():
			s += float(f.call(logs[run]))
			n += 1
	return s / maxf(n, 1)


func _print_runs(all_logs: Array) -> void:
	print("\nCURVE (average of %d trials; a match %.1f min, a run +%.1f min; quests %.1f; item share %d%%; hardness %+.2f)" % [trials, min_per_match, min_per_run, quests_done, roundi(sink * 100.0), hardness])
	print("run  level(xp)  matches  wins  island(share)         income  of which quests   bank after builds   hours")
	var hours := 0.0
	for run in runs_print:
		var xp := _avg(all_logs, run, func(l): return l.xp)
		var m := _avg(all_logs, run, func(l): return l.matches)
		var w := _avg(all_logs, run, func(l): return l.wins)
		var inc := _avg(all_logs, run, func(l): return l.income)
		var q := _avg(all_logs, run, func(l): return l.quests)
		var bank := _avg(all_logs, run, func(l): return l.bank)
		hours += _avg(all_logs, run, func(l): return l.minutes) / 60.0
		var shares := {}
		for logs in all_logs:
			if run < logs.size():
				shares[logs[run].island] = int(shares.get(logs[run].island, 0)) + 1
		var isl := ""
		for id in Locations.ORDER:
			if shares.has(id):
				isl += "%s %d%%  " % [Locations.find(id)["name"].left(4), roundi(100.0 * shares[id] / trials)]
		print("%3d  %5.0f      %4.1f     %3.1f   %-22s %6.0f  %6.0f           %7.0f             %5.1f" % [run + 1, xp, m, w, isl, inc, q, bank, hours])


## The run and hour at which things are first bought / reached (median of the trials).
func _print_milestones(all_logs: Array) -> void:
	print("\nWHEN WHAT IS BOUGHT (median run / hours; played, not queued)")
	var names: Array = []
	for id in ClubBuilds.ORDER:
		for lv in range(1, ClubBuilds.max_level(id) + 1):
			names.append("%s%d" % [id, lv])
	names += ["item:epic", "item:legendary"]
	var rows: Array = []
	for nm in names:
		var runs: Array = []
		var hrs: Array = []
		for logs in all_logs:
			var h := 0.0
			for i in logs.size():
				h += logs[i].minutes / 60.0
				if (logs[i].bought as Array).has(nm):
					runs.append(i + 1)
					hrs.append(h)
					break
		if runs.size() * 2 >= all_logs.size():
			runs.sort()
			hrs.sort()
			var label: String = nm
			if ClubBuilds.TABLE.has(nm.rstrip("0123456789")) and nm.length() > 1:
				var id: String = nm.rstrip("0123456789")
				var lv := int(nm.substr(id.length()))
				label = "%s %d  «%s» %d" % [ClubBuilds.TABLE[id]["name"], lv, ClubBuilds.TABLE[id]["levels"][lv - 1]["title"], ClubBuilds.TABLE[id]["levels"][lv - 1]["price"]]
			rows.append([runs[runs.size() / 2], hrs[hrs.size() / 2], label])
	rows.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	for r in rows:
		print("  run %3d  %5.1f h   %s" % [r[0], r[1], r[2]])
	# titles and islands
	for loc in ["park", "clay", "grass"]:
		var runs: Array = []
		for logs in all_logs:
			for i in logs.size():
				if logs[i].title and logs[i].island == loc:
					runs.append(i + 1)
					break
		if runs.size() > 0:
			runs.sort()
			print("  first title on %s: run %d (median of %d/%d trials)" % [Locations.find(loc)["name"], runs[runs.size() / 2], runs.size(), all_logs.size()])
	var done: Array = []
	var done_h: Array = []
	for tr in all_logs.size():
		if done_at.has(tr):
			var h := 0.0
			for i in int(done_at[tr]):
				h += all_logs[tr][i].minutes / 60.0
			done.append(int(done_at[tr]))
			done_h.append(h)
	if done.size() > 0:
		done.sort()
		done_h.sort()
		print("  THE WHOLE CLUB (the table in the game now, %d gold): run %d, %.1f h (median of %d/%d trials)" % [_total_now(), done[done.size() / 2], done_h[done_h.size() / 2], done.size(), all_logs.size()])
	else:
		print("  the whole club is not finished in %d runs" % max_runs)


func _total_now() -> int:
	var s := 0
	for id in ClubBuilds.ORDER:
		for lv in ClubBuilds.TABLE[id]["levels"]:
			s += int(lv["price"])
	return s


## How much gold has been earned by hour h: what the club's total price must be to take
## 60 / 70 / 80 hours (the average over the trials of the cumulative income + the sinks).
func _print_income(all_logs: Array, club_total: int) -> void:
	print("\nINCOME BY HOURS (cumulative gold earned, average; the club's total price for X hours = this)")
	var marks := [0.5, 1, 2, 5, 10, 20, 30, 40, 60, 70, 80]
	var line_h := ""
	for mk in marks:
		var s := 0.0
		var n := 0
		for logs in all_logs:
			var h := 0.0
			var g := 0.0
			var reached := false
			for lg in logs:
				h += lg.minutes / 60.0
				g += lg.income
				if h >= mk:
					reached = true
					break
			if reached:
				s += g
				n += 1
		if n > 0:
			line_h += "  %sh: %d" % [str(mk), roundi(s / n)]
	print(line_h)
	print("(the club in the game now costs %d; one gold a minute of play ~ see the per-run table)" % club_total)
