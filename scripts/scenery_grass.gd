class_name SceneryGrass
extends Scenery
## A grey, misty morning at a lawn tennis club in an old English town. Everything is
## procedural.
##
##   light   overcast sky, the sun only a pale glow low in the mist, soft faint shadows;
##           depth fog that leaves the court crisp and swallows the town behind it
##   life    a red double-decker and black cabs on the wet street, crows, flickering
##           street lamps, Belisha beacons blinking, a light drizzle, drifting mist
##   court   dark green windscreens, cream-and-green stands, umpire's chair, players'
##           chairs with towels, flower boxes with hydrangeas, a scoreboard
##   world   ivy-covered brick walls and iron railings, a street with a phone box, a pub
##           and shops, Victorian terraces with chimneys and lit windows, a church spire,
##           a clock tower and a dome fading into the fog
##
## Repeated things are MultiMesh (one draw call per kind); boxes of many colours share one
## tinted MultiMesh, so the whole location is a few dozen draw calls.

const MIST := Color(0.70, 0.73, 0.74)
const OVERCAST_TOP := Color(0.50, 0.54, 0.58)
const OVERCAST_HORIZON := Color(0.73, 0.75, 0.75)
const PALE_SUN := Color(0.97, 0.95, 0.88)
const LAMP_GLOW := Color(1.0, 0.72, 0.38)
const WINDOW_GLOW := Color(1.0, 0.74, 0.44)
const CLUB_GREEN := Color(0.07, 0.19, 0.13)
const CREAM := Color(0.86, 0.83, 0.72)
const PURPLE := Color(0.34, 0.17, 0.43)
const IRON := Color(0.055, 0.06, 0.065)
const STONE := Color(0.62, 0.61, 0.57)
const RED := Color(0.72, 0.07, 0.06)
const BRICKS := [
	Color(0.55, 0.32, 0.25),  # red brick
	Color(0.60, 0.52, 0.40),  # London stock
	Color(0.45, 0.29, 0.24),  # dark red
	Color(0.83, 0.81, 0.75),  # white stucco
	Color(0.50, 0.44, 0.36),  # sooty stock
	Color(0.64, 0.39, 0.30),  # bright red
]
const SLATES := [Color(0.27, 0.29, 0.33), Color(0.32, 0.33, 0.36), Color(0.38, 0.29, 0.26)]
const IVY := [Color(0.13, 0.25, 0.12), Color(0.19, 0.31, 0.15), Color(0.11, 0.21, 0.11), Color(0.24, 0.34, 0.17)]
const PLANE_LEAVES := [Color(0.27, 0.38, 0.22), Color(0.33, 0.43, 0.25), Color(0.24, 0.34, 0.21)]
const BLOOMS := [Color(0.52, 0.45, 0.85), Color(0.72, 0.52, 0.86), Color(0.95, 0.95, 0.97), Color(0.92, 0.5, 0.66), Color(0.42, 0.52, 0.9)]
const DOORS := [Color(0.05, 0.05, 0.06), Color(0.55, 0.08, 0.08), Color(0.08, 0.16, 0.36), Color(0.07, 0.25, 0.16), Color(0.9, 0.9, 0.88)]

const STREET_Y := 1.4          # the town stands a storey-height above the sunken club
const WALL_Z := -23.0          # retaining wall under the street railing
const ROAD_NEAR_Z := -26.5
const ROAD_FAR_Z := -35.0
const ROW_A_Z := -38.0         # house fronts across the street
const SIDE_STREET := Vector2(9.6, 19.2)
const CLUB_W := 26.0           # club grounds half-width (side walls)
const BAY := 2.4               # facade window bay (the facade shader uses the same grid)
const FLOOR_H := 3.1

# Instances collected while building, flushed into one MultiMesh per kind.
var _near_t: Array[Transform3D] = []   # courtside boxes, cast shadows
var _near_c: Array[Color] = []
var _street_t: Array[Transform3D] = [] # street and town boxes, no shadows
var _street_c: Array[Color] = []
var _iron_t: Array[Transform3D] = []
var _cyl_t: Array[Transform3D] = []
var _cyl_c: Array[Color] = []
var _fac_t: Array[Transform3D] = []
var _fac_c: Array[Color] = []
var _roof_t: Array[Transform3D] = []
var _roof_c: Array[Color] = []
var _cone_t: Array[Transform3D] = []
var _cone_c: Array[Color] = []
var _glow_t: Array[Transform3D] = []   # lantern glass, lit shop windows (boxes)
var _glow_c: Array[Color] = []
var _globe_t: Array[Transform3D] = []
var _globe_c: Array[Color] = []
var _disc_t: Array[Transform3D] = []
var _disc_c: Array[Color] = []
var _halo_t: Array[Transform3D] = []
var _pave_t: Array[Transform3D] = []
var _puddle_t: Array[Transform3D] = []
var _wall_t: Array[Transform3D] = []
var _wall_c: Array[Color] = []
var _ivy_t: Array[Transform3D] = []
var _ivy_c: Array[Color] = []
var _bloom_t: Array[Transform3D] = []
var _bloom_c: Array[Color] = []
var _trunk_t: Array[Transform3D] = []
var _crown_t: Array[Transform3D] = []
var _crown_c: Array[Color] = []

var _cyl := CylinderMesh.new()
var _cone := CylinderMesh.new()
var _vehicles: Array[Node3D] = []
var _extras: Array[GeometryInstance3D] = []  # drizzle, halos, mist: dropped on slow phones
var _flock: MultiMeshInstance3D
var _flock_timer := 4.0


func _ready() -> void:
	rng.seed = 1877  # the year of the first lawn tennis championship
	_unit_box.size = Vector3.ONE
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 10
	_sphere.rings = 6
	_cyl.top_radius = 1.0
	_cyl.bottom_radius = 1.0
	_cyl.height = 1.0
	_cyl.radial_segments = 8
	_cyl.rings = 0
	_cone.top_radius = 0.0
	_cone.bottom_radius = 1.0
	_cone.height = 1.0
	_cone.radial_segments = 8
	_cone.rings = 0
	_build_light()
	_build_overcast()
	_build_grounds()
	_build_walls()
	_build_street()
	_build_town()
	_build_landmarks()
	_build_court_surrounds()
	_build_stands()
	_build_courtside()
	_build_greenery()
	_build_mist()
	_build_vehicles()
	_build_drizzle()
	_build_flock()
	_flush()


func _process(delta: float) -> void:
	_t += delta
	# The pale sun comes and goes behind thicker and thinner cloud.
	_sun.light_energy = 0.62 + sin(_t * 0.11) * 0.05 + sin(_t * 0.037 + 2.0) * 0.04
	for v in _vehicles:
		var speed: float = v.get_meta("speed")
		v.position.x += speed * delta
		if absf(v.position.x) > 140.0:
			v.position.x = -signf(speed) * 140.0
	_update_flock(delta)


## Lighter rendering for slow phones: shorter, hard shadows; no drizzle, lamp halos or
## mist sheets (transparent layers that cost fill rate).
func set_high_quality(on: bool) -> void:
	for n in _extras:
		n.visible = on
	_sun.directional_shadow_max_distance = 42.0 if on else 26.0
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if on else RenderingServer.SHADOW_QUALITY_HARD)


# --- Light, sky, mist -------------------------------------------------------------

