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
var quests: ClubQuests.Watch          # the coach's quests, counted from the match's events
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
	hud.roulette_back.connect(func() -> void:
		if _foreman_on:
			foreman_close()
		else:
			roulette_close())
	hud.foreman_step.connect(func(d: int) -> void: _foreman_step(d))
	hud.foreman_build.connect(func() -> void: foreman_build())
	hud.foreman_color.connect(func(i: int) -> void:
		_color_pick = i
		foreman_show(_foreman_id))
	hud.upgrade.connect(func(place_id: String) -> void:
		var b: String = ClubPlaces.find(place_id).get("build", "")
		if b != "":
			foreman_open(b))
	hud.skip.connect(skip_build)
	var thud := "res://assets/club/build_thud.wav"
	if ResourceLoader.exists(thud):
		main.sfx._streams["club_build"] = load(thud)
	hud.settings.connect(func() -> void:
		if main.hud.has_method("_toggle_debug"):
			main.hud._toggle_debug())
	for b in hud.buttons:
		main.hud.touch.blocked_controls.append(b)
	main.hud.touch.tapped.connect(_on_tap)
	main.hud.touch.held.connect(_on_hold)
	coach.setup(self, main.cpu)
	quests = ClubQuests.Watch.new()
	add_child(quests)
	quests.setup(main)


## Into the club (from the start, a match, a run) or back to it (from a room's screen).
func open() -> bool:
	var fresh: bool = not active or main.location_id != "club"
	if fresh:
		main.set_location("club")
		world = main.scenery as ClubWorld
		if world == null:
			return false  # the club's scenery failed to load: Main keeps its old menu
		world.set_props_visible(true)
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
	world.set_props_visible(true)
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
	if _foreman_on:
		skip_build()
		_foreman_on = false
		hud.hide_foreman()
		if is_instance_valid(world):
			world.show_ghost("", 0)
			world.focus_room("")
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
	if is_instance_valid(world):
		world.set_props_visible(false)  # a match on the club court: no machine, no circles
	main.cpu.set_meta("club_coach", false)
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
	quests.sync_run()
	world.set_board(ClubQuests.board_text())
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
	if world.level_built("stands") != ClubBuilds.level("stands"):
		world.set_level("stands", ClubBuilds.level("stands"))
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
	if main.ui.is_open() or _roulette_on or _foreman_on:
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
	var left_court := _place == "court" and id == ""
	_place = id
	if left_court and not SaveData.club.get("walk_hint", false):
		SaveData.club["walk_hint"] = true
		SaveData.save()
		var tap_mode: bool = get_node("/root/Tuning").tap_controls
		hud.show_hint(("Это твой клуб. Тап по земле — иди туда, держи палец — иди за ним" if tap_mode else
			"Это твой клуб. Веди пальцем внизу экрана — гуляй") + ". ◎ слева внизу — быстро к корту")
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
			if ClubQuests.claimable_count() > 0:
				coach.say("reward")
			else:
				coach.say("court_run" if SaveData.resumable() != null else "court")
		"coach":
			if Skills.points + Skills.pending.size() > 0:
				coach.say("coach")


func _show_place(id: String) -> void:
	var b := place_buttons(id)
	hud.show_place(id, b["label"], b["action"], b["extra"], upgrade_price(id))


## "↑ 340" by a place whose construction's next level is affordable. Not at the gate (its
## own button is the foreman) and not on the main screen by the court (Новая игра /
## Продолжить stay alone there; the court is built at the foreman's).
func upgrade_price(place_id: String) -> int:
	var b: String = ClubPlaces.find(place_id).get("build", "")
	if b == "" or place_id in ["gate", "court"] or not ClubBuilds.can_afford(b):
		return 0
	return ClubBuilds.next_price(b)


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
				"extra": [["Другое место", "club_locations"]]}
		return {"label": "НОВАЯ ИГРА", "action": "club_tournament", "extra": []}
	if id == "coach":
		if ClubQuests.claimable_count() > 0:
			return {"label": "ЗАБРАТЬ  ·  +%d ●" % ClubQuests.claimable_gold(), "action": "club_claim",
				"extra": [["Навыки", "character"]]}
		return {"label": "НАВЫКИ", "action": "character", "extra": [["Задания", "club_quests"]]}
	var st := ClubPlaces.state(id)
	return {"label": String(st["label"]).to_upper(), "action": st["action"], "extra": []}


