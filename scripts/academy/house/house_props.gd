class_name HouseProps
extends RefCounted
## What each level puts into a room of the house - STUBS (AH-1): a few coloured boxes and cylinders per
## object, the right size and place, so the house is readable and walkable until the model pack and
## HouseShapes (stream art, AH-5) draw the real ones. The anchors are the art stream's frame
## (scripts/academy/house/house_layout.gd of its branch): a room is 6 x 6 m, x and z in [-3, 3],
## the back wall at z = -3, the wall to the hall at x = -3 with the door at z = +1.5; a room on the
## other side of the hall is the same plan mirrored (x -> -x, yaw -> -yaw). Table: HouseRooms.
##
## An OBJECT is {solid: bool, boxes: [shape...]}; the level's list is what the level ADDS (spec 2.3: a level adds
## an object, it doesn't replace the room). A shape is one of
##   ["b", w, h, d, x, y, z, color, yaw]   a box standing on y (the bottom), centred on x/z
##   ["c", r, h, x, y, z, color]           a cylinder of 8 sides
##   ["o", r, x, y, z, color]              a ball, y is its centre
## Everything is built into ONE mesh per room (vertex colours, ClubScenery.prop_material()), so a whole room
## is a single draw call.

const WOOD := Color("c08a55")
const WOODD := Color("6b4a32")
const CREAM := Color("f4ead5")
const SAGE := Color("a9c5a0")
const MUSTARD := Color("e8b84a")
const PLUM := Color("6b4b7a")
const TEAL := Color("4a8f87")
const SKY := Color("7fb6d9")
const TERRA := Color("b5654a")
const GOLD := Color("ffd642")
const NEON := Color("ffe27a")
const WHITE := Color("f2f0ea")
const GREY := Color("9e968a")
const METAL := Color("b9bec4")
const METALD := Color("25272b")
const NAVY := Color("1e2a44")
const RED := Color("d9473b")
const GREEN := Color("3d806a")
const GLASS := Color("8fb8c9")
const SCREEN := Color("8fd3e8")
const CLUB := Color("2a54a3")
const CHALK := Color("29392f")
const CORK := Color("c9a46b")
const CLINIC := Color("dfe6ea")

const SIZE := 3.0                     # a room's half width and depth
const CHALK_COL := Color("cfc8b8")


static func _b(w: float, h: float, d: float, x: float, y: float, z: float, col: Color, yaw := 0.0) -> Array:
	return ["b", w, h, d, x, y, z, col, yaw]


static func _c(r: float, h: float, x: float, y: float, z: float, col: Color) -> Array:
	return ["c", r, h, x, y, z, col]


static func _o(r: float, x: float, y: float, z: float, col: Color) -> Array:
	return ["o", r, x, y, z, col]


static func _s(shapes: Array) -> Dictionary:
	return {"solid": true, "boxes": shapes}


static func _d(shapes: Array) -> Dictionary:
	return {"solid": false, "boxes": shapes}


static func _bed(x: float, z: float, mattress: Color) -> Dictionary:
	return _s([_b(0.95, 0.35, 2.0, x, 0.0, z, WOOD), _b(0.88, 0.14, 1.9, x, 0.35, z, mattress), _b(0.55, 0.1, 0.35, x, 0.49, z - 0.75, WHITE)])


static func _table(x: float, z: float, w := 1.6, d := 0.8) -> Dictionary:
	var s := [_b(w, 0.08, d, x, 0.72, z, WOOD)]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			s.append(_b(0.08, 0.72, 0.08, x + sx * (w * 0.5 - 0.08), 0.0, z + sz * (d * 0.5 - 0.08), WOODD))
	return _s(s)


static func _sofa(x: float, z: float, w: float, col: Color, facing_back := true) -> Dictionary:
	var dz := 0.38 if facing_back else -0.38
	return _s([_b(w, 0.45, 0.9, x, 0.0, z, col), _b(w, 0.5, 0.2, x, 0.45, z + dz, col.darkened(0.15)),
		_b(0.2, 0.3, 0.9, x - w * 0.5 + 0.1, 0.45, z, col.darkened(0.1)), _b(0.2, 0.3, 0.9, x + w * 0.5 - 0.1, 0.45, z, col.darkened(0.1))])


