class_name ClubNpcLife
extends Node
## The club's own people (spec 2): the students of the academy and a visiting star walk
## between stops (the court, the bench, the shop, the coach's room...), stand and train,
## show a mark over their heads now and then, and can be talked to. Light figures from the
## meshes of ClubCrowd (two MultiMeshes), sized by age (JuniorGen.junior_t: the model's
## size is stream H's, this is the stub of it). Each is registered in the club's ClubNpc
## (stream H-8: the button, the bubble, a body the hero can't walk through); the coach is
## registered by Club, here he only gets the «Выбрать ученика» button. Nothing here is an Athlete.

const MAX := 5
const SPEED := 1.6
const MARKS := ["!", "…", "?", "+"]
const STUDENT_LINES := ["Готов тренироваться!", "Тренер сказал бить глубже", "Сегодня подача идёт", "Хочу сыграть матч", "Дай мне ещё корзину мячей", "Ноги гудят, но я справлюсь"]
const HINT_LINE := "Кажется, у меня что-то получается..."
const GUEST_LINES := ["Хороший корт. Давно так не играл", "Покажи, чему учишь молодёжь", "Загляну ещё"]

class Npc:
	var id := ""
	var kind := "student"
	var name := ""
	var st: Dictionary = {}
	var pos := Vector3.ZERO
	var yaw := 0.0
	var route: Array = []
	var dwell := 1.0
	var activity := "idle"
	var size := 1.0
	var shirt := Color.WHITE
	var skin := Color.WHITE
	var mark_t := 0.0
	var next_mark := 20.0
	var bubble: Label3D
	var bubble_t := 0.0
	var phase := 0.0
	var stuck := 0.0
	var look: Dictionary = {}
	var body: Athlete              # a real body while the hero is near (spec 2.1), else null
	var face := Vector3.INF        # someone to look at (the coach putting a word in)
	var face_t := 0.0
	var swing_t := 0.0

var club: Node
var world: ClubWorld
var _body: MultiMeshInstance3D
var _legs: MultiMeshInstance3D
var _npcs: Array[Npc] = []
var _active := false
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _athletes: Array[Athlete] = []   # the pool of real bodies (BODIES at most), reused

const BODIES := 2              # real Athletes near the hero, never more (spec 2.1, the budget)
const NEAR_IN := 11.0          # a light figure this close becomes a body...
const NEAR_OUT := 15.0         # ...and a body this far goes back to a figure


func setup(c: Node) -> void:
	club = c
	_rng.randomize()


func set_active(on: bool) -> void:
	_active = on
	if on:
		refresh()
		if is_instance_valid(_body):
			_body.visible = true
			_legs.visible = true
	else:
		for n in _npcs:
			_release(n)
		for a in _athletes:
			if is_instance_valid(a):
				a.visible = false
		if is_instance_valid(_body):
			_body.visible = false
			_legs.visible = false
		for n in _npcs:
			if n.bubble:
				n.bubble.visible = false
			_registry().unregister(n.id)
		_registry().set_button("coach", "Поговорить", "")


func _registry() -> ClubNpc:
	return club.npc


## Where a person of ours is now (ClubNpc reads it every frame): nowhere while the club is shut.
func pos_of(id: String) -> Vector3:
	var n := npc(id)
	return n.pos if n != null and _active else Vector3.INF


func people() -> Array[Npc]:
	return _npcs


func npc(id: String) -> Npc:
	for n in _npcs:
		if n.id == id:
			return n
	return null


## The club's people as they should be now: the students, the visitor, the coach's button.
## Safe to call again (a hire, a new run, a new world).
func refresh() -> void:
	if club == null or not is_instance_valid(club.world):
		return
	world = club.world
	_ensure_meshes()
	var want: Array = []   # [id, kind, data]
	for s in Academy.students():
		want.append(["stu_" + String(s["id"]), "student", s])
	var g := Academy.guest()
	if not g.is_empty():
		want.append(["guest", "guest", g])
	# Those gone leave; those new arrive.
	for i in range(_npcs.size() - 1, -1, -1):
		var keep := false
		for w in want:
			keep = keep or w[0] == _npcs[i].id
		if not keep:
			_release(_npcs[i])
			_registry().unregister(_npcs[i].id)
			if _npcs[i].bubble:
				_npcs[i].bubble.queue_free()
			_npcs.remove_at(i)
	for w in want:
		if _npcs.size() >= MAX:
			break
		var n := npc(String(w[0]))
		if n == null:
			n = _spawn(String(w[0]), String(w[1]), w[2])
			_npcs.append(n)
		_register(n, w[2])
	_register_coach()
	_paint()