## Red counts over places: skill points and quests to collect at the coach's, what's
## affordable at the foreman's.
func badge_counts() -> Dictionary:
	return {"coach": Skills.points + Skills.pending.size() + ClubQuests.claimable_count(), "gate": ClubBuilds.affordable_count()}


func _update_badges() -> void:
	var counts := badge_counts()
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
func ui_action(action: String, arg: int) -> void:
	var id := _place if _place != "" else hud.current_place()
	match action:
		"club_shop":
			if not _hand_to("RunShop", action, arg):
				ClubScreens.shop(main.ui, ClubPlaces.state("shop"))
		"club_locker":
			if not _hand_to("RunLocker", action, arg):
				main._on_ui("locker", 0)  # until stream A's locker: the look / backhand / controls screen
		"club_place":
			ClubScreens.place(main.ui, ClubPlaces.state(id))
		"club_roulette":
			roulette_open()
		"club_foreman":
			foreman_open()
		"club_claim":
			_claim()
		"club_blackjack":
			if not _open_blackjack():
				ClubScreens.place(main.ui, ClubPlaces.state("blackjack"))
		"club_quests":
			ClubScreens.quests(main.ui)
		"club_locations":
			ClubScreens.locations(main.ui)


## 'Забрать' at the coach's: every finished quest's reward at once.
func _claim() -> void:
	if ClubQuests.claimable_count() == 0:
		return
	var r := ClubQuests.claim_all()
	hud.fly_coins(hud.get_viewport().get_visible_rect().size * Vector2(0.5, 0.8))
	hud.set_gold(SaveData.gold)
	main.sfx.play("coin" if main.sfx.has("coin") else "point", -4.0)
	var items: Array = r["items"]
	var line := "Держи %d золота" % int(r["gold"])
	if not items.is_empty():
		line += " и %s" % String(items[0].get("name", "вещь")).to_lower()
	coach.say(line, true)
	world.set_board(ClubQuests.board_text())
	_show_place(_place if _place != "" else "coach")


## Hands a club action to another stream's screen class, the way Main hands the bets and
## the bag to RunBets / RunBag: `Class.ui_action(main, action, arg)`. False if the class
## isn't in the game yet.
func _hand_to(cls: String, action: String, arg: int) -> bool:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			var scr: GDScript = load(c["path"])
			for m in scr.get_script_method_list():
				if m["name"] == "ui_action":
					scr.call("ui_action", main, action, arg)
					return true
	return false


## Stream E's blackjack (hub spec 6): ClubBlackjack.open(club) when it's in the game.
## Its scene stands on world.blackjack_root(), its limit is ClubBuilds.bet_limit().
func _open_blackjack() -> bool:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "ClubBlackjack":
			var scr: GDScript = load(c["path"])
			for m in scr.get_script_method_list():
				if m["name"] == "open":
					scr.call("open", self)
					return true
	return false


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
	if _foreman_on:
		return
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if d.y > -0.01:
		return
	var g := o + d * (-o.y / d.y)
	# A tap on a place walks the hero into its circle; only its button acts (the owner's
	# phone test: a tap on the court started practice by the machine).
	for id in _open_ids:
		var p := ClubPlaces.find(id)
		var c: Vector3 = p["pos"]
		if Vector2(g.x - c.x, g.z - c.z).length() <= float(p["r"]) + 0.6:
			g = Vector3(c.x, 0.0, c.z)
			break
	_move_target = g
	_route = []


## Holding the finger (tap controls): the hero keeps walking toward it.
func _on_hold(screen_pos: Vector2) -> void:
	if not active or main.ui.is_open() or hud.travel_open() or _roulette_on or _foreman_on:
		return
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if d.y > -0.01:
		return
	var g := o + d * (-o.y / d.y)
	if _move_target == Vector3.INF or Vector2(g.x - _move_target.x, g.z - _move_target.z).length() > 0.6:
		_move_target = g
		_route = []


# --- The foreman: buying the constructions' levels (H2) --------------------------------

## Where the camera looks at each construction from (above the foreman's cards).
## The phone's frame is narrow (a 52-degree vertical FOV is ~25 degrees across), so the
## camera stands far enough to take a construction's whole width, and looks a little in
## front of it: the foreman's card covers the lower part of the screen.
const BUILD_VIEW := {
	"court": [Vector3(0, 27.0, 36.0), Vector3(0, 0, 10.0)],
	"stands": [Vector3(14.0, 9.0, 12.0), Vector3(11.5, 0.5, -3.0)],
	"gate": [Vector3(3.5, 21.0, 60.0), Vector3(3.5, 0.0, 42.0)],
	"trophy": [Vector3(-17.5, 10.0, -11.0), Vector3(-17.5, 0.0, -24.5)],
	"shop": [Vector3(22.0, 11.0, 13.0), Vector3(22.0, 0.0, 4.6)],
	"locker": [Vector3(-14.0, 11.0, 37.0), Vector3(-14.0, 0.0, 28.6)],
	"bar": [Vector3(20.0, 17.0, -9.0), Vector3(20.0, 0.0, -27.5)],
}
const BUILD_TIME := 2.0

