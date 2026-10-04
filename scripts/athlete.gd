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
# Diving for a ball out of reach: launch sideways, hit it in the air, land on the court,
# lie there a moment and get back up (no running or hitting meanwhile).
const DIVE_REACH := 0.9         # extra reach of a dive
const DIVE_SPEED := 4.6         # sideways launch speed (m/s)
const DIVE_TIME := 0.3          # in the air
const GROUND_TIME := 0.55       # lying on the court
const GETUP_TIME := 0.6         # getting back up
const STUMBLE_TIME := 0.5       # knocked off balance by a heavy ball
const KO_FLY := 0.42            # knocked out by a ball (trophy mini-game): flying back
const KO_LIE := 3.0             # ... and lying on the court
const FOLLOW_TIME := 0.34

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
var _hip_twist := 0.0          # hips turn less than the shoulders (and lead the forward swing)
var _prep_t := 0.0             # seconds into the current unit turn
var _attach := 0.0             # left hand: 0 free, 1 on the racket throat, 2 on the grip (two-hander)
var _stance := 0.0             # 0 neutral feet, 1 the current stroke's stance
var _follow := 0.0             # 0..1 through the follow-through (heel lift, landing)
var _down := -1.0              # seconds into a dive or stumble, -1 = on the feet
var _down_kind := 0            # 1 dive, 2 stumble
var _down_dir := 1.0           # +1 toward the body's right, -1 toward the left
var _down_back := false        # tips over backwards instead of sideways (knockout from the front)
var _prev_pos := Vector3.ZERO  # position at the previous physics tick, for smooth rendering

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


## Dive toward a ball out of reach (contact point in world space).
func dive(contact_world: Vector3) -> void:
	if _down >= 0.0:
		return
	_down = 0.0
	_down_kind = 1
	_down_dir = 1.0 if lateral_of(contact_world) >= 0.0 else -1.0
	var flat := contact_world - global_position
	flat.y = 0.0
	velocity = flat.normalized() * DIVE_SPEED if flat.length() > 0.01 else right() * _down_dir * DIVE_SPEED


## Hit by a ball (the trophy mini-game): thrown back off the feet, stays down.
func knockout(push_world: Vector3) -> void:
	_down = 0.0
	_down_kind = 3
	var flat := Vector3(push_world.x, 0.0, push_world.z)
	var lat := flat.normalized().dot(right()) if flat.length() > 0.01 else 0.0
	_down_back = absf(lat) < 0.6
	_down_dir = 1.0 if lat >= 0.0 else -1.0
	velocity = flat.normalized() * 5.5 if flat.length() > 0.01 else -forward() * 5.5


## Slipping on grass: the feet go and the player falls, keeping their momentum.
func _slip() -> void:
	_down = 0.0
	_down_kind = 1
	var lat := velocity.normalized().dot(right()) if velocity.length() > 0.1 else 1.0
	_down_dir = 1.0 if lat >= 0.0 else -1.0
	_slide = 0.0


## Sliding right now (clay keeps the marks).
func is_sliding() -> bool:
	return _slide > 0.35 and velocity.length() > 1.0


## True once when a dive or slip lands on the court.
func take_landing() -> bool:
	var l := _landed
	_landed = false
	return l


## A heavy ball knocks the player off balance for a moment.
func stumble(dir: float) -> void:
	if _down >= 0.0:
		return
	_down = 0.0
	_down_kind = 2
	_down_dir = dir


## Diving, lying on the court, getting up or stumbling: no running, no hitting.
func is_down() -> bool:
	return _down >= 0.0


func is_diving() -> bool:
	return _down_kind == 1 and _down >= 0.0 and _down < DIVE_TIME


## Back on the feet at once (a new point starts).
func recover() -> void:
	_down = -1.0
	_down_kind = 0


func _down_total() -> float:
	match _down_kind:
		1:
			return DIVE_TIME + GROUND_TIME + GETUP_TIME
		3:
			return KO_FLY + KO_LIE
	return STUMBLE_TIME


## How far the body is tipped over (rad) and lifted, for the current dive/stumble.
func _down_pose() -> Vector2:
	if _down < 0.0:
		return Vector2.ZERO
	if _down_kind == 2:
		var u := _down / STUMBLE_TIME
		return Vector2(sin(u * PI) * 0.32, 0.0)
	if _down_kind == 3:
		var u := clampf(_down / KO_FLY, 0.0, 1.0)
		return Vector2(1.5 * (1.0 - (1.0 - u) * (1.0 - u)), sin(u * PI) * 0.4)
	if _down < DIVE_TIME:
		var u := _down / DIVE_TIME
		return Vector2(1.3 * (1.0 - (1.0 - u) * (1.0 - u)), sin(u * PI) * 0.18)
	if _down < DIVE_TIME + GROUND_TIME:
		return Vector2(1.3, 0.0)
	var g := (_down - DIVE_TIME - GROUND_TIME) / GETUP_TIME
	return Vector2(1.3 * (1.0 - g * g * (3.0 - 2.0 * g)), 0.0)


