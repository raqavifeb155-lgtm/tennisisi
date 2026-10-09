class_name BallMachine
extends Node
## The ball machine drill (docs/superpowers/specs/2026-10-08-p-ball-machine.md): the machine
## on the far half of the club's main court feeds the player one exercise after another -
## flat, topspin, slice, drop shot, lob, volley, smash, then the player serves. A ball counts
## when the stroke is the one asked for (the gesture's type) and it lands in the court;
## PERFECT is counted apart. A counted ball pays a little experience to the stroke's skill
## (half of a match's, a tenth after three laps a day) and a whole lap pays a little gold.
##
## Main's part is small: the phase DRILL (between balls), the ball itself plays in the
## ordinary RALLY / SERVE phases so the timing ring, the swing and the hit are the match's.
## The verdicts come from GameEvents (player_stroke, bounce), so the point logic of Main
## never sees the drill: a verdict takes the phase out of RALLY before Main's own bounce
## code runs. Hooks in Main: create + setup, tick(), stop(), xp_mult() / holds_xp() in the
## experience, the AI idle, and `_on_ui("drill")`.
##
## Saved in SaveData.club["drills"]: {done, later, circles, day, today, types, hint}.

signal round_done(info: Dictionary)

enum St { OFF, WAIT, FLIGHT, SERVE, PAUSE, SUMMARY }

const DAILY_CIRCLES := 3            # laps a day at full pay
const XP_MULT := 0.5                # of a match's experience for a counted ball
const XP_MULT_CAPPED := 0.1         # after the daily laps
const GOLD_BASE := 10               # a lap's gold, times the island's multiplier
## Loop review P1 (decided 10.10, stream A): the lap's gold stays OFF Tournament.income_scale -
## it is the daily hook, capped at DAILY_CIRCLES laps (30..60 a day, ~5% of the club over 60 h),
## while everything paid per run (prizes, style, chests, the coach's quests) is on the scale.
const PER_TYPE := 3
const PER_TYPE_FIRST := 1           # the first lap is short
const FEED_GAP := 1.35              # seconds from a verdict to the next ball
const STEP_GAP := 2.4               # ...to the first ball of the next exercise (read the card)
const FLIGHT_MAX := 9.0
const MUZZLE := Vector3(0.0, 0.82, -0.72)   # the barrel's end in the machine's frame
const HOME_POS := Vector3(2.5, 0.0, -10.5)  # ClubWorld's ball_machine marker
const COACH_POS := Vector3(-1.4, 0.0, -11.4)
const ISLE_MULT := [1.0, 1.3, 1.6, 2.0]     # the same as the coach's quests (ClubQuests.GOLD_MULT)
const FEED_X := [2.7, -2.7, 0.9, -1.3, 3.3, -3.3, 1.8, -2.0]
const FEED_Z := [7.0, 8.2, 6.4, 7.6, 6.9, 8.6]
const FEED_PACE := [16.5, 18.5, 17.0, 19.0]

## gesture: the drawing (DrillHud: 0 flat, 1 topspin, 2 slice, 3 drop, 4 lob, 5 volley,
## 6 smash, 7 serve). feed: ground / net / high / serve. skill: what a counted ball trains
## (the same as in a match, see Main.stroke_skill) - "" = by the side.
const TYPES := [
	{"id": "flat", "name": "Плоский", "title": "ПЛОСКИЙ", "gesture": 0, "feed": "ground",
		"line": "Плоский: свайп прямо вверх. Бей, когда кольцо сожмётся до круга"},
	{"id": "topspin", "name": "Топспин", "title": "ТОПСПИН", "gesture": 1, "feed": "ground",
		"line": "Топспин: свайп вверх и в конце выкрут пальцем. Мяч ныряет и прыгает"},
	{"id": "slice", "name": "Слайс", "title": "СЛАЙС", "gesture": 2, "feed": "ground",
		"line": "Слайс: длинный свайп вниз, будто режешь мяч. Он стелется низко"},
	{"id": "drop", "name": "Укороченный", "title": "УКОРОЧЕННЫЙ", "gesture": 3, "feed": "ground",
		"line": "Укороченный: короткий свайп вниз. Мяч упадёт сразу за сеткой"},
	{"id": "lob", "name": "Свеча", "title": "СВЕЧА", "gesture": 4, "feed": "ground",
		"line": "Свеча: медленная дуга вверх. Мяч улетит высоко и глубоко"},
	{"id": "volley", "name": "С лёта", "title": "С ЛЁТА", "gesture": 5, "feed": "net",
		"line": "С лёта: подбеги к сетке и бей, пока мяч не упал на корт"},
	{"id": "smash", "name": "Смэш", "title": "СМЭШ", "gesture": 6, "feed": "high",
		"line": "Смэш: высокий мяч. Встань под него и свайпни вверх, когда кольцо сожмётся"},
	{"id": "serve", "name": "Подача", "title": "ПОДАЧА", "gesture": 7, "feed": "serve",
		"line": "Подача: тап по корту, мяч взлетает, свайп в квадрат напротив, когда кольцо сожмётся"},
]