var _foreman_on := false
var _foreman_id := ""
var _color_pick := -1
var _building := false
var _build_tw: Tween
var _build_fx: Array = []


func foreman_on() -> bool:
	return _foreman_on


func building() -> bool:
	return _building


## The foreman's strip, on a construction (or the first affordable one).
func foreman_open(start := "") -> void:
	_foreman_on = true
	main.player.move_input = Vector2.ZERO
	_move_target = Vector3.INF
	hud.hide_place()
	if start == "":
		start = ClubBuilds.ORDER[0]
		for id in ClubBuilds.ORDER:
			if ClubBuilds.can_afford(id):
				start = id
				break
	foreman_show(start)
	if ClubBuilds.affordable_count() == 0:
		var cheapest := _cheapest_gap()
		if cheapest != "":
			coach.say(cheapest, true)


## "До трибун 12 золота — ещё один забег" (H2 7).
func _cheapest_gap() -> String:
	var best := ""
	var gap := 1 << 30
	for id in ClubBuilds.ORDER:
		if ClubBuilds.is_open(id) and not ClubBuilds.next(id).is_empty():
			var g := ClubBuilds.next_price(id) - SaveData.gold
			if g > 0 and g < gap:
				gap = g
				best = id
	if best == "":
		return ""
	return "До «%s» %d золота — ещё один забег" % [String(ClubBuilds.next(best)["title"]).to_lower(), gap]


func foreman_show(id: String) -> void:
	if not ClubBuilds.TABLE.has(id):
		return
	if id != _foreman_id:
		_color_pick = -1
	_foreman_id = id
	var lv := ClubBuilds.level(id)
	var mx := ClubBuilds.max_level(id)
	var t: Dictionary = ClubBuilds.TABLE[id]
	var dots := ""
	for i in mx:
		dots += "●" if i < lv else "○"
	var card := {"tag": "%s   %s" % [t["name"], dots], "max": lv >= mx}
	var build := {}
	var colors := 0
	if not ClubBuilds.is_open(id):
		card["title"] = t["name"]
		card["desc"] = "Откроется %s" % ("после первого забега" if t["unlock"] == "played" else "после первого титула")
		card["locked"] = true
	elif lv >= mx:
		card["title"] = "Максимум"
		card["desc"] = "Сейчас: %s" % t["levels"][mx - 1]["now"]
	else:
		var nx: Dictionary = t["levels"][lv]
		card["title"] = nx["title"]
		var now: String = t.get("start", "ничего") if lv == 0 else String(t["levels"][lv - 1]["now"])
		card["desc"] = "Сейчас: %s\nБудет: %s" % [now, nx["now"]]
		var perk_now := "" if lv == 0 else String(t["levels"][lv - 1].get("perk", ""))
		if String(nx.get("perk", "")) != "":
			card["desc"] += "\nПольза: %s" % (("%s → %s" % [perk_now, nx["perk"]]) if perk_now != "" else nx["perk"])
		var price := ClubBuilds.next_price(id)
		if ClubBuilds.can_afford(id):
			build = {"text": "ПОСТРОИТЬ  ·  %d ●" % price, "can": true}
		else:
			build = {"text": "Нужно ещё %d" % (price - SaveData.gold), "can": false}
		if id == "court" and lv == 2:
			colors = ClubMaterial.CLUB_COLORS.size()
	var i := ClubBuilds.ORDER.find(id)
	if _color_pick < 0:
		_color_pick = ClubBuilds.color_index()
	hud.show_foreman(card, build, i > 0, i < ClubBuilds.ORDER.size() - 1, colors, _color_pick)
	hud.set_gold(SaveData.gold)
	var view: Array = BUILD_VIEW[id]
	cam.frame(view[0], view[1])
	world.focus_room(id)
	if lv < mx and ClubBuilds.is_open(id):
		world.show_ghost(id, lv + 1)
	else:
		world.show_ghost("", 0)


