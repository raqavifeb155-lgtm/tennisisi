class_name AthleteSkin
extends RefCounted
## The SMOOTH body (Athlete.Body.SMOOTH): every part of the TOON body baked into ONE
## skinned mesh on a Skeleton3D, with a drawn face.
##
## Nothing in the rig changes: Athlete still poses its parts (_set_bone, _set_joint,
## _place_hand, the head node) every frame, and those parts stay as invisible proxies (so
## gear, tests and anything hung on a part keep working). After the pose, `sync` copies each
## proxy's transform onto its bone. One mesh draws the whole body, one pass its outline and
## one its shadow: ~3 draw calls instead of ~30 (docs/PERFORMANCE.md).
##
## What the bake adds over the parts:
##   - knees and elbows bend as one surface: the ends of thigh/shin and upper arm/forearm
##     are weighted to both bones, the limbs' bones roll with the plane of the bend (no
##     twist at the joint);
##   - one outline for the body (no rings at the joints), small parts (ears, nose, hands)
##     without one;
##   - a face drawn by the shader on the skull: eyes with an iris that follows the ball,
##     blinks, brows and a mouth that show effort at the stroke, joy and disappointment
##     after a point (Athlete.emote), and being out of breath.
## Parts whose material is not plain (glowing gear: shoes, wristbands of epic and up) stay
## their own meshes, drawn as before.

## The limbs whose ends meet at a bending joint: bone -> [the other bone, the joint's end
## of this one (1 = far end, 0 = near end)].
const BLEND := {
	"thigh0": ["shin0", 1], "shin0": ["thigh0", 0],
	"thigh1": ["shin1", 1], "shin1": ["thigh1", 0],
	"upper_r": ["fore_r", 1], "fore_r": ["upper_r", 0],
	"upper_l": ["fore_l", 1], "fore_l": ["upper_l", 0],
}
## [root bone, end bone] of each limb, rolled with its bend.
const LIMBS := [["thigh0", "shin0"], ["thigh1", "shin1"], ["upper_r", "fore_r"], ["upper_l", "fore_l"]]
const ZONE := 0.22               # share of a limb's length blended toward the joint
const NO_OUTLINE := 0.22          # parts smaller than this (m) get no outline (as Athlete._lighten)

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var material: ShaderMaterial
var _nodes: Array[Node3D] = []   # per bone: the proxy whose transform drives it
var _names: Array[String] = []
var _limb_idx := {}              # bone name -> bone index (limbs only)
var _bend := {}                  # limb root -> its last good bend normal
var _sources: Array[MeshInstance3D] = []

# Face state
var _blink_wait := 2.5
var _blink_t := -1.0
var _mood := ""
var _mood_left := 0.0
var _face := {"blink": 0.0, "smile": 0.1, "open": 0.0, "brow": 0.0}
var _gaze := Vector2.ZERO
var _clock := 0.0
var _rng := RandomNumberGenerator.new()

static var _shader: Shader
static var _outline: ShaderMaterial


## Bakes the athlete's current parts into one skinned mesh under its model and hides them.
## The proxies are posed once (a standing pose) to take the bind pose from.
static func bake(a: Athlete) -> AthleteSkin:
	var s := AthleteSkin.new()
	s._rng.seed = a.get_instance_id()
	s._build(a)
	return s


## Removes the baked mesh and shows the parts again (a rebuild, or gear changed).
func clear() -> void:
	for mi in _sources:
		if is_instance_valid(mi):
			mi.layers = 1
	_sources.clear()
	if is_instance_valid(skeleton):
		skeleton.get_parent().remove_child(skeleton)
		skeleton.queue_free()


