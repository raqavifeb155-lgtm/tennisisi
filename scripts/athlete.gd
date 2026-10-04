class_name Athlete
extends Node3D
## A tennis player: momentum-based movement plus a procedural rig.
##
## The rig is built from simple shapes but moves like a body: two-bone IK arms
## (shoulder -> elbow -> hand) and legs (hip -> knee -> foot), a torso that turns for
## the unit turn and unwinds through the shot, a head that tracks the ball, and a
## racket held in the hand. Each stroke has its own racket path and the racket head
## is steered onto the real contact point, so the strings meet the ball.
##   forehand topspin  low-to-high, finishing over the left shoulder
##   forehand flat     level through the ball, finishing across the chest
##   slice (both wings) high-to-low with an open face, finishing toward the net
##   backhand           two-handed: both hands on the grip, low-to-high, finish over the right shoulder
##   smash / serve     trophy pose, racket drop behind the back, up and through, down across
##   drop shot         disguised as a slice, then soft hands: a short, gentle finish
## Movement has weight: arms pump when running, the body leans into the sprint, and a
## hard stop turns into a slide with the lead leg out and the body low.
## Right-handed. Local space: forward = -Z, right = +X.

enum Style { TOPSPIN, FLAT, SLICE, SMASH, SERVE, DROP, UNDERARM }

const REACH := 1.55            # max horizontal distance body -> ball at contact
const IDEAL_LATERAL := 0.75    # ideal sideways distance of the ball at contact
const CONTACT_FORWARD := 0.45  # contact point in front of the body
const IDEAL_HEIGHT := 0.95

const HIP_H := 0.92
const THIGH := 0.46
const SHIN := 0.46
const SHOULDER_H := 1.42
const SHOULDER_W := 0.2
const UPPER_ARM := 0.3
const FOREARM := 0.28
const RACKET_REACH := 0.52     # hand -> racket head centre
const SWING_TO_CONTACT := 0.16
const FOLLOW_TIME := 0.28

var facing := -1.0             # -1 faces -Z (near player), +1 faces +Z (opponent)
var velocity := Vector3.ZERO
var max_speed := 6.2
var accel := 22.0
var decel := 30.0
var move_input := Vector2.ZERO # desired direction in world x/z, length 0..1
var area := Rect2(-9.0, 0.8, 18.0, 17.0)  # allowed region: x, z
var look_target := Vector3.INF # world point the head follows (usually the ball)

# Pose state (model-local)
var _hand := Vector3(0.12, 1.02, -0.36)
var _rdir := Vector3(-0.35, 0.5, -0.75).normalized()
var _lhand := Vector3(0.0, 1.05, -0.45)
var _twist := 0.0
var _crouch := 0.06
var _lean := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0

var _mode := 0                 # 0 ready, 1 prepared, 2 swinging, 3 tossing, 4 holding the ball to serve
var _side := 1
var _style := Style.TOPSPIN
var _clock := 0.0
var _contact_at := 0.0
var _contact := Vector3(IDEAL_LATERAL, IDEAL_HEIGHT, -CONTACT_FORWARD)  # local contact point
var _swing_from_hand := Vector3.ZERO
var _swing_from_dir := Vector3.ZERO

var _hop := 1.0
var _run_phase := 0.0
var _prev_speed := 0.0
var _slide := 0.0              # 1 at the start of a slide, decays to 0
var _slide_dir := Vector3.ZERO # model-local direction of the slide
var _dust: CPUParticles3D
var _last_vel := Vector3.ZERO
var _lhand_actual := Vector3(0.05, 1.05, -0.38)

# Visual nodes
var _model: Node3D
var _bones := {}
var _racket: Node3D
var _racket_mat: StandardMaterial3D
var _racket_light: OmniLight3D
var _head: Node3D
var _hand_r: MeshInstance3D
var _hand_l: MeshInstance3D


