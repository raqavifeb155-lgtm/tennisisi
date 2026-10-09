class_name JuniorBot
extends RefCounted
## The student's side of a match (spec 4, T-4): the six stats of a student become the levels of
## `Skills` (a profile that stands in for the hero's for the length of the match), the stats,
## the traits and the coach's setup become a play style, and the style drives what the bot
## does with every ball - where it serves, where it hits, when it comes in. Main only gives it
## a tick (`Main.spectate`, one line in `_autoplay_tick`); the bot swings through Main's own
## `_swing_input` / `_player_serve`, so a junior hits with the same quality model as the hero.
##
## Also here, as data and pure functions (the tests and `JuniorSim` read them):
##   STANCES   the eight setups of the coach (spec 4): what they change in the style, who they
##             are good against (`fit`, -1..+1), the four offered in a situation (`options_for`);
##   the situations that stop the match for advice (`situation`).
## The strength of a setup is calibrated with `--junior-duel` (see `docs/superpowers/specs/
## 2026-10-09-tycoon.md` 4, the table): `EFFECT_PP` is points of the share of points won, per
## `fit`; `BOOST` is what a unit of it does to the junior's execution so the live match agrees.

const POINTS_PER_STANCE := 4
const FADE_POINTS := 2

## stat 1..10 -> level of Skills (0..25). Tuned so that a student against an OpponentAI of the
## same stats wins about half of the points (tools: --junior-duel, spec 4 table).
## level = LV_A + LV_B x (stat - 1), rounded (static vars: the calibration moves them).
static var lv_a := 5.0
static var lv_b := 1.4
## The bot's timing error (s): a beginner's thumb .. a pro's.
static var sd_max := 0.075
const SD_MIN := 0.04

## The coach's setups. d: additive change of the play style (Opponents.PLAY_STYLES keys);
## serve: where the serve goes; target: "weak" = the opponent's weaker wing.
const STANCES := {
	"aggr": {"name": "Агрессивнее", "hint": "Бьёт ближе к линиям, чаще ошибается", "d": {"aggr": 0.30, "risk": 0.15, "pace": 0.08}},
	"patient": {"name": "Терпеливее", "hint": "Выше над сеткой, в центр, длинные розыгрыши", "d": {"patience": 0.30, "risk": -0.20, "pace": -0.05}},
	"net": {"name": "К сетке", "hint": "Выходит вперёд после глубокого удара", "d": {"approach": 0.35, "net_rush": 0.12}},
	"body": {"name": "Подавай в тело", "hint": "Подача в корпус, точнее", "d": {"serve": -0.03}, "serve": "body"},
	"weak": {"name": "Бей по слабому крылу", "hint": "Мячи туда, где ему хуже", "d": {"read": 0.55}, "target": "weak"},
	"change": {"name": "Меняй направление", "hint": "Игра в обратную сторону, бегает", "d": {"change": 0.30}},
	"lob": {"name": "Свечи и укоротки", "hint": "Свеча над сеткой, мячи у сетки", "d": {"lob": 0.30, "drop": 0.15}},
	"legs": {"name": "Береги ноги", "hint": "Медленнее, дольше, бережёт дыхание", "d": {"pace": -0.10, "patience": 0.20, "drop": 0.10}},
}
const STANCE_ORDER := ["aggr", "patient", "net", "body", "weak", "change", "lob", "legs"]

## The four setups offered in a situation (spec 4). "body" gives way to "weak" when the
## junior is not the next to serve (a serve target is no use then).
const OFFER := {
	"behind": ["aggr", "patient", "net", "body"],
	"critical": ["body", "change", "patient", "aggr"],
	"tired": ["legs", "lob", "patient", "net"],
	"streak": ["change", "weak", "patient", "aggr"],
}
const SITUATION_TEXT := {
	"behind": "Проигрывает по очкам",
	"critical": "Сетбол у соперника",
	"tired": "Выдохся",
	"streak": "Три очка подряд у соперника",
}
## How many points one piece of advice is worth: share-of-points change per `fit` (the live
## match gets it through BOOST, JuniorSim directly). Points at fit = -1, -.5, 0, +.5, +1.
## Calibrated by the sweep in the spec's table (T-4).
const EFFECT_FIT := [-1.0, -0.5, 0.0, 0.5, 1.0]
const EFFECT_PP := [-8.0, -4.0, 0.0, 7.0, 13.0]
## What a unit of "boost" does to the junior's play (Skills mods layer): cleaner timing, less
## scatter when the setup suits him and the opponent; the opposite when it does not.
const BOOST := {"forehand_window": 0.35, "backhand_window": 0.35, "serve_window": 0.35, "net_window": 0.35, "touch_window": 0.35,
	"forehand_scatter": -0.30, "backhand_scatter": -0.30, "serve_scatter": -0.30, "net_scatter": -0.30, "touch_scatter": -0.30}