func _build_light() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = OVERCAST_TOP
	sky_mat.sky_horizon_color = OVERCAST_HORIZON
	sky_mat.sky_curve = 0.3
	sky_mat.ground_bottom_color = MIST.darkened(0.25)
	sky_mat.ground_horizon_color = OVERCAST_HORIZON
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	# Overcast: most light comes from the whole sky, little from the sun.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.84, 0.86)
	e.ambient_light_energy = 0.72
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.95
	e.adjustment_contrast = 1.05
	# Depth fog: nothing up to just past the far baseline, then the town thins into mist.
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = MIST
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = 0.12
	e.fog_density = 0.94
	e.fog_depth_begin = 34.0
	e.fog_depth_end = 190.0
	e.fog_depth_curve = 0.8
	e.fog_sky_affect = 0.7
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)

	# The sun hangs low ahead, behind the town, as a pale disc in the mist.
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-36.0, 188.0, 0.0)
	_sun.light_color = PALE_SUN
	_sun.light_energy = 0.62
	_sun.shadow_enabled = true
	_sun.shadow_opacity = 0.25
	_sun.shadow_blur = 2.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 42.0
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_sun)

	var to_sun := _sun.transform.basis.z
	var az := Vector3(to_sun.x, 0.0, to_sun.z).normalized()
	var elev := deg_to_rad(8.0)
	var pos := az * cos(elev) * 480.0 + Vector3(0.0, 8.0 + sin(elev) * 480.0, 0.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.05, 0.08, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.0, 0.97, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_fog = true
	var q := QuadMesh.new()
	q.size = Vector2(150.0, 150.0)
	var glow := MeshInstance3D.new()
	glow.mesh = q
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.transform = Transform3D(Basis.looking_at(pos.normalized(), Vector3.UP), pos)
	add_child(glow)


func _build_overcast() -> void:
	# A low, unbroken cloud deck: big soft grey banks just above the rooftops.
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _make_cloud_texture()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	var q := QuadMesh.new()
	var t: Array[Transform3D] = []
	var c: Array[Color] = []
	for i in 16:
		var w := rng.randf_range(160.0, 280.0)
		var dist := rng.randf_range(430.0, 560.0)
		var el := deg_to_rad(rng.randf_range(5.0, 16.0))
		var x := -480.0 + i * 64.0 + rng.randf_range(-25.0, 25.0)
		var p := Vector3(x, 8.0 + dist * tan(el), -dist)
		t.append(Transform3D(Basis.looking_at(p.normalized(), Vector3.UP) * Basis.from_scale(Vector3(w, w * 0.32, 1.0)), p))
		var g := rng.randf_range(0.58, 0.7)
		c.append(Color(g, g + 0.02, g + 0.035, rng.randf_range(0.35, 0.6)))
	_mm(q, mat, t, c).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_mist() -> void:
	# Soft sheets of low-lying mist between the rows of houses, drifting slowly.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 mist : source_color;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float h = smoothstep(0.0, 1.0, UV.y);
	float drift = 0.7 + 0.3 * sin(wpos.x * 0.045 + TIME * 0.05 + wpos.z) * sin(wpos.x * 0.017 - TIME * 0.03);
	ALBEDO = mist;
	ALPHA = h * h * 0.42 * drift;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("mist", MIST.lightened(0.04))
	var t: Array[Transform3D] = []
	for z in [-51.0, -71.0, -92.0, -116.0, -150.0]:
		var h := 22.0 if z > -100.0 else 34.0
		t.append(Transform3D(Basis.from_scale(Vector3(520.0, h, 1.0)), Vector3(0.0, STREET_Y - 0.5 + h * 0.5, z)))
	var mmi := _mm(QuadMesh.new(), m, t)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_extras.append(mmi)


# --- Ground -----------------------------------------------------------------------

func _build_grounds() -> void:
	# The club lawn, from the retaining wall back past the camera.
	_ground(Vector2(640.0, 280.0), Vector3(0, LAWN_Y, WALL_Z + 140.0), _noise_mat(Color(0.24, 0.36, 0.19), 0.1, 30.0))
	# The town at street level, out into the fog: wet asphalt.
	var asphalt := _noise_mat(Color(0.16, 0.165, 0.17), 0.12, 14.0)
	asphalt.roughness = 0.32
	_ground(Vector2(900.0, 600.0), Vector3(0, STREET_Y, WALL_Z - 300.0), asphalt)
	# The court's grass apron stands on a low stone-edged plinth.
	var apron := Vector3(Court.DOUBLES_HALF_WIDTH * 2.0 + 13.0, 0.0, Court.HALF_LENGTH * 2.0 + 18.0)
	_box(Vector3(apron.x + 0.24, -LAWN_Y - 0.02, apron.z + 0.24), Vector3(0, (LAWN_Y - 0.02) * 0.5, 0), _plain(STONE.darkened(0.15)), false)
	# Wet stone paths: along the far end under the wall, and down both sides.
	_pave_t.append(Transform3D(Basis.from_scale(Vector3(CLUB_W * 2.0, 0.06, 2.4)), Vector3(0, LAWN_Y + 0.03, WALL_Z + 1.2)))
	for s in [-1.0, 1.0]:
		_pave_t.append(Transform3D(Basis.from_scale(Vector3(2.4, 0.06, 64.0)), Vector3(s * 18.5, LAWN_Y + 0.03, WALL_Z + 32.0)))
	_pave_t.append(Transform3D(Basis.from_scale(Vector3(39.4, 0.06, 2.4)), Vector3(0, LAWN_Y + 0.03, 25.6)))
	for i in 14:
		var p := Vector3(rng.randf_range(-24.0, 24.0), LAWN_Y + 0.065, WALL_Z + rng.randf_range(0.5, 1.9))
		if i >= 8:
			p = Vector3((1.0 if i % 2 == 0 else -1.0) * rng.randf_range(17.6, 19.4), LAWN_Y + 0.065, rng.randf_range(-20.0, 30.0))
		_puddle_t.append(Transform3D(Basis(Vector3.UP, rng.randf() * PI) * Basis.from_scale(Vector3(rng.randf_range(0.4, 1.1), 0.01, rng.randf_range(0.25, 0.6))), p))


func _build_walls() -> void:
	# The club sits a storey below the street; an ivy-covered brick retaining wall with a
	# stone coping and iron railings holds the pavement above the far end.
	var brick := Color(0.56, 0.36, 0.28)
	var top := STREET_Y + 0.4
	_wall_t.append(Transform3D(Basis.from_scale(Vector3(CLUB_W * 2.0 + 0.9, top - LAWN_Y + 0.1, 0.6)), Vector3(0, (top + LAWN_Y - 0.1) * 0.5, WALL_Z - 0.3)))
	_wall_c.append(brick)
	_bx(_street_t, _street_c, Vector3(CLUB_W * 2.0 + 1.0, 0.12, 0.72), Vector3(0, top + 0.06, WALL_Z - 0.3), STONE)
	# Garden walls down both sides of the grounds.
	for s in [-1.0, 1.0]:
		_wall_t.append(Transform3D(Basis.from_scale(Vector3(0.45, 3.0, 80.0)), Vector3(s * (CLUB_W + 0.22), LAWN_Y + 1.5, WALL_Z + 40.0)))
		_wall_c.append(brick.darkened(0.06))
		_bx(_street_t, _street_c, Vector3(0.55, 0.1, 80.0), Vector3(s * (CLUB_W + 0.22), LAWN_Y + 3.05, WALL_Z + 40.0), STONE)
	# Railings: bars with little spear tips between two rails.
	var x := -CLUB_W
	while x <= CLUB_W:
		_iron_t.append(Transform3D(Basis.from_scale(Vector3(0.035, 1.05, 0.035)), Vector3(x, top + 0.12 + 0.52, WALL_Z - 0.3)))
		_iron_t.append(Transform3D(Basis(Vector3.FORWARD, PI * 0.25) * Basis.from_scale(Vector3(0.06, 0.06, 0.03)), Vector3(x, top + 1.2, WALL_Z - 0.3)))
		x += 0.2
	for h in [0.22, 1.05]:
		_iron_t.append(Transform3D(Basis.from_scale(Vector3(CLUB_W * 2.0, 0.045, 0.045)), Vector3(0, top + 0.12 + h, WALL_Z - 0.3)))
	# Ivy: dense clumps over the brick, a few spilling over the top.
	var clump := func(p: Vector3, size: Vector3) -> void:
		_ivy_t.append(Transform3D(Basis.from_scale(size), p))
		_ivy_c.append(IVY[rng.randi() % IVY.size()])
	for i in 300:
		var px := rng.randf_range(-CLUB_W, CLUB_W)
		var cover := 0.55 + 0.45 * sin(px * 0.21) * sin(px * 0.07 + 1.0)
		var py := lerpf(LAWN_Y, top + 0.1, sqrt(rng.randf()) * clampf(cover + 0.3, 0.3, 1.0))
		clump.call(Vector3(px, py, WALL_Z + 0.02), Vector3(rng.randf_range(0.5, 1.2), rng.randf_range(0.35, 0.75), 0.18))
	for s in [-1.0, 1.0]:
		for i in 260:
			var pz := rng.randf_range(WALL_Z + 0.5, WALL_Z + 79.0)
			var py := lerpf(LAWN_Y, LAWN_Y + 3.15, sqrt(rng.randf()))
			clump.call(Vector3(s * (CLUB_W - 0.02), py, pz), Vector3(0.18, rng.randf_range(0.4, 0.85), rng.randf_range(0.6, 1.4)))


# --- Street -----------------------------------------------------------------------

func _build_street() -> void:
	# Pavements with kerbs on both sides of the street and along the side street.
	var kerb := 0.12
	_pave_t.append(Transform3D(Basis.from_scale(Vector3(900.0, kerb, ROAD_NEAR_Z - WALL_Z - 0.6 + 0.6)), Vector3(0, STREET_Y + kerb * 0.5, (WALL_Z + ROAD_NEAR_Z) * 0.5 - 0.3)))
	_pave_t.append(Transform3D(Basis.from_scale(Vector3(900.0, kerb, ROAD_FAR_Z - ROW_A_Z + 0.4)), Vector3(0, STREET_Y + kerb * 0.5, (ROAD_FAR_Z + ROW_A_Z) * 0.5 - 0.2)))
	for sx in [SIDE_STREET.x + 0.8, SIDE_STREET.y - 0.8]:
		_pave_t.append(Transform3D(Basis.from_scale(Vector3(1.6, kerb, 400.0)), Vector3(sx, STREET_Y + kerb * 0.5, ROW_A_Z - 200.0)))
	# Road markings: a dashed centre line, double yellow lines, a zebra crossing.
	var mid := (ROAD_NEAR_Z + ROAD_FAR_Z) * 0.5
	var white := Color(0.82, 0.82, 0.8)
	var yellow := Color(0.85, 0.7, 0.2)
	var x := -150.0
	while x < 150.0:
		if absf(x + 2.0) > 6.0:
			_bx(_street_t, _street_c, Vector3(3.0, 0.02, 0.12), Vector3(x, STREET_Y + 0.01, mid), white)
		x += 7.0
	for z in [ROAD_NEAR_Z - 0.25, ROAD_NEAR_Z - 0.42, ROAD_FAR_Z + 0.25, ROAD_FAR_Z + 0.42]:
		for seg in [Vector2(-150.0, -9.0), Vector2(5.0, 150.0)]:
			_bx(_street_t, _street_c, Vector3(seg.y - seg.x, 0.02, 0.08), Vector3((seg.x + seg.y) * 0.5, STREET_Y + 0.01, z), yellow)
	for k in 8:
		_bx(_street_t, _street_c, Vector3(3.0, 0.02, 0.5), Vector3(-2.0, STREET_Y + 0.01, ROAD_NEAR_Z - 0.5 - k * 1.05), white)
	# Belisha beacons: striped poles with blinking amber globes at the crossing.
	for z in [ROAD_NEAR_Z + 0.4, ROAD_FAR_Z - 0.4]:
		for k in 6:
			_cyl_t.append(Transform3D(Basis.from_scale(Vector3(0.07, 0.4, 0.07)), Vector3(-3.8, STREET_Y + kerb + 0.2 + k * 0.4, z)))
			_cyl_c.append(Color(0.05, 0.05, 0.05) if k % 2 == 0 else Color(0.9, 0.9, 0.88))
		_globe_t.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.2), Vector3(-3.8, STREET_Y + kerb + 2.6, z)))
		_globe_c.append(Color(1.0, 0.6, 0.12, 0.0))
	# Lamp posts along both pavements, down the side street and in the club grounds.
	x = -105.0
	while x <= 105.0:
		_lamp(Vector3(x, STREET_Y + kerb, ROAD_NEAR_Z + 0.5), 0.0)
		var xf := x - 7.0
		if xf < SIDE_STREET.x - 1.0 or xf > SIDE_STREET.y + 1.0:
			_lamp(Vector3(xf, STREET_Y + kerb, ROAD_FAR_Z - 0.5), 0.0)
		x += 14.0
	var z := ROW_A_Z - 8.0
	while z > -230.0:
		_lamp(Vector3(SIDE_STREET.x + 0.6, STREET_Y + kerb, z), PI * 0.5)
		_lamp(Vector3(SIDE_STREET.y - 0.6, STREET_Y + kerb, z - 7.0), PI * 0.5)
		z -= 14.0
	for s in [-1.0, 1.0]:
		_lamp(Vector3(s * 14.0, LAWN_Y + 0.06, WALL_Z + 1.3), 0.0)
		for lz in [-6.0, 10.0, 24.0]:
			_lamp(Vector3(s * 17.0, LAWN_Y, lz), PI * 0.5)
	# A red telephone box and a pillar box on the near pavement.
	var pb := Vector3(-6.5, STREET_Y + kerb, WALL_Z - 1.6)
	_bx(_street_t, _street_c, Vector3(0.92, 2.35, 0.92), pb + Vector3(0, 1.175, 0), RED)
	_bx(_street_t, _street_c, Vector3(0.96, 1.5, 0.74), pb + Vector3(0, 1.25, 0), Color(0.62, 0.66, 0.66))
	_bx(_street_t, _street_c, Vector3(0.74, 1.5, 0.96), pb + Vector3(0, 1.25, 0), Color(0.62, 0.66, 0.66))
	_bx(_street_t, _street_c, Vector3(0.98, 0.16, 0.98), pb + Vector3(0, 2.15, 0), Color(0.92, 0.9, 0.84))
	_bx(_street_t, _street_c, Vector3(1.04, 0.14, 1.04), pb + Vector3(0, 2.42, 0), RED)
	_bx(_street_t, _street_c, Vector3(0.7, 0.16, 0.7), pb + Vector3(0, 2.56, 0), RED)
	_cyl_t.append(Transform3D(Basis.from_scale(Vector3(0.26, 1.3, 0.26)), Vector3(4.2, STREET_Y + kerb + 0.65, ROAD_NEAR_Z + 0.6)))
	_cyl_c.append(RED)
	_globe_t.append(Transform3D(Basis.from_scale(Vector3(0.27, 0.16, 0.27)), Vector3(4.2, STREET_Y + kerb + 1.3, ROAD_NEAR_Z + 0.6)))
	_globe_c.append(Color(0.5, 0.05, 0.04, 0.5))
	# Bollards at the corners of the side street.
	for bx in [SIDE_STREET.x + 0.4, SIDE_STREET.y - 0.4]:
		for k in 3:
			_cyl_t.append(Transform3D(Basis.from_scale(Vector3(0.1, 0.9, 0.1)), Vector3(bx, STREET_Y + kerb + 0.45, ROAD_FAR_Z - 0.4 - k * 1.2)))
			_cyl_c.append(IRON)
	# Puddles on the road and pavements.
	for i in 18:
		var p := Vector3(rng.randf_range(-40.0, 40.0), STREET_Y + 0.006, rng.randf_range(ROAD_FAR_Z + 0.3, ROAD_NEAR_Z - 0.3))
		if i % 3 == 0:
			p = Vector3(rng.randf_range(-40.0, 40.0), STREET_Y + kerb + 0.006, rng.randf_range(ROAD_FAR_Z - 2.6, ROAD_FAR_Z - 0.6))
		_puddle_t.append(Transform3D(Basis(Vector3.UP, rng.randf() * PI) * Basis.from_scale(Vector3(rng.randf_range(0.5, 1.8), 0.01, rng.randf_range(0.3, 0.8))), p))