func _ensure_meshes() -> void:
	if is_instance_valid(_body) and _body.get_parent() == world:
		return
	_body = _mm(ClubCrowd._body_mesh())
	_legs = _mm(ClubCrowd._legs_mesh())


func _mm(mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "npc_life"
	mmi.multimesh = mm
	mmi.material_override = ClubScenery.prop_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-70, -1, -50), Vector3(140, 4, 100))
	world.add_child(mmi)
	for i in MAX:
		mm.set_instance_color(i, Color.WHITE)
	return mmi


func _spawn(id: String, kind: String, data: Dictionary) -> Npc:
	var n := Npc.new()
	n.id = id
	n.kind = kind
	n.st = data
	n.name = String(data.get("name", "?"))
	n.size = 1.0 if kind == "guest" else JuniorGen.junior_t(float(Academy.age(data)))
	var look: Dictionary = data.get("look", {})
	if look.is_empty() and kind == "guest":   # the star looks like himself, not like the hero's default
		look = (Opponents.find(String(data.get("roster", ""))) as Dictionary).get("look", {})
	n.look = look
	n.skin = Looks.skin(look) if look.has("skin") else Color("e3b48a")
	n.shirt = ClubBuilds.club_color() if kind == "student" else Color("f2f0ea")
	var stops := _stops()
	var at := Vector2.ZERO
	for tries in 12:   # a place nobody stands on (two arriving at one stop would be one inside the other)
		var s: Vector2 = stops[_rng.randi() % stops.size()]["at"]
		at = s + Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)) * (1.0 + float(tries) * 0.3)
		var free := true
		for o in _npcs:
			free = free and Vector2(o.pos.x, o.pos.z).distance_to(at) > 1.0
		for a in _registry().agent_list(id):
			free = free and (a[0] as Vector2).distance_to(at) > float(a[1]) + 0.5
		if free:
			break
	n.pos = Vector3(at.x, 0.0, at.y)
	n.dwell = _rng.randf_range(2.0, 6.0)
	n.next_mark = _rng.randf_range(10.0, 30.0)
	return n


func _paint() -> void:
	var n_all := _npcs.size()
	_body.multimesh.visible_instance_count = n_all
	_legs.multimesh.visible_instance_count = n_all
	for i in n_all:
		_body.multimesh.set_instance_color(i, _npcs[i].shirt)
		_legs.multimesh.set_instance_color(i, Color.WHITE.lerp(_npcs[i].skin, 0.35))


func _register(n: Npc, data: Dictionary) -> void:
	var id := n.id
	var opts := {"kind": n.kind, "name": n.name, "radius": 0.36 * n.size + 0.04, "head": 2.0 * n.size + 0.1,
		"line": Callable(self, "line_for").bind(id)}
	if n.kind == "student":
		opts["extra"] = [["Поговорить", "club_say_" + id]]
		_registry().register(id, [self, "pos_of", id], "Тренировать · %s" % String(n.name).get_slice(" ", 0),
			"club_train:%s" % String(data["id"]), [], opts)
	else:
		var cand := Academy.guest_candidate()
		var can_hire := not cand.is_empty() and not Academy.is_full()
		opts["extra"] = [["Поговорить", "club_say_" + id]] if can_hire else []
		_registry().register(id, [self, "pos_of", id], ("Нанять · %d ●" % int(cand.get("price", 0))) if can_hire else "Поговорить",
			"club_guest_hire" if can_hire else "", [], opts)


## The coach (Club registers him) gets «Выбрать ученика» while there are newcomers and room.
func _register_coach() -> void:
	var reg := _registry()
	if not reg.has("coach"):
		return
	if hiring():
		reg.set_button("coach", "Выбрать ученика", "club_hire", [["Поговорить", "club_say_coach"]])
	elif not Academy.students().is_empty():
		reg.set_button("coach", "Ученики", "club_students", [["Поговорить", "club_say_coach"]])   # the office (T-3)
	else:
		reg.set_button("coach", "Поговорить", "")
	reg.entry("coach")["line"] = Callable(self, "_coach_line")


func hiring() -> bool:
	return not Academy.is_full() and not Academy.candidates().is_empty()


