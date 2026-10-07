extends SceneTree
## Stream C (the non-match UI and the HUD overlays) tests, headless:
##   godot --headless --path . -s tests/ui_test.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_fit_size()
	test_calls()
	test_announcer_column()
	test_announcer_center()
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


## One column under the score: a new call replaces the old, two toasts at most (the
## same skill updates in place), a reserved slot (VAR, the style plate) sits in it.
func test_announcer_column() -> void:
	print("announcer column")
	var a := HudAnnouncer.new()
	root.add_child(a)
	a.size = Vector2(720, 1564)
	a.set_safe_area(180.0, 60.0)
	a.call_point("BASILASHVILI DOUBLE FAULT", "GAME · YOU", UiTheme.WIN)
	a.call_point("ACE!", "", UiTheme.WIN)
	check(a.column_items().size() == 1, "a new call replaces the old one")
	for i in 4:
		a.toast("НОГИ %d" % (3 + i), "feet")
	check(a.column_items().size() == 2, "the same skill updates its toast: %d" % a.column_items().size())
	a.toast("ФОРХЕНД 5", "forehand")
	a.toast("ПОДАЧА 2", "serve")
	check(a.column_items().size() == 1 + HudAnnouncer.MAX_TOASTS, "two toasts at most: %d" % a.column_items().size())
	check(a.waiting_toasts() == 1, "the third waits")
	var y := a.reserve(190.0, 2.6)
	check(y >= 180.0 + HudAnnouncer.COLUMN_TOP + 40.0, "a reserved slot sits under the call: %d" % y)
	check(a.column_items()[1].has_meta("slot"), "right after the call, before the toasts")
	var call: Control = a.column_items()[0]
	check(call.get_combined_minimum_size().x <= HudAnnouncer.WIDTH, "the call is no wider than the column")
	a.finish_now()
	check(a.column_items().is_empty() and a.waiting_toasts() == 0, "finish_now clears the column")
	a.free()


## The centre holds one moment at a time; the rest wait their turn; a tap skips.
func test_announcer_center() -> void:
	print("announcer centre")
	var a := HudAnnouncer.new()
	root.add_child(a)
	a.size = Vector2(720, 1564)
	a.moment("KNOCKOUT!", UiTheme.GOLD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var item := Gear.roll(Gear.LEGENDARY, rng)
	a.item_card(item, "ТРОФЕЙ")
	check(a.center_item() != null and a.waiting_moments() == 1, "one moment shown, one waiting")
	a.skip()
	var card := a.center_item() as GameCard
	check(card != null and card.rarity == Gear.LEGENDARY, "the trophy is a card with its rarity")
	check(card != null and card.custom_minimum_size.x <= 560.0, "the card fits the screen")
	a.intro("ВТОРОЙ КРУГ", "Николоз Басилашвили")
	a.skip()
	check(a.center_item() != null and a.waiting_moments() == 0, "the intro follows")
	a.set_hint("Подача по бегущему: попади в него мячом")
	check(a.hint_text() != "", "the hint is up")
	a.set_hint("")
	check(a.hint_text() == "", "and gone")
	a.free()