## fit -> boost units (calibrated alongside EFFECT_PP).
const BOOST_FIT := [-1.0, -0.5, 0.0, 0.5, 1.0]
const BOOST_UNITS := [-1.0, -0.5, 0.0, 0.5, 1.0]

# --- The student as numbers ------------------------------------------------------------------------

static func stat_of(st: Dictionary, key: String) -> int:
	return clampi(int((st.get("stats", {}) as Dictionary).get(key, 3)), 1, 10)


## 0..1 of a stat.
static func t_of(stats: Dictionary, key: String) -> float:
	return clampf((float(stats.get(key, 3)) - 1.0) / 9.0, 0.0, 1.0)


static func level_of(stat: int) -> int:
	return clampi(roundi(lv_a + lv_b * float(clampi(stat, 1, 10) - 1)), 0, Skills.MAX_LEVEL)


## Skill levels from the six stats (the spec's mapping: speed = feet, touch = the hands in general).
static func levels(st: Dictionary) -> Dictionary:
	var s: Dictionary = st.get("stats", {})
	var touch := roundi((float(s.get("net", 3)) + float(s.get("forehand", 3)) + float(s.get("backhand", 3))) / 3.0)
	return {"forehand": level_of(int(s.get("forehand", 3))), "backhand": level_of(int(s.get("backhand", 3))), "serve": level_of(int(s.get("serve", 3))),
		"net": level_of(int(s.get("net", 3))), "feet": level_of(int(s.get("speed", 3))), "stamina": level_of(int(s.get("stamina", 3))), "touch": level_of(touch)}


## The profile Main plays with for the match (Skills.load_profile).
static func skill_profile(st: Dictionary) -> Dictionary:
	return Skills.profile_from_levels(levels(st), 0)


## The bot's timing error: from 0.085 s (stats 1) to 0.04 s (10), by the mean of the stats.
static func sd_of(st: Dictionary) -> float:
	var sum := 0.0
	for k in Opponents.STAT_KEYS:
		sum += t_of(st.get("stats", {}), k)
	return lerpf(sd_max, SD_MIN, sum / float(Opponents.STAT_KEYS.size()))


## The student's own style: the stats lean it, the traits add (Traits.style_of).
static func style_of(st: Dictionary) -> Dictionary:
	var s: Dictionary = st.get("stats", {})
	var out: Dictionary = Opponents.PLAY_STYLES[Opponents.DEFAULT_STYLE].duplicate()
	var fh := t_of(s, "forehand")
	var bh := t_of(s, "backhand")
	var sv := t_of(s, "serve")
	var nt := t_of(s, "net")
	var sp := t_of(s, "speed")
	var stm := t_of(s, "stamina")
	out["aggr"] = 0.35 + 0.45 * (0.5 * sv + 0.5 * fh)
	out["patience"] = 0.45 + 0.35 * stm
	out["approach"] = 0.15 + 0.65 * nt
	out["net_rush"] = 0.15 * nt
	out["drop"] = 0.15 + 0.25 * nt
	out["lob"] = 0.30 + 0.25 * sp
	out["risk"] = 1.0 + 0.2 * (fh - 0.5)
	out["pace"] = 0.95 + 0.12 * (0.5 * fh + 0.5 * bh)
	out["serve"] = 0.95 + 0.15 * sv
	var ids := Traits.all_ids(st)
	var tr := Traits.style_of(ids)
	for k in tr:
		out[k] = float(out.get(k, 0.0)) + float(tr[k])
	return out


# --- Setups and how well they suit -----------------------------------------------------------------

static func name_of(id: String) -> String:
	return String(STANCES.get(id, {}).get("name", id))


## A style with a setup on it at weight w (1 = full, then fading to 0 over FADE_POINTS).
static func styled(base: Dictionary, id: String, w: float) -> Dictionary:
	var out := base.duplicate()
	if id == "" or w <= 0.0 or not STANCES.has(id):
		return out
	var d: Dictionary = STANCES[id]["d"]
	for k in d:
		out[k] = float(out.get(k, 0.0)) + float(d[k]) * w
	return out


static func _d(x: float) -> float:
	return 2.0 * x - 1.0