func _coach_line() -> String:
	if hiring():
		return "Привёл новичков — выбирай, пока свободны"
	return "Твои ученики растут с каждым забегом" if not Academy.students().is_empty() and _rng.randf() < 0.4 else ""


# --- Life ------------------------------------------------------------------------------------------

func _stops() -> Array:
	var raw: Array = [
		{"at": Vector2(-4.5, 10.5), "kind": "train"},
		{"at": Vector2(3.8, 5.0), "kind": "train"},
		{"at": Vector2(-12.4, 3.0), "kind": "idle"},
		{"at": Vector2(11.5, 21.0), "kind": "idle"},
	]
	var shop: Vector3 = ClubPlaces.find("shop")["pos"]
	raw.append({"at": Vector2(shop.x, shop.z + 4.4), "kind": "idle"})
	if Academy.is_built():
		var ac: Vector3 = ClubPlaces.find("academy")["pos"]
		var on_court := ClubLots.xf("academy") * (ClubLevels.ACADEMY + Vector3(4.9, 0, 2.6))
		raw.append({"at": Vector2(on_court.x, on_court.z), "kind": "train"})
		raw.append({"at": Vector2(ac.x - 0.8, ac.z + 2.6), "kind": "idle"})
	for t in ["coach", "bar", "trophy"]:
		if ClubLots.is_placed(t):
			var c: Vector3 = ClubPlaces.find(t)["pos"]
			raw.append({"at": Vector2(c.x, c.z + (4.4 if t == "coach" else 2.6)), "kind": "idle"})
	var out: Array = []
	for r in raw:
		if is_instance_valid(world) and world.walk.blocked(r["at"], 0.4):
			continue
		out.append(r)
	if out.is_empty():
		out.append({"at": Vector2(-4.5, 10.5), "kind": "idle"})
	return out


func _process(delta: float) -> void:
	if not _active or club == null or not club.active or not is_instance_valid(world) or not is_instance_valid(_body):
		return
	_clock += delta
	var hero: Vector3 = club.main.player.position
	_assign_bodies(hero)
	var i := 0
	for n in _npcs:
		_step(n, delta, hero)
		var lean := 0.0
		var bob := 0.0
		n.face_t -= delta
		if n.route.is_empty():
			if n.face_t > 0.0 and n.face != Vector3.INF:
				var f := Vector2(n.face.x - n.pos.x, n.face.z - n.pos.z)
				n.yaw = lerp_angle(n.yaw, atan2(-f.x, -f.y), 1.0 - exp(-6.0 * delta))
			elif n.activity == "train":
				var beat := maxf(0.0, sin(_clock * 4.2 + n.phase))
				lean = 0.35 * beat
				n.yaw = lerp_angle(n.yaw, 0.0 if n.pos.z > 0.0 else PI, 1.0 - exp(-6.0 * delta))
			else:
				var d := Vector2(hero.x - n.pos.x, hero.z - n.pos.z)
				if d.length() < 5.0 and d.length() > 0.2:
					n.yaw = lerp_angle(n.yaw, atan2(-d.x, -d.y), 1.0 - exp(-5.0 * delta))
		else:
			n.phase += delta * 9.0
			bob = absf(sin(n.phase)) * 0.04
			lean = sin(n.phase) * 0.04
		# The ground under him (rooms' floors, ramps: ClubWalk.floor_at), eased like the hero's.
		n.pos.y = move_toward(n.pos.y, world.walk.floor_at(Vector2(n.pos.x, n.pos.z)), 1.6 * delta)
		var b := Basis.from_euler(Vector3(-lean, n.yaw, 0.0)) * Basis.from_scale(Vector3.ONE * n.size)
		var at := n.pos
		if n.body != null:
			_drive_body(n, delta)
			b = Basis.from_scale(Vector3.ONE * 0.001)   # the figure steps aside for the body
			at = Vector3(0.0, -5.0, 0.0)
		_body.multimesh.set_instance_transform(i, Transform3D(b, at + Vector3(0, bob, 0)))
		_legs.multimesh.set_instance_transform(i, Transform3D(b, at + Vector3(0, bob * 0.4, 0)))
		_bubble_tick(n, delta)
		i += 1


