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
var retries := 0


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


## A tap at the middle of a control, once the control stands still: a container re-sorts at the
## end of a frame and a press dips the button (scale), so under load a rect read right after a
## fade or a re-open is stale and the finger would land beside the button.
func _tap(c: Control) -> void:
	if c == null:
		await _expect("кнопка для нажатия найдена", func() -> bool: return false)
		return
	await _still(c)
	if not is_instance_valid(c):  # the screen was rebuilt meanwhile: nothing to press any more
		return
	await _tap_at(c.get_global_rect().get_center())


## Waits (up to 2 s) until `c` is in the tree, not mid-press and has kept its rect for 3 frames.
func _still(c: Control) -> void:
	var last := Rect2()
	var same := 0
	var t := 0.0
	while same < 3 and t < 2.0 and is_instance_valid(c):
		await process_frame
		t += 0.02
		if not is_instance_valid(c):
			return
		var r := c.get_global_rect()
		if c.is_visible_in_tree() and r.size.x > 0.0 and c.scale.is_equal_approx(Vector2.ONE) and r == last:
			same += 1
		else:
			same = 0
		last = r


## A tap that must have an effect: taps the control that `find` returns and waits for `done`;
## if nothing happened (a tap eaten by something that was still fading), looks again and taps
## again, up to 3 times. Every repeat is printed (RETRY), so a flaky spot stays visible.
func _tap_until(find: Callable, done: Callable) -> void:
	for attempt in 3:
		var c: Control = await find.call()
		if c == null or not is_instance_valid(c):
			break
		await _tap(c)
		var t := 0.0
		while not done.call() and t < 2.0:
			await _wait(0.05)
			t += 0.05
		if done.call():
			return
		retries += 1
		print("RETRY  тап по «%s» не сработал, попытка %d" % [c.text if c is Button else str(c.name), attempt + 2])


## A check that may need a moment (a tap's dip, a sheet's fade, a slow frame when other
## Godot windows share the machine): `cond` is asked again for up to 2 s before it fails.
func _expect(what: String, cond: Callable) -> void:
	var t := 0.0
	while not cond.call() and t < 4.0:  # 4 s: other Godot windows may share the machine
		await _wait(0.05)
		t += 0.05
	_check(what, cond.call())


## The visible button with `text` under `from`, waiting up to 2 s for it to appear.
func _find(from: Node, text: String) -> Button:
	var t := 0.0
	var b := _button(from, text)
	while b == null and t < 4.0:
		await _wait(0.05)
		t += 0.05
		b = _button(from, text)
	return b


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


## The bag chip is on screen, inside the width, and clear of the ⚙ button, the bank and the
## run's chips and (`back`) of «Назад».
func _chip_clear(ui, back := false) -> bool:
	var c: Control = ui.bag_chip
	if not c.is_visible_in_tree():
		return false
	var r := c.get_global_rect()
	if r.position.x < 0.0 or r.end.x > 720.0 - 132.0 + 14.0:  # TournamentUI.HUD_BUTTON_W
		return false
	for other in [ui._chip, ui._run_chip]:
		if (other as Control).is_visible_in_tree() and r.intersects((other as Control).get_global_rect()):
			return false
	if r.intersects(_gear().get_global_rect()):
		return false
	if back:
		for b in ui._back_slot.get_children():
			if (b as Control).is_visible_in_tree() and r.intersects((b as Control).get_global_rect()):
				return false
	return true


# Scripts that use TournamentUI are loaded at run time: a tool compiles before the autoloads exist.
func _run_bag():
	return load("res://scripts/ui/screens/run_bag.gd")


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
	await _expect("%s: «Как играть» открылось" % ctx, func() -> bool: return _tut().visible)
	var page: int = _tut()._page
	var next := await _find(_tut(), "ДАЛЬШЕ")
	await _expect("%s: «ДАЛЬШЕ» есть" % ctx, func() -> bool: return next != null)
	if next:
		await _tap_until(func() -> Control: return await _find(_tut(), "ДАЛЬШЕ"), func() -> bool: return _tut()._page == page + 1)
		await _expect("%s: «ДАЛЬШЕ» листает" % ctx, func() -> bool: return _tut()._page == page + 1)
	var close := await _find(_tut(), "Закрыть")
	await _expect("%s: «Закрыть» есть на странице" % ctx, func() -> bool: return close != null)
	if close:
		await _tap_until(func() -> Control: return await _find(_tut(), "Закрыть"), func() -> bool: return not _tut().visible)
	await _expect("%s: обучение закрылось" % ctx, func() -> bool: return not _tut().visible)


## The settings sheet opened from a place that is not a match: no exit, no pause, and
## "ГОТОВО" closes it.
func _settings_round(ctx: String) -> void:
	await _expect("%s: настройки открылись" % ctx, func() -> bool: return _sheet().visible)
	await _expect("%s: игра не на паузе" % ctx, func() -> bool: return not paused)
	await _expect("%s: «Выйти» не показывается вне матча" % ctx, func() -> bool: return _button(_sheet(), "Выйти") == null)
	var done := await _find(_sheet(), "ГОТОВО")
	await _expect("%s: «ГОТОВО» есть и внизу" % ctx, func() -> bool: return done != null and done.get_global_rect().position.y > root.size.y * 0.8)
	if done:
		await _tap(done)
	await _expect("%s: настройки закрылись" % ctx, func() -> bool: return not _sheet().visible)


