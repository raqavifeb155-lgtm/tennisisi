class_name ClubCoach
extends RefCounted
## The coach (docs/club/CLUB_BRIEF.md 6): Main's second Athlete (the opponent in a match)
## dressed in a cap and a polo. He waits by the court, now and then goes on a round (T-2): to
## a student to put a word in (the student answers), to his room if it is built, to the shop,
## to a lot being built - along the club's paths - and back; he talks in a bubble with an
## Animal Crossing murmur: short syllables, no voice. While he has newcomers to choose from he
## stays by the court, where the hero finds him.

const LOOK := {"skin": 5, "hair": 1, "hair_color": 10, "beard": 2, "head": 1, "shirt": 0, "shorts": 3, "accent": 3}
const HOME := Vector3(-2.3, 0.0, 12.3)
const SPEED := 2.3
const SAY_GAP := 20.0          # never more often than this (s)
const SYLLABLES := 6

const LINES := {
	"first": "Это твой корт. Пока так себе — но это наш",
	"court": "Готов? Турнир ждёт",
	"court_run": "Доиграем турнир?",
	"coach": "Есть очки навыков — распредели",
	"locker": "Новая форма — новая игра",
	"reward": "Есть награда за задания — заходи в тренерскую",
	"lot": "Пустой участок. Построй здесь что-нибудь",
	"hire": "Привёл тебе новичков. Подойди — выберешь ученика",
	"drill_first": "Покажу удары. Пойдём к пушке",
	"drilled": "Теперь в турнир. Жми «Новая игра»",
}

var body: Athlete
var club: Node
var _path: Array = []          # waypoints still to walk
var _wait := 8.0               # seconds until the next walk
var _last_say := -100.0
var _clock := 0.0
var _murmur: Array = []        # syllable start times left in the current line
var _stops: Array = []         # the round: [{at: Vector3, stay: s, who: student id or ""}]
var _stay := 0.0               # standing at a stop
var _reply: Array = []
var _blocked := 0.0            # how long the hero has stood in his way         # [time, npc id, line]: a student answers the coach

const TIPS := ["Колени ниже, %s!", "Раньше разворот, %s", "Смотри на мяч до конца, %s", "Хорошо! Ещё корзину, %s", "Ноги, %s, ноги!", "Дыши на подаче, %s"]
const REPLIES := ["Понял, тренер!", "Сейчас попробую", "Ага!", "Ещё разок!", "Есть!"]


func setup(c: Node, b: Athlete) -> void:
	club = c
	body = b
	var sfx = c.main.sfx
	for i in SYLLABLES:
		var path := "res://assets/club/murmur_%d.wav" % i
		if ResourceLoader.exists(path):
			sfx._streams["club_murmur_%d" % i] = load(path)


## Into the club: dressed, at his spot by the court.
func enter() -> void:
	AthleteCasual.make_elder(body)
	body.set_meta("club_coach", true)
	body.area = club.world.walk.bounds
	body.position = HOME
	body.velocity = Vector3.ZERO
	body.relax()
	_path = []
	_stops = []
	_stay = 0.0
	_reply = []
	_wait = randf_range(25.0, 45.0)


func tick(delta: float, hero: Vector3) -> void:
	_clock += delta
	_wait -= delta
	if _path.is_empty() and _stops.is_empty() and _wait <= 0.0:
		_wait = randf_range(30.0, 60.0)
		if not _hiring():
			_stops = plan_round()
	if _path.is_empty() and not _stops.is_empty():
		_stay -= delta
		if _stay <= 0.0:
			_next_stop()
	_tick_reply()
	var mv := Vector2.ZERO
	if not _path.is_empty():
		var t: Vector3 = _path[0]
		mv = club.world.walk.steer(Vector2(body.position.x, body.position.z), Vector2(t.x, t.z))
		if mv == Vector2.ZERO:
			_path.pop_front()
			if _path.is_empty() and not _stops.is_empty():
				_arrive(_stops[0])
	# he stops for the hero in his way, and waits
	var hv := Vector2(hero.x - body.position.x, hero.z - body.position.z)
	if mv != Vector2.ZERO and hv.length() < 1.7 and hv.normalized().dot(mv.normalized()) > 0.3:
		_blocked += delta
		# a moment's wait, then round him (the hero may just stand there)
		mv = Vector2.ZERO if _blocked < 1.2 else mv.rotated(-1.1 if hv.cross(mv) > 0.0 else 1.1)
	else:
		_blocked = 0.0
	body.max_speed = SPEED
	body.move_input = mv
	var look := Vector2(body.velocity.x, body.velocity.z)
	if look.length() < 0.3:
		look = Vector2(hero.x - body.position.x, hero.z - body.position.z)  # waiting: watches the hero
	if look.length() > 0.05:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-look.x, -look.y), 1.0 - exp(-8.0 * delta))
	_update_murmur()


