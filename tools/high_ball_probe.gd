extends SceneTree
## Probe for balls above the usual strike zone but below the smash threshold (F-D):
##   godot --headless --path . --fixed-fps 60 -s tools/high_ball_probe.gd [-- --body=1 --verbose]
## Swings at balls 1.4..2.2 m high, in front and a little to the side, forehand and
## backhand, from the ready stance and from a full takeback, and prints per case the worst
## elbow bend, the worst turn of the racket / hand between two frames, and how deep the
## racket goes into the head / trunk.

const DT := 1.0 / 60.0
var ath: Athlete
var _ran := false
var verbose := false
var only := ""        # --case=h,side,lat,fwd: one case, frame by frame (with --verbose)


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--body="):
			Athlete.body_style = int(a.get_slice("=", 1))
		elif a.begins_with("--case="):
			only = a.get_slice("=", 1)
		elif a == "--verbose":
			verbose = true
	run()
	quit(0)
	return true


func step() -> void:
	ath._physics_process(DT)
	ath._process(DT)


func fresh() -> void:
	if ath:
		ath.free()
	Athlete.surface = "hard"
	ath = Athlete.new()
	root.add_child(ath)
	ath.setup(-1.0, Color(0.9, 0.3, 0.2), Rect2(-12, -14, 24, 34))
	ath.position = Vector3(0, 0, 11)
	for i in 30:
		step()


func run() -> void:
	if only != "":
		var q := only.split(",")
		probe(float(q[0]), int(q[1]), float(q[2]), float(q[3]), true)
		return
	for h in [0.95, 1.4, 1.6, 1.8, 2.0, 2.2]:
		for side in [1, -1]:
			for lat in [0.5, 0.75, 1.0]:
				for fwd in [0.5, 0.8]:
					for pre in [true, false]:
						probe(h, side, lat, fwd, pre)


func probe(h: float, side: int, lat: float, fwd: float, pre: bool) -> void:
	fresh()
	ath.prepare(side)
	if pre:
		for i in 40:
			step()
	var c := Vector3(lat * side, h, -fwd)
	ath.swing(side, 0.3, ath.to_global(c), Athlete.Style.TOPSPIN)
	var r := Athlete.UPPER_ARM
	var min_elbow := 999.0
	var max_wrist := 0.0
	var max_rjump := 0.0
	var max_hjump := 0.0
	var max_ejump := 0.0
	var prev_r: Vector3 = ath._rdir
	var prev_h := Vector3.ZERO
	var prev_e := Vector3.ZERO
	var deep := 0.0
	var worst_f := ""
	var worst_back := -9.0
	var head_close := 9.0     # closest the forearm / hand gets to the head centre
	var hand_x_at := 9.0      # the hand's x (model space) at contact
	var f := 0
	var first := true
	while f < 150 and (ath.is_swinging() or f < 5):
		step()
		f += 1
		var up: Array = ath._ends["upper_r"]
		var fo: Array = ath._ends["fore_r"]
		var sh: Vector3 = up[0]
		var el: Vector3 = up[1]
		var hd: Vector3 = fo[1]
		var ua := (el - sh).normalized()
		var fa := (hd - el).normalized()
		var elbow_deg := rad_to_deg(ua.angle_to(fa))   # 0 = straight
		var rd: Vector3 = ath._racket.transform.basis.y
		var wrist_deg := rad_to_deg(fa.angle_to(rd))
		var rj := 0.0
		var hj := 0.0
		var ej := 0.0
		if not first:
			rj = rad_to_deg(prev_r.angle_to(rd))
			hj = (hd - prev_h).length()
			ej = (el - prev_e).length()
		first = false
		prev_r = rd
		prev_h = hd
		prev_e = el
		var head: Vector3 = ath._head.position
		# racket shaft + head vs the head sphere
		var cp := Geometry3D.get_closest_point_to_segment(head, hd, hd + rd * 0.62)
		var dd := cp.distance_to(head)
		var pen := maxf(0.0, 0.17 - dd)
		if pen > deep:
			deep = pen
		head_close = minf(head_close, Geometry3D.get_closest_point_to_segment(head, el, hd).distance_to(head))
		if absf(ath._clock - ath._contact_at) < 0.009:
			hand_x_at = hd.x
		var tw := Basis(Vector3.UP, ath._twist)
		var back: float = (tw.inverse() * (hd - sh)).z
		worst_back = maxf(worst_back, back)
		if elbow_deg > min_elbow or true:
			pass
		min_elbow = minf(min_elbow, 180.0 - elbow_deg)
		max_wrist = maxf(max_wrist, wrist_deg)
		if rj > max_rjump:
			max_rjump = rj
			worst_f = "f%d clock-contact %.3f" % [f, ath._clock - ath._contact_at]
		max_hjump = maxf(max_hjump, hj)
		max_ejump = maxf(max_ejump, ej)
		if verbose:
			print("   f%3d dt=%.3f elbow=%5.1f wrist=%5.1f rjump=%5.1f hjump=%.3f ejump=%.3f hand=%s" % [f, ath._clock - ath._contact_at, 180.0 - elbow_deg, wrist_deg, rj, hj, ej, hd])
	print("%s h=%.2f lat=%.2f fwd=%.2f %s: minElbow=%5.1f maxWrist=%5.1f maxRacketJump=%5.1f (%s) maxHandJump=%.3f maxElbowJump=%.3f racketInHead=%.2f handBack=%.2f headDist=%.2f handX=%.2f" % ["FH" if side > 0 else "BH", h, lat, fwd, "takeback" if pre else "cold    ", min_elbow, max_wrist, max_rjump, worst_f, max_hjump, max_ejump, deep, worst_back, head_close, hand_x_at])
