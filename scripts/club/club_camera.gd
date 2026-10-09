class_name ClubCamera
extends Camera3D
## The club's camera (docs/club/H1_SPEC.md 5, rebuilt for stream H): low and behind the
## hero's back, like a walk through a park, not a map; it trails his heading softly.
## Inside a pavilion it holds the room's own framing; the match camera (GameCamera) is
## untouched: Club switches between them.
##
## The stick is relative to the camera as it was when the finger went down (Club asks
## `stick_yaw()`): the camera may swing behind the hero on a long walk, and the thumb
## does not have to chase it, so the hero never spirals while the camera turns.

const HEIGHT := 3.9        # metres over the ground, behind the hero's back
const BACK := 8.8
const AHEAD := 6.5         # the look point, ahead of the hero
const LOOK_Y := 0.0
const RUN_BACK := 1.4       # running: a little farther back...
const RUN_DOWN := 0.6       # ...and lower
const MIN_BACK := 2.6      # when a wall is behind him the camera comes closer, not through it
const FOLLOW_K := 5.0      # 1/s, position
const YAW_K := 2.2         # 1/s, how fast it swings behind a turning hero
const YAW_K_RUN := 4.5     # the same on the auto-run along a path

var target: Node3D
var walk_override: ClubWalk     # the walls the camera keeps out of, when not the club's: the academy's house (AH-1)
var yaw := 0.0                  # the heading it looks along: 0 = north (-z), as Godot's rotation.y
var run_mode := false           # the auto-run: swing behind faster
var _frame_pos := Vector3.INF   # a held framing (a room), or INF = follow the hero
var _frame_look := Vector3.ZERO
var _look := Vector3.ZERO
var _run_k := 0.0               # 0 standing or walking .. 1 running (smoothed)
var _back := BACK               # the current distance (shorter near walls)
var _tw: Tween


func _ready() -> void:
	fov = 55.0
	near = 0.4
	far = 700.0


## Forward on the ground (x, z) for a heading.
static func forward_of(a: float) -> Vector3:
	return Vector3(-sin(a), 0.0, -cos(a))


## The yaw the stick is read against: the held room's (always north) or the following one.
func stick_yaw() -> float:
	return 0.0 if _frame_pos != Vector3.INF else yaw


func _back_max() -> float:
	return BACK + RUN_BACK * _run_k


func _clear_back(p: Vector3) -> float:
	var walk := _walk()
	if walk == null:
		return _back_max()
	var back_dir := -forward_of(yaw)
	var d := _back_max()
	# The gate's arch, beam and sign hang over the way in: the camera never goes through
	# them to the street while the hero is inside (it stays a metre short, close above him).
	if p.z < ClubLevels.GATE_Z - 0.3 and back_dir.z > 0.05 and absf(p.x + back_dir.x * (ClubLevels.GATE_Z - p.z) / back_dir.z) < 7.0:
		var reach := (ClubLevels.GATE_Z - 1.3 - p.z) / back_dir.z
		d = minf(d, maxf(reach, 0.3))
	var from := Vector2(p.x, p.z)
	var step := 0.5
	var t := 1.5
	while t <= _back_max():
		var q := from + Vector2(back_dir.x, back_dir.z) * t
		if walk.blocked(q, 0.15) or _in_crown(q):
			d = minf(d, maxf(t - 0.8, MIN_BACK))
			break
		t += step
	return d


func _in_crown(q: Vector2) -> bool:
	var club := get_parent()
	if club == null or club.get("world") == null:
		return false
	var sc := (club.get("world") as Node).get_node_or_null("ClubScenery")
	if sc == null:
		return false
	for c in sc.get("crowns"):
		if q.distance_to(Vector2(c.x, c.y)) < float(c.z):
			return true
	return false


func _walk() -> ClubWalk:
	if walk_override != null:
		return walk_override
	var club := get_parent()
	if club != null and club.get("world") != null:
		var w = club.get("world")
		if is_instance_valid(w):
			return (w as ClubWorld).walk
	return null


