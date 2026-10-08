class_name ClubQuests
## The coach's quests (docs/superpowers/specs/2026-10-08-v02-hub-economy.md 5): three a run
## from a pool of templates, harder on the farther islands, counted from the match's
## events (ClubQuests.Watch listens to GameEvents - nothing inside Main), collected at the
## coach's for gold and, every third quest, an item. Unfinished quests burn with the run.
##
## Saved in SaveData.club["quests"]:
##   {run: the run's seed, list: [quest], issued: all ever dealt, claimed: all collected}
##   quest: {tpl, text, event, kind ("count" | "max"), scope ("match" | "run"), need,
##           have, done, claimed, gold, item, tier}

const PER_RUN := 3
const GOLD_MULT := [1.0, 1.3, 1.6, 2.0]       # by island (Locations tier)
const ITEM_EVERY := 3                          # every third quest dealt also gives an item
const ITEM_EPIC_CHANCE := 0.2                  # the rest are rare
## Islands until stream A's Locations.tier() exists (hub spec 4).
const TIER_FALLBACK := {"park": 0, "clay": 1, "grass": 2, "paris": 3}

## The pool. n: the threshold on island 0 / 1 / 2+. kind "count" adds up, "max" keeps the
## best value seen. %d / %s in the text is the threshold.
const TEMPLATES := [
	{"id": "aces", "text": "Подай %d эйса за матч", "event": "ace", "kind": "count", "scope": "match", "n": [2, 3, 4], "gold": 40},
	{"id": "style", "text": "Очко со стилем ×%s", "event": "style", "kind": "max", "scope": "run", "n": [2.0, 2.5, 3.0], "gold": 45},
	{"id": "drops", "text": "Укороченный навылет: %d раза", "event": "drop_winner", "kind": "count", "scope": "run", "n": [2, 3, 4], "gold": 35},
	{"id": "net", "text": "Выиграй %d очков у сетки", "event": "net_point", "kind": "count", "scope": "run", "n": [4, 6, 8], "gold": 30},
	{"id": "rally", "text": "Розыгрыш в %d ударов", "event": "rally", "kind": "max", "scope": "run", "n": [16, 20, 24], "gold": 30},
	{"id": "bagel", "text": "Выиграй матч, не отдав ни гейма", "event": "bagel", "kind": "count", "scope": "run", "n": [1, 1, 1], "gold": 60},
	{"id": "tire", "text": "Загоняй соперника до %d%% выносливости", "event": "tire", "kind": "max", "scope": "run", "n": [80, 83, 86], "gold": 40},
	{"id": "perfect", "text": "%d ударов PERFECT за матч", "event": "perfect", "kind": "count", "scope": "match", "n": [6, 9, 12], "gold": 30},
	{"id": "forehand", "text": "%d виннеров форхендом", "event": "fh_winner", "kind": "count", "scope": "run", "n": [3, 5, 7], "gold": 25},
	{"id": "lob", "text": "Свеча навылет: %d", "event": "lob_winner", "kind": "count", "scope": "run", "n": [1, 2, 2], "gold": 40},
	{"id": "smash", "text": "Смэш навылет: %d", "event": "smash_winner", "kind": "count", "scope": "run", "n": [2, 3, 4], "gold": 35},
	{"id": "serve", "text": "Подача быстрее %d км/ч", "event": "serve_kmh", "kind": "max", "scope": "run", "n": [150, 165, 180], "gold": 25},
	{"id": "streak", "text": "%d очков подряд", "event": "streak", "kind": "max", "scope": "run", "n": [5, 6, 8], "gold": 35},
	{"id": "wins", "text": "Выиграй %d матча в забеге", "event": "wins", "kind": "count", "scope": "run", "n": [2, 3, 3], "gold": 50},
	{"id": "dive", "text": "Достань %d мяча в прыжке", "event": "dive", "kind": "count", "scope": "run", "n": [2, 3, 4], "gold": 20},
]


static func find_template(id: String) -> Dictionary:
	for t in TEMPLATES:
		if t["id"] == id:
			return t
	return {}


static func state() -> Dictionary:
	if not SaveData.club.has("quests"):
		SaveData.club["quests"] = {"run": "", "list": [], "issued": 0, "claimed": 0}
	return SaveData.club["quests"]


static func current() -> Array:
	return state()["list"]


## The island of a location: stream A's Locations.tier() when it exists.
static func tier_of(location: String) -> int:
	var scr: GDScript = load("res://scripts/locations.gd")
	for m in scr.get_script_method_list():
		if m["name"] == "tier":
			return int(scr.call("tier", location))
	return int(TIER_FALLBACK.get(location, 0))


