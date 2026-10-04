class_name TouchInput
extends Control
## One-finger controls (works anywhere on the screen):
##  - tap              -> tapped(pos): run there / toss on serve
##  - hold still       -> held(pos): keep running toward the finger
##  - swipe / slide    -> swiped(points, times): the whole finger path, read by
##                        ShotGesture (direction, power, flat / topspin / slice)
## Desktop: WASD / arrows move, mouse click = tap, mouse drag = swipe.

signal tapped(pos: Vector2)
signal held(pos: Vector2)
signal swiped(points: PackedVector2Array, times: PackedInt32Array)
signal swipe_progress(points: PackedVector2Array)

const SWIPE_MIN := 0.04     # fraction of screen height before a touch counts as a swipe
const HOLD_MS := 300        # a still touch longer than this becomes "hold to run"
const TAP_MAX_MS := 350

var move_vector := Vector2.ZERO  # keyboard movement (desktop)
var blocked_controls: Array[Control] = []

var _touches := {}               # finger index -> Dictionary
var _trail := PackedVector2Array()
var _trail_fade := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _is_blocked(pos: Vector2) -> bool:
	for c in blocked_controls:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _input(event: InputEvent) -> void:
	var h := get_viewport_rect().size.y
	var now := Time.get_ticks_msec()
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _is_blocked(t.position):
				return
			_touches[t.index] = {
				"start": t.position, "ms": now, "pos": t.position, "swipe": false,
				"points": [t.position], "times": [now],
			}
		elif _touches.has(t.index):
			var d: Dictionary = _touches[t.index]
			_touches.erase(t.index)
			if d["swipe"]:
				_finish_swipe(d, t.position, now, h)
			elif now - int(d["ms"]) <= TAP_MAX_MS:
				tapped.emit(t.position)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if not _touches.has(dr.index):
			return
		var d: Dictionary = _touches[dr.index]
		d["pos"] = dr.position
		(d["points"] as Array).append(dr.position)
		(d["times"] as Array).append(now)
		var start: Vector2 = d["start"]
		if not d["swipe"] and (dr.position - start).length() > SWIPE_MIN * h:
			d["swipe"] = true
		if d["swipe"]:
			swipe_progress.emit(PackedVector2Array(d["points"]))
		queue_redraw()


func _finish_swipe(d: Dictionary, end_pos: Vector2, now: int, _h: float) -> void:
	var points := PackedVector2Array(d["points"])
	var times := PackedInt32Array(d["times"])
	if points[points.size() - 1] != end_pos:
		points.append(end_pos)
		times.append(now)
	_trail = points
	_trail_fade = 1.0
	swiped.emit(points, times)


func _process(delta: float) -> void:
	var k := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		k.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		k.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		k.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		k.y += 1.0
	move_vector = k.normalized()

	var now := Time.get_ticks_msec()
	for idx in _touches:
		var d: Dictionary = _touches[idx]
		if not d["swipe"] and now - int(d["ms"]) > HOLD_MS:
			held.emit(d["pos"])

	if _trail_fade > 0.0:
		_trail_fade = maxf(0.0, _trail_fade - delta * 3.0 / maxf(Engine.time_scale, 0.05))
		queue_redraw()


func _draw() -> void:
	for idx in _touches:
		var d: Dictionary = _touches[idx]
		var pts: Array = d["points"]
		if d["swipe"] and pts.size() > 1:
			draw_polyline(PackedVector2Array(pts), Color(1, 1, 1, 0.75), 7.0, true)
	if _trail_fade > 0.0 and _trail.size() > 1:
		draw_polyline(_trail, Color(1, 1, 0.6, 0.6 * _trail_fade), 7.0, true)
