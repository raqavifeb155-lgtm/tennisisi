class_name SceneryClay
extends Scenery
## Golden hour at a clay-court club on the Spanish Mediterranean (Costa del Sol).
## Everything is procedural, like Scenery (the New York park) whose helpers it reuses.
##
##   light   the sun sets over the sea beyond the far end of the court: a peach-to-violet
##           sky, sun-tinted clouds, warm haze. The shadow-casting light stays higher and
##           to the right, so shadows fall short and sideways, never across the court
##   life    swaying palms, sailboats and yachts crossing the bay, gulls circling, the sea
##           glittering in the sun's path, ripples on the club pool
##   court   green windscreens, a wooden umpire's chair with a sunshade, white benches
##           with towels, white-and-wood stands, festoon lights over the terraces
##   world   a club house with an arcade and a terracotta roof, a pool, a seafront
##           promenade with a balustrade, whitewashed villas on a hillside that runs out
##           into the sea as a headland with a lighthouse, mountains in the haze
##
## Repeated things are MultiMeshes (one draw call per kind); only the sun casts shadows,
## and only near, large things cast them.

const SKY_HORIZON_C := Color(0.98, 0.64, 0.42)    # also the haze colour: sea and sky meet
const SKY_LOW_C := Color(0.9, 0.52, 0.52)
const SKY_MID_C := Color(0.66, 0.46, 0.66)
const SKY_TOP_C := Color(0.34, 0.35, 0.62)
const SUN_GLOW_C := Color(1.0, 0.6, 0.32)
const SUN_LIGHT_C := Color(1.0, 0.8, 0.6)
## The sun disk drawn in the sky, low over the sea (azimuth right of -Z, elevation).
const SUN_SKY_AZIMUTH := 9.0
const SUN_SKY_ELEVATION := 3.6
## The shadow-casting light: high enough for short shadows, from the far right.
const SUN_LIGHT_ROTATION := Vector3(-34.0, 125.0, 0.0)

const PLATEAU_Y := LAWN_Y        # the club's terrace, a curb below the court apron
const SEA_Y := -5.5              # the sea lies below the terrace wall
const EDGE_Z := -45.0            # terrace wall on the seafront (court side face)
const WALL_T := 0.6
const HEAD_A := Vector2(-75.0, -70.0)    # the headland's ridge, from its root...
const HEAD_B := Vector2(-112.0, -390.0)  # ...to its tip with the lighthouse
const CLUB_X := -17.0            # club house arcade front (faces the court)
const NEIGH_X := 33.0            # a second clay court beyond the right fence

const WHITES := [Color(0.97, 0.95, 0.9), Color(0.98, 0.93, 0.84), Color(0.96, 0.9, 0.8), Color(0.99, 0.97, 0.94), Color(0.97, 0.86, 0.76), Color(0.95, 0.83, 0.66)]
const TERRACOTTA := [Color(0.7, 0.38, 0.27), Color(0.64, 0.34, 0.25), Color(0.74, 0.44, 0.32), Color(0.6, 0.32, 0.24)]
const PALM_GREEN := Color(0.34, 0.5, 0.22)
const BOUGAINVILLEA := [Color(0.86, 0.16, 0.52), Color(0.78, 0.12, 0.48), Color(0.93, 0.3, 0.62), Color(0.7, 0.18, 0.6)]
const SHRUBS := [Color(0.3, 0.42, 0.2), Color(0.38, 0.48, 0.24), Color(0.26, 0.36, 0.2), Color(0.44, 0.5, 0.3)]

var _hnoise := FastNoiseLite.new()
var _sea_mat: ShaderMaterial
var _pool_mat: StandardMaterial3D
var _cloud_mm: MultiMesh
var _cloud_pos: Array[Vector3] = []
var _cloud_basis: Array[Basis] = []
var _boat_list: Array[Dictionary] = []
var _gull_mm: MultiMesh
var _gulls: MultiMeshInstance3D
var _gull_data: Array[Vector4] = []
var _low_quality_hidden: Array[Node3D] = []
var _vc: StandardMaterial3D
var _fence_mat: StandardMaterial3D
var _fence_t: Array[Transform3D] = []

# Batches filled while building, turned into MultiMeshes at the end (_flush).
var _near_t: Array[Transform3D] = []    # tinted boxes that cast shadows
var _near_c: Array[Color] = []
var _far_t: Array[Transform3D] = []     # tinted boxes that do not
var _far_c: Array[Color] = []
var _wall_near_t: Array[Transform3D] = []  # whitewashed walls with windows
var _wall_near_c: Array[Color] = []
var _wall_far_t: Array[Transform3D] = []
var _wall_far_c: Array[Color] = []
var _gable_near_t: Array[Transform3D] = []
var _gable_far_t: Array[Transform3D] = []
var _gable_far_c: Array[Color] = []
var _hip_near_t: Array[Transform3D] = []
var _hip_far_t: Array[Transform3D] = []
var _hip_far_c: Array[Color] = []
var _bloom_t: Array[Transform3D] = []   # bougainvillea and flowers
var _bloom_c: Array[Color] = []
var _bush_t: Array[Transform3D] = []
var _bush_c: Array[Color] = []
var _scrub_t: Array[Transform3D] = []
var _scrub_c: Array[Color] = []
var _cypress_t: Array[Transform3D] = []
var _cypress_c: Array[Color] = []
var _pot_t: Array[Transform3D] = []
var _pot_c: Array[Color] = []
var _parasol_t: Array[Transform3D] = []
var _parasol_c: Array[Color] = []
var _trunk_t: Array[Transform3D] = []
var _trunk_c: Array[Color] = []
var _crown_t: Array[Transform3D] = []
var _crown_c: Array[Color] = []
var _glow_t: Array[Transform3D] = []    # festoon bulbs, lanterns, the lighthouse lamp
var _wire_t: Array[Transform3D] = []
var _stone_t: Array[Transform3D] = []   # pale stone paving
var _tile_t: Array[Transform3D] = []    # terracotta tiles
# Palms: [variant][casts shadow] -> transforms.
var _palm_t := [[[], []], [[], []], [[], []]]
var _villa_spots: Array[Vector2] = []


func _ready() -> void:
	rng.seed = 2208  # the same place every time
	_unit_box.size = Vector3.ONE
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 10
	_sphere.rings = 6
	_hnoise.seed = 31
	_hnoise.frequency = 0.009
	_hnoise.fractal_octaves = 3
	_fence_tex = _make_fence_texture()
	_vc = _vc_mat()
	_build_sky_and_light()
	_build_clouds()
	_build_terrain()
	_build_sea()
	_build_seafront()
	_build_grounds()
	_build_clubhouse()
	_build_pool()
	_build_fence()
	_build_neighbour_court()
	_build_court_furniture()
	_build_stands()
	_build_string_lights()
	_build_gardens()
	_build_villas()
	_build_hill_vegetation()
	_build_lighthouse()
	_build_boats()
	_build_gulls()
	_flush()


func _process(delta: float) -> void:
	_t += delta
	_pool_mat.uv1_offset += Vector3(0.012, 0.007, 0.0) * delta
	for i in _cloud_pos.size():
		var p := _cloud_pos[i]
		p.x += 0.6 * delta
		if p.x > 560.0:
			p.x -= 1120.0
		_cloud_pos[i] = p
		_cloud_mm.set_instance_transform(i, Transform3D(_cloud_basis[i], p))
	_update_boats(delta)
	if _gulls.visible:
		_update_gulls()


## Lighter rendering for slow phones: hard shadows over a shorter distance; the gulls,
## the hillside scrub and the beach things are hidden.
func set_high_quality(on: bool) -> void:
	_sun.directional_shadow_max_distance = 45.0 if on else 28.0
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if on else RenderingServer.SHADOW_QUALITY_HARD)
	for n in _low_quality_hidden:
		n.visible = on


# --- Light & sky ------------------------------------------------------------------

func _sun_sky_dir() -> Vector3:
	var az := deg_to_rad(SUN_SKY_AZIMUTH)
	var el := deg_to_rad(SUN_SKY_ELEVATION)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


