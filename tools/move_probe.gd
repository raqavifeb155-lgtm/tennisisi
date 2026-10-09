extends SceneTree
## Movement probe: the autoplay bot plays practice points against the AI while this
## samples both athletes every physics tick and prints movement numbers that can be held
## against tracking data of real players (docs/MOVEMENT_REALISM.md):
##   run speed (mean / p90 / peak), acceleration and braking (p90 / peak), distance per
##   shot, the lateral share of running, direction changes per shot, the time from the
##   other's contact to the first step (reaction), the split step relative to that
##   contact, where the player stands when the other one hits (recovery), the time
##   between shots, ball speed and spin per stroke, the unit turn and swing lengths.
##   godot --headless --path . --fixed-fps 60 -s tools/move_probe.gd -- --points=60 --location=hard --seed=1
## --csv=path also writes every tick (t, who, x, z, vx, vz, speed, acc, mode) for plots.

var main: Node
var frame := 0
var seed_v := 1
var csv_path := ""
var sampler: Sampler


class Track:
	var name := ""
	var speeds: Array[float] = []      # m/s, every rally tick
	var accs: Array[float] = []        # m/s2 speeding up (along the velocity)
	var brakes: Array[float] = []      # m/s2 slowing down
	var lat := 0.0                     # metres run sideways (x)
	var depth := 0.0                   # metres run forward/back (z)
	var per_shot: Array[float] = []    # metres from the other's contact to the own contact
	var peak_per_shot: Array[float] = []
	var turns_per_shot: Array[int] = []
	var react: Array[float] = []       # s: other's contact -> moving at 1 m/s
	var to3: Array[float] = []         # s: other's contact -> 3 m/s (if reached)
	var split_rel: Array[float] = []   # s: split step start - other's contact (- = before)
	var stand_z: Array[float] = []     # m behind own baseline when the other hits
	var stand_x: Array[float] = []
	var speed_at_hit: Array[float] = []
	var prep_to_hit: Array[float] = [] # s: unit turn start -> contact
	var swing_to_hit: Array[float] = [] # s: visible swing start -> contact
	# per-shot state
	var since := -1.0
	var run := 0.0
	var peak := 0.0
	var turns := 0
	var react_done := false
	var to3_done := false
	var last_dir := Vector2.ZERO
	var prev_mode := 0
	var prep_at := -1.0
	var swing_at := -1.0
	var prev_hop := 1.0
	var last_other_hit := -10.0
	var last_split := -10.0
	var split_counted := true
	var shot_kmh: Array[float] = []
	var shot_spin: Array[float] = []
	var gaps: Array[float] = []         # s between this side's contact and the other's next

	func reset_shot(t: float) -> void:
		since = t
		run = 0.0
		peak = 0.0
		turns = 0
		react_done = false
		to3_done = false
		last_dir = Vector2.ZERO


class Sampler extends Node:
	var probe
	func _physics_process(delta: float) -> void:
		probe.tick(delta)


var tr := [Track.new(), Track.new()]
var t := 0.0
var prev_vel := [Vector3.ZERO, Vector3.ZERO]
var rows := PackedStringArray()
var last_shot_t := -1.0
var last_shot_who := -1
var loc := "?"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_v = int(a.get_slice("=", 1))
		elif a.begins_with("--csv="):
			csv_path = a.get_slice("=", 1)
	tr[0].name = "PLAYER(bot)"
	tr[1].name = "CPU(AI)"
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.autoplay = true
	root.add_child(main)
	sampler = Sampler.new()
	sampler.probe = self
	sampler.process_physics_priority = 100  # after Main moved everybody
	root.add_child(sampler)
	root.get_node("GameEvents").shot.connect(_on_shot)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		main.rng.seed = seed_v
		main.ai.rng.seed = seed_v + 1
		loc = str(main.location_id)
	return false


func _ath(who: int) -> Athlete:
	return main.player if who == 0 else main.cpu


func _on_shot(who: int, info: Dictionary) -> void:
	var me: Track = tr[who]
	var other: Track = tr[1 - who]
	var a := _ath(who)
	if not bool(info.get("serve", false)):
		me.shot_kmh.append(float(info["speed"]) * 3.6)
		me.shot_spin.append(float(info["top"]))
	if me.since >= 0.0 and not bool(info.get("serve", false)):
		me.per_shot.append(me.run)
		me.peak_per_shot.append(me.peak)
		me.turns_per_shot.append(me.turns)
		me.speed_at_hit.append(Athlete.speed_of(a.velocity))
		if me.prep_at >= 0.0:
			me.prep_to_hit.append(t - me.prep_at)
		if me.swing_at >= 0.0:
			me.swing_to_hit.append(t - me.swing_at)
	if last_shot_t >= 0.0 and last_shot_who == 1 - who:
		other.gaps.append(t - last_shot_t)
	last_shot_t = t
	last_shot_who = who
	me.prep_at = -1.0
	me.swing_at = -1.0
	me.since = -1.0
	# The other side now has a ball coming: their shot interval starts.
	var oa := _ath(1 - who)
	other.reset_shot(t)
	other.last_other_hit = t
	other.split_counted = false
	if t - other.last_split <= 0.4:
		other.split_rel.append(other.last_split - t)  # took off before this contact
		other.split_counted = true
	other.stand_z.append(absf(oa.position.z) - 11.885)
	other.stand_x.append(oa.position.x)


