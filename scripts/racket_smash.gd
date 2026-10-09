class_name RacketSmash
extends Node
## The "Разбить ракетку" mini-game (docs/superpowers/specs/2026-10-09-racket-smash.md): after
## a point lost to the player's own error the hero lifts the racket over his head in both
## hands and slams it into the court. Three swipes: up (the wind-up), down (the first blow),
## down (the racket breaks). The hand follows the finger; the strength of a swipe is the
## strength of the blow.
##
## This node only animates and reports: it drives the Athlete in its "smash" mode (arms,
## shoulders, knees from the poses below), shakes the camera, asks for a hit-stop, plays the
## sounds and throws the shards. The rules (when it is offered, what it gives and costs) are
## SmashHub's. It runs before the Athlete (process_priority) so the pose is never a frame late.
##
## The shards (6): three arcs of the rim, the handle with its throat, two scraps of string.
## They are made from the very mesh code of the worn racket (AthleteGear), fly on a plain
## ballistic path with a bounce, and go out after 2 s; the handle lies on the court for 10 s.

signal impact(blow: int, power: float)     # a blow reached the court (1 = the first)
signal broken(strength: float)             # the racket is in pieces
signal finished(was_broken: bool)          # the hero is back on his feet

enum S { IDLE, READY, RAISE, HELD, STRIKE, RECOIL, BREAK, AFTER, CANCEL, DONE }

const MIN_SWIPE := 0.07          # of the screen height: a shorter stroke is not a swipe
const STEEP := 1.2               # |dy| must beat |dx| by this: the swipe is vertical
const IDLE_CANCEL := 3.0         # seconds without a swipe: the hero gives up, nothing breaks
const RAISE_T := 0.24
const STRIKE_T := 0.1
const RECOIL_T := 0.36
const BREAK_HOLD := 0.3          # hands stay on the court, empty
const AFTER_T := 0.62            # the hero lets his breath out and straightens
const CANCEL_T := 0.45
const HITSTOP_MS := 60
const SHAKE := 0.45              # Camera.impulse: ~0.15 s
const SHARD_SCALE := 1.5         # a little larger than life: from the game camera a real rim is a few pixels
const SHARD_LIFE := 2.0
const HANDLE_LIFE := 10.0
const FADE := 0.45
const GRAVITY := 9.8
const BOUNCE := 0.35

## Poses, model space (forward = -Z). "th": the racket's angle in the vertical plane, from
## straight up (0) through horizontal forward (pi/2) to pointing back down; negative = back.
const P_READY := {"hand": Vector3(0.12, 1.0, -0.4), "th": 1.2, "rx": -0.25, "twist": 0.0, "hip": 0.0, "crouch": 0.08, "pitch": 0.1, "head": 0.0}
const P_RAISED := {"hand": Vector3(0.1, 1.9, -0.22), "th": -0.9, "rx": 0.12, "twist": -0.2, "hip": -0.1, "crouch": 0.0, "pitch": 0.0, "head": 0.32}
const P_STRIKE := {"hand": Vector3(0.06, 0.5, -0.55), "th": 2.35, "rx": 0.0, "twist": 0.1, "hip": 0.06, "crouch": 0.4, "pitch": 0.95, "head": -0.4}
const P_SLUMP := {"hand": Vector3(0.1, 0.78, -0.3), "th": 2.2, "rx": 0.0, "twist": 0.0, "hip": 0.0, "crouch": 0.1, "pitch": 0.35, "head": -0.35}

var ath: Athlete
var world: Node3D              # the shards live here
var cam: Camera3D              # GameCamera: impulse(); optional
var sfx: Node                  # Sfx: play(), crowd(); optional
var hitstop: Callable          # (ms: int) -> void; optional (Main: Tuning.hitstop, not in autoplay)
var state := S.IDLE
var swipes := 0                # accepted swipes (0..3)
var powers: Array[float] = []  # the strength of each
var rejected := 0.0            # seconds the prompt flashes red after a swipe that did not count
var racket_item := {}          # the worn racket, as it was when it broke (for the shards)
var shards: Array[Dictionary] = []
var tip_at_impact := Vector3.INF   # world point where the racket met the court (tests, dust)

