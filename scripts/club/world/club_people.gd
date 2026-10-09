class_name ClubPeople
extends RefCounted
## The club's light figures (passers-by, the fans at the fence): a whole person in ONE mesh
## drawn by a MultiMesh, so a crowd costs one draw call per figure kind, however many walk.
##
## The body is made like the players' (turned profiles: real legs, a torso, arms with hands,
## a head with eyes and hair), in white where the instance paints it. What paints what is in
## the vertex's UV.x:
##   0 fixed colour (eyes, shoes)   1 shirt (the instance COLOR)   2 skin (INSTANCE_CUSTOM)
##   3 hair (COLOR.a: black .. fair) 4 trousers (picked from the shirt: navy, denim, grey, khaki)
## and UV.y says which limb swings: 1/2 the left/right leg (from the hip), 3/4 the left/right
## arm (from the shoulder). The vertex shader swings them by INSTANCE_CUSTOM.a, the walk's
## phase (0..1; below 0 = standing): the legs and arms really walk, nothing on the CPU.
##
##   var mm := ClubPeople.multimesh(ClubPeople.Kind.SHORT_HAIR, n)
##   ClubPeople.paint(mm, i, shirt, skin, hair_tone)
##   ClubPeople.step(mm, i, phase)      # each frame for a walker; -1.0 for one standing

enum Kind { SHORT_HAIR, LONG_HAIR }

const HIP := 0.88
const SHOULDER := 1.39
const SEGS := 8

static var _meshes := {}
static var _mat: ShaderMaterial
const LOW_SEGS := 5