## A Victorian cast-iron street lamp with a glowing lantern.
func _lamp(p: Vector3, yaw: float) -> void:
	var o := Transform3D(Basis(Vector3.UP, yaw), p)
	var part := func(size: Vector3, at: Vector3) -> void:
		_iron_t.append(o * Transform3D(Basis.from_scale(size), at))
	part.call(Vector3(0.34, 0.7, 0.34), Vector3(0, 0.35, 0))
	_cyl_t.append(o * Transform3D(Basis.from_scale(Vector3(0.065, 3.3, 0.065)), Vector3(0, 2.3, 0)))
	_cyl_c.append(IRON)
	part.call(Vector3(0.2, 0.12, 0.2), Vector3(0, 3.3, 0))
	part.call(Vector3(0.75, 0.05, 0.05), Vector3(0, 3.6, 0))
	part.call(Vector3(0.3, 0.07, 0.3), Vector3(0, 3.98, 0))
	part.call(Vector3(0.48, 0.07, 0.48), Vector3(0, 4.55, 0))
	part.call(Vector3(0.22, 0.16, 0.22), Vector3(0, 4.66, 0))
	part.call(Vector3(0.05, 0.16, 0.05), Vector3(0, 4.8, 0))
	_glow_t.append(o * Transform3D(Basis.from_scale(Vector3(0.36, 0.52, 0.36)), Vector3(0, 4.27, 0)))
	_glow_c.append(Color(LAMP_GLOW, 1.0))
	_halo_t.append(Transform3D(Basis.from_scale(Vector3.ONE * 2.4), o * Vector3(0, 4.27, 0)))


# --- Town -------------------------------------------------------------------------