static func _desk(x: float, z: float, w := 1.6, d := 0.7, yaw := 0.0) -> Dictionary:
	return _s([_b(w, 0.07, d, x, 0.72, z, WOODD, yaw), _b(0.1, 0.72, d - 0.1, x - w * 0.5 + 0.1, 0.0, z, WOOD, yaw), _b(0.1, 0.72, d - 0.1, x + w * 0.5 - 0.1, 0.0, z, WOOD, yaw)])


## The objects a room gets AT this level (1..5).
static func items(room: String, lv: int) -> Array:
	match room:
		"dorm":
			match lv:
				1: return [_bed(-2.1, -2.0, GREY.lightened(0.35)), _bed(-0.4, -2.0, GREY.lightened(0.35)), _s([_b(0.4, 0.45, 0.4, -1.25, 0.0, -2.75, WOODD)])]
				2:
					var bunk := [_b(0.88, 0.14, 1.9, 1.35, 0.3, -2.0, SKY), _b(0.88, 0.14, 1.9, 1.35, 1.15, -2.0, SAGE)]
					for sx in [-1.0, 1.0]:
						for sz in [-1.0, 1.0]:
							bunk.append(_b(0.07, 1.8, 0.07, 1.35 + sx * 0.45, 0.0, -2.0 + sz * 0.95, WOODD))
					return [_s(bunk), _s([_b(0.9, 2.0, 0.5, 2.45, 0.0, -2.7, WOODD), _b(0.02, 1.7, 0.02, 2.45, 0.15, -2.43, WOOD)])]
				3: return [_s([_b(0.4, 0.45, 0.4, 0.45, 0.0, -2.75, WOODD)]), _d([_c(0.09, 0.28, 0.45, 0.45, -2.75, NEON), _c(0.09, 0.28, -1.25, 0.45, -2.75, NEON)]),
					_d([_b(0.45, 2.1, 0.08, -1.35, 0.5, -2.93, PLUM), _b(0.45, 2.1, 0.08, 1.35, 0.5, -2.93, PLUM)])]
				4: return [_d([_b(2.6, 0.03, 1.7, -0.4, 0.0, 0.5, TERRA), _b(2.0, 0.035, 1.1, -0.4, 0.0, 0.5, MUSTARD)])]
				5: return [_s([_b(0.08, 1.1, 1.6, -1.25, 0.0, -1.2, GLASS)]), _d([_o(0.09, -1.25, 0.95, -2.75, NEON)]),
					_d([_b(1.6, 0.12, 2.6, 4.0, -0.12, -0.6, WOOD), _b(0.06, 0.9, 2.6, 4.75, 0.0, -0.6, METAL), _b(1.6, 0.06, 0.06, 4.0, 0.9, -1.88, METAL), _b(1.6, 0.06, 0.06, 4.0, 0.9, 0.68, METAL)])]
		"canteen":
			match lv:
				1: return [_table(0.0, 1.15), _s([_b(1.6, 0.45, 0.35, 0.0, 0.0, 0.4, WOODD)]), _s([_b(1.6, 0.45, 0.35, 0.0, 0.0, 1.9, WOODD)]),
					_s([_b(0.7, 1.7, 0.65, -2.5, 0.0, -2.65, WHITE), _b(0.04, 0.5, 0.04, -2.2, 0.9, -2.3, METAL)])]
				2: return [_s([_b(3.0, 0.9, 0.6, 0.2, 0.0, -2.65, WOODD), _b(3.0, 0.05, 0.62, 0.2, 0.9, -2.65, CREAM)]), _d([_b(0.7, 0.04, 0.5, -0.6, 0.95, -2.65, METALD), _b(0.4, 0.1, 0.3, -1.2, 0.95, -2.65, WHITE), _c(0.1, 0.25, 1.4, 0.95, -2.65, METAL)])]
				3: return [_s([_b(1.8, 0.95, 0.8, 0.0, 0.0, -1.05, WOOD), _b(1.9, 0.06, 0.9, 0.0, 0.95, -1.05, CREAM)]), _s([_b(0.5, 1.0, 2.0, 2.65, 0.0, 0.3, WOOD), _b(0.55, 0.06, 2.1, 2.65, 1.0, 0.3, CREAM)])]
				4: return [_s([_b(0.8, 1.3, 0.45, -2.55, 0.0, -1.0, MUSTARD), _o(0.12, -2.55, 1.4, -1.0, RED), _o(0.12, -2.4, 1.4, -0.85, GREEN)]), _d([_b(0.9, 0.9, 0.06, 2.4, 0.9, -1.75, CHALK, -0.44)])]
				5: return [_table(-1.3, 1.3, 1.2, 0.8), _table(1.1, 1.3, 1.2, 0.8),
					_s([_b(0.45, 0.9, 0.3, 1.9, 0.0, -1.85, WHITE), _o(0.17, 1.9, 1.05, -1.85, Color("e3b48a")), _c(0.15, 0.3, 1.9, 1.2, -1.85, WHITE)])]
		"gym":
			match lv:
				1: return [_d([_b(1.8, 0.04, 0.9, -1.6, 0.0, 0.6, SKY)]), _d([_b(0.5, 0.12, 0.15, 1.5, 0.0, -2.5, METALD), _b(0.5, 0.12, 0.15, 1.5, 0.12, -2.5, METALD)]), _s([_o(0.35, 2.15, 0.35, -1.7, RED)])]
				2: return [_s([_b(0.08, 2.3, 0.08, -2.25, 0.0, -2.3, METAL), _b(0.08, 2.3, 0.08, -2.25, 0.0, -1.5, METAL), _b(0.08, 0.08, 0.9, -2.25, 2.3, -1.9, METAL)]), _d([_b(0.5, 0.03, 2.0, 0.6, 0.0, 0.5, MUSTARD)])]
				3:
					var out := []
					for x in [-1.1, 0.0]:
						out.append(_s([_b(0.8, 0.18, 1.8, x, 0.0, -1.9, METALD), _b(0.65, 0.06, 1.5, x, 0.18, -1.8, GREY), _b(0.7, 0.9, 0.12, x, 0.18, -2.7, METALD), _b(0.5, 0.05, 0.3, x, 1.05, -2.6, SCREEN)]))
					return out
				4: return [_d([_b(2.4, 1.6, 0.05, -0.55, 0.4, -2.95, GLASS)]), _s([_b(0.1, 2.2, 0.1, 1.55, 0.0, 0.5, METALD), _b(0.1, 2.2, 0.1, 2.35, 0.0, 0.5, METALD), _b(0.9, 0.1, 0.1, 1.95, 1.3, 0.5, METAL)]), _d([_b(1.8, 0.06, 0.06, 1.9, 0.4, 2.2, METAL), _c(0.2, 0.06, 1.1, 0.4, 2.2, METALD), _c(0.2, 0.06, 2.7, 0.4, 2.2, METALD)])]
				5: return [_d([_b(0.06, 0.9, 1.6, -2.9, 1.6, -1.2, METALD), _b(0.04, 0.6, 1.3, -2.86, 1.75, -1.2, NEON)]), _s([_b(0.4, 0.8, 0.4, -2.4, 0.0, 2.6, METALD)]), _s([_b(0.6, 0.35, 0.6, 0.0, 0.0, 2.4, WOOD), _b(0.6, 0.5, 0.6, 0.65, 0.0, 2.4, WOOD), _b(0.6, 0.65, 0.6, 1.3, 0.0, 2.4, WOOD)])]
		"lounge":
			match lv:
				1: return [_sofa(0.7, -0.4, 2.0, TERRA, true), _s([_b(1.4, 0.5, 0.4, 0.7, 0.0, -2.7, WOODD), _b(1.2, 0.7, 0.08, 0.7, 0.5, -2.7, METALD), _b(1.1, 0.6, 0.02, 0.7, 0.55, -2.65, SCREEN)])]
				2: return [_s([_b(1.3, 0.06, 2.2, -1.2, 0.74, 1.1, CLUB), _b(0.06, 0.74, 0.06, -1.8, 0.0, 0.15, METALD), _b(0.06, 0.74, 0.06, -0.6, 0.0, 0.15, METALD), _b(0.06, 0.74, 0.06, -1.8, 0.0, 2.05, METALD), _b(0.06, 0.74, 0.06, -0.6, 0.0, 2.05, METALD)]), _d([_b(1.4, 0.16, 0.02, -1.2, 0.8, 1.1, WHITE)])]
				3: return [_d([_b(0.3, 0.06, 0.2, 0.7, 0.5, -2.45, METALD)]), _s([_b(0.5, 0.4, 0.5, 2.1, 0.0, 0.9, MUSTARD)]), _s([_b(0.5, 0.4, 0.5, 2.2, 0.0, 1.6, TEAL)])]
				4: return [_s([_b(1.6, 2.2, 0.35, -1.6, 0.0, -2.8, WOODD), _b(1.4, 0.2, 0.05, -1.6, 0.4, -2.6, RED), _b(1.4, 0.2, 0.05, -1.6, 1.0, -2.6, TEAL), _b(1.4, 0.2, 0.05, -1.6, 1.6, -2.6, MUSTARD)]),
					_s([_b(1.0, 0.9, 0.5, 2.25, 0.0, -2.7, WOODD), _b(0.9, 0.6, 0.4, 2.25, 0.9, -2.7, SKY)])]
				5: return [_d([_b(1.8, 0.12, 4.0, 4.1, -0.12, -0.4, WOOD), _b(0.06, 0.9, 4.0, 4.95, 0.0, -0.4, METAL)]), _s([_b(0.5, 1.1, 1.6, -2.7, 0.0, -0.2, WOOD), _b(0.55, 0.06, 1.7, -2.7, 1.1, -0.2, CREAM)])]
		"video":
			match lv:
				1: return [_s([_b(1.6, 0.7, 0.4, 0.0, 0.0, -2.7, WOODD), _b(1.4, 0.8, 0.1, 0.0, 0.7, -2.7, METALD), _b(1.25, 0.65, 0.02, 0.0, 0.78, -2.64, SCREEN)]), _sofa(0.0, 0.3, 2.0, PLUM, true)]
				2: return [_d([_b(3.0, 1.8, 0.04, 0.0, 0.9, -2.95, WHITE)]), _d([_b(0.4, 0.2, 0.4, 0.0, 2.35, 2.3, METALD), _b(0.05, 0.4, 0.05, 0.0, 2.6, 2.3, METAL)])]
				3: return [_s([_b(1.4, 1.0, 0.05, 2.3, 0.9, -2.2, GREEN, -0.35), _b(0.05, 0.9, 0.05, 1.7, 0.0, -2.2, METAL), _b(0.05, 0.9, 0.05, 2.9, 0.0, -2.2, METAL)])]
				4: return [_desk(2.2, 0.4, 1.6, 0.7, 1.5708), _d([_b(0.5, 0.35, 0.05, 2.2, 0.8, -0.1, METALD, 1.5708), _b(0.45, 0.28, 0.02, 2.17, 0.84, -0.1, SCREEN, 1.5708), _b(0.5, 0.35, 0.05, 2.2, 0.8, 0.9, METALD, 1.5708), _b(0.45, 0.28, 0.02, 2.17, 0.84, 0.9, SCREEN, 1.5708)])]
				5: return [_s([_b(2.4, 0.35, 0.9, 0.0, 0.0, 1.7, NAVY), _b(0.5, 0.5, 0.5, -0.8, 0.35, 1.7, RED), _b(0.5, 0.5, 0.5, 0.0, 0.35, 1.7, RED), _b(0.5, 0.5, 0.5, 0.8, 0.35, 1.7, RED)]),
					_d([_b(0.05, 1.2, 2.0, -2.9, 1.0, -1.0, NAVY), _b(0.03, 0.8, 1.6, -2.86, 1.2, -1.0, NEON)])]
		"coach":
			match lv:
				1: return [_desk(-1.0, -2.4, 1.6, 0.7), _s([_b(0.5, 0.45, 0.5, -1.0, 0.0, -1.45, METALD), _b(0.5, 0.5, 0.08, -1.0, 0.45, -1.2, METALD)]), _d([_b(1.2, 0.9, 0.06, 0.9, 1.1, -2.95, CHALK), _b(0.2, 0.1, 0.01, 0.6, 1.5, -2.9, GREEN), _b(0.2, 0.1, 0.01, 0.9, 1.5, -2.9, MUSTARD), _b(0.2, 0.1, 0.01, 1.2, 1.5, -2.9, RED)])]
				2: return [_d([_b(0.5, 0.35, 0.05, -1.0, 0.85, -2.5, METALD), _b(0.45, 0.28, 0.02, -1.0, 0.88, -2.47, SCREEN), _b(0.3, 0.1, 0.22, -0.2, 0.79, -2.3, MUSTARD), _b(0.3, 0.1, 0.22, -0.2, 0.89, -2.3, SKY)])]
				3: return [_s([_b(0.05, 1.5, 1.6, -2.55, 0.5, -0.4, WHITE), _b(0.03, 0.5, 1.2, -2.5, 1.0, -0.4, GREEN), _b(0.05, 0.5, 0.05, -2.55, 0.0, -0.9, METAL), _b(0.05, 0.5, 0.05, -2.55, 0.0, 0.1, METAL)])]
				4: return [_s([_b(1.4, 2.3, 0.35, 2.2, 0.0, -2.8, WOODD), _b(1.2, 0.25, 0.05, 2.2, 0.5, -2.6, RED), _b(1.2, 0.25, 0.05, 2.2, 1.1, -2.6, TEAL), _b(1.2, 0.25, 0.05, 2.2, 1.7, -2.6, MUSTARD)]),
					_d([_b(0.5, 0.4, 0.03, -1.6, 1.6, -2.95, CREAM), _b(0.5, 0.4, 0.03, -1.0, 1.6, -2.95, CREAM), _b(0.5, 0.4, 0.03, -0.4, 1.6, -2.95, CREAM)])]
				5: return [_s([_b(1.8, 0.8, 1.1, 0.5, 0.0, 0.6, WOODD), _b(1.7, 0.04, 1.0, 0.5, 0.8, 0.6, CLUB), _b(0.1, 0.1, 0.1, 0.2, 0.84, 0.4, RED), _b(0.1, 0.1, 0.1, 0.9, 0.84, 0.8, GOLD)]),
					_s([_b(0.4, 1.0, 1.8, -2.8, 0.0, -1.9, WOOD), _c(0.1, 0.25, -2.7, 1.0, -2.2, GOLD), _c(0.1, 0.25, -2.7, 1.0, -1.6, GOLD)])]
		"med":
			match lv:
				1: return [_s([_b(0.8, 0.55, 1.9, -1.4, 0.0, -1.95, CLINIC), _b(0.7, 0.1, 0.5, -1.4, 0.55, -2.6, TEAL)]), _d([_b(0.5, 0.5, 0.15, 1.0, 1.4, -2.9, WHITE), _b(0.2, 0.06, 0.02, 1.0, 1.62, -2.81, RED), _b(0.06, 0.2, 0.02, 1.0, 1.55, -2.81, RED)])]
				2: return [_d([_c(0.04, 1.8, -0.45, 0.0, -2.5, METAL), _b(0.4, 0.2, 0.3, -0.45, 1.7, -2.4, WHITE)]), _s([_b(0.5, 0.9, 0.4, 0.4, 0.0, -2.55, CLINIC), _b(0.4, 0.2, 0.02, 0.4, 0.6, -2.34, SCREEN)])]
				3: return [_s([_b(0.8, 0.25, 2.0, -1.4, 0.55, -1.95, TEAL), _b(0.7, 0.12, 0.5, -1.4, 0.8, -1.2, TEAL.lightened(0.2))])]
				4: return [_s([_b(0.9, 0.55, 1.6, 1.45, 0.0, -2.0, SKY), _b(0.8, 0.04, 1.5, 1.45, 0.55, -2.0, WHITE)]), _s([_b(0.9, 0.55, 1.6, 2.45, 0.0, -2.0, SKY), _b(0.8, 0.04, 1.5, 2.45, 0.55, -2.0, WHITE)])]
				5: return [_s([_b(2.4, 0.5, 2.2, 0.9, 0.0, 0.9, TEAL), _b(2.0, 0.04, 1.8, 0.9, 0.46, 0.9, SKY)])]
		"hall":
			match lv:
				1: return [_s([_b(2.0, 1.0, 0.7, 0.0, 0.0, -1.5, CLUB), _b(2.1, 0.06, 0.8, 0.0, 1.0, -1.5, WOOD)]), _d([_b(1.0, 1.3, 0.06, -2.1, 0.9, -2.4, CORK, 0.26), _b(0.2, 0.25, 0.01, -2.2, 1.5, -2.36, WHITE, 0.26), _b(0.2, 0.25, 0.01, -1.9, 1.3, -2.36, MUSTARD, 0.26)])]
				2: return [_s([_b(1.0, 2.0, 0.08, 2.3, 0.0, -2.3, NAVY), _b(0.7, 0.5, 0.01, 2.3, 1.3, -2.25, GOLD)])]
				3: return [_s([_b(0.5, 1.9, 1.6, -2.8, 0.0, -0.2, GLASS), _c(0.1, 0.3, -2.8, 1.0, -0.6, GOLD), _c(0.1, 0.3, -2.8, 1.0, 0.2, GOLD), _c(0.1, 0.2, -2.8, 0.4, -0.2, GOLD)])]
				4: return [_desk(1.4, 0.4, 1.6, 0.8), _s([_b(0.45, 0.45, 0.45, 1.4, 0.0, 1.35, METALD)]), _s([_b(0.45, 0.45, 0.45, 1.4, 0.0, -0.5, METALD)])]
				5: return [_d([_b(3.6, 2.2, 0.08, 0.0, 0.6, -2.95, NAVY), _b(0.3, 0.4, 0.02, -1.2, 1.5, -2.9, GOLD), _b(0.3, 0.4, 0.02, -0.6, 1.5, -2.9, GOLD), _b(0.3, 0.4, 0.02, 0.0, 1.5, -2.9, GOLD), _b(0.3, 0.4, 0.02, 0.6, 1.5, -2.9, GOLD), _b(0.3, 0.4, 0.02, 1.2, 1.5, -2.9, GOLD)])]
	return []


