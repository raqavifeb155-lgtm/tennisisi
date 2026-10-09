class_name HouseLayout
extends RefCounted
## The Academy house, room by room (stream art): the layout the stand viewer
## (tools/academy_room_shots.gd) builds and docs/academy/ART_BRIEF.md draws. A starting point
## for the house stream's anchors (HouseRooms): 8 rooms 6 x 6 m, the interior x, z in [-3, 3],
## the back wall at z = -3 (north), the hall-side wall at x = -3 with the door at z = +1.5,
## the front (z = +3) and the east wall (x = +3) are cut away for the dolls'-house camera.
## Spots are (x, z, yaw degrees, y): a model faces +z at yaw 0, and at yaw a it faces
## (sin a, cos a): 90 = toward +x (a thing against the west wall), 180 = toward -z (to the back wall).
##
## An item is {from, until, ids, spots}: it stands from room level `from` up to `until`
## (inclusive, default 5); `ids` is one id, or {level: id}: the id of the greatest key <= the room
## level (a bed gets better, a kitchen grows); `spots` are where. The level's own new object is the
## one with that `from` - the five rows per room of the spec's table (2.2) read down `from`.

const ROOM_ORDER := ["dorm", "canteen", "gym", "video", "coach", "med", "lounge", "hall"]
## building level that opens the room (spec 2.1)
const OPENS := {"dorm": 1, "canteen": 1, "gym": 2, "lounge": 2, "video": 3, "coach": 3, "med": 4, "hall": 5}

## The spec's 40 objects: room -> title per level (what the level adds), and the ids drawn for it.
const TITLES := {
	"dorm": ["Две койки и тумбочка", "Двухъярусная кровать, шкаф", "Тумбочки с лампами, шторы", "Ортопедические матрасы, коврик", "Отдельные «номера»: ночник, балкон"],
	"canteen": ["Стол, лавки, холодильник", "Плита, посуда, чайник", "Кухонный остров, стойка раздачи", "Витрина с фруктами, меню диетолога", "Шеф-повар, зал на 8 мест"],
	"gym": ["Коврик, гантели, фитболы", "Турник, скакалки, лестница", "Две беговые дорожки", "Силовая рама, зеркала, штанги", "Кроссфит-зал с табло и музыкой"],
	"video": ["Телевизор на тумбе, диван", "Проектор и экран", "Тактическая доска", "Монтажная: два монитора", "Кинозал, статистика на стене"],
	"coach": ["Стол, стул, доска с режимами", "Компьютер, папки с делами", "Стенд с графиками роста", "Книжный шкаф, дипломы", "Штаб: стратегическая карта, кубки"],
	"med": ["Кушетка, аптечка", "Лампа и физиоаппарат", "Массажный стол", "Ванны со льдом", "Спа-бассейн"],
	"lounge": ["Диван и телевизор", "Стол для настольного тенниса", "Приставка и пуфы", "Библиотека и аквариум", "Терраса с видом на корт, мини-бар"],
	"hall": ["Стойка и доска кандидатов", "Стенд со спонсором", "Шкаф с кубками академии", "Агентский стол", "Зал славы: выпускники, ракетки"],
}

## Floor and wall paint by room (worn at level 1, fresh at 5: see `paint`).
const LOOK := {
	"dorm": {"floor": Color("b99a73"), "wall": Color("e9d9c3"), "trim": Color("a9c5a0")},
	"canteen": {"floor": Color("c9b79a"), "wall": Color("f0e3c8"), "trim": Color("e8b84a")},
	"gym": {"floor": Color("5e6670"), "wall": Color("d9dde0"), "trim": Color("2a54a3")},
	"video": {"floor": Color("5a4a5c"), "wall": Color("6b5a7a"), "trim": Color("1e2a44")},
	"coach": {"floor": Color("a98764"), "wall": Color("e3d6c3"), "trim": Color("6b4a32")},
	"med": {"floor": Color("cfd8dc"), "wall": Color("eef4f4"), "trim": Color("4a8f87")},
	"lounge": {"floor": Color("b5654a"), "wall": Color("e8d3b8"), "trim": Color("3fb8af")},
	"hall": {"floor": Color("8f8a80"), "wall": Color("f4ead5"), "trim": Color("2a54a3")},
}
## x of the window in the back wall (0 = none), the window's width
const WINDOWS := {"dorm": [0.0, 2.2], "canteen": [-2.0, 1.4], "gym": [2.0, 1.6], "video": [0.0, 0.0], "coach": [-1.0, 0.0],
		"med": [1.6, 1.4], "lounge": [0.0, 0.0], "hall": [0.0, 0.0]}