func setup(face: float, shirt: Color, region: Rect2) -> void:
	facing = face
	area = region
	_build(shirt)
	rotation.y = 0.0 if facing < 0.0 else PI


func right() -> Vector3:
	return Vector3(-facing, 0.0, 0.0)


func forward() -> Vector3:
	return Vector3(0.0, 0.0, facing)


## Signed sideways offset of p relative to the body: + = forehand side.
func lateral_of(p: Vector3) -> float:
	return (p - global_position).dot(right())


## Where the body should stand to meet a ball at contact point p on the given side.
func stance_for(p: Vector3, side: int) -> Vector3:
	var s := p - right() * (IDEAL_LATERAL * side) - forward() * CONTACT_FORWARD
	s.y = 0.0
	return s


func is_swinging() -> bool:
	return _mode == 2


## Unit turn toward the side the ball is coming to.
func prepare(side: int, style := Style.TOPSPIN) -> void:
	if _mode == 2:
		return
	_mode = 1
	_side = side
	_style = style


## Before the toss: ball held in the left hand in front, racket ready.
func serve_ready() -> void:
	if _mode != 2:
		_mode = 4


## Where the left hand is right now (the ball sits in it before the toss).
func left_hand_world() -> Vector3:
	return _model.to_global(_lhand_actual) if _model else global_position + Vector3.UP


## Toss: sideways stance, tossing arm going up.
func prepare_serve() -> void:
	if _mode == 2:
		return
	_mode = 3
	_side = 1
	_style = Style.SERVE


func relax() -> void:
	if _mode != 2:
		_mode = 0


## Start a swing that meets the ball at contact_world after time_to_contact (game seconds).
func swing(side: int, time_to_contact: float, contact_world: Vector3, style := Style.TOPSPIN) -> void:
	_mode = 2
	_side = side
	_style = style
	_clock = 0.0
	_contact_at = maxf(time_to_contact, 0.05)
	_contact = to_local(contact_world)
	_swing_from_hand = _hand
	_swing_from_dir = _rdir


## Refine where the strings meet the ball once the real contact point is known.
func update_contact(contact_world: Vector3) -> void:
	_contact = to_local(contact_world)


func split_step() -> void:
	_hop = 0.0


func _physics_process(delta: float) -> void:
	var target_v := Vector3(move_input.x, 0.0, move_input.y).limit_length(1.0) * max_speed
	var speeding_up := target_v.length() > velocity.length() and target_v.dot(velocity) >= 0.0
	var rate := accel if speeding_up else decel
	velocity += (target_v - velocity).limit_length(rate * delta)
	var p := position + velocity * delta
	var cx := clampf(p.x, area.position.x, area.end.x)
	var cz := clampf(p.z, area.position.y, area.end.y)
	if cx != p.x:
		velocity.x = 0.0
	if cz != p.z:
		velocity.z = 0.0
	position = Vector3(cx, 0.0, cz)

	# A hard stop from a sprint (or swinging on the run) turns into a slide.
	var speed := velocity.length()
	var decel := (_prev_speed - speed) / maxf(delta, 0.0001)
	if _slide < 0.2 and _prev_speed > 4.6 and (decel > 20.0 or (_mode == 2 and _prev_speed > 5.2)):
		_slide = 1.0
		var v_dir := velocity if speed > 0.5 else _last_vel
		_slide_dir = (global_basis.inverse() * v_dir).normalized()
		_slide_dir.y = 0.0
		if _dust:
			_dust.restart()
	if speed > 0.5:
		_last_vel = velocity
	_prev_speed = speed


# --- Stroke keyframes ------------------------------------------------------------

func _two_handed() -> bool:
	return _side < 0 and (_style == Style.TOPSPIN or _style == Style.FLAT)


