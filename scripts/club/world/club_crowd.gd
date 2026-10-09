class_name ClubCrowd
extends Node3D
## The club's people and birds (stream H): a few passers-by who stroll the paths and the
## promenade, and pigeons that peck on the ground and scatter when the hero comes close.
## The people are ClubPeople figures (a whole body in one mesh, legs and arms walking in the
## shader), two kinds - short hair in trousers, long hair in shorts - one MultiMesh each, and
## one for the pigeons: three draw calls, moved from here each frame (a dozen transforms).
## Person i (the fans first, then the walkers) is of kind i % 2, slot i / 2 in its MultiMesh.
## The coach and the court are others'.

const WALK_SPEED := 0.75
const FANS := 8                       # the fence's watchers (the first FANS instances), by the stands' level

## Routes the strollers walk back and forth along (x, z points), with their lane offset.
const MANUAL := [        # the promenade and the street's pavement (not in the path graph)
	[Vector2(-46, -42.3), Vector2(46, -42.3)],
	[Vector2(-46, -40.9), Vector2(46, -40.9)],
	[Vector2(-60, 47.5), Vector2(60, 47.5)],
	[Vector2(60, 48.2), Vector2(-60, 48.2)],
]

class Walker:
	var route := 0
	var s := 0.0              # distance along the route
	var dir := 1.0
	var speed := 1.0
	var phase := 0.0
	var lane := 0.0
	var off := 0.0            # the sideways offset he really stands at (eases to lane * dir when he turns round)
	var length := 0.0
	var cool := 0.0           # after turning away from the hero
	var pos := Vector2(1.0e5, 1.0e5)   # where he stood last frame (the others look at it)
	var heading := Vector2.ZERO
	var waiting := 0.0        # how long he has been held up

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
var _people: Array[MultiMeshInstance3D] = []
var _birds: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()
var _high := true
var _lengths: Array[float] = []
var _routes: Array = []
var _fan_n := 0
var _registered := false
var _shown := 1000                # how many strollers are drawn now (refresh)
var _fan_base: Array[Color] = []
var _fan_t := 0.0


func _ready() -> void:
	_rng.seed = 55
	_routes = MANUAL.duplicate()
	for i in ClubPaths.WALKS.size():   # the others walk the path graph's own chains
		_routes.append(ClubPaths.walk_points(i))
	for r in _routes:
		var l := 0.0
		for i in range(1, (r as Array).size()):
			l += (r[i - 1] as Vector2).distance_to(r[i])
		_lengths.append(l)
	var shirts := [Color("d9473b"), Color("2a54a3"), Color("f2f0ea"), Color("3fb8af"), Color("ffd642"), Color("f08a3c"), Color("9a5cf0"), Color("3d806a")]
	var skins: Array = Looks.SKIN
	var body_col: Array[Color] = []
	for f in FANS:   # the watchers first: their instances never move in the list
		var shirt: Color = shirts[_rng.randi() % shirts.size()]
		_fan_base.append(shirt)
		body_col.append(shirt)
	for i in _routes.size():
		var n := 2 if i < MANUAL.size() else 1
		for k in n:
			var w := Walker.new()
			w.route = i
			w.length = _lengths[i]
			w.s = _rng.randf_range(0.0, w.length)
			w.dir = 1.0 if _rng.randf() < 0.5 else -1.0
			w.speed = _rng.randf_range(0.8, 1.4)
			w.phase = _rng.randf_range(0.0, TAU)
			w.lane = 0.45          # everybody keeps to the same hand: two who meet pass 0.9 m apart
			w.off = w.lane * w.dir
			_walkers.append(w)
			body_col.append(shirts[_rng.randi() % shirts.size()])
	for k in 2:
		var mmi := ClubPeople.instance(k, (body_col.size() + 1 - k) / 2)
		add_child(mmi)
		_people.append(mmi)
	for i in body_col.size():
		var skin: Color = skins[_rng.randi() % skins.size()]
		var hair := _rng.randf_range(0.0, 0.35) if _rng.randf() < 0.75 else _rng.randf_range(0.6, 1.0)
		ClubPeople.paint(_people[i % 2].multimesh, i / 2, body_col[i], skin, hair)
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
	var n := _walkers.size() + FANS
	var vis := n if high else mini(n, FANS + 5)
	_shown = maxi(0, vis - FANS)   # the strollers not drawn (the low preset) are not there: nobody bumps into them
	for k in 2:
		_people[k].multimesh.visible_instance_count = (vis + 1 - k) / 2
	_birds.visible = high
	# the fence's watchers: more of them the higher the stands (ClubBuilds "stands")
	var lv: int = get_parent().level_of("stands")
	_fan_n = [0, 2, 4, 6, 7, 8][clampi(lv, 0, 5)]
	var club := ClubBuilds.club_color()
	for i in FANS:
		ClubPeople.shirt(_people[i % 2].multimesh, i / 2, club if lv >= 3 and i % 4 != 3 else _fan_base[i])


