class_name ClubNpcLife
extends Node
## The club's own people (spec 2): the students of the academy and a visiting star walk
## between stops (the court, the bench, the shop, the coach's room...), stand and train,
## show a mark over their heads now and then, and can be talked to. Light figures from the
## meshes of ClubCrowd (two MultiMeshes), sized by age (JuniorGen.junior_t: the model's
## size is stream H's, this is the stub of it). Each is registered in ClubNpc (the button,
## the collision circles), so is the coach. Nothing here is an Athlete.

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

var club: Node
var world: ClubWorld
var _body: MultiMeshInstance3D
var _legs: MultiMeshInstance3D
var _npcs: Array[Npc] = []
var _active := false
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


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
		if is_instance_valid(_body):
			_body.visible = false
			_legs.visible = false
		for n in _npcs:
			if n.bubble:
				n.bubble.visible = false
		ClubNpc.unregister("coach")
		for n in _npcs:
			ClubNpc.unregister(n.id)


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
			ClubNpc.unregister(_npcs[i].id)
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
	n.skin = Looks.skin(look) if look.has("skin") else Color("e3b48a")
	n.shirt = ClubBuilds.club_color() if kind == "student" else Color("f2f0ea")
	var stops := _stops()
	var at: Vector2 = stops[_rng.randi() % stops.size()]["at"]
	n.pos = Vector3(at.x + _rng.randf_range(-0.5, 0.5), 0.0, at.y + _rng.randf_range(-0.5, 0.5))
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
	var p := func() -> Vector3: return n.pos
	if n.kind == "student":
		ClubNpc.register(id, p, "Тренировать · %s" % String(n.name).get_slice(" ", 0), "club_npc_train:%s" % String(data["id"]),
			{"kind": "student", "name": n.name, "r": 0.5 * n.size + 0.1, "extra": [["Поговорить", "club_npc_talk:%s" % id]]})
	else:
		var cand := Academy.guest_candidate()
		var can_hire := not cand.is_empty() and not Academy.is_full()
		ClubNpc.register(id, p, ("Нанять · %d ●" % int(cand.get("price", 0))) if can_hire else "Поговорить",
			"club_npc_hire:guest" if can_hire else "club_npc_talk:%s" % id,
			{"kind": "guest", "name": n.name, "extra": [["Поговорить", "club_npc_talk:%s" % id]] if can_hire else []})


func _register_coach() -> void:
	var body: Athlete = club.coach.body
	var p := func() -> Vector3: return body.position
	var hire := not Academy.is_full() and not Academy.candidates().is_empty()
	if hire:
		ClubNpc.register("coach", p, "Выбрать ученика", "club_hire", {"kind": "coach", "name": "Тренер", "extra": [["Поговорить", "club_npc_talk:coach"]]})
	else:
		ClubNpc.register("coach", p, "Поговорить", "club_npc_talk:coach", {"kind": "coach", "name": "Тренер"})


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
	world.walk.clear_tag("npc_life")   # routes are drawn without them, they are put back below
	var hero: Vector3 = club.main.player.position
	var i := 0
	for n in _npcs:
		_step(n, delta, hero)
		var lean := 0.0
		var bob := 0.0
		var pos := n.pos
		if n.route.is_empty():
			if n.activity == "train":
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
		var b := Basis.from_euler(Vector3(-lean, n.yaw, 0.0)) * Basis.from_scale(Vector3.ONE * n.size)
		_body.multimesh.set_instance_transform(i, Transform3D(b, pos + Vector3(0, bob, 0)))
		_legs.multimesh.set_instance_transform(i, Transform3D(b, pos + Vector3(0, bob * 0.4, 0)))
		_bubble_tick(n, delta)
		world.walk.add_circle(Vector2(n.pos.x, n.pos.z), 0.5 * n.size + 0.1, "npc_life")
		i += 1
	# The coach is a person too: a circle the hero can't walk through.
	var c: Vector3 = club.coach.body.position
	world.walk.add_circle(Vector2(c.x, c.z), 0.5, "npc_life")


func _step(n: Npc, delta: float, hero: Vector3) -> void:
	var here := Vector2(n.pos.x, n.pos.z)
	if n.route.is_empty():
		n.dwell -= delta
		if n.dwell <= 0.0:
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
	here += mv * SPEED * delta
	n.pos = Vector3(here.x, 0.0, here.y)
	n.yaw = lerp_angle(n.yaw, atan2(-mv.x, -mv.y), 1.0 - exp(-10.0 * delta))


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


## A line over a person's head (the talk button).
func say(id: String, text: String, secs := 3.5) -> void:
	var n := npc(id)
	if n != null:
		_show_bubble(n, text, secs)


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
		return "Моё — %s" % String(Traits.def(shown[_rng.randi() % shown.size()])["name"]).to_lower()
	return STUDENT_LINES[_rng.randi() % STUDENT_LINES.size()]