static func _s(x: float, z: float, yaw := 0.0, y := 0.0) -> Vector4:
	return Vector4(x, z, yaw, y)


static func _it(from: int, ids, spots: Array, until := 5) -> Dictionary:
	return {"from": from, "until": until, "ids": ids, "spots": spots}


## The items of a room.
static func items(room: String) -> Array:
	match room:
		"dorm":
			return [
				_it(1, {1: "bed_1", 3: "bed_2", 4: "bed_3", 5: "bed_4"}, [_s(-2.2, -2.05), _s(-0.3, -2.05)]),
				_it(1, {1: "nightstand_1", 3: "nightstand_3"}, [_s(-1.25, -2.75)]),
				_it(2, "bunk_2", [_s(1.5, -2.05)]),
				_it(2, "wardrobe_2", [_s(2.5, -2.7)]),
				_it(3, "nightstand_3", [_s(0.62, -2.75)]),
				_it(3, "curtain_3", [_s(0.0, -2.9)]),
				_it(4, "rug_a", [_s(-0.4, 0.5)]),
				_it(5, "partition_5", [_s(-1.25, -1.2, 90)]),
				_it(5, "nightlight_5", [_s(-1.25, -2.75, 0, 0.58)]),
				_it(5, "balcony_5", [_s(3.75, -0.6, 90)]),
			]
		"canteen":
			return [
				_it(1, "bench_1", [_s(0.0, 0.4), _s(0.0, 1.9)], 1),
				_it(1, "fridge_1", [_s(-2.5, -2.65)], 1),
				_it(1, {1: "table_1", 2: "table_2", 3: "table_3"}, [_s(0.0, 1.15)], 4),
				_it(2, {2: "kitchen_2", 3: "kitchen_3", 4: "kitchen_4"}, [_s(0.0, -2.66)]),
				_it(2, "dishes_2", [_s(-0.6, -2.66, 0, 0.92)]),
				_it(2, "kettle_2", [_s(1.4, -2.66, 0, 0.95)]),
				_it(2, {2: "chair_2", 3: "chair_3"}, [_s(-0.55, 0.4), _s(0.55, 0.4), _s(-0.55, 1.9, 180), _s(0.55, 1.9, 180)], 4),
				_it(3, "kitchen_island_3", [_s(0.0, -1.05)]),
				_it(3, "serving_3", [_s(2.65, 0.3, -90)]),
				_it(4, "fruit_stand_4", [_s(-2.55, -1.0, 90)]),
				_it(4, "menu_board_4", [_s(2.4, -1.75, -25)]),
				_it(5, "table_4", [_s(-1.3, 1.3), _s(1.1, 1.3)]),
				_it(5, "chair_4", [_s(-1.85, 0.5), _s(-0.75, 0.5), _s(0.55, 0.5), _s(1.65, 0.5), _s(-1.85, 2.1, 180), _s(-0.75, 2.1, 180), _s(0.55, 2.1, 180), _s(1.65, 2.1, 180)]),
				_it(5, "chef_5", [_s(1.9, -1.85, 180)]),
			]
		"gym":
			return [
				_it(1, "mat_1", [_s(-2.0, 0.6), _s(-1.15, 0.6)]),
				_it(1, "dumbbells_1", [_s(1.5, -2.5)]),
				_it(1, "fitball_1", [_s(2.15, -1.7)]),
				_it(2, "pullup_2", [_s(-2.25, -2.3)]),
				_it(2, "ladder_2", [_s(0.6, 0.5)]),
				_it(2, "jumprope_2", [_s(2.2, -2.95)]),
				_it(3, "treadmill_3", [_s(-1.1, -1.9), _s(0.0, -1.9)]),
				_it(4, "mirror_4", [_s(-0.55, -2.95)]),
				_it(4, "rack_4", [_s(1.95, 0.5, -90)]),
				_it(4, "barbell_4", [_s(1.9, 2.2)]),
				_it(5, "scoreboard_5", [_s(-2.9, -1.2, 90)]),
				_it(5, "speaker_5", [_s(-2.4, 2.6, 45)]),
				_it(5, "plyo_5", [_s(0.0, 2.4)]),
			]
		"video":
			return [
				_it(1, "tv_1", [_s(0.0, -2.7)], 1),
				_it(1, {1: "sofa_1", 2: "sofa_2", 3: "sofa_3"}, [_s(0.0, 0.3, 180)], 4),
				_it(2, "screen_2", [_s(0.0, -2.95)]),
				_it(2, "projector_2", [_s(0.0, 2.3)]),
				_it(3, "tacticboard_3", [_s(2.3, -2.2, -20)]),
				_it(4, "editdesk_4", [_s(2.2, 0.4, -90)]),
				_it(5, "cinema_5", [_s(0.0, 0.4, 180), _s(0.0, 1.7, 180, 0.22)]),
				_it(5, "statswall_5", [_s(-2.9, -1.0, 90)]),
			]
		"coach":
			return [
				_it(1, {1: "desk_1", 2: "desk_2", 3: "desk_3", 4: "desk_4"}, [_s(-1.0, -2.4)], 5),
				_it(1, "chair_office_1", [_s(-1.0, -1.45, 180)]),
				_it(1, "modesboard_1", [_s(0.9, -2.95)]),
				_it(2, "folders_2", [_s(-0.2, -2.3, 0, 0.78)]),
				_it(3, "chartstand_3", [_s(-2.55, -0.4, 90)]),
				_it(4, "bookcase_4", [_s(2.2, -2.8)]),
				_it(4, "diplomas_4", [_s(-1.0, -2.95)]),
				_it(5, "strategymap_5", [_s(0.5, 0.6)]),
				_it(5, "cups_5", [_s(-2.9, -1.9, 90)]),
			]
		"med":
			return [
				_it(1, "medcouch_1", [_s(-1.4, -1.95)], 2),
				_it(1, "firstaid_1", [_s(1.0, -2.95)]),
				_it(2, "physiolamp_2", [_s(-0.45, -2.5)]),
				_it(2, "physio_2", [_s(0.4, -2.55)]),
				_it(3, "massage_3", [_s(-1.4, -1.95)]),
				_it(4, "icebath_4", [_s(1.45, -2.0), _s(2.45, -2.0)]),
				_it(5, "spapool_5", [_s(0.9, 0.9)]),
			]
		"lounge":
			return [
				_it(1, "tv_1", [_s(0.7, -2.7)], 2),
				_it(1, {1: "sofa_1", 2: "sofa_2", 3: "sofa_3", 4: "sofa_3", 5: "sofa_4"}, [_s(0.7, -0.4, 180)]),
				_it(2, "pingpong_2", [_s(-1.2, 1.1)]),
				_it(3, "console_3", [_s(0.7, -2.7)]),
				_it(3, "pouf_3", [_s(2.1, 0.9)]),
				_it(4, "library_4", [_s(-1.6, -2.8)]),
				_it(4, "aquarium_4", [_s(2.25, -2.7)]),
				_it(5, "terrace_5", [_s(4.1, -0.4, 90)]),
				_it(5, "minibar_5", [_s(-2.7, -0.2, 90)]),
			]
		"hall":
			return [
				_it(1, "reception_1", [_s(0.0, -1.5)]),
				_it(1, "candidates_1", [_s(-2.1, -2.4, 15)]),
				_it(2, "sponsor_2", [_s(2.3, -2.3)]),
				_it(3, "trophycase_3", [_s(-2.8, -0.2, 90)]),
				_it(4, "agentdesk_4", [_s(1.4, 0.4)]),
				_it(5, "fame_5", [_s(0.0, -2.95)]),
			]
	return []


