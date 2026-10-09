class_name HouseVisit
extends Node
## The hero in the academy's house (spec 0.1, 8.2): the door of the academy in the club, a fade of 0.25 s,
## the house instead of the club, the same walk and camera, and the way back. A child of Club; Club hands it
## its per-frame work while the hero is inside (`tick`) and the actions «club_house*» (HouseRoomSheet.route).
##
## What "inside" means for the rest: the club's world is hidden and does not process, its people (ClubNpcLife)
## and the coach are put away, the walls the hero meets and the camera keeps out of are the house's
## (Club._walk(), ClubCamera.walk_override), the camera has the house's light (its own Environment). The house
## is built on the first visit and then only hidden (a second visit is instant); Club.close() frees it.

const FADE := 0.25                  # seconds to black and back
const ENTER_BUDGET := 0.7           # from the tap to the controls, seconds (spec 8.2)

signal entered
signal left

var club: Node                      # the Club
var world: HouseWorld
var inside := false
var busy := false                   # a fade is on
var build_ms := 0.0                 # what the house cost to build the first time (the tests and the shots print it)
var _veil: ColorRect
var _layer: CanvasLayer
var _room := ""                     # the room the hero stands in ("" = the hall)
var _key := ""                      # what the place button shows now
var _shut := ""                     # the shut door the hero stands at
var _tw: Tween


func setup(c: Node) -> void:
	club = c
	_layer = CanvasLayer.new()
	_layer.layer = 12                # over the club's HUD (9) and the screens (10), under the settings (20)
	add_child(_layer)
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0, 0, 0, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	_layer.add_child(_veil)


## The ClubWalk of the house (what the hero and the camera collide with), null outside.
func walk() -> ClubWalk:
	return world.walk if inside and world != null else null


func _fade(to: float) -> void:
	_veil.visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_veil, "color:a", to, FADE)
	await _tw.finished
	if to <= 0.0:
		_veil.visible = false


# --- Going in -------------------------------------------------------------------------------------------

## The door: fade out, the house, fade in. The controls are the hero's as soon as the house is up (during the
## second half of the fade). Awaitable.
func enter() -> void:
	if inside or busy or not AcademyHouse.is_built() or not is_instance_valid(club.world):
		return
	busy = true
	club.main.player.move_input = Vector2.ZERO
	club._move_target = Vector3.INF
	club._route = []
	club.hud.hide_place()
	await _fade(1.0)
	_swap_in()
	busy = false
	entered.emit()
	await _fade(0.0)


func _swap_in() -> void:
	var t0 := Time.get_ticks_usec()
	var main: Node = club.main
	club.world.visible = false
	club.world.process_mode = Node.PROCESS_MODE_DISABLED
	if club.npc_life != null:
		club.npc_life.set_active(false)
	main.cpu.visible = false
	if world == null:
		world = HouseWorld.new()
		club.add_child(world)
		build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	world.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.set_shadows(club.world.high_quality())
	var done := AcademyHouse.complete_ready()   # the scaffolding that came down over the runs played
	world.sync()
	inside = true
	_room = ""
	_key = ""
	var p: Athlete = main.player
	p.area = world.walk.bounds
	p.position = HouseWorld.spawn()
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	club._hero_y = 0.0
	club._place = ""
	club._auto = ""
	club._stick_down = false
	club.cam.walk_override = world.walk
	club.cam.environment = world.env
	club.cam.release(0.0)
	club.cam.snap()
	world.set_inside("")
	world.show_near(p.position)
	club.hud._toggle_travel(false)
	club.hud._travel_btn.visible = false
	club.hud.set_gold(SaveData.gold)
	club.hud.place_badges({}, {})        # the club's red counts stay behind
	club.hud._bubble.visible = false
	for x in done:
		_announce_built(String(x["room"]), int(x["level"]))


# --- Going out ---------------------------------------------------------------------------------------------

## The door out: fade out, the club, fade in. Awaitable.
func leave() -> void:
	if not inside or busy:
		return
	busy = true
	club.main.player.move_input = Vector2.ZERO
	club._move_target = Vector3.INF
	club._route = []
	club.hud.hide_place()
	await _fade(1.0)
	_swap_out(true)
	busy = false
	left.emit()
	await _fade(0.0)


