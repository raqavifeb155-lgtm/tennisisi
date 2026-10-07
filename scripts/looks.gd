class_name Looks
## What a player looks like: skin, hair, beard, headwear and kit colours. A look is a
## small Dictionary of palette indices, so it saves as is and 100 players cost nothing:
##   {"skin": 2, "hair": 2, "hair_color": 1, "beard": 0, "head": 1,
##    "shirt": 12, "shorts": 3, "accent": 12}
## Athlete builds the body from it (see Athlete.set_look); the editor (LookEditor) and
## the opponents (Opponents.ROSTER "look") use the same keys.

const SKIN := [
	Color(0.98, 0.87, 0.78), Color(0.96, 0.8, 0.68), Color(0.93, 0.76, 0.62), Color(0.87, 0.68, 0.52),
	Color(0.8, 0.6, 0.45), Color(0.7, 0.5, 0.36), Color(0.6, 0.41, 0.29), Color(0.48, 0.32, 0.22),
	Color(0.38, 0.25, 0.17), Color(0.28, 0.18, 0.12),
]

const HAIR_COLORS := [
	Color(0.07, 0.06, 0.06), Color(0.18, 0.12, 0.08), Color(0.3, 0.2, 0.12), Color(0.42, 0.26, 0.15),
	Color(0.55, 0.4, 0.26), Color(0.68, 0.55, 0.36), Color(0.85, 0.72, 0.45), Color(0.93, 0.9, 0.8),
	Color(0.78, 0.4, 0.18), Color(0.55, 0.22, 0.12), Color(0.6, 0.6, 0.6), Color(0.2, 0.45, 0.9),
]

## Shirts, shorts and the headwear share one palette.
const KIT := [
	Color(0.96, 0.96, 0.96), Color(0.72, 0.74, 0.78), Color(0.3, 0.31, 0.35), Color(0.14, 0.15, 0.2),
	Color(0.22, 0.28, 0.42), Color(0.2, 0.36, 0.85), Color(0.45, 0.72, 0.95), Color(0.1, 0.55, 0.55),
	Color(0.15, 0.5, 0.25), Color(0.62, 0.85, 0.2), Color(0.98, 0.84, 0.2), Color(0.98, 0.55, 0.15),
	Color(0.92, 0.36, 0.26), Color(0.8, 0.14, 0.16), Color(0.95, 0.5, 0.7), Color(0.5, 0.28, 0.75),
]

enum Hair { BALD, BUZZ, SHORT, SIDE_PART, QUIFF, SPIKY, MESSY, CURLY, AFRO, LONG, PONYTAIL, BUN, MOHAWK, MULLET, DREADS }
const HAIR_NAMES := ["Лысый", "Ёжик", "Короткая", "Пробор", "Кок", "Иглы", "Растрёпанная", "Кудряшки",
	"Афро", "Длинные", "Хвост", "Пучок", "Ирокез", "Маллет", "Дреды"]

enum Beard { NONE, STUBBLE, MOUSTACHE, GOATEE, SHORT, FULL }
const BEARD_NAMES := ["Нет", "Щетина", "Усы", "Эспаньолка", "Борода", "Густая"]

enum Head { NONE, CAP, CAP_BACK, HEADBAND, VISOR }
const HEAD_NAMES := ["Нет", "Кепка", "Кепка назад", "Повязка", "Козырёк"]

## Key -> how many options it has (the editor and sanitize use it).
const SIZES := {
	"skin": 10, "hair": 15, "hair_color": 12, "beard": 6, "head": 5,
	"shirt": 16, "shorts": 16, "accent": 16,
}

const DEFAULT := {"skin": 2, "hair": 2, "hair_color": 2, "beard": 0, "head": 1, "shirt": 12, "shorts": 3, "accent": 12}


## A complete, valid look: missing or broken keys fall back to the default.
static func sanitize(look) -> Dictionary:
	var out := DEFAULT.duplicate()
	if look is Dictionary:
		for k in SIZES:
			if look.has(k):
				out[k] = clampi(int(look[k]), 0, SIZES[k] - 1)
	return out


## The look of an old caller that only knew the shirt colour.
static func from_shirt(c: Color) -> Dictionary:
	var look := DEFAULT.duplicate()
	look["shirt"] = nearest_kit(c)
	look["accent"] = look["shirt"]
	return look


static func nearest_kit(c: Color) -> int:
	var best := 0
	var best_d := INF
	for i in KIT.size():
		var k: Color = KIT[i]
		var d := Vector3(k.r - c.r, k.g - c.g, k.b - c.b).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


static func skin(look: Dictionary) -> Color:
	return SKIN[int(look["skin"])]


static func hair_color(look: Dictionary) -> Color:
	return HAIR_COLORS[int(look["hair_color"])]


static func kit(look: Dictionary, key: String) -> Color:
	return KIT[int(look[key])]


## A random look: everyday colours are more likely than the loud ones.
static func random(rng: RandomNumberGenerator) -> Dictionary:
	var look := {}
	for k in SIZES:
		look[k] = rng.randi_range(0, SIZES[k] - 1)
	look["hair_color"] = rng.randi_range(0, 11) if rng.randf() < 0.1 else rng.randi_range(0, 9)
	if rng.randf() < 0.5:
		look["beard"] = 0
	look["accent"] = look["shirt"] if rng.randf() < 0.5 else look["accent"]
	return look
