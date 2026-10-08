extends SceneTree
## Every overlay opened from every context, driven by real taps (push_input), so a modal
## that is covered, eats no taps or has no way out shows up as FAIL (UI_FLOW_TZ 5.5):
##   godot --path . --rendering-driver opengl3 -s tools/overlay_probe.gd
## Contexts: the old 2D Club, the walkable 3D club and a place's screen, the tournament
## bracket, a practice match and a tournament match with their pause, a result screen,
## the trophy mini-game. Overlays: the pause, the settings sheet, the exit confirmation,
## "Как играть". Prints one PASS / FAIL line per check and a total; exits 1 on a failure.

var main: Node
var fails := 0
var checks := 0
var _chosen := ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout  # runs while the tree is paused


## A tap at a point of the screen, as a finger would do it.
func _tap_at(p: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = p
		root.push_input(e)
		await process_frame
	await _wait(0.35)  # TournamentUI reports a press after its little dip


## A tap at the middle of a control.
func _tap(c: Control) -> void:
	if c == null:
		_check("кнопка для нажатия найдена", false)
		return
	await _tap_at(c.get_global_rect().get_center())


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
	return main.hud.settings_sheet


func _pause() -> Control:
	return main.hud.pause_sheet


func _confirm() -> Control:
	return main.hud.confirm_sheet


func _gear() -> Button:
	return main.hud._debug_btn


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


## The settings sheet opened from a place that is not a match: no exit, no pause, and
## "ГОТОВО" closes it.
func _settings_round(ctx: String) -> void:
	_check("%s: настройки открылись" % ctx, _sheet().visible)
	_check("%s: игра не на паузе" % ctx, not paused)
	_check("%s: «Выйти» не показывается вне матча" % ctx, _button(_sheet(), "Выйти") == null)
	var done := _button(_sheet(), "ГОТОВО")
	_check("%s: «ГОТОВО» есть и внизу" % ctx, done != null and done.get_global_rect().position.y > root.size.y * 0.8)
	if done:
		await _tap(done)
	_check("%s: настройки закрылись" % ctx, not _sheet().visible)


## The pause's shape: the game stands, every button is a thumb's size, ПРОДОЛЖИТЬ is in
## the bottom third.
func _pause_shape(ctx: String) -> void:
	_check("%s: пауза открылась" % ctx, _pause().visible)
	_check("%s: игра стоит" % ctx, paused)
	var go := _button(_pause(), "ПРОДОЛЖИТЬ")
	_check("%s: «ПРОДОЛЖИТЬ» в нижней трети" % ctx, go != null and go.get_global_rect().position.y > root.size.y * 0.66)
	var small := 0
	for c in _pause().find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree() and (c as Button).size.y < 84.0:
			small += 1
	_check("%s: кнопки не меньше 84 px" % ctx, small == 0)


func _run() -> void:
	root.size = Vector2i(720, 1564)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	SaveData.enabled = false  # look, don't touch the player's progress
	Skills.pending = []       # no perk screen in the way of the menu
	main.ui.chosen.connect(func(a: String, _arg: int) -> void: _chosen = a)
	_check("кнопка ⚙/❚❚ — 84 px", _gear().size.y >= 84.0 and _gear().size.x >= 84.0)

	# --- The old 2D Club (-- --old-menu) -----------------------------------------------
	main.ui.show_menu()
	await _wait(0.6)
	await _tap(_button(main.ui.root, "Как играть"))
	await _tutorial_round("Клуб 2D → ?")
	_check("Клуб 2D → ?: игра не на паузе после", not paused)
	_chosen = ""
	await _tap(_button(main.ui.root, "ТУРНИР"))
	_check("Клуб 2D → ?: после закрытия «ТУРНИР» нажимается", _chosen == "start_tournament")

	main.ui.show_menu()
	await _wait(0.6)
	_check("Клуб 2D: кнопка — шестерёнка", _gear().kind == IconButton.GEAR)
	await _tap(_gear())
	await _settings_round("Клуб 2D → ⚙")
	_chosen = ""
	await _tap(_button(main.ui.root, "ТУРНИР"))
	_check("Клуб 2D → ⚙ → ГОТОВО: Клуб нажимается", _chosen == "start_tournament")

	# --- The walkable 3D club (the main screen since v0.2 B) ----------------------------
	main._show_menu()
	await _wait(1.5)
	var club = main.get("club")
	var in_3d: bool = club != null and club.active
	_check("Клуб 3D открылся", in_3d)
	if in_3d:
		await _tap(club.hud.gear)
		await _settings_round("Клуб 3D → ⚙")
		_check("Клуб 3D → ⚙ → ГОТОВО: клуб на месте", club.active and club.hud.visible)
		await _tap(club.hud._travel_btn)
		await _tap(_button(club.hud.root, "Как играть"))
		await _tutorial_round("Клуб 3D → ? (быстрый переход)")
		_check("Клуб 3D → ?: клуб живёт, не на паузе", club.active and not paused)
		# A place's screen over the club (Раздевалка), as the place's button opens it.
		main._on_ui("locker", 0)
		await _wait(0.8)
		_check("Клуб 3D → Раздевалка: ⚙ видна над экраном", _gear().is_visible_in_tree())
		await _tap(_gear())
		await _settings_round("Клуб 3D → Раздевалка → ⚙")
		_chosen = ""
		await _tap(_button(main.ui.root, "Назад"))
		_check("Клуб 3D → Раздевалка → ⚙ → ГОТОВО: «Назад» нажимается", _chosen == "menu")
		await _wait(0.8)

	# --- The bracket ---------------------------------------------------------------
	var t := Tournament.new(1)
	main.tournament = t
	main.tournament_mode = true
	main.ui.show_bracket(t)
	await _wait(0.6)
	await _tap(_gear())
	await _settings_round("Сетка → ⚙")
	_chosen = ""
	await _tap(_button(main.ui.root, "НА КОРТ"))
	_check("Сетка → ⚙ → ГОТОВО: «НА КОРТ» нажимается", _chosen == "play")

	# --- A practice match and its pause ------------------------------------------------
	main.tournament = null
	main.tournament_mode = false
	main._start_practice()
	await _wait(1.0)
	if _tut().visible:  # the first match opens the tutorial once
		await _tutorial_round("Первый матч")
		_check("Первый матч: после обучения игра идёт", not paused)
	await _wait(0.3)
	_check("Матч: кнопка — пауза ❚❚", _gear().kind == IconButton.PAUSE)
	await _tap(_gear())
	await _pause_shape("Тренировка → пауза")
	_check("Тренировка → пауза: «Выйти в клуб» есть", _button(_pause(), "Выйти в клуб") != null)
	await _tap(_button(_pause(), "ПРОДОЛЖИТЬ"))
	_check("Пауза → ПРОДОЛЖИТЬ: закрылась и игра идёт", not _pause().visible and not paused)

	await _tap(_gear())
	await _tap_at(Vector2(360, 300))  # the dimmed court above the sheet
	_check("Пауза → тап по затемнению: продолжить", not _pause().visible and not paused)

	await _tap(_gear())
	await _tap(_button(_pause(), "Настройки"))
	_check("Пауза → Настройки: лист открылся, игра стоит", _sheet().visible and paused)
	_check("Пауза → Настройки: «Выйти» в листе нет", _button(_sheet(), "Выйти") == null)
	await _tap(_button(_sheet(), "ГОТОВО"))
	_check("Пауза → Настройки → ГОТОВО: снова пауза", _pause().visible and not _sheet().visible and paused)

	await _tap(_button(_pause(), "Как играть"))
	await _tutorial_round("Пауза → Как играть")
	_check("Пауза → Как играть → Закрыть: возврат в паузу", _pause().visible and paused)
	await _tap(_button(_pause(), "ПРОДОЛЖИТЬ"))
	_check("Пауза → ПРОДОЛЖИТЬ после справочника: игра идёт", not paused)

	await _tap(_gear())
	await _tap(_button(_pause(), "Выйти в клуб"))
	_check("Тренировка → Выйти в клуб: без подтверждения", not _confirm().visible)
	await _wait(0.8)
	var in_club: bool = main.ui.is_open() or (club != null and club.active)
	_check("Тренировка → Выйти в клуб: Клуб и не на паузе", in_club and not paused)

	# --- A tournament match: leaving it asks first ---------------------------------------
	var tm := Tournament.new(1)
	SaveData.active = tm
	main.tournament = tm
	main.tournament_mode = true
	main._play_match()
	await _wait(1.0)
	await _tap(_gear())
	await _pause_shape("Турнир → пауза")
	await _tap(_button(_pause(), "Выйти в клуб"))
	_check("Турнир → Выйти: спрашивает подтверждение, игра стоит", _confirm().visible and paused)
	_check("Турнир → Выйти: объясняет, что пропадёт", _confirm().find_children("*", "Label", true, false).any(func(l): return "заново" in (l as Label).text))
	await _tap(_button(_confirm(), "Остаться"))
	_check("Турнир → Выйти → Остаться: снова пауза", not _confirm().visible and _pause().visible and paused)
	await _tap(_button(_pause(), "Выйти в клуб"))
	await _tap_at(Vector2(360, 300))
	_check("Турнир → Выйти → тап по затемнению: остаться", not _confirm().visible and _pause().visible)
	await _tap(_button(_pause(), "Выйти в клуб"))
	await _tap(_button(_confirm(), "Выйти"))
	await _wait(0.8)
	in_club = main.ui.is_open() or (club != null and club.active)
	_check("Турнир → Выйти → Выйти: Клуб и не на паузе", in_club and not paused and not _pause().visible)
	_check("Турнир → Выйти: турнир сохранился", SaveData.resumable() == tm)

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
	await _tap(_gear())
	await _settings_round("Итог → ⚙")
	_chosen = ""
	await _tap(_button(main.ui.root, "НАГРАДУ"))
	_check("Итог → ⚙ → ГОТОВО: главное действие нажимается", _chosen == "to_reward")

	# --- Gold: the bank on the chip, the run's gold apart until the summary (C-4) ---------
	var bank0 := SaveData.gold
	var g := Tournament.new(1)
	g.gold = 75
	main.ui.show_bracket(g)
	await _wait(0.4)
	_check("Золото: чип — банк, без золота забега", main.ui.chip_values().x == bank0)
	_check("Золото: забег отдельно «+75»", main.ui.chip_values().y == 75 and main.ui.run_chip_shown())
	_check("Золото: на сетке сказано, когда забег уйдёт в банк", main.ui.root.find_children("*", "Label", true, false).any(func(l): return (l as Label).is_visible_in_tree() and "в банк" in (l as Label).text))
	main.ui.show_menu()
	await _wait(0.4)
	_check("Золото: в Клубе чип забега не показывается", not main.ui.run_chip_shown() and main.ui.chip_values().x == bank0)
	g.state = Tournament.State.OVER
	SaveData.record_run(g)
	main.ui.show_summary(g)
	await _wait(0.2)
	_check("Золото: итоги начинаются с банка до забега", main.ui.chip_values().x == bank0 and main.ui.run_chip_shown())
	await _wait(2.0)
	_check("Золото: на итогах забег ушёл в банк", main.ui.chip_values().x == bank0 + 75 and not main.ui.run_chip_shown())

	# --- The trophy mini-game ------------------------------------------------------
	main.ui.close()
	r.pending_loot = Gear.roll(Gear.EPIC, rng)
	main._start_bonus()
	await _wait(0.5)
	await _tap(_gear())
	_check("Трофей → пауза: открылась и игра стоит", _pause().visible and paused)
	_check("Трофей → пауза: выхода нет (трофей не достаётся даром)", _button(_pause(), "Выйти") == null)
	await _tap(_button(_pause(), "ПРОДОЛЖИТЬ"))
	_check("Трофей → пауза → ПРОДОЛЖИТЬ: игра идёт", not paused and not _pause().visible)

	print("\nOVERLAYS: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
