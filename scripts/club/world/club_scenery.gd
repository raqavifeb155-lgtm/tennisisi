class_name ClubScenery
extends Node3D
## The club as a place (stream H): everything around the places that makes the riverside
## park look lived in - or half abandoned, at the start. ClubWorld makes ONE call
## (ClubScenery.build) and this node does the rest: props from the model pack baked per
## map square (ClubProps / ClubLayout), ground detail (ClubTerrain), the 360-degree
## backdrop (ClubBackdrop), people and birds (ClubCrowd), the hour of the day
## (ClubDaytime). It follows the club's levels and the graphics preset by itself, so
## nothing else has to tell it anything: a construction built, the pack arriving, Low
## swapped for High are all noticed and the affected meshes rebuilt.
##
## Budget (docs/CLUB_HUB_TZ.md 9): a handful of draw calls - props are folded into a few
## meshes of one material, crowds and backdrops are MultiMeshes - and a few thousand
## triangles; High adds detail, Low leaves it out.

var world: ClubWorld
var props := ClubProps.new()
var _cells := {}                # Vector2i -> {"low": MeshInstance3D, "tall": MeshInstance3D}
var _sig := ""
var _gen := -1
var _high := true
var _t := 0.0
var _boards := {}               # place id -> MeshInstance3D (planks across the door of a shut room)
var _fence_mats: Array[StandardMaterial3D] = []
var _net_ok := false
const SHADOW_REACH := 26.0
const DRAW_RANGE := 80.0
var _tuning: Node
var terrain: ClubTerrain
var backdrop: ClubBackdrop
var crowd: ClubCrowd
var daytime: ClubDaytime

static var _prop_mat: StandardMaterial3D


## The one call: from ClubWorld._ready, right after the park's trees were cleared for the
## club's places. Takes the old random park (trees, lamps) away and starts the new one.
static func build(w: ClubWorld) -> void:
	_thin_park(w)
	var s := ClubScenery.new()
	s.name = "ClubScenery"
	s.world = w
	w.add_child(s)


## The material every prop wears: the club's soft toon, colours from the mesh's vertices
## (sRGB, as the pack and ClubShapes write them), no outline.
static func prop_material() -> StandardMaterial3D:
	if _prop_mat == null:
		_prop_mat = ClubMaterial.get_mat(Color.WHITE, false).duplicate()
		_prop_mat.vertex_color_use_as_albedo = true
		_prop_mat.vertex_color_is_srgb = true
	return _prop_mat


## Scenery's random park: swaying trees (trunks and crowns) and the thin lamps along the
## river. The club plants its own (ClubLayout), where its paths and places leave room.
static func _thin_park(w: ClubWorld) -> void:
	for c in w.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var mesh := mmi.multimesh.mesh
		var gone := false
		if mesh is CylinderMesh and absf((mesh as CylinderMesh).height - 3.2) < 0.01:
			gone = true     # tree trunks
		elif mesh is SphereMesh and mmi.material_override is ShaderMaterial:
			gone = true     # tree crowns
		elif mesh is BoxMesh and mmi.material_override is StandardMaterial3D and mmi.multimesh.instance_count > 10 and mmi.multimesh.instance_count < 40:
			var col := (mmi.material_override as StandardMaterial3D).albedo_color
			gone = col.is_equal_approx(Color(0.14, 0.15, 0.16))   # the lamps along the promenade
		if gone:
			mmi.queue_free()
	# the trunks' obstacles (ClubWorld._clear_reserved ran just before: they are all there is)
	w.walk.circles.clear()
	w.walk._circle_tags.clear()


func _ready() -> void:
	_high = world.high_quality()
	for c in world.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.material_override is StandardMaterial3D:
			var m := mi.material_override as StandardMaterial3D
			if m.albedo_texture != null and m.albedo_texture == world.get("_fence_tex") and not _fence_mats.has(m):
				_fence_mats.append(m)
	ClubLayout.fill(props)
	terrain = ClubTerrain.new()
	terrain.name = "terrain"
	add_child(terrain)
	backdrop = ClubBackdrop.new()
	backdrop.name = "backdrop"
	add_child(backdrop)
	crowd = ClubCrowd.new()
	crowd.name = "crowd"
	add_child(crowd)
	daytime = ClubDaytime.new()
	daytime.name = "daytime"
	add_child(daytime)
	ClubPack.request(self)
	_refresh(true)


func _process(delta: float) -> void:
	_t += delta
	# The camera is low and close: shadows reach as far as the eye cares (the preset's
	# own reach scales it; Graphics sets the base, this keeps it short).
	var sun := world.sun()
	if sun != null and sun.shadow_enabled:
		sun.directional_shadow_max_distance = SHADOW_REACH * _reach()
	var high := world.high_quality()
	if not _net_ok and fmod(_t, 0.5) < delta:
		_net_ok = _update_net()   # the court may not have been there yet when this was built
	var s := _signature()
	if s != _sig or ClubPack.generation != _gen or high != _high:
		_high = high
		_refresh(false)


