class_name Scenery
extends Node3D
## Summer morning at a riverside park court in the city. Everything is procedural.
##
##   light   low warm sun that slowly climbs, cloud shadows drifting over the court,
##           gently breathing sunlight, morning haze, soft clouds on the horizon
##   life    swaying trees, a flock of birds now and then, boats on the river,
##           glittering water
##   court   empty umpire's chair with a sunshade, players' chairs with towels, bottles
##           and racket bags, empty bleachers, ball basket, fence with windscreens
##   world   park lawn, trees and bushes, a promenade by the river, a suspension bridge
##           and the city on the far shore
##
## Repeated things (trees, buildings, cables, posts) are MultiMesh: one draw call per
## kind, so phones keep their frame rate.

const SUN_COLOR := Color(1.0, 0.85, 0.66)
const SKY_TOP := Color(0.3, 0.53, 0.86)
const SKY_HORIZON := Color(1.0, 0.85, 0.71)
const HAZE := Color(0.95, 0.87, 0.79)
const FACADES := [
	Color(0.80, 0.70, 0.57),  # sandstone
	Color(0.62, 0.40, 0.31),  # brick
	Color(0.52, 0.60, 0.68),  # blue glass
	Color(0.86, 0.83, 0.78),  # limestone
	Color(0.42, 0.45, 0.50),  # dark glass
	Color(0.70, 0.55, 0.45),  # terracotta
]
const LEAVES := [Color(0.3, 0.48, 0.2), Color(0.4, 0.56, 0.23), Color(0.26, 0.42, 0.22), Color(0.47, 0.58, 0.27)]

const HX := Court.DOUBLES_HALF_WIDTH + 3.5  # fence half-width
const HZ := Court.HALF_LENGTH + 6.0         # fence half-length
const LAWN_Y := -0.25                       # park ground sits a curb below the court apron
const SHORE_Z := -45.0                      # near river bank
const FAR_SHORE_Z := -190.0
const WATER_Y := -0.7

var rng := RandomNumberGenerator.new()
var _sun: DirectionalLight3D
var _cloud_shadow_mat: StandardMaterial3D
var _water_mat: StandardMaterial3D
var _crowns: MultiMeshInstance3D
var _crown_base: Array[Transform3D] = []
var _crown_phase: Array[float] = []
var _clouds: Array[Node3D] = []
var _boats: Array[Node3D] = []
var _birds: Node3D
var _bird_timer := 3.0
var _t := 0.0
var _window_tex: ImageTexture
var _fence_tex: ImageTexture
var _unit_box := BoxMesh.new()
var _sphere := SphereMesh.new()


func _ready() -> void:
	rng.seed = 1977  # the same place every time
	_unit_box.size = Vector3.ONE
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 10
	_sphere.rings = 6
	_window_tex = _make_window_texture()
	_fence_tex = _make_fence_texture()
	_build_sky_and_sun()
	_build_clouds()
	_build_ground()
	_build_park()
	_build_river()
	_build_bridge()
	_build_city()
	_build_fence()
	_build_court_furniture()
	_build_bleachers()
	_build_cloud_shadows()
	_build_birds()


func _process(delta: float) -> void:
	_t += delta
	# The sun climbs slowly through the morning; its warmth breathes as thin, high
	# clouds pass in front of it.
	_sun.rotation_degrees.x = -31.0 - minf(_t / 900.0, 1.0) * 8.0
	_sun.light_energy = 1.05 + sin(_t * 0.23) * 0.05 + sin(_t * 0.071 + 1.0) * 0.05
	_cloud_shadow_mat.uv1_offset += Vector3(0.016, 0.006, 0.0) * delta
	_water_mat.uv1_offset += Vector3(0.02, 0.006, 0.0) * delta
	for c in _clouds:
		c.position.x += 0.8 * delta
		if c.position.x > 420.0:
			c.position.x -= 840.0
	for b in _boats:
		var speed: float = b.get_meta("speed")
		b.position.x += speed * delta
		b.position.y = WATER_Y + sin(_t * 1.3 + b.position.x) * 0.05
		if absf(b.position.x) > 260.0:
			b.position.x = -signf(speed) * 260.0
	# Tree crowns sway in the breeze (their shadows on the court move with them).
	var mm := _crowns.multimesh
	for i in _crown_base.size():
		var ph := _crown_phase[i]
		var sway := sin(_t * 0.9 + ph) * 0.07 + sin(_t * 2.1 + ph * 2.0) * 0.025
		var tr := _crown_base[i]
		tr.origin += Vector3(sway, 0.0, sway * 0.4)
		mm.set_instance_transform(i, tr)
	_update_birds(delta)


# --- Light & sky ------------------------------------------------------------------