func tick(delta: float) -> void:
	t += delta
	if main.phase != main.Phase.RALLY:
		for i in 2:
			prev_vel[i] = _ath(i).velocity
			tr[i].prev_hop = _ath(i)._hop
		return
	for i in 2:
		var a := _ath(i)
		var k: Track = tr[i]
		var v := Vector2(a.velocity.x, a.velocity.z)
		var pv := Vector2(prev_vel[i].x, prev_vel[i].z)
		var sp := v.length()
		var dv := (v - pv) / delta
		var along := dv.dot(v.normalized()) if sp > 0.2 else dv.length()
		k.speeds.append(sp)
		if along > 0.5:
			k.accs.append(along)
		elif along < -0.5:
			k.brakes.append(-along)
		k.lat += absf(v.x) * delta
		k.depth += absf(v.y) * delta
		if csv_path != "":
			rows.append("%.3f,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%d" % [t, i, a.position.x, a.position.z, v.x, v.y, sp, along, a._mode])
		if k.since >= 0.0:
			k.run += sp * delta
			k.peak = maxf(k.peak, sp)
			if sp > 1.0:
				var d := v / sp
				if k.last_dir != Vector2.ZERO and d.dot(k.last_dir) < 0.0:
					k.turns += 1
				k.last_dir = d
			var since := t - k.since
			if not k.react_done and sp >= 1.0:
				k.react_done = true
				k.react.append(since)
			if not k.to3_done and sp >= 3.0:
				k.to3_done = true
				k.to3.append(since)
			if a._mode == 1 and k.prev_mode != 1 and k.prep_at < 0.0:
				k.prep_at = t
			if a._mode == 2 and k.prev_mode != 2:
				k.swing_at = t  # the racket starts forward (into the slot or the stroke)
				if k.prep_at < 0.0:
					k.prep_at = t
		if a._hop < 0.05 and k.prev_hop >= 0.05:
			k.last_split = t
			if not k.split_counted and t - k.last_other_hit <= 0.4:
				k.split_rel.append(t - k.last_other_hit)  # took off after the contact
				k.split_counted = true
		k.prev_hop = a._hop
		k.prev_mode = a._mode
		prev_vel[i] = a.velocity


static func _pct(arr: Array, p: float) -> float:
	if arr.is_empty():
		return NAN
	var s := arr.duplicate()
	s.sort()
	return float(s[clampi(int(round(p * (s.size() - 1))), 0, s.size() - 1)])


static func _mean(arr: Array) -> float:
	if arr.is_empty():
		return NAN
	var s := 0.0
	for x in arr:
		s += float(x)
	return s / arr.size()


func _line(label: String, arr: Array, unit: String) -> String:
	return "  %-26s n=%-4d mean %6.2f  p10 %6.2f  p50 %6.2f  p90 %6.2f  max %6.2f %s" % [label, arr.size(), _mean(arr), _pct(arr, 0.1), _pct(arr, 0.5), _pct(arr, 0.9), _pct(arr, 1.0), unit]


func _finalize() -> void:
	_report()


func _report() -> void:
	print("\n=== MOVE PROBE (location %s, seed %d) ===" % [loc, seed_v])
	for k: Track in tr:
		print(k.name)
		print(_line("run speed (rally ticks)", k.speeds, "m/s"))
		var moving: Array[float] = []
		for s in k.speeds:
			if s > 0.5:
				moving.append(s)
		print(_line("run speed while moving", moving, "m/s"))
		print(_line("acceleration", k.accs, "m/s2"))
		print(_line("braking", k.brakes, "m/s2"))
		print(_line("distance per shot", k.per_shot, "m"))
		print(_line("peak speed per shot", k.peak_per_shot, "m/s"))
		print(_line("direction changes / shot", k.turns_per_shot, ""))
		print(_line("first step (>=1 m/s)", k.react, "s after other's contact"))
		print(_line("reach 3 m/s", k.to3, "s after other's contact"))
		print(_line("split step", k.split_rel, "s rel. other's contact"))
		print(_line("stand behind baseline", k.stand_z, "m when other hits"))
		print(_line("speed at own contact", k.speed_at_hit, "m/s"))
		print(_line("unit turn -> contact", k.prep_to_hit, "s"))
		print(_line("swing start -> contact", k.swing_to_hit, "s"))
		print(_line("ball speed (rally)", k.shot_kmh, "km/h"))
		print(_line("spin value (rally)", k.shot_spin, "rpm"))
		print(_line("time to other's contact", k.gaps, "s"))
		var tot := k.lat + k.depth
		print("  lateral share of running   %.0f%%  (x %.0f m, z %.0f m)" % [100.0 * k.lat / maxf(tot, 0.001), k.lat, k.depth])
	if csv_path != "":
		var f := FileAccess.open(csv_path, FileAccess.WRITE)
		f.store_line("t,who,x,z,vx,vz,speed,acc_along,mode")
		for r in rows:
			f.store_line(r)
		f.close()
		print("csv -> %s (%d rows)" % [csv_path, rows.size()])
