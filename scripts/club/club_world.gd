class_name ClubWorld
extends Scenery
## The player's club, level 0 (docs/club/CLUB_BRIEF.md, H1_SPEC.md): the riverside park
## of Scenery - sky, river, bridge, city - turned into a place to walk around. The
## public court is worn (cracks, faded lines), the places of the club stand around it:
## open pavilions for the locker room and the coach, signs where things will be built.
##
## Everything is procedural and cheap: one material per kind of thing, static boxes
## folded by MeshMerge (Main._trim_shadows), repeated things in MultiMesh. On the lower
## presets the sun casts no shadow here; the people stand on their round shadows.

const PAVILION := Vector2(6.0, 5.0)    # x, z
const WALL_H := 3.0
const RESERVED := [                      # no trees here: places, the arena site, the gate
	Rect2(-53, -21, 31, 42),              # arena site
	Rect2(-20, 20, 12, 12), Rect2(10, 20, 12, 12),   # pavilions
	Rect2(-9, 29, 18, 16),                # gate and the way in
	Rect2(-24, -32, 12, 12), Rect2(14, -36, 12, 12), Rect2(18, -18, 8, 8),
	Rect2(-2, 17, 4, 14),                 # the path from the gate to the court
	Rect2(-17, -32, 8, 52), Rect2(9, -36, 7, 56),     # the paths west and east of the court
	Rect2(-20, 28, 40, 6),                # past the pavilion doors
	Rect2(16, -4, 14, 14), Rect2(12, 4, 12, 4),        # the shop and the way to it
	Rect2(14, -38, 13, 14),               # the bar's terrace
]

var walk := ClubWalk.new()
var _shadows_on := true
var _rings: MultiMeshInstance3D
var _ring_ids: Array = []              # place id per ring instance
var _highlight := ""
var _pavilions := {}                   # place id -> {"root", "fade", "inside"}
var _place_nodes := {}                 # place id -> Node3D at the place
var _ball_machine: Marker3D
var _paving: StandardMaterial3D
var _keep: Array = []                  # nodes shown and hidden later: MeshMerge leaves them be
var _level_roots := {}                 # place id -> Node3D holding what its level shows
var _levels := {}                      # place id -> the level built
var _roulette: ClubRoulette
var _umbrella: Node3D


func _ready() -> void:
	super._ready()
	# Low-poly crowns, bushes and flowers (the club's budget: <= 25k triangles on Low,
	# docs/PERFORMANCE.md 3): a faceted sphere is the cartoon look anyway.
	_sphere.radial_segments = 6
	_sphere.rings = 4
	_paving = _noise_mat(Color(0.74, 0.7, 0.64), 0.05, 20.0)
	walk.bounds = Rect2(-55, SHORE_Z + 1.5, 110, 46.0 - SHORE_Z - 1.5)
	_clear_reserved()
	_build_worn_court()
	_build_south_fence()
	_build_paths()
	_build_places()
	_build_obstacles()
	_build_waypoints()
	_build_rings()
	_ball_machine = Marker3D.new()
	_ball_machine.name = "ball_machine"
	_ball_machine.position = Vector3(2.5, 0.0, -10.5)
	_ball_machine.rotation.y = PI  # -basis.z (where it shoots) points at the near baseline
	add_child(_ball_machine)
	_build_machine_model()


func _process(delta: float) -> void:
	super._process(delta)
	if _rings and _rings.visible:
		_update_rings()


## Where the ball machine stands on the main court and where it shoots (-basis.z), for
## the tutorial with the machine (built by the integrator, H1_SPEC 4).
func ball_machine() -> Transform3D:
	return _ball_machine.global_transform if _ball_machine.is_inside_tree() else _ball_machine.transform


func place_node(id: String) -> Node3D:
	return _place_nodes.get(id)


## The camera framing of a pavilion the hero stands in (its front wall and roof fade).
func set_inside(id: String) -> void:
	for pid in _pavilions:
		var p: Dictionary = _pavilions[pid]
		(p["fade"] as Node3D).visible = pid != id


## Pavilions' contents are not drawn while the hero is far from them.
func show_interiors_near(pos: Vector3) -> void:
	for pid in _pavilions:
		var p: Dictionary = _pavilions[pid]
		var root := p["root"] as Node3D
		(p["inside"] as Node3D).visible = Vector2(pos.x - root.position.x, pos.z - root.position.z).length() < 14.0