func _physics_process(delta: float) -> void:
	_prev_pos = position
	if _down >= 0.0:
		# Flying through the dive, then sliding to a stop on the court.
		if _down_kind == 1 and _down < DIVE_TIME and _down + delta >= DIVE_TIME:
			_landed = true
		_down += delta
		if (_down_kind == 1 and _down > DIVE_TIME) or _down_kind == 2 or (_down_kind == 3 and _down > KO_FLY):
			velocity = velocity.move_toward(Vector3.ZERO, decel * 1.5 * delta)
		if _down >= _down_total():
			_down = -1.0
			_down_kind = 0
	else:
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
	var slide_from := 3.8 if surface == "clay" else 4.6
	if _down < 0.0 and _slide < 0.2 and _prev_speed > slide_from and (decel > 20.0 or (_mode == 2 and _prev_speed > slide_from + 0.6)):
		_slide = 1.0
		if surface == "grass" and _prev_speed > 5.4 and _slip_rng.randf() < GRASS_SLIP_CHANCE:
			_slip()
		var v_dir := velocity if speed > 0.5 else _last_vel
		_slide_dir = (global_basis.inverse() * v_dir).normalized()
		_slide_dir.y = 0.0
		if _dust:
			_dust.restart()
	if speed > 0.5:
		_last_vel = velocity
	_prev_speed = speed


# --- Stroke keyframes ------------------------------------------------------------
# Technique reference (right-hander), phase by phase:
#  forehand (open / semi-open stance): unit turn — shoulders ~70°, hips about half, the
#    left hand guides the racket back on the throat, then points across at the ball;
#    racket loops up and drops below the ball; hips fire first, shoulders follow; contact
#    in front of the right hip with the arm long; the left arm folds into the chest and
#    catches the racket by the throat over the left shoulder; right heel comes up and
#    the right foot pivots forward.
#  two-handed backhand (neutral stance): shoulders turn past the hips with the right
#    shoulder under the chin, both hands on the grip (left above right), right foot
#    steps in toward the ball; low-to-high swing, contact in front of the right hip,
#    finish with both hands over the right shoulder, chest to the net.
#  serve: sideways, front (left) foot at the baseline and the back foot behind it; ball
#    bounced with the left hand; knees bend while the tossing arm goes up (trophy
#    position); legs drive up into the ball, landing on the front foot.

const UNIT_TURN := 1.2          # shoulder turn at the end of the takeback (rad)
const HIP_RATIO := 0.55         # hips turn about half as far as the shoulders
const FINISH_TURN := 0.85       # chest past square toward the other side at the finish
const SERVE_TURN := 1.05        # sideways serve stance (left shoulder to the net)
const BH_TURN := 1.55           # backhands turn further: the back half-faces the net

## One-handed backhand (Wawrinka) instead of the two-hander. Set by Main from the settings.
var one_handed_backhand := false

## Court surface (set by Main): on clay players slide into the ball easily and far; on
## grass a hard stop can end on the floor.
static var surface := "hard"
const GRASS_SLIP_CHANCE := 0.1   # only on a hard stop from a full sprint
var _slip_rng := RandomNumberGenerator.new()
var _landed := false            # just hit the court (a mark for clay), see take_landing()

## Bounce of the ball before the serve, 0..1 per bounce (-1 = not dribbling). Set by Main.
var dribble := -1.0


func _two_handed() -> bool:
	return _side < 0 and (_style == Style.TOPSPIN or _style == Style.FLAT) and not one_handed_backhand


func _one_handed() -> bool:
	return _side < 0 and (_style == Style.TOPSPIN or _style == Style.FLAT) and one_handed_backhand


## How far the shoulders turn back in the takeback for the current stroke.
func _turn_amount() -> float:
	if _serve_style():
		return SERVE_TURN
	return BH_TURN if _side < 0 else UNIT_TURN


func _serve_style() -> bool:
	return _style == Style.SERVE or _style == Style.SMASH