func _foreman_step(d: int) -> void:
	if _building:
		return
	var i := clampi(ClubBuilds.ORDER.find(_foreman_id) + d, 0, ClubBuilds.ORDER.size() - 1)
	foreman_show(ClubBuilds.ORDER[i])


## Buys the next level of the card in the middle and plays the build moment. The gold is
## gone and saved before the show (a tap or leaving midway changes nothing).
func foreman_build() -> bool:
	if not _foreman_on or _building:
		return false
	var id := _foreman_id
	if not ClubBuilds.can_afford(id):
		hud.shake_gold()
		return false
	var color_level := id == "court" and ClubBuilds.level(id) == 2
	if not ClubBuilds.buy(id):
		return false
	if color_level:
		SaveData.club["color"] = maxi(_color_pick, 0)
		SaveData.save()
	var lv := ClubBuilds.level(id)
	world.show_ghost("", 0)
	world.set_level(id, lv)
	_refresh()
	_play_build(id, lv)
	return true


func _play_build(id: String, lv: int) -> void:
	_building = true
	hud.set_building(true)
	hud.set_gold(SaveData.gold)
	var view: Array = BUILD_VIEW[id]
	var focus: Vector3 = view[1]
	hud.fly_coins(cam.unproject_position(focus))
	# The camera comes closer.
	cam.frame((view[0] as Vector3).lerp(focus, 0.3), focus, 0.4)
	var root := world.level_root(id) if not world.is_room(id) else world.room_inside(id)
	if root:
		root.scale = Vector3(1, 0.0, 1)
	# Dust and a gold ring at the foot of it.
	var dust := CPUParticles3D.new()
	dust.amount = 40 if world.high_quality() else 12
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.lifetime = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 1.5
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 3.5
	dust.gravity = Vector3(0, -2.0, 0)
	dust.scale_amount_min = 0.25
	dust.scale_amount_max = 0.6
	var dm := SphereMesh.new()
	dm.radius = 0.25
	dm.height = 0.5
	dm.radial_segments = 6
	dm.rings = 3
	dust.mesh = dm
	dust.material_override = ClubMaterial.get_mat(ClubMaterial.PALETTE[ClubMaterial.PAVING], false)
	dust.position = focus + Vector3(0, 0.3, 0)
	world.add_child(dust)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 3
	ring.mesh = tm
	ring.material_override = ClubMaterial.glow(UiTheme.GOLD, 1.4)
	ring.position = focus + Vector3(0, 0.1, 0)
	ring.scale = Vector3(0.5, 0.05, 0.5)
	world.add_child(ring)
	_build_fx = [dust, ring]
	_build_tw = create_tween()
	_build_tw.tween_interval(0.5)                     # the coins land
	_build_tw.tween_callback(func() -> void:
		dust.emitting = true
		main.sfx.play("club_build" if main.sfx.has("club_build") else "bounce", -2.0, 0.8)
		TelegramApp.haptic("heavy"))
	_build_tw.tween_property(ring, "scale", Vector3(4.0, 0.05, 4.0), 0.3)
	if root:
		_build_tw.tween_property(root, "scale", Vector3(1, 1.08, 1), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_build_tw.tween_property(root, "scale", Vector3.ONE, 0.15)
	_build_tw.tween_interval(maxf(0.0, BUILD_TIME - 1.3))
	_build_tw.tween_callback(_end_build.bind(id, lv))


## A tap during the build moment: straight to how it ends.
func skip_build() -> void:
	if not _building:
		return
	if _build_tw:
		_build_tw.kill()
	_end_build(_foreman_id, ClubBuilds.level(_foreman_id))


func _end_build(id: String, lv: int) -> void:
	_building = false
	var root: Node3D = null
	if is_instance_valid(world):
		root = world.level_root(id) if not world.is_room(id) else world.room_inside(id)
	if root:
		root.scale = Vector3.ONE
	for n in _build_fx:
		if is_instance_valid(n):
			n.queue_free()
	_build_fx = []
	hud.set_building(false)
	if ClubBuilds.level("stands") >= 1 and main.sfx.has("applause"):
		main.sfx.play("applause", -10.0)
	coach.say(ClubBuilds.line(id, lv), true)
	if _foreman_on:
		foreman_show(id)


func foreman_close() -> void:
	if not _foreman_on:
		return
	skip_build()
	_foreman_on = false
	hud.hide_foreman()
	world.show_ghost("", 0)
	world.focus_room("")
	cam.release()
	_place = ""
	_refresh()
	_update_place()
