class_name TouchInput
extends Control
## Two-thumb mobile controls.
##  - Left half of the screen: floating virtual joystick (movement).
##  - Right half: swipe to hit. Released swipe = swing.
## Desktop fallback: WASD / arrows to move, mouse drag on the right half to swipe.

signal swiped(vec: Vector2, duration: float)
signal swipe_moved(vec: Vector2)   # live, while the finger is down (for the aim marker)
signal swipe_ended
signal swipe_started               # finger down on the swipe half (used to toss on serve)

const JOY_RADIUS := 90.0
const MIN_SWIPE := 0.035  # fraction of screen height

var move_vector := Vector2.ZERO
var blocked_controls: Array[Control] = []

var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _swipe_index := -1
var _swipe_start := Vector2.ZERO
var _swipe_start_ms := 0
var _swipe_points := PackedVector2Array()
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
	var size_px := get_viewport_rect().size
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _is_blocked(t.position):
				return
			if t.position.x < size_px.x * 0.5:
				if _joy_index == -1:
					_joy_index = t.index
					_joy_origin = t.position
					_joy_pos = t.position
			elif _swipe_index == -1:
				_swipe_index = t.index
				_swipe_start = t.position
				_swipe_start_ms = Time.get_ticks_msec()
				_swipe_points = PackedVector2Array([t.position])
				swipe_started.emit()
		else:
			if t.index == _joy_index:
				_joy_index = -1
				move_vector = Vector2.ZERO
			elif t.index == _swipe_index:
				_swipe_index = -1
				_finish_swipe(t.position, size_px)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_index:
			_joy_pos = d.position
			var v := (_joy_pos - _joy_origin) / JOY_RADIUS
			if v.length() > 1.0:
				_joy_origin = _joy_pos - v.normalized() * JOY_RADIUS
				v = v.normalized()
			move_vector = v
		elif d.index == _swipe_index:
			_swipe_points.append(d.position)
			swipe_moved.emit((d.position - _swipe_start) / size_px.y)
		queue_redraw()


func _finish_swipe(end_pos: Vector2, size_px: Vector2) -> void:
	var vec := (end_pos - _swipe_start) / size_px.y
	var dur := maxf((Time.get_ticks_msec() - _swipe_start_ms) / 1000.0, 0.03)
	_trail = _swipe_points.duplicate()
	_trail.append(end_pos)
	_trail_fade = 1.0
	swipe_ended.emit()
	if vec.length() >= MIN_SWIPE:
		swiped.emit(vec, dur)


func _process(delta: float) -> void:
	if _joy_index == -1:
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
	if _trail_fade > 0.0:
		_trail_fade = maxf(0.0, _trail_fade - delta * 3.0 / maxf(Engine.time_scale, 0.05))
		queue_redraw()


func _draw() -> void:
	if _joy_index != -1:
		draw_circle(_joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(_joy_origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		var knob := _joy_origin + move_vector * JOY_RADIUS
		draw_circle(knob, 38.0, Color(1, 1, 1, 0.45))
	if _swipe_index != -1 and _swipe_points.size() > 1:
		draw_polyline(_swipe_points, Color(1, 1, 1, 0.7), 6.0, true)
	elif _trail_fade > 0.0 and _trail.size() > 1:
		draw_polyline(_trail, Color(1, 1, 0.6, 0.6 * _trail_fade), 6.0, true)