## [hand position, racket direction] for a phase of the current stroke, in model space.
func _key(style: int, phase: String, side: int) -> Array:
	var c := _contact_model()
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
				# Trophy position: racket arm up and back, elbow at shoulder height.
				hand = Vector3(0.36, 1.62, 0.22)
				dir = Vector3(0.1, 0.8, 0.55)
			"drop":
				# Racket drop behind the back.
				hand = Vector3(0.3, 1.82, 0.22)
				dir = Vector3(0.05, -0.92, 0.38)
			"contact":
				dir = Vector3(0.05, 1.0, -0.25)
				hand = c - dir.normalized() * RACKET_REACH
			_:
				# Finish across the body, down by the left hip.
				hand = Vector3(-0.38, 0.88, -0.3)
				dir = Vector3(-0.35, -0.75, -0.45)
		return [hand, dir.normalized()]

	if side < 0 and style != Style.SLICE and style != Style.DROP and one_handed_backhand:
		# One-handed backhand (Wawrinka): high takeback with the left hand on the throat,
		# racket head up behind; long low-to-high swing; arm up high toward the target.
		match phase:
			"prep":
				hand = Vector3(-0.2, 1.3, 0.34)
				dir = Vector3(0.3, 0.7, 0.65)
			"drop":
				hand = Vector3(-0.4, maxf(c.y - 0.32, 0.5), 0.14)
				dir = Vector3(-0.3, -0.7, 0.62)
			"contact":
				dir = Vector3(-1.0, -0.02, -0.25)
				hand = c - dir.normalized() * RACKET_REACH
			_:
				if style == Style.FLAT:
					hand = Vector3(0.05, 1.45, -0.6)
					dir = Vector3(-0.3, 0.55, -0.78)
				else:
					hand = Vector3(0.08, 1.82, -0.38)
					dir = Vector3(0.2, 0.78, 0.6)
		return [hand, dir.normalized()]

	if side < 0 and style != Style.SLICE and style != Style.DROP:
		# Two-handed backhand.
		match phase:
			"prep":
				# Hands low by the left hip with the elbow tucked back, racket behind the
				# back: the wrist lays back more than the elbow bends.
				hand = Vector3(-0.22, 1.02, 0.4)
				dir = Vector3(0.3, 0.6, 0.74)
			"drop":
				hand = Vector3(-0.36, maxf(c.y - 0.32, 0.5), 0.12)
				dir = Vector3(-0.45, -0.55, 0.6)
			"contact":
				dir = Vector3(-1.0, -0.03, -0.28)
				hand = c - dir.normalized() * RACKET_REACH
			_:
				if style == Style.FLAT:
					hand = Vector3(0.36, 1.25, -0.38)
					dir = Vector3(0.6, 0.2, 0.65)
				else:
					# Both hands over the right shoulder, racket behind the head.
					hand = Vector3(0.3, 1.5, -0.22)
					dir = Vector3(0.3, 0.45, 0.85)
		return [hand, dir.normalized()]

	var s := float(side)
	match style:
		Style.SLICE, Style.DROP:
			# One-handed slice on both wings: high to low, face open.
			match phase:
				"prep":
					hand = Vector3(0.4 * s, 1.42, 0.3)
					dir = Vector3(0.2 * s, 0.85, 0.45)
				"drop":
					hand = Vector3(0.42 * s, maxf(c.y + 0.2, 0.9), 0.1)
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
						hand = Vector3(0.1 * s, 0.9, -0.66)
						dir = Vector3(0.35 * s, 0.0, -1.0)
		Style.FLAT:
			match phase:
				"prep":
					hand = Vector3(0.45 * s, 1.15, 0.32)
					dir = Vector3(0.2 * s, 0.6, 0.78)
				"drop":
					hand = Vector3(0.48 * s, c.y - 0.05, 0.15)
					dir = Vector3(0.6 * s, -0.1, 0.7)
				"contact":
					dir = Vector3(1.0 * s, 0.03, -0.25)
					hand = c - dir.normalized() * RACKET_REACH
				_:
					hand = Vector3(-0.38 * s, 1.22, -0.36)
					dir = Vector3(-0.6 * s, 0.25, 0.65)
		_:  # forehand topspin
			match phase:
				"prep":
					# End of the takeback: elbow bent, racket head up and back ("the loop").
					hand = Vector3(0.42 * s, 1.12, 0.32)
					dir = Vector3(0.15 * s, 0.75, 0.6)
				"drop":
					# Racket head drops below the ball, hand by the right hip.
					hand = Vector3(0.48 * s, maxf(c.y - 0.38, 0.48), 0.16)
					dir = Vector3(0.4 * s, -0.72, 0.52)
				"contact":
					dir = Vector3(1.0 * s, -0.05, -0.22)
					hand = c - dir.normalized() * RACKET_REACH
				_:
					# Windshield-wiper finish: hand by the left shoulder, racket behind it.
					hand = Vector3(-0.3 * s, 1.5, -0.24)
					dir = Vector3(-0.25 * s, 0.35, 0.9)
	return [hand, dir.normalized()]


