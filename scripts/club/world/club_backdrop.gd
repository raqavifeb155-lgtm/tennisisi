class_name ClubBackdrop
extends Node3D
## What the club sees at the edge of the world, all the way round (stream H): the river,
## the bridge and the far city to the north are Scenery's; this adds the other three
## sides. Simple, quiet silhouettes - nothing here is drawn closely, and each sector is
## its own MultiMesh so what the camera isn't facing is not drawn at all:
##   - islands in the river (green mounds with a few trees),
##   - a forest at the back of the park, east, west and behind the street's shops,
##   - a far skyline of towers to the east, south and west, hazed by the fog.

const WATER_Y := Scenery.WATER_Y

var _skyline: Array[MultiMeshInstance3D] = []
var _forest: Array[MultiMeshInstance3D] = []
var _islands: MeshInstance3D
var _islands_far: MeshInstance3D   # the two farther islands: High only


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	_build_skyline(rng)
	_build_forest(rng)
	_build_islands(rng)


func refresh(high: bool) -> void:
	# Low keeps every second tree of the forest: the instance count is the budget.
	_islands_far.visible = high
	for mmi in _forest:
		mmi.multimesh.visible_instance_count = mmi.multimesh.instance_count if high else mmi.multimesh.instance_count / 2


## Towers on a ring far out, three sectors (east, south, west), tinted by the haze.
func _build_skyline(rng: RandomNumberGenerator) -> void:
	var facade: StandardMaterial3D = get_parent().world.call("_facade")
	var tints := [Color(0.80, 0.70, 0.57), Color(0.62, 0.40, 0.31), Color(0.52, 0.60, 0.68), Color(0.86, 0.83, 0.78),
		Color(0.42, 0.45, 0.50), Color(0.70, 0.55, 0.45)]
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	for sector in 3:
		var xf: Array[Transform3D] = []
		var cols: Array[Color] = []
		var lo := 62.0 + sector * 80.0
		var a := lo
		while a < lo + 80.0:
			var r := rng.randf_range(250.0, 330.0)
			var phi := deg_to_rad(a)
			var w := rng.randf_range(24.0, 50.0)
			var d := rng.randf_range(24.0, 40.0)
			var h := rng.randf_range(34.0, 90.0) if rng.randf() < 0.8 else rng.randf_range(100.0, 150.0)
			var pos := Vector3(sin(phi) * r, h * 0.5 - 0.3, -cos(phi) * r)
			xf.append(Transform3D(Basis.from_euler(Vector3(0.0, phi + rng.randf_range(-0.2, 0.2), 0.0)) * Basis.from_scale(Vector3(w, h, d)), pos))
			cols.append(tints[rng.randi() % tints.size()])
			a += rng.randf_range(4.0, 7.5)
		_skyline.append(_mm(box, facade, xf, cols))


## Conifers and round crowns as cones and blobs: a few triangles each.
func _build_forest(rng: RandomNumberGenerator) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 0
	cone.cap_bottom = false
	var mat := ClubMaterial.get_mat(Color.WHITE, false).duplicate()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	for sector in 3:
		var xf: Array[Transform3D] = []
		var cols: Array[Color] = []
		var n := 40
		for i in n:
			var side := sector   # 0 east, 1 south, 2 west
			var pos := Vector3.ZERO
			match side:
				0:
					pos = Vector3(rng.randf_range(72.0, 125.0), 0.0, rng.randf_range(-60.0, 90.0))
				1:
					pos = Vector3(rng.randf_range(-130.0, 130.0), 0.0, rng.randf_range(78.0, 130.0))
				2:
					pos = Vector3(-rng.randf_range(72.0, 125.0), 0.0, rng.randf_range(-60.0, 90.0))
			if absf(pos.x) < 56.0 and pos.z < 60.0:
				continue
			var h := rng.randf_range(9.0, 17.0)
			var r := h * rng.randf_range(0.26, 0.38)
			xf.append(Transform3D(Basis.from_scale(Vector3(r, h, r)), pos + Vector3(0, h * 0.5 - 0.3, 0)))
			var g := rng.randf_range(0.8, 1.1)
			cols.append(Color(0.19 * g, 0.36 * g, 0.2 * g).lerp(Color(0.34, 0.45, 0.26), rng.randf() * 0.3))
		_forest.append(_mm(cone, mat, xf, cols))


## A few islands in the river, each a mound with trees and a rock.
func _build_islands(rng: RandomNumberGenerator) -> void:
	var near := ClubShapes.new()
	var far := ClubShapes.new()
	var spots := [Vector3(-64.0, 0.0, -96.0), Vector3(58.0, 0.0, -104.0), Vector3(-26.0, 0.0, -150.0), Vector3(96.0, 0.0, -140.0)]
	for i in spots.size():
		var s: ClubShapes = near if i < 2 else far
		var c: Vector3 = spots[i]
		var r: float = rng.randf_range(10.0, 17.0)
		s.cyl(r * 0.8, r * 1.05, 2.2, Vector3(c.x, WATER_Y + 0.4, c.z), Color("c9b98d"), 10)               # sand under
		s.cyl(r * 0.72, r * 0.8, 0.5, Vector3(c.x, WATER_Y + 1.7, c.z), Color("668f3b"), 10)               # grass top
		for k in 5:
			var a := rng.randf_range(0.0, TAU)
			var d := rng.randf_range(0.0, r * 0.55)
			var h := rng.randf_range(4.0, 8.5)
			var p := Vector3(c.x + cos(a) * d, WATER_Y + 1.95, c.z + sin(a) * d)
			s.cyl(0.18, 0.28, h * 0.4, p + Vector3(0, h * 0.2, 0), ClubShapes.TRUNK, 5)
			if k % 2 == 0:
				s.cyl(0.0, h * 0.28, h * 0.8, p + Vector3(0, h * 0.7, 0), Color("436b38"), 6)
			else:
				s.ball(h * 0.3, p + Vector3(0, h * 0.62, 0), ClubShapes.LEAF[k % 4], Vector3(1, 0.9, 1), 6, 4)
		s.ball(1.6, Vector3(c.x + r * 0.6, WATER_Y + 1.5, c.z + 1.0), ClubShapes.STONE, Vector3(1, 0.6, 0.9), 5, 3)
	_islands = _island_node("islands", near)
	_islands_far = _island_node("islands_far", far)


func _island_node(node_name: String, s: ClubShapes) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = s.build()
	mi.material_override = ClubScenery.prop_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _mm(mesh: Mesh, mat: Material, xf: Array[Transform3D], cols: Array[Color]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi
