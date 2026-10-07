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
	hud.roulette_chip.connect(func(c: int) -> void:
		_chip = c
		_roulette_panel())
	hud.roulette_bet.connect(func(bet: String) -> void: spin(bet, _chip))
	hud.roulette_back.connect(roulette_close)
	hud.settings.connect(func() -> void:
		if main.hud.has_method("_toggle_debug"):
			main.hud._toggle_debug())
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
		if not world.roulette().finished.is_connected(_on_spun):
			world.roulette().finished.connect(_on_spun)
		_roulette_on = false
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
	if _roulette_on:
		_roulette_on = false
		hud.hide_roulette()
		main.player.visible = true
		if is_instance_valid(world):
			world.set_roulette_view(false)
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
	_show_hud_settings(true)
	_move_target = Vector3.INF


## The tournament format just chosen: next time "Турнир" goes straight to the bracket.
func remember(location: String, format: int) -> void:
	SaveData.club["last_location"] = location
	SaveData.club["last_format"] = format


func _refresh() -> void:
	_open_ids = []
	var travel: Array = []
	for p in ClubPlaces.LIST:
		var id: String = p["id"]
		var lv := ClubPlaces.level(id)
		if world.level_built(id) != lv:
			world.set_level(id, lv)
		if not ClubPlaces.is_open(p, SaveData.played, SaveData.titles):
			continue
		if ClubPlaces.state(id, lv)["action"] == "":
			continue  # nothing to press yet (a sign says why)
		_open_ids.append(id)
		if p.get("travel", true):
			travel.append({"id": id, "name": p["name"]})
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
	_show_hud_settings(screen_open)
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
	var head := coach.head_position()
	var on_screen := not cam.is_position_behind(head) and get_viewport().get_visible_rect().grow(-20.0).has_point(cam.unproject_position(head))
	hud.bubble_at(cam.unproject_position(head), on_screen)


## Hud's НАСТР button: hidden while the club's own gear is on the screen, back on the
## rooms' screens (TournamentUI keeps its corner free for it) and in a match.
func _show_hud_settings(on: bool) -> void:
	var b = main.hud.get("_debug_btn")
	if b is Control:
		(b as Control).visible = on


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
	if main.ui.is_open() or _roulette_on:
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


## What a place offers right now: its main button and at most one quiet one above it.
## The court's circle is the main screen (HANDOFF 10): «Новая игра» / «Продолжить».
func place_buttons(id: String) -> Dictionary:
	if id == "court":
		var run := SaveData.resumable()
		if run != null:
			return {"label": "ПРОДОЛЖИТЬ  ·  %s" % run.round_name().to_lower(), "action": "continue",
				"extra": [["Новая игра", "club_tournament_new"]]}
		if SaveData.club.has("last_location"):
			var loc := Locations.find(SaveData.club["last_location"])
			return {"label": "НОВАЯ ИГРА  ·  %s" % String(loc["name"]).to_upper(), "action": "club_tournament",
				"extra": [["Другое место", "start_tournament"]]}
		return {"label": "НОВАЯ ИГРА", "action": "club_tournament", "extra": []}
	var st := ClubPlaces.state(id)
	return {"label": String(st["label"]).to_upper(), "action": st["action"], "extra": []}


func _update_badges() -> void:
	var counts := {"coach": Skills.points + Skills.pending.size()}
	var screen := {}
	for id in counts:
		var pos: Vector3 = ClubPlaces.find(id)["pos"] + Vector3(0, 3.6, 0)
		if id != _place and not cam.is_position_behind(pos):
			screen[id] = cam.unproject_position(pos)
	hud.place_badges(counts, screen)


func _on_choice(action: String, arg: int) -> void:
	if action == "club_tournament" or action == "club_tournament_new":
		if action == "club_tournament" and SaveData.resumable() != null:
			main._on_ui("continue", 0)
		elif SaveData.club.has("last_location"):
			main._next_location = SaveData.club["last_location"]
			main._start_tournament(int(SaveData.club.get("last_format", 1)))
		else:
			main._on_ui("start_tournament", 0)
		return
	if action.begins_with("club_"):
		ui_action(action, arg)
		return
	main._on_ui(action, arg)


## The club's own actions (the places' buttons and the club's screens). Main hands the
## ones that come from TournamentUI screens here too ("club_*").
func ui_action(action: String, _arg: int) -> void:
	var id := _place if _place != "" else hud.current_place()
	match action:
		"club_shop":
			ClubScreens.shop(main.ui, ClubPlaces.state("shop"))
		"club_place":
			ClubScreens.place(main.ui, ClubPlaces.state(id))
		"club_roulette":
			roulette_open()
		"club_foreman":
			coach.say("Стройка скоро: прораб ещё в пути", true)


# --- The Totalizator at the bar: a 3D roulette ---------------------------------------

var _roulette_on := false
var _chip := 10
var _spin := {}                        # the spin being shown: field, bet, stake, paid


func roulette_on() -> bool:
	return _roulette_on


func roulette_busy() -> bool:
	return _roulette_on and world.roulette().busy()


## The chips the bar takes now: within its level's limit and a quarter of the gold.
func chips() -> Array:
	var limit := int(ClubPlaces.state("bar").get("bet_limit", 0))
	return Bets.chips_for(SaveData.gold).filter(func(c): return c <= limit)


func roulette_open() -> void:
	if _roulette_on:
		return
	_roulette_on = true
	main.player.move_input = Vector2.ZERO
	_move_target = Vector3.INF
	var w := world.roulette().global_position
	cam.frame(w + Vector3(0, 4.7, 2.9), w + Vector3(0, 0.0, 0.75))  # the wheel whole, above the desk
	hud.hide_place()
	world.set_roulette_view(true)
	main.player.visible = false  # he stands right under the camera
	_roulette_panel()
	if Bets.needs_break(SaveData.bets):
		coach.say("Три ставки мимо подряд. Перерыв? Корт ждёт", true)


func _roulette_panel(result := "", won := false) -> void:
	var allowed := chips()
	if not allowed.is_empty() and not allowed.has(_chip):
		_chip = allowed.back()
	var note := ""
	if allowed.is_empty():
		note = "Ставка — до четверти золота: нужно хотя бы %d" % ceili(Bets.CHIPS[0] / Bets.MAX_SHARE)
	hud.show_roulette(Bets.CHIPS, allowed, _chip, result, won, note)


func roulette_close() -> void:
	if not _roulette_on:
		return
	roulette_skip()
	_roulette_on = false
	hud.hide_roulette()
	world.set_roulette_view(false)
	main.player.visible = true
	cam.release()
	_place = ""
	_update_place()


## A bet: the field is drawn now (Bets.spin), gold paid out now and saved; the wheel only
## shows it. {} when it can't go (the ball still rolls, a stake over the limit).
func spin(bet: String, stake: int) -> Dictionary:
	if not _roulette_on or world.roulette().busy() or not chips().has(stake) or not Bets.PAYS.has(bet):
		return {}
	var field := Bets.spin(main.rng)
	var paid := Bets.payout(bet, stake, field)
	SaveData.gold += paid - stake
	Bets.note(SaveData.bets, paid > 0)
	if bet == "net" and paid > 0:
		SaveData.bets["net_hits"] = int(SaveData.bets.get("net_hits", 0)) + 1
	SaveData.save()
	_spin = {"field": field, "bet": bet, "stake": stake, "paid": paid}
	hud.set_gold(SaveData.gold - paid)  # the win shows when the ball stops
	hud.roulette_spinning(true)
	world.roulette().play(ClubRoulette.simulate(field, main.rng.randi()))
	return _spin


## A tap while the ball rolls: straight to the end.
func roulette_skip() -> void:
	if _roulette_on and world.roulette().busy():
		world.roulette().skip()


func _on_spun() -> void:
	if _spin.is_empty():
		return
	var paid := int(_spin["paid"])
	var names := {"blue": "синее", "red": "красное", "net": "сетка"}
	var text := ("+%d золота" % paid) if paid > 0 else "Мимо: %s" % names[Bets.color_of(int(_spin["field"]))]
	hud.set_gold(SaveData.gold)
	main.sfx.play("point" if paid > 0 else "miss", -8.0)
	_spin = {}
	_roulette_panel(text, paid > 0)
	if Bets.needs_break(SaveData.bets):
		coach.say("Три ставки мимо подряд. Перерыв? Корт ждёт", true)


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
	if _roulette_on:
		roulette_skip()
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