func _step(n: Npc, delta: float, hero: Vector3) -> void:
	var here := Vector2(n.pos.x, n.pos.z)
	if n.route.is_empty():
		n.dwell -= delta
		if n.dwell <= 0.0 and n.face_t <= 0.0:
			_next_stop(n)
		return
	var target: Vector2 = n.route[0]
	var mv := world.walk.steer(here, target)
	if mv == Vector2.ZERO:
		n.route.pop_front()
		if n.route.is_empty():
			n.dwell = _rng.randf_range(14.0, 24.0) if n.activity == "train" else _rng.randf_range(6.0, 12.0)
		return
	# The hero in the way: wait for him (and look).
	var to_hero := Vector2(hero.x - here.x, hero.z - here.y)
	if to_hero.length() < 1.5 and mv.normalized().dot(to_hero.normalized()) > 0.3:
		n.yaw = lerp_angle(n.yaw, atan2(-to_hero.x, -to_hero.y), 1.0 - exp(-8.0 * delta))
		return
	# Other people are bodies too (ClubNpc): he slides round them, never through.
	var r := 0.36 * n.size + 0.04
	var to := world.walk.resolve(here, here + mv * SPEED * delta, r, _registry().agent_list(n.id))
	if to.distance_to(here) < 0.2 * SPEED * delta:
		n.stuck += delta
		if n.stuck > 2.5:   # wedged (two people on one path): give up this stop
			n.stuck = 0.0
			n.route = []
			n.dwell = _rng.randf_range(1.0, 3.0)
		return
	n.stuck = 0.0
	n.pos = Vector3(to.x, n.pos.y, to.y)
	n.yaw = lerp_angle(n.yaw, atan2(-mv.x, -mv.y), 1.0 - exp(-10.0 * delta))


## Stand still for a while looking at `who` (the coach has a word for him).
func hold(id: String, secs: float, who := Vector3.INF) -> void:
	var n := npc(id)
	if n == null:
		return
	n.route = []
	n.dwell = maxf(n.dwell, secs)
	n.face_t = secs
	n.face = who if who != Vector3.INF else club.coach.body.position


# --- Real bodies near the hero (spec 2.1) ------------------------------------------------------

## The (at most BODIES) people nearest to the hero get a real Athlete - a child's size by
## age, his own look, no racket while he walks, the racket up when he trains - the rest stay
## light figures. A margin between NEAR_IN and NEAR_OUT keeps them from flickering.
func _assign_bodies(hero: Vector3) -> void:
	for n in _npcs:
		if n.body != null and Vector2(n.pos.x - hero.x, n.pos.z - hero.z).length() > NEAR_OUT:
			_release(n)
	var free := BODIES
	for n in _npcs:
		if n.body != null:
			free -= 1
	if free <= 0:
		return
	var want: Array = _npcs.filter(func(n): return n.body == null and Vector2(n.pos.x - hero.x, n.pos.z - hero.z).length() < NEAR_IN)
	want.sort_custom(func(a, b): return Vector2(a.pos.x - hero.x, a.pos.z - hero.z).length() < Vector2(b.pos.x - hero.x, b.pos.z - hero.z).length())
	for n in want.slice(0, free):
		_take_body(n)


func _take_body(n: Npc) -> void:
	var look: Dictionary = n.look.duplicate() if not n.look.is_empty() else Looks.DEFAULT.duplicate()
	if n.kind == "student":
		look["shirt"] = Looks.nearest_kit(ClubBuilds.club_color())   # the club's colours
		look["beard"] = 0 if Academy.age(n.st) < 18 else int(look.get("beard", 0))
	var a: Athlete = null
	for x in _athletes:
		if is_instance_valid(x) and not x.has_meta("npc_owner"):
			a = x
			break
	if a == null:
		if _athletes.size() >= BODIES:
			return
		a = Athlete.new()
		a.name = "npc_body_%d" % _athletes.size()
		world.add_child(a)
		a.setup(-1.0, look, world.walk.bounds)
		_athletes.append(a)
	elif a.get_meta("npc_look", "") != str(look):
		a.set_look(look)
	a.set_meta("npc_look", str(look))
	a.set_meta("npc_owner", n.id)
	a.set_meta("casual", true)
	if n.size < 0.999:
		AthleteCasual.set_junior(a, n.size)
	elif a.has_meta("junior"):
		a.remove_meta("junior")
		a.remove_meta("body_stamp")
	a.area = world.walk.bounds
	a.position = Vector3(n.pos.x, 0.0, n.pos.z)
	a.rotation.y = n.yaw
	a.velocity = Vector3.ZERO
	a.move_input = Vector2.ZERO
	a.max_speed = SPEED
	a.relax()
	a.visible = true
	n.body = a


