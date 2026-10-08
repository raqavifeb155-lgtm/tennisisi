extends SceneTree
## Every overlay opened from every context, driven by real taps (push_input), so a modal
## that is covered, eats no taps or has no way out shows up as FAIL (UI_FLOW_TZ 5.5):
##   godot --path . --rendering-driver opengl3 -s tools/overlay_probe.gd
## Contexts: the Club, the tournament bracket, a match, the pause, a result screen, the
## trophy mini-game. Overlays: the settings / pause sheet, "Как играть". Prints one
## PASS / FAIL line per check and a total; exits 1 when anything fails.

var main: Node
var fails := 0
var checks := 0
var _chosen := ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout  # runs while the tree is paused


## A tap at the middle of a control, as a finger would do it.
func _tap(c: Control) -> void:
	if c == null:
		_check("кнопка для нажатия найдена", false)
		return
	var p := c.get_global_rect().get_center()
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = p
		root.push_input(e)
		await process_frame
	await _wait(0.35)  # TournamentUI reports a press after its little dip


func _check(what: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", what])


## The visible button whose text contains `text`, under `from`.
func _button(from: Node, text: String) -> Button:
	for c in from.find_children("*", "Button", true, false):
		var b := c as Button
		if b.is_visible_in_tree() and text in b.text:
			return b
	return null


func _tut() -> Control:
	return main.hud._tutorial


func _sheet() -> Control:
	return main.hud._debug_panel


## Opens "Как играть", turns a page with ДАЛЬШЕ and leaves with Закрыть.
func _tutorial_round(ctx: String) -> void:
	_check("%s: «Как играть» открылось" % ctx, _tut().visible)
	var page: int = _tut()._page
	var next := _button(_tut(), "ДАЛЬШЕ")
	_check("%s: «ДАЛЬШЕ» есть" % ctx, next != null)
	if next:
		await _tap(next)
		_check("%s: «ДАЛЬШЕ» листает" % ctx, _tut()._page == page + 1)
	var close := _button(_tut(), "Закрыть")
	_check("%s: «Закрыть» есть на странице" % ctx, close != null)
	if close:
		await _tap(close)
	_check("%s: обучение закрылось" % ctx, not _tut().visible)


func _run() -> void:
	root.size = Vector2i(720, 1564)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	main.ui.chosen.connect(func(a: String, _arg: int) -> void: _chosen = a)
	var gear: Button = main.hud._debug_btn

	# --- The Club ------------------------------------------------------------------
	main.ui.show_menu()
	await _wait(0.6)
	await _tap(_button(main.ui.root, "Как играть"))
	await _tutorial_round("Клуб → ?")
	_check("Клуб → ?: игра не на паузе после", not paused)
	_chosen = ""
	await _tap(_button(main.ui.root, "ТУРНИР"))
	_check("Клуб → ?: после закрытия «ТУРНИР» нажимается", _chosen == "start_tournament")

	main.ui.show_menu()
	await _wait(0.6)
	await _tap(gear)
	_check("Клуб → ⚙: настройки открылись", _sheet().visible)
	await _tap(_button(_sheet(), "Как играть"))
	await _tutorial_round("Клуб → ⚙ → Как играть")
	_check("Клуб → ⚙ → Как играть: не на паузе", not paused)
	await _tap(gear)
	var done := _button(_sheet(), "Готово")
	_check("Клуб → ⚙: «Готово» есть", done != null)
	if done:
		await _tap(done)
	_check("Клуб → ⚙: настройки закрылись", not _sheet().visible)
	_chosen = ""
	await _tap(_button(main.ui.root, "ТУРНИР"))
	_check("Клуб → ⚙ → Готово: Клуб нажимается", _chosen == "start_tournament")

	# --- The bracket ---------------------------------------------------------------
	var t := Tournament.new(1)
	main.tournament = t
	main.tournament_mode = true
	main.ui.show_bracket(t)
	await _wait(0.6)
	await _tap(gear)
	_check("Сетка → ⚙: настройки открылись", _sheet().visible)
	_check("Сетка → ⚙: «Выйти в меню» не показывается вне матча", _button(_sheet(), "Выйти в меню") == null)
	await _tap(_button(_sheet(), "Готово"))
	_chosen = ""
	await _tap(_button(main.ui.root, "НА КОРТ"))
	_check("Сетка → ⚙ → Готово: «НА КОРТ» нажимается", _chosen == "play")

	# --- A match and its pause --------------------------------------------------------
	main.tournament = null
	main.tournament_mode = false
	main._start_practice()
	await _wait(1.0)
	if _tut().visible:  # the first match opens the tutorial once
		await _tutorial_round("Первый матч")
	await _wait(0.3)
	_check("Матч: кнопка паузы читается как пауза", gear.text != "НАСТР")
	await _tap(gear)
	_check("Матч → пауза: открылась", _sheet().visible)
	_check("Матч → пауза: игра стоит", paused)
	await _tap(_button(_sheet(), "Продолжить"))
	_check("Матч → пауза → Продолжить: закрылась", not _sheet().visible)
	_check("Матч → пауза → Продолжить: игра идёт", not paused)

	await _tap(gear)
	await _tap(_button(_sheet(), "Как играть"))
	await _tutorial_round("Матч → пауза → Как играть")
	_check("Матч → пауза → Как играть → Закрыть: возврат в паузу", _sheet().visible and paused)
	if _sheet().visible:
		await _tap(_button(_sheet(), "Продолжить"))

	await _tap(gear)
	await _tap(_button(_sheet(), "Выйти в меню"))
	_check("Матч → пауза → Выйти: спрашивает подтверждение", main.ui.is_open() == false and _sheet().visible)
	await _wait(0.6)
	# The Club is the walkable 3D club since v0.2 B (the old list only with --old-menu).
	var in_club: bool = main.ui.is_open() or (main.get("club") != null and main.club.active)
	_check("Матч → пауза → Выйти: в итоге Клуб и не на паузе", in_club and not paused)

	# --- A result screen -------------------------------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var r := Tournament.new(1)
	r.record_match(true, "6:3", rng)
	r.pending_loot = {}
	main.tournament = r
	main.tournament_mode = true
	main.ui.show_result(r, true, "6:3", {"perfect": 3, "aces": 1, "best_rally": 9})
	await _wait(1.2)
	await _tap(gear)
	_check("Итог → ⚙: настройки открылись", _sheet().visible)
	_check("Итог → ⚙: «Выйти в меню» не показывается вне матча", _button(_sheet(), "Выйти в меню") == null)
	await _tap(_button(_sheet(), "Готово"))
	_chosen = ""
	await _tap(_button(main.ui.root, "НАГРАДУ"))
	_check("Итог → ⚙ → Готово: главное действие нажимается", _chosen == "to_reward")

	# --- The trophy mini-game ------------------------------------------------------
	main.ui.close()
	r.pending_loot = Gear.roll(Gear.EPIC, rng)
	main._start_bonus()
	await _wait(0.5)
	await _tap(gear)
	_check("Трофей → пауза: открылась и игра стоит", _sheet().visible and paused)
	await _tap(_button(_sheet(), "Продолжить"))
	_check("Трофей → пауза → Продолжить: игра идёт", not paused and not _sheet().visible)

	print("\nOVERLAYS: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
