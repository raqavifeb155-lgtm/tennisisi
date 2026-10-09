class_name HouseWorld
extends Node3D
## The academy's house as a place (spec 0.1, 8): its own scene far from the club, a hall 4 m wide with four
## rooms of 6 x 6 m on each side, no ceiling - a dolls' house for the camera. The club behind it is
## not drawn and not processed while the hero is here (HouseVisit hides and pauses it).
##
## The plan, from the entrance (south) to the north end of the hall (x across the hall, -z north):
##
##          west rooms          hall          east rooms
##   row 3  med                               hall (reception)
##   row 2  video                             coach
##   row 1  gym                               lounge
##   row 0  dorm                              canteen          <- the door out is at the south end
##
## A room's own frame is the art stream's (HouseProps): the back wall at z = -3, the wall to the hall at
## x = -3, the door at z = +1.5; rooms west of the hall are mirrored. The front (south) wall of a room
## and the wall between two rooms are the room's "fade": hidden while the hero is in the room.
##
## Everything solid is one mesh with the colours in its vertices (the shell), each room's things one
## more, each front wall one more, and a sign by each door: the world is some thirty draw calls.

const ORIGIN := Vector3(2000.0, 0.0, 0.0)    # where it stands: the club is a kilometre away, out of the camera's far plane
const WALL_H := 3.0
const T := 0.2                                # a wall's thickness
const ROOM := 6.0                             # a room's inside, x and z
const PITCH := 6.4                            # from one room's centre to the next: the room and the wall between
const HALL_HALF := 2.0                        # the hall is 4 m wide
const DOOR_W := 1.8
const DOOR_DZ := 1.5                          # the door's centre, from the room's centre toward the entrance
const ROWS := 4
const FRONT := -0.2                           # the hall's south end (the front wall stands on z -0.2 .. 0)
const NORTH := FRONT - ROWS * PITCH + 0.4     # the hall's north end: -25.4
const EXIT_AT := Vector2(0.0, -1.5)           # the circle by the door out (local x, z) ...
const EXIT_R := 1.6
const SPAWN := Vector3(0.0, 0.0, -2.4)
const SIGN_W := 1.15                          # a door's plate, hanging into the hall from its wall
const NEAR := 14.0                            # rooms farther than this from the hero aren't drawn

const SKY_TOP := Color("1c1a33")                # a dusk behind the dolls' house: a deep blue over a warm table
const SKY_HORIZON := Color("5b4a52")
const HALL_FLOOR := Color("d2b48c")
const HALL_WALL := Color("efe4cf")
const CARPET := Color("2a54a3")
const CLOSED_FLOOR := Color("26232b")
const CLOSED_WALL := Color("5a5560")

var walk := ClubWalk.new()
var env: Environment
var sun: DirectionalLight3D

var _shell: MeshInstance3D
var _ground: MeshInstance3D
var _rooms := {}          # id -> {root, fade (MeshInstance3D), stuff (MeshInstance3D), sign (Label3D), built, mark, scaffold, open}
var _inside := ""
var _exit_sign: Label3D
var _hall_sign: Label3D
var _bounce: Tween


func _init() -> void:
	name = "HouseWorld"
	position = ORIGIN


func _ready() -> void:
	_build_environment()
	_build_ground()
	_shell = MeshInstance3D.new()
	_shell.name = "Shell"
	_shell.material_override = ClubScenery.prop_material()
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	for id in HouseRooms.ids():
		_make_room(id)
	_build_walk()
	_build_signs()
	sync()


# --- The plan -------------------------------------------------------------------------------------

## The centre of a room's floor in the world.
static func room_center(room: String) -> Vector3:
	return ORIGIN + _local_center(room)


static func _local_center(room: String) -> Vector3:
	var d: Dictionary = HouseRooms.ROOMS[room]
	return Vector3(int(d["side"]) * (HALL_HALF + T + ROOM * 0.5), 0.0, FRONT - ROOM * 0.5 - int(d["row"]) * PITCH)


