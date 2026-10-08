class_name ModalStack
extends Node
## The one owner of the game's pause and of which modal window is on top (UI_FLOW_TZ 5.5,
## rule 4). Windows are pushed with an id; closing one returns to the window under it in
## the state it was left (help from the pause -> the pause, the game still standing).
##
## The game is paused while a window opened from a match (`pauses`) is in the stack. The
## stack writes `get_tree().paused` only when its own decision changes, so a tool or a test
## that pauses the tree itself is not fought every frame. A top window hidden from outside
## (a tool closing the tutorial by `visible = false`) leaves the stack on the next frame.

signal changed

var _entries: Array[Dictionary] = []   # {id, node, pauses}, bottom first
var _pausing := false                  # what the stack last decided


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Opens `id` on top (moved up if it was already open).
func push(id: String, node: CanvasItem, pauses: bool) -> void:
	_remove(id)
	_entries.append({"id": id, "node": node, "pauses": pauses})
	_sync()


## Closes `id` and every window opened over it.
func pop(id: String) -> void:
	var i := _index(id)
	if i < 0:
		return
	_entries.resize(i)
	_sync()


func clear() -> void:
	_entries.clear()
	_sync()


func top() -> String:
	return "" if _entries.is_empty() else String(_entries.back()["id"])


func has(id: String) -> bool:
	return _index(id) >= 0


func is_empty() -> bool:
	return _entries.is_empty()


## The ids from the bottom up (for tests and the debug line).
func ids() -> Array[String]:
	var out: Array[String] = []
	for e in _entries:
		out.append(String(e["id"]))
	return out


func _process(_delta: float) -> void:
	var dropped := false
	while not _entries.is_empty():
		var n = _entries.back()["node"]
		if is_instance_valid(n) and (n as CanvasItem).visible:
			break
		_entries.pop_back()
		dropped = true
	if dropped:
		_sync()


func _index(id: String) -> int:
	for i in _entries.size():
		if _entries[i]["id"] == id:
			return i
	return -1


func _remove(id: String) -> void:
	var i := _index(id)
	if i >= 0:
		_entries.remove_at(i)


func _sync() -> void:
	var want := false
	for e in _entries:
		if e["pauses"]:
			want = true
	if want != _pausing and is_inside_tree():
		_pausing = want
		get_tree().paused = want
	changed.emit()
