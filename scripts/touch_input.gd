class_name TouchInput
extends Control
## Two-thumb controls:
##  - below the player: a floating joystick for the left thumb (move_vector).
##    It appears where the thumb lands; a quick tap there still counts as a tap,
##    and a quick flick up the screen there still counts as a shot (a swing started
##    a little too low must not turn into a run and a missed ball).
##  - above the player (anywhere else):
##    - tap            -> tapped(pos): run there / toss on serve
##    - hold still     -> held(pos): keep running toward the finger
##    - swipe / slide  -> swiped(points, times): the whole finger path, read by
##                        ShotGesture (direction, power, flat / topspin / slice)
## Both thumbs work at once: run with the left, swing with the right.
## Desktop: WASD / arrows move, mouse click = tap, mouse drag = swipe.

signal tapped(pos: Vector2)
signal held(pos: Vector2)
signal swiped(points: PackedVector2Array, times: PackedInt32Array)
signal swipe_progress(points: PackedVector2Array)

const SWIPE_MIN := 0.04     # fraction of screen height before a touch counts as a swipe
const HOLD_MS := 300        # a still touch longer than this becomes "hold to run"
const TAP_MAX_MS := 350

const STICK_RADIUS := 75.0      # px of thumb travel for full speed
const STICK_DEAD := 0.15
const FLICK_MS := 300           # a joystick touch released this fast...
const FLICK_MIN := 0.065        # ...after travelling this far (x screen height), mostly up = a shot

var move_vector := Vector2.ZERO  # joystick or keyboard, x = right, y = toward the camera
var blocked_controls: Array[Control] = []
## Screen y below which a touch becomes the joystick (just under the player's feet).
var stick_zone_top := INF
var stick_active := false
## The faint hint where the joystick zone begins (off in the club: the whole lower screen walks).
var show_zone := true
## Set by the game while a hit is due (the ball is close): then a finger moving up out
## of the joystick zone is a shot at any speed, not only a quick flick.
var shot_window := false

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_ms := 0
var _stick_moved := false
var _stick_vector := Vector2.ZERO
var _stick_points: Array = []
var _stick_times: Array = []
var _drawn_zone := INF

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
		if t.index == _stick_index and not t.pressed:
			_stick_index = -1
			stick_active = false
			_stick_vector = Vector2.ZERO
			var travel: Vector2 = t.position - (_stick_points[0] as Vector2)
			if not _stick_moved and now - _stick_ms <= TAP_MAX_MS:
				tapped.emit(t.position)
			elif (now - _stick_ms <= FLICK_MS or (shot_window and now - _stick_ms <= 900)) and travel.length() >= FLICK_MIN * h and -travel.y > 0.5 * travel.length():
				# Not a run: a swing that started in the joystick zone.
				_finish_swipe({"points": _stick_points, "times": _stick_times}, t.position, now, h)
			queue_redraw()
			return
		if t.pressed:
			if _is_blocked(t.position):
				return
			if t.position.y > stick_zone_top and _stick_index == -1:
				_stick_index = t.index
				_stick_origin = t.position
				_stick_pos = t.position
				_stick_ms = now
				_stick_moved = false
				_stick_points = [t.position]
				_stick_times = [now]
				stick_active = true
				queue_redraw()
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
		if dr.index == _stick_index:
			_stick_points.append(dr.position)
			_stick_times.append(now)
			_update_stick(dr.position, h)
			return
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


func _update_stick(pos: Vector2, h: float) -> void:
	_stick_pos = pos
	var off := pos - _stick_origin
	if off.length() > SWIPE_MIN * h * 0.5:
		_stick_moved = true
	# The base follows the thumb when it goes past the edge, so turning back is instant.
	if off.length() > STICK_RADIUS:
		_stick_origin = pos - off.normalized() * STICK_RADIUS
		off = pos - _stick_origin
	var v := off / STICK_RADIUS
	var l := v.length()
	_stick_vector = Vector2.ZERO if l < STICK_DEAD else v / l * ((l - STICK_DEAD) / (1.0 - STICK_DEAD))
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
	move_vector = k.normalized() if k != Vector2.ZERO else _stick_vector

	if absf(stick_zone_top - _drawn_zone) > 2.0:
		_drawn_zone = stick_zone_top
		queue_redraw()

	var now := Time.get_ticks_msec()
	for idx in _touches:
		var d: Dictionary = _touches[idx]
		if not d["swipe"] and now - int(d["ms"]) > HOLD_MS:
			held.emit(d["pos"])

	if _trail_fade > 0.0:
		_trail_fade = maxf(0.0, _trail_fade - delta * 3.0 / maxf(Engine.time_scale, 0.05))
		queue_redraw()


func _draw() -> void:
	if stick_active:
		draw_circle(_stick_origin, STICK_RADIUS + 18.0, Color(0, 0, 0, 0.16))
		draw_arc(_stick_origin, STICK_RADIUS + 18.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
		draw_circle(knob, 34.0, Color(1, 1, 1, 0.5))
	elif show_zone and stick_zone_top < get_viewport_rect().size.y - 90.0:
		# Where the thumb goes: a faint ring under the player, and a faint line where the
		# joystick zone begins (above it every touch is a shot or a tap).
		var vp := get_viewport_rect().size
		draw_line(Vector2(vp.x * 0.08, stick_zone_top), Vector2(vp.x * 0.92, stick_zone_top), Color(1, 1, 1, 0.1), 2.0, true)
		var home := Vector2(vp.x * 0.5, minf((stick_zone_top + vp.y) * 0.5 + 20.0, vp.y - 110.0))
		draw_arc(home, STICK_RADIUS + 18.0, 0.0, TAU, 48, Color(1, 1, 1, 0.13), 3.0, true)
		draw_circle(home, 34.0, Color(1, 1, 1, 0.08))
	for idx in _touches:
		var d: Dictionary = _touches[idx]
		var pts: Array = d["points"]
		if d["swipe"] and pts.size() > 1:
			draw_polyline(PackedVector2Array(pts), Color(1, 1, 1, 0.75), 7.0, true)
	if _trail_fade > 0.0 and _trail.size() > 1:
		draw_polyline(_trail, Color(1, 1, 0.6, 0.6 * _trail_fade), 7.0, true)
