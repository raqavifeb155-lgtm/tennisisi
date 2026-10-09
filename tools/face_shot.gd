extends SceneTree
## Close-ups of the SMOOTH body's faces (AthleteSkin): one row per look, one column per
## expression (calm, blink, effort at the stroke, joy, disappointment, a shout, eyes to
## the side, out of breath).
##
##   godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/face_shot.gd -- --out=/tmp/shots
## Writes faces.png.

const CELL := Vector2i(220, 260)
const EXPR := {
	"calm": {"blink": 0.0, "smile": 0.12, "mouth_open": 0.0, "brow": 0.0, "gaze": Vector2.ZERO},
	"blink": {"blink": 1.0, "smile": 0.12, "mouth_open": 0.0, "brow": 0.0, "gaze": Vector2.ZERO},
	"effort": {"blink": 0.3, "smile": -0.4, "mouth_open": 0.65, "brow": -0.9, "gaze": Vector2.ZERO},
	"joy": {"blink": 0.15, "smile": 1.0, "mouth_open": 0.45, "brow": 0.35, "gaze": Vector2.ZERO},
	"sad": {"blink": 0.35, "smile": -0.8, "mouth_open": 0.0, "brow": 0.9, "gaze": Vector2(0, -0.6)},
	"shout": {"blink": 0.2, "smile": 0.2, "mouth_open": 1.0, "brow": -1.0, "gaze": Vector2.ZERO},
	"look": {"blink": 0.0, "smile": 0.12, "mouth_open": 0.0, "brow": 0.0, "gaze": Vector2(0.9, 0.3)},
	"tired": {"blink": 0.25, "smile": -0.35, "mouth_open": 0.5, "brow": 0.65, "gaze": Vector2.ZERO},
}

var out_dir := "/tmp/shots"
var cells: Array = []    # [SubViewport, Athlete, expression]
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Athlete.body_style = Athlete.Body.SMOOTH
	var looks := [
		{"skin": 2, "hair": Looks.Hair.SHORT, "hair_color": 1, "beard": 0, "head": Looks.Head.CAP, "shirt": 12, "shorts": 3, "accent": 12},
		{"skin": 7, "hair": Looks.Hair.AFRO, "hair_color": 0, "beard": Looks.Beard.SHORT, "head": Looks.Head.HEADBAND, "shirt": 5, "shorts": 0, "accent": 10},
		{"skin": 1, "hair": Looks.Hair.PONYTAIL, "hair_color": 6, "beard": 0, "head": Looks.Head.VISOR, "shirt": 14, "shorts": 0, "accent": 15},
		{"skin": 4, "hair": Looks.Hair.CURLY, "hair_color": 2, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.NONE, "shirt": 8, "shorts": 3, "accent": 0},
		{"skin": 0, "hair": Looks.Hair.SIDE_PART, "hair_color": 8, "beard": 0, "head": Looks.Head.NONE, "shirt": 4, "shorts": 2, "accent": 11},
	]
	for look in looks:
		for e in EXPR:
			cells.append(_cell(look, e))


func _cell(look: Dictionary, expr: String) -> Array:
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
	var a := Athlete.new()
	vp.add_child(a)
	a.setup(-1.0, Looks.sanitize(look), Rect2(-50, -50, 100, 100))
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	return [vp, a, expr, cam]


func _process(_delta: float) -> bool:
	frame += 1
	for c in cells:
		var a: Athlete = c[1]
		if frame == 30:
			a.set_process(false)
			var ex: Dictionary = EXPR[c[2]]
			for k in ex:
				a._skin.material.set_shader_parameter(k, ex[k])
		var h: Vector3 = a._head.global_position
		(c[3] as Camera3D).look_at_from_position(h + Vector3(0.3, 0.04, -0.85), h + Vector3(0, -0.03, 0), Vector3.UP)
	if frame == 40:
		_save.call_deferred()
	return frame > 46


func _save() -> void:
	await RenderingServer.frame_post_draw
	var cols := EXPR.size()
	var rows := cells.size() / cols
	var first: Image = (cells[0][0] as SubViewport).get_texture().get_image()
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, first.get_format())
	for i in cells.size():
		var img: Image = (cells[i][0] as SubViewport).get_texture().get_image()
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	var path := "%s/faces.png" % out_dir
	sheet.save_png(path)
	print("saved ", path)
