class_name ClubTerrain
extends Node3D
## The ground of the club (stream H): kerbs along every path, paving with slabs and
## joints instead of one flat colour, the pavement and the street behind the gate. All of
## it a couple of meshes of one material: the cost is draw calls in single digits.

const PAVE := Color("bdb3a3")
const KERB := Color("a8a398")
const ASPHALT := Color("3b3d42")
const LINE := Color("e6e2d6")

var _ground: MeshInstance3D     # kerbs, pavement, road; on High also every second lawn patch and the markings
var _low: ArrayMesh
var _high: ArrayMesh


func _ready() -> void:
	_slab_texture()
	var s := ClubShapes.new()
	_street(s)
	var hi := ClubShapes.new()
	_lawn_patches(s, hi)
	_markings(hi)
	_low = s.build()
	_high = ClubShapes.new().merge(s).merge(hi).build()   # High: one mesh with the extras, not two
	_build_paths()
	_ground = MeshInstance3D.new()
	_ground.name = "ground"
	_ground.mesh = _high
	_ground.material_override = ClubScenery.prop_material()
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)


func refresh(_level_of: Callable, high: bool) -> void:
	if _ground:
		_ground.mesh = _high if high else _low


## The club's paving gets its slabs: the world's flat paving colour is replaced by a
## texture of 1 m slabs with dark joints and a little moss, laid in world space.
func _slab_texture() -> void:
	var w: Variant = get_parent().world
	var mat: StandardMaterial3D = w.get("_paving")
	if mat == null:
		return
	var n := 128
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var slab := n / 4
	for sy in 4:
		for sx in 4:
			var base := Color(0.74, 0.70, 0.64).lerp(Color(0.62, 0.59, 0.55), rng.randf() * 0.55)
			base = base.lerp(Color(0.72, 0.74, 0.62), rng.randf() * 0.18)
			for y in slab:
				for x in slab:
					var c := base
					var edge := minf(minf(x, slab - 1 - x), minf(y, slab - 1 - y))
					if edge < 1:
						c = base.darkened(0.3).lerp(Color(0.4, 0.46, 0.3), 0.25)   # a joint, a little mossy
					elif edge < 2:
						c = base.darkened(0.07)
					elif rng.randf() < 0.05:
						c = base.darkened(0.06)
					img.set_pixel(sx * slab + x, sy * slab + y, c)
	# cracks: a few dark wandering lines across the slabs
	for k in 5:
		var q := Vector2(rng.randf_range(0, n), rng.randf_range(0, n))
		var a := rng.randf_range(0.0, TAU)
		for step in rng.randi_range(14, 40):
			a += rng.randf_range(-0.22, 0.22)
			q += Vector2.from_angle(a)
			var xi := posmod(int(q.x), n)
			var yi := posmod(int(q.y), n)
			img.set_pixel(xi, yi, img.get_pixel(xi, yi).darkened(0.32))
	img.generate_mipmaps()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(1.0 / 4.0, 1.0 / 4.0, 1.0 / 4.0)   # 4 slabs per texture, 1 m a slab
	mat.albedo_color = Color.WHITE


## Behind the gate: a pavement, the road with a kerb either side, the far pavement.
func _street(s: ClubShapes) -> void:
	var w := 220.0
	# near pavement (also where the gate opens): from the gate wall to the kerb
	s.box(Vector3(w, 0.3, 8.4), Vector3(0.0, -0.1, 45.8), PAVE)
	s.box(Vector3(w, 0.18, 0.2), Vector3(0.0, 0.0, 50.0), KERB)           # kerb
	s.box(Vector3(w, 0.1, 8.0), Vector3(0.0, -0.03, 54.2), ASPHALT)       # the road
	s.box(Vector3(w, 0.18, 0.2), Vector3(0.0, 0.0, 58.3), KERB)
	s.box(Vector3(w, 0.3, 8.0), Vector3(0.0, -0.1, 62.4), PAVE)           # far pavement under the shops


## Lane dashes and crossings (High only: a dash is a box).
func _markings(s: ClubShapes) -> void:
	var x := -100.0
	while x < 100.0:
		s.box(Vector3(2.4, 0.01, 0.16), Vector3(x, 0.03, 54.2), LINE)
		x += 6.0
	# patched and cracked asphalt: darker patches, thin cracks
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 9:
		s.flat(Vector2(rng.randf_range(0.8, 2.4), rng.randf_range(0.5, 1.0)), Vector3(rng.randf_range(-60.0, 60.0), 0.032 + k * 0.0003, 54.2 + rng.randf_range(-2.8, 2.8)), Color("2e3035"), 6, rng.randf_range(0, PI))
	for k in 16:
		var at := Vector3(rng.randf_range(-70.0, 70.0), 0.034, 54.2 + rng.randf_range(-3.4, 3.4))
		var a := rng.randf_range(-0.5, 0.5)
		for j in 3:
			s.box(Vector3(0.9, 0.006, 0.05), at + Vector3(cos(a) * 0.8 * j, 0, sin(a) * 0.8 * j), Color("26282c"), a + rng.randf_range(-0.4, 0.4))
	# a zebra crossing in front of the gate
	for k in 7:
		s.box(Vector3(0.5, 0.01, 7.4), Vector3(-2.1 + k * 0.7, 0.031, 54.2), LINE)


## The lawn is one big colour: lighter and darker patches (mown stripes of a park nobody
## has mown for a while) and a few bare, yellowed ones break it up. Flat fans, a few
## hundred triangles in all.
func _lawn_patches(s: ClubShapes, hi: ClubShapes) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var tones := [Color("7ea14c"), Color("5f8a3a"), Color("8aa84f"), Color("6c9640"), Color("a3a653"), Color("55803a")]
	var n := 0
	var tries := 0
	while n < 130 and tries < 900:
		tries += 1
		var q := Vector2(rng.randf_range(-62.0, 62.0), rng.randf_range(-40.0, 44.0))
		if not ClubLayout.open_at(q, -0.8):
			continue
		var r := rng.randf_range(1.8, 5.0)
		var tone: Color = tones[rng.randi() % tones.size()]
		(s if n % 2 == 0 else hi).flat(Vector2(r, r * rng.randf_range(0.5, 0.9)), Vector3(q.x, ClubLayout.LAWN + 0.02 + n * 0.0003, q.y), tone, 7, rng.randf_range(0.0, PI))
		n += 1


## The paths: the graph's one surface (laid in world space with the club's slab paving) and
## its kerb: two meshes, two draw calls.
func _build_paths() -> void:
	var w: Variant = get_parent().world
	var meshes := ClubPaths.build_meshes(ClubLayout.LAWN)
	var surf := MeshInstance3D.new()
	surf.name = "paths"
	surf.mesh = meshes["surface"]
	surf.material_override = w.get("_paving")
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surf)
	var kerb := MeshInstance3D.new()
	kerb.name = "path_kerbs"
	kerb.mesh = meshes["curb"]
	kerb.material_override = ClubScenery.prop_material()
	kerb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(kerb)