func _build_sky_and_light() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type sky;
uniform vec3 sun_dir = vec3(0.24, 0.07, -0.97);
uniform vec4 horizon : source_color;
uniform vec4 low : source_color;
uniform vec4 mid : source_color;
uniform vec4 top : source_color;
uniform vec4 glow : source_color;
void sky() {
	vec3 d = EYEDIR;
	float y = max(d.y, 0.0);
	vec2 hd = normalize(d.xz + vec2(0.00001));
	float toward = max(dot(hd, normalize(sun_dir.xz)), 0.0);
	float s = max(dot(d, sun_dir), 0.0);
	// The warm band over the horizon is wider toward the sun.
	float lift = 0.035 + 0.07 * toward * toward;
	vec3 c = mix(horizon.rgb, low.rgb, smoothstep(0.0, lift, y));
	c = mix(c, mid.rgb, smoothstep(lift * 0.7, 0.2 + 0.06 * toward, y));
	c = mix(c, top.rgb, smoothstep(0.18, 0.6, y));
	c += glow.rgb * (pow(s, 6.0) * 0.28 + pow(s, 60.0) * 0.4 + pow(s, 900.0) * 0.7);
	// The sun disk, soft-edged, a little squashed as it nears the sea.
	c = mix(c, vec3(2.6, 1.75, 0.95), smoothstep(0.99958, 0.99968, s));
	if (d.y < 0.0) {
		c = horizon.rgb + glow.rgb * pow(s, 60.0) * 0.3;
	}
	COLOR = c;
}
"""
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sh
	sky_mat.set_shader_parameter("sun_dir", _sun_sky_dir())
	sky_mat.set_shader_parameter("horizon", SKY_HORIZON_C)
	sky_mat.set_shader_parameter("low", SKY_LOW_C)
	sky_mat.set_shader_parameter("mid", SKY_MID_C)
	sky_mat.set_shader_parameter("top", SKY_TOP_C)
	sky_mat.set_shader_parameter("glow", SUN_GLOW_C)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.82, 0.74, 0.86)  # violet-tinted shade, warm light
	e.ambient_light_energy = 0.56
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.98
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.08
	e.adjustment_contrast = 1.05
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = SKY_HORIZON_C
	e.fog_light_energy = 0.95
	e.fog_density = 0.85
	e.fog_depth_begin = 80.0
	e.fog_depth_end = 900.0
	e.fog_depth_curve = 1.0
	e.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = SUN_LIGHT_ROTATION
	_sun.light_color = SUN_LIGHT_C
	_sun.light_energy = 1.2
	_sun.shadow_enabled = true
	_sun.shadow_opacity = 0.45
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 45.0
	# The visible sun is painted by the sky shader; this light stays out of it so the
	# sky's radiance map is never re-rendered.
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_sun)


func _build_clouds() -> void:
	# Long, thin evening clouds, golden underneath and lavender on top, brightest
	# near the sun. One MultiMesh of quads turned toward the court.
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _sunset_cloud_texture()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var sun := _sun_sky_dir()
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var n := 12
	for i in n:
		var az := deg_to_rad(lerpf(-80.0, 80.0, i / float(n - 1)) + rng.randf_range(-6.0, 6.0))
		var el := deg_to_rad(rng.randf_range(6.0, 15.0) if absf(az) < 0.5 else rng.randf_range(4.0, 12.0))
		var dist := rng.randf_range(440.0, 600.0)
		var dir := Vector3(sin(az), 0.0, -cos(az))
		var p := dir * dist
		p.y = 8.0 + dist * tan(el)
		var w := rng.randf_range(120.0, 230.0)
		var flip := -1.0 if rng.randf() < 0.5 else 1.0
		var b := Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3(w * flip, w * rng.randf_range(0.16, 0.26), 1.0))
		var k := pow(maxf((dir + Vector3(0, tan(el), 0)).normalized().dot(sun), 0.0), 8.0)
		var col := Color(0.95, 0.78, 0.92).lerp(Color(1.0, 0.92, 0.75), k)
		transforms.append(Transform3D(b, p))
		colors.append(col)
		_cloud_pos.append(p)
		_cloud_basis.append(b)
	var mmi := _mm(q, mat, transforms, colors)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud_mm = mmi.multimesh


# --- Land and sea -----------------------------------------------------------------

## Height of the land. The club's terrace is flat; hills rise to the left and run out
## into the sea as a headland; mountains far to the left; a beach below the terrace wall.
func _height(x: float, z: float) -> float:
	var n := _hnoise.get_noise_2d(x, z)
	var h: float
	if z >= EDGE_Z:
		var foot := 42.0 + 6.0 * (1.0 + sin(z * 0.035)) * clampf((absf(z + 25.0) - 25.0) / 15.0, 0.0, 1.0)
		var hl := clampf((-x - foot) * 0.42, 0.0, 44.0)
		var hr := clampf((x - 75.0) * 0.2, 0.0, 18.0)
		var bump := hl + hr
		h = PLATEAU_Y + bump + n * 7.0 * clampf(bump / 10.0, 0.0, 1.0)
	else:
		h = SEA_Y + 0.9 - (EDGE_Z - WALL_T - z) * 0.1  # sand sloping into the water
	# The headland.
	var p := Vector2(x, z)
	var ab := HEAD_B - HEAD_A
	var t := clampf((p - HEAD_A).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var d := p.distance_to(HEAD_A + ab * t)
	var w := lerpf(42.0, 24.0, t)
	var l := w - d + n * 7.0
	if l > 0.0:
		var top := (lerpf(22.0, 46.0, t / 0.35) if t < 0.35 else lerpf(46.0, 16.0, (t - 0.35) / 0.65)) * (1.0 + n * 0.3)
		var hh := SEA_Y + smoothstep(0.0, 9.0, l) * (PLATEAU_Y - SEA_Y + 1.5) + smoothstep(5.0, w * 0.95, l) * top
		h = maxf(h, hh)
	# Mountains far to the left, behind the headland.
	var s := clampf((-x - 135.0) / 170.0, 0.0, 1.0)
	if s > 0.0:
		h = maxf(h, SEA_Y - 6.0 + s * (100.0 + n * 30.0))
	return h


func _axis(lo: float, hi: float, dense: Vector2, mid: Vector2, extra: Array) -> PackedFloat32Array:
	var vals: Array[float] = []
	var v := lo
	while v < hi:
		var near := false
		for e in extra:
			if absf(v - float(e)) < 0.9:
				near = true
		if not near:
			vals.append(v)
		var step := 26.0
		if v >= mid.x and v < mid.y:
			step = 7.0
		if v >= dense.x and v < dense.y:
			step = 3.0
		v += step
	vals.append(hi)
	for e in extra:
		vals.append(float(e))
	vals.sort()
	return PackedFloat32Array(vals)


func _build_terrain() -> void:
	var xs := _axis(-900.0, 700.0, Vector2(-70.0, 70.0), Vector2(-240.0, 190.0), [])
	var zs := _axis(-950.0, 320.0, Vector2(-75.0, 60.0), Vector2(-450.0, 140.0), [EDGE_Z, EDGE_Z - WALL_T])
	var nx := xs.size()
	var nz := zs.size()
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = _height(xs[i], zs[j])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	var detail := FastNoiseLite.new()
	detail.seed = 5
	detail.frequency = 0.03
	for j in nz:
		for i in nx:
			var x := xs[i]
			var z := zs[j]
			var h := hs[j * nx + i]
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, nx - 1)
			var j0 := maxi(j - 1, 0)
			var j1 := mini(j + 1, nz - 1)
			var dx := (hs[j * nx + i1] - hs[j * nx + i0]) / maxf(xs[i1] - xs[i0], 0.01)
			var dz := (hs[j1 * nx + i] - hs[j0 * nx + i]) / maxf(zs[j1] - zs[j0], 0.01)
			var nrm := Vector3(-dx, 1.0, -dz).normalized()
			verts[j * nx + i] = Vector3(x, h, z)
			normals[j * nx + i] = nrm
			var dn := detail.get_noise_2d(x, z)
			var c: Color
			if h < SEA_Y + 1.6:
				c = Color(0.88, 0.76, 0.58)  # sand
			elif z >= EDGE_Z and h < PLATEAU_Y + 0.3:
				# Watered club lawn, drier away from the club.
				var dry := clampf((maxf(absf(x) - 45.0, 0.0) + maxf(z - 70.0, 0.0)) / 120.0, 0.0, 1.0)
				c = Color(0.4, 0.55, 0.25).lerp(Color(0.58, 0.56, 0.33), dry * 0.7)
			else:
				# Mediterranean scrub: dry ochre grass and darker pine and lentisk.
				c = Color(0.42, 0.44, 0.26).lerp(Color(0.19, 0.28, 0.15), clampf(dn * 2.2 + 0.6, 0.0, 1.0))
				if nrm.y < 0.82:
					c = c.lerp(Color(0.58, 0.5, 0.42), clampf((0.82 - nrm.y) * 5.0, 0.0, 1.0))  # rock
			colors[j * nx + i] = c
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			if maxf(maxf(hs[a], hs[b]), maxf(hs[c], hs[d])) < SEA_Y - 1.0:
				continue  # under the sea
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = _grey_noise_texture()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / 24.0
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_sea() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.05
	var ripples := NoiseTexture2D.new()
	ripples.width = 256
	ripples.height = 256
	ripples.seamless = true
	ripples.as_normal_map = true
	ripples.bump_strength = 4.0
	ripples.noise = noise
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, specular_disabled;
uniform vec4 deep : source_color;
uniform vec4 shallow : source_color;
uniform vec4 sky_low : source_color;
uniform vec4 sky_high : source_color;
uniform vec4 glint : source_color;
uniform vec3 sun_dir;
uniform sampler2D ripples : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 v = normalize(wpos - cam);
	float dist = length(wpos.xz - cam.xz);
	vec2 uv = wpos.xz;
	vec2 n1 = texture(ripples, uv * 0.035 + vec2(TIME * 0.010, TIME * 0.004)).xy * 2.0 - 1.0;
	vec2 n2 = texture(ripples, uv * 0.09 + vec2(-TIME * 0.013, TIME * 0.009)).xy * 2.0 - 1.0;
	vec2 slope = (n1 + n2) * mix(0.2, 0.09, clamp(dist / 500.0, 0.0, 1.0));
	vec3 n = normalize(vec3(slope.x, 1.0, slope.y));
	vec3 r = reflect(v, n);
	float fres = pow(1.0 - clamp(dot(-v, n), 0.0, 1.0), 3.0);
	vec3 refl = mix(sky_low.rgb, sky_high.rgb, clamp(r.y * 6.0, 0.0, 1.0));
	float near_shore = smoothstep(-80.0, -48.0, wpos.z);
	vec3 water = mix(deep.rgb, shallow.rgb, near_shore);
	vec3 col = mix(water, refl, clamp(0.1 + fres * 0.75, 0.0, 0.8));
	// The sun's path: a broad warm sheen and glitter where ripples catch the sun.
	float s = max(dot(r, sun_dir), 0.0);
	col += glint.rgb * (pow(s, 40.0) * 0.4 + pow(s, 8.0) * 0.08 + pow(s, 900.0) * 9.0);
	ALBEDO = col;
}
"""
	_sea_mat = ShaderMaterial.new()
	_sea_mat.shader = sh
	_sea_mat.set_shader_parameter("deep", Color(0.13, 0.2, 0.36))
	_sea_mat.set_shader_parameter("shallow", Color(0.2, 0.45, 0.52))
	_sea_mat.set_shader_parameter("sky_low", Color(0.95, 0.6, 0.46))
	_sea_mat.set_shader_parameter("sky_high", Color(0.45, 0.4, 0.6))
	_sea_mat.set_shader_parameter("glint", Color(1.0, 0.78, 0.46))
	_sea_mat.set_shader_parameter("sun_dir", _sun_sky_dir())
	_sea_mat.set_shader_parameter("ripples", ripples)
	var sea_len := 1700.0
	_ground(Vector2(3000.0, sea_len), Vector3(0, SEA_Y, EDGE_Z - sea_len * 0.5), _sea_mat)


func _build_seafront() -> void:
	# The terrace wall with a white balustrade, and the promenade along it.
	var x0 := -42.0
	var x1 := 72.0
	_box(Vector3(x1 - x0, PLATEAU_Y - SEA_Y + 0.75, WALL_T), Vector3((x0 + x1) * 0.5, (SEA_Y - 0.6 + PLATEAU_Y + 0.15) * 0.5, EDGE_Z - WALL_T * 0.5), _plain(Color(0.84, 0.76, 0.64)), false)
	var white := Color(0.96, 0.94, 0.9)
	var rail_y := PLATEAU_Y + 1.0
	_bx(Vector3(x1 - x0, 0.12, 0.42), Vector3((x0 + x1) * 0.5, rail_y, EDGE_Z - 0.25), white, 0.0, false)
	_bx(Vector3(x1 - x0, 0.16, 0.5), Vector3((x0 + x1) * 0.5, PLATEAU_Y + 0.08, EDGE_Z - 0.25), white, 0.0, false)
	var x := x0 + 0.3
	while x < x1:
		_bx(Vector3(0.13, 0.78, 0.13), Vector3(x, PLATEAU_Y + 0.55, EDGE_Z - 0.25), white, 0.0, false)
		x += 0.45
	x = x0 + 1.0
	while x < x1:
		_bx(Vector3(0.4, 1.05, 0.5), Vector3(x, PLATEAU_Y + 0.5, EDGE_Z - 0.25), white, 0.0, false)  # pillar
		# Iron lantern on every other pillar.
		_bx(Vector3(0.07, 2.4, 0.07), Vector3(x, rail_y + 1.25, EDGE_Z - 0.25), Color(0.12, 0.12, 0.13), 0.0, false)
		_bx(Vector3(0.32, 0.42, 0.32), Vector3(x, rail_y + 2.6, EDGE_Z - 0.25), Color(0.12, 0.12, 0.13), 0.0, false)
		_glow_t.append(Transform3D(Basis.from_scale(Vector3(0.15, 0.19, 0.15)), Vector3(x, rail_y + 2.58, EDGE_Z - 0.25)))
		x += 6.0
	# Promenade paving.
	_stone_t.append(_slab(Vector3(x1 - x0, 0.1, 5.0), Vector3((x0 + x1) * 0.5, PLATEAU_Y + 0.0, EDGE_Z + 2.5)))
	# On the beach below: a few parasols and loungers (only seen in wide shots).
	var beach: Array[Transform3D] = []
	var beach_c: Array[Color] = []
	var cols := [Color(0.95, 0.93, 0.88), Color(0.2, 0.36, 0.6), Color(0.95, 0.75, 0.3), Color(0.85, 0.35, 0.3)]
	for k in 9:
		var bx := -20.0 + k * 9.0 + rng.randf_range(-2.0, 2.0)
		var bz := EDGE_Z - 4.0 - rng.randf_range(0.0, 3.0)
		var by := _height(bx, bz)
		beach.append(Transform3D(Basis.from_scale(Vector3(1.3, 0.5, 1.3)), Vector3(bx, by + 2.1, bz)))
		beach_c.append(cols[k % cols.size()])
		_far_t.append(Transform3D(Basis.from_scale(Vector3(0.05, 2.1, 0.05)), Vector3(bx, by + 1.05, bz)))
		_far_c.append(Color(0.9, 0.9, 0.88))
		for s in [-1.0, 1.0]:
			_far_t.append(Transform3D(Basis.from_scale(Vector3(0.6, 0.12, 1.8)), Vector3(bx + s * 0.9, by + 0.25, bz + 1.4)))
			_far_c.append(Color(0.95, 0.95, 0.92))
	var cone := _cone_mesh()
	var bm := _mm(cone, _vc, beach, beach_c)
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_low_quality_hidden.append(bm)


