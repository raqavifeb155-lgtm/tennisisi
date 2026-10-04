extends SceneTree
## Frame-by-frame snapshots of the player's strokes, for reviewing the animation.
## Renders the Athlete alone on a plain court at fixed moments of a stroke and saves
## one contact sheet per stroke:
## rows: 3/4 front, right side, and behind-above (like the game camera); time runs
## left to right. The ball flies in, meets the strings at contact and flies away.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 60 \
##       -s tools/pose_shots.gd -- --stroke=fh --out=/tmp/poses
## Strokes: fh (forehand topspin), bh (two-handed backhand), bh1 (one-handed backhand),
## sl (slice), serve, walk, dive.

const CELL := Vector2i(260, 340)

var ath: Athlete
var ball: MeshInstance3D
var views: Array[SubViewport] = []
var cam_offsets: Array = []      # [camera position, look point] relative to the player
var frame := 0
var plan: Array = []            # [frame, Callable] actions
var shots: Array = []           # frames to capture
var images: Array = []          # per shot: [Image, Image]
var stroke := "fh"
var out_dir := "/tmp/poses"
var done_frame := 0
var ball_contact := Vector3.ZERO  # world contact point
var ball_frame := -1              # frame of contact
var ball_in := Vector3.ZERO       # incoming velocity (m/s)
var ball_out := Vector3.ZERO      # outgoing velocity (m/s)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stroke="):
			stroke = a.get_slice("=", 1)
		elif a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)

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
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.38, 0.66)
	ground.material_override = gm
	root.add_child(ground)
	for x in [-4.115, 4.115]:
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.01, 12)
		line.mesh = bm
		line.position = Vector3(x, 0.005, 0)
		root.add_child(line)

	ath = Athlete.new()
	root.add_child(ath)
	ath.setup(-1.0, Color(0.92, 0.36, 0.26), Rect2(-9, -9, 18, 18))
	ath.position = Vector3.ZERO

	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	ball.mesh = sm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.86, 0.95, 0.2)
	bmat.emission_enabled = true
	bmat.emission = Color(0.5, 0.6, 0.1)
	ball.material_override = bmat
	ball.visible = false
	root.add_child(ball)

	# Two cameras: 3/4 from the front-right, and from the player's right side.
	for cfg in [[Vector3(2.2, 1.5, -2.6), Vector3(0.15, 1.0, -0.2)], [Vector3(3.4, 1.2, -0.1), Vector3(0.0, 1.0, -0.2)], [Vector3(0.3, 3.2, 3.6), Vector3(0.0, 0.9, -0.3)]]:
		var vp := SubViewport.new()
		vp.size = CELL
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		root.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 36.0
		vp.add_child(cam)
		cam.look_at_from_position(cfg[0], cfg[1], Vector3.UP)
		cam_offsets.append(cfg)
		views.append(vp)

	_build_plan()


func _at(t: float) -> int:
	return roundi(t * 60.0)


