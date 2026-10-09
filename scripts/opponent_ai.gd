class_name OpponentAI
extends Node
## CPU opponent: BALL PREDICTION -> POSITIONING -> SHOT/TARGET SELECTION -> EXECUTION.
## Uses the same flight model as the real ball to find a reachable contact point,
## the same quality model as the player, and tactics chosen once per hit by ShotPlanner
## from the situation and the opponent's play style (Opponents.PLAY_STYLES): approach a
## short ball and volley at the net, drop shot a player camped deep, lob or pass a net
## rusher, go for the open court, play safe when stretched. It reads the player's habits
## (PlayerModel: serve directions, the weaker wing) and misses under pressure (stretched,
## a heavy ball) more than on easy balls. Skill changes behaviour, not just speed.

const CPU := 1  # matches Main.Who.CPU

var game: Node
var me: Athlete
var ball: Ball
var rng := RandomNumberGenerator.new()

var _reaction := 0.0
var _plan_timer := 0.0
var _goal := Vector3(0, 0, -12.6)
var _recovery := Vector3(0, 0, -12.6)
var _prev_rel := INF
var _swung := false  # the visible swing at the incoming ball has started

# What the CPU has learned about the player's serve
var _serve_speeds: Array[float] = []

## Difficulty modifier "Быстрые ноги" (Tournament.MODIFIERS).
var speed_mult := 1.0
var _drop_memory := 0.0

## The player's habits this match (scripts/ai/player_model.gd).
var model := PlayerModel.new()

## The play style (Opponents.PLAY_STYLES) and its id.
var style: Dictionary = Opponents.PLAY_STYLES[Opponents.DEFAULT_STYLE]
var style_id := Opponents.DEFAULT_STYLE

## The opponent's stats 1..10 (Opponents.stats; D-5): every stroke, the serve, the legs.
const SLOW_BALL := 3.0           # m/s along the ground: a drop's hover, not a rally ball (D-7)
const SLOW_AHEAD := 0.4           # m: the ball may be this far in front of the contact plane

var ratings: Dictionary = Opponents.stats({}, 0.5)
var spared := 0.0                 # what a beginner is spared (Opponents.spared), set with the profile
var _base_skill := 0.5            # the profile's skill: Tuning.ai_skill above / below it
                                  # (modifiers, tiredness) shifts every stat a little

## Decisions this session, for the bot metrics (AiMetrics prints report()).
var stats := {}

const NET_POS_FAR := 4.8          # how close to the net it closes in after an approach
const NET_POS_NEAR := 3.8         # (weak .. strong)
const FORECOURT_Z := 8.0          # in front of this it looks to volley before the bounce

var _at_net := false              # came in after the last shot: volleys the next ball
var _pos_at_player_hit := Vector3(0, 0, -12.6)
var _stretch := 0.0               # this shot: how far it had to run (0..1)
var _risk := 0.0                  # this shot: the planner's extra risk
var _wing_t := 0.5                # this shot: the wing's stat (0..1)
var _last_player_side := 0        # the wing of the player's last rally ball
var _player_contact := Vector3(0, 0, 12.6)  # where the player hit their last ball from
var _player_q := 0.7              # and how well


func setup(g: Node, athlete: Athlete, b: Ball) -> void:
	game = g
	me = athlete
	ball = b
	rng.randomize()
	var ge := get_tree().root.get_node_or_null("GameEvents") if is_inside_tree() else null
	if ge:
		ge.bounce.connect(_on_bounce)
		ge.match_started.connect(func(i: Dictionary) -> void:
			new_match()
			var prof = i.get("profile", {})  # a stats dictionary: a random player, an academy pupil (AiProfile)
			set_profile(prof if prof is Dictionary and not prof.is_empty() else Opponents.find(String(i.get("opponent", "")))))
		ge.player_stroke.connect(_on_player_stroke)
		ge.point.connect(_on_point)


## A new opponent / match: forget what was learned about the player.
func new_match() -> void:
	model.reset()
	_serve_speeds.clear()
	_drop_memory = 0.0
	_at_net = false


## The opponent's profile (an Opponents.ROSTER entry; {} = the practice all-rounder).
func set_profile(opp: Dictionary) -> void:
	style_id = String(opp.get("play_style", Opponents.DEFAULT_STYLE))
	if not Opponents.PLAY_STYLES.has(style_id):
		style_id = Opponents.DEFAULT_STYLE
	style = Opponents.PLAY_STYLES[style_id]
	_base_skill = float(opp.get("skill", skill()))
	ratings = Opponents.stats(opp, _base_skill)
	spared = Opponents.spared()


