class_name MatchEffects
extends RefCounted
## One tournament match of the roguelike (v0.2 A-2): the player's gear at work (RunEffects)
## and the opponent's stamina as his health (OppStamina). RunHub feeds it GameEvents;
## this carries out what they mean for Main: the player's stat mods (Skills.gear), his
## stamina, the run's gold, and how fast and steady the opponent still is.
## Everything is put back when the match ends.

signal damaged(amount: float, kind: String)   # for the view: "run", "heavy", "item"

const CPU := 1

var main: Node
var t: Tournament
var fx: RunEffects
var opp := OppStamina.new()
var damage_dealt := 0.0
var raw_damage := 0.0             # before the bar's floor: what the balls asked for (bot balance)
var points := 0
var lowest := OppStamina.MAX
var _tuning: Node
var _base_speed := 1.0
var _base_skill := 0.5
var _ran := 0.0                   # metres the opponent ran since he last hit
var _last_pos := Vector3.ZERO
var _kmh := 0.0                   # the player's last ball (km/h)
var _perfect := false             # ... and whether it was a PERFECT
var _rally_n := 0                 # the player's strokes this rally
var _tiebreak := false


func _init(m: Node, tour: Tournament) -> void:
	main = m
	t = tour
	_tuning = (Engine.get_main_loop() as SceneTree).root.get_node("Tuning")
	fx = RunEffects.new(t.equip, t.run_mods)
	_base_speed = main.ai.speed_mult
	_base_skill = _tuning.ai_skill
	_last_pos = main.cpu.position
	_tiebreak = main.scoreboard.in_tiebreak
	_apply_mods()


## StyleRules boosts for this point: the gear's, the point's own (a meteor), the cannon.
func style_boosts() -> Dictionary:
	var b := fx.style_boosts()
	b["all"] = float(b.get("all", 1.0)) * fx.point_style()
	var cannon := fx.rule("cannon_kmh")
	if cannon > 0.0:
		b["cannon_kmh"] = cannon
	return b


func physics(rally: bool) -> void:
	var p: Vector3 = main.cpu.position
	if rally:
		_ran += Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	main.ai.speed_mult = _base_speed * opp.speed_mult()
	_tuning.ai_skill = maxf(0.0, _base_skill - opp.skill_penalty())
	main.cpu.tired = not rally and opp.tired() > 0.0


func on_shot(who: int, info: Dictionary) -> void:
	if who == CPU:
		_hurt_for_ball()
	else:
		_kmh = float(info.get("speed", 0.0)) * 3.6


## The ball he just played (or ran for and missed) cost him the metres and the weight.
func _hurt_for_ball() -> void:
	var run_mult := fx.rule("run_dmg")
	var d := OppStamina.shot_damage(_ran, _kmh, _perfect, run_mult if run_mult > 0.0 else 1.0)
	var heavy := maxf(0.0, _kmh - OppStamina.HEAVY_FROM) * OppStamina.PER_KMH
	var running := _ran * OppStamina.PER_METRE
	_hurt(d, "heavy" if heavy > running else "run")
	_ran = 0.0


func on_stroke(info: Dictionary) -> void:
	_rally_n += 1
	var label := String(info.get("label", ""))
	_perfect = label == "PERFECT"
	var ctx := {"type": String(info.get("type", "")), "label": label, "rally_n": _rally_n}
	_run(fx.fire("on_hit", ctx))
	if _perfect:
		_run(fx.fire("on_perfect", ctx))
	if info.get("diving", false) and fx.rule("dive_free") > 0.0:
		main.stamina = minf(main.stamina + main.STAMINA_DIVE * Skills.stamina_drain(), 1.0)
	_apply_mods()


## A point is over (before Main moves the score on). tricks: its StyleRules result.
func on_point(info: Dictionary, result: Dictionary, last_type: String) -> void:
	var sb: MatchScore = main.scoreboard
	var winner := int(info.get("winner", -1))
	var reason := String(info.get("reason", ""))
	if winner == 0:
		if _ran > 0.5:
			_hurt_for_ball()  # he ran for it and didn't get there
		if reason == "ACE":
			_run(fx.fire("on_ace", {}))
		_run(fx.fire("on_point_won", {"type": last_type, "reason": reason, "tricks": result.get("tricks", [])}))
	# What the point decides, on a copy of the board (as MatchScore.match_point_for does).
	var c := clone(sb)
	var ev := c.add_point(winner)
	var brk := c.break_after(ev)
	if winner == 0 and ev != MatchScore.Event.POINT:
		_run(fx.fire("on_game_won", {}))
		if sb.server == CPU and not sb.in_tiebreak:
			_run(fx.fire("on_break", {}))
	points += 1
	opp.rest("point")
	match brk:
		MatchScore.Break.CHANGE_ENDS:
			if fx.rule("second_wind") > 0.0:
				main.stamina = 1.0
			else:
				opp.rest("change")
		MatchScore.Break.SET_BREAK:
			opp.rest("set")
	_tiebreak = c.in_tiebreak
	fx.end_point()
	_rally_n = 0
	_kmh = 0.0
	_perfect = false
	_ran = 0.0
	_apply_mods()


func finish() -> void:
	main.ai.speed_mult = _base_speed
	_tuning.ai_skill = _base_skill
	main.cpu.tired = false


func _apply_mods() -> void:
	Skills.gear = fx.mods({"tiebreak": _tiebreak})


func _hurt(n: float, kind: String) -> void:
	if n <= 0.05:
		return
	if main.ai.has_method("stamina_mult"):
		n *= main.ai.stamina_mult()  # v0.2 D-5: the opponent's stamina stat (a bigger tank drains slower)
	raw_damage += n
	var d := opp.damage(n)
	damage_dealt += d
	lowest = minf(lowest, opp.value)
	if d > 0.0:
		damaged.emit(d, kind)


func _run(actions: Array) -> void:
	for a in actions:
		match String(a[0]):
			"opp_stamina":
				_hurt(float(a[1]), "item")
			"self_stamina":
				main.stamina = minf(main.stamina + float(a[1]), 1.0)
			"money":
				t.earn("bonus", int(a[1]))


static func clone(sb: MatchScore) -> MatchScore:
	var c := MatchScore.new(sb.sets_to_win, sb.games_per_set, sb.tiebreak_at, sb.server, sb.opponent_name)
	c.points = sb.points.duplicate()
	c.games = sb.games.duplicate()
	c.sets = sb.sets.duplicate()
	c.in_tiebreak = sb.in_tiebreak
	c._tb_first = sb._tb_first
	return c