func _follow_pos() -> Vector3:
	var p := target.global_position
	# pulled in by a wall or the gate, the camera rises: it looks down on him, he doesn't fill the frame
	return p - forward_of(yaw) * _back + Vector3(0.0, HEIGHT - RUN_DOWN * _run_k + clampf(_back_max() - _back, 0.0, 6.0) * 0.5, 0.0)


func _follow_look() -> Vector3:
	var p := target.global_position
	return p + forward_of(yaw) * AHEAD * clampf(_back / _back_max(), 0.12, 1.0) + Vector3(0.0, LOOK_Y, 0.0)


## Straight to where the camera should be (entering the club, after quick travel). On a
## fresh entry it stands behind the hero looking north, as the main screen always did.
func snap(north := true) -> void:
	if target == null:
		return
	if north:
		yaw = 0.0
		target.rotation.y = 0.0
	else:
		yaw = target.rotation.y
	_back = _clear_back(target.global_position)
	global_position = _follow_pos() if _frame_pos == Vector3.INF else _frame_pos
	_look = _follow_look() if _frame_pos == Vector3.INF else _frame_look
	look_at(_look, Vector3.UP)


## Holds a framing (a room) - eased over `t` seconds.
func frame(pos: Vector3, look: Vector3, t := 0.4) -> void:
	yaw = 0.0   # every framing looks north: leaving one starts from there and swings behind the hero as he walks
	_frame_pos = pos
	_frame_look = look
	_glide(pos, look, t)


## Back to following the hero.
func release(t := 0.4) -> void:
	if _frame_pos == Vector3.INF:
		return
	_frame_pos = Vector3.INF
	if target != null:
		_back = _clear_back(target.global_position)
		_glide(_follow_pos(), _follow_look(), t)


## Quick travel by teleport (tests, the foreman): a short flight to the hero's new place.
func fly(t := 0.4) -> void:
	if target != null and _frame_pos == Vector3.INF:
		_back = _clear_back(target.global_position)
	_glide(_follow_pos() if _frame_pos == Vector3.INF else _frame_pos, _follow_look() if _frame_pos == Vector3.INF else _frame_look, t)


func is_flying() -> bool:
	return _tw != null and _tw.is_running()


func _glide(pos: Vector3, look: Vector3, t: float) -> void:
	if _tw:
		_tw.kill()
	var from_pos := global_position
	var from_look := _look
	var arc := clampf(from_pos.distance_to(pos) * 0.12, 0.0, 6.0)  # a long hop rises a little
	_tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_tw.tween_method(func(k: float) -> void:
		global_position = from_pos.lerp(pos, k) + Vector3.UP * arc * sin(k * PI)
		_look = from_look.lerp(look, k)
		look_at(_look, Vector3.UP), 0.0, 1.0, t)


func _process(delta: float) -> void:
	if target == null or not current or is_flying():
		return
	var follow := _frame_pos == Vector3.INF
	if follow:
		# Swing behind the hero while he walks; hold the heading when he stands.
		var p3 := target as Athlete
		var speed := Vector2(p3.velocity.x, p3.velocity.z).length() if p3 != null else 0.0
		var moving := speed > 0.8
		_run_k = lerpf(_run_k, clampf((speed - 2.6) / 2.0, 0.0, 1.0), 1.0 - exp(-2.5 * delta))
		if moving:
			var k_yaw := 1.0 - exp(-(YAW_K_RUN if run_mode else YAW_K) * delta)
			yaw = lerp_angle(yaw, target.rotation.y, k_yaw)
		_back = lerpf(_back, _clear_back(target.global_position), 1.0 - exp(-6.0 * delta))
	var want_pos := _follow_pos() if follow else _frame_pos
	var want_look := _follow_look() if follow else _frame_look
	var k := 1.0 - exp(-FOLLOW_K * delta)
	global_position = global_position.lerp(want_pos, k)
	_look = _look.lerp(want_look, k)
	look_at(_look, Vector3.UP)