## A stat as 0..1 (1 -> 0, 10 -> 1), moved by how far Tuning.ai_skill is from the
## profile's skill (a "Железный" modifier, tiredness from the stamina "health").
func stat(key: String) -> float:
	return clampf((float(ratings.get(key, 5)) - 1.0) / 9.0 + (skill() - _base_skill) - spared, 0.0, 1.0)


## The stamina stat as a multiplier of the stamina "health" a ball takes (MatchEffects):
## a weak tank drains 1.5x faster, the best one at 0.6x.
func stamina_mult() -> float:
	return lerpf(1.5, 0.6, stat("stamina"))


## The CPU's serve by the serve stat (Main._cpu_serve_hit): a weak server serves slow and
## to the middle of the box, a strong one hits the corners and the T, hard. `mult`: the
## "Бомбардир" modifier. Returns tx, tz, pace, top, side_spin.
func plan_serve(box_side: float, attempt: int, mult := 1.0) -> Dictionary:
	var t := stat("serve")
	if attempt == 1:
		var x: float
		var side_spin := 0.0
		# F-E: harder (up to 57 m/s = 205 km/h before the style) and nearer the lines: the T and the
		# sideline corner, not the middle of the box (the owner: the AI served worse than he did).
		var pace := lerpf(SERVE_PACE_WEAK, SERVE_PACE_BEST, t) * rng.randf_range(0.94, 1.04) * mult * serve_mult()
		if rng.randf() < lerpf(SERVE_CORNER_WEAK, SERVE_CORNER_BEST, t):
			var wide := rng.randf() < 0.5
			x = rng.randf_range(3.3, 3.85) if wide else rng.randf_range(0.3, 0.8)
			if wide and rng.randf() < 0.5:
				pace *= 0.88
				side_spin = 240.0 * -box_side  # slice curving out wide
		else:
			x = rng.randf_range(1.1, 1.7) if rng.randf() < 0.5 else rng.randf_range(2.4, 3.0)  # a body serve leans to a side, never the dead middle
		_count("serve_corner" if x < 1.0 or x > 2.8 else "serve_middle")
		return {"tx": box_side * x, "tz": rng.randf_range(lerpf(4.8, 5.3, t), 5.95), "pace": pace, "top": 120.0, "side_spin": side_spin}
	return {"tx": box_side * rng.randf_range(0.9, 2.6), "tz": rng.randf_range(4.2, 5.4), "pace": lerpf(26.0, 38.0, t), "top": 320.0, "side_spin": 0.0}


const SERVE_PACE_WEAK := 33.0     # m/s of the first serve by the serve stat (before the style): was 30 .. 50
const SERVE_PACE_BEST := 57.0
const SERVE_CORNER_WEAK := 0.2    # the share of first serves into a corner / the T: was 0.15 .. 0.85
const SERVE_CORNER_BEST := 0.92


## First serve pace multiplier of the play style (the "bomber" serves bigger).
func serve_mult() -> float:
	return float(style.get("serve", 1.0))


## The player's rally strokes and errors: which wing is weaker (PlayerModel).
func _on_player_stroke(info: Dictionary) -> void:
	if info.get("serve", false):
		_last_player_side = 0
		return
	_last_player_side = int(info.get("side", 1))
	_player_q = float(info.get("q", 0.7))
	_player_contact = game.player.position
	model.note_stroke(_last_player_side, _player_q)


func _on_point(info: Dictionary) -> void:
	var reason := String(info.get("reason", ""))
	if int(info.get("winner", 0)) == CPU and (reason == "OUT" or reason == "NET") and _last_player_side != 0 and int(info.get("rally", 0)) >= 2:
		model.note_error(_last_player_side)
	_last_player_side = 0


## The player's serve landed in the box: remember which way it went.
func _on_bounce(info: Dictionary) -> void:
	if not game.serve_flight or int(info.get("last_hitter", -1)) != 0:
		return
	var pos: Vector3 = info.get("pos", Vector3.ZERO)
	if Court.in_service_box(pos, -1, game.box_side, BallPhysics.RADIUS):
		model.note_serve(game.box_side, pos.x * game.box_side)