func _build_grounds() -> void:
	# The court's apron stands on a low terracotta curb.
	var apron := Vector3(Court.DOUBLES_HALF_WIDTH * 2.0 + 13.0, 0.0, Court.HALF_LENGTH * 2.0 + 18.0)
	_box(Vector3(apron.x, -LAWN_Y - 0.05, apron.z), Vector3(0, (LAWN_Y - 0.05) * 0.5, 0), _plain(Color(0.5, 0.29, 0.2)), false)
	# Pale stone terrace around the court, a path to the promenade, the entrance path.
	_stone_t.append(_slab(Vector3(33.0, 0.1, 53.0), Vector3(0, PLATEAU_Y, 0.5)))
	_stone_t.append(_slab(Vector3(3.0, 0.1, EDGE_Z * -1.0 - 27.0), Vector3(4.0, PLATEAU_Y, (EDGE_Z + 5.0 - 27.0) * 0.5)))
	_stone_t.append(_slab(Vector3(4.0, 0.1, 36.0), Vector3(0, PLATEAU_Y, 45.0)))
	# Terracotta-tiled terrace in front of (and under) the club house.
	_tile_t.append(_slab(Vector3(18.0, 0.12, 38.0), Vector3(-25.5, PLATEAU_Y + 0.01, -21.0)))
	# Low hedges framing the gardens.
	var hedge := Color(0.26, 0.4, 0.2)
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.9, 0.8, 14.0), Vector3(s * 3.0 + 4.0, PLATEAU_Y + 0.4, -34.0), hedge, 0.0, false)
	_bx(Vector3(12.0, 0.8, 0.9), Vector3(-9.0, PLATEAU_Y + 0.4, -27.0), hedge, 0.0, false)
	_bx(Vector3(10.0, 0.8, 0.9), Vector3(13.0, PLATEAU_Y + 0.4, -27.0), hedge, 0.0, false)
	# White garden wall with a gate behind the entrance, draped in bougainvillea.
	for s in [-1.0, 1.0]:
		_wall_far_t.append(Transform3D(Basis.from_scale(Vector3(40.0, 1.8, 0.4)), Vector3(s * 22.0, PLATEAU_Y + 0.9, 62.0)))
		_wall_far_c.append(WHITES[0])
		_wall_far_t.append(Transform3D(Basis.from_scale(Vector3(0.7, 2.6, 0.7)), Vector3(s * 2.4, PLATEAU_Y + 1.3, 62.0)))
		_wall_far_c.append(WHITES[1])
		for k in 7:
			_bloom(Vector3(s * (5.0 + k * 5.0 + rng.randf_range(-1.0, 1.0)), PLATEAU_Y + 1.6, 61.6), 1.4)


func _build_clubhouse() -> void:
	# Two storeys behind an arcade facing the court, an upper terrace over the arcade,
	# a terracotta roof and a little tower.
	var z0 := -36.0
	var z1 := -6.0
	var back := -31.0
	var loggia := CLUB_X - 4.0
	var white := WHITES[0]
	_wall_near_t.append(Transform3D(Basis.from_scale(Vector3(loggia - back, 8.4 - PLATEAU_Y, z1 - z0)), Vector3((back + loggia) * 0.5, (8.4 + PLATEAU_Y) * 0.5, (z0 + z1) * 0.5)))
	_wall_near_c.append(white)
	# Arcade.
	var arcade := MeshInstance3D.new()
	arcade.mesh = _arcade_mesh(CLUB_X, z0, 7, (z1 - z0) / 7.0, 0.75, 2.5, 4.7 - PLATEAU_Y, 0.45, white)
	arcade.position.y = PLATEAU_Y
	arcade.material_override = _vc
	add_child(arcade)
	# Slab over the arcade with a balustrade: the upper terrace.
	_wall_near_t.append(Transform3D(Basis.from_scale(Vector3(CLUB_X - loggia + 0.3, 0.4, z1 - z0 + 0.3)), Vector3((CLUB_X + loggia) * 0.5 + 0.1, 4.9, (z0 + z1) * 0.5)))
	_wall_near_c.append(white)
	_wall_near_t.append(Transform3D(Basis.from_scale(Vector3(0.3, 0.95, z1 - z0 + 0.3)), Vector3(CLUB_X + 0.1, 5.55, (z0 + z1) * 0.5)))
	_wall_near_c.append(white)
	for s in [z0, z1]:
		_wall_near_t.append(Transform3D(Basis.from_scale(Vector3(CLUB_X - loggia, 0.95, 0.3)), Vector3((CLUB_X + loggia) * 0.5, 5.55, s)))
		_wall_near_c.append(white)
	# Roof and tower.
	var w := loggia - back
	_gable_near_t.append(Transform3D(Basis.from_scale(Vector3(w + 0.8, 2.3, z1 - z0 + 0.8)), Vector3((back + loggia) * 0.5, 8.4 + 1.15, (z0 + z1) * 0.5)))
	_wall_near_t.append(Transform3D(Basis.from_scale(Vector3(4.2, 4.2, 4.2)), Vector3(-25.0, 10.2, -31.5)))
	_wall_near_c.append(WHITES[3])
	_hip_near_t.append(Transform3D(Basis.from_scale(Vector3(5.0, 2.0, 5.0)) * Basis(Vector3.UP, PI * 0.25), Vector3(-25.0, 13.3, -31.5)))
	# Floor of the arcade: terracotta tiles (part of the terrace slab), roof tiles' shade.
	# The club's name over the arcade.
	var club_sign := Label3D.new()
	club_sign.text = "CLUB DE TENIS"
	club_sign.font_size = 72
	club_sign.pixel_size = 0.011
	club_sign.outline_size = 0
	club_sign.modulate = Color(0.55, 0.24, 0.14)
	club_sign.shaded = true
	club_sign.double_sided = false
	club_sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	club_sign.rotation.y = PI * 0.5
	club_sign.position = Vector3(loggia + 0.03, 7.0, (z0 + z1) * 0.5)
	add_child(club_sign)
	# Bougainvillea climbing the arcade and spilling over the terrace.
	for k in 8:
		var z := z0 + k * (z1 - z0) / 7.0
		_bloom(Vector3(CLUB_X + 0.3, 3.4 + rng.randf_range(-0.5, 0.6), z + rng.randf_range(-0.4, 0.4)), 1.0)
		if k % 2 == 0:
			_bloom(Vector3(CLUB_X + 0.25, 5.9, z + 1.5), 1.3)
	for z in [z0 - 0.6, z1 + 0.6]:
		_bloom(Vector3(CLUB_X - 1.5, 2.0, z), 1.6)
	# Pots with geraniums along the arcade, café tables under parasols in front.
	for k in 8:
		var z := z0 + k * (z1 - z0) / 7.0
		_pot(Vector3(CLUB_X + 0.5, PLATEAU_Y + 0.12, z), 0.55, 1)
	for k in 4:
		var z := -32.0 + k * 7.0
		var x := CLUB_X + 3.6
		_parasol_t.append(Transform3D(Basis.from_scale(Vector3(1.6, 0.6, 1.6)), Vector3(x, PLATEAU_Y + 2.45, z)))
		_parasol_c.append(Color(0.96, 0.93, 0.86) if k % 2 == 0 else Color(0.82, 0.45, 0.32))
		_bx(Vector3(0.06, 2.4, 0.06), Vector3(x, PLATEAU_Y + 1.2, z), Color(0.85, 0.82, 0.76))
		_bx(Vector3(0.9, 0.05, 0.9), Vector3(x, PLATEAU_Y + 0.75, z), Color(0.95, 0.95, 0.93))
		_bx(Vector3(0.08, 0.75, 0.08), Vector3(x, PLATEAU_Y + 0.37, z), Color(0.3, 0.3, 0.32))
		for s in [-1.0, 1.0]:
			var cx: float = x + s * 0.85
			_bx(Vector3(0.45, 0.05, 0.45), Vector3(cx, PLATEAU_Y + 0.47, z), Color(0.55, 0.38, 0.24))
			_bx(Vector3(0.05, 0.5, 0.45), Vector3(cx + s * 0.22, PLATEAU_Y + 0.75, z), Color(0.55, 0.38, 0.24))
			_bx(Vector3(0.4, 0.45, 0.4), Vector3(cx, PLATEAU_Y + 0.22, z), Color(0.25, 0.25, 0.27))


func _build_pool() -> void:
	# The club pool beyond the right fence: water, a stone rim, loungers and parasols.
	var c := Vector3(27.0, PLATEAU_Y, -34.0)
	var size := Vector2(12.0, 6.0)
	_stone_t.append(_slab(Vector3(size.x + 5.0, 0.1, 1.2), c + Vector3(0, 0.02, -size.y * 0.5 - 0.6)))
	_stone_t.append(_slab(Vector3(size.x + 5.0, 0.1, 4.0), c + Vector3(0, 0.02, size.y * 0.5 + 2.0)))
	_stone_t.append(_slab(Vector3(2.5, 0.1, size.y), c + Vector3(-size.x * 0.5 - 1.25, 0.02, 0)))
	_stone_t.append(_slab(Vector3(2.5, 0.1, size.y), c + Vector3(size.x * 0.5 + 1.25, 0.02, 0)))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var ripples := NoiseTexture2D.new()
	ripples.width = 128
	ripples.height = 128
	ripples.seamless = true
	ripples.as_normal_map = true
	ripples.bump_strength = 3.0
	ripples.noise = noise
	_pool_mat = StandardMaterial3D.new()
	_pool_mat.albedo_color = Color(0.3, 0.72, 0.8)
	_pool_mat.metallic = 0.3
	_pool_mat.roughness = 0.08
	_pool_mat.normal_enabled = true
	_pool_mat.normal_texture = ripples
	_pool_mat.uv1_scale = Vector3(2.0, 3.0, 1.0)
	_ground(size, c + Vector3(0, 0.03, 0), _pool_mat)
	for k in 5:
		var x := c.x - 5.0 + k * 2.5
		var z := c.z + size.y * 0.5 + 2.0
		_bx(Vector3(0.7, 0.3, 1.9), Vector3(x, PLATEAU_Y + 0.22, z), Color(0.97, 0.97, 0.95), 0.0, false)
		_bx(Vector3(0.7, 0.5, 0.08), Vector3(x, PLATEAU_Y + 0.5, z + 0.9), Color(0.97, 0.97, 0.95), 0.0, false)
		if k % 2 == 1:
			_parasol_t.append(Transform3D(Basis.from_scale(Vector3(1.5, 0.55, 1.5)), Vector3(x + 1.25, PLATEAU_Y + 2.4, z)))
			_parasol_c.append(Color(0.96, 0.93, 0.86))
			_bx(Vector3(0.05, 2.4, 0.05), Vector3(x + 1.25, PLATEAU_Y + 1.2, z), Color(0.85, 0.82, 0.76), 0.0, false)


# --- Court ------------------------------------------------------------------------

