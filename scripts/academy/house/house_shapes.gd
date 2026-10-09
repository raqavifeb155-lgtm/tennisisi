class_name HouseShapes
extends RefCounted
## The Academy house's forms made in code (stream art, docs/academy/ART_BRIEF.md): everything
## the CC0 sets do not have (gym machines, screens, medical couch, trophy cases, the facade...)
## and a simple form of every id the model pack has (HousePack: bed_3, kitchen_2...), so the
## house stands before the pack arrives - or when it never does.
##
## Same interface as ClubShapes: `make(id)` -> an ArrayMesh with the colours in the vertices
## (one surface, no texture; draw it with ClubScenery.prop_material()), metres, standing on
## y = 0, centred on x/z, the front toward +z. Built with the ClubShapes builder (box, cyl,
## ball, flat); a few hundred triangles a thing at most (`HousePack.tris(id)`).
##
## Ids: `<thing>_<n>`: n is the STAGE of the look (1 worn out, 2 plain, 3 good, 4 premium) for
## things that grow with the room (beds, tables, desks, sofas), or the room level the thing
## appears at (tv_1, treadmill_3...). `ids()` lists all of them, `room_of(id)` names the room
## (for the gallery). The club's two blues (CLUB_BLUE, CLUB_DARK) are the only colours
## HousePack.club_mesh swaps for the colour the player chose for the club.
## Wall things (frames, boards, the mirror) hang at their own height: the origin is still the floor.

const CLUB_BLUE := Color("2a54a3")
const CLUB_DARK := Color("1e3a73")
const OAK := Color("d8a373")
const WOODL := Color("c08a55")
const WOODD := Color("6b4a32")
const ESPRESSO := Color("3b2f2a")
const CREAM := Color("f4ead5")
const SAGE := Color("a9c5a0")
const MUSTARD := Color("e8b84a")
const PLUM := Color("6b4b7a")
const TEAL := Color("4a8f87")
const SKY := Color("7fb6d9")
const BLUSH := Color("e9b8a8")
const TERRA := Color("b5654a")
const GOLD := Color("ffd642")
const WHITE := Color("f2f0ea")
const GREY := Color("9e968a")
const METAL := Color("b9bec4")
const METALD := Color("25272b")
const RUST := Color("8c4a2a")
const NAVY := Color("1e2a44")
const CLINIC := Color("dfe6ea")
const RED := Color("d9473b")
const GREEN := Color("3d806a")
const GLASS := Color("8fb8c9")
const SCREEN := Color("8fd3e8")      # a lit screen: bright, no light of its own (the stand may add a glow)
const CHALK := Color("29392f")
const BALL := Color("dff23a")
const NEON := Color("ffe27a")
const DUST := Color(0.56, 0.52, 0.46)
const SKIN := Color("e3b48a")
const BLACKISH := Color("2b2d33")
const SILVER := Color("c9ced4")
const BRONZE := Color("b87a45")

## room -> ids made here (the pack's ids are in HousePackInfo.IDS and have a simple form here too)
const ROOMS := {
	"dorm": ["bed_1", "bed_2", "bed_3", "bed_4", "bunk_2", "nightstand_1", "nightstand_2", "nightstand_3", "wardrobe_2", "curtain_3",
		"partition_5", "nightlight_5", "balcony_5", "rug_a", "lamp_table"],
	"canteen": ["table_1", "table_2", "table_3", "table_4", "chair_1", "chair_2", "chair_3", "chair_4", "bench_1", "fridge_1", "kitchen_2",
		"kitchen_3", "kitchen_4", "kitchen_island_3", "dishes_2", "kettle_2", "serving_3", "fruit_stand_4", "menu_board_4", "chef_5"],
	"gym": ["mat_1", "dumbbells_1", "fitball_1", "pullup_2", "jumprope_2", "ladder_2", "treadmill_3", "rack_4", "mirror_4", "barbell_4",
		"scoreboard_5", "speaker_5", "plyo_5"],
	"video": ["tv_1", "projector_2", "screen_2", "tacticboard_3", "editdesk_4", "cinema_5", "statswall_5"],
	"coach": ["desk_1", "desk_2", "desk_3", "desk_4", "chair_office_1", "modesboard_1", "folders_2", "chartstand_3", "bookcase_4",
		"diplomas_4", "strategymap_5", "cups_5"],
	"med": ["medcouch_1", "firstaid_1", "physiolamp_2", "physio_2", "massage_3", "icebath_4", "spapool_5"],
	"lounge": ["sofa_1", "sofa_2", "sofa_3", "sofa_4", "armchair_2", "armchair_3", "armchair_4", "pingpong_2", "console_3", "pouf_3",
		"library_4", "aquarium_4", "terrace_5", "minibar_5"],
	"hall": ["reception_1", "candidates_1", "sponsor_2", "trophycase_3", "agentdesk_4", "fame_5", "cup_gold", "cup_silver", "cup_bronze"],
	"shell": ["door_a", "door_b", "frame_s", "frame_m", "frame_l", "plant_s", "plant_m", "crate_1", "barrel_1", "chalk_here", "rug_b", "rug_c",
		"lamp_standing", "coffee_2", "radio_1", "bunk_1"],
	"kids": ["kid_stand_a", "kid_stand_b", "kid_stand_c", "kid_sit_a", "kid_sit_b", "kid_sit_c", "kid_eat_a", "kid_eat_b", "kid_eat_c",
		"kid_lie_a", "kid_lie_b", "kid_lie_c", "kid_run_a", "kid_run_b", "kid_run_c"],
	"outside": ["academy_0", "academy_1", "academy_2", "academy_3", "academy_4", "academy_5"],
}

## Small things that make a room cosy and nothing else: the Low preset leaves them out (docs/CLUB_HUB_TZ.md 9:
## "мелочь в комнатах скрыта на Низкой"; the house's room budget there is 3k triangles).
const DECOR := ["dishes_2", "kettle_2", "jumprope_2", "dumbbells_1", "folders_2", "diplomas_4", "cups_5", "fruit_stand_4", "menu_board_4",
	"nightlight_5", "pouf_3", "fitball_1", "lamp_table", "lamp_standing", "plant_s", "plant_m", "frame_s", "frame_m", "frame_l", "radio_1",
	"coffee_2", "barrel_1", "crate_1", "rug_a", "rug_b", "rug_c", "plyo_5", "barbell_4"]

static var _ids: Array = []


static func ids() -> Array:
	if _ids.is_empty():
		for r in ROOMS:
			_ids.append_array(ROOMS[r])
	return _ids


static func room_of(id: String) -> String:
	for r in ROOMS:
		if id in ROOMS[r]:
			return r
	return ""


## The simple form of an id, or null for an id nobody knows.
static func make(id: String) -> ArrayMesh:
	var s := ClubShapes.new()
	var ok := _dorm(id, s) or _canteen(id, s) or _gym(id, s) or _video(id, s) or _coach(id, s) or _med(id, s) \
			or _lounge(id, s) or _hall(id, s) or _shell(id, s) or _outside(id, s) or _kids(id, s)
	return s.build() if ok else null


## The colour of something old: dusty and a little darker (w 0..1).
static func worn(c: Color, w: float) -> Color:
	return c.lerp(DUST, w * 0.55).darkened(0.16 * w)


static func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


## A pillow: a soft flat lump.
static func _pillow(s: ClubShapes, pos: Vector3, col: Color, yaw := 0.0, w := 0.46) -> void:
	s.box(_v(w, 0.09, w * 0.65), pos, col, yaw)
	s.box(_v(w * 0.9, 0.05, w * 0.55), pos + _v(0, 0.06, 0), col.lightened(0.06), yaw)


## A cup (a trophy): base, stem, bowl, two handles.
static func _cup(s: ClubShapes, pos: Vector3, col: Color, k := 1.0) -> void:
	s.box(_v(0.16 * k, 0.04 * k, 0.16 * k), pos + _v(0, 0.02 * k, 0), WOODD)
	s.cyl(0.03 * k, 0.05 * k, 0.1 * k, pos + _v(0, 0.09 * k, 0), col, 5)
	s.cyl(0.1 * k, 0.04 * k, 0.14 * k, pos + _v(0, 0.2 * k, 0), col, 6)
	s.box(_v(0.25 * k, 0.04 * k, 0.03 * k), pos + _v(0, 0.22 * k, 0), col)


## A lamp: base, stem, shade.
static func _lamp(s: ClubShapes, pos: Vector3, h: float, shade: Color) -> void:
	s.cyl(0.08, 0.1, 0.04, pos + _v(0, 0.02, 0), METALD, 8)
	s.cyl(0.015, 0.015, h, pos + _v(0, h * 0.5, 0), METAL, 4)
	s.cyl(0.09, 0.16, 0.18, pos + _v(0, h + 0.04, 0), shade, 8)


# --- dorm ----------------------------------------------------------------------------

static func _bed(s: ClubShapes, st: int) -> void:
	# 1.0 x 1.9, the head toward -z
	match st:
		1:
			for x in [-0.34, 0.0, 0.34]:
				s.box(_v(0.28, 0.1, 1.9), _v(x, 0.07, 0), worn(WOODL, 0.8))
			s.box(_v(0.94, 0.11, 1.84), _v(0, 0.18, 0), worn(CREAM, 0.95))
			s.box(_v(0.96, 0.05, 0.9), _v(0, 0.25, 0.42), Color(0.45, 0.5, 0.42))
			s.box(_v(0.46, 0.07, 0.3), _v(0.02, 0.26, -0.7), worn(WHITE, 0.8), 0.07)
		2:
			for x in [-0.46, 0.46]:
				for z in [-0.9, 0.9]:
					s.box(_v(0.07, 0.3, 0.07), _v(x, 0.15, z), WOODL)
				s.box(_v(0.06, 0.1, 1.9), _v(x, 0.3, 0), WOODL)
			s.box(_v(0.9, 0.14, 1.84), _v(0, 0.4, 0), CREAM)
			s.box(_v(0.94, 0.06, 1.0), _v(0, 0.49, 0.4), SAGE)
			s.box(_v(1.0, 0.55, 0.05), _v(0, 0.5, -0.95), WOODL)
			_pillow(s, _v(0, 0.51, -0.7), WHITE)
		3:
			for x in [-0.48, 0.48]:
				for z in [-0.92, 0.92]:
					s.box(_v(0.08, 0.28, 0.08), _v(x, 0.14, z), OAK)
				s.box(_v(0.06, 0.12, 1.95), _v(x, 0.3, 0), OAK)
			s.box(_v(0.92, 0.18, 1.86), _v(0, 0.4, 0), WHITE)
			s.box(_v(0.96, 0.08, 1.15), _v(0, 0.52, 0.35), CLUB_BLUE)
			s.box(_v(0.96, 0.085, 0.16), _v(0, 0.525, 0.1), CLUB_DARK)
			s.box(_v(1.06, 0.85, 0.06), _v(0, 0.62, -0.98), OAK)
			s.box(_v(1.06, 0.3, 0.06), _v(0, 0.3, 0.98), OAK)
			_pillow(s, _v(-0.22, 0.58, -0.72), CREAM, 0.1, 0.4)
			_pillow(s, _v(0.22, 0.58, -0.72), CREAM, -0.1, 0.4)
		_:
			s.box(_v(1.3, 0.3, 1.96), _v(0, 0.15, 0), ESPRESSO)
			s.box(_v(1.22, 0.22, 1.86), _v(0, 0.41, 0), WHITE)
			s.box(_v(1.26, 0.1, 1.2), _v(0, 0.57, 0.33), PLUM)
			s.box(_v(1.26, 0.11, 0.14), _v(0, 0.575, 0.0), GOLD)
			s.box(_v(1.4, 1.0, 0.09), _v(0, 0.68, -1.0), WOODD)
			s.box(_v(1.4, 0.05, 0.11), _v(0, 1.2, -1.0), GOLD)
			_pillow(s, _v(-0.3, 0.64, -0.72), CREAM, 0.1, 0.5)
			_pillow(s, _v(0.3, 0.64, -0.72), BLUSH, -0.1, 0.5)


