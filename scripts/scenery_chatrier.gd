class_name SceneryChatrier
extends Scenery
## The centre court of a Grand Slam on clay in Paris, after the Court Philippe-Chatrier:
## a sunken clay floor ringed by dark green walls with boards, two tiers of steep stands
## with white aisles all round, a white band between the tiers, a roof canopy over the
## upper tier and a big orange screen at the far end. Afternoon sun, a full house.
##
## The crowd is the point and costs almost nothing: ~19 000 spectators, each a figure
## of 4 triangles (shirt and head) turned to the camera on the GPU, in two MultiMeshes
## (one draw call each), filled from one packed buffer at build time. The stands are
## tinted box MultiMeshes; only the sun casts shadows, and only near things cast them.

const FLOOR_HX := 12.2           # inner face of the green wall, sides
const FLOOR_HZ := 21.2           # ... and ends
const WALL_H := 1.1
const WALL_T := 0.3
const WALK := 1.7                # the photographers' walkway behind the wall
const T1_ROWS := 22
const T1_DEPTH := 0.82
const T1_RISE := 0.42
const T1_BASE := 1.5             # the first row's seat above the floor
const BAND_H := 1.7              # the white band between the tiers
const CONCOURSE := 2.6
const T2_ROWS := 20
const T2_DEPTH := 0.8
const T2_RISE := 0.56
const SEAT_SPACING := 0.56
const AISLE_EVERY := 7.5
const AISLE_W := 1.1

## The boards along the walls: the author's Telegram and the game.
const ADS := "@CblHMOCKBA"
const ADS_END := ADS + "          TENNISISI          " + ADS
const ADS_SIDE := ADS + "        " + ADS + "        " + ADS + "        " + ADS

const CLAY := Color(0.74, 0.38, 0.22)
const WALL_GREEN := Color(0.07, 0.27, 0.19)
const CONCRETE := Color(0.7, 0.68, 0.64)
const SEAT := Color(0.6, 0.58, 0.55)
const AISLE := Color(0.9, 0.9, 0.88)
const BOX_FRONT := Color(0.74, 0.38, 0.26)   # the terracotta fronts of the boxes on the sides
const WHITE := Color(0.94, 0.94, 0.93)

## Shirt colours of a June crowd in Paris, [colour, weight], read off the photo: lots of
## white and beige, navy and black, light blue, a few bright ones.
const SHIRTS := [
	[Color(0.95, 0.95, 0.93), 26.0], [Color(0.86, 0.8, 0.68), 10.0], [Color(0.62, 0.76, 0.9), 9.0],
	[Color(0.16, 0.2, 0.34), 10.0], [Color(0.1, 0.1, 0.12), 9.0], [Color(0.55, 0.56, 0.58), 7.0],
	[Color(0.78, 0.18, 0.16), 5.0], [Color(0.2, 0.4, 0.26), 3.0], [Color(0.95, 0.82, 0.3), 3.0],
	[Color(0.93, 0.6, 0.7), 4.0], [Color(0.95, 0.55, 0.2), 3.0], [Color(0.3, 0.45, 0.8), 5.0],
	[Color(0.45, 0.3, 0.2), 3.0], [Color(0.5, 0.3, 0.6), 2.0],
]
const HATS := [Color(0.97, 0.96, 0.92), Color(0.9, 0.84, 0.7), Color(0.95, 0.95, 0.95), Color(0.2, 0.24, 0.36)]

var _near_t: Array[Transform3D] = []   # tinted boxes that cast shadows
var _near_c: Array[Color] = []
var _far_t: Array[Transform3D] = []    # tinted boxes that do not
var _far_c: Array[Color] = []
var _glow_t: Array[Transform3D] = []
var _crowd: Array[MultiMeshInstance3D] = []   # lower tier, upper tier
var _crowd_full: Array[int] = []              # instance counts at full density
# The tier being built: spectators alternate between the halves (see _person).
var _buf_a := PackedFloat32Array()
var _buf_b := PackedFloat32Array()
var _empty_noise := FastNoiseLite.new()
var _shirt_total := 0.0


