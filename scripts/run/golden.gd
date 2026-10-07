class_name Golden
## Rare golden opponents (v0.2 A-4, HOW_TO_FISH_TAKEAWAYS 3.3): about one opponent in 50
## walks out in a golden kit with a legendary (or better) item in hand, and beating him
## pays double. The ones you beat go into a collection — "поймай золотого Синнера".
## The first opponent of a run (the tutorial) is never golden. Shadow variants come later.

const CHANCE := 0.02
const KIT := 10                   # Looks.KIT index: the gold of the kit
const GOLD_X := 2                 # prize money for beating him


## His look in gold: the same face and hair, a golden shirt, shorts and accents.
static func look(base: Dictionary) -> Dictionary:
	var l := base.duplicate()
	for k in ["shirt", "shorts", "accent"]:
		l[k] = KIT
	return l


static func note_beaten(id: String) -> void:
	if not SaveData.golden.has(id):
		SaveData.golden.append(id)


## "Золотые: 1 из 5"
static func collection_text() -> String:
	return "Золотые соперники: %d из %d" % [SaveData.golden.size(), Opponents.ROSTER.size() - 1]