## Just after contact the hand keeps going out toward the target (extension) before the
## racket wraps around; without this the hand would cut from the contact point straight
## to the shoulder, through the face. Returns [] for strokes without it.
func _extension(con: Array) -> Array:
	if _style == Style.SLICE or _style == Style.DROP or _style == Style.UNDERARM:
		return []
	var h: Vector3 = con[0]
	if _serve_style():
		return [Vector3(0.18, 1.45, -0.62), Vector3(0.05, -0.35, -0.94).normalized()]
	var s := float(_side)
	var ext := Vector3(lerpf(h.x, 0.18 * s, 0.45), maxf(h.y + 0.22, 1.05), minf(h.z, -0.3) - 0.32)
	return [ext, Vector3(0.35 * s, 0.62, -0.7).normalized()]


## The contact point in the model's space (the model is drawn slightly offset between
## physics ticks, see _process).
func _contact_model() -> Vector3:
	return _contact - (_model.position if _model else Vector3.ZERO)


func _process(delta: float) -> void:
	if _model == null:
		return
	# Draw the body between the last two physics ticks (smooth in slow motion); a jump
	# (placed for the serve) is not smoothed.
	var off := (_prev_pos - position) * (1.0 - Engine.get_physics_interpolation_fraction())
	_model.position = global_basis.inverse() * off if off.length() < 1.0 else Vector3.ZERO
	var speed := velocity.length()
	var k := 1.0 - exp(-12.0 * delta)
	_prep_t = _prep_t + delta if _mode == 1 else 0.0

	# --- Racket path, shoulder and hip turn ---
	var near_contact := 0.0  # 1 at the contact instant: steer the racket head onto the ball
	var swing_e := 0.0       # 0..1 through the forward swing
	var follow_e := 0.0      # 0..1 through the follow-through
	if _mode == 2:
		_clock += delta
		var start := _contact_at - SWING_TO_CONTACT
		var prep: Array = _key(_style, "prep", _side)
		var drop: Array = _key(_style, "drop", _side)
		var con: Array = _key(_style, "contact", _side)
		var fol: Array = _key(_style, "follow", _side)
		var turn := _turn_amount() * _side
		if _clock < start:
			_hand = _hand.lerp(prep[0], k)
			_rdir = _rdir.lerp(prep[1], k).normalized()
			_twist = lerpf(_twist, -turn, k)
			_hip_twist = lerpf(_hip_twist, -turn * HIP_RATIO, k)
		elif _clock < _contact_at:
			var u := clampf((_clock - start) / SWING_TO_CONTACT, 0.0, 1.0)
			var from_h: Vector3 = prep[0] if start > 0.0 else _swing_from_hand
			var from_d: Vector3 = prep[1] if start > 0.0 else _swing_from_dir
			var e := u * u * (3.0 - 2.0 * u)
			swing_e = e
			if e < 0.5:
				var w := e * 2.0
				_hand = from_h.cubic_interpolate(drop[0], from_h, con[0], w)
				_rdir = from_d.lerp(drop[1], w).normalized()
			else:
				var w := (e - 0.5) * 2.0
				_hand = (drop[0] as Vector3).cubic_interpolate(con[0], from_h, fol[0], w)
				_rdir = (drop[1] as Vector3).lerp(con[1], w).normalized()
			# Kinetic chain: the hips fire first, the shoulders follow.
			_twist = lerpf(-turn, 0.0, e)
			_hip_twist = lerpf(-turn * HIP_RATIO, turn * 0.15, clampf(e * 1.4, 0.0, 1.0))
		else:
			var u := clampf((_clock - _contact_at) / FOLLOW_TIME, 0.0, 1.0)
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			swing_e = 1.0
			follow_e = e
			var ext := _extension(con)
			if ext.is_empty():
				_hand = (con[0] as Vector3).cubic_interpolate(fol[0], drop[0], fol[0], e)
				_rdir = (con[1] as Vector3).lerp(fol[1], e).normalized()
			elif e < 0.35:
				var w := e / 0.35
				_hand = (con[0] as Vector3).cubic_interpolate(ext[0], drop[0], fol[0], w)
				_rdir = (con[1] as Vector3).slerp(ext[1], w).normalized()
			else:
				var w := (e - 0.35) / 0.65
				_hand = (ext[0] as Vector3).cubic_interpolate(fol[0], con[0], fol[0], w)
				_rdir = (ext[1] as Vector3).slerp(fol[1], w).normalized()
			# The one-hander keeps the chest sideways; everything else turns through.
			var fin := FINISH_TURN * (0.6 if _serve_style() else (0.2 if _one_handed() else 1.0))
			_twist = lerpf(0.0, fin * _side, e)
			_hip_twist = lerpf(turn * 0.15, fin * 0.7 * _side, e)
			if u >= 1.0:
				_mode = 0
		near_contact = clampf(1.0 - absf(_clock - _contact_at) / 0.07, 0.0, 1.0)
	else:
		var target: Array
		var t_twist := 0.0
		var t_hips := 0.0
		match _mode:
			1:
				target = _key(_style, "prep", _side)
				# The unit turn takes a moment: the racket goes back with the shoulders.
				var g := clampf(_prep_t / 0.3, 0.0, 1.0)
				t_twist = -_turn_amount() * _side * g
				t_hips = t_twist * HIP_RATIO
			3:
				target = _key(Style.SERVE, "prep", 1)
				t_twist = -SERVE_TURN
				t_hips = -SERVE_TURN * 0.9
			4:
				# Waiting to serve: sideways, racket resting in front, ball in the left hand.
				target = [Vector3(0.1, 1.0, -0.4), Vector3(-0.55, 0.45, -0.7).normalized()]
				t_twist = -SERVE_TURN
				t_hips = -SERVE_TURN * 0.9
			_:
				target = [Vector3(0.12, 1.02, -0.36), Vector3(-0.35, 0.5, -0.75).normalized()]
		var kk := 1.0 - exp(-9.0 * delta)
		_hand = _hand.lerp(target[0], kk)
		_rdir = _rdir.lerp(target[1], kk).normalized()
		_twist = lerpf(_twist, t_twist, kk)
		_hip_twist = lerpf(_hip_twist, t_hips, kk)

	# --- Left hand ---
	# _lhand is the free target; _attach blends it onto the racket throat (taking the
	# racket back, catching it at the finish); a two-hander holds the grip.
	var lh := Vector3(-0.22, 1.05, -0.2)
	var attach := 0.0
	var swinging_before := _mode == 2 and _clock < _contact_at
	if _mode == 4:
		lh = Vector3(-0.05, 1.05, -0.42)                     # holding the ball in front
		if dribble >= 0.0:
			# Push the ball down, follow it a little, catch it back.
			var push := sin(clampf(dribble / 0.5, 0.0, 1.0) * PI)
			lh += Vector3(0.0, -0.16 * push, -0.04 * push)
	elif _mode == 3 or (swinging_before and _serve_style()):
		lh = Vector3(-0.02, 1.98, -0.4)                      # tossing arm up, pointing at the ball
	elif _two_handed() and (_mode == 1 or _mode == 2):
		attach = 2.0                                         # both hands on the grip
	elif _one_handed() and (_mode == 1 or _mode == 2):
		# Left hand on the throat in the takeback, then it lets go and flies back, arms
		# opening like wings while the chest stays sideways.
		attach = 1.0 if _mode == 1 or (_mode == 2 and swing_e < 0.3) else 0.0
		lh = Vector3(-0.62, 1.22, 0.36)
	elif _style == Style.SLICE or _style == Style.DROP:
		if _side < 0:
			# One-handed slice: the left hand takes the racket back, then the arm opens behind.
			attach = 1.0 if _mode == 1 or (_mode == 2 and swing_e < 0.25) else 0.0
			lh = Vector3(-0.55, 1.18, 0.3)
		else:
			attach = 1.0 if _mode == 1 and _prep_t < 0.18 else 0.0
			lh = Vector3(0.28, 1.25, -0.48) if swinging_before or _mode == 1 else Vector3(-0.22, 1.1, -0.28)
	elif _side > 0 and (_mode == 1 or _mode == 2):
		# Forehand: throat -> pointing across at the ball -> folding into the chest -> catch.
		var point := Vector3(0.3, 1.32, -0.44)
		var tuck := Vector3(-0.2, 1.14, -0.3)
		if _mode == 1:
			attach = 1.0 if _prep_t < 0.18 else 0.0
			lh = point
		elif swinging_before:
			lh = point.lerp(tuck, clampf(swing_e * 1.3, 0.0, 1.0))
		else:
			lh = tuck
			attach = clampf((follow_e - 0.45) / 0.4, 0.0, 1.0)
	if _mode == 0 and speed > 1.5:
		var pump := sin(_run_phase) * clampf(speed / 5.0, 0.0, 1.0)
		lh = Vector3(-0.25, 1.05 + 0.08 * pump, -0.1 - 0.28 * pump)
		_hand += Vector3(0.0, 0.0, 0.12 * pump) * k
	_lhand = _lhand.lerp(lh, k)
	if attach >= 2.0:
		_attach = 2.0
	else:
		_attach = lerpf(minf(_attach, 1.0), attach, 1.0 - exp(-14.0 * delta))

	# --- Body: crouch, hop, lean, stance ---
	_run_phase += delta * (5.0 + speed * 2.2)
	var amt := clampf(speed / 4.0, 0.0, 1.0)
	var target_crouch := 0.06 - amt * 0.03
	var target_lean := 0.0
	var stance_t := 0.0
	match _mode:
		1:
			target_crouch += 0.1                              # loading the legs in the takeback
			stance_t = 1.0
		2:
			stance_t = 1.0
			if _serve_style():
				target_crouch += 0.16 * (1.0 - swing_e)       # knees bent, then the drive up
			else:
				# Loaded until the forward swing, then driving up through the ball.
				target_crouch += lerpf(0.1, -0.01, swing_e) + clampf((0.65 - _contact.y) * 0.5, 0.0, 0.18)
				target_lean = -signf(_contact.x) * clampf((absf(_contact.x) - 0.95) * 0.45, 0.0, 0.25)
		3:
			target_crouch = 0.2                               # knee bend under the toss
			stance_t = 1.0
		4:
			target_crouch = 0.05 + (0.04 * sin(clampf(dribble / 0.5, 0.0, 1.0) * PI) if dribble >= 0.0 else 0.0)
			stance_t = 1.0
	if _slide > 0.0:
		_slide = maxf(0.0, _slide - delta / (0.8 if surface == "clay" else 0.5))
		var sl := _slide * _slide * (3.0 - 2.0 * _slide)
		target_crouch += 0.24 * sl
		target_lean += -_slide_dir.x * 0.22 * sl
		if _dust:
			_dust.emitting = _slide > 0.7
	_crouch = lerpf(_crouch, target_crouch, k)
	_lean = lerpf(_lean, target_lean, k)
	_stance = lerpf(_stance, stance_t, 1.0 - exp(-10.0 * delta))
	_follow = follow_e
	var lift := 0.0
	if _hop < 1.0:
		_hop = minf(1.0, _hop + delta / 0.28)
		lift = sin(_hop * PI) * 0.13
	# Serve / smash: spring up to meet a high ball.
	var air := 0.0
	if _mode == 2 and _serve_style():
		air = _jump_height() * clampf(1.0 - absf(_clock - _contact_at) / 0.28, 0.0, 1.0)
	_model.position.y = lift + air + absf(sin(_run_phase)) * 0.03 * amt

	var local_v := global_basis.inverse() * velocity
	# Lean into the run a little, but keep the upper body quiet (heads stay level).
	_model.rotation.x = lerpf(_model.rotation.x, -local_v.z * 0.03, k)
	_model.rotation.z = lerpf(_model.rotation.z, -local_v.x * 0.018 + _lean, k)
	var dp := _down_pose()
	if _down >= 0.0:
		# Diving / lying / getting up: the whole body tips over sideways from the feet.
		if _down_back:
			_model.rotation.x = dp.x
			_model.rotation.z = 0.0
		else:
			_model.rotation.z = -_down_dir * dp.x
			_model.rotation.x = 0.0
		_model.position.y += dp.y

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


