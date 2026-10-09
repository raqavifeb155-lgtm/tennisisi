extends SceneTree
## Animation checks against the broadcast measurements (research/CLIPS_5045_5046.md):
##   godot --headless --path . --fixed-fps 60 -s tests/anim_test.gd [-- --body=1]
## Drives a lone Athlete frame by frame and reads its bones: feet stay on the court and
## the legs keep their length, a clay stop glides 0.9-1.6 m, a stretched ball spreads the
## feet ~1.4 m, volleys are short, the serve lands with the back leg kicked up, the body
## leans into a burst more than into a steady run, and the CPU's swing starts before contact.

const DT := 1.0 / 60.0

var failures := 0
var ath: Athlete
var _ran := false


## Runs on the first frame, once the scene tree is up (the rig needs global transforms).
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	run_all()
	return true


func run_all() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--body="):
			Athlete.body_style = int(a.get_slice("=", 1))
			print("body style ", Athlete.body_style)
	test_legs_hold_together()
	test_clay_slide()
	test_hard_court_stop()
	test_lunge()
	test_volley()
	test_serve_kick()
	test_stances()
	test_human_arms()
	test_high_balls()
	test_stance_change()
	test_racket_slot()
	test_foot_jitter()
	test_lean()
	test_swing_retarget()
	test_tired_pose()
	test_racket_smash()
	test_racket_on_a_fall()
	print("\n%s (%d failures)" % ["ALL ANIMATION TESTS PASSED" if failures == 0 else "ANIMATION TESTS FAILED", failures])
	if ath:
		ath.free()
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func fresh(surface := "hard", at := Vector3(0, 0, 11), area := Rect2(-9, -14, 18, 30)) -> Athlete:
	if ath:
		ath.free()
	Athlete.surface = surface
	ath = Athlete.new()
	root.add_child(ath)
	ath.setup(-1.0, Color(0.9, 0.3, 0.2), area)
	ath.position = at
	for i in 30:
		step()
	return ath


func step() -> void:
	ath._physics_process(DT)
	ath._process(DT)


## The bone's end points in model space: a capsule along its local Y.
func bone_ends(name: String) -> Array:
	if ath._ends.has(name):
		return ath._ends[name]
	var mi: MeshInstance3D = ath._bones[name]
	var half := ((mi.mesh as CapsuleMesh).height - (mi.mesh as CapsuleMesh).radius * 2.0) * 0.5
	var y := mi.transform.basis.y.normalized()
	return [mi.transform.origin - y * half, mi.transform.origin + y * half]


## Lowest point of each shoe and both shin lengths, in world space.
func feet_world() -> Array:
	var out := []
	for i in 2:
		var shoe: Array = bone_ends("shoe%d" % i)
		var a: Vector3 = ath._model.to_global(shoe[0])
		var b: Vector3 = ath._model.to_global(shoe[1])
		out.append(a if a.y < b.y else b)
	return out


## Over a run of frames: the lowest foot never sinks into the court, and the thigh and
## shin keep their lengths (the IK never had to stretch a leg).
func watch_legs(frames: int, act: Callable) -> Vector2:
	var sink := 0.0
	var stretch := 0.0
	for f in frames:
		act.call(f)
		step()
		var feet := feet_world()
		var low := minf((feet[0] as Vector3).y, (feet[1] as Vector3).y)
		sink = minf(sink, low)
		for i in 2:
			var th: Array = bone_ends("thigh%d" % i)
			var sh: Array = bone_ends("shin%d" % i)
			stretch = maxf(stretch, absf(((th[1] as Vector3) - (th[0] as Vector3)).length() - Athlete.THIGH))
			stretch = maxf(stretch, absf(((sh[1] as Vector3) - (sh[0] as Vector3)).length() - Athlete.SHIN))
	return Vector2(sink, stretch)


func test_legs_hold_together() -> void:
	print("legs: feet on the court, limbs keep their length")
	fresh("clay")
	var r := watch_legs(240, func(f: int) -> void:
		if f == 1:
			ath.move_input = Vector2(1, 0)
		elif f == 60:
			ath.move_input = Vector2.ZERO
		elif f == 120:
			ath.prepare(1)
		elif f == 150:
			ath.swing(1, 0.3, ath.to_global(Vector3(1.35, 0.45, -0.4)), Athlete.Style.TOPSPIN))
	check(r.x > -0.06, "no foot sinks into the court (lowest %.3f m) through a sprint, slide and lunge" % r.x)
	check(r.y < 0.02, "thighs and shins keep their length (worst %.3f m)" % r.y)


func test_clay_slide() -> void:
	print("clay: a hard stop from a sprint is a slide")
	fresh("clay")
	ath.max_speed = 5.1
	ath.move_input = Vector2(1, 0)
	for i in 70:
		step()
	var v0 := ath.velocity.length()
	var x0 := ath.position.x
	ath.move_input = Vector2.ZERO
	var t := 0.0
	var spread := 0.0
	while ath.velocity.length() > 0.2 and t < 2.0:
		step()
		t += DT
		var feet := feet_world()
		spread = maxf(spread, absf((feet[0] as Vector3).x - (feet[1] as Vector3).x))
	var dist := ath.position.x - x0
	check(v0 > 5.0, "top speed reached %.1f m/s" % v0)
	check(dist > 1.1 and dist < 1.9, "glides %.2f m before stopping (Sinner 1.6 m from 5.1 m/s)" % dist)
	check(t > 0.4 and t < 0.75, "stops in %.2f s (measured 0.63 s)" % t)
	check(spread > 1.0, "feet spread %.2f m along the slide (measured 1.5-1.8 m)" % spread)
	# Pushing back the other way bites after ~0.28 s of the slide, not at once.
	fresh("clay")
	ath.max_speed = 5.1
	ath.move_input = Vector2(1, 0)
	for i in 70:
		step()
	ath.move_input = Vector2(-1, 0)
	var turned := -1.0
	t = 0.0
	while t < 1.2:
		step()
		t += DT
		if ath.velocity.x < 0.0:
			turned = t
			break
	check(turned > 0.3 and turned < 0.8, "turns back after %.2f s (Sinner: stop 0.63 s, push-off right after)" % turned)


