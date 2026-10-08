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
const SWING_TO_CONTACT := 0.24  # racket drop -> contact (Sinner FH-3/BH-4 to contact: 0.24 s)
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
# Timings and shapes measured frame by frame on broadcast clips of Alcaraz and Sinner on
# clay (research/clip-IMG_5044, research/CLIPS_5045_5046.md):
const FOLLOW_TIME := 0.55        # contact -> finish over the shoulder ~0.35 s, arm down by ~0.6 s (Sinner FH-7..9)
const SERVE_FOLLOW := 0.8        # landing ~0.3 s after contact, back leg up ~0.4 s, steps by 0.75 s
const VOLLEY_SWING := 0.1        # at the net the swing is a short punch...
const VOLLEY_FOLLOW := 0.24      # ...with a short finish
const VOLLEY_ZONE := 5.6         # closer to the net than this (m) a stroke is played as a volley
const UNIT_TURN_TIME := 0.42     # the shoulder turn is gradual, 0.5-0.7 s, done on the run
const SPLIT_TIME := 0.5          # a split step is a low wide load, not a hop
const LEAN_MAX := 0.26           # ~15 deg: the most a body leans into a sprint start
const SLIDE_DECEL := 9.0         # clay: a hard stop glides (measured 6-8 m/s2, 0.85-1.6 m)

var facing := -1.0             # -1 faces -Z (near player), +1 faces +Z (opponent)
var velocity := Vector3.ZERO
var max_speed := 6.2
var tired := false             # out of breath (Main sets it between points): hands on the knees
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
var _twirl := 0.0               # racket spun around its handle (rad), the idle fidget
var _shoulder_roll := 0.0       # shoulder line tilt (rad), + = right shoulder up (the serve)
var _pronation := 0.0           # racket turned over the ball after a serve (rad)
var _twirl_t := -1.0            # 0..1 through a spin, -1 = none
var _twirl_wait := 3.0          # seconds of standing until the next spin
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
var _acc := Vector3.ZERO       # world acceleration over the last physics tick
var _acc_local := Vector3.ZERO # the same in model space, smoothed (drives the lean)
var _lunge := 0.0              # 0..1 how far the legs are spread for a stretched ball
var _lunge_dir := Vector3.RIGHT # model-local direction toward that ball
var _pitch := 0.0              # trunk bent forward over a low ball (rad)
var _volley := false           # the current stroke is played at the net
var _alive_t := 0.0            # clock for the small breathing/bouncing while waiting
var _elbow_up := 0.0           # 0..1 the racket elbow raised toward the target in the finish
var _toss_t := 0.0             # seconds into the toss (racket arm low, then up to the trophy)
var _stretch := false          # the ball is out wide: a reaching shot with a short, low finish
var _swing_e := 0.0           # 0..1 through the forward swing (for the arm poles)
var _tilt := 0.0               # trunk tipped sideways from the hips toward a wide ball (rad, + = right)

# Visual nodes
var look: Dictionary = Looks.DEFAULT.duplicate()
var _shadow: MeshInstance3D
var _model: Node3D
var _bones := {}
var _racket: Node3D
var _gear := AthleteGear.new()  # what is worn and how it looks (scripts/athlete_gear.gd)
var _head: Node3D
var _hand_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _ends := {}                 # bone -> [from, to] in model space, as last drawn

## How the body is drawn (the rig, the animations and the look are the same for all):
##   CLASSIC  the original capsules
##   ATHLETE  real proportions: tapered limbs, a shaped torso, sleeves, shorts, socks,
##            sneakers, wristbands - one mesh per limb, coloured by the look
##   TOON     the ATHLETE body made chunkier with a bigger head, hands and feet,
##            cel shading and an outline (the mobile-sports-game look)
enum Body { CLASSIC, ATHLETE, TOON }
static var body_style := Body.TOON      # the look of every player (chosen 2026-10-06; CLASSIC / ATHLETE kept)
var _body := Body.CLASSIC                 # this player's, taken from body_style in setup()


## `appearance` is a look (see Looks) or, for older callers, just the shirt colour.
func setup(face: float, appearance, region: Rect2) -> void:
	facing = face
	area = region
	look = Looks.from_shirt(appearance) if appearance is Color else Looks.sanitize(appearance)
	_body = body_style
	_build()
	_lighten.call_deferred()
	rotation.y = 0.0 if facing < 0.0 else PI


## Dresses the player in another look: the body is rebuilt (between points, never
## mid-swing matters: the pose is recomputed every frame anyway).
func set_look(l: Dictionary) -> void:
	look = Looks.sanitize(l)
	if _model == null:
		return
	_model.queue_free()
	_shadow.queue_free()
	_bones = {}
	_build()
	_lighten.call_deferred()


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
	_volley = _at_net(style)


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
	if _mode == 2 and side == _side and not _serve_style() and _clock <= _contact_at + 0.08:
		# Already swinging at this ball (the swing was started ahead of contact so the
		# racket comes through): keep the motion, only correct where and when it meets
		# the ball. The stroke shape may still change before the forward swing starts.
		_contact = to_local(contact_world)
		if _clock < _contact_at:
			_stretch = _is_stretch()
		if _clock < _contact_at:
			_contact_at = minf(_contact_at, _clock + maxf(time_to_contact, 0.0))
		if _clock < _contact_at - _swing_time():
			_style = style
		return
	_mode = 2
	_side = side
	_style = style
	_volley = _at_net(style)
	_clock = 0.0
	_contact_at = maxf(time_to_contact, 0.05)
	_contact = to_local(contact_world)
	_stretch = _is_stretch()
	_swing_from_hand = _hand
	_swing_from_dir = _rdir


## Refine where the strings meet the ball once the real contact point is known.
func update_contact(contact_world: Vector3) -> void:
	_contact = to_local(contact_world)
	if _mode == 2 and _clock < _contact_at:
		_stretch = _is_stretch()


## The ball is out of comfortable reach: the stroke becomes a stretch.
func _is_stretch() -> bool:
	return not _serve_style() and Vector2(_contact.x, _contact.z).length() > 1.15


func split_step() -> void:
	_hop = 0.0