## Where the feet stand for the current stroke (model space), before running and lunges.
## [right foot, left foot]; y > 0.05 lifts the heel.
func _stance_feet() -> Array:
	var r := Vector3(0.17, 0.05, 0.0)
	var l := Vector3(-0.17, 0.05, 0.0)
	var f := _follow
	if _mode == 3 or _mode == 4 or (_mode == 2 and _serve_style()):
		# Sideways serve stance: left foot at the line pointing at the net post, right
		# foot behind and to the right, parallel to the baseline.
		l = Vector3(-0.08, 0.05, -0.22)
		r = Vector3(0.3, 0.05, 0.16)
		if _mode == 2:
			# Drive up and land on the front foot inside the court, back leg kicking back.
			l = l.lerp(Vector3(-0.05, 0.05, -0.45), f)
			r = r.lerp(Vector3(0.12, 0.2, 0.1), f)
		return [r, l]
	if _mode != 1 and _mode != 2:
		return [r, l]
	if _side > 0 and not (_style == Style.SLICE or _style == Style.DROP):
		# Open-stance forehand: right foot set wide and loaded, left foot slightly ahead;
		# through the finish the right heel comes up and the foot pivots forward.
		r = Vector3(0.33, 0.05, 0.1).lerp(Vector3(0.24, 0.12, -0.08), f)
		l = Vector3(-0.14, 0.05, -0.1)
	elif _one_handed():
		# Closed stance: the right foot steps across toward the ball.
		r = Vector3(-0.16, 0.05, -0.36)
		l = Vector3(-0.32, 0.05, 0.18).lerp(Vector3(-0.28, 0.12, 0.1), f)
	elif _side < 0:
		# Neutral stance on the backhand: the right foot steps in toward the ball, the left
		# foot stays back loaded; at the finish the left heel comes up.
		r = Vector3(-0.08, 0.05, -0.32)
		l = Vector3(-0.3, 0.05, 0.14).lerp(Vector3(-0.24, 0.12, 0.05), f)
	else:
		# Forehand slice: the left foot steps across.
		r = Vector3(0.26, 0.05, 0.12)
		l = Vector3(0.02, 0.05, -0.3)
	return [r, l]