func _ready() -> void:
	rng.seed = 2025  # the same crowd every time
	_unit_box.size = Vector3.ONE
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 10
	_sphere.rings = 6
	_empty_noise.seed = 8
	_empty_noise.frequency = 0.09
	for s in SHIRTS:
		_shirt_total += float(s[1])
	_build_sky_and_sun()
	_sun.rotation_degrees = Vector3(-52.0, -150.0, 0.0)   # early afternoon
	_sun.light_energy = 1.15
	_sun.directional_shadow_max_distance = 45.0
	_build_floor()
	_build_walls()
	_build_stands()
	_build_roof()
	_build_screen()
	_build_court_furniture()
	_flush()
	SceneryDetail.apply(self, "paris")  # stream H-6: people and props from the club's pack


func _process(delta: float) -> void:
	_t += delta


## Lighter rendering for slow phones: hard shadows over a shorter distance and half the
## crowd (every other spectator, so the stands stay evenly full).
func set_high_quality(on: bool) -> void:
	_sun.directional_shadow_max_distance = 45.0 if on else 28.0
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if on else RenderingServer.SHADOW_QUALITY_HARD)
	for i in _crowd.size():
		_crowd[i].multimesh.visible_instance_count = -1 if on else _crowd_full[i] / 2


# --- Floor and walls ----------------------------------------------------------------

func _build_floor() -> void:
	# Everything outside the stadium bowl: the concourses, never really seen.
	_ground(Vector2(400.0, 400.0), Vector3(0, -0.03, 0), _plain(Color(0.55, 0.54, 0.52)))
	# Clay all the way to the walls. It lies between the court's apron (y 0) and its
	# run-off (y 0.01), so it hides the darker apron and never z-fights.
	_ground(Vector2(FLOOR_HX * 2.0, FLOOR_HZ * 2.0), Vector3(0, 0.005, 0), _noise_mat(CLAY.darkened(0.03), 0.06, 8.0))
	# The photographers' walkway behind the wall.
	var wx := FLOOR_HX + WALL_T + WALK
	var wz := FLOOR_HZ + WALL_T + WALK
	for s in [-1.0, 1.0]:
		_far_t.append(_slab_tf(Vector3(WALK, 0.1, wz * 2.0), Vector3(s * (wx - WALK * 0.5), 0.0, 0)))
		_far_c.append(Color(0.42, 0.44, 0.42))
		_far_t.append(_slab_tf(Vector3(wx * 2.0, 0.1, WALK), Vector3(0, 0.0, s * (wz - WALK * 0.5))))
		_far_c.append(Color(0.42, 0.44, 0.42))


func _build_walls() -> void:
	var hx := FLOOR_HX + WALL_T * 0.5
	var hz := FLOOR_HZ + WALL_T * 0.5
	for s in [-1.0, 1.0]:
		_bx(Vector3(WALL_T, WALL_H, FLOOR_HZ * 2.0 + WALL_T * 2.0), Vector3(s * hx, WALL_H * 0.5, 0), WALL_GREEN)
		_bx(Vector3(FLOOR_HX * 2.0 + WALL_T * 2.0, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, s * hz), WALL_GREEN)
		# Advertising boards all along the walls, a lighter green than the wall.
		_bx(Vector3(FLOOR_HX * 2.0 - 0.4, 0.8, 0.06), Vector3(0, 0.55, s * (FLOOR_HZ - 0.03)), WALL_GREEN.lightened(0.1), 0.0, false)
		_bx(Vector3(0.06, 0.8, FLOOR_HZ * 2.0 - 0.4), Vector3(s * (FLOOR_HX - 0.03), 0.55, 0), WALL_GREEN.lightened(0.1), 0.0, false)
	# What the boards say: one long label per wall (one draw call each).
	for end in [-1.0, 1.0]:
		_sign(ADS_END, Vector3(0, 0.56, end * (FLOOR_HZ - 0.08)), 0.0 if end < 0.0 else PI, 0.0052)
		_sign(ADS_SIDE, Vector3(end * (FLOOR_HX - 0.08), 0.56, 0), -end * PI * 0.5, 0.0052)