## How well a setup suits this student against this opponent (-1..+1). `tired` 0..1: how
## spent the student is now (the stamina below the tired mark). The columns of spec 4 "Лучше против".
static func fit(id: String, st: Dictionary, opp: Dictionary, tired := 0.0) -> float:
	var j: Dictionary = st.get("stats", {})
	var o: Dictionary = Opponents.stats(opp)
	var os: Dictionary = Opponents.play_style(opp)
	var counter := float(os.get("patience", 0.5)) >= 0.7
	var hitter := float(os.get("aggr", 0.5)) >= 0.7
	var ret := (t_of(o, "forehand") + t_of(o, "backhand")) * 0.5
	var raw := 0.0
	match id:
		"aggr":
			raw = 0.40 * _d(1.0 - t_of(o, "serve")) + 0.35 * _d(1.0 - t_of(o, "speed")) + 0.25 * (1.0 if counter else (-0.6 if hitter else 0.0))
		"patient":
			raw = 0.40 * _d(1.0 - t_of(o, "stamina")) + 0.35 * (1.0 if hitter else (-0.6 if counter else 0.0)) + 0.25 * _d(t_of(j, "stamina"))
		"net":
			raw = 0.35 * _d(1.0 - t_of(o, "net")) + 0.35 * _d(1.0 - t_of(o, "speed")) + 0.30 * _d(t_of(j, "net"))
		"body":
			raw = 0.60 * _d(ret) + 0.40 * _d(t_of(j, "serve"))
		"weak":
			var skew := absf(float(o.get("forehand", 5)) - float(o.get("backhand", 5)))
			raw = 2.0 * minf(skew / 4.0, 1.0) - 1.0
		"change":
			raw = 0.50 * (1.0 if counter else -0.4) + 0.50 * _d(t_of(o, "speed"))
		"lob":
			raw = 0.60 * (1.0 if float(os.get("approach", 0.4)) >= 0.7 else -0.5) + 0.40 * _d(t_of(o, "net"))
		"legs":
			raw = 0.50 * _d(1.0 - t_of(j, "stamina")) + 0.50 * (2.0 * tired - 1.0)
	return clampf(raw * 1.5, -1.0, 1.0)


static func _interp(xs: Array, ys: Array, x: float) -> float:
	if x <= float(xs[0]):
		return float(ys[0])
	for i in range(1, xs.size()):
		if x <= float(xs[i]):
			return lerpf(float(ys[i - 1]), float(ys[i]), (x - float(xs[i - 1])) / (float(xs[i]) - float(xs[i - 1])))
	return float(ys[ys.size() - 1])


## Points of the share of points won that a setup of this fit is worth (JuniorSim reads it).
static func effect_pp(f: float) -> float:
	return _interp(EFFECT_FIT, EFFECT_PP, f)


## Units of BOOST for a fit (the live match).
static func boost_of(f: float) -> float:
	return _interp(BOOST_FIT, BOOST_UNITS, f)


## The four setups for a situation: the serve target gives way to the weak wing when the
## student is not the one to serve next.
static func options_for(situation: String, student_serves: bool) -> Array:
	var out: Array = []
	for id in OFFER.get(situation, OFFER["behind"]):
		if id == "body" and not student_serves:
			out.append("weak" if not (OFFER[situation] as Array).has("weak") else "change")
		else:
			out.append(id)
	return out


## What stops the match, if anything: "critical" / "behind" / "streak" / "tired" or "".
## a, b: the points of the student and the opponent; streak: the opponent's points in a row;
## since: points since the last advice (or 99); count: advice so far; stamina 0..1.
static func situation(a: int, b: int, streak: int, stamina: float, since: int, count: int, tired_below := 0.35, match_point_b := false) -> String:
	if count >= 3 or since < POINTS_PER_STANCE:
		return ""
	if match_point_b or (b >= 6 and b - a >= 1):
		return "critical"
	if b - a >= 2:
		return "behind"
	if streak >= 3:
		return "streak"
	if stamina < tired_below:
		return "tired"
	return ""


## The best setup of the offered four by fit, and `rank`-th best (0 = best): the autopilot.
static func pick(options: Array, st: Dictionary, opp: Dictionary, rank := 0, tired := 0.0) -> String:
	var scored: Array = []
	for id in options:
		scored.append([fit(id, st, opp, tired), id])
	scored.sort_custom(func(x, y): return x[0] > y[0])
	return String(scored[clampi(rank, 0, scored.size() - 1)][1])


# --- The bot of a match ------------------------------------------------------------------------------

var st: Dictionary
var opp: Dictionary
var rng := RandomNumberGenerator.new()
var base_style: Dictionary
var style: Dictionary
var stance := ""                 # the setup in force ("" = none)
var stance_w := 0.0              # its weight 0..1 (fades out over FADE_POINTS)
var sd := 0.06                   # timing error now, s
var points_played := 0
var at_break_point := false      # a match point stands (the traits' «breakpoint»)