func _build_town() -> void:
	var up := STREET_Y
	# Across the street: two- and three-storey terraces with a pub on the side-street corner.
	var row_a := Transform3D(Basis.IDENTITY, Vector3(-158.4, up, ROW_A_Z))
	_terrace(row_a, 66, 9.0, 2, 3, true)
	_house(Transform3D(Basis.IDENTITY, Vector3(0, up, ROW_A_Z)), 0.0, 3 * BAY, 9.0, 3, BRICKS[2], SLATES[0], false)
	_house(Transform3D(Basis.IDENTITY, Vector3(0, up, ROW_A_Z)), 3 * BAY, SIDE_STREET.x - 3 * BAY, 9.0, 3, BRICKS[3], SLATES[1], false)
	_terrace(Transform3D(Basis.IDENTITY, Vector3(SIDE_STREET.y, up, ROW_A_Z)), 58, 9.0, 2, 3, true)
	_pub(Vector3(3 * BAY, up, ROW_A_Z), SIDE_STREET.x - 3 * BAY)
	_shop(Vector3(-4.0 * BAY, up, ROW_A_Z), 2 * BAY, Color(0.36, 0.08, 0.1))
	_shop(Vector3(-11.0 * BAY, up, ROW_A_Z), 2 * BAY, Color(0.08, 0.14, 0.3))
	_shop(Vector3(10.0 * BAY, up, ROW_A_Z), 3 * BAY, Color(0.1, 0.24, 0.17))
	# On our side of the street, beyond the club walls (their backs face the club).
	_terrace(Transform3D(Basis(Vector3.UP, PI), Vector3(-26.4, up, WALL_Z - 0.6)), 55, 9.0, 3, 3, false)
	_terrace(Transform3D(Basis(Vector3.UP, PI), Vector3(158.4, up, WALL_Z - 0.6)), 55, 9.0, 3, 3, false)
	# Rows running beside the club, gardens between them and the club walls.
	_terrace(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-43.2, up, -14.4)), 30, 9.0, 3, 4, false)
	_terrace(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(43.2, up, 57.6)), 30, 9.0, 3, 4, false)
	# Deeper rows behind, taller mansion blocks, each a little further into the mist.
	var gaps := [[-158.4, SIDE_STREET.x], [SIDE_STREET.y, 158.4]]
	for row in [[-56.0, 10.0, 3, 4], [-78.0, 10.0, 3, 5], [-100.0, 12.0, 4, 5]]:
		for g in gaps:
			var x0: float = g[0]
			var x1: float = g[1]
			if row[0] == -78.0 and x0 > 0.0:
				# Leave room for the church.
				_terrace(Transform3D(Basis.IDENTITY, Vector3(x0, up, row[0])), 2, row[1], row[2], row[3], false)
				_terrace(Transform3D(Basis.IDENTITY, Vector3(33.6, up, row[0])), roundi((x1 - 33.6) / BAY), row[1], row[2], row[3], false)
				continue
			_terrace(Transform3D(Basis.IDENTITY, Vector3(x0, up, row[0])), roundi((x1 - x0) / BAY), row[1], row[2], row[3], false)
	# Far town: blocks with flat roofs, mostly lost in the fog.
	for i in 70:
		var w := rng.randf_range(14.0, 32.0)
		var d := rng.randf_range(12.0, 24.0)
		var h := rng.randf_range(12.0, 26.0)
		var p := Vector3(rng.randf_range(-260.0, 260.0), up - 0.5 + h * 0.5, rng.randf_range(-125.0, -280.0))
		_fac_t.append(Transform3D(Basis.from_scale(Vector3(w, h, d)), p))
		_fac_c.append(Color(BRICKS[rng.randi() % BRICKS.size()], 1.0))


## A run of terraced houses along local +x from the frame origin, fronts facing local +z.
func _terrace(frame: Transform3D, bays_total: int, depth: float, fmin: int, fmax: int, doors: bool) -> void:
	var b := 0
	var run := 0
	var floors := fmin
	var col: Color = BRICKS[0]
	var slate: Color = SLATES[0]
	while b < bays_total:
		if run <= 0:
			run = rng.randi_range(3, 7)
			floors = rng.randi_range(fmin, fmax)
			col = BRICKS[rng.randi() % BRICKS.size()]
			slate = SLATES[rng.randi() % SLATES.size()]
		var n := 2 if rng.randf() < 0.75 else 3
		var left := bays_total - b
		if left <= 3:
			n = left
		elif left - n == 1:
			n = 5 - n
		var tint := col.lerp(Color(0.45, 0.42, 0.4), rng.randf() * 0.18)
		_house(frame, b * BAY, n * BAY, depth, floors, tint, slate, doors)
		b += n
		run -= 1


## One house: brick body with the window grid (facade shader), a stone cornice, a slate
## roof, a chimney stack with pots on the party wall, and a front door.
func _house(frame: Transform3D, x: float, w: float, depth: float, floors: int, col: Color, slate: Color, door: bool) -> void:
	var top := floors * FLOOR_H + 0.7
	var bottom := LAWN_Y - STREET_Y - 0.1
	var h := top - bottom
	var add := func(arr_t: Array[Transform3D], arr_c: Array[Color], basis: Basis, at: Vector3, c: Color) -> void:
		arr_t.append(Transform3D(frame.basis * basis, frame * at))
		arr_c.append(c)
	add.call(_fac_t, _fac_c, Basis.from_scale(Vector3(w, h, depth)), Vector3(x + w * 0.5, bottom + h * 0.5, -depth * 0.5), Color(col, 1.0))
	add.call(_fac_t, _fac_c, Basis.from_scale(Vector3(w, 0.26, 0.32)), Vector3(x + w * 0.5, top - 0.32, 0.1), Color(STONE.lightened(0.15), 0.0))
	add.call(_fac_t, _fac_c, Basis.from_scale(Vector3(w, 0.16, 0.18)), Vector3(x + w * 0.5, FLOOR_H - 0.05, 0.05), Color(STONE.lightened(0.1), 0.0))
	var rh := rng.randf_range(1.9, 2.7)
	add.call(_roof_t, _roof_c, Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(depth - 0.3, rh, w)), Vector3(x + w * 0.5, top - 0.25 + rh * 0.5, -depth * 0.5), slate)
	var stack_h := rh + 1.1
	add.call(_fac_t, _fac_c, Basis.from_scale(Vector3(1.3, stack_h, 0.7)), Vector3(x, top - 0.3 + stack_h * 0.5, -depth * 0.5), Color(col.darkened(0.12), 0.0))
	add.call(_fac_t, _fac_c, Basis.from_scale(Vector3(1.42, 0.12, 0.82)), Vector3(x, top - 0.3 + stack_h, -depth * 0.5), Color(STONE, 0.0))
	for k in 3:
		add.call(_cyl_t, _cyl_c, Basis.from_scale(Vector3(0.12, 0.5, 0.12)), Vector3(x - 0.4 + k * 0.4, top - 0.3 + stack_h + 0.3, -depth * 0.5), Color(0.6, 0.36, 0.26))
	if door:
		var dc: Color = DOORS[rng.randi() % DOORS.size()]
		add.call(_street_t, _street_c, Basis.from_scale(Vector3(1.0, 2.3, 0.1)), Vector3(x + BAY * 0.5, 1.15, 0.05), dc)
		add.call(_street_t, _street_c, Basis.from_scale(Vector3(1.3, 0.3, 0.12)), Vector3(x + BAY * 0.5, 2.45, 0.06), Color(0.86, 0.84, 0.78))
		add.call(_street_t, _street_c, Basis.from_scale(Vector3(1.5, 0.16, 0.6)), Vector3(x + BAY * 0.5, 0.08, 0.3), STONE)


## The corner pub: dark green front, a black fascia with gold lines, warm windows,
## hanging baskets and a sign on a bracket, round the corner into the side street.
func _pub(p: Vector3, w: float) -> void:
	var green := Color(0.06, 0.17, 0.12)
	var gold := Color(0.78, 0.62, 0.3)
	_bx(_street_t, _street_c, Vector3(w, 3.4, 0.3), p + Vector3(w * 0.5, 1.7, 0.15), green)
	_bx(_street_t, _street_c, Vector3(w + 0.1, 0.6, 0.42), p + Vector3(w * 0.5, 3.1, 0.2), Color(0.04, 0.04, 0.045))
	for gy in [2.8, 3.4]:
		_bx(_street_t, _street_c, Vector3(w + 0.12, 0.05, 0.44), p + Vector3(w * 0.5, gy, 0.2), gold)
	_bx(_street_t, _street_c, Vector3(0.3, 3.4, 8.6), p + Vector3(w + 0.15, 1.7, -4.3), green)
	_bx(_street_t, _street_c, Vector3(0.42, 0.6, 8.7), p + Vector3(w + 0.2, 3.1, -4.3), Color(0.04, 0.04, 0.045))
	for k in 2:
		_glow_t.append(Transform3D(Basis.from_scale(Vector3(w * 0.32, 1.7, 0.32)), p + Vector3(w * (0.22 + k * 0.56), 1.55, 0.16)))
		_glow_c.append(Color(WINDOW_GLOW, 0.5))
	_glow_t.append(Transform3D(Basis.from_scale(Vector3(0.32, 1.7, 3.0)), p + Vector3(w + 0.16, 1.55, -5.0)))
	_glow_c.append(Color(WINDOW_GLOW, 0.5))
	# Sign on a bracket at the corner, and hanging baskets.
	_iron_t.append(Transform3D(Basis.from_scale(Vector3(1.1, 0.05, 0.05)), p + Vector3(w + 0.7, 4.4, 0.3)))
	_bx(_street_t, _street_c, Vector3(0.06, 1.0, 0.8), p + Vector3(w + 1.0, 3.8, 0.3), Color(0.45, 0.08, 0.08))
	_bx(_street_t, _street_c, Vector3(0.08, 1.1, 0.9), p + Vector3(w + 1.0, 3.8, 0.3), gold.darkened(0.3))
	for k in 3:
		var bp := p + Vector3(w * (0.15 + k * 0.35), 3.9, 0.55)
		for j in 6:
			_bloom_t.append(Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.12, 0.2)), bp + Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.2, 0.1), rng.randf_range(-0.15, 0.15))))
			_bloom_c.append([Color(0.9, 0.2, 0.25), Color(0.95, 0.9, 0.95), Color(0.3, 0.5, 0.2)][j % 3])


