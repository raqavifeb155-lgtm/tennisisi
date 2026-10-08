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
	check(finished == 6, "every test ran to its end: %d of 6" % finished)
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
