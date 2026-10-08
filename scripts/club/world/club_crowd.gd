class_name ClubCrowd
extends Node3D
## The club's people and birds (stream H): a few passers-by who stroll the paths and the
## promenade, and pigeons that peck on the ground and scatter when the hero comes close.
## Two MultiMeshes for the people (shirts, then legs and heads), one for the pigeons: three
## draw calls, moved from here each frame (a dozen transforms). The coach, the stands'
## fans and the court are others'.

const WALK_SPEED := 1.1

## Routes the strollers walk back and forth along (x, z points), with their lane offset.
const ROUTES := [
	[Vector2(-46, -42.3), Vector2(46, -42.3)],
	[Vector2(-46, -40.9), Vector2(46, -40.9)],
	[Vector2(0.4, 46.0), Vector2(0.4, 31.0), Vector2(-14.0, 31.0)],
	[Vector2(17.0, 31.0), Vector2(14.6, 29.0), Vector2(14.6, -26.0)],
	[Vector2(-12.9, -25.0), Vector2(-12.9, -0.5), Vector2(-20.0, 0.0)],
	[Vector2(-60, 47.5), Vector2(60, 47.5)],
	[Vector2(60, 48.2), Vector2(-60, 48.2)],
	[Vector2(16.0, 6.2), Vector2(23.0, 6.2)],
]

class Walker:
	var route := 0
	var s := 0.0              # distance along the route
	var dir := 1.0
	var speed := 1.0
	var phase := 0.0
	var lane := 0.0
	var length := 0.0

class Pigeon:
	var home := Vector3.ZERO
	var pos := Vector3.ZERO
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var t := -1.0             # 0..1 through a flight, -1 = on the ground
	var yaw := 0.0
	var peck := 0.0

var _walkers: Array[Walker] = []
var _pigeons: Array[Pigeon] = []
var _body: MultiMeshInstance3D
var _legs: MultiMeshInstance3D
var _birds: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()
var _high := true
var _lengths: Array[float] = []


func _ready() -> void:
	_rng.seed = 55
	for r in ROUTES:
		var l := 0.0
		for i in range(1, (r as Array).size()):
			l += (r[i - 1] as Vector2).distance_to(r[i])
		_lengths.append(l)
	var shirts := [Color("d9473b"), Color("2a54a3"), Color("f2f0ea"), Color("3fb8af"), Color("ffd642"), Color("f08a3c"), Color("9a5cf0"), Color("3d806a")]
	var skins: Array = Looks.SKIN
	var body_xf: Array[Transform3D] = []
	var body_col: Array[Color] = []
	var leg_col: Array[Color] = []
	for i in ROUTES.size():
		var n := 2 if i < 2 or i > 4 else 1
		for k in n:
			var w := Walker.new()
			w.route = i
			w.length = _lengths[i]
			w.s = _rng.randf_range(0.0, w.length)
			w.dir = 1.0 if _rng.randf() < 0.5 else -1.0
			w.speed = _rng.randf_range(0.8, 1.4)
			w.phase = _rng.randf_range(0.0, TAU)
			w.lane = _rng.randf_range(-0.25, 0.25)
			_walkers.append(w)
			body_col.append(shirts[_rng.randi() % shirts.size()])
			var skin: Color = skins[_rng.randi() % skins.size()]
			leg_col.append(Color.WHITE.lerp(skin, 0.35))
	_body = _people_mm(_body_mesh(), body_col)
	_legs = _people_mm(_legs_mesh(), leg_col)
	for i in 6:
		var p := Pigeon.new()
		var spot: Vector2 = [Vector2(-4, 36), Vector2(5, 33), Vector2(10, 31), Vector2(-9, 37), Vector2(17, -6), Vector2(-14, -9)][i]
		p.home = Vector3(spot.x, 0.05, spot.y)
		p.pos = p.home
		p.yaw = _rng.randf_range(0.0, TAU)
		_pigeons.append(p)
	_birds = _mm_of(_pigeon_mesh(), _pigeons.size())
	_update(0.0)