static func _dorm(id: String, s: ClubShapes) -> bool:
	match id:
		"bed_1", "bed_2", "bed_3", "bed_4":
			_bed(s, int(id.right(1)))
		"bunk_2":
			for x in [-0.5, 0.5]:
				for z in [-0.92, 0.92]:
					s.box(_v(0.08, 1.9, 0.08), _v(x, 0.95, z), WOODD)
			for y in [0.35, 1.3]:
				s.box(_v(0.96, 0.12, 1.84), _v(0, y, 0), CREAM)
				s.box(_v(0.98, 0.06, 0.9), _v(0, y + 0.08, 0.4), SKY if y < 1.0 else SAGE)
				s.box(_v(0.94, 0.05, 0.05), _v(0, y + 0.2, 0.9), WOODL)
				_pillow(s, _v(0, y + 0.1, -0.7), WHITE, 0.0, 0.4)
			s.box(_v(0.05, 1.0, 0.05), _v(0.53, 0.8, 0.5), WOODL)
			for k in 4:
				s.box(_v(0.05, 0.04, 0.4), _v(0.53, 0.2 + k * 0.28, 0.5), WOODL)
		"nightstand_1":
			s.box(_v(0.5, 0.4, 0.4), _v(0, 0.2, 0), worn(WOODL, 0.8))
			s.box(_v(0.5, 0.03, 0.4), _v(0, 0.415, 0), worn(WOODD, 0.8))
			s.box(_v(0.36, 0.14, 0.02), _v(0, 0.3, 0.2), worn(WOODD, 0.8))
		"nightstand_2", "nightstand_3":
			s.box(_v(0.5, 0.52, 0.45), _v(0, 0.28, 0), WOODL if id == "nightstand_2" else OAK)
			s.box(_v(0.54, 0.04, 0.5), _v(0, 0.56, 0), WOODD)
			for y in [0.18, 0.4]:
				s.box(_v(0.4, 0.17, 0.02), _v(0, y, 0.23), WOODD)
				s.box(_v(0.1, 0.02, 0.03), _v(0, y, 0.25), GOLD if id == "nightstand_3" else METAL)
			if id == "nightstand_3":
				_lamp(s, _v(-0.1, 0.58, 0), 0.3, CREAM)
				s.box(_v(0.2, 0.05, 0.14), _v(0.12, 0.61, 0.05), TERRA, 0.3)
		"wardrobe_2":
			s.box(_v(1.0, 1.9, 0.55), _v(0, 0.95, 0), WOODL)
			s.box(_v(1.06, 0.05, 0.6), _v(0, 1.92, 0), WOODD)
			for x in [-0.25, 0.25]:
				s.box(_v(0.44, 1.7, 0.02), _v(x, 0.95, 0.28), WOODD)
				s.box(_v(0.03, 0.2, 0.04), _v(x * 0.4, 1.0, 0.3), METAL)
			s.box(_v(0.9, 0.05, 0.5), _v(0, 0.03, 0), WOODD)
		"curtain_3":
			s.cyl(0.02, 0.02, 1.9, _v(0, 2.3, 0.0), WOODD, 4, _v(0, 0, PI * 0.5))
			for x in [-0.78, 0.78]:
				s.box(_v(0.5, 1.8, 0.07), _v(x, 1.4, 0.02), CLUB_BLUE)
				s.box(_v(0.12, 1.8, 0.09), _v(x * 0.8, 1.4, 0.03), CLUB_DARK)
			s.box(_v(0.18, 0.05, 0.1), _v(-0.56, 1.0, 0.03), GOLD)
			s.box(_v(0.18, 0.05, 0.1), _v(0.56, 1.0, 0.03), GOLD)
		"partition_5":
			# a low wooden screen between two beds (along x)
			s.box(_v(2.0, 0.06, 0.08), _v(0, 1.3, 0), WOODD)
			s.box(_v(2.0, 0.06, 0.08), _v(0, 0.3, 0), WOODD)
			for k in 11:
				s.box(_v(0.1, 1.0, 0.04), _v(-0.9 + k * 0.18, 0.8, 0), OAK)
			s.box(_v(2.0, 0.22, 0.05), _v(0, 1.05, 0.02), CLUB_BLUE)
			for x in [-1.0, 1.0]:
				s.box(_v(0.08, 1.4, 0.2), _v(x, 0.7, 0), WOODD)
		"nightlight_5":
			s.cyl(0.14, 0.17, 0.04, _v(0, 0.02, 0), WOODD, 8)
			s.cyl(0.03, 0.03, 0.3, _v(0, 0.19, 0), WOODL, 5)
			s.ball(0.13, _v(0, 0.42, 0), NEON, _v(1, 1, 1), 8, 5)
			s.ball(0.04, _v(0.07, 0.46, 0.1), GOLD, _v(1, 1, 1), 4, 3)
		"balcony_5":
			s.box(_v(3.2, 0.12, 1.3), _v(0, 0.06, 0), OAK)
			for k in 7:
				s.box(_v(0.02, 0.13, 1.3), _v(-1.5 + k * 0.5, 0.06, 0), WOODL)
			for x in [-1.55, -0.52, 0.52, 1.55]:
				s.box(_v(0.06, 1.0, 0.06), _v(x, 0.62, 0.62), METALD)
			s.box(_v(3.2, 0.06, 0.07), _v(0, 1.12, 0.62), METALD)
			s.box(_v(3.2, 0.04, 0.05), _v(0, 0.6, 0.62), METALD)
			for z in [-0.3, 0.3]:
				s.box(_v(0.06, 1.0, 0.06), _v(-1.55, 0.62, z), METALD)
				s.box(_v(0.06, 1.0, 0.06), _v(1.55, 0.62, z), METALD)
			s.box(_v(0.07, 0.06, 1.24), _v(-1.55, 1.12, 0), METALD)
			s.box(_v(0.07, 0.06, 1.24), _v(1.55, 1.12, 0), METALD)
			for x in [-1.0, 1.1]:
				s.cyl(0.17, 0.12, 0.28, _v(x, 0.26, 0.4), TERRA, 7)
				s.ball(0.2, _v(x, 0.5, 0.4), Color("4d7a33"), _v(1, 0.8, 1), 6, 4)
		"rug_a":
			s.flat(Vector2(0.75, 0.5), _v(0, 0.03, 0), CLUB_BLUE, 12)
			s.flat(Vector2(0.55, 0.35), _v(0, 0.04, 0), MUSTARD, 12)
			s.flat(Vector2(0.3, 0.18), _v(0, 0.05, 0), CLUB_BLUE, 10)
		"lamp_table":
			_lamp(s, _v(0, 0, 0), 0.25, CREAM)
		"rug_b", "rug_c":
			s.box(_v(1.5, 0.03, 1.0), _v(0, 0.015, 0), CLUB_BLUE if id == "rug_b" else PLUM)
			s.box(_v(1.3, 0.035, 0.8), _v(0, 0.017, 0), CREAM if id == "rug_b" else GOLD)
			s.box(_v(1.2, 0.04, 0.7), _v(0, 0.02, 0), CLUB_BLUE if id == "rug_b" else PLUM)
		"lamp_standing":
			_lamp(s, _v(0, 0, 0), 1.4, CREAM)
		_:
			return false
	return true


# --- canteen -------------------------------------------------------------------------

static func _table(s: ClubShapes, st: int) -> void:
	# 2.1 x 0.9 x 0.74
	var top: Color = [worn(WOODL, 0.8), WOODL, OAK, WOODD][st - 1]
	var leg: Color = [worn(WOODD, 0.8), WOODD, WOODL, ESPRESSO][st - 1]
	s.box(_v(2.1, 0.07, 0.9), _v(0, 0.71, 0), top)
	for x in [-0.95, 0.95]:
		for z in [-0.35, 0.35]:
			s.box(_v(0.08, 0.68, 0.08), _v(x, 0.34, z), leg)
	if st == 1:
		s.box(_v(0.05, 0.05, 0.9), _v(0.0, 0.8, 0.0), Color(0.5, 0.35, 0.25), 0.0, _v(0, 0, 0.3))   # a plank patch
		s.box(_v(0.6, 0.015, 0.02), _v(-0.5, 0.75, 0.1), Color("5e5a54"), 0.2)                      # a crack
	if st >= 3:
		s.box(_v(1.9, 0.05, 0.05), _v(0, 0.55, 0), leg)
	if st == 4:
		s.box(_v(2.2, 0.025, 1.0), _v(0, 0.755, 0), CREAM)
		s.box(_v(2.2, 0.22, 0.02), _v(0, 0.64, 0.5), CREAM)
		s.box(_v(0.4, 0.03, 1.02), _v(0, 0.77, 0), CLUB_BLUE)
		_cup(s, _v(0.0, 0.78, 0), GOLD, 0.8)


static func _chair(s: ClubShapes, st: int) -> void:
	if st == 1:
		s.box(_v(0.38, 0.38, 0.38), _v(0, 0.19, 0), worn(Color("c9a56b"), 0.7))
		s.box(_v(0.4, 0.03, 0.4), _v(0, 0.39, 0), worn(WOODL, 0.7))
		return
	var wood: Color = [WOODL, WOODL, OAK, WOODD][st - 1]
	var pad: Color = [SAGE, SAGE, CLUB_BLUE, PLUM][st - 1]
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.19]:
			s.box(_v(0.05, 0.42, 0.05), _v(x, 0.21, z), GOLD if st == 4 else wood)
	s.box(_v(0.46, 0.05, 0.46), _v(0, 0.44, 0), wood)
	if st >= 3:
		s.box(_v(0.4, 0.07, 0.4), _v(0, 0.5, 0.0), pad)
	s.box(_v(0.46, 0.42, 0.05), _v(0, 0.74, -0.2), wood if st < 3 else pad)
	if st == 2:
		s.box(_v(0.4, 0.1, 0.04), _v(0, 0.8, -0.2), wood.darkened(0.15))


static func _counter_run(s: ClubShapes, st: int) -> void:
	# along x, the back toward -z, 0.65 deep; st 2: 3.4 m, 3: 4.2 m, 4: 4.4 m
	var n := 3 if st == 2 else 4
	var body: Color = [WOODL, OAK, WOODD][st - 2]
	var top: Color = [CREAM, WHITE, CLINIC][st - 2]
	var w := n * 1.0
	var x0 := -(w + 0.8) * 0.5
	s.box(_v(w, 0.82, 0.62), _v(x0 + w * 0.5 + 0.8, 0.45, 0), body)
	s.box(_v(w + 0.04, 0.05, 0.68), _v(x0 + w * 0.5 + 0.8, 0.9, 0), top)
	for k in n:
		var cx := x0 + 0.8 + 0.5 + k
		s.box(_v(0.9, 0.62, 0.02), _v(cx, 0.45, 0.32), body.darkened(0.12))
		s.box(_v(0.12, 0.02, 0.03), _v(cx, 0.7, 0.34), GOLD if st == 4 else METAL)
	# sink (dark inset + tap), hotplates
	var sx := x0 + 0.8 + 1.5
	s.box(_v(0.6, 0.02, 0.4), _v(sx, 0.925, 0.0), METAL)
	s.cyl(0.015, 0.015, 0.3, _v(sx, 1.05, -0.2), METAL, 4)
	s.box(_v(0.03, 0.03, 0.14), _v(sx, 1.2, -0.13), METAL)
	var hx := x0 + 0.8 + (2.5 if n == 3 else 3.5)
	for dx in [-0.17, 0.17]:
		for dz in [-0.12, 0.12]:
			s.cyl(0.08, 0.08, 0.02, _v(hx + dx, 0.93, dz), METALD, 8)
	s.box(_v(0.85, 0.06, 0.02), _v(hx, 0.78, 0.33), METALD)
	# the fridge at the left end
	var fh := 1.7 if st == 2 else (1.85 if st == 3 else 1.95)
	var fc: Color = [SAGE, CLUB_BLUE, WHITE][st - 2]
	s.box(_v(0.8, fh, 0.66), _v(x0 + 0.4, fh * 0.5, 0), fc)
	s.box(_v(0.8, 0.03, 0.02), _v(x0 + 0.4, fh * 0.62, 0.34), METALD)
	s.box(_v(0.04, 0.5, 0.04), _v(x0 + 0.68, fh * 0.45, 0.36), METAL)
	s.box(_v(0.04, 0.3, 0.04), _v(x0 + 0.68, fh * 0.8, 0.36), METAL)
	if st >= 3:
		# the hood over the plates and a splashback
		s.box(_v(w - 0.1, 0.5, 0.03), _v(x0 + 0.8 + w * 0.5, 1.2, -0.31), top.darkened(0.04))
		s.box(_v(0.9, 0.08, 0.5), _v(hx, 1.75, -0.1), METAL if st == 3 else GOLD)
		s.box(_v(0.4, 0.4, 0.3), _v(hx, 2.05, -0.2), METAL if st == 3 else GOLD)


static func _canteen(id: String, s: ClubShapes) -> bool:
	match id:
		"table_1", "table_2", "table_3", "table_4":
			_table(s, int(id.right(1)))
		"chair_1", "chair_2", "chair_3", "chair_4":
			_chair(s, int(id.right(1)))
		"bench_1":
			s.box(_v(1.9, 0.06, 0.32), _v(0, 0.44, 0), worn(WOODL, 0.8))
			for x in [-0.8, 0.8]:
				s.box(_v(0.07, 0.42, 0.28), _v(x, 0.21, 0), worn(WOODD, 0.8))
		"fridge_1":
			s.box(_v(0.72, 1.45, 0.66), _v(0, 0.73, 0), worn(WHITE, 0.9))
			s.box(_v(0.72, 0.03, 0.02), _v(0, 1.05, 0.34), worn(METALD, 0.5))
			s.box(_v(0.04, 0.34, 0.05), _v(0.28, 1.25, 0.36), METAL)
			s.box(_v(0.04, 0.4, 0.05), _v(0.28, 0.78, 0.36), METAL)
			s.box(_v(0.18, 0.3, 0.02), _v(-0.18, 0.5, 0.34), RUST)
			s.box(_v(0.3, 0.02, 0.02), _v(0.0, 1.43, 0.34), RUST)
		"kitchen_2":
			_counter_run(s, 2)
		"kitchen_3":
			_counter_run(s, 3)
		"kitchen_4":
			_counter_run(s, 4)
			s.box(_v(4.0, 0.5, 0.34), _v(0.4, 1.95, -0.16), WOODD)       # wall cabinets
			for k in 4:
				s.box(_v(0.9, 0.42, 0.02), _v(-1.1 + k * 1.0, 1.95, 0.02), WOODD.lightened(0.06))
				s.box(_v(0.1, 0.02, 0.03), _v(-1.1 + k * 1.0, 1.8, 0.04), GOLD)
		"kitchen_island_3":
			s.box(_v(2.0, 0.86, 0.9), _v(0, 0.43, 0), OAK)
			s.box(_v(2.1, 0.06, 1.0), _v(0, 0.89, 0), WHITE)
			for k in 3:
				s.box(_v(0.55, 0.6, 0.02), _v(-0.65 + k * 0.65, 0.43, 0.46), OAK.darkened(0.12))
			s.cyl(0.14, 0.1, 0.1, _v(0.4, 0.97, 0.1), TERRA, 8)
			s.ball(0.1, _v(0.4, 1.06, 0.1), RED, _v(1, 1, 1), 6, 4)
			s.box(_v(0.4, 0.03, 0.3), _v(-0.5, 0.94, 0.0), WOODL)
		"dishes_2":
			for k in 3:
				s.cyl(0.14, 0.12, 0.02, _v(-0.3, 0.02 + k * 0.025, 0.1), WHITE, 8)
			s.cyl(0.1, 0.1, 0.02, _v(0.0, 0.02, 0.1), WHITE, 8)
			s.cyl(0.12, 0.09, 0.08, _v(-0.1, 0.05, -0.3), CLUB_BLUE, 8)
			s.cyl(0.1, 0.1, 0.12, _v(0.4, 0.07, -0.1), METAL, 8)
			s.box(_v(0.14, 0.02, 0.02), _v(0.53, 0.14, -0.1), METALD)
		"kettle_2":
			s.cyl(0.1, 0.13, 0.18, _v(0, 0.09, 0), CLUB_BLUE, 8)
			s.ball(0.08, _v(0, 0.2, 0), CLUB_BLUE, _v(1, 0.5, 1), 6, 3)
			s.box(_v(0.18, 0.03, 0.03), _v(0.14, 0.14, 0), METAL, 0.0, _v(0, 0, -0.4))
			s.box(_v(0.03, 0.18, 0.03), _v(-0.12, 0.2, 0), METALD)
			s.ball(0.025, _v(0, 0.26, 0), METALD, _v(1, 1, 1), 4, 3)
		"serving_3":
			s.box(_v(2.2, 0.92, 0.6), _v(0, 0.46, 0), WOODL)
			s.box(_v(2.3, 0.06, 0.7), _v(0, 0.95, 0), CLUB_BLUE)
			s.box(_v(2.3, 0.04, 0.2), _v(0, 0.82, 0.4), METAL)                         # tray rail
			for x in [-1.05, 1.05]:
				s.box(_v(0.04, 0.5, 0.04), _v(x, 1.25, -0.1), METAL)
			s.box(_v(2.15, 0.04, 0.4), _v(0, 1.52, -0.12), METAL)                      # the sneeze guard's top
			for k in 3:
				s.cyl(0.18, 0.15, 0.03, _v(-0.7 + k * 0.7, 0.99, 0.1), WHITE, 8)
				s.ball(0.09, _v(-0.7 + k * 0.7, 1.05, 0.1), [RED, MUSTARD, Color("668f3b")][k], _v(1, 0.7, 1), 6, 3)
		"fruit_stand_4":
			s.box(_v(1.3, 0.55, 0.6), _v(0, 0.28, 0), WOODL)
			s.box(_v(1.1, 0.4, 0.5), _v(0, 0.75, -0.04), WOODL.lightened(0.05))
			s.box(_v(0.8, 0.3, 0.4), _v(0, 1.1, -0.08), WOODL.lightened(0.1))
			var fr := [RED, MUSTARD, Color("668f3b"), Color("f08a3c")]
			for k in 14:
				var row := 0 if k < 6 else (1 if k < 11 else 2)
				var n: int = [6, 5, 3][row]
				var i := k if row == 0 else (k - 6 if row == 1 else k - 11)
				s.ball(0.085, _v(-0.5 + i * (1.0 / maxf(n - 1, 1)) + (0.05 if row == 1 else 0.0), [0.6, 1.0, 1.32][row], [0.12, 0.08, 0.04][row]), fr[(k + row) % 4], _v(1, 0.9, 1), 5, 3)
		"menu_board_4":
			s.box(_v(0.06, 1.3, 0.06), _v(-0.4, 0.65, -0.12), WOODD, 0.0, _v(0.15, 0, 0))
			s.box(_v(0.06, 1.3, 0.06), _v(0.4, 0.65, -0.12), WOODD, 0.0, _v(0.15, 0, 0))
			s.box(_v(0.06, 1.2, 0.06), _v(0, 0.6, -0.4), WOODD, 0.0, _v(-0.35, 0, 0))
			s.box(_v(0.95, 0.85, 0.05), _v(0, 1.0, 0.0), CHALK, 0.0, _v(-0.15, 0, 0))
			s.box(_v(1.0, 0.04, 0.07), _v(0, 0.58, 0.07), WOODD)
			for k in 4:
				s.box(_v(0.6 - 0.1 * (k % 2), 0.025, 0.01), _v(0, 1.25 - k * 0.15, 0.04), WHITE, 0.0, _v(-0.15, 0, 0))
			s.ball(0.07, _v(-0.32, 1.28, 0.05), RED, _v(1, 1, 0.3), 5, 3)
		"chef_5":
			for x in [-0.1, 0.1]:
				s.cyl(0.085, 0.07, 0.8, _v(x, 0.4, 0), NAVY, 5)
				s.box(_v(0.12, 0.07, 0.22), _v(x, 0.04, 0.05), METALD)
			s.ball(0.25, _v(0, 1.17, 0), WHITE, _v(1.0, 1.3, 0.72), 6, 3)
			for k in 3:
				s.ball(0.025, _v(-0.08 + k * 0.08, 1.18, 0.17), CLUB_BLUE, _v(1, 1, 0.4), 4, 3)
			s.cyl(0.055, 0.05, 0.5, _v(-0.29, 1.1, 0.0), WHITE, 4)
			s.cyl(0.055, 0.05, 0.4, _v(0.28, 1.2, 0.15), WHITE, 4, _v(0.9, 0, 0))
			s.cyl(0.015, 0.015, 0.3, _v(0.28, 1.42, 0.35), METAL, 4, _v(1.5, 0, 0))
			s.ball(0.05, _v(0.28, 1.42, 0.5), METAL, _v(1, 0.5, 1), 5, 3)
			s.ball(0.15, _v(0, 1.68, 0), SKIN, _v(1, 1.1, 1), 6, 3)
			s.cyl(0.19, 0.16, 0.12, _v(0, 1.86, 0), WHITE, 8)
			s.ball(0.2, _v(0, 2.0, 0), WHITE, _v(1, 0.8, 1), 6, 3)
			s.box(_v(0.16, 0.035, 0.03), _v(0, 1.62, 0.15), Color("3b2a1e"))
		_:
			return false
	return true