const PRAISE := ["Отлично!", "Чисто!", "Так и надо!", "Хорошо пошло!", "Вот это удар!"]

var main: Node
var active := false
var paying := false                 # Main's _gain_xp is being called by the drill itself
var hud: DrillHud
var world: Node                     # the club's ClubWorld (the machine's model), or null

var _ph: Dictionary                 # Main.Phase by name
var _who: Dictionary                # Main.Who by name
var _state := St.OFF
var _step := 0
var _need := PER_TYPE
var _first := false                 # the first lap ever (short; its end leads to «Новая игра»)
var _onboarding := false            # started by the first-entry flow («Позже» instead of «Выйти»)
var _finished_lap := false
var _ok: Array = []
var _tries: Array = []
var _perfect: Array = []
var _fails := 0                     # misses in a row, the coach repeats the gesture after three
var _n := 0                         # balls fed this lap, varies the feed
var _wait_t := 0.0
var _flight_t := 0.0
var _pause_t := 0.0
var _still_t := 0.0
var _hit := {}                      # the player's stroke to this ball
var _hit_ok := false
var _saved_serves := 0
var _serve_i := 0
var _first_timer := -1.0
var _last_note := ""
var _recoil: Tween
var last_verdict := ""              # "ok" / "wrong" / "out" / "miss" (tests, the overlay probe)
var last_detail := ""
var last_info := {}                 # the last lap's summary


# --- The save --------------------------------------------------------------------

static var fake_day := ""           # tests: pretend today is another day


static func today_key() -> String:
	return fake_day if fake_day != "" else Time.get_date_string_from_system()


## SaveData.club["drills"], with today's count rolled over.
static func data() -> Dictionary:
	var d: Dictionary = SaveData.club.get("drills", {})
	for k in {"done": false, "later": false, "circles": 0, "day": "", "today": 0, "types": {}, "hint": false}:
		if not d.has(k):
			d[k] = {"done": false, "later": false, "circles": 0, "day": "", "today": 0, "types": {}, "hint": false}[k]
	if String(d["day"]) != today_key():
		d["day"] = today_key()
		d["today"] = 0
	SaveData.club["drills"] = d
	return d


## The tutorial cards' script, by path: it reaches the autoloads, which a test's script
## does not have yet when it compiles this one.
static func _tutorial() -> GDScript:
	return load("res://scripts/tutorial.gd")


static func capped() -> bool:
	return int(data()["today"]) >= DAILY_CIRCLES


## The experience of a counted ball, of a match's.
static func xp_factor() -> float:
	return XP_MULT_CAPPED if capped() else XP_MULT


static func island_mult() -> float:
	var loc := String(SaveData.club.get("last_location", "park"))
	return float(ISLE_MULT[clampi(ClubQuests.tier_of(loc), 0, ISLE_MULT.size() - 1)])


static func gold_for_lap() -> int:
	return roundi(GOLD_BASE * island_mult())


# --- Main's hooks -------------------------------------------------------------------

func setup(m: Node) -> void:
	main = m
	var consts: Dictionary = main.get_script().get_script_constant_map()
	_ph = consts["Phase"]
	_who = consts["Who"]
	hud = DrillHud.new()
	add_child(hud)
	hud.exit_pressed.connect(_on_exit)
	hud.again_pressed.connect(_on_again)
	for b in hud.blocking():
		main.hud.touch.blocked_controls.append(b)
	var ev: Node = Engine.get_main_loop().root.get_node("GameEvents")
	ev.player_stroke.connect(_on_stroke)
	ev.bounce.connect(_on_bounce)
	ev.match_started.connect(_on_match_started)