func _build_fence() -> void:
	var height := 3.6
	_fence_mat = StandardMaterial3D.new()
	_fence_mat.albedo_texture = _fence_tex
	_fence_mat.albedo_color = Color(0.16, 0.26, 0.2)
	_fence_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_fence_mat.alpha_scissor_threshold = 0.5
	_fence_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fence_mat.uv1_triplanar = true
	_fence_mat.uv1_world_triplanar = true
	_fence_mat.uv1_scale = Vector3(1.6, 1.6, 1.6)
	var screen := Color(0.12, 0.3, 0.21)  # green windscreens, as at every clay club
	var sh := 2.3
	_fence_t.append(Transform3D(Basis.from_scale(Vector3(HX * 2.0, height, 0.02)), Vector3(0, height * 0.5, -HZ)))
	_bx(Vector3(HX * 2.0, sh, 0.04), Vector3(0, sh * 0.5, -HZ + 0.03), screen)
	for s in [-1.0, 1.0]:
		_fence_t.append(Transform3D(Basis.from_scale(Vector3(0.02, height, HZ * 2.0)), Vector3(s * HX, height * 0.5, 0)))
		_bx(Vector3(0.04, sh, HZ * 2.0), Vector3(s * (HX - 0.03), sh * 0.5, 0), screen)
	var post := Color(0.13, 0.2, 0.16)
	var x := -HX
	while x <= HX + 0.01:
		_bx(Vector3(0.08, height + 0.1, 0.08), Vector3(x, (height + 0.1) * 0.5, -HZ), post)
		x += 3.0
	var z := -HZ
	while z <= HZ + 0.01:
		for s in [-1.0, 1.0]:
			_bx(Vector3(0.08, height + 0.1, 0.08), Vector3(s * HX, (height + 0.1) * 0.5, z), post)
		z += 3.0
	_bx(Vector3(HX * 2.0, 0.07, 0.07), Vector3(0, height, -HZ), post)
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.07, 0.07, HZ * 2.0), Vector3(s * HX, height, 0), post)
	# The club's name on the far windscreen.
	var label := Label3D.new()
	label.text = "CLUB DE TENIS  ·  COSTA DEL SOL"
	label.font_size = 64
	label.pixel_size = 0.0085
	label.outline_size = 0
	label.modulate = Color(0.95, 0.93, 0.86, 0.9)
	label.shaded = false
	label.double_sided = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = Vector3(0, 1.45, -HZ + 0.06)
	add_child(label)
	# Bougainvillea spilling over the far corners of the fence.
	for sx in [-1.0, 1.0]:
		for k in 5:
			_bloom(Vector3(sx * (HX - 0.5 - k * 0.8), height - 0.6 + rng.randf_range(-0.4, 0.3) - k * 0.1, -HZ - 0.25), 0.8, Vector3(1.0, 1.0, 0.4))
			_bloom(Vector3(sx * (HX + 0.25), height - 0.7 + rng.randf_range(-0.5, 0.3) - k * 0.1, -HZ + 0.5 + k * 0.8), 0.8, Vector3(0.4, 1.0, 1.0))


func _build_neighbour_court() -> void:
	# A second clay court beyond the right fence, swept and ready for the next match.
	var cx := NEIGH_X
	var apron := Vector3(Court.DOUBLES_HALF_WIDTH * 2.0 + 13.0, 0.0, Court.HALF_LENGTH * 2.0 + 18.0)
	_box(Vector3(apron.x, -LAWN_Y - 0.03, apron.z), Vector3(cx, (LAWN_Y - 0.03) * 0.5, 0), _noise_mat(Color(0.56, 0.31, 0.21), 0.05, 8.0), false)
	_box(Vector3(Court.DOUBLES_HALF_WIDTH * 2.0 + 7.0, 0.02, Court.HALF_LENGTH * 2.0 + 12.0), Vector3(cx, -0.03, 0), _noise_mat(Color(0.75, 0.41, 0.24), 0.04, 5.0), false)
	var white := Color(0.95, 0.94, 0.9)
	var y := -0.015
	for s in [-1.0, 1.0]:
		_bx(Vector3(Court.DOUBLES_HALF_WIDTH * 2.0, 0.01, 0.12), Vector3(cx, y, s * Court.HALF_LENGTH), white, 0.0, false)
		_bx(Vector3(0.08, 0.01, Court.HALF_LENGTH * 2.0), Vector3(cx + s * Court.DOUBLES_HALF_WIDTH, y, 0), white, 0.0, false)
		_bx(Vector3(0.08, 0.01, Court.HALF_LENGTH * 2.0), Vector3(cx + s * Court.SINGLES_HALF_WIDTH, y, 0), white, 0.0, false)
		_bx(Vector3(Court.SINGLES_HALF_WIDTH * 2.0, 0.01, 0.08), Vector3(cx, y, s * Court.SERVICE_LINE), white, 0.0, false)
	_bx(Vector3(0.08, 0.01, Court.SERVICE_LINE * 2.0), Vector3(cx, y, 0), white, 0.0, false)
	_bx(Vector3(Court.NET_HALF_WIDTH * 2.0, 0.85, 0.03), Vector3(cx, 0.45, 0), Color(0.1, 0.1, 0.12), 0.0, false)
	_bx(Vector3(Court.NET_HALF_WIDTH * 2.0, 0.07, 0.05), Vector3(cx, 0.9, 0), white, 0.0, false)
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.08, 1.07, 0.08), Vector3(cx + s * (Court.NET_HALF_WIDTH + 0.05), 0.53, 0), Color(0.15, 0.15, 0.17), 0.0, false)
	# Its fence and windscreens.
	var height := 3.6
	var screen := Color(0.12, 0.3, 0.21)
	var post := Color(0.13, 0.2, 0.16)
	for s in [-1.0, 1.0]:
		_fence_t.append(Transform3D(Basis.from_scale(Vector3(HX * 2.0, height, 0.02)), Vector3(cx, height * 0.5, s * HZ)))
		_fence_t.append(Transform3D(Basis.from_scale(Vector3(0.02, height, HZ * 2.0)), Vector3(cx + s * HX, height * 0.5, 0)))
		_bx(Vector3(0.04, 2.3, HZ * 2.0), Vector3(cx + s * (HX - 0.03), 1.15, 0), screen, 0.0, false)
		_bx(Vector3(HX * 2.0, 0.07, 0.07), Vector3(cx, height, s * HZ), post, 0.0, false)
		_bx(Vector3(0.07, 0.07, HZ * 2.0), Vector3(cx + s * HX, height, 0), post, 0.0, false)
	_bx(Vector3(HX * 2.0, 2.3, 0.04), Vector3(cx, 1.15, -HZ + 0.03), screen, 0.0, false)
	var z := -HZ
	while z <= HZ + 0.01:
		for s in [-1.0, 1.0]:
			_bx(Vector3(0.08, height, 0.08), Vector3(cx + s * HX, height * 0.5, z), post, 0.0, false)
		z += 3.0
	# Its benches and a little umpire's chair.
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.45, 0.45, 1.6), Vector3(cx - Court.NET_HALF_WIDTH - 1.4, 0.22, s * 1.5), white, 0.0, false)
	_bx(Vector3(0.7, 1.9, 0.7), Vector3(cx + Court.NET_HALF_WIDTH + 1.3, 0.95, 0), Color(0.6, 0.4, 0.25), 0.0, false)


func _build_court_furniture() -> void:
	var wood := Color(0.6, 0.4, 0.25)
	var white := Color(0.96, 0.95, 0.92)
	# Umpire's chair by the net post: varnished wood, a white seat, a small sunshade.
	var ux := Court.NET_HALF_WIDTH + 1.35
	for lx in [-0.4, 0.4]:
		for lz in [-0.4, 0.4]:
			_bx(Vector3(0.08, 2.0, 0.08), Vector3(ux + lx, 1.0, lz), wood)
	for h in [0.7, 1.4]:
		for lz in [-0.4, 0.4]:
			_bx(Vector3(0.85, 0.06, 0.06), Vector3(ux, h, lz), wood)
	_bx(Vector3(0.95, 0.08, 0.95), Vector3(ux, 2.0, 0), wood)
	_bx(Vector3(0.62, 0.1, 0.6), Vector3(ux - 0.02, 2.12, 0), white)
	_bx(Vector3(0.08, 0.75, 0.6), Vector3(ux + 0.3, 2.5, 0), white)
	for side in [-0.32, 0.32]:
		_bx(Vector3(0.55, 0.06, 0.06), Vector3(ux - 0.02, 2.4, side), wood)
	_bx(Vector3(0.5, 0.05, 0.6), Vector3(ux - 0.65, 1.15, 0), wood)
	for k in 5:
		_bx(Vector3(0.06, 0.04, 0.55), Vector3(ux + 0.55, 0.3 + k * 0.38, 0), wood)
	for lz in [-0.27, 0.27]:
		_bx(Vector3(0.05, 1.9, 0.05), Vector3(ux + 0.55, 0.95, lz), wood)
	_bx(Vector3(0.04, 1.2, 0.04), Vector3(ux + 0.25, 3.1, 0), white)
	_parasol_t.append(Transform3D(Basis.from_scale(Vector3(0.95, 0.35, 0.95)), Vector3(ux + 0.2, 3.75, 0)))
	_parasol_c.append(Color(0.14, 0.36, 0.26))

	# Players' benches on the other side, with towels, bags, bottles and a cooler.
	var bx := -(Court.NET_HALF_WIDTH + 1.4)
	var bottles: Array[Transform3D] = []
	var bottle_colors: Array[Color] = []
	for bz in [-1.5, 1.5]:
		var f := Transform3D(Basis.IDENTITY, Vector3(bx, 0.0, bz))
		_bx(Vector3(0.45, 0.06, 1.7), f * Vector3(0, 0.45, 0), white)
		_bx(Vector3(0.05, 0.42, 1.7), f * Vector3(-0.22, 0.72, 0), white)
		for lz in [-0.75, 0.75]:
			_bx(Vector3(0.42, 0.45, 0.05), f * Vector3(0, 0.22, lz), wood)
		var towel := Color(0.96, 0.55, 0.25) if bz > 0.0 else Color(0.97, 0.96, 0.92)
		_bx(Vector3(0.1, 0.55, 0.45), f * Vector3(-0.26, 0.6, 0.3), towel)
		_bx(Vector3(0.4, 0.04, 0.5), f * Vector3(0.02, 0.5, -0.4), towel.darkened(0.08))
		_bx(Vector3(0.32, 0.32, 0.85), f * Vector3(0.45, 0.16, 0.2), Color(0.14, 0.17, 0.24) if bz > 0.0 else Color(0.62, 0.16, 0.16))
		for k in 2:
			bottles.append(Transform3D(Basis.from_scale(Vector3(0.035, 0.12, 0.035)), f * Vector3(0.05, 0.6, -0.65 + k * 0.12)))
			bottle_colors.append(Color(0.45, 0.78, 0.98) if k == 0 else Color(0.98, 0.85, 0.3))
	_bx(Vector3(0.45, 0.5, 0.45), Vector3(bx + 0.05, 0.25, 0.0), Color(0.9, 0.42, 0.22))  # cooler
	_bx(Vector3(0.47, 0.06, 0.47), Vector3(bx + 0.05, 0.53, 0.0), white)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 2.0
	cyl.radial_segments = 8
	_mm(cyl, _vc, bottles, bottle_colors).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Ball basket in the near corner, a few stray balls by the far windscreen.
	var basket := Vector3(-(Court.DOUBLES_HALF_WIDTH + 1.4), 0.0, Court.HALF_LENGTH + 1.2)
	_bx(Vector3(0.45, 0.05, 0.45), basket + Vector3(0, 0.7, 0), Color(0.2, 0.22, 0.24))
	for lx in [-0.2, 0.2]:
		_bx(Vector3(0.03, 0.7, 0.03), basket + Vector3(lx, 0.35, 0), Color(0.2, 0.22, 0.24))
	var balls: Array[Transform3D] = []
	for k in 22:
		balls.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.034), basket + Vector3(rng.randf_range(-0.17, 0.17), 0.76 + rng.randf_range(0.0, 0.14), rng.randf_range(-0.17, 0.17))))
	for k in 4:
		balls.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.034), Vector3(rng.randf_range(-HX + 1.0, HX - 1.0), 0.034, rng.randf_range(-HZ + 0.4, -HZ + 1.6))))
	_mm(_sphere, _plain(Color(0.86, 0.95, 0.2)), balls).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The club's name painted behind each baseline.
	for end in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = "CLUB DE TENIS · COSTA DEL SOL"
		label.font_size = 96
		label.pixel_size = 0.004
		label.outline_size = 0
		label.modulate = Color(1, 0.97, 0.92, 0.6)
		label.shaded = false
		label.double_sided = false
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.rotation = Vector3(-PI * 0.5, 0.0 if end > 0.0 else PI, 0.0)
		label.position = Vector3(0, 0.04, end * (Court.HALF_LENGTH + 2.3))
		add_child(label)
	# Clay-court tools by the right fence: a drag brush and a line sweeper.
	_bx(Vector3(0.05, 1.7, 0.05), Vector3(HX - 0.3, 0.85, 10.0), Color(0.6, 0.45, 0.3))
	_bx(Vector3(0.12, 0.6, 1.8), Vector3(HX - 0.12, 0.3, 10.0), Color(0.3, 0.28, 0.24))
	_bx(Vector3(0.05, 1.3, 0.05), Vector3(HX - 0.35, 0.65, 12.5), Color(0.6, 0.45, 0.3))
	_bx(Vector3(0.25, 0.12, 0.6), Vector3(HX - 0.3, 0.06, 12.5), Color(0.75, 0.2, 0.15))


