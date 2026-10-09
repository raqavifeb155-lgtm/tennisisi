class_name AcademyHouse
extends RefCounted
## The academy's house, the state and what it does (spec 2, 7, 9): the levels of the eight rooms, buying
## them, the long build of levels 4 and 5 (the gold goes at once, the scaffolding stays for a few runs, like
## ClubBuilds' `runs`), and the effects the school reads through Academy's hooks - the seats, the growth
## and the ceiling. Data and logic only: HouseRooms is the table, HouseWorld draws, the sheets show.
##
## Saved in SaveData.house (the section "house", a new one; a save without it is an empty house):
##   v 1
##   levels   {room: level}            what is built
##   building {room: {level, until}}   paid, on scaffolding; `until` = the SaveData.played that finishes it
##   spent    int                      the gold the house has taken (the save's score grows with it)
## More comes with the next stages (life, bonds, the pros) beside these keys.
##
## Rules: the rooms open with the academy's level (HouseRooms.opens); a room's level is at most the
## building's + 1; online the house gives nothing (`enabled`, like ClubBuilds.utility_enabled).

static var enabled := true       # off in an online match: equal stats, no house


static func data() -> Dictionary:
	var d: Dictionary = SaveData.house
	if not d.has("v"):
		d["v"] = 1
	if not d.has("levels"):
		d["levels"] = {}
	if not d.has("building"):
		d["building"] = {}
	if not d.has("spent"):
		d["spent"] = 0
	return d


# --- The state ------------------------------------------------------------------------------------

## The academy building's level, 0 without it. The house is entered from level 1.
static func building_level() -> int:
	return Academy.level()


static func is_built() -> bool:
	return building_level() >= 1


## The highest level any room can have now.
static func max_level() -> int:
	return HouseRooms.cap_for_building(building_level())


static func is_open(room: String) -> bool:
	return is_built() and building_level() >= HouseRooms.opens(room)


## The built level 0..5 (what stands; a level on scaffolding is not yet).
static func level(room: String) -> int:
	var lv = (SaveData.house.get("levels", {}) as Dictionary).get(room, 0)
	return clampi(int(lv), 0, HouseRooms.MAX_LEVEL)


static func levels_total() -> int:
	var n := 0
	for r in HouseRooms.ids():
		n += level(r)
	return n


static func spent() -> int:
	return int(SaveData.house.get("spent", 0))


## The rooms on scaffolding: {room: {level, until}}.
static func building() -> Dictionary:
	var b = SaveData.house.get("building", {})
	return b if b is Dictionary else {}


static func is_building(room: String) -> bool:
	return building().has(room)


## Runs still to play before the scaffolding comes down (0: ready, or not building).
static func runs_left(room: String) -> int:
	if not is_building(room):
		return 0
	return maxi(int(building()[room].get("until", 0)) - SaveData.played, 0)


## The level the next purchase would build (0 at the top).
static func next_level(room: String) -> int:
	var lv := level(room)
	return lv + 1 if lv < HouseRooms.MAX_LEVEL else 0


static func next_price(room: String) -> int:
	var n := next_level(room)
	return HouseRooms.price(n) if n > 0 else 0


## "" when the next level can be bought now; else why not, short, for the button.
static func why_not(room: String) -> String:
	if not is_built():
		return "Сначала построй академию"
	if not is_open(room):
		return "Откроется на ур. %d академии" % HouseRooms.opens(room)
	if is_building(room):
		var left := runs_left(room)
		return "Леса стоят · ещё %d %s" % [left, ClubBuilds.runs_word(left)] if left > 0 else "Готово — зайди в дом заново"
	var n := next_level(room)
	if n == 0:
		return "Комната построена целиком"
	if n > max_level():
		return "Нужна академия ур. %d" % (n - 1)
	if SaveData.gold < next_price(room):
		return "Нужно ещё %d" % (next_price(room) - SaveData.gold)
	return ""


static func can_buy(room: String) -> bool:
	return why_not(room) == ""