## A run is on (key: its seed). A new one deals three quests; the last run's unfinished
## ones burn, the finished but uncollected ones stay to be collected.
static func start_run(key: String, tier: int) -> bool:
	var st := state()
	if st["run"] == key:
		return false
	var keep: Array = []
	for q in st["list"]:
		if q["done"] and not q["claimed"]:
			keep.append(q)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var pool: Array = range(TEMPLATES.size())
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var dealt: Array = []
	for k in PER_RUN:
		var tpl: Dictionary = TEMPLATES[pool[k]]
		st["issued"] = int(st["issued"]) + 1
		dealt.append(_make(tpl, tier, int(st["issued"]) % ITEM_EVERY == 0))
	st["run"] = key
	st["list"] = dealt + keep
	return true


## No run any more (it ended): the unfinished quests go.
static func end_run() -> void:
	var st := state()
	if st["run"] == "":
		return
	st["run"] = ""
	st["list"] = (st["list"] as Array).filter(func(q): return q["done"] and not q["claimed"])


static func _make(tpl: Dictionary, tier: int, item: bool) -> Dictionary:
	var n = tpl["n"][clampi(tier, 0, 2)]
	var text: String = tpl["text"]
	if tpl["id"] == "tire":
		text = text % (100 - int(n))
	elif text.contains("%s"):
		text = text % str(n)
	elif text.contains("%d"):
		text = text % int(n)
	return {"tpl": tpl["id"], "text": text, "event": tpl["event"], "kind": tpl["kind"], "scope": tpl["scope"],
		"need": n, "have": 0, "done": false, "claimed": false, "item": item, "tier": tier,
		"gold": roundi(int(tpl["gold"]) * float(GOLD_MULT[clampi(tier, 0, GOLD_MULT.size() - 1)]) * (1.0 + ClubBuilds.quest_gold_bonus()))}


## Something happened in a match. Returns the indexes of the quests it finished.
static func note(event: String, value := 1.0) -> Array:
	var finished: Array = []
	var list := current()
	for i in list.size():
		var q: Dictionary = list[i]
		if q["done"] or q["event"] != event:
			continue
		if q["kind"] == "max":
			q["have"] = maxf(float(q["have"]), value)
		else:
			q["have"] = float(q["have"]) + value
		if float(q["have"]) >= float(q["need"]):
			q["have"] = q["need"]
			q["done"] = true
			finished.append(i)
	for i in finished:
		var q: Dictionary = list[i]
		var ev = Engine.get_main_loop().root.get_node_or_null("GameEvents") if Engine.get_main_loop() else null
		if ev:
			ev.quest_done.emit({"index": i, "text": q["text"], "gold": q["gold"], "item": q["item"]})
	if not finished.is_empty():
		SaveData.save()
	return finished


## A new match: counts "in a match" start again (unless already done).
static func match_started() -> void:
	for q in current():
		if q["scope"] == "match" and not q["done"]:
			q["have"] = 0


static func progress(i: int) -> Dictionary:
	var list := current()
	if i < 0 or i >= list.size():
		return {}
	var q: Dictionary = list[i]
	return {"have": q["have"], "need": q["need"], "done": q["done"], "claimed": q["claimed"], "text": q["text"]}


static func claimable_count() -> int:
	var n := 0
	for q in current():
		if q["done"] and not q["claimed"]:
			n += 1
	return n


static func claimable_gold() -> int:
	var g := 0
	for q in current():
		if q["done"] and not q["claimed"]:
			g += int(q["gold"])
	return g


## Collects one quest's reward: {gold, item, to} ({} if not done or already collected).
## to: where the item went - "locker" (stream A), "bag" (the run on), "club" (waits).
static func claim(i: int) -> Dictionary:
	var list := current()
	if i < 0 or i >= list.size():
		return {}
	var q: Dictionary = list[i]
	if not q["done"] or q["claimed"]:
		return {}
	q["claimed"] = true
	SaveData.gold += int(q["gold"])
	state()["claimed"] = int(state()["claimed"]) + 1
	var out := {"gold": int(q["gold"]), "item": {}, "to": ""}
	if q["item"]:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var rarity := Gear.EPIC if rng.randf() < ITEM_EPIC_CHANCE else Gear.RARE
		var item := Gear.roll(rarity, rng, Gear.SLOTS[rng.randi() % Gear.SLOTS.size()])
		out["item"] = item
		out["to"] = _stash(item)
	# Collected quests of a finished run leave the list.
	if state()["run"] == "":
		state()["list"] = (state()["list"] as Array).filter(func(x): return not x["claimed"])
	SaveData.save()
	return out


## Everything that's done: {gold, items: [...]}.
static func claim_all() -> Dictionary:
	var gold := 0
	var items: Array = []
	var i := 0
	while i < current().size():
		var before := current().size()
		var r := claim(i)
		if not r.is_empty():
			gold += int(r["gold"])
			if not (r["item"] as Dictionary).is_empty():
				items.append(r["item"])
		if current().size() == before:
			i += 1
	return {"gold": gold, "items": items}