func _build_sky_and_sun() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.35, 0.42, 0.45)
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.84, 0.86, 0.9)
	e.ambient_light_energy = 0.44
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.92
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	e.adjustment_contrast = 1.06
	e.fog_enabled = true
	e.fog_light_color = HAZE
	e.fog_light_energy = 1.0
	e.fog_density = 0.0019
	e.fog_sky_affect = 0.1
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-31.0, -130.0, 0.0)
	_sun.light_color = SUN_COLOR
	_sun.light_energy = 1.05
	_sun.shadow_enabled = true
	_sun.shadow_opacity = 0.62
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 50.0
	add_child(_sun)


func _build_clouds() -> void:
	# Soft cumulus banks low over the horizon, lit warm from below by the morning sun.
	var tex := _make_cloud_texture()
	for i in 9:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = Color(1.0, 0.97, 0.94).lerp(Color(1.0, 0.86, 0.78), rng.randf() * 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.disable_fog = true
		mat.disable_receive_shadows = true
		var q := QuadMesh.new()
		var w := rng.randf_range(120.0, 220.0)
		q.size = Vector2(w, w * rng.randf_range(0.28, 0.4))
		var c := MeshInstance3D.new()
		c.mesh = q
		c.material_override = mat
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dist := rng.randf_range(480.0, 600.0)
		var elev := deg_to_rad(rng.randf_range(4.0, 13.0))
		c.position = Vector3(-400.0 + i * 95.0 + rng.randf_range(-30.0, 30.0), 9.0 + dist * tan(elev), -dist)
		add_child(c)
		_clouds.append(c)


func _build_cloud_shadows() -> void:
	# Soft blotches sliding over the court: shadows of small clouds passing the sun.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 0.78, 1.0])
	ramp.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.04, 0.06, 0.12, 0.24), Color(0.04, 0.06, 0.12, 0.26)])
	tex.color_ramp = ramp
	_cloud_shadow_mat = StandardMaterial3D.new()
	_cloud_shadow_mat.albedo_texture = tex
	_cloud_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_shadow_mat.uv1_scale = Vector3(1.6, 1.6, 1.0)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90.0, 90.0)
	plane.mesh = pm
	plane.material_override = _cloud_shadow_mat
	plane.position = Vector3(0, 0.05, -10.0)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)


# --- Ground and park --------------------------------------------------------------

func _build_ground() -> void:
	# Lawn from the river bank toward (and behind) the camera.
	var lawn_len := 400.0
	_ground(Vector2(800.0, lawn_len), Vector3(0, LAWN_Y, SHORE_Z + lawn_len * 0.5), _noise_mat(Color(0.37, 0.55, 0.27), 0.08, 40.0))
	# The court's concrete apron stands on a low curb.
	var apron := Vector3(Court.DOUBLES_HALF_WIDTH * 2.0 + 13.0, 0.0, Court.HALF_LENGTH * 2.0 + 18.0)
	_box(Vector3(apron.x, -LAWN_Y - 0.05, apron.z), Vector3(0, (LAWN_Y - 0.05) * 0.5, 0), _plain(Court.COLOR_SURROUND.darkened(0.1)), false)
	# Paths from the court to the promenade, and the promenade along the river.
	var paving := _noise_mat(Color(0.74, 0.7, 0.64), 0.05, 20.0)
	_box(Vector3(2.4, 0.1, -SHORE_Z - apron.z * 0.5 - 4.0), Vector3(-3.0, LAWN_Y + 0.05, (SHORE_Z + 4.0 - apron.z * 0.5) * 0.5), paving, false)
	_box(Vector3(800.0, 0.1, 4.0), Vector3(0, LAWN_Y + 0.05, SHORE_Z + 2.0), paving, false)
	# Far shore: the city's ground.
	_ground(Vector2(800.0, 400.0), Vector3(0, LAWN_Y, FAR_SHORE_Z - 200.0), _plain(Color(0.6, 0.57, 0.52)))