static func speed_of(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Slice and drop shot: the body stays side-on through the ball.
func _side_on() -> bool:
	return (_style == Style.SLICE or _style == Style.DROP) and not _volley


## Strokes close to the net are volleys: compact, racket head up, a short punch.
func _at_net(style: int) -> bool:
	if style != Style.TOPSPIN and style != Style.FLAT and style != Style.SLICE:
		return false
	return absf(global_position.z) < VOLLEY_ZONE


## 0..1: the serve's back leg kicked up behind (Alcaraz SV-8..10: up ~0.4 s after contact).
func _serve_kick() -> float:
	if _mode != 2 or not _serve_style() or _clock < _contact_at:
		return 0.0
	# Up behind ~0.1-0.3 s after the hit, held high while the left foot lands and the
	# body leans in, down again by ~0.75 s (Alcaraz SV-8..10).
	var t := _clock - _contact_at
	var up := clampf((t - 0.08) / 0.22, 0.0, 1.0)
	var down := clampf((t - 0.55) / 0.22, 0.0, 1.0)
	return up * up * (3.0 - 2.0 * up) * (1.0 - down * down * (3.0 - 2.0 * down))


## Forward swing (racket drop -> contact) and follow-through lengths for the stroke.
func _swing_time() -> float:
	return VOLLEY_SWING if _volley else SWING_TO_CONTACT


func _follow_time() -> float:
	if _serve_style():
		return SERVE_FOLLOW
	return VOLLEY_FOLLOW if _volley else FOLLOW_TIME


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
	var v_before := velocity
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
		_acc = Vector3.ZERO
	else:
		var target_v := Vector3(move_input.x, 0.0, move_input.y).limit_length(1.0) * max_speed
		var speeding_up := target_v.length() > velocity.length() and target_v.dot(velocity) >= 0.0
		var rate := accel if speeding_up else decel
		var released := target_v.length() < 0.1
		var reversing := target_v.dot(velocity) < 0.0
		if surface == "clay" and _slide > 0.3 and (released or (reversing and _slide > 0.6)):
			# Clay: letting go after a sprint is a slide, the body glides on; pushing
			# back the other way only bites after ~0.28 s of it (the outside foot digs
			# in and pushes off). Steering in to a stop near the ball stays as it was.
			rate = SLIDE_DECEL
		velocity += (target_v - velocity).limit_length(rate * delta)
		_acc = (velocity - v_before) / maxf(delta, 0.0001)
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

const UNIT_TURN := 1.62         # shoulder turn at the end of the takeback (rad): ~90 deg, chest to the side fence
const HIP_RATIO := 0.6          # hips turn a bit more than half as far as the shoulders
const FINISH_TURN := 0.85       # chest past square toward the other side at the finish
const SERVE_TURN := 1.4         # sideways serve stance: left shoulder to the net, right shoulder back
const FH_CONTACT_TURN := 0.45  # share of the forehand's turn still on at contact (Sinner FH-5/6)
const BH_TURN := 1.25           # two-hander: shoulders ~70 deg, the back half to the net, hands out to the left (Sinner)

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
## How the player waits while standing (Main sets it): 0 between points, upright with
## the feet apart; 1 receiving a serve, knees bent and weight forward. Both hold the
## racket in front with both hands, the left on the throat, like real players.
var stance_style := 0


func _two_handed() -> bool:
	return _side < 0 and (_style == Style.TOPSPIN or _style == Style.FLAT) and not one_handed_backhand and not _volley


func _one_handed() -> bool:
	return _side < 0 and (_style == Style.TOPSPIN or _style == Style.FLAT) and one_handed_backhand and not _volley


## How far the shoulders turn back in the takeback for the current stroke.
func _turn_amount() -> float:
	if _serve_style():
		return SERVE_TURN
	if _volley:
		return 0.55  # at the net the shoulders turn only a little
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

	if phase == "follow" and _stretch and not _volley and (style == Style.TOPSPIN or style == Style.FLAT):
		# A stretch has no big finish: the racket carries on out toward the target, low,
		# and the arm stays long (Alcaraz LG-7..9, the racket close to the clay).
		var sf := float(side)
		return [Vector3(0.62 * sf, maxf(c.y + 0.1, 0.62), -0.5), Vector3(0.55 * sf, 0.15, -0.82).normalized()]
	if _volley and (style == Style.TOPSPIN or style == Style.FLAT or style == Style.SLICE):
		# Volley: no backswing to speak of, racket head up in front of the shoulder line,
		# a short punch through the ball with the face a little open, the finish stops
		# toward the target.
		var sv := float(side)
		match phase:
			"prep":
				hand = Vector3(0.46 * sv, 1.24, 0.02)
				dir = Vector3(0.25 * sv, 0.85, 0.35)
			"drop":
				hand = Vector3(0.5 * sv, maxf(c.y + 0.12, 0.7), -0.06)
				dir = Vector3(0.6 * sv, 0.55, 0.1)
			"contact":
				dir = Vector3(1.0 * sv, 0.3, -0.35)
				hand = c - dir.normalized() * RACKET_REACH
			_:
				hand = Vector3(0.3 * sv, maxf(c.y, 0.9), -0.62)
				dir = Vector3(0.45 * sv, 0.35, -0.82)
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
				# The arm swings on through, past the right shoulder: up and out to the
				# right side, straight, the racket head up and behind (the classic
				# one-hander finish, about 70 degrees on from pointing at the target).
				# The hand sits one straight arm (0.58 m) from the turned right shoulder,
				# and the racket carries on the line of the forearm: no bend at the
				# elbow, no kink at the wrist.
				if style == Style.FLAT:
					dir = Vector3(0.67, 0.67, 0.32)
				else:
					dir = Vector3(0.45, 0.8, 0.4)
				hand = Vector3(0.19, SHOULDER_H, 0.06) + dir.normalized() * (UPPER_ARM + FOREARM - 0.01)
		return [hand, dir.normalized()]

	if side < 0 and style != Style.SLICE and style != Style.DROP:
		# Two-handed backhand.
		match phase:
			"prep":
				# Hands out to the left by the left hip, arms fairly long, racket head up
				# and back (Sinner BH-2/3): not tucked in behind the back.
				hand = Vector3(-0.46, 1.02, 0.22)
				dir = Vector3(-0.2, 0.6, 0.78)
			"drop":
				# The racket head drops only to hip height, still pointing back; the hands
				# stay out to the left, arms long (BH-4/5).
				hand = Vector3(-0.52, maxf(c.y - 0.06, 0.84), 0.06)
				dir = Vector3(-0.45, -0.3, 0.84)
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
					# End of the takeback: the shoulders are turned ~90 deg, the hand is back
					# behind the right shoulder at chest height, elbow down, racket head up
					# and pointing back toward the back fence (Sinner FH-1..3), never lying
					# flat along the shoulders.
					hand = Vector3(0.36 * s, 1.26, 0.48)
					dir = Vector3(0.08 * s, 0.86, 0.5)
				"drop":
					# The racket head drops behind and below the hand; the hand itself stays
					# up at the hip, elbow bent ~90 deg (FH-4) — it never hangs down straight.
					hand = Vector3(0.42 * s, maxf(c.y + 0.02, 0.96), 0.24)
					dir = Vector3(0.3 * s, -0.68, 0.67)
				"contact":
					dir = Vector3(1.0 * s, -0.05, -0.22)
					hand = c - dir.normalized() * RACKET_REACH
				_:
					if side > 0:
						# Nadal's lasso: the arm whips up over the head on the same side,
						# the racket wraps round behind the head, then comes back down.
						hand = Vector3(0.1, 1.98, -0.12)
						dir = Vector3(-0.55, 0.25, 0.8)
					else:
						# Windshield-wiper finish: hand by the left shoulder, racket behind it.
						hand = Vector3(-0.3 * s, 1.5, -0.24)
						dir = Vector3(-0.25 * s, 0.35, 0.9)
	return [hand, dir.normalized()]


## Just after contact the hand keeps going out toward the target (extension) before the
## racket wraps around; without this the hand would cut from the contact point straight
## to the shoulder, through the face. Returns [] for strokes without it.
func _extension(con: Array) -> Array:
	if _style == Style.SLICE or _style == Style.DROP or _style == Style.UNDERARM or _volley or _stretch:
		return []
	var h: Vector3 = con[0]
	if _serve_style():
		# After the hit the arm stays long, up and out toward the target while the
		# racket turns over and the chest turns to the net (Alcaraz SV-6/7).
		return [Vector3(0.12, 1.8, -0.55), Vector3(0.12, 0.3, -0.95).normalized()]
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
	_shadow.visible = _no_sun_shadows()
	# Draw the body between the last two physics ticks (smooth in slow motion); a jump
	# (placed for the serve) is not smoothed.
	var off := (_prev_pos - position) * (1.0 - Engine.get_physics_interpolation_fraction())
	_model.position = global_basis.inverse() * off if off.length() < 1.0 else Vector3.ZERO
	var speed := velocity.length()
	var k := 1.0 - exp(-12.0 * delta)
	_prep_t = _prep_t + delta if _mode == 1 else 0.0
	_toss_t = _toss_t + delta if _mode == 3 else 0.0

	# --- Racket path, shoulder and hip turn ---
	var near_contact := 0.0  # 1 at the contact instant: steer the racket head onto the ball
	var swing_e := 0.0       # 0..1 through the forward swing
	var follow_e := 0.0      # 0..1 through the follow-through
	if _mode == 2:
		_clock += delta
		var swing_t := _swing_time()
		var start := _contact_at - swing_t
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
			var u := clampf((_clock - start) / swing_t, 0.0, 1.0)
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
			# Kinetic chain: the hips fire first, the shoulders stay turned while the
			# racket drops (FH-4, BH-4) and unwind late, into the ball. A slice keeps
			# the body side-on through the ball.
			var sh_e := clampf((e - 0.35) / 0.65, 0.0, 1.0)
			sh_e = sh_e * sh_e * (3.0 - 2.0 * sh_e)
			var hip_e := clampf((e - 0.1) / 0.75, 0.0, 1.0)
			hip_e = hip_e * hip_e * (3.0 - 2.0 * hip_e)
			if _side_on():
				_twist = lerpf(-turn, -turn * 0.3, sh_e)
				_hip_twist = lerpf(-turn * HIP_RATIO, -turn * HIP_RATIO * 0.7, hip_e)
			elif _side > 0 and not _volley:
				# Forehand: the chest is still turned to the right at contact (FH-5) and
				# just after (FH-6); it comes square only in the finish (FH-7).
				_twist = lerpf(-turn, -turn * FH_CONTACT_TURN, sh_e)
				_hip_twist = lerpf(-turn * HIP_RATIO, -turn * HIP_RATIO * 0.25, hip_e)
			else:
				_twist = lerpf(-turn, 0.0, sh_e)
				_hip_twist = lerpf(-turn * HIP_RATIO, turn * 0.15, hip_e)
		else:
			var u := clampf((_clock - _contact_at) / _follow_time(), 0.0, 1.0)
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
			if _one_handed():
				# The one-hander's arm stays straight all the way: after contact the hand
				# travels on a sphere around the right shoulder (one straight arm long),
				# from low in front up to beside the body, in line with the shoulders,
				# never across the face. The racket carries on the line of the arm.
				var tw0 := Basis(Vector3.UP, _twist)
				var r_sh := Vector3(0.0, SHOULDER_H - _crouch * 0.6, 0.0) + tw0 * Vector3(SHOULDER_W, 0.0, 0.0)
				var reach0 := ((con[0] as Vector3) - r_sh).length()
				var arm := UPPER_ARM + FOREARM - 0.01
				var d0 := ((con[0] as Vector3) - r_sh).normalized()
				var d1 := (tw0 * Vector3(0.62, 0.78, 0.0)).normalized()  # up and out, in the body's plane
				var d := d0.slerp(d1, e)
				_hand = r_sh + d * lerpf(reach0, arm, clampf(e * 4.0, 0.0, 1.0))
				_rdir = (con[1] as Vector3).slerp(d, clampf(e * 1.6, 0.0, 1.0)).normalized()
			_elbow_up = e
			if _side > 0 and _style == Style.TOPSPIN and e > 0.5 and not _volley and not _stretch:
				# After the lasso over the head the arm comes down in front of the right
				# side of the chest, racket head up, on the way back to the ready position
				# (Alcaraz 7.75-8.07 s): never out to the side behind the shoulder.
				var w := (e - 0.5) / 0.5
				w = w * w * (3.0 - 2.0 * w)
				_hand = (fol[0] as Vector3).lerp(Vector3(0.3, 1.22, -0.34), w)
				_rdir = (fol[1] as Vector3).slerp(Vector3(-0.25, 0.75, -0.6).normalized(), w).normalized()
				_elbow_up = e * (1.0 - w)
			# The one-hander keeps the chest mostly sideways (the arm does the travelling);
			# everything else turns through.
			var fin := FINISH_TURN * (0.6 if _serve_style() else (0.35 if _one_handed() or _volley else 1.0))
			if _side_on():
				# Slice / drop: the finish goes out toward the target, the hips stay
				# where they were (DS-4..9), the chest opens only a little.
				_twist = lerpf(-turn * 0.3, -turn * 0.1, e)
				_hip_twist = -turn * HIP_RATIO * 0.7
			elif _side > 0 and not _volley and not _serve_style():
				# Forehand: the shoulders carry on unwinding after the hit, square by
				# ~0.23 s (FH-7), then on round into the finish.
				var w := u * u * (3.0 - 2.0 * u)
				_twist = lerpf(-turn * FH_CONTACT_TURN, fin * _side, w)
				_hip_twist = lerpf(-turn * HIP_RATIO * 0.25, fin * 0.7 * _side, minf(w * 1.3, 1.0))
			else:
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
				# The unit turn takes a moment: the racket goes back with the shoulders,
				# gradually and while still running (it starts slow and settles).
				var g := clampf(_prep_t / UNIT_TURN_TIME, 0.0, 1.0)
				g = g * g * (3.0 - 2.0 * g)
				# Running hard away from the hitting side (round the backhand to take a
				# forehand): the racket stays in front until the feet slow down (IO-1..3).
				var lv := global_basis.inverse() * velocity
				var away := clampf((-lv.x * _side - 1.0) / 1.5, 0.0, 1.0)
				g *= 1.0 - away
				var ready := [Vector3(0.1, 1.02, -0.38), Vector3(-0.35, 0.5, -0.78).normalized()]
				target = [(ready[0] as Vector3).lerp(target[0], g), (ready[1] as Vector3).slerp(target[1], g).normalized()]
				t_twist = -_turn_amount() * _side * g
				t_hips = t_twist * HIP_RATIO
			3:
				# Toss: the racket arm hangs down by the right hip while the tossing arm
				# goes up, then rises into the trophy (Alcaraz SV-1..3).
				var trophy: Array = _key(Style.SERVE, "prep", 1)
				var w := clampf((_toss_t - 0.12) / 0.45, 0.0, 1.0)
				w = w * w * (3.0 - 2.0 * w)
				target = [Vector3(0.36, 0.82, 0.22).lerp(trophy[0], w), Vector3(0.15, -0.85, 0.45).normalized().slerp(trophy[1], w)]
				# As the ball tops out the racket head starts dropping behind the back
				# (SV-3): it is half way down by the time the swing starts.
				var dr := clampf((_toss_t - 0.5) / 0.3, 0.0, 1.0)
				if dr > 0.0:
					var drop_k: Array = _key(Style.SERVE, "drop", 1)
					dr = dr * dr * (3.0 - 2.0 * dr) * 0.75
					target = [(target[0] as Vector3).lerp(drop_k[0], dr), (target[1] as Vector3).slerp(drop_k[1], dr).normalized()]
				t_twist = -SERVE_TURN
				t_hips = -SERVE_TURN * 0.9
			4:
				# Waiting to serve: sideways, racket resting in front, ball in the left hand.
				target = [Vector3(0.1, 1.0, -0.4), Vector3(-0.55, 0.45, -0.7).normalized()]
				t_twist = -SERVE_TURN
				t_hips = -SERVE_TURN * 0.9
			_:
				if _blowing(speed):
					# Out of breath: bent over, both hands on the knees, the racket hanging.
					target = [Vector3(0.2, 0.62, -0.26), Vector3(0.05, -0.75, -0.66).normalized()]
				elif stance_style == 1:
					# Ready to return: racket low and out in front, head up, both hands.
					target = [Vector3(0.06, 0.94, -0.44), Vector3(-0.3, 0.45, -0.84).normalized()]
				else:
					target = [Vector3(0.1, 1.02, -0.38), Vector3(-0.35, 0.5, -0.78).normalized()]
				if _slide > 0.2:
					# Sliding out wide: the body turns to the side it slides to and the
					# racket arm reaches out that way (Sinner SL-5..9).
					var ss := signf(_slide_dir.x) if absf(_slide_dir.x) > 0.3 else 1.0
					var sk := clampf((_slide - 0.2) / 0.4, 0.0, 1.0)
					t_twist = -ss * 1.25 * sk
					t_hips = t_twist * 0.6
					var reach: Array = [Vector3(0.62, 1.0, -0.1), Vector3(0.75, 0.45, -0.45).normalized()] if ss > 0.0 else [Vector3(-0.5, 1.0, -0.18), Vector3(-0.7, 0.5, -0.5).normalized()]
					target = [(target[0] as Vector3).lerp(reach[0], sk), (target[1] as Vector3).slerp(reach[1], sk)]
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
	elif _mode == 3:
		lh = Vector3(-0.02, 1.98, -0.4)                      # tossing arm up, pointing at the ball
	elif _mode == 2 and _serve_style():
		# The tossing arm stays up through the trophy, then drops and folds into the
		# stomach as the racket swings up: it is down well before contact.
		var up := Vector3(-0.02, 1.98, -0.4)
		var tuck := Vector3(-0.12, 1.02, -0.26)
		lh = up.lerp(tuck, clampf(swing_e / 0.35, 0.0, 1.0)) if swinging_before else tuck
	elif _volley and (_mode == 1 or _mode == 2):
		# Volley: the left hand holds the racket up in front, then lets go — out in front
		# for balance on the forehand, opening back on the backhand.
		attach = 1.0 if _mode == 1 or (swinging_before and swing_e < 0.3) else 0.0
		lh = Vector3(-0.3, 1.22, -0.42) if _side > 0 else Vector3(-0.5, 1.15, 0.18)
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
			# The lasso finish goes over the head alone; other forehands are caught.
			attach = 0.0 if _style == Style.TOPSPIN or _stretch else clampf((follow_e - 0.45) / 0.4, 0.0, 1.0)
		if _lunge > 0.05:
			# Stretched out wide: the left arm swings back the other way for balance.
			lh = lh.lerp(Vector3(-0.66, 1.22, 0.0), clampf(_lunge * 1.5, 0.0, 1.0))
	var sliding_out := _mode == 0 and _slide > 0.2
	if _mode == 0 and speed <= 1.5 and not sliding_out:
		attach = 1.0  # standing: the left hand rests on the racket throat
	if _blowing(speed):
		attach = 0.0
		lh = Vector3(-0.2, 0.62, -0.26)  # the other hand on the left knee
	if sliding_out and _slide_dir.x > 0.3:
		# Sliding to the forehand side: the left arm out the other way, no hand on the racket.
		attach = 0.0
		lh = Vector3(-0.58, 1.18, -0.06)
	elif sliding_out:
		attach = 1.0
	if _mode == 0 and speed > 1.5 and not sliding_out:
		var pump := sin(_run_phase) * clampf(speed / 5.0, 0.0, 1.0)
		lh = Vector3(-0.25, 1.05 + 0.08 * pump, -0.1 - 0.28 * pump)
		_hand += Vector3(0.0, 0.0, 0.12 * pump) * k
	_lhand = _lhand.lerp(lh, k)
	_update_twirl(delta, speed)
	if attach >= 2.0:
		_attach = 2.0
	else:
		_attach = lerpf(minf(_attach, 1.0), attach, 1.0 - exp(-14.0 * delta))

	# --- Body: crouch, hop, lean, stance ---
	_run_phase += delta * (5.0 + speed * 2.2)
	var amt := clampf(speed / 4.0, 0.0, 1.0)
	var target_crouch := 0.06 - amt * 0.03
	if _mode == 0 and stance_style == 1:
		target_crouch += 0.13 * (1.0 - amt)  # the returner's knees bend, ready to spring
	var target_lean := 0.0
	# Standing, the feet keep the waiting stance (wide); running, they go to the gait.
	var stance_t := clampf(1.0 - speed / 2.5, 0.0, 1.0)
	match _mode:
		1:
			target_crouch += 0.14                             # loading the legs in the takeback
			stance_t = 1.0
		2:
			# Hit and go: once the finish is under way the feet already run on to the
			# recovery (measured: the first recovery step ~0.3 s after contact).
			stance_t = 1.0 - clampf((follow_e - 0.45) / 0.4, 0.0, 1.0) * clampf(speed / 2.0, 0.0, 1.0)
			if _serve_style():
				target_crouch += 0.16 * (1.0 - swing_e)       # knees bent, then the drive up
			else:
				# Loaded until the forward swing, then driving up through the ball.
				target_crouch += lerpf(0.1, -0.01, swing_e) + clampf((0.65 - _contact.y) * 0.5, 0.0, 0.18)
				target_lean = -signf(_contact.x) * clampf((absf(_contact.x) - 0.95) * 0.45, 0.0, 0.25)
		3:
			# Knees bend under the toss, deepest as the ball tops out (SV-2/3).
			target_crouch = lerpf(0.08, 0.26, clampf(_toss_t / 0.6, 0.0, 1.0))
			stance_t = 1.0
		4:
			target_crouch = 0.05 + (0.04 * sin(clampf(dribble / 0.5, 0.0, 1.0) * PI) if dribble >= 0.0 else 0.0)
			stance_t = 1.0
	var slide_k := 0.0
	if _slide > 0.0:
		_slide = maxf(0.0, _slide - delta / (0.7 if surface == "clay" else 0.5))
		slide_k = _slide * _slide * (3.0 - 2.0 * _slide)
		# The slide is ridden low with the legs spread and the trunk upright (Sinner's
		# 1.6 m slide: hips ~0.62 m, head over the middle of the feet).
		target_crouch += 0.24 * slide_k
		target_lean += _slide_dir.x * 0.04 * slide_k
		if _dust:
			_dust.emitting = _slide > 0.35 and speed > 0.8

	# Stretched for a ball: the legs spread toward it and the hips drop (the real lunge
	# is 1.4-1.5 m wide); low balls bend the trunk forward over them.
	var lunge_t := 0.0
	var bend_t := 0.0
	if _mode == 2 and not _serve_style():
		var flat := Vector2(_contact.x, _contact.z)
		var near := minf(clampf((_clock - (_contact_at - 0.38)) / 0.24, 0.0, 1.0), clampf(1.0 - (_clock - (_contact_at + 0.18)) / 0.3, 0.0, 1.0))
		lunge_t = near * clampf((flat.length() - 0.95) / 0.45, 0.0, 1.0)
		if flat.length() > 0.01:
			_lunge_dir = Vector3(flat.x, 0.0, flat.y).normalized()
		bend_t = near * (clampf((0.78 - _contact.y) * 0.6, 0.0, 0.38) + 0.12 * lunge_t)
	if _mode == 2 and _serve_style():
		# Serve: bent forward over the landing while the back leg kicks up.
		bend_t = 0.55 * _serve_kick()
	if _blowing(speed):
		bend_t = 0.5 + 0.03 * sin(_alive_t * TAU * 1.6)  # bent over, heaving with each breath
	_lunge = lerpf(_lunge, lunge_t, 1.0 - exp(-10.0 * delta))
	_pitch = lerpf(_pitch, bend_t, 1.0 - exp(-(4.0 if tired else 10.0) * delta))
	target_crouch += 0.18 * _lunge
	# A stretch tips the trunk toward the ball from the hips, the feet stay on the court
	# (Alcaraz LG-4..7).
	var tilt_t := signf(_contact.x) * 0.55 * _lunge if _mode == 2 and not _serve_style() else 0.0
	_tilt = lerpf(_tilt, tilt_t, 1.0 - exp(-10.0 * delta))

	# Split step: a quick hop that lands low and wide, loaded to push off.
	var lift := 0.0
	if _hop < 1.0:
		_hop = minf(1.0, _hop + delta / SPLIT_TIME)
		lift = sin(clampf(_hop / 0.45, 0.0, 1.0) * PI) * 0.1
		target_crouch += 0.16 * sin(clampf((_hop - 0.3) / 0.7, 0.0, 1.0) * PI)
	# Waiting is never frozen: a slow breathing bounce in the knees.
	_alive_t += delta
	if _blowing(speed):
		target_crouch += 0.08  # knees bent under the hands
	elif _mode == 0 and speed < 0.4 and _down < 0.0:
		target_crouch += 0.012 * (0.5 + 0.5 * sin(_alive_t * TAU * (1.4 if stance_style == 1 else 0.7)))
	_crouch = lerpf(_crouch, target_crouch, k)
	_lean = lerpf(_lean, target_lean, k)
	_stance = lerpf(_stance, stance_t, 1.0 - exp(-10.0 * delta))
	_follow = follow_e
	_swing_e = swing_e
	# The serve's "cartwheel": in the trophy the left shoulder is up, reaching after the
	# toss; through the swing the shoulders tip over and the right one is high at
	# contact, the arm at full stretch; the racket then turns over the ball (pronation)
	# and the arm comes down across the body.
	var roll := 0.0
	var pron := 0.0
	if _mode == 3:
		roll = -0.3
	elif _mode == 2 and _serve_style():
		if _clock < _contact_at:
			roll = lerpf(-0.3, 0.62, clampf((swing_e - 0.1) / 0.6, 0.0, 1.0))
		else:
			roll = 0.62 * (1.0 - clampf(follow_e / 0.8, 0.0, 1.0))
			pron = -1.4 * clampf(follow_e / 0.3, 0.0, 1.0)
	var kr := 1.0 - exp(-30.0 * delta)
	_shoulder_roll = lerpf(_shoulder_roll, roll, kr)
	_pronation = lerpf(_pronation, pron, kr)
	# Serve / smash: spring up to meet a high ball.
	var air := 0.0
	if _mode == 2 and _serve_style():
		air = _jump_height() * clampf(1.0 - absf(_clock - _contact_at) / 0.28, 0.0, 1.0)
	_model.position.y = lift + air + absf(sin(_run_phase)) * 0.03 * amt

	var local_v := global_basis.inverse() * velocity
	# The body leans with the change of speed far more than with the speed itself
	# (measured: 14-17 deg in the first 0.3-0.5 s of a burst, ~0-5 deg at a steady run,
	# leaning back to brake). A slide is ridden upright.
	_acc_local = _acc_local.lerp(global_basis.inverse() * _acc, 1.0 - exp(-9.0 * delta))
	var calm := (1.0 - 0.65 * slide_k) * (0.6 if _mode == 2 else 1.0)
	var lean_side := clampf(-(local_v.x * 0.012 + _acc_local.x * 0.016) * calm, -LEAN_MAX, LEAN_MAX)
	var lean_fwd := clampf((local_v.z * 0.022 + _acc_local.z * 0.016) * calm, -LEAN_MAX, LEAN_MAX)
	_model.rotation.x = lerpf(_model.rotation.x, lean_fwd, k)
	_model.rotation.z = lerpf(_model.rotation.z, lean_side + _lean, k)
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
	if _serve_gaze():
		# Serving: the face turns up to the tossed ball (and stays there through the swing).
		pitch_t = clampf(maxf(pitch_t, SERVE_GAZE), SERVE_GAZE, 0.95)
	_head_yaw = lerpf(_head_yaw, yaw_t, 1.0 - exp(-8.0 * delta))
	_head_pitch = lerpf(_head_pitch, pitch_t, 1.0 - exp(-8.0 * delta))

	_pose(local_v, amt, near_contact)


const SERVE_GAZE := 0.62   # head tilt (rad) toward the toss at least, ~35 deg


## The toss and the swing up to just after contact: the eyes are on the ball overhead.
func _serve_gaze() -> bool:
	return _mode == 3 or (_mode == 2 and _serve_style() and _clock < _contact_at + 0.1)


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
			# Drive up and land on the front foot inside the court; the back leg kicks up
			# behind almost to the horizontal and comes back down (Alcaraz, Sinner: the
			# landing ~0.3 s after contact, the kick held ~0.3 s).
			# In the air the feet come together under the body (SV-4..6); the left foot
			# lands first, the right leg swings back nearly straight and comes down later
			# (SV-8..10).
			var air_k := clampf(1.0 - absf(_clock - _contact_at + 0.05) / 0.28, 0.0, 1.0)
			l = l.lerp(Vector3(-0.05, 0.05, -0.45), f)
			r = r.lerp(Vector3(0.12, 0.05, 0.05), f)
			r = r.lerp(l + Vector3(0.16, 0.0, 0.1), air_k)
			r += Vector3(0.03, 0.62, 0.78) * _serve_kick()
		return [r, l]
	if _mode == 0:
		# Waiting: the feet wider than the shoulders, both toes to the net; a split step
		# lands them wider still.
		var w := 0.4 if stance_style == 1 else 0.36
		if _hop < 1.0:
			# In the air the feet come in, they land wide and low (SP-2..6).
			w += -0.1 * sin(clampf(_hop / 0.35, 0.0, 1.0) * PI) + 0.26 * sin(clampf((_hop - 0.3) / 0.7, 0.0, 1.0) * PI)
		return [Vector3(w, 0.05, 0.0), Vector3(-w, 0.05, 0.0)]
	if _mode != 1 and _mode != 2:
		return [r, l]
	if _volley:
		# Volley: a step in toward the ball with the opposite foot, no heel lift.
		if _side > 0:
			return [Vector3(0.24, 0.05, 0.1), Vector3(-0.04, 0.05, -0.36)]
		return [Vector3(0.02, 0.05, -0.36), Vector3(-0.24, 0.05, 0.1)]
	if _side > 0 and not (_style == Style.SLICE or _style == Style.DROP):
		# Open-stance forehand, wide (~0.75 m): the right foot set back and out, loaded,
		# the left foot ahead; through the finish the right heel comes up and the foot
		# pivots forward (Sinner FH-1..10).
		r = Vector3(0.44, 0.05, 0.3).lerp(Vector3(0.32, 0.12, 0.0), f)
		l = Vector3(-0.3, 0.05, -0.14)
	elif _one_handed():
		# Closed stance: the right foot steps across toward the ball.
		r = Vector3(-0.16, 0.05, -0.36)
		l = Vector3(-0.32, 0.05, 0.18).lerp(Vector3(-0.28, 0.12, 0.1), f)
	elif _side < 0 and _style != Style.SLICE and _style != Style.DROP:
		# Two-hander (Sinner IMG_5046 5.0-6.2 s). Takeback: wide and planted, the left
		# foot out to the left and loaded, the right foot to the right (BH-1..3). Into
		# the forward swing the right foot steps in toward the net, so at contact the
		# feet are one behind the other, the line between them square to the baseline:
		# right foot ahead, left foot behind (BH-4/5). Both stay flat on the court
		# through the hit; only late in the finish the left heel comes up a little.
		var stp := 0.0
		if _mode == 2:
			stp = clampf((_clock - (_contact_at - 0.42)) / 0.26, 0.0, 1.0)
			stp = stp * stp * (3.0 - 2.0 * stp)
		r = Vector3(0.26, 0.05, -0.14).lerp(Vector3(-0.06, 0.05, -0.46), stp)
		l = Vector3(-0.46, 0.05, 0.12).lerp(Vector3(-0.3, 0.05, 0.24), stp)
		l.y += 0.05 * clampf((f - 0.55) / 0.45, 0.0, 1.0)
	elif _side < 0:
		# Backhand slice / drop: the right foot steps toward the ball, the left stays
		# back a little (Alcaraz DS-1).
		r = Vector3(-0.02, 0.05, -0.34)
		l = Vector3(-0.36, 0.05, 0.2).lerp(Vector3(-0.3, 0.12, 0.1), f)
	else:
		# Forehand slice: the left foot steps across.
		r = Vector3(0.26, 0.05, 0.12)
		l = Vector3(0.02, 0.05, -0.3)
	return [r, l]


func _pose(local_v: Vector3, amt: float, near_contact: float) -> void:
	var tw := Basis(Vector3.UP, _twist)
	var th := Basis(Vector3.UP, _hip_twist)
	var tilt := Basis(Vector3(0, 0, 1), _shoulder_roll)  # + raises the right shoulder

	# Legs: feet step along the running direction (skimming the court on sideways
	# shuffles, higher in a sprint); for a stroke they take that stroke's stance; a
	# stretched ball spreads them toward it and a slide spreads them along the slide. The
	# hips then sit as low as it takes for both feet to reach the court.
	var stride := Vector3(local_v.x, 0, local_v.z).normalized() * 0.4 * amt if amt > 0.05 else Vector3.ZERO
	var sideways := absf(local_v.x) / maxf(Vector2(local_v.x, local_v.z).length(), 0.01)
	# Sideways the feet shuffle (apart, together) on a wider base and never cross: a
	# crossover only comes in a real sprint (Alcaraz's 5 m run, 3.7 m/s and up).
	var shuffle := clampf(1.0 - (local_v.length() - 3.6) / 1.0, 0.0, 1.0) * sideways
	stride.x *= lerpf(1.0, 0.32, shuffle)
	var sl := _slide * _slide * (3.0 - 2.0 * _slide)
	var lead := 1.0 if _slide_dir.x >= 0.0 else -1.0  # the foot on the slide's side leads
	var ball_side := signf(_lunge_dir.x) if absf(_lunge_dir.x) > 0.2 else float(_side)
	var reach_dir := _slide_dir if sl > _lunge else _lunge_dir
	var stance: Array = _stance_feet()
	var planted := _stance * (1.0 - amt)
	# The whole body leans from the feet: planted feet are put back on the court.
	var roll := _model.rotation.z if _down < 0.0 else 0.0
	var tip := _model.rotation.x if _down < 0.0 else 0.0
	var hip_y := HIP_H - _crouch
	var feet: Array[Vector3] = []
	var hip_off: Array[Vector3] = []
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var phase := _run_phase + (0.0 if i == 0 else PI)
		var ho := th * Vector3(0.11 * sgn, 0, 0)
		var neutral := Vector3((0.17 + 0.07 * shuffle * amt) * sgn, 0.05, 0.0)
		var base: Vector3 = neutral.lerp(stance[i], _stance)
		var foot := base + stride * sin(phase)
		foot.y += maxf(0.0, cos(phase)) * lerpf(0.18, 0.09, sideways) * amt
		foot = foot.lerp(stance[i], planted * 0.5)
		if sl > 0.0:
			# Slide: the legs spread wide along it, the lead leg bent, the trailing one
			# straight, both feet flat on the clay (~1.4 m apart).
			var slide_foot := Vector3(0.17 * sgn, 0.04, 0.0) + (_slide_dir * 0.8 if sgn == lead else -_slide_dir * 0.6 + Vector3(0, 0, 0.06))
			foot = foot.lerp(slide_foot, sl)
			if sgn == lead and _dust:
				_dust.position = foot
		if _lunge > 0.0:
			# Lunge: the foot on the ball's side reaches toward it, the other pushes away.
			if sgn == ball_side:
				foot += _lunge_dir * 0.6 * _lunge
			else:
				foot += (-_lunge_dir * 0.3 + Vector3(0, 0, 0.08)) * _lunge
		foot.y += -foot.x * tan(roll) + foot.z * tan(tip)
		feet.append(foot)
		hip_off.append(ho)
	# Push-off: a burst sideways from a standstill drives off the outside leg, long and
	# straight, while the inside foot steps out (Alcaraz SP-8/9, RS-4).
	var push := clampf((absf(_acc_local.x) - 6.0) / 10.0, 0.0, 1.0) * (1.0 - clampf(speed_of(local_v) / 4.5, 0.0, 1.0)) if _down < 0.0 else 0.0
	if push > 0.01 and (_mode == 0 or _mode == 1):
		var go := signf(_acc_local.x)
		var lead_i := 0 if go > 0.0 else 1
		feet[lead_i].x += go * 0.22 * push
		feet[1 - lead_i].x -= go * 0.24 * push
	if _down < 0.0 and not (_mode == 2 and _serve_style()) and _mode != 3 and _mode != 4 and feet[0].x - feet[1].x < 0.14:
		# The right foot stays right of the left one (a stance or step never crosses).
		var mid := (feet[0].x + feet[1].x) * 0.5
		feet[0].x = mid + 0.07
		feet[1].x = mid - 0.07
	for i in 2:
		var foot := feet[i]
		var ho := hip_off[i]
		var d := Vector2(foot.x - ho.x, foot.z - ho.z).length()
		var leg := (THIGH + SHIN) * 0.985
		hip_y = minf(hip_y, foot.y + sqrt(maxf(leg * leg - d * d, 0.0)))
	hip_y = maxf(hip_y, 0.42)
	var drop := (HIP_H - _crouch) - hip_y
	var pelvis := Vector3(0, hip_y, 0)
	var chest := Vector3(0, SHOULDER_H - _crouch * 0.6 - drop * 0.85, 0)
	var head_up := Vector3(0, 0.3, 0)
	if _pitch > 0.001 or absf(_tilt) > 0.001:
		# Bending over a low ball / reaching for a wide one: the trunk tips from the hips.
		var h := chest.y - pelvis.y
		var up := Vector3(sin(_tilt), cos(_tilt) * cos(_pitch), -cos(_tilt) * sin(_pitch))
		chest = pelvis + up * h
		head_up = up * 0.3
	var r_sh := chest + tw * (tilt * Vector3(SHOULDER_W, 0, 0))
	var l_sh := chest + tw * (tilt * Vector3(-SHOULDER_W, 0, 0))
	var head := chest + head_up * (1.04 if _body == Body.TOON else (0.88 if _body == Body.ATHLETE else 1.0))

	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var hip := pelvis + hip_off[i]
		var foot := feet[i]
		# Knees point over the toes, also when the foot is out wide.
		var out := Vector3(foot.x - hip.x, 0, foot.z - hip.z)
		var knee := _ik(hip, foot, THIGH, SHIN, hip + th * Vector3(0.08 * sgn, 0, -1.0) + out * 0.8)
		var ankle := _reach(knee, foot, SHIN)
		_set_bone("thigh%d" % i, hip, knee)
		_set_joint("knee%d" % i, knee)
		_set_bone("shin%d" % i, knee, ankle)
		# Toes point where the hips point (the lead foot of a lunge or slide turns out
		# toward the ball); a lifted heel tips the shoe forward.
		var toe_dir := th * Vector3(0.12 * sgn, 0, -1.0).normalized()
		var spread := maxf(_lunge, sl)
		if spread > 0.01 and out.length() > 0.3 and out.normalized().dot(reach_dir) > 0.3:
			toe_dir = toe_dir.lerp(out.normalized(), 0.5 * spread).normalized()
		var heel := ankle + Vector3(0, -0.03, 0) - toe_dir * 0.05
		var toe := ankle + toe_dir * 0.14
		toe.y = maxf(0.03, toe.y - maxf(0.0, ankle.y - 0.1) * 0.8)
		var kicked := _serve_kick() if i == 0 else 0.0
		if kicked > 0.01:
			# The serve's back leg swung up behind: the foot is pointed, the sole up,
			# along the line of the shin (SV-9) — not hooked down at the court.
			var along := (ankle - knee).normalized()
			heel = heel.lerp(ankle - along * 0.03 + Vector3(0, 0.03, 0), kicked)
			toe = toe.lerp(ankle + along * 0.15, kicked)
		_set_bone("shoe%d" % i, heel, toe)

	# Torso: hips follow the hip turn, chest the shoulder turn; both are wider than deep,
	# so the turn reads from any angle.
	_set_bone("hips", pelvis + th * Vector3(-0.1, 0.0 if _body == Body.TOON else 0.02, 0), pelvis + th * Vector3(0.1, 0.0 if _body == Body.TOON else 0.02, 0))
	if _body == Body.TOON:
		# One piece from the pelvis to the shoulders: no seam across the back.
		_set_torso("waist", pelvis + Vector3(0, 0.08, 0), chest.lerp(pelvis, 0.45), lerpf(_hip_twist, _twist, 0.5), 1.1, 0.8)
		_set_torso("chest", pelvis + Vector3(0, 0.06, 0), chest + Vector3(0, -0.04, 0), lerpf(_hip_twist, _twist, 0.75), 1.12, 0.76)
	else:
		_set_torso("waist", pelvis + Vector3(0, 0.08, 0), chest.lerp(pelvis, 0.45), lerpf(_hip_twist, _twist, 0.5), 1.1, 0.8)
		_set_torso("chest", chest.lerp(pelvis, 0.5), chest + Vector3(0, -0.04, 0), _twist, 1.15, 0.72)
	_set_bone("shoulders", l_sh, r_sh)
	_set_bone("neck", chest, chest + Vector3(0, 0.16, 0))
	if _head_pitch > 0.0:
		# A head tipped back sinks onto the shoulders a little instead of riding on a long neck.
		var back := clampf(_head_pitch / 0.95, 0.0, 1.0)
		head += Vector3(0.0, -0.035 * back, 0.035 * back)
	_head.position = head
	_head.rotation = Vector3(_head_pitch, _head_yaw, 0.0)

	# Racket arm, with the racket head steered onto the ball at the contact instant.
	# Elbow poles live in the shoulders' frame: out and down on the forehand side, in
	# front of the chest when the arm crosses the body (backhands).
	var cross := _side < 0 and (_mode == 1 or _mode == 2) and not _serve_style()
	var r_pole := r_sh + tw * (Vector3(0.1, -0.75, -0.65) if cross else Vector3(0.55, -0.8, 0.3))
	if cross and _two_handed() and (_mode == 1 or (_mode == 2 and _clock < _contact_at)):
		# Two-hander takeback: the right elbow points back (behind the body), not out;
		# through the forward swing it comes round to point down in front, so the arm
		# never kinks on the way to the ball (BH-5).
		r_pole = r_sh + Vector3(-0.05, -0.8, 0.65)
		if _mode == 2:
			r_pole = r_pole.lerp(r_sh + tw * Vector3(0.1, -0.75, -0.65), clampf(_swing_e * 1.4, 0.0, 1.0))
	if _mode == 2 and not _serve_style() and _follow > 0.0:
		# Through the finish the elbow rises and points at the target, outside the face
		# (and drops again as the arm comes down after a lasso).
		if _two_handed():
			# Two-hander's finish over the right shoulder: the right elbow points down
			# and out to the right, never up across the face (Sinner BH-9/10).
			r_pole = r_pole.lerp(r_sh + tw * Vector3(0.45, -0.6, -0.45), clampf(_follow * 1.6, 0.0, 1.0))
		else:
			r_pole = r_pole.lerp(r_sh + tw * Vector3(0.45 * _side, 0.55, -0.7), _elbow_up)
	# The hand keys are set for an upright trunk; when the hips sink into a lunge or the
	# trunk bends over a low ball the shoulders move, and the arms must move with them
	# (otherwise an arm reaching for a key over the head of a sunken body snaps straight
	# and backwards). Only the strings-on-ball moment stays where the ball really is.
	var carry := chest - Vector3(0, SHOULDER_H - _crouch * 0.6, 0)
	var at_ball := 0.0
	if _mode == 2 and not _serve_style():
		at_ball = clampf(1.0 - absf(_clock - _contact_at) / 0.2, 0.0, 1.0)
	var hand_t := _keep_out(_human_hand(r_sh, _hand + carry * (1.0 - at_ball), tw), chest, pelvis, head, tw)
	var elbow := _keep_out(_ik(r_sh, hand_t, UPPER_ARM, FOREARM, r_pole), chest, pelvis, head, tw)
	elbow = _human_elbow(r_sh, hand_t, elbow, tw, chest, pelvis, head)
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
	_set_joint("elbow_r", elbow)
	_set_bone("fore_r", elbow, hand)
	_place_hand(_hand_r, elbow, hand)

	# Left arm: free, on the throat, or on the grip above the right hand (from where the
	# right hand really is, so both hands stay together).
	var lt := _lhand + carry
	if _attach >= 2.0:
		lt = hand + rdir * 0.11
	elif _attach > 0.001:
		lt = lt.lerp(hand + rdir * 0.22 + tw * Vector3(-0.03, 0, 0), _attach)
	else:
		lt = _human_hand(l_sh, _keep_out(_human_hand(l_sh, lt, tw), chest, pelvis, head, tw), tw)
	if _attach < 1.5:
		lt = _human_hand(l_sh, lt, tw)
	var l_pole := l_sh + tw * (Vector3(-0.25, -0.75, -0.6) if _attach >= 2.0 else Vector3(-0.55, -0.8, 0.2))
	if _attach >= 2.0 and (_mode == 1 or (_mode == 2 and _clock < _contact_at)):
		# Two-hander up to contact: the left elbow points back and a little out, the
		# arm bent (Sinner BH-2..5), never folded forward across the chest.
		l_pole = l_sh + tw * Vector3(-0.3, -0.55, 0.7)
	elif _attach >= 2.0 and _mode == 2:
		# Through the finish the left elbow comes round in front and up.
		l_pole = (l_sh + tw * Vector3(-0.3, -0.55, 0.7)).lerp(l_sh + tw * Vector3(-0.1, -0.5, -0.85), clampf(_follow * 1.5, 0.0, 1.0))
	var l_elbow := _keep_out(_ik(l_sh, lt, UPPER_ARM, FOREARM, l_pole), chest, pelvis, head, tw)
	l_elbow = _human_elbow(l_sh, lt, l_elbow, tw, chest, pelvis, head)
	var lhand := _reach(l_elbow, lt, FOREARM)
	_set_bone("upper_l", l_sh, l_elbow)
	_set_joint("elbow_l", l_elbow)
	_set_bone("fore_l", l_elbow, lhand)
	_place_hand(_hand_l, l_elbow, lhand)
	_lhand_actual = lhand

	# Racket: handle along the racket direction, face turned toward the shot (open for slice).
	var y := rdir
	var face := Vector3(0, 0.45, -1) if _style == Style.SLICE or _style == Style.DROP or _style == Style.UNDERARM else Vector3(0, 0, -1)
	face = face - y * face.dot(y)
	if (_twirl != 0.0 or _pronation != 0.0) and face.length() > 0.05:
		face = Basis(y, _twirl + _pronation) * face
	if face.length() < 0.05:
		face = Vector3(0, 1, 0) - y * y.y
	face = face.normalized()
	var x := y.cross(face).normalized()
	_racket.transform = Transform3D(Basis(x, y, x.cross(y)), hand)


## A hand sits on the end of the forearm and points along it.
func _place_hand(h: MeshInstance3D, elbow: Vector3, hand: Vector3) -> void:
	h.position = hand
	if _body == Body.CLASSIC:
		return
	var y := (hand - elbow).normalized() if (hand - elbow).length() > 0.001 else Vector3.DOWN
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	h.basis = Basis(x, y, x.cross(y)) * Basis.from_scale(_hand_scale)
	h.position = hand + y * 0.02


## Standing and waiting, the player spins the racket in the hand now and then (a full
## turn in under half a second); any movement or stroke stops it at once.
func _update_twirl(delta: float, speed: float) -> void:
	if _mode != 0 or speed > 0.6:
		_twirl = 0.0
		_twirl_t = -1.0
		_twirl_wait = maxf(_twirl_wait, 1.5)
		return
	if _twirl_t < 0.0:
		_twirl_wait -= delta
		if _twirl_wait <= 0.0:
			_twirl_t = 0.0
		return
	_twirl_t = minf(_twirl_t + delta / 0.45, 1.0)
	var e := _twirl_t * _twirl_t * (3.0 - 2.0 * _twirl_t)
	_twirl = TAU * e
	if _twirl_t >= 1.0:
		_twirl = 0.0
		_twirl_t = -1.0
		_twirl_wait = _slip_rng.randf_range(3.0, 7.0)


## Keeps a hand or elbow out of the torso and the head, so arms never pass through the
## body: the torso is an upright ellipse turned with the shoulders.
## A human shoulder and elbow: the elbow can't go further back than the plane of the
## body (a little more with the arm hanging down), and it never sits above the hand
## once the hand is up above the shoulder (no "chicken wing", no arm turned inside
## out). The serve / smash trophy is the one place where the elbow is up and back.
## The elbow is turned round the shoulder-hand line, so the hand stays where it is.
## Real shadows switched off in the graphics settings (Tuning.gfx_shadows == 0).
func _no_sun_shadows() -> bool:
	if blob_shadows:
		return true
	var tuning := get_node_or_null("/root/Tuning")
	return tuning != null and int(tuning.gfx_shadows) == 0


## The club turns the sun's shadow off on the lower presets (docs/club/H1_SPEC.md 7):
## then everyone stands on the round shadow, as with shadows off in the settings.
static var blob_shadows := false


## Standing still out of breath, not sliding or down: the hands-on-knees pose.
func _blowing(speed: float) -> bool:
	return tired and _mode == 0 and speed < 0.4 and _slide <= 0.2 and _down < 0.0


func _human_elbow(sh: Vector3, hand: Vector3, elbow: Vector3, tw: Basis, chest: Vector3, pelvis: Vector3, head: Vector3) -> Vector3:
	if _serve_style() and (_mode == 2 or _mode == 3) or _mode == 3 or _down >= 0.0:
		return elbow
	var axis := hand - sh
	if axis.length() < 0.05:
		return elbow
	axis = axis.normalized()
	var on_axis := sh + axis * (elbow - sh).dot(axis)
	var rad := elbow - on_axis
	if rad.length() < 0.01:
		return elbow
	var best := elbow
	var best_cost := _elbow_cost(sh, hand, elbow, tw)
	if best_cost <= 0.0:
		return elbow
	for k in range(1, 24):
		for sgn in [1.0, -1.0]:
			var e := on_axis + rad.rotated(axis, sgn * k * TAU / 48.0)
			var c := _elbow_cost(sh, hand, e, tw) + 0.002 * k  # the smallest turn that does it
			if c < best_cost:
				best_cost = c
				best = e
	return _keep_out(best, chest, pelvis, head, tw)


## A hand can't reach round behind the back: past the plane of the body it's held
## a hand's width behind at most (the serve's trophy and racket drop excepted).
func _human_hand(sh: Vector3, p: Vector3, tw: Basis) -> Vector3:
	if _serve_style() and (_mode == 2 or _mode == 3) or _mode == 3 or _down >= 0.0:
		return p
	var v := tw.inverse() * (p - sh)
	if v.z <= 0.12:
		return p
	v.z = 0.12
	return sh + tw * v


## How far an elbow is outside what a human arm can do (0 = fine).
func _elbow_cost(sh: Vector3, hand: Vector3, elbow: Vector3, tw: Basis) -> float:
	var v := tw.inverse() * (elbow - sh)          # in the chest's frame: +Z is behind the back
	var down := clampf(-v.y / UPPER_ARM, 0.0, 1.0)
	var back := maxf(0.0, v.z - (0.06 + 0.12 * down))
	var up := 0.0
	if hand.y > sh.y + 0.05:
		up = maxf(0.0, elbow.y - hand.y + 0.02)
	return back + up


func _keep_out(p: Vector3, chest: Vector3, pelvis: Vector3, head: Vector3, tw: Basis) -> Vector3:
	var hd := p - head
	var hr := 0.2
	if hd.length() < hr:
		p = head + (hd.normalized() if hd.length() > 0.001 else Vector3(0, 0, -1)) * hr
	if p.y < pelvis.y - 0.1 or p.y > chest.y + 0.12:
		return p
	# The trunk's centre at this height (it leans forward over low balls).
	var ctr := pelvis.lerp(chest, clampf((p.y - pelvis.y) / maxf(chest.y - pelvis.y, 0.01), 0.0, 1.0))
	var lp := tw.inverse() * Vector3(p.x - ctr.x, 0.0, p.z - ctr.z)
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
	return Vector3(out.x + ctr.x, p.y, out.z + ctr.z)


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
	var ys := 1.0
	if not mi.mesh is CapsuleMesh:
		ys = (b - a).length() / float(mi.get_meta("ref", 1.0))
	mi.basis = Basis(x * sx, y * ys, z * sz)


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
	_ends[bone] = [a, b]
	if not mi.mesh is CapsuleMesh:
		# A turned body part made for a reference length: stretched to the bone, and
		# flattened top to bottom if it's a shoe.
		var ys := len / float(mi.get_meta("ref", len))
		var z := x.cross(y)
		var flat := float(mi.get_meta("flat", 1.0))
		if flat != 1.0:
			# Squash along whichever side axis points most up.
			if absf(x.y) > absf(z.y):
				x *= flat
			else:
				z *= flat
		mi.transform = Transform3D(Basis(x, y * ys, z), (a + b) * 0.5)
		return
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	# Limb lengths are fixed by the IK; only rebuild a mesh when its length really changes.
	var cm := mi.mesh as CapsuleMesh
	var h := len + cm.radius * 2.0
	if absf(cm.height - h) > 0.015:
		cm.height = h


# --- Build ----------------------------------------------------------------------

func _build() -> void:
	_model = Node3D.new()
	add_child(_model)
	var skin := Looks.skin(look)
	var shirt := Looks.kit(look, "shirt")
	var shorts := Looks.kit(look, "shorts")
	var white := Color(0.96, 0.96, 0.96)

	# A dark disc under the feet: only a stand-in for when the real (sun) shadows are
	# switched off in the graphics settings; with them on it doubled the shadow.
	_shadow = _mesh_cyl(0.38, 0.002, Color(0, 0, 0, 0.35), true)
	_shadow.position.y = 0.04
	_shadow.visible = _no_sun_shadows()
	add_child(_shadow)

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

	if _body == Body.CLASSIC:
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
	else:
		_build_body()
	_model.add_child(_hand_r)
	_model.add_child(_hand_l)

	# Head: face looks along -Z; hair, beard and headwear from the look, eyes.
	_head = Node3D.new()
	_model.add_child(_head)
	if _body == Body.TOON:
		_head.scale = Vector3.ONE * 1.28
	var skull := _sphere(0.12, skin)
	skull.scale = Vector3(0.95, 1.05, 1.0)
	_head.add_child(skull)
	if _body != Body.CLASSIC:
		for ex in [-1.0, 1.0]:
			var ear := _no_outline(_sphere(0.026, skin.darkened(0.04)))
			ear.scale = Vector3(0.45, 1.0, 0.8)
			ear.position = Vector3(ex * 0.112, 0.0, 0.01)
			_head.add_child(ear)
	_build_hair()
	_build_beard()
	_build_headwear()
	for ex in [-0.04, 0.04]:
		var eye := _no_outline(_sphere(0.016, Color(0.08, 0.08, 0.1)))
		eye.position = Vector3(ex, 0.015, -0.112)
		_head.add_child(eye)
	var nose := _no_outline(_sphere(0.02, skin.darkened(0.08)))
	nose.position = Vector3(0, -0.02, -0.122)
	_head.add_child(nose)

	# Racket: local +Y runs from the hand to the head; the face lies in the XY plane.
	# Its meshes, the shoes' and wristbands' colours come from what is worn.
	_racket = Node3D.new()
	_model.add_child(_racket)
	_gear.dress(self)


# --- Gear on the body (v0.2 F, scripts/athlete_gear.gd) ------------------------------

## Dresses the player in these items (Gear / Items dictionaries, {} = nothing in that
## slot; the slot comes from the item): the racket, the shoes and the wristbands look
## like them. Only the gear is rebuilt, never the body; set_look keeps it.
func set_gear(items: Array) -> void:
	_gear.wear(items)
	_gear.dress(self)


## Only the racket (the trophy in hand, a knocked-out racket); shoes and band stay.
func set_racket(item: Dictionary) -> void:
	var items := AthleteGear.items_of(_gear.worn)
	items[0] = item
	set_gear(items)


## What is worn, {slot: item}.
func gear() -> Dictionary:
	return _gear.worn.duplicate()


## Older callers: the worn racket's frame in colour c, glowing like a rarity with this
## glow (Gear.RARITIES "glow"), e.g. the golden opponent's.
func set_racket_look(c: Color, glow: float) -> void:
	_gear.tint = {"color": c, "glow": glow}
	_gear.dress(self)


# --- Hair, beard, headwear ---------------------------------------------------------
# Built in head space: the skull is an ellipsoid of 0.114 x 0.126 x 0.12 m, the face
# looks along -Z, the eyes sit at y 0.015. Each of hair, beard and headwear is merged
# into ONE mesh (one draw call) however many curls or spikes it has.

static var _unit_sphere: SphereMesh
static var _unit_dome: SphereMesh
static var _unit_capsule: CapsuleMesh
static var _unit_cone: CylinderMesh
static var _unit_disc: CylinderMesh


static func _parts_meshes() -> void:
	if _unit_sphere != null:
		return
	_unit_sphere = SphereMesh.new()
	_unit_sphere.radius = 1.0
	_unit_sphere.height = 2.0
	_unit_sphere.radial_segments = 12
	_unit_sphere.rings = 6
	_unit_dome = SphereMesh.new()
	_unit_dome.radius = 1.0
	_unit_dome.height = 1.0
	_unit_dome.is_hemisphere = true
	_unit_dome.radial_segments = 14
	_unit_dome.rings = 4
	_unit_capsule = CapsuleMesh.new()
	_unit_capsule.radius = 0.5
	_unit_capsule.height = 2.0
	_unit_capsule.radial_segments = 8
	_unit_capsule.rings = 2
	_unit_cone = CylinderMesh.new()
	_unit_cone.top_radius = 0.0
	_unit_cone.bottom_radius = 1.0
	_unit_cone.height = 1.0
	_unit_cone.radial_segments = 6
	_unit_cone.rings = 1
	_unit_disc = CylinderMesh.new()
	_unit_disc.top_radius = 1.0
	_unit_disc.bottom_radius = 1.0
	_unit_disc.height = 1.0
	_unit_disc.radial_segments = 16
	_unit_disc.rings = 1


static func _tf(pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos)


## [mesh, transform] parts merged into one MeshInstance3D on the head.
func _merged(parts: Array, c: Color) -> void:
	if parts.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		st.append_from(p[0], 0, p[1])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(c)
	_head.add_child(mi)


## A point on the hair cap's surface: elevation `el` (0 at the ear line, PI/2 on top)
## and azimuth `az` (0 = straight back, PI = the forehead).
static func _cap_point(el: float, az: float, grow := 1.0) -> Vector3:
	var c := Vector3(0.0, 0.03, 0.012)
	return c + Vector3(sin(az) * cos(el) * 0.122, sin(el) * 0.118, cos(az) * cos(el) * 0.126) * grow


func _build_hair() -> void:
	_parts_meshes()
	var style := int(look["hair"])
	var head_kind := int(look["head"])
	var capped := head_kind == Looks.Head.CAP or head_kind == Looks.Head.CAP_BACK
	var p: Array = []   # [mesh, transform, is_top]
	var sph := _unit_sphere
	# The cap of hair every style but bald and the mohawk starts from; a cap on top
	# squashes it so nothing pokes through the crown.
	var base := _tf(Vector3(0, 0.03, 0.012), Vector3(0.122, 0.118, 0.126))
	if capped:
		base = _tf(Vector3(0, 0.0, 0.02), Vector3(0.12, 0.115, 0.122))
	match style:
		Looks.Hair.BALD:
			pass
		Looks.Hair.BUZZ:
			# Shaved close: a thin layer, the colour half skin so the scalp shows through.
			_merged([[sph, _tf(Vector3(0, 0.012, 0.006), Vector3(0.117, 0.12, 0.123))]], Looks.hair_color(look).lerp(Looks.skin(look), 0.45))
			return
		Looks.Hair.SHORT:
			p.append([sph, base, false])
		Looks.Hair.SIDE_PART:
			p.append([sph, base, false])
			p.append([sph, _tf(Vector3(-0.045, 0.1, -0.035), Vector3(0.075, 0.04, 0.07), Vector3(0, 0, 0.25)), true])
		Looks.Hair.QUIFF:
			p.append([sph, base, false])
			p.append([sph, _tf(Vector3(0, 0.118, -0.06), Vector3(0.085, 0.05, 0.065), Vector3(-0.5, 0, 0)), true])
		Looks.Hair.SPIKY:
			p.append([sph, base, false])
			for i in 9:
				var el := 0.75 + 0.55 * float(i % 3) / 2.0
				var az := TAU * float(i) / 9.0 + 0.3
				var at := _cap_point(el, az, 0.92)
				var n := (at - Vector3(0, 0.03, 0.012)).normalized()
				var x := (n.cross(Vector3.FORWARD) if absf(n.z) < 0.9 else n.cross(Vector3.RIGHT)).normalized()
				var b := Basis(x, n, x.cross(n))
				p.append([_unit_cone, Transform3D(b * Basis.from_scale(Vector3(0.024, 0.07, 0.024)), at + n * 0.03), true])
		Looks.Hair.MESSY:
			p.append([sph, base, false])
			for i in 10:
				var at := _cap_point(0.55 + 0.9 * fmod(i * 0.618, 1.0), TAU * fmod(i * 0.381, 1.0), 0.98)
				p.append([sph, _tf(at, Vector3.ONE * (0.035 + 0.012 * float(i % 3))), at.y > 0.07])
		Looks.Hair.CURLY:
			p.append([sph, base, false])
			for i in 30:
				var el := asin(clampf(-0.15 + 1.15 * float(i) / 29.0, -1.0, 1.0))
				var az := float(i) * 2.39996
				if el < 0.25 and cos(az) < -0.55:
					continue  # not over the face
				var at := _cap_point(el, az, 1.02)
				p.append([sph, _tf(at, Vector3.ONE * 0.033), at.y > 0.07])
		Looks.Hair.AFRO:
			p.append([sph, base, false])
			p.append([sph, _tf(Vector3(0, 0.09, 0.05), Vector3(0.165, 0.15, 0.16)), true])
			for i in 22:
				var el := asin(clampf(-0.3 + 1.3 * float(i) / 21.0, -1.0, 1.0))
				var az := float(i) * 2.39996
				if el < 0.35 and cos(az) < -0.4:
					continue
				var at := Vector3(0, 0.09, 0.05) + Vector3(sin(az) * cos(el) * 0.155, sin(el) * 0.14, cos(az) * cos(el) * 0.15)
				p.append([sph, _tf(at, Vector3.ONE * 0.06), at.y > 0.07])
		Looks.Hair.LONG:
			p.append([sph, base, false])
			p.append([sph, _tf(Vector3(0, -0.06, 0.07), Vector3(0.125, 0.19, 0.075)), false])
			for sx in [-1.0, 1.0]:
				p.append([sph, _tf(Vector3(sx * 0.1, -0.05, 0.005), Vector3(0.035, 0.13, 0.07)), false])
		Looks.Hair.PONYTAIL:
			p.append([sph, base, false])
			p.append([sph, _tf(Vector3(0, 0.035, 0.13), Vector3.ONE * 0.032), false])
			p.append([_unit_capsule, _tf(Vector3(0, -0.07, 0.165), Vector3(0.05, 0.075, 0.05), Vector3(0.35, 0, 0)), false])
		Looks.Hair.BUN:
			p.append([sph, base, false])
			p.append([sph, _tf(Vector3(0, 0.11 if not capped else 0.04, 0.105 if not capped else 0.135), Vector3.ONE * 0.05), false])
		Looks.Hair.MOHAWK:
			for i in 10:
				var th := -0.7 + 2.5 * float(i) / 9.0
				var at := Vector3(0, cos(th) * 0.135 + 0.012, sin(th) * 0.135 + 0.01)
				p.append([sph, Transform3D(Basis(Vector3.RIGHT, th) * Basis.from_scale(Vector3(0.026, 0.075 - 0.025 * absf(th - 0.4), 0.045)), at), at.y > 0.07])
		Looks.Hair.MULLET:
			p.append([sph, base, false])
			p.append([sph, _tf(Vector3(0, -0.085, 0.085), Vector3(0.105, 0.14, 0.06)), false])
		Looks.Hair.DREADS:
			p.append([sph, base, false])
			for i in 13:
				var az := deg_to_rad(-115.0 + 230.0 * float(i) / 12.0)
				var at := Vector3(sin(az) * 0.112, -0.07, cos(az) * 0.112 + 0.012)
				var tilt := Vector3(-cos(az) * 0.15, 0, sin(az) * 0.15)
				p.append([_unit_capsule, _tf(at, Vector3(0.042, 0.11, 0.042), tilt), false])
	var parts: Array = []
	for e in p:
		if capped and e[2]:
			continue  # under a cap: nothing on the crown
		parts.append([e[0], e[1]])
	_merged(parts, Looks.hair_color(look))


func _build_beard() -> void:
	_parts_meshes()
	var kind := int(look["beard"])
	if kind == Looks.Beard.NONE:
		return
	var hair := Looks.hair_color(look)
	var skin := Looks.skin(look)
	# The lower half of an ellipsoid round the jaw (a dome turned upside down).
	var jaw := Transform3D(Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(0.118, 0.13, 0.122)), Vector3(0, -0.005, -0.008))
	var moustache := [_unit_capsule, _tf(Vector3(0, -0.052, -0.121), Vector3(0.024, 0.036, 0.024), Vector3(0, 0, PI * 0.5))]
	match kind:
		Looks.Beard.STUBBLE:
			_merged([[_unit_dome, jaw]], skin.lerp(hair, 0.22))
		Looks.Beard.MOUSTACHE:
			_merged([moustache], hair)
		Looks.Beard.GOATEE:
			_merged([moustache, [_unit_sphere, _tf(Vector3(0, -0.105, -0.095), Vector3(0.035, 0.032, 0.03))]], hair)
		Looks.Beard.SHORT:
			jaw = jaw.scaled_local(Vector3(1.03, 1.03, 1.03))
			_merged([[_unit_dome, jaw], moustache], hair.lerp(skin, 0.15))
		Looks.Beard.FULL:
			jaw = jaw.scaled_local(Vector3(1.05, 1.06, 1.05))
			_merged([[_unit_dome, jaw], moustache, [_unit_sphere, _tf(Vector3(0, -0.12, -0.06), Vector3(0.085, 0.07, 0.075))]], hair)