## Main's _gain_xp asks: while the drill runs, only its own payments count.
func holds_xp() -> bool:
	return active and not paying


## Main's _xp_mult while the drill pays.
func xp_mult() -> float:
	return xp_factor()


## A tournament match begins: the «Новая игра» pulse has done its job.
func _on_match_started(info: Dictionary) -> void:
	if info.get("tournament", false):
		var d := data()
		if d["hint"]:
			d["hint"] = false


## Main's _open_menu: the club is open. The first time ever, the coach leads here.
func on_club_opened(force := false) -> void:
	if active:
		return
	var d := data()
	if d["done"] or d["later"]:
		return
	if not force and (not SaveData.enabled or _tutorial().call("is_done") or SaveData.played > 0):
		return  # a returning player is not led by the hand
	_first_timer = 4.0


func _process(delta: float) -> void:
	if _first_timer < 0.0 or active:
		return
	var club = main.club
	if not club.active or main.ui.is_open():
		_first_timer = -1.0
		return
	_first_timer -= delta
	if _first_timer <= 0.0:
		_first_timer = -1.0
		club.coach.say("drill_first", true)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if main.club.active and not active:
				start(true))


## Into the drill (from the machine's button, or led by the coach on the first visit).
func start(onboarding := false) -> void:
	if active:
		return
	var club = main.club
	if club.active:
		club.close()  # remembers where the hero stood
	if not onboarding:
		club.stand_at(ClubPlaces.find("machine")["pos"])  # back by the machine afterwards
	if main.location_id != "club":
		main.set_location("club")
	world = main.scenery if main.scenery != null and main.scenery.has_method("ball_machine") else null
	var d := data()
	_first = not bool(d["done"])
	_onboarding = onboarding
	_need = PER_TYPE_FIRST if _first else PER_TYPE
	active = true
	main.tournament = null
	main.tournament_mode = false
	Rewards.restore()
	main._set_opponent_mods(1.0, 1.0, {})
	main.scoreboard = MatchScore.new(1, 99, 0, _who["PLAYER"], "CPU")
	main.server = _who["PLAYER"]
	main.score = [0, 0]
	main.rally = 0
	main.best_rally = 0
	main._match_over = false
	main._replay_serve = false
	main._run_dist = 0.0
	main.court.clear_marks()
	main.stamina = 1.0
	main.hud.set_score("")
	_saved_serves = main._own_serves
	main._own_serves = main.SERVE_HINTS  # the drill's own card explains the serve
	_place_actors()
	main.ball.park()
	main.phase = _ph["DRILL"]
	var sa: Vector2 = main._safe
	hud.set_safe_area(maxf(sa.x, 0.0), maxf(sa.y, 0.0))
	hud.show_hud(true)
	hud.hide_summary()
	hud.set_exit_label("Позже" if _first else "Выйти")
	_machine_visible(true)
	_begin_lap()


func _begin_lap() -> void:
	_step = 0
	_ok = []
	_tries = []
	_perfect = []
	for i in TYPES.size():
		_ok.append(0)
		_tries.append(0)
		_perfect.append(0)
	_fails = 0
	_n = 0
	_finished_lap = false
	_hit = {}
	hud.hide_summary()
	_enter_step(true)


## Main's _stop_match: leaving the court (the pause's «Выйти в клуб», a match, the menu).
func stop() -> void:
	if not active:
		return
	active = false
	_state = St.OFF
	if _onboarding and not _finished_lap:
		data()["later"] = true  # walked out of the first lesson: not dragged back in
		if SaveData.enabled:
			_tutorial().call("mark_done")
	main._own_serves = _saved_serves
	hud.show_hud(false)
	_machine_visible(false)
	var m := _model()
	if m != null:
		if _recoil != null and _recoil.is_valid():
			_recoil.kill()
		m.rotation.y = PI
		m.position = HOME_POS
	if SaveData.enabled:
		SaveData.save()


func _place_actors() -> void:
	var p: Athlete = main.player
	p.area = main.PLAYER_AREA
	p.position = main.PLAYER_HOME
	p.velocity = Vector3.ZERO
	p.move_input = Vector2.ZERO
	p.recover()
	p.relax()
	_place_coach()


