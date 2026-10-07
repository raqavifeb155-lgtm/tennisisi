class_name Locations
## Where tournaments are played: each location has its scenery, court surface and
## ball physics (see BallPhysics.SURFACES and Athlete.surface).

const LIST := [
	{
		"id": "park", "name": "Нью-Йорк", "surface": "hard", "surface_name": "хард",
		"desc": "Набережная Ист-Ривер, летнее утро. Средняя скорость, честный отскок",
		"scenery": "res://scripts/scenery.gd", "tour": "Клубный турнир · Нью-Йорк",
	},
	{
		"id": "clay", "name": "Испания", "surface": "clay", "surface_name": "грунт",
		"desc": "Корты у моря на закате. Мяч медленный и высокий, крутка решает, скольжение и следы",
		"scenery": "res://scripts/scenery_clay.gd", "tour": "Турнир на грунте · Коста-дель-Соль",
	},
	{
		"id": "paris", "name": "Париж", "surface": "clay", "surface_name": "грунт",
		"desc": "Центральный корт Большого шлема: полные трибуны, медленный высокий отскок",
		"scenery": "res://scripts/scenery_chatrier.gd", "tour": "Большой шлем · Париж",
	},
	{
		"id": "grass", "name": "Англия", "surface": "grass", "surface_name": "трава",
		"desc": "Туманный Альбион. Мяч быстрый и низкий, подача рулит, можно поскользнуться",
		"scenery": "res://scripts/scenery_grass.gd", "tour": "Турнир на траве · Ройал Альбион",
	},
]

## Places that are not on the tournament map: the player's own club (docs/club). "sound":
## whose ambience plays there.
const PRIVATE := [
	{
		"id": "club", "name": "Свой клуб", "surface": "hard", "surface_name": "хард",
		"desc": "Твой корт на набережной Ист-Ривер", "sound": "park",
		"scenery": "res://scripts/club/club_world.gd", "tour": "Свой клуб",
	},
]


static func find(id: String) -> Dictionary:
	for l in LIST + PRIVATE:
		if l["id"] == id:
			return l
	return LIST[0]