func _build(a: Athlete) -> void:
	var model: Node3D = a._model
	# Bones: every posed part, the joint balls, the hands and the head.
	var bones := {}
	for b in a._bones:
		bones[b] = a._bones[b]
	for j in a._joints:
		bones[j] = a._joints[j]
	bones["hand_r"] = a._hand_r
	bones["hand_l"] = a._hand_l
	bones["head"] = a._head
	skeleton = Skeleton3D.new()
	skeleton.name = "SkinSkeleton"
	model.add_child(skeleton)
	for b in bones:
		var i := skeleton.add_bone(b)
		_names.append(b)
		_nodes.append(bones[b])
		if BLEND.has(b):
			_limb_idx[b] = i
	# Bind pose = the proxies as posed now (the limbs on frames rolled with their bend).
	var bind: Array[Transform3D] = []
	for i in _names.size():
		bind.append(_pose_of(a, i))
	var skin := Skin.new()
	for i in _names.size():
		skin.add_bind(i, bind[i].affine_inverse())

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bidx := PackedInt32Array()
	var bw := PackedFloat32Array()
	var idx := PackedInt32Array()
	for i in _names.size():
		var node: Node3D = _nodes[i]
		var parts: Array = []   # [MeshInstance3D, transform from its mesh to the bone node]
		if node is MeshInstance3D:
			parts.append([node, Transform3D.IDENTITY])
		if node == a._head:
			for c in node.get_children():
				if c is MeshInstance3D:
					parts.append([c, (c as MeshInstance3D).transform])
		for p in parts:
			var mi: MeshInstance3D = p[0]
			if not mi.visible or mi.mesh == null or not _bakeable(mi.material_override):
				continue
			var to_model: Transform3D = node.transform * (p[1] as Transform3D)
			var mat := mi.material_override as StandardMaterial3D
			var tint := mat.albedo_color   # as the parts drew it (vertex colours are not converted either)
			var sz := (mi.get_aabb().size * to_model.basis.get_scale()).length()
			var outline := mat.next_pass != null and sz >= NO_OUTLINE
			var nb := to_model.basis.inverse().transposed()
			var skull := bool(mi.get_meta("skull", false))
			var blend: Array = BLEND.get(_names[i], [])
			var other := _names.find(String(blend[0])) if not blend.is_empty() else -1
			var ref := float(mi.get_meta("ref", 1.0))
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var pn = arr[Mesh.ARRAY_NORMAL]
				var pc = arr[Mesh.ARRAY_COLOR]
				var pi = arr[Mesh.ARRAY_INDEX]
				var base := verts.size()
				for vi in pv.size():
					var v := pv[vi]
					verts.append(to_model * v)
					norms.append((nb * (pn[vi] if pn != null else v)).normalized())
					var c: Color = tint * (pc[vi] if pc != null and mat.vertex_color_use_as_albedo else Color.WHITE)
					c.a = 1.0 if outline else 0.0
					cols.append(c)
					if skull:
						var h := (p[1] as Transform3D) * v
						uvs.append(Vector2(h.x, h.y))
						uv2s.append(Vector2(h.z, 1.0))
					else:
						uvs.append(Vector2.ZERO)
						uv2s.append(Vector2.ZERO)
					var w := 0.0
					if other >= 0:
						var t := clampf(v.y / ref + 0.5, 0.0, 1.0)
						w = 0.5 * smoothstep(1.0 - ZONE, 1.0, t) if int(blend[1]) == 1 else 0.5 * (1.0 - smoothstep(0.0, ZONE, t))
					bidx.append_array([i, maxi(other, 0), 0, 0])
					bw.append_array([1.0 - w, w, 0.0, 0.0])
				if pi != null:
					for k in (pi as PackedInt32Array):
						idx.append(base + k)
				else:
					for k in pv.size():
						idx.append(base + k)
			mi.layers = 0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_sources.append(mi)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_BONES] = bidx
	arrays[Mesh.ARRAY_WEIGHTS] = bw
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Skin"
	mesh_instance.mesh = am
	mesh_instance.skin = skin
	material = _material(a)
	mesh_instance.material_override = material
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	sync(a, 0.0)


## Plain look materials only: vertex colours or one colour, opaque, no glow.
static func _bakeable(m: Material) -> bool:
	var sm := m as StandardMaterial3D
	return sm != null and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.emission_enabled