## The gold circle of the place the hero stands in glows brighter.
func highlight(id: String) -> void:
	_highlight = id


## Which places have their circle and button (`ids`); the others show their sign, with
## the text their level gives (ClubPlaces.state), if any.
func set_open(ids: Array) -> void:
	_ring_ids = []
	var xf: Array[Transform3D] = []
	for p in ClubPlaces.LIST:
		var open: bool = ids.has(p["id"])
		var sign := _place_nodes.get(p["id"] + "_sign") as Node3D
		if sign:
			var text: String = ClubPlaces.state(p["id"], int(_levels.get(p["id"], 0))).get("sign", "")
			if not ClubPlaces.is_open(p, SaveData.played, SaveData.titles):
				text = p["sign"]
			sign.visible = not open and text != ""
			(sign.get_meta("label") as Label3D).text = text
		if not open:
			continue
		var r := float(p["r"])
		_ring_ids.append(p["id"])
		xf.append(Transform3D(Basis.from_scale(Vector3(r, 1.0, r)), p["pos"] + Vector3(0, 0.05, 0)))
	var mm := _rings.multimesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	_update_rings()


## What a place shows at its level: pavilions refill their room, others rebuild their
## level node (a function _level_<id>(root, level) per place). Safe to call again.
func set_level(id: String, lv: int) -> void:
	_levels[id] = lv
	if _pavilions.has(id):
		var inside: Node3D = _pavilions[id]["inside"]
		for c in inside.get_children():
			inside.remove_child(c)
			c.queue_free()
		_fill_room(id, inside, lv)
	var fn := "_level_" + id
	if has_method(fn):
		var root: Node3D = _level_roots.get(id)
		if root == null:
			root = Node3D.new()
			root.name = "level_" + id
			(_place_nodes[id] as Node3D).add_child(root)
			_level_roots[id] = root
			_keep.append(root)
		for c in root.get_children():
			root.remove_child(c)
			c.queue_free()
		call(fn, root, lv)
		MeshMerge.merge_static(root)


func level_built(id: String) -> int:
	return int(_levels.get(id, 0))


## The Totalizator's wheel at the bar.
func roulette() -> ClubRoulette:
	return _roulette


## Looking down at the wheel: the umbrella's canopy steps out of the way.
func set_roulette_view(on: bool) -> void:
	_umbrella.visible = not on


func sun() -> DirectionalLight3D:
	return _sun if _shadows_on else null  # Graphics leaves a disabled sun alone


## Low and Medium: the sun casts no shadow in the club (its pass doubled the draw calls,
## docs/PERFORMANCE.md); the people get their round shadows instead.
func set_high_quality(on: bool) -> void:
	super.set_high_quality(on)
	ClubMaterial.set_outlines(on)  # outlines are a second pass per mesh: High and up only
	_shadows_on = on
	_sun.shadow_enabled = on
	Athlete.blob_shadows = not on