## Back in the club. `at_door`: the hero stands at the academy's door (else Club.close() is leaving anyway).
func _swap_out(at_door: bool) -> void:
	inside = false
	var main: Node = club.main
	club.cam.walk_override = null
	club.cam.environment = null
	club.hud._travel_btn.visible = true
	if world != null:
		world.visible = false
		world.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(club.world):
		club.world.visible = true
		club.world.process_mode = Node.PROCESS_MODE_INHERIT
		(main.player as Athlete).area = club.world.walk.bounds
	main.cpu.visible = true
	if club.npc_life != null and club.active:
		club.npc_life.set_active(true)
	if at_door and club.active:
		var p: Athlete = main.player
		var door: Vector3 = ClubPlaces.find("academy")["pos"]
		p.position = door
		p.velocity = Vector3.ZERO
		p.rotation.y = 0.0
		club._hero_y = club.world.walk.floor_at(Vector2(door.x, door.z))
		club._place = ""
		club.cam.release(0.0)
		club.cam.snap()
		club._update_place()
	_room = ""
	_key = ""


## The club is closing (a match, a bracket): the house goes, with no fade. A second visit builds it again.
func shutdown() -> void:
	if inside:
		_swap_out(false)
	if world != null:
		world.queue_free()
		world = null
	_veil.visible = false
	busy = false


# --- Each frame inside -----------------------------------------------------------------------------------

## Club._process while the hero is in the house.
func tick(_delta: float) -> void:
	if not inside or world == null:
		return
	var p: Node3D = club.main.player
	var room := HouseWorld.room_at(p.position)
	if room != _room:
		_room = room
		world.set_inside(room)
		if room != "":
			var v := HouseWorld.room_view(room)
			club.cam.frame(v[0], v[1])
		else:
			club.cam.release()
		_key = ""
	world.show_near(p.position)
	_update_place(p.position)
	_shut_door_hint(p.position)


## The button for where the hero stands: the way out at the door, a room's sheet inside a room.
func _update_place(pos: Vector3) -> void:
	var key := ""
	if _room != "":
		key = "%s|%d|%s|%d" % [_room, AcademyHouse.level(_room), AcademyHouse.why_not(_room), SaveData.gold if AcademyHouse.can_buy(_room) else 0]
	elif HouseWorld.at_exit(pos):
		key = "exit"
	if key == _key:
		return
	_key = key
	var hud = club.hud
	if key == "":
		hud.hide_place()
	elif key == "exit":
		hud.show_place("house_exit", "ВЫЙТИ ИЗ ДОМА", "club_house_exit", [])
	else:
		var lv := AcademyHouse.level(_room)
		var label := "%s  ·  %d/%d" % [HouseRooms.short_of(_room).to_upper(), lv, HouseRooms.MAX_LEVEL]
		if AcademyHouse.is_building(_room):
			label = "%s  ·  СТРОИТСЯ" % HouseRooms.short_of(_room).to_upper()
		var extra: Array = []
		if AcademyHouse.can_buy(_room):
			extra.append(["Улучшить  ·  %d ●" % AcademyHouse.next_price(_room), "club_house_up:" + _room])
		hud.show_place("house_" + _room, label, "club_house_room:" + _room, extra)


## A shut door the hero stops at says when it opens, once per visit to the door.
func _shut_door_hint(pos: Vector3) -> void:
	var near := ""
	if _room == "":
		for id in HouseRooms.ids():
			if not AcademyHouse.is_open(id) and Vector2(pos.x - HouseWorld.door_point(id).x, pos.z - HouseWorld.door_point(id).z).length() < 1.9:
				near = id
				break
	if near == _shut:
		return
	_shut = near
	if near != "":
		club.hud.show_hint("%s: откроется на уровне академии %d (сейчас %d)" % [HouseRooms.name_of(near), HouseRooms.opens(near), AcademyHouse.building_level()], 3.5)


## Rebuilds the button on the next frame (something changed under it).
func refresh_place() -> void:
	_key = "?"


# --- Buying ----------------------------------------------------------------------------------------------------

## Buys the next level of a room for the gold: the build moment (a bounce) or the scaffolding. Returns the level
## bought (0: it couldn't be).
func buy(room: String) -> int:
	var n := AcademyHouse.buy(room)
	if n <= 0:
		club.hud.shake_gold()
		return 0
	club.hud.set_gold(SaveData.gold)
	if world != null:
		world.sync()
	if AcademyHouse.is_building(room):
		club.hud.show_hint("%s · ур. %d: леса стоят, ещё %d %s" % [HouseRooms.short_of(room), n, AcademyHouse.runs_left(room), ClubBuilds.runs_word(AcademyHouse.runs_left(room))])
	else:
		_announce_built(room, n)
		TelegramApp.haptic("heavy")
	var main: Node = club.main
	if main.sfx.has("club_build"):
		main.sfx.play("club_build", -2.0, 0.8)
	refresh_place()
	return n


func _announce_built(room: String, lv: int) -> void:
	if world != null:
		world.bounce(room)
	club.hud.show_hint("%s · ур. %d: %s" % [HouseRooms.short_of(room), lv, String(HouseRooms.level(room, lv)["obj"]).to_lower()])