func test_hard_court_stop() -> void:
	print("hard court: the stop stays short")
	fresh("hard")
	ath.max_speed = 5.1
	ath.move_input = Vector2(1, 0)
	for i in 70:
		step()
	var x0 := ath.position.x
	ath.move_input = Vector2.ZERO
	for i in 90:
		step()
	check(ath.position.x - x0 < 0.6, "stops within %.2f m (no glide off clay)" % (ath.position.x - x0))


func test_lunge() -> void:
	print("lunge: a stretched low ball spreads the legs and drops the hips")
	fresh()
	ath.prepare(1)
	for i in 20:
		step()
	var hip0: float = (bone_ends("hips")[0] as Vector3).y
	ath.swing(1, 0.3, ath.to_global(Vector3(1.35, 0.45, -0.4)), Athlete.Style.TOPSPIN)
	var spread := 0.0
	var hip_low := 9.0
	for i in 20:
		step()
		var feet := feet_world()
		spread = maxf(spread, Vector2((feet[0] as Vector3).x - (feet[1] as Vector3).x, (feet[0] as Vector3).z - (feet[1] as Vector3).z).length())
		hip_low = minf(hip_low, (bone_ends("hips")[0] as Vector3).y)
	check(spread > 1.3, "feet %.2f m apart at contact (Alcaraz 1.4-1.5 m)" % spread)
	check(hip0 - hip_low > 0.12, "hips drop %.2f m into the lunge" % (hip0 - hip_low))
	fresh()
	ath.prepare(1)
	for i in 20:
		step()
	ath.swing(1, 0.3, ath.to_global(Vector3(0.75, 0.95, -0.45)), Athlete.Style.TOPSPIN)
	var spread_n := 0.0
	for i in 20:
		step()
		var feet := feet_world()
		spread_n = maxf(spread_n, absf((feet[0] as Vector3).x - (feet[1] as Vector3).x))
	check(spread_n < 0.8, "a comfortable ball keeps the normal stance (%.2f m)" % spread_n)
	# Through the lunge's finish the arms follow the sunken shoulders: the racket arm
	# doesn't lock straight reaching for a key above an upright body, and neither hand
	# ends up behind the back.
	fresh()
	ath.prepare(1)
	for i in 20:
		step()
	ath.swing(1, 0.3, ath.to_global(Vector3(1.35, 0.45, -0.4)), Athlete.Style.TOPSPIN)
	var locked := 0
	var frames := 0
	var behind := 0.0
	while ath.is_swinging() and frames < 90:
		step()
		frames += 1
		if ath._clock < ath._contact_at + 0.12:
			continue
		var up: Array = bone_ends("upper_r")
		var fo: Array = bone_ends("fore_r")
		var a := ((up[1] as Vector3) - (up[0] as Vector3)).normalized()
		var b := ((fo[1] as Vector3) - (fo[0] as Vector3)).normalized()
		if a.dot(b) > 0.995:
			locked += 1
		for h in [ath._hand_r.position, ath._hand_l.position]:
			behind = maxf(behind, (h as Vector3).z)
	check(locked <= 3, "racket arm not locked straight in the finish (%d frames)" % locked)
	check(behind < 0.35, "hands stay off the back (furthest %.2f m behind)" % behind)
	# The forehand's lasso finish comes down in front, not out to the side behind the
	# shoulder with the elbow up (the "arm falling off backwards" look).
	fresh()
	ath.prepare(1)
	for i in 20:
		step()
	ath.swing(1, 0.3, ath.to_global(Vector3(0.75, 0.95, -0.45)), Athlete.Style.TOPSPIN)
	var out_back := 0
	frames = 0
	while ath.is_swinging() and frames < 90:
		step()
		frames += 1
		if ath._clock < ath._contact_at + 0.1:
			continue
		var sh: Vector3 = (bone_ends("upper_r")[0] as Vector3)
		var hd: Vector3 = ath._hand_r.position
		if hd.x > sh.x + 0.2 and hd.z > sh.z + 0.05 and absf(hd.y - sh.y) < 0.3:
			out_back += 1
	check(out_back == 0, "forehand finish never swings the arm out behind the shoulder (%d frames)" % out_back)


func test_volley() -> void:
	print("volley: at the net the swing is a short punch")
	fresh("hard", Vector3(0, 0, 3))
	ath.swing(1, 0.2, ath.to_global(Vector3(0.75, 1.2, -0.5)), Athlete.Style.FLAT)
	check(ath._volley, "a stroke 3 m from the net is a volley")
	var frames := 0
	var hand_max := 0.0
	while ath.is_swinging() and frames < 120:
		step()
		frames += 1
		hand_max = maxf(hand_max, ath._hand.y)
	check(frames * DT < 0.5, "volley over in %.2f s" % (frames * DT))
	check(hand_max < 1.6, "no big finish over the head (hand up to %.2f m)" % hand_max)
	fresh()
	ath.swing(1, 0.3, ath.to_global(Vector3(0.75, 0.95, -0.45)), Athlete.Style.TOPSPIN)
	check(not ath._volley, "the same stroke on the baseline is a groundstroke")


func test_serve_kick() -> void:
	print("serve: land on the front foot, back leg kicked up")
	fresh()
	ath.serve_ready()
	for i in 20:
		step()
	ath.prepare_serve()
	for i in 40:
		step()
	ath.swing(1, 0.18, ath.to_global(Vector3(0.1, 2.85, -0.4)), Athlete.Style.SERVE)
	var kick := 0.0
	var t := 0.0
	var t_kick := 0.0
	while ath.is_swinging() and t < 1.2:
		step()
		t += DT
		# The right foot above the left one (both rise in the jump; the kick is the
		# right one going on up behind after the left has landed).
		var y: float = ath._model.to_global(bone_ends("shoe0")[0]).y - ath._model.to_global(bone_ends("shoe1")[0]).y
		if y > kick:
			kick = y
			t_kick = t
	check(kick > 0.35, "right foot kicks up %.2f m above the landed left one" % kick)
	check(t_kick > 0.45 and t_kick < 0.8, "highest %.2f s into the serve (contact 0.18 s, Alcaraz: ~0.44 s after it)" % t_kick)