func skill() -> float:
	return Tuning.ai_skill


## Called when the player hits: reaction delay + split step.
func on_player_hit() -> void:
	_pos_at_player_hit = me.position
	_reaction = lerpf(0.30, 0.09, stat("speed"))
	_plan_timer = 0.0
	_prev_rel = INF
	_swung = false
	me.split_step()


## Called after the player serves: a big serve is read later.
func on_player_serve(kmh: float, underarm: bool) -> void:
	on_player_hit()
	# F-E: the returner reads the toss and the server's stance, so a serve is picked up sooner than a
	# rally ball (was 0.30 .. 0.09 s + up to 0.16 s for a big one): a big serve still costs a beat.
	_reaction = lerpf(0.24, 0.07, stat("speed")) + clampf((kmh - 150.0) / 500.0, 0.0, 0.09)
	_serve_speeds.append(kmh)
	if _serve_speeds.size() > 6:
		_serve_speeds.pop_front()
	_drop_memory = 1.0 if underarm else _drop_memory * 0.6


## Where to stand to return: deeper against big servers, closer after being caught
## by an underarm serve (that memory fades), with a little variety. Across: on the
## bisector of the server's widest and T serves (read from where the server stands),
## shaded toward the side they have been serving to this match (HANDOFF 9.4).
const RETURN_WIDE_X := 3.9        # the widest serve's bounce, across the box
const RETURN_T_X := 0.3           # the T serve's bounce
const RETURN_LEAN := 0.5          # 0 = on the T line .. 1 = on the wide line; 0.5 = the bisector
const RETURN_STEADY := 0.85       # F-E: the returner's error chance on a serve x this
const RETURN_READ := 0.30         # how far the read habit shifts that (x wide_bias); F-E: was 0.22


func receive_position(box_side: float) -> Vector3:
	var avg := 150.0
	if not _serve_speeds.is_empty():
		avg = 0.0
		for v in _serve_speeds:
			avg += v
		avg /= _serve_speeds.size()
	var depth := lerpf(12.1, 13.9, clampf((avg - 120.0) / 80.0, 0.0, 1.0))
	depth -= _drop_memory * 1.8
	depth += rng.randf_range(-0.35, 0.35)
	var srv: Vector3 = game.player.position
	# Where a serve along each line crosses our contact depth (it keeps its line after
	# the bounce, near enough).
	var land_z := -(Court.SERVICE_LINE - 0.8)
	var f := (-depth - srv.z) / (land_z - srv.z)
	var at_wide := srv.x + (box_side * RETURN_WIDE_X - srv.x) * f
	var at_t := srv.x + (box_side * RETURN_T_X - srv.x) * f
	var lean := clampf(RETURN_LEAN + RETURN_READ * model.wide_bias(box_side), 0.2, 0.8)
	var x := lerpf(at_t, at_wide, lean) + rng.randf_range(-0.2, 0.2)
	return Vector3(x, 0.0, -depth)


## How much of its contact quality a returner keeps against a serve of this speed (F-E). Big serves
## are blocked back rather than driven, but not framed: was 1.15 - (kmh - 120) / 130, floor 0.4, which
## left a 210 km/h serve 0.46 and a third of the returns flying anywhere. s: the wing's stat 0..1.
static func serve_return_factor(kmh: float, s: float) -> float:
	return clampf(1.15 - (kmh - 125.0) / 190.0, lerpf(0.52, 0.64, s), 1.0)


## How far the returner can stretch for a serve (a full lunge is the rally's REACH).
func return_reach() -> float:
	return lerpf(1.45, 1.75, stat("speed"))  # F-E: was 1.35 .. 1.6


## Top run speed by the speed stat (m/s), before the modifiers.
func run_speed() -> float:
	return lerpf(4.8, 7.2, stat("speed"))


## Called when the CPU itself hits (or feeds): plan the recovery position, at the net
## after an approach (it stays there for the volleys).
func on_cpu_hit(target_x: float, approach := false) -> void:
	_at_net = approach
	if approach:
		_recovery = Vector3(clampf(target_x * 0.35, -2.0, 2.0), 0.0, -lerpf(NET_POS_FAR, NET_POS_NEAR, stat("net")))
	else:
		_recovery = Vector3(clampf(target_x * 0.25, -1.5, 1.5), 0.0, -12.4)
	_goal = _recovery


