class_name SaveData
## Meta progress that survives runs: gold, tournaments played and won, best round,
## and the player's skills (experience, build perks, perk choices still to make).
## Stored in user:// (IndexedDB in the browser); Telegram CloudStorage comes later.

const FILE := "user://progress.cfg"

static var gold := 0
static var played := 0
static var titles := 0
static var best_round := -1       # furthest round reached (index), -1 = none yet
static var _loaded := false
static var enabled := true        # off in automated test runs
static var control_chosen := false # the first-launch control choice was made
static var tap_controls := false
static var one_handed_bh := false


static func load_once() -> void:
	if _loaded or not enabled:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(FILE) != OK:
		return
	gold = cf.get_value("meta", "gold", 0)
	played = cf.get_value("meta", "played", 0)
	titles = cf.get_value("meta", "titles", 0)
	best_round = cf.get_value("meta", "best_round", -1)
	control_chosen = cf.get_value("settings", "control_chosen", false)
	tap_controls = cf.get_value("settings", "tap_controls", false)
	one_handed_bh = cf.get_value("settings", "one_handed_bh", false)
	Skills.xp = cf.get_value("skills", "xp", {})
	Skills.perks = cf.get_value("skills", "perks", [])
	Skills.pending = cf.get_value("skills", "pending", [])
	Skills.points = cf.get_value("skills", "points", Skills.START_POINTS)


static func save() -> void:
	if not enabled:
		return
	var cf := ConfigFile.new()
	cf.set_value("meta", "gold", gold)
	cf.set_value("meta", "played", played)
	cf.set_value("meta", "titles", titles)
	cf.set_value("meta", "best_round", best_round)
	cf.set_value("settings", "control_chosen", control_chosen)
	cf.set_value("settings", "tap_controls", tap_controls)
	cf.set_value("settings", "one_handed_bh", one_handed_bh)
	cf.set_value("skills", "xp", Skills.xp)
	cf.set_value("skills", "perks", Skills.perks)
	cf.set_value("skills", "pending", Skills.pending)
	cf.set_value("skills", "points", Skills.points)
	cf.save(FILE)


static func record_run(t: Tournament) -> void:
	load_once()
	if t.banked:
		return
	t.banked = true
	played += 1
	gold += t.gold
	if t.champion:
		titles += 1
	best_round = maxi(best_round, mini(t.stage, t.rounds() - 1))
	save()
