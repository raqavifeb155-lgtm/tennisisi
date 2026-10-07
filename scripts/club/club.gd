class_name Club
extends Node
## The club as the main screen (docs/club/H1_SPEC.md): Main calls open() where it used to
## show the menu list. The club swaps in its location ("club", ClubWorld), its camera and
## its HUD, walks the hero (Main's player) with the match controls and dresses the
## opponent as the coach. The rooms' screens are still TournamentUI's, opened by the
## same actions. A match, a tournament's bracket or another location closes the club.
##
## Main's hooks (kept small): creates it (setup), calls open() for the menu, skips its own
## match loop and touch handling while `active`, practises on the club court, and tells
## remember() the tournament format chosen.

const WALK_SPEED := 5.5
const START := Vector3(0, 0, 14.0)     # the court's circle: "Турнир" is one tap away

var main: Node
var world: ClubWorld
var cam: ClubCamera
var hud: ClubHud
var coach := ClubCoach.new()
var active := false
var _hero := START
var _move_target := Vector3.INF
var _route: Array = []                 # turning points still to walk (a tap far away)
var _place := ""
var _safe := Vector2(-1, -1)
var _open_ids: Array = []
var _idle := 4                         # Main's Phase.IDLE (Main has no class name to reach it by)


static func enabled() -> bool:
	return not "--old-menu" in OS.get_cmdline_user_args()


func setup(m: Node) -> void:
	main = m
	_idle = main.get_script().get_script_constant_map()["Phase"]["IDLE"]
	cam = ClubCamera.new()
	add_child(cam)
	hud = ClubHud.new()
	add_child(hud)
	hud.chosen.connect(_on_choice)
	hud.travel.connect(_travel)
	for b in hud.buttons:
		main.hud.touch.blocked_controls.append(b)
	main.hud.touch.tapped.connect(_on_tap)
	coach.setup(self, main.cpu)


## Into the club (from the start, a match, a run) or back to it (from a room's screen).
func open() -> bool:
	var fresh: bool = not active or main.location_id != "club"
	if fresh:
		main.set_location("club")
		world = main.scenery as ClubWorld
		if world == null:
			return false  # the club's scenery failed to load: Main keeps its old menu
		main.ui.close()
		active = true
		main.hud.touch.show_zone = false
		var p: Athlete = main.player
		p.area = world.walk.bounds
		p.position = _hero
		p.velocity = Vector3.ZERO
		p.relax()
		p.look_target = Vector3.INF
		main.cpu.look_target = Vector3.INF
		coach.enter()
		cam.target = p
		cam.current = true
		cam.release(0.0)
		cam.snap()
		_place = ""
		hud.hide_place()
	main.ui.close()
	_refresh()
	hud.visible = true
	if not SaveData.club.get("met_coach", false):
		SaveData.club["met_coach"] = true
		SaveData.save()
		coach.say("first", true)
	return true


## Out of the club: Main's camera and the match's areas come back. Positions are Main's
## business from here (it lays out the serve).
func close() -> void:
	if not active:
		return
	active = false
	_hero = main.player.position if _place != "" else START
	var p: Athlete = main.player
	p.area = main.PLAYER_AREA
	p.rotation.y = 0.0
	p.move_input = Vector2.ZERO
	main.cpu.area = main.CPU_AREA
	main.cpu.rotation.y = PI
	main.cpu.move_input = Vector2.ZERO
	main.cam.current = true
	main.hud.touch.show_zone = true
	hud.visible = false
	_move_target = Vector3.INF


## The tournament format just chosen: next time "Турнир" goes straight to the bracket.
func remember(location: String, format: int) -> void:
	SaveData.club["last_location"] = location
	SaveData.club["last_format"] = format


func _refresh() -> void:
	_open_ids = []
	var travel: Array = []
	for p in ClubPlaces.LIST:
		if ClubPlaces.is_open(p, SaveData.played, SaveData.titles):
			_open_ids.append(p["id"])
			travel.append({"id": p["id"], "name": p["name"]})
	world.set_open(_open_ids)
	hud.set_places(travel)
	hud.set_gold(SaveData.gold)
	if _place != "":
		_show_place(_place)


func _process(delta: float) -> void:
	if not active:
		return
	# A match started, or a tournament moved the game elsewhere: the club steps aside.
	if main.phase != _idle or main.location_id != "club" or not is_instance_valid(world):
		close()
		return
	var screen_open: bool = main.ui.is_open()
	hud.visible = not screen_open
	if main._safe != _safe:
		_safe = main._safe
		hud.set_safe_area(maxf(_safe.x, 0.0), maxf(_safe.y, 0.0))
	var vh := get_viewport().get_visible_rect().size.y
	var tap_mode: bool = get_node("/root/Tuning").tap_controls  # by path: tests compile before autoloads
	main.hud.touch.stick_zone_top = INF if tap_mode else vh * 0.34
	coach.tick(delta, main.player.position)
	world.show_interiors_near(main.player.position)
	_update_place()
	_update_badges()
	hud.bubble_at(cam.unproject_position(coach.head_position()), not cam.is_position_behind(coach.head_position()))