## A MultiMesh of n people of this kind (colours, custom data on), white until painted.
static func multimesh(kind: int, n: int, low := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh(kind, low)
	mm.instance_count = n
	for i in n:
		mm.set_instance_color(i, Color.WHITE)
		mm.set_instance_custom_data(i, Color(0.9, 0.75, 0.6, -1.0))
	return mm


static func instance(kind: int, n: int, low := false) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = multimesh(kind, n, low)
	mmi.material_override = material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Person i's colours: the shirt, the skin and the hair (0 black .. 1 fair).
static func paint(mm: MultiMesh, i: int, shirt: Color, skin: Color, hair := 0.2) -> void:
	mm.set_instance_color(i, Color(shirt.r, shirt.g, shirt.b, clampf(hair, 0.0, 1.0)))
	var c := mm.get_instance_custom_data(i)
	mm.set_instance_custom_data(i, Color(skin.r, skin.g, skin.b, c.a))


## Only the shirt (the fans in the club's colour).
static func shirt(mm: MultiMesh, i: int, c: Color) -> void:
	var was := mm.get_instance_color(i)
	mm.set_instance_color(i, Color(c.r, c.g, c.b, was.a))


## The walk's phase in radians (any), or a negative number for standing.
static func step(mm: MultiMesh, i: int, phase: float) -> void:
	var c := mm.get_instance_custom_data(i)
	c.a = fposmod(phase / TAU, 1.0) if phase >= 0.0 else -1.0
	mm.set_instance_custom_data(i, c)


static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat


# --- The mesh ------------------------------------------------------------------------------

## `low`: the Low preset's figure - the same body from a quarter of the triangles (five-sided limbs,
## a head of a few facets, no eyes, nose, hands or belt line): a stroller is a few pixels tall there,
## and the whole crowd is drawn whether he is in view or not (docs/PERFORMANCE.md 6).
static func mesh(kind: int, low := false) -> ArrayMesh:
	var cache_key := kind + (10 if low else 0)
	if _meshes.has(cache_key):
		return _meshes[cache_key]
	if low:
		_meshes[cache_key] = _low_mesh(kind)
		return _meshes[cache_key]
	var b := _Builder.new()
	var white := Color.WHITE
	var shoe := Color("e9e6df")
	var long := kind == Kind.LONG_HAIR
	for side in [-1.0, 1.0]:
		var limb := 1 if side < 0.0 else 2
		var hip := Vector3(0.095 * side, HIP, 0.0)
		# Leg, hip -> ankle: trousers (or shorts over a bare calf on the long-haired kind).
		var leg := [[0.0, 0.0], [0.03, 0.086], [0.2, 0.088], [0.48, 0.066], [0.55, 0.062], [0.7, 0.062], [0.93, 0.047], [1.0, 0.0]]
		if long:
			b.lathe(_cut(leg, 0.0, 0.32), hip, Vector3.DOWN, HIP - 0.07, 4, limb, white, SEGS)
			b.lathe(_cut(leg, 0.32, 1.0), hip, Vector3.DOWN, HIP - 0.07, 2, limb, white, SEGS)
		else:
			b.lathe(leg, hip, Vector3.DOWN, HIP - 0.07, 4, limb, white, SEGS)
		# Shoe: a flat ellipsoid at the ankle, toe forward (-Z).
		b.ball(Vector3(0.095 * side, 0.045, -0.04), Vector3(0.05, 0.045, 0.11), 0, limb, shoe, 7, 4)
		# Arm, shoulder -> wrist: a sleeve, then the forearm; a hand.
		var sh := Vector3(0.2 * side, SHOULDER, 0.0)
		var dir := Vector3(0.12 * side, -1.0, 0.0).normalized()
		b.lathe([[0.0, 0.0], [0.05, 0.058], [0.3, 0.058], [0.4, 0.056], [0.4, 0.0]], sh, dir, 0.52, 1, limb + 2, white, SEGS)
		b.lathe([[0.38, 0.0], [0.38, 0.044], [0.6, 0.043], [0.95, 0.033], [1.0, 0.0]], sh, dir, 0.52, 2, limb + 2, white, SEGS)
		b.ball(sh + dir * 0.57, Vector3(0.04, 0.052, 0.03), 2, limb + 2, white, 6, 4)
		# Eyes.
		b.ball(Vector3(0.038 * side, 1.712, -0.113), Vector3(0.016, 0.02, 0.01), 0, 0, Color(0.08, 0.07, 0.08), 5, 3)
	# Torso, hips -> neck: a narrow waist, a broad chest, flatter front to back.
	b.lathe([[0.0, 0.0], [0.0, 0.15], [0.12, 0.155], [0.35, 0.145], [0.62, 0.17], [0.82, 0.18], [0.93, 0.15], [1.0, 0.07], [1.0, 0.0]],
		Vector3(0, HIP - 0.06, 0), Vector3.UP, SHOULDER + 0.08 - HIP, 1, 0, white, 12, Vector3(1.0, 1.0, 0.68))
	# Belt line in the trousers' colour.
	b.lathe([[0.0, 0.0], [0.0, 0.153], [1.0, 0.153], [1.0, 0.0]], Vector3(0, HIP - 0.07, 0), Vector3.UP, 0.08, 4, 0, white, 12, Vector3(1.0, 1.0, 0.68))
	# Shoulders: round deltoids across.
	b.lathe([[0.0, 0.0], [0.05, 0.062], [0.25, 0.066], [0.75, 0.066], [0.95, 0.062], [1.0, 0.0]],
		Vector3(-0.235, SHOULDER - 0.01, 0), Vector3.RIGHT, 0.47, 1, 0, white, SEGS)
	# Neck and head.
	b.lathe([[0.0, 0.0], [0.0, 0.055], [1.0, 0.05], [1.0, 0.0]], Vector3(0, SHOULDER + 0.02, 0), Vector3.UP, 0.18, 2, 0, white, SEGS)
	b.ball(Vector3(0, 1.69, 0), Vector3(0.115, 0.132, 0.122), 2, 0, white, 12, 7)
	b.ball(Vector3(0, 1.665, -0.122), Vector3(0.017, 0.021, 0.017), 2, 0, white, 5, 3)   # nose
	# Hair: a cap over the crown and the back of the head (long: down to the shoulders, a
	# fringe).
	b.ball(Vector3(0, 1.728, 0.012), Vector3(0.123, 0.115, 0.128), 3, 0, white, 12, 6, 0.0)
	b.ball(Vector3(0, 1.69, 0.045), Vector3(0.112, 0.11, 0.09), 3, 0, white, 10, 5)
	if long:
		b.ball(Vector3(0, 1.6, 0.06), Vector3(0.115, 0.17, 0.08), 3, 0, white, 10, 6)
		b.ball(Vector3(0, 1.77, -0.07), Vector3(0.095, 0.035, 0.05), 3, 0, white, 8, 4)
	var m := b.commit()
	_meshes[cache_key] = m
	return m


static func _low_mesh(kind: int) -> ArrayMesh:
	var b := _Builder.new()
	var white := Color.WHITE
	var shoe := Color("e9e6df")
	var long := kind == Kind.LONG_HAIR
	var leg := [[0.0, 0.0], [0.03, 0.086], [0.48, 0.066], [0.93, 0.047], [1.0, 0.0]]
	for side in [-1.0, 1.0]:
		var limb := 1 if side < 0.0 else 2
		var hip := Vector3(0.095 * side, HIP, 0.0)
		if long:
			b.lathe(_cut(leg, 0.0, 0.32), hip, Vector3.DOWN, HIP - 0.07, 4, limb, white, LOW_SEGS)
			b.lathe(_cut(leg, 0.32, 1.0), hip, Vector3.DOWN, HIP - 0.07, 2, limb, white, LOW_SEGS)
		else:
			b.lathe(leg, hip, Vector3.DOWN, HIP - 0.07, 4, limb, white, LOW_SEGS)
		b.ball(Vector3(0.095 * side, 0.045, -0.04), Vector3(0.05, 0.045, 0.11), 0, limb, shoe, 5, 2)
		var sh := Vector3(0.2 * side, SHOULDER, 0.0)
		var dir := Vector3(0.12 * side, -1.0, 0.0).normalized()
		b.lathe([[0.0, 0.0], [0.05, 0.058], [0.4, 0.056], [0.4, 0.0]], sh, dir, 0.52, 1, limb + 2, white, LOW_SEGS)
		b.lathe([[0.38, 0.0], [0.38, 0.044], [1.0, 0.0]], sh, dir, 0.52, 2, limb + 2, white, LOW_SEGS)
	b.lathe([[0.0, 0.0], [0.0, 0.15], [0.35, 0.145], [0.82, 0.18], [1.0, 0.07], [1.0, 0.0]],
		Vector3(0, HIP - 0.06, 0), Vector3.UP, SHOULDER + 0.08 - HIP, 1, 0, white, 8, Vector3(1.0, 1.0, 0.68))
	b.lathe([[0.0, 0.0], [0.0, 0.055], [1.0, 0.05], [1.0, 0.0]], Vector3(0, SHOULDER + 0.02, 0), Vector3.UP, 0.18, 2, 0, white, LOW_SEGS)
	b.ball(Vector3(0, 1.69, 0), Vector3(0.115, 0.132, 0.122), 2, 0, white, 8, 4)
	b.ball(Vector3(0, 1.728, 0.012), Vector3(0.123, 0.115, 0.128), 3, 0, white, 8, 3, 0.0)
	b.ball(Vector3(0, 1.69, 0.045), Vector3(0.112, 0.11, 0.09), 3, 0, white, 6, 3)
	if long:
		b.ball(Vector3(0, 1.6, 0.06), Vector3(0.115, 0.17, 0.08), 3, 0, white, 6, 3)
	return b.commit()


## The rows of a profile between t0 and t1, re-spread over 0..1 of that part, with a closed
## end where it was cut.
static func _cut(prof: Array, t0: float, t1: float) -> Array:
	var out: Array = []
	for row in prof:
		var t: float = row[0]
		if t >= t0 and t <= t1:
			out.append([t, row[1]])
	if out[0][0] > t0:
		out.push_front([t0, _at(prof, t0)])
	if out.back()[0] < t1:
		out.append([t1, _at(prof, t1)])
	out.push_front([t0, 0.0])
	out.append([t1, 0.0])
	return out


static func _at(prof: Array, t: float) -> float:
	for i in prof.size() - 1:
		if t <= float(prof[i + 1][0]):
			return lerpf(float(prof[i][1]), float(prof[i + 1][1]), inverse_lerp(float(prof[i][0]), float(prof[i + 1][0]), t))
	return float(prof.back()[1])


## Collects triangles with colour, normal and the paint/limb tags.
class _Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	## A profile [t 0..1 along `dir` from `from` over `len`, radius] turned round the axis;
	## `squash` scales the result (a flatter torso).
	func lathe(prof: Array, from: Vector3, dir: Vector3, len: float, paint: int, limb: int, col: Color, segs: int, squash := Vector3.ONE) -> void:
		var y := dir.normalized()
		var x := y.cross(Vector3.FORWARD)
		if x.length() < 0.01:
			x = y.cross(Vector3.UP)
		x = x.normalized()
		var z := x.cross(y)
		var base := v.size()
		var rows := prof.size()
		for i in rows:
			var t: float = prof[i][0]
			var r: float = prof[i][1]
			var ia := maxi(i - 1, 0)
			var ib := mini(i + 1, rows - 1)
			var dy: float = (float(prof[ib][0]) - float(prof[ia][0])) * len
			var dr: float = float(prof[ib][1]) - float(prof[ia][1])
			for j in segs + 1:
				var a := TAU * float(j) / float(segs)
				var rad := x * cos(a) + z * sin(a)
				var nrm := y * (-1.0 if t < 0.5 else 1.0)
				if r > 0.0001 and absf(dy) > 0.0001:
					nrm = (rad - y * (dr / dy)).normalized()
				elif r > 0.0001:
					nrm = (rad + nrm * 0.6).normalized()
				var p := from + y * (t * len) + rad * r
				v.append(Vector3(p.x * squash.x, p.y, p.z * squash.z) if squash != Vector3.ONE else p)
				n.append((Vector3(nrm.x / squash.x, nrm.y, nrm.z / squash.z)).normalized())
				c.append(col)
				uv.append(Vector2(paint, limb))
		for i in rows - 1:
			for j in segs:
				var a0 := base + i * (segs + 1) + j
				var b0 := a0 + segs + 1
				idx.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])

	## An ellipsoid of radii `r` at `at`; `cut` > -1 keeps only what is above that height
	## (-1..1 of the radius) - a hair cap without a chin.
	func ball(at: Vector3, r: Vector3, paint: int, limb: int, col: Color, segs: int, rings: int, cut := -1.0) -> void:
		var base := v.size()
		var r0 := 0
		for i in rings + 1:
			var el := lerpf(-PI * 0.5, PI * 0.5, float(i) / float(rings))
			if sin(el) < cut - 0.0001 and i < rings:
				r0 = i + 1
				continue
			for j in segs + 1:
				var a := TAU * float(j) / float(segs)
				var d := Vector3(cos(el) * cos(a), sin(el), cos(el) * sin(a))
				v.append(at + d * r)
				n.append(Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized())
				c.append(col)
				uv.append(Vector2(paint, limb))
		for i in rings - r0:
			for j in segs:
				var a0 := base + i * (segs + 1) + j
				var b0 := a0 + segs + 1
				idx.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])

	func commit() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


