extends SceneTree
## Contact sheets of the stance change (forehand <-> backhand) on the move, with a check
## of where the hands and elbows are against the trunk (AthleteProbe):
##   godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/stance_shots.gd -- \
##       --scenario=back --dir=fh2bh --tag=before --out=/tmp/stance
## Scenarios: back (running back), fwd (running in), still (on the spot), side (running
## right, then turning round to the left), side_keep (the same without turning round),
## back_swing (running back, change, then swing). --dir=fh2bh|bh2fh. --all draws every
## scenario in a row and prints one table. Twelve frames at equal intervals, 4x3 sheet; each
## cell is the phone-sized 720x1564 frame: the 3/4 view from behind and the side above,
## and the view from above below it (forward is up). A red frame marks a cell where a hand,
## an elbow or a forearm is through the trunk or behind the back plane.
## --frames: also list every flagged frame. --metrics: no pictures, only the table (works headless).

const FRAMES := 12
const STEP := 0.07            # seconds between the cells
const FULL := Vector2i(720, 1564)
const VIEW_A := Vector2i(720, 1000)
const VIEW_B := Vector2i(720, 564)
const OUT_SCALE := 2.0 / 3.0

var ath: Athlete
var views: Array[SubViewport] = []
var label: Label
var scenario := "back"
var dir := "fh2bh"
var tag := ""
var out_dir := "/tmp/stance"
var metrics_only := false
var run_all := false
var per_frame := false
var queue: Array = []
var frame := 0
var first := 1
var t0_frame := 0
var samples: Array = []        # frames to capture
var images: Array = []         # per sample: composed Image
var rows: Array = []           # per sample: [k, t, problems]
var all_rows: Array = []       # across scenarios, for the final table
var worst_frames := 0
var cur := 0
var ground: MeshInstance3D
var done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.get_slice("=", 1)
		elif a.begins_with("--dir="):
			dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1)
		elif a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--body="):
			Athlete.body_style = int(a.get_slice("=", 1))
		elif a == "--metrics":
			metrics_only = true
		elif a == "--frames":
			per_frame = true
		elif a == "--all":
			run_all = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	if run_all:
		for sc in AthleteProbe.SCENARIOS:
			for d in ["fh2bh", "bh2fh"]:
				queue.append([sc, d])
	else:
		queue.append([scenario, dir])
	if not metrics_only:
		_build_world()
	_next_run()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	root.add_child(sun)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.38, 0.66)
	ground.material_override = gm
	root.add_child(ground)
	for sz in [VIEW_A, VIEW_B]:
		var vp := SubViewport.new()
		vp.size = sz
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		root.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 40.0
		vp.add_child(cam)
		views.append(vp)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(14, 10)
	views[1].add_child(label)


func _next_run() -> void:
	if queue.is_empty():
		_finish()
		return
	var q: Array = queue.pop_front()
	scenario = q[0]
	dir = q[1]
	first = 1 if dir == "fh2bh" else -1
	if ath:
		ath.queue_free()
	Athlete.surface = "hard"
	ath = Athlete.new()
	root.add_child(ath)
	ath.setup(-1.0, Color(0.92, 0.36, 0.26), Rect2(-12, -14, 24, 34))
	ath.position = AthleteProbe.start_of(scenario)
	if ground:
		ground.position = ath.position
	frame = 0
	images.clear()
	rows.clear()
	worst_frames = 0
	var sw := roundi(AthleteProbe.SWITCH_AT * 60.0)
	var step := roundi(STEP * 60.0)
	samples.clear()
	for k in FRAMES:
		samples.append(sw - step + k * step)
	cur = 0


func _process(_delta: float) -> bool:
	if done:
		return true
	if ath == null:
		return false
	AthleteProbe.drive(ath, scenario, frame, first)
	var p := Vector3(ath.position.x, 0, ath.position.z)
	if not views.is_empty():
		views[0].get_camera_3d().look_at_from_position(p + Vector3(1.9, 1.65, 2.5), p + Vector3(0, 1.05, 0), Vector3.UP)
		views[1].get_camera_3d().look_at_from_position(p + Vector3(0, 3.6, 0.01), p + Vector3(0, 1.0, 0), Vector3(0, 0, -1))
		ground.position = p
	if frame > 0 and not AthleteProbe.problems(ath).is_empty():
		worst_frames += 1
		if per_frame:
			print("FRAME | %s %s | f%d t=%.2f | %s" % [scenario, dir, frame, float(frame) / 60.0, ", ".join(AthleteProbe.problems(ath))])
	if cur < samples.size() and frame == samples[cur]:
		var k := cur
		cur += 1
		if metrics_only:
			rows.append([k, float(frame) / 60.0, AthleteProbe.problems(ath)])
		else:
			var bad := AthleteProbe.problems(ath)
			label.text = "%s %s  #%02d  t=%.2f s%s" % [scenario, dir, k + 1, float(frame) / 60.0, ("\n" + ", ".join(bad)) if not bad.is_empty() else ""]
			_capture.call_deferred(k, frame, bad)
	frame += 1
	if frame > samples.back() + 3 and (metrics_only or rows.size() == FRAMES):
		_save_run()
		_next_run()
	return false


func _capture(k: int, f: int, bad: Array) -> void:
	await RenderingServer.frame_post_draw
	var a: Image = views[0].get_texture().get_image()
	var b: Image = views[1].get_texture().get_image()
	var img := Image.create(FULL.x, FULL.y, false, a.get_format())
	img.blit_rect(a, Rect2i(Vector2i.ZERO, VIEW_A), Vector2i.ZERO)
	img.blit_rect(b, Rect2i(Vector2i.ZERO, VIEW_B), Vector2i(0, VIEW_A.y))
	if not bad.is_empty():
		var red := Color(0.95, 0.1, 0.1)
		img.fill_rect(Rect2i(0, 0, FULL.x, 10), red)
		img.fill_rect(Rect2i(0, FULL.y - 10, FULL.x, 10), red)
		img.fill_rect(Rect2i(0, 0, 10, FULL.y), red)
		img.fill_rect(Rect2i(FULL.x - 10, 0, 10, FULL.y), red)
	img.resize(int(FULL.x * OUT_SCALE), int(FULL.y * OUT_SCALE), Image.INTERPOLATE_LANCZOS)
	images.append([k, img])
	rows.append([k, float(f) / 60.0, bad])


func _save_run() -> void:
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	if not metrics_only:
		images.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		var cw := int(FULL.x * OUT_SCALE)
		var ch := int(FULL.y * OUT_SCALE)
		var sheet := Image.create(cw * 4, ch * 3, false, (images[0][1] as Image).get_format())
		for i in images.size():
			sheet.blit_rect(images[i][1], Rect2i(0, 0, cw, ch), Vector2i((i % 4) * cw, (i / 4) * ch))
		var path := "%s/stance_%s_%s%s.png" % [out_dir, scenario, dir, ("_" + tag) if tag != "" else ""]
		sheet.save_png(path)
		print("saved ", path)
	var flagged := 0
	for r in rows:
		if not (r[2] as Array).is_empty():
			flagged += 1
			print("TABLE | %s %s | #%02d t=%.2f | %s" % [scenario, dir, r[0] + 1, r[1], ", ".join(r[2])])
	print("SUMMARY | %s %s | cells flagged %d/12 | frames flagged %d" % [scenario, dir, flagged, worst_frames])


func _finish() -> void:
	done = true
	quit(0)