## Where what a level adds will stand, as rects in the room's own frame (x, z): one for each object that has
## something on the floor (a thing hung on the wall has none) - for the chalk marks «здесь будет» and the
## scaffolding. Kept inside the room and never thinner than half a metre.
static func marks(room: String, lv: int) -> Array:
	var out := _marks(room, lv, true)
	return out if not out.is_empty() else _marks(room, lv, false)   # all of it is on a desk or a wall: mark its shadow on the floor


static func _marks(room: String, lv: int, floor_only: bool) -> Array:
	var out: Array = []
	for it in items(room, lv):
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for s in it["boxes"]:
			if floor_only and _bottom_of(s) > 0.5:
				continue
			var r := _rect_of(s)
			lo = Vector2(minf(lo.x, r.position.x), minf(lo.y, r.position.y))
			hi = Vector2(maxf(hi.x, r.end.x), maxf(hi.y, r.end.y))
		if lo.x == INF:
			continue
		var rect := Rect2(lo, hi - lo).intersection(Rect2(-SIZE + 0.1, -SIZE + 0.1, SIZE * 2.0 - 0.2, SIZE * 2.0 - 0.2))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var c := rect.get_center()
		rect = Rect2(c - Vector2(maxf(rect.size.x, 0.5), maxf(rect.size.y, 0.5)) * 0.5, Vector2(maxf(rect.size.x, 0.5), maxf(rect.size.y, 0.5)))
		out.append(rect.grow(0.06))
	return out