## Bone i's transform in model space now: the proxy's, or for a limb a frame along the
## bone whose side axis is the normal of the limb's bend (so both halves of a limb roll
## together and the joint between them never twists).
func _pose_of(a: Athlete, i: int) -> Transform3D:
	var node: Node3D = _nodes[i]
	var b := _names[i]
	if not _limb_idx.has(b) or not a._ends.has(b):
		return node.transform
	var root := b
	var tip := b
	for l in LIMBS:
		if l[0] == b or l[1] == b:
			root = l[0]
			tip = l[1]
	var e: Array = a._ends[b]
	var y: Vector3 = e[1] - e[0]
	var len := y.length()
	if len < 0.0001:
		return node.transform
	y /= len
	var n := Vector3.ZERO
	if a._ends.has(root) and a._ends.has(tip):
		var r0: Array = a._ends[root]
		var t0: Array = a._ends[tip]
		n = ((r0[1] - r0[0]) as Vector3).cross(t0[1] - t0[0])
	var prev: Vector3 = _bend.get(root, Vector3.ZERO)
	if n.length() > 0.004:
		n = n.normalized()
		_bend[root] = n
	elif prev != Vector3.ZERO:
		n = prev            # a straight limb keeps the last bend's roll
	else:
		n = y.cross(Vector3.FORWARD)
		if n.length() < 0.01:
			n = y.cross(Vector3.RIGHT)
		n = n.normalized()
	var x := (n - y * n.dot(y)).normalized()
	var mi := node as MeshInstance3D
	var ref := float(mi.get_meta("ref", len)) if mi else len
	return Transform3D(Basis(x, y * (len / ref), x.cross(y)), (e[0] + e[1]) * 0.5)