func _pose(local_v: Vector3, amt: float, near_contact: float) -> void:
	var hip_y := HIP_H - _crouch
	var tw := Basis(Vector3.UP, _twist)
	var th := Basis(Vector3.UP, _hip_twist)
	var pelvis := Vector3(0, hip_y, 0)
	var chest := Vector3(0, SHOULDER_H - _crouch * 0.6, 0)
	var r_sh := chest + tw * Vector3(SHOULDER_W, 0, 0)
	var l_sh := chest + tw * Vector3(-SHOULDER_W, 0, 0)
	var head := chest + Vector3(0, 0.3, 0)

	# Legs: feet step along the running direction; for a stroke they take the stance
	# of that stroke, and on a swing the foot on the ball's side steps toward a wide ball.
	var stride := Vector3(local_v.x, 0, local_v.z).normalized() * 0.4 * amt if amt > 0.05 else Vector3.ZERO
	var sl := _slide * _slide * (3.0 - 2.0 * _slide)
	var lead := 1.0 if _slide_dir.x >= 0.0 else -1.0  # the foot on the slide's side leads
	var lunge := 0.0
	if _mode == 2 and not _serve_style():
		lunge = clampf(1.0 - absf(_clock - _contact_at) / 0.35, 0.0, 1.0) * clampf((absf(_contact.x) - 0.9) / 0.5, 0.0, 1.0)
	var stance: Array = _stance_feet()
	var planted := _stance * (1.0 - amt)
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var phase := _run_phase + (0.0 if i == 0 else PI)
		var hip := pelvis + th * Vector3(0.11 * sgn, 0, 0)
		var neutral := Vector3(0.17 * sgn, 0.05, 0.0)
		var base: Vector3 = neutral.lerp(stance[i], _stance)
		var foot := base + stride * sin(phase)
		foot.y += maxf(0.0, cos(phase)) * 0.18 * amt
		foot = foot.lerp(stance[i], planted * 0.5)
		if sl > 0.0:
			# Slide: lead leg reaches out along the slide, trailing leg bent behind.
			var slide_foot := Vector3(0.17 * sgn, 0.04, 0.0) + (_slide_dir * 0.6 if sgn == lead else -_slide_dir * 0.15 + Vector3(0, 0, 0.15))
			foot = foot.lerp(slide_foot, sl)
			if sgn == lead and _dust:
				_dust.position = foot
		if sgn * signf(_contact.x) > 0.0:
			foot += Vector3(signf(_contact.x) * 0.2, 0.0, -0.12) * lunge
		var knee := _ik(hip, foot, THIGH, SHIN, hip + th * Vector3(0.08 * sgn, 0, -1.0))
		var ankle := _reach(knee, foot, SHIN)
		_set_bone("thigh%d" % i, hip, knee)
		_set_bone("shin%d" % i, knee, ankle)
		# Toes point where the hips point; a lifted heel tips the shoe forward.
		var toe_dir := th * Vector3(0.12 * sgn, 0, -1.0).normalized()
		var heel := ankle + Vector3(0, -0.03, 0) - toe_dir * 0.05
		var toe := ankle + toe_dir * 0.14
		toe.y = maxf(0.03, toe.y - maxf(0.0, ankle.y - 0.1) * 0.8)
		_set_bone("shoe%d" % i, heel, toe)

	# Torso: hips follow the hip turn, chest the shoulder turn; both are wider than deep,
	# so the turn reads from any angle.
	_set_bone("hips", pelvis + th * Vector3(-0.1, 0.02, 0), pelvis + th * Vector3(0.1, 0.02, 0))
	_set_torso("waist", pelvis + Vector3(0, 0.08, 0), chest.lerp(pelvis, 0.45), lerpf(_hip_twist, _twist, 0.5), 1.1, 0.8)
	_set_torso("chest", chest.lerp(pelvis, 0.5), chest + Vector3(0, -0.04, 0), _twist, 1.15, 0.72)
	_set_bone("shoulders", l_sh, r_sh)
	_set_bone("neck", chest, chest + Vector3(0, 0.16, 0))
	_head.position = head
	_head.rotation = Vector3(_head_pitch, _head_yaw, 0.0)

	# Racket arm, with the racket head steered onto the ball at the contact instant.
	# Elbow poles live in the shoulders' frame: out and down on the forehand side, in
	# front of the chest when the arm crosses the body (backhands).
	var cross := _side < 0 and (_mode == 1 or _mode == 2) and not _serve_style()
	var r_pole := r_sh + tw * (Vector3(0.1, -0.75, -0.65) if cross else Vector3(0.55, -0.8, 0.3))
	if cross and _two_handed() and (_mode == 1 or (_mode == 2 and _clock < _contact_at)):
		# Two-hander takeback: the right elbow points back (behind the body), not out.
		r_pole = r_sh + Vector3(-0.05, -0.8, 0.65)
	if _mode == 2 and not _serve_style() and _follow > 0.0:
		# Through the finish the elbow rises and points at the target, outside the face.
		r_pole = r_pole.lerp(r_sh + tw * Vector3(0.45 * _side, 0.55, -0.7), _follow)
	var hand_t := _keep_out(_hand, chest, pelvis, head, tw)
	var elbow := _keep_out(_ik(r_sh, hand_t, UPPER_ARM, FOREARM, r_pole), chest, pelvis, head, tw)
	var hand := _reach(elbow, hand_t, FOREARM)
	var rdir := _rdir
	if near_contact > 0.0:
		var to_ball := _contact_model() - hand
		if to_ball.length() > 0.05:
			rdir = rdir.lerp(to_ball.normalized(), near_contact).normalized()
	else:
		# Forearm and racket go around the head, never through it.
		var cleared := _clear_head(elbow, hand, rdir, head)
		elbow = cleared[0]
		hand = cleared[1]
		rdir = cleared[2]
	_set_bone("upper_r", r_sh, elbow)
	_set_bone("fore_r", elbow, hand)
	_hand_r.position = hand

	# Left arm: free, on the throat, or on the grip above the right hand (from where the
	# right hand really is, so both hands stay together).
	var lt := _lhand
	if _attach >= 2.0:
		lt = hand + rdir * 0.11
	elif _attach > 0.001:
		lt = _lhand.lerp(hand + rdir * 0.22 + tw * Vector3(-0.03, 0, 0), _attach)
	else:
		lt = _keep_out(lt, chest, pelvis, head, tw)
	var l_pole := l_sh + tw * (Vector3(-0.25, -0.75, -0.6) if _attach >= 2.0 else Vector3(-0.55, -0.8, 0.2))
	var l_elbow := _keep_out(_ik(l_sh, lt, UPPER_ARM, FOREARM, l_pole), chest, pelvis, head, tw)
	var lhand := _reach(l_elbow, lt, FOREARM)
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