var _t := 0.0                  # seconds in the state
var _idle := 0.0
var _clock := 0.0
var _follow := 0.0             # 0..1: how far the finger has pulled the hand up (READY) or down (HELD)
var _raise := 0.0              # 0 (ready) .. 1 (over the head)
var _strike := 0.0             # 0 .. 1 (on the court)
var _from := {}                # the pose a move starts from
var _power := 0.5              # the strength of the blow in flight
var _charge := 0.5             # the wind-up's strength
var _blow := 0


func _init() -> void:
	process_priority = -10


# --- Reading a swipe ---------------------------------------------------------------

## A finger path -> {"dir": -1 up / +1 down / 0 no swipe, "power": 0..1}. `h`: screen height.
static func classify(points: PackedVector2Array, times: PackedInt32Array, h: float) -> Dictionary:
	if points.size() < 2:
		return {"dir": 0, "power": 0.0}
	var d := points[points.size() - 1] - points[0]
	if absf(d.y) < MIN_SWIPE * h or absf(d.y) < STEEP * absf(d.x):
		return {"dir": 0, "power": 0.0}
	var ms := maxi(times[times.size() - 1] - times[0], 30)
	var speed := absf(d.y) / h / (ms / 1000.0)        # screen heights per second, as the strokes read it
	return {"dir": -1 if d.y < 0.0 else 1, "power": clampf((speed - 0.8) / 3.2, 0.0, 1.0)}


## How far a finger has gone vertically so far, up positive, in 0..1 of 0.3 of the screen.
static func pull(points: PackedVector2Array, h: float) -> float:
	if points.size() < 2:
		return 0.0
	return clampf((points[0].y - points[points.size() - 1].y) / (0.3 * h), -1.0, 1.0)


# --- Running it --------------------------------------------------------------------

## Starts with the hero where he stands. Everything else is optional (a bare test).
func begin(athlete: Athlete, parent: Node3D, camera: Camera3D = null, sound: Node = null, stop: Callable = Callable()) -> void:
	ath = athlete
	world = parent
	cam = camera
	sfx = sound
	hitstop = stop
	racket_item = ath.gear().get("racket", {})
	state = S.READY
	swipes = 0
	powers.clear()
	_blow = 0
	_t = 0.0
	_idle = 0.0
	_follow = 0.0
	_raise = 0.0
	_strike = 0.0
	rejected = 0.0
	tip_at_impact = Vector3.INF
	ath.velocity = Vector3.ZERO
	ath.move_input = Vector2.ZERO
	ath.smash_begin(_pose(0.0, 0.0))


## The prompt now: -1 swipe up, +1 swipe down, 0 nothing is expected (a blow is in flight).
func expects() -> int:
	match state:
		S.READY:
			return -1
		S.HELD, S.RECOIL:
			return 1
	return 0


func is_active() -> bool:
	return state != S.IDLE and state != S.DONE


## The finger is on the screen: `up` is Pull.pull(...) (up positive). The hand goes with it.
func progress(up: float) -> void:
	if state == S.READY:
		_follow = clampf(up, 0.0, 1.0)
	elif state == S.HELD:
		_follow = clampf(-up, 0.0, 1.0)


## A finished swipe. Returns true when it counted.
func swipe(dir: int, power: float) -> bool:
	_idle = 0.0
	var want := expects()
	if dir == 0 or want == 0 or dir != want:
		if dir != 0 or want != 0:
			rejected = 0.35
		_follow = 0.0
		return false
	swipes += 1
	powers.append(power)
	_follow = 0.0
	if state == S.READY:
		_charge = lerpf(0.3, 1.0, power)
		_go(S.RAISE)
	else:
		_blow += 1
		_power = lerpf(0.3, 1.0, power) * lerpf(0.75, 1.0, _charge)
		_go(S.STRIKE)
	return true


