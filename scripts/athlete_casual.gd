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

const WALK_TO_JOG := Vector2(2.0, 3.8)      # speeds (m/s) where the walk turns into a jog


## The old coach (stream H-8): grey side-parted hair, a moustache, a cap, a navy polo, a
## whistle on a cord - and a slight stoop (see `shape`).
const ELDER_LOOK := {"skin": 2, "hair": 3, "hair_color": 10, "beard": 2, "head": 1, "shirt": 4, "shorts": 2, "accent": 1}


## Dresses an athlete as the old coach.
static func make_elder(a: Athlete, look := ELDER_LOOK) -> void:
	a.set_meta("elder", true)
	a.set_look(look)


## A child or a teenager: `size` 0.7..1.0 of the adult's height, with a bigger head and the
## limbs a little short for the body (the model's non-uniform scale; the poses and the
## strokes are the adult's, scaled with it, so nothing in the animation changes).
static func set_junior(a: Athlete, size: float) -> void:
	a.set_meta("junior", clampf(size, 0.7, 1.0))


## Brings the body in line with the metas "junior" and "elder": runs every frame from `shape`
## (cheap) and redoes its work when the model has been rebuilt (a new look).
static func _body(a: Athlete) -> void:
	var model: Node3D = a._model
	if model == null:
		return
	var jr := float(a.get_meta("junior", 1.0))
	var elder := bool(a.get_meta("elder", false))
	var stamp := "%d:%.2f:%d" % [model.get_instance_id(), jr, int(elder)]
	if a.get_meta("body_stamp", "") == stamp:
		return
	a.set_meta("body_stamp", stamp)
	model.scale = Vector3.ONE if jr >= 0.999 else Vector3(jr * 1.05, jr * 0.94, jr * 1.05)
	var head: Node3D = a._head
	if head != null and jr < 0.999:
		head.scale = head.scale * (1.0 + (1.0 - jr) * 1.6)   # a child's head is big
	if elder:
		var chest: Node3D = a._bones.get("chest")
		if chest != null:
			var whistle := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.035
			cap.height = 0.11
			whistle.mesh = cap
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.8, 0.2)
			whistle.material_override = mat
			whistle.position = Vector3(0.0, 0.08, -0.2)
			whistle.rotation = Vector3(0.0, 0.0, PI * 0.5)
			chest.add_child(whistle)
			var cord := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.008
			cm.bottom_radius = 0.008
			cm.height = 0.22
			cm.radial_segments = 4
			cm.rings = 0
			cord.mesh = cm
			var cmat := StandardMaterial3D.new()
			cmat.albedo_color = Color(0.1, 0.1, 0.12)
			cord.material_override = cmat
			cord.position = Vector3(0.0, 0.17, -0.19)
			chest.add_child(cord)


## Whether a node walks casually.
static func is_on(a: Node) -> bool:
	return a.has_meta("casual") and bool(a.get_meta("casual"))


## Adjusts the athlete's pose inputs for this frame; returns the stride factor `amt`.
static func shape(a: Athlete, delta: float, speed: float, amt: float) -> float:
	if a.has_meta("junior") or a.has_meta("elder"):
		_body(a)
		if bool(a.get_meta("elder", false)) and a._mode == 0 and a._down < 0.0:
			a._pitch = lerpf(a._pitch, 0.2, 1.0 - exp(-4.0 * delta))   # a slight stoop
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
