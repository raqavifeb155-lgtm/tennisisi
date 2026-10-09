class_name ClubNpc
extends RefCounted
## People in the club you can bump into and talk to (stream H-8). Whoever puts a person in the
## club - the coach, the strollers, the fans at the fence, later the juniors and the guests of
## the academy (stream T) - registers them here:
##
##   club.npc.register("anya", node_or_pos, "Поговорить", "club_anya", ["Привет!", "Я Аня."])
##
##   where     a Node3D (followed), a Vector3 (fixed), [object, "method", args...] (a call that
##             returns a Vector3; Vector3.INF = not there now) or a Callable doing the same
##   label     the context button's text when the hero is within 1.2 m ("" = no button)
##   action    what the button does besides the bubble: emitted as the HUD's `chosen(action)`
##             (and `acted(id, action)` here); "" = a line and nothing else
##   lines     3-5 lines, said in turn round and round, in a bubble over the person's head
##   opts      "auto": a line comes by itself when the hero walks by (a stroller's greeting,
##             no button); "radius": how big the body is for the hero (default 0.4 m, a capsule)
##
## Every registered body is an obstacle for the hero (ClubWalk agents): he doesn't walk
## through people, and people stop for him.

signal acted(id: String, action: String)

const TALK_RADIUS := 1.2
const BODY := 0.4
const AUTO_RADIUS := 1.7
const AUTO_GAP := 14.0

var club: Node
var _list := {}
var _speaker := ""
var _clock := 0.0


func setup(c: Node) -> void:
	club = c


func register(id: String, where: Variant, label := "", action := "", lines: Array = [], opts := {}) -> void:
	_list[id] = {"id": id, "where": where, "label": label, "action": action, "lines": lines, "next": 0,
		"auto": bool(opts.get("auto", false)), "radius": float(opts.get("radius", BODY)),
		"head": float(opts.get("head", 2.1)), "cool": 0.0}


func unregister(id: String) -> void:
	_list.erase(id)
	if _speaker == id:
		_speaker = ""


func has(id: String) -> bool:
	return _list.has(id)


func ids() -> Array:
	return _list.keys()


func entry(id: String) -> Dictionary:
	return _list.get(id, {})


## Where a person is now (Vector3.INF if not in the club at the moment).
func position_of(id: String) -> Vector3:
	var e: Dictionary = _list.get(id, {})
	if e.is_empty():
		return Vector3.INF
	var w: Variant = e["where"]
	if typeof(w) == TYPE_OBJECT:
		if not is_instance_valid(w):
			return Vector3.INF
		return (w as Node3D).global_position if (w as Node3D).visible else Vector3.INF
	if w is Array:     # [object, "method", arg...]: its owner may be gone (a new world)
		var o = (w as Array)[0]
		if typeof(o) != TYPE_OBJECT or not is_instance_valid(o):
			return Vector3.INF
		return o.callv((w as Array)[1], (w as Array).slice(2))
	if w is Callable:
		return (w as Callable).call() if (w as Callable).is_valid() else Vector3.INF
	return w


func head_of(id: String) -> Vector3:
	var p := position_of(id)
	return p + Vector3(0, float((_list.get(id, {}) as Dictionary).get("head", 2.1)), 0) if p != Vector3.INF else Vector3.INF


## Everybody's body as an obstacle: [[Vector2 centre, radius], ...] (not `exclude`).
func agent_list(exclude := "") -> Array:
	var out: Array = []
	for id in _list:
		if id == exclude:
			continue
		var p := position_of(id)
		if p != Vector3.INF:
			out.append([Vector2(p.x, p.z), float((_list[id] as Dictionary)["radius"])])
	return out


## Each frame: the nearest person within talking distance that has a button ("" if none);
## strollers with "auto" greet whoever passes.
func tick(hero: Vector3, delta: float) -> String:
	_clock += delta
	var best := ""
	var bd := TALK_RADIUS
	for id in _list:
		var e: Dictionary = _list[id]
		e["cool"] = maxf(0.0, float(e["cool"]) - delta)
		var p := position_of(id)
		if p == Vector3.INF:
			continue
		var d := Vector2(p.x - hero.x, p.z - hero.z).length()
		if e["auto"] and d < AUTO_RADIUS and float(e["cool"]) <= 0.0 and not (e["lines"] as Array).is_empty():
			e["cool"] = AUTO_GAP + randf_range(0.0, 6.0)
			if not club.hud.is_saying():
				say(id, _next_line(e))
		if String(e["label"]) != "" and d < bd:
			bd = d
			best = id
	if _speaker != "" and not club.hud.is_saying():
		_speaker = ""
	return best


func _next_line(e: Dictionary) -> String:
	var lines: Array = e["lines"]
	var line: String = lines[int(e["next"]) % lines.size()]
	e["next"] = int(e["next"]) + 1
	return line


## The context button was pressed: the next line in a bubble and the action, if any.
func talk(id: String) -> void:
	var e: Dictionary = _list.get(id, {})
	if e.is_empty():
		return
	if not (e["lines"] as Array).is_empty():
		say(id, _next_line(e))
	var action: String = e["action"]
	if action != "":
		acted.emit(id, action)
		club.hud.chosen.emit(action, 0)


## A line over this person's head (the coach's own lines come through here too).
func say(id: String, text: String, seconds := 4.0) -> void:
	_speaker = id
	club.hud.say(text, seconds)


## Who the bubble belongs to ("" = nobody registered).
func speaker() -> String:
	return _speaker
