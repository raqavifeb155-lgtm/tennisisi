class_name ClubLotBuild
extends Node
## The build moment of a lot (docs/superpowers/specs/2026-10-09-tycoon.md 1.5): the gold has
## gone and been saved already, the building stands (hidden) - this only shows it: coins fly
## in, scaffolding pops up, two builders hammer, the scaffolding drops with a cloud of dust
## and a gold ring, and the building grows 0 -> 1.08 -> 1 with a little overshoot, a thud, a
## buzz and (with the stands) applause. About 4 s; a tap skips to the end.

signal finished

const TIME := 4.2

var running := false
var club: Node
var world: ClubWorld
var _roots: Array[Node3D] = []
var _scaffold: Node3D
var _workers: ClubNpcWorkers
var _fx: Array[Node] = []
var _tw: Tween
var _at := Vector3.ZERO
var _type := ""


func play(c: Node, lot_id: String, type: String) -> void:
	club = c
	world = c.world
	_type = type
	_at = ClubLots.lot(lot_id)["pos"]
	running = true
	_roots = world.lot_roots(type)
	for r in _roots:
		r.scale = Vector3(1.0, 0.001, 1.0)    # it rises later
		r.visible = false
	var sz := Vector2(7.6, 5.8)
	match type:
		"bar":
			sz = Vector2(13.0, 5.2)
		"trophy":
			sz = Vector2(8.0, 4.2)
		"stands":
			sz = Vector2(5.0, 11.0)
		"academy":
			sz = Vector2(14.0, 10.0)
	_scaffold = world.make_scaffold_at("scaffold_lot", _at + Vector3(0, 0, -0.3), sz, false)
	_scaffold.scale = Vector3(1.0, 0.001, 1.0)
	_scaffold.visible = false
	(_scaffold.get_meta("label") as Label3D).text = "СТРОИТСЯ"
	_workers = ClubNpcWorkers.new()
	_workers.name = "builders"
	world.add_child(_workers)
	_workers.start(_at)
	var dust := _dust(_at + Vector3(0, 0.4, 0.5), 18 if world.high_quality() else 8)
	var burst := _dust(_at + Vector3(0, 0.5, 0), 44 if world.high_quality() else 14)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 3
	ring.mesh = tm
	ring.material_override = ClubMaterial.glow(UiTheme.GOLD, 1.4)
	ring.position = _at + Vector3(0, 0.1, 0)
	ring.scale = Vector3(0.5, 0.05, 0.5)
	world.add_child(ring)
	_fx = [dust, burst, ring]

	var hud = club.hud
	hud.fly_coins(club.cam.unproject_position(_at))
	var v: Array = club.lot_view(lot_id, type, true)
	club.cam.frame(v[0], v[1], 0.5)
	var thud := "club_build" if club.main.sfx.has("club_build") else "bounce"
	_tw = create_tween()
	_tw.tween_interval(0.4)
	_tw.tween_callback(func() -> void:
		_scaffold.visible = true
		_workers.arrive())
	_tw.tween_property(_scaffold, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_interval(0.5)
	for k in 5:
		_tw.tween_callback(func() -> void:
			club.main.sfx.play(thud, -13.0, 1.6 + 0.1 * (k % 2))
			dust.restart()
			dust.emitting = true)
		_tw.tween_interval(0.26)
	# The big moment.
	_tw.tween_callback(func() -> void:
		club.main.sfx.play(thud, -1.0, 0.8)
		TelegramApp.haptic("heavy")
		burst.emitting = true
		for r in _roots:
			r.visible = true
		_workers.leave())
	_tw.tween_property(_scaffold, "scale", Vector3(1.0, 0.001, 1.0), 0.2)
	_tw.parallel().tween_property(ring, "scale", Vector3(4.2, 0.05, 4.2), 0.3)
	for r in _roots:
		_tw.parallel().tween_property(r, "scale", Vector3(1.0, 1.08, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func() -> void: _scaffold.visible = false)
	for r in _roots:
		_tw.parallel().tween_property(r, "scale", Vector3.ONE, 0.15)
	_tw.tween_interval(maxf(0.1, TIME - 3.2))   # the builders run off meanwhile
	_tw.tween_callback(_finish)


## A tap: straight to how it ends.
func skip() -> void:
	if not running:
		return
	if _tw:
		_tw.kill()
	_finish()


func _finish() -> void:
	if not running:
		return
	running = false
	for r in _roots:
		if is_instance_valid(r):
			r.scale = Vector3.ONE
			r.visible = true
	if is_instance_valid(_scaffold):
		_scaffold.queue_free()
	if is_instance_valid(_workers):
		_workers.queue_free()
	for n in _fx:
		if is_instance_valid(n):
			n.queue_free()
	_fx = []
	finished.emit()


func _dust(at: Vector3, amount: int) -> CPUParticles3D:
	var d := CPUParticles3D.new()
	d.amount = amount
	d.one_shot = true
	d.emitting = false
	d.explosiveness = 0.9
	d.lifetime = 0.9
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	d.emission_sphere_radius = 1.6
	d.direction = Vector3.UP
	d.spread = 70.0
	d.initial_velocity_min = 1.2
	d.initial_velocity_max = 3.2
	d.gravity = Vector3(0, -2.0, 0)
	d.scale_amount_min = 0.2
	d.scale_amount_max = 0.55
	var dm := SphereMesh.new()
	dm.radius = 0.25
	dm.height = 0.5
	dm.radial_segments = 6
	dm.rings = 3
	d.mesh = dm
	d.material_override = ClubMaterial.get_mat(ClubMaterial.PALETTE[ClubMaterial.PAVING], false)
	d.position = at
	world.add_child(d)
	return d