func _build_headwear() -> void:
	_parts_meshes()
	var kind := int(look["head"])
	var c := Looks.kit(look, "accent")
	var band := [_unit_disc, _tf(Vector3(0, 0.06, 0.004), Vector3(0.128, 0.032, 0.132))]
	var front_visor := [_unit_disc, _tf(Vector3(0, 0.048, -0.14), Vector3(0.088, 0.012, 0.075), Vector3(-0.12, 0, 0))]
	match kind:
		Looks.Head.CAP:
			_merged([[_unit_dome, _tf(Vector3(0, 0.045, 0.006), Vector3(0.127, 0.1, 0.131))], front_visor], c)
		Looks.Head.CAP_BACK:
			var back_visor := [_unit_disc, _tf(Vector3(0, 0.05, 0.142), Vector3(0.088, 0.012, 0.075), Vector3(0.12, 0, 0))]
			_merged([[_unit_dome, _tf(Vector3(0, 0.045, 0.006), Vector3(0.127, 0.1, 0.131))], back_visor], c)
		Looks.Head.HEADBAND:
			_merged([band], c)
		Looks.Head.VISOR:
			_merged([band, front_visor], c)


# --- Body (ATHLETE / TOON) -----------------------------------------------------------
# Each body part is one mesh turned on a lathe along the bone: a profile of rings
# [t along the bone 0..1, radius, colour]. Two rings at the same t make a hem (a sleeve,
# the shorts' leg, a sock). Colours come from the look, so every combination of skin,
# kit and accent works; the head (hair, beard, headwear) is the same for every body.