func _process(delta: float) -> void:
	_update(delta)
	if not _registered:
		_register()


func _update(delta: float) -> void:
	# the watchers at the court's west fence, facing it, a small sway and now and then a clap
	_fan_t += delta
	for i in FANS:
		var at := Vector3(-ClubLayout.HX - 1.3 - 0.25 * float(i % 2), 0.0, -9.5 + float(i) * 2.55)
		var sc := 1.0 if i < _fan_n else 0.0
		var cheer := maxf(0.0, sin(_fan_t * 2.2 + float(i) * 1.7)) * 0.05
		var fb := Basis.from_euler(Vector3(0.0, -PI * 0.5 + 0.1 * sin(float(i)), 0.03 * sin(_fan_t * 1.3 + float(i)))) * Basis.from_scale(Vector3.ONE * sc)
		_put(i, Transform3D(fb, at + Vector3(0, cheer, 0)), -1.0)
	var others := _others()
	for i in _walkers.size():
		var w := _walkers[i]
		var slot := FANS + i
		# never through the hero: one that would meet him stops, then turns round
		w.cool = maxf(0.0, w.cool - delta)
		var hp := _hero_pos()
		var here := _point(w.route, w.s)
		var to_hero := Vector2(hp.x - here.x, hp.z - here.y)
		var move := 1.0
		if to_hero.length() < 2.2:
			var ahead := _point(w.route, clampf(w.s + w.dir * 0.5, 0.0, w.length)) - here
			if ahead.length() > 0.01 and ahead.normalized().dot(to_hero.normalized()) > 0.2:
				move = 0.0
				if to_hero.length() < 1.5 and w.cool <= 0.0:
					w.dir = -w.dir
					w.cool = 3.0
		# nor through each other: one with somebody close ahead waits; held up too long, he turns round
		for j in _walkers.size():
			if j != i:
				var od := _walkers[j].pos - w.pos
				if od.length() < 0.85 and od.dot(w.heading) > 0.0:
					move = 0.0
		# ...nor through the club's own people (students, the guest, the coach)
		for op in others:
			var od2: Vector2 = (op as Vector2) - w.pos
			if od2.length() < 1.0 and od2.dot(w.heading) > 0.0:
				move = 0.0
		if move == 0.0:
			w.waiting += delta
			if w.waiting > 3.0 and w.cool <= 0.0:
				w.dir = -w.dir
				w.cool = 3.0
				w.waiting = 0.0
		else:
			w.waiting = 0.0
		var s0 := w.s
		var off0 := w.off
		w.s += w.dir * w.speed * WALK_SPEED * delta * move
		if w.s > w.length:
			w.s = w.length
			w.dir = -1.0
		elif w.s < 0.0:
			w.s = 0.0
			w.dir = 1.0
		var at := _point(w.route, w.s)
		# the way along the route (s growing) and its left side; turning round does not move him
		# sideways in one jump (that walked him through the one he was facing): the offset eases
		var fwd := _point(w.route, clampf(w.s + 0.4, 0.0, w.length)) - at
		if fwd.length() < 0.001:
			fwd = at - _point(w.route, clampf(w.s - 0.4, 0.0, w.length))
		fwd = fwd.normalized() if fwd.length() > 0.001 else Vector2(0, -1)
		var tang := fwd * w.dir
		w.off = move_toward(w.off, w.lane * w.dir, delta * 0.6)
		var q := at + Vector2(-fwd.y, fwd.x) * w.off
		# a last guard, whatever the turns and the sidesteps: no step brings him within 0.7 m of
		# somebody it did not already (the end of a route, a turn beside a queue)
		for j in _walkers.size():
			if j != i and w.pos.x < 1.0e4:
				var op := _walkers[j].pos
				var dn := q.distance_to(op)
				if dn < 0.7 and dn < w.pos.distance_to(op):
					w.s = s0
					w.off = off0
					q = w.pos
					move = 0.0
					w.waiting += delta
					break
		for op in others:
			var dn2 := q.distance_to(op)
			if w.pos.x < 1.0e4 and dn2 < 0.8 and dn2 < w.pos.distance_to(op):
				w.s = s0
				w.off = off0
				q = w.pos
				w.waiting += delta
				break
		w.pos = q
		w.heading = tang
		w.phase += delta * (5.0 + w.speed * 2.0)
		var bob := absf(sin(w.phase)) * 0.045
		var yaw := atan2(-tang.x, -tang.y)
		var sway := sin(w.phase) * 0.025   # the hips sway a little (the legs walk in ClubPeople)
		var gy := ClubLayout.gy(q)
		var b := Basis.from_euler(Vector3(0.0, yaw, sway))
		_put(slot, Transform3D(b, Vector3(q.x, gy + bob * 0.6, q.y)), w.phase if move > 0.0 else -1.0)
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