func _build_stands() -> void:
	# Small stands outside the right fence: white frames, wooden seats.
	var x0 := HX + 1.2
	var length := 13.0
	var zc := 0.0
	for row in 4:
		var y := 0.42 + row * 0.45
		var x := x0 + row * 0.75
		_bx(Vector3(0.5, 0.06, length), Vector3(x, y, zc), Color(0.66, 0.46, 0.3))      # seat
		_bx(Vector3(0.06, 0.42, length), Vector3(x - 0.3, y - 0.2, zc), Color(0.95, 0.95, 0.92))  # riser
		_bx(Vector3(0.75, 0.04, length), Vector3(x + 0.1, y - 0.41, zc), Color(0.9, 0.9, 0.88))   # step
	for z in [-length * 0.5, -length * 0.17, length * 0.17, length * 0.5]:
		var t := Transform3D(Basis.from_scale(Vector3(3.4, 0.09, 0.09)), Vector3(x0 + 1.1, 0.95, z)).rotated_local(Vector3.FORWARD, -0.55)
		_near_t.append(t)
		_near_c.append(Color(0.95, 0.95, 0.92))
		_bx(Vector3(0.09, 2.25, 0.09), Vector3(x0 + 2.55, 1.12, z), Color(0.95, 0.95, 0.92))
	_bx(Vector3(0.06, 1.0, length), Vector3(x0 + 2.75, 2.25 + 0.3, zc), Color(0.95, 0.95, 0.92))  # back rail


func _build_string_lights() -> void:
	# Festoon lights on wooden poles: across the garden behind the far fence and along
	# the club house terrace.
	var pole := Color(0.4, 0.3, 0.22)
	var lines := []
	var far_row: Array[Vector3] = []
	var x := -24.0
	while x <= 24.01:
		far_row.append(Vector3(x, 4.6, -23.5))
		x += 8.0
	lines.append(far_row)
	var club_row: Array[Vector3] = []
	var z := -36.0
	while z <= -5.99:
		club_row.append(Vector3(CLUB_X + 6.6, 4.3, z))
		z += 7.5
	lines.append(club_row)
	for row in lines:
		var pts: Array[Vector3] = row
		for p in pts:
			_bx(Vector3(0.12, p.y + 0.3, 0.12), Vector3(p.x, PLATEAU_Y + (p.y + 0.3) * 0.5, p.z), pole, 0.0, false)
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var n := 9
			var prev := a
			for m in range(1, n + 1):
				var t := m / float(n)
				var q := a.lerp(b, t) + Vector3(0, -0.85 * 4.0 * t * (1.0 - t), 0)
				_wire_t.append(_segment(prev, q, 0.018))
				if m < n:
					_glow_t.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.1), q + Vector3(0, -0.12, 0)))
				prev = q


# --- Gardens, villas, hills -------------------------------------------------------

func _build_gardens() -> void:
	# Palms: [0] Canary date palm, [1] tall Washingtonia, [2] slender curved date palm.
	# Only palms whose shadows fall away from the court cast them.
	for z in [-2.0, 9.0, 19.0]:
		_palm(0, Vector3(-13.5 + rng.randf_range(-0.5, 0.5), PLATEAU_Y, z), true)
	for k in 4:
		_palm(1 if k % 2 == 0 else 2, Vector3(18.0 + rng.randf_range(-1.0, 1.0), PLATEAU_Y, -10.0 + k * 11.0), false)
	for x in [-38.0, -27.0, -16.0, 14.0, 26.0, 38.0, 50.0, 62.0]:
		_palm(1 if absf(x) > 20.0 else 0, Vector3(x + rng.randf_range(-1.0, 1.0), PLATEAU_Y, EDGE_Z + 3.2), false)
	for z in [30.0, 39.0, 48.0, 57.0]:
		for s in [-1.0, 1.0]:
			_palm(2 if s > 0.0 else 0, Vector3(s * 9.0, PLATEAU_Y, z), false)
	for z in [-39.0, -3.0]:
		_palm(1, Vector3(CLUB_X + 1.0, PLATEAU_Y, z), true)
	# Cypresses behind the club house and by the entrance.
	for k in 7:
		_cypress(Vector3(-33.5 + rng.randf_range(-0.6, 0.6), PLATEAU_Y, -38.0 + k * 5.5), 1.0)
	for s in [-1.0, 1.0]:
		_cypress(Vector3(s * 4.2, PLATEAU_Y, 61.0), 0.9)
	# Olive trees in the lawns.
	for p in [Vector3(52.0, 0, -6.0), Vector3(56.0, 0, 8.0), Vector3(50.0, 0, 22.0), Vector3(-26.0, 0, 8.0), Vector3(-30.0, 0, 18.0), Vector3(13.0, 0, -35.0), Vector3(-22.0, 0, 30.0), Vector3(24.0, 0, 34.0), Vector3(42.0, 0, -31.0), Vector3(60.0, 0, -24.0), Vector3(36.0, 0, 30.0)]:
		_olive(Vector3(p.x, PLATEAU_Y, p.z))
	# Shrubs and lavender along the hedges, pots on the terrace corners.
	for k in 26:
		var p := Vector3(rng.randf_range(-40.0, 40.0), PLATEAU_Y, rng.randf_range(-42.0, 58.0))
		if absf(p.x) < 18.0 and p.z > -28.0 and p.z < 30.0:
			continue
		if p.x < -16.0 and p.z > -41.0 and p.z < -1.0:
			continue
		if p.x > 18.0 and p.x < 48.0 and p.z > -40.0 and p.z < 22.0:
			continue  # the other court and the pool
		var s := rng.randf_range(0.7, 1.3)
		_bush_t.append(Transform3D(Basis.from_scale(Vector3(1.2, 0.8, 1.1) * s), p + Vector3(0, 0.5 * s, 0)))
		_bush_c.append(SHRUBS[rng.randi() % SHRUBS.size()])
	for side in [-1.0, 1.0]:
		for k in 18:
			var p := Vector3(side * 3.0 + 4.0 + side * 0.85, PLATEAU_Y, -40.0 + k * 0.75)
			_bloom_t.append(Transform3D(Basis.from_scale(Vector3(0.4, 0.28, 0.42)), p + Vector3(0, 0.2, 0)))
			_bloom_c.append(Color(0.56, 0.5, 0.78).lerp(Color(0.5, 0.56, 0.4), 0.25 if k % 3 == 0 else 0.0))  # lavender
	for c in [Vector3(-16.0, 0, 26.5), Vector3(16.0, 0, 26.5), Vector3(15.8, 0, -25.5), Vector3(-2.0, 0, 27.5), Vector3(2.0, 0, 27.5), Vector3(2.4, 0, -26.5), Vector3(5.6, 0, -26.5)]:
		_pot(Vector3(c.x, PLATEAU_Y + 0.05, c.z), 0.8, 0)
	for k in 6:
		_pot(Vector3(-2.6, PLATEAU_Y + 0.05, 30.0 + k * 5.0), 0.7, k % 2)
		_pot(Vector3(2.6, PLATEAU_Y + 0.05, 30.0 + k * 5.0), 0.7, (k + 1) % 2)


func _build_villas() -> void:
	# Whitewashed villas on the hillside and the headland, facing the sea.
	var tries := 0
	while _villa_spots.size() < 80 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-170.0, -36.0)
		var z := rng.randf_range(-340.0, 90.0)
		if rng.randf() < 0.15:
			x = rng.randf_range(90.0, 220.0)
			z = rng.randf_range(-40.0, 160.0)
		var h := _height(x, z)
		if h < PLATEAU_Y + 2.0 or h > 46.0:
			continue
		var g := Vector2(_height(x + 2.0, z) - _height(x - 2.0, z), _height(x, z + 2.0) - _height(x, z - 2.0)) / 4.0
		if g.length() > 0.85:
			continue
		var ok := true
		for q in _villa_spots:
			if q.distance_to(Vector2(x, z)) < 13.0:
				ok = false
				break
		if not ok:
			continue
		_villa_spots.append(Vector2(x, z))
		_villa(x, z, g)
	# The lighthouse keeper's house on the tip of the headland.