func _reach() -> float:
	if _tuning == null:
		_tuning = get_node_or_null("/root/Tuning")
	return float(_tuning.get("gfx_reach")) if _tuning != null else 1.0


## What the club's state is, as far as scenery is concerned.
func _signature() -> String:
	var parts := PackedStringArray()
	for id in ["court", "stands", "gate", "shop", "locker", "trophy", "bar", "arena"]:
		parts.append(str(level_of(id)))
	parts.append(str(int(SaveData.played >= 1)))
	return ",".join(parts)


func level_of(owner: String) -> int:
	if ClubBuilds.TABLE.has(owner):
		return ClubBuilds.level(owner)
	return ClubPlaces.level(owner)


## Redraws what depends on a level, the pack or the preset.
func _refresh(first: bool) -> void:
	_sig = _signature()
	_gen = ClubPack.generation
	var list := props.visible(level_of, _high)
	world.walk.clear_tag("props")
	for p in list:
		if p.solid > 0.0:
			world.walk.add_circle(Vector2(p.xf.origin.x, p.xf.origin.z), p.solid, "props")
	var baked := ClubProps.bake(list, _high)
	for key in _cells:
		if not baked.has(key):
			for k in _cells[key]:
				(_cells[key][k] as MeshInstance3D).mesh = null
	for key in baked:
		if not _cells.has(key):
			_cells[key] = {}
		var d: Dictionary = baked[key]
		for k in ["small", "big", "tall"]:
			var mi: MeshInstance3D = _cells[key].get(k)
			if mi == null:
				if not d.has(k):
					continue
				mi = MeshInstance3D.new()
				mi.name = "props_%d_%d_%s" % [key.x, key.y, k]
				mi.material_override = prop_material()
				mi.visibility_range_end = ClubProps.RANGE[k]
				mi.visibility_range_end_margin = 6.0
				add_child(mi)
				_cells[key][k] = mi
			mi.mesh = d.get(k)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (k == "tall" and _high) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scenery_detail()
	_draw_distance()
	_update_boards()
	_update_fence()
	_net_ok = _update_net()
	if daytime:
		daytime.refresh(list)
	if terrain:
		terrain.refresh(level_of, _high)
	if backdrop:
		backdrop.refresh(_high)
	if crowd:
		crowd.refresh(_high)


## Planks over the door of a room that isn't open yet.
func _update_boards() -> void:
	for id in ["locker", "shop"]:
		var place := ClubPlaces.find(id)
		var shut := not ClubPlaces.is_open(place, SaveData.played, SaveData.titles)
		var node: MeshInstance3D = _boards.get(id)
		var c: Vector3 = place["pos"]
		if shut and node == null:
			node = MeshInstance3D.new()
			node.name = "boards_" + id
			node.material_override = prop_material()
			node.mesh = _boards_mesh()
			node.position = Vector3(c.x, 0.0, c.z + ClubWorld.PAVILION.y * 0.5 + 0.05)
			add_child(node)
			_boards[id] = node
		if node:
			node.visible = shut
		world.walk.clear_tag("boards_" + id)
		if shut:
			var hz := ClubWorld.PAVILION.y * 0.5
			world.walk.add_box(Rect2(c.x - 0.95, c.z + hz - 0.2, 1.9, 0.9), "boards_" + id)


static func _boards_mesh() -> ArrayMesh:
	var s := ClubShapes.new()
	var wood := Color("a8794a")
	var old := Color("7a5a3c")
	for k in 4:
		s.box(Vector3(2.1, 0.22, 0.05), Vector3(0.0, 0.35 + k * 0.5, 0.0), wood if k % 2 == 0 else old, 0.0, Vector3(0.0, 0.0, [0.03, -0.05, 0.04, -0.02][k]))
	for x in [-0.8, 0.8]:
		s.box(Vector3(0.12, 2.1, 0.06), Vector3(x, 1.05, -0.02), old)
	s.box(Vector3(0.14, 2.5, 0.05), Vector3(0.0, 1.1, 0.05), wood, 0.0, Vector3(0.0, 0.0, 0.55))
	return s.build()


## The court's fence: rusty while the court is level 0 or 1, the club's green after.
func _update_fence() -> void:
	var rusty := level_of("court") < 2
	for m in _fence_mats:
		m.albedo_color = Color(0.5, 0.3, 0.2) if rusty else Color(0.16, 0.24, 0.2)