func _sign(text: String, pos: Vector3, yaw: float, px: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = Color(1, 1, 1, 0.92)
	l.shaded = false
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.rotation = Vector3(0, yaw, 0)
	l.position = pos
	add_child(l)


# --- Stands and crowd ---------------------------------------------------------------

func _build_stands() -> void:
	var x1 := FLOOR_HX + WALL_T + WALK   # inner edge of the lower tier, sides
	var z1 := FLOOR_HZ + WALL_T + WALK   # ... ends
	_tier(x1, z1, T1_ROWS, T1_DEPTH, T1_RISE, T1_BASE, 1.0, true)
	_crowd_mm()
	# The band between the tiers: a flat concourse, then the white front of the upper tier.
	var t1_top := T1_BASE + (T1_ROWS - 1) * T1_RISE
	var x2 := x1 + T1_ROWS * T1_DEPTH + CONCOURSE
	var z2 := z1 + T1_ROWS * T1_DEPTH + CONCOURSE
	for s in [-1.0, 1.0]:
		_far_t.append(_slab_tf(Vector3(CONCOURSE, t1_top, z2 * 2.0), Vector3(s * (x2 - CONCOURSE * 0.5), t1_top * 0.5, 0)))
		_far_c.append(CONCRETE.darkened(0.1))
		_far_t.append(_slab_tf(Vector3(x2 * 2.0, t1_top, CONCOURSE), Vector3(0, t1_top * 0.5, s * (z2 - CONCOURSE * 0.5))))
		_far_c.append(CONCRETE.darkened(0.1))
		_far_t.append(_slab_tf(Vector3(0.4, BAND_H, z2 * 2.0 + 0.8), Vector3(s * (x2 + 0.2), t1_top + BAND_H * 0.5, 0)))
		_far_c.append(WHITE)
		_far_t.append(_slab_tf(Vector3(x2 * 2.0 + 0.8, BAND_H, 0.4), Vector3(0, t1_top + BAND_H * 0.5, s * (z2 + 0.2))))
		_far_c.append(WHITE)
	var band := Label3D.new()
	band.text = "COURT CENTRAL"
	band.font_size = 96
	band.pixel_size = 0.009
	band.outline_size = 0
	band.modulate = Color(0.2, 0.3, 0.25)
	band.shaded = false
	band.double_sided = false
	band.position = Vector3(0, t1_top + BAND_H * 0.5, -(z2 - 0.02))
	add_child(band)
	for sx in [-1.0, 1.0]:
		var side := band.duplicate() as Label3D
		side.text = ADS + "              " + ADS
		side.position = Vector3(sx * (x2 - 0.02), t1_top + BAND_H * 0.5, 0)
		side.rotation = Vector3(0, -sx * PI * 0.5, 0)
		add_child(side)
	var t2_base := t1_top + BAND_H + 0.3
	_tier(x2 + 0.4, z2 + 0.4, T2_ROWS, T2_DEPTH, T2_RISE, t2_base, 0.72, false)
	_crowd_mm()
	# The back wall above the last row, up to the roof.
	var t2_top := t2_base + (T2_ROWS - 1) * T2_RISE
	var bx := x2 + 0.4 + T2_ROWS * T2_DEPTH
	var bz := z2 + 0.4 + T2_ROWS * T2_DEPTH
	var wall_h := t2_top + 4.0
	for s in [-1.0, 1.0]:
		_far_t.append(_slab_tf(Vector3(1.0, wall_h, bz * 2.0 + 2.0), Vector3(s * (bx + 0.5), wall_h * 0.5, 0)))
		_far_c.append(CONCRETE.darkened(0.35))
		_far_t.append(_slab_tf(Vector3(bx * 2.0 + 2.0, wall_h, 1.0), Vector3(0, wall_h * 0.5, s * (bz + 0.5))))
		_far_c.append(CONCRETE.darkened(0.35))


## One tier: rows of steps all round (each a ring of four boxes, the sides running into
## the corners), white aisles, seats, and a spectator in most seats. `shade` darkens the
## crowd under the roof; `boxes` adds the terracotta box fronts low on the sides.
func _tier(x0: float, z0: float, rows: int, depth: float, rise: float, base_y: float, shade: float, boxes: bool) -> void:
	for r in rows:
		var o := r * depth
		var top := base_y + r * rise
		var ix := x0 + o
		var iz := z0 + o
		var tint := CONCRETE.darkened(0.04 * float(r % 2))
		for s in [-1.0, 1.0]:
			# The step (from the ground up: the front face is the riser) and its seat strip.
			_far_t.append(_slab_tf(Vector3(depth, top, (iz + depth) * 2.0), Vector3(s * (ix + depth * 0.5), top * 0.5, 0)))
			_far_c.append(tint)
			_far_t.append(_slab_tf(Vector3(ix * 2.0, top, depth), Vector3(0, top * 0.5, s * (iz + depth * 0.5))))
			_far_c.append(tint)
			_far_t.append(_slab_tf(Vector3(depth * 0.45, 0.14, (iz + depth) * 2.0), Vector3(s * (ix + depth * 0.68), top + 0.07, 0)))
			_far_c.append(SEAT)
			_far_t.append(_slab_tf(Vector3(ix * 2.0, 0.14, depth * 0.45), Vector3(0, top + 0.07, s * (iz + depth * 0.68))))
			_far_c.append(SEAT)
			if boxes and r % 6 == 0 and r > 0:
				_far_t.append(_slab_tf(Vector3(0.05, 0.75, (iz + depth) * 1.6), Vector3(s * (ix - 0.03), top - 0.2, 0)))
				_far_c.append(BOX_FRONT)
			# Aisles: white steps every AISLE_EVERY metres along every side.
			var k := 0
			while k * AISLE_EVERY < iz + depth:
				for zs in ([0.0] if k == 0 else [-1.0, 1.0]):
					_far_t.append(_slab_tf(Vector3(depth, 0.16, AISLE_W), Vector3(s * (ix + depth * 0.5), top + 0.06, zs * k * AISLE_EVERY)))
					_far_c.append(AISLE)
				k += 1
			k = 0
			while k * AISLE_EVERY < ix:
				for xs in ([0.0] if k == 0 else [-1.0, 1.0]):
					_far_t.append(_slab_tf(Vector3(AISLE_W, 0.16, depth), Vector3(xs * k * AISLE_EVERY, top + 0.06, s * (iz + depth * 0.5))))
					_far_c.append(AISLE)
				k += 1
			# The crowd: the sides take the corners, the ends stop at them.
			var z := -(iz + depth) + SEAT_SPACING * 0.5
			while z < iz + depth:
				if not _in_aisle(z):
					_person(Vector3(s * (ix + depth * 0.62), top + 0.08, z), shade, r)
				z += SEAT_SPACING
			var x := -ix + SEAT_SPACING * 0.5
			while x < ix:
				if not _in_aisle(x):
					_person(Vector3(x, top + 0.08, s * (iz + depth * 0.62)), shade, r)
				x += SEAT_SPACING


func _in_aisle(along: float) -> bool:
	var k := roundf(along / AISLE_EVERY)
	return absf(along - k * AISLE_EVERY) < AISLE_W * 0.6


## One spectator into the packed buffer (alternating halves, so a low quality setting
## can draw every other one): transform, shirt colour, head colour (face or hat).
func _person(p: Vector3, shade: float, row: int) -> void:
	# A few empty patches, more in the front rows (as in the photo, the low rows fill late).
	var empty := 0.05 + 0.45 * clampf((_empty_noise.get_noise_2d(p.x, p.z) - 0.25) * 3.0, 0.0, 1.0) * (1.0 if row < 8 else 0.3)
	if rng.randf() < empty:
		return
	var shirt := _pick_shirt()
	var head: Color
	if rng.randf() < 0.22:
		head = HATS[rng.randi_range(0, HATS.size() - 1)]
	else:
		head = (Looks.SKIN[rng.randi_range(0, 6)] as Color).darkened(rng.randf_range(0.0, 0.12))
	shirt = shirt.darkened(1.0 - shade)
	head = head.darkened(1.0 - shade)
	var h := rng.randf_range(0.9, 1.1)
	var data := PackedFloat32Array([h, 0.0, 0.0, p.x, 0.0, h, 0.0, p.y, 0.0, 0.0, h, p.z,
		shirt.r, shirt.g, shirt.b, 1.0, head.r, head.g, head.b, 1.0])
	if _buf_a.size() <= _buf_b.size():
		_buf_a.append_array(data)
	else:
		_buf_b.append_array(data)


func _pick_shirt() -> Color:
	var roll := rng.randf() * _shirt_total
	for s in SHIRTS:
		roll -= float(s[1])
		if roll <= 0.0:
			return s[0]
	return SHIRTS[0][0]


## The crowd of the tier just built as one MultiMesh: half A then half B (see _person).
func _crowd_mm() -> void:
	var buf := _buf_a + _buf_b
	_buf_a = PackedFloat32Array()
	_buf_b = PackedFloat32Array()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _person_mesh()
	mm.instance_count = buf.size() / 20
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _crowd_mat()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_crowd.append(mmi)
	_crowd_full.append(mm.instance_count)


## A seated spectator seen from the front: a shirt (UV.y 0) and a head (UV.y 1).
func _person_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in [[-0.21, 0.0, 0.21, 0.5, 0.0], [-0.1, 0.53, 0.1, 0.76, 1.0]]:
		var a := Vector3(q[0], q[1], 0)
		var b := Vector3(q[2], q[1], 0)
		var c := Vector3(q[2], q[3], 0)
		var d := Vector3(q[0], q[3], 0)
		for v in [a, b, c, a, c, d]:
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(Vector2(0.0, q[4]))
			st.add_vertex(v)
	return st.commit()


## Unshaded and turned to the camera about the vertical (like a Y billboard): a crowd
## reads as colour, not as lit geometry. Shirt = instance colour, head = custom data.
func _crowd_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
varying vec3 head_col;
varying float is_head;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	head_col = INSTANCE_CUSTOM.rgb;
	is_head = UV.y;
}
void fragment() {
	ALBEDO = mix(COLOR.rgb, head_col, step(0.5, is_head)) * 0.88;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# --- Roof and screen ----------------------------------------------------------------

func _build_roof() -> void:
	# A white canopy over the upper tier: white on top, a dark underside, a strip of
	# lights along its inner edge.
	var t1_top := T1_BASE + (T1_ROWS - 1) * T1_RISE
	var t2_top := t1_top + BAND_H + 0.3 + (T2_ROWS - 1) * T2_RISE
	var x1 := FLOOR_HX + WALL_T + WALK
	var z1 := FLOOR_HZ + WALL_T + WALK
	var x2 := x1 + T1_ROWS * T1_DEPTH + CONCOURSE + 0.4
	var z2 := z1 + T1_ROWS * T1_DEPTH + CONCOURSE + 0.4
	var inner_x := x2 + 3.0
	var inner_z := z2 + 3.0
	var outer_x := x2 + T2_ROWS * T2_DEPTH + 3.0
	var outer_z := z2 + T2_ROWS * T2_DEPTH + 3.0
	var y := t2_top + 4.6
	var w := outer_x - inner_x
	var wz := outer_z - inner_z
	for s in [-1.0, 1.0]:
		for layer in [[y + 0.45, 0.5, WHITE], [y - 0.05, 0.5, Color(0.24, 0.25, 0.27)]]:
			_far_t.append(_slab_tf(Vector3(w, layer[1], outer_z * 2.0), Vector3(s * (inner_x + w * 0.5), layer[0], 0)))
			_far_c.append(layer[2])
			_far_t.append(_slab_tf(Vector3(inner_x * 2.0, layer[1], wz), Vector3(0, layer[0], s * (inner_z + wz * 0.5))))
			_far_c.append(layer[2])
		_glow_t.append(_slab_tf(Vector3(0.25, 0.12, inner_z * 2.0), Vector3(s * (inner_x + 0.3), y - 0.36, 0)))
		_glow_t.append(_slab_tf(Vector3(inner_x * 2.0, 0.12, 0.25), Vector3(0, y - 0.36, s * (inner_z + 0.3))))


func _build_screen() -> void:
	# The big screen high at the far end, orange like the photo, the clay ball logo on it.
	var t1_top := T1_BASE + (T1_ROWS - 1) * T1_RISE
	var z2 := FLOOR_HZ + WALL_T + WALK + T1_ROWS * T1_DEPTH + CONCOURSE + 0.4
	var y := t1_top + BAND_H + 0.3 + T2_ROWS * T2_RISE * 0.62
	var z := -(z2 + T2_ROWS * T2_DEPTH * 0.62)
	_far_t.append(_slab_tf(Vector3(9.2, 5.4, 0.6), Vector3(0, y, z - 0.35)))
	_far_c.append(Color(0.06, 0.06, 0.07))
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.2, 0.06, 0.02)
	screen.emission_enabled = true
	screen.emission = Color(0.95, 0.36, 0.12)
	screen.emission_energy_multiplier = 1.4
	_box(Vector3(8.6, 4.8, 0.2), Vector3(0, y, z), screen, false)
	var logo := StandardMaterial3D.new()
	logo.albedo_color = Color(0.3, 0.2, 0.15)
	logo.emission_enabled = true
	logo.emission = Color(1.0, 0.85, 0.7)
	logo.emission_energy_multiplier = 1.2
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.1
	cm.height = 0.05
	cm.radial_segments = 24
	disc.mesh = cm
	disc.material_override = logo
	disc.rotation = Vector3(PI * 0.5, 0, 0)
	disc.position = Vector3(0, y, z + 0.13)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)


