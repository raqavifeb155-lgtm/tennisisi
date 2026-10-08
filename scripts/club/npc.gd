class_name ClubNpc
extends RefCounted
## The registry of the club's people you can talk to (docs/superpowers/specs/2026-10-09-tycoon.md
## 2.4). Whoever owns a person registers him here; Club reads it for the one button at his
## side («Поговорить» / «Тренировать» / «Нанять»), stream H reads it for their collision circles
## (ClubWalk) and for walking around the hero. The students, the coach and the visitors are
## registered by ClubNpcLife; the passers-by of ClubCrowd are H's.
##
##   ClubNpc.register(id, pos, label, action, opts)
##     pos     a Vector3, or a Callable returning one (the person walks)
##     label   the button's text; action: what it does ("club_npc_talk:<id>", "club_npc_train:<id>",
##             "club_hire", "club_npc_hire:guest")
##     opts    r (collision radius, 0.5), kind ("coach" | "student" | "guest" | "passer"),
##             name, lines (what he says), extra ([[label, action]]: quiet buttons)

const TALK_R := 2.0

static var _list := {}


static func register(id: String, pos, label: String, action: String, opts := {}) -> void:
	var n: Dictionary = {"id": id, "pos": pos, "label": label, "action": action, "r": 0.5, "kind": "passer", "name": "", "lines": [], "extra": []}
	for k in opts:
		n[k] = opts[k]
	_list[id] = n


static func unregister(id: String) -> void:
	_list.erase(id)


static func clear() -> void:
	_list = {}


static func has(id: String) -> bool:
	return _list.has(id)


static func position_of(n: Dictionary) -> Vector3:
	var p = n["pos"]
	return (p as Callable).call() if p is Callable else p


## Everybody with where he is now.
static func all() -> Array:
	var out: Array = []
	for id in _list:
		var n: Dictionary = (_list[id] as Dictionary).duplicate()
		n["pos"] = position_of(_list[id])
		out.append(n)
	return out


static func get_npc(id: String) -> Dictionary:
	if not _list.has(id):
		return {}
	var n: Dictionary = (_list[id] as Dictionary).duplicate()
	n["pos"] = position_of(_list[id])
	return n


## The nearest one within `r` of the hero's feet (his own radius counts), {} if none.
static func near(pos: Vector3, r := TALK_R) -> Dictionary:
	var best := {}
	var best_d := INF
	for n in all():
		if String(n["action"]) == "":
			continue
		var p: Vector3 = n["pos"]
		var d := Vector2(pos.x - p.x, pos.z - p.z).length() - float(n["r"])
		if d <= r and d < best_d:
			best = n
			best_d = d
	return best


## The button of a person (what ClubHud.show_place takes): {label, action, extra}.
static func button(id: String) -> Dictionary:
	var n := get_npc(id)
	if n.is_empty():
		return {}
	return {"label": String(n["label"]).to_upper(), "action": n["action"], "extra": n["extra"]}