## Gives up at once (the match was left).
func abort() -> void:
	if is_active():
		_finish(false)


func _go(s: int) -> void:
	state = s as S
	_t = 0.0
	_from = _current()


func _process(delta: float) -> void:
	if not is_active() or ath == null:
		_update_shards(delta)
		return
	_clock += delta
	_t += delta
	rejected = maxf(0.0, rejected - delta)
	match state:
		S.READY, S.HELD:
			_idle += delta
			_raise = lerpf(_raise, (_follow * 0.8) if state == S.READY else 1.0, 1.0 - exp(-18.0 * delta))
			_strike = lerpf(_strike, _follow * 0.3 if state == S.HELD else 0.0, 1.0 - exp(-18.0 * delta))
			if _idle >= IDLE_CANCEL:
				_go(S.CANCEL)
		S.RAISE:
			var u := clampf(_t / (RAISE_T * lerpf(1.3, 0.8, _charge)), 0.0, 1.0)
			_raise = lerpf(float(_from["raise"]), 1.0, 1.0 - pow(1.0 - u, 3.0))
			_strike = 0.0
			if u >= 1.0:
				_go(S.HELD)
		S.STRIKE:
			var u := clampf(_t / (STRIKE_T * lerpf(1.35, 0.8, _power)), 0.0, 1.0)
			_strike = lerpf(float(_from["strike"]), 1.0, u * u)   # falls: accelerates onto the court
			# The blow lands when the head really is on the court (the body takes a moment to
			# follow the pose), or at the latest 0.25 s after the swipe.
			if u >= 1.0:
				_strike = 1.0
				if ath.racket_tip_world().y <= 0.1 or _t > 0.25:
					_hit_court()
		S.RECOIL:
			var u := clampf(_t / RECOIL_T, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - u, 2.0)
			_strike = lerpf(1.0, 0.0, e)
			_raise = 1.0
			if u >= 1.0:
				_idle = 0.0
				_go(S.HELD)
		S.BREAK:
			if _t >= BREAK_HOLD:
				_go(S.AFTER)
		S.AFTER:
			var u := clampf(_t / AFTER_T, 0.0, 1.0)
			_strike = 1.0 - u * u * (3.0 - 2.0 * u)       # the hands come off the court and hang
			_raise = _strike
			if u >= 1.0:
				_finish(true)
		S.CANCEL:
			var u := clampf(_t / CANCEL_T, 0.0, 1.0)
			_raise = lerpf(float(_from["raise"]), 0.0, u)
			_strike = lerpf(float(_from["strike"]), 0.0, u)
			if u >= 1.0:
				_finish(false)
	if is_active():
		ath.smash_set(_pose(_raise, _strike))
	_update_shards(delta)


func _finish(was_broken: bool) -> void:
	state = S.DONE
	if ath:
		ath.smash_end()
		var node := ath.racket_node()
		if node:
			node.visible = true
	finished.emit(was_broken)


# --- The blow -----------------------------------------------------------------------

func _hit_court() -> void:
	tip_at_impact = ath.racket_tip_world()
	if hitstop.is_valid():
		hitstop.call(HITSTOP_MS if _power >= 0.4 else 40)
	if cam and cam.has_method("impulse"):
		cam.impulse(SHAKE * lerpf(0.8, 1.15, _power))
	_dust(tip_at_impact, _power)
	impact.emit(_blow, _power)
	if _blow >= 2:
		_break()
		return
	if sfx:
		sfx.play("racket_slam", lerpf(-8.0, -1.0, _power), lerpf(1.1, 0.9, _power))
	_go(S.RECOIL)


