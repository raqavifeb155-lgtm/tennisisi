## Run with a fixed step, the offer window counts real frames:
##   godot --headless --path . --fixed-fps 60 -s tests/smash_test.gd
extends SceneTree
## «Разбить ракетку» in a tournament match, in the live scene (the button, the mini-game, what it
## gives and what it costs; docs/superpowers/specs/2026-10-09-racket-smash.md):
##   godot --headless --path . --fixed-fps 60 -s tests/smash_test.gd

var failures := 0
var main: Node
var hub


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _initialize() -> void:
	var tuning := root.get_node("Tuning")
	tuning.slowmo_enabled = false
	tuning.hitstop = false
	SaveData.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A rally over: the player's ball goes out (or whatever `winner` and `reason` say).
func _point(winner: int, reason: String, rally := 6) -> void:
	main.phase = main.Phase.RALLY
	main.last_hitter = main.Who.PLAYER if winner == main.Who.CPU else main.Who.CPU
	main.rally = rally
	main.ball_used = true
	main._end_point(winner, reason)
	await _frames(2)


## Three swipes through the hub, as the touch layer gives them (path and time stamps).
func _swipes() -> void:
	var h := 1564.0
	var up := PackedVector2Array([Vector2(360, 900), Vector2(360, 540)])
	var dn := PackedVector2Array([Vector2(360, 540), Vector2(360, 900)])
	var t := PackedInt32Array([0, 80])
	var guard := 0
	while main.phase == main.Phase.SMASH and guard < 900:
		guard += 1
		await process_frame
		var sm: RacketSmash = hub.smash
		if sm.state == RacketSmash.S.READY and sm.swipes == 0:
			hub.smash.swipe(-1, 0.8)
		elif sm.state == RacketSmash.S.HELD:
			hub.smash.swipe(1, 0.9)