func _build_park() -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	var bushes: Array[Transform3D] = []
	var bush_colors: Array[Color] = []

	var add_tree := func(p: Vector3, k: float) -> void:
		var h := 3.2 * k
		trunks.append(Transform3D(Basis.from_scale(Vector3(k, k, k)), Vector3(p.x, LAWN_Y + h * 0.5, p.z)))
		var leaf: Color = LEAVES[rng.randi() % LEAVES.size()]
		for j in 3:
			var r := rng.randf_range(1.5, 2.2) * k
			var off := Vector3(rng.randf_range(-0.9, 0.9) * k, LAWN_Y + h + 0.3 + j * 0.9 * k, rng.randf_range(-0.9, 0.9) * k)
			crowns.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.88, r)), Vector3(p.x, 0.0, p.z) + off))
			crown_colors.append(leaf.lerp(Color(0.62, 0.66, 0.3), rng.randf() * 0.25))

	# A row of trees along each side of the court.
	for i in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := lerpf(-HZ + 1.0, HZ + 2.0, float(i >> 1) / 6.0)
		if side > 0.0 and z > -HZ and z < -2.0:
			continue  # bleachers stand there
		add_tree.call(Vector3(side * (HX + rng.randf_range(5.0, 7.0)), 0.0, z), rng.randf_range(0.95, 1.2))
	# Park between the court and the river, kept open in the middle so the river,
	# the bridge and the city stay in view.
	var n := 0
	while n < 60:
		var p := Vector3(rng.randf_range(-90.0, 90.0), 0.0, rng.randf_range(SHORE_Z + 6.0, 40.0))
		var open_view := absf(p.x) < 14.0 + (-p.z - HZ) * 0.55
		if (absf(p.x) < HX + 4.0 and p.z > -HZ - 4.0) or (p.z < -HZ and open_view):
			continue
		add_tree.call(p, rng.randf_range(0.95, 1.5))
		n += 1
	# A few low trees right on the bank frame the water.
	for x in [-34.0, -21.0, 26.0, 41.0]:
		add_tree.call(Vector3(x, 0.0, SHORE_Z + 6.5), 0.8)

	# Bushes along the far fence, around the court and by the paths.
	for i in 22:
		var x := lerpf(-HX - 2.5, HX + 2.5, i / 21.0)
		if absf(x + 3.0) < 1.6:
			continue  # gap for the path
		bushes.append(Transform3D(Basis.from_scale(Vector3(1.3, 0.85, 1.0) * rng.randf_range(0.8, 1.1)), Vector3(x, LAWN_Y + 0.5, -HZ - 3.8)))
		bush_colors.append(LEAVES[rng.randi() % LEAVES.size()])
	for i in 18:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := lerpf(-HZ - 2.0, HZ, float(i >> 1) / 8.0)
		bushes.append(Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.3) * rng.randf_range(0.8, 1.1)), Vector3(side * (HX + 3.6), LAWN_Y + 0.45, z)))
		bush_colors.append(LEAVES[rng.randi() % LEAVES.size()].darkened(0.08))
	for i in 30:
		var x := rng.randf_range(-40.0, 40.0)
		var z := rng.randf_range(SHORE_Z + 5.0, -HZ - 6.0)
		if absf(x + 3.0) < 2.0:
			continue
		bushes.append(Transform3D(Basis.from_scale(Vector3(1.1, 0.7, 1.0) * rng.randf_range(0.7, 1.2)), Vector3(x, LAWN_Y + 0.35, z)))
		bush_colors.append(LEAVES[rng.randi() % LEAVES.size()])

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 3.2
	trunk_mesh.radial_segments = 6
	_mm(trunk_mesh, _plain(Color(0.36, 0.27, 0.2)), trunks)
	_crowns = _mm(_sphere, _tinted(), crowns, crown_colors)
	_crown_base = crowns
	for i in crowns.size():
		_crown_phase.append(rng.randf() * TAU)
	_mm(_sphere, _tinted(), bushes, bush_colors)

	# Flower beds by the court gate.
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var palette := [Color(0.95, 0.35, 0.42), Color(1.0, 0.82, 0.3), Color(0.97, 0.97, 0.95), Color(0.72, 0.45, 0.92)]
	for c in [Vector3(-6.2, LAWN_Y, -HZ - 6.5), Vector3(0.2, LAWN_Y, -HZ - 6.5)]:
		_box(Vector3(4.2, 0.3, 1.5), c + Vector3(0, 0.15, 0), _plain(Color(0.42, 0.33, 0.26)))
		for k in 36:
			var fp: Vector3 = c + Vector3(rng.randf_range(-1.9, 1.9), 0.36, rng.randf_range(-0.6, 0.6))
			flowers.append(Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.1, 0.16)), fp))
			flower_colors.append(palette[rng.randi() % palette.size()])
	_mm(_sphere, _tinted(), flowers, flower_colors)

	# Park benches and lamps along the paths.
	_bench(Vector3(-5.6, LAWN_Y, -HZ - 9.5), 0.0)
	_bench(Vector3(-0.4, LAWN_Y, -HZ - 13.0), PI)
	_bench(Vector3(-HX - 1.6, 0.0, 5.0), PI * 0.5)
	var lamps: Array[Transform3D] = []
	var x := -60.0
	while x <= 60.0:
		lamps.append(Transform3D(Basis.from_scale(Vector3(0.12, 4.0, 0.12)), Vector3(x, LAWN_Y + 2.0, SHORE_Z + 3.6)))
		lamps.append(Transform3D(Basis.from_scale(Vector3(0.35, 0.45, 0.35)), Vector3(x, LAWN_Y + 4.2, SHORE_Z + 3.6)))
		x += 12.0
	_mm(_unit_box, _plain(Color(0.14, 0.15, 0.16)), lamps)