func _shop(p: Vector3, w: float, fascia: Color) -> void:
	_bx(_street_t, _street_c, Vector3(w, 3.3, 0.24), p + Vector3(w * 0.5, 1.65, 0.12), fascia.darkened(0.3))
	_bx(_street_t, _street_c, Vector3(w + 0.06, 0.55, 0.36), p + Vector3(w * 0.5, 3.05, 0.18), fascia)
	_glow_t.append(Transform3D(Basis.from_scale(Vector3(w * 0.62, 1.8, 0.28)), p + Vector3(w * 0.42, 1.5, 0.13)))
	_glow_c.append(Color(WINDOW_GLOW.lerp(Color(1, 0.95, 0.85), rng.randf() * 0.5), 0.5))
	# Striped awning.
	_bx(_street_t, _street_c, Vector3(w - 0.2, 0.08, 1.1), p + Vector3(w * 0.5, 2.68, 0.7), fascia.lightened(0.25))


func _build_landmarks() -> void:
	var up := STREET_Y
	var stone := Color(0.6, 0.6, 0.57, 0.0)
	var dark_slate := Color(0.26, 0.28, 0.31)
	# A church: nave with a steep roof, a square tower with pinnacles and a slender spire.
	var cx := 28.8
	_fac_t.append(Transform3D(Basis.from_scale(Vector3(9.0, 11.0, 20.0)), Vector3(cx, up + 5.0, -89.5)))
	_fac_c.append(stone)
	_roof_t.append(Transform3D(Basis.from_scale(Vector3(9.8, 5.5, 20.4)), Vector3(cx, up + 10.5 + 2.75, -89.5)))
	_roof_c.append(dark_slate)
	_fac_t.append(Transform3D(Basis.from_scale(Vector3(5.6, 16.0, 5.6)), Vector3(cx, up + 7.5, -78.5)))
	_fac_c.append(stone)
	_fac_t.append(Transform3D(Basis.from_scale(Vector3(6.2, 0.6, 6.2)), Vector3(cx, up + 15.8, -78.5)))
	_fac_c.append(stone)
	_cone_t.append(Transform3D(Basis.from_scale(Vector3(2.5, 14.0, 2.5)), Vector3(cx, up + 16.1 + 7.0, -78.5)))
	_cone_c.append(dark_slate)
	for dx in [-2.7, 2.7]:
		for dz in [-2.7, 2.7]:
			_cone_t.append(Transform3D(Basis.from_scale(Vector3(0.32, 2.6, 0.32)), Vector3(cx + dx, up + 16.1 + 1.3, -78.5 + dz)))
			_cone_c.append(stone)

	# A clock tower in the manner of Westminster: a tall shaft, the clock stage with four
	# lit faces, a belfry and a steep iron roof with a needle.
	var tx := -32.0
	var tz := -94.0
	var tstone := Color(0.66, 0.61, 0.49, 0.0)
	_fac_t.append(Transform3D(Basis.from_scale(Vector3(7.0, 25.0, 7.0)), Vector3(tx, up + 12.0, tz)))
	_fac_c.append(tstone)
	for dx in [-3.4, 3.4]:
		for dz in [-3.4, 3.4]:
			_fac_t.append(Transform3D(Basis.from_scale(Vector3(0.9, 25.0, 0.9)), Vector3(tx + dx, up + 12.0, tz + dz)))
			_fac_c.append(tstone.darkened(0.06))
	var cy := up + 24.5 + 3.6
	_fac_t.append(Transform3D(Basis.from_scale(Vector3(8.6, 7.2, 8.6)), Vector3(tx, cy, tz)))
	_fac_c.append(tstone)
	for k in 4:
		var yaw := k * PI * 0.5
		var face := Basis(Vector3.UP, yaw)
		var n := face * Vector3(0, 0, 1)
		_disc_t.append(Transform3D(face * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(2.7, 0.1, 2.7)), Vector3(tx, cy, tz) + n * 4.3))
		_disc_c.append(Color(0.96, 0.93, 0.8, 0.5))
		# Hands at ten to nine... it is always early at the club.
		for hand in [[1.6, 0.22, -1.1], [2.2, 0.15, 2.0]]:
			var hb: Basis = face * Basis(Vector3(0, 0, 1), hand[2]) * Basis.from_scale(Vector3(hand[1], hand[0], 0.06))
			_fac_t.append(Transform3D(hb, Vector3(tx, cy, tz) + n * 4.38 + face * (Basis(Vector3(0, 0, 1), hand[2]) * Vector3(0, hand[0] * 0.5, 0))))
			_fac_c.append(Color(0.08, 0.08, 0.08, 0.0))
		_cone_t.append(Transform3D(Basis.from_scale(Vector3(0.4, 3.2, 0.4)), Vector3(tx, cy + 3.6 + 1.6, tz) + face * Vector3(4.0, 0, 4.0)))
		_cone_c.append(tstone)
	_fac_t.append(Transform3D(Basis.from_scale(Vector3(7.2, 3.8, 7.2)), Vector3(tx, cy + 3.6 + 1.9, tz)))
	_fac_c.append(tstone.darkened(0.08))
	var roof_y := cy + 3.6 + 3.8
	_cone_t.append(Transform3D(Basis(Vector3.UP, PI * 0.25) * Basis.from_scale(Vector3(5.2, 10.0, 5.2)), Vector3(tx, roof_y + 5.0, tz)))
	_cone_c.append(Color(0.2, 0.24, 0.25))
	_cone_t.append(Transform3D(Basis.from_scale(Vector3(0.35, 5.0, 0.35)), Vector3(tx, roof_y + 10.0 + 2.0, tz)))
	_cone_c.append(Color(0.2, 0.24, 0.25))
	# A long Gothic hall beside it, with pinnacles along the roof line.
	_fac_t.append(Transform3D(Basis.from_scale(Vector3(40.0, 15.0, 8.0)), Vector3(tx - 24.0, up + 7.0, tz)))
	_fac_c.append(Color(0.66, 0.61, 0.49, 1.0))
	_roof_t.append(Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(7.6, 3.5, 40.0)), Vector3(tx - 24.0, up + 14.5 + 1.75, tz)))
	_roof_c.append(Color(0.24, 0.27, 0.28))
	var px := tx - 43.5
	while px < tx - 4.0:
		for dz in [-4.0, 4.0]:
			_cone_t.append(Transform3D(Basis.from_scale(Vector3(0.3, 2.4, 0.3)), Vector3(px, up + 14.5 + 1.2, tz + dz)))
			_cone_c.append(tstone)
		px += 3.0
	# A great dome far off over the rooftops.
	var dome := Vector3(62.0, up, -170.0)
	_fac_t.append(Transform3D(Basis.from_scale(Vector3(44.0, 20.0, 30.0)), dome + Vector3(0, 9.5, 0)))
	_fac_c.append(Color(0.7, 0.68, 0.62, 1.0))
	_cyl_t.append(Transform3D(Basis.from_scale(Vector3(10.0, 9.0, 10.0)), dome + Vector3(0, 19.5 + 4.5, 0)))
	_cyl_c.append(Color(0.7, 0.68, 0.62))
	_globe_t.append(Transform3D(Basis.from_scale(Vector3(9.6, 9.6, 9.6)), dome + Vector3(0, 28.5, 0)))
	_globe_c.append(Color(0.5, 0.53, 0.53, 0.6))
	_cyl_t.append(Transform3D(Basis.from_scale(Vector3(1.6, 4.0, 1.6)), dome + Vector3(0, 38.5 + 2.0, 0)))
	_cyl_c.append(Color(0.7, 0.68, 0.62))
	_cone_t.append(Transform3D(Basis.from_scale(Vector3(1.4, 3.0, 1.4)), dome + Vector3(0, 42.5 + 1.5, 0)))
	_cone_c.append(Color(0.5, 0.53, 0.53))


# --- Court ------------------------------------------------------------------------

func _build_court_surrounds() -> void:
	# Dark green windscreen behind the far baseline, low walls along the sides (purple
	# trim, as at the old club), a low barrier at the near end.
	var g := CLUB_GREEN
	var screen_h := 2.2
	_bx(_near_t, _near_c, Vector3(HX * 2.0 + 0.12, screen_h, 0.12), Vector3(0, screen_h * 0.5, -HZ), g)
	_bx(_near_t, _near_c, Vector3(HX * 2.0 + 0.14, 0.06, 0.15), Vector3(0, screen_h + 0.03, -HZ), g.darkened(0.3))
	var side_len := HZ * 2.0 + 1.5
	for s in [-1.0, 1.0]:
		_bx(_near_t, _near_c, Vector3(0.12, 1.1, side_len), Vector3(s * HX, 0.55, 0.75), g)
		_bx(_near_t, _near_c, Vector3(0.15, 0.05, side_len), Vector3(s * HX, 1.12, 0.75), PURPLE)
		# The far screen wraps round the corners for a few metres.
		_bx(_near_t, _near_c, Vector3(0.12, screen_h, 3.0), Vector3(s * HX, screen_h * 0.5, -HZ + 1.5), g)
	_bx(_near_t, _near_c, Vector3(HX * 2.0, 0.8, 0.12), Vector3(0, 0.4, HZ + 1.5), g)
	_bx(_near_t, _near_c, Vector3(HX * 2.0, 0.05, 0.15), Vector3(0, 0.82, HZ + 1.5), PURPLE)
	# A manual scoreboard standing behind the far screen.
	var sb := Vector3(5.2, 0.0, -HZ - 0.6)
	for lx in [-1.3, 1.3]:
		_iron_t.append(Transform3D(Basis.from_scale(Vector3(0.1, 2.2, 0.1)), sb + Vector3(lx, 1.1, 0)))
	_bx(_near_t, _near_c, Vector3(3.2, 1.35, 0.14), sb + Vector3(0, 2.75, 0), Color(0.05, 0.14, 0.1))
	for row in 2:
		var y := 3.1 - row * 0.5
		_bx(_near_t, _near_c, Vector3(1.4, 0.16, 0.16), sb + Vector3(-0.65, y, 0.01), CREAM)
		for k in 3:
			_bx(_near_t, _near_c, Vector3(0.2, 0.3, 0.16), sb + Vector3(0.45 + k * 0.32, y, 0.01), Color(0.95, 0.95, 0.9) if k < 2 else Color(0.9, 0.75, 0.3))
	# Painted name of the club behind each baseline.
	for end in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = "ROYAL ALBION\nLAWN TENNIS CLUB"
		label.font_size = 96
		label.pixel_size = 0.0052
		label.line_spacing = -18.0
		label.outline_size = 0
		label.modulate = Color(1, 1, 1, 0.5)
		label.shaded = false
		label.double_sided = false
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.rotation = Vector3(-PI * 0.5, 0.0 if end > 0.0 else PI, 0.0)
		label.position = Vector3(0, 0.04, end * (Court.HALF_LENGTH + 2.6))
		add_child(label)