func tick(delta: float, incoming: bool) -> void:
	me.max_speed = run_speed() * speed_mult
	if incoming:
		if _reaction > 0.0:
			_reaction -= delta
			me.move_input = me.move_input.lerp(Vector2.ZERO, 0.2)
		else:
			_plan_timer -= delta
			if _plan_timer <= 0.0:
				_plan_timer = 0.1
				_replan()
			_move_to(_goal)
		_anticipate_swing()
		_check_hit()
	else:
		_prev_rel = INF
		_move_to(_recovery)
		me.relax()


func _move_to(goal: Vector3) -> void:
	var d := Vector2(goal.x - me.position.x, goal.z - me.position.z)
	var dist := d.length()
	if dist < 0.05:
		me.move_input = Vector2.ZERO
		return
	me.move_input = d / dist * clampf(dist / 0.9, 0.0, 1.0)


func _replan() -> void:
	var pred := BallPhysics.predict(ball.state, 3.0, 1.0 / 60.0, 2)
	if pred.bounce_points.is_empty():
		return
	var b0 := pred.bounce_points[0]
	# Let clearly-out balls go (better players judge closer to the line).
	if game.bounces == 0 and not Court.is_in_singles(b0, -1, BallPhysics.RADIUS):
		var margin := maxf(absf(b0.x) - Court.SINGLES_HALF_WIDTH, -b0.z - Court.HALF_LENGTH)
		if b0.z > 0.0 or margin > lerpf(0.6, 0.05, skill()):
			_goal = _recovery
			return
	if game.bounces == 0 and (_at_net or me.position.z > -FORECOURT_Z) and _plan_volley(pred):
		return
	var start_i := pred.bounce_indices[0]
	var end_i := pred.points.size() - 1
	if pred.bounce_indices.size() > 1:
		end_i = pred.bounce_indices[1]
	if game.bounces >= 1:
		# Already bounced on our side: the next predicted bounce is the second one.
		start_i = 0
		end_i = pred.bounce_indices[0]
	var best := Vector3.INF
	var best_side := 1
	var fallback := Vector3.INF
	var fallback_short := INF
	for i in range(start_i, end_i):
		var p := pred.points[i]
		var t := pred.times[i]
		if p.y < 0.3 or p.y > 1.7:
			continue
		var descending := i + 1 < pred.points.size() and pred.points[i + 1].y < p.y
		for side in [1, -1]:
			var stance := me.stance_for(p, side)
			if stance.z > -0.8:
				continue
			var need := (stance - me.position).length() / me.max_speed + 0.12
			if need <= t and (descending or p.y < 1.15):
				best = stance
				best_side = side
				break
			if need - t < fallback_short:
				fallback_short = need - t
				fallback = stance
		if best != Vector3.INF:
			break
	if best != Vector3.INF:
		_goal = best
		me.prepare(best_side)
	elif fallback != Vector3.INF:
		_goal = fallback


## At the net: the earliest point before the bounce it can get to (a volley, or a smash
## of a short lob). False if none: then it plays the ball after the bounce.
func _plan_volley(pred: BallPhysics.Prediction) -> bool:
	var end_i := pred.bounce_indices[0]
	for i in range(0, end_i):
		var p := pred.points[i]
		if p.z > -1.2 or p.y < 0.35 or p.y > 2.6:
			continue
		for side in [1, -1]:
			var stance := me.stance_for(p, side)
			if stance.z > -0.8:
				continue
			if (stance - me.position).length() / me.max_speed + 0.08 <= pred.times[i]:
				_goal = stance
				me.prepare(side)
				return true
	return false


## Starts the visible swing a beat before the ball reaches the hitting plane, so the
## racket comes through the ball instead of appearing at the contact point. Only the
## look: the shot itself is still played in _check_hit().
func _anticipate_swing() -> void:
	if _swung or game.serve_flight or me.is_swinging() or me.is_down():
		return
	var v := ball.state.vel
	if v.z >= -0.5:
		return
	var t := (ball.state.pos.z - (me.position.z + Athlete.CONTACT_FORWARD)) / -v.z
	if t <= 0.0 or t > Athlete.SWING_TO_CONTACT + 0.02:
		return
	var p := ball.state.pos + v * t + Vector3(0.0, -4.9 * t * t, 0.0)
	var flat_d := Vector2(p.x - me.position.x, p.z - me.position.z).length()
	if flat_d > Athlete.REACH or p.y < 0.1 or p.y > 2.5:
		return
	_swung = true
	me.swing(1 if me.lateral_of(p) >= 0.0 else -1, t, p, Athlete.Style.TOPSPIN)


