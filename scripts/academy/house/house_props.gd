class_name HouseProps
extends RefCounted
## What each level puts into a room of the house (spec 2.3): the layout of the art stream (HouseLayout: the
## items of a room, their anchors, the id of an item at a room level) drawn with its models (HousePack: the
## CC0 pack, or the form made in code when the pack isn't here - HouseShapes). This file turns that into what the
## house needs: ONE mesh per room (vertex colours, ClubScenery.prop_material()), the chalk marks «здесь будет»,
## the scaffolding of a level on the build, and the rects the hero can't walk through.
##
## A room's own frame is the art's (HouseLayout): 6 x 6 m, x and z in [-3, 3], the back wall at z = -3, the wall
## to the hall at x = -3, the door at z = +1.5; a room west of the hall is the same plan mirrored (x -> -x, yaw ->
## -yaw: the things keep their faces, only their places and turns are mirrored). Table: HouseRooms.

const SIZE := 3.0                     # a room's half width and depth
const CHALK_COL := Color("cfc8b8")
const MIN_MARK := 0.6                 # a chalk mark is never thinner than this


static func _xf(spot: Vector4, side: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(spot.z * side)), Vector3(spot.x * side, spot.w, spot.y))


## The things standing in a room at this level: [{id, item, spot}], what the layout says (and the Low preset leaves the
## small cosy things out, HouseShapes.DECOR).
static func placed(room: String, level: int) -> Array:
	var out: Array = []
	for it in HouseLayout.items(room):
		var id := HouseLayout.id_at(it, level)
		if id == "" or (HousePack.detail == 0 and id in HouseShapes.DECOR):
			continue
		for sp in it["spots"]:
			out.append({"id": id, "item": it, "spot": sp})
	return _fit(out)


## The room's budget in triangles by the pack's detail (spec 8.1: 3k Low, 5k Medium, 8k High).
const BUDGET := [3000, 5000, 8000]
const FLOOR_EXTRA := 600              # the chalk marks, the scaffolding: kept free of the budget


## A full room (the canteen at level 5: 8 chairs, 2 tables, the kitchen) can be over its budget: the repeated things
## (chairs, beds, the second of a pair) lose their last spots, one at a time from the heaviest, until it fits; never
## below one of a kind.
static func _fit(list: Array) -> Array:
	var limit: int = BUDGET[clampi(HousePack.detail, 0, 2)] - FLOOR_EXTRA
	var total := 0
	for t in list:
		total += HousePack.tris(String(t["id"]))
	while total > limit:
		var best := -1
		var best_n := 0
		for i in list.size():
			var id := String(list[i]["id"])
			var same := 0
			for t in list:
				if t["item"] == list[i]["item"]:
					same += 1
			if same > 1 and HousePack.tris(id) > best_n:
				best = i
				best_n = HousePack.tris(id)
		if best < 0:
			break
		# the last spot of that item goes
		var last := -1
		for i in list.size():
			if list[i]["item"] == list[best]["item"]:
				last = i
		total -= HousePack.tris(String(list[last]["id"]))
		list.remove_at(last)
	return list


## The footprint (x, z in the room's frame) of a thing from the box of its mesh, turned by its spot.
static func _rect(id: String, sp: Vector4) -> Rect2:
	var m := HousePack.mesh(id)
	if m == null:
		return Rect2()
	var bb := m.get_aabb()
	var b := Basis(Vector3.UP, deg_to_rad(sp.z))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for cx in [bb.position.x, bb.end.x]:
		for cz in [bb.position.z, bb.end.z]:
			var p := b * Vector3(cx, 0.0, cz)
			lo = Vector2(minf(lo.x, p.x + sp.x), minf(lo.y, p.z + sp.y))
			hi = Vector2(maxf(hi.x, p.x + sp.x), maxf(hi.y, p.z + sp.y))
	return Rect2(lo, hi - lo)


## The walk's obstacles of a room at `built` levels, in the room's own frame (unmirrored): the things that stand
## on the floor and are higher than knee-high (rugs, mats and wall pictures don't stop anybody).
static func solids(room: String, built: int) -> Array:
	var out: Array = []
	for t in placed(room, built):
		var m := HousePack.mesh(String(t["id"]))
		var sp: Vector4 = t["spot"]
		if m == null:
			continue
		var bb := m.get_aabb()
		if bb.size.y < 0.4 or bb.position.y + sp.w > 0.5:
			continue
		var r := _rect(String(t["id"]), sp).intersection(Rect2(-SIZE, -SIZE, SIZE * 2.0, SIZE * 2.0))
		if r.size.x > 0.0 and r.size.y > 0.0:
			out.append(r)
	return out