# --- His round (T-2) ------------------------------------------------------------------------

func _hiring() -> bool:
	var life = club.get("npc_life")
	return life != null and life.hiring()


## Where he goes this time: a student or two (a word each), his room if it is built, the shop or
## a lot under construction, then back home. Stops are where the walk can stand.
func plan_round() -> Array:
	var out: Array = []
	var life = club.get("npc_life")
	if life != null:
		var people: Array = life.people().filter(func(n): return n.kind == "student")
		people.shuffle()
		for n in people.slice(0, 2):
			out.append({"at": Vector3.INF, "stay": randf_range(5.0, 8.0), "who": n.id})
	var spots: Array = []
	if ClubLots.is_placed("coach"):
		spots.append(_front_of("coach"))
	spots.append(_front_of("shop"))
	spots.shuffle()
	out.append({"at": spots[0], "stay": randf_range(4.0, 7.0), "who": ""})
	out.shuffle()
	out.append({"at": HOME, "stay": 0.0, "who": ""})
	return out.filter(func(s): return s["who"] != "" or s["at"] != Vector3.INF)


func _front_of(id: String) -> Vector3:
	var p := ClubPlaces.find(id)
	if p.is_empty():
		return HOME
	var c: Vector3 = p["pos"]
	var at := Vector3(c.x, 0.0, c.z + 1.6)   # by the circle, not on it: the hero's button stays the place's
	return at if not club.world.walk.blocked(Vector2(at.x, at.z), 0.4) else HOME


func _next_stop() -> void:
	if not _stops.is_empty() and bool(_stops[0].get("done", false)):
		_stops.pop_front()   # stood there long enough
	if _stops.is_empty():
		return
	var s: Dictionary = _stops[0]
	var to: Vector3 = s["at"]
	if s["who"] != "":
		var life = club.get("npc_life")
		var n = life.npc(s["who"]) if life != null else null
		if n == null:
			_stops.pop_front()
			return
		var side := Vector3(1.3, 0.0, 0.4) if (n.pos.x < 0.0) else Vector3(-1.3, 0.0, 0.4)
		to = n.pos + side
	var here := Vector2(body.position.x, body.position.z)
	var route: Array = club._path_route(here, Vector2(to.x, to.z)) if club.has_method("_path_route") else [Vector2(to.x, to.z)]
	s["done"] = true
	if route.is_empty() or here.distance_to(Vector2(to.x, to.z)) < 0.5:
		_arrive(s)
		return
	_path = route.map(func(q: Vector2) -> Vector3: return Vector3(q.x, 0.0, q.y))


func _arrive(s: Dictionary) -> void:
	_stay = float(s["stay"])
	if s["who"] == "":
		return
	var life = club.get("npc_life")
	var n = life.npc(s["who"]) if life != null else null
	if n == null:
		return
	life.hold(n.id, _stay + 1.0)   # he waits for the word, facing the coach
	var first := String(n.name).get_slice(" ", 0)
	if say(TIPS[randi() % TIPS.size()] % first):
		_reply = [_clock + 2.4, n.id, REPLIES[randi() % REPLIES.size()]]


func _tick_reply() -> void:
	if _reply.is_empty() or _clock < float(_reply[0]):
		return
	var life = club.get("npc_life")
	if life != null:
		life.say(String(_reply[1]), String(_reply[2]), 2.5)
	_reply = []


## Where he is going on his round (for tests): the stops left.
func round_left() -> Array:
	return _stops


## A line in the bubble, unless he spoke a moment ago. `force`: the first-visit line.
func say(key: String, force := false) -> bool:
	if not force and _clock - _last_say < SAY_GAP:
		return false
	var text: String = LINES.get(key, key)
	_last_say = _clock
	club.npc.say("coach", text)
	_murmur = []
	var n := clampi(text.length() / 7, 3, 7)
	for i in n:
		_murmur.append(_clock + i * 0.11 + randf_range(0.0, 0.03))
	return true


func _update_murmur() -> void:
	while not _murmur.is_empty() and _clock >= float(_murmur[0]):
		_murmur.pop_front()
		club.main.sfx.play("club_murmur_%d" % (randi() % SYLLABLES), -9.0, randf_range(0.92, 1.12))


func head_position() -> Vector3:
	return body.global_position + Vector3(0, 2.2, 0)