func _build_stands() -> void:
	# Cream concrete stands with dark green seats on both sides, empty on a grey morning.
	_stand(1.0, 7, -15.0, 3.0)
	_stand(-1.0, 4, -15.0, 3.0)


func _stand(side: float, rows: int, z0: float, z1: float) -> void:
	var x0 := HX + 0.5
	var depth := 0.85
	var len := z1 - z0
	var zc := (z0 + z1) * 0.5
	var seat_c := Color(0.08, 0.27, 0.17)
	for r in rows:
		var y := 0.45 + r * 0.42
		var xc := side * (x0 + (r + 0.5) * depth)
		_bx(_near_t, _near_c, Vector3(depth, y, len), Vector3(xc, y * 0.5, zc), CREAM if r % 2 == 0 else CREAM.darkened(0.04))
		var z := z0 + 0.4
		while z < z1 - 0.3:
			if absf(z - zc) > 0.55:
				_bx(_near_t, _near_c, Vector3(0.42, 0.4, 0.44), Vector3(xc - side * 0.05, y + 0.2, z), seat_c)
				_bx(_near_t, _near_c, Vector3(0.06, 0.4, 0.44), Vector3(xc + side * 0.2, y + 0.55, z), seat_c)
			z += 0.56
		for ez in [z0 - 0.1, z1 + 0.1]:
			_bx(_near_t, _near_c, Vector3(depth, y + 1.0, 0.2), Vector3(xc, (y + 1.0) * 0.5, ez), CREAM.darkened(0.06))
	var top := 0.45 + rows * 0.42 + 1.4
	var xb := side * (x0 + rows * depth + 0.1)
	_bx(_near_t, _near_c, Vector3(0.2, top, len + 0.4), Vector3(xb, top * 0.5, zc), CREAM.darkened(0.06))
	_bx(_near_t, _near_c, Vector3(0.3, 0.12, len + 0.5), Vector3(xb, top + 0.06, zc), CLUB_GREEN)
	# Purple and green bunting along the back wall.
	var z := z0
	var k := 0
	while z < z1:
		_bx(_near_t, _near_c, Vector3(0.04, 0.35, 0.9), Vector3(xb - side * 0.13, top - 0.3, z + 0.45), PURPLE if k % 2 == 0 else CLUB_GREEN.lightened(0.15))
		z += 0.9
		k += 1


func _build_courtside() -> void:
	var frame := CLUB_GREEN
	var white := Color(0.93, 0.92, 0.88)
	# Umpire's chair by the net post, dark green with a cream seat.
	var ux := Court.NET_HALF_WIDTH + 1.35
	for lx in [-0.4, 0.4]:
		for lz in [-0.4, 0.4]:
			_bx(_near_t, _near_c, Vector3(0.07, 2.0, 0.07), Vector3(ux + lx, 1.0, lz), frame)
	for h in [0.7, 1.4]:
		for lz in [-0.4, 0.4]:
			_bx(_near_t, _near_c, Vector3(0.85, 0.05, 0.05), Vector3(ux, h, lz), frame)
	_bx(_near_t, _near_c, Vector3(0.95, 0.08, 0.95), Vector3(ux, 2.0, 0), frame)
	_bx(_near_t, _near_c, Vector3(0.62, 0.1, 0.6), Vector3(ux - 0.02, 2.12, 0), white)
	_bx(_near_t, _near_c, Vector3(0.08, 0.75, 0.6), Vector3(ux + 0.3, 2.5, 0), frame)
	for side in [-0.32, 0.32]:
		_bx(_near_t, _near_c, Vector3(0.55, 0.06, 0.06), Vector3(ux - 0.02, 2.4, side), frame)
	_bx(_near_t, _near_c, Vector3(0.5, 0.05, 0.6), Vector3(ux - 0.65, 1.15, 0), frame)
	for k in 5:
		_bx(_near_t, _near_c, Vector3(0.06, 0.04, 0.55), Vector3(ux + 0.55, 0.3 + k * 0.38, 0), frame)
	for lz in [-0.27, 0.27]:
		_bx(_near_t, _near_c, Vector3(0.04, 1.9, 0.04), Vector3(ux + 0.55, 0.95, lz), frame)

	# Players' chairs across the net: cream seats on green frames, towels in the club's
	# purple and green, drinks on a little table, racket bags.
	var bx := -(Court.NET_HALF_WIDTH + 1.35)
	for bz in [-1.3, 1.3]:
		var o := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(bx, 0, bz))
		var part := func(size: Vector3, at: Vector3, c: Color) -> void:
			_near_t.append(o * Transform3D(Basis.from_scale(size), at))
			_near_c.append(c)
		part.call(Vector3(0.52, 0.07, 0.5), Vector3(0, 0.46, 0), CREAM)
		part.call(Vector3(0.52, 0.55, 0.06), Vector3(0, 0.78, 0.24), CREAM)
		for lx in [-0.22, 0.22]:
			for lz in [-0.2, 0.2]:
				part.call(Vector3(0.045, 0.46, 0.045), Vector3(lx, 0.23, lz), frame)
		part.call(Vector3(0.5, 0.62, 0.1), Vector3(0.02, 0.74, 0.3), PURPLE if bz < 0.0 else Color(0.1, 0.4, 0.22))
		part.call(Vector3(0.32, 0.3, 0.9), Vector3(0.0, 0.15, -0.75), Color(0.12, 0.13, 0.16) if bz < 0.0 else Color(0.9, 0.9, 0.88))
	_bx(_near_t, _near_c, Vector3(0.5, 0.05, 0.6), Vector3(bx, 0.7, 0), white)
	_bx(_near_t, _near_c, Vector3(0.06, 0.7, 0.06), Vector3(bx, 0.35, 0), frame)
	for k in 4:
		_cyl_t.append(Transform3D(Basis.from_scale(Vector3(0.035, 0.24, 0.035)), Vector3(bx + (k % 2 - 0.5) * 0.2, 0.84, -0.18 + k * 0.12)))
		_cyl_c.append([Color(0.55, 0.85, 0.3), Color(0.98, 0.6, 0.2), Color(0.85, 0.92, 0.97), Color(0.55, 0.85, 0.3)][k])

	# Line judges' chairs at the far corners, cream with green legs.
	for s in [-1.0, 1.0]:
		var o := Transform3D(Basis.IDENTITY, Vector3(s * 6.6, 0, -HZ + 0.6))
		_near_t.append(o * Transform3D(Basis.from_scale(Vector3(0.45, 0.07, 0.45)), Vector3(0, 0.46, 0)))
		_near_c.append(CREAM)
		_near_t.append(o * Transform3D(Basis.from_scale(Vector3(0.45, 0.45, 0.06)), Vector3(0, 0.75, -0.21)))
		_near_c.append(CREAM)
		_near_t.append(o * Transform3D(Basis.from_scale(Vector3(0.36, 0.46, 0.36)), Vector3(0, 0.23, 0)))
		_near_c.append(frame)

	# Flower boxes with hydrangeas at the corners and beside the chairs.
	for spot in [Vector3(8.35, 0, -16.2), Vector3(-8.35, 0, -16.2), Vector3(8.35, 0, 2.9), Vector3(8.35, 0, -2.9),
			Vector3(-8.35, 0, 3.4), Vector3(-8.35, 0, -3.4), Vector3(8.35, 0, 18.0), Vector3(-8.35, 0, 18.0)]:
		_planter(spot)
	# A few balls by the far screen.
	for k in 5:
		_bloom_t.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.034), Vector3(rng.randf_range(-HX + 1.0, HX - 1.0), 0.034, rng.randf_range(-HZ + 0.3, -HZ + 1.2))))
		_bloom_c.append(Color(0.86, 0.95, 0.2))