# --- gym -----------------------------------------------------------------------------

## A dumbbell lying along x: handle and two heads.
static func _dumbbell(s: ClubShapes, pos: Vector3, col: Color, k := 1.0, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	s.cyl(0.02 * k, 0.02 * k, 0.26 * k, pos, METAL, 5, _v(0, yaw, PI * 0.5))
	for sx in [-1.0, 1.0]:
		s.cyl(0.07 * k, 0.07 * k, 0.07 * k, pos + b * _v(sx * 0.14 * k, 0, 0), col, 6, _v(0, yaw, PI * 0.5))


static func _gym(id: String, s: ClubShapes) -> bool:
	match id:
		"mat_1":
			s.box(_v(0.7, 0.04, 1.8), _v(0, 0.02, 0), worn(TEAL, 0.7))
			s.box(_v(0.7, 0.045, 0.08), _v(0, 0.022, 0.5), worn(CREAM, 0.7))
			s.box(_v(0.3, 0.045, 0.3), _v(0.12, 0.022, -0.4), Color("5e5a54"), 0.3)      # a stain
		"dumbbells_1":
			var cols := [RED, CLUB_BLUE, BLACKISH, RED, CLUB_BLUE, BLACKISH]
			for k in 6:
				_dumbbell(s, _v(-0.3 + (k % 3) * 0.3, 0.07, -0.15 + (k / 3) * 0.3), worn(cols[k], 0.5), 0.8 + 0.12 * (k % 3), 0.15 * k)
		"fitball_1":
			s.ball(0.33, _v(-0.25, 0.3, 0), worn(TEAL, 0.5), _v(1, 0.94, 1), 9, 6)
			s.ball(0.3, _v(0.45, 0.28, 0.2), worn(TERRA, 0.5), _v(1, 0.94, 1), 9, 6)
		"pullup_2":
			for x in [-0.55, 0.55]:
				s.box(_v(0.08, 2.3, 0.08), _v(x, 1.15, 0), METALD)
				s.box(_v(0.1, 0.06, 0.9), _v(x, 0.03, 0), METALD)
			s.cyl(0.025, 0.025, 1.2, _v(0, 2.2, 0), METAL, 6, _v(0, 0, PI * 0.5))
			s.cyl(0.025, 0.025, 0.7, _v(0, 1.8, 0.2), METAL, 6, _v(0, 0, PI * 0.5))
			s.box(_v(1.2, 0.05, 0.05), _v(0, 0.2, -0.4), METALD)
		"jumprope_2":
			s.box(_v(1.0, 0.1, 0.04), _v(0, 1.5, 0), WOODD)
			for k in 3:
				var x := -0.3 + k * 0.3
				s.cyl(0.02, 0.02, 0.06, _v(x, 1.45, 0.06), METAL, 4, _v(PI * 0.5, 0, 0))
				for j in 8:
					var a := TAU * j / 8.0
					s.box(_v(0.03, 0.03, 0.09), _v(x + cos(a) * 0.12, 1.2 + sin(a) * 0.12, 0.08), [RED, MUSTARD, CLUB_BLUE][k], 0.0, _v(0, 0, a))
		"ladder_2":
			for x in [-0.27, 0.27]:
				s.box(_v(0.04, 0.012, 3.4), _v(x, 0.006, 0), MUSTARD)
			for k in 9:
				s.box(_v(0.54, 0.012, 0.04), _v(0, 0.006, -1.6 + k * 0.4), MUSTARD)
		"treadmill_3":
			s.box(_v(0.82, 0.2, 1.8), _v(0, 0.16, 0.0), METALD)
			s.box(_v(0.62, 0.04, 1.5), _v(0, 0.27, 0.0), Color("3a3f47"))
			for k in 6:
				s.box(_v(0.6, 0.005, 0.03), _v(0, 0.295, -0.6 + k * 0.24), Color("2b2d33"))
			for x in [-0.4, 0.4]:
				s.box(_v(0.06, 1.15, 0.06), _v(x, 0.7, -0.78), METALD)
				s.box(_v(0.04, 0.04, 0.7), _v(x, 1.05, -0.45), METAL)
			s.box(_v(0.82, 0.3, 0.18), _v(0, 1.15, -0.78), CLUB_BLUE, 0.0, _v(-0.35, 0, 0))
			s.box(_v(0.6, 0.18, 0.02), _v(0, 1.16, -0.7), SCREEN, 0.0, _v(-0.35, 0, 0))
			s.box(_v(0.9, 0.06, 0.1), _v(0, 0.04, 0.9), METALD)
		"rack_4":
			s.box(_v(2.1, 0.05, 1.6), _v(0, 0.025, 0), Color("2b2d33"))
			for x in [-0.9, 0.9]:
				for z in [-0.55, 0.55]:
					s.box(_v(0.09, 2.3, 0.09), _v(x, 1.2, z), RED if x > 0 else CLUB_BLUE)
				s.box(_v(0.07, 0.07, 1.1), _v(x, 2.2, 0), METALD)
				s.box(_v(0.12, 0.05, 0.12), _v(x, 1.3, 0.0), METALD)
			s.box(_v(1.9, 0.08, 0.08), _v(0, 2.25, -0.55), METALD)
			s.cyl(0.02, 0.02, 2.2, _v(0, 1.4, 0.0), METAL, 6, _v(0, 0, PI * 0.5))
			for sx in [-1.0, 1.0]:
				s.cyl(0.24, 0.24, 0.05, _v(sx * 0.82, 1.4, 0.0), METALD, 10, _v(0, 0, PI * 0.5))
				s.cyl(0.19, 0.19, 0.05, _v(sx * 0.88, 1.4, 0.0), RED, 10, _v(0, 0, PI * 0.5))
			s.box(_v(0.35, 0.4, 1.2), _v(0, 0.22, 0.0), METALD)
			s.box(_v(0.34, 0.08, 1.15), _v(0, 0.46, 0.0), RED)
		"mirror_4":
			s.box(_v(3.0, 1.9, 0.06), _v(0, 1.45, 0), METALD)
			s.box(_v(2.9, 1.8, 0.02), _v(0, 1.45, 0.035), GLASS.lightened(0.15))
			for k in 3:
				s.box(_v(0.12, 1.9, 0.01), _v(-0.8 + k * 0.7, 1.45, 0.05), WHITE.darkened(0.04), 0.0, _v(0, 0, 0.4))
		"barbell_4":
			s.cyl(0.02, 0.02, 2.0, _v(0, 0.08, 0.0), METAL, 6, _v(0, 0, PI * 0.5))
			for sx in [-1.0, 1.0]:
				for k in 2:
					s.cyl(0.2 - 0.04 * k, 0.2 - 0.04 * k, 0.05, _v(sx * (0.8 + 0.06 * k), 0.2 - 0.04 * k * 0.0, 0.0), [RED, MUSTARD][k], 10, _v(0, 0, PI * 0.5))
			s.box(_v(0.5, 0.06, 0.4), _v(0.0, 0.03, 0.4), METALD)
		"scoreboard_5":
			s.box(_v(2.6, 0.9, 0.14), _v(0, 2.1, 0), METALD)
			s.box(_v(2.7, 0.06, 0.16), _v(0, 2.58, 0), CLUB_BLUE)
			s.box(_v(2.7, 0.06, 0.16), _v(0, 1.62, 0), CLUB_BLUE)
			s.box(_v(2.4, 0.7, 0.02), _v(0, 2.1, 0.08), Color("101114"))
			for k in 4:
				s.box(_v(0.34, 0.5, 0.02), _v(-0.9 + k * 0.6, 2.1, 0.1), NEON)
				s.box(_v(0.14, 0.12, 0.02), _v(-0.9 + k * 0.6, 2.1 + (0.12 if k % 2 == 0 else -0.12), 0.115), Color("101114"))
			s.box(_v(0.05, 0.4, 0.05), _v(-1.2, 1.4, 0.0), METALD)
			s.box(_v(0.05, 0.4, 0.05), _v(1.2, 1.4, 0.0), METALD)
		"speaker_5":
			for x in [-0.45, 0.45]:
				s.box(_v(0.5, 1.15, 0.42), _v(x, 0.58, 0), METALD)
				s.cyl(0.16, 0.14, 0.04, _v(x, 0.85, 0.22), CLUB_DARK, 10, _v(PI * 0.5, 0, 0))
				s.cyl(0.1, 0.08, 0.04, _v(x, 1.0 - 0.45, 0.22), METAL, 8, _v(PI * 0.5, 0, 0))
				s.cyl(0.06, 0.06, 0.04, _v(x, 1.05, 0.22), METAL, 8, _v(PI * 0.5, 0, 0))
				s.box(_v(0.5, 0.04, 0.44), _v(x, 1.17, 0), NEON)
			s.box(_v(0.7, 0.5, 0.5), _v(0, 0.25, 0.5), METALD)
			s.cyl(0.2, 0.18, 0.04, _v(0, 0.28, 0.76), CLUB_BLUE, 10, _v(PI * 0.5, 0, 0))
		"plyo_5":
			for k in 3:
				var h := 0.5 + 0.15 * k
				s.box(_v(0.6, h, 0.5), _v(-0.7 + k * 0.7, h * 0.5, 0), WOODL)
				s.box(_v(0.62, 0.05, 0.52), _v(-0.7 + k * 0.7, h, 0), WOODD)
				s.box(_v(0.64, 0.1, 0.52), _v(-0.7 + k * 0.7, h * 0.5, 0), CLUB_BLUE)
			s.ball(0.16, _v(1.5, 0.16, 0.3), TERRA, _v(1, 1, 1), 7, 4)
			s.ball(0.16, _v(1.3, 0.16, -0.1), CLUB_BLUE, _v(1, 1, 1), 7, 4)
		_:
			return false
	return true


# --- video room ----------------------------------------------------------------------

static func _video(id: String, s: ClubShapes) -> bool:
	match id:
		"tv_1":
			s.box(_v(1.2, 0.5, 0.45), _v(0, 0.25, 0), worn(WOODL, 0.8))
			s.box(_v(1.1, 0.04, 0.4), _v(0, 0.5, 0), worn(WOODD, 0.8))
			s.box(_v(0.8, 0.62, 0.55), _v(0, 0.84, -0.02), worn(Color("6b7f94"), 0.6))                 # CRT body
			s.box(_v(0.58, 0.46, 0.04), _v(-0.06, 0.86, 0.27), Color(0.55, 0.7, 0.62))                  # tube face
			s.box(_v(0.12, 0.4, 0.04), _v(0.31, 0.86, 0.27), METALD)
			s.box(_v(0.5, 0.35, 0.3), _v(0, 0.88, -0.35), worn(Color("6b7f94"), 0.7))
			s.box(_v(0.02, 0.4, 0.02), _v(-0.1, 1.28, -0.2), METAL, 0.0, _v(0, 0, 0.5))
			s.box(_v(0.02, 0.4, 0.02), _v(0.1, 1.28, -0.2), METAL, 0.0, _v(0, 0, -0.5))
		"projector_2":
			s.box(_v(0.7, 0.72, 0.5), _v(0, 0.36, 0), WOODL)
			s.box(_v(0.76, 0.04, 0.56), _v(0, 0.74, 0), WOODD)
			s.box(_v(0.44, 0.16, 0.34), _v(0, 0.84, 0), WHITE)
			s.cyl(0.07, 0.07, 0.1, _v(0, 0.86, -0.22), METALD, 8, _v(PI * 0.5, 0, 0))
			s.ball(0.045, _v(0, 0.86, -0.28), SCREEN, _v(1, 1, 0.4), 5, 3)
			s.box(_v(0.1, 0.02, 0.1), _v(0.12, 0.93, 0.05), CLUB_BLUE)
		"screen_2":
			s.cyl(0.04, 0.04, 2.5, _v(0, 2.45, 0), METALD, 6, _v(0, 0, PI * 0.5))
			s.box(_v(2.3, 1.55, 0.03), _v(0, 1.62, 0.0), WHITE)
			s.box(_v(2.4, 0.04, 0.04), _v(0, 0.82, 0.02), METALD)
			s.box(_v(0.04, 1.55, 0.04), _v(-1.17, 1.62, 0.0), METALD)
			s.box(_v(0.04, 1.55, 0.04), _v(1.17, 1.62, 0.0), METALD)
			s.box(_v(1.4, 0.8, 0.012), _v(0, 1.62, 0.02), SCREEN.darkened(0.1))
			s.box(_v(0.5, 0.03, 0.012), _v(0, 1.02, 0.02), CLUB_BLUE)
		"tacticboard_3":
			for x in [-0.7, 0.7]:
				s.box(_v(0.06, 1.8, 0.06), _v(x, 0.9, -0.1), METAL, 0.0, _v(0.05, 0, 0))
				s.box(_v(0.06, 0.06, 0.7), _v(x, 0.06, 0.0), METALD)
				s.cyl(0.05, 0.05, 0.04, _v(x, 0.03, 0.3), METALD, 6)
				s.cyl(0.05, 0.05, 0.04, _v(x, 0.03, -0.3), METALD, 6)
			s.box(_v(1.8, 1.25, 0.06), _v(0, 1.35, 0.0), METAL)
			s.box(_v(1.7, 1.15, 0.03), _v(0, 1.35, 0.04), WHITE)
			s.box(_v(1.4, 0.8, 0.012), _v(0, 1.35, 0.06), Color("3d806a"))
			s.box(_v(1.4, 0.015, 0.012), _v(0, 1.35, 0.07), WHITE)
			s.box(_v(0.015, 0.8, 0.012), _v(0, 1.35, 0.07), WHITE)
			s.box(_v(0.5, 0.015, 0.012), _v(0.45, 1.5, 0.07), RED, 0.0, _v(0, 0, -0.5))
			var mc := [RED, CLUB_BLUE, RED, CLUB_BLUE, MUSTARD, RED]
			for k in 6:
				s.cyl(0.04, 0.04, 0.02, _v(-0.5 + k * 0.2, 1.2 + (k % 3) * 0.15, 0.08), mc[k], 8, _v(PI * 0.5, 0, 0))
			s.box(_v(1.7, 0.05, 0.12), _v(0, 0.7, 0.07), METAL)
		"editdesk_4":
			s.box(_v(2.4, 0.06, 0.85), _v(0, 0.76, 0), ESPRESSO)
			for x in [-1.1, 1.1]:
				s.box(_v(0.08, 0.74, 0.75), _v(x, 0.37, 0), METALD)
			s.box(_v(2.2, 0.2, 0.6), _v(0, 0.55, 0.0), METALD)
			for x in [-0.55, 0.55]:
				s.box(_v(0.9, 0.52, 0.05), _v(x, 1.2, -0.28), METALD)
				s.box(_v(0.82, 0.44, 0.015), _v(x, 1.2, -0.25), SCREEN)
				s.box(_v(0.05, 0.3, 0.05), _v(x, 0.92, -0.28), METAL)
				s.box(_v(0.3, 0.02, 0.2), _v(x, 0.8, -0.28), METAL)
			s.box(_v(0.7, 0.025, 0.22), _v(-0.3, 0.8, 0.15), WHITE)
			s.box(_v(0.5, 0.05, 0.3), _v(0.45, 0.8, 0.12), METALD)
			for k in 5:
				s.cyl(0.02, 0.02, 0.03, _v(0.3 + k * 0.08, 0.84, 0.12), [RED, MUSTARD, CLUB_BLUE, GOLD, RED][k], 5)
			s.box(_v(0.12, 0.12, 0.12), _v(0.95, 0.85, 0.1), CLUB_BLUE)
			# a chair
			s.cyl(0.25, 0.25, 0.08, _v(0, 0.52, 0.8), CLUB_BLUE, 8)
			s.box(_v(0.46, 0.5, 0.07), _v(0, 0.85, 1.02), CLUB_BLUE)
			s.cyl(0.03, 0.03, 0.3, _v(0, 0.28, 0.8), METALD, 5)
			s.cyl(0.25, 0.22, 0.04, _v(0, 0.04, 0.8), METALD, 5)
		"cinema_5":
			s.box(_v(2.2, 0.22, 1.1), _v(0, 0.11, 0), ESPRESSO)
			for k in 3:
				var x := -0.7 + k * 0.7
				s.box(_v(0.56, 0.26, 0.56), _v(x, 0.35, 0.05), RED)
				s.box(_v(0.56, 0.62, 0.16), _v(x, 0.7, -0.27), RED, 0.0, _v(-0.12, 0, 0))
				s.box(_v(0.16, 0.18, 0.6), _v(x - 0.3, 0.5, 0.05), METALD)
				s.cyl(0.04, 0.03, 0.08, _v(x - 0.3, 0.62, 0.15), METAL, 5)
			s.box(_v(0.16, 0.18, 0.6), _v(1.05, 0.5, 0.05), METALD)
			s.box(_v(2.3, 0.04, 0.06), _v(0, 0.24, 0.58), NEON)
		"statswall_5":
			s.box(_v(3.6, 1.7, 0.1), _v(0, 1.75, 0), METALD)
			s.box(_v(3.7, 0.06, 0.12), _v(0, 2.62, 0), CLUB_BLUE)
			s.box(_v(3.7, 0.06, 0.12), _v(0, 0.9, 0), CLUB_BLUE)
			s.box(_v(3.4, 1.5, 0.02), _v(0, 1.75, 0.06), Color("101114"))
			var hs := [0.5, 0.8, 0.65, 1.1, 0.9, 1.25]
			for k in 6:
				s.box(_v(0.28, hs[k], 0.02), _v(-1.4 + k * 0.32, 1.0 + 0.5 + hs[k] * 0.5 - 0.35, 0.08), [CLUB_BLUE, SCREEN, NEON][k % 3])
			s.box(_v(1.1, 0.5, 0.02), _v(1.1, 2.25, 0.08), SCREEN)
			for k in 4:
				s.box(_v(0.9 - 0.15 * k, 0.04, 0.02), _v(1.1, 1.75 - k * 0.12, 0.08), WHITE)
		_:
			return false
	return true


# --- coach's room --------------------------------------------------------------------

## A flat monitor on a stand (facing +z).
static func _monitor(s: ClubShapes, pos: Vector3, w := 0.5) -> void:
	s.box(_v(w, w * 0.6, 0.04), pos + _v(0, w * 0.3 + 0.12, 0), METALD)
	s.box(_v(w * 0.9, w * 0.52, 0.015), pos + _v(0, w * 0.3 + 0.12, 0.02), SCREEN)
	s.box(_v(0.05, 0.14, 0.05), pos + _v(0, 0.07, 0), METAL)
	s.box(_v(0.2, 0.02, 0.14), pos + _v(0, 0.01, 0), METAL)


## A bookcase: sides, shelves, books in colours (w x h, 0.34 deep).
static func _bookcase(s: ClubShapes, w: float, h: float, wood: Color, books := true) -> void:
	s.box(_v(w, h, 0.03), _v(0, h * 0.5, -0.155), wood.darkened(0.15))
	for x in [-1.0, 1.0]:
		s.box(_v(0.04, h, 0.34), _v(x * (w * 0.5 - 0.02), h * 0.5, 0), wood)
	var n := int(h / 0.42)
	for k in n + 1:
		s.box(_v(w, 0.04, 0.34), _v(0, 0.02 + k * (h - 0.04) / n, 0), wood)
	if not books:
		return
	var cols := [RED, CLUB_BLUE, MUSTARD, TEAL, WHITE, TERRA, PLUM]
	for k in n:
		var x := -w * 0.5 + 0.1
		var j := 0
		while x < w * 0.5 - 0.15:
			var bw := 0.05 + 0.02 * ((j + k) % 3)
			var bh := 0.22 + 0.05 * ((j * 2 + k) % 4)
			s.box(_v(bw, bh, 0.22), _v(x + bw * 0.5, 0.04 + k * (h - 0.04) / n + bh * 0.5 + 0.02, 0.0), cols[(j + k * 3) % cols.size()])
			x += bw + 0.012
			j += 1
			if j % 5 == 4:
				x += 0.14


static func _desk(s: ClubShapes, st: int) -> void:
	# 1.6 x 0.8 (st 1: planks on two crates; 4: a big oak desk 2.0 wide)
	match st:
		1:
			s.box(_v(0.6, 0.55, 0.5), _v(-0.52, 0.27, 0), worn(Color("c9a56b"), 0.8))
			s.box(_v(0.6, 0.55, 0.5), _v(0.52, 0.27, 0), worn(Color("c9a56b"), 0.8))
			s.box(_v(1.7, 0.07, 0.8), _v(0, 0.58, 0), worn(WOODL, 0.8))
			s.box(_v(0.3, 0.02, 0.2), _v(0.3, 0.63, 0.1), CREAM, 0.2)         # a paper
			s.box(_v(0.4, 0.15, 0.02), _v(-0.52, 0.3, 0.26), Color("5e5a54"))
		2:
			s.box(_v(1.6, 0.06, 0.8), _v(0, 0.74, 0), WOODL)
			for x in [-0.72, 0.72]:
				s.box(_v(0.08, 0.72, 0.7), _v(x, 0.36, 0), WOODD)
			s.box(_v(1.4, 0.18, 0.02), _v(0, 0.6, -0.3), WOODD)
			s.box(_v(0.5, 0.04, 0.34), _v(0.1, 0.78, 0.05), METALD)             # a laptop
			s.box(_v(0.46, 0.3, 0.025), _v(0.1, 0.95, -0.1), METALD, 0.0, _v(-0.2, 0, 0))
			s.box(_v(0.42, 0.26, 0.01), _v(0.1, 0.95, -0.085), SCREEN, 0.0, _v(-0.2, 0, 0))
			s.box(_v(0.3, 0.1, 0.4), _v(-0.55, 0.82, 0.0), MUSTARD)               # folders
		3:
			s.box(_v(1.8, 0.06, 0.85), _v(0, 0.75, 0), OAK)
			for x in [-0.82, 0.82]:
				s.box(_v(0.08, 0.72, 0.75), _v(x, 0.36, 0), WOODL)
			s.box(_v(1.6, 0.2, 0.02), _v(0, 0.6, -0.33), WOODL)
			_monitor(s, _v(0.1, 0.78, -0.18), 0.55)
			s.box(_v(0.4, 0.02, 0.14), _v(0.1, 0.79, 0.1), METALD)
			_lamp(s, _v(-0.7, 0.78, -0.2), 0.3, CREAM)
			s.box(_v(0.3, 0.12, 0.4), _v(-0.4, 0.84, 0.1), CLUB_BLUE)
			s.cyl(0.05, 0.04, 0.1, _v(0.7, 0.84, 0.1), RED, 6)
		_:
			s.box(_v(2.1, 0.07, 0.95), _v(0, 0.77, 0), ESPRESSO)
			s.box(_v(2.14, 0.02, 0.99), _v(0, 0.815, 0), WOODD)
			for x in [-0.95, 0.95]:
				s.box(_v(0.5, 0.74, 0.8), _v(x, 0.37, 0), WOODD)
				for y in [0.2, 0.45, 0.65]:
					s.box(_v(0.42, 0.18, 0.02), _v(x, y, 0.41), WOODD.lightened(0.06))
					s.box(_v(0.1, 0.02, 0.03), _v(x, y, 0.43), GOLD)
			_monitor(s, _v(-0.35, 0.82, -0.2), 0.5)
			_monitor(s, _v(0.3, 0.82, -0.2), 0.5)
			s.box(_v(0.5, 0.02, 0.16), _v(0.0, 0.83, 0.12), METALD)
			_lamp(s, _v(-0.85, 0.82, -0.25), 0.34, GOLD)
			_cup(s, _v(0.8, 0.82, 0.05), GOLD, 0.7)
			s.box(_v(0.4, 0.04, 0.22), _v(0.55, 0.83, 0.25), CREAM, 0.2)


static func _coach(id: String, s: ClubShapes) -> bool:
	match id:
		"desk_1", "desk_2", "desk_3", "desk_4":
			_desk(s, int(id.right(1)))
		"chair_office_1":
			s.cyl(0.26, 0.24, 0.04, _v(0, 0.05, 0), worn(METALD, 0.4), 5)
			s.cyl(0.025, 0.025, 0.3, _v(0, 0.22, 0), METAL, 5)
			s.box(_v(0.5, 0.08, 0.48), _v(0, 0.46, 0), worn(RED, 0.7))
			s.box(_v(0.46, 0.5, 0.07), _v(0, 0.78, -0.22), worn(RED, 0.7), 0.0, _v(0.1, 0, 0))
			s.box(_v(0.05, 0.03, 0.3), _v(-0.27, 0.62, 0.0), METALD)
			s.box(_v(0.05, 0.03, 0.3), _v(0.27, 0.62, 0.0), METALD)
		"modesboard_1":
			s.box(_v(1.5, 1.05, 0.05), _v(0, 1.55, 0), WOODD)
			s.box(_v(1.4, 0.95, 0.03), _v(0, 1.55, 0.03), CHALK)
			var cc := [Color("668f3b"), MUSTARD, RED]
			for k in 3:
				s.box(_v(0.38, 0.14, 0.02), _v(-0.45 + k * 0.45, 1.95, 0.05), cc[k])
				s.box(_v(0.3, 0.02, 0.01), _v(-0.45 + k * 0.45, 1.8, 0.05), WHITE)
				s.box(_v(0.22, 0.02, 0.01), _v(-0.45 + k * 0.45, 1.72, 0.05), WHITE)
			s.cyl(0.05, 0.05, 0.03, _v(0.0, 1.45, 0.05), MUSTARD, 8, _v(PI * 0.5, 0, 0))
			s.box(_v(1.2, 0.03, 0.02), _v(0, 1.1, 0.05), WHITE.darkened(0.1))
		"folders_2":
			s.box(_v(0.5, 0.03, 0.34), _v(0, 0.02, 0), WOODD)
			var fc := [CLUB_BLUE, MUSTARD, RED, TEAL]
			for k in 4:
				s.box(_v(0.05, 0.3, 0.26), _v(-0.18 + k * 0.1, 0.18, 0), fc[k], 0.0, _v(0, 0, 0.05 * (k - 1.5)))
		"chartstand_3":
			for k in 3:
				var a := TAU * k / 3.0 + 0.5
				s.box(_v(0.05, 1.5, 0.05), _v(cos(a) * 0.3, 0.72, sin(a) * 0.3 * 0.7), WOODD, 0.0, _v(sin(a) * 0.2, 0, -cos(a) * 0.2))
			s.box(_v(1.2, 1.2, 0.05), _v(0, 1.35, 0), WOODL)
			s.box(_v(1.12, 1.12, 0.02), _v(0, 1.35, 0.03), WHITE)
			s.box(_v(0.02, 0.8, 0.01), _v(-0.4, 1.3, 0.045), METALD)
			s.box(_v(0.85, 0.02, 0.01), _v(0.0, 0.92, 0.045), METALD)
			for k in 5:
				s.box(_v(0.2, 0.025, 0.01), _v(-0.3 + k * 0.17, 1.0 + k * 0.07 + 0.05, 0.05), CLUB_BLUE, 0.0, _v(0, 0, 0.35))
			for k in 4:
				s.box(_v(0.14, 0.14 + k * 0.08, 0.01), _v(-0.28 + k * 0.17, 0.95 + (0.07 + k * 0.04), 0.05), [RED, MUSTARD, TEAL, GOLD][k])
		"bookcase_4":
			_bookcase(s, 1.55, 2.0, WOODD)
		"diplomas_4":
			for k in 3:
				s.box(_v(0.5, 0.4, 0.03), _v(-0.6 + k * 0.6, 1.75, 0), GOLD if k == 1 else WOODD)
				s.box(_v(0.42, 0.32, 0.015), _v(-0.6 + k * 0.6, 1.75, 0.02), CREAM)
				s.box(_v(0.3, 0.025, 0.01), _v(-0.6 + k * 0.6, 1.82, 0.03), GREY)
				s.box(_v(0.22, 0.025, 0.01), _v(-0.6 + k * 0.6, 1.75, 0.03), GREY)
				s.ball(0.045, _v(-0.5 + k * 0.6, 1.65, 0.035), RED, _v(1, 1, 0.3), 5, 3)
		"strategymap_5":
			s.box(_v(2.2, 0.8, 1.4), _v(0, 0.4, 0), ESPRESSO)
			s.box(_v(2.3, 0.06, 1.5), _v(0, 0.83, 0), WOODD)
			s.box(_v(2.1, 0.03, 1.3), _v(0, 0.87, 0), Color("e3d6c3"))
			s.box(_v(1.0, 0.035, 0.6), _v(-0.5, 0.885, -0.2), CLUB_BLUE)
			s.box(_v(0.7, 0.035, 0.5), _v(0.55, 0.885, 0.25), Color("668f3b"))
			s.box(_v(0.5, 0.035, 0.35), _v(0.6, 0.885, -0.35), Color("c58c63"))
			s.box(_v(1.6, 0.04, 0.03), _v(0.0, 0.89, 0.0), Color("b5654a"), 0.4)
			for k in 6:
				s.cyl(0.0, 0.05, 0.14, _v(-0.8 + k * 0.32, 0.98, -0.35 + (k % 3) * 0.3), [RED, GOLD, CLUB_BLUE][k % 3], 5)
			s.ball(0.12, _v(0.1, 1.5, 0.0), WHITE, _v(1, 0.6, 1), 6, 3)       # a lamp over it
			s.cyl(0.01, 0.01, 0.6, _v(0.1, 1.9, 0.0), METALD, 3)
		"cups_5":
			s.box(_v(2.0, 0.05, 0.3), _v(0, 1.5, 0), WOODD)
			s.box(_v(2.0, 0.05, 0.3), _v(0, 2.0, 0), WOODD)
			for x in [-0.9, 0.9]:
				s.box(_v(0.05, 0.6, 0.25), _v(x, 1.75, 0), WOODD)
			var cs := [GOLD, GOLD, SILVER, BRONZE, GOLD]
			for k in 5:
				_cup(s, _v(-0.8 + k * 0.4, 1.525, 0), cs[k], 1.0)
			for k in 3:
				_cup(s, _v(-0.5 + k * 0.5, 2.025, 0), [GOLD, SILVER, GOLD][k], 0.8)
		_:
			return false
	return true


# --- medical room and spa ------------------------------------------------------------

static func _med(id: String, s: ClubShapes) -> bool:
	match id:
		"medcouch_1":
			# a folding cot: two X legs, a thin worn mattress, a folded towel
			for z in [-0.6, 0.6]:
				s.box(_v(0.05, 0.6, 0.05), _v(-0.3, 0.3, z), worn(METAL, 0.5), 0.0, _v(0, 0, 0.45))
				s.box(_v(0.05, 0.6, 0.05), _v(0.3, 0.3, z), worn(METAL, 0.5), 0.0, _v(0, 0, -0.45))
			s.box(_v(0.05, 0.05, 1.9), _v(-0.34, 0.5, 0), worn(METAL, 0.5))
			s.box(_v(0.05, 0.05, 1.9), _v(0.34, 0.5, 0), worn(METAL, 0.5))
			s.box(_v(0.7, 0.07, 1.85), _v(0, 0.55, 0), worn(CLINIC, 0.8))
			s.box(_v(0.4, 0.07, 0.3), _v(0, 0.62, -0.75), worn(WHITE, 0.6))
			s.box(_v(0.3, 0.05, 0.4), _v(0.0, 0.62, 0.5), worn(BLUSH, 0.7))
		"firstaid_1":
			s.box(_v(0.45, 0.35, 0.14), _v(0, 1.5, 0), WHITE)
			s.box(_v(0.28, 0.07, 0.02), _v(0, 1.5, 0.08), RED)
			s.box(_v(0.07, 0.28, 0.02), _v(0, 1.5, 0.08), RED)
			s.box(_v(0.12, 0.04, 0.04), _v(0, 1.68, 0.05), METAL)
		"physiolamp_2":
			s.cyl(0.22, 0.26, 0.05, _v(0, 0.03, 0), METALD, 6)
			s.cyl(0.025, 0.025, 1.5, _v(0, 0.78, 0), METAL, 5)
			s.box(_v(0.03, 0.03, 0.4), _v(0, 1.52, 0.18), METAL)
			s.cyl(0.2, 0.12, 0.22, _v(0, 1.45, 0.4), WHITE, 8, _v(PI * 0.5 + 0.4, 0, 0))
			s.cyl(0.14, 0.14, 0.02, _v(0, 1.37, 0.5), Color("ff8a5a"), 8, _v(PI * 0.5 + 0.4, 0, 0))
		"physio_2":
			s.box(_v(0.7, 0.7, 0.5), _v(0, 0.45, 0), CLINIC)
			for x in [-0.28, 0.28]:
				s.cyl(0.05, 0.05, 0.04, _v(x, 0.05, 0.18), METALD, 6, _v(0, 0, PI * 0.5))
				s.cyl(0.05, 0.05, 0.04, _v(x, 0.05, -0.18), METALD, 6, _v(0, 0, PI * 0.5))
			s.box(_v(0.5, 0.2, 0.34), _v(0, 0.9, 0), WHITE)
			s.box(_v(0.34, 0.14, 0.02), _v(0, 0.96, 0.18), SCREEN)
			for k in 3:
				s.cyl(0.03, 0.03, 0.02, _v(-0.15 + k * 0.15, 0.85, 0.18), [RED, MUSTARD, CLUB_BLUE][k], 6, _v(PI * 0.5, 0, 0))
			s.box(_v(0.5, 0.05, 0.02), _v(0, 0.55, 0.26), TEAL)
			s.box(_v(0.12, 0.08, 0.1), _v(0.4, 0.98, 0.0), CLUB_BLUE)      # a pad on its cable
		"massage_3":
			for x in [-0.28, 0.28]:
				for z in [-0.8, 0.8]:
					s.box(_v(0.06, 0.62, 0.06), _v(x, 0.31, z), WOODL, 0.0, _v(0, 0, -x * 0.5))
			s.box(_v(0.6, 0.05, 1.7), _v(0, 0.3, 0), WOODL)
			s.box(_v(0.78, 0.13, 1.9), _v(0, 0.72, 0), WHITE)
			s.box(_v(0.72, 0.03, 1.8), _v(0, 0.8, 0), Color("dfe6ea"))
			s.box(_v(0.3, 0.14, 0.2), _v(0, 0.78, -0.95), Color("2b2d33"))
			s.box(_v(0.5, 0.1, 0.35), _v(0, 0.86, 0.1), TEAL)                  # a towel
			s.cyl(0.07, 0.07, 0.5, _v(0, 0.9, 0.75), BLUSH, 7, _v(0, 0, PI * 0.5))
		"icebath_4":
			s.box(_v(1.0, 0.75, 1.8), _v(0, 0.38, 0), TEAL)
			s.box(_v(1.04, 0.05, 1.84), _v(0, 0.78, 0), METAL)
			s.box(_v(0.88, 0.03, 1.68), _v(0, 0.77, 0), SKY.lightened(0.1))
			for k in 7:
				s.box(_v(0.16, 0.12, 0.16), _v(-0.28 + (k % 3) * 0.28, 0.84, -0.6 + (k / 3) * 0.55), Color("e8f6fb"), 0.4 * k, _v(0.3 * k, 0, 0.2))
			s.box(_v(0.06, 0.4, 0.06), _v(0.55, 0.3, 0.7), METAL)
			s.box(_v(0.4, 0.04, 0.5), _v(0.0, 0.84, 1.2), WOODL)
			s.box(_v(0.3, 0.3, 0.02), _v(0.0, 1.2, -0.92), WHITE)
			s.box(_v(0.08, 0.2, 0.01), _v(0.0, 1.2, -0.9), RED)
		"spapool_5":
			s.box(_v(3.4, 0.55, 2.6), _v(0, 0.28, 0), WOODL)
			for k in 12:
				s.box(_v(0.02, 0.56, 2.6), _v(-1.65 + k * 0.3, 0.28, 0), WOODD)
			s.box(_v(3.0, 0.06, 2.2), _v(0, 0.56, 0), TEAL)
			s.box(_v(2.6, 0.04, 1.8), _v(0, 0.55, 0), SKY.lightened(0.1))
			for k in 9:
				s.ball(0.07 + 0.02 * (k % 3), _v(-0.9 + (k % 3) * 0.9, 0.62, -0.6 + (k / 3) * 0.6), WHITE, _v(1, 0.5, 1), 5, 3)
			s.box(_v(0.8, 0.3, 0.4), _v(0, 0.15, 1.5), WOODL)
			s.box(_v(0.8, 0.3, 0.4), _v(0, 0.3, 1.2), WOODL)
			s.cyl(0.14, 0.12, 0.2, _v(1.4, 0.7, 1.0), CREAM, 7)
			s.ball(0.04, _v(1.4, 0.84, 1.0), NEON, _v(1, 1.5, 1), 4, 3)
			s.box(_v(0.4, 0.05, 0.7), _v(-1.4, 0.58, 1.1), TERRA)
			s.box(_v(0.4, 0.05, 0.7), _v(-1.4, 0.64, 1.1), CREAM)
		_:
			return false
	return true


# --- lounge --------------------------------------------------------------------------

static func _sofa(s: ClubShapes, st: int, seats := 2) -> void:
	# 2.0 x 0.95 (armchair: 1.1), the back toward -z
	var w := 2.0 if seats == 2 else 1.1
	var col: Color = [Color(0.55, 0.45, 0.35), SAGE, CLUB_BLUE, PLUM][st - 1]
	if st == 1:
		col = worn(col, 0.8)
	s.box(_v(w, 0.3, 0.9), _v(0, 0.28, 0.0), col.darkened(0.1))
	s.box(_v(w - 0.3, 0.14, 0.76), _v(0, 0.5, 0.06), col)
	s.box(_v(w, 0.6, 0.22), _v(0, 0.62, -0.38), col, 0.0, _v(-0.08, 0, 0))
	for x in [-1.0, 1.0]:
		s.box(_v(0.16, 0.5, 0.9), _v(x * (w * 0.5 - 0.08), 0.45, 0.0), col.darkened(0.06))
	if seats == 2:
		s.box(_v(0.02, 0.14, 0.76), _v(0, 0.51, 0.06), col.darkened(0.2))
	if st == 1:
		s.box(_v(0.5, 0.05, 0.4), _v(0.4, 0.58, 0.05), TERRA, 0.2)
		s.box(_v(0.3, 0.02, 0.3), _v(-0.45, 0.58, 0.1), Color("5e5a54"), 0.3)
	elif st >= 3:
		_pillow(s, _v(-0.62 * (w / 2.0), 0.63, -0.1), MUSTARD if st == 3 else GOLD, 0.4, 0.4)
		_pillow(s, _v(0.62 * (w / 2.0), 0.63, -0.1), MUSTARD if st == 3 else BLUSH, -0.4, 0.4)
	if st == 4:
		for x in [-1.0, 1.0]:
			s.cyl(0.04, 0.03, 0.12, _v(x * (w * 0.5 - 0.1), 0.06, 0.38), GOLD, 5)
			s.cyl(0.04, 0.03, 0.12, _v(x * (w * 0.5 - 0.1), 0.06, -0.38), GOLD, 5)


static func _lounge(id: String, s: ClubShapes) -> bool:
	match id:
		"sofa_1", "sofa_2", "sofa_3", "sofa_4":
			_sofa(s, int(id.right(1)))
		"armchair_2", "armchair_3", "armchair_4":
			_sofa(s, int(id.right(1)), 1)
		"pingpong_2":
			# 2.7 x 1.5 (the real table is 2.74 x 1.53), the net across the middle (along x)
			s.box(_v(1.5, 0.05, 2.7), _v(0, 0.74, 0), TEAL)
			for x in [-0.65, 0.65]:
				for z in [-1.15, 1.15]:
					s.box(_v(0.07, 0.72, 0.07), _v(x, 0.36, z), METALD)
				s.box(_v(0.05, 0.05, 2.3), _v(x, 0.5, 0), METALD)
			s.box(_v(1.5, 0.052, 0.025), _v(0, 0.745, 0), WHITE)
			s.box(_v(0.025, 0.052, 2.7), _v(0, 0.745, 0), WHITE)
			s.box(_v(1.5, 0.052, 0.025), _v(0, 0.745, 1.34), WHITE)
			s.box(_v(1.5, 0.052, 0.025), _v(0, 0.745, -1.34), WHITE)
			s.box(_v(1.7, 0.16, 0.025), _v(0, 0.86, 0), WHITE.darkened(0.1))                 # the net
			for x in [-0.8, 0.8]:
				s.box(_v(0.04, 0.2, 0.05), _v(x, 0.86, 0), METALD)
			s.cyl(0.09, 0.09, 0.012, _v(-0.3, 0.775, 0.9), RED, 7)
			s.cyl(0.09, 0.09, 0.012, _v(0.3, 0.775, -0.9), CLUB_BLUE, 7)
			s.ball(0.02, _v(0.1, 0.79, 0.4), WHITE, _v(1, 1, 1), 4, 3)
		"console_3":
			s.box(_v(1.7, 0.45, 0.45), _v(0, 0.23, 0), WOODL)
			s.box(_v(1.76, 0.04, 0.5), _v(0, 0.47, 0), WOODD)
			s.box(_v(1.4, 0.8, 0.06), _v(0, 1.0, -0.05), METALD)
			s.box(_v(1.3, 0.7, 0.015), _v(0, 1.0, -0.015), SCREEN)
			s.box(_v(0.4, 0.06, 0.04), _v(0, 0.55, -0.05), METALD)
			s.box(_v(0.3, 0.06, 0.24), _v(-0.5, 0.52, 0.05), WHITE)
			s.box(_v(0.16, 0.04, 0.1), _v(0.35, 0.51, 0.1), CLUB_BLUE, 0.3)
			s.box(_v(0.16, 0.04, 0.1), _v(0.6, 0.51, 0.1), RED, -0.3)
		"pouf_3":
			var pc := [CLUB_BLUE, MUSTARD, TERRA]
			for k in 3:
				s.ball(0.36, _v(-0.55 + k * 0.6, 0.27, 0.15 * (k % 2)), pc[k], _v(1, 0.78, 1), 8, 5)
				s.ball(0.05, _v(-0.55 + k * 0.6, 0.5, 0.15 * (k % 2)), pc[k].darkened(0.2), _v(1, 0.5, 1), 4, 3)
		"library_4":
			_bookcase(s, 2.4, 2.1, WOODD)
			s.box(_v(0.3, 0.3, 0.2), _v(0.7, 1.26, 0.0), CREAM)       # a globe's stand and ball
			s.ball(0.17, _v(0.7, 1.5, 0.0), SKY, _v(1, 1, 1), 7, 5)
		"aquarium_4":
			s.box(_v(1.5, 0.72, 0.55), _v(0, 0.36, 0), WOODD)
			s.box(_v(1.5, 0.03, 0.55), _v(0, 0.73, 0), METALD)
			s.box(_v(1.4, 0.7, 0.03), _v(0, 1.1, -0.22), SKY.darkened(0.1))        # back (water)
			s.box(_v(1.4, 0.04, 0.46), _v(0, 0.77, 0), Color("d2b48c"))              # sand
			for x in [-0.7, 0.7]:
				s.box(_v(0.04, 0.7, 0.46), _v(x, 1.1, 0), SKY.darkened(0.05))
			s.box(_v(1.5, 0.04, 0.55), _v(0, 1.47, 0), METALD)
			s.box(_v(1.0, 0.03, 0.2), _v(0, 1.44, 0.1), NEON)
			var fc := [Color("f08a3c"), CLUB_BLUE, GOLD, Color("f08a3c")]
			for k in 4:
				s.ball(0.07, _v(-0.5 + k * 0.33, 1.0 + 0.15 * (k % 2), 0.0), fc[k], _v(1.6, 1, 0.5), 5, 3)
			for k in 3:
				s.cyl(0.0, 0.03, 0.3 + 0.1 * k, _v(-0.55 + k * 0.5, 0.95, -0.12), Color("4d7a33"), 4)
			s.ball(0.12, _v(0.45, 0.85, 0.1), GREY, _v(1.2, 0.8, 1), 5, 3)
		"terrace_5":
			s.box(_v(4.2, 0.14, 2.0), _v(0, 0.07, 0), OAK)
			for k in 9:
				s.box(_v(0.02, 0.15, 2.0), _v(-1.9 + k * 0.48, 0.07, 0), WOODL)
			for x in [-2.05, -0.7, 0.7, 2.05]:
				s.box(_v(0.07, 1.0, 0.07), _v(x, 0.64, 0.95), METALD)
			s.box(_v(4.2, 0.06, 0.07), _v(0, 1.14, 0.95), METALD)
			s.box(_v(4.2, 0.03, 0.04), _v(0, 0.6, 0.95), METALD)
			s.cyl(0.55, 0.55, 0.04, _v(0.8, 0.8, -0.1), WHITE, 8)
			s.cyl(0.04, 0.04, 0.66, _v(0.8, 0.45, -0.1), METAL, 5)
			s.cyl(0.0, 0.95, 0.3, _v(0.8, 2.2, -0.1), RED, 8)
			s.cyl(0.03, 0.03, 1.4, _v(0.8, 1.5, -0.1), METAL, 4)
			for a in [-0.9, 0.9]:
				s.box(_v(0.46, 0.05, 0.46), _v(0.8 + a, 0.46, 0.55 if a > 0 else -0.75), CLUB_BLUE)
				s.box(_v(0.46, 0.4, 0.05), _v(0.8 + a, 0.7, -0.98 if a < 0 else 0.78), CLUB_BLUE)
			for x in [-1.7, 1.7]:
				s.cyl(0.17, 0.12, 0.28, _v(x, 0.28, -0.6), TERRA, 7)
				s.ball(0.22, _v(x, 0.52, -0.6), Color("4d7a33"), _v(1, 0.8, 1), 6, 4)
		"minibar_5":
			s.box(_v(1.8, 1.0, 0.6), _v(0, 0.5, 0), ESPRESSO)
			s.box(_v(1.9, 0.06, 0.7), _v(0, 1.03, 0), OAK)
			s.box(_v(1.9, 0.03, 0.04), _v(0, 1.07, 0.34), GOLD)
			for k in 3:
				s.box(_v(0.5, 0.78, 0.02), _v(-0.6 + k * 0.6, 0.5, 0.31), WOODD)
			s.box(_v(1.8, 0.04, 0.3), _v(0, 1.7, -0.3), WOODD)
			s.box(_v(1.8, 0.04, 0.3), _v(0, 1.4, -0.3), WOODD)
			var bc := [RED, GLASS, MUSTARD, TEAL, Color("668f3b"), CLUB_BLUE, TERRA]
			for k in 7:
				s.cyl(0.04, 0.045, 0.22, _v(-0.75 + k * 0.25, 1.52, -0.3), bc[k], 6)
				s.cyl(0.015, 0.025, 0.1, _v(-0.75 + k * 0.25, 1.68, -0.3), bc[k], 5)
			for x in [-0.5, 0.5]:
				s.cyl(0.18, 0.18, 0.05, _v(x, 0.72, 0.75), RED, 7)
				s.cyl(0.03, 0.04, 0.7, _v(x, 0.36, 0.75), METALD, 5)
		_:
			return false
	return true


# --- reception and the hall of fame --------------------------------------------------

static func _hall(id: String, s: ClubShapes) -> bool:
	match id:
		"reception_1":
			s.box(_v(1.8, 1.0, 0.6), _v(0, 0.5, 0), worn(WOODL, 0.6))
			s.box(_v(1.9, 0.06, 0.72), _v(0, 1.03, 0), worn(WOODD, 0.6))
			s.cyl(0.06, 0.07, 0.04, _v(-0.6, 1.08, 0.1), GOLD, 8)                       # a bell
			s.ball(0.03, _v(-0.6, 1.12, 0.1), GOLD, _v(1, 1, 1), 4, 3)
			s.box(_v(0.4, 0.03, 0.3), _v(0.2, 1.07, 0.1), CREAM, 0.15)                   # a book
			s.cyl(0.05, 0.04, 0.12, _v(0.7, 1.12, 0.0), CLUB_BLUE, 6)
			s.box(_v(1.7, 0.1, 0.02), _v(0, 0.78, 0.31), CLUB_BLUE)
		"candidates_1":
			for x in [-0.55, 0.55]:
				s.box(_v(0.06, 1.7, 0.06), _v(x, 0.85, -0.05), WOODD, 0.0, _v(0.05, 0, 0))
			s.box(_v(1.4, 1.1, 0.06), _v(0, 1.2, 0.0), WOODD)
			s.box(_v(1.3, 1.0, 0.03), _v(0, 1.2, 0.03), Color("c9a56b"))
			var cc := [CREAM, MUSTARD, WHITE, BLUSH, CREAM]
			for k in 5:
				s.box(_v(0.28, 0.36, 0.01), _v(-0.45 + (k % 3) * 0.45 + (0.1 if k > 2 else 0.0), 1.45 - (k / 3) * 0.5, 0.05), cc[k], 0.05 * (k - 2))
				s.ball(0.02, _v(-0.45 + (k % 3) * 0.45 + (0.1 if k > 2 else 0.0), 1.6 - (k / 3) * 0.5, 0.06), RED, _v(1, 1, 0.5), 4, 3)
			s.box(_v(1.2, 0.03, 0.1), _v(0, 0.56, 0.05), WOODD)
		"sponsor_2":
			s.box(_v(0.9, 0.04, 0.4), _v(0, 0.02, 0), METALD)
			s.box(_v(0.04, 2.0, 0.04), _v(-0.4, 1.0, 0), METAL)
			s.box(_v(0.04, 2.0, 0.04), _v(0.4, 1.0, 0), METAL)
			s.box(_v(0.84, 1.8, 0.03), _v(0, 1.05, 0.0), CLUB_BLUE)
			s.box(_v(0.84, 0.3, 0.035), _v(0, 0.35, 0.0), CLUB_DARK)
			s.ball(0.25, _v(0, 1.45, 0.03), GOLD, _v(1, 1, 0.2), 8, 4)
			s.box(_v(0.5, 0.06, 0.035), _v(0, 0.95, 0.0), WHITE)
			s.box(_v(0.4, 0.06, 0.035), _v(0, 0.8, 0.0), WHITE)
		"trophycase_3":
			s.box(_v(1.7, 2.0, 0.04), _v(0, 1.0, -0.23), NAVY)
			for x in [-0.84, 0.84]:
				s.box(_v(0.06, 2.0, 0.5), _v(x, 1.0, 0), WOODD)
			s.box(_v(1.74, 0.07, 0.52), _v(0, 2.03, 0), WOODD)
			for k in 4:
				s.box(_v(1.62, 0.04, 0.46), _v(0, 0.07 + k * 0.5, 0.0), GLASS if k > 0 else WOODD)
			var cs := [[GOLD, SILVER, BRONZE], [GOLD, GOLD, SILVER], [BRONZE, GOLD, GOLD]]
			for r in 3:
				for k in 3:
					_cup(s, _v(-0.5 + k * 0.5, 0.09 + r * 0.5, -0.02), cs[r][k], 1.0)
			s.box(_v(1.7, 0.1, 0.04), _v(0, 1.95, 0.24), CLUB_BLUE)
		"agentdesk_4":
			s.box(_v(2.3, 0.07, 1.0), _v(0, 0.77, 0), ESPRESSO)
			s.box(_v(2.34, 0.02, 0.06), _v(0, 0.815, 0.5), GOLD)
			for x in [-1.0, 1.0]:
				s.box(_v(0.1, 0.74, 0.9), _v(x, 0.37, 0), WOODD)
			s.box(_v(2.1, 0.5, 0.03), _v(0, 0.55, -0.4), WOODD)
			_monitor(s, _v(-0.5, 0.82, -0.25), 0.5)
			s.box(_v(0.18, 0.1, 0.16), _v(0.4, 0.88, -0.2), METALD)             # a phone
			s.box(_v(0.1, 0.04, 0.12), _v(0.4, 0.95, -0.2), METALD, 0.0, _v(0, 0, 0.3))
			s.box(_v(0.5, 0.025, 0.36), _v(0.2, 0.83, 0.2), CREAM, 0.1)         # a contract
			s.box(_v(0.12, 0.02, 0.04), _v(0.3, 0.85, 0.22), CLUB_BLUE, 0.7)
			_cup(s, _v(0.95, 0.82, 0.0), GOLD, 0.6)
			for x in [-0.55, 0.55]:
				s.box(_v(0.5, 0.06, 0.5), _v(x, 0.46, 1.25), PLUM)
				s.box(_v(0.5, 0.55, 0.06), _v(x, 0.75, 1.5), PLUM)
				for dx in [-0.2, 0.2]:
					s.box(_v(0.05, 0.44, 0.05), _v(x + dx, 0.22, 1.1), GOLD)
					s.box(_v(0.05, 0.44, 0.05), _v(x + dx, 0.22, 1.45), GOLD)
		"fame_5":
			s.box(_v(4.0, 2.2, 0.08), _v(0, 1.6, 0), CREAM)
			s.box(_v(4.1, 0.1, 0.12), _v(0, 2.7, 0), CLUB_BLUE)
			s.box(_v(4.1, 0.1, 0.12), _v(0, 0.5, 0), CLUB_BLUE)
			var pc := [CLUB_BLUE, TEAL, TERRA, PLUM, MUSTARD, CLUB_BLUE, TEAL, TERRA]
			for k in 8:
				var fx := -1.4 + (k % 4) * 0.95
				var fy := 2.25 - (k / 4) * 0.85
				s.box(_v(0.7, 0.6, 0.05), _v(fx, fy, 0.05), WOODD)
				s.box(_v(0.6, 0.5, 0.02), _v(fx, fy, 0.08), pc[k].lightened(0.35))
				s.ball(0.11, _v(fx, fy + 0.03, 0.1), SKIN, _v(1, 1.1, 0.3), 5, 3)
				s.ball(0.17, _v(fx, fy - 0.2, 0.1), pc[k], _v(1, 0.55, 0.3), 5, 2)
			# the departed's rackets on pegs
			s.box(_v(3.6, 0.07, 0.08), _v(0, 0.75, 0.08), WOODD)
			for k in 6:
				var rx := -1.5 + k * 0.6
				s.cyl(0.03, 0.03, 0.4, _v(rx, 0.55, 0.12), [RED, CLUB_BLUE, METALD, WHITE, MUSTARD, TEAL][k], 4, _v(0, 0, 0.1 * (k % 3 - 1)))
				s.cyl(0.15, 0.15, 0.025, _v(rx - 0.012 * (k % 3 - 1), 0.97 - 0.3, 0.12), [RED, CLUB_BLUE, METALD, WHITE, MUSTARD, TEAL][k], 6, _v(PI * 0.5, 0, 0))
			s.box(_v(0.9, 0.2, 0.03), _v(0, 0.2, 0.06), GOLD)
		"cup_gold", "cup_silver", "cup_bronze":
			_cup(s, Vector3.ZERO, {"cup_gold": GOLD, "cup_silver": SILVER, "cup_bronze": BRONZE}[id], 1.6)
		_:
			return false
	return true


# --- shell and small things ----------------------------------------------------------

static func _shell(id: String, s: ClubShapes) -> bool:
	match id:
		"door_a", "door_b":
			var dc := WOODL if id == "door_a" else CLUB_BLUE
			s.box(_v(1.2, 0.08, 0.3), _v(0, 2.0, 0), WOODD)
			for x in [-0.55, 0.55]:
				s.box(_v(0.1, 2.0, 0.3), _v(x, 1.0, 0), WOODD)
			s.box(_v(1.0, 1.95, 0.08), _v(0, 0.98, 0.0), dc)
			s.box(_v(0.7, 0.8, 0.02), _v(0, 1.25, 0.05), dc.darkened(0.12))
			s.ball(0.04, _v(0.38, 0.95, 0.07), GOLD, _v(1, 1, 1), 5, 3)
		"frame_s", "frame_m", "frame_l":
			var d: Vector2 = {"frame_s": Vector2(0.4, 0.48), "frame_m": Vector2(0.63, 0.8), "frame_l": Vector2(1.6, 0.96)}[id]
			s.box(_v(d.x, d.y, 0.05), _v(0, 1.6, 0), WOODD)
			s.box(_v(d.x - 0.08, d.y - 0.08, 0.02), _v(0, 1.6, 0.03), CREAM)
			s.box(_v(d.x * 0.6, d.y * 0.4, 0.015), _v(0, 1.55 + d.y * 0.08, 0.045), SKY)
			s.box(_v(d.x * 0.6, d.y * 0.2, 0.015), _v(0, 1.5 - d.y * 0.04, 0.045), SAGE)
		"plant_s", "plant_m":
			var k := 1.0 if id == "plant_s" else 1.8
			s.cyl(0.1 * k, 0.07 * k, 0.14 * k, _v(0, 0.07 * k, 0), TERRA, 7)
			s.ball(0.1 * k, _v(0, 0.2 * k, 0), Color("4d7a33"), _v(1, 1.2, 1), 6, 4)
			s.ball(0.03 * k, _v(0.05 * k, 0.32 * k, 0.04 * k), Color("e9b8a8"), _v(1, 1, 1), 4, 3)
		"crate_1":
			s.box(_v(0.6, 0.4, 0.4), _v(0, 0.2, 0), worn(Color("c9a56b"), 0.6))
			s.box(_v(0.62, 0.04, 0.42), _v(0, 0.4, 0), worn(WOODL, 0.6))
		"barrel_1":
			s.cyl(0.26, 0.24, 0.6, _v(0, 0.3, 0), worn(WOODL, 0.6), 8)
			s.cyl(0.27, 0.27, 0.03, _v(0, 0.18, 0), METALD, 8)
			s.cyl(0.27, 0.27, 0.03, _v(0, 0.44, 0), METALD, 8)
		"coffee_2":
			s.box(_v(0.3, 0.12, 0.35), _v(0, 0.06, 0), METALD)
			s.box(_v(0.28, 0.28, 0.14), _v(0, 0.22, -0.1), RED)
			s.cyl(0.04, 0.04, 0.1, _v(0, 0.2, 0.05), WHITE, 6)
		"radio_1":
			s.box(_v(0.5, 0.3, 0.16), _v(0, 0.15, 0), worn(RED, 0.5))
			s.cyl(0.1, 0.1, 0.02, _v(-0.13, 0.15, 0.09), METALD, 8, _v(PI * 0.5, 0, 0))
			s.box(_v(0.02, 0.4, 0.02), _v(0.18, 0.5, -0.05), METAL, 0.0, _v(0, 0, -0.5))
		"bunk_1":
			for x in [-0.5, 0.5]:
				for z in [-0.92, 0.92]:
					s.box(_v(0.07, 1.7, 0.07), _v(x, 0.85, z), worn(METALD, 0.5))
			for y in [0.4, 1.2]:
				s.box(_v(0.96, 0.1, 1.84), _v(0, y, 0), worn(CREAM, 0.95))
				s.box(_v(0.98, 0.05, 0.8), _v(0, y + 0.07, 0.4), Color(0.45, 0.5, 0.42))
		"chalk_here":
			# "здесь будет": a dark patch on the floor with a chalk outline (1.2 x 1.2)
			s.box(_v(1.2, 0.02, 1.2), _v(0, 0.03, 0), Color("4b4540"))
			for k in 2:
				s.box(_v(1.2, 0.024, 0.035), _v(0, 0.032, (k - 0.5) * 1.17), WHITE.darkened(0.1))
				s.box(_v(0.035, 0.024, 1.2), _v((k - 0.5) * 1.17, 0.032, 0), WHITE.darkened(0.1))
		_:
			return false
	return true


# --- the building outside: the academy's facade, level 0 (stakes) to 5 (glass centre) -------

## A gable: a triangular prism, its base on y = pos.y, width w (x), height h, depth d (z).
static func _prism(s: ClubShapes, w: float, h: float, d: float, pos: Vector3, col: Color) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var a := pos + _v(-hw, 0, -hd)
	var b := pos + _v(hw, 0, -hd)
	var c := pos + _v(0, h, -hd)
	var a2 := pos + _v(-hw, 0, hd)
	var b2 := pos + _v(hw, 0, hd)
	var c2 := pos + _v(0, h, hd)
	var sl := _v(-h, hw, 0).normalized()
	var sr := _v(h, hw, 0).normalized()
	_tri(s, [a2, b2, c2], _v(0, 0, 1), col)
	_tri(s, [b, a, c], _v(0, 0, -1), col)
	_tri(s, [a, a2, c2], sl, col)
	_tri(s, [a, c2, c], sl, col)
	_tri(s, [b2, b, c], sr, col)
	_tri(s, [b2, c, c2], sr, col)
	_tri(s, [a, b, b2], _v(0, -1, 0), col)
	_tri(s, [a, b2, a2], _v(0, -1, 0), col)


static func _tri(s: ClubShapes, p: Array, n: Vector3, col: Color) -> void:
	var base := s._v.size()
	for q in p:
		s._v.append(q)
		s._n.append(n)
		s._c.append(col)
	s._i.append(base)
	s._i.append(base + 1)
	s._i.append(base + 2)


## A roof over a box: two slabs on a ridge along z (width w, ridge height h above `y`, depth d).
static func _roof(s: ClubShapes, w: float, h: float, d: float, y: float, col: Color, wall: Color, z := 0.0) -> void:
	var ang := atan2(h, w * 0.5)
	var len := sqrt(w * w * 0.25 + h * h) + 0.35
	for sg in [-1.0, 1.0]:
		s.box(_v(len, 0.14, d + 0.5), _v(sg * (w * 0.25 + 0.08), y + h * 0.5 + 0.1, z), col, 0.0, _v(0, 0, -sg * ang))
	_prism(s, w - 0.1, h - 0.02, d, _v(0, y, z), wall)


## A window: frame, glass (lit: warm), sill.
static func _window(s: ClubShapes, pos: Vector3, w: float, h: float, lit := false, shutters := Color(0, 0, 0, 0)) -> void:
	s.box(_v(w + 0.12, h + 0.12, 0.08), pos, WHITE)
	s.box(_v(w, h, 0.05), pos + _v(0, 0, 0.03), NEON if lit else GLASS)
	s.box(_v(0.04, h, 0.06), pos + _v(0, 0, 0.05), WHITE)
	s.box(_v(w + 0.2, 0.05, 0.16), pos + _v(0, -h * 0.5 - 0.08, 0.05), WOODD)
	if shutters.a > 0.0:
		for x in [-1.0, 1.0]:
			s.box(_v(w * 0.4, h, 0.04), pos + _v(x * (w * 0.5 + w * 0.25), 0, 0.03), shutters)


static func _flag(s: ClubShapes, pos: Vector3, h: float) -> void:
	s.cyl(0.04, 0.05, h, pos + _v(0, h * 0.5, 0), METAL, 5)
	s.box(_v(0.7, 0.45, 0.03), pos + _v(0.38, h - 0.3, 0), CLUB_BLUE)
	s.box(_v(0.7, 0.12, 0.035), pos + _v(0.38, h - 0.3, 0), GOLD)
	s.ball(0.06, pos + _v(0, h + 0.04, 0), GOLD, _v(1, 1, 1), 4, 3)


static func _mini_court(s: ClubShapes, pos: Vector3, w: float, d: float, net_h: float) -> void:
	s.box(_v(w + 0.8, 0.02, d + 0.8), pos + _v(0, 0.01, 0), GREEN)
	s.box(_v(w, 0.03, d), pos + _v(0, 0.02, 0), CLUB_BLUE)
	for k in 2:
		s.box(_v(w, 0.032, 0.05), pos + _v(0, 0.025, (k - 0.5) * (d - 0.05)), WHITE)
		s.box(_v(0.05, 0.032, d), pos + _v((k - 0.5) * (w - 0.05), 0.025, 0), WHITE)
	s.box(_v(0.05, 0.032, d), pos + _v(0, 0.025, 0), WHITE)
	s.box(_v(0.03, net_h * 0.8, d + 0.2), pos + _v(0, net_h * 0.6, 0), WHITE.darkened(0.08))
	for sg in [-1.0, 1.0]:
		s.box(_v(0.07, net_h + 0.1, 0.07), pos + _v(0, (net_h + 0.1) * 0.5, sg * (d * 0.5 + 0.1)), METALD)


static func _outside(id: String, s: ClubShapes) -> bool:
	match id:
		"academy_0":
			# stakes with tape, a gravel patch, a sign (9 x 7 m)
			s.flat(Vector2(4.8, 3.8), _v(0, 0.02, 0), Color("9e968a"), 12)
			s.flat(Vector2(3.0, 2.2), _v(0.3, 0.03, 0.2), Color("bdb3a3"), 10, 0.4)
			for sx in [-4.5, 4.5]:
				for sz in [-3.5, 3.5]:
					s.box(_v(0.1, 1.1, 0.1), _v(sx, 0.55, sz), WOODL)
					s.box(_v(0.12, 0.2, 0.12), _v(sx, 1.0, sz), RED)
			for k in 9:
				var c := RED if k % 2 == 0 else WHITE
				s.box(_v(1.0, 0.05, 0.02), _v(-4.0 + k * 1.0, 0.92 - 0.04 * sin(k * 0.7), 3.5), c)
				s.box(_v(1.0, 0.05, 0.02), _v(-4.0 + k * 1.0, 0.92 - 0.04 * sin(k * 0.7), -3.5), c)
			for k in 7:
				var c := RED if k % 2 == 0 else WHITE
				s.box(_v(0.02, 0.05, 1.0), _v(-4.5, 0.92 - 0.04 * sin(k * 0.8), -3.0 + k * 1.0), c)
				s.box(_v(0.02, 0.05, 1.0), _v(4.5, 0.92 - 0.04 * sin(k * 0.8), -3.0 + k * 1.0), c)
			s.box(_v(0.08, 1.6, 0.08), _v(-1.2, 0.8, 3.9), WOODD)
			s.box(_v(1.4, 0.7, 0.06), _v(-0.6, 1.5, 3.9), WOODL)
			s.box(_v(1.2, 0.5, 0.02), _v(-0.6, 1.5, 3.94), CREAM)
			s.box(_v(0.5, 0.08, 0.02), _v(-0.6, 1.58, 3.95), CLUB_BLUE)
			s.box(_v(0.35, 0.05, 0.02), _v(-0.6, 1.42, 3.95), GOLD)
			s.cyl(0.25, 0.2, 0.3, _v(3.4, 0.15, 2.6), WOODL, 8)             # a ball bucket
			s.ball(0.07, _v(3.35, 0.32, 2.6), BALL, _v(1, 1, 1), 5, 3)
			s.ball(0.07, _v(3.5, 0.32, 2.68), BALL, _v(1, 1, 1), 5, 3)
		"academy_1":
			# "children's ground": a half court with a low net, a wall to hit against, a shed, a bench
			_mini_court(s, _v(0, 0, 0.5), 6.0, 3.0, 0.7)
			s.box(_v(4.6, 2.0, 0.3), _v(0, 1.0, -2.6), Color("a0523d"))
			s.box(_v(4.8, 0.14, 0.4), _v(0, 2.06, -2.6), WOODD)
			s.cyl(0.6, 0.6, 0.02, _v(0, 1.0, -2.43), MUSTARD, 12, _v(PI * 0.5, 0, 0))
			s.cyl(0.35, 0.35, 0.025, _v(0, 1.0, -2.42), RED, 12, _v(PI * 0.5, 0, 0))
			s.box(_v(4.6, 0.04, 0.02), _v(0, 0.9, -2.43), WHITE)
			s.box(_v(2.4, 2.0, 2.0), _v(5.3, 1.0, -1.6), WOODL)
			s.box(_v(2.7, 0.12, 2.3), _v(5.3, 2.12, -1.6), RED, 0.0, _v(0.08, 0, 0))
			s.box(_v(0.8, 1.5, 0.05), _v(5.3, 0.75, -0.58), CLUB_BLUE)
			s.box(_v(1.5, 0.06, 0.4), _v(-4.0, 0.42, 3.0), WOODL)
			s.box(_v(1.5, 0.4, 0.06), _v(-4.0, 0.62, 2.85), WOODL)
			for x in [-4.6, -3.4]:
				s.box(_v(0.06, 0.4, 0.34), _v(x, 0.2, 3.0), METALD)
			s.box(_v(0.08, 1.6, 0.08), _v(-3.2, 0.8, -3.5), WOODD)
			s.box(_v(1.2, 0.6, 0.05), _v(-3.2, 1.45, -3.5), CREAM)
			s.box(_v(0.5, 0.07, 0.02), _v(-3.2, 1.55, -3.46), CLUB_BLUE)
			s.cyl(0.25, 0.2, 0.3, _v(3.2, 0.15, 3.0), WOODL, 8)
			s.ball(0.07, _v(3.2, 0.32, 3.0), BALL, _v(1, 1, 1), 5, 3)
		"academy_2":
			# "the little house": a wooden cottage with a porch
			s.flat(Vector2(5.5, 4.3), _v(0, 0.015, 0.4), Color("bdb3a3"), 12)
			s.box(_v(6.4, 0.3, 4.6), _v(0, 0.15, 0), WOODD)
			s.box(_v(6.0, 2.5, 4.2), _v(0, 1.55, 0), WOODL)
			for k in 12:
				s.box(_v(0.03, 2.5, 0.02), _v(-2.75 + k * 0.5, 1.55, 2.11), WOODL.darkened(0.12))
			_roof(s, 6.4, 1.7, 4.4, 2.8, RED, WOODL)
			s.box(_v(0.6, 1.3, 0.6), _v(2.0, 4.0, -1.0), Color("a0523d"))
			s.box(_v(0.7, 0.1, 0.7), _v(2.0, 4.7, -1.0), METALD)
			s.box(_v(1.1, 2.0, 0.08), _v(-1.2, 1.3, 2.14), CLUB_BLUE)
			s.ball(0.05, _v(-0.8, 1.25, 2.2), GOLD, _v(1, 1, 1), 5, 3)
			_window(s, _v(1.4, 1.7, 2.12), 1.1, 1.0, false, CLUB_BLUE)
			_window(s, _v(-2.5, 1.7, 2.12), 0.8, 1.0, false)
			s.box(_v(2.2, 0.12, 1.2), _v(-1.2, 0.36, 2.7), WOODL)                       # porch
			s.box(_v(0.12, 1.7, 0.12), _v(-2.2, 1.15, 3.2), WOODD)
			s.box(_v(0.12, 1.7, 0.12), _v(-0.2, 1.15, 3.2), WOODD)
			s.box(_v(2.6, 0.1, 1.4), _v(-1.2, 2.05, 2.75), RED, 0.0, _v(0.12, 0, 0))
			s.box(_v(1.3, 0.3, 0.3), _v(1.4, 0.65, 2.55), WOODD)                        # a flower box
			for k in 4:
				s.ball(0.1, _v(1.0 + k * 0.27, 0.9, 2.55), [RED, MUSTARD, WHITE, RED][k], _v(1, 0.8, 1), 5, 3)
			s.cyl(0.27, 0.22, 0.35, _v(2.6, 0.5, 2.7), WOODL, 8)
			for k in 3:
				s.ball(0.08, _v(2.55 + k * 0.05, 0.72, 2.7 + k * 0.03), BALL, _v(1, 1, 1), 5, 3)
			_mini_court(s, _v(-5.3, 0, 0.5), 2.6, 4.0, 0.5)
		"academy_3":
			# "the academy court": a brick pavilion, a schedule board, floodlights, a court in front
			s.box(_v(8.6, 0.3, 5.0), _v(0, 0.15, -1.6), Color("8f8a80"))
			s.box(_v(8.0, 3.2, 4.4), _v(0, 1.9, -1.6), Color("a0523d"))
			s.box(_v(8.1, 0.2, 4.5), _v(0, 3.55, -1.6), WHITE)
			_roof(s, 8.8, 1.2, 4.8, 3.6, Color("5e5a54"), Color("a0523d"), -1.6)
			for k in 4:
				_window(s, _v(-2.7 + k * 1.8, 2.2, 0.62), 1.2, 1.1, k % 2 == 1)
			s.box(_v(1.2, 2.1, 0.08), _v(0, 1.35, 0.62), CLUB_BLUE)
			s.box(_v(2.2, 0.12, 1.2), _v(0, 2.5, 1.2), METALD)
			for x in [-1.0, 1.0]:
				s.box(_v(0.08, 2.2, 0.08), _v(x, 1.3, 1.7), METALD)
			s.box(_v(4.0, 0.5, 0.06), _v(0, 3.0, 0.64), CLUB_BLUE)
			s.ball(0.17, _v(-1.5, 3.0, 0.7), GOLD, _v(1, 1, 0.3), 6, 4)
			_mini_court(s, _v(0.0, 0, 4.2), 9.0, 4.2, 0.9)
			for x in [-5.3, 5.3]:
				s.cyl(0.08, 0.1, 5.2, _v(x, 2.6, 4.2), METALD, 6)
				s.box(_v(0.9, 0.2, 0.4), _v(x, 5.2, 4.2), METALD)
				s.box(_v(0.8, 0.05, 0.32), _v(x, 5.07, 4.2), NEON)
			s.box(_v(0.08, 1.6, 0.08), _v(-3.4, 0.8, 7.1), WOODD)
			s.box(_v(1.5, 0.9, 0.06), _v(-3.4, 1.55, 7.1), CHALK)
			s.box(_v(1.3, 0.04, 0.02), _v(-3.4, 1.8, 7.14), WHITE)
			s.box(_v(1.0, 0.04, 0.02), _v(-3.4, 1.55, 7.14), WHITE)
			s.box(_v(1.1, 0.04, 0.02), _v(-3.4, 1.3, 7.14), WHITE)
			s.box(_v(1.7, 0.06, 0.4), _v(3.6, 0.4, 7.0), WOODL)
			s.box(_v(1.7, 0.4, 0.06), _v(3.6, 0.6, 6.85), WOODL)
		"academy_4":
			# "the dormitory": two storeys, club band, lit windows, balconies, flags
			s.box(_v(11.0, 0.3, 6.2), _v(0, 0.15, 0), Color("8f8a80"))
			s.box(_v(10.4, 6.2, 5.6), _v(0, 3.4, 0), CREAM)
			s.box(_v(10.6, 0.5, 5.8), _v(0, 3.45, 0), CLUB_BLUE)
			s.box(_v(10.8, 0.3, 6.0), _v(0, 6.65, 0), CLUB_DARK)
			s.box(_v(10.4, 0.4, 0.2), _v(0, 6.95, 2.7), CREAM)
			for k in 5:
				_window(s, _v(-4.0 + k * 2.0, 1.9, 2.82), 1.0, 1.2, k != 2)
				_window(s, _v(-4.0 + k * 2.0, 4.9, 2.82), 1.0, 1.2, k % 2 == 0)
			s.box(_v(1.4, 2.3, 0.08), _v(0, 1.45, 2.82), CLUB_BLUE)
			s.box(_v(2.4, 0.14, 1.4), _v(0, 2.65, 3.5), CLUB_DARK)
			for x in [-1.1, 1.1]:
				s.box(_v(0.14, 2.4, 0.14), _v(x, 1.5, 4.1), WHITE)
			s.box(_v(3.0, 0.1, 1.2), _v(-3.5, 4.3, 3.4), METALD)                         # balconies
			s.box(_v(3.0, 0.1, 1.2), _v(3.5, 4.3, 3.4), METALD)
			for x in [-3.5, 3.5]:
				s.box(_v(3.0, 0.7, 0.05), _v(x, 4.75, 3.95), GLASS)
				s.box(_v(3.0, 0.05, 0.06), _v(x, 5.1, 3.95), METALD)
			_flag(s, _v(-5.7, 0, 3.2), 6.2)
			_flag(s, _v(5.7, 0, 3.2), 6.2)
			s.box(_v(2.2, 0.9, 0.12), _v(0, 5.7 + 0.0, 2.85), CLUB_BLUE)
			s.ball(0.28, _v(0, 5.7, 2.95), GOLD, _v(1, 1, 0.3), 8, 4)
		"academy_5":
			# "the training centre": a glass hall, white upper floor, a canopy, a tower with the board
			s.box(_v(13.0, 0.3, 8.2), _v(0, 0.15, 0), Color("bdb3a3"))
			s.box(_v(12.0, 3.2, 7.2), _v(0, 1.9, 0), GLASS)
			for k in 13:
				s.box(_v(0.08, 3.2, 0.1), _v(-6.0 + k * 1.0, 1.9, 3.62), WHITE)
			for k in 3:
				s.box(_v(12.0, 0.08, 0.1), _v(0, 0.5 + k * 1.05, 3.62), WHITE)
			s.box(_v(12.4, 0.4, 7.6), _v(0, 3.7, 0), WHITE)
			s.box(_v(9.0, 2.8, 6.4), _v(-1.4, 5.3, -0.2), WHITE)
			s.box(_v(9.1, 0.6, 6.5), _v(-1.4, 5.2, -0.2), CLUB_BLUE)
			for k in 6:
				s.box(_v(1.0, 1.2, 0.06), _v(-4.6 + k * 1.5, 5.6, 3.04), GLASS)
			s.box(_v(9.4, 0.3, 6.8), _v(-1.4, 6.85, -0.2), CLUB_DARK)
			s.box(_v(13.4, 0.3, 4.0), _v(0, 3.3, 5.0), METALD)                           # the canopy
			for x in [-5.5, 0.0, 5.5]:
				s.box(_v(0.14, 3.2, 0.14), _v(x, 1.7, 6.8), WHITE)
			s.box(_v(3.4, 3.2, 0.1), _v(0, 1.9, 3.7), Color("101114"))                    # the entrance
			s.box(_v(3.2, 3.0, 0.05), _v(0, 1.9, 3.76), GLASS.lightened(0.2))
			s.box(_v(0.06, 3.0, 0.06), _v(0, 1.9, 3.78), WHITE)
			s.box(_v(4.0, 0.7, 0.14), _v(0, 3.95, 3.9), CLUB_BLUE)
			s.ball(0.3, _v(-1.4, 3.95, 4.0), GOLD, _v(1, 1, 0.3), 8, 4)
			s.box(_v(1.8, 0.1, 0.03), _v(0.4, 3.95, 4.0), WHITE)
			s.box(_v(1.0, 0.1, 0.03), _v(0.0, 3.75, 4.0), WHITE)
			for k in 3:
				s.box(_v(4.6, 0.15, 0.6), _v(0, 0.08 + k * 0.15 - 0.1, 7.2 - k * 0.6 + 0.8), Color("8f8a80"))
			s.box(_v(1.4, 7.5, 1.2), _v(7.6, 3.75, 1.5), CLUB_BLUE)                     # the tower with the board
			s.box(_v(1.0, 1.4, 0.06), _v(7.6, 6.0, 2.14), Color("101114"))
			s.box(_v(0.8, 0.5, 0.04), _v(7.6, 6.2, 2.18), NEON)
			s.box(_v(0.5, 0.1, 0.04), _v(7.6, 5.7, 2.18), SCREEN)
			s.box(_v(1.5, 0.2, 1.3), _v(7.6, 7.6, 1.5), GOLD)
			_flag(s, _v(-6.6, 0, 6.0), 7.0)
			_flag(s, _v(6.0, 0, 6.2), 7.0)
			for x in [-5.0, 5.0]:
				s.cyl(0.4, 0.3, 0.5, _v(x, 0.3, 5.9), METALD, 8)
				s.ball(0.5, _v(x, 1.2, 5.9), Color("4d7a33"), _v(1, 1.2, 1), 6, 4)
		_:
			return false
	return true


# --- light figures: the academy's kids as one small mesh each (a MultiMesh of them stays two draws) ----------

## A junior (about 1.5 m, the head big) in a pose, facing +z. Letters a/b/c: shirt and hair.
## sit/eat: the hips on y = 0.46 (a chair seat), the feet forward; lie: on the back, the head toward -z,
## on y = 0 (put it on the mattress: + the bed's height); run: the stride of a runner on a treadmill.
static func _kids(id: String, s: ClubShapes) -> bool:
	if not id.begins_with("kid_"):
		return false
	var parts := id.split("_")
	if parts.size() != 3:
		return false
	var v := "abc".find(parts[2])
	if v < 0:
		return false
	var shirt: Color = [CLUB_BLUE, TERRA, TEAL][v]
	var hair: Color = [Color("3b2a1e"), Color("c9a05a"), Color("6b3a22")][v]
	var pants := NAVY
	var skin: Color = [SKIN, Color("c58c63"), Color("f0c8a0")][v]
	match parts[1]:
		"stand":
			for x in [-0.08, 0.08]:
				s.cyl(0.07, 0.055, 0.66, _v(x, 0.35, 0), pants, 5)
				s.box(_v(0.1, 0.06, 0.2), _v(x, 0.03, 0.04), WHITE)
			s.ball(0.19, _v(0, 0.95, 0), shirt, _v(1.0, 1.35, 0.7), 6, 3)
			for x in [-0.22, 0.22]:
				s.cyl(0.045, 0.04, 0.45, _v(x, 0.92, 0.0), shirt, 4)
				s.ball(0.045, _v(x, 0.68, 0.0), skin, _v(1, 1, 1), 4, 3)
			_kid_head(s, _v(0, 1.37, 0), skin, hair)
		"sit", "eat":
			for x in [-0.08, 0.08]:
				s.cyl(0.07, 0.06, 0.4, _v(x, 0.46, 0.2), pants, 5, _v(PI * 0.5, 0, 0))
				s.cyl(0.055, 0.05, 0.44, _v(x, 0.24, 0.4), pants, 5)
				s.box(_v(0.1, 0.06, 0.2), _v(x, 0.03, 0.46), WHITE)
			s.box(_v(0.28, 0.14, 0.26), _v(0, 0.5, 0.02), pants)
			s.ball(0.19, _v(0, 0.82, -0.02), shirt, _v(1.0, 1.35, 0.7), 6, 3)
			var up := parts[1] == "eat"
			s.cyl(0.045, 0.04, 0.4, _v(-0.22, 0.8, 0.1), shirt, 4, _v(0.9, 0, 0))
			s.cyl(0.045, 0.04, 0.4, _v(0.22, 0.88 if up else 0.8, 0.14 if up else 0.1), shirt, 4, _v(-0.3 if up else 0.9, 0, 0))
			s.ball(0.045, _v(-0.22, 0.68, 0.3), skin, _v(1, 1, 1), 4, 3)
			s.ball(0.045, _v(0.2, 1.1 if up else 0.68, 0.18 if up else 0.3), skin, _v(1, 1, 1), 4, 3)
			if up:
				s.cyl(0.012, 0.012, 0.16, _v(0.2, 1.15, 0.2), METAL, 3, _v(0.6, 0, 0))
			_kid_head(s, _v(0, 1.2, 0.0), skin, hair)
		"lie":
			for x in [-0.08, 0.08]:
				s.cyl(0.07, 0.055, 0.7, _v(x, 0.12, 0.66), pants, 5, _v(PI * 0.5, 0, 0))
				s.box(_v(0.1, 0.1, 0.2), _v(x, 0.1, 1.08), WHITE)
			s.ball(0.19, _v(0, 0.14, 0.05), shirt, _v(1.0, 0.7, 1.35), 6, 3)
			for x in [-0.23, 0.23]:
				s.cyl(0.045, 0.04, 0.45, _v(x, 0.08, 0.08), shirt, 4, _v(PI * 0.5, 0, 0))
			s.ball(0.13, _v(0, 0.18, -0.45), skin, _v(1, 1, 1), 6, 3)
			s.ball(0.14, _v(0, 0.2, -0.47), hair, _v(1, 0.8, 1), 5, 2)
			s.box(_v(0.45, 0.08, 0.3), _v(0, 0.06, -0.5), WHITE, 0.0)
			s.box(_v(0.5, 0.07, 0.8), _v(0, 0.2, 0.55), shirt.lightened(0.15))      # the blanket over the legs
		"run":
			s.cyl(0.07, 0.055, 0.62, _v(-0.08, 0.5, 0.18), pants, 5, _v(-0.6, 0, 0))
			s.cyl(0.07, 0.055, 0.62, _v(0.08, 0.5, -0.2), pants, 5, _v(0.5, 0, 0))
			s.box(_v(0.1, 0.06, 0.2), _v(-0.08, 0.22, 0.42), WHITE)
			s.box(_v(0.1, 0.06, 0.2), _v(0.08, 0.12, -0.36), WHITE)
			s.ball(0.19, _v(0, 0.95, 0.0), shirt, _v(1.0, 1.3, 0.7), 6, 3)
			s.cyl(0.045, 0.04, 0.42, _v(-0.22, 0.95, 0.15), shirt, 4, _v(-0.8, 0, 0))
			s.cyl(0.045, 0.04, 0.42, _v(0.22, 0.95, -0.15), shirt, 4, _v(0.8, 0, 0))
			_kid_head(s, _v(0, 1.36, 0.03), skin, hair)
		_:
			return false
	return true


static func _kid_head(s: ClubShapes, pos: Vector3, skin: Color, hair: Color) -> void:
	s.ball(0.17, pos, skin, _v(1, 1.05, 1), 6, 4)
	s.ball(0.185, pos + _v(0, 0.03, -0.035), hair, _v(1, 0.9, 0.95), 5, 3)
	for x in [-0.05, 0.05]:
		s.ball(0.018, pos + _v(x, 0.0, 0.15), Color("1d1d22"), _v(1, 1, 0.5), 4, 3)
