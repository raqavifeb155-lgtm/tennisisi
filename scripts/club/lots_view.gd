class_name ClubLotsView
extends RefCounted
## What an empty lot looks like (docs/superpowers/specs/2026-10-09-tycoon.md 1.3): four
## stakes with a red-and-white tape around a patch of gravel, and a signboard that says
## «Участок · построить / от 96 ●» (a shut lot: grey tape and what opens it). One merged mesh
## and one board a lot. A lot with a building on it shows nothing: the building does.

var world: ClubWorld
var _marks := {}        # lot id -> {"node": Node3D, "open": bool}


func _init(w: ClubWorld) -> void:
	world = w


## Draws the markers of the empty lots (again when a lot opens or gets built on).
func sync() -> void:
	for l in ClubLots.LOTS:
		var id: String = l["id"]
		var empty := ClubLots.type_at(id) == ""
		var open := ClubLots.lot_open(id)
		var m: Dictionary = _marks.get(id, {})
		if not m.is_empty() and (m["open"] != open or not empty):
			(m["node"] as Node3D).queue_free()
			m = {}
			_marks.erase(id)
		if not empty:
			_hide_sign(id)
			continue
		if m.is_empty():
			var n := _marker(l, open)
			_marks[id] = {"node": n, "open": open}
		_ensure_sign(l)


func marker(lot_id: String) -> Node3D:
	var m: Dictionary = _marks.get(lot_id, {})
	return m.get("node") if not m.is_empty() else null


func _hide_sign(id: String) -> void:
	var s := world.place_node("lot_%s_sign" % id)
	if s:
		s.visible = false


## The signboard (a post and a board, ClubWorld._sign) stands apart from the lot's circle.
func _ensure_sign(l: Dictionary) -> void:
	var id: String = l["id"]
	if world.place_node("lot_%s_sign" % id) != null:
		return
	var c: Vector3 = l["pos"]
	var s := world._sign(c + Vector3(3.4, 0, 2.9), ClubLots.sign_text(id))
	world._place_nodes["lot_%s_sign" % id] = s
	world._keep.append(s)
	var holder := Node3D.new()   # the lot's place node: where a place's node is expected
	holder.name = "place_lot_" + id
	holder.position = c
	world.add_child(holder)
	world._place_nodes["lot_" + id] = holder


func _marker(l: Dictionary, open: bool) -> Node3D:
	var c: Vector3 = l["pos"]
	var n := Node3D.new()
	n.name = "lot_" + String(l["id"])
	n.position = c
	world.add_child(n)
	world._keep.append(n)
	# One mesh with its colours in the vertices (the club's prop material): a lot is one draw call.
	var wood: Color = ClubMaterial.PALETTE[ClubMaterial.WOOD]
	var tape_a: Color = ClubMaterial.PALETTE[ClubMaterial.RED if open else ClubMaterial.METAL]
	var tape_b: Color = ClubMaterial.PALETTE[ClubMaterial.WHITE if open else ClubMaterial.STEEL]
	var gravel: Color = ClubMaterial.PALETTE[ClubMaterial.GRAVEL]
	var hx := 4.5
	var hz := 3.5
	var s := ClubShapes.new()
	s.box(Vector3(hx * 2.0, 0.03, hz * 2.0), Vector3(0, 0.03, 0), gravel)
	for sx in [-hx, hx]:
		for sz in [-hz, hz]:
			s.box(Vector3(0.09, 1.0, 0.09), Vector3(sx, 0.5, sz), wood)
	# The tape along the four sides, in short red and white pieces.
	var k := 0
	for side in 4:
		var horizontal := side % 2 == 0
		var length := hx * 2.0 if horizontal else hz * 2.0
		var pieces := int(length / 0.5)
		for i in pieces:
			var t := (float(i) + 0.5) / float(pieces) - 0.5
			var p := Vector3(t * length, 0.85, (-hz if side == 0 else hz)) if horizontal else Vector3((-hx if side == 1 else hx), 0.85, t * length)
			var size := Vector3(0.5, 0.05, 0.04) if horizontal else Vector3(0.04, 0.05, 0.5)
			s.box(size, p, tape_a if k % 2 == 0 else tape_b)
			k += 1
	var mi := MeshInstance3D.new()
	mi.name = "marks"
	mi.mesh = s.build()
	mi.material_override = ClubScenery.prop_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n