func test_stances() -> void:
	print("stances: wide feet, turned body, no crossed legs")
	fresh()
	for i in 30:
		step()
	var feet := feet_world()
	var w := absf((feet[0] as Vector3).x - (feet[1] as Vector3).x)
	check(w > 0.6, "waiting: feet %.2f m apart (Sinner ~1.2 m)" % w)
	ath.prepare(1)
	for i in 40:
		step()
	check(ath._twist < -1.4, "forehand takeback: shoulders turned %.0f deg" % rad_to_deg(-ath._twist))
	feet = feet_world()
	var fw := Vector2((feet[0] as Vector3).x - (feet[1] as Vector3).x, (feet[0] as Vector3).z - (feet[1] as Vector3).z).length()
	check(fw > 0.65, "forehand stance %.2f m wide" % fw)
	check((feet[0] as Vector3).z > (feet[1] as Vector3).z + 0.2, "forehand: right foot back (%.2f m behind the left)" % ((feet[0] as Vector3).z - (feet[1] as Vector3).z))
	fresh()
	ath.prepare(-1)
	for i in 40:
		step()
	feet = feet_world()
	check((feet[0] as Vector3).x > (feet[1] as Vector3).x + 0.5, "two-hander: right foot not in front of the body (%.2f m right of the left)" % ((feet[0] as Vector3).x - (feet[1] as Vector3).x))
	fresh()
	ath.split_step()
	ath.move_input = Vector2(1, 0)
	var crossed := 0
	for i in 90:
		step()
		var ff := feet_world()
		if ath.to_local(ff[0]).x < ath.to_local(ff[1]).x:
			crossed += 1
	check(crossed == 0, "split step and shuffle right: feet never cross (%d frames)" % crossed)
	# Round 3 (FH-4, BH-4, DS, SV): the shoulders stay turned while the racket drops,
	# a slice keeps the hips side-on, the serve's right shoulder is high at contact.
	for side in [1, -1]:
		fresh()
		ath.prepare(side)
		for i in 40:
			step()
		var c := Vector3(0.75, 0.95, -0.45) if side > 0 else Vector3(-0.7, 0.95, -0.4)
		ath.swing(side, 0.3, ath.to_global(c), Athlete.Style.TOPSPIN)
		while ath._clock < ath._contact_at - 0.16:
			step()
		check(absf(ath._twist) > 0.7, "%s: shoulders still turned %.0f deg 0.16 s before contact (racket dropping)" % ["forehand" if side > 0 else "backhand", rad_to_deg(absf(ath._twist))])
	fresh()
	ath.prepare(1)
	for i in 40:
		step()
	ath.swing(1, 0.3, ath.to_global(Vector3(0.75, 0.95, -0.45)), Athlete.Style.TOPSPIN)
	while ath._clock < ath._contact_at:
		step()
	var tw_contact := absf(ath._twist)
	while ath._clock < ath._contact_at + 0.23:
		step()
	check(tw_contact > 0.55, "forehand: chest still turned %.0f deg at contact (FH-5)" % rad_to_deg(tw_contact))
	check(absf(ath._twist) < 0.4, "forehand: square %.0f deg ~0.23 s after contact (FH-7)" % rad_to_deg(absf(ath._twist)))
	# Two-hander at contact: right foot ahead, left behind, in a line square to the
	# baseline, both flat on the court (Sinner BH-5/6).
	fresh()
	ath.prepare(-1)
	for i in 40:
		step()
	ath.swing(-1, 0.3, ath.to_global(Vector3(-0.7, 0.95, -0.4)), Athlete.Style.TOPSPIN)
	var lift := 0.0
	while ath._clock < ath._contact_at + 0.15:
		step()
		var fl := feet_world()
		lift = maxf(lift, maxf((fl[0] as Vector3).y, (fl[1] as Vector3).y))
	var fb := feet_world()
	var rf := ath.to_local(fb[0])
	var lf := ath.to_local(fb[1])
	check(lf.z - rf.z > 0.45 and absf(lf.x - rf.x) < 0.4, "two-hander: right foot %.2f m ahead of the left, %.2f m to the side" % [lf.z - rf.z, absf(lf.x - rf.x)])
	check(lift < 0.1, "two-hander: feet stay on the court through the hit (highest %.2f m)" % lift)
	fresh()
	ath.prepare(-1, Athlete.Style.SLICE)
	for i in 40:
		step()
	ath.swing(-1, 0.3, ath.to_global(Vector3(-0.7, 0.8, -0.4)), Athlete.Style.SLICE)
	var hips_min := 9.0
	while ath.is_swinging():
		step()
		hips_min = minf(hips_min, ath._hip_twist)
	check(hips_min > 0.3, "backhand slice: hips stay side-on through the finish (%.0f deg)" % rad_to_deg(hips_min))
	fresh()
	ath.serve_ready()
	for i in 20:
		step()
	ath.prepare_serve()
	for i in 40:
		step()
	ath.swing(1, 0.18, ath.to_global(Vector3(0.1, 2.85, -0.4)), Athlete.Style.SERVE)
	while ath._clock < ath._contact_at:
		step()
	var ff := feet_world()
	check(ath._shoulder_roll > 0.45, "serve contact: right shoulder up (%.0f deg)" % rad_to_deg(ath._shoulder_roll))
	check(((ff[0] as Vector3) - (ff[1] as Vector3)).length() < 0.32, "serve: feet together in the air (%.2f m)" % ((ff[0] as Vector3) - (ff[1] as Vector3)).length())