func _planter(p: Vector3) -> void:
	_bx(_near_t, _near_c, Vector3(0.55, 0.45, 1.6), p + Vector3(0, 0.225, 0), CREAM)
	_bx(_near_t, _near_c, Vector3(0.6, 0.06, 1.65), p + Vector3(0, 0.45, 0), CLUB_GREEN)
	var bloom: Color = BLOOMS[rng.randi() % BLOOMS.size()]
	for k in 9:
		var q := p + Vector3(rng.randf_range(-0.12, 0.12), 0.58, -0.6 + k * 0.15)
		_bloom_t.append(Transform3D(Basis.from_scale(Vector3(0.24, 0.16, 0.2)), q + Vector3(0, -0.04, 0)))
		_bloom_c.append(Color(0.18, 0.32, 0.16))
		if k % 2 == 0:
			_bloom_t.append(Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.14, 0.19)), q + Vector3(0, 0.1, 0)))
			_bloom_c.append(bloom.lerp(BLOOMS[rng.randi() % BLOOMS.size()], 0.25))


# --- Trees and hedges -------------------------------------------------------------

func _build_greenery() -> void:
	var add_tree := func(p: Vector3, k: float) -> void:
		var h := 3.2 * k
		_trunk_t.append(Transform3D(Basis.from_scale(Vector3(k, k, k)), Vector3(p.x, p.y + h * 0.5, p.z)))
		var leaf: Color = PLANE_LEAVES[rng.randi() % PLANE_LEAVES.size()]
		for j in 4:
			var r := rng.randf_range(1.6, 2.3) * k
			var off := Vector3(rng.randf_range(-1.1, 1.1) * k, h + 0.4 + j * 0.85 * k, rng.randf_range(-1.1, 1.1) * k)
			_crown_t.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.85, r)), p + off))
			_crown_c.append(leaf.lerp(Color(0.42, 0.46, 0.32), rng.randf() * 0.3))
	# London planes along the club's side lawns and in the gardens beyond the walls.
	for s in [-1.0, 1.0]:
		var z := -18.0
		while z < 50.0:
			add_tree.call(Vector3(s * rng.randf_range(21.5, 23.5), LAWN_Y, z), rng.randf_range(1.05, 1.35))
			z += rng.randf_range(8.0, 11.0)
		z = -10.0
		while z < 55.0:
			add_tree.call(Vector3(s * rng.randf_range(29.0, 32.0), LAWN_Y, z), rng.randf_range(1.0, 1.4))
			z += rng.randf_range(9.0, 13.0)
		# Street trees at the corners of the club, framing the street.
		add_tree.call(Vector3(s * 24.5, STREET_Y + 0.12, WALL_Z - 1.8), 1.3)
	for x in [-31.0, 37.0, -52.0, 58.0]:
		add_tree.call(Vector3(x, STREET_Y + 0.12, ROAD_FAR_Z - 1.6), 1.15)
	for i in 10:
		add_tree.call(Vector3(rng.randf_range(-24.0, 24.0), LAWN_Y, rng.randf_range(32.0, 60.0)), rng.randf_range(1.0, 1.4))
	# Clipped box hedges behind the near end, and along the side paths.
	var hedge := Color(0.13, 0.27, 0.13)
	for s in [-1.0, 1.0]:
		_bx(_near_t, _near_c, Vector3(9.0, 0.9, 0.9), Vector3(s * 7.5, LAWN_Y + 0.45, 23.4), hedge)
		_bx(_near_t, _near_c, Vector3(0.9, 0.9, 30.0), Vector3(s * 16.2, LAWN_Y + 0.45, 6.0), hedge)
	# Flower beds along the hedges.
	for s in [-1.0, 1.0]:
		for k in 40:
			var q := Vector3(s * rng.randf_range(15.2, 15.6), LAWN_Y + 0.15, rng.randf_range(-8.5, 20.5))
			_bloom_t.append(Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.14, 0.22)), q))
			_bloom_c.append(BLOOMS[rng.randi() % BLOOMS.size()] if k % 3 != 0 else Color(0.2, 0.34, 0.17))


# --- Vehicles ---------------------------------------------------------------------

func _build_vehicles() -> void:
	var near_lane := ROAD_NEAR_Z - 2.1
	var far_lane := ROAD_FAR_Z + 2.1
	# They drive on the left: westbound (-x) in the near lane, eastbound in the far lane.
	_bus(Vector3(25.0, STREET_Y, near_lane), -4.2)
	_cab(Vector3(85.0, STREET_Y, near_lane), -4.2)
	_cab(Vector3(-40.0, STREET_Y, far_lane), 6.5)
	_cab(Vector3(70.0, STREET_Y, far_lane), 6.5)


func _vehicle(p: Vector3, speed: float, boxes: Array, wheels: Array) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = 0.0 if speed > 0.0 else PI
	v.set_meta("speed", speed)
	add_child(v)
	var t: Array[Transform3D] = []
	var c: Array[Color] = []
	for b in boxes:
		t.append(Transform3D(Basis.from_scale(b[0]), b[1]))
		c.append(b[2])
	_mm(_unit_box, _tinted(), t, c, v).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wt: Array[Transform3D] = []
	for w in wheels:
		var wp: Vector3 = w
		wt.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(wp.y, 0.28, wp.y)), Vector3(wp.x, wp.y, 0.0)))
		wt.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(wp.y, 0.28, wp.y)), Vector3(wp.x, wp.y, 0.0)))
	# Wheels on both sides.
	var half: float = wheels[0].z
	for i in wt.size():
		wt[i].origin.z = half if i % 2 == 0 else -half
	_mm(_cyl, _plain(Color(0.05, 0.05, 0.05)), wt, [], v).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vehicles.append(v)


## A red double-decker, front at local +x.
func _bus(p: Vector3, speed: float) -> void:
	var glass := Color(0.16, 0.17, 0.19)
	var lit := Color(0.55, 0.47, 0.34)
	_vehicle(p, speed, [
		[Vector3(9.4, 1.95, 2.5), Vector3(0, 1.4, 0), RED],
		[Vector3(9.4, 1.85, 2.5), Vector3(0, 3.33, 0), RED],
		[Vector3(9.3, 0.14, 2.4), Vector3(0, 4.3, 0), RED.darkened(0.1)],
		[Vector3(9.42, 0.1, 2.52), Vector3(0, 2.4, 0), CREAM],
		[Vector3(8.0, 0.85, 2.52), Vector3(-0.5, 1.8, 0), lit],
		[Vector3(9.0, 0.8, 2.52), Vector3(0, 3.42, 0), lit],
		[Vector3(9.43, 0.8, 2.2), Vector3(0, 3.42, 0), glass],
		[Vector3(9.43, 0.85, 1.0), Vector3(0, 1.8, -0.6), glass],
		[Vector3(9.44, 0.26, 1.2), Vector3(0, 2.72, 0.3), Color(0.95, 0.9, 0.6)],
		[Vector3(9.44, 0.2, 0.3), Vector3(0, 0.85, 0.95), Color(1.0, 0.97, 0.85)],
		[Vector3(9.44, 0.2, 0.3), Vector3(0, 0.85, -0.95), Color(1.0, 0.97, 0.85)],
		[Vector3(9.0, 0.3, 2.3), Vector3(0, 0.38, 0), Color(0.08, 0.08, 0.08)],
	], [Vector3(3.2, 0.52, 1.1), Vector3(-2.7, 0.52, 1.1)])


## A black cab, front at local +x.
func _cab(p: Vector3, speed: float) -> void:
	var black := Color(0.04, 0.04, 0.05)
	var glass := Color(0.24, 0.26, 0.29)
	_vehicle(p, speed, [
		[Vector3(4.4, 0.8, 1.75), Vector3(0, 0.78, 0), black],
		[Vector3(2.6, 0.78, 1.66), Vector3(-0.35, 1.56, 0), black],
		[Vector3(2.3, 0.46, 1.68), Vector3(-0.35, 1.58, 0), glass],
		[Vector3(2.62, 0.46, 1.4), Vector3(-0.35, 1.58, 0), glass],
		[Vector3(0.3, 0.14, 0.2), Vector3(0.6, 2.02, 0), Color(1.0, 0.72, 0.2)],
		[Vector3(4.42, 0.15, 0.25), Vector3(0, 0.9, 0.6), Color(1.0, 0.97, 0.85)],
		[Vector3(4.42, 0.15, 0.25), Vector3(0, 0.9, -0.6), Color(0.6, 0.05, 0.05)],
		[Vector3(4.5, 0.12, 1.8), Vector3(0, 0.42, 0), Color(0.25, 0.25, 0.26)],
	], [Vector3(1.35, 0.36, 0.78), Vector3(-1.35, 0.36, 0.78)])


# --- Drizzle and crows ------------------------------------------------------------

