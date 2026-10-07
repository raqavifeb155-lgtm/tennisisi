class_name OppStamina
extends RefCounted
## The opponent's stamina as his "health" (ROGUELIKE_DESIGN 5.1): balls that make him run
## or take a heavy ball wear him down, the numbers fly out of him. Below 40% he is slower
## and misses more, the same tiredness the player has. Rests between points, at the
## change of ends and between sets. Pure model; RunHub feeds it and shows it.

const MAX := 100.0
const TIRED_BELOW := 40.0
const PER_METRE := 0.6            # stamina per metre run for the ball
const HEAVY_FROM := 90.0          # km/h: a ball faster than this is heavy to take
const PER_KMH := 0.05
const PERFECT_X := 1.5
const REST := {"point": 6.0, "change": 20.0, "set": 40.0}
const SLOW := 0.3                 # run speed lost when empty
const SKILL := 0.12               # AI skill lost when empty

var value := MAX


## What one ball cost him: the metres he ran for it, how fast it came, how well it was
## hit (a PERFECT x1.5); run_mult from the player's gear (heavy steps).
static func shot_damage(metres: float, kmh: float, perfect: bool, run_mult: float) -> float:
	var d := metres * PER_METRE * run_mult + maxf(0.0, kmh - HEAVY_FROM) * PER_KMH
	return d * (PERFECT_X if perfect else 1.0)


## Takes stamina; returns how much it really took.
func damage(n: float) -> float:
	var before := value
	value = clampf(value - n, 0.0, MAX)
	return before - value


func rest(kind: String) -> void:
	value = minf(value + float(REST.get(kind, 0.0)), MAX)


## 0 above 40%, 1 when empty.
func tired() -> float:
	return clampf((TIRED_BELOW - value) / TIRED_BELOW, 0.0, 1.0)


func speed_mult() -> float:
	return 1.0 - SLOW * tired()


func skill_penalty() -> float:
	return SKILL * tired()
