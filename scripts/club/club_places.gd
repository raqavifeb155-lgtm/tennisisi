class_name ClubPlaces
## The places of the club (docs/club/CLUB_BRIEF.md, section 2): where each stands, its
## circle on the ground, the one button it shows and when it opens. Data only; ClubWorld
## builds them, Club and ClubHud use them.
##
## Coordinates: the main court's centre is the origin, -z toward the river (as in
## scenery.gd). The camera looks north from the gate, as the old menu did.
##   unlock  ""        open from the start
##           "played"  after the first run
##           "title"   after the first title
##           "never"   not built yet (a sign stands there instead of a button)
##   cam     a room's own camera framing (pavilions): "pos" and "look", else the follow cam

const LIST := [
	{
		"id": "court", "name": "Главный корт", "pos": Vector3(0, 0, 14.0), "r": 2.2,
		"action": "club_tournament", "label": "Турнир", "unlock": "", "sign": "",
	},
	{
		"id": "coach", "name": "Тренерская", "pos": Vector3(16, 0, 26), "r": 1.8,
		"action": "character", "label": "Навыки", "unlock": "", "sign": "",
		"cam": {"pos": Vector3(16, 10.5, 35.0), "look": Vector3(16, 0.4, 25.6)},
	},
	{
		"id": "gate", "name": "Вход", "pos": Vector3(0, 0, 36), "r": 1.8,
		"action": "", "label": "Прораб", "unlock": "never", "sign": "Стройка · скоро",
	},
	{
		"id": "locker", "name": "Раздевалка", "pos": Vector3(-14, 0, 26), "r": 1.8,
		"action": "locker", "label": "Раздевалка", "unlock": "played", "sign": "Раздевалка · после первого забега",
		"cam": {"pos": Vector3(-14, 10.5, 35.0), "look": Vector3(-14, 0.4, 25.6)},
	},
	{
		"id": "trophy", "name": "Трофейная", "pos": Vector3(-18, 0, -26), "r": 1.8,
		"action": "", "label": "Трофейная", "unlock": "never", "sign": "Трофейная · после первого забега",
	},
	{
		"id": "bar", "name": "Бар", "pos": Vector3(20, 0, -30), "r": 1.8,
		"action": "bets", "label": "Тотализатор", "unlock": "never", "sign": "Бар · после первого титула",
	},
	{
		"id": "arena", "name": "Арена", "pos": Vector3(-22, 0, 0), "r": 2.0,
		"action": "", "label": "Арена", "unlock": "never", "sign": "Арена · скоро",
	},
	{
		"id": "board", "name": "Доска-табло", "pos": Vector3(22, 0, -14), "r": 1.8,
		"action": "", "label": "Онлайн", "unlock": "never", "sign": "Онлайн · скоро",
	},
]


static func find(id: String) -> Dictionary:
	for p in LIST:
		if p["id"] == id:
			return p
	return {}


## Whether the place works yet (has its button) for a player with this progress.
static func is_open(place: Dictionary, played: int, titles: int) -> bool:
	match String(place.get("unlock", "never")):
		"":
			return true
		"played":
			return played >= 1
		"title":
			return titles >= 1
	return false


## The place whose circle holds `pos`, or {}.
static func at(pos: Vector3) -> Dictionary:
	for p in LIST:
		var c: Vector3 = p["pos"]
		if Vector2(pos.x - c.x, pos.z - c.z).length() <= float(p["r"]):
			return p
	return {}