# --- River, bridge, city ----------------------------------------------------------

func _build_river() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.06
	var ripples := NoiseTexture2D.new()
	ripples.width = 256
	ripples.height = 256
	ripples.seamless = true
	ripples.as_normal_map = true
	ripples.bump_strength = 5.0
	ripples.noise = noise
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.25, 0.42, 0.55)
	_water_mat.metallic = 0.4
	_water_mat.roughness = 0.1
	_water_mat.normal_enabled = true
	_water_mat.normal_texture = ripples
	_water_mat.uv1_scale = Vector3(60.0, 12.0, 1.0)
	var width := FAR_SHORE_Z - SHORE_Z
	_ground(Vector2(800.0, -width + 2.0), Vector3(0, WATER_Y, (SHORE_Z + FAR_SHORE_Z) * 0.5), _water_mat)
	# Stone embankments with a railing on our side.
	var stone := _plain(Color(0.62, 0.58, 0.52))
	for z in [SHORE_Z, FAR_SHORE_Z]:
		_box(Vector3(800.0, LAWN_Y - WATER_Y + 0.8, 0.8), Vector3(0, (LAWN_Y + WATER_Y - 0.8) * 0.5, z), stone, false)
	var rail: Array[Transform3D] = []
	var x := -100.0
	while x <= 100.0:
		rail.append(Transform3D(Basis.from_scale(Vector3(0.06, 1.0, 0.06)), Vector3(x, LAWN_Y + 0.5, SHORE_Z + 0.3)))
		x += 2.0
	rail.append(Transform3D(Basis.from_scale(Vector3(200.0, 0.06, 0.08)), Vector3(0, LAWN_Y + 1.0, SHORE_Z + 0.3)))
	_mm(_unit_box, _plain(Color(0.12, 0.13, 0.14)), rail)
	# Boats: a couple of sailboats and a small ferry.
	_boat(Vector3(-60.0, WATER_Y, -78.0), 2.2, true)
	_boat(Vector3(70.0, WATER_Y, -112.0), -1.6, true)
	_boat(Vector3(-140.0, WATER_Y, -165.0), 3.4, false)


func _boat(p: Vector3, speed: float, sail: bool) -> void:
	var b := Node3D.new()
	b.position = p
	b.set_meta("speed", speed)
	add_child(b)
	var white := _plain(Color(0.96, 0.96, 0.94))
	if sail:
		b.add_child(_mesh_box(Vector3(7.0, 0.9, 2.2), Vector3(0, 0.45, 0), white))
		b.add_child(_mesh_box(Vector3(0.12, 8.0, 0.12), Vector3(0.6, 4.6, 0), _plain(Color(0.3, 0.3, 0.3))))
		var s := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(4.2, 7.0, 0.05)
		pm.left_to_right = 1.0
		s.mesh = pm
		s.material_override = white
		s.position = Vector3(-1.5, 4.6, 0)
		b.add_child(s)
	else:
		b.add_child(_mesh_box(Vector3(16.0, 1.6, 5.0), Vector3(0, 0.8, 0), white))
		b.add_child(_mesh_box(Vector3(9.0, 2.2, 4.2), Vector3(-1.0, 2.7, 0), _plain(Color(0.95, 0.6, 0.2))))
	_boats.append(b)


func _build_bridge() -> void:
	# A stone-towered suspension bridge crossing the river at an angle.
	var bridge := Node3D.new()
	bridge.position = Vector3(10.0, 0.0, -140.0)
	bridge.rotation.y = deg_to_rad(20.0)
	add_child(bridge)
	var deck_y := 11.0
	var tower_h := 31.0
	var span := 52.0  # tower x in local space (±)
	var stone := _plain(Color(0.74, 0.64, 0.52))
	_box(Vector3(500.0, 1.4, 10.0), Vector3(0, deck_y, 0), _plain(Color(0.4, 0.38, 0.37)), true, bridge)
	for tx in [-span, span]:
		_box(Vector3(9.0, 4.0, 13.0), Vector3(tx, WATER_Y + 1.0, 0), stone, true, bridge)  # pier
		for side in [-1.0, 1.0]:
			_box(Vector3(4.5, tower_h, 3.0), Vector3(tx, tower_h * 0.5, side * 4.0), stone, true, bridge)
		_box(Vector3(4.6, 4.0, 11.0), Vector3(tx, tower_h - 2.0, 0), stone, true, bridge)
		_box(Vector3(4.6, 2.5, 11.0), Vector3(tx, deck_y + 9.0, 0), stone, true, bridge)
	var top := tower_h - 1.0
	var cable_y := func(x: float) -> float:
		var a := absf(x)
		if a <= span:
			return deck_y + 2.0 + (top - deck_y - 2.0) * pow(a / span, 2.0)
		return lerpf(top, deck_y + 1.0, clampf((a - span) / 120.0, 0.0, 1.0))
	var segs: Array[Transform3D] = []
	for side in [-4.6, 4.6]:
		var x := -200.0
		while x < 200.0:
			var step := 4.0
			var a := Vector3(x, cable_y.call(x), side)
			var b := Vector3(x + step, cable_y.call(x + step), side)
			segs.append(_segment(a, b, 0.3))
			if absf(x) < 170.0 and a.y > deck_y + 1.5:
				segs.append(_segment(Vector3(x, deck_y + 0.7, side), a, 0.08))
			x += step
	_mm(_unit_box, _plain(Color(0.3, 0.3, 0.31)), segs, [], bridge)