## [hand position, racket direction] for a phase of the current stroke, in model space.
func _key(style: int, phase: String, side: int) -> Array:
	var c := _contact
	var hand: Vector3
	var dir: Vector3
	if style == Style.UNDERARM:
		# Underarm serve: racket low behind, brushed forward under the ball.
		match phase:
			"prep":
				hand = Vector3(0.42, 0.95, 0.35)
				dir = Vector3(0.3, -0.5, 0.8)
			"drop":
				hand = Vector3(0.4, 0.62, 0.12)
				dir = Vector3(0.45, -0.8, 0.3)
			"contact":
				dir = Vector3(0.35, -0.2, -0.9)
				hand = c - dir.normalized() * RACKET_REACH
			_:
				hand = Vector3(0.15, 1.25, -0.55)
				dir = Vector3(0.1, 0.8, -0.6)
		return [hand, dir.normalized()]
	if style == Style.SMASH or style == Style.SERVE:
		c.y -= _jump_height()  # the body is in the air at contact
		match phase:
			"prep":
				hand = Vector3(0.38, 1.55, 0.25)
				dir = Vector3(0.15, 0.75, 0.6)
			"drop":
				hand = Vector3(0.32, 1.85, 0.28)
				dir = Vector3(0.05, -0.9, 0.45)
			"contact":
				dir = Vector3(0.05, 1.0, -0.25)
				hand = c - dir.normalized() * RACKET_REACH
			_:
				hand = Vector3(-0.35, 0.85, -0.3)
				dir = Vector3(-0.35, -0.75, -0.45)
		return [hand, dir.normalized()]

	if side < 0 and style != Style.SLICE and style != Style.DROP:
		# Two-handed backhand.
		match phase:
			"prep":
				hand = Vector3(-0.42, 1.0, 0.4)
				dir = Vector3(-0.15, 0.45, 0.9)
			"drop":
				hand = Vector3(-0.4, maxf(c.y - 0.35, 0.45), 0.1)
				dir = Vector3(-0.5, -0.5, 0.6)
			"contact":
				dir = Vector3(-1.0, -0.03, -0.3)
				hand = c - dir.normalized() * RACKET_REACH
			_:
				if style == Style.FLAT:
					hand = Vector3(0.4, 1.2, -0.35)
					dir = Vector3(0.6, 0.15, 0.65)
				else:
					hand = Vector3(0.32, 1.55, -0.1)
					dir = Vector3(0.35, 0.4, 0.85)
		return [hand, dir.normalized()]

	var s := float(side)
	match style:
		Style.SLICE, Style.DROP:
			# One-handed slice on both wings: high to low, face open.
			match phase:
				"prep":
					hand = Vector3(0.4 * s, 1.45, 0.35)
					dir = Vector3(0.2 * s, 0.85, 0.45)
				"drop":
					hand = Vector3(0.4 * s, maxf(c.y + 0.2, 0.9), 0.12)
					dir = Vector3(0.75 * s, 0.35, 0.3)
				"contact":
					dir = Vector3(1.0 * s, 0.18, -0.25)
					hand = c - dir.normalized() * RACKET_REACH
				_:
					if style == Style.DROP:
						# Soft hands: the racket stops short, face still open under the ball.
						hand = Vector3(0.3 * s, 0.95, -0.5)
						dir = Vector3(0.7 * s, 0.45, -0.55)
					else:
						hand = Vector3(0.05 * s, 0.85, -0.68)
						dir = Vector3(0.35 * s, 0.0, -1.0)
		Style.FLAT:
			match phase:
				"prep":
					hand = Vector3(0.5 * s, 1.15, 0.45)
					dir = Vector3(0.25 * s, 0.35, 0.9)
				"drop":
					hand = Vector3(0.48 * s, c.y, 0.15)
					dir = Vector3(0.6 * s, 0.05, 0.7)
				"contact":
					dir = Vector3(1.0 * s, 0.03, -0.25)
					hand = c - dir.normalized() * RACKET_REACH
				_:
					hand = Vector3(-0.42 * s, 1.15, -0.4)
					dir = Vector3(-0.65 * s, 0.15, 0.6)
		_:  # forehand topspin
			match phase:
				"prep":
					hand = Vector3(0.5 * s, 1.05, 0.45)
					dir = Vector3(0.2 * s, 0.35, 0.95)
				"drop":
					hand = Vector3(0.45 * s, maxf(c.y - 0.4, 0.45), 0.12)
					dir = Vector3(0.55 * s, -0.55, 0.55)
				"contact":
					dir = Vector3(1.0 * s, -0.05, -0.25)
					hand = c - dir.normalized() * RACKET_REACH
				_:
					hand = Vector3(-0.32 * s, 1.6, -0.15)
					dir = Vector3(-0.3 * s, 0.35, 0.9)
	return [hand, dir.normalized()]