func _build_drizzle() -> void:
	# Fine rain streaks falling on the GPU: each instance wraps round in a 16 m column.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float fall_h = 16.0;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float y = mod(o.y - TIME * 7.0, fall_h);
	float dy = y - o.y;
	VERTEX.y += dy;
	VERTEX.x -= dy * 0.12;
}
void fragment() {
	ALBEDO = vec3(0.86, 0.89, 0.92);
	ALPHA = 0.2 * (1.0 - abs(UV.y - 0.5) * 2.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.5)
	var t: Array[Transform3D] = []
	for i in 700:
		t.append(Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(0.0, 16.0), rng.randf_range(-24.0, 22.0))))
	var mmi := _mm(q, m, t)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-22, -1, -26), Vector3(44, 18, 50))
	_extras.append(mmi)


func _build_flock() -> void:
	# A few crows: wings are mirrored instances that flap in the vertex shader.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float a = sin(TIME * 8.0 + o.x * 0.3 + o.z * 1.7) * 0.6;
	vec3 v = VERTEX + vec3(0.4, 0.0, 0.0);
	VERTEX = vec3(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a), v.z);
}
void fragment() {
	ALBEDO = vec3(0.07, 0.07, 0.08);
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var wing := BoxMesh.new()
	wing.size = Vector3(0.8, 0.04, 0.3)
	var t: Array[Transform3D] = []
	for i in 9:
		var p := Vector3(-absf(i - 4) * 2.4 + rng.randf_range(-0.6, 0.6), (i % 3) * 0.8 + rng.randf_range(-0.3, 0.3), (i - 4) * 2.1)
		t.append(Transform3D(Basis.IDENTITY, p))
		t.append(Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), p))
	_flock = _mm(wing, m, t)
	_flock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flock.visible = false


func _update_flock(delta: float) -> void:
	if not _flock.visible:
		_flock_timer -= delta
		if _flock_timer <= 0.0:
			_flock.visible = true
			_flock.position = Vector3(-60.0, rng.randf_range(12.0, 18.0), rng.randf_range(-50.0, -30.0))
		return
	_flock.position.x += 6.5 * delta
	_flock.position.y += sin(_t * 0.7) * 0.4 * delta
	if _flock.position.x > 60.0:
		_flock.visible = false
		_flock_timer = rng.randf_range(14.0, 28.0)


# --- Building the MultiMeshes -----------------------------------------------------

func _flush() -> void:
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm(_unit_box, _tinted(), _near_t, _near_c)
	_mm(_unit_box, _tinted(), _street_t, _street_c).cast_shadow = off
	_mm(_unit_box, _plain(IRON), _iron_t).cast_shadow = off
	_mm(_cyl, _tinted(), _cyl_t, _cyl_c).cast_shadow = off
	_mm(_unit_box, _victorian_facade(), _fac_t, _fac_c).cast_shadow = off
	var prism := PrismMesh.new()
	_mm(prism, _tinted(), _roof_t, _roof_c).cast_shadow = off
	_mm(_cone, _tinted(), _cone_t, _cone_c).cast_shadow = off
	var glow := _glow_material()
	_mm(_unit_box, glow, _glow_t, _glow_c).cast_shadow = off
	_mm(_sphere, glow, _globe_t, _globe_c).cast_shadow = off
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 1.0
	disc.radial_segments = 16
	disc.rings = 0
	_mm(disc, glow, _disc_t, _disc_c).cast_shadow = off
	var halos := _mm(QuadMesh.new(), _halo_material(), _halo_t)
	halos.cast_shadow = off
	_extras.append(halos)
	var paving := _noise_mat(Color(0.47, 0.47, 0.46), 0.1, 6.0)
	paving.roughness = 0.38
	_mm(_unit_box, paving, _pave_t).cast_shadow = off
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color(0.1, 0.11, 0.12)
	puddle.roughness = 0.04
	puddle.metallic_specular = 0.8
	var pm := CylinderMesh.new()
	pm.top_radius = 1.0
	pm.bottom_radius = 1.0
	pm.height = 1.0
	pm.radial_segments = 12
	pm.rings = 0
	_mm(pm, puddle, _puddle_t).cast_shadow = off
	_mm(_unit_box, _brick_material(), _wall_t, _wall_c).cast_shadow = off
	_mm(_sphere, _tinted(), _ivy_t, _ivy_c).cast_shadow = off
	_mm(_sphere, _tinted(), _bloom_t, _bloom_c).cast_shadow = off
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.24
	trunk.height = 3.2
	trunk.radial_segments = 6
	trunk.rings = 0
	_mm(trunk, _plain(Color(0.42, 0.4, 0.34)), _trunk_t).cast_shadow = off
	_mm(_sphere, _swaying_leaves(), _crown_t, _crown_c).cast_shadow = off


func _bx(t: Array[Transform3D], c: Array[Color], size: Vector3, pos: Vector3, col: Color) -> void:
	t.append(Transform3D(Basis.from_scale(size), pos))
	c.append(col)


# --- Materials --------------------------------------------------------------------

## Brick, stucco and stone tinted per instance, with a world-space grid of sash windows
## (some lit warm from inside) on the walls. Instance colour alpha 0 = plain wall
## (chimneys, cornices, stone), 1 = windows.
func _victorian_facade() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform float street_y = 1.4;
uniform float bay = 2.4;
uniform float floor_h = 3.1;
uniform vec3 glow : source_color = vec3(1.0, 0.74, 0.44);
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float box(vec2 d, vec2 half_size) {
	vec2 w = fwidth(d) * 0.7 + 0.0001;
	vec2 s = 1.0 - smoothstep(half_size - w, half_size + w, d);
	return s.x * s.y;
}
void fragment() {
	vec3 n = abs(wnrm);
	float u = n.x > n.z ? wpos.z : wpos.x;
	float v = wpos.y - street_y;
	vec3 col = COLOR.rgb * (0.86 + 0.14 * smoothstep(0.0, 9.0, v));
	vec3 em = vec3(0.0);
	if (COLOR.a > 0.5 && n.y < 0.5 && v > 0.4) {
		vec2 cell = vec2(u / bay, v / floor_h);
		vec2 id = floor(cell);
		vec2 d = abs(fract(cell) - vec2(0.5, 0.5));
		float surround = box(d, vec2(0.24, 0.33));
		float pane = box(d, vec2(0.18, 0.27));
		float bar = 1.0 - box(vec2(d.y, 0.0), vec2(0.025, 1.0));
		float h = hash(id + vec2(floor(wpos.x * 0.05), floor(wpos.z * 0.05)) * 3.1);
		float lit = step(0.8, h);
		vec3 dark = mix(vec3(0.11, 0.12, 0.14), vec3(0.3, 0.33, 0.36), fract(cell.y) * 0.8);
		vec3 g = mix(dark, vec3(0.0), lit);
		col = mix(col, vec3(0.82, 0.8, 0.74), surround);
		col = mix(col, g, pane * bar);
		em = glow * (0.7 + 0.6 * hash(id * 1.7 + 0.3)) * lit * pane * bar;
	}
	ALBEDO = col;
	EMISSION = em;
	ROUGHNESS = 0.92;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("street_y", STREET_Y)
	m.set_shader_parameter("bay", BAY)
	m.set_shader_parameter("floor_h", FLOOR_H)
	m.set_shader_parameter("glow", WINDOW_GLOW)
	return m


## Unshaded glowing things tinted per instance. Instance colour alpha selects the life:
## 1 = street lamp (gentle flicker, a rare dip), 0.5 = steady, 0 = blinking beacon.
func _glow_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float energy = 1.5;
varying float k;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = hash(dot(o, vec3(12.9898, 78.233, 37.719)));
	if (COLOR.a > 0.75) {
		float n = sin(TIME * (2.3 + ph) + ph * 30.0) * 0.5 + sin(TIME * (5.7 + ph * 3.0) + ph * 11.0) * 0.5;
		float dip = step(0.985, hash(floor(TIME * 7.0) + ph * 97.0));
		k = 1.0 + n * 0.08 - dip * 0.4;
	} else if (COLOR.a > 0.25) {
		k = 1.0;
	} else {
		k = 0.15 + 0.85 * step(0.5, fract(TIME * 0.7 + ph));
	}
}
void fragment() {
	ALBEDO = COLOR.rgb * k * energy;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Soft warm glow around each lantern: camera-facing quads, added on top, fading out with
## distance (the fog would otherwise turn them into grey cards).
func _halo_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.7, 0.38);
varying float fade;
void vertex() {
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	VERTEX = c + vec3(VERTEX.x, VERTEX.y, 0.0) * s;
	NORMAL = vec3(0.0, 0.0, 1.0);
	fade = 1.0 - smoothstep(20.0, 130.0, -c.z);
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = pow(max(1.0 - r, 0.0), 2.5);
	ALBEDO = tint * a * fade * 0.5;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Brick walls in world space, tinted per instance.
func _brick_material() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var shades := []
	for i in 32:
		shades.append(r.randf_range(0.82, 1.12))
	for y in 64:
		var row := y / 8
		for x in 64:
			var off := 16 if row % 2 == 1 else 0
			var bxi := ((x + off) / 32) % 2
			var mortar := y % 8 == 0 or (x + off) % 32 == 0
			var s: float = shades[(row * 2 + bxi) % 32]
			var c := Color(0.86, 0.84, 0.8) if mortar else Color(s, s, s) * (0.96 + r.randf() * 0.08)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 0.6
	return m
