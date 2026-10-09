extends SceneTree
## The club's light figures side by side: the old crowd meshes (ClubCrowd._body_mesh and
## _legs_mesh) on the left, ClubPeople's two kinds walking (several phases of the step)
## and standing on the right.
##
##   godot --path . --rendering-driver opengl3 -s tools/people_shot.gd -- --out=/tmp/shots
## Writes people.png.

var out_dir := "/tmp/shots"
var vp: SubViewport
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	vp = SubViewport.new()
	vp.size = Vector2i(1600, 700)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.76, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.82, 0.86)
	e.ambient_light_energy = 0.6
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.62, 0.35)
	ground.material_override = gm
	vp.add_child(ground)

	var shirts := [Color("d9473b"), Color("2a54a3"), Color("f2f0ea"), Color("3fb8af"), Color("ffd642"), Color("9a5cf0")]
	var skins := [Looks.SKIN[1], Looks.SKIN[7], Looks.SKIN[3], Looks.SKIN[9], Looks.SKIN[0], Looks.SKIN[5]]
	# Before: the old two-mesh figures.
	var body := _mm(ClubCrowd._body_mesh(), 3, ClubScenery.prop_material())
	var legs := _mm(ClubCrowd._legs_mesh(), 3, ClubScenery.prop_material())
	for i in 3:
		var xf := Transform3D(Basis(Vector3.UP, -0.5 + 0.5 * i), Vector3(6.2 - i * 1.0, 0, 0))
		body.multimesh.set_instance_transform(i, xf)
		legs.multimesh.set_instance_transform(i, xf)
		body.multimesh.set_instance_color(i, shirts[i])
		legs.multimesh.set_instance_color(i, Color.WHITE.lerp(skins[i], 0.35))
	# After: both kinds, walking at different phases, the last two standing.
	for k in 2:
		var mmi := ClubPeople.instance(k, 4)
		vp.add_child(mmi)
		for i in 4:
			var n := k * 4 + i
			var xf := Transform3D(Basis(Vector3.UP, -0.9 + 0.45 * i), Vector3(2.4 - n * 1.0, 0, 0))
			mmi.multimesh.set_instance_transform(i, xf)
			ClubPeople.paint(mmi.multimesh, i, shirts[n % shirts.size()], skins[n % skins.size()], [0.1, 0.8, 0.25, 0.0][i])
			ClubPeople.step(mmi.multimesh, i, [0.25 * TAU, 0.75 * TAU, 0.0, -1.0][i])
	var cam := Camera3D.new()
	cam.fov = 34.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(-0.6, 2.2, -8.5), Vector3(-0.6, 0.95, 0), Vector3.UP)


func _mm(mesh: Mesh, n: int, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	vp.add_child(mmi)
	return mmi


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 20:
		_save.call_deferred()
	return frame > 26


func _save() -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/people.png" % out_dir
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