func _place_coach() -> void:
	var c: Athlete = main.cpu
	c.set_look(ClubCoach.LOOK)
	c.area = main.CPU_AREA
	c.position = COACH_POS
	c.velocity = Vector3.ZERO
	c.move_input = Vector2.ZERO
	c.rotation.y = PI
	c.recover()
	c.relax()


func _model() -> Node3D:
	if world == null or not is_instance_valid(world):
		return null
	return world.get_node_or_null("machine_model") as Node3D


func _machine_visible(on: bool) -> void:
	var m := _model()
	if m != null:
		m.visible = on


# --- Steps ------------------------------------------------------------------------

func _enter_step(first_ball_long := false) -> void:
	var t: Dictionary = TYPES[_step]
	_state = St.WAIT
	_wait_t = STEP_GAP if first_ball_long else FEED_GAP
	_fails = 0
	_still_t = 0.0
	hud.set_dim(false)
	hud.set_gesture(int(t["gesture"]), String(t["line"]))
	_refresh_hud()


func _refresh_hud(note := "") -> void:
	var t: Dictionary = TYPES[_step]
	var states := []
	for i in TYPES.size():
		states.append(2 if int(_ok[i]) >= _need else (1 if i == _step else 0))
	_last_note = note if note != "" else ("на сегодня хватит · опыт ×0.1" if capped() else "")
	hud.set_task(String(t["title"]), mini(int(_ok[_step]), _need), _need, states, _last_note)


func progress() -> Vector2i:
	return Vector2i(mini(int(_ok[_step]), _need), _need) if not _ok.is_empty() else Vector2i.ZERO


func step_id() -> String:
	return String(TYPES[_step]["id"])


func step_index() -> int:
	return _step


func state_name() -> String:
	return St.keys()[_state]


func tick(delta: float) -> void:
	if not active:
		return
	main.stamina = 1.0  # a drill is no test of the legs
	var sa: Vector2 = main._safe
	if hud._safe_top != maxf(sa.x, 0.0):
		hud.set_safe_area(maxf(sa.x, 0.0), maxf(sa.y, 0.0))
	var p: Athlete = main.player
	_still_t = _still_t + delta if p.velocity.length() < 0.8 else 0.0
	match _state:
		St.WAIT:
			_wait_t -= delta
			var ready := _ready_to_fire()
			if _wait_t <= 0.0 and ready:
				_fire()
		St.FLIGHT:
			_flight_t += delta
			if _flight_t > FLIGHT_MAX or main.ball.state.rolling:
				_resolve("miss", "не достал")
		St.PAUSE:
			_pause_t -= delta
			if _pause_t <= 0.0:
				_next()


## Whether the ball may come now, and what the card says while it waits for the player.
func _ready_to_fire() -> bool:
	var feed := String(TYPES[_step]["feed"])
	var z: float = main.player.position.z
	var note := ""
	var ok := true
	match feed:
		"net":
			ok = z < 7.0 and _still_t > 0.3
			note = "" if ok else "подойди к сетке"
		"high":
			ok = z > 1.5 and z < 9.5 and _still_t > 0.4
			note = "" if ok else "встань и жди"
	if note != _last_note and (note != "" or _last_note in ["подойди к сетке", "встань и жди"]):
		_refresh_hud(note)
	return ok


# --- Feeding ------------------------------------------------------------------------

func _fire() -> void:
	var t: Dictionary = TYPES[_step]
	if t["feed"] == "serve":
		_prepare_serve()
		return
	_n += 1
	var p: Athlete = main.player
	var plan := _plan(String(t["feed"]), p)
	_aim_machine(plan["aim"])
	var from := _muzzle()
	var vel: Vector3
	var spin: Vector3
	if plan["through"]:
		vel = through(from, plan["aim"], float(plan["time"]))
		spin = Vector3.ZERO
	else:
		var r := ShotSolver.solve(from, plan["aim"], float(plan["pace"]), float(plan["top"]), float(plan["margin"]))
		vel = r.velocity
		spin = r.spin
	main.ball.launch(from, vel, spin)
	main.trail.set_color(main.TRAIL_FLAT, false)
	main.sfx.play("hit", -7.0, 0.72)
	_kick()
	main.last_hitter = _who["CPU"]
	main.bounces = 0
	main.net_touched = false
	main.serve_flight = false
	main.ball_used = false
	main.rally = 1
	main.pending_swing = {}
	main.late_until = -1.0
	main._assist_suppressed = bool(plan["still"])
	main.phase = _ph["RALLY"]
	_hit = {}
	_hit_ok = false
	_flight_t = 0.0
	_state = St.FLIGHT
	hud.set_dim(true)
	_refresh_hud()


