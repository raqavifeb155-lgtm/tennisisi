extends SceneTree
## Stream C (the non-match UI and the HUD overlays) tests, headless:
##   godot --headless --path . -s tests/ui_test.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_fit_size()
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
