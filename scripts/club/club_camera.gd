class_name ClubCamera
extends Camera3D
## The club's camera (docs/club/H1_SPEC.md 5): above and behind the hero, following
## softly; inside a pavilion it holds the room's own framing; quick travel flies it to a
## place. The match camera (GameCamera) is untouched: Club switches between them.

const HEIGHT := 9.0        # the hero stands at ~2/3 of the screen, over the buttons; beyond
const BACK := 12.0         # him the court, the river and the city
const AHEAD := 7.3
const FOLLOW_K := 6.0       # 1/s

var target: Node3D
var _frame_pos := Vector3.INF   # a held framing (a room), or INF = follow the hero
var _frame_look := Vector3.ZERO
var _look := Vector3.ZERO
var _tw: Tween


func _ready() -> void:
	fov = 52.0
	near = 0.5
	far = 700.0


func _follow_pos() -> Vector3:
	var p := target.global_position
	return Vector3(p.x, HEIGHT, p.z + BACK)


func _follow_look() -> Vector3:
	var p := target.global_position
	return Vector3(p.x, 0.0, p.z - AHEAD)


## Straight to where the camera should be (entering the club, after quick travel).
func snap() -> void:
	if target == null:
		return
	global_position = _follow_pos() if _frame_pos == Vector3.INF else _frame_pos
	_look = _follow_look() if _frame_pos == Vector3.INF else _frame_look
	look_at(_look, Vector3.UP)


## Holds a framing (a room) - eased over `t` seconds.
func frame(pos: Vector3, look: Vector3, t := 0.4) -> void:
	_frame_pos = pos
	_frame_look = look
	_glide(pos, look, t)


## Back to following the hero.
func release(t := 0.4) -> void:
	if _frame_pos == Vector3.INF:
		return
	_frame_pos = Vector3.INF
	_glide(_follow_pos(), _follow_look(), t)


## Quick travel: a short flight to the hero's new place (the world stays one piece).
func fly(t := 0.4) -> void:
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
	var want_pos := _follow_pos() if _frame_pos == Vector3.INF else _frame_pos
	var want_look := _follow_look() if _frame_pos == Vector3.INF else _frame_look
	var k := 1.0 - exp(-FOLLOW_K * delta)
	global_position = global_position.lerp(want_pos, k)
	_look = _look.lerp(want_look, k)
	look_at(_look, Vector3.UP)