var _hand_scale := Vector3.ONE
var _joints := {}               # knee / elbow balls that close the gap between two limbs


func _set_joint(name: String, at: Vector3) -> void:
	if _joints.has(name):
		(_joints[name] as MeshInstance3D).position = at


func _build_body() -> void:
	var skin := Looks.skin(look)
	var shirt := Looks.kit(look, "shirt")
	var shorts := Looks.kit(look, "shorts")
	var accent := Looks.kit(look, "accent")
	var white := Color(0.96, 0.96, 0.96)
	var sock := Color(0.97, 0.97, 0.97)
	var sole := Color(0.86, 0.86, 0.84)
	var toon := _body == Body.TOON
	var k := 1.14 if toon else 1.0          # chunkier limbs
	var hk := 1.4 if toon else 1.0          # bigger hands
	var fk := 1.3 if toon else 1.0          # bigger feet
	for i in 2:
		# Thigh, hip -> knee: the shorts' leg over the top 45%, then the bare thigh
		# tapering to the knee.
		_lathe_bone("thigh%d" % i, THIGH, [
			[0.0, 0.0, shorts], [0.03, 0.07 * k, shorts], [0.1, 0.09 * k, shorts], [0.44, 0.088 * k, shorts],
			[0.44, 0.074 * k, skin], [0.65, 0.068 * k, skin], [0.92, 0.054 * k, skin], [0.97, 0.045 * k, skin], [1.0, 0.0, skin]])
		# Shin, knee -> ankle: the calf, then a white sock from just under it.
		_lathe_bone("shin%d" % i, SHIN, [
			[0.0, 0.0, skin], [0.03, 0.05 * k, skin], [0.3, 0.06 * k, skin], [0.58, 0.05 * k, skin],
			[0.66, 0.047 * k, skin], [0.66, 0.05 * k, sock], [0.95, 0.04 * k, sock], [1.0, 0.0, sock]])
		# Sneaker, heel -> toe, flat, with a stripe in the accent colour.
		_lathe_bone("shoe%d" % i, 0.19, [
			[0.0, 0.0, sole], [0.05, 0.054 * fk, white], [0.38, 0.062 * fk, white], [0.38, 0.064 * fk, accent],
			[0.5, 0.064 * fk, accent], [0.5, 0.062 * fk, white], [0.85, 0.052 * fk, white], [1.0, 0.0, white]], 0.6)
	var hr := 0.118 if toon else 0.13      # the toon shirt covers the top of the shorts
	_lathe_bone("hips", 0.2, [
		[0.0, 0.0, shorts], [0.0, 0.1 * k, shorts], [0.25, hr * k, shorts], [0.75, hr * k, shorts], [1.0, 0.1 * k, shorts], [1.0, 0.0, shorts]])
	# Waist (pelvis -> mid trunk) and chest (mid trunk -> shoulders): narrow waist,
	# broad chest, a little shoulder slope; flattened front to back by _set_torso.
	_lathe_bone("waist", 0.3, [
		[0.0, 0.0, shirt], [0.0, 0.125 * k, shirt], [0.5, 0.13 * k, shirt], [1.0, 0.142 * k, shirt], [1.0, 0.0, shirt]])
	if toon:
		_lathe_bone("chest", 0.25, [
			[0.0, 0.0, shirt], [0.0, 0.125 * k, shirt], [0.35, 0.133 * k, shirt], [0.62, 0.16 * k, shirt],
			[0.8, 0.172 * k, shirt], [0.92, 0.16 * k, shirt], [0.98, 0.13 * k, shirt], [1.0, 0.09 * k, shirt], [1.0, 0.0, shirt]])
	else:
		_lathe_bone("chest", 0.25, [
			[0.0, 0.0, shirt], [0.0, 0.145 * k, shirt], [0.45, 0.17 * k, shirt], [0.8, 0.175 * k, shirt],
			[0.95, 0.15 * k, shirt], [1.0, 0.11 * k, shirt], [1.0, 0.0, shirt]])
	# Shoulders, left -> right: the deltoids bulge at the ends, in the shirt.
	_lathe_bone("shoulders", 0.4, [
		[0.0, 0.0, shirt], [0.02, 0.06 * k, shirt], [0.12, 0.07 * k, shirt], [0.3, 0.062 * k, shirt],
		[0.7, 0.062 * k, shirt], [0.88, 0.07 * k, shirt], [0.98, 0.06 * k, shirt], [1.0, 0.0, shirt]])
	# Neck with the shirt's collar round its base.
	var collar := 0.12 if toon else 0.28   # the toon collar stays under the shirt's top
	_lathe_bone("neck", 0.16, [[0.0, 0.0, shirt], [0.0, 0.085 * k, shirt], [collar, 0.07 * k, shirt],
		[collar, 0.058 * k, skin], [1.0, 0.05 * k, skin], [1.0, 0.0, skin]])
	for side in ["r", "l"]:
		# Upper arm: a short sleeve over the top half, then the bare arm to the elbow.
		_lathe_bone("upper_" + side, UPPER_ARM, [
			[0.0, 0.0, shirt], [0.04, 0.06 * k, shirt], [0.2, 0.066 * k, shirt], [0.5, 0.062 * k, shirt],
			[0.5, 0.048 * k, skin], [0.75, 0.046 * k, skin], [0.97, 0.04 * k, skin], [1.0, 0.0, skin]])
		# Forearm: muscle near the elbow, slim wrist, a wristband in the accent colour.
		_lathe_bone("fore_" + side, FOREARM, [
			[0.0, 0.0, skin], [0.04, 0.04 * k, skin], [0.3, 0.046 * k, skin], [0.72, 0.036 * k, skin],
			[0.72, 0.043 * k, accent], [0.94, 0.042 * k, accent], [0.94, 0.032 * k, skin], [1.0, 0.0, skin]])
	# Knees and elbows: a ball as wide as the limb there, so a bent joint stays closed.
	for i in 2:
		_joint_ball("knee%d" % i, 0.052 * k, skin)
	for side in ["r", "l"]:
		_joint_ball("elbow_" + side, 0.041 * k, skin)
	# A mitten-shaped hand pointing along the forearm (see _place_hand).
	_hand_scale = Vector3(0.82, 1.15, 0.62) * hk
	_hand_r = _sphere(0.05, skin)
	_hand_l = _sphere(0.05, skin)
	# Parts that sit inside the chest's outline: their own outline would draw lines
	# across the shirt.
	for part in ["shoulders", "neck", "waist"]:
		_no_outline(_bones[part])
	if toon:
		_bones["waist"].visible = false   # the chest is one piece down to the pelvis


