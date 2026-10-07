extends SceneTree
## Stream C (the non-match UI and the HUD overlays) tests, headless:
##   godot --headless --path . -s tests/ui_test.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_fit_size()
	test_calls()
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