## Foot and knee jitter on the run (a hotfix: a leg started to shake on the run): in the
## body's frame a foot never jumps between two frames and never zigzags (its velocity
## flipping direction at speed several times a second) in any run: straight, sideways,
## back, snaking, round a circle, a U-turn, a stick shivering around the straight line.
const JITTER_JUMP := 0.30     # m per frame (18 m/s): a clean gait peaks at ~0.12
const JITTER_ZIGZAG := 0.5    # quick direction flips (two within 0.1 s, each over 1 m/s: a visible shake, not a 5 mm tremor) of a foot, per second and shoe
# (a clean gait flips once per stance/swing change, 0.15+ s apart); the knees only for jumps


func jitter_input(name: String, t: float) -> Vector2:
	match name:
		"fwd_slow": return Vector2(0.0, -0.35)
		"fwd": return Vector2(0.0, -1.0)
		"side": return Vector2(1.0, 0.0)
		"side_left": return Vector2(-1.0, 0.0)
		"back": return Vector2(0.0, 1.0)
		"diag": return Vector2(0.6, -0.8)
		"wobble_slow": return Vector2(0.08 * sin(t * 4.0), -1.0)
		"wobble_fast": return Vector2(0.08 * sin(t * 23.0), -1.0)
		"stick_shiver": return Vector2(0.06 if int(t * 60.0) % 2 == 0 else -0.06, -1.0)
		"snake": return Vector2(sin(t * 1.8), -1.0)
		"snake_back": return Vector2(sin(t * 2.6), 0.8)
		"circle": return Vector2(sin(t * 1.4), -cos(t * 1.4))
		"slow_circle": return Vector2(0.4 * sin(t * 2.2), -0.4 * cos(t * 2.2))
		"u_turn": return Vector2(0.0, -1.0) if fmod(t, 2.4) < 1.2 else Vector2(0.0, 1.0)
		"zig": return Vector2(1.0, -0.3) if fmod(t, 0.9) < 0.45 else Vector2(-1.0, -0.3)
		"creep": return Vector2(0.03 * sin(t * 5.0), -0.12)
	return Vector2.ZERO


## Worst frame jump (m) and zigzag rate (per second) of both feet and both knees in the
## body's frame over a run of the given input; returns [jump, zigzag, where].
func jitter_run(name: String, top_speed: float) -> Array:
	fresh("hard", Vector3(0, 0, 0), Rect2(-80, -80, 160, 160))
	ath.max_speed = top_speed
	var t := 0.0
	var prev := {}
	var vel_prev := {}
	var flip_at := {}
	var frame := 0
	var jump := 0.0
	var where := ""
	var zig := 0
	var seconds := 0.0
	for f in 60 * 7:
		ath.move_input = jitter_input(name, t)
		var slide_before: float = ath._slide
		step()
		if ath._slide > slide_before:
			prev.clear()   # a hard stop from a sprint snaps into the slide pose on purpose
			vel_prev.clear()
		t += DT
		if t < 1.0:
			continue
		seconds += DT
		frame += 1
		for key in ["shoe0", "shoe1", "knee0", "knee1"]:
			var p: Vector3
			if key.begins_with("shoe"):
				p = ath._model.global_transform * (bone_ends(key)[0] as Vector3).lerp(bone_ends(key)[1], 0.5)
			else:
				p = ath._model.global_transform * (bone_ends("shin" + key.substr(4))[0] as Vector3)
			p = ath.to_local(p)
			if prev.has(key):
				var w: Vector3 = (p - prev[key]) / DT
				w.y = 0.0
				if (p - prev[key]).length() > jump:
					jump = (p - prev[key]).length()
					where = "%s t=%.2f" % [key, t]
				if vel_prev.has(key):
					var u: Vector3 = vel_prev[key]
					if key.begins_with("shoe") and u.length() > 1.0 and w.length() > 1.0 and u.dot(w) < 0.0:
						if flip_at.has(key) and frame - int(flip_at[key]) <= 6:
							zig += 1
						flip_at[key] = frame
				vel_prev[key] = w
			prev[key] = p
	return [jump, zig / maxf(seconds, 0.01) / 2.0, where]


func test_foot_jitter() -> void:
	print("foot jitter: no jumps, no zigzag of the feet and knees on the run")
	var names := ["fwd_slow", "fwd", "side", "side_left", "back", "diag", "wobble_slow", "wobble_fast",
		"stick_shiver", "snake", "snake_back", "circle", "slow_circle", "u_turn", "zig", "creep"]
	var worst_jump := 0.0
	var worst_zig := 0.0
	var wj := ""
	var wz := ""
	for top in [2.5, 4.0, 6.2]:
		for n in names:
			var r := jitter_run(n, top)
			if r[0] > worst_jump:
				worst_jump = r[0]
				wj = "%s @%.1f %s" % [n, top, r[2]]
			if r[1] > worst_zig:
				worst_zig = r[1]
				wz = "%s @%.1f" % [n, top]
			if r[0] > JITTER_JUMP or r[1] > JITTER_ZIGZAG:
				print("    %-12s top %.1f: jump %.3f m, zigzag %.1f /s %s" % [n, top, r[0], r[1], r[2]])
	check(worst_jump < JITTER_JUMP, "no foot or knee jumps between frames (worst %.3f m: %s)" % [worst_jump, wj])
	check(worst_zig < JITTER_ZIGZAG, "no foot or knee zigzag (worst %.1f /s: %s)" % [worst_zig, wz])


