class_name OpponentAI
extends Node
## CPU opponent: BALL PREDICTION -> POSITIONING -> SHOT/TARGET SELECTION -> EXECUTION.
## Uses the same flight model as the real ball to find a reachable contact point,
## the same quality model as the player, and simple tactics (hit away from the
## player, play safe when stretched). Skill changes behaviour, not just speed.

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


func setup(g: Node, athlete: Athlete, b: Ball) -> void:
	game = g
	me = athlete
	ball = b
	rng.randomize()


func skill() -> float:
	return Tuning.ai_skill


## Called when the player hits: reaction delay + split step.
func on_player_hit() -> void:
	_reaction = lerpf(0.30, 0.10, skill())
	_plan_timer = 0.0
	_prev_rel = INF
	me.split_step()


## Called when the CPU itself hits (or feeds): plan the recovery position.
func on_cpu_hit(target_x: float) -> void:
	_recovery = Vector3(clampf(target_x * 0.25, -1.5, 1.5), 0.0, -12.4)
	_goal = _recovery


func tick(delta: float, incoming: bool) -> void:
	me.max_speed = lerpf(5.0, 6.8, skill())
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


func _check_hit() -> void:
	var plane_z := me.position.z + Athlete.CONTACT_FORWARD
	var rel := ball.state.pos.z - plane_z
	if _prev_rel > 0.0 and rel <= 0.0 and ball.state.vel.z < 0.0 and not game.serve_flight:
		var bp := ball.state.pos
		var flat_d := Vector2(bp.x - me.position.x, bp.z - me.position.z).length()
		if flat_d <= Athlete.REACH and bp.y > 0.05 and bp.y < 2.5:
			_hit(bp)
	_prev_rel = rel


func _hit(bp: Vector3) -> void:
	var s := skill()
	var lateral := me.lateral_of(bp)
	var side := 1 if lateral >= 0.0 else -1
	var t_err := rng.randfn(0.0, lerpf(0.10, 0.04, s))
	var tq: Array = game.timing_quality(t_err)
	var q: float = tq[0] * game.position_quality(lateral, bp.y) * game.movement_quality(me.velocity.length())
	q *= lerpf(0.72, 0.92, s)  # the CPU never plays quite as cleanly as a perfect swipe

	var player_x: float = game.player.position.x
	var tx: float
	var tz: float
	var pace: float
	var top: float
	if q < 0.45:
		# Stretched: high, deep, central — buy time.
		tx = rng.randf_range(-1.5, 1.5)
		tz = rng.randf_range(8.0, 10.0)
		pace = rng.randf_range(18.0, 21.0)
		top = 240.0
	else:
		var open_side := -signf(player_x) if absf(player_x) > 0.8 else (1.0 if rng.randf() < 0.5 else -1.0)
		if rng.randf() > 0.35 + s * 0.6:
			open_side = -open_side
		tx = open_side * lerpf(1.2, 3.6, rng.randf() * (0.4 + s * 0.6))
		tz = lerpf(6.8, 10.8, clampf(rng.randf_range(0.3, 1.0) * (0.55 + 0.45 * s), 0.0, 1.0))
		pace = lerpf(22.0, 32.0, s) * rng.randf_range(0.88, 1.1)
		top = rng.randf_range(160.0, 300.0)
	var lob := false
	var player_z: float = game.player.position.z
	if player_z < 6.5 and q >= 0.45:
		# Player at the net: lob over them, or pass down the open side hard.
		if rng.randf() < 0.3 + 0.35 * s:
			lob = true
			tx = rng.randf_range(-2.5, 2.5)
			tz = rng.randf_range(9.0, 10.8)
			pace = 30.0
			top = 220.0
		else:
			tx = (-signf(player_x) if absf(player_x) > 0.3 else (1.0 if rng.randf() < 0.5 else -1.0)) * rng.randf_range(2.8, 3.5)
			tz = rng.randf_range(6.0, 9.0)
			pace *= 1.1
	me.swing(side, 0.02, bp.y)
	game.execute_shot(CPU, me, bp, Vector3(tx, BallPhysics.RADIUS, tz), pace, top, q, t_err, side, lob)
	on_cpu_hit(tx)