func _process(delta: float) -> void:
	if _model == null:
		return
	var speed := velocity.length()
	var k := 1.0 - exp(-12.0 * delta)

	# --- Racket path, torso turn ---
	var near_contact := 0.0  # 1 at the contact instant: steer the racket head onto the ball
	if _mode == 2:
		_clock += delta
		var start := _contact_at - SWING_TO_CONTACT
		var prep: Array = _key(_style, "prep", _side)
		var drop: Array = _key(_style, "drop", _side)
		var con: Array = _key(_style, "contact", _side)
		var fol: Array = _key(_style, "follow", _side)
		if _clock < start:
			_hand = _hand.lerp(prep[0], k)
			_rdir = _rdir.lerp(prep[1], k).normalized()
			_twist = lerpf(_twist, -0.8 * _side, k)
		elif _clock < _contact_at:
			var u := clampf((_clock - start) / SWING_TO_CONTACT, 0.0, 1.0)
			var from_h: Vector3 = prep[0] if start > 0.0 else _swing_from_hand
			var from_d: Vector3 = prep[1] if start > 0.0 else _swing_from_dir
			var e := u * u * (3.0 - 2.0 * u)
			if e < 0.5:
				var w := e * 2.0
				_hand = from_h.cubic_interpolate(drop[0], from_h, con[0], w)
				_rdir = from_d.lerp(drop[1], w).normalized()
			else:
				var w := (e - 0.5) * 2.0
				_hand = (drop[0] as Vector3).cubic_interpolate(con[0], from_h, fol[0], w)
				_rdir = (drop[1] as Vector3).lerp(con[1], w).normalized()
			_twist = lerpf(-0.8 * _side, 0.0, e)
		else:
			var u := clampf((_clock - _contact_at) / FOLLOW_TIME, 0.0, 1.0)
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			_hand = (con[0] as Vector3).cubic_interpolate(fol[0], drop[0], fol[0], e)
			_rdir = (con[1] as Vector3).lerp(fol[1], e).normalized()
			_twist = lerpf(0.0, 0.75 * _side, e)
			if u >= 1.0:
				_mode = 0
		near_contact = clampf(1.0 - absf(_clock - _contact_at) / 0.07, 0.0, 1.0)
	else:
		var target: Array
		var t_twist := 0.0
		match _mode:
			1:
				target = _key(_style, "prep", _side)
				t_twist = -0.8 * _side
			3:
				target = _key(Style.SERVE, "prep", 1)
				t_twist = -0.9
			_:
				target = [Vector3(0.12, 1.02, -0.36), Vector3(-0.35, 0.5, -0.75).normalized()]
		var kk := 1.0 - exp(-9.0 * delta)
		_hand = _hand.lerp(target[0], kk)
		_rdir = _rdir.lerp(target[1], kk).normalized()
		_twist = lerpf(_twist, t_twist, kk)

	# --- Left hand ---
	var lh := _hand + _rdir * 0.2 + Vector3(-0.05, 0.0, 0.0)  # on the throat
	var swinging_before := _mode == 2 and _clock < _contact_at
	if _mode == 4:
		lh = Vector3(0.05, 1.05, -0.38)                      # holding the ball in front
	elif _mode == 3 or (swinging_before and (_style == Style.SERVE or _style == Style.SMASH)):
		lh = Vector3(0.0, 1.95, -0.42)                       # tossing / pointing up at the ball
	elif _two_handed() and (_mode == 1 or _mode == 2):
		lh = _hand + _rdir * 0.11                            # both hands on the grip
	elif _side > 0 and (_mode == 1 or swinging_before):
		lh = Vector3(0.28, 1.3, -0.5)                        # pointing at the ball (forehand)
	elif _mode == 2 and (_style == Style.SLICE or _style == Style.DROP) and _side < 0:
		lh = Vector3(-0.55, 1.2, 0.35)                       # one-hander: arm back for balance
	elif _mode == 2:
		lh = Vector3(-0.3, 1.05, 0.05)                       # tucked in on the follow-through
	if _mode == 0 and speed > 1.5:
		var pump := sin(_run_phase) * clampf(speed / 5.0, 0.0, 1.0)
		lh = Vector3(-0.25, 1.05 + 0.08 * pump, -0.1 - 0.28 * pump)
		_hand += Vector3(0.0, 0.0, 0.12 * pump) * k
	_lhand = _lhand.lerp(lh, k) if not (_two_handed() and _mode == 2) else lh

	# --- Body: crouch, hop, lean ---
	_run_phase += delta * (5.0 + speed * 2.2)
	var amt := clampf(speed / 4.0, 0.0, 1.0)
	var target_crouch := 0.06 + (0.08 if _mode == 1 or _mode == 2 else 0.0) - amt * 0.03
	var target_lean := 0.0
	if _mode == 2:
		target_crouch += clampf((0.65 - _contact.y) * 0.5, 0.0, 0.18)   # get down to low balls
		target_lean = -signf(_contact.x) * clampf((absf(_contact.x) - 0.95) * 0.45, 0.0, 0.25)
	elif _mode == 3:
		target_crouch = 0.04
	if _slide > 0.0:
		_slide = maxf(0.0, _slide - delta / 0.5)
		var sl := _slide * _slide * (3.0 - 2.0 * _slide)
		target_crouch += 0.24 * sl
		target_lean += -_slide_dir.x * 0.22 * sl
		if _dust:
			_dust.emitting = _slide > 0.7
	_crouch = lerpf(_crouch, target_crouch, k)
	_lean = lerpf(_lean, target_lean, k)
	var lift := 0.0
	if _hop < 1.0:
		_hop = minf(1.0, _hop + delta / 0.28)
		lift = sin(_hop * PI) * 0.13
	# Serve / smash: spring up to meet a high ball.
	var air := 0.0
	if _mode == 2 and (_style == Style.SERVE or _style == Style.SMASH):
		air = _jump_height() * clampf(1.0 - absf(_clock - _contact_at) / 0.28, 0.0, 1.0)
	_model.position.y = lift + air + absf(sin(_run_phase)) * 0.04 * amt

	var local_v := global_basis.inverse() * velocity
	_model.rotation.x = lerpf(_model.rotation.x, -local_v.z * 0.04, k)
	_model.rotation.z = lerpf(_model.rotation.z, -local_v.x * 0.025 + _lean, k)

	# --- Head tracks the ball ---
	var yaw_t := 0.0
	var pitch_t := 0.0
	if look_target != Vector3.INF:
		var lt := to_local(look_target) - Vector3(0, SHOULDER_H + 0.3, 0)
		yaw_t = clampf(atan2(-lt.x, -lt.z), -1.4, 1.4)
		pitch_t = clampf(atan2(lt.y, Vector2(lt.x, lt.z).length()), -0.6, 0.7)
	_head_yaw = lerpf(_head_yaw, yaw_t, 1.0 - exp(-8.0 * delta))
	_head_pitch = lerpf(_head_pitch, pitch_t, 1.0 - exp(-8.0 * delta))

	_pose(local_v, amt, near_contact)