func _joint_ball(name: String, r: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(c)
	_model.add_child(mi)
	_joints[name] = mi


func _lathe_bone(bone: String, ref: float, prof: Array, flat := 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _lathe(ref, prof, 22 if _body == Body.TOON else 14)
	mi.material_override = _body_mat()
	mi.set_meta("ref", ref)
	if flat != 1.0:
		mi.set_meta("flat", flat)
	_model.add_child(mi)
	_bones[bone] = mi


## The profile turned round +Y, centred on the origin, with vertex colours.
static func _lathe(len: float, prof: Array, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := prof.size()
	for i in n:
		var t: float = prof[i][0]
		var r: float = prof[i][1]
		# The slope of the profile around this ring gives the normal's tilt.
		var ia := maxi(i - 1, 0)
		var ib := mini(i + 1, n - 1)
		var dy: float = (float(prof[ib][0]) - float(prof[ia][0])) * len
		var dr: float = float(prof[ib][1]) - float(prof[ia][1])
		for j in segs + 1:
			var a := TAU * float(j) / float(segs)
			var rad := Vector3(cos(a), 0.0, sin(a))
			var nrm := Vector3(0, -1.0 if t < 0.5 else 1.0, 0)
			if r > 0.0001 and absf(dy) > 0.0001:
				nrm = (rad - Vector3(0, dr / dy, 0)).normalized()
			elif r > 0.0001:
				nrm = (rad + nrm * 0.6).normalized()
			st.set_color(prof[i][2])
			st.set_normal(nrm)
			st.add_vertex(rad * r + Vector3(0, (t - 0.5) * len, 0))
	for i in n - 1:
		for j in segs:
			var a0 := i * (segs + 1) + j
			var b0 := a0 + segs + 1
			st.add_index(a0)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(b0 + 1)
			st.add_index(b0)
	return st.commit()


static var _toon_outline: StandardMaterial3D


## The material for vertex-coloured body parts.
func _body_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 0.75
	_toonify(m)
	return m


## TOON: flat bands of light and a dark outline (the back faces of a slightly grown copy).
func _toonify(m: StandardMaterial3D) -> void:
	if _body != Body.TOON:
		return
	# Soft light that wraps round the form (no hard bands), a small toon highlight, a
	# light rim, and a thin even outline.
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.55
	m.rim_enabled = true
	m.rim = 0.55
	m.rim_tint = 0.4
	if _toon_outline == null:
		_toon_outline = StandardMaterial3D.new()
		_toon_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_toon_outline.albedo_color = Color(0.13, 0.1, 0.18)
		_toon_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_toon_outline.grow = true
		_toon_outline.grow_amount = 0.007
	m.next_pass = _toon_outline


## Small face details (eyes, nose, ears) without the TOON outline: on something that
## small it would draw a ring like a pair of glasses.
## Fewer draw calls for the same look (docs/PERFORMANCE.md): parts too small to matter
## at the camera's distance (eyes, ears, nose, hands, wrist bands) cast no shadow, the
## smallest also lose the outline pass (on a copy of their material: it may be shared);
## the dust under the feet never casts a shadow. Two players drew ~110 calls a frame.
const SMALL_NO_SHADOW := 0.25
const SMALL_NO_OUTLINE := 0.22


func _lighten() -> void:
	if _model == null:
		return
	for n in _model.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g is CPUParticles3D or g is GPUParticles3D:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var sz := (g.get_aabb().size * g.global_transform.basis.get_scale()).length()
		if sz >= SMALL_NO_SHADOW:
			continue
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mi := g as MeshInstance3D
		if mi and sz < SMALL_NO_OUTLINE and mi.material_override is StandardMaterial3D and (mi.material_override as StandardMaterial3D).next_pass:
			mi.material_override = mi.material_override.duplicate()
			(mi.material_override as StandardMaterial3D).next_pass = null


func _no_outline(mi: MeshInstance3D) -> MeshInstance3D:
	var m := mi.material_override as StandardMaterial3D
	if m:
		m.next_pass = null
	return mi


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
	else:
		_toonify(m)
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