## The court's net while the court is still level 0-1: sagging in the middle, its posts
## leaning in (the court's own flat net and tape hide behind it; level 2 is a new net).
func _update_net() -> bool:
	var main := world.get_parent()
	var court = main.get("court") if main != null else null
	if court == null:
		return false
	var root: Node3D = court.get("_net_root")
	if root == null or root.get_child_count() < 4:
		return false
	var old := root.get_node_or_null("sag_net")
	var sag := level_of("court") < 2
	if sag and old == null:
		root.get_child(0).visible = false
		root.get_child(1).visible = false
		var net_mat: Material = (root.get_child(0) as MeshInstance3D).material_override
		var hw := Court.NET_HALF_WIDTH
		var n := 26
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tape := ClubShapes.new()
		var prev := Vector2.ZERO
		for k in n + 1:
			var x := lerpf(-hw, hw, float(k) / n)
			var top := _sag_height(x)
			var bottom := 0.04 + 0.05 * sin(float(k) * 2.3)       # a frayed bottom edge
			if k > 0:
				var x0 := prev.x
				var t0 := prev.y
				var b0 := 0.04 + 0.05 * sin(float(k - 1) * 2.3)
				for v in [Vector3(x0, b0, 0), Vector3(x0, t0, 0), Vector3(x, top, 0), Vector3(x0, b0, 0), Vector3(x, top, 0), Vector3(x, bottom, 0)]:
					st.set_normal(Vector3(0, 0, 1))
					st.add_vertex(v)
				var mid := Vector3((x0 + x) * 0.5, (t0 + top) * 0.5, 0.0)
				var ang := atan2(top - t0, x - x0)
				tape.box(Vector3(maxf(x - x0, 0.1) + 0.03, 0.07, 0.035), mid, Color("f2f0ea"), 0.0, Vector3(0.0, 0.0, ang))
			prev = Vector2(x, top)
		var panel := MeshInstance3D.new()
		panel.name = "sag_net"
		panel.mesh = st.commit()
		panel.material_override = net_mat
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(panel)
		var strap := MeshInstance3D.new()
		strap.name = "sag_tape"
		strap.mesh = tape.build()
		strap.material_override = prop_material()
		strap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(strap)
		for i in [2, 3]:
			var post := root.get_child(i) as Node3D
			post.rotation.z = -signf(post.position.x) * 0.1
	elif not sag and old != null:
		old.queue_free()
		root.get_node("sag_tape").queue_free()
		root.get_child(0).visible = true
		root.get_child(1).visible = true
		for i in [2, 3]:
			(root.get_child(i) as Node3D).rotation.z = 0.0
	return true


static func _sag_height(x: float) -> float:
	var t := clampf(absf(x) / Court.NET_HALF_WIDTH, 0.0, 1.0)
	return lerpf(0.8, 1.0, t * t)


## What the props cost, by id: {id: [count, triangles]} for what is visible now (budgets).
func prop_stats() -> Dictionary:
	var out := {}
	for p in props.visible(level_of, _high):
		if not out.has(p.id):
			out[p.id] = [0, 0]
		out[p.id][0] += 1
		out[p.id][1] += ClubPack.tris(p.id)
	return out


## Low: the park's own extras are thinned - no old bushes (the club's own are baked into the
## props), one cloud in three, one boat in three and no flocks of birds (each bird is two
## meshes). High keeps them all.
func _scenery_detail() -> void:
	for c in world.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or not (mmi.multimesh.mesh is SphereMesh):
			continue
		var mm := mmi.multimesh
		if mm.instance_count > 20 and mm.instance_count < 120 and mmi.material_override is StandardMaterial3D and (mmi.material_override as StandardMaterial3D).vertex_color_use_as_albedo:
			mmi.visible = _high   # the old bushes (72) and flowers (32)
	var clouds: Array = world.get("_clouds")
	for i in clouds.size():
		(clouds[i] as Node3D).visible = _high or i % 3 == 0
	var boats: Array = world.get("_boats")
	for i in boats.size():
		(boats[i] as Node3D).visible = _high or i == 0


## Every smallish thing of the world (the places' boards and walls, the park's boats and
## bridge towers, B's constructions) stops being drawn far off: from the gate looking
## north the whole club is in view, and what stands 80 m away is a few pixels.
func _draw_distance() -> void:
	for n in world.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.visibility_range_end > 0.0 or g is Label3D and false:
			continue
		var p := g.get_parent()
		var mine := false
		while p != null and p != world:
			if p == self:
				mine = true
			p = p.get_parent()
		if mine:
			continue
		if g is MultiMeshInstance3D:
			continue   # a MultiMesh's box is the whole spread of its instances
		var size := g.get_aabb().size.length()
		if g is Label3D:
			g.visibility_range_end = 38.0      # a sign's text can't be read from farther
		elif size < 3.0:
			g.visibility_range_end = 48.0
		elif size < 8.0:
			g.visibility_range_end = 66.0
		elif size < 16.0:
			g.visibility_range_end = DRAW_RANGE
		else:
			continue
		g.visibility_range_end_margin = 6.0
