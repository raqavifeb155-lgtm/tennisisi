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
	test_stance_change()
	test_lean()
	test_swing_retarget()
	test_tired_pose()
	test_racket_smash()
	test_club_crowd()
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


## The club with people (stream H-8, after the NPC collisions): the hero walks and jogs through
## a crowd at the court as Club does it (ClubWalk.resolve against ClubNpc's bodies each frame,
## the ground's height eased under his feet), among a junior and the old coach who are real
## bodies, driven as ClubNpcLife drives them, and three who stand. He is never inside anybody,
## never jumps, is not held up for long, his yaw is smooth, and every pair of feet stays on
## the ground - the hero's, the junior's, the coach's - with the legs whole.
func test_club_crowd() -> void:
	print("club with people: the hero walks through the crowd at the court")
	if ath:
		ath.free()
		ath = null
	Athlete.surface = "hard"
	var walk := ClubWalk.new()
	walk.bounds = Rect2(-12, -14, 24, 30)
	var ground := func(q: Vector2) -> float:   # the way up to the court: the path rises 12 cm over z 6..2
		return 0.12 * clampf((6.0 - q.y) / 4.0, 0.0, 1.0)
	walk.ground = ground
	walk.floors.append([Rect2(-12, -14, 24, 3.0), 0.15])   # and a room's floor at the far end
	walk.add_circle(Vector2(4.2, -2.0), 0.5, "post")
	var reg := ClubNpc.new()
	var hero := Athlete.new()
	root.add_child(hero)
	hero.setup(-1.0, Color(0.9, 0.3, 0.2), walk.bounds)
	hero.set_meta("casual", true)
	hero.position = Vector3(0, 0, 9)
	var kid := Athlete.new()
	root.add_child(kid)
	kid.setup(-1.0, Color(0.2, 0.5, 0.9), walk.bounds)
	AthleteCasual.set_junior(kid, 0.75)
	kid.set_meta("casual", true)
	var old := Athlete.new()
	root.add_child(old)
	old.setup(-1.0, Color(0.5, 0.5, 0.5), walk.bounds)
	AthleteCasual.make_elder(old)
	old.set_meta("casual", true)
	kid.position = Vector3(-3.0, 0, 1.0)
	old.position = Vector3(1.4, 0, -0.5)
	# the people: [id, body or null, x, z, radius]; the two with bodies walk, the rest stand
	var people := {"kid": kid, "coach": old}
	var stand := {"s1": Vector2(-0.5, 3.4), "s2": Vector2(0.5, 3.4), "guest": Vector2(-0.3, -1.8)}   # two shoulder to shoulder: a notch the hero can't pass
	var pos := {"kid": Vector2(-3.0, 1.0), "coach": Vector2(1.4, -0.5)}
	for id in stand:
		pos[id] = stand[id]
		reg.register(id, Vector3(stand[id].x, 0.0, stand[id].y), "", "", [], {"radius": 0.40})
	reg.register("kid", func() -> Vector3: return Vector3(pos["kid"].x, 0.0, pos["kid"].y), "", "", [], {"radius": 0.30})
	reg.register("coach", func() -> Vector3: return Vector3(pos["coach"].x, 0.0, pos["coach"].y), "", "", [], {"radius": 0.40})
	var worst := {"sink": 0.0, "stretch": 0.0, "jump": 0.0, "yaw": 0.0, "overlap": 0.0, "off": 0.0, "sink_who": ""}
	var hero_y := 0.0
	var results := []
	for pass_i in 2:
		var jog := pass_i == 1
		hero.position = Vector3(0.0, 0, 9.5)
		hero.velocity = Vector3.ZERO
		hero_y = walk.floor_at(Vector2(0.0, 9.5))
		var frames := 0
		var held := 0.0
		var worst_held := 0.0
		var side := 1.0
		var detour := 0.0
		var last := Vector2(hero.position.x, hero.position.z)
		var last_yaw := hero.rotation.y
		while hero.position.z > -9.0 and frames < 1800:
			frames += 1
			var here := Vector2(hero.position.x, hero.position.z)
			# the stick: toward the far end; held up by somebody for half a second, he steps aside a while
			var want := Vector2(0.0, -1.0)
			if detour > 0.0:
				detour -= DT
				want = Vector2(side * 0.9, -0.45).normalized()
			elif held > 0.5:
				detour = 0.7
				held = 0.0
				side = -side
			hero.max_speed = Club.JOG_SPEED if jog else Club.WALK_TOP
			hero.accel = Club.ACCEL
			hero.decel = Club.DECEL
			hero.move_input = want
			var v := Vector2(hero.velocity.x, hero.velocity.z)
			if v.length() > 0.4:
				hero.rotation.y = lerp_angle(hero.rotation.y, atan2(-v.x, -v.y), 1.0 - exp(-12.0 * DT))
			# the walkers: the junior to and fro across the court's width, the coach pacing a short beat
			for id in people:
				var b: Athlete = people[id]
				var goal := Vector2(3.4 if int(frames / 240) % 2 == 0 else -3.4, 1.0) if id == "kid" else Vector2(1.4 + (0.9 if int(frames / 150) % 2 == 0 else -0.9), -0.5)
				var d: Vector2 = goal - (pos[id] as Vector2)
				var sp := 1.6 if id == "kid" else 1.1
				var mv: Vector2 = d.normalized() * minf(1.0, d.length() / 0.4) if d.length() > 0.1 else Vector2.ZERO
				var rr := 0.36 * (0.75 if id == "kid" else 1.0) + 0.04
				var others := reg.agent_list(id) + [[here, 0.35]]   # (he stops for the hero: ClubNpcLife._step)
				var to := walk.resolve(pos[id], pos[id] + mv * sp * DT, rr, others)
				pos[id] = to
				b.max_speed = sp * 1.25
				b.move_input = (Vector2(to.x - b.position.x, to.y - b.position.z) / 0.35).limit_length(1.0) if Vector2(to.x - b.position.x, to.y - b.position.z).length() > 0.04 else Vector2.ZERO
			# the club's own frame (Club._physics_process): out of the bodies, onto the ground
			hero._physics_process(DT)
			for id in people:
				var nb: Athlete = people[id]
				nb._physics_process(DT)   # (it clamps into its area and puts him at height 0)
				nb.position.y = walk.floor_at(Vector2(nb.position.x, nb.position.z))   # ClubNpcLife._drive_body puts him on the ground after it
			var at := walk.resolve(here, Vector2(hero.position.x, hero.position.z), 0.35, reg.agent_list())
			hero.position = Vector3(at.x, hero_y, at.y)
			hero_y = move_toward(hero_y, walk.floor_at(at), 1.6 * DT)
			hero.position.y = hero_y
			ath = hero
			step_process_only(hero)
			for id in people:
				step_process_only(people[id])
			# what to look at
			var now := Vector2(hero.position.x, hero.position.z)
			worst["jump"] = maxf(worst["jump"], now.distance_to(last))
			if now.distance_to(last) < 0.2 * hero.max_speed * DT:
				held += DT
				worst_held = maxf(worst_held, held)
			else:
				held = 0.0
			last = now
			worst["yaw"] = maxf(worst["yaw"], absf(angle_difference(last_yaw, hero.rotation.y)))
			last_yaw = hero.rotation.y
			for a in reg.agent_list():
				var gap := now.distance_to(a[0]) - (float(a[1]) + 0.35)
				worst["overlap"] = minf(worst["overlap"], gap)
			worst["off"] = maxf(worst["off"], absf(hero.position.y - walk.floor_at(now)))
			if frames > 20:
				var legs := _crowd_legs(hero, hero.position.y)
				if legs.x < worst["sink"]:
					worst["sink_who"] = "hero f%d y%.3f floor %.3f" % [frames, hero.position.y, walk.floor_at(now)]
				worst["sink"] = minf(worst["sink"], legs.x)
				worst["stretch"] = maxf(worst["stretch"], legs.y)
				for id in people:
					var lb := _crowd_legs(people[id], walk.floor_at(Vector2(people[id].position.x, people[id].position.z)))
					if lb.x < worst["sink"]:
						worst["sink_who"] = "%s f%d y%.3f floor %.3f speed %.2f" % [id, frames, people[id].position.y, walk.floor_at(Vector2(people[id].position.x, people[id].position.z)), people[id].velocity.length()]
					worst["sink"] = minf(worst["sink"], lb.x)
					worst["stretch"] = maxf(worst["stretch"], lb.y)
		results.append([jog, hero.position.z, frames, worst_held])
	for r in results:
		check(r[1] <= -9.0, "%s through the crowd to the far end in %.1f s (z %.1f)" % ["jogging" if r[0] else "walking", r[2] * DT, r[1]])
		check(r[3] < 1.5, "%s: never held up for long by anybody (%.2f s)" % ["jogging" if r[0] else "walking", r[3]])
	check(worst["overlap"] > -0.03, "never inside anybody (deepest %.3f m)" % worst["overlap"])
	check(worst["jump"] < 0.16, "no jump in his position, no shove (largest step %.3f m a frame)" % worst["jump"])
	check(worst["yaw"] < 0.7, "he turns smoothly (largest turn %.2f rad a frame)" % worst["yaw"])
	check(worst["off"] < 0.03, "he stands on the ground, on the ramp and the room's floor (off by %.3f m)" % worst["off"])
	check(worst["sink"] > -0.06 and worst["stretch"] < 0.02, "every pair of feet on the ground, legs whole (sink %.3f %s, stretch %.3f)" % [worst["sink"], worst["sink_who"], worst["stretch"]])
	kid.free()
	old.free()


## The pose of an athlete as Athlete._process draws it (without its physics).
func step_process_only(a: Athlete) -> void:
	a._process(DT)


## The lowest shoe above the ground it stands on (negative: sunk) and how far the thigh and the
## shin are from their lengths, for the athlete `a` standing at ground height `floor_y`.
func _crowd_legs(a: Athlete, floor_y: float) -> Vector2:
	var keep := ath
	ath = a
	var feet := feet_world()
	var low := minf((feet[0] as Vector3).y, (feet[1] as Vector3).y) - floor_y
	var stretch := 0.0
	for i in 2:
		var th: Array = bone_ends("thigh%d" % i)
		var sh: Array = bone_ends("shin%d" % i)
		stretch = maxf(stretch, absf(((th[1] as Vector3) - (th[0] as Vector3)).length() - Athlete.THIGH))
		stretch = maxf(stretch, absf(((sh[1] as Vector3) - (sh[0] as Vector3)).length() - Athlete.SHIN))
	ath = keep
	return Vector2(low, stretch)