static func _bottom_of(s: Array) -> float:
	match String(s[0]):
		"b":
			return float(s[5])
		"c":
			return float(s[4])
		"o":
			return float(s[3]) - float(s[1])
	return 0.0


static func _rect_of(s: Array) -> Rect2:
	match String(s[0]):
		"b":
			var yaw := float(s[8])
			var w := float(s[1])
			var d := float(s[3])
			if absf(sin(yaw)) > 0.7:   # a quarter turn swaps the sides
				var t := w
				w = d
				d = t
			return Rect2(float(s[4]) - w * 0.5, float(s[6]) - d * 0.5, w, d)
		"c":
			var r := float(s[1])
			return Rect2(float(s[3]) - r, float(s[5]) - r, r * 2.0, r * 2.0)
		"o":
			var r2 := float(s[1])
			return Rect2(float(s[2]) - r2, float(s[4]) - r2, r2 * 2.0, r2 * 2.0)
	return Rect2()


## The walk's obstacles in the room's own frame: one rect per solid object (what it adds up to this level).
static func solids(room: String, built: int) -> Array:
	var out: Array = []
	for lv in range(1, built + 1):
		for it in items(room, lv):
			if not bool(it["solid"]):
				continue
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for s in it["boxes"]:
				if String(s[0]) == "b" and float(s[5]) > 0.5:
					continue   # up on the wall or a shelf
				var r := _rect_of(s)
				lo = Vector2(minf(lo.x, r.position.x), minf(lo.y, r.position.y))
				hi = Vector2(maxf(hi.x, r.end.x), maxf(hi.y, r.end.y))
			if lo.x != INF:
				out.append(Rect2(lo, hi - lo))
	return out