func test_lean() -> void:
	print("lean: into the burst, not the steady run")
	fresh()
	ath.move_input = Vector2(1, 0)
	var burst := 0.0
	for i in 18:
		step()
		burst = maxf(burst, absf(ath._model.rotation.z))
	for i in 60:
		step()
	var steady := absf(ath._model.rotation.z)
	check(burst > 0.14 and burst < Athlete.LEAN_MAX + 0.05, "%.0f deg leaning in the first 0.3 s (measured 14-17)" % rad_to_deg(burst))
	check(steady < burst * 0.6, "settles to %.0f deg at full speed" % rad_to_deg(steady))
	# Forward (-Z) is where the chest faces: + rotation.x tips the head back.
	fresh()
	ath.move_input = Vector2(0, -1)
	var fwd := 0.0
	for i in 18:
		step()
		fwd = minf(fwd, ath._model.rotation.x)
	check(fwd < -0.1, "sprinting in to the net leans forward (%.0f deg)" % rad_to_deg(-fwd))
	fresh()
	ath.move_input = Vector2(0, 1)
	var back := 0.0
	for i in 18:
		step()
		back = maxf(back, ath._model.rotation.x)
	check(back > 0.1, "backing off a deep ball leans back (%.0f deg)" % rad_to_deg(back))


func test_swing_retarget() -> void:
	print("a swing started ahead of the ball keeps going when the contact is confirmed")
	fresh()
	ath.swing(1, 0.16, ath.to_global(Vector3(0.75, 0.95, -0.45)), Athlete.Style.TOPSPIN)
	for i in 6:
		step()
	var clock: float = ath._clock
	ath.swing(1, 0.02, ath.to_global(Vector3(0.8, 0.9, -0.45)), Athlete.Style.TOPSPIN)
	check(is_equal_approx(ath._clock, clock), "the swing is not restarted (clock %.3f)" % ath._clock)
	check(ath._contact_at <= clock + 0.03, "contact moved to now (%.3f s)" % ath._contact_at)


## The arm's joints in model space: [shoulder, elbow, hand].
func arm(side: String) -> Array:
	var up: Array = bone_ends("upper_" + side)
	var fo: Array = bone_ends("fore_" + side)
	var best := [up[0], up[1], fo[0], fo[1]]
	var d := 99.0
	for i in 2:
		for j in 2:
			var dd := ((up[i] as Vector3) - (fo[j] as Vector3)).length()
			if dd < d:
				d = dd
				best = [up[1 - i], up[i], fo[1 - j]]
	return best


func test_human_arms() -> void:
	print("arms move like a human's: no elbow behind the back, none above a raised hand")
	var cases := [
		[1, Vector3(0.75, 0.95, -0.45), Athlete.Style.TOPSPIN, Vector3(0, 0, 11), "forehand"],
		[-1, Vector3(-0.7, 0.95, -0.4), Athlete.Style.TOPSPIN, Vector3(0, 0, 11), "two-handed backhand"],
		[-1, Vector3(-0.7, 0.8, -0.4), Athlete.Style.SLICE, Vector3(0, 0, 11), "backhand slice"],
		[1, Vector3(0.75, 0.8, -0.45), Athlete.Style.FLAT, Vector3(0, 0, 11), "flat forehand"],
		[1, Vector3(1.35, 0.45, -0.4), Athlete.Style.TOPSPIN, Vector3(0, 0, 11), "stretched forehand"],
		[1, Vector3(0.75, 1.2, -0.5), Athlete.Style.FLAT, Vector3(0, 0, 3), "forehand volley"],
		[-1, Vector3(-0.7, 1.1, -0.5), Athlete.Style.FLAT, Vector3(0, 0, 3), "backhand volley"],
	]
	for c in cases:
		fresh("hard", c[3])
		ath.prepare(c[0], c[2])
		var worst := 0.0
		var hand_back := -9.0
		var worst_at := ""
		var frames := 0
		for i in 40:
			step()
		ath.swing(c[0], 0.3, ath.to_global(c[1]), c[2])
		while ath.is_swinging() and frames < 120:
			step()
			frames += 1
			var tw := Basis(Vector3.UP, ath._twist)
			for sd in ["r", "l"]:
				var j := arm(sd)
				worst = maxf(worst, ath._elbow_cost(j[0], j[2], j[1], tw))
				# The hand: no further behind the back than a hand's width.
				var hb: float = (tw.inverse() * ((j[2] as Vector3) - (j[0] as Vector3))).z
				if hb > hand_back:
					hand_back = hb
					worst_at = "%s hand, %.2f s from contact, mode %d" % [sd, ath._clock - ath._contact_at, ath._mode]
		check(worst < 0.03, "%s: elbows stay human through the stroke (worst %.3f)" % [c[4], worst])
		check(hand_back < 0.2, "%s: hands never reach round behind the back (%.2f m, %s)" % [c[4], hand_back, worst_at])


## Balls above the usual strike zone but below the smash threshold (Main.SMASH_MIN_H, 2.2 m),
## in front and a little to the side, forehand and backhand: the contact keys used to put the
## hand half a metre to the side of the ball at the ball's height, flat racket across the
## arm, so at head height the arm went up beside / across the face, the elbow flipped
## round the shoulder-hand line (0.5 m in a frame) and the racket turned 45-55 deg in a
## frame. Every frame of each swing: the forearm keeps off the head, the elbow stays bent
## like an arm (not folded shut), the racket and the elbow do not jump between frames, a
## forehand's hand stays on the racket side of the spine, the racket stays out of the head.
const HIGH_HEIGHTS := [1.4, 1.6, 1.8, 2.0, 2.2]
const HIGH_HEAD_MIN := 0.19      # m: the forearm's closest point to the head centre
const HIGH_ELBOW_MIN := 40.0     # deg: the elbow's interior angle
const HIGH_RACKET_JUMP := 40.0   # deg per frame (a whip peaks near 32 on these strokes)
const HIGH_ELBOW_JUMP := 0.32    # m per frame
const HIGH_HAND_X := 0.08        # m right of the spine at a forehand's contact


