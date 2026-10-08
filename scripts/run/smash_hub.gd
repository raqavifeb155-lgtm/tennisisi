class_name SmashHub
extends Node
## «Разбить ракетку» (docs/superpowers/specs/2026-10-09-racket-smash.md): decides when the
## button is offered, runs the mini-game (RacketSmash) while Main stands in Phase.SMASH,
## and gives the bonus «Выпустил пар». The cost (the racket's effects off for the rest of
## the match, the «Психанул» trick) is carried out by RunHub on GameEvents.racket_smashed.
## Main creates it once (smash_hub.setup(self)) and calls point_over() after a point,
## on_swipe() / on_progress() from its touch handlers while in Phase.SMASH.

const WINDOW := 2.5               # s the button stays after the point
const COOLDOWN_GAMES := 3         # games between two offers
const AFTER := 0.8                # s of Phase.OVER after the hero is done, before the next serve
const REASONS := ["OUT", "NET", "DOUBLE FAULT"]   # a point lost to the player's own error

## «Выпустил пар»
const WINDOW_MODS := {"forehand_window": 0.10, "backhand_window": 0.10, "serve_window": 0.10, "net_window": 0.10, "touch_window": 0.10}
const REST_MODS := {"stamina_rest": 0.03, "stamina_change": 0.15}
const WINDOW_POINTS := 3          # the PERFECT window is wider for this many points

var main: Node
var smash: RacketSmash
var offer_left := 0.0             # s of the window still open (0 = no button)
var games_since := COOLDOWN_GAMES # games finished since the last offer: the first one is free
var smashed := false              # the racket is already broken in this match
var perfect_left := 0             # points the wider PERFECT window still has
var rest_state := 0               # 0 none, 1 from the next game, 2 now (until that game ends)
var offers := 0                   # shown (this run of the game: tests)
var chance_roll := -1.0           # tests: a fixed roll instead of main.rng
var _applied := {}                # what this hub has added to Skills.mods_layer
var _strength := 0.0


## Whether the button is offered (pure: the rules of the spec, section 1). ctx: winner,
## reason, rally, match_over, autoplay, practice, allowed (false online), games_since,
## smashed (already this match), roll (0..1).
static func should_offer(ctx: Dictionary) -> bool:
	if ctx.get("autoplay", false) or ctx.get("match_over", false) or not ctx.get("allowed", true):
		return false
	if int(ctx.get("winner", -1)) != 1 or not String(ctx.get("reason", "")) in REASONS:
		return false
	if ctx.get("practice", false):
		return true   # training: always, to learn it
	if ctx.get("smashed", false) or int(ctx.get("games_since", 0)) < COOLDOWN_GAMES:
		return false
	return float(ctx.get("roll", 1.0)) < chance(int(ctx.get("rally", 0)))


## "Sometimes": more likely after a long rally thrown away.
static func chance(rally: int) -> float:
	return clampf(0.35 + 0.04 * float(rally), 0.35, 0.7)


## The mods «Выпустил пар» wants in force now.
static func wanted(window_points: int, rest: int) -> Dictionary:
	var out := {}
	if window_points > 0:
		for k in WINDOW_MODS:
			out[k] = float(out.get(k, 0.0)) + float(WINDOW_MODS[k])
	if rest == 2:
		for k in REST_MODS:
			out[k] = float(out.get(k, 0.0)) + float(REST_MODS[k])
	return out


func setup(m: Node) -> void:
	main = m
	smash = RacketSmash.new()
	add_child(smash)
	smash.broken.connect(func(s: float) -> void: _strength = s)
	smash.finished.connect(_on_done)
	main.hud.smash_pressed.connect(press)
	var ev: Node = get_node("/root/GameEvents")
	ev.match_started.connect(func(_i: Dictionary) -> void: reset())
	ev.match_finished.connect(func(_i: Dictionary) -> void: reset())


## A new match, or the match is over: nothing carries on.
func reset() -> void:
	offer_left = 0.0
	games_since = COOLDOWN_GAMES
	smashed = false
	perfect_left = 0
	rest_state = 0
	if smash.is_active():
		smash.abort()
	smash.clear_shards()
	main.hud.hide_smash_offer()
	main.hud.show_smash_prompt(-1)
	_refresh_buff()


