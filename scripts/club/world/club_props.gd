class_name ClubProps
extends RefCounted
## A bag of placed props (stream H): each is a pack id at a place, with a yaw, a size and
## a tint, and baked - per square of the map - into a few meshes of one material (the
## club's vertex-coloured one). A prop costs triangles and no draw call of its own: the
## whole lot is a handful of draws, and the squares the camera isn't looking at are
## culled whole. Rebuilt when the pack arrives, the quality changes or a level moves.
##
## A prop has:  id       a ClubPack id
##              xf       where and how it stands (a Transform3D; use `at()`)
##              tint     multiplied into its vertex colours
##              high     true: drawn on High and up only
##              shadow   true: casts the sun's shadow (High and up only; tall things)
##              far      true: seen from far off (trees, lamps, buildings): drawn farther
##              solid    > 0: the hero can't walk through (a circle of this radius, m)
##              owner    the place whose level cleans it up ("" = always there)
##              need     the owner's level at which it is gone (a ruin) - 0 = never goes
##              from     the owner's level from which it is there (a tidy-up) - 0 = always
##              tag      a name for a group (the evening's lamps, ...)

const CELL := 24.0
## Draw distances (m, to the middle of a square's mesh).
const RANGE := {"big": 100.0, "tall": 140.0}

class Prop:
	var id := ""
	var xf := Transform3D.IDENTITY
	var tint := Color.WHITE
	var high := false
	var shadow := false
	var far := false
	var solid := 0.0
	var owner := ""
	var need := 0
	var from := 0
	var tag := ""

	## The same prop carried with its building to another lot (t: ClubLots.xf), set down on the
	## ground there (the height above it kept).
	func moved(t: Transform3D) -> Prop:
		var q := Prop.new()
		q.id = id
		q.tint = tint
		q.high = high
		q.shadow = shadow
		q.far = far
		q.solid = solid
		q.owner = owner
		q.need = need
		q.from = from
		q.tag = tag
		var o := t * xf.origin
		o.y = xf.origin.y
		q.xf = Transform3D(t.basis * xf.basis, o)
		return q

var props: Array[Prop] = []


## Puts a prop down. yaw in radians; size is one number or a Vector3; tilt leans it.
func at(id: String, pos: Vector3, yaw := 0.0, size = 1.0, tilt := Vector3.ZERO) -> Prop:
	var p := Prop.new()
	p.id = id
	var s: Vector3 = size if size is Vector3 else Vector3.ONE * float(size)
	var b := Basis.from_euler(Vector3(tilt.x, yaw, tilt.z)) * Basis.from_scale(s)
	p.xf = Transform3D(b, pos)
	props.append(p)
	return p


func count() -> int:
	return props.size()


## Which props are there at the given levels (level_of: Callable owner -> int). `from_level_of`
## (when given) is what the tidy-ups (`from`) look at instead: the ruins (`need`) belong to a site,
## the tidy-ups to the building.
func visible(level_of: Callable, high: bool, from_level_of := Callable()) -> Array[Prop]:
	var out: Array[Prop] = []
	for p in props:
		if p.high and not high:
			continue
		if p.owner != "":
			var lv: int = level_of.call(p.owner)
			if p.need > 0 and lv >= p.need:
				continue
			if p.from > 0 and (int(from_level_of.call(p.owner)) if from_level_of.is_valid() else lv) < p.from:
				continue
		out.append(p)
	return out


## Bakes props into meshes per map square: {cell: {"big"|"tall": ArrayMesh}}.
## "tall" holds the ones that cast shadows (a mesh of their own, drawn twice on High and
## once, without the shadow, below it), "big" everything else; each is drawn out to its
## own distance (RANGE).
static func bake(list: Array[Prop], shadows := true) -> Dictionary:
	var cells := {}
	for p in list:
		var key := Vector2i(floori(p.xf.origin.x / CELL), floori(p.xf.origin.z / CELL))
		if not cells.has(key):
			cells[key] = {"big": _Acc.new(), "tall": _Acc.new()}
		# Without shadows (Low) "tall" is just "big": one draw call a square.
		var cls := "tall" if (p.shadow and shadows) else "big"
		var acc: _Acc = cells[key][cls]
		acc.add(ClubPack.mesh(p.id), p.xf, p.tint)
	var out := {}
	for key in cells:
		var d := {}
		for k in ["big", "tall"]:
			var acc: _Acc = cells[key][k]
			if acc.v.size() > 0:
				d[k] = acc.build()
		out[key] = d
	return out


## All of `list` in one go, without squares: {"big": mesh, "tall": mesh} (a key only when it has
## something). For a scenery that wants two draw calls for its whole set of props.
static func bake_one(list: Array[Prop], shadows := true) -> Dictionary:
	var big := _Acc.new()
	var tall := _Acc.new()
	for p in list:
		(tall if (p.shadow and shadows) else big).add(ClubPack.mesh(p.id), p.xf, p.tint)
	var out := {}
	if big.v.size() > 0:
		out["big"] = big.build()
	if tall.v.size() > 0:
		out["tall"] = tall.build()
	return out


## Collects transformed vertices of many meshes into one.
class _Acc:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	func add(mesh: ArrayMesh, xf: Transform3D, tint: Color) -> void:
		if mesh == null:
			return
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var cols = a[Mesh.ARRAY_COLOR]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var base := v.size()
			var nb := xf.basis.inverse().transposed()
			var white := tint == Color.WHITE
			for k in verts.size():
				v.append(xf * verts[k])
				n.append((nb * norms[k]).normalized())
				var col: Color = (cols as PackedColorArray)[k] if cols != null else Color.WHITE
				c.append(col if white else Color(col.r * tint.r, col.g * tint.g, col.b * tint.b, col.a))
			for k in idx:
				i.append(base + k)

	func build() -> ArrayMesh:
		var m := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = i
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m