func test_high_balls() -> void:
	print("high balls below the smash: the arm does not twist, cross the face or flip")
	var kinds := [
		["forehand", 1, Athlete.Style.TOPSPIN, false],
		["two-handed backhand", -1, Athlete.Style.TOPSPIN, false],
		["one-handed backhand", -1, Athlete.Style.TOPSPIN, true],
		["forehand slice", 1, Athlete.Style.SLICE, false],
	]
	for k in kinds:
		var side: int = k[1]
		for h in HIGH_HEIGHTS:
			var head_min := 9.0
			var elbow_min := 999.0
			var rjump := 0.0
			var ejump := 0.0
			var hand_x := 9.0
			var in_head := 0.0
			for lat in [0.5, 0.75]:
				for fwd in [0.5, 0.8]:
					fresh("hard", Vector3(0, 0, 11))
					ath.one_handed_backhand = k[3]
					ath.prepare(side, k[2])
					for i in 40:
						step()
					ath.swing(side, 0.3, ath.to_global(Vector3(lat * side, h, -fwd)), k[2])
					var prev_r := Vector3.ZERO
					var prev_e := Vector3.ZERO
					var frames := 0
					while ath.is_swinging() and frames < 150:
						step()
						frames += 1
						var j := arm("r")
						var sh: Vector3 = j[0]
						var el: Vector3 = j[1]
						var hd: Vector3 = j[2]
						var rd: Vector3 = ath._racket.transform.basis.y
						var head: Vector3 = ath._head.position
						head_min = minf(head_min, Geometry3D.get_closest_point_to_segment(head, el, hd).distance_to(head))
						elbow_min = minf(elbow_min, 180.0 - rad_to_deg((el - sh).angle_to(hd - el)))
						in_head = maxf(in_head, 0.17 - Geometry3D.get_closest_point_to_segment(head, hd, hd + rd * 0.62).distance_to(head))
						if frames > 1:
							rjump = maxf(rjump, rad_to_deg(prev_r.angle_to(rd)))
							ejump = maxf(ejump, (el - prev_e).length())
						prev_r = rd
						prev_e = el
						if side > 0 and absf(ath._clock - ath._contact_at) < 0.009:
							hand_x = minf(hand_x, hd.x)
			var tag := "%s at %.1f m" % [k[0], h]
			check(head_min >= HIGH_HEAD_MIN, "%s: the forearm keeps %.2f m off the head" % [tag, head_min])
			check(elbow_min >= HIGH_ELBOW_MIN, "%s: the elbow never folds shut (%.0f deg)" % [tag, elbow_min])
			check(rjump <= HIGH_RACKET_JUMP, "%s: the racket never turns more than %.0f deg in a frame (%.0f)" % [tag, HIGH_RACKET_JUMP, rjump])
			check(ejump <= HIGH_ELBOW_JUMP, "%s: the elbow never jumps (%.2f m in a frame)" % [tag, ejump])
			check(in_head < 0.03, "%s: the racket stays out of the head (%.2f m in)" % [tag, in_head])
			if side > 0:
				check(hand_x >= HIGH_HAND_X, "%s: the hand stays on the racket side of the spine at contact (x %.2f)" % [tag, hand_x])


## The racket leaves the hand when the player goes down (a dive that lands, a slip, a
## knockout), tumbles and lies flat on the court (never under it), and is back in the hand
## once the player is up.
func racket_in_hand() -> float:
	var j := arm("r")
	return ath._model.to_global(j[2]).distance_to(ath._racket.global_position)


func test_racket_on_a_fall() -> void:
	print("racket on a fall: out of the hand, on the court, back in the hand")
	for kind in ["dive", "knockout", "dive then restart"]:
		fresh("hard", Vector3(0, 0, 11))
		ath.prepare(1)
		for i in 30:
			step()
		var held_before := true
		var loose := 0
		var loose_from := -1
		var sink := 99.0
		var rest_speed := 0.0
		var prev := Vector3.ZERO
		var frames := 0
		var total := 0
		if kind == "knockout":
			ath.knockout(Vector3(0, 2, 8))
			total = int((Athlete.KO_FLY + Athlete.KO_LIE + 0.8) * 60.0)
		else:
			ath.swing(1, 0.2, ath.to_global(Vector3(2.0, 0.6, -0.4)), Athlete.Style.TOPSPIN)
			ath.dive(ath.to_global(Vector3(2.0, 0.6, -0.4)))
			total = int((Athlete.DIVE_TIME + Athlete.GROUND_TIME + Athlete.GETUP_TIME + 0.8) * 60.0)
		var restart_at := int((Athlete.DIVE_TIME + 1.0) * 60.0) if kind == "dive then restart" else -1
		var back_at := -1
		for f in total:
			if f == restart_at:
				ath.recover()
			step()
			var t := float(f) / 60.0
			var d := racket_in_hand()
			if t < 0.1 and kind != "knockout" and d > 0.03:
				held_before = false
			if ath.racket_loose() and d > 0.12:
				loose += 1
				if loose_from < 0:
					loose_from = f
				sink = minf(sink, ath.racket_lowest_y())
				if ath._rk == 1:
					rest_speed = (ath._racket.global_position - prev).length() * 60.0   # the last one: just before it is picked up
			elif loose_from >= 0 and back_at < 0 and not ath.racket_loose():
				back_at = f
			prev = ath._racket.global_position
		check(held_before, "%s: the racket stays in the hand through the swing (the first 0.1 s)" % kind)
		check(loose >= 40, "%s: the racket is out of the hand for a while (%d frames)" % [kind, loose])
		check(sink > -0.005, "%s: the racket never goes through the court (lowest %.3f m)" % [kind, sink])
		check(rest_speed < 0.1, "%s: it lies still after sliding (%.2f m/s)" % [kind, rest_speed])
		check(back_at > 0 and racket_in_hand() < 0.03 and not ath.racket_loose(), "%s: the racket is in the hand again (frame %d, %.3f m off)" % [kind, back_at, racket_in_hand()])