## Schedules the stroke and the moments to capture (seconds from the start).
func _build_plan() -> void:
	var c_fh := Vector3(0.75, 0.95, -0.45)
	var c_bh := Vector3(-0.7, 0.95, -0.4)
	match stroke:
		"fh", "bh", "bh1", "sl":
			var side := 1 if stroke == "fh" else -1
			ath.one_handed_backhand = stroke == "bh1"
			var style := Athlete.Style.SLICE if stroke == "sl" else Athlete.Style.TOPSPIN
			var c := c_fh if side > 0 else c_bh
			if stroke == "sl":
				c.y = 0.8
			plan.append([_at(0.05), func() -> void: ath.prepare(side, style)])
			plan.append([_at(0.6), func() -> void: ath.swing(side, 0.3, ath.to_global(c), style)])
			_ball_path(ath.to_global(c), 0.9, Vector3(0.0, 1.0, 18.0), Vector3(-1.5 * side, 3.0, -25.0))
			# ready, unit turn, takeback, drop, forward swing, contact, follow, finish
			# ready, unit turn, takeback, drop, forward swing, contact, extension, wrap, finish
			shots = [0.02, 0.3, 0.6, 0.78, 0.86, 0.9, 0.94, 0.98, 1.03, 1.1, 1.2, 1.32]
		"serve":
			plan.append([_at(0.02), func() -> void: ath.serve_ready()])
			plan.append([_at(0.8), func() -> void: ath.prepare_serve()])
			var c := Vector3(0.1, 2.85, -0.4)
			plan.append([_at(1.55), func() -> void: ath.swing(1, 0.18, ath.to_global(c), Athlete.Style.SERVE)])
			_ball_path(ath.to_global(c), 1.73, Vector3(0.0, -2.0, 0.0), Vector3(-2.0, -4.0, -45.0))
			shots = [0.3, 0.7, 0.95, 1.2, 1.45, 1.6, 1.68, 1.73, 1.85, 2.1]
		"dive":
			# A ball 2 m to the right: the player dives, hits it, lands and gets up.
			var cd := Vector3(2.2, 0.6, -0.4)
			plan.append([_at(0.05), func() -> void: ath.prepare(1)])
			plan.append([_at(0.5), func() -> void: ath.swing(1, 0.3, ath.to_global(cd), Athlete.Style.TOPSPIN)])
			plan.append([_at(0.56), func() -> void: ath.dive(ath.to_global(cd))])
			_ball_path(ath.to_global(cd), 0.8, Vector3(0.0, 1.0, 18.0), Vector3(-1.0, 3.0, -22.0))
			shots = [0.3, 0.6, 0.7, 0.8, 0.9, 1.1, 1.4, 1.6, 1.8, 2.0, 2.3]
		"walk":
			# Serve stance, then walking left (backwards for a right-hander) and right.
			plan.append([_at(0.02), func() -> void: ath.serve_ready()])
			plan.append([_at(0.4), func() -> void: ath.move_input = Vector2(-1, 0)])
			plan.append([_at(1.2), func() -> void: ath.move_input = Vector2(1, 0)])
			plan.append([_at(2.0), func() -> void: ath.move_input = Vector2.ZERO])
			shots = [0.3, 0.55, 0.7, 0.85, 1.0, 1.35, 1.5, 1.65, 1.8, 2.3]
	done_frame = _at(shots.back()) + 2


## The ball meets the racket at `contact` at time `t`, flying in and out at these velocities.
func _ball_path(contact: Vector3, t: float, v_in: Vector3, v_out: Vector3) -> void:
	ball_contact = contact
	ball_frame = _at(t)
	ball_in = v_in
	ball_out = v_out


func _process(_delta: float) -> bool:
	frame += 1
	if ball_frame > 0:
		var dt := float(frame - ball_frame) / 60.0
		ball.visible = dt > -0.45 and dt < 0.5
		ball.position = ball_contact + (ball_in if dt < 0.0 else ball_out) * dt
	while not plan.is_empty() and plan[0][0] <= frame:
		(plan.pop_front()[1] as Callable).call()
	if stroke == "walk":
		ath.serve_ready()  # keep the serve stance while walking, like Main does
	# Cameras follow the player sideways (walking would leave the frame).
	for i in views.size():
		var p := Vector3(ath.position.x, 0, 0)
		views[i].get_camera_3d().look_at_from_position(cam_offsets[i][0] + p, cam_offsets[i][1] + p, Vector3.UP)
	for t in shots:
		if _at(t) == frame:
			_capture.call_deferred()
	if frame > done_frame:
		_save_sheet()
		return true
	return false


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var row: Array = []
	for v in views:
		row.append(v.get_texture().get_image())
	images.append(row)
	print_verbose("shot ", frame, " mode ", ath._mode, " twist ", ath._twist)


func _save_sheet() -> void:
	var n := images.size()
	if n == 0:
		push_error("no frames captured")
		return
	var rows := views.size()
	var sheet := Image.create(CELL.x * n, CELL.y * rows, false, images[0][0].get_format())
	for i in n:
		for row in rows:
			var img: Image = images[i][row]
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, CELL.y * row))
	var path := "%s/poses_%s.png" % [out_dir, stroke]
	sheet.save_png(path)
	print("saved ", path, " (", n, " frames)")