func _villa(x: float, z: float, g: Vector2) -> void:
	var down := -g.normalized() if g.length() > 0.01 else Vector2(1, 0)
	var yaw := atan2(down.x, down.y) + rng.randf_range(-0.2, 0.2)
	var rot := Basis(Vector3.UP, yaw)
	var w := rng.randf_range(7.0, 11.0)   # along the slope's contour (local x)
	var d := rng.randf_range(5.5, 8.0)    # local z, facing downhill
	var storeys := 2 if rng.randf() < 0.55 else 1
	var lo := INF
	var hi := -INF
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var cv: Vector2 = c
		var off := rot * Vector3(cv.x * w * 0.5, 0, cv.y * d * 0.5)
		var ch := _height(x + off.x, z + off.z)
		lo = minf(lo, ch)
		hi = maxf(hi, ch)
	var y0 := lo - 0.8
	var top := hi + storeys * 3.0 + 0.3
	var col: Color = WHITES[rng.randi() % 4] if rng.randf() < 0.85 else WHITES[4 + rng.randi() % 2]
	_wall_far_t.append(Transform3D(rot * Basis.from_scale(Vector3(w, top - y0, d)), Vector3(x, (y0 + top) * 0.5, z)))
	_wall_far_c.append(col)
	var roof: Color = TERRACOTTA[rng.randi() % TERRACOTTA.size()]
	var r := rng.randf()
	if r < 0.45:
		_hip_far_t.append(Transform3D(rot * Basis.from_scale(Vector3(w + 0.6, 1.7, d + 0.6)) * Basis(Vector3.UP, PI * 0.25), Vector3(x, top + 0.85, z)))
		_hip_far_c.append(roof)
	elif r < 0.75:
		_gable_far_t.append(Transform3D(rot * Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(d + 0.6, 1.6, w + 0.6)), Vector3(x, top + 0.8, z)))
		_gable_far_c.append(roof)
	# else: a flat roof terrace, white.
	if rng.randf() < 0.55:
		# A lower wing to one side with a flat terrace roof.
		var s := -1.0 if rng.randf() < 0.5 else 1.0
		var w2 := rng.randf_range(4.0, 6.0)
		var d2 := d * rng.randf_range(0.7, 0.95)
		var off := rot * Vector3(s * (w * 0.5 + w2 * 0.5 - 0.2), 0, rng.randf_range(0.0, 1.0))
		var top2 := hi + 3.0 if storeys == 2 else hi + 2.4
		_wall_far_t.append(Transform3D(rot * Basis.from_scale(Vector3(w2, top2 - y0, d2)), Vector3(x + off.x, (y0 + top2) * 0.5, z + off.z)))
		_wall_far_c.append(col.darkened(0.03))
	for k in rng.randi_range(0, 2):
		var s := -1.0 if k == 0 else 1.0
		var p := rot * Vector3(s * w * 0.5 * rng.randf_range(0.5, 1.0), 0, d * 0.5 + 0.2)
		_bloom(Vector3(x + p.x, lo + rng.randf_range(1.2, 2.4), z + p.z), 1.4)
	if rng.randf() < 0.5:
		var p := rot * Vector3((w * 0.5 + 1.8) * (-1.0 if rng.randf() < 0.5 else 1.0), 0, rng.randf_range(-d, d) * 0.4)
		_cypress(Vector3(x + p.x, _height(x + p.x, z + p.z), z + p.z), rng.randf_range(0.8, 1.2))
	if rng.randf() < 0.35:
		var p := rot * Vector3(rng.randf_range(-2.0, 2.0), 0, d * 0.5 + 3.0)
		_palm(1 if rng.randf() < 0.5 else 2, Vector3(x + p.x, _height(x + p.x, z + p.z), z + p.z), false)
	if rng.randf() < 0.3:
		# A pool on the terrace below the house.
		var p := rot * Vector3(rng.randf_range(-1.5, 1.5), 0, d * 0.5 + 3.2)
		var ph := _height(x + p.x, z + p.z)
		if ph > lo - 1.0:
			_far_t.append(Transform3D(rot * Basis.from_scale(Vector3(6.0, 1.4, 4.0)), Vector3(x + p.x, ph - 0.4, z + p.z)))
			_far_c.append(WHITES[2])
			_far_t.append(Transform3D(rot * Basis.from_scale(Vector3(4.6, 0.1, 2.6)), Vector3(x + p.x, ph + 0.33, z + p.z)))
			_far_c.append(Color(0.3, 0.75, 0.85))


func _build_hill_vegetation() -> void:
	# Umbrella pines and scrub on the hills; kept off the villas.
	var pines := 0
	var tries := 0
	while pines < 110 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-260.0, -36.0)
		var z := rng.randf_range(-400.0, 160.0)
		if rng.randf() < 0.2:
			x = rng.randf_range(80.0, 260.0)
			z = rng.randf_range(-40.0, 200.0)
		var h := _height(x, z)
		if h < PLATEAU_Y + 1.5 or h > 70.0 or _near_villa(x, z, 7.0):
			continue
		var s := rng.randf_range(0.8, 1.3)
		var th := 5.5 * s
		_trunk_t.append(Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12)) * Basis.from_scale(Vector3(0.28 * s, th, 0.28 * s)), Vector3(x, h + th * 0.5, z)))
		_trunk_c.append(Color(0.42, 0.3, 0.22))
		var cr := rng.randf_range(2.6, 3.6) * s
		var cc := Color(0.24, 0.38, 0.17).lerp(Color(0.33, 0.45, 0.2), rng.randf())
		_crown_t.append(Transform3D(Basis.from_scale(Vector3(cr, cr * 0.42, cr * 0.9)), Vector3(x, h + th + 0.3, z)))
		_crown_c.append(cc)
		_crown_t.append(Transform3D(Basis.from_scale(Vector3(cr * 0.7, cr * 0.38, cr * 0.65)), Vector3(x + cr * 0.45, h + th + 0.8, z + cr * 0.2)))
		_crown_c.append(cc.lightened(0.06))
		pines += 1
	var n := 0
	tries = 0
	while n < 420 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-240.0, -38.0)
		var z := rng.randf_range(-400.0, 160.0)
		if rng.randf() < 0.18:
			x = rng.randf_range(80.0, 260.0)
			z = rng.randf_range(-40.0, 200.0)
		var h := _height(x, z)
		if h < PLATEAU_Y + 0.8 or _near_villa(x, z, 6.0):
			continue
		var s := rng.randf_range(1.0, 2.4)
		_scrub_t.append(Transform3D(Basis.from_scale(Vector3(1.3, 0.75, 1.2) * s), Vector3(x, h + 0.35 * s, z)))
		_scrub_c.append(SHRUBS[rng.randi() % SHRUBS.size()].darkened(rng.randf_range(0.0, 0.15)))
		n += 1


func _near_villa(x: float, z: float, r: float) -> bool:
	for q in _villa_spots:
		if absf(q.x - x) < r + 6.0 and absf(q.y - z) < r + 6.0:
			return true
	return false


func _build_lighthouse() -> void:
	var ab := HEAD_B - HEAD_A
	var p2 := HEAD_A + ab * 0.94
	var base := Vector3(p2.x, _height(p2.x, p2.y) - 0.5, p2.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_scyl(st, base, 1.5, 1.1, 14.0, 10, Color(0.97, 0.96, 0.93))
	_scyl(st, base + Vector3(0, 14.0, 0), 1.7, 1.7, 0.35, 10, Color(0.2, 0.2, 0.22))
	_scyl(st, base + Vector3(0, 15.9, 0), 1.05, 0.15, 1.0, 10, Color(0.55, 0.18, 0.14))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_glow_t.append(Transform3D(Basis.from_scale(Vector3(0.95, 0.8, 0.95)), base + Vector3(0, 15.2, 0)))
	# Keeper's house.
	var hp := HEAD_A + ab * 0.9
	var hy := _height(hp.x, hp.y)
	_wall_far_t.append(Transform3D(Basis.from_scale(Vector3(7.0, 4.0, 5.0)), Vector3(hp.x + 4.0, hy + 1.2, hp.y)))
	_wall_far_c.append(WHITES[0])
	_hip_far_t.append(Transform3D(Basis.from_scale(Vector3(7.6, 1.4, 5.6)) * Basis(Vector3.UP, PI * 0.25), Vector3(hp.x + 4.0, hy + 3.9, hp.y)))
	_hip_far_c.append(TERRACOTTA[0])


# --- Boats and gulls --------------------------------------------------------------

func _build_boats() -> void:
	var sail_mm := _mm(_sailboat_mesh(), _vc, _placeholder(5))
	sail_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var yacht_mm := _mm(_yacht_mesh(), _vc, _placeholder(2))
	yacht_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sails := [Vector3(-10.0, -140.0, 1.4), Vector3(70.0, -200.0, 1.1), Vector3(20.0, -310.0, 0.9), Vector3(150.0, -250.0, 1.2), Vector3(-40.0, -420.0, 0.8)]
	for i in sails.size():
		var s: Vector3 = sails[i]
		_boat_list.append({"mm": sail_mm.multimesh, "i": i, "x": s.x, "z": s.y, "speed": s.z, "ph": rng.randf() * TAU, "scale": 1.0})
	var yachts := [Vector3(110.0, -120.0, 2.2), Vector3(-20.0, -230.0, 1.6)]
	for i in yachts.size():
		var y: Vector3 = yachts[i]
		_boat_list.append({"mm": yacht_mm.multimesh, "i": i, "x": y.x, "z": y.y, "speed": y.z, "ph": rng.randf() * TAU, "scale": 1.0})
	_update_boats(0.0)


func _update_boats(delta: float) -> void:
	for b in _boat_list:
		var x: float = b.x + b.speed * delta
		if x > 320.0:
			x = -190.0  # back behind the headland
		b.x = x
		var ph: float = b.ph
		var roll := Basis(Vector3.RIGHT, sin(_t * 0.9 + ph) * 0.035)
		var pos := Vector3(x, SEA_Y + sin(_t * 1.1 + ph) * 0.07, b.z)
		(b.mm as MultiMesh).set_instance_transform(b.i, Transform3D(Basis.from_scale(Vector3.ONE * b.scale) * roll, pos))


func _placeholder(n: int) -> Array[Transform3D]:
	var a: Array[Transform3D] = []
	for i in n:
		a.append(Transform3D(Basis.IDENTITY, Vector3(0, -50, 0)))
	return a


func _build_gulls() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sbox(st, Vector3(0.3, 0, 0), Vector3(0.6, 0.03, 0.26), Color(0.95, 0.95, 0.93))
	_sbox(st, Vector3(0.75, 0, 0.02), Vector3(0.3, 0.03, 0.18), Color(0.3, 0.3, 0.32))
	var mat := _vc_mat()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var n := 7
	_gulls = _mm(st.commit(), mat, _placeholder(n * 2))
	_gulls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gull_mm = _gulls.multimesh
	for i in n:
		_gull_data.append(Vector4(rng.randf_range(18.0, 34.0), rng.randf_range(0.12, 0.2) * (1.0 if i % 3 else -1.0), rng.randf() * TAU, rng.randf_range(11.0, 19.0)))
	_low_quality_hidden.append(_gulls)
	_update_gulls()


func _update_gulls() -> void:
	var center := Vector3(18.0, 0.0, -78.0)
	for g in _gull_data.size():
		var d := _gull_data[g]
		var th := d.z + _t * d.y
		var p := center + Vector3(cos(th) * d.x, d.w + sin(_t * 0.3 + d.z) * 1.5, sin(th) * d.x * 0.6)
		var v := Vector3(-sin(th) * d.x, 0.0, cos(th) * d.x * 0.6) * signf(d.y)
		var yb := Basis(Vector3.UP, atan2(-v.x, -v.z))
		var flap := 0.12 + sin(_t * 8.0 + d.z * 3.0) * 0.55 * clampf(sin(_t * 0.45 + d.z) * 2.0, 0.0, 1.0)
		var bank := -0.3 * signf(d.y)
		_gull_mm.set_instance_transform(g * 2, Transform3D(yb * Basis(Vector3.BACK, flap + bank) * Basis.from_scale(Vector3.ONE * 1.4), p))
		_gull_mm.set_instance_transform(g * 2 + 1, Transform3D(yb * Basis(Vector3.BACK, -flap + bank) * Basis.from_scale(Vector3(-1.4, 1.4, 1.4)), p))


# --- Batches ----------------------------------------------------------------------

func _flush() -> void:
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm(_unit_box, _vc, _near_t, _near_c)
	_mm(_unit_box, _vc, _far_t, _far_c).cast_shadow = off
	var walls := _villa_mat()
	_mm(_unit_box, walls, _wall_near_t, _wall_near_c)
	_mm(_unit_box, walls, _wall_far_t, _wall_far_c).cast_shadow = off
	var roofs := _roof_mat()
	var gable := PrismMesh.new()
	gable.size = Vector3.ONE
	var hip := CylinderMesh.new()
	hip.top_radius = 0.0
	hip.bottom_radius = 0.7071
	hip.height = 1.0
	hip.radial_segments = 4
	hip.rings = 1
	var near_roof: Array[Color] = []
	for t in _gable_near_t:
		near_roof.append(TERRACOTTA[0])
	_mm(gable, roofs, _gable_near_t, near_roof)
	near_roof = []
	for t in _hip_near_t:
		near_roof.append(TERRACOTTA[2])
	_mm(hip, roofs, _hip_near_t, near_roof)
	_mm(gable, roofs, _gable_far_t, _gable_far_c).cast_shadow = off
	_mm(hip, roofs, _hip_far_t, _hip_far_c).cast_shadow = off
	_mm(_sphere, _sway_mat(0.05), _bloom_t, _bloom_c).cast_shadow = off
	_mm(_sphere, _sway_mat(0.06), _bush_t, _bush_c).cast_shadow = off
	var scrub := _mm(_sphere, _vc, _scrub_t, _scrub_c)
	scrub.cast_shadow = off
	_low_quality_hidden.append(scrub)
	_mm(_sphere, _sway_mat(0.08), _cypress_t, _cypress_c).cast_shadow = off
	var pot := CylinderMesh.new()
	pot.top_radius = 0.5
	pot.bottom_radius = 0.34
	pot.height = 1.0
	pot.radial_segments = 8
	_mm(pot, _vc, _pot_t, _pot_c).cast_shadow = off
	_mm(_cone_mesh(), _vc, _parasol_t, _parasol_c)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.6
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 6
	_mm(trunk, _vc, _trunk_t, _trunk_c).cast_shadow = off
	_mm(_sphere, _sway_mat(0.05), _crown_t, _crown_c).cast_shadow = off
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.2, 0.15, 0.1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.8, 0.5)
	glow.emission_energy_multiplier = 2.2
	_mm(_sphere, glow, _glow_t).cast_shadow = off
	_mm(_unit_box, _plain(Color(0.12, 0.11, 0.1)), _wire_t).cast_shadow = off
	_mm(_unit_box, _fence_mat, _fence_t).cast_shadow = off
	var stone := _stone_paving()
	_mm(_unit_box, stone, _stone_t).cast_shadow = off
	var tiles := _tile_paving()
	_mm(_unit_box, tiles, _tile_t).cast_shadow = off
	var palm_meshes := [_palm_mesh(8.0, 0.0, 0.42, 24, 4.6, 1.5, 3), _palm_mesh(14.0, 0.02, 0.22, 16, 2.6, 1.0, 7), _palm_mesh(10.0, 0.1, 0.24, 15, 3.6, 1.7, 11)]
	var heights := [8.0, 14.0, 10.0]
	for v in 3:
		var mat := _palm_mat(heights[v])
		for cast in 2:
			var list: Array[Transform3D] = []
			list.assign(_palm_t[v][cast])
			if list.is_empty():
				continue
			var mmi := _mm(palm_meshes[v], mat, list)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast == 1 else off


