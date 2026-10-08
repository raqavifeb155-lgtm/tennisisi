class_name ClubCoach
extends RefCounted
## The coach (docs/club/CLUB_BRIEF.md 6): Main's second Athlete (the opponent in a match)
## dressed in a cap and a polo. He waits by the court, now and then walks to his room and
## back, and talks in a bubble with an Animal Crossing murmur: short syllables, no voice.

const LOOK := {"skin": 5, "hair": 1, "hair_color": 10, "beard": 2, "head": 1, "shirt": 0, "shorts": 3, "accent": 3}
const HOME := Vector3(-2.3, 0.0, 12.3)
const ROUTE := [Vector3(0, 0, 20.5), Vector3(0, 0, 31.0), Vector3(15.0, 0, 31.0), Vector3(16.0, 0, 26.6)]
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
	body.set_look(LOOK)
	body.set_meta("club_coach", true)
	body.area = club.world.walk.bounds
	body.position = HOME
	body.velocity = Vector3.ZERO
	body.relax()
	_path = []
	_wait = randf_range(25.0, 45.0)


func tick(delta: float, hero: Vector3) -> void:
	_clock += delta
	_wait -= delta
	if _path.is_empty() and _wait <= 0.0:
		# Off to his room and back, the long way round through the gate.
		var there := ROUTE.duplicate()
		var back := ROUTE.duplicate()
		back.reverse()
		back.pop_front()
		_path = there + back + [HOME]
		_wait = randf_range(30.0, 60.0)
	var mv := Vector2.ZERO
	if not _path.is_empty():
		var t: Vector3 = _path[0]
		mv = club.world.walk.steer(Vector2(body.position.x, body.position.z), Vector2(t.x, t.z))
		if mv == Vector2.ZERO:
			_path.pop_front()
	body.max_speed = SPEED
	body.move_input = mv
	var look := Vector2(body.velocity.x, body.velocity.z)
	if look.length() < 0.3:
		look = Vector2(hero.x - body.position.x, hero.z - body.position.z)  # waiting: watches the hero
	if look.length() > 0.05:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-look.x, -look.y), 1.0 - exp(-8.0 * delta))
	_update_murmur()


## A line in the bubble, unless he spoke a moment ago. `force`: the first-visit line.
func say(key: String, force := false) -> bool:
	if not force and _clock - _last_say < SAY_GAP:
		return false
	var text: String = LINES.get(key, key)
	_last_say = _clock
	club.hud.say(text)
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
