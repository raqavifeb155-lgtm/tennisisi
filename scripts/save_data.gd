class_name SaveData
## Meta progress that survives runs: gold, tournaments played and won, best round,
## and the player's skills (experience, build perks, perk choices still to make).
## Stored in user:// (IndexedDB in the browser) and, inside Telegram, copied to the
## player's Telegram CloudStorage after every save: the browser's storage of a Mini App
## can be wiped, the cloud copy survives that and follows the player to a new phone.
## On start the best copy wins (the one with the most progress): the local file, a
## copy left in a folder an older version used, or the cloud.
##
## The save folder is fixed in project.godot (custom user dir): on the web it is
## derived from the project name, and renaming the game once moved it and "lost" the
## progress. Never change it.

const FILE := "user://progress.cfg"
const ALIVE := "user://alive.cfg"
## Folders older versions saved to (web): /userfs/Матчбол for one day after the rename.
const OLD_FILES := ["/userfs/Матчбол/progress.cfg", "/userfs/godot/app_userdata/TENNISISI/progress.cfg",
	"/userfs/Godot/app_userdata/Матчбол/progress.cfg"]

static var gold := 0
static var played := 0
static var titles := 0
static var best_round := -1       # furthest round reached (index), -1 = none yet
static var _loaded := false
static var enabled := true        # off in automated test runs
static var control_chosen := false # the first-launch control choice was made
static var tap_controls := false
static var one_handed_bh := false
static var ambience := true
static var music := true
static var graphics := 0          # GraphicsQuality preset, 0 = auto
static var gfx := {}              # the custom graphics parts and the FPS counter (Tuning names)
static var club := {}             # the player's club (docs/club): last tournament, met the coach...
static var look := {}             # the player's appearance (Looks), {} = the default
static var active: Tournament = null   # the run in progress, written with every save
static var run := {}                   # ...and as read back from the file
static var crashes := 0                # page reloads while the game was on screen
static var last_crash := ""            # where the last one happened ("матч · Максимум")
static var style := {}                 # style records (v0.2 A): best_mult, best_points, total
static var bets := {}                  # the betting desk (v0.2 A): placed, won, loss_streak, net_hits
static var golden: Array = []          # golden opponents beaten (v0.2 A): roster ids
## Club-side, not the character's (v0.2 A; a retired player keeps them, ACADEMY_LEGACY_TZ):
static var locker := {}                # the locker: "items" kept, "next" bought for the next run, "shop" the shop's state
static var titles_by_loc := {}         # titles won per location id (the islands open by them)
static var lifetime_xp := 0.0          # every bit of skill experience ever earned (never reset)
static var camera := "normal"          # the match camera (v0.2 D): "normal" | "tv" (section "view")
static var source := "none"            # where the progress came from: local, old, cloud (telemetry)
static var _cloud_checked := false
static var _last_cloud := ""


static func load_once() -> void:
	if _loaded or not enabled:
		return
	_loaded = true
	var best: ConfigFile = null
	var best_score := -1.0
	var from_file := ""
	for path in [FILE] + (OLD_FILES if OS.has_feature("web") else []):
		var cf := ConfigFile.new()
		if cf.load(path) == OK and _score(cf) > best_score:
			best = cf
			best_score = _score(cf)
			from_file = path
	if best != null:
		source = "local" if from_file == FILE else "old"
		_apply(best)
		if from_file != FILE:
			save()  # an older folder had more: keep it in the right place from now on
	_read_alive()


## How much progress a save holds: tournaments, titles, skill experience, gold.
static func _score(cf: ConfigFile) -> float:
	var xp := 0.0
	var d: Dictionary = cf.get_value("skills", "xp", {})
	for k in d:
		xp += float(d[k])
	var base := float(cf.get_value("meta", "played", 0)) * 1000.0 + float(cf.get_value("meta", "titles", 0)) * 500.0 \
		+ xp + float(cf.get_value("meta", "gold", 0)) * 0.1 + (1.0 if cf.get_value("settings", "control_chosen", false) else 0.0) \
		+ float((cf.get_value("club", "data", {}) as Dictionary).get("spent", 0)) * 0.1  # v0.2 B: gold built into the club still counts
	# v0.2 A: the shop's and the locker's spending counts too, and experience that was
	# earned and then reset by a retirement (lifetime_xp) - the score only ever grows.
	return base + float((cf.get_value("locker", "data", {}) as Dictionary).get("spent", 0)) * 0.1 \
		+ maxf(0.0, float(cf.get_value("lifetime", "xp", 0.0)) - xp)


static func _apply(cf: ConfigFile) -> void:
	gold = cf.get_value("meta", "gold", 0)
	played = cf.get_value("meta", "played", 0)
	titles = cf.get_value("meta", "titles", 0)
	best_round = cf.get_value("meta", "best_round", -1)
	control_chosen = cf.get_value("settings", "control_chosen", false)
	tap_controls = cf.get_value("settings", "tap_controls", false)
	one_handed_bh = cf.get_value("settings", "one_handed_bh", false)
	ambience = cf.get_value("settings", "ambience", true)
	music = cf.get_value("settings", "music", true)
	graphics = cf.get_value("settings", "graphics", 0)
	gfx = cf.get_value("settings", "gfx", {})
	look = cf.get_value("player", "look", {})
	club = cf.get_value("club", "data", {})
	run = cf.get_value("run", "data", {})
	style = cf.get_value("style", "data", {})
	bets = cf.get_value("bets", "data", {})
	golden = cf.get_value("golden", "beaten", [])
	locker = cf.get_value("locker", "data", {})
	titles_by_loc = cf.get_value("titles_by_loc", "data", {})
	lifetime_xp = cf.get_value("lifetime", "xp", 0.0)
	camera = cf.get_value("view", "camera", "normal")
	active = null
	Skills.xp = cf.get_value("skills", "xp", {})
	Skills.perks = cf.get_value("skills", "perks", [])
	Skills.pending = cf.get_value("skills", "pending", [])
	Skills.points = cf.get_value("skills", "points", Skills.START_POINTS)
	Skills.rebuild_pending()  # an old save's experience may land on a different level curve


