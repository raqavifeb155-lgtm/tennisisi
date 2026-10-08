class_name ClubShapes
extends RefCounted
## Simple forms for everything the model pack draws (stream H): what the club shows until
## the pack has been downloaded - and what it keeps showing if the download never comes.
## Same ids, same sizes (metres, standing on y = 0), colours baked into the vertices like
## the pack's own meshes, so both go through the same material (ClubMaterial.tinted) and
## fold into the same draw calls. A few hundred triangles a prop at the most.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()

static var _box := BoxMesh.new()
static var _cyl := CylinderMesh.new()
static var _ball := SphereMesh.new()

const LEAF := [Color("4d7a33"), Color("668f3b"), Color("436b38"), Color("77953f")]
const TRUNK := Color("6b4a32")
const WOOD := Color("c08a55")
const DARK := Color("25272b")
const METAL := Color("b9bec4")
const STONE := Color("8f8a80")
const BRICK := Color("a0523d")
const PLASTER := Color("e3d6c3")
const GLASS := Color("8fb8c9")


func box(size: Vector3, pos: Vector3, col: Color, yaw := 0.0, tilt := Vector3.ZERO) -> ClubShapes:
	_box.size = Vector3.ONE
	var b := Basis.from_euler(Vector3(tilt.x, yaw + tilt.y, tilt.z)) * Basis.from_scale(size)
	return _add(_box, Transform3D(b, pos), col)


func cyl(top: float, bottom: float, h: float, pos: Vector3, col: Color, segs := 6, tilt := Vector3.ZERO) -> ClubShapes:
	_cyl.top_radius = top
	_cyl.bottom_radius = bottom
	_cyl.height = h
	_cyl.radial_segments = segs
	_cyl.rings = 0
	_cyl.cap_top = top > 0.001
	_cyl.cap_bottom = true
	return _add(_cyl, Transform3D(Basis.from_euler(tilt), pos), col)


func ball(r: float, pos: Vector3, col: Color, squash := Vector3.ONE, segs := 6, rings := 4) -> ClubShapes:
	_ball.radius = 1.0
	_ball.height = 2.0
	_ball.radial_segments = segs
	_ball.rings = rings
	return _add(_ball, Transform3D(Basis.from_scale(squash * r), pos), col)


## A flat patch lying on the ground: a fan of `segs` triangles, facing up (y = pos.y).
func flat(r: Vector2, pos: Vector3, col: Color, segs := 7, yaw := 0.0) -> ClubShapes:
	var base := _v.size()
	var b := Basis(Vector3.UP, yaw)
	_v.append(pos)
	_n.append(Vector3.UP)
	_c.append(col)
	for i in segs:
		var a := TAU * float(i) / segs
		_v.append(pos + b * Vector3(cos(a) * r.x, 0.0, sin(a) * r.y))
		_n.append(Vector3.UP)
		_c.append(col)
	for i in segs:
		_i.append(base)
		_i.append(base + 1 + i)
		_i.append(base + 1 + (i + 1) % segs)
	return self


## A thin pyramid, no base (a blade of grass): three triangles, flat-shaded.
func blade(base: Vector3, tip: Vector3, w: float, col: Color) -> ClubShapes:
	var ring: Array[Vector3] = []
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.5
		ring.append(base + Vector3(cos(a) * w, 0.0, sin(a) * w))
	for k in 3:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 3]
		var n := (b - a).cross(tip - a).normalized()
		if n.y < 0.0 and (a + b).length() >= 0.0:
			n = -n if n.dot(((a + b) * 0.5 - base)) < 0.0 else n
		var o := _v.size()
		for v in [a, tip, b]:
			_v.append(v)
			_n.append(Vector3(n.x, absf(n.y) * 0.5 + 0.5, n.z).normalized())
			_c.append(col)
		_i.append(o)
		_i.append(o + 1)
		_i.append(o + 2)
	return self


func _add(mesh: PrimitiveMesh, xf: Transform3D, col: Color) -> ClubShapes:
	var a := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var base := _v.size()
	var nb := xf.basis.inverse().transposed()
	for k in verts.size():
		_v.append(xf * verts[k])
		_n.append((nb * norms[k]).normalized())
		_c.append(col)
	for k in idx:
		_i.append(base + k)
	return self