func _pose(local_v: Vector3, amt: float, near_contact: float) -> void:
	var hip_y := HIP_H - _crouch
	var tw := Basis(Vector3.UP, _twist)
	var pelvis := Vector3(0, hip_y, 0)
	var chest := Vector3(0, SHOULDER_H - _crouch * 0.6, 0)
	var r_sh := chest + tw * Vector3(SHOULDER_W, 0, 0)
	var l_sh := chest + tw * Vector3(-SHOULDER_W, 0, 0)

	# Legs: feet step along the running direction; on a swing the foot on the ball's
	# side steps out toward it (a lunge), knees bend forward.
	var stride := Vector3(local_v.x, 0, local_v.z).normalized() * 0.4 * amt if amt > 0.05 else Vector3.ZERO
	var sl := _slide * _slide * (3.0 - 2.0 * _slide)
	var lead := 1.0 if _slide_dir.x >= 0.0 else -1.0  # the foot on the slide's side leads
	var lunge := 0.0
	if _mode == 2:
		lunge = clampf(1.0 - absf(_clock - _contact_at) / 0.35, 0.0, 1.0)
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var phase := _run_phase + (0.0 if i == 0 else PI)
		var hip := pelvis + Vector3(0.11 * sgn, 0, 0)
		var foot := Vector3(0.17 * sgn, 0.05, 0.0) + stride * sin(phase)
		foot.y += maxf(0.0, cos(phase)) * 0.18 * amt
		if sl > 0.0:
			# Slide: lead leg reaches out along the slide, trailing leg bent behind.
			var slide_foot := Vector3(0.17 * sgn, 0.04, 0.0) + (_slide_dir * 0.6 if sgn == lead else -_slide_dir * 0.15 + Vector3(0, 0, 0.15))
			foot = foot.lerp(slide_foot, sl)
			if sgn == lead and _dust:
				_dust.position = foot
		if sgn * signf(_contact.x) > 0.0:
			foot += Vector3(signf(_contact.x) * 0.18, 0.0, -0.22) * lunge
		var knee := _ik(hip, foot, THIGH, SHIN, hip + Vector3(0, 0, -1.0))
		var ankle := _reach(knee, foot, SHIN)
		_set_bone("thigh%d" % i, hip, knee)
		_set_bone("shin%d" % i, knee, ankle)
		_set_bone("shoe%d" % i, ankle + Vector3(0, -0.03, 0.05), ankle + Vector3(0, -0.03, -0.14))

	# Torso: hips, waist, chest, shoulders, neck.
	_set_bone("hips", pelvis + Vector3(-0.1, 0.02, 0), pelvis + Vector3(0.1, 0.02, 0))
	_set_bone("waist", pelvis + Vector3(0, 0.08, 0), chest.lerp(pelvis, 0.45))
	_set_bone("chest", chest.lerp(pelvis, 0.5), chest + Vector3(0, -0.04, 0))
	_set_bone("shoulders", l_sh, r_sh)
	_set_bone("neck", chest, chest + Vector3(0, 0.16, 0))
	_head.position = chest + Vector3(0, 0.3, 0)
	_head.rotation = Vector3(_head_pitch, _head_yaw, 0.0)

	# Racket arm, with the racket head steered onto the ball at the contact instant.
	var elbow := _ik(r_sh, _hand, UPPER_ARM, FOREARM, r_sh + Vector3(0.4 * _side, -0.9, 0.35))
	var hand := _reach(elbow, _hand, FOREARM)
	var rdir := _rdir
	if near_contact > 0.0:
		var to_ball := _contact - hand
		if to_ball.length() > 0.05:
			rdir = rdir.lerp(to_ball.normalized(), near_contact).normalized()
	_set_bone("upper_r", r_sh, elbow)
	_set_bone("fore_r", elbow, hand)
	_hand_r.position = hand
	var l_elbow := _ik(l_sh, _lhand, UPPER_ARM, FOREARM, l_sh + Vector3(-0.4, -0.9, 0.25))
	var lhand := _reach(l_elbow, _lhand, FOREARM)
	_set_bone("upper_l", l_sh, l_elbow)
	_set_bone("fore_l", l_elbow, lhand)
	_hand_l.position = lhand
	_lhand_actual = lhand

	# Racket: handle along the racket direction, face turned toward the shot (open for slice).
	var y := rdir
	var face := Vector3(0, 0.45, -1) if _style == Style.SLICE or _style == Style.DROP or _style == Style.UNDERARM else Vector3(0, 0, -1)
	face = face - y * face.dot(y)
	if face.length() < 0.05:
		face = Vector3(0, 1, 0) - y * y.y
	face = face.normalized()
	var x := y.cross(face).normalized()
	_racket.transform = Transform3D(Basis(x, y, x.cross(y)), hand)