## The Telegram cloud copy arrives a moment after the start (the page asks for it while
## the engine loads). Main calls this for the first seconds; true = the cloud had more
## progress than this phone and it was taken (the menu should be redrawn).
static func poll_cloud() -> bool:
	if _cloud_checked or not enabled or not OS.has_feature("web"):
		return false
	var r = JavaScriptBridge.eval("typeof window.tennisCloud === 'string' ? window.tennisCloud : null", true)
	if r == null:
		return false
	_cloud_checked = true
	var text := String(r)
	if text.is_empty():
		_push_cloud(_to_config().encode_to_text())  # first time: put this phone's progress up
		return false
	var cf := ConfigFile.new()
	if cf.parse(text) != OK:
		return false
	_last_cloud = text
	var taken := _score(cf) > _score(_to_config()) + 0.5
	TelegramApp.log_event("cloud", {"taken": taken, "had": source, "played": int(cf.get_value("meta", "played", 0))})
	if taken:
		source = "cloud"
		_apply(cf)
		_save_local(cf)
		return true
	return false


static func save() -> void:
	if not enabled:
		return
	var cf := _to_config()
	_save_local(cf)
	_push_cloud(cf.encode_to_text())


static func _save_local(cf: ConfigFile) -> void:
	cf.save(FILE)


static func _push_cloud(text: String) -> void:
	if not OS.has_feature("web") or text == _last_cloud:
		return
	_last_cloud = text
	JavaScriptBridge.eval("window.tennisCloudSave && window.tennisCloudSave(%s)" % JSON.stringify(text), true)


## A heartbeat (Main calls it every few seconds): if the page reloads while the game
## was on screen, the next start counts it as a crash and remembers where it was.
static func mark_alive(where: String) -> void:
	if not enabled:
		return
	var visible := true
	if OS.has_feature("web"):
		visible = JavaScriptBridge.eval("document.visibilityState === 'visible'", true) == true
	var cf := ConfigFile.new()
	cf.set_value("alive", "t", Time.get_unix_time_from_system())
	cf.set_value("alive", "visible", visible)
	cf.set_value("alive", "where", where)
	cf.set_value("alive", "crashes", crashes)
	cf.set_value("alive", "last_crash", last_crash)
	cf.save(ALIVE)


static func _read_alive() -> void:
	var cf := ConfigFile.new()
	if cf.load(ALIVE) != OK:
		return
	crashes = cf.get_value("alive", "crashes", 0)
	last_crash = cf.get_value("alive", "last_crash", "")
	var ago := Time.get_unix_time_from_system() - float(cf.get_value("alive", "t", 0.0))
	if cf.get_value("alive", "visible", false) and ago < 90.0:
		crashes += 1
		last_crash = String(cf.get_value("alive", "where", "?"))


static func _to_config() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.set_value("meta", "gold", gold)
	cf.set_value("meta", "played", played)
	cf.set_value("meta", "titles", titles)
	cf.set_value("meta", "best_round", best_round)
	cf.set_value("settings", "control_chosen", control_chosen)
	cf.set_value("settings", "tap_controls", tap_controls)
	cf.set_value("settings", "one_handed_bh", one_handed_bh)
	cf.set_value("settings", "ambience", ambience)
	cf.set_value("settings", "music", music)
	cf.set_value("settings", "graphics", graphics)
	cf.set_value("settings", "gfx", gfx)
	cf.set_value("player", "look", look)
	cf.set_value("view", "camera", camera)
	cf.set_value("club", "data", club)
	if not style.is_empty():
		cf.set_value("style", "data", style)
	if not bets.is_empty():
		cf.set_value("bets", "data", bets)
	if not golden.is_empty():
		cf.set_value("golden", "beaten", golden)
	if not locker.is_empty():
		cf.set_value("locker", "data", locker)
	if not titles_by_loc.is_empty():
		cf.set_value("titles_by_loc", "data", titles_by_loc)
	if lifetime_xp > 0.0:
		cf.set_value("lifetime", "xp", lifetime_xp)
	if active != null and not active.banked and active.state != Tournament.State.OVER:
		run = active.to_dict()
	else:
		run = {}
	if not run.is_empty():
		cf.set_value("run", "data", run)
	cf.set_value("skills", "xp", Skills.xp)
	cf.set_value("skills", "perks", Skills.perks)
	cf.set_value("skills", "pending", Skills.pending)
	cf.set_value("skills", "points", Skills.points)
	return cf


## A tournament to continue: the one in memory, or the one saved before a reload.
static func resumable() -> Tournament:
	load_once()
	if active != null and not active.banked and active.state != Tournament.State.OVER:
		return active
	if not run.is_empty():
		active = Tournament.from_dict(run)
		return active
	return null


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


## A point scored with style (StyleRules result): keeps the records for the whole game.
static func note_style(r: Dictionary) -> void:
	style["best_mult"] = maxf(float(style.get("best_mult", 1.0)), float(r.get("mult", 1.0)))
	style["best_points"] = maxi(int(style.get("best_points", 0)), int(r.get("points", 0)))
	style["total"] = int(style.get("total", 0)) + int(r.get("points", 0))


## A title won at a location (v0.2 A-4): the next island opens by it.
static func note_title(loc: String) -> void:
	titles_by_loc[loc] = int(titles_by_loc.get(loc, 0)) + 1
