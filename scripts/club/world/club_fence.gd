class_name ClubFence
extends Node3D
## The club's fence all the way round (stream H, the owner's wish of 08.10): wire mesh on
## posts along the east and west edges of the world, the south edge past the gate's wall
## and the north edge above the promenade, with a wicket to the embankment where the
## path from the court meets it (the gate itself is the Entrance's). One MultiMesh a side:
## sections of 3 m, instance-coloured and instance-tilted, so four draw calls in all.
##
## Level 0 of the Entrance: rusty, here and there leaning or torn down to half height - but
## the hero's walls (ClubWalk) are continuous, nothing is a way out. From the Entrance's
## level 3: straight, green, whole. The camera meets the same walls (ClubCamera).

const SECTION := 3.0
const HEIGHT := 1.9
const WEST := -54.6
const EAST := 54.6
const NORTH := -40.9
const SOUTH := 41.0
const WICKET := Rect2(-4.2, NORTH - 0.2, 2.4, 0.4)     # the opening in the north fence, on the path
const GATE_WALL := 14.1                                 # the Entrance's own brick wall reaches this far

var _sides := {}        # "n","s","e","w" -> {"mm": MultiMeshInstance3D, "base": Array of Transform3D}
var _level := -1
var _walk: ClubWalk


func _ready() -> void:
	var world: ClubWorld = get_parent().world
	_walk = world.walk
	var mesh := _section_mesh()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = world.get("_fence_tex")
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	var y := ClubLayout.LAWN
	_side("n", mesh, mat, _line(Vector2(WEST, NORTH), Vector2(-4.2, NORTH)) + _line(Vector2(-1.8, NORTH), Vector2(EAST, NORTH)), 0.0, y)
	_side("s", mesh, mat, _line(Vector2(WEST, SOUTH), Vector2(-GATE_WALL, SOUTH)) + _line(Vector2(GATE_WALL, SOUTH), Vector2(EAST, SOUTH)), 0.0, y)
	_side("w", mesh, mat, _line(Vector2(WEST, NORTH), Vector2(WEST, SOUTH)), PI * 0.5, y)
	_side("e", mesh, mat, _line(Vector2(EAST, NORTH), Vector2(EAST, SOUTH)), PI * 0.5, y)
	# the walls: east and west are the world's own edge (ClubWalk.bounds); north and south here
	_walk.add_wall(Vector2(WEST, NORTH), Vector2(-4.2, NORTH), 0.3, "fence")
	_walk.add_wall(Vector2(-1.8, NORTH), Vector2(EAST, NORTH), 0.3, "fence")
	_walk.add_wall(Vector2(WEST, SOUTH), Vector2(-GATE_WALL, SOUTH), 0.3, "fence")
	_walk.add_wall(Vector2(GATE_WALL, SOUTH), Vector2(EAST, SOUTH), 0.3, "fence")
	# the way to the embankment: the path through the wicket
	for w in [Vector2(-3.0, -24.0), Vector2(-3.0, -39.3), Vector2(-3.0, -42.2)]:
		_walk.waypoints.append(w)
	refresh(0)


## Section centres along a line (as 2D points), one per SECTION.
func _line(a: Vector2, b: Vector2) -> Array:
	var out := []
	var n := maxi(1, roundi(a.distance_to(b) / SECTION))
	for i in n:
		out.append(a.lerp(b, (i + 0.5) / n))
	return out


func _side(id: String, mesh: Mesh, mat: Material, centres: Array, yaw: float, y: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = centres.size()
	var base := []
	for i in centres.size():
		var c: Vector2 = centres[i]
		base.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "fence_" + id
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_sides[id] = {"mm": mmi, "base": base}


## Rust and lean while the Entrance is below level 3; straight and green from level 3.
func refresh(gate_level: int) -> void:
	var neat := gate_level >= 3
	if neat == (_level >= 3) and _level >= 0:
		return
	_level = gate_level
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for id in _sides:
		var d: Dictionary = _sides[id]
		var mm: MultiMesh = (d["mm"] as MultiMeshInstance3D).multimesh
		var base: Array = d["base"]
		for i in base.size():
			var xf: Transform3D = base[i]
			var col := Color(0.2, 0.34, 0.27)
			if not neat:
				var rust := rng.randf_range(0.0, 1.0)
				col = Color(0.62, 0.38, 0.24).lerp(Color(0.42, 0.3, 0.22), rust)
				var r := rng.randf()
				if r < 0.16:      # leaning
					xf.basis = xf.basis * Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.16, 0.16)))
				elif r < 0.3:     # torn down to half height
					xf.basis = xf.basis * Basis.from_scale(Vector3(1.0, rng.randf_range(0.5, 0.65), 1.0))
					col = col.darkened(0.15)
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, col)


## One section along x, 3 m: two posts, a top rail and the mesh panel (a double quad, texture
## repeated; the posts' UVs sit on a solid texel of the fence texture).
static func _section_mesh() -> ArrayMesh:
	var s := ClubShapes.new()
	var col := Color.WHITE
	for x in [-SECTION * 0.5, SECTION * 0.5]:
		s.box(Vector3(0.12, HEIGHT + 0.15, 0.12), Vector3(x, (HEIGHT + 0.15) * 0.5, 0), col)
	s.box(Vector3(SECTION, 0.07, 0.07), Vector3(0, HEIGHT, 0), col)
	s.box(Vector3(SECTION, 0.05, 0.05), Vector3(0, 0.12, 0), col)
	var verts := s._v.duplicate()
	var norms := s._n.duplicate()
	var cols := s._c.duplicate()
	var idx := s._i.duplicate()
	var uvs := PackedVector2Array()
	for k in verts.size():
		uvs.append(Vector2(1.0 / 32.0, 1.0 / 32.0))
	var b := verts.size()
	var w := SECTION - 0.12
	for p in [Vector3(-w * 0.5, 0.12, 0), Vector3(w * 0.5, 0.12, 0), Vector3(w * 0.5, HEIGHT, 0), Vector3(-w * 0.5, HEIGHT, 0)]:
		verts.append(p)
		norms.append(Vector3(0, 0, 1))
		cols.append(col)
	uvs.append(Vector2(0, 3.2))
	uvs.append(Vector2(w / 0.55, 3.2))
	uvs.append(Vector2(w / 0.55, 0))
	uvs.append(Vector2(0, 0))
	for k in [0, 1, 2, 0, 2, 3]:
		idx.append(b + k)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