## Lit like the club's props (wrapped light, a toon highlight, a rim). Colours are used as
## they are, like the players' (Athlete) - the hero walks among them.
const SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_toon;

varying vec3 paint;

vec3 rot_x(vec3 p, vec3 pivot, float a) {
	vec3 q = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec3(q.x, q.y * c - q.z * s, q.y * s + q.z * c);
}

void vertex() {
	float kind = UV.x;
	float limb = UV.y;
	vec4 shirt = COLOR;   // the mesh is white where painted: COLOR is the instance's colour
	vec3 skin = INSTANCE_CUSTOM.rgb;
	vec3 hair = mix(vec3(0.08, 0.06, 0.05), vec3(0.82, 0.66, 0.4), shirt.a);
	float h = fract(dot(shirt.rgb, vec3(7.1, 3.3, 5.7)));
	vec3 trousers = h < 0.3 ? vec3(0.17, 0.21, 0.32) : (h < 0.55 ? vec3(0.29, 0.39, 0.56) : (h < 0.8 ? vec3(0.33, 0.33, 0.36) : vec3(0.62, 0.55, 0.42)));
	vec3 col = COLOR.rgb;
	if (kind > 0.5 && kind < 1.5) col = shirt.rgb;
	else if (kind > 1.5 && kind < 2.5) col = skin;
	else if (kind > 2.5 && kind < 3.5) col = hair;
	else if (kind > 3.5) col = trousers;
	// Fixed parts: COLOR is tinted by the instance there too, so their colour is by height
	// (shoes low, eyes high).
	if (kind < 0.5) col = VERTEX.y < 0.3 ? vec3(0.91, 0.9, 0.87) : vec3(0.08, 0.07, 0.08);
	paint = col;
	// The walk: legs from the hips, arms from the shoulders, opposite to each other.
	float ph = INSTANCE_CUSTOM.a;
	if (ph >= 0.0 && limb > 0.5) {
		float s = sin(ph * 6.2831853);
		if (limb < 2.5) {
			float a = (limb < 1.5 ? s : -s) * 0.42;
			VERTEX = rot_x(VERTEX, vec3(0.0, 0.88, 0.0), a);
			NORMAL = rot_x(NORMAL, vec3(0.0), a);
			// the foot in the air lifts a little more (a knee would)
			VERTEX.y += max(0.0, -cos(ph * 6.2831853 + (limb < 1.5 ? 0.0 : 3.14159))) * 0.04 * clamp((0.5 - VERTEX.y) * 2.0, 0.0, 1.0);
		} else {
			float a = (limb < 3.5 ? -s : s) * 0.36;
			VERTEX = rot_x(VERTEX, vec3(0.0, 1.39, 0.0), a);
			NORMAL = rot_x(NORMAL, vec3(0.0), a);
		}
	}
}

void fragment() {
	ALBEDO = paint;
	ROUGHNESS = 0.7;
	RIM = 0.35;
	RIM_TINT = 0.5;
}
"""