func _check_hit() -> void:
	var plane_z := me.position.z + Athlete.CONTACT_FORWARD
	var rel := ball.state.pos.z - plane_z
	if _prev_rel > 0.0 and rel <= 0.0 and ball.state.vel.z < 0.0 and not game.serve_flight:
		var bp := ball.state.pos
		var flat_d := Vector2(bp.x - me.position.x, bp.z - me.position.z).length()
		if game.autoplay and game.rally == 1:
			print("    AI at serve cross: ball=(%.1f,%.2f,%.1f) me=(%.1f,%.1f) d=%.2f" % [bp.x, bp.y, bp.z, me.position.x, me.position.z, flat_d])
		# Returning serve there's no time to lunge fully: a little less reach, so wide or
		# fast serves can still be aces.
		var reach := return_reach() if game.rally == 1 else Athlete.REACH
		var top_h := 2.9 if game.bounces == 0 and me.position.z > -FORECOURT_Z else 2.5  # a smash at the net
		if flat_d <= reach and bp.y > 0.05 and bp.y < top_h:
			_hit(bp)
	elif _slow_ball_in_reach(rel):
		_hit(ball.state.pos)
	_prev_rel = rel


## D-7: a drop shot dies in front of the net and hovers (backspin holds it back to ~0.4 m/s), so
## the contact plane, which only the ball crossing it can trigger, is reached by the runner
## after the ball has crept to a stop: it ran up and did not swing, the second bounce won the
## point. A slow ball already bounced and within reach is played when it is at the plane, or a
## little ahead of it (the body is in front of the ball: the arm reaches).
func _slow_ball_in_reach(rel: float) -> bool:
	if game.serve_flight or game.bounces < 1 or game.rally < 2 or me.is_down():
		return false
	var v := ball.state.vel
	if Vector2(v.x, v.z).length() > SLOW_BALL or rel > SLOW_AHEAD:
		return false
	var bp := ball.state.pos
	if bp.y < 0.2 or bp.y > 1.5 or bp.z > -0.8:
		return false
	return Vector2(bp.x - me.position.x, bp.z - me.position.z).length() <= Athlete.REACH


func _hit(bp: Vector3) -> void:
	var lateral := me.lateral_of(bp)
	var side := 1 if lateral >= 0.0 else -1
	# The wing's stat plays this ball (D-5): timing, contact, pace, errors.
	var s := stat("forehand" if side > 0 else "backhand")
	_wing_t = s
	var t_err := rng.randfn(0.0, lerpf(0.095, 0.03, s))
	var tq: Array = game.timing_quality(t_err)
	var q: float = tq[0] * game.position_quality(lateral, minf(bp.y, 1.2) if bp.y > 2.2 else bp.y) * game.movement_quality(me.velocity.length())
	q *= lerpf(0.72, 0.96, s)  # the CPU never plays quite as cleanly as a perfect swipe
	if game.rally == 1:
		# Returning serve: big serves are only blocked back.
		q *= serve_return_factor(game.last_serve_kmh, s)
	# How far it had to run for this ball: errors grow with it (error_chance).
	var run := Vector2(bp.x - _pos_at_player_hit.x, bp.z - _pos_at_player_hit.z).length() - Athlete.IDEAL_LATERAL
	_stretch = clampf((run - 1.5) / 3.5, 0.0, 1.0)

	# Out of the air in the forecourt = a volley (a high one is smashed); a high ball
	# taken early from the back is just a rally ball.
	var volley: bool = game.bounces == 0 and me.position.z > -FORECOURT_Z
	var smash := volley and bp.y > 2.2
	if volley:
		q = minf(q * lerpf(0.8, 1.08, stat("net")), 1.0)
	var plan := ShotPlanner.choose({
		"q": q, "skill": s, "me": me.position, "contact": bp, "player": game.player.position,
		"player_vel": game.player.velocity, "volley": volley, "rally": game.rally,
		"player_contact": _player_contact, "player_q": _player_q,
		"short": not volley and game.rally >= 2 and bp.z > -9.6,
		"bh_x": -signf(game.player.right().x), "bh_weak": model.backhand_weakness(),
		"net_k": lerpf(0.4, 1.8, stat("net")),
	}, style, rng)
	if smash:
		plan["kind"] = "smash"
		plan["pace"] = lerpf(28.0, 36.0, s)
		plan["top"] = 40.0
		plan["lob"] = false
		plan["drop"] = false
	var tx: float = plan["tx"]
	var tz: float = plan["tz"]
	var pace: float = plan["pace"]
	var top: float = plan["top"]
	var lob: bool = plan["lob"]
	var drop: bool = plan["drop"]
	_risk = float(plan["risk"])
	if game.rally == 1 and rng.randf() < clampf((0.55 - q) * 1.5, 0.0, 0.6):
		# Overpowered by the serve: a frame shot that flies anywhere.
		tx = rng.randf_range(-7.0, 7.0)
		tz = rng.randf_range(8.0, 15.0)
		pace = rng.randf_range(14.0, 22.0)
		top = 60.0
		lob = false
		drop = false
		plan["kind"] = "framed"
		plan["approach"] = false
	_count(plan["kind"])
	if plan["approach"] and not _at_net:
		_count("came_in")
	var look := Athlete.Style.SMASH if smash else (Athlete.Style.DROP if drop else (Athlete.Style.SLICE if q < 0.45 else Athlete.Style.TOPSPIN))
	me.swing(side, 0.02, bp, look)
	game.execute_shot(CPU, me, bp, Vector3(tx, BallPhysics.RADIUS, tz), pace, top, q, t_err, side, lob, 0.0, drop)
	on_cpu_hit(tx, plan["approach"])


