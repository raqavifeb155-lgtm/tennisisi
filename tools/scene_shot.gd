extends SceneTree
## Renders a location (scenery + court surface + two players) for reviewing it:
## the game camera (portrait phone), a wide view from behind, and a side view.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 60 \
##       -s tools/scene_shot.gd -- --scenery=clay --out=/tmp/shots
## --scenery=park (hard court, scripts/scenery.gd), clay (scripts/scenery_clay.gd),
## grass (scripts/scenery_grass.gd). --seconds=N lets animations run before the shot.

const PORTRAIT := Vector2i(405, 720)
const WIDE := Vector2i(720, 405)

var scenery_id := "park"
var out_dir := "/tmp/shots"
var seconds := 1.5
var views: Array[SubViewport] = []
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenery="):
			scenery_id = a.get_slice("=", 1)
		elif a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--seconds="):
			seconds = float(a.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out_dir)

	var path := "res://scripts/scenery.gd" if scenery_id == "park" else "res://scripts/scenery_%s.gd" % scenery_id
	var scenery: Node3D = (load(path) as GDScript).new()
	root.add_child(scenery)
	var court := Court.new()
	root.add_child(court)
	court.surface = {"park": "hard", "clay": "clay", "grass": "grass"}.get(scenery_id, "hard")
	for cfg in [[-1.0, Vector3(0.5, 0, 12.4), Color(0.92, 0.36, 0.26)], [1.0, Vector3(-0.8, 0, -12.2), Color(0.22, 0.28, 0.42)]]:
		var a := Athlete.new()
		root.add_child(a)
		a.setup(cfg[0], cfg[2], Rect2(-9, -18, 18, 36))
		a.position = cfg[1]
	# Game camera: like GameCamera behind the near player.
	_view(PORTRAIT, Vector3(0.35, 8.0, 18.6), Vector3(0.15, 0.0, 3.6), 52.0, true)
	_view(WIDE, Vector3(0.0, 14.0, 34.0), Vector3(0.0, 0.0, -10.0), 60.0, false)
	_view(WIDE, Vector3(10.5, 4.5, 7.0), Vector3(0.0, 1.0, -5.0), 70.0, false)
	# A few marks to see how clay keeps them (after the court is ready).
	await process_frame
	for i in 6:
		court.add_mark(Vector3(-2.0 + i * 0.7, 0, 9.0 - i * 1.3), Vector3(0.3, 0, -1), 0.09, 0.06)
	court.add_mark(Vector3(1.5, 0, 11.0), Vector3(1, 0, 0.2), 0.9, 0.12)



func _view(size: Vector2i, pos: Vector3, look: Vector3, fov: float, keep_width: bool) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 700.0
	cam.near = 0.5
	if keep_width:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
	vp.add_child(cam)
	cam.look_at_from_position(pos, look, Vector3.UP)
	views.append(vp)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == roundi(seconds * 60.0):
		_save.call_deferred()
	return frame > roundi(seconds * 60.0) + 5


func _save() -> void:
	await RenderingServer.frame_post_draw
	var imgs: Array[Image] = []
	for v in views:
		imgs.append(v.get_texture().get_image())
	var w := PORTRAIT.x + WIDE.x
	var sheet := Image.create(w, PORTRAIT.y, false, imgs[0].get_format())
	sheet.blit_rect(imgs[0], Rect2i(Vector2i.ZERO, PORTRAIT), Vector2i.ZERO)
	sheet.blit_rect(imgs[1], Rect2i(Vector2i.ZERO, WIDE), Vector2i(PORTRAIT.x, 0))
	sheet.blit_rect(imgs[2], Rect2i(Vector2i.ZERO, WIDE), Vector2i(PORTRAIT.x, WIDE.y))
	var path := "%s/scene_%s.png" % [out_dir, scenery_id]
	sheet.save_png(path)
	print("saved ", path)
