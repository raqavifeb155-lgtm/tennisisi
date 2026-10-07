extends SceneTree
## Compares the body styles (Athlete.Body): the same players drawn in each style, full
## length from the front-side, in poses from a rally (ready, forehand contact, two-hander
## finish, serve trophy, slide).
##
##   godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/body_shot.gd -- --out=/tmp/shots
## Writes body_styles.png: one row per style, one column per player / pose.

const CELL := Vector2i(300, 440)

## Rally poses: [name, what to call on the athlete, seconds to let it play]
const POSES := ["ready", "forehand", "backhand", "trophy", "slide"]

var out_dir := "/tmp/shots"
var rows: Array = []      # per style: Array of [SubViewport, Athlete, pose]
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	# A spread of looks: skin tones, hair, beards, headwear, kit colours.
	var looks := [
		{"skin": 2, "hair": Looks.Hair.SHORT, "hair_color": 1, "beard": 0, "head": Looks.Head.CAP, "shirt": 12, "shorts": 3, "accent": 12},
		{"skin": 7, "hair": Looks.Hair.AFRO, "hair_color": 0, "beard": Looks.Beard.SHORT, "head": Looks.Head.HEADBAND, "shirt": 5, "shorts": 0, "accent": 10},
		{"skin": 1, "hair": Looks.Hair.PONYTAIL, "hair_color": 6, "beard": 0, "head": Looks.Head.VISOR, "shirt": 14, "shorts": 0, "accent": 15},
		{"skin": 4, "hair": Looks.Hair.CURLY, "hair_color": 2, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.NONE, "shirt": 8, "shorts": 3, "accent": 0},
	]
	for style in [Athlete.Body.CLASSIC, Athlete.Body.ATHLETE, Athlete.Body.TOON]:
		var row: Array = []
		for i in looks.size():
			row.append(_cell(style, looks[i], "ready"))
		for pose in ["forehand", "backhand", "trophy", "slide"]:
			row.append(_cell(style, looks[0], pose))
		rows.append(row)


func _cell(style: int, look: Dictionary, pose: String) -> Array:
	Athlete.body_style = style
	Athlete.surface = "clay" if pose == "slide" else "hard"
	var vp := SubViewport.new()
	vp.size = CELL
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.8, 0.85)
	e.ambient_light_energy = 0.55
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.72, 0.38, 0.24) if pose == "slide" else Color(0.2, 0.38, 0.66)
	ground.material_override = gm
	vp.add_child(ground)
	var a := Athlete.new()
	vp.add_child(a)
	a.setup(-1.0, Looks.sanitize(look), Rect2(-50, -50, 100, 100))
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(1.8, 1.45, -3.3), Vector3(0.1, 0.95, 0), Vector3.UP)
	return [vp, a, pose, cam]


func _process(_delta: float) -> bool:
	frame += 1
	for row in rows:
		for c in row:
			_drive(c[1], c[2], frame)
			var cam: Camera3D = c[3]
			var p: Vector3 = (c[1] as Athlete).position
			cam.look_at_from_position(Vector3(1.8 + p.x, 1.45, -3.3 + p.z), Vector3(0.1 + p.x, 0.95, p.z), Vector3.UP)
	if frame == 75:
		_save.call_deferred()
	return frame > 82


## Plays each pose so that it is at its key moment on frame 75.
func _drive(a: Athlete, pose: String, f: int) -> void:
	match pose:
		"forehand":
			if f == 5:
				a.prepare(1)
			if f == 40:
				a.swing(1, 0.5, a.to_global(Vector3(0.75, 0.95, -0.45)), Athlete.Style.TOPSPIN)
		"backhand":
			if f == 5:
				a.prepare(-1)
			if f == 30:
				a.swing(-1, 0.3, a.to_global(Vector3(-0.7, 0.95, -0.4)), Athlete.Style.TOPSPIN)
		"trophy":
			if f == 5:
				a.serve_ready()
			if f == 25:
				a.prepare_serve()
		"slide":
			if f == 5:
				a.move_input = Vector2(1, 0)
			if f == 62:
				a.move_input = Vector2.ZERO


func _save() -> void:
	await RenderingServer.frame_post_draw
	var cols: int = rows[0].size()
	var first: Image = (rows[0][0][0] as SubViewport).get_texture().get_image()
	var sheet := Image.create(CELL.x * cols, CELL.y * rows.size(), false, first.get_format())
	for r in rows.size():
		for i in cols:
			var img: Image = (rows[r][i][0] as SubViewport).get_texture().get_image()
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(i * CELL.x, r * CELL.y))
	var path := "%s/body_styles.png" % out_dir
	sheet.save_png(path)
	print("saved ", path)