## Main, after a point is decided and the score has moved on. `game_ended`: it finished a game.
func point_over(winner: int, reason: String, game_ended: bool) -> void:
	if perfect_left > 0:
		perfect_left -= 1
	if game_ended:
		games_since += 1
		if rest_state == 2:
			rest_state = 0
		elif rest_state == 1:
			rest_state = 2
	_refresh_buff()
	var ctx := {
		"winner": winner, "reason": reason, "rally": main.rally, "match_over": main._match_over,
		"autoplay": main.autoplay, "practice": not main.tournament_mode, "allowed": true,
		"games_since": games_since, "smashed": smashed,
		"roll": chance_roll if chance_roll >= 0.0 else main.rng.randf(),
	}
	if not should_offer(ctx):
		return
	offers += 1
	games_since = 0
	offer_left = WINDOW
	main.phase_timer = maxf(main.phase_timer, WINDOW)  # the next serve waits for the window
	main.hud.show_smash_offer(1.0)
	GameEvents.racket_smash_offered.emit({"reason": reason, "rally": main.rally, "window": WINDOW})


func _process(delta: float) -> void:
	if offer_left > 0.0:
		offer_left -= delta
		if main.phase != main.Phase.OVER or offer_left <= 0.0:
			offer_left = 0.0
			main.hud.hide_smash_offer()
		else:
			main.hud.show_smash_offer(offer_left / WINDOW)
	if main.phase == main.Phase.SMASH:
		main.hud.show_smash_prompt(smash.swipes, smash.rejected)
	if smash.is_active() and main.phase == main.Phase.IDLE:
		smash.abort()  # left for the menu mid-way
	if perfect_left == 0 and rest_state == 0 and not _applied.is_empty():
		_refresh_buff()
	if main.phase == main.Phase.IDLE and (smashed or perfect_left > 0 or rest_state > 0):
		reset()


## The button was pressed: the match stands, the hero takes the racket in both hands.
func press() -> void:
	if offer_left <= 0.0 or main.phase != main.Phase.OVER:
		return
	offer_left = 0.0
	main.hud.hide_smash_offer()
	main.phase = main.Phase.SMASH
	main._move_target = Vector3.INF
	main.hud.announcer.set_hint("свайп вверх — замах, вниз — удар")
	main.hud.show_smash_prompt(0)
	var stop := func(ms: int) -> void:
		if Tuning.hitstop and not main.autoplay:
			main._hitstop_until_ms = Time.get_ticks_msec() + ms
	smash.begin(main.player, main, main.cam, main.sfx, stop)


## Main's touch handlers, in Phase.SMASH.
func on_swipe(points: PackedVector2Array, times: PackedInt32Array) -> void:
	var c := RacketSmash.classify(points, times, main.get_viewport().get_visible_rect().size.y)
	smash.swipe(int(c["dir"]), float(c["power"]))
	main.hud.show_smash_prompt(smash.swipes, smash.rejected)
	main._haptic("heavy" if smash.swipes > 0 else "light")


func on_progress(points: PackedVector2Array) -> void:
	smash.progress(RacketSmash.pull(points, main.get_viewport().get_visible_rect().size.y))


func _on_done(was_broken: bool) -> void:
	main.hud.announcer.set_hint("")
	main.hud.show_smash_prompt(-1)
	if was_broken:
		smashed = true
		main.player.set_racket({})  # the club's spare one: plain, the worn one is mended after the match
		_grant()
		GameEvents.racket_smashed.emit({"strength": _strength, "swipes": smash.swipes, "tournament": main.tournament_mode})
		main.hud.announcer.moment("ВЫПУСТИЛ ПАР", UiTheme.GOLD, "восстановление, окно PERFECT · ракетка запасная")
	if main.phase == main.Phase.SMASH:
		main.phase = main.Phase.OVER
		main.phase_timer = AFTER


## «Выпустил пар»: the PERFECT window for the next points, the legs' recovery from the next
## game on (now, if the game just began).
func _grant() -> void:
	perfect_left = WINDOW_POINTS
	var fresh: bool = main.scoreboard.points[0] == 0 and main.scoreboard.points[1] == 0
	rest_state = 2 if fresh else 1
	_refresh_buff()


## Skills.mods_layer carries the bonus; only the difference to what is already added moves.
func _refresh_buff() -> void:
	var want := wanted(perfect_left, rest_state)
	var keys := {}
	for k in _applied:
		keys[k] = true
	for k in want:
		keys[k] = true
	for k in keys:
		var diff := float(want.get(k, 0.0)) - float(_applied.get(k, 0.0))
		if absf(diff) < 0.000001:
			continue
		var v := float(Skills.mods_layer.get(k, 0.0)) + diff
		if absf(v) < 0.000001:
			Skills.mods_layer.erase(k)
		else:
			Skills.mods_layer[k] = v
	_applied = want