func _physics_process(delta: float) -> void:
	if not active:
		return
	var p: Athlete = main.player
	# Walls and posts: the body slides along them (Athlete only knows its rectangle).
	var at := world.walk.resolve(Vector2(p.position.x, p.position.z), Vector2(p.position.x, p.position.z))
	if at.x != p.position.x or at.y != p.position.z:
		p.position = Vector3(at.x, 0.0, at.y)
	var c := coach.body
	var cat := world.walk.resolve(Vector2(c.position.x, c.position.z), Vector2(c.position.x, c.position.z))
	c.position = Vector3(cat.x, 0.0, cat.y)
	if main.ui.is_open():
		p.move_input = Vector2.ZERO
		return
	var mv: Vector2 = main.hud.touch.move_vector
	var here := Vector2(p.position.x, p.position.z)
	if mv != Vector2.ZERO:
		_move_target = Vector3.INF
		_route = []
	elif _move_target != Vector3.INF:
		if _route.is_empty():
			_route = world.walk.route(here, Vector2(_move_target.x, _move_target.z))
			if _route.is_empty():
				_move_target = Vector3.INF  # somewhere the hero can't get to
		while not _route.is_empty():
			mv = world.walk.steer(here, _route[0])
			if mv != Vector2.ZERO and (_route.size() == 1 or here.distance_to(_route[0]) > 0.45):
				break
			_route.pop_front()  # a turning point passed: on to the next
			mv = Vector2.ZERO
		if _route.is_empty() and mv == Vector2.ZERO:
			_move_target = Vector3.INF
	p.max_speed = WALK_SPEED
	p.move_input = mv
	# The hero faces where he walks (the match keeps him facing the net).
	var v := Vector2(p.velocity.x, p.velocity.z)
	if v.length() > 0.4:
		p.rotation.y = lerp_angle(p.rotation.y, atan2(-v.x, -v.y), 1.0 - exp(-12.0 * delta))


## The hero stepped into a place's circle (or out of it).
func _update_place() -> void:
	var here := ClubPlaces.at(main.player.position)
	var id: String = here.get("id", "")
	if id != "" and not _open_ids.has(id):
		id = ""
	world.highlight(id)
	if id == _place:
		return
	_place = id
	if id == "":
		hud.hide_place()
	else:
		_show_place(id)
	var p := ClubPlaces.find(id)
	if p.has("cam"):
		cam.frame(p["cam"]["pos"], p["cam"]["look"])
		world.set_inside(id)
	else:
		cam.release()
		world.set_inside("")
	match id:
		"court":
			coach.say("court_run" if SaveData.resumable() != null else "court")
		"coach":
			if Skills.points + Skills.pending.size() > 0:
				coach.say("coach")


func _show_place(id: String) -> void:
	var b := place_buttons(id)
	hud.show_place(id, b["label"], b["action"], b["extra"])


## What a place offers right now: its main button and the small ones above it.
func place_buttons(id: String) -> Dictionary:
	var p := ClubPlaces.find(id)
	if id == "court":
		var run := SaveData.resumable()
		if run != null:
			return {"label": "ПРОДОЛЖИТЬ  ·  %s" % run.round_name().to_lower(), "action": "continue",
				"extra": [["Тренировка", "practice"], ["Новый турнир", "start_tournament"]]}
		if SaveData.club.has("last_location"):
			var loc := Locations.find(SaveData.club["last_location"])
			return {"label": "ТУРНИР  ·  %s" % String(loc["name"]).to_upper(), "action": "club_tournament",
				"extra": [["Тренировка", "practice"], ["Другое место", "start_tournament"]]}
		return {"label": "ТУРНИР", "action": "club_tournament", "extra": [["Тренировка", "practice"]]}
	return {"label": String(p["label"]).to_upper(), "action": p["action"], "extra": []}


func _update_badges() -> void:
	var counts := {"coach": Skills.points + Skills.pending.size()}
	var screen := {}
	for id in counts:
		var pos: Vector3 = ClubPlaces.find(id)["pos"] + Vector3(0, 3.6, 0)
		if id != _place and not cam.is_position_behind(pos):
			screen[id] = cam.unproject_position(pos)
	hud.place_badges(counts, screen)


func _on_choice(action: String, arg: int) -> void:
	if action == "club_tournament":
		if SaveData.resumable() != null:
			main._on_ui("continue", 0)
		elif SaveData.club.has("last_location"):
			main._next_location = SaveData.club["last_location"]
			main._start_tournament(int(SaveData.club.get("last_format", 1)))
		else:
			main._on_ui("start_tournament", 0)
		return
	main._on_ui(action, arg)


## Quick travel: the camera flies, the hero comes out by the place's circle.
func _travel(id: String) -> void:
	var p := ClubPlaces.find(id)
	if p.is_empty():
		return
	var at: Vector3 = p["pos"]
	main.player.position = at
	main.player.velocity = Vector3.ZERO
	_move_target = Vector3.INF
	_route = []
	_update_place()
	cam.fly()


## A tap on the ground walks the hero there; a tap on an open place's circle (or its
## pavilion) is that place's button, for whoever doesn't want to walk.
func _on_tap(screen_pos: Vector2) -> void:
	if not active or main.ui.is_open() or hud.travel_open():
		return
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if d.y > -0.01:
		return
	var g := o + d * (-o.y / d.y)
	for id in _open_ids:
		var p := ClubPlaces.find(id)
		var c: Vector3 = p["pos"]
		if Vector2(g.x - c.x, g.z - c.z).length() <= float(p["r"]) + 0.6:
			_on_choice(place_buttons(id)["action"], 0)
			return
	_move_target = g
	_route = []