## The room's inside in the world (x, z): where the hero counts as being in it.
static func room_rect(room: String) -> Rect2:
	var c := room_center(room)
	return Rect2(c.x - ROOM * 0.5, c.z - ROOM * 0.5, ROOM, ROOM)


## The camera's framing of a room, like a pavilion's: above and behind the south wall, looking in.
static func room_view(room: String) -> Array:
	var c := room_center(room)
	return [c + Vector3(0.0, 11.0, 9.6), c + Vector3(0.0, 0.3, -0.3)]


## The room the point is in ("" in the hall).
static func room_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	for id in HouseRooms.ids():
		if room_rect(id).has_point(q):
			return id
	return ""


## Where the hero's feet are when he comes in: the hall by the door, facing north.
static func spawn() -> Vector3:
	return ORIGIN + SPAWN


static func exit_center() -> Vector3:
	return ORIGIN + Vector3(EXIT_AT.x, 0.0, EXIT_AT.y)


static func at_exit(p: Vector3) -> bool:
	return Vector2(p.x - ORIGIN.x - EXIT_AT.x, p.z - ORIGIN.z - EXIT_AT.y).length() <= EXIT_R


## The door of a room in the world (the hall side, in the hall).
static func door_point(room: String) -> Vector3:
	var d: Dictionary = HouseRooms.ROOMS[room]
	var c := room_center(room)
	return Vector3(ORIGIN.x + int(d["side"]) * (HALL_HALF - 0.9), 0.0, c.z + DOOR_DZ)


static func bounds() -> Rect2:
	var w := HALL_HALF + T + ROOM + T
	return Rect2(ORIGIN.x - w, ORIGIN.z + NORTH - 0.2, w * 2.0, -NORTH + 0.2)


# --- Light ----------------------------------------------------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.ground_bottom_color = SKY_HORIZON
	sky_mat.sky_curve = 0.25
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.88)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	sun = DirectionalLight3D.new()
	sun.name = "HouseLight"
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	sun.shadow_enabled = false     # none on Low; the visit turns them on from Medium (set_shadows)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 26.0
	add_child(sun)


func set_shadows(on: bool) -> void:
	sun.shadow_enabled = on


func _build_ground() -> void:
	_ground = MeshInstance3D.new()
	_ground.name = "Table"
	var m := BoxMesh.new()
	m.size = Vector3(260.0, 0.1, 260.0)
	_ground.mesh = m
	_ground.position = Vector3(0.0, -0.16, -12.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = SKY_HORIZON
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground.material_override = gm
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)


# --- Rooms ----------------------------------------------------------------------------------------------

func _make_room(id: String) -> void:
	var root := Node3D.new()
	root.name = "Room_" + id
	root.position = _local_center(id)
	add_child(root)
	var fade := MeshInstance3D.new()
	fade.name = "Fade"
	fade.material_override = ClubScenery.prop_material()
	fade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fade)
	var stuff := MeshInstance3D.new()
	stuff.name = "Stuff"
	stuff.material_override = ClubScenery.prop_material()
	stuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stuff)
	var sign := _label("", 40, Vector3.ZERO, 0.0, Color.WHITE)
	sign.name = "Sign"
	add_child(sign)
	_rooms[id] = {"root": root, "fade": fade, "stuff": stuff, "sign": sign, "built": -1, "mark": -1, "scaffold": -1, "open": null}
	# the front wall / the wall between two rooms: built once
	fade.mesh = _fade_mesh(id, (HouseRooms.ROOMS[id]["look"]["wall"] as Color))


func _fade_mesh(id: String, wall: Color) -> ArrayMesh:
	var d: Dictionary = HouseRooms.ROOMS[id]
	var side := int(d["side"])
	var row := int(d["row"])
	var c := _local_center(id)
	var x0 := HALL_HALF + T
	var x1 := x0 + ROOM + T
	var sb := ClubShapes.new()
	var z_mid := -0.1 if row == 0 else -float(row) * PITCH      # the wall's centre, in the house's frame
	var thick := T if row == 0 else 2.0 * T
	sb.box(Vector3(x1 - x0, WALL_H, thick), Vector3(side * (x0 + x1) * 0.5 - c.x, WALL_H * 0.5, z_mid - c.z), wall)
	sb.box(Vector3(x1 - x0, 0.14, thick + 0.1), Vector3(side * (x0 + x1) * 0.5 - c.x, WALL_H + 0.05, z_mid - c.z), (d["look"]["trim"] as Color))
	return sb.build()