## A box into the tinted batch (near ones cast shadows), optionally turned by yaw.
func _bx(size: Vector3, pos: Vector3, col: Color, yaw := 0.0, near := true) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), pos)
	if near:
		_near_t.append(t)
		_near_c.append(col)
	else:
		_far_t.append(t)
		_far_c.append(col)


## A paving slab whose top sits `size.y / 2` above `pos.y`.
func _slab(size: Vector3, pos: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), pos)


func _bloom(p: Vector3, s: float, flat := Vector3.ONE) -> void:
	for k in 3:
		var o := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.5, 0.5)) * s * flat
		var r := rng.randf_range(0.35, 0.6) * s
		_bloom_t.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.8, r) * flat), p + o))
		_bloom_c.append(BOUGAINVILLEA[rng.randi() % BOUGAINVILLEA.size()] if k < 2 else Color(0.3, 0.45, 0.2))


func _pot(p: Vector3, s: float, plant: int) -> void:
	_pot_t.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.9, s)), p + Vector3(0, s * 0.45, 0)))
	_pot_c.append(TERRACOTTA[rng.randi() % TERRACOTTA.size()].lightened(0.05))
	if plant == 0:
		_bush_t.append(Transform3D(Basis.from_scale(Vector3(0.5, 0.45, 0.5) * s), p + Vector3(0, s * 1.05, 0)))
		_bush_c.append(SHRUBS[rng.randi() % SHRUBS.size()])
	else:
		_bush_t.append(Transform3D(Basis.from_scale(Vector3(0.42, 0.3, 0.42) * s), p + Vector3(0, s * 0.95, 0)))
		_bush_c.append(Color(0.3, 0.45, 0.2))
		for k in 3:
			_bloom_t.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.16 * s), p + Vector3(rng.randf_range(-0.25, 0.25) * s, s * 1.15, rng.randf_range(-0.25, 0.25) * s)))
			_bloom_c.append(Color(0.9, 0.15, 0.18) if rng.randf() < 0.7 else Color(0.95, 0.4, 0.6))


func _palm(variant: int, p: Vector3, casts: bool) -> void:
	var s := rng.randf_range(0.85, 1.15)
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06)) * Basis.from_scale(Vector3.ONE * s)
	(_palm_t[variant][1 if casts else 0] as Array).append(Transform3D(b, p))


func _cypress(p: Vector3, s: float) -> void:
	var h := rng.randf_range(4.0, 5.5) * s
	_cypress_t.append(Transform3D(Basis.from_scale(Vector3(0.75 * s, h, 0.75 * s)), p + Vector3(0, h * 0.95, 0)))
	_cypress_c.append(Color(0.2, 0.3, 0.17).lerp(Color(0.26, 0.34, 0.18), rng.randf()))


func _olive(p: Vector3) -> void:
	var s := rng.randf_range(0.85, 1.15)
	_trunk_t.append(Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.2, 0.2)) * Basis.from_scale(Vector3(0.22, 1.8, 0.22) * s), p + Vector3(0, 0.9 * s, 0)))
	_trunk_c.append(Color(0.4, 0.34, 0.28))
	for k in 3:
		var r := rng.randf_range(1.1, 1.6) * s
		_crown_t.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.75, r)), p + Vector3(rng.randf_range(-0.8, 0.8), 2.2 * s + k * 0.35, rng.randf_range(-0.8, 0.8))))
		_crown_c.append(Color(0.5, 0.56, 0.4).lerp(Color(0.6, 0.64, 0.5), rng.randf()))


# --- Meshes -----------------------------------------------------------------------

## Triangle with a flat normal; the winding is fixed so it faces along n.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(p)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	_tri(st, a, b, c, n, col)
	_tri(st, a, c, d, n, col)


func _sbox(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, b := Basis.IDENTITY) -> void:
	var h := s * 0.5
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		for sgn in [-1.0, 1.0]:
			var n: Vector3 = axes[i] * sgn
			var u: Vector3 = axes[(i + 1) % 3]
			var v: Vector3 = axes[(i + 2) % 3]
			var fc := n * h
			var hu := u * h
			var hv := v * h
			_quad(st, c + b * (fc - hu - hv), c + b * (fc + hu - hv), c + b * (fc + hu + hv), c + b * (fc - hu + hv), (b * n).normalized(), col)


func _scyl(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, sides: int, col: Color) -> void:
	var up := Vector3.UP * h
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := ((d0 + d1).normalized() + Vector3.UP * (r0 - r1) / h).normalized()
		_quad(st, base + d0 * r0, base + d1 * r0, base + up + d1 * r1, base + up + d0 * r1, n, col)
		_tri(st, base + up, base + up + d0 * r1, base + up + d1 * r1, Vector3.UP, col)


func _cone_mesh() -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 1.0
	cone.height = 0.6
	cone.radial_segments = 10
	cone.rings = 1
	return cone