func _jump_height() -> float:
	return clampf(_contact.y - 2.4, 0.0, 0.5)


## Two-bone IK: the middle joint of a chain root -> joint -> end reaching for target.
func _ik(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d := target - root
	var dist := clampf(d.length(), 0.02, l1 + l2 - 0.002)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var c := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var perp := pole - root
	perp -= dir * perp.dot(dir)
	if perp.length() < 0.0001:
		perp = Vector3.FORWARD - dir * dir.dot(Vector3.FORWARD)
	perp = perp.normalized()
	return root + dir * (l1 * c) + perp * (l1 * sqrt(1.0 - c * c))


## End of a limb: toward the target from the joint, at the limb's length.
func _reach(joint: Vector3, target: Vector3, l2: float) -> Vector3:
	var d := target - joint
	return joint + d.normalized() * l2 if d.length() > 0.0001 else joint + Vector3.DOWN * l2


func _set_bone(bone: String, a: Vector3, b: Vector3) -> void:
	var mi: MeshInstance3D = _bones[bone]
	var d := b - a
	var len := d.length()
	if len < 0.0001:
		return
	var y := d / len
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	# Limb lengths are fixed by the IK; only rebuild a mesh when its length really changes.
	var cm := mi.mesh as CapsuleMesh
	var h := len + cm.radius * 2.0
	if absf(cm.height - h) > 0.015:
		cm.height = h


# --- Build ----------------------------------------------------------------------

func _build(shirt: Color) -> void:
	_model = Node3D.new()
	add_child(_model)
	var skin := Color(0.93, 0.76, 0.62)
	var shorts := Color(0.14, 0.15, 0.2)
	var white := Color(0.96, 0.96, 0.96)
	var hair := Color(0.25, 0.17, 0.1)

	var sh := _mesh_cyl(0.38, 0.002, Color(0, 0, 0, 0.35), true)
	sh.position.y = 0.04
	add_child(sh)

	# Dust kicked up by slides
	_dust = CPUParticles3D.new()
	_dust.emitting = false
	_dust.amount = 6
	_dust.lifetime = 0.3
	_dust.explosiveness = 0.3
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 70.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.2
	_dust.gravity = Vector3(0, -1.5, 0)
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 0.8
	var dm := SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	dm.radial_segments = 6
	dm.rings = 3
	_dust.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.85, 0.85, 0.9, 0.22)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust.material_override = dmat
	_model.add_child(_dust)

	for i in 2:
		_bone_mesh("thigh%d" % i, 0.075, skin)
		_bone_mesh("shin%d" % i, 0.058, white)
		_bone_mesh("shoe%d" % i, 0.055, white.darkened(0.12))
	_bone_mesh("hips", 0.13, shorts)
	_bone_mesh("waist", 0.15, shirt)
	_bone_mesh("chest", 0.18, shirt)
	_bone_mesh("shoulders", 0.085, shirt)
	_bone_mesh("neck", 0.05, skin)
	_bone_mesh("upper_r", 0.055, shirt.lightened(0.08))
	_bone_mesh("fore_r", 0.042, skin)
	_bone_mesh("upper_l", 0.055, shirt.lightened(0.08))
	_bone_mesh("fore_l", 0.042, skin)
	_hand_r = _sphere(0.05, skin)
	_hand_l = _sphere(0.05, skin)
	_model.add_child(_hand_r)
	_model.add_child(_hand_l)

	# Head: face looks along -Z; cap with a visor, hair at the back, eyes.
	_head = Node3D.new()
	_model.add_child(_head)
	var skull := _sphere(0.12, skin)
	skull.scale = Vector3(0.95, 1.05, 1.0)
	_head.add_child(skull)
	var back_hair := _sphere(0.115, hair)
	back_hair.position = Vector3(0, -0.01, 0.03)
	_head.add_child(back_hair)
	var cap := _mesh_cyl(0.122, 0.07, shirt.darkened(0.35))
	cap.position = Vector3(0, 0.085, 0)
	_head.add_child(cap)
	var visor := _mesh_cyl(0.09, 0.012, shirt.darkened(0.35))
	visor.position = Vector3(0, 0.06, -0.12)
	visor.scale = Vector3(1.0, 1.0, 0.8)
	_head.add_child(visor)
	for ex in [-0.04, 0.04]:
		var eye := _sphere(0.016, Color(0.08, 0.08, 0.1))
		eye.position = Vector3(ex, 0.015, -0.112)
		_head.add_child(eye)
	var nose := _sphere(0.02, skin.darkened(0.08))
	nose.position = Vector3(0, -0.02, -0.122)
	_head.add_child(nose)

	# Racket: local +Y runs from the hand to the head; the face lies in the XY plane.
	_racket = Node3D.new()
	_model.add_child(_racket)
	var handle := _mesh_capsule(0.016, 0.3, Color(0.1, 0.1, 0.1))
	handle.position = Vector3(0, 0.13, 0)
	_racket.add_child(handle)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.105
	tm.outer_radius = 0.128
	tm.rings = 20
	tm.ring_segments = 6
	ring.mesh = tm
	_racket_mat = _mat(Color(0.15, 0.15, 0.2))
	ring.material_override = _racket_mat
	ring.basis = Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 1.3))
	ring.position = Vector3(0, RACKET_REACH - 0.02, 0)
	_racket.add_child(ring)
	_racket_light = OmniLight3D.new()
	_racket_light.position = ring.position
	_racket_light.omni_range = 1.2
	_racket_light.shadow_enabled = false
	_racket_light.visible = false
	_racket.add_child(_racket_light)
	var strings := _mesh_cyl(0.105, 0.004, Color(0.95, 0.95, 0.9, 0.45), true)
	strings.basis = ring.basis
	strings.position = ring.position
	_racket.add_child(strings)


## Racket frame colour by rarity; epic and legendary rackets glow (see Gear).
func set_racket_look(c: Color, glow: float) -> void:
	_racket_mat.albedo_color = c
	_racket_mat.emission_enabled = glow > 0.0
	_racket_mat.emission = c
	_racket_mat.emission_energy_multiplier = glow
	_racket_light.visible = glow > 1.0
	_racket_light.light_color = c
	_racket_light.light_energy = glow * 0.8


func _bone_mesh(bone: String, r: float, c: Color) -> void:
	var mi := _mesh_capsule(r, 0.3, c)
	_model.add_child(mi)
	_bones[bone] = mi


func _sphere(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(c)
	return mi


func _mat(c: Color, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh_capsule(r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0 + 0.01)
	cm.radial_segments = 10
	cm.rings = 3
	mi.mesh = cm
	mi.material_override = _mat(c)
	return mi


func _mesh_cyl(r: float, h: float, c: Color, transparent := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = _mat(c, transparent)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