## Where and how the next ball goes. `aim` is the landing spot (ground and net feeds) or the
## point the ball must pass (the high one); `still`: aimed at where the player stands, so
## Main's auto-positioning stays out of it.
func _plan(feed: String, p: Athlete) -> Dictionary:
	var px: float = p.position.x
	var pz: float = p.position.z
	var fx: float = FEED_X[_n % FEED_X.size()]
	var plan := {"through": false, "pace": 17.0, "top": 120.0, "margin": 0.5, "still": false, "time": 2.0}
	match feed:
		"net":
			# A soft ball that arrives at the net player's strike zone before it bounces:
			# through a spot a little to the side of where he stands, chest high, falling.
			var want_x := clampf(px + (0.8 if _n % 2 == 0 else -0.8), -3.2, 3.2)
			plan["aim"] = Vector3(want_x, 1.2, pz - Athlete.CONTACT_FORWARD)
			plan["through"] = true
			plan["time"] = 0.95
			plan["still"] = true
		"high":
			var plane_z2 := pz - Athlete.CONTACT_FORWARD
			var want_x2 := clampf(px + (0.7 if _n % 2 == 0 else -0.7), -3.4, 3.4)
			plan["aim"] = Vector3(want_x2, 2.75, plane_z2)
			plan["through"] = true
			plan["time"] = 2.15
			plan["still"] = true
		_:
			var tz: float = FEED_Z[_n % FEED_Z.size()]
			plan["aim"] = Vector3(clampf(fx, -3.4, 3.4), BallPhysics.RADIUS, tz)
			plan["pace"] = FEED_PACE[_n % FEED_PACE.size()]
	return plan


## A velocity that takes a ball from `p0` through `target` in `t` seconds in the real flight
## model (air drag included), found by correcting the ballistic guess.
static func through(p0: Vector3, target: Vector3, t: float) -> Vector3:
	var g := BallPhysics.gravity()
	var v := Vector3((target.x - p0.x) / t, (target.y - p0.y) / t + 0.5 * g * t, (target.z - p0.z) / t)
	var steps := maxi(int(t * 240.0), 1)
	var h := t / steps
	for i in 8:
		var s := BallPhysics.State.new(p0, v, Vector3.ZERO)
		for k in steps:
			BallPhysics.integrate_free(s, h)
		var err := target - s.pos
		if err.length() < 0.02:
			break
		v += err / t
	return v


func _muzzle() -> Vector3:
	var m := _model()
	if m != null:
		return m.global_transform * MUZZLE if m.is_inside_tree() else m.transform * MUZZLE
	return Transform3D(Basis(Vector3.UP, PI), HOME_POS) * MUZZLE


## The machine turns toward where the ball will go.
func _aim_machine(target: Vector3) -> void:
	var m := _model()
	if m == null:
		return
	var base := m.position
	var d := Vector3(target.x - base.x, 0.0, target.z - base.z)
	if d.length() > 0.1:
		m.rotation.y = atan2(-d.x, -d.z)


func _kick() -> void:
	var m := _model()
	if m == null or not m.is_inside_tree():
		return
	if _recoil != null and _recoil.is_valid():
		_recoil.kill()
	var back := m.global_transform.basis.z * 0.12
	var home := m.position
	_recoil = create_tween()
	_recoil.tween_property(m, "position", home + back, 0.05)
	_recoil.tween_property(m, "position", home, 0.22)


## The serve exercise: the player serves from the baseline, nothing comes back.
func _prepare_serve() -> void:
	main.server = _who["PLAYER"]
	main.serve_attempt = 1
	main.scoreboard.points = [_serve_i, 0]  # the court side alternates like in a match
	_serve_i += 1
	main._setup_serve()
	_place_coach()
	_hit = {}
	_hit_ok = false
	_state = St.SERVE
	hud.set_dim(false)
	_refresh_hud()


# --- Verdicts --------------------------------------------------------------------------

