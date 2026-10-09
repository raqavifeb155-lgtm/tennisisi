extends SceneTree
## Stream C (the non-match UI and the HUD overlays) tests, headless:
##   godot --headless --path . -s tests/ui_test.gd

var failures := 0
var finished := 0                 # tests that ran to their end (a script error stops one short)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_fit_size()
	test_calls()
	await test_announcer_strip()
	await test_announcer_moments()
	await test_modal_stack()
	test_layers()
	test_graphics_labels()
	test_match_tally()
	test_thumb_keys()
	await test_card_turn()
	await test_reward_flow()
	await test_flights()
	check(finished == 12, "every test ran to its end: %d of 12" % finished)
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


## A call is as big as fits the column: 56 px for "ACE!", smaller for a long name, and
## never below the floor (the label wraps from there).
func test_fit_size() -> void:
	print("fit size")
	var f := UiTheme.display()
	check(UiText.fit_size(f, "ACE!", 640.0, 56, 40) == 56, "a short call keeps 56")
	var long_name := "BASILASHVILI DOUBLE FAULT"
	var s := UiText.fit_size(f, long_name, 640.0, 56, 40)
	check(s < 56 and s >= 40, "a long call shrinks: %d" % s)
	check(UiText.fits(f, long_name, 640.0, s) or s == 40, "and fits, or stops at the floor")
	check(UiText.fit_size(f, "ГЕЙМ\nБАСИЛАШВИЛИ ДВОЙНАЯ ОШИБКА ПОДАЧИ", 640.0, 56, 40) == 40, "the widest line decides")
	finished += 1


## The court calls: English, upper case, one language per line (UI_FLOW_TZ 5.6).
func test_calls() -> void:
	print("calls")
	check(Calls.point(true, "OUT", "RUBLEV") == "RUBLEV OUT", "their out")
	check(Calls.point(true, "WINNER", "RUBLEV") == "WINNER!", "your winner")
	check(Calls.point(false, "ACE", "RUBLEV") == "RUBLEV ACE", "their ace")
	check(Calls.point(false, "WINNER", "RUBLEV") == "MISSED", "their winner")
	check(Calls.score(MatchScore.Event.GAME, true, "RUBLEV") == "GAME · YOU", "game to you")
	check(Calls.score(MatchScore.Event.SET, false, "RUBLEV") == "SET · RUBLEV", "set to them")
	check(Calls.score(MatchScore.Event.MATCH, true, "RUBLEV") == "MATCH · YOU", "match to you")
	check(Calls.score(MatchScore.Event.POINT, true, "RUBLEV") == "", "a point: no second line")
	check(Calls.fault("NET") == "NET · FAULT" and Calls.fault("LONG") == "FAULT", "faults")
	var latin := RegEx.create_from_string("^[A-Z]+$")
	for o in Opponents.ROSTER:
		check(latin.search(String(o.get("short_en", ""))) != null, "latin short name: %s" % o.get("short_en", "-"))
	finished += 1


## The TV strip: one item at a time; a new call cuts in (an old call goes, a level-up
## waits again); the same skill updates its line; the strip stays narrow and above the
## far court (UI_FLOW_TZ 5, the owner's "ТВ-строка").
func test_announcer_strip() -> void:
	print("announcer strip")
	var a := HudAnnouncer.new()
	root.add_child(a)
	a.size = Vector2(720, 1564)
	a.set_safe_area(180.0, 60.0)
	a.toast("НОГИ 3", "feet")
	a.call_point("BASILASHVILI DOUBLE FAULT", "GAME · BASILASHVILI", UiTheme.WIN)
	check(a.current().get("kind", "") == "call", "a call cuts in front of a level-up")
	check(a.waiting() == 1, "and the level-up waits again")
	a.call_point("ACE!", "", UiTheme.WIN)
	check(a.current().get("main", "") == "ACE!" and a.waiting() == 1, "a new call replaces the old one")
	for i in 4:
		a.toast("НОГИ %d" % (4 + i), "feet")
	check(a.waiting() == 1, "the same skill updates its line: %d waiting" % a.waiting())
	a.toast("ФОРХЕНД 5", "forehand", true)
	check(a.waiting() == 2, "another skill queues")
	await process_frame
	var strip := a.strip()
	check(strip.size.x <= HudAnnouncer.WIDTH, "the strip is no wider than %d: %d" % [HudAnnouncer.WIDTH, strip.size.x])
	check(strip.size.y <= 110.0, "and narrow: %d tall" % strip.size.y)
	check(strip.position.y >= 180.0 + HudAnnouncer.STRIP_TOP - 0.5 and strip.get_rect().end.y < 1564.0 * 0.36, "under the score, above the far court (y %d..%d, far baseline ~560)" % [strip.position.y, strip.get_rect().end.y])
	a.call_point("BASILASHVILI DOUBLE FAULT", "GAME · BASILASHVILI", UiTheme.WIN)
	await process_frame
	check(a.strip().size.x <= HudAnnouncer.WIDTH, "the longest call fits too: %d" % a.strip().size.x)
	a.finish_now()
	check(a.current().is_empty() and a.waiting() == 0, "finish_now clears it")
	a.free()
	finished += 1


