class_name HousePack
extends RefCounted
## The Academy house's model pack (tools/academy_models.py): CC0 KayKit furniture brought
## to the club's look and composed into levelled sets (bed_1 ... bed_4), one glb of
## vertex-coloured meshes without any texture - the same kind as ClubPack, the same
## material (ClubScenery.prop_material / ClubMaterial.tinted).
##
## Where it comes from: like ClubPack - the web build leaves it out of the game pack and the
## page serves models/academy_props.<version>.glb (tools/build_web.sh needs one more copy
## line and export_presets.cfg the exclude assets/academy/models/*); everywhere else it is
## read from res://. Until it is here - or if it never comes - every id has a simple form made
## in code (HouseShapes), so the house always stands. `generation` counts the arrivals.

const RES_PATH := "res://assets/academy/models/academy_props.glb"

enum { IDLE, LOADING, READY, FAILED }

static var state := IDLE
static var generation := 0
static var _pack := {}              # id -> ArrayMesh
static var _simple := {}            # id -> ArrayMesh
static var _tinted := {}            # "id|club" -> ArrayMesh (club colour swapped in)
static var force_simple := false    # tools: show the code forms even when the pack is here


static func request(host: Node) -> void:
	if state != IDLE:
		return
	state = LOADING
	if OS.has_feature("web"):
		_download(host)
		return
	if not FileAccess.file_exists(RES_PATH):
		state = FAILED
		return
	_arrived(FileAccess.get_file_as_bytes(RES_PATH))


static func _download(host: Node) -> void:
	var base := String(JavaScriptBridge.eval("location.href.split('#')[0].split('?')[0].replace(/[^/]*$/, '')", true))
	var req := HTTPRequest.new()
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			_arrived(body)
		else:
			state = FAILED)
	if req.request(base + "models/academy_props.%s.glb" % HousePackInfo.VERSION) != OK:
		req.queue_free()
		state = FAILED


static func _arrived(bytes: PackedByteArray) -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_buffer(bytes, "", st) != OK:
		state = FAILED
		return
	var scene := doc.generate_scene(st)
	if scene == null:
		state = FAILED
		return
	for n in scene.get_children():
		var mi := n as MeshInstance3D
		if mi and mi.mesh is ArrayMesh:
			_pack[String(mi.name)] = mi.mesh
	scene.free()
	state = READY if not _pack.is_empty() else FAILED
	if state == READY:
		generation += 1


static func has_pack() -> bool:
	return state == READY and not force_simple


static func in_pack(id: String) -> bool:
	return has_pack() and _pack.has(id)


## The mesh of a prop: the pack's, else its simple form; null for an unknown id.
static func mesh(id: String) -> ArrayMesh:
	if has_pack() and _pack.has(id):
		return _pack[id]
	if not _simple.has(id):
		_simple[id] = HouseShapes.make(id)
	return _simple[id]


## The same mesh with the club's two blues (CLUB_BLUE, CLUB_DARK in the vertices) swapped for
## the colour the player chose for the club (ClubMaterial.CLUB_COLORS[i]); cached.
static func club_mesh(id: String, club: Color) -> ArrayMesh:
	var m := mesh(id)
	if m == null or club.is_equal_approx(HouseShapes.CLUB_BLUE):
		return m
	var key := "%s|%s" % [id, club.to_html()]
	if _tinted.has(key):
		return _tinted[key]
	var arr := m.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var dark := club.darkened(0.3)
	for i in cols.size():
		var c := cols[i]
		if _near(c, HouseShapes.CLUB_BLUE):
			cols[i] = club
		elif _near(c, HouseShapes.CLUB_DARK):
			cols[i] = dark
	arr[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_tinted[key] = out
	return out


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.012 and absf(a.g - b.g) < 0.012 and absf(a.b - b.b) < 0.012


## Triangles of a prop (for budgets).
static func tris(id: String) -> int:
	var m := mesh(id)
	if m == null:
		return 0
	var arr := m.surface_get_arrays(0)
	return (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
