extends SceneTree
## Headless physics sanity tests:
##   godot --headless --path . -s tests/run_tests.gd

var failures := 0


func _init() -> void:
	test_drop_bounce()
	test_topspin_dips()
	test_topspin_kicks_on_bounce()
	test_solver_accuracy()
	test_net_collision()
	test_scoring()
	test_service_box()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


## ITF: dropped from 254 cm a ball must rebound 135-147 cm.
func test_drop_bounce() -> void:
	print("drop bounce")
	var s := BallPhysics.State.new(Vector3(0, 2.54, 5), Vector3.ZERO, Vector3.ZERO)
	var bounced := false
	var apex := 0.0
	for i in 2400:
		var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
		if ev == BallPhysics.Event.BOUNCE:
			if bounced:
				break
			bounced = true
		if bounced:
			apex = maxf(apex, s.pos.y)
	check(apex > 1.30 and apex < 1.50, "rebound height %.2f m (ITF 1.35-1.47)" % apex)


func flight_range(v: Vector3, spin_rad: float) -> float:
	var dir := Vector3(0, 0, -1)
	var s := BallPhysics.State.new(Vector3(0, 1.0, 11.0), v, BallPhysics.topspin_vector(dir, spin_rad))
	for i in 4000:
		if BallPhysics.substep(s, BallPhysics.MAX_STEP) == BallPhysics.Event.BOUNCE:
			return 11.0 - s.pos.z
	return INF


func test_topspin_dips() -> void:
	print("topspin dips, slice floats")
	var v := Vector3(0, 4.0, -25.0)
	var flat := flight_range(v, 0.0)
	var top := flight_range(v, 300.0)
	var slice := flight_range(v, -200.0)
	check(top < flat - 2.0, "topspin lands shorter: top %.1f m vs flat %.1f m" % [top, flat])
	check(slice > flat, "slice carries further: slice %.1f m vs flat %.1f m" % [slice, flat])


func test_topspin_kicks_on_bounce() -> void:
	print("bounce behaviour vs spin")
	var results := {}
	for spin in [300.0, 0.0, -200.0]:
		var s := BallPhysics.State.new(Vector3(0, 0.5, 0), Vector3(0, -6.0, -20.0), BallPhysics.topspin_vector(Vector3(0, 0, -1), spin))
		for i in 400:
			if BallPhysics.substep(s, BallPhysics.MAX_STEP) == BallPhysics.Event.BOUNCE:
				break
		results[spin] = s.vel
	var top: Vector3 = results[300.0]
	var flat: Vector3 = results[0.0]
	var slc: Vector3 = results[-200.0]
	check(-top.z > -flat.z, "topspin keeps more forward speed: %.1f vs flat %.1f m/s" % [-top.z, -flat.z])
	check(-slc.z <= -flat.z + 0.5, "slice does not kick forward: %.1f vs flat %.1f m/s" % [-slc.z, -flat.z])
	check(top.y > slc.y, "topspin bounces steeper than slice: vy %.2f vs %.2f" % [top.y, slc.y])


func test_solver_accuracy() -> void:
	print("shot solver lands on target")
	var cases := [
		[Vector3(1.0, 0.9, 11.5), Vector3(-3.0, 0.033, -10.0), 28.0, 250.0],
		[Vector3(-2.0, 0.6, 12.5), Vector3(3.5, 0.033, -9.0), 35.0, 40.0],
		[Vector3(0.0, 1.2, 10.0), Vector3(0.0, 0.033, -4.0), 15.0, -150.0],
		[Vector3(0.5, 1.0, -12.0), Vector3(2.0, 0.033, 10.5), 24.0, 200.0],
	]
	for c in cases:
		var p0: Vector3 = c[0]
		var target: Vector3 = c[1]
		var t0 := Time.get_ticks_usec()
		var r := ShotSolver.solve(p0, target, c[2], c[3])
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var s := BallPhysics.State.new(p0, r.velocity, r.spin)
		var landing := Vector3.ZERO
		var netted := false
		for i in 4000:
			var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
			if ev == BallPhysics.Event.NET:
				netted = true
			if ev == BallPhysics.Event.BOUNCE:
				landing = s.pos
				break
		var err := Vector2(landing.x - target.x, landing.z - target.z).length()
		check(r.ok and not netted and err < 0.35,
			"target %s: err %.2f m, speed %.1f->%.1f m/s, elev %.1f deg, %.1f ms" % [target, err, c[2], r.speed, r.elevation_deg, ms])


func test_net_collision() -> void:
	print("net collision")
	var s := BallPhysics.State.new(Vector3(0, 0.5, 5.0), Vector3(0, 0.5, -20.0), Vector3.ZERO)
	var got_net := false
	for i in 2000:
		var ev := BallPhysics.substep(s, BallPhysics.MAX_STEP)
		if ev == BallPhysics.Event.NET:
			got_net = true
		if ev == BallPhysics.Event.BOUNCE:
			break
	check(got_net and s.pos.z > 0.0, "low ball hits the net and drops on hitter's side (z=%.2f)" % s.pos.z)


func test_scoring() -> void:
	print("tennis scoring")
	var sc := TennisScore.new()
	for i in 3:
		sc.add_point(0)
	check(sc.point_text() == "YOU  40 : 0  CPU", "40-0: '%s'" % sc.point_text())
	for i in 3:
		sc.add_point(1)
	check(sc.point_text() == "DEUCE", "deuce: '%s'" % sc.point_text())
	sc.add_point(1)
	check(sc.point_text() == "AD CPU" and not sc.deuce_side(), "advantage CPU served from ad side")
	sc.add_point(0)
	check(sc.point_text() == "DEUCE", "back to deuce")
	sc.add_point(0)
	var game := sc.add_point(0)
	check(game and sc.games == [1, 0] and sc.server == 1, "game to player, server switches")


func test_service_box() -> void:
	print("service boxes")
	# Player serving from the deuce side (x > 0) must land in the CPU box with x < 0.
	check(Court.in_service_box(Vector3(-2.0, 0, -5.0), -1, -1.0, BallPhysics.RADIUS), "diagonal box: in")
	check(not Court.in_service_box(Vector3(2.0, 0, -5.0), -1, -1.0, BallPhysics.RADIUS), "wrong box: fault")
	check(not Court.in_service_box(Vector3(-2.0, 0, -7.0), -1, -1.0, BallPhysics.RADIUS), "past service line: fault")
	check(Court.in_service_box(Vector3(0.01, 0, -6.42), -1, -1.0, BallPhysics.RADIUS), "touching lines: in")