func _build_city() -> void:
	# Low brownstones on the waterfront, towers behind them, all softened by haze.
	var boxes: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tanks: Array[Vector3] = []
	for row in 2:
		var x := -340.0
		while x < 340.0:
			var w := rng.randf_range(12.0, 26.0) if row == 1 else rng.randf_range(8.0, 16.0)
			var d := rng.randf_range(12.0, 22.0)
			var z := FAR_SHORE_Z - 14.0 - rng.randf_range(0.0, 6.0) if row == 0 else rng.randf_range(-290.0, -240.0)
			var h := rng.randf_range(10.0, 22.0) if row == 0 else rng.randf_range(28.0, 62.0)
			if row == 1 and absf(x) < 170.0 and rng.randf() < 0.35:
				h = rng.randf_range(80.0, 150.0)
			var col: Color = FACADES[rng.randi() % FACADES.size()]
			var tiers := 3 if h > 75.0 else (2 if h > 40.0 else 1)
			var shares: Array = [1.0] if tiers == 1 else ([0.68, 0.32] if tiers == 2 else [0.55, 0.28, 0.17])
			var y := LAWN_Y
			var ww := w
			var dd := d
			for t in tiers:
				var th: float = h * float(shares[t])
				boxes.append(Transform3D(Basis.from_scale(Vector3(ww, th, dd)), Vector3(x + w * 0.5, y + th * 0.5, z)))
				colors.append(col)
				y += th
				ww *= 0.74
				dd *= 0.74
			if h > 110.0:  # spire
				boxes.append(Transform3D(Basis.from_scale(Vector3(1.2, h * 0.25, 1.2)), Vector3(x + w * 0.5, y + h * 0.125, z)))
				colors.append(Color(0.75, 0.75, 0.75))
			if h < 40.0 and rng.randf() < 0.45:
				tanks.append(Vector3(x + w * 0.5 + rng.randf_range(-2.0, 2.0), y, z))
			x += w + (rng.randf_range(0.0, 2.0) if row == 0 else rng.randf_range(3.0, 9.0))
	_mm(_unit_box, _facade(), boxes, colors)
	# Rooftop water tanks: wooden barrels on legs with cone hats.
	var barrels: Array[Transform3D] = []
	var hats: Array[Transform3D] = []
	for p in tanks:
		barrels.append(Transform3D(Basis.from_scale(Vector3(1.8, 1.6, 1.8)), p + Vector3(0, 3.4, 0)))
		hats.append(Transform3D(Basis.from_scale(Vector3(2.0, 0.9, 2.0)), p + Vector3(0, 5.4, 0)))
	var barrel := CylinderMesh.new()
	barrel.top_radius = 1.0
	barrel.bottom_radius = 1.0
	barrel.height = 2.0
	barrel.radial_segments = 8
	_mm(barrel, _plain(Color(0.45, 0.32, 0.22)), barrels)
	var hat := CylinderMesh.new()
	hat.top_radius = 0.05
	hat.bottom_radius = 1.1
	hat.height = 1.0
	hat.radial_segments = 8
	_mm(hat, _plain(Color(0.3, 0.25, 0.2)), hats)


# --- Court ------------------------------------------------------------------------