## The shell: the floors, the walls that stay, the doors. Rebuilt when a room opens or closes.
func _rebuild_shell() -> void:
	var sb := ClubShapes.new()
	var z_mid := (FRONT + NORTH) * 0.5
	var z_len := FRONT - NORTH
	# the hall: a wood floor and a blue runner
	sb.box(Vector3(HALL_HALF * 2.0, 0.1, z_len), Vector3(0.0, -0.05, z_mid), HALL_FLOOR)
	sb.box(Vector3(1.5, 0.02, z_len - 1.6), Vector3(0.0, 0.01, z_mid), CARPET)
	sb.box(Vector3(1.6, 0.02, 0.9), Vector3(0.0, 0.01, -0.6), Color("7a2f2a"))   # the mat at the door
	# the south wall of the hall, with the door out
	var gap := 1.8
	var sx := (HALL_HALF + T - gap * 0.5) * 0.5
	for s in [-1.0, 1.0]:
		sb.box(Vector3(HALL_HALF + T - gap * 0.5, WALL_H, T), Vector3(s * (gap * 0.5 + sx), WALL_H * 0.5, -0.1), HALL_WALL)
		sb.box(Vector3(0.2, 2.5, 0.3), Vector3(s * (gap * 0.5 + 0.1), 1.25, -0.1), Color("6b4a32"))
	sb.box(Vector3(gap + 0.4, WALL_H - 2.5, T), Vector3(0.0, 2.5 + (WALL_H - 2.5) * 0.5, -0.1), HALL_WALL)
	sb.box(Vector3(gap + 0.4, 0.12, 0.3), Vector3(0.0, 2.5, -0.1), Color("6b4a32"))
	# the north end
	sb.box(Vector3((HALL_HALF + T + ROOM + T) * 2.0, WALL_H, T), Vector3(0.0, WALL_H * 0.5, NORTH - 0.1), HALL_WALL)
	for id in HouseRooms.ids():
		_shell_room(sb, id)
	# lamps along the hall (the boxes glow in the vertex colours) and plants at the door
	for r in range(1, ROWS):
		for s in [-1.0, 1.0]:
			sb.box(Vector3(0.12, 0.34, 0.3), Vector3(s * (HALL_HALF - 0.06), 2.1, -float(r) * PITCH + 0.0), Color("ffe9a8"))
	for s in [-1.0, 1.0]:
		var p := Vector3(s * 1.5, 0.0, -1.0)
		sb.cyl(0.28, 0.2, 0.45, p + Vector3(0, 0.22, 0), Color("b5654a"), 8)
		sb.ball(0.42, p + Vector3(0, 0.9, 0), Color("4d7a33"), Vector3(1, 1.2, 1), 7, 5)
	_shell.mesh = sb.build()