## The park's swaying crowns, plus: within a few metres of the camera they dissolve in a
## dither, so a tree between the camera and the hero never hides him.
func _swaying_leaves() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = o.x * 0.37 + o.z * 0.23;
	float s = sin(TIME * 0.9 + ph) * 0.07 + sin(TIME * 2.1 + ph * 2.0) * 0.025;
	float bend = VERTEX.y * 0.5 + 0.5;
	VERTEX.x += s * bend / length(MODEL_MATRIX[0].xyz);
	VERTEX.z += s * 0.4 * bend / length(MODEL_MATRIX[2].xyz);
}
void fragment() {
	float d = length(VERTEX);
	float keep = smoothstep(7.0, 11.0, d);
	vec2 c = floor(FRAGCOORD.xy * 0.5);
	float dither = fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
	if (keep < 0.999 && dither > keep) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _exit_tree() -> void:
	Athlete.blob_shadows = false


# --- Building -----------------------------------------------------------------------

## The park's trees, bushes and lamps keep out of the club's places and paths.
func _clear_reserved() -> void:
	for c in get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null:
			continue
		var mm := mmi.multimesh
		var keep_xf: Array[Transform3D] = []
		var keep_col: Array[Color] = []
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			if _reserved(Vector2(t.origin.x, t.origin.z)):
				continue
			keep_xf.append(t)
			if mm.use_colors:
				keep_col.append(mm.get_instance_color(i))
		if keep_xf.size() == mm.instance_count:
			continue
		mm.instance_count = keep_xf.size()
		for i in keep_xf.size():
			mm.set_instance_transform(i, keep_xf[i])
			if mm.use_colors:
				mm.set_instance_color(i, keep_col[i])
		# Tree trunks are what the hero would bump into.
		if mm.mesh is CylinderMesh and absf((mm.mesh as CylinderMesh).height - 3.2) < 0.01:
			(mm.mesh as CylinderMesh).rings = 0  # a plain six-sided post, no bands
			(mm.mesh as CylinderMesh).cap_bottom = false
			for t in keep_xf:
				walk.add_circle(Vector2(t.origin.x, t.origin.z), 0.35)


func _reserved(p: Vector2) -> bool:
	for r in RESERVED:
		if (r as Rect2).has_point(p):
			return true
	return false


## A public court that has seen better days: cracks, worn patches, faded lines. A layer
## of its own over the Court (matches elsewhere keep the clean one).
static var _worn_tex: ImageTexture


func _build_worn_court() -> void:
	if _worn_tex == null:
		_worn_tex = _make_worn_texture()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _worn_tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Court.DOUBLES_HALF_WIDTH * 2.0 + 2.0, Court.HALF_LENGTH * 2.0 + 3.0)
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(0, 0.035, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Sun-bleached patches (the blue gone grey) and thin cracks, ~5 cm a pixel.
func _make_worn_texture() -> ImageTexture:
	var w := 256
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.035
	for y in h:
		for x in w:
			var n := noise.get_noise_2d(x, y)
			if n > 0.12:
				img.set_pixel(x, y, Color(0.55, 0.6, 0.66, clampf((n - 0.12) * 0.9, 0.0, 0.16)))
	var crack := Color(0.12, 0.13, 0.15, 0.55)
	var crng := RandomNumberGenerator.new()
	crng.seed = 77
	for k in 16:
		var p := Vector2(crng.randf_range(0, w), crng.randf_range(0, h))
		var a := crng.randf_range(0.0, TAU)
		for s in crng.randi_range(40, 140):
			a += crng.randf_range(-0.45, 0.45)
			p += Vector2.from_angle(a)
			if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
				img.set_pixel(int(p.x), int(p.y), crack)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The near end of the fence, with the gate the hero walks through (the match view
## leaves it out: there it would stand between the camera and the player).
func _build_south_fence() -> void:
	var height := 1.1
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_texture = _fence_tex
	mesh_mat.albedo_color = Color(0.3, 0.27, 0.22)  # a little rust on the old fence
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh_mat.alpha_scissor_threshold = 0.5
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_mat.uv1_triplanar = true
	mesh_mat.uv1_world_triplanar = true
	mesh_mat.uv1_scale = Vector3(1.6, 1.6, 1.6)
	var gate := 1.3
	for s in [-1.0, 1.0]:
		var len := HX - gate
		_box(Vector3(len, height, 0.02), Vector3(s * (gate + len * 0.5), height * 0.5, HZ), mesh_mat, false)
	var post := ClubMaterial.pal(ClubMaterial.METAL_DARK, false)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.12, height + 0.3, 0.12), Vector3(s * gate, (height + 0.3) * 0.5, HZ), post)
		_box(Vector3(HX - gate, 0.06, 0.06), Vector3(s * (gate + (HX - gate) * 0.5), height, HZ), post)


func _build_paths() -> void:
	var y := 0.02
	_box(Vector3(2.4, 0.06, 22.0), Vector3(0, y, HZ + 11.0), _paving, false)       # gate -> court
	_box(Vector3(34.0, 0.06, 2.4), Vector3(1.0, y, 31.0), _paving, false)         # past the pavilion doors
	_box(Vector3(2.4, 0.06, 40.0), Vector3(HX + 3.0, y, -8.0), _paving, false)    # east: to the bar
	_box(Vector3(10.0, 0.06, 2.4), Vector3(HX + 7.0, y, -30.0), _paving, false)
	_box(Vector3(13.0, 0.06, 2.4), Vector3(-HX - 6.0, y, 0.0), _paving, false)    # west: to the arena
	_box(Vector3(2.4, 0.06, 26.0), Vector3(-HX - 4.0, y, -13.0), _paving, false)  # to the trophy room
	_box(Vector3(9.0, 0.06, 2.4), Vector3(-HX - 8.0, y, -26.0), _paving, false)
	_box(Vector3(11.0, 0.06, 2.4), Vector3(HX + 8.5, y, 6.2), _paving, false)    # east: to the shop