func _build_fence() -> void:
	var height := 3.6
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_texture = _fence_tex
	mesh_mat.albedo_color = Color(0.16, 0.24, 0.2)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh_mat.alpha_scissor_threshold = 0.5
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_mat.uv1_triplanar = true
	mesh_mat.uv1_world_triplanar = true
	mesh_mat.uv1_scale = Vector3(1.6, 1.6, 1.6)
	var screen := _plain(Color(0.13, 0.3, 0.22))  # windscreen fabric on the lower part
	# Far end and both sides (the near end would stand between the camera and the player).
	_box(Vector3(HX * 2.0, height, 0.02), Vector3(0, height * 0.5, -HZ), mesh_mat, false)
	_box(Vector3(HX * 2.0, 1.9, 0.03), Vector3(0, 0.95, -HZ + 0.03), screen)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.02, height, HZ * 2.0), Vector3(s * HX, height * 0.5, 0), mesh_mat, false)
		_box(Vector3(0.03, 1.9, HZ * 2.0), Vector3(s * (HX - 0.03), 0.95, 0), screen)
	var posts: Array[Transform3D] = []
	var x := -HX
	while x <= HX + 0.01:
		posts.append(Transform3D(Basis.from_scale(Vector3(0.09, height + 0.1, 0.09)), Vector3(x, (height + 0.1) * 0.5, -HZ)))
		x += 3.0
	var z := -HZ
	while z <= HZ + 0.01:
		for s in [-1.0, 1.0]:
			posts.append(Transform3D(Basis.from_scale(Vector3(0.09, height + 0.1, 0.09)), Vector3(s * HX, (height + 0.1) * 0.5, z)))
		z += 3.0
	posts.append(Transform3D(Basis.from_scale(Vector3(HX * 2.0, 0.07, 0.07)), Vector3(0, height, -HZ)))
	for s in [-1.0, 1.0]:
		posts.append(Transform3D(Basis.from_scale(Vector3(0.07, 0.07, HZ * 2.0)), Vector3(s * HX, height, 0)))
	# Light poles at the corners.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			posts.append(Transform3D(Basis.from_scale(Vector3(0.18, 8.0, 0.18)), Vector3(sx * (HX + 0.3), 4.0, sz * (HZ - 0.3))))
	_mm(_unit_box, _plain(Color(0.12, 0.16, 0.14)), posts)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.9, 0.25, 0.5), Vector3(sx * (HX - 0.05), 8.0, sz * (HZ - 0.5)), _plain(Color(0.85, 0.85, 0.8)))


func _build_court_furniture() -> void:
	var frame := _plain(Color(0.18, 0.3, 0.25))
	var white := _plain(Color(0.95, 0.95, 0.92))
	# Umpire's chair by the net post: a tall frame, a seat with a backrest, a footrest,
	# a ladder and a sunshade. Nobody in it: it is just a morning hit.
	var ux := Court.NET_HALF_WIDTH + 1.35
	for lx in [-0.4, 0.4]:
		for lz in [-0.4, 0.4]:
			_box(Vector3(0.07, 2.0, 0.07), Vector3(ux + lx, 1.0, lz), frame)
	for h in [0.7, 1.4]:
		_box(Vector3(0.85, 0.05, 0.05), Vector3(ux, h, -0.4), frame)
		_box(Vector3(0.85, 0.05, 0.05), Vector3(ux, h, 0.4), frame)
	_box(Vector3(0.95, 0.08, 0.95), Vector3(ux, 2.0, 0), frame)
	_box(Vector3(0.62, 0.1, 0.6), Vector3(ux - 0.02, 2.12, 0), white)
	_box(Vector3(0.08, 0.75, 0.6), Vector3(ux + 0.3, 2.5, 0), white)
	for side in [-0.32, 0.32]:
		_box(Vector3(0.55, 0.06, 0.06), Vector3(ux - 0.02, 2.4, side), frame)  # armrests
	_box(Vector3(0.5, 0.05, 0.6), Vector3(ux - 0.65, 1.15, 0), frame)        # footrest
	for k in 5:
		_box(Vector3(0.06, 0.04, 0.55), Vector3(ux + 0.55, 0.3 + k * 0.38, 0), frame)
	_box(Vector3(0.04, 1.9, 0.04), Vector3(ux + 0.55, 0.95, -0.27), frame)
	_box(Vector3(0.04, 1.9, 0.04), Vector3(ux + 0.55, 0.95, 0.27), frame)
	_box(Vector3(0.05, 1.3, 0.05), Vector3(ux + 0.25, 3.1, 0), white)
	var canopy := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 1.05
	cm.height = 0.35
	cm.radial_segments = 8
	canopy.mesh = cm
	canopy.material_override = _plain(Color(0.2, 0.42, 0.32))
	canopy.position = Vector3(ux + 0.15, 3.8, 0)
	add_child(canopy)

	# Players' chairs on the other side of the net, with towels, bottles and bags.
	var bx := -(Court.NET_HALF_WIDTH + 1.3)
	var bottles: Array[Transform3D] = []
	var bottle_colors: Array[Color] = []
	for bz in [-1.4, 1.4]:
		_chair(Vector3(bx, 0.0, bz), -PI * 0.5)
		var towel := Color(0.95, 0.42, 0.36) if bz > 0.0 else Color(0.36, 0.56, 0.92)
		_box(Vector3(0.12, 0.5, 0.42), Vector3(bx - 0.27, 0.62, bz), _plain(towel))  # over the backrest
		_box(Vector3(0.8, 0.32, 0.32), Vector3(bx - 0.75, 0.16, bz + 0.15), _plain(Color(0.14, 0.16, 0.2)))  # racket bag
		for k in 2:
			bottles.append(Transform3D(Basis.from_scale(Vector3(0.035, 0.12, 0.035)), Vector3(bx + 0.45, 0.12, bz + (k - 0.5) * 0.14)))
			bottle_colors.append(Color(0.45, 0.78, 0.98) if k == 0 else Color(0.98, 0.85, 0.3))
	_box(Vector3(0.45, 0.55, 0.45), Vector3(bx - 0.05, 0.28, 0.0), _plain(Color(0.2, 0.42, 0.75)))  # cooler
	_box(Vector3(0.47, 0.06, 0.47), Vector3(bx - 0.05, 0.58, 0.0), white)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 2.0
	cyl.radial_segments = 8
	_mm(cyl, _tinted(), bottles, bottle_colors)

	# Ball basket in the near corner, and a few stray balls by the far fence.
	var basket := Vector3(-(Court.DOUBLES_HALF_WIDTH + 1.4), 0.0, Court.HALF_LENGTH + 1.2)
	_box(Vector3(0.45, 0.05, 0.45), basket + Vector3(0, 0.7, 0), frame)
	for lx in [-0.2, 0.2]:
		_box(Vector3(0.03, 0.7, 0.03), basket + Vector3(lx, 0.35, 0), frame)
	var balls: Array[Transform3D] = []
	for k in 22:
		balls.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.034), basket + Vector3(rng.randf_range(-0.17, 0.17), 0.76 + rng.randf_range(0.0, 0.14), rng.randf_range(-0.17, 0.17))))
	for k in 4:
		balls.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.034), Vector3(rng.randf_range(-HX + 1.0, HX - 1.0), 0.034, rng.randf_range(-HZ + 0.4, -HZ + 1.6))))
	_mm(_sphere, _plain(Color(0.86, 0.95, 0.2)), balls)
	# The park's name painted behind each baseline, as on real courts.
	for end in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = "EAST RIVER PARK"
		label.font_size = 96
		label.pixel_size = 0.0065
		label.outline_size = 0
		label.modulate = Color(1, 1, 1, 0.55)
		label.shaded = false
		label.double_sided = false
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.rotation = Vector3(-PI * 0.5, 0.0 if end > 0.0 else PI, 0.0)
		label.position = Vector3(0, 0.04, end * (Court.HALF_LENGTH + 2.3))
		add_child(label)
	# Court brush leaning on the side fence.
	_box(Vector3(0.06, 1.6, 0.06), Vector3(HX - 0.25, 0.8, 9.0), _plain(Color(0.6, 0.45, 0.3)))
	_box(Vector3(0.2, 0.12, 1.4), Vector3(HX - 0.2, 0.06, 9.0), _plain(Color(0.25, 0.25, 0.25)))