func _break() -> void:
	var node := ath.racket_node()
	if sfx:
		sfx.play("racket_crack", -1.0, 1.0)
		sfx.play("racket_slam", -4.0, 0.8)
		sfx.crowd("crowd_ooh", -5.0)
	_spawn_shards(node.global_transform if node else Transform3D(Basis.IDENTITY, tip_at_impact), _power)
	if node:
		node.visible = false
	var strength := 0.0
	for p in powers:
		strength += p
	strength /= float(maxi(powers.size(), 1))
	broken.emit(strength)
	_go(S.BREAK)


# --- Poses ---------------------------------------------------------------------------

static func _dir(th: float, rx: float) -> Vector3:
	return Vector3(rx, cos(th), -sin(th)).normalized()


static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {
		"hand": (a["hand"] as Vector3).lerp(b["hand"], k), "th": lerpf(float(a["th"]), float(b["th"]), k),
		"rx": lerpf(float(a["rx"]), float(b["rx"]), k), "twist": lerpf(float(a["twist"]), float(b["twist"]), k),
		"hip": lerpf(float(a["hip"]), float(b["hip"]), k), "crouch": lerpf(float(a["crouch"]), float(b["crouch"]), k),
		"pitch": lerpf(float(a["pitch"]), float(b["pitch"]), k), "head": lerpf(float(a["head"]), float(b["head"]), k),
	}


## What is asked of the Athlete for a wind-up `raise` (0..1) and a slam `strike` (0..1).
func _pose(raise: float, strike: float) -> Dictionary:
	var up := _mix(P_READY, P_RAISED, ease_out(raise))
	var k := strike
	var p := _mix(up, P_SLUMP if state >= S.BREAK and state != S.CANCEL else P_STRIKE, k * k * (3.0 - 2.0 * k))
	var h: Vector3 = p["hand"]
	if state == S.READY or state == S.HELD or state == S.RAISE:
		# Shaking with anger: the grip trembles, the more the higher it is.
		var amp := 0.004 + 0.008 * raise
		h += Vector3(sin(_clock * 53.0), sin(_clock * 67.0 + 1.0), sin(_clock * 41.0 + 2.0)) * amp
	var fast := 60.0 if state == S.STRIKE or state == S.BREAK else 26.0
	return {
		"hand": h, "rdir": _dir(float(p["th"]), float(p["rx"])), "twist": p["twist"], "hip": p["hip"],
		"crouch": p["crouch"], "pitch": p["pitch"], "head": p["head"], "k": fast,
	}


func _current() -> Dictionary:
	return {"raise": _raise, "strike": _strike}


static func ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


# --- Dust ----------------------------------------------------------------------------

func _dust(at: Vector3, power: float) -> void:
	if world == null or not world.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10 + int(10.0 * power)
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0 + 1.5 * power
	p.gravity = Vector3(0.0, -4.0, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.82, 0.74, 0.8)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(p)
	p.global_position = Vector3(at.x, maxf(at.y, 0.03), at.z)
	var tw := p.create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(p.queue_free)


# --- The shards ------------------------------------------------------------------------
# Meshes in racket space, each moved to its own centre so that it tumbles about it.