## Where what a level adds will stand: a rect for each of its things that has something on the floor (else of
## everything it adds), in the room's frame, inside the room, never thinner than MIN_MARK. A level adds the items
## whose `from` is this level.
static func marks(room: String, lv: int) -> Array:
	var out := _marks(room, lv, true)
	return out if not out.is_empty() else _marks(room, lv, false)   # all of it is on a desk or a wall: mark its shadow on the floor


static func _marks(room: String, lv: int, floor_only: bool) -> Array:
	var out: Array = []
	for it in HouseLayout.items(room):
		if int(it["from"]) != lv:
			continue
		var id := HouseLayout.id_at(it, lv)
		var m := HousePack.mesh(id)
		if id == "" or m == null:
			continue
		var bb := m.get_aabb()
		for sp in it["spots"]:
			if floor_only and bb.position.y + (sp as Vector4).w > 0.5:
				continue
			var r := _rect(id, sp).intersection(Rect2(-SIZE + 0.1, -SIZE + 0.1, SIZE * 2.0 - 0.2, SIZE * 2.0 - 0.2))
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				continue
			var c := r.get_center()
			var sz := Vector2(maxf(r.size.x, MIN_MARK), maxf(r.size.y, MIN_MARK))
			out.append(Rect2(c - sz * 0.5, sz).grow(0.05))
	return out


## The room as one mesh: its things at `built` levels, the chalk marks of level `mark` (0: none), the scaffolding of
## level `scaffold` (0: none). `side`: +1 the plan as written, -1 mirrored. `floor`: the room's floor colour (the
## marks are a darker patch of it). null when there is nothing to draw (a surface without vertices is an error).
static func mesh(room: String, built: int, mark: int, scaffold: int, side: int, floor := Color("8f8a80")) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	var club := ClubBuilds.club_color()
	for t in placed(room, built):
		var m := HousePack.club_mesh(String(t["id"]), club)
		if m == null:
			continue
		st.append_from(m, 0, _xf(t["spot"], side))
		n += 1
	var extra := ClubShapes.new()
	var e := 0
	if mark >= 1 and mark <= HouseRooms.MAX_LEVEL:
		for r in marks(room, mark):
			_mark(extra, r, side, floor.darkened(0.5))
			e += 1
	if scaffold >= 1:
		for r in marks(room, scaffold):
			_scaffold(extra, r, side)
			e += 1
	if e > 0:
		st.append_from(extra.build(), 0, Transform3D.IDENTITY)
		n += e
	return st.commit() if n > 0 else null


## «Здесь будет»: a dark patch of floor with a chalk outline.
static func _mark(sb: ClubShapes, r: Rect2, side: int, col: Color) -> void:
	var c := r.get_center()
	var cx := c.x * side
	sb.box(Vector3(r.size.x, 0.02, r.size.y), Vector3(cx, 0.012, c.y), col)
	var t := 0.05
	sb.box(Vector3(r.size.x, 0.022, t), Vector3(cx, 0.016, r.position.y), CHALK_COL)
	sb.box(Vector3(r.size.x, 0.022, t), Vector3(cx, 0.016, r.end.y), CHALK_COL)
	sb.box(Vector3(t, 0.022, r.size.y), Vector3(r.position.x * side, 0.016, c.y), CHALK_COL)
	sb.box(Vector3(t, 0.022, r.size.y), Vector3(r.end.x * side, 0.016, c.y), CHALK_COL)


## Scaffolding on the spot of a level being built: four poles and planks.
static func _scaffold(sb: ClubShapes, r: Rect2, side: int) -> void:
	var c := r.get_center()
	var cx := c.x * side
	var wood := Color("c08a55")
	var dark := Color("6b4a32")
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			sb.cyl(0.05, 0.05, 1.9, Vector3(cx + sx * r.size.x, 0.95, c.y + sz * r.size.y), wood, 5)
	for y in [0.6, 1.3]:
		sb.box(Vector3(r.size.x + 0.1, 0.06, 0.12), Vector3(cx, y, c.y - r.size.y * 0.5), dark)
		sb.box(Vector3(r.size.x + 0.1, 0.06, 0.12), Vector3(cx, y, c.y + r.size.y * 0.5), dark)
	sb.box(Vector3(0.12, 0.06, r.size.y), Vector3(cx - r.size.x * 0.5, 1.3, c.y), dark)
	sb.box(Vector3(0.12, 0.06, r.size.y), Vector3(cx + r.size.x * 0.5, 1.3, c.y), dark)