## The pause's shape: the game stands, every button is a thumb's size, ПРОДОЛЖИТЬ is in
## the bottom third.
func _pause_shape(ctx: String) -> void:
	await _expect("%s: пауза открылась" % ctx, func() -> bool: return _pause().visible)
	await _expect("%s: игра стоит" % ctx, func() -> bool: return paused)
	var go := await _find(_pause(), "ПРОДОЛЖИТЬ")
	await _expect("%s: «ПРОДОЛЖИТЬ» в нижней трети" % ctx, func() -> bool: return go != null and go.get_global_rect().position.y > root.size.y * 0.66)
	var small := 0
	for c in _pause().find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree() and (c as Button).size.y < 84.0:
			small += 1
	await _expect("%s: кнопки не меньше 84 px" % ctx, func() -> bool: return small == 0)


## Every visible button of the club's screen is a thumb's size and inside the phone's frame
## (a card that slid under the edge or a row too thin to hit shows up here).
func _screen_shape(ctx: String) -> void:
	var small := 0
	var outside := 0
	var frame := Rect2(Vector2.ZERO, Vector2(root.size))
	for c in main.ui.root.find_children("*", "Button", true, false):
		var b := c as Button
		if not b.is_visible_in_tree():
			continue
		if b.size.y < 84.0:
			small += 1
		if not frame.grow(2.0).encloses(b.get_global_rect()):
			outside += 1
	await _expect("%s: кнопки не меньше 84 px" % ctx, func() -> bool: return small == 0)
	await _expect("%s: кнопки целиком на экране" % ctx, func() -> bool: return outside == 0)


## A club screen on TournamentUI's frame (the coach's board, the islands, a shop, a place's
## card): opens with its title, is shaped for a thumb, has the gear over it that opens the
## settings (no exit outside a match), and "Назад" comes back to the walkable club.
func _club_screen(ctx: String, action: String, title: String, back := "menu") -> void:
	var club = main.get("club")
	club.ui_action(action, 0)
	await _wait(0.8)
	await _expect("%s: экран открылся" % ctx, func() -> bool: return main.ui.is_open() and main.ui.root.find_children("*", "Label", true, false).any(func(l): return (l as Label).is_visible_in_tree() and title in (l as Label).text))
	await _screen_shape(ctx)
	await _expect("%s: ⚙ видна над экраном" % ctx, func() -> bool: return _gear().is_visible_in_tree())
	await _tap(_gear())
	await _settings_round("%s → ⚙" % ctx)
	_chosen = ""
	await _tap_until(func() -> Control: return await _find(main.ui.root, "Назад"), func() -> bool: return _chosen == back)
	await _expect("%s: «Назад» нажимается" % ctx, func() -> bool: return _chosen == back)
	await _expect("%s: назад в клуб" % ctx, func() -> bool: return club.active and club.hud.visible and not main.ui.is_open())


## «Условия забега» from the club's link (hub-economy 14): shaped for a thumb, the gear over it,
## the rate's three plates in a row inside the screen, a tap picks a rate (the total moves),
## «Назад» comes back to the club.
func _run_mods_round(club) -> void:
	var rm = load("res://scripts/ui/screens/run_mods.gd")
	var played := SaveData.played
	var mf := SaveData.mods_freq
	SaveData.played = 3
	SaveData.mods_freq = 0
	club.ui_action("club_mods", 0)
	await _wait(0.8)
	var ctx := "Клуб 3D → Условия забега"
	await _expect("%s: экран открылся" % ctx, func() -> bool: return main.ui.is_open() and main.ui.root.find_children("*", "Label", true, false).any(func(l): return (l as Label).is_visible_in_tree() and "Условия забега" in (l as Label).text))
	# The list scrolls (6..8 conditions): rows below the fold are cut by the scroll, not by the
	# screen, so they only must fit the width; everything else fits whole.
	var frame := Rect2(Vector2.ZERO, Vector2(root.size))
	var bad := 0
	for c in main.ui.root.find_children("*", "Button", true, false):
		var b := c as Button
		if not b.is_visible_in_tree():
			continue
		var r := b.get_global_rect()
		var scrolled: bool = main.ui._scroll.is_ancestor_of(b)
		if r.size.y < 84.0 or (scrolled and (r.position.x < -2.0 or r.end.x > frame.end.x + 2.0)) or (not scrolled and not frame.grow(2.0).encloses(r)):
			bad += 1
	_check("%s: кнопки не меньше 84 px, в ширину экрана (список прокручивается)" % ctx, bad == 0)
	await _expect("%s: ⚙ видна над экраном" % ctx, func() -> bool: return _gear().is_visible_in_tree())
	var fb: Array = rm.freq_buttons(main.ui)
	await _expect("%s: частота — три плашки в ряд, целиком на экране, не налезают" % ctx, func() -> bool:
		if fb.size() != 3:
			return false
		for k in 3:
			var r: Rect2 = (fb[k] as Control).get_global_rect()
			if not frame.encloses(r) or r.size.y < 84.0 or (k > 0 and r.intersects((fb[k - 1] as Control).get_global_rect())):
				return false
		return true)
	await _expect("%s: частота не под ⚙ и «Назад»" % ctx, func() -> bool: return fb.all(func(b): return not (b as Control).get_global_rect().intersects(_gear().get_global_rect())))
	var x0: float = rm.total()
	await _tap(fb[2] if fb.size() == 3 else null)
	await _expect("%s: тап по «Часто» выбирает её, награда растёт" % ctx, func() -> bool: return rm.freq == 2 and rm.total() > x0 + 0.3)
	fb = rm.freq_buttons(main.ui)
	await _tap(fb[1] if fb.size() == 3 else null)
	await _expect("%s: тап по «Обычно» — обычно" % ctx, func() -> bool: return rm.freq == 1)
	await _tap(_gear())
	await _settings_round("%s → ⚙" % ctx)
	_chosen = ""
	await _tap(await _find(main.ui.root, "Назад"))
	await _expect("%s: «Назад» нажимается" % ctx, func() -> bool: return _chosen == "mods_back")
	await _wait(0.8)
	await _expect("%s: назад в клуб" % ctx, func() -> bool: return club.active and club.hud.visible and not main.ui.is_open())
	SaveData.played = played
	SaveData.mods_freq = mf