## [{"mesh", "centre", "kind" ("arc" | "handle" | "string"), "r"}] for a racket item.
static func shard_meshes(item: Dictionary, toon: bool) -> Array:
	var skin := AthleteGear.skin_of(item, "racket")
	var parts := AthleteGear.racket_parts(item, toon)
	var frame_mat: Material = (parts[0] as MeshInstance3D).material_override
	for p in parts:
		(p as Node).free()
	var col := AthleteGear._c(skin, "color", "#262633").srgb_to_linear()
	var acc := AthleteGear._c(skin, "accent", "#3a3a4a").srgb_to_linear()
	var pattern := String(skin.get("pattern", ""))
	var tube: float = AthleteGear.TUBE * float(skin.get("tube", 1.0))
	var out: Array = []
	# Three arcs of the rim with gaps between them (the missing bits are the dust).
	for span in [[0.0, 0.3], [0.34, 0.62], [0.68, 0.97]]:
		var s0: float = span[0]
		var s1: float = span[1]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings: Array = []
		var n := 12
		for i in n + 1:
			var s := lerpf(s0, s1, float(i) / n)
			var fr := AthleteGear._rim_frame(skin, fmod(s, 1.0))
			var taper := 1.0 if i > 0 and i < n else 0.55
			rings.append({"p": fr[0], "n": fr[2], "b": Vector3.BACK, "r": tube * taper, "u": s})
		AthleteGear._tube(st, rings, AthleteGear.TUBE_SEGS, func(s: float, phi: float, p: Vector3) -> Color:
			var accent := AthleteGear._rim_accent(pattern, s, phi, p)
			var c := acc if accent else col
			c.a = 1.0 if accent else 0.55
			return c)
		var mesh := st.commit()
		var centre := mesh.get_aabb().get_center()
		out.append({"mesh": mesh, "centre": centre, "kind": "arc", "r": tube * 1.3, "mat": frame_mat})
	# The handle with the throat's stubs.
	var wrap := AthleteGear._c(skin, "wrap", "#2c2c33").srgb_to_linear()
	var grip := AthleteGear._c(skin, "grip", "#1b1b1f").srgb_to_linear()
	var hs := SurfaceTool.new()
	hs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hand: Array = []
	hand.append({"p": Vector3(0, -0.036, 0), "r": 0.0, "u": 0.0})
	hand.append({"p": Vector3(0, -0.034, 0), "r": 0.0175, "u": 0.0})
	for k in 17:
		hand.append({"p": Vector3(0, -0.028 + 0.23 * k / 16.0, 0), "r": 0.0185, "u": float(k) / 16.0})
	hand.append({"p": Vector3(0, 0.21, 0), "r": 0.014, "u": 1.0})
	hand.append({"p": Vector3(0, 0.3, 0), "r": 0.011, "u": 1.0})
	hand.append({"p": Vector3(0, 0.34, 0.0), "r": 0.0, "u": 1.0})
	for h in hand:
		h["n"] = Vector3.RIGHT
		h["b"] = Vector3.BACK
	AthleteGear._tube(hs, hand, 8, func(s: float, phi: float, p: Vector3) -> Color:
		var c: Color
		if p.y < -0.025:
			c = acc
		elif p.y > 0.205:
			c = col
		else:
			c = wrap if fposmod(s * 5.0 + phi / TAU, 1.0) < 0.32 else grip
		c.a = 0.0
		return c)
	var hmesh := hs.commit()
	out.append({"mesh": hmesh, "centre": hmesh.get_aabb().get_center(), "kind": "handle", "r": 0.02, "mat": frame_mat})
	# Two scraps of string: flat strips, one of them curled over.
	var sc := AthleteGear._c(skin, "strings", "#f2f2e6")
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(sc.r, sc.g, sc.b, 0.95)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for len in [0.17, 0.11]:
		var q := QuadMesh.new()
		q.size = Vector2(0.012, len)
		out.append({"mesh": q, "centre": Vector3.ZERO, "kind": "string", "r": 0.004, "mat": sm,
			"at": Vector3(0.0, AthleteGear.HEAD_Y + (0.04 if len > 0.15 else -0.05), 0.0)})
	return out