func refresh(high: bool) -> void:
	_high = high
	var n := _walkers.size()
	_body.multimesh.visible_instance_count = n if high else mini(n, 6)
	_legs.multimesh.visible_instance_count = n if high else mini(n, 6)
	_birds.visible = high


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	var bm := _body.multimesh
	var lm := _legs.multimesh
	for i in _walkers.size():
		var w := _walkers[i]
		w.s += w.dir * w.speed * WALK_SPEED * delta
		if w.s > w.length:
			w.s = w.length
			w.dir = -1.0
		elif w.s < 0.0:
			w.s = 0.0
			w.dir = 1.0
		var at := _point(w.route, w.s)
		var ahead := _point(w.route, clampf(w.s + w.dir * 0.4, 0.0, w.length))
		var tang := (ahead - at)
		if tang.length() < 0.001:
			tang = Vector2(0, -1)
		tang = tang.normalized()
		var side := Vector2(-tang.y, tang.x) * w.lane
		var q := at + side
		w.phase += delta * (5.0 + w.speed * 2.0)
		var bob := absf(sin(w.phase)) * 0.045
		var yaw := atan2(-tang.x, -tang.y)
		var sway := sin(w.phase) * 0.05
		var gy := ClubLayout.gy(q)
		var b := Basis.from_euler(Vector3(0.0, yaw, sway))
		bm.set_instance_transform(i, Transform3D(b, Vector3(q.x, gy + bob, q.y)))
		lm.set_instance_transform(i, Transform3D(b, Vector3(q.x, gy + bob * 0.4, q.y)))
	# pigeons
	var hero := _hero_pos()
	var pm := _birds.multimesh
	for i in _pigeons.size():
		var p := _pigeons[i]
		if p.t < 0.0:
			p.peck += delta * 3.0
			if Vector2(hero.x - p.pos.x, hero.z - p.pos.z).length() < 3.4 and _high:
				var a := _rng.randf_range(0.0, TAU)
				var d := _rng.randf_range(5.0, 9.0)
				p.from = p.pos
				p.to = Vector3(p.pos.x + cos(a) * d, 0.05, p.pos.z + sin(a) * d)
				p.t = 0.0
				p.yaw = atan2(-(p.to.x - p.from.x), -(p.to.z - p.from.z))
		else:
			p.t += delta / 1.1
			if p.t >= 1.0:
				p.t = -1.0
				p.pos = p.to
			else:
				p.pos = p.from.lerp(p.to, p.t) + Vector3(0, sin(p.t * PI) * 2.2, 0)
		var lift := 0.0 if p.t >= 0.0 else 0.0
		var b := Basis.from_euler(Vector3(sin(p.peck) * 0.35 if p.t < 0.0 else -0.25, p.yaw, 0.0))
		pm.set_instance_transform(i, Transform3D(b, p.pos + Vector3(0, lift, 0)))


func _point(route: int, s: float) -> Vector2:
	var r: Array = ROUTES[route]
	var d := s
	for i in range(1, r.size()):
		var seg: float = (r[i - 1] as Vector2).distance_to(r[i])
		if d <= seg or i == r.size() - 1:
			return (r[i - 1] as Vector2).lerp(r[i], clampf(d / maxf(seg, 0.001), 0.0, 1.0))
		d -= seg
	return r[r.size() - 1]


func _hero_pos() -> Vector3:
	var main: Node = get_parent().world.get_parent()
	var p = main.get("player") if main != null else null
	return (p as Node3D).position if p is Node3D else Vector3(1000, 0, 1000)


func _people_mm(mesh: Mesh, cols: Array[Color]) -> MultiMeshInstance3D:
	var mmi := _mm_of(mesh, cols.size())
	for i in cols.size():
		mmi.multimesh.set_instance_color(i, cols[i])
	return mmi


func _mm_of(mesh: Mesh, n: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ClubScenery.prop_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	for i in n:
		mm.set_instance_color(i, Color.WHITE)
	return mmi


## Torso and arms (white: the instance colour is the shirt) and a hairy head.
static func _body_mesh() -> ArrayMesh:
	var s := ClubShapes.new()
	s.box(Vector3(0.42, 0.55, 0.26), Vector3(0, 1.22, 0), Color.WHITE)
	for x in [-0.27, 0.27]:
		s.box(Vector3(0.11, 0.52, 0.13), Vector3(x, 1.2, 0), Color.WHITE)
	return s.build()


## Legs (a dark trouser) and the head (skin), tinted together by one colour.
static func _legs_mesh() -> ArrayMesh:
	var s := ClubShapes.new()
	for x in [-0.1, 0.1]:
		s.box(Vector3(0.16, 0.85, 0.18), Vector3(x, 0.43, 0), Color("2c3a52"))
	s.ball(0.15, Vector3(0, 1.66, 0), Color("e3b48a"), Vector3(1, 1.1, 1), 6, 4)
	s.ball(0.155, Vector3(0, 1.73, 0.02), Color("3b2a1e"), Vector3(1, 0.75, 1), 6, 3)
	return s.build()


static func _pigeon_mesh() -> ArrayMesh:
	var s := ClubShapes.new()
	var grey := Color("8a93a0")
	s.ball(0.11, Vector3(0, 0.15, 0), grey, Vector3(0.9, 0.8, 1.4), 5, 3)
	s.ball(0.06, Vector3(0, 0.26, -0.13), Color("6b7f94"), Vector3.ONE, 5, 3)
	s.box(Vector3(0.1, 0.03, 0.14), Vector3(0, 0.14, 0.17), Color("5e6570"), 0.0, Vector3(-0.2, 0, 0))
	return s.build()
