extends SceneTree
## Gait probe: a lone Athlete runs at fixed speeds (forward and sideways) and this prints
## how far a planted foot slides over the court per step (foot skating), the step rate
## and the step length, to hold against real running (docs/MOVEMENT_REALISM.md).
##   godot --headless --path . --fixed-fps 60 -s tools/gait_probe.gd

const DT := 1.0 / 60.0
var ath: Athlete
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	for dir in [Vector2(0, -1), Vector2(1, 0)]:
		for v in [1.0, 2.0, 3.0, 4.0, 5.0, 6.2]:
			_run(v, dir)
	ath.free()
	quit(0)
	return true


func _foot_world(i: int) -> Vector3:
	var sh: Array = ath._ends["shin%d" % i]
	return ath._model.global_transform * (sh[1] as Vector3)


func _run(v: float, dir: Vector2) -> void:
	if ath:
		ath.free()
	ath = Athlete.new()
	root.add_child(ath)
	ath.setup(-1.0, Color(0.9, 0.3, 0.2), Rect2(-200, -200, 400, 400))
	ath.position = Vector3.ZERO
	ath.max_speed = v
	ath.move_input = dir
	var prev := [Vector3.INF, Vector3.INF]
	var slide := 0.0
	var planted_t := 0.0
	var steps := 0
	var was_down := [false, false]
	var t := 0.0
	var plant_x := [Vector3.ZERO, Vector3.ZERO]
	var step_len := 0.0
	for f in 240:
		ath._physics_process(DT)
		ath._process(DT)
		t += DT
		if t < 1.0:
			continue
		for i in 2:
			var p := _foot_world(i)
			var down := p.y < 0.07
			if down and prev[i] != Vector3.INF and was_down[i]:
				slide += Vector2(p.x - prev[i].x, p.z - prev[i].z).length()
				planted_t += DT
			if down and not was_down[i]:
				steps += 1
				if plant_x[i] != Vector3.ZERO:
					step_len += Vector2(p.x - plant_x[i].x, p.z - plant_x[i].z).length() * 0.5
				plant_x[i] = p
			was_down[i] = down
			prev[i] = p
	var dur := t - 1.0
	print("%-8s v=%.1f m/s  steps %.1f /s  step %.2f m  foot slide while planted %.2f m/s (%.0f%% of body speed)" % ["forward" if dir.y != 0 else "sideways", v, steps / dur, step_len / maxf(steps - 2, 1), slide / maxf(planted_t, 0.001), 100.0 * slide / maxf(planted_t, 0.001) / v])