func _shell_room(sb: ClubShapes, id: String) -> void:
	var d: Dictionary = HouseRooms.ROOMS[id]
	var side := float(d["side"])
	var c := _local_center(id)
	var look: Dictionary = d["look"]
	var open := AcademyHouse.is_open(id)
	var floor_col: Color = look["floor"] if open else CLOSED_FLOOR
	var wall: Color = look["wall"] if open else CLOSED_WALL
	var trim: Color = look["trim"] if open else CLOSED_WALL.darkened(0.2)
	var x_in := HALL_HALF + T
	# the floor of the room
	sb.box(Vector3(ROOM, 0.1, ROOM), Vector3(c.x, -0.05, c.z), floor_col)
	# the wall to the hall, with the door (x from HALL_HALF to HALL_HALF + T), the whole pitch of the row
	var wx := side * (HALL_HALF + T * 0.5)
	var z_s := c.z + PITCH * 0.5           # south end of the wall's span
	var z_n := c.z - PITCH * 0.5
	var g0 := c.z + DOOR_DZ - DOOR_W * 0.5   # the door's north edge
	var g1 := c.z + DOOR_DZ + DOOR_W * 0.5
	sb.box(Vector3(T, WALL_H, g0 - z_n), Vector3(wx, WALL_H * 0.5, (z_n + g0) * 0.5), wall)
	sb.box(Vector3(T, WALL_H, z_s - g1), Vector3(wx, WALL_H * 0.5, (g1 + z_s) * 0.5), wall)
	sb.box(Vector3(T, WALL_H - 2.4, DOOR_W), Vector3(wx, 2.4 + (WALL_H - 2.4) * 0.5, (g0 + g1) * 0.5), wall)
	for z in [g0, g1]:
		sb.box(Vector3(T + 0.08, 2.4, 0.1), Vector3(wx, 1.2, z), trim)
	sb.box(Vector3(T + 0.08, 0.1, DOOR_W + 0.1), Vector3(wx, 2.4, (g0 + g1) * 0.5), trim)
	# the plate over the door: it hangs into the hall, facing the entrance, so it reads as the hero walks in
	sb.box(Vector3(SIGN_W, 0.62, 0.06), Vector3(side * (HALL_HALF - SIGN_W * 0.5), 2.6, (g0 + g1) * 0.5), trim.darkened(0.35) if open else CLOSED_WALL.darkened(0.3))
	if not open:
		sb.box(Vector3(0.12, 2.4, DOOR_W), Vector3(wx, 1.2, (g0 + g1) * 0.5), Color("3a2f2a"))
		sb.box(Vector3(0.14, 0.2, 0.2), Vector3(wx - side * 0.07, 1.2, (g0 + g1) * 0.5), Color("e8b84a"))
		# a lid: the shut room is a box
		sb.box(Vector3(ROOM + 0.2, 0.15, ROOM + 0.2), Vector3(c.x, WALL_H + 0.075, c.z), CLOSED_WALL.darkened(0.1))
	# the outer wall, a window in it
	var ox := side * (x_in + ROOM + T * 0.5)
	sb.box(Vector3(T, WALL_H, ROOM + 0.0), Vector3(ox, WALL_H * 0.5, c.z), wall)
	if open:
		sb.box(Vector3(0.05, 1.1, 1.8), Vector3(ox - side * (T * 0.5 + 0.01), 1.45, c.z - 0.4), Color("b9dbe8"))
		sb.box(Vector3(0.07, 0.06, 1.9), Vector3(ox - side * (T * 0.5 + 0.01), 0.9, c.z - 0.4), trim)
	# skirting
	if open:
		sb.box(Vector3(0.05, 0.14, ROOM), Vector3(ox - side * (T * 0.5 + 0.025), 0.07, c.z), trim)


func _build_signs() -> void:
	_exit_sign = _label("ВЫХОД", 56, Vector3(0.0, 2.75, -0.26), PI, Color("9be3a8"))   # faces north, into the hall
	add_child(_exit_sign)
	_hall_sign = _label("АКАДЕМИЯ", 70, Vector3(0.0, 2.05, NORTH + 0.02), 0.0, UiTheme.GOLD)
	_hall_sign.width = 900
	add_child(_hall_sign)