## Arcade wall facing +X at x = fx: `bays` round arches on pillars, from z0 along +Z.
func _arcade_mesh(fx: float, z0: float, bays: int, bw: float, pw: float, ys: float, top: float, thick: float, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shade := col.darkened(0.12)
	var n_arc := 10
	for i in bays:
		var u0 := z0 + i * bw
		var u1 := u0 + bw
		var uc := (u0 + u1) * 0.5
		var r := (bw - pw) * 0.5
		var arc: Array[Vector2] = []
		for k in n_arc + 1:
			var a := PI - PI * k / n_arc
			arc.append(Vector2(uc + cos(a) * r, ys + sin(a) * r))
		for side in 2:
			var dx := 0.0 if side == 0 else -thick
			var n := Vector3.RIGHT if side == 0 else Vector3.LEFT
			var P := func(q: Vector2) -> Vector3: return Vector3(fx + dx, q.y, q.x)
			_quad(st, P.call(Vector2(u0, 0)), P.call(Vector2(uc - r, 0)), P.call(Vector2(uc - r, ys)), P.call(Vector2(u0, ys)), n, col)
			_quad(st, P.call(Vector2(uc + r, 0)), P.call(Vector2(u1, 0)), P.call(Vector2(u1, ys)), P.call(Vector2(uc + r, ys)), n, col)
			_quad(st, P.call(Vector2(u0, ys + r)), P.call(Vector2(u1, ys + r)), P.call(Vector2(u1, top)), P.call(Vector2(u0, top)), n, col)
			var tl := Vector2(u0, ys + r)
			var tr := Vector2(u1, ys + r)
			_tri(st, P.call(tl), P.call(Vector2(u0, ys)), P.call(arc[0]), n, col)
			for k in n_arc / 2:
				_tri(st, P.call(tl), P.call(arc[k]), P.call(arc[k + 1]), n, col)
			for k in range(n_arc / 2, n_arc):
				_tri(st, P.call(tr), P.call(arc[k]), P.call(arc[k + 1]), n, col)
			_tri(st, P.call(tr), P.call(arc[n_arc]), P.call(Vector2(u1, ys)), n, col)
		# Intrados and the pillars' inner faces, a shade darker.
		for k in n_arc:
			var a := arc[k]
			var b := arc[k + 1]
			var m := (a + b) * 0.5
			var nn := (Vector2(uc, ys) - m).normalized()
			_quad(st, Vector3(fx, a.y, a.x), Vector3(fx, b.y, b.x), Vector3(fx - thick, b.y, b.x), Vector3(fx - thick, a.y, a.x), Vector3(0, nn.y, nn.x), shade)
		_quad(st, Vector3(fx, 0, uc - r), Vector3(fx, ys, uc - r), Vector3(fx - thick, ys, uc - r), Vector3(fx - thick, 0, uc - r), Vector3.BACK, shade)
		_quad(st, Vector3(fx, 0, uc + r), Vector3(fx, ys, uc + r), Vector3(fx - thick, ys, uc + r), Vector3(fx - thick, 0, uc + r), Vector3.FORWARD, shade)
	var z1 := z0 + bays * bw
	for e in [[z0, Vector3.FORWARD], [z1, Vector3.BACK]]:
		var ez: float = e[0]
		_quad(st, Vector3(fx, 0, ez), Vector3(fx, top, ez), Vector3(fx - thick, top, ez), Vector3(fx - thick, 0, ez), e[1], col)
	_quad(st, Vector3(fx, top, z0), Vector3(fx, top, z1), Vector3(fx - thick, top, z1), Vector3(fx - thick, top, z0), Vector3.UP, col)
	return st.commit()


## A palm, base at the origin: a ringed trunk (optionally curving toward +X) and a
## crown of arching, folded fronds. Vertex alpha marks how much each part flutters.
func _palm_mesh(h: float, curve: float, trunk_r: float, fronds: int, frond_len: float, droop: float, mesh_seed: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = mesh_seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	var sides := 6
	var trunk := Color(0.52, 0.42, 0.32, 0.0)
	var spine := func(t: float) -> Vector3: return Vector3(curve * t * t * h, t * h, 0)
	for sgi in segs:
		var t0 := sgi / float(segs)
		var t1 := (sgi + 1) / float(segs)
		var c0: Vector3 = spine.call(t0)
		var c1: Vector3 = spine.call(t1)
		var r0 := trunk_r * lerpf(1.3, 0.8, t0)
		var r1 := trunk_r * lerpf(1.3, 0.8, t1) * 1.08
		var col := trunk.darkened(0.14) if sgi % 2 == 0 else trunk
		col.a = 0.0
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			_quad(st, c0 + d0 * r0, c0 + d1 * r0, c1 + d1 * r1, c1 + d0 * r1, (d0 + d1).normalized(), col)
	var top: Vector3 = spine.call(1.0)
	# A tuft where the fronds start.
	_sbox(st, top + Vector3(0, 0.1, 0), Vector3(trunk_r * 2.2, 0.6, trunk_r * 2.2), Color(0.42, 0.42, 0.22, 0.0), Basis(Vector3.UP, 0.4))
	for i in fronds:
		var az := TAU * i / fronds + r.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(az), 0, sin(az))
		var side := Vector3(-dir.z, 0, dir.x)
		var e := r.randf_range(0.2, 0.95)
		var flen := frond_len * r.randf_range(0.8, 1.1)
		var leaf := PALM_GREEN.lerp(Color(0.46, 0.56, 0.26), r.randf() * 0.5)
		var nseg := 6
		var pts: Array[Vector3] = []
		var p := top
		for k in nseg + 1:
			pts.append(p)
			var ang := e - droop * k / float(nseg)
			p += (dir * cos(ang) + Vector3.UP * sin(ang)) * flen / nseg
		for k in nseg:
			var w0 := flen * 0.13 * sin(PI * (k + 0.35) / (nseg + 0.35))
			var w1 := flen * 0.13 * sin(PI * (k + 1.35) / (nseg + 0.35))
			var a := pts[k]
			var b := pts[k + 1]
			var col := leaf.lightened(0.12).lerp(leaf.darkened(0.12), k / float(nseg))
			col.a = (k + 1) / float(nseg)
			for sd in [-1.0, 1.0]:
				var e0: Vector3 = a + side * w0 * sd - Vector3.UP * w0 * 0.35
				var e1: Vector3 = b + side * w1 * sd - Vector3.UP * w1 * 0.35
				var nrm := (b - a).cross(e0 - a).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				_tri(st, a, e0, b, nrm, col)
				_tri(st, e0, e1, b, nrm, col)
	return st.commit()


func _sailboat_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hull := Color(0.96, 0.96, 0.94)
	_hull(st, [Vector2(-3.4, -1.1), Vector2(1.2, -1.2), Vector2(3.8, 0.0), Vector2(1.2, 1.2), Vector2(-3.4, 1.1)], 0.0, 1.0, 0.65, hull, Color(0.7, 0.55, 0.38))
	_sbox(st, Vector3(-0.6, 1.25, 0), Vector3(2.0, 0.5, 1.2), hull)
	_sbox(st, Vector3(0.6, 5.4, 0), Vector3(0.12, 8.8, 0.12), Color(0.75, 0.75, 0.75))
	var sail := Color(0.98, 0.96, 0.9)
	for n in [Vector3.BACK, Vector3.FORWARD]:
		_tri(st, Vector3(0.5, 1.6, 0), Vector3(0.5, 9.6, 0), Vector3(-3.0, 1.7, 0), n, sail)
		_tri(st, Vector3(0.7, 9.0, 0), Vector3(3.6, 1.2, 0), Vector3(0.7, 1.4, 0), n, sail.darkened(0.04))
	return st.commit()


func _yacht_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color(0.97, 0.97, 0.96)
	var dark := Color(0.12, 0.15, 0.2)
	_hull(st, [Vector2(-7.5, -2.3), Vector2(3.0, -2.4), Vector2(8.5, 0.0), Vector2(3.0, 2.4), Vector2(-7.5, 2.3)], 0.0, 1.9, 0.7, white, Color(0.85, 0.82, 0.76))
	_sbox(st, Vector3(-1.5, 2.6, 0), Vector3(8.0, 1.5, 3.6), white)
	_sbox(st, Vector3(-1.0, 2.75, 0), Vector3(6.6, 0.55, 3.66), dark)
	_sbox(st, Vector3(-2.4, 3.8, 0), Vector3(4.6, 0.9, 3.0), white)
	_sbox(st, Vector3(-2.2, 3.85, 0), Vector3(3.6, 0.4, 3.06), dark)
	_sbox(st, Vector3(-2.4, 4.6, 0), Vector3(0.12, 1.0, 0.12), Color(0.7, 0.7, 0.7))
	return st.commit()


## Boat hull: a deck outline (x, z) at y_top, narrowing toward a keel line at y_bot.
func _hull(st: SurfaceTool, outline: Array, y_bot: float, y_top: float, narrow: float, side: Color, deck: Color) -> void:
	var n := outline.size()
	var c := Vector3.ZERO
	for q in outline:
		var v: Vector2 = q
		c += Vector3(v.x, y_top, v.y)
	c /= n
	for k in n:
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % n]
		var at := Vector3(a.x, y_top, a.y)
		var bt := Vector3(b.x, y_top, b.y)
		var ab_ := Vector3(a.x * 0.92, y_bot, a.y * narrow)
		var bb := Vector3(b.x * 0.92, y_bot, b.y * narrow)
		var out := Vector3(a.x + b.x, 0, a.y + b.y).normalized()
		var nrm := (bt - at).cross(ab_ - at).normalized()
		if nrm.dot(out) < 0.0:
			nrm = -nrm
		_quad(st, at, bt, bb, ab_, nrm, side)
		_tri(st, c, at, bt, Vector3.UP, deck)


# --- Materials and textures -------------------------------------------------------

## Per-instance (or per-vertex) colours, read as sRGB like albedo colours.
func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.88
	return m


## Foliage tinted per instance that sways on the GPU (like Scenery._swaying_leaves).
func _sway_mat(strength: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform float strength = 0.06;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = o.x * 0.37 + o.z * 0.23;
	float s = (sin(TIME * 0.9 + ph) + sin(TIME * 2.1 + ph * 2.0) * 0.35) * strength;
	float bend = VERTEX.y * 0.5 + 0.5;
	VERTEX.x += s * bend / length(MODEL_MATRIX[0].xyz);
	VERTEX.z += s * 0.4 * bend / length(MODEL_MATRIX[2].xyz);
}
void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("strength", strength)
	return m


## Palms bend in the sea breeze: the trunk sways more toward the top, the fronds
## flutter (vertex alpha). The shadow pass runs the same code.
func _palm_mat(height: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
uniform float height = 8.0;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = o.x * 0.29 + o.z * 0.17;
	float t = clamp(VERTEX.y / height, 0.0, 1.3);
	vec3 w = vec3(sin(TIME * 0.7 + ph) * 0.2 + sin(TIME * 1.7 + ph * 1.9) * 0.05, 0.0, sin(TIME * 0.55 + ph * 0.6) * 0.1) * t * t;
	w.y += sin(TIME * 2.6 + ph + VERTEX.x * 0.9 + VERTEX.z * 0.9) * 0.12 * COLOR.a;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * w;
}
void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("height", height)
	return m


## Whitewashed walls (unit boxes tinted per instance) with shuttered windows on tall
## walls, a few of them lit warmly; storeys counted from the top.
func _villa_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 lp;
varying vec3 ln;
varying vec3 sc;
varying vec3 org;
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() {
	sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * sc;
	ln = NORMAL;
	org = MODEL_MATRIX[3].xyz;
}
void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	vec3 emit = vec3(0.0);
	if (abs(ln.y) < 0.5 && sc.y > 2.6) {
		bool xface = abs(ln.x) > 0.5;
		float u = xface ? lp.z : lp.x;
		float wdt = xface ? sc.z : sc.x;
		float from_top = sc.y * 0.5 - lp.y;
		float fu = u / 3.9 + 0.5;
		float fl = from_top / 3.0;
		vec2 f = vec2(fract(fu), fract(fl));
		float inside = step(abs(u), wdt * 0.5 - 1.0) * step(0.3, from_top) * step(from_top, sc.y - 0.6);
		float rows = step(0.3, f.y) * step(f.y, 0.78);
		float win = step(0.39, f.x) * step(f.x, 0.61) * rows * inside;
		float hv = hash(floor(org * 0.37));
		float shut = (step(0.29, f.x) * step(f.x, 0.39) + step(0.61, f.x) * step(f.x, 0.71)) * rows * inside * step(0.35, hv);
		vec3 shutter = mix(vec3(0.05, 0.16, 0.09), vec3(0.06, 0.12, 0.24), step(0.7, hv));
		col = mix(col, shutter, shut);
		col = mix(col, vec3(0.03, 0.035, 0.05), win);
		float lit = step(0.88, hash(vec3(floor(fu), floor(fl), org.x + org.z)));
		emit = vec3(1.0, 0.6, 0.25) * win * lit * 0.5;
	}
	// A touch darker toward the ground.
	col *= mix(0.86, 1.0, smoothstep(0.0, 2.0, lp.y + sc.y * 0.5));
	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Terracotta roofs: rows of curved tiles; the gable ends are whitewashed.
func _roof_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 lp;
varying vec3 ln;
void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * sc;
	ln = NORMAL;
}
void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float ch = abs(ln.x) > abs(ln.z) ? lp.z : lp.x;
	float channels = 0.8 + 0.2 * smoothstep(-0.6, 0.8, sin(ch * 22.0));
	float rows = 0.9 + 0.1 * step(0.5, fract(lp.y * 3.2));
	col *= channels * rows;
	if (abs(ln.z) > 0.9 && abs(ln.y) < 0.1) {
		col = vec3(0.86, 0.82, 0.76);
	}
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _stone_paving() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tile_texture(Color(0.86, 0.79, 0.66), Color(0.72, 0.65, 0.54), 4, 0.04)
	m.roughness = 0.92
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 2.4
	return m


func _tile_paving() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tile_texture(Color(0.74, 0.42, 0.3), Color(0.6, 0.48, 0.4), 4, 0.06)
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 1.6
	return m


func _tile_texture(base: Color, grout: Color, tiles: int, vary: float) -> ImageTexture:
	var n := 64
	var cell := n / tiles
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var shades: Array[float] = []
	for i in tiles * tiles:
		shades.append(r.randf_range(-vary, vary))
	for y in n:
		for x in n:
			var c: Color
			if x % cell == 0 or y % cell == 0:
				c = grout
			else:
				var s := shades[(y / cell) * tiles + x / cell] + r.randf_range(-0.012, 0.012)
				c = Color(base.r + s, base.g + s * 0.9, base.b + s * 0.8)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _grey_noise_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(0.86, 0.86, 0.86), Color(1.0, 1.0, 1.0)])
	tex.color_ramp = ramp
	return tex


## A long evening cloud: soft blobs stretched sideways, golden underneath, lavender on top.
func _sunset_cloud_texture() -> ImageTexture:
	var w := 256
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 0.04
	noise.fractal_octaves = 4
	var blobs := []
	for i in 9:
		blobs.append(Vector3(rng.randf_range(0.12, 0.88) * w, rng.randf_range(0.42, 0.62) * h, rng.randf_range(8.0, 17.0)))
	var top := Color(0.86, 0.66, 0.86)
	var bottom := Color(1.0, 0.76, 0.52)
	for y in h:
		for x in w:
			var d := 0.0
			for bl in blobs:
				var v: Vector3 = bl
				var dx := (x - v.x) / (v.z * 2.6)
				var dy := (y - v.y) / v.z
				d = maxf(d, 1.0 - (dx * dx + dy * dy))
			d += noise.get_noise_2d(x, y * 2.0) * 0.45
			var edge := clampf(minf(x, w - 1 - x) / 30.0, 0.0, 1.0)
			var a := clampf(d * 2.0, 0.0, 1.0) * edge * 0.85
			var c := top.lerp(bottom, smoothstep(0.35, 0.85, y / float(h)))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