## The visible cards (GameCard) of the screen. By the script's name: the class needs the autoloads.
func _cards() -> Array:
	return main.ui.root.find_children("*", "Control", true, false).filter(func(c): return c.is_visible_in_tree() and c.get_script() != null and (c.get_script() as Script).get_global_name() == &"GameCard")


## E-5: the bookmaker at the bar. Without a run: a word and the history; with a run in the
## bracket: two sides (for and against yourself) that do not overlap, a tap on a side places
## the bet and the screen shows it; «Назад» comes back to the walkable club.
func _bookie_round(club) -> void:
	var titles0: int = SaveData.titles
	var gold0: int = SaveData.gold
	var active0 = SaveData.active
	var run0: Dictionary = SaveData.run
	var tour0 = main.tournament
	SaveData.titles = maxi(titles0, 1)
	SaveData.gold = 1000
	SaveData.run = {}
	SaveData.active = null
	main.tournament = null
	await _club_screen("Клуб 3D → Букмекер (нет забега)", "club_bookie", "Букмекер", "bet_back")
	var bt := Tournament.new(1, 7)
	SaveData.active = bt
	await _club_screen("Клуб 3D → Букмекер (забег)", "club_bookie", "Букмекер", "bet_back")
	club.ui_action("club_bookie", 0)
	await _wait(0.8)
	var sides := _cards()
	await _expect("Букмекер: две стороны — на себя и против себя", func() -> bool: return sides.size() == 2)
	if sides.size() == 2:
		var frame := Rect2(Vector2.ZERO, Vector2(root.size))
		_check("Букмекер: стороны не наезжают друг на друга", not (sides[0] as Control).get_global_rect().intersects((sides[1] as Control).get_global_rect()))
		_check("Букмекер: стороны целиком на экране", sides.all(func(c): return frame.grow(2.0).encloses((c as Control).get_global_rect())))
		var against: Array = sides.filter(func(c): return String(c.tag) == "Против себя")
		if not against.is_empty():
			await _tap(against[0])
		await _expect("Букмекер: тап по «Против себя» ставит", func() -> bool: return String(bt.bet.get("side", "")) == "against")
		await _expect("Букмекер: ставка видна на экране", func() -> bool: return main.ui.root.find_children("*", "Label", true, false).any(func(l): return (l as Label).is_visible_in_tree() and "против себя" in (l as Label).text and "Ставка" in (l as Label).text))
		await _screen_shape("Букмекер (ставка сделана)")
	_chosen = ""
	await _tap(await _find(main.ui.root, "Назад"))
	await _wait(0.8)
	await _expect("Букмекер → Назад: клуб", func() -> bool: return club.active and club.hud.visible and not main.ui.is_open())
	SaveData.titles = titles0
	SaveData.gold = gold0
	SaveData.run = run0
	SaveData.active = active0
	main.tournament = tour0


## The opponent's stamina bar in its three looks (OppStaminaView): where it stands is
## inside the phone's frame and clear of the timing ring, the ball in play (the serve) is
## not near it, and a ball on the bar makes it fade and a far ball brings it back.
func _opp_bar_round() -> void:
	var view: OppStaminaView = main.run_hub.view
	var tuning = root.get_node("Tuning")
	var frame := Rect2(Vector2.ZERO, Vector2(root.size))
	await _expect("Полоска соперника: показана в турнирном матче", func() -> bool: return view.shown)
	for st in [1, 2, 3]:
		tuning.opp_bar_style = st
		await _wait(0.3)
		var r := view.bar_rect()
		var ring: Control = main.hud.ring
		var tag := "Полоска соперника (вид %d)" % st
		_check("%s: целиком на экране" % tag, frame.encloses(r))
		_check("%s: не в кольце тайминга" % tag, not r.intersects(ring.get_global_rect()))
		_check("%s: мяч в игре не закрыт (рядом — полоска бледная)" % tag, not view.ball_near() or view.bar_alpha() < 0.5)
		if st == 1:
			_check("%s: тонкая, 4 px, и короткая" % tag, is_equal_approx(r.size.y, 4.0) and r.size.x <= 110.0)
		if st == 3:
			_check("%s: 120x6" % tag, r.size == Vector2(120, 6))
		main.run_hub.set_process(false)  # the probe places the ball itself
		view.ball_px = r.get_center()
		await _wait(0.5)
		_check("%s: мяч на полоске — она бледнеет" % tag, view.bar_alpha() < 0.4)
		view.ball_px = r.get_center() + Vector2(0, 400)
		await _wait(0.5)
		_check("%s: мяч ушёл — полоска вернулась" % tag, view.bar_alpha() > 0.95)
		main.run_hub.set_process(true)
	tuning.opp_bar_style = 1