## Changing the stance (forehand <-> backhand) while running back, running in, standing
## and running sideways: the chest turns half a circle and the hands must go round in
## front of it. Every frame, no hand, elbow or forearm may be inside the trunk or behind
## the back plane (AthleteProbe), and a hand keeps off the spine (not closer than 0.19 m).
func test_stance_change() -> void:
	print("stance change on the move: the arms never pass through the back")
	for sc in AthleteProbe.SCENARIOS:
		for first in [1, -1]:
			fresh("hard", AthleteProbe.start_of(sc), Rect2(-12, -14, 24, 34))
			var bad := 0
			var first_bad := ""
			var closest := 9.0
			for f in 120:
				AthleteProbe.drive(ath, sc, f, first)
				step()
				var pr := AthleteProbe.problems(ath)
				if not pr.is_empty():
					bad += 1
					if first_bad == "":
						first_bad = "frame %d %s" % [f, pr]
				var t := AthleteProbe.torso(ath)
				for it in AthleteProbe.arm_points(ath):
					if (it[0] as String).begins_with("hand"):
						var q := AthleteProbe.in_torso_frame(t, it[1])
						if q.z < 99.0:
							closest = minf(closest, Vector2(q.x, q.y).length())
			var dir := "forehand -> backhand" if first > 0 else "backhand -> forehand"
			check(bad == 0, "%s, %s: no arm through the trunk or behind the back (%d bad frames %s)" % [sc, dir, bad, first_bad])
			check(closest > 0.19, "%s, %s: hands keep %.2f m from the spine" % [sc, dir, closest])


## The racket slot (Athlete.slot): no swipe yet and the ball close, the racket drops into
## the slot by itself and waits; the swipe whips it through the ball from there. Standing,
## backing off and shuffling sideways, released at contact, released early, released into
## another stroke (slice), never released, or the ball switching wings: the arms never go
## through the trunk or behind the back, the hands keep off the spine, the hand never jumps
## more than a real whip moves in a frame (~15 m/s), and the swing still meets the ball.
const ENDINGS := ["legacy", "whip", "early", "slice", "none", "switch"]


func test_racket_slot() -> void:
	print("racket slot: drop by itself, whip on the swipe, no arm through the body")
	var moves := {"still": Vector2.ZERO, "back": Vector2(0.0, 1.0), "sideways": Vector2(1.0, 0.0)}
	for mv_name in moves:
		for side in [1, -1]:
			for ending in ENDINGS:
				fresh("hard", Vector3(0, 0, 9), Rect2(-12, -14, 24, 34))
				var bad := 0
				var first_bad := ""
				var closest := 9.0
				var jump := 0.0
				var jump_at := ""
				var closest_at := ""
				var met := 9.0
				ath.prepare(side)
				for f in 30:
					ath.move_input = moves[mv_name] * 0.5
					step()
				var ttc := Athlete.SWING_TO_CONTACT
				var cur_side: int = side
				var released := false
				var prev_hand := ath._hand
				for f in 70:
					ath.move_input = moves[mv_name] * 0.5
					var contact := ath.global_position + ath.right() * cur_side * 0.75 + ath.forward() * 0.45 + Vector3(0, 0.95, 0)
					if not released:
						if ending == "switch" and ttc < 0.1 and cur_side == side:
							cur_side = -side
							contact = ath.global_position + ath.right() * cur_side * 0.75 + ath.forward() * 0.45 + Vector3(0, 0.95, 0)
						var go := ttc <= 0.0 if ending != "early" else ttc <= 0.15
						if ending == "legacy":
							if go:  # the old way: no slot, the whole swing starts at the swipe
								ath.swing(cur_side, 0.0, contact)
								released = true
						elif ending == "none":
							if ttc < -0.1:
								ath.unslot()
								released = true
							else:
								ath.slot(cur_side, maxf(ttc, 0.0), contact)
						elif go or (ending == "switch" and cur_side != side and ttc <= 0.0):
							ath.swing(cur_side, maxf(ttc, 0.0), contact, Athlete.Style.SLICE if ending == "slice" else Athlete.Style.TOPSPIN)
							released = true
						else:
							ath.slot(cur_side, ttc, contact)
					else:
						ath.update_contact(contact) if ath.is_swinging() and ath._clock < ath._contact_at else null
					step()
					ttc -= DT
					if (ath._hand - prev_hand).length() > jump:
						jump = (ath._hand - prev_hand).length()
						jump_at = "f%d mode %d clock %.3f contact %.3f len %.3f" % [f, ath._mode, ath._clock, ath._contact_at, ath._swing_len]
					prev_hand = ath._hand
					if ath.is_swinging() and absf(ath._clock - ath._contact_at) < DT * 0.6:
						met = (ath.racket_head_world() - contact).length()
					var pr := AthleteProbe.problems(ath)
					if not pr.is_empty():
						bad += 1
						if first_bad == "":
							first_bad = "frame %d %s" % [f, pr]
					var t := AthleteProbe.torso(ath)
					for it in AthleteProbe.arm_points(ath):
						if (it[0] as String).begins_with("hand"):
							var q := AthleteProbe.in_torso_frame(t, it[1])
							if q.z < 99.0 and Vector2(q.x, q.y).length() < closest:
								closest = Vector2(q.x, q.y).length()
								closest_at = "f%d %s mode %d hold %s q %s" % [f, it[0], ath._mode, ath._slot_hold, q]
				var tag := "%s, %s, %s" % [mv_name, "FH" if side > 0 else "BH", ending]
				check(bad == 0, "%s: no arm through the trunk or behind the back (%d bad frames %s)" % [tag, bad, first_bad])
				# Both hands on the racket in the ready stance hold it ~0.18 m in front of the
				# chest (as before the slot), so the margin here is that, not the takeback's.
				check(closest > 0.17, "%s: hands keep %.2f m from the spine (%s)" % [tag, closest, closest_at])
				if ending == "legacy" or ending == "switch":
					# The whole swing squeezed into the frames after the swipe (the old way,
					# and still the way when the ball switches wings at the last moment).
					print("  info %s: the hand moves up to %.2f m in a frame (%s)" % [tag, jump, jump_at])
				else:
					# A real forehand whip: the hand ~12-17 m/s near contact, 0.2-0.3 m a frame.
					check(jump < 0.32, "%s: the hand moves at most %.2f m in a frame (%s)" % [tag, jump, jump_at])
				if ending != "none":
					check(met < 0.35, "%s: the racket meets the ball (%.2f m off at contact)" % [tag, met])
				check(not ath.is_slotted(), "%s: nothing left waiting in the slot" % tag)