var _stats: Dictionary
var _ids: Array
var _ost: Dictionary
var _weak_x := 0.0               # x (real world) of the opponent's weaker wing
var _weak_amount := 0.0
var _armed := false
var _plan := {}
var _net_goal := Vector3.INF
var _cpu_contact := Vector3(0, 0, -12.6)
var _cpu_q := 0.7
var _boost_undo: Array = []
var _traits_undo: Array = []
var _active := false


func _init(student: Dictionary, opponent: Dictionary, seed_v := 1) -> void:
	st = student
	opp = opponent
	rng.seed = seed_v
	_stats = st.get("stats", {})
	_ids = Traits.all_ids(st)
	_ost = Opponents.stats(opp)
	base_style = style_of(st)
	style = base_style
	sd = sd_of(st)


## Puts the student's traits on the skills layer for the match (undone by end()).
func begin() -> void:
	if _active:
		return
	_active = true
	_traits_undo = Traits.apply_side(_ids)


func end() -> void:
	if not _active:
		return
	_active = false
	Traits.undo_side(_boost_undo)
	_boost_undo = []
	Traits.undo_side(_traits_undo)
	_traits_undo = []
	stance = ""
	stance_w = 0.0


## A setup at weight w (0 = off): the style and the execution follow it.
func set_stance(id: String, w: float, tired := 0.0) -> void:
	stance = id if w > 0.0 else ""
	stance_w = w if id != "" else 0.0
	style = styled(base_style, stance, stance_w)
	Traits.undo_side(_boost_undo)
	_boost_undo = []
	if stance != "":
		var units := boost_of(fit(stance, st, opp, tired)) * stance_w
		if absf(units) > 0.001:
			for k in BOOST:
				var v := float(BOOST[k]) * units
				Skills.mods_layer[k] = float(Skills.mods_layer.get(k, 0.0)) + v
				_boost_undo.append([k, v])


## The timing error now: the traits' situational shifts (Traits.ctx) move it.
func refresh_sd() -> void:
	var k := 0.0
	if points_played < 2:
		k += Traits.ctx(_ids, "start")
	k += Traits.ctx(_ids, "tiebreak")
	if at_break_point:
		k += Traits.ctx(_ids, "breakpoint")
	sd = sd_of(st) * clampf(1.0 - k, 0.6, 1.4)


## The opponent shot (GameEvents.shot, who = 1): where it was hit from and how well.
func on_shot(who: int, info: Dictionary) -> void:
	if who == 1:
		_cpu_contact = info.get("contact", _cpu_contact)
		_cpu_q = float(info.get("q", 0.7))


## A point ended: forget the ball and the net run.
func on_point() -> void:
	_armed = false
	_plan = {}
	_net_goal = Vector3.INF
	points_played += 1


static func _mir(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, -v.z)


## Main's tick for the student's side (replaces the autoplay bot): m = Main.
func tick(m: Node) -> void:
	if _weak_amount == 0.0 and m.cpu != null:
		_read_weak(m)
	var ph = m.Phase
	if m.phase == ph.SERVE and m.server == m.Who.PLAYER:
		_serve(m)
		return
	if not m._player_can_hit():
		_armed = false
		_plan = {}
		_run_to_net(m)
		return
	if not _armed:
		_armed = true
		m._bot_offset = rng.randfn(0.0, sd)   # the timing error of this ball, + = late
	if m.late_until > 0.0:
		if m.game_time - m.late_cross_time >= m._bot_offset:
			_swing(m)
	elif m._bot_offset <= 0.0 and m.pending_swing.is_empty() and m.t_contact <= -m._bot_offset:
		_swing(m)


func _read_weak(m: Node) -> void:
	var fh := float(_ost.get("forehand", 5))
	var bh := float(_ost.get("backhand", 5))
	var bh_x := -signf((m.cpu as Node3D).global_transform.basis.x.x)   # the side of a right-hander's backhand
	_weak_x = bh_x if bh <= fh else -bh_x
	_weak_amount = maxf(clampf(absf(fh - bh) / 5.0, 0.0, 1.0), 0.001)