func _matches(id: String, info: Dictionary) -> bool:
	var smash := bool(info.get("smash", false))
	var volley := bool(info.get("volley", false))
	var serve := bool(info.get("serve", false))
	match id:
		"serve":
			return serve
		"smash":
			return smash
		"volley":
			return volley and not smash
		_:
			if serve or smash:
				return false
			var ty := String(info.get("type", ""))
			return ty == {"flat": "FLAT", "topspin": "TOPSPIN", "slice": "SLICE", "drop": "DROP SHOT", "lob": "LOB"}[id]


const STROKE_NAMES := {"FLAT": "плоский", "TOPSPIN": "топспин", "SLICE": "слайс", "DROP SHOT": "укороченный", "LOB": "свеча", "SMASH": "смэш", "SERVE": "подача"}


func _on_stroke(info: Dictionary) -> void:
	if not active or (_state != St.FLIGHT and _state != St.SERVE):
		return
	var t: Dictionary = TYPES[_step]
	_hit = info
	if _state == St.SERVE:
		if not bool(info.get("serve", false)):
			return
		_state = St.FLIGHT
		_flight_t = 0.0
		_hit_ok = true
		hud.set_dim(true)
		return
	_hit_ok = _matches(String(t["id"]), info)
	if not _hit_ok:
		var nm := String(STROKE_NAMES.get(String(info.get("type", "")), ""))
		if bool(info.get("volley", false)) and not bool(info.get("smash", false)) and nm != "":
			nm += " с лёта"
		_resolve("wrong", nm)


func _on_bounce(info: Dictionary) -> void:
	if not active or _state != St.FLIGHT:
		return
	var pos: Vector3 = info["pos"]
	var n: int = int(info["bounces"])
	var who: int = int(info["last_hitter"])
	if who == _who["CPU"]:
		if n >= 1 and _hit.is_empty():
			_resolve("miss", "не достал")  # the second bounce: it got by
		return
	# The player's ball, its first bounce.
	if n != 0:
		return
	if not _hit_ok:
		if _hit.is_empty():
			_resolve("wrong", "подача снизу")  # an underarm serve is not a stroke event
		return
	var reach := Court.mark_reach(main.ball.impact_vel)
	var id := String(TYPES[_step]["id"])
	var inside: bool
	if id == "serve":
		inside = Court.in_service_box_mark(pos, -1, main.box_side, reach)
	else:
		inside = Court.is_in_singles_mark(pos, -1, reach)
	if inside:
		_resolve("ok")
	else:
		_resolve("out", "в сетку" if pos.z > 0.0 else "в аут")


## The ball's verdict. The phase leaves RALLY at once: Main's own bounce code (a point, a
## fault) then does nothing with the ball.
func _resolve(kind: String, detail := "") -> void:
	if _state != St.FLIGHT:
		return
	main.phase = _ph["DRILL"]
	main.pending_swing = {}
	main.late_until = -1.0
	main.serve_flight = false
	_tries[_step] += 1
	last_verdict = kind
	last_detail = detail
	var t: Dictionary = TYPES[_step]
	var label := String(_hit.get("label", ""))
	match kind:
		"ok":
			_ok[_step] += 1
			_fails = 0
			if label == "PERFECT":
				_perfect[_step] += 1
			_pay(_hit)
			hud.flash("ЗАСЧИТАНО", UiTheme.WIN)
			var tail: String = "PERFECT!" if label == "PERFECT" else PRAISE[(_n + int(_ok[_step])) % PRAISE.size()]
			hud.say(tail + (" Остался %d." % (_need - int(_ok[_step])) if int(_ok[_step]) < _need else ""), 1.4)
		"wrong":
			_fails += 1
			hud.flash("НЕ ТОТ УДАР", Color(1.0, 0.7, 0.3))
			hud.say("Это был %s. Нужен %s: %s" % [detail if detail != "" else "другой", String(t["name"]).to_lower(), _short(String(t["id"]))], 3.2)
		"out":
			_fails += 1
			hud.flash("МИМО", UiTheme.LOSE)
			hud.say("Удар верный, но %s. Бей мягче и целься в корт" % detail, 2.8)
		_:
			_fails += 1
			hud.flash("МИМО", UiTheme.LOSE)
			hud.say("Не достал. Бей, когда кольцо сожмётся до круга", 2.6)
	if _fails >= 3 and kind != "ok":
		_fails = 0
		hud.say(String(t["line"]), 4.0)
	hud.set_dim(false)
	_state = St.PAUSE
	_pause_t = FEED_GAP
	_refresh_hud()
	_haptic(kind)


