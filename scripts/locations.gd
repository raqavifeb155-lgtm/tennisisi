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


# --- The islands (v0.2 A-4, spec 2026-10-08-v02-hub-economy 4) ------------------------
## The order they open in (= the tournament's tier 0..3): New York, Spain, England, Paris.
const ORDER := ["park", "clay", "grass", "paris"]
## Per tier: the opponents' strength, the prize money, the rarity shift of their gear.
const TIERS := [
	{"power": 1.0, "prize": 1.0, "epic": 0.0, "legendary": 0.0},
	{"power": 1.12, "prize": 1.3, "epic": 0.01, "legendary": 0.005},
	{"power": 1.25, "prize": 1.6, "epic": 0.02, "legendary": 0.010},
	{"power": 1.4, "prize": 2.0, "epic": 0.03, "legendary": 0.015},
]


static func tier(id: String) -> int:
	return maxi(0, ORDER.find(id))


static func tier_info(id: String) -> Dictionary:
	return TIERS[tier(id)]


static func power(id: String) -> float:
	return float(tier_info(id)["power"])


static func prize_mult(id: String) -> float:
	return float(tier_info(id)["prize"])


## Open: New York always; Spain for any title; England for a title in Spain; Paris for a
## title in England. The player's own club is always open.
static func unlocked(id: String) -> bool:
	var i := ORDER.find(id)
	if i <= 0:
		return true
	if i == 1:
		return SaveData.titles >= 1 or not SaveData.titles_by_loc.is_empty()
	return int(SaveData.titles_by_loc.get(ORDER[i - 1], 0)) >= 1


## What opens it, for the lock: "за первый титул", "за титул в Испании".
static func unlock_hint(id: String) -> String:
	var i := ORDER.find(id)
	if i <= 0:
		return ""
	if i == 1:
		return "за первый титул"
	return "за титул в %s" % _where(ORDER[i - 1])


static func _where(id: String) -> String:
	return {"park": "Нью-Йорке", "clay": "Испании", "grass": "Англии", "paris": "Париже"}.get(id, String(find(id)["name"]))


## The best open island (by tier).
static func best_unlocked() -> String:
	var best := "park"
	for id in ORDER:
		if unlocked(id):
			best = id
	return best