## Out of breath between points: bent over with both hands at the knees, the feet
## planted and the legs whole; it lets go once the player moves again.
func test_tired_pose() -> void:
	print("out of breath: hands on the knees")
	fresh()
	ath.tired = true
	var legs := watch_legs(90, func(_f: int) -> void: pass)
	var r_hand: Vector3 = ath._hand
	var l_hand: Vector3 = ath._lhand
	check(ath._pitch > 0.35, "trunk bent forward (%.2f rad)" % ath._pitch)
	check(r_hand.y < 0.8 and l_hand.y < 0.8 and r_hand.x > 0.0 and l_hand.x < 0.0, "hands down at the knees (R %.2f, L %.2f m)" % [r_hand.y, l_hand.y])
	check(legs.x > -0.03 and legs.y < 0.02, "feet stay on the court, legs whole (sink %.3f, stretch %.3f)" % [legs.x, legs.y])
	ath.tired = false
	for i in 60:
		step()
	check(ath._pitch < 0.15 and ath._hand.y > 0.9, "back upright when rested (%.2f rad)" % ath._pitch)


## The racket smash (RacketSmash, mode 5): the hero lifts the racket in both hands, slams it
## into the court twice, the second blow breaks it. The arms never go through the trunk or
## the back, the racket's head meets the court at the blows, the legs stay whole, and the
## stance, the arms and the racket are back afterwards.
func test_racket_smash() -> void:
	print("racket smash: wind-up, two blows, the racket breaks, the stance comes back")
	fresh("hard", Vector3(0, 0, 11))
	var world := Node3D.new()
	root.add_child(world)
	var rs := RacketSmash.new()
	root.add_child(rs)
	var hits: Array[Vector3] = []
	var broke := [false]
	var done := [false, false]
	rs.impact.connect(func(_b: int, _p: float) -> void: hits.append(rs.tip_at_impact))
	rs.broken.connect(func(_s: float) -> void: broke[0] = true)
	rs.finished.connect(func(was: bool) -> void:
		done[0] = true
		done[1] = was)
	rs.begin(ath, world)
	var bad := 0
	var first_bad := ""
	var sink := 0.0
	var stretch := 0.0
	var hidden_at_break := false
	var tip_low := 9.0
	var frames := 0
	var script := {60: [-1, 0.8], 120: [1, 0.9], 190: [1, 0.9]}
	while not done[0] and frames < 600:
		if script.has(frames):
			var sw: Array = script[frames]
			rs.swipe(sw[0], sw[1])
		frames += 1
		rs._process(DT)
		step()
		var pr := AthleteProbe.problems(ath)
		if not pr.is_empty():
			bad += 1
			if first_bad == "":
				first_bad = "frame %d %s" % [frames, pr]
		var feet := feet_world()
		sink = minf(sink, minf((feet[0] as Vector3).y, (feet[1] as Vector3).y))
		for i in 2:
			var th: Array = bone_ends("thigh%d" % i)
			var sh: Array = bone_ends("shin%d" % i)
			stretch = maxf(stretch, absf(((th[1] as Vector3) - (th[0] as Vector3)).length() - Athlete.THIGH))
			stretch = maxf(stretch, absf(((sh[1] as Vector3) - (sh[0] as Vector3)).length() - Athlete.SHIN))
		if rs.state == RacketSmash.S.STRIKE or rs.state == RacketSmash.S.RECOIL:
			tip_low = minf(tip_low, ath.racket_tip_world().y)
		if rs.state == RacketSmash.S.BREAK:
			hidden_at_break = not ath.racket_node().visible
	check(done[0] and done[1], "the mini-game ends, the racket broken (%d frames)" % frames)
	check(hits.size() == 2 and broke[0], "two blows reached the court, the second broke it (%d blows)" % hits.size())
	for h in hits:
		check(h.y < 0.1 and h.y > -0.08, "the racket's head meets the court at the blow (height %.2f m)" % h.y)
	check(tip_low > -0.1, "the racket never goes through the court (lowest %.2f m)" % tip_low)
	check(bad == 0, "no arm through the trunk or behind the back (%d bad frames %s)" % [bad, first_bad])
	check(sink > -0.06 and stretch < 0.02, "feet on the court, legs whole (sink %.3f, stretch %.3f)" % [sink, stretch])
	check(hidden_at_break and rs.shard_count() == 6, "the racket is gone and six pieces fly (%d)" % rs.shard_count())
	for i in 40:
		step()
	check(ath._mode == 0 and ath.racket_node().visible, "after: the ready stance, the racket node back")
	check(ath._pitch < 0.15 and ath._hand.y > 0.9 and absf(ath._twist) < 0.1, "after: upright, the hand at the ready (pitch %.2f, hand %.2f)" % [ath._pitch, ath._hand.y])
	# A wrong swipe does not count; the hero gives up after IDLE_CANCEL seconds and nothing breaks.
	fresh("hard", Vector3(0, 0, 11))
	rs = RacketSmash.new()
	root.add_child(rs)
	var res := [false, true]
	rs.finished.connect(func(was: bool) -> void:
		res[0] = true
		res[1] = was)
	rs.begin(ath, world)
	check(not rs.swipe(1, 0.9) and rs.swipes == 0 and rs.rejected > 0.0, "a swipe down before the wind-up does not count")
	for i in int((RacketSmash.IDLE_CANCEL + RacketSmash.CANCEL_T + 0.3) / DT):
		rs._process(DT)
		step()
	check(res[0] and not res[1] and ath._mode == 0, "no swipe for %.0f s: the mini-game ends, nothing broken" % RacketSmash.IDLE_CANCEL)
	rs.free()
	world.free()