func _build_places() -> void:
	for p in ClubPlaces.LIST:
		var n := Node3D.new()
		n.name = "place_" + p["id"]
		n.position = p["pos"]
		add_child(n)
		_place_nodes[p["id"]] = n
		if p["sign"] != "":
			var s := _sign(p["pos"] + Vector3(1.6, 0, -1.2), p["sign"])
			_place_nodes[p["id"] + "_sign"] = s
			_keep.append(s)
	_pavilion("locker", ClubPlaces.find("locker")["pos"])
	_pavilion("coach", ClubPlaces.find("coach")["pos"])
	_pavilion("shop", ClubPlaces.find("shop")["pos"])
	_build_bar_table()
	for p in ClubPlaces.LIST:
		set_level(p["id"], ClubPlaces.level(p["id"]))
	_build_stakes()
	_build_gate()
	_build_arena_site()


## A board on a post with a line of text: what will stand here and when.
func _sign(pos: Vector3, text: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var wood := ClubMaterial.pal(ClubMaterial.WOOD, false)
	root.add_child(_mesh_box(Vector3(0.1, 1.3, 0.1), Vector3(0, 0.65, 0), wood))
	var board := _mesh_box(Vector3(3.0, 1.15, 0.06), Vector3(0, 1.75, 0), ClubMaterial.pal(ClubMaterial.BOARD))
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board)
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.text_bold()
	l.font_size = 64
	l.pixel_size = 0.0055
	l.width = 500
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(0.16, 0.13, 0.1)
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.position = Vector3(0, 1.75, 0.04)
	root.add_child(l)
	root.set_meta("label", l)
	walk.add_circle(Vector2(pos.x, pos.z), 0.25)
	return root


## An open pavilion: floor, back and side walls; the front wall (with the door) and the
## roof fade when the hero is inside, like a doll's house. Contents per room.
func _pavilion(id: String, c: Vector3) -> void:
	var root := Node3D.new()
	root.position = Vector3(c.x, 0, c.z)
	add_child(root)
	var fade := Node3D.new()
	root.add_child(fade)
	var inside := Node3D.new()
	root.add_child(inside)
	var wall := ClubMaterial.pal(ClubMaterial.PLASTER)
	var trim := ClubMaterial.pal(ClubMaterial.WOOD_DARK)
	var hx := PAVILION.x * 0.5
	var hz := PAVILION.y * 0.5
	_box(Vector3(PAVILION.x + 0.4, 0.15, PAVILION.y + 0.4), Vector3(0, 0.075, 0), ClubMaterial.pal(ClubMaterial.WOOD, false), false, root)
	_box(Vector3(PAVILION.x, WALL_H, 0.2), Vector3(0, WALL_H * 0.5, -hz), wall, true, root)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.2, WALL_H, PAVILION.y), Vector3(s * hx, WALL_H * 0.5, 0), wall, true, root)
	var door := 1.8
	var side := (PAVILION.x - door) * 0.5
	for s in [-1.0, 1.0]:
		var front := _mesh_box(Vector3(side, WALL_H, 0.2), Vector3(s * (door * 0.5 + side * 0.5), WALL_H * 0.5, hz), wall)
		fade.add_child(front)
	fade.add_child(_mesh_box(Vector3(door, 0.6, 0.2), Vector3(0, WALL_H - 0.3, hz), wall))
	fade.add_child(_mesh_box(Vector3(PAVILION.x + 0.8, 0.25, PAVILION.y + 0.8), Vector3(0, WALL_H + 0.12, 0), trim))
	_pavilions[id] = {"root": root, "fade": fade, "inside": inside}
	_keep.append_array([fade, inside])
	# Walls the hero can't walk through (the door stays open).
	walk.add_wall(Vector2(c.x - hx, c.z - hz), Vector2(c.x + hx, c.z - hz))
	walk.add_wall(Vector2(c.x - hx, c.z - hz), Vector2(c.x - hx, c.z + hz))
	walk.add_wall(Vector2(c.x + hx, c.z - hz), Vector2(c.x + hx, c.z + hz))
	walk.add_wall(Vector2(c.x - hx, c.z + hz), Vector2(c.x - door * 0.5, c.z + hz))
	walk.add_wall(Vector2(c.x + door * 0.5, c.z + hz), Vector2(c.x + hx, c.z + hz))