# --- Court furniture -----------------------------------------------------------------

func _build_court_furniture() -> void:
	var green := Color(0.1, 0.32, 0.22)
	# The umpire's chair by the net post: a tall dark green frame, a seat with a canopy.
	var ux := Court.NET_HALF_WIDTH + 1.3
	for lx in [-0.4, 0.4]:
		for lz in [-0.4, 0.4]:
			_bx(Vector3(0.09, 2.3, 0.09), Vector3(ux + lx, 1.15, lz), green)
	_bx(Vector3(1.0, 0.1, 1.0), Vector3(ux, 2.3, 0), green)
	_bx(Vector3(0.65, 0.12, 0.6), Vector3(ux, 2.42, 0), Color(0.9, 0.88, 0.8))
	_bx(Vector3(0.1, 0.8, 0.65), Vector3(ux + 0.3, 2.8, 0), green)
	_bx(Vector3(0.9, 0.06, 0.9), Vector3(ux + 0.05, 3.5, 0), green)
	for k in 6:
		_bx(Vector3(0.06, 0.04, 0.55), Vector3(ux + 0.55, 0.3 + k * 0.38, 0), green)
	# The players' chairs either side of the umpire, facing the court, each with a
	# towel, a racket bag and a little drinks table.
	var px := ux + 0.35
	for pz in [-2.1, 2.1]:
		_bx(Vector3(0.6, 0.08, 0.6), Vector3(px, 0.48, pz), green)
		_bx(Vector3(0.08, 0.75, 0.6), Vector3(px + 0.28, 0.88, pz), green)
		_bx(Vector3(0.5, 0.44, 0.06), Vector3(px, 0.22, pz - 0.25), green)
		_bx(Vector3(0.5, 0.44, 0.06), Vector3(px, 0.22, pz + 0.25), green)
		_bx(Vector3(0.1, 0.5, 0.45), Vector3(px + 0.22, 0.75, pz - 0.05), Color(0.95, 0.95, 0.93))  # towel
		_bx(Vector3(0.35, 0.32, 0.9), Vector3(px + 0.15, 0.16, pz + signf(pz) * 0.75), Color(0.15, 0.17, 0.25) if pz < 0.0 else Color(0.62, 0.16, 0.16))  # bag
		_bx(Vector3(0.4, 0.55, 0.4), Vector3(px, 0.28, pz + signf(pz) * 1.35), Color(0.92, 0.92, 0.9))  # drinks
	# Line judges' chairs in the four corners, ball kids crouched at the net and corners.
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var p := Vector3(cx * (FLOOR_HX - 1.2), 0.0, cz * (FLOOR_HZ - 1.4))
			_bx(Vector3(0.5, 0.08, 0.5), p + Vector3(0, 0.46, 0), green)
			_bx(Vector3(0.5, 0.55, 0.06), p + Vector3(0, 0.75, cz * 0.25), green)
			_bx(Vector3(0.45, 0.45, 0.45), p + Vector3(0, 0.22, 0), green.darkened(0.2))
			var kid := Vector3(cx * (Court.DOUBLES_HALF_WIDTH + 2.4), 0.0, cz * (FLOOR_HZ - 0.9))
			_bx(Vector3(0.35, 0.55, 0.3), kid + Vector3(0, 0.28, 0), Color(0.12, 0.16, 0.3))
			_bx(Vector3(0.18, 0.18, 0.18), kid + Vector3(0, 0.66, 0), Looks.SKIN[2])
	for nx in [-1.0, 1.0]:
		var kid := Vector3(nx * (Court.NET_HALF_WIDTH + 0.7), 0.0, -0.6)
		_bx(Vector3(0.35, 0.55, 0.3), kid + Vector3(0, 0.28, 0), Color(0.12, 0.16, 0.3))
		_bx(Vector3(0.18, 0.18, 0.18), kid + Vector3(0, 0.66, 0), Looks.SKIN[4])
	# Photographers crouched in the walkway behind the far baseline.
	for k in 7:
		var p := Vector3(-6.0 + k * 2.0 + rng.randf_range(-0.4, 0.4), 0.0, -(FLOOR_HZ + WALL_T + WALK * 0.5))
		_bx(Vector3(0.45, 0.8, 0.4), p + Vector3(0, 0.4, 0), Color(0.12, 0.12, 0.14), 0.0, false)
		_bx(Vector3(0.2, 0.15, 0.35), p + Vector3(0, 0.95, 0.2), Color(0.05, 0.05, 0.05), 0.0, false)


# --- Batching -----------------------------------------------------------------------

func _flush() -> void:
	var vc := _tinted()
	_mm(_unit_box, vc, _near_t, _near_c)
	_mm(_unit_box, vc, _far_t, _far_c).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.3, 0.3)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.97, 0.9)
	glow.emission_energy_multiplier = 1.6
	_mm(_unit_box, glow, _glow_t).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A box into the tinted batch (near ones cast shadows), optionally turned by yaw.
func _bx(size: Vector3, pos: Vector3, col: Color, yaw := 0.0, near := true) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), pos)
	if near:
		_near_t.append(t)
		_near_c.append(col)
	else:
		_far_t.append(t)
		_far_c.append(col)


func _slab_tf(size: Vector3, pos: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), pos)