func _short(id: String) -> String:
	return {"flat": "свайп прямо вверх", "topspin": "вверх и выкрут в конце", "slice": "длинный свайп вниз",
		"drop": "короткий свайп вниз", "lob": "медленная дуга вверх", "volley": "бей мяч до отскока",
		"smash": "бей высокий мяч над головой", "serve": "тап — подброс, свайп вверх"}[id]


func _haptic(kind: String) -> void:
	if kind == "ok":
		main._haptic("perfect" if String(_hit.get("label", "")) == "PERFECT" else "light")


## A counted ball pays its stroke's skill, half of a match's (a tenth after the daily laps).
func _pay(info: Dictionary) -> void:
	var skill := String(info.get("skill", ""))
	if skill == "":
		return
	paying = true
	main._gain_xp(skill, String(info.get("label", "GOOD")))
	paying = false
	var d := data()
	var types: Dictionary = d["types"]
	var id := String(TYPES[_step]["id"])
	types[id] = int(types.get(id, 0)) + 1


## After the pause: the next ball, or the next exercise, or the end of the lap.
func _next() -> void:
	if int(_ok[_step]) >= _need:
		_step += 1
		if _step >= TYPES.size():
			_step = TYPES.size() - 1
			_finish_lap()
			return
		_enter_step(true)
		return
	_state = St.WAIT
	_wait_t = 0.0
	_still_t = 0.0
	_refresh_hud()


func _finish_lap() -> void:
	_finished_lap = true
	_state = St.SUMMARY
	var d := data()
	var was_first := not bool(d["done"])
	var before := int(d["today"])
	d["done"] = true
	d["circles"] = int(d["circles"]) + 1
	d["today"] = before + 1
	var gold := gold_for_lap() if before < DAILY_CIRCLES else 0
	SaveData.gold += gold
	var quests: Array = ClubQuests.note("drill_circle")
	if was_first:
		d["hint"] = true  # «Новая игра» pulses in the club
	if SaveData.enabled:
		_tutorial().call("mark_done")  # the lesson replaces the pop-up cards
	var rows := []
	var ok_all := 0
	var tries_all := 0
	var perfect_all := 0
	for i in TYPES.size():
		rows.append({"name": TYPES[i]["name"], "ok": mini(int(_ok[i]), _need), "need": _need, "perfect": _perfect[i]})
		ok_all += int(_ok[i])
		tries_all += int(_tries[i])
		perfect_all += int(_perfect[i])
	var footer := []
	if gold > 0:
		footer.append("+%d золота за круг" % gold)
	if before >= DAILY_CIRCLES:
		footer.append("На сегодня хватит: опыт ×0.1, золота нет. Завтра снова полный круг")
	elif before + 1 >= DAILY_CIRCLES:
		footer.append("Три круга сегодня сделаны: дальше опыт ×0.1")
	else:
		footer.append("Опыт за круг: ×%s от матча" % str(XP_MULT))
	if not quests.is_empty():
		footer.append("Задание тренера выполнено")
	if was_first:
		footer.append("Дальше — «Новая игра» в клубе")
	last_info = {"ok": ok_all, "tries": tries_all, "perfect": perfect_all, "gold": gold, "first": was_first, "need": _need, "quests": quests.size(), "capped": before >= DAILY_CIRCLES}
	hud.show_summary(rows, perfect_all, ok_all, footer, was_first)
	hud.set_dim(false)
	_refresh_hud()
	SaveData.save()
	round_done.emit(last_info)


# --- Buttons ---------------------------------------------------------------------------

func _on_again() -> void:
	if not active or _state != St.SUMMARY:
		return
	_place_actors()
	main.ball.park()
	main.phase = _ph["DRILL"]
	hud.set_exit_label("Выйти")
	_first = false
	_need = PER_TYPE
	_begin_lap()


func _on_exit() -> void:
	if not active:
		return
	if _onboarding and not _finished_lap:
		data()["later"] = true
		if SaveData.enabled:
			_tutorial().call("mark_done")  # the old cards stay in «?»
	main._show_menu()