## A room's things at a level (docs/club/CLUB_BRIEF.md 3: what each level shows). The
## pavilion is 6 x 5 m, open toward the camera (+z); the back wall at z = -2.5.
func _fill_room(id: String, inside: Node3D, lv: int) -> void:
	var hz := PAVILION.y * 0.5
	var trim := ClubMaterial.pal(ClubMaterial.WOOD_DARK)
	match id:
		"locker":
			var metal := ClubMaterial.pal(ClubMaterial.STEEL)
			var lockers := clampi(1 + lv * 2, 1, 6)
			for i in lockers:
				inside.add_child(_mesh_box(Vector3(0.6, 2.0, 0.55), Vector3(-2.4 + i * 0.65, 1.0, -hz + 0.4), metal))
			inside.add_child(_mesh_box(Vector3(2.2, 0.08, 0.5), Vector3(0.9, 0.45, 0.2), ClubMaterial.pal(ClubMaterial.WOOD, false)))
			for lx in [0.0, 1.8]:
				inside.add_child(_mesh_box(Vector3(0.08, 0.45, 0.45), Vector3(lx, 0.22, 0.2), trim))
			if lv >= 1:  # a mirror
				inside.add_child(_mesh_box(Vector3(0.06, 1.6, 1.0), Vector3(2.85, 1.3, -0.6), ClubMaterial.pal(ClubMaterial.GLASS)))
		"coach":
			inside.add_child(_mesh_box(Vector3(2.4, 1.3, 0.06), Vector3(0.6, 1.7, -hz + 0.14), ClubMaterial.pal(ClubMaterial.CHALKBOARD)))
			var chalk := Label3D.new()
			chalk.text = "ФОР · БЭК · ПОД\nСЕТ · НОГИ"
			chalk.font = UiTheme.text_bold()
			chalk.font_size = 48
			chalk.pixel_size = 0.005
			chalk.modulate = Color(0.92, 0.92, 0.88, 0.85)
			chalk.outline_size = 0
			chalk.shaded = false
			chalk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chalk.position = Vector3(0.6, 1.7, -hz + 0.18)
			inside.add_child(chalk)
			var chair := Node3D.new()
			chair.position = Vector3(-1.4, 0.15, -0.6)
			inside.add_child(chair)
			var seat := ClubMaterial.pal(ClubMaterial.METAL_DARK, false)
			chair.add_child(_mesh_box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.45, 0), seat))
			chair.add_child(_mesh_box(Vector3(0.5, 0.5, 0.05), Vector3(0, 0.72, -0.23), seat))
			chair.add_child(_mesh_box(Vector3(0.44, 0.45, 0.44), Vector3(0, 0.22, 0), seat))
			if lv >= 1:  # dumbbells and a mat
				inside.add_child(_mesh_box(Vector3(1.8, 0.03, 0.9), Vector3(1.4, 0.17, 0.6), ClubMaterial.pal(ClubMaterial.TEAL, false)))
		"shop":
			# A counter with a till, a rack of rackets, a glass case of things.
			inside.add_child(_mesh_box(Vector3(2.6, 1.0, 0.7), Vector3(-0.8, 0.5, -0.2), ClubMaterial.pal(ClubMaterial.WOOD)))
			inside.add_child(_mesh_box(Vector3(2.7, 0.06, 0.8), Vector3(-0.8, 1.03, -0.2), trim))
			inside.add_child(_mesh_box(Vector3(0.4, 0.3, 0.3), Vector3(-1.6, 1.21, -0.25), ClubMaterial.pal(ClubMaterial.METAL_DARK, false)))
			inside.add_child(_mesh_box(Vector3(2.2, 1.6, 0.12), Vector3(0.9, 1.4, -hz + 0.2), ClubMaterial.pal(ClubMaterial.WOOD_DARK)))
			var frames := [Color("d9473b"), Color("2a54a3"), Color("f2f0ea"), Color("ffd642")]
			var rackets := 3 + mini(lv, 3)
			for i in rackets:
				var rk := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.13
				tm.outer_radius = 0.16
				tm.rings = 10
				tm.ring_segments = 4
				rk.mesh = tm
				rk.material_override = ClubMaterial.get_mat(frames[i % frames.size()], false)
				rk.rotation.x = PI * 0.5
				rk.scale = Vector3(0.8, 1.0, 1.0)
				rk.position = Vector3(0.1 + i * 0.32 * (3.0 / rackets), 1.65, -hz + 0.3)
				inside.add_child(rk)
				inside.add_child(_mesh_box(Vector3(0.03, 0.32, 0.03), Vector3(rk.position.x, 1.32, -hz + 0.3), ClubMaterial.pal(ClubMaterial.BLACK, false)))
			if lv >= 1:  # a glass case with a lit shelf
				inside.add_child(_mesh_box(Vector3(1.2, 0.9, 0.6), Vector3(2.1, 0.45, 0.6), ClubMaterial.pal(ClubMaterial.GLASS)))
				inside.add_child(_mesh_box(Vector3(1.1, 0.04, 0.5), Vector3(2.1, 0.92, 0.6), ClubMaterial.glow(UiTheme.GOLD, 1.0)))
			var sign := Label3D.new()
			sign.text = "МАГАЗИН"
			sign.font = UiTheme.display()
			sign.font_size = 72
			sign.pixel_size = 0.006
			sign.modulate = UiTheme.GOLD
			sign.outline_size = 10
			sign.outline_modulate = Color(0.1, 0.08, 0.06)
			sign.shaded = false
			sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sign.position = Vector3(0, 2.6, -hz + 0.12)
			inside.add_child(sign)


