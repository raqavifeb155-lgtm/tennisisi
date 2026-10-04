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
		"id": "grass", "name": "Англия", "surface": "grass", "surface_name": "трава",
		"desc": "Туманный Альбион. Мяч быстрый и низкий, подача рулит, можно поскользнуться",
		"scenery": "res://scripts/scenery_grass.gd", "tour": "Турнир на траве · Ройал Альбион",
	},
]


static func find(id: String) -> Dictionary:
	for l in LIST:
		if l["id"] == id:
			return l
	return LIST[0]