func _spawn_shards(t: Transform3D, power: float) -> void:
	if world == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 + int(t.origin.x * 100.0)
	for sm in shard_meshes(racket_item, ath._toon()):
		var mi := MeshInstance3D.new()
		mi.mesh = sm["mesh"]
		mi.material_override = sm["mat"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if sm["kind"] == "string" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var centre: Vector3 = sm["at"] if sm.has("at") else sm["centre"]
		mi.position = -sm["centre"] if not sm.has("at") else Vector3.ZERO
		var root := Node3D.new()
		root.add_child(mi)
		world.add_child(root)
		root.global_transform = Transform3D(t.basis.orthonormalized() * Basis.from_scale(Vector3.ONE * SHARD_SCALE), t * centre)
		var kind: String = sm["kind"]
		# Out from the blow: forward (the hero faces -Z), up and sideways; the handle drops
		# short and lies near the hero's feet.
		var v := Vector3(rng.randf_range(-2.4, 2.4), rng.randf_range(2.6, 4.6), rng.randf_range(-2.2, 0.4)) * lerpf(0.7, 1.25, power)
		if kind == "handle":
			v = Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(1.6, 2.4), rng.randf_range(-1.4, -0.2)) * lerpf(0.8, 1.1, power)
		var av := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(6.0, 14.0)
		shards.append({"node": root, "v": v, "av": av, "kind": kind, "r": float(sm["r"]), "age": 0.0, "rest": false, "bounces": 0,
			"life": HANDLE_LIFE if kind == "handle" else SHARD_LIFE + rng.randf_range(-0.2, 0.2)})


func _update_shards(delta: float) -> void:
	var i := shards.size() - 1
	while i >= 0:
		var s: Dictionary = shards[i]
		var n = s["node"]
		if not is_instance_valid(n):
			shards.remove_at(i)
			i -= 1
			continue
		s["age"] += delta
		var age: float = s["age"]
		var life: float = s["life"]
		if age >= life + FADE:
			n.queue_free()
			shards.remove_at(i)
			i -= 1
			continue
		if age > life:
			n.scale = Vector3.ONE * SHARD_SCALE * maxf(0.0, 1.0 - (age - life) / FADE)
		_step_shard(s, n, delta)
		i -= 1


func _step_shard(s: Dictionary, n: Node3D, delta: float) -> void:
	var v: Vector3 = s["v"]
	var r: float = float(s["r"]) * SHARD_SCALE
	if bool(s["rest"]):
		# Lying: the last bit of roll settles it flat.
		_lay_flat(s, n, delta)
		return
	v.y -= GRAVITY * delta
	var p := n.global_position + v * delta
	var av: Vector3 = s["av"]
	if av.length() > 0.001:
		n.global_basis = Basis(av.normalized(), av.length() * delta) * n.global_basis
	if p.y < r:
		p.y = r
		if v.y < 0.0:
			v.y = -v.y * BOUNCE
			v.x *= 0.7
			v.z *= 0.7
			av *= 0.55
			s["bounces"] += 1
			if absf(v.y) < 0.9:
				s["rest"] = true
				v = Vector3.ZERO
				av = Vector3.ZERO
	s["v"] = v
	s["av"] = av
	n.global_position = p


## A shard that stopped turns the way it would fall: the handle with its length along the
## court, a piece of rim or string on its face.
func _lay_flat(s: Dictionary, n: Node3D, delta: float) -> void:
	var kind: String = s["kind"]
	var axis := n.global_basis.y if kind == "handle" else n.global_basis.z
	var want := Vector3.UP
	if kind == "handle":
		want = Vector3(axis.x, 0.0, axis.z)
		if want.length() < 0.05:
			want = Vector3.RIGHT
		want = want.normalized()
	if axis.dot(want) > 0.9999:
		return
	var q := Quaternion(axis.normalized(), want) if axis.dot(want) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	var step := Quaternion.IDENTITY.slerp(q, 1.0 - exp(-14.0 * delta))
	n.global_basis = Basis(step) * n.global_basis
	n.global_position.y = lerpf(n.global_position.y, float(s["r"]) * SHARD_SCALE, 1.0 - exp(-14.0 * delta))


## Frees whatever is left (the match ended, the scene is torn down).
func clear_shards() -> void:
	for s in shards:
		if is_instance_valid(s["node"]):
			(s["node"] as Node).queue_free()
	shards.clear()


func shard_count() -> int:
	return shards.size()