## The bar's table with the roulette under an umbrella (the Totalizator, HANDOFF 9.1).
## The bar itself grows by levels (H2, _level_bar).
func _build_bar_table() -> void:
	var c: Vector3 = ClubPlaces.find("bar")["pos"]
	var at := Vector3(c.x, 0.0, c.z - 3.2)
	var root := Node3D.new()
	root.name = "bar_table"
	root.position = at
	add_child(root)
	_keep.append(root)
	var top := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.3
	cyl.bottom_radius = 1.3
	cyl.height = 0.1
	cyl.radial_segments = 24
	cyl.rings = 0
	top.mesh = cyl
	top.material_override = ClubMaterial.pal(ClubMaterial.WOOD_DARK)
	top.position = Vector3(0, 0.8, 0)
	root.add_child(top)
	var leg := MeshInstance3D.new()
	var lc := CylinderMesh.new()
	lc.top_radius = 0.35
	lc.bottom_radius = 0.55
	lc.height = 0.78
	lc.radial_segments = 12
	lc.rings = 0
	leg.mesh = lc
	leg.material_override = ClubMaterial.pal(ClubMaterial.WOOD_DARK)
	leg.position = Vector3(0, 0.39, 0)
	root.add_child(leg)
	# The umbrella over it, on its pole beside the table.
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.04
	pc.bottom_radius = 0.05
	pc.height = 2.7
	pc.radial_segments = 6
	pc.rings = 0
	pole.mesh = pc
	pole.material_override = ClubMaterial.pal(ClubMaterial.METAL, false)
	pole.position = Vector3(1.55, 1.35, -0.3)
	root.add_child(pole)
	var canopy := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 1.9
	cm.height = 0.55
	cm.radial_segments = 8
	cm.rings = 0
	cm.cap_bottom = false
	canopy.mesh = cm
	canopy.material_override = ClubMaterial.pal(ClubMaterial.RED)
	canopy.position = Vector3(1.55, 2.85, -0.3)
	root.add_child(canopy)
	_umbrella = canopy
	# A wooden deck under the table, and a little counter behind it.
	var deck := _mesh_box(Vector3(6.0, 0.12, 5.0), Vector3(0, 0.06, -0.4), ClubMaterial.pal(ClubMaterial.WOOD, false))
	root.add_child(deck)
	root.add_child(_mesh_box(Vector3(2.2, 1.05, 0.6), Vector3(-1.9, 0.6, -2.3), ClubMaterial.pal(ClubMaterial.WOOD_DARK)))
	root.add_child(_mesh_box(Vector3(2.3, 0.06, 0.7), Vector3(-1.9, 1.15, -2.3), ClubMaterial.pal(ClubMaterial.TEAL, false)))
	walk.add_box(Rect2(at.x - 3.0, at.z - 2.65, 2.3, 0.7))
	_roulette = ClubRoulette.new()
	_roulette.name = "roulette"
	_roulette.position = Vector3(0, 0.95, 0)
	root.add_child(_roulette)
	walk.add_circle(Vector2(at.x, at.z), 1.45)


## Where the stands will go: stakes and red-and-white tape (the bleachers come in H2).
func _build_bleachers() -> void:
	pass