## The shapes of a room at `built` levels, plus the chalk marks of the next one and the scaffolding of the one on
## the build, as one mesh (null when there is nothing to draw). `side`: +1 the plan as written, -1 mirrored (a
## room west of the hall). `floor`: the room's floor colour, the marks are a darker patch of it.
static func mesh(room: String, built: int, mark: int, scaffold: int, side: int, floor := Color("8f8a80")) -> ArrayMesh:
	var sb := ClubShapes.new()
	var n := 0
	for lv in range(1, built + 1):
		for it in items(room, lv):
			for s in it["boxes"]:
				_add(sb, s, side)
				n += 1
	if mark >= 1 and mark <= HouseRooms.MAX_LEVEL:
		for r in marks(room, mark):
			_mark(sb, r, side, floor.darkened(0.5))
			n += 1
	if scaffold >= 1:
		for r in marks(room, scaffold):
			_scaffold(sb, r, side)
			n += 1
	return sb.build() if n > 0 else null   # nothing to draw: no mesh (a surface with no vertices is an error)


static func _add(sb: ClubShapes, s: Array, side: int) -> void:
	match String(s[0]):
		"b":
			sb.box(Vector3(float(s[1]), float(s[2]), float(s[3])), Vector3(float(s[4]) * side, float(s[5]) + float(s[2]) * 0.5, float(s[6])), s[7], float(s[8]) * side)
		"c":
			sb.cyl(float(s[1]), float(s[1]), float(s[2]), Vector3(float(s[3]) * side, float(s[4]) + float(s[2]) * 0.5, float(s[5])), s[6], 8)
		"o":
			sb.ball(float(s[1]), Vector3(float(s[2]) * side, float(s[3]), float(s[4])), s[5])