## Keeps a hand or elbow out of the torso and the head, so arms never pass through the
## body: the torso is an upright ellipse turned with the shoulders.
func _keep_out(p: Vector3, chest: Vector3, pelvis: Vector3, head: Vector3, tw: Basis) -> Vector3:
	var hd := p - head
	var hr := 0.2
	if hd.length() < hr:
		p = head + (hd.normalized() if hd.length() > 0.001 else Vector3(0, 0, -1)) * hr
	if p.y < pelvis.y - 0.1 or p.y > chest.y + 0.12:
		return p
	var lp := tw.inverse() * Vector3(p.x, 0.0, p.z)
	var a := 0.27
	var b := 0.2
	var q := (lp.x / a) * (lp.x / a) + (lp.z / b) * (lp.z / b)
	if q >= 1.0:
		return p
	if q < 0.0001:
		lp = Vector3(0, 0, -b)
	else:
		lp /= sqrt(q)
	var out := tw * lp
	return Vector3(out.x, p.y, out.z)


## Pushes the forearm and the racket shaft out of the head: the closest point of each
## segment to the head centre must stay a head's width away.
func _clear_head(elbow: Vector3, hand: Vector3, rdir: Vector3, head: Vector3) -> Array:
	var r := 0.21
	var cp := Geometry3D.get_closest_point_to_segment(head, elbow, hand)
	var d := cp - head
	if d.length() < r:
		var away := d.normalized() if d.length() > 0.001 else Vector3(0, 0, -1)
		var push := away * (r - d.length())
		elbow += push
		hand += push
	# The racket head is a ring ~13 cm across: its centre keeps head + ring apart; the
	# throat keeps a head's width.
	var ring_r := r + 0.14
	var centre := hand + rdir * (RACKET_REACH - 0.02)
	var dc := centre - head
	if dc.length() < ring_r:
		var away := dc.normalized() if dc.length() > 0.001 else Vector3(0, 0, 1)
		rdir = (head + away * ring_r - hand).normalized()
	var cr := Geometry3D.get_closest_point_to_segment(head, hand, hand + rdir * 0.3)
	var dr := cr - head
	if dr.length() < r:
		var away := dr.normalized() if dr.length() > 0.001 else Vector3(0, 0, 1)
		rdir = (hand + rdir * 0.3 + away * (r - dr.length()) * 2.0 - hand).normalized()
	return [elbow, hand, rdir]


## Like _set_bone for the torso pieces: also turned about the vertical and squashed
## front to back, so the chest shows which way it faces.
func _set_torso(bone: String, a: Vector3, b: Vector3, yaw: float, sx: float, sz: float) -> void:
	_set_bone(bone, a, b)
	var mi: MeshInstance3D = _bones[bone]
	var y := (b - a).normalized()
	var x := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	x = (x - y * x.dot(y)).normalized()
	var z := x.cross(y)
	mi.basis = Basis(x * sx, y, z * sz)


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