func _build_stakes() -> void:
	var x0 := HX + 1.6
	var x1 := HX + 4.6
	var corners := [Vector3(x0, 0, -14.0), Vector3(x1, 0, -14.0), Vector3(x1, 0, -4.0), Vector3(x0, 0, -4.0)]
	var wood := ClubMaterial.pal(ClubMaterial.WOOD, false)
	for c in corners:
		_box(Vector3(0.08, 0.9, 0.08), (c as Vector3) + Vector3(0, 0.45, 0), wood)
	var tape: Array[Transform3D] = []
	var tape_colors: Array[Color] = []
	for i in 4:
		var a: Vector3 = corners[i] + Vector3(0, 0.8, 0)
		var b: Vector3 = corners[(i + 1) % 4] + Vector3(0, 0.8, 0)
		var n := int(a.distance_to(b) / 0.5)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			tape.append(_segment(p - (b - a).normalized() * 0.25, p + (b - a).normalized() * 0.25, 0.05))
			tape_colors.append(Color(0.9, 0.2, 0.18) if k % 2 == 0 else Color(0.96, 0.96, 0.94))
	_mm(_unit_box, _tinted(), tape, tape_colors).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var s := _sign(Vector3((x0 + x1) * 0.5, 0, -2.6), "Здесь будут трибуны")
	s.rotation.y = 0.0
	walk.add_box(Rect2(x0, -14.0, x1 - x0, 10.0))


## The way in: an old gate in a low wall with a "Public Courts" plate.
func _build_gate() -> void:
	var z := 41.0
	var brick := ClubMaterial.pal(ClubMaterial.BRICK)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.6, 2.6, 0.6), Vector3(s * 1.8, 1.3, z), brick)
		_box(Vector3(12.0, 0.9, 0.35), Vector3(s * 8.1, 0.45, z), brick)
		walk.add_box(Rect2(s * 8.1 - 6.0, z - 0.3, 12.0, 0.6))
		walk.add_circle(Vector2(s * 1.8, z), 0.4)
	var plate := Label3D.new()
	plate.text = "PUBLIC COURTS"
	plate.font = UiTheme.display()
	plate.font_size = 64
	plate.pixel_size = 0.006
	plate.modulate = Color(0.95, 0.93, 0.86)
	plate.outline_size = 10
	plate.outline_modulate = Color(0.12, 0.2, 0.16)
	plate.shaded = false
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.position = Vector3(0, 2.25, z + 0.05)
	add_child(plate)


## Where the arena will rise: a builder's fence around a patch of gravel.
func _build_arena_site() -> void:
	var r := Rect2(-50, -16, 24, 32)
	_box(Vector3(r.size.x, 0.04, r.size.y), Vector3(r.get_center().x, 0.0, r.get_center().y), ClubMaterial.pal(ClubMaterial.GRAVEL, false), false)
	var boards := ClubMaterial.pal(ClubMaterial.BOARD)
	var h := 1.6
	_box(Vector3(r.size.x, h, 0.08), Vector3(r.get_center().x, h * 0.5, r.position.y), boards, false)
	_box(Vector3(r.size.x, h, 0.08), Vector3(r.get_center().x, h * 0.5, r.end.y), boards, false)
	_box(Vector3(0.08, h, r.size.y), Vector3(r.position.x, h * 0.5, r.get_center().y), boards, false)
	_box(Vector3(0.08, h, r.size.y), Vector3(r.end.x, h * 0.5, r.get_center().y), boards, false)
	walk.add_box(r.grow(0.1))