## Where the club's other people stand now (everybody registered but the strollers and the fans).
func _others() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var main: Node = get_parent().world.get_parent()
	var club = main.get("club") if main != null else null
	if not _registered or club == null or club.get("npc") == null:
		return out
	var reg: ClubNpc = club.npc
	for id in reg.ids():
		if String(id).begins_with("walker_") or String(id).begins_with("fan_"):
			continue
		var p := reg.position_of(id)
		if p != Vector3.INF:
			out.append(Vector2(p.x, p.z))
	return out


## Where stroller `i` stands, and where fan `i` does (Vector3.INF = not there).
func walker_pos(i: int) -> Vector3:
	var w := _walkers[i]
	if i >= _shown:
		return Vector3.INF
	return Vector3(w.pos.x, 0.0, w.pos.y) if w.pos.x < 1.0e4 else Vector3.INF


func fan_pos(i: int) -> Vector3:
	if i >= _fan_n:
		return Vector3.INF
	return Vector3(-ClubLayout.HX - 1.3 - 0.25 * float(i % 2), 0.0, -9.5 + float(i) * 2.55)


func walker_count() -> int:
	return _walkers.size()


## Everybody here is somebody the hero can bump into and greet (ClubNpc).
func _register() -> void:
	var main: Node = get_parent().world.get_parent()
	var club = main.get("club") if main != null else null
	if club == null or club.get("npc") == null:
		return
	_registered = true
	var npc: ClubNpc = club.npc
	for i in _walkers.size():
		npc.register("walker_%d" % i, [self, "walker_pos", i], "", "", [
			"Добрый день!", "Хорошая погода сегодня", "Играете? Удачи!", "Говорят, скоро здесь всё починят"], {"auto": true, "head": 1.95})
	for i in FANS:
		npc.register("fan_%d" % i, [self, "fan_pos", i], "", "", [
			"Давай, чемпион!", "Мы за тебя!", "Отсюда лучший вид на корт", "Ещё один такой удар!"], {"auto": true, "head": 1.95})


func _point(route: int, s: float) -> Vector2:
	var r: Array = _routes[route]
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


## Person i where it stands, walking at this phase (radians) or standing (< 0).
func _put(i: int, xf: Transform3D, phase: float) -> void:
	var mm := _people[i % 2].multimesh
	mm.set_instance_transform(i / 2, xf)
	ClubPeople.step(mm, i / 2, phase)


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


## Torso, shoulders and arms (white: the instance colour is the shirt): a rounded figure
## like the procedural crowds of the other scenery - capsule-ish body, not a box.
static func _body_mesh() -> ArrayMesh:
	var s := ClubShapes.new()
	s.ball(0.23, Vector3(0, 1.2, 0), Color.WHITE, Vector3(1.0, 1.35, 0.68), 8, 5)     # chest
	s.ball(0.2, Vector3(0, 1.0, 0), Color.WHITE, Vector3(1.0, 1.0, 0.7), 8, 4)         # belly
	for x in [-0.26, 0.26]:
		s.ball(0.075, Vector3(x, 1.38, 0), Color.WHITE, Vector3(1, 1, 1), 6, 3)         # shoulder
		s.cyl(0.055, 0.05, 0.5, Vector3(x * 1.08, 1.12, 0.0), Color.WHITE, 6, Vector3(0, 0, -signf(x) * 0.08))
	return s.build()


## Legs (a dark trouser), the neck, the head (skin) and hair, tinted together by one colour.
static func _legs_mesh() -> ArrayMesh:
	var s := ClubShapes.new()
	for x in [-0.1, 0.1]:
		s.cyl(0.085, 0.07, 0.86, Vector3(x, 0.43, 0), Color("2c3a52"), 7)
		s.ball(0.085, Vector3(x, 0.04, -0.05), Color("f2f0ea"), Vector3(1, 0.55, 1.6), 6, 3)   # a shoe
	s.cyl(0.06, 0.07, 0.12, Vector3(0, 1.57, 0), Color("e3b48a"), 6)
	s.ball(0.15, Vector3(0, 1.7, 0), Color("e3b48a"), Vector3(1, 1.1, 1.0), 8, 5)
	s.ball(0.158, Vector3(0, 1.75, 0.025), Color("3b2a1e"), Vector3(1, 0.7, 1.0), 8, 3)
	return s.build()


static func _pigeon_mesh() -> ArrayMesh:
	var s := ClubShapes.new()
	var grey := Color("8a93a0")
	s.ball(0.11, Vector3(0, 0.15, 0), grey, Vector3(0.9, 0.8, 1.4), 5, 3)
	s.ball(0.06, Vector3(0, 0.26, -0.13), Color("6b7f94"), Vector3.ONE, 5, 3)
	s.box(Vector3(0.1, 0.03, 0.14), Vector3(0, 0.14, 0.17), Color("5e6570"), 0.0, Vector3(-0.2, 0, 0))
	return s.build()