## How many rooms can be improved right now (the badge on the door).
static func affordable_count() -> int:
	var n := 0
	for r in HouseRooms.ids():
		if can_buy(r):
			n += 1
	return n


## Buys the next level: the gold goes and is saved before any show. A level of 4 or 5 only puts the scaffolding
## up. Returns the level bought (or being built), 0 if it can't be.
static func buy(room: String) -> int:
	if not HouseRooms.has(room) or not can_buy(room):
		return 0
	var n := next_level(room)
	var price := next_price(room)
	var d := data()
	SaveData.gold -= price
	d["spent"] = int(d["spent"]) + price
	var runs := HouseRooms.runs(n)
	if runs > 0:
		var b: Dictionary = (d["building"] as Dictionary).duplicate()
		b[room] = {"level": n, "until": SaveData.played + runs}
		d["building"] = b
	else:
		var lv: Dictionary = (d["levels"] as Dictionary).duplicate()
		lv[room] = n
		d["levels"] = lv
	SaveData.save()
	if runs <= 0:
		_emit("house_room_built", {"room": room, "level": n})
	return n


## Takes the scaffolding down where the runs are played. Returns [{room, level}] done (the house shows each
## one's build moment when it opens).
static func complete_ready() -> Array:
	var done: Array = []
	var b: Dictionary = building().duplicate()
	for r in HouseRooms.ids():
		if b.has(r) and SaveData.played >= int(b[r].get("until", 0)):
			done.append({"room": r, "level": int(b[r].get("level", 0))})
	if done.is_empty():
		return done
	var d := data()
	var lv: Dictionary = (d["levels"] as Dictionary).duplicate()
	for x in done:
		lv[x["room"]] = maxi(int(lv.get(x["room"], 0)), int(x["level"]))
		b.erase(x["room"])
	d["levels"] = lv
	d["building"] = b
	SaveData.save()
	for x in done:
		_emit("house_room_built", {"room": x["room"], "level": x["level"]})
	return done


static func _emit(sig: String, info: Dictionary) -> void:
	var ml := Engine.get_main_loop() as SceneTree
	var ev: Node = ml.root.get_node_or_null("GameEvents") if ml != null else null
	if ev != null and ev.has_signal(sig):
		ev.emit_signal(sig, info)


# --- What the house gives the school (Academy's hooks) --------------------------------------------

## The seats: the school's own row (Academy.CAPACITY by the building) or the dorm's, the better.
static func capacity() -> int:
	var base := int(Academy.CAPACITY[clampi(Academy.level(), 0, Academy.CAPACITY.size() - 1)])
	if not enabled:
		return base
	var cap := 0
	var lv := level("dorm")
	if lv > 0:
		cap = int(HouseRooms.level("dorm", lv).get("cap", 0))
	return maxi(base, cap)


## The multiplier on the experience of a stat: every room's effects, tag by tag, multiplied; never past
## HouseRooms.GROWTH_CAP (rooms, form and trust all together stay under it).
static func growth_mult(_st: Dictionary, stat: String) -> float:
	if not enabled:
		return 1.0
	var m := 1.0
	for r in HouseRooms.ids():
		for g in HouseRooms.grow_of(r, level(r)):
			var stats: Array = g["stats"]
			if stats.has("*") or stats.has(stat):
				m *= 1.0 + float(g["pct"]) / 100.0
	return minf(m, HouseRooms.GROWTH_CAP)


## The ceiling of a stat goes up by this (the gym's top level: speed and stamina +1).
static func ceiling_add(_st: Dictionary, stat: String) -> int:
	if not enabled or stat == "":
		return 0
	var n := 0
	for r in HouseRooms.ids():
		n += int(HouseRooms.ceil_of(r, level(r)).get(stat, 0))
	return n


## Puts the house into the school: the hooks Academy reads. Safe to call again.
static func install() -> void:
	Academy.set_hook("capacity", capacity)
	Academy.set_hook("growth_mult", growth_mult)
	Academy.set_hook("ceiling_add", ceiling_add)


static func uninstall() -> void:
	for h in ["capacity", "growth_mult", "ceiling_add"]:
		Academy.set_hook(h, Callable())