## «Разбить ракетку» after a point lost on an out ball (practice: always offered): the button is
## on screen, a thumb's size, clear of the stamina ring, the ❚❚ button and the joystick zone, a
## tap on it starts the mini-game (the match stands) and ❚❚ still pauses it.
func _smash_probe() -> void:
	var m = main
	var hub = m.smash_hub
	for size in [Vector2i(720, 1564), Vector2i(720, 1480)]:
		root.size = size
		await _wait(0.5)
		m.phase = m.Phase.RALLY
		m.last_hitter = m.Who.PLAYER
		m.rally = 5
		m._end_point(m.Who.CPU, "OUT")
		await _wait(0.4)
		var ctx := "Кнопка «Разбить ракетку» (%d×%d)" % [size.x, size.y]
		var b: Control = m.hud.smash_btn
		await _expect("%s: видна после аута" % ctx, func() -> bool: return b.is_visible_in_tree() and hub.offer_left > 0.0)
		var r := b.get_global_rect()
		var frame := Rect2(Vector2.ZERO, Vector2(root.size))
		_check("%s: целиком на экране, не меньше 84 px" % ctx, frame.grow(2.0).encloses(r) and r.size.x >= 84.0 and r.size.y >= 84.0)
		var ring_c: Vector2 = m.hud.ring.anchor
		var nearest := Vector2(clampf(ring_c.x, r.position.x, r.end.x), clampf(ring_c.y, r.position.y, r.end.y)).distance_to(ring_c)
		_check("%s: не налезает на кольцо выносливости (до него %.0f px, кольцо — 60)" % [ctx, nearest], nearest > 60.0)
		_check("%s: не налезает на ❚❚" % ctx, not r.intersects(_gear().get_global_rect()))
		_check("%s: выше зоны джойстика (%.0f < %.0f)" % [ctx, r.end.y, m.hud.touch.stick_zone_top], r.end.y < m.hud.touch.stick_zone_top)
		var hint: Control = m.hud.announcer._hint
		_check("%s: не закрывает подсказку и полосу вызовов" % ctx, not r.intersects(hint.get_global_rect()) and r.position.y > 150.0)
		_check("%s: тап по ней не читается как тап по корту (в blocked_controls)" % ctx, m.hud.touch.blocked_controls.has(b))
	await _tap(m.hud.smash_btn)
	await _expect("Кнопка «Разбить ракетку»: тап начинает мини-игру, матч стоит", func() -> bool: return m.phase == m.Phase.SMASH and m.hud.smash_prompt.visible)
	var pr: SmashPrompt = m.hud.smash_prompt
	var ok := true
	for i in 3:
		var c := pr.centre(i)
		ok = ok and c.x > 40.0 and c.x < root.size.x - 40.0 and c.y > 330.0 and c.y < m.hud.touch.stick_zone_top - 100.0
	_check("Три свайпа: подсказки на экране, под полосой вызовов и выше героя", ok)
	await _tap(_gear())
	await _expect("Мини-игра → ❚❚: пауза открылась", func() -> bool: return _pause().visible and paused)
	await _tap(await _find(_pause(), "ПРОДОЛЖИТЬ"))
	await _expect("Мини-игра → пауза → ПРОДОЛЖИТЬ: игра идёт", func() -> bool: return not paused and m.phase == m.Phase.SMASH)
	hub.smash.abort()
	await _expect("Мини-игра прервана: матч идёт дальше", func() -> bool: return m.phase == m.Phase.OVER)
	await _wait(0.5)
	root.size = Vector2i(720, 1564)


## The ball machine's drill: the card, the hint and the pill stay in the top band - clear of
## the timing ring above the player and the joystick under his feet, of the pause button and
## the frame - for every exercise, with a verdict flashing and the lap's summary; every
## button is a thumb's size; the pause and the summary lead back to the club.
func _drill_round(club) -> void:
	var drill = main.get("drill")
	SaveData.club = {}
	main._show_menu()
	await _wait(0.8)
	main._on_ui("drill", 0)
	await _wait(1.0)
	await _expect("Пушка: упражнение началось, клуб отошёл", func() -> bool: return drill.active and not club.active)
	var frame := Rect2(Vector2.ZERO, Vector2(root.size))
	var hud: DrillHud = drill.hud
	for i in drill.TYPES.size():
		drill._step = i
		drill._enter_step(true)
		if i == 2:
			hud.flash("НЕ ТОТ УДАР", Color.WHITE)  # the verdict shares the card
		await _wait(0.35)
		var ring_at: Vector2 = main.hud.ring.anchor
		var ring_zone := Rect2(ring_at - Vector2(140, 140), Vector2(280, 280))
		var stick_top: float = main.hud.touch.stick_zone_top
		var gear := _gear().get_global_rect()
		var bad := ""
		for r in hud.rects():
			if r.intersects(ring_zone):
				bad = "кольцо"
			elif r.end.y > stick_top:
				bad = "джойстик"
			elif r.intersects(gear):
				bad = "кнопка паузы"
			elif not frame.grow(2.0).encloses(r):
				bad = "рамка экрана"
		_check("Пушка · %s: карточки не перекрывают кольцо, джойстик, паузу (%s)" % [drill.TYPES[i]["id"], bad if bad != "" else "чисто"], bad == "")
	var pill: Button = hud.buttons()[0]
	_check("Пушка: «%s» не меньше 84 px и на виду" % pill.text, pill.size.y >= 84.0 and pill.is_visible_in_tree() and frame.encloses(pill.get_global_rect()))
	# The pause's exit.
	await _tap(_gear())
	await _pause_shape("Пушка → пауза")
	await _tap(await _find(_pause(), "Выйти в клуб"))
	await _wait(0.8)
	await _expect("Пушка → пауза → Выйти в клуб: клуб, упражнение закончено, не на паузе", func() -> bool: return club.active and not drill.active and not paused)
	# The lap's summary: buttons of a thumb's size, «В КЛУБ» leads back.
	main._on_ui("drill", 0)
	await _wait(0.8)
	drill._ok = [1, 1, 1, 1, 1, 1, 1, 1]
	drill._need = 1
	drill._finish_lap()
	await _wait(0.5)
	var small := 0
	for b in hud.buttons():
		if b.is_visible_in_tree() and b.size.y < 84.0:
			small += 1
	_check("Пушка · итог круга: кнопки не меньше 84 px, панель на экране", small == 0 and hud.summary_shown() and frame.encloses(hud.rects().back()))
	await _tap(await _find(hud, "Ещё круг"))
	await _expect("Пушка · итог → «Ещё круг»: новый круг, итог закрылся", func() -> bool: return drill.active and not hud.summary_shown() and drill.step_id() == "flat")
	drill._ok = [3, 3, 3, 3, 3, 3, 3, 3]
	drill._finish_lap()
	await _wait(0.4)
	await _tap(await _find(hud, "В КЛУБ"))
	await _wait(0.8)
	await _expect("Пушка · итог → «В КЛУБ»: клуб, герой у пушки", func() -> bool: return club.active and not drill.active and club.hud.current_place() == "machine")


