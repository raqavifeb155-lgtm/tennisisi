class_name AthleteCasual
## The hero walking around the club (stream H): no racket, hands free - a calm walk at a
## slow speed and a jog with the arms pumping at a fast one. Athlete keeps all the
## stroke animation; this only reshapes its pose inputs when the node has the meta
## "casual" set (Club sets it on the player while he walks the club). One hook line in
## Athlete._process: `amt = AthleteCasual.shape(self, delta, speed, amt)`.
##
## The feet are Athlete's own gait (stride 0.4 m x amt, a lift), so this picks the
## stride and the cadence that match the ground speed (no skating on the spot), and
## hands the arms their own swing: opposite to the legs, bent at the elbow on the jog.

const WALK_TO_JOG := Vector2(1.8, 4.0)      # speeds (m/s) where the walk turns into a jog


## Whether a node walks casually.
static func is_on(a: Node) -> bool:
	return a.has_meta("casual") and bool(a.get_meta("casual"))


## Adjusts the athlete's pose inputs for this frame; returns the stride factor `amt`.
static func shape(a: Athlete, delta: float, speed: float, amt: float) -> float:
	var on := is_on(a)
	var racket: Node3D = a._racket
	if racket != null:
		var hidden := bool(a.get_meta("casual_hid", false))
		if on and not hidden:
			racket.visible = false
			a.set_meta("casual_hid", true)
		elif not on and hidden:
			racket.visible = true
			a.set_meta("casual_hid", false)
	if not on:
		return amt
	var k := 1.0 - exp(-10.0 * delta)
	var jog := clampf((speed - WALK_TO_JOG.x) / (WALK_TO_JOG.y - WALK_TO_JOG.x), 0.0, 1.0)
	var moving := smoothstep(0.15, 0.9, speed)
	# The stride and the cadence that fit the speed: feet swing +-0.4 m x amt, a foot
	# stays on the ground for half a cycle, so rate = pi * v / (0.8 * amt).
	var stride_amt := lerpf(0.62, 1.2, jog) * moving
	if stride_amt > 0.05:
		var rate := clampf(PI * speed / (0.8 * stride_amt), 3.0, 17.0)
		# Athlete advanced the phase at its own sprint cadence this frame; replace that.
		a._run_phase += delta * (rate - (5.0 + speed * 2.2))
	a._stance = 0.0                       # feet under the shoulders, not the ready stance
	a._hop = 1.0
	a._twirl = 0.0
	a._twirl_t = -1.0
	var lean := jog * 0.05
	a._crouch = lerpf(a._crouch, 0.015 + lean * 0.6, k)
	var s := sin(a._run_phase)
	var c := cos(a._run_phase)
	var breath := sin(a._alive_t * TAU * 0.25)
	# Arms: s > 0 is the right leg forward, so the left arm goes forward (and the right back).
	var right: Vector3
	var left: Vector3
	var stand_y := 0.80 + 0.008 * breath
	var walk_swing := 0.17 * moving
	var walk_r := Vector3(0.33, stand_y + 0.02 * absf(s) * moving, 0.0 + walk_swing * s)
	var walk_l := Vector3(-0.33, stand_y + 0.02 * absf(s) * moving, 0.0 - walk_swing * s)
	# Jog: forearms bent, hands pump between the hip and the chest, drawing a small oval.
	var jog_r := Vector3(0.25 - 0.05 * maxf(-s, 0.0), 1.10 - 0.11 * s, -0.06 + 0.34 * s + 0.03 * c)
	var jog_l := Vector3(-0.25 + 0.05 * maxf(s, 0.0), 1.10 + 0.11 * s, -0.06 - 0.34 * s - 0.03 * c)
	right = walk_r.lerp(jog_r, jog)
	left = walk_l.lerp(jog_l, jog)
	# Hard set: Athlete's own easing toward its racket pose runs just before this hook.
	a._hand = right
	a._lhand = left
	a._attach = 0.0
	return clampf(stride_amt, 0.0, 1.5)