func _release(n: Npc) -> void:
	if n.body == null:
		return
	if is_instance_valid(n.body):
		n.body.remove_meta("npc_owner")
		n.body.move_input = Vector2.ZERO
		n.body.visible = false
	n.body = null


## The body follows the person's own walk (the figure's logic stays the one truth): steered to
## where he is, the gait from its own speed; the racket comes out on the court.
func _drive_body(n: Npc, delta: float) -> void:
	var a := n.body
	var d := Vector2(n.pos.x - a.position.x, n.pos.z - a.position.z)
	if d.length() > 2.5:
		a.position = Vector3(n.pos.x, 0.0, n.pos.z)   # a jump (a test, a new stop): no running after it
		d = Vector2.ZERO
	a.max_speed = SPEED * 1.25
	a.move_input = (d / 0.09).limit_length(1.0) if d.length() > 0.03 else Vector2.ZERO
	a.rotation.y = lerp_angle(a.rotation.y, n.yaw, 1.0 - exp(-10.0 * delta))
	a.position.y = n.pos.y
	var training := n.route.is_empty() and n.activity == "train" and n.face_t <= 0.0
	a.set_meta("casual", not training)
	if training:
		n.swing_t -= delta
		if n.swing_t <= 0.0 and not a.is_swinging():
			n.swing_t = _rng.randf_range(2.2, 3.4)
			var side := 1 if _rng.randf() < 0.6 else -1
			var contact := a.to_global(Vector3(0.75 * float(side), 0.95 * n.size, -0.5))   # local: +x his forehand, -z ahead
			a.swing(side, 0.45, contact)


func _next_stop(n: Npc) -> void:
	var stops := _stops()
	var s: Dictionary = stops[_rng.randi() % stops.size()]
	var here := Vector2(n.pos.x, n.pos.z)
	var route: Array = world.walk.route(here, s["at"])
	n.activity = String(s["kind"])
	if route.is_empty():
		n.dwell = 3.0
		return
	n.route = route


func _bubble_tick(n: Npc, delta: float) -> void:
	n.next_mark -= delta
	if n.next_mark <= 0.0 and n.bubble_t <= 0.0:
		n.next_mark = _rng.randf_range(30.0, 60.0)
		_show_bubble(n, MARKS[_rng.randi() % MARKS.size()], 2.2, true)
	if n.bubble != null:
		if n.bubble_t > 0.0:
			n.bubble_t -= delta
			n.bubble.visible = _active
			n.bubble.position = n.pos + Vector3(0, 1.95 * n.size + 0.4, 0)
		else:
			n.bubble.visible = false


func _show_bubble(n: Npc, text: String, secs: float, mark := false) -> void:
	if n.bubble == null or not is_instance_valid(n.bubble):
		var l := Label3D.new()
		l.font = UiTheme.text_bold()
		l.shaded = false
		l.double_sided = true
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_modulate = Color(1, 1, 1, 0.95)
		l.modulate = Color(0.16, 0.13, 0.1)
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(l)
		n.bubble = l
	n.bubble.text = text
	n.bubble.font_size = 96 if mark else 44
	n.bubble.pixel_size = 0.008 if mark else 0.0065
	n.bubble.outline_size = 22 if mark else 16
	n.bubble.width = 360.0
	n.bubble.autowrap_mode = TextServer.AUTOWRAP_OFF if mark else TextServer.AUTOWRAP_WORD_SMART
	n.bubble_t = secs


## A line over a person's head: the club's bubble (ClubNpc.say), like everybody's.
func say(id: String, text: String, secs := 3.5) -> void:
	if npc(id) != null:
		_registry().say(id, text, secs)


## What a person says when you talk to him.
func line_for(id: String) -> String:
	var n := npc(id)
	if n == null:
		return ""
	if n.kind == "guest":
		return GUEST_LINES[_rng.randi() % GUEST_LINES.size()]
	if Traits.hidden_count(n.st) > 0 and _rng.randf() < 0.3:
		return HINT_LINE
	var shown: Array = Traits.shown(n.st)
	if not shown.is_empty() and _rng.randf() < 0.4:
		return "Моё — %s" % Traits.name(shown[_rng.randi() % shown.size()]).to_lower()
	return STUDENT_LINES[_rng.randi() % STUDENT_LINES.size()]