## Takes everything another builder holds (to build a High mesh = Low + extras in one).
func merge(o: ClubShapes) -> ClubShapes:
	var base := _v.size()
	_v.append_array(o._v)
	_n.append_array(o._n)
	_c.append_array(o._c)
	for k in o._i:
		_i.append(base + k)
	return self


func build() -> ArrayMesh:
	var m := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_COLOR] = _c
	arr[Mesh.ARRAY_INDEX] = _i
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## The simple form of a pack id, or null for an id nobody knows.
static func make(id: String) -> ArrayMesh:
	var s := ClubShapes.new()
	match id:
		"bench":
			s.box(Vector3(1.6, 0.06, 0.45), Vector3(0, 0.45, 0), WOOD)
			s.box(Vector3(1.6, 0.4, 0.06), Vector3(0, 0.72, -0.2), WOOD)
			for x in [-0.7, 0.7]:
				s.box(Vector3(0.08, 0.45, 0.4), Vector3(x, 0.22, 0), DARK)
		"streetlight":
			s.cyl(0.05, 0.08, 4.0, Vector3(0, 2.0, 0), DARK)
			s.box(Vector3(0.9, 0.12, 0.3), Vector3(0.25, 4.1, 0), DARK)
			s.box(Vector3(0.5, 0.06, 0.24), Vector3(0.45, 4.02, 0), Color("ffe27a"))
		"trash_bin":
			s.cyl(0.3, 0.26, 0.9, Vector3(0, 0.45, 0), Color("3d806a"), 8)
			s.cyl(0.34, 0.34, 0.08, Vector3(0, 0.94, 0), DARK, 8)
			s.cyl(0.06, 0.06, 0.1, Vector3(0, 1.03, 0), DARK, 5)
		"trash_bags":
			s.ball(0.3, Vector3(-0.2, 0.28, 0), Color("2b2d33"), Vector3(1, 0.9, 1))
			s.ball(0.26, Vector3(0.25, 0.24, 0.1), Color("3a3f47"), Vector3(1, 0.9, 1))
			s.ball(0.2, Vector3(0.0, 0.5, -0.05), Color("2b2d33"), Vector3(1, 0.9, 1), 5, 3)
		"dumpster":
			s.box(Vector3(1.8, 1.2, 1.0), Vector3(0, 0.7, 0), Color("3d806a"))
			s.box(Vector3(1.9, 0.1, 1.1), Vector3(0, 1.35, 0), DARK)
		"hydrant":
			s.cyl(0.14, 0.17, 0.7, Vector3(0, 0.35, 0), Color("d9473b"), 8)
			s.ball(0.16, Vector3(0, 0.72, 0), Color("d9473b"))
		"box_a", "box_b", "crate":
			var h := 0.55 if id == "box_a" else (0.45 if id == "box_b" else 0.5)
			s.box(Vector3(h * 1.2, h, h * 1.2), Vector3(0, h * 0.5, 0), WOOD if id == "crate" else Color("c9a56b"))
		"menu_board":
			s.box(Vector3(0.4, 0.55, 0.05), Vector3(0, 0.45, 0), Color("29392f"))
			s.box(Vector3(0.05, 0.4, 0.3), Vector3(0.15, 0.2, -0.1), DARK, 0.0, Vector3(0, 0, 0.2))
		"car_hatch", "car_sedan", "car_wagon":
			var col: Color = {"car_hatch": Color("d9473b"), "car_sedan": Color("6b7f94"), "car_wagon": Color("e3d6c3")}[id]
			var len := 3.8 if id == "car_hatch" else 4.3
			s.box(Vector3(1.7, 0.6, len), Vector3(0, 0.55, 0), col)
			s.box(Vector3(1.5, 0.5, len * 0.5), Vector3(0, 1.05, -0.2), GLASS)
			for x in [-0.85, 0.85]:
				for z in [-len * 0.32, len * 0.32]:
					s.cyl(0.3, 0.3, 0.2, Vector3(x, 0.3, z), Color("101114"), 8, Vector3(0, 0, PI * 0.5))
		"watertower":
			for x in [-0.8, 0.8]:
				for z in [-0.8, 0.8]:
					s.box(Vector3(0.12, 2.2, 0.12), Vector3(x, 1.1, z), TRUNK)
			s.cyl(1.2, 1.2, 2.0, Vector3(0, 3.2, 0), Color("a0523d"), 8)
			s.cyl(0.05, 1.3, 0.8, Vector3(0, 4.6, 0), DARK, 8)
		"building_a", "building_b", "shop_a", "shop_b", "shop_c", "shop_wide_a", "shop_wide_b":
			var dims: Vector3 = {"building_a": Vector3(8, 9, 8), "building_b": Vector3(9, 10, 8), "shop_a": Vector3(8, 12, 8),
				"shop_b": Vector3(10, 14, 8), "shop_c": Vector3(8, 10, 7), "shop_wide_a": Vector3(16, 9, 8),
				"shop_wide_b": Vector3(14, 9, 8)}[id]
			var cols := [BRICK, PLASTER, Color("8fb8c9"), Color("c08a55"), Color("6b7f94")]
			var col: Color = cols[id.hash() % cols.size()]
			s.box(dims, Vector3(0, dims.y * 0.5, 0), col)
			s.box(Vector3(dims.x + 0.4, 0.5, dims.z + 0.4), Vector3(0, dims.y + 0.25, 0), Color("5e5a54"))
			s.box(Vector3(dims.x * 0.9, 3.0, 0.2), Vector3(0, 2.0, dims.z * 0.5 + 0.05), GLASS)
		"armchair":
			s.box(Vector3(0.8, 0.4, 0.8), Vector3(0, 0.3, 0), Color("d9473b"))
			s.box(Vector3(0.8, 0.5, 0.2), Vector3(0, 0.65, -0.3), Color("d9473b"))
		"chair_wood", "bar_chair":
			s.box(Vector3(0.45, 0.06, 0.45), Vector3(0, 0.45, 0), WOOD)
			s.box(Vector3(0.45, 0.45, 0.05), Vector3(0, 0.72, -0.2), WOOD)
			for x in [-0.18, 0.18]:
				for z in [-0.18, 0.18]:
					s.box(Vector3(0.05, 0.45, 0.05), Vector3(x, 0.22, z), TRUNK)
		"bar_stool":
			s.cyl(0.2, 0.2, 0.06, Vector3(0, 0.72, 0), Color("d9473b"), 8)
			s.cyl(0.04, 0.06, 0.7, Vector3(0, 0.36, 0), DARK)
		"table_low":
			s.box(Vector3(0.9, 0.06, 0.6), Vector3(0, 0.42, 0), WOOD)
			for x in [-0.4, 0.4]:
				s.box(Vector3(0.06, 0.4, 0.06), Vector3(x, 0.2, 0), TRUNK)
		"bar_table":
			s.cyl(0.5, 0.5, 0.06, Vector3(0, 0.75, 0), WOOD, 10)
			s.cyl(0.05, 0.1, 0.72, Vector3(0, 0.36, 0), DARK)
		"tree_oak", "tree_round", "tree_tall", "tree_fat", "tree_small":
			var h: float = {"tree_oak": 6.5, "tree_round": 6.0, "tree_tall": 7.5, "tree_fat": 5.5, "tree_small": 4.0}[id]
			var leaf: Color = LEAF[id.hash() % LEAF.size()]
			s.cyl(0.14 * h / 5.0, 0.22 * h / 5.0, h * 0.5, Vector3(0, h * 0.25, 0), TRUNK)
			s.ball(h * 0.3, Vector3(0, h * 0.7, 0), leaf, Vector3(1, 0.9, 1), 6, 4)
			s.ball(h * 0.2, Vector3(h * 0.12, h * 0.55, h * 0.05), leaf.darkened(0.08), Vector3(1, 0.9, 1), 6, 3)
		"tree_pine", "tree_pine_small":
			var h := 8.0 if id == "tree_pine" else 3.5
			s.cyl(0.12, 0.2, h * 0.3, Vector3(0, h * 0.15, 0), TRUNK)
			s.cyl(0.02, h * 0.18, h * 0.5, Vector3(0, h * 0.5, 0), LEAF[2], 7)
			s.cyl(0.02, h * 0.13, h * 0.4, Vector3(0, h * 0.75, 0), LEAF[2].lightened(0.05), 7)
		"bush", "bush_large":
			var r := 0.5 if id == "bush" else 0.75
			s.ball(r, Vector3(0, r * 0.7, 0), LEAF[id.hash() % LEAF.size()], Vector3(1, 0.8, 1))
		"flowers_red", "flowers_yellow", "flowers_purple":
			var col: Color = {"flowers_red": Color("d9473b"), "flowers_yellow": Color("ffd642"), "flowers_purple": Color("9a5cf0")}[id]
			s.cyl(0.01, 0.02, 0.22, Vector3(0, 0.11, 0), LEAF[1], 4)
			s.ball(0.07, Vector3(0, 0.26, 0), col, Vector3.ONE, 5, 3)
		"rock", "stone_tall":
			var h: float = {"rock": 0.35, "stone_tall": 1.6}[id]
			if id == "stone_tall":
				s.box(Vector3(0.6, h, 0.45), Vector3(0, h * 0.5, 0), STONE, 0.3)
			else:
				s.ball(h * 0.7, Vector3(0, h * 0.35, 0), STONE, Vector3(1, 0.6, 0.85), 6, 3)
		"column_broken":
			s.cyl(0.35, 0.4, 1.4, Vector3(0, 0.7, 0), PLASTER, 8)
			s.box(Vector3(0.7, 0.15, 0.7), Vector3(0, 1.45, 0), PLASTER, 0.4, Vector3(0.2, 0, 0.1))
		"stump":
			s.cyl(0.25, 0.3, 0.45, Vector3(0, 0.22, 0), TRUNK, 8)
		"log":
			s.cyl(0.14, 0.14, 1.4, Vector3(0, 0.14, 0), TRUNK, 6, Vector3(0, 0, PI * 0.5))
		"log_stack":
			for k in 3:
				s.cyl(0.13, 0.13, 1.2, Vector3(0, 0.14 + (0.0 if k < 2 else 0.22), (-0.15 + 0.3 * k) if k < 2 else 0.0), TRUNK, 6, Vector3(0, 0, PI * 0.5))
		"planter":
			s.cyl(0.35, 0.25, 0.5, Vector3(0, 0.25, 0), Color("a0523d"), 8)
			s.ball(0.3, Vector3(0, 0.65, 0), LEAF[0], Vector3(1, 0.8, 1))
		"sign":
			s.box(Vector3(0.08, 1.2, 0.08), Vector3(0, 0.6, 0), TRUNK)
			s.box(Vector3(0.9, 0.5, 0.06), Vector3(0, 1.05, 0), WOOD)
		"fence_planks":
			for x in [-0.5, 0.0, 0.5]:
				s.box(Vector3(0.14, 0.9, 0.04), Vector3(x, 0.45, 0), WOOD)
			s.box(Vector3(1.3, 0.08, 0.04), Vector3(0, 0.6, 0.04), TRUNK)
		"cone":
			s.cyl(0.02, 0.18, 0.6, Vector3(0, 0.3, 0), Color("f08a3c"), 8)
			s.box(Vector3(0.4, 0.04, 0.4), Vector3(0, 0.02, 0), DARK)
		"tyre":
			s.cyl(0.3, 0.3, 0.2, Vector3(0, 0.1, 0), Color("101114"), 10)
		"bumper":
			s.box(Vector3(1.2, 0.2, 0.3), Vector3(0, 0.1, 0), METAL, 0.2)
		"parasol":
			s.cyl(0.03, 0.04, 2.3, Vector3(0, 1.15, 0), METAL)
			s.cyl(0.02, 1.2, 0.4, Vector3(0, 2.4, 0), Color("d9473b"), 8)
		"awning", "awning_wide":
			var aw := 0.9 if id == "awning" else 1.8
			s.box(Vector3(aw, 0.05, 0.33), Vector3(0, 0.7, 0.0), Color("d9473b"), 0.0, Vector3(0.4, 0, 0))
		"parasol_b":
			s.cyl(0.03, 0.04, 2.3, Vector3(0, 1.15, 0), METAL)
			s.cyl(0.02, 1.0, 0.4, Vector3(0, 2.4, 0), Color("3fb8af"), 8)
		"fridge":
			s.box(Vector3(0.9, 1.0, 0.9), Vector3(0, 0.5, 0), Color("f2f0ea"))
			s.box(Vector3(0.8, 0.04, 0.02), Vector3(0, 0.62, 0.46), METAL)
			s.ball(0.12, Vector3(-0.2, 1.1, 0.0), Color("dff23a"), Vector3.ONE, 5, 3)
		"trafficlight":
			s.cyl(0.05, 0.07, 3.2, Vector3(0, 1.6, 0), DARK)
			s.box(Vector3(0.3, 0.8, 0.25), Vector3(0, 3.0, 0), DARK)
			s.ball(0.07, Vector3(0, 3.25, 0.13), Color("d9473b"), Vector3.ONE, 5, 3)
			s.ball(0.07, Vector3(0, 3.0, 0.13), Color("ffd642"), Vector3.ONE, 5, 3)
			s.ball(0.07, Vector3(0, 2.75, 0.13), Color("3d806a"), Vector3.ONE, 5, 3)
		"fence_low", "fence":
			var h := 0.6 if id == "fence_low" else 1.0
			s.box(Vector3(2.0, 0.06, 0.05), Vector3(0, h * 0.8, 0), WOOD)
			s.box(Vector3(2.0, 0.06, 0.05), Vector3(0, h * 0.4, 0), WOOD)
			for x in [-0.95, 0.95]:
				s.box(Vector3(0.08, h, 0.08), Vector3(x, h * 0.5, 0), TRUNK)
		"kiosk":
			# a snack kiosk, its window and striped awning toward +z (like every model here)
			var body := Color("3fb8af")
			s.box(Vector3(2.7, 2.1, 1.9), Vector3(0, 1.05, 0), body)
			s.box(Vector3(2.9, 0.18, 2.1), Vector3(0, 2.2, 0), Color("f2f0ea"))
			s.box(Vector3(1.9, 0.9, 0.06), Vector3(0, 1.45, 0.97), Color("29392f"))
			s.box(Vector3(2.1, 0.08, 0.5), Vector3(0, 0.98, 1.2), Color("c08a55"))
			for k in 6:
				var c := Color("d9473b") if k % 2 == 0 else Color("f5f5f5")
				s.box(Vector3(0.48, 0.07, 1.25), Vector3(-1.2 + k * 0.48, 2.0, 1.45), c, 0.0, Vector3(-0.38, 0, 0))
			s.ball(0.28, Vector3(0.0, 2.65, 0.0), Color("ffe27a"), Vector3.ONE, 6, 4)
			s.cyl(0.0, 0.2, 0.55, Vector3(0.0, 2.35, 0.0), Color("c9a56b"), 6, Vector3(PI, 0, 0))
			s.box(Vector3(0.7, 0.5, 0.06), Vector3(-0.8, 1.55, 0.98), Color("ede3cc"))
		"bicycle":
			# a bicycle parked: front +z, wheels as discs, a thin frame, a bar and a seat
			for z in [-0.55, 0.55]:
				s.cyl(0.33, 0.33, 0.05, Vector3(0, 0.33, z), Color("25272b"), 10, Vector3(0, 0, PI * 0.5))
				s.cyl(0.08, 0.08, 0.07, Vector3(0, 0.33, z), METAL, 6, Vector3(0, 0, PI * 0.5))
			var fc := Color("d9473b")
			s.box(Vector3(0.05, 0.05, 0.95), Vector3(0, 0.72, 0.0), fc)
			s.box(Vector3(0.05, 0.06, 0.8), Vector3(0, 0.52, -0.1), fc, 0.0, Vector3(0.0, 0, 0))
			s.box(Vector3(0.05, 0.5, 0.05), Vector3(0, 0.55, -0.42), fc, 0.0, Vector3(0.35, 0, 0))
			s.box(Vector3(0.05, 0.6, 0.05), Vector3(0, 0.65, 0.5), METAL, 0.0, Vector3(-0.3, 0, 0))
			s.box(Vector3(0.55, 0.04, 0.04), Vector3(0, 1.0, 0.6), DARK)
			s.box(Vector3(0.2, 0.06, 0.28), Vector3(0, 0.98, -0.42), DARK)
		"sitter_a", "sitter_b", "sitter_c":
			# someone sitting on a bench (seat 0.55 m), facing +z
			var shirt: Color = {"sitter_a": Color("d9473b"), "sitter_b": Color("2a54a3"), "sitter_c": Color("ffd642")}[id]
			s.box(Vector3(0.36, 0.16, 0.5), Vector3(0, 0.63, 0.15), Color("2c3a52"))
			s.box(Vector3(0.3, 0.45, 0.14), Vector3(0, 0.34, 0.4), Color("2c3a52"))
			s.ball(0.22, Vector3(0, 0.98, -0.02), shirt, Vector3(1.0, 1.35, 0.7), 7, 4)
			s.ball(0.14, Vector3(0, 1.38, 0.0), Color("e3b48a"), Vector3(1, 1.1, 1), 7, 4)
			s.ball(0.15, Vector3(0, 1.43, -0.02), Color("3b2a1e"), Vector3(1, 0.7, 1), 7, 3)
			for x in [-0.25, 0.25]:
				s.box(Vector3(0.09, 0.09, 0.4), Vector3(x, 0.92, 0.18), shirt, 0.0, Vector3(0.5, 0, 0))
		"poster":
			# a tournament poster on its two posts, face to +z
			s.box(Vector3(0.07, 1.9, 0.07), Vector3(-0.5, 0.95, -0.06), TRUNK)
			s.box(Vector3(0.07, 1.9, 0.07), Vector3(0.5, 0.95, -0.06), TRUNK)
			s.box(Vector3(1.2, 1.45, 0.05), Vector3(0, 1.35, 0.0), Color("f5f5f5"))
			s.box(Vector3(1.1, 0.36, 0.06), Vector3(0, 1.8, 0.01), Color("2a54a3"))
			s.ball(0.26, Vector3(0, 1.32, 0.04), Color("dff23a"), Vector3(1, 1, 0.3), 8, 4)
			s.box(Vector3(1.1, 0.14, 0.06), Vector3(0, 0.78, 0.01), Color("d9473b"))
		"bunting":
			# a string of flags, 6 m along x, sagging in the middle
			var flags := [Color("d9473b"), Color("ffd642"), Color("f5f5f5"), Color("2a54a3"), Color("3fb8af")]
			for k in 13:
				var t := float(k) / 12.0
				var sag := -0.5 * (1.0 - pow(2.0 * t - 1.0, 2.0))
				s.cyl(0.0, 0.1, 0.28, Vector3(-3.0 + 6.0 * t, 3.0 + sag - 0.14, 0), flags[k % flags.size()], 3, Vector3(PI, 0, 0))
			s.box(Vector3(6.0, 0.015, 0.015), Vector3(0, 2.78, 0), DARK)
		"manhole":
			s.flat(Vector2(0.45, 0.45), Vector3(0, 0.02, 0), Color("55575c"), 10)
			s.flat(Vector2(0.3, 0.3), Vector3(0, 0.03, 0), Color("45474c"), 8)
		"gatepost":
			s.box(Vector3(0.3, 2.4, 0.3), Vector3(0, 1.2, 0), Color("a0523d"))
			s.box(Vector3(0.42, 0.14, 0.42), Vector3(0, 2.45, 0), Color("e3d6c3"))
		"pole":
			s.cyl(0.05, 0.06, 3.4, Vector3(0, 1.7, 0), TRUNK)
		"dirt":
			s.flat(Vector2(1.0, 0.8), Vector3(0, 0.03, 0), Color("8a6a46"), 9)
			s.flat(Vector2(0.62, 0.5), Vector3(0.1, 0.04, 0.05), Color("7a5a3c"), 7, 0.5)
		"tuft", "tuft_dry":
			# weeds: five thin blades leaning out of one spot
			var col: Color = LEAF[1].lightened(0.1) if id == "tuft" else Color("a99a55")
			for k in 5:
				var a := k * TAU / 5.0 + 0.4
				var h := 0.34 + 0.12 * float(k % 3)
				s.blade(Vector3(cos(a) * 0.04, 0.0, sin(a) * 0.04), Vector3(cos(a) * 0.2, h, sin(a) * 0.2), 0.04, col.darkened(0.07 * float(k % 2)))
		"flower_patch":
			# a little bed: a mound of soil and a handful of blooms
			s.cyl(0.55, 0.62, 0.1, Vector3(0, 0.05, 0), Color("6b4a32"), 7)
			var blooms := [Color("d9473b"), Color("ffd642"), Color("f5f5f5"), Color("9a5cf0"), Color("ff8fb0"), Color("ffd642")]
			for k in 6:
				var a := k * TAU / 6.0
				var r := 0.3 if k % 2 == 0 else 0.12
				s.cyl(0.0, 0.015, 0.2, Vector3(cos(a) * r, 0.2, sin(a) * r), LEAF[1], 3)
				s.ball(0.085, Vector3(cos(a) * r, 0.31, sin(a) * r), blooms[k], Vector3(1, 0.8, 1), 4, 2)
		_:
			return null
	return s.build()
