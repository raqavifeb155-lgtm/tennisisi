class_name Rewards
## Rewards between matches: pick 1 of 3 — a run perk, a racket (added by Tournament)
## and a wildcard (one spare life).
## Run perks turn the same knobs as the settings panel (Tuning) and last one tournament.

const WILDCARD := {
	"kind": "wildcard", "id": "wildcard", "title": "Вайлд-кард",
	"desc": "Запасная жизнь: проиграл матч — переиграй его",
}

const PERKS := [
	{"id": "eagle_eye", "title": "Глаз-алмаз", "desc": "Окно PERFECT +8 мс", "mods": {"perfect_window": 0.008}},
	{"id": "steady_hands", "title": "Спокойные руки", "desc": "Окно GOOD +15 мс", "mods": {"good_window": 0.015}},
	{"id": "light_feet", "title": "Лёгкие ноги", "desc": "Скорость бега +0.5 м/с", "mods": {"player_speed": 0.5}},
	{"id": "late_whip", "title": "Поздний хлыст", "desc": "Поздний удар ещё успевает: +30 мс", "mods": {"late_limit": 0.03}},
	{"id": "time_slows", "title": "Время тянется", "desc": "Замедление перед ударом сильнее", "mods": {"slowmo_scale": -0.06}},
	{"id": "instinct", "title": "Чутьё", "desc": "Автоподстройка под мяч сильнее", "mods": {"assist": 0.15}},
]

## Tuning values before the run's perks were applied (restored when the run ends).
static var _base := {}


## The Tuning autoload, looked up at run time (static code in headless test scripts
## is compiled before autoload names exist).
static func _tuning() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Tuning")


static func offer(owned_ids: Array, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for p in PERKS:
		if not owned_ids.has(p["id"]):
			pool.append(p)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var cards: Array = []
	for p in pool.slice(0, 1):
		var c: Dictionary = p.duplicate()
		c["kind"] = "perk"
		cards.append(c)
	cards.append(WILDCARD.duplicate())
	return cards


static func find_perk(id: String) -> Dictionary:
	for p in PERKS:
		if p["id"] == id:
			return p
	return {}


## Applies the run's perks on top of the base tuning (call at every match start).
static func apply(perk_ids: Array) -> void:
	if _base.is_empty():
		for p in PERKS:
			for k in p["mods"]:
				_base[k] = _tuning().get(k)
	for k in _base:
		_tuning().set(k, _base[k])
	for id in perk_ids:
		var p := find_perk(id)
		for k in p.get("mods", {}):
			_tuning().set(k, _tuning().get(k) + p["mods"][k])


## Puts the tuning back as it was before the run.
static func restore() -> void:
	for k in _base:
		_tuning().set(k, _base[k])
	_base = {}