## Where a quest's item goes: stream A's locker if it's there, the bag of a run on, or it
## waits in the club's save (SaveData.club.quest_items) for the locker.
static func _stash(item: Dictionary) -> String:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "Locker":
			var scr: GDScript = load(c["path"])
			for m in scr.get_script_method_list():
				if m["name"] == "put":
					scr.call("put", item, 4)  # round 4 = a title: any rarity may go in
					return "locker"
	var run := SaveData.resumable()
	if run != null and run.state != Tournament.State.OVER:
		run.add_to_bag(item)
		return "bag"
	var waiting: Array = SaveData.club.get("quest_items", [])
	waiting.append(item)
	SaveData.club["quest_items"] = waiting
	return "club"


## The coach's chalkboard: one line a quest.
static func board_text() -> String:
	var lines: Array[String] = []
	for q in current():
		var mark := "✓" if q["done"] else "%s/%s" % [_num(q["have"]), _num(q["need"])]
		if q["claimed"]:
			continue
		lines.append("%s  %s%s" % [q["text"], mark, "  +вещь" if q["item"] else ""])
	return "\n".join(lines) if not lines.is_empty() else "Задания — с началом турнира"


static func _num(v) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else str(snappedf(f, 0.1))


## Listens to the match for the quests: GameEvents (and RunHub's style points), tournament
## matches only. Created by Club.setup.
class Watch extends Node:
	var main: Node
	var _streak := 0
	var _last := {}                  # the player's last stroke

	func setup(m: Node) -> void:
		main = m
		var ev := get_tree().root.get_node_or_null("GameEvents") if is_inside_tree() else null
		if ev == null:
			ev = Engine.get_main_loop().root.get_node_or_null("GameEvents")
		if ev == null:
			return
		ev.match_started.connect(_on_started)
		ev.match_finished.connect(_on_finished)
		ev.point.connect(_on_point)
		ev.player_stroke.connect(func(info: Dictionary) -> void:
			if not _on():
				return
			_last = info
			if info.get("label", "") == "PERFECT":
				ClubQuests.note("perfect")
			if info.get("diving", false):
				ClubQuests.note("dive")
			if info.get("serve", false):
				ClubQuests.note("serve_kmh", float(info.get("kmh", 0.0))))
		var hub = main.get("run_hub")
		if hub and hub.has_signal("style_scored"):
			hub.style_scored.connect(func(r: Dictionary) -> void:
				if _on():
					ClubQuests.note("style", float(r.get("mult", 1.0))))

	func _on() -> bool:
		return main.tournament_mode and main.tournament != null

	## The run's first match deals its quests (or the club saw the run first).
	func sync_run() -> void:
		var t = main.tournament if main.tournament != null else SaveData.resumable()
		if t != null and t.state != Tournament.State.OVER:
			ClubQuests.start_run(str(t.rng.seed), ClubQuests.tier_of(t.location))
		else:
			ClubQuests.end_run()

	func _on_started(info: Dictionary) -> void:
		_streak = 0
		_last = {}
		if not info.get("tournament", false):
			return
		sync_run()
		ClubQuests.match_started()

	func _on_point(info: Dictionary) -> void:
		if not _on():
			return
		ClubQuests.note("rally", float(info.get("rally", 0)))
		if int(info.get("winner", -1)) != 0:
			_streak = 0
			_last = {}
			return
		_streak += 1
		ClubQuests.note("streak", _streak)
		var reason := String(info.get("reason", ""))
		if reason == "ACE" and int(info.get("server", -1)) == 0:
			ClubQuests.note("ace")
		var t := String(_last.get("type", ""))
		if _last.get("volley", false) or _last.get("smash", false):
			ClubQuests.note("net_point")
		if reason == "WINNER":
			if t == "DROP SHOT":
				ClubQuests.note("drop_winner")
			elif t == "LOB":
				ClubQuests.note("lob_winner")
			elif _last.get("smash", false):
				ClubQuests.note("smash_winner")
			elif int(_last.get("side", 0)) > 0 and not _last.get("volley", false) and not _last.get("serve", false):
				ClubQuests.note("fh_winner")
		var hub = main.get("run_hub")
		if hub and hub.get("match_fx") != null and hub.match_fx.get("lowest") != null:
			ClubQuests.note("tire", 100.0 - float(hub.match_fx.lowest))
		_last = {}

	func _on_finished(info: Dictionary) -> void:
		if not info.get("tournament", false) or not info.get("won", false):
			return
		ClubQuests.note("wins")
		var sb = main.get("scoreboard")
		if sb != null:
			var theirs := 0
			for s in sb.set_scores:
				theirs += int(s[1])
			if theirs == 0:
				ClubQuests.note("bagel")
