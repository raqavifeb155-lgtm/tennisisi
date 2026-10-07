extends SceneTree
## Renders the character options as contact sheets for reviewing them: every hair
## style, beards x headwear, skin tones and hair colours, close-up from the front.
##
##   godot --path . --rendering-driver opengl3 -s tools/look_shot.gd -- --out=/tmp/shots
## Writes looks_hair.png, looks_beard_head.png, looks_colors.png.

const CELL := Vector2i(160, 160)

var out_dir := "/tmp/shots"
var sheets: Array = []   # [name, viewport]
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var hair: Array = []
	for i in Looks.SIZES["hair"]:
		hair.append({"hair": i, "head": Looks.Head.NONE, "hair_color": 2})
	_sheet("looks_hair", hair, 5)
	var bh: Array = []
	for h in Looks.SIZES["head"]:
		for b in Looks.SIZES["beard"]:
			bh.append({"hair": Looks.Hair.SHORT if h != 0 else Looks.Hair.CURLY, "beard": b, "head": h, "hair_color": 1, "accent": 5})
	_sheet("looks_beard_head", bh, 6)
	var cols: Array = []
	for i in Looks.SIZES["skin"]:
		cols.append({"skin": i, "hair": Looks.Hair.AFRO if i > 6 else Looks.Hair.MESSY, "head": 0, "hair_color": i % 12, "shirt": i})
	for i in Looks.SIZES["hair_color"]:
		cols.append({"skin": 2, "hair": Looks.Hair.LONG, "head": Looks.Head.HEADBAND, "hair_color": i, "accent": 15 - i, "beard": i % 6})
	_sheet("looks_colors", cols, 11)


## One sheet: a row-major grid of head-and-shoulders portraits, each in its own small
## viewport (players always stand on the ground, so they cannot share one camera).
func _sheet(name: String, looks: Array, cols: int) -> void:
	var cells: Array = []
	for l in looks:
		var vp := SubViewport.new()
		vp.size = CELL
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		vp.own_world_3d = true
		root.add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.2, 0.24, 0.3)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.8, 0.82, 0.86)
		e.ambient_light_energy = 0.5
		env.environment = e
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 160, 0)
		vp.add_child(sun)
		var a := Athlete.new()
		vp.add_child(a)
		a.setup(-1.0, Looks.sanitize(l), Rect2(-50, -50, 100, 100))
		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		# From the front and a little to the side, so the hair's volume reads.
		cam.look_at_from_position(Vector3(-0.45, 1.85, -1.3), Vector3(0, 1.6, 0), Vector3.UP)
		cells.append(vp)
	sheets.append([name, cells, cols])


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 40:
		_save.call_deferred()
	return frame > 46


func _save() -> void:
	await RenderingServer.frame_post_draw
	for s in sheets:
		var cells: Array = s[1]
		var cols: int = s[2]
		var rows := ceili(float(cells.size()) / cols)
		var first: Image = (cells[0] as SubViewport).get_texture().get_image()
		var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, first.get_format())
		for i in cells.size():
			var img: Image = (cells[i] as SubViewport).get_texture().get_image()
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
		var path := "%s/%s.png" % [out_dir, s[0]]
		sheet.save_png(path)
		print("saved ", path)