func _build_bleachers() -> void:
	# Small aluminium stands outside the right fence, empty this early.
	var x0 := HX + 1.3
	var seats: Array[Transform3D] = []
	for row in 4:
		var y := 0.4 + row * 0.45
		var x := x0 + row * 0.7
		seats.append(Transform3D(Basis.from_scale(Vector3(0.5, 0.06, 11.0)), Vector3(x, y, -9.0)))   # seat
		seats.append(Transform3D(Basis.from_scale(Vector3(0.06, 0.42, 11.0)), Vector3(x - 0.3, y - 0.2, -9.0)))  # riser
	for z in [-14.4, -9.0, -3.6]:
		seats.append(Transform3D(Basis.from_scale(Vector3(3.2, 0.08, 0.08)), Vector3(x0 + 1.05, 0.95, z)).rotated_local(Vector3.FORWARD, -0.57))
	_mm(_unit_box, _plain(Color(0.78, 0.8, 0.82)), seats)


func _chair(p: Vector3, yaw: float) -> void:
	var c := Node3D.new()
	c.position = p
	c.rotation.y = yaw
	add_child(c)
	var mat := _plain(Color(0.92, 0.92, 0.9))
	c.add_child(_mesh_box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.45, 0), mat))
	c.add_child(_mesh_box(Vector3(0.5, 0.5, 0.05), Vector3(0, 0.72, 0.23), mat))
	for lx in [-0.22, 0.22]:
		for lz in [-0.22, 0.22]:
			c.add_child(_mesh_box(Vector3(0.04, 0.45, 0.04), Vector3(lx, 0.22, lz), _plain(Color(0.3, 0.3, 0.32))))