func _label(text: String, size: int, pos: Vector3, yaw: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.text_bold()
	l.font_size = size
	l.pixel_size = 0.0055
	l.width = 420
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = col
	l.outline_size = 8
	l.outline_modulate = Color(0.08, 0.07, 0.1)
	l.shaded = false
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.position = pos
	l.rotation.y = yaw
	return l


# --- The walk -----------------------------------------------------------------------------------------

func _build_walk() -> void:
	var b := bounds()
	walk.bounds = Rect2(b.position, b.size)
	walk.ground = func(_p: Vector2) -> float: return 0.0
	var o := Vector2(ORIGIN.x, ORIGIN.z)
	# the outer walls
	walk.add_wall(o + Vector2(-8.4, 0.0), o + Vector2(8.4, 0.0), T)
	walk.add_wall(o + Vector2(-8.4, NORTH - 0.1), o + Vector2(8.4, NORTH - 0.1), T)
	walk.add_wall(o + Vector2(-8.3, NORTH), o + Vector2(-8.3, 0.0), T)
	walk.add_wall(o + Vector2(8.3, NORTH), o + Vector2(8.3, 0.0), T)
	# the door out is open: the bounds hold the hero a step inside
	walk.add_wall(o + Vector2(-8.4, -0.1), o + Vector2(-0.9, -0.1), T)
	walk.add_wall(o + Vector2(0.9, -0.1), o + Vector2(8.4, -0.1), T)
	for r in range(1, ROWS):
		var z := -float(r) * PITCH
		walk.add_wall(o + Vector2(-8.4, z), o + Vector2(-HALL_HALF, z), 2.0 * T)
		walk.add_wall(o + Vector2(HALL_HALF, z), o + Vector2(8.4, z), 2.0 * T)
	for id in HouseRooms.ids():
		var d: Dictionary = HouseRooms.ROOMS[id]
		var side := float(d["side"])
		var c := _local_center(id)
		var wx := side * (HALL_HALF + T * 0.5)
		var g0 := c.z + DOOR_DZ - DOOR_W * 0.5
		var g1 := c.z + DOOR_DZ + DOOR_W * 0.5
		walk.add_wall(o + Vector2(wx, c.z - PITCH * 0.5), o + Vector2(wx, g0), T)
		walk.add_wall(o + Vector2(wx, g1), o + Vector2(wx, c.z + PITCH * 0.5), T)
		# the points a route turns at: in the hall by the door, in the doorway, inside
		walk.waypoints.append(o + Vector2(side * 0.9, c.z + DOOR_DZ))
		walk.waypoints.append(o + Vector2(side * (HALL_HALF + T * 0.5), c.z + DOOR_DZ))
		walk.waypoints.append(o + Vector2(side * (HALL_HALF + T + 1.0), c.z + DOOR_DZ))
		walk.waypoints.append(o + Vector2(side * (HALL_HALF + T + 3.0), c.z))
	for r in ROWS:
		walk.waypoints.append(o + Vector2(0.0, FRONT - ROOM * 0.5 - r * PITCH))
	# the plants at the door
	for s in [-1.0, 1.0]:
		walk.add_circle(o + Vector2(s * 1.5, -1.0), 0.3)


# --- What the rooms show now ------------------------------------------------------------------------------

## Brings the rooms to what AcademyHouse says: the objects of the built levels, the chalk mark of the
## next one, the scaffolding, the door and the sign. Safe to call again.
func sync() -> void:
	var shut_changed := false
	for id in HouseRooms.ids():
		var r: Dictionary = _rooms[id]
		var open := AcademyHouse.is_open(id)
		if r["open"] != open:
			shut_changed = true
		r["open"] = open
	if shut_changed or _shell.mesh == null:
		_rebuild_shell()
		for id in HouseRooms.ids():
			_door_blocker(id)
	for id in HouseRooms.ids():
		_sync_room(id)


func _door_blocker(id: String) -> void:
	var d: Dictionary = HouseRooms.ROOMS[id]
	var tag := "door_" + id
	walk.clear_tag(tag)
	if bool(_rooms[id]["open"]):
		return
	var side := float(d["side"])
	var c := _local_center(id)
	var o := Vector2(ORIGIN.x, ORIGIN.z)
	var wx := side * (HALL_HALF + T * 0.5)
	walk.add_wall(o + Vector2(wx, c.z + DOOR_DZ - DOOR_W * 0.5), o + Vector2(wx, c.z + DOOR_DZ + DOOR_W * 0.5), T, tag)


func _sync_room(id: String) -> void:
	var r: Dictionary = _rooms[id]
	var d: Dictionary = HouseRooms.ROOMS[id]
	var side := int(d["side"])
	var open: bool = r["open"]
	var lv := AcademyHouse.level(id) if open else 0
	var next := lv + 1 if lv < HouseRooms.MAX_LEVEL and open else 0
	var scaffold := 0
	if open and AcademyHouse.is_building(id):
		scaffold = int(AcademyHouse.building()[id].get("level", 0))
		next = 0
	if int(r["built"]) != lv or int(r["mark"]) != next or int(r["scaffold"]) != scaffold:
		(r["stuff"] as MeshInstance3D).mesh = HouseProps.mesh(id, lv, next, scaffold, side, d["look"]["floor"])
		r["built"] = lv
		r["mark"] = next
		r["scaffold"] = scaffold
		var tag := "obj_" + id
		walk.clear_tag(tag)
		var o := Vector2(ORIGIN.x, ORIGIN.z)
		var c := _local_center(id)
		for s in HouseProps.solids(id, lv):
			var rect := s as Rect2
			var x0 := rect.position.x * side
			var x1 := rect.end.x * side
			walk.add_box(Rect2(o.x + c.x + minf(x0, x1), o.y + c.z + rect.position.y, absf(x1 - x0), rect.size.y).grow(0.04), tag)
	(r["stuff"] as MeshInstance3D).visible = open
	# the sign by the door, on the hall's wall
	var sign := r["sign"] as Label3D
	var c2 := _local_center(id)
	sign.position = Vector3(side * (HALL_HALF - SIGN_W * 0.5), 2.6, c2.z + DOOR_DZ + 0.045)
	sign.rotation.y = 0.0
	var name := HouseRooms.short_of(id)
	sign.width = 200
	if not open:
		sign.text = "%s\nакадемия ур. %d" % [name, HouseRooms.opens(id)]
		sign.modulate = Color("c9c3cf")
		sign.font_size = 28
	elif AcademyHouse.is_building(id):
		var left := AcademyHouse.runs_left(id)
		sign.text = "%s\nстройка · ещё %d" % [name, left] if left > 0 else "%s\nготово" % name
		sign.modulate = UiTheme.GOLD
		sign.font_size = 28
	else:
		sign.text = "%s\n%s" % [name, _dots(lv)]
		sign.modulate = Color.WHITE
		sign.font_size = 34


static func _dots(lv: int) -> String:
	var s := ""
	for i in HouseRooms.MAX_LEVEL:
		s += "●" if i < lv else "○"
	return s


## The hero is in this room ("" = the hall): its front wall steps aside.
func set_inside(id: String) -> void:
	_inside = id
	for rid in _rooms:
		(_rooms[rid]["fade"] as MeshInstance3D).visible = rid != id


func inside() -> String:
	return _inside


## Rooms far from the hero are not drawn (the open ones near him, and the one he is in, are).
func show_near(pos: Vector3) -> void:
	for rid in _rooms:
		var r: Dictionary = _rooms[rid]
		var c := (r["root"] as Node3D).global_position
		var near: bool = rid == _inside or absf(c.z - pos.z) < NEAR
		(r["stuff"] as MeshInstance3D).visible = bool(r["open"]) and near
		(r["fade"] as MeshInstance3D).visible = rid != _inside


func room_node(id: String) -> Node3D:
	return _rooms[id]["root"]


func stuff(id: String) -> MeshInstance3D:
	return _rooms[id]["stuff"]


func sign_of(id: String) -> Label3D:
	return _rooms[id]["sign"]


func fade_of(id: String) -> MeshInstance3D:
	return _rooms[id]["fade"]


## The build moment of a room's new level: its things grow up with a bounce.
func bounce(id: String) -> void:
	var m := stuff(id)
	if _bounce != null and _bounce.is_valid():
		_bounce.kill()
	m.scale = Vector3(1.0, 0.05, 1.0)
	_bounce = create_tween()
	_bounce.tween_property(m, "scale", Vector3(1.0, 1.08, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce.tween_property(m, "scale", Vector3.ONE, 0.2)