func _run() -> void:
	await _frames(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var t := Tournament.new(1, 5)
	var racket := Gear.roll(Gear.EPIC, rng)
	t.equip["racket"] = racket
	main.tournament = t
	main.tournament_mode = true
	main._play_match()
	await _frames(5)
	hub = main.smash_hub
	hub.chance_roll = 0.0   # the dice always say yes: the rules are what is tested
	check(not Skills.gear.is_empty(), "the epic racket's mods are in force (%d)" % Skills.gear.size())
	var win0: float = Skills.stroke("forehand")["window"]
	var plates := []
	main.run_hub.style_scored.connect(func(r: Dictionary) -> void: plates.append(r))

	print("the offer")
	await _point(main.Who.PLAYER, "WINNER")
	check(hub.offer_left == 0.0 and not main.hud.smash_btn.visible, "a point the player won: no button")
	await _point(main.Who.CPU, "WINNER")
	check(hub.offer_left == 0.0, "the opponent's winner: no button")
	await _point(main.Who.CPU, "OUT")
	check(hub.offer_left > 2.0 and main.hud.smash_btn.visible, "a ball hit out: the button, a 2.5 s window")
	check(main.phase == main.Phase.OVER and main.phase_timer >= 2.4, "the next serve waits for the window (%.1f s)" % main.phase_timer)
	check(main.hud.smash_btn.get_global_rect().size.x >= 84.0, "the button is a thumb's size")
	var win_before: float = hub.offer_left
	await _frames(30)
	check(hub.offer_left < win_before - 0.3 and main.hud.smash_btn.left < 0.9, "the window runs out (the ring on the button)")
	await _frames(int(3.0 * 60.0))
	check(hub.offer_left == 0.0 and not main.hud.smash_btn.visible, "unanswered: the button goes and the game carries on")
	check(main.phase != main.Phase.SMASH, "...no mini-game")
	await _frames(60)

	print("cooldown")
	await _point(main.Who.CPU, "NET")
	check(hub.offer_left == 0.0, "an error again at once: not offered (once in 3 games)")
	hub.games_since = SmashHub.COOLDOWN_GAMES
	check(hub.offers == 1, "one offer so far")

	print("the smash")
	await _point(main.Who.CPU, "DOUBLE FAULT")
	check(hub.offer_left > 2.0, "three games later a double fault is offered again")
	var points_before: int = main._points_played
	hub.press()
	check(main.phase == main.Phase.SMASH and hub.smash.is_active(), "pressed: the match stands in Phase.SMASH")
	check(not main.hud.smash_btn.visible and main.hud.smash_prompt.visible, "the button is gone, the three swipes show")
	main.player.move_input = Vector2(1, 0)
	await _frames(10)
	check(main.player.move_input == Vector2.ZERO, "the stick does not move the hero meanwhile")
	var events := []
	root.get_node("GameEvents").racket_smashed.connect(func(i: Dictionary) -> void: events.append(i))
	await _swipes()
	check(hub.smashed and hub.smash.swipes == 3 and events.size() == 1, "three swipes: the racket is smashed, racket_smashed fired once")
	check(events[0]["tournament"] and float(events[0]["strength"]) > 0.5, "the event carries the strength (%.2f) and the mode" % float(events[0]["strength"]))
	check(main.phase == main.Phase.OVER and main.phase_timer <= SmashHub.AFTER + 0.01, "the match goes on from Phase.OVER")
	check(main.player.gear().get("racket", {}).is_empty(), "the hero holds the club's spare racket")
	check(main.tournament.equip["racket"] == racket, "the worn racket is not lost: it is whole in Tournament.equip")
	check(Skills.gear.is_empty(), "the cost: the racket's mods are off for the rest of the match (%s)" % str(Skills.gear))
	check(main.run_hub.match_fx.fx.style_boosts().is_empty(), "...and its style boosts")
	var win1: float = Skills.stroke("forehand")["window"]
	check(win1 > win0 * 1.05 or Skills.mod("forehand_window") >= 0.1, "the bonus: the PERFECT window is wider (%.2f -> %.2f)" % [win0, win1])
	var fresh: bool = main.scoreboard.points[0] == 0 and main.scoreboard.points[1] == 0
	check(hub.perfect_left == 3 and hub.rest_state == (2 if fresh else 1), "the window lasts 3 points, the recovery %s (a game has %s just ended)" % ["is on now" if fresh else "starts with the next game", "" if fresh else "not"])
	hub.rest_state = 1   # a smash in the middle of a game, whatever the score above says
	hub._refresh_buff()

	print("the bonus runs out")
	await _frames(int(SmashHub.AFTER * 60.0) + 90)
	check(main.phase == main.Phase.SERVE or main.phase == main.Phase.WAIT or main.phase == main.Phase.RALLY, "the next point is played (phase %d)" % main.phase)
	check(main._points_played == points_before, "...it has not been counted twice")
	var rest0: float = Skills.stamina_rest("point")
	hub.point_over(main.Who.CPU, "WINNER", true)   # a game ends: the recovery bonus starts now
	check(hub.rest_state == 2 and Skills.stamina_rest("point") > rest0 + 0.02, "the next game: recovery +%.2f a point" % (Skills.stamina_rest("point") - rest0))
	hub.point_over(main.Who.CPU, "WINNER", true)   # ... and it is over
	check(hub.rest_state == 0 and hub.perfect_left == 1, "the bonus game ends: the recovery is back to normal, the window has 1 point left")
	check(not Skills.mods_layer.has("stamina_rest") and Skills.mods_layer.has("forehand_window"), "only the window is still on")
	hub.point_over(main.Who.CPU, "WINNER", false)
	check(hub.perfect_left == 0 and not Skills.mods_layer.has("forehand_window"), "three points later the window is back to normal")

	print("«Психанул» and once a match")
	main.phase = main.Phase.RALLY
	main.last_hitter = main.Who.PLAYER
	main.rally = 3
	main._end_point(main.Who.PLAYER, "WINNER")
	await _frames(2)
	check(not plates.is_empty() and plates.any(func(r): return r["tricks"].any(func(x): return x["id"] == "vented")), "a won point after the smash: «Психанул» x1.2 on the plate")
	check(not main.run_hub.meter.vent_next, "...and only that one")
	hub.games_since = SmashHub.COOLDOWN_GAMES
	await _point(main.Who.CPU, "OUT")
	check(hub.offer_left == 0.0, "the racket is already broken in this match: not offered again")

	print("a new match")
	root.get_node("GameEvents").match_started.emit({"tournament": true})
	check(not hub.smashed and Skills.mods_layer.is_empty() and hub.games_since >= SmashHub.COOLDOWN_GAMES, "a new match: the racket is whole again, the offers are back, no leftovers in Skills")

	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)