func _bench(p: Vector3, yaw: float) -> void:
	var b := Node3D.new()
	b.position = p
	b.rotation.y = yaw
	add_child(b)
	var wood := _plain(Color(0.55, 0.38, 0.24))
	var iron := _plain(Color(0.15, 0.16, 0.17))
	b.add_child(_mesh_box(Vector3(2.0, 0.06, 0.45), Vector3(0, 0.45, 0), wood))
	b.add_child(_mesh_box(Vector3(2.0, 0.4, 0.05), Vector3(0, 0.75, 0.22), wood))
	for lx in [-0.85, 0.85]:
		b.add_child(_mesh_box(Vector3(0.06, 0.45, 0.45), Vector3(lx, 0.22, 0), iron))


# --- Birds ------------------------------------------------------------------------

func _build_birds() -> void:
	_birds = Node3D.new()
	_birds.visible = false
	add_child(_birds)
	var mat := _plain(Color(0.15, 0.15, 0.17))
	for i in 7:
		var bird := Node3D.new()
		bird.position = Vector3(-absf(i - 3) * 2.2, (i % 3) * 0.7, (i - 3) * 2.0)
		for side in [-1.0, 1.0]:
			var wing := _mesh_box(Vector3(0.75, 0.04, 0.3), Vector3(side * 0.36, 0, 0), mat)
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bird.add_child(wing)
		_birds.add_child(bird)


func _update_birds(delta: float) -> void:
	if not _birds.visible:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			# A small flock crosses over the park beyond the court.
			_birds.visible = true
			_birds.position = Vector3(-45.0, rng.randf_range(10.0, 15.0), rng.randf_range(-45.0, -28.0))
		return
	_birds.position.x += 7.0 * delta
	_birds.position.y += sin(_t * 0.8) * 0.5 * delta
	for i in _birds.get_child_count():
		var b := _birds.get_child(i) as Node3D
		var flap := sin(_t * 10.0 + i * 1.3) * 0.55
		(b.get_child(0) as Node3D).rotation.z = -flap
		(b.get_child(1) as Node3D).rotation.z = flap
	if _birds.position.x > 50.0:
		_birds.visible = false
		_bird_timer = rng.randf_range(12.0, 25.0)


# --- Helpers ----------------------------------------------------------------------

func _mm(mesh: Mesh, mat: Material, transforms: Array[Transform3D], colors: Array[Color] = [], parent: Node3D = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	(parent if parent else self).add_child(mmi)
	return mmi


## Thin box from a to b (cables).
func _segment(a: Vector3, b: Vector3, thickness: float) -> Transform3D:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Transform3D(Basis(x * thickness, y * d.length(), x.cross(y).normalized() * thickness), (a + b) * 0.5)


func _ground(size: Vector2, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _box(size: Vector3, pos: Vector3, mat: Material, shadow := true, parent: Node3D = null) -> void:
	var mi := _mesh_box(size, pos, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)


func _mesh_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	return mi


func _plain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


## White material tinted per instance (MultiMesh colors).
func _tinted() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	return m


## Ground material with soft large-scale mottling, so big areas never look flat.
func _noise_mat(c: Color, amount: float, tile_m: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([c.darkened(amount), c.lightened(amount)])
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	return m


## Facade with a world-space window grid (3 m bays, 3.5 m floors), tinted per instance.
func _facade() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _window_tex
	m.roughness = 0.8
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 3.0, 1.0 / 3.5, 1.0 / 3.0)
	return m


func _make_window_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	for y in range(9, 27):
		for x in range(6, 26):
			img.set_pixel(x, y, Color(0.55, 0.62, 0.72))
	for x in range(6, 26):
		img.set_pixel(x, 18, Color(0.75, 0.78, 0.82))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_fence_texture() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in n:
		for t in [-1, 0, 1]:
			img.set_pixel(i, posmod(i + t, n), Color(1, 1, 1, 1))
			img.set_pixel(i, posmod(n - 1 - i + t, n), Color(1, 1, 1, 1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A puffy cloud: a few overlapping soft blobs with a flatter base, brighter on top.
func _make_cloud_texture() -> ImageTexture:
	var w := 192
	var h := 72
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	var blobs := []
	for i in 7:
		blobs.append(Vector3(rng.randf_range(0.2, 0.8) * w, rng.randf_range(0.45, 0.7) * h, rng.randf_range(14.0, 27.0)))
	for y in h:
		for x in w:
			var d := 0.0
			for bl in blobs:
				var v: Vector3 = bl
				var dx := (x - v.x) / (v.z * 1.6)
				var dy := (y - v.y) / v.z
				d = maxf(d, 1.0 - (dx * dx + dy * dy))
			d += noise.get_noise_2d(x, y) * 0.35
			var base := clampf((h * 0.78 - y) / (h * 0.12), 0.0, 1.0)  # flat bottom
			var a := clampf(d * 2.2, 0.0, 1.0) * base * 0.92
			var shade := lerpf(0.86, 1.0, clampf(1.0 - y / float(h) + 0.2, 0.0, 1.0))
			img.set_pixel(x, y, Color(shade, shade, shade * 0.98, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