## The chance this shot is simply missed (Main.error_chance asks the AI for its own):
## rare on an easy ball, much more when stretched or under a heavy ball, plus the risk
## of what it went for and the play style's appetite for it. q: contact quality;
## incoming: the ball's speed (m/s).
func error_chance(q: float, incoming: float, stretch := -1.0) -> float:
	var s := _wing_t
	var st := _stretch if stretch < 0.0 else stretch
	var heavy := clampf((incoming - 18.0) / 18.0, 0.0, 1.0)
	var base := lerpf(0.045, 0.008, s) * (1.0 - q * 0.6)          # unforced: rare
	var forced := (0.4 * st + 0.35 * heavy * (1.0 - q * 0.5)) * lerpf(0.4, 0.16, s)
	var poor := pow(1.0 - q, 2.0) * 0.26
	# x0.85: the AI's contact model is harsher than a thumb's (as before D-3).
	var p := (base + forced + poor + _risk) * float(style.get("risk", 1.0)) * 0.85
	if game != null and int(game.get("rally")) == 1:
		p *= RETURN_STEADY  # F-E: a returner is set for the serve (it blocks it back), a rally ball finds it moving
	p = clampf(p, 0.0, 0.6)
	if stretch < 0.0:
		# Bot metrics: this model against the old one (Main.error_chance before D-3).
		var pressure := clampf((incoming - 16.0) / 22.0, 0.0, 1.0)
		var old := (lerpf(0.09, 0.02, s) * (1.0 - q * 0.7) + pressure * (1.0 - q) * lerpf(0.6, 0.35, s) + pow(1.0 - q, 2.0) * 0.35) * 0.8
		stats["err_n"] = int(stats.get("err_n", 0)) + 1
		stats["err_new"] = float(stats.get("err_new", 0.0)) + p
		stats["err_old"] = float(stats.get("err_old", 0.0)) + clampf(old, 0.0, 0.6)
		stats["stretch"] = float(stats.get("stretch", 0.0)) + st
	return p


func _count(key: String) -> void:
	stats[key] = int(stats.get(key, 0)) + 1


## One line for the bot metrics: the style and how often each decision was taken.
func report() -> String:
	var total := 0
	for k in ShotPlanner.KINDS:
		total += int(stats.get(k, 0))
	var parts := PackedStringArray()
	for k in ShotPlanner.KINDS + ["smash", "framed", "came_in"]:
		if stats.has(k):
			parts.append("%s %d (%.0f%%)" % [k, stats[k], 100.0 * stats[k] / maxf(total, 1)])
	var n := maxf(stats.get("err_n", 0), 1)
	parts.append("| error chance %.3f (old model %.3f), stretch %.2f" % [stats.get("err_new", 0.0) / n, stats.get("err_old", 0.0) / n, stats.get("stretch", 0.0) / n])
	return "ai style %s: %s" % [style_id, "  ".join(parts)]