## The ball machine itself, standing on its marker: a box on little wheels with a hopper
## of balls on top and a short barrel toward the near baseline.
func _build_machine_model() -> void:
	var m := Node3D.new()
	m.name = "machine_model"
	m.transform = _ball_machine.transform
	add_child(m)
	var body := ClubMaterial.pal(ClubMaterial.METAL_DARK)
	m.add_child(_mesh_box(Vector3(0.6, 0.55, 0.75), Vector3(0, 0.45, 0), body))
	m.add_child(_mesh_box(Vector3(0.66, 0.08, 0.81), Vector3(0, 0.74, 0), ClubMaterial.pal(ClubMaterial.ORANGE, false)))
	var hopper := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.34
	cone.bottom_radius = 0.2
	cone.height = 0.35
	cone.radial_segments = 10
	cone.rings = 0
	hopper.mesh = cone
	hopper.material_override = ClubMaterial.pal(ClubMaterial.METAL)
	hopper.position = Vector3(0, 0.95, 0.05)
	m.add_child(hopper)
	var balls := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.3
	bm.height = 0.24
	bm.radial_segments = 10
	bm.rings = 3
	balls.mesh = bm
	balls.material_override = ClubMaterial.get_mat(Color(0.86, 0.95, 0.3), false)
	balls.position = Vector3(0, 1.1, 0.05)
	m.add_child(balls)
	var barrel := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.07
	tube.bottom_radius = 0.08
	tube.height = 0.4
	tube.radial_segments = 8
	tube.rings = 0
	barrel.mesh = tube
	barrel.material_override = body
	barrel.rotation.x = deg_to_rad(-75.0)
	barrel.position = Vector3(0, 0.62, -0.5)  # -z of the marker: toward the near baseline
	m.add_child(barrel)
	for x in [-0.25, 0.25]:
		for z in [-0.3, 0.3]:
			m.add_child(_mesh_box(Vector3(0.06, 0.16, 0.16), Vector3(x, 0.08, z), ClubMaterial.pal(ClubMaterial.BLACK, false)))
	var o := _ball_machine.position
	walk.add_circle(Vector2(o.x, o.z), 0.55)


func _build_obstacles() -> void:
	# The court's fence: sides and far end are solid, the near end has its gate.
	walk.add_wall(Vector2(-HX, -HZ), Vector2(HX, -HZ), 0.2)
	walk.add_wall(Vector2(-HX, -HZ), Vector2(-HX, HZ), 0.2)
	walk.add_wall(Vector2(HX, -HZ), Vector2(HX, HZ), 0.2)
	walk.add_wall(Vector2(-HX, HZ), Vector2(-1.3, HZ), 0.2)
	walk.add_wall(Vector2(1.3, HZ), Vector2(HX, HZ), 0.2)
	walk.add_wall(Vector2(-Court.NET_HALF_WIDTH - 0.1, 0.0), Vector2(Court.NET_HALF_WIDTH + 0.1, 0.0), 0.2)
	var ux := Court.NET_HALF_WIDTH + 1.35
	walk.add_box(Rect2(ux - 0.6, -0.6, 1.4, 1.2))                              # umpire's chair
	walk.add_box(Rect2(-(Court.NET_HALF_WIDTH + 1.3) - 1.0, -1.8, 1.4, 3.6))   # players' chairs
	walk.add_circle(Vector2(-(Court.DOUBLES_HALF_WIDTH + 1.4), Court.HALF_LENGTH + 1.2), 0.35)  # ball basket
	walk.add_circle(Vector2(-HX - 1.6, 5.0), 1.0)  # park bench by the fence


## Where a walk may turn: both sides of the court's gate, the pavilions' doors, the
## corners of the paths. ClubWalk.route links the ones that see each other.
func _build_waypoints() -> void:
	for p in [
		Vector2(0, 16.4), Vector2(0, 19.6),                      # the court's gate
		Vector2(-11.5, 19.6), Vector2(11.5, 19.6), Vector2(-11.5, -19.8), Vector2(11.5, -19.8),
		Vector2(0, 31), Vector2(0, 36),
		Vector2(-14, 31), Vector2(-14, 27.4), Vector2(16, 31), Vector2(16, 27.4),  # doors
		Vector2(12, -14), Vector2(12, -30), Vector2(-13, 0), Vector2(-13, -26),
		Vector2(12, 6.2), Vector2(22, 6.2), Vector2(22, 3.4),    # the shop's door
	]:
		walk.waypoints.append(p)


## The gold circles on the ground (one MultiMesh, per-instance colour for the pulse).
func _build_rings() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = ring
	_rings = MultiMeshInstance3D.new()
	_rings.multimesh = mm
	_rings.material_override = mat
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rings.scale = Vector3(1, 0.05, 1)
	add_child(_rings)
	set_open(["court"])


func _update_rings() -> void:
	var mm := _rings.multimesh
	var pulse := 0.5 + 0.5 * sin(_t * TAU / 1.5)
	for i in mini(mm.instance_count, _ring_ids.size()):
		var lit: bool = _ring_ids[i] == _highlight
		var a := lerpf(0.75, 1.0, pulse) if lit else lerpf(0.3, 0.5, pulse)
		mm.set_instance_color(i, Color(UiTheme.GOLD, a))