## «Здесь будет»: a dark patch of floor with a chalk outline.
static func _mark(sb: ClubShapes, r: Rect2, side: int, col: Color) -> void:
	var c := r.get_center()
	var cx := c.x * side
	sb.box(Vector3(r.size.x, 0.02, r.size.y), Vector3(cx, 0.012, c.y), col)
	var t := 0.05
	sb.box(Vector3(r.size.x, 0.022, t), Vector3(cx, 0.016, r.position.y), CHALK_COL)
	sb.box(Vector3(r.size.x, 0.022, t), Vector3(cx, 0.016, r.end.y), CHALK_COL)
	sb.box(Vector3(t, 0.022, r.size.y), Vector3(r.position.x * side, 0.016, c.y), CHALK_COL)
	sb.box(Vector3(t, 0.022, r.size.y), Vector3(r.end.x * side, 0.016, c.y), CHALK_COL)


## Scaffolding on the spot of a level being built: four poles and two planks.
static func _scaffold(sb: ClubShapes, r: Rect2, side: int) -> void:
	var c := r.get_center()
	var cx := c.x * side
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			sb.cyl(0.05, 0.05, 1.9, Vector3(cx + sx * r.size.x, 0.95, c.y + sz * r.size.y), WOOD, 5)
	for y in [0.6, 1.3]:
		sb.box(Vector3(r.size.x + 0.1, 0.06, 0.12), Vector3(cx, y, c.y - r.size.y * 0.5), WOODD)
		sb.box(Vector3(r.size.x + 0.1, 0.06, 0.12), Vector3(cx, y, c.y + r.size.y * 0.5), WOODD)
	sb.box(Vector3(0.12, 0.06, r.size.y), Vector3(cx - r.size.x * 0.5, 1.3, c.y), WOODD)
	sb.box(Vector3(0.12, 0.06, r.size.y), Vector3(cx + r.size.x * 0.5, 1.3, c.y), WOODD)