func _serve(m: Node) -> void:
	if not m.toss_active:
		m._start_toss()
		m._bot_offset = rng.randfn(0.0, sd * 0.5)
		return
	if m.game_time < m.toss_ideal + m._bot_offset:
		return
	var first: bool = m.serve_attempt == 1
	var sv := t_of(_stats, "serve")
	var bs: float = m.box_side
	var tx: float
	if STANCES.get(stance, {}).get("serve", "") == "body" and stance_w > 0.5:
		tx = clampf(float((m.cpu as Node3D).position.x) * bs, 1.0, 2.8)
	elif first and rng.randf() < lerpf(0.15, 0.8, sv):
		tx = rng.randf_range(2.9, 3.7) if rng.randf() < 0.5 else rng.randf_range(0.35, 0.9)
	else:
		tx = rng.randf_range(1.2, 2.6)
	var pos: Vector3 = m.player.position
	var d := Vector3(bs * tx - pos.x, 0.0, -5.6 - pos.z).normalized()
	var pace_k := clampf(lerpf(0.55, 1.0, sv) * float(style.get("serve", 1.0)), 0.3, 1.0) if first else lerpf(0.35, 0.55, sv)
	var r := rng.randf()
	var type: int = (1 if r < 0.5 else (2 if r < 0.8 else 0)) if first else (0 if r < 0.7 else 2)
	m._curl_k = rng.randf_range(0.9, 1.3)
	m._player_serve(d, pace_k, type)


func _swing(m: Node) -> void:
	if _plan.is_empty():
		_plan = _decide(m)
	m._curl_k = float(_plan["curl"])
	m._swing_input(_plan["dir"], float(_plan["pace_k"]), int(_plan["type"]))


## One decision per ball: ShotPlanner in the mirror (the planner thinks from the far end of the
## court), turned back into a direction, a pace and a stroke for Main's swing.
func _decide(m: Node) -> Dictionary:
	var p: Vector3 = m.player.position
	var c: Vector3 = m.contact_pred
	var cpu: Node3D = m.cpu
	var lat: float = m.player.lateral_of(c)
	var side := 1 if lat >= 0.0 else -1
	var s_wing := t_of(_stats, "forehand" if side > 0 else "backhand")
	var q_est := clampf(float(m.position_quality(lat, c.y)) * float(m.movement_quality(m.player.velocity.length(), Skills.move_penalty_mult())) * 0.92, 0.0, 1.0)
	var volley: bool = m.bounces == 0 and p.z < 8.0
	var sit := {
		"q": q_est, "skill": s_wing, "me": _mir(p), "contact": _mir(c), "player": _mir(cpu.position),
		"player_vel": _mir((m.cpu as Athlete).velocity), "volley": volley, "rally": m.rally,
		"player_contact": _mir(_cpu_contact), "player_q": _cpu_q,
		"short": not volley and m.rally >= 2 and -c.z > -9.6,
		"bh_x": -_weak_x, "bh_weak": _weak_amount,
		"net_k": lerpf(0.4, 1.8, t_of(_stats, "net")),
	}
	var plan := ShotPlanner.choose(sit, style, rng)
	var kind := String(plan["kind"])
	var tx := -float(plan["tx"])
	var type := 0
	var aim_z := -9.8
	match kind:
		"defend":
			type = 2
			if plan["lob"]:
				type = 4
				aim_z = -10.5
		"lob":
			type = 4
			aim_z = -10.5
		"drop":
			type = 3
			aim_z = -2.0
		"volley":
			type = 1
		"attack", "pass", "approach":
			type = 1 if rng.randf() < 0.45 else 0
		_:
			type = 2 if rng.randf() < 0.12 + 0.2 * float(style.get("patience", 0.5)) * 0.3 else 0
	var o := Vector3(c.x, 0.0, c.z)
	var dir := Vector3(tx - o.x, 0.0, aim_z - o.z)
	if dir.z > -0.3:
		dir = Vector3(dir.x, 0.0, -0.3)
	dir = dir.normalized()
	var pace_k := clampf((float(plan["pace"]) - 16.0) / 18.0, 0.1, 1.0)
	if bool(plan["approach"]) and p.z > 6.0:
		_net_goal = Vector3(clampf(c.x * 0.5, -2.0, 2.0), 0.0, 5.4)
	elif kind != "volley":
		_net_goal = Vector3.INF
	return {"dir": dir, "pace_k": pace_k, "type": type, "curl": rng.randf_range(0.9, 1.3) if type == 0 else 1.0, "kind": kind}


## After an approach: the student runs in while the ball is on the other side.
func _run_to_net(m: Node) -> void:
	if _net_goal == Vector3.INF:
		return
	var ph = m.Phase
	if m.phase != ph.RALLY or m.last_hitter != m.Who.PLAYER:
		return
	var p: Vector3 = m.player.position
	var d := Vector2(_net_goal.x - p.x, _net_goal.z - p.z)
	if d.length() > 0.35:
		m.player.move_input = d.normalized() * clampf(d.length() / 0.8, 0.4, 1.0)