## Big moments ride the same strip: the intro, KNOCKOUT!, the trophy in its rarity.
func test_announcer_moments() -> void:
	print("announcer moments")
	var a := HudAnnouncer.new()
	root.add_child(a)
	a.size = Vector2(720, 1564)
	a.moment("KNOCKOUT!", UiTheme.GOLD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	a.item_card(Gear.roll(Gear.LEGENDARY, rng), "ТРОФЕЙ")
	check(a.current().get("main", "") == "KNOCKOUT!" and a.waiting() == 1, "one shown, one waiting")
	a.skip()
	check(a.current().get("kind", "") == "item" and int(a.strip().get_meta("rarity", -1)) == Gear.LEGENDARY, "the trophy wears its rarity")
	await process_frame
	check(a.strip().size.x <= HudAnnouncer.WIDTH, "the trophy's name fits: %d" % a.strip().size.x)
	a.intro("ВТОРОЙ КРУГ", "Николоз Басилашвили")
	a.skip()
	check(a.current().get("main", "") == "ВТОРОЙ КРУГ", "the intro follows")
	a.set_hint("Подача по бегущему: попади в него мячом")
	check(a.hint_text() != "", "the hint is up")
	a.set_hint("тап по корту — подброс\nкороткий свайп вниз до подброса — подача снизу")
	await process_frame
	check(a._hint.size.y < 260.0, "a two-line hint is a thin plate, not a screen tall: %d" % a._hint.size.y)
	a.set_hint("")
	check(a.hint_text() == "", "and gone")
	a.free()
	finished += 1




## One owner of the pause (UI_FLOW_TZ 5.5, rule 4): the game stands while a window opened
## from a match is in the stack; closing returns to the window under it.
func test_modal_stack() -> void:
	print("modal stack")
	var m := ModalStack.new()
	root.add_child(m)
	var nodes := {}
	for id in ["settings", "pause", "help", "confirm"]:
		var c := Control.new()
		root.add_child(c)
		nodes[id] = c
	m.push("settings", nodes["settings"], false)
	check(m.top() == "settings" and not paused, "settings outside a match: no pause")
	m.pop("settings")
	check(m.is_empty(), "closed")
	m.push("pause", nodes["pause"], true)
	check(paused, "the pause stops the game")
	m.push("help", nodes["help"], true)
	m.pop("help")
	check(m.top() == "pause" and paused, "help closed: back to the pause, still paused")
	m.push("settings", nodes["settings"], true)
	m.pop("settings")
	check(m.top() == "pause" and paused, "settings closed: back to the pause")
	m.push("confirm", nodes["confirm"], true)
	m.pop("pause")
	check(m.is_empty() and not paused, "closing the pause closes what is over it and resumes")
	m.push("help", nodes["help"], true)
	check(m.has("help") and paused, "help from a match pauses")
	nodes["help"].visible = false  # tools hide it from outside
	await process_frame
	await process_frame
	check(m.is_empty() and not paused, "a hidden top window leaves the stack, the pause goes")
	paused = true  # someone else's pause: the stack doesn't fight it
	await process_frame
	check(paused, "the stack writes the pause only when its own decision changes")
	paused = false
	for c in nodes.values():
		c.free()
	m.free()
	finished += 1


## The layer map lives in UiTheme, in the order of UI_FLOW_TZ 5.5.
func test_layers() -> void:
	print("layers")
	var order := [UiTheme.LAYER_HUD, UiTheme.LAYER_STYLE, UiTheme.LAYER_CLUB, UiTheme.LAYER_SCREENS,
		UiTheme.LAYER_SHEETS, UiTheme.LAYER_PAUSE, UiTheme.LAYER_CONFIRM, UiTheme.LAYER_HELP, UiTheme.LAYER_LOADING]
	var sorted := order.duplicate()
	sorted.sort()
	check(order == sorted, "layers go up: %s" % str(order))
	check(UiTheme.LAYER_SCREENS == 10 and UiTheme.LAYER_PAUSE == 20 and UiTheme.LAYER_HELP == 30, "screens 10, pause 20, help 30")
	finished += 1


## Graphics (HANDOFF 9.6): on a phone "Авто" never goes above Medium (High stutters in
## Telegram); High and Max say so on the button and in the line under the presets.
func test_graphics_labels() -> void:
	print("graphics labels")
	check(GraphicsQuality.auto_steps(true) == [GraphicsQuality.MEDIUM, GraphicsQuality.LOW], "phone: Auto is Medium, then Low")
	check(GraphicsQuality.auto_steps(false) == [GraphicsQuality.HIGH, GraphicsQuality.MEDIUM, GraphicsQuality.LOW], "computer: Auto starts at High")
	for i in [GraphicsQuality.HIGH, GraphicsQuality.MAX]:
		check("!" in GraphicsQuality.caption(i), "the %s button is marked" % GraphicsQuality.NAMES[i])
		check("Telegram" in GraphicsQuality.note(i, false), "and its line warns about Telegram")
	for i in [GraphicsQuality.AUTO, GraphicsQuality.LOW, GraphicsQuality.MEDIUM]:
		check(not "!" in GraphicsQuality.caption(i) and not "Telegram" in GraphicsQuality.note(i, false), "%s is not marked" % GraphicsQuality.NAMES[i])
	check("Средней" in GraphicsQuality.note(GraphicsQuality.AUTO, true), "Auto on a phone says its cap")
	finished += 1


## The match's numbers for the result screen (HANDOFF 7.3), from GameEvents payloads.
func test_match_tally() -> void:
	print("match tally")
	var t := MatchTally.new()
	t.shot(0, {"side": 1, "serve": false, "incoming": 20.0})
	check(t.forehands[0] == 0, "nothing counts before the match starts")
	t.start()
	# Point 1: you serve, the first serve faults, the second goes in; a rally; you hit a
	# winner with your backhand.
	t.fault({"server": 0, "second": false})
	t.shot(0, {"side": 1, "serve": true, "incoming": 0.0})
	t.shot(1, {"side": 1, "serve": false, "incoming": 30.0})
	t.shot(0, {"side": -1, "serve": false, "incoming": 25.0})
	t.point({"winner": 0, "reason": "WINNER", "rally": 3, "server": 0})
	# Point 2: an ace.
	t.shot(0, {"side": 1, "serve": true, "incoming": 0.0})
	t.point({"winner": 0, "reason": "ACE", "rally": 1, "server": 0})
	# Point 3: a double fault.
	t.fault({"server": 0, "second": false})
	t.fault({"server": 0, "second": true})
	t.point({"winner": 1, "reason": "DOUBLE FAULT", "rally": 1, "server": 0})
	# Point 4: they serve; you push a slow ball out (unforced).
	t.shot(1, {"side": 1, "serve": true, "incoming": 0.0})
	t.shot(0, {"side": 1, "serve": false, "incoming": 30.0})
	t.shot(1, {"side": -1, "serve": false, "incoming": 18.0})
	t.shot(0, {"side": 1, "serve": false, "incoming": 15.0})
	t.point({"winner": 1, "reason": "OUT", "rally": 4, "server": 1})
	# Point 5: they serve; you miss into the net under a heavy ball (forced).
	t.shot(1, {"side": 1, "serve": true, "incoming": 0.0})
	t.shot(0, {"side": -1, "serve": false, "incoming": 34.0})
	t.point({"winner": 1, "reason": "NET", "rally": 2, "server": 1})
	t.finish()
	t.shot(0, {"side": 1, "serve": false, "incoming": 10.0})  # the trophy mini-game after
	check(t.forehands == [2, 1] and t.backhands == [2, 1], "forehands %s, backhands %s (serves apart)" % [t.forehands, t.backhands])
	check(t.aces == [1, 0] and t.doubles == [1, 0], "aces and double faults")
	check(t.winners == [1, 0], "winners (aces apart)")
	check(t.unforced == [1, 0], "a slow ball out is unforced, a heavy one into the net is not")
	check(t.first_serve_pct(0) == 33 and t.first_serve_pct(1) == 100, "first serve in: you 1 of 3, them 2 of 2: %d / %d" % [t.first_serve_pct(0), t.first_serve_pct(1)])
	check(t.best_rally == 4, "the best rally")
	var rows := t.rows()
	check(rows.size() == 7 and rows[0][0] == "Эйсы" and rows[0][1] == "1", "rows for the screen: %s" % str(rows[0]))
	check(t.has_data(), "a finished match has numbers")
	t.start()
	check(not t.has_data() and t.aces == [0, 0], "a new match starts from zero")
	finished += 1


# --- v0.2 L: loot cards ---------------------------------------------------------------

func timer(s: float) -> void:
	await create_timer(s, true, false, true).timeout


# Scripts that use TournamentUI come through load(): a test compiles before the autoloads exist.
var TUI: GDScript
var BAG: GDScript
var FX: GDScript


func _ui():
	if TUI == null:  # loaded now, not as the script's members: the autoloads exist by this time
		TUI = load("res://scripts/tournament_ui.gd")
		BAG = load("res://scripts/ui/screens/run_bag.gd")
		FX = load("res://scripts/ui/item_fx.gd")
	root.size = Vector2i(720, 1564)
	var ui = TUI.new()
	root.add_child(ui)
	return ui


func _cards(ui) -> Array:
	return ui._box.get_children().filter(func(c): return c is GameCard)


## One picture per look: a catalog thing by its id (the level is not in the key: it does not
## change the look), a generated one by slot and rarity, the stock one by slot; and every
## one of them has a model to draw (the render itself needs a renderer: tests/thumb_render_test.gd).
func test_thumb_keys() -> void:
	print("thumb keys")
	var keys := {}
	for e in Items.LIST:
		keys[ItemThumb.key(Items.instance(e))] = true
	check(Items.LIST.size() == 25 and keys.size() == 25, "25 things, 25 pictures: %d" % keys.size())
	var lv3 := Items.instance(Items.find("sun"))
	Items.set_level(lv3, 3)
	check(ItemThumb.key(lv3) == ItemThumb.key(Items.instance(Items.find("sun"))), "a level does not change the look: one picture")
	var g0 := {"slot": "shoes", "rarity": 0, "name": "x", "mods": {}, "lines": []}
	var g1 := {"slot": "shoes", "rarity": 1, "name": "x", "mods": {}, "lines": []}
	check(ItemThumb.key(g0) != ItemThumb.key(g1) and ItemThumb.key({}, "band") != ItemThumb.key({}, "racket"), "generated by slot and rarity, stock by slot")
	var all: Array = [g0, g1, {}]
	for e in Items.LIST:
		all.append(Items.instance(e))
	var drawable := true
	for it in all:
		var pivot := ItemThumb.stage(it, "racket" if (it as Dictionary).is_empty() else "")
		var meshes := pivot.find_children("*", "MeshInstance3D", true, false)
		drawable = drawable and not meshes.is_empty()
		pivot.free()
	check(drawable, "every thing builds a model to draw")
	check(ItemThumb.POOL == 3, "at most 3 pictures in one frame")
	finished += 1


## A face-down card shows nothing readable (its back has no text), turns over and then shows it.
func test_card_turn() -> void:
	print("card turn")
	var host := Control.new()
	host.size = Vector2(664, 400)
	root.add_child(host)
	var c := GameCard.new()
	c.title = "Перо"
	c.desc = "Окно PERFECT на касании +15%"
	c.tag = "Ракетка"
	c.rarity = Gear.EPIC
	c.face_down = true
	c.size = Vector2(664, 200)
	host.add_child(c)
	await process_frame
	await process_frame
	check(c.visible_text() == "", "before the turn nothing can be read: '%s'" % c.visible_text())
	check((c._back as Control).find_children("*", "Label", true, false).is_empty(), "the back has no text of its own")
	var order: Array[String] = []
	c.flipped.connect(func() -> void: order.append("flipped"))
	c.revealed.connect(func() -> void: order.append("revealed"))
	c.flip()
	check(not c.is_open(), "a turning card cannot be taken yet")
	await timer(0.5)
	check(not c.face_down and c.is_open(), "after the turn it is face up and open")
	check("Перо" in c.visible_text() and "касании" in c.visible_text(), "and the text can be read")
	check(order == ["flipped", "revealed"], "the face swaps mid-turn, then the card is revealed: %s" % str(order))
	host.free()
	finished += 1


## The reward: three backs with nothing to read, turning 0.15 s apart; a tap on a back turns all.
func test_reward_flow() -> void:
	print("reward flow")
	var ui = _ui()
	var t := Tournament.new(1, 4)
	t.state = Tournament.State.REWARD
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var shoes := Gear.roll(Gear.RARE, rng, "shoes")
	t.offer = [Rewards.offer([], rng)[0], {"kind": "item", "item": shoes, "title": shoes["name"], "desc": Gear.describe(shoes)}, Rewards.WILDCARD.duplicate()]
	ui.show_reward(t)
	await timer(0.3)
	var cards := _cards(ui)
	check(cards.size() == 3 and cards.all(func(c): return c.face_down), "three cards, all face down")
	check(cards.all(func(c): return c.visible_text() == ""), "none of them shows a word")
	check(ui.bag_chip.visible and ui.bag_chip.count == BAG.carried(t), "the bag chip is on the screen with the count")
	var at: Array[int] = []
	for c in cards:
		c.flipped.connect(func() -> void: at.append(Time.get_ticks_msec()))
	await timer(TUI.REVEAL_WAIT + 0.15 * 2 + 0.8)
	check(cards.all(func(c): return c.is_open() and c.visible_text() != ""), "after the turns all are open and readable")
	check(at.size() == 3 and (at[1] - at[0]) >= 100 and (at[1] - at[0]) <= 260 and (at[2] - at[1]) >= 100 and (at[2] - at[1]) <= 260,
		"they turned one after another, about 0.15 s apart: %s" % str(at))
	ui.show_reward(t)
	await timer(0.3)
	cards = _cards(ui)
	(cards[2] as GameCard).pressed.emit()  # a tap on a back
	await timer(0.45)
	check(cards.all(func(c): return c.is_open()), "a tap on a back turns the whole row at once")
	ui.show_skill_perk("forehand", Skills.PERKS["forehand"].slice(0, 3))
	await timer(0.4)
	check(_cards(ui).size() == 3 and _cards(ui).all(func(c): return not c.face_down and not c.flipping and c.visible_text() != ""),
		"a perk's choice is known before: no turning, text from the start")
	ui.queue_free()
	finished += 1


## A thing flies into the bag chip (the count and the «+1»), coins into the gold chip; the chips
## do not run into each other.
func test_flights() -> void:
	print("flights")
	var ui = _ui()
	var t := Tournament.new(1, 4)
	t.gold = 30
	t.pending_loot = Items.instance(Items.find("twister"))
	ui.show_loot(t)
	await timer(0.5)
	var take: Button = ui._actions.get_child(0)
	check(take.has_meta("fly"), "«НАДЕТЬ» carries the thing")
	var have: int = BAG.carried(t)
	check(ui.bag_chip.count == have, "the chip shows what you have before")
	var done := [false]
	var t0 := Time.get_ticks_msec()
	var plan: Dictionary = take.get_meta("fly")
	(func() -> void:
		await FX.run(ui, plan)
		done[0] = true).call()
	var guard := 0.0
	while not done[0] and guard < 3.0:
		await timer(0.05)
		guard += 0.05
	check(done[0] and Time.get_ticks_msec() - t0 < 1500, "the flight ends in %d ms" % (Time.get_ticks_msec() - t0))
	check(ui.bag_chip.count == have + 1 and ui.bag_chip.badge_text() == "+1", "the chip counts it and shows +1: %d %s" % [ui.bag_chip.count, ui.bag_chip.badge_text()])
	# The landing bumps the chip (scale 1.22 and back, ~0.35 s; the tween starts on the next frame)
	# and a container re-sorts at the end of the frame: measure the resting layout, not the bump
	# (it flaked, the gap to the run's chip is 4 px).
	await process_frame
	await process_frame
	var settle := 0.0
	while settle < 3.0 and not ui.bag_chip.scale.is_equal_approx(Vector2.ONE):
		await timer(0.05)
		settle += 0.05
	await process_frame
	var rc: Rect2 = ui.bag_chip.get_global_rect()
	check(rc.end.x <= 720.0 - TUI.HUD_BUTTON_W + 14.0 and not rc.intersects(ui._chip.get_global_rect()) and not rc.intersects(ui._run_chip.get_global_rect()), "the bag chip stands clear of the gold chips and the ⚙ corner")
	# A sale pours coins into the run's chip.
	t.pending_loot = {}
	var spare := Gear.roll(Gear.RARE, RandomNumberGenerator.new(), "racket")
	t.bag = [spare]
	BAG.show_item(ui, t, BAG.BAG_ARG)
	await timer(0.4)
	var sell: Button = null
	for b in ui._actions.get_children():
		if b is Button and "Продать" in (b as Button).text:
			sell = b
	check(sell != null and sell.has_meta("fly") and sell.get_meta("fly")["kind"] == "coins", "«Продать» carries coins")
	if sell != null:
		var plan2: Dictionary = sell.get_meta("fly")
		var done2 := [false]
		(func() -> void:
			await FX.run(ui, plan2)
			done2[0] = true).call()
		guard = 0.0
		while not done2[0] and guard < 3.0:
			await timer(0.05)
			guard += 0.05
		check(done2[0] and ui.chip_values().y == t.gold + Gear.price(spare), "the coins landed: the run's chip counts %d" % ui.chip_values().y)
	ui.queue_free()
	finished += 1