func _run() -> void:
	root.size = Vector2i(720, 1564)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	# The boot screen (BootLoader) eats every tap until frames come out steady or 6 s have passed,
	# plus its 0.35 s fade: under load a fixed 7 s was not always enough. Wait for it to be gone.
	await create_timer(1.0).timeout
	var boot := 0.0
	while boot < 60.0 and not main.find_children("*", "BootLoader", false, false).is_empty():
		await create_timer(0.1).timeout
		boot += 0.1
	await create_timer(1.0).timeout  # the club and the menu settle under the faded screen
	SaveData.control_chosen = true
	SaveData.enabled = false  # look, don't touch the player's progress
	Skills.pending = []       # no perk screen in the way of the menu
	main.ui.chosen.connect(func(a: String, _arg: int) -> void: _chosen = a)
	await _expect("кнопка ⚙/❚❚ — 84 px", func() -> bool: return _gear().size.y >= 84.0 and _gear().size.x >= 84.0)

	# --- The old 2D Club (-- --old-menu) -----------------------------------------------
	main.ui.show_menu()
	await _wait(0.6)
	await _tap(await _find(main.ui.root, "Как играть"))
	await _tutorial_round("Клуб 2D → ?")
	await _expect("Клуб 2D → ?: игра не на паузе после", func() -> bool: return not paused)
	_chosen = ""
	await _tap_until(func() -> Control: return await _find(main.ui.root, "ТУРНИР"), func() -> bool: return _chosen == "start_tournament")
	await _expect("Клуб 2D → ?: после закрытия «ТУРНИР» нажимается", func() -> bool: return _chosen == "start_tournament")

	main.ui.show_menu()
	await _wait(0.6)
	await _expect("Клуб 2D: кнопка — шестерёнка", func() -> bool: return _gear().kind == IconButton.GEAR)
	await _tap(_gear())
	await _settings_round("Клуб 2D → ⚙")
	_chosen = ""
	await _tap_until(func() -> Control: return await _find(main.ui.root, "ТУРНИР"), func() -> bool: return _chosen == "start_tournament")
	await _expect("Клуб 2D → ⚙ → ГОТОВО: Клуб нажимается", func() -> bool: return _chosen == "start_tournament")

	# --- The walkable 3D club (the main screen since v0.2 B) ----------------------------
	main._show_menu()
	await _wait(1.5)
	var club = main.get("club")
	var in_3d: bool = club != null and club.active
	await _expect("Клуб 3D открылся", func() -> bool: return in_3d)
	if in_3d:
		await _tap(club.hud.gear)
		await _settings_round("Клуб 3D → ⚙")
		await _expect("Клуб 3D → ⚙ → ГОТОВО: клуб на месте", func() -> bool: return club.active and club.hud.visible)
		await _tap(club.hud._travel_btn)
		await _tap(await _find(club.hud.root, "Как играть"))
		await _tutorial_round("Клуб 3D → ? (быстрый переход)")
		await _expect("Клуб 3D → ?: клуб живёт, не на паузе", func() -> bool: return club.active and not paused)
		# A place's screen over the club (Раздевалка), as the place's button opens it.
		main._on_ui("locker", 0)
		await _wait(0.8)
		await _expect("Клуб 3D → Раздевалка: ⚙ видна над экраном", func() -> bool: return _gear().is_visible_in_tree())
		await _tap(_gear())
		await _settings_round("Клуб 3D → Раздевалка → ⚙")
		_chosen = ""
		await _tap(await _find(main.ui.root, "Назад"))
		await _expect("Клуб 3D → Раздевалка → ⚙ → ГОТОВО: «Назад» нажимается", func() -> bool: return _chosen == "menu")
		await _wait(0.8)

		# The club's screens added by the hub (coach's board, islands, shop, place cards).
		load("res://scripts/club/club_quests.gd").start_run("probe", 0)  # by path: the class names need the autoloads, which a -s script compiles before
		await _club_screen("Клуб 3D → Задания тренера", "club_quests", "Задания тренера")
		await _club_screen("Клуб 3D → Куда едем?", "club_locations", "Куда едем?")
		await _club_screen("Клуб 3D → Магазин", "club_shop", "Магазин")
		for pl in [["trophy", "Трофейная"], ["blackjack", "Блэкджек"]]:
			club._place = pl[0]
			await _club_screen("Клуб 3D → место: %s" % pl[1], "club_place", pl[1])
		club._place = ""
		await _run_mods_round(club)


		await _bookie_round(club)
		# The locked island: a row that can't be pressed, with a hint.
		load("res://scripts/club/club_screens.gd").locations(main.ui, func(id: String) -> bool: return id == "newyork", func(_id: String) -> String: return "за титул в Нью-Йорке")
		await _wait(0.6)
		var lock_rows := 0
		for c in main.ui.root.find_children("*", "Button", true, false):
			var b := c as Button
			if b.is_visible_in_tree() and b.find_children("*", "Label", true, false).any(func(l): return "✕" in (l as Label).text):
				lock_rows += 1
				_check("Куда едем?: закрытый остров не нажимается", b.disabled)
		await _expect("Куда едем?: закрытые острова есть, с замком", func() -> bool: return lock_rows > 0)
		await _screen_shape("Куда едем? (замки)")
		_chosen = ""
		await _tap(await _find(main.ui.root, "Назад"))
		await _wait(0.8)
		# T-1: the lot's sheet (the foreman's strip with a card for each building) and the build moment.
		SaveData.club["lots"] = {}
		SaveData.gold = 500
		club._refresh()
		club._travel("lot_n1")
		await _wait(0.6)
		club._on_choice("club_lot", 0)
		await _wait(1.0)
		await _expect("Участок: лист выбора открыт", func() -> bool: return club.lot_on() and club.hud.foreman_visible())
		var lf: Control = club.hud._foreman
		var lframe := Rect2(Vector2.ZERO, Vector2(root.size))
		await _expect("Участок: лист целиком на экране", func() -> bool: return lframe.grow(2.0).encloses(lf.get_global_rect()))
		await _expect("Участок: «Построить» не меньше 84 px", func() -> bool: return club.hud._foreman_build.size.y >= 84.0)
		await _expect("Участок: ⚙ не закрыта листом", func() -> bool: return not lf.get_global_rect().intersects(club.hud.gear.get_global_rect()))
		await _tap(club.hud.gear)
		await _settings_round("Участок → ⚙")
		await _expect("Участок → ⚙ → ГОТОВО: лист на месте", func() -> bool: return club.lot_on() and club.hud.foreman_visible())
		for t in ["coach", "stands", "locker", "trophy", "bar", "academy", "arena"]:
			club.lot_show(t)
			await _wait(0.1)
			_check("Участок · %s: карточка в экране, ниже ⚙" % t, lframe.grow(2.0).encloses(lf.get_global_rect()) and lf.get_global_rect().position.y > club.hud.gear.get_global_rect().end.y)
		club.lot_show("coach")
		await _wait(0.2)
		await _tap(club.hud._foreman_build)
		await _expect("Участок: «Построить» строит (идёт показ)", func() -> bool: return club.building())
		await _tap_at(Vector2(root.size) * 0.5)
		await _expect("Участок: тап пропускает показ, тренерская стоит", func() -> bool: return not club.building() and load("res://scripts/club/lots.gd").type_at("n1") == "coach")
		await _expect("Участок: после стройки клуб на месте, кнопка здания", func() -> bool: return club.active and club.hud.visible and not club.foreman_on())
		club._travel("lot_n2")
		await _wait(0.6)
		club._on_choice("club_lot", 0)
		await _wait(0.8)
		_chosen = ""
		await _tap(club.hud._roulette_back)
		await _expect("Участок: «Назад» закрывает лист", func() -> bool: return not club.foreman_on() and club.active)
		SaveData.club["lots"] = {"n1": "locker", "n2": "coach", "n3": "trophy", "n4": "stands", "n5": "bar"}
		club._refresh()
		# The foreman: his strip stands over the 3D club, the gear is above it and works.
		club.foreman_open("court")
		await _wait(1.0)
		await _expect("Прораб: полоса открыта", func() -> bool: return club.hud.foreman_visible())
		var fo: Control = club.hud._foreman
		var frame := Rect2(Vector2.ZERO, Vector2(root.size))
		await _expect("Прораб: полоса целиком на экране", func() -> bool: return frame.grow(2.0).encloses(fo.get_global_rect()))
		await _expect("Прораб: «Построить» не меньше 84 px", func() -> bool: return club.hud._foreman_build.size.y >= 84.0)
		await _expect("Прораб: ⚙ не закрыта полосой", func() -> bool: return not fo.get_global_rect().intersects(club.hud.gear.get_global_rect()))
		await _tap(club.hud.gear)
		await _settings_round("Прораб → ⚙")
		await _expect("Прораб → ⚙ → ГОТОВО: прораб на месте", func() -> bool: return club.foreman_on() and club.hud.foreman_visible())
		for id in ["court", "stands", "gate", "shop", "locker", "trophy", "bar"]:
			club.foreman_show(id)
			await _wait(0.1)
			_check("Прораб · %s: карточка в экране, ниже ⚙" % id, frame.grow(2.0).encloses(fo.get_global_rect()) and fo.get_global_rect().position.y > club.hud.gear.get_global_rect().end.y)
		club.foreman_close()
		await _wait(0.6)
		await _expect("Прораб: закрылся, клуб на месте", func() -> bool: return not club.foreman_on() and club.active)

	# --- The ball machine's drill (v0.2 P): its HUD stays clear of the ring and the stick ------
	if in_3d:
		await _drill_round(club)

	# --- The bracket ---------------------------------------------------------------
	var t := Tournament.new(1)
	main.tournament = t
	main.tournament_mode = true
	main.ui.show_bracket(t)
	await _wait(0.6)
	await _tap(_gear())
	await _settings_round("Сетка → ⚙")
	_chosen = ""
	await _tap(await _find(main.ui.root, "НА КОРТ"))
	await _expect("Сетка → ⚙ → ГОТОВО: «НА КОРТ» нажимается (откроет карточку соперника)", func() -> bool: return _chosen == "opponent_card")
	# E-5: the opponent's card carries the bookmaker's line, above «ИГРАТЬ», not under it.
	var titles1: int = SaveData.titles
	SaveData.titles = maxi(titles1, 1)
	main.ui.show_opponent_card(t, t.stage)
	await _wait(0.8)
	var play := await _find(main.ui.root, "ИГРАТЬ")
	var odds_l: Array = main.ui.root.find_children("*", "Label", true, false).filter(func(l): return (l as Label).is_visible_in_tree() and (l as Label).text.begins_with("Коэф."))
	await _expect("Карточка соперника: строка «Коэф.» есть", func() -> bool: return odds_l.size() == 1)
	await _expect("Карточка соперника: «Коэф.» выше «ИГРАТЬ» и не под ней", func() -> bool: return play != null and odds_l.size() == 1 and (odds_l[0] as Label).get_global_rect().end.y <= play.get_global_rect().position.y)
	await _screen_shape("Карточка соперника")
	SaveData.titles = titles1

	# --- A practice match and its pause ------------------------------------------------
	main.tournament = null
	main.tournament_mode = false
	main._start_practice()
	await _wait(1.0)
	if _tut().visible:  # the first match opens the tutorial once
		await _tutorial_round("Первый матч")
		await _expect("Первый матч: после обучения игра идёт", func() -> bool: return not paused)
	await _wait(0.3)
	await _smash_probe()
	await _expect("Матч: кнопка — пауза ❚❚", func() -> bool: return _gear().kind == IconButton.PAUSE)
	await _tap(_gear())
	await _pause_shape("Тренировка → пауза")
	await _expect("Тренировка → пауза: «Выйти в клуб» есть", func() -> bool: return _button(_pause(), "Выйти в клуб") != null)
	await _tap(await _find(_pause(), "ПРОДОЛЖИТЬ"))
	await _expect("Пауза → ПРОДОЛЖИТЬ: закрылась и игра идёт", func() -> bool: return not _pause().visible and not paused)

	await _tap(_gear())
	await _tap_at(Vector2(360, 300))  # the dimmed court above the sheet
	await _expect("Пауза → тап по затемнению: продолжить", func() -> bool: return not _pause().visible and not paused)

	await _tap(_gear())
	await _tap(await _find(_pause(), "Настройки"))
	await _expect("Пауза → Настройки: лист открылся, игра стоит", func() -> bool: return _sheet().visible and paused)
	await _expect("Пауза → Настройки: «Выйти» в листе нет", func() -> bool: return _button(_sheet(), "Выйти") == null)
	await _tap(await _find(_sheet(), "ГОТОВО"))
	await _expect("Пауза → Настройки → ГОТОВО: снова пауза", func() -> bool: return _pause().visible and not _sheet().visible and paused)

	await _tap(await _find(_pause(), "Как играть"))
	await _tutorial_round("Пауза → Как играть")
	await _expect("Пауза → Как играть → Закрыть: возврат в паузу", func() -> bool: return _pause().visible and paused)
	await _tap(await _find(_pause(), "ПРОДОЛЖИТЬ"))
	await _expect("Пауза → ПРОДОЛЖИТЬ после справочника: игра идёт", func() -> bool: return not paused)

	await _tap(_gear())
	await _tap(await _find(_pause(), "Выйти в клуб"))
	await _expect("Тренировка → Выйти в клуб: без подтверждения", func() -> bool: return not _confirm().visible)
	await _wait(0.8)
	await _expect("Тренировка → Выйти в клуб: Клуб и не на паузе", func() -> bool: return (main.ui.is_open() or (club != null and club.active)) and not paused)

	# --- A tournament match: leaving it asks first ---------------------------------------
	var tm := Tournament.new(1)
	SaveData.active = tm
	main.tournament = tm
	main.tournament_mode = true
	main._play_match()
	await _wait(1.0)
	# The opponent's stamina bar (C-7), in each look: inside the frame, away from the ring,
	# and out of the ball's way (it fades while the ball is near it).
	await _opp_bar_round()
	await _tap(_gear())
	await _pause_shape("Турнир → пауза")
	await _tap(await _find(_pause(), "Выйти в клуб"))
	await _expect("Турнир → Выйти: спрашивает подтверждение, игра стоит", func() -> bool: return _confirm().visible and paused)
	await _expect("Турнир → Выйти: объясняет, что пропадёт", func() -> bool: return _confirm().find_children("*", "Label", true, false).any(func(l): return "заново" in (l as Label).text))
	await _tap(await _find(_confirm(), "Остаться"))
	await _expect("Турнир → Выйти → Остаться: снова пауза", func() -> bool: return not _confirm().visible and _pause().visible and paused)
	await _tap(await _find(_pause(), "Выйти в клуб"))
	await _tap_at(Vector2(360, 300))
	await _expect("Турнир → Выйти → тап по затемнению: остаться", func() -> bool: return not _confirm().visible and _pause().visible)
	await _tap(await _find(_pause(), "Выйти в клуб"))
	await _tap(await _find(_confirm(), "Выйти"))
	await _wait(0.8)
	await _expect("Турнир → Выйти → Выйти: Клуб и не на паузе", func() -> bool: return (main.ui.is_open() or (club != null and club.active)) and not paused and not _pause().visible)
	await _expect("Турнир → Выйти: турнир сохранился", func() -> bool: return SaveData.resumable() == tm)

	# --- A result screen -------------------------------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var r := Tournament.new(1)
	r.record_match(true, "6:3", rng)
	r.pending_loot = {}
	main.tournament = r
	main.tournament_mode = true
	var tl: MatchTally = main.hud.tally  # the match stats table (C-5): typical numbers
	tl.start()
	tl.aces = [3, 1]
	tl.doubles = [1, 2]
	tl.winners = [9, 5]
	tl.unforced = [7, 12]
	tl.serve_points = [30, 28]
	tl.first_faults = [10, 12]
	tl.forehands = [41, 38]
	tl.backhands = [22, 30]
	tl.best_rally = 14
	tl.points = 58
	tl.finish()
	main.ui.show_result(r, true, "6:3", {"perfect": 3, "aces": 1, "best_rally": 9})
	await _wait(1.2)
	var labels: Array = main.ui.root.find_children("*", "Label", true, false)
	await _expect("Итог: статистика матча — ты слева, соперник справа", func() -> bool: return labels.any(func(l): return (l as Label).is_visible_in_tree() and (l as Label).text == "Первая подача") and labels.any(func(l): return (l as Label).is_visible_in_tree() and (l as Label).text == "67%"))
	await _tap(_gear())
	await _settings_round("Итог → ⚙")
	_chosen = ""
	# After a win: «ОТКРЫТЬ СУНДУК» / «ВЫБРАТЬ НАГРАДУ» / «ДАЛЬШЕ» (A-7: a chest or none)
	var go: Button = _button(main.ui.root, "СУНДУК")
	if go == null:
		go = _button(main.ui.root, "НАГРАДУ")
	if go == null:
		go = await _find(main.ui.root, "ДАЛЬШЕ")
	await _tap(go)
	await _expect("Итог → ⚙ → ГОТОВО: главное действие нажимается", func() -> bool: return _chosen in ["to_reward", "to_bracket", "to_summary"])

	# --- Gold: the bank on the chip, the run's gold apart until the summary (C-4) ---------
	var bank0 := SaveData.gold
	var g := Tournament.new(1)
	g.gold = 75
	main.ui.show_bracket(g)
	await _wait(0.4)
	await _expect("Золото: чип — банк, без золота забега", func() -> bool: return main.ui.chip_values().x == bank0)
	await _expect("Золото: забег отдельно «+75»", func() -> bool: return main.ui.chip_values().y == 75 and main.ui.run_chip_shown())
	await _expect("Золото: на сетке сказано, когда забег уйдёт в банк", func() -> bool: return main.ui.root.find_children("*", "Label", true, false).any(func(l): return (l as Label).is_visible_in_tree() and "в банк" in (l as Label).text))
	main.ui.show_menu()
	await _wait(0.4)
	await _expect("Золото: в Клубе чип забега не показывается", func() -> bool: return not main.ui.run_chip_shown() and main.ui.chip_values().x == bank0)
	g.state = Tournament.State.OVER
	SaveData.record_run(g)
	main.ui.show_summary(g)
	await _wait(0.2)
	await _expect("Золото: итоги начинаются с банка до забега", func() -> bool: return main.ui.chip_values().x == bank0 and main.ui.run_chip_shown())
	await _wait(2.0)
	await _expect("Золото: на итогах забег ушёл в банк", func() -> bool: return main.ui.chip_values().x == bank0 + 75 and not main.ui.run_chip_shown())

	# --- Loot cards (v0.2 L): backs, the turn, the bag chip, the flight into it ---------------
	var lt := Tournament.new(1, 5)
	main.tournament = lt
	main.tournament_mode = true
	lt.state = Tournament.State.REWARD
	var lrng := RandomNumberGenerator.new()
	lrng.seed = 9
	var shoes := Gear.roll(Gear.RARE, lrng, "shoes")
	lt.offer = [
		{"kind": "item", "item": shoes, "title": shoes["name"], "desc": Gear.describe(shoes)},
		{"kind": "item", "item": Gear.roll(Gear.COMMON, lrng, "band"), "title": "Напульсник", "desc": "x"},
		Rewards.WILDCARD.duplicate()]
	main.ui.show_reward(lt)
	await _wait(0.4)
	var cards: Array = main.ui._box.get_children().filter(func(c): return c is GameCard)
	_check("Награда: три карточки, все рубашкой вверх, читать нечего", cards.size() == 3 and cards.all(func(c): return c.face_down and c.visible_text() == ""))
	_check("Награда: чип сумки виден, не налезает на ⚙, золото и забег", _chip_clear(main.ui))
	await _tap(cards[0])
	await _expect("Награда: тап по рубашке открывает весь ряд", func() -> bool: return cards.all(func(c): return c.is_open() and c.visible_text() != ""))
	_chosen = ""
	var had: int = _run_bag().carried(lt)
	var shoes_slot: String = shoes["slot"]
	await _tap(cards[0])
	await _expect("Награда: тап по открытой карте берёт её", func() -> bool: return _chosen == "reward")
	await _expect("Награда: вещь долетела до чипа сумки: число выросло, бейдж +1", func() -> bool: return main.ui.bag_chip.count == had + 1)
	lt.pending_loot = Gear.roll(Gear.EPIC, lrng)
	main.ui.show_loot(lt)
	await _wait(0.8)
	_check("Трофей: чип сумки не налезает на ⚙, золото и забег", _chip_clear(main.ui))
	var carried_before: int = _run_bag().carried(lt)
	_chosen = ""
	await _tap(await _find(main.ui.root, "НАДЕТЬ"))
	await _expect("Трофей: «НАДЕТЬ» — вещь летит в сумку, потом экран меняется", func() -> bool: return _chosen == "loot" and main.ui.bag_chip.count == carried_before + 1)
	SaveData.gold = 700
	var shop = load("res://scripts/ui/screens/run_shop.gd")
	shop.back_to = "menu"
	shop.show_shop(main.ui)
	await _wait(0.5)
	_check("Магазин: чип (шкафчик) на месте, «Назад» и золото не задеты", _chip_clear(main.ui, true))

	# --- The trophy mini-game ------------------------------------------------------
	main.ui.close()
	r.pending_loot = Gear.roll(Gear.EPIC, rng)
	main._start_bonus()
	await _wait(0.5)
	await _tap(_gear())
	await _expect("Трофей → пауза: открылась и игра стоит", func() -> bool: return _pause().visible and paused)
	await _expect("Трофей → пауза: выхода нет (трофей не достаётся даром)", func() -> bool: return _button(_pause(), "Выйти") == null)
	await _tap(await _find(_pause(), "ПРОДОЛЖИТЬ"))
	await _expect("Трофей → пауза → ПРОДОЛЖИТЬ: игра идёт", func() -> bool: return not paused and not _pause().visible)

	print("\nOVERLAYS: %d checks, %d failed, %d repeated taps" % [checks, fails, retries])
	quit(1 if fails > 0 else 0)