## After the pose: bones follow the proxies, the face lives.
func sync(a: Athlete, delta: float) -> void:
	if not is_instance_valid(skeleton):
		return
	for i in _names.size():
		var t := _pose_of(a, i)
		if not _nodes[i].visible:
			t.basis = t.basis.scaled(Vector3.ONE * 0.0001)   # a part hidden by its owner (the dealer's legs)
		skeleton.set_bone_pose_position(i, t.origin)
		skeleton.set_bone_pose_rotation(i, t.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(i, t.basis.get_scale())
	if delta > 0.0:
		_live(a, delta)


# --- Face -------------------------------------------------------------------------------

## A short mood: "joy" (won the point), "sad" (lost it), "shout" (come on!).
func emote(kind: String, secs: float) -> void:
	_mood = kind
	_mood_left = secs


func _live(a: Athlete, delta: float) -> void:
	_clock += delta
	# Blinks every 2-5 s, ~0.15 s each.
	var blink := 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		blink = sin(clampf(_blink_t / 0.15, 0.0, 1.0) * PI)
		if _blink_t > 0.15:
			_blink_t = -1.0
			_blink_wait = _rng.randf_range(2.0, 5.0)
	else:
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_t = 0.0
	# Eyes follow what the head follows (the ball).
	var g := Vector2.ZERO
	if a.look_target != Vector3.INF and is_instance_valid(a._head) and a._head.is_inside_tree():
		var d: Vector3 = a._head.global_basis.inverse() * (a.look_target - a._head.global_position)
		if d.z < -0.05:
			g = Vector2(clampf(d.x / -d.z, -1.0, 1.0), clampf(d.y / -d.z, -1.0, 1.0))
	_gaze = _gaze.lerp(g, 1.0 - exp(-14.0 * delta))
	# The target expression: calm (a hint of a smile), effort at the stroke, out of breath,
	# or a mood after a point.
	var want := {"blink": 0.0, "smile": 0.12, "open": 0.0, "brow": 0.0}
	var speed := Vector2(a.velocity.x, a.velocity.z).length()
	if speed > 3.5:
		want = {"blink": 0.1, "smile": -0.1, "open": 0.3, "brow": -0.3}
	if a.tired:
		want = {"blink": 0.25, "smile": -0.35, "open": 0.35 + 0.2 * sin(_clock * 6.0), "brow": 0.65}
	var stroke := a._mode == 2 and absf(a._clock - a._contact_at) < 0.2
	if stroke or a._mode == 5:
		want = {"blink": 0.3, "smile": -0.4, "open": 0.65, "brow": -0.9}
	if _mood_left > 0.0:
		_mood_left -= delta
		match _mood:
			"joy":
				want = {"blink": 0.15, "smile": 1.0, "open": 0.45, "brow": 0.35}
			"sad":
				want = {"blink": 0.35, "smile": -0.8, "open": 0.0, "brow": 0.9}
			"shout":
				want = {"blink": 0.2, "smile": 0.2, "open": 1.0, "brow": -1.0}
	var k := 1.0 - exp(-12.0 * delta)
	for key in _face:
		_face[key] = lerpf(float(_face[key]), float(want[key]), k)
	material.set_shader_parameter("blink", clampf(maxf(blink, float(_face["blink"])), 0.0, 1.0))
	material.set_shader_parameter("smile", _face["smile"])
	material.set_shader_parameter("mouth_open", _face["open"])
	material.set_shader_parameter("brow", _face["brow"])
	material.set_shader_parameter("gaze", _gaze)


# --- Materials ----------------------------------------------------------------------------

## The body's material, its own per athlete (the face's uniforms).
static func _material(a: Athlete) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BODY_SHADER
		var os := Shader.new()
		os.code = OUTLINE_SHADER
		_outline = ShaderMaterial.new()
		_outline.shader = os
		_outline.set_shader_parameter("color", Color(0.13, 0.1, 0.18))
		_outline.set_shader_parameter("grow", 0.0075)
	var m := ShaderMaterial.new()
	m.shader = _shader
	var hair: Color = Looks.hair_color(a.look)
	var skin: Color = Looks.skin(a.look)
	m.set_shader_parameter("brow_color", hair.darkened(0.25) if hair.get_luminance() > 0.25 else hair)
	m.set_shader_parameter("iris", _iris(a.look))
	m.set_shader_parameter("lip", skin.darkened(0.35).lerp(Color(0.62, 0.25, 0.25), 0.35))
	m.set_shader_parameter("blush", skin.lerp(Color(0.95, 0.45, 0.45), 0.5))
	m.next_pass = _outline
	return m


## Eye colour from the look (brown for most, the lighter the skin and hair the likelier
## blue, green or hazel), stable for a look.
static func _iris(look: Dictionary) -> Color:
	var pick := (int(look["skin"]) * 7 + int(look["hair_color"]) * 3 + int(look["hair"])) % 6
	if int(look["skin"]) >= 5 or int(look["hair_color"]) <= 1:
		return [Color(0.25, 0.15, 0.08), Color(0.18, 0.11, 0.06), Color(0.32, 0.2, 0.1)][pick % 3]
	return [Color(0.3, 0.19, 0.1), Color(0.2, 0.42, 0.68), Color(0.3, 0.48, 0.3), Color(0.45, 0.33, 0.15), Color(0.22, 0.13, 0.07), Color(0.35, 0.5, 0.62)][pick]


## Lit like the TOON body (soft wrapped light, a toon highlight, a light rim); on the
## skull's front (UV2.y = 1, UV2.x = depth < 0) a face is drawn in head-space metres (UV):
## eyes at (+-0.042, 0.012), brows above, the mouth at y -0.052.
const BODY_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_toon;

uniform vec3 iris : source_color = vec3(0.3, 0.19, 0.1);
uniform vec3 brow_color : source_color = vec3(0.2, 0.13, 0.08);
uniform vec3 lip : source_color = vec3(0.6, 0.3, 0.3);
uniform vec3 blush : source_color = vec3(0.9, 0.55, 0.5);
uniform float blink = 0.0;
uniform float smile = 0.1;
uniform float mouth_open = 0.0;
uniform float brow = 0.0;
uniform vec2 gaze = vec2(0.0);

float fill(float d, float w) {
	return 1.0 - smoothstep(-w, w, d);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec3 face(vec3 col, vec2 p) {
	float w = max(fwidth(p.x), fwidth(p.y)) * 0.8 + 0.00005;
	float side = p.x < 0.0 ? -1.0 : 1.0;
	vec2 q = vec2(abs(p.x), p.y);
	// cheeks
	col = mix(col, blush, 0.22 * fill(length(q - vec2(0.062, -0.028)) - 0.018, 0.012));
	// eyes: the white, cut by the upper lid (lower with a blink), an iris following the gaze
	vec2 ec = vec2(0.042, 0.012);
	vec2 er = vec2(0.0185, 0.022);
	float ed = (length((q - ec) / er) - 1.0) * er.x;
	float open = 1.0 - blink;
	float lid = ec.y - er.y + 2.0 * er.y * open;
	float eye = fill(ed, w) * fill(q.y - lid, w);
	col = mix(col, vec3(0.97, 0.96, 0.93), eye);
	vec2 ic = vec2(side * ec.x, ec.y - 0.002) + gaze * vec2(0.0075, 0.007);
	float id = length(p - ic);
	col = mix(col, iris, eye * fill(id - 0.0125, w));
	col = mix(col, vec3(0.03, 0.03, 0.04), eye * fill(id - 0.0062, w));
	col = mix(col, vec3(1.0), eye * fill(length(p - ic - vec2(0.004, 0.0045)) - 0.0028, w));
	// the lash line along the lid (a line when closed)
	float lash = fill(abs(q.y - lid) - 0.0026, w) * fill(ed - 0.0025, w) * step(ec.y - er.y * 0.6, q.y + 0.0001 + 0.03 * (1.0 - open));
	col = mix(col, vec3(0.07, 0.05, 0.06), lash);
	// brows: the inner end up when worried (brow > 0), down when angry or straining
	vec2 bi = vec2(0.022, 0.045 + 0.009 * brow);
	vec2 bo = vec2(0.064, 0.047 - 0.003 * brow + 0.002);
	float bt = mix(0.0055, 0.0035, clamp((q.x - bi.x) / (bo.x - bi.x), 0.0, 1.0));
	col = mix(col, brow_color, fill(seg(q, bi, bo) - bt, w));
	// mouth: a line curved by the smile, opened into a dark lens
	float hw = 0.021 + 0.004 * max(smile, 0.0);
	float xn = clamp(p.x / hw, -1.0, 1.0);
	float my = -0.052 + smile * 0.011 * (xn * xn - 0.35);
	float inside = step(abs(p.x), hw);
	float h = mouth_open * 0.017 * (1.0 - xn * xn);
	float lens = inside * fill(p.y - (my + h * 0.35), w) * fill((my - h) - p.y, w);
	col = mix(col, vec3(0.32, 0.07, 0.09), lens * step(0.02, mouth_open));
	float teeth = lens * fill(abs(p.y - (my + h * 0.35 - 0.0025)) - 0.0022, w) * step(0.3, mouth_open);
	col = mix(col, vec3(0.97, 0.96, 0.92), teeth);
	float line_d = abs(p.y - my) - 0.0019 * (1.0 - xn * xn * 0.6);
	col = mix(col, lip * 0.55, fill(line_d, w) * fill(abs(p.x) - hw, w));
	return col;
}

void fragment() {
	vec3 col = COLOR.rgb;
	if (UV2.y > 0.5 && UV2.x < -0.03) {
		col = face(col, UV);
	}
	ALBEDO = col;
	ROUGHNESS = 0.55;
	RIM = 0.55;
	RIM_TINT = 0.4;
}
"""

## The back faces of the body grown along the normals: a thin dark line round it. Parts
## marked with vertex alpha 0 (ears, nose, hands) don't grow, so they draw no line.
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.13, 0.1, 0.18, 1.0);
uniform float grow = 0.0075;

void vertex() {
	VERTEX += NORMAL * grow * COLOR.a;
}

void fragment() {
	ALBEDO = color.rgb;
}
"""
