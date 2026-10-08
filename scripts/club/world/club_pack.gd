class_name ClubPack
extends RefCounted
## The club's model pack (stream H, tools/club_models.py): ~55 CC0 props of KayKit and
## Kenney, baked to one look, one glb of vertex-coloured meshes without any texture.
##
## Where it comes from: the web build leaves it out of the game pack
## (export_presets.cfg) and the page serves it as models/club_props.<version>.glb; the
## game downloads it after the start, the way it does the music (Sfx). Everywhere else
## (desktop, tests) it is read from res://. Until it is here - or if it never comes -
## every id has a simple form made in code (ClubShapes), so the club always stands.
##
## `generation` counts the arrivals; whoever drew props from `mesh()` redraws when it
## changes (ClubScenery polls it).

const RES_PATH := "res://assets/club/models/club_props.glb"

enum { IDLE, LOADING, READY, FAILED }

static var state := IDLE
static var generation := 0          # 0 while only the simple forms exist, 1 once the pack is here
static var _pack := {}              # id -> ArrayMesh
static var _simple := {}            # id -> ArrayMesh


## Starts getting the pack (once). `host` is any node in the tree (the download hangs a
## request node on it).
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
	var bytes := FileAccess.get_file_as_bytes(RES_PATH)
	_arrived(bytes)


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
	if req.request(base + "models/club_props.%s.glb" % ClubPackInfo.VERSION) != OK:
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
	return state == READY


## The mesh of a prop: the pack's, else its simple form; null for an unknown id.
static func mesh(id: String) -> ArrayMesh:
	if _pack.has(id):
		return _pack[id]
	if not _simple.has(id):
		_simple[id] = ClubShapes.make(id)
	return _simple[id]


## Triangles of a prop (for budgets).
static func tris(id: String) -> int:
	var m := mesh(id)
	if m == null:
		return 0
	var arr := m.surface_get_arrays(0)
	return (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
