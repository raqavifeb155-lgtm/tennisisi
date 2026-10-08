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
			s.box(Vector3(1.6, 0.4, 0.06), Vector3(0, 0.72, 0.2), WOOD)
			for x in [-0.7, 0.7]:
				s.box(Vector3(0.08, 0.45, 0.4), Vector3(x, 0.22, 0), DARK)
		"streetlight":
			s.cyl(0.05, 0.08, 4.0, Vector3(0, 2.0, 0), DARK)
			s.box(Vector3(0.9, 0.12, 0.3), Vector3(0.25, 4.1, 0), DARK)
			s.box(Vector3(0.5, 0.06, 0.24), Vector3(0.45, 4.02, 0), Color("ffe27a"))
		"trash_bin":
			s.cyl(0.3, 0.26, 0.9, Vector3(0, 0.45, 0), Color("3d806a"), 8)
			s.cyl(0.33, 0.33, 0.08, Vector3(0, 0.95, 0), DARK, 8)
		"trash_bags":
			s.ball(0.3, Vector3(-0.2, 0.28, 0), DARK, Vector3(1, 0.9, 1))
			s.ball(0.26, Vector3(0.25, 0.24, 0.1), Color("3a3f47"), Vector3(1, 0.9, 1))
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
			s.box(Vector3(0.05, 0.4, 0.3), Vector3(0.15, 0.2, 0), DARK, 0.0, Vector3(0, 0, 0.2))
		"car_hatch", "car_sedan", "car_wagon":
			var col: Color = {"car_hatch": Color("d9473b"), "car_sedan": Color("6b7f94"), "car_wagon": Color("e3d6c3")}[id]
			var len := 3.8 if id == "car_hatch" else 4.3
			s.box(Vector3(1.7, 0.6, len), Vector3(0, 0.55, 0), col)
			s.box(Vector3(1.5, 0.5, len * 0.5), Vector3(0, 1.05, 0.2), GLASS)
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
			s.box(Vector3(0.8, 0.5, 0.2), Vector3(0, 0.65, 0.3), Color("d9473b"))
		"chair_wood", "bar_chair":
			s.box(Vector3(0.45, 0.06, 0.45), Vector3(0, 0.45, 0), WOOD)
			s.box(Vector3(0.45, 0.45, 0.05), Vector3(0, 0.72, 0.2), WOOD)
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
		"rock", "rock_big", "stone_tall":
			var h: float = {"rock": 0.35, "rock_big": 1.1, "stone_tall": 1.6}[id]
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
		"awning":
			s.box(Vector3(2.4, 0.08, 1.0), Vector3(0, 0.5, 0.5), Color("d9473b"), 0.0, Vector3(0.4, 0, 0))
		"fence_low", "fence":
			var h := 0.6 if id == "fence_low" else 1.0
			s.box(Vector3(2.0, 0.06, 0.05), Vector3(0, h * 0.8, 0), WOOD)
			s.box(Vector3(2.0, 0.06, 0.05), Vector3(0, h * 0.4, 0), WOOD)
			for x in [-0.95, 0.95]:
				s.box(Vector3(0.08, h, 0.08), Vector3(x, h * 0.5, 0), TRUNK)
		_:
			return null
	return s.build()