## The id of a slot at a room level ("" = not there).
static func id_at(item: Dictionary, level: int) -> String:
	if level < int(item["from"]) or level > int(item["until"]):
		return ""
	var ids = item["ids"]
	if ids is String:
		return ids
	var best := -1
	for k in ids:
		if int(k) <= level and int(k) > best:
			best = int(k)
	return "" if best < 0 else String(ids[best])


## Light figures and the one real Athlete of a room: {kind: "kid"/"athlete", id: figure id or pose name,
## at: Vector4 spot, from: level}. y is the seat / mattress height by level where it changes.
static func cast(room: String) -> Array:
	match room:
		"dorm":
			return [
				{"kind": "kid", "id": "kid_lie_a", "at": _s(-2.2, -2.05, 0, 0.0), "y": {1: 0.3, 3: 0.5, 4: 0.58, 5: 0.7}},
				{"kind": "kid", "id": "kid_sit_b", "at": _s(-0.3, -1.4, 180, 0.0), "y": {1: -0.12, 3: 0.0, 4: 0.05, 5: 0.15}},
				{"kind": "athlete", "id": "talk", "at": _s(1.6, 0.6, -150), "junior": 0.82},
			]
		"canteen":
			return [
				{"kind": "kid", "id": "kid_eat_a", "at": _s(-0.55, 0.4, 0), "y": {1: -0.0}},
				{"kind": "kid", "id": "kid_eat_b", "at": _s(0.55, 1.9, 180), "y": {1: 0.0}},
				{"kind": "athlete", "id": "eat", "at": _s(0.55, 0.4, 0), "junior": 0.9},
			]
		"gym":
			return [
				{"kind": "kid", "id": "kid_run_b", "at": _s(-1.1, -1.9, 0), "y": {3: 0.3}, "from": 3},
				{"kind": "kid", "id": "kid_stand_c", "at": _s(1.5, -1.6, -40)},
				{"kind": "athlete", "id": "squat", "at": _s(-1.6, 0.6, 0), "junior": 0.95},
			]
		"video":
			return [
				{"kind": "kid", "id": "kid_sit_a", "at": _s(-0.4, 0.2, 180), "y": {1: 0.0}},
				{"kind": "kid", "id": "kid_sit_c", "at": _s(0.45, 0.2, 180), "y": {1: 0.0}},
				{"kind": "athlete", "id": "talk", "at": _s(2.2, -0.9, -110), "junior": 0.85},
			]
		"coach":
			return [
				{"kind": "athlete", "id": "sit", "at": _s(-1.0, -1.45, 180), "junior": 1.0, "elder": true},
				{"kind": "kid", "id": "kid_stand_a", "at": _s(0.4, -0.6, -150)},
				{"kind": "kid", "id": "kid_stand_b", "at": _s(1.4, -0.3, 160)},
			]
		"med":
			return [
				{"kind": "kid", "id": "kid_lie_c", "at": _s(-1.4, -1.95, 0), "y": {1: 0.55, 3: 0.84}},
				{"kind": "kid", "id": "kid_sit_a", "at": _s(1.0, 0.2, 200), "y": {1: -0.0}},
				{"kind": "athlete", "id": "stand", "at": _s(0.3, -1.4, 160), "junior": 1.0, "elder": true},
			]
		"lounge":
			return [
				{"kind": "kid", "id": "kid_sit_a", "at": _s(0.2, -0.4, 180), "y": {1: 0.02}},
				{"kind": "kid", "id": "kid_sit_b", "at": _s(1.2, -0.4, 180), "y": {1: 0.02}},
				{"kind": "athlete", "id": "swing", "at": _s(-1.2, 2.3, 180), "junior": 0.9, "from": 2},
			]
		"hall":
			return [
				{"kind": "kid", "id": "kid_stand_a", "at": _s(0.0, -2.1, 0)},
				{"kind": "kid", "id": "kid_sit_c", "at": _s(1.4, 1.4, 180), "from": 4},
				{"kind": "athlete", "id": "talk", "at": _s(-0.2, 0.3, 160), "junior": 0.88},
			]
	return []


static func y_at(c: Dictionary, level: int) -> float:
	var ys = c.get("y", {})
	var best := -1
	for k in ys:
		if int(k) <= level and int(k) > best:
			best = int(k)
	return 0.0 if best < 0 else float(ys[best])
