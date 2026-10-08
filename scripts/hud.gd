class_name Hud
extends CanvasLayer
## On-screen UI: score, rally counter, hit feedback popups, timing ring, line-call
## replay, and the modal windows over everything: the pause, the settings sheet, the exit
## confirmation and "Как играть". One owner of the game's pause: `modals` (ModalStack,
## UI_FLOW_TZ 5.5). Layers from UiTheme.LAYER_*. No permanent hints.

signal menu_requested

const GOLD := Color(1.0, 0.85, 0.25)

var touch: TouchInput
var ring: TimingRing
var _hawkeye: HawkEye

var _root: Control
var _top: Control          # the ⚙ / ❚❚ button, the pause and the settings: over the menus
var _fps_t := 0.0
var _fps_label: Label
var announcer: HudAnnouncer   # every call, level-up, big moment and hint (UI_FLOW_TZ 5)
var _trophy: TrophyPlate       # the trophy mini-game's balls, where the score bug sits
var _safe_top := 0.0
var _score: Label
var _bug: ScoreBug
var _tired_edge: TextureRect
var _serve_hint := ""
var _rally: Label
var _tutorial: Tutorial
var _debug_text: Label
var _debug_btn: IconButton    # ⚙ outside a match, ❚❚ in it (the name is the club's: club.gd)
var _debug_panel: Control     # the old name of the settings sheet (tools)
var modals: ModalStack
var pause_sheet: PauseSheet
var settings_sheet: SettingsSheet
var confirm_sheet: ConfirmSheet
var in_match := false         # a match is on (Main): the button is the pause
var _tournament_match := false  # leaving it asks first (GameEvents.match_started)
var _board: MatchScore        # the score shown, for the pause's header
var tally := MatchTally.new() # the match's numbers for the result screen (MatchStats, C-5)


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	layer = UiTheme.LAYER_HUD
	modals = ModalStack.new()
	add_child(modals)
	var top_layer := CanvasLayer.new()
	top_layer.layer = UiTheme.LAYER_PAUSE  # over the screens: settings open from the menus too
	add_child(top_layer)
	_top = Control.new()
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.add_child(_top)

	ring = TimingRing.new()
	_root.add_child(ring)
	_hawkeye = HawkEye.new()
	_hawkeye.compact = true  # small, beside the score: the TV strip runs under it
	_root.add_child(_hawkeye)
	touch = TouchInput.new()
	_root.add_child(touch)

	_score = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor_top(_score, 18.0, 60.0)
	# Exhausted: a soft red glow creeps in from the edges of the screen.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.05, 0.05, 0.0))
	grad.set_color(1, Color(0.85, 0.05, 0.05, 0.9))
	grad.add_point(0.55, Color(0.85, 0.05, 0.05, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 128
	tex.height = 256
	_tired_edge = TextureRect.new()
	_tired_edge.texture = tex
	_tired_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tired_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tired_edge.stretch_mode = TextureRect.STRETCH_SCALE
	_tired_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tired_edge.modulate.a = 0.0
	_tired_edge.visible = false
	_root.add_child(_tired_edge)
	_bug = ScoreBug.new()
	_bug.position = Vector2(14.0, 14.0)
	_bug.visible = false
	_root.add_child(_bug)
	# The rally count in the top band, between the score bug and the pause button: under
	# the bug it sat where the calls now go.
	_rally = _label(24, HORIZONTAL_ALIGNMENT_RIGHT)
	_rally.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rally.offset_left = -330.0
	_rally.offset_right = -136.0
	_rally.offset_top = 14.0
	_rally.offset_bottom = 58.0
	_rally.modulate = Color(1, 1, 1, 0.85)
	_trophy = TrophyPlate.new()
	_trophy.position = Vector2(14.0, 14.0)
	_trophy.visible = false
	_root.add_child(_trophy)
	announcer = HudAnnouncer.new()
	announcer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(announcer)

	# The ⚙ / ❚❚ button, top right (84 px, UI_FLOW_TZ P1-4).
	_debug_btn = IconButton.new()
	_debug_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug_btn.offset_left = -14.0 - IconButton.SIZE
	_debug_btn.offset_right = -14.0
	_debug_btn.offset_top = 14.0
	_debug_btn.offset_bottom = 14.0 + IconButton.SIZE
	_debug_btn.pressed.connect(_toggle_debug)
	_debug_btn.process_mode = Node.PROCESS_MODE_ALWAYS  # works while the match is paused
	_top.add_child(_debug_btn)
	touch.blocked_controls.append(_debug_btn)
	# The frame-rate counter (settings: "Счётчик FPS"), under the button.
	_fps_label = _label(24, HORIZONTAL_ALIGNMENT_RIGHT)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -200.0
	_fps_label.offset_right = -16.0
	_fps_label.offset_top = 102.0
	_fps_label.offset_bottom = 132.0
	_fps_label.visible = false

	_debug_text = _label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_debug_text.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_debug_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_debug_text.offset_left = 12.0
	_debug_text.offset_top = 180.0
	_debug_text.offset_right = 520.0
	_debug_text.offset_bottom = 580.0
	_debug_text.visible = Tuning.show_debug_text

	_build_modals()


## The modal windows, each a full-screen veil that takes every tap (and keeps the touch
## layer from reading them as running or swings).
func _build_modals() -> void:
	pause_sheet = PauseSheet.new()
	_top.add_child(pause_sheet)
	pause_sheet.resume.connect(resume)
	pause_sheet.help.connect(open_tutorial)
	pause_sheet.settings.connect(open_settings)
	pause_sheet.leave.connect(_leave)
	settings_sheet = SettingsSheet.new()
	_top.add_child(settings_sheet)
	settings_sheet.veil_tapped.connect(close_settings)
	_debug_panel = settings_sheet
	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = UiTheme.LAYER_CONFIRM
	add_child(confirm_layer)
	confirm_sheet = ConfirmSheet.new()
	confirm_layer.add_child(confirm_sheet)
	confirm_sheet.answered.connect(_on_leave_answer)
	# "Как играть" over everything: opened from the Club, under the menu it was covered
	# and the menu took its taps.
	var tut_layer := CanvasLayer.new()
	tut_layer.layer = UiTheme.LAYER_HELP
	add_child(tut_layer)
	_tutorial = Tutorial.new()
	_tutorial.visible = false
	tut_layer.add_child(_tutorial)
	_tutorial.finished.connect(func() -> void:
		modals.pop("help")
		_restore())
	for c in [pause_sheet, settings_sheet, confirm_sheet, _tutorial]:
		touch.blocked_controls.append(c)
	GameEvents.match_started.connect(func(info: Dictionary) -> void:
		_tournament_match = bool(info.get("tournament", false))
		tally.start())
	GameEvents.shot.connect(tally.shot)
	GameEvents.fault.connect(tally.fault)
	GameEvents.point.connect(tally.point)
	GameEvents.match_finished.connect(func(_info: Dictionary) -> void: tally.finish())


## The frame rate next to the graphics preset, so a phone can be checked by eye:
## 60 is the ceiling in Safari and Telegram on iPhone.
func _process(delta: float) -> void:
	_fps_label.visible = Tuning.show_fps
	if not Tuning.show_fps:
		return
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.5
		var fps := Engine.get_frames_per_second()
		_fps_label.text = "%d FPS" % fps
		_fps_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if fps >= 55 else (Color(1.0, 0.85, 0.3) if fps >= 40 else Color(1.0, 0.45, 0.4)))


## Keeps the HUD clear of Telegram's buttons and the notch (top) and the home bar
## (bottom). Everything anchored to an edge moves with it.
## Only the edge-anchored parts move (score, buttons, labels, the settings sheet): the
## timing ring, the joystick, the swipe trail and the line-call replay are drawn at
## screen positions of things on the court and must stay exactly where they are.
func set_safe_area(top: float, bottom: float) -> void:
	_anchor_top(_score, 18.0 + top, 60.0)
	_bug.position.y = 14.0 + top
	_rally.offset_top = 14.0 + top
	_rally.offset_bottom = 58.0 + top
	_trophy.position.y = 14.0 + top
	_debug_btn.offset_top = 14.0 + top
	_debug_btn.offset_bottom = 14.0 + IconButton.SIZE + top
	_fps_label.offset_top = 102.0 + top
	_fps_label.offset_bottom = 132.0 + top
	_debug_text.offset_top = 180.0 + top
	_debug_text.offset_bottom = 580.0 + top
	for sheet in [pause_sheet, settings_sheet, confirm_sheet]:
		(sheet as UiSheet).set_safe_area(top, bottom)
	_hawkeye.top_inset = top
	ring.top_inset = top
	_safe_top = top
	announcer.set_safe_area(top, bottom)

## Plain text in place of the score bug ("" = nothing at all).
func set_score(text: String) -> void:
	_score.text = text
	_bug.visible = false
	_trophy.visible = false
	ring.show_stamina = false


## The trophy mini-game: its plate with a ball per serve in place of the score bug.
func set_trophy(left: int, total: int) -> void:
	_score.text = ""
	_bug.visible = false
	ring.show_stamina = false
	_trophy.set_balls(left, total)
	_trophy.visible = true


## The match score, broadcast style. names: [player, opponent].
func show_board(s: MatchScore, names: Array) -> void:
	_score.text = ""
	_trophy.visible = false
	_board = s
	_bug.show_score(s, names)
	ring.show_stamina = true


## Stamina (0..1): the arc inside the timing ring, and the screen's edges reddening
## when the player is close to empty.
func set_stamina(v: float) -> void:
	ring.set_stamina(v)
	var a := clampf((0.25 - v) / 0.25, 0.0, 1.0) * 0.55
	if absf(_tired_edge.modulate.a - a) > 0.01:
		_tired_edge.modulate.a = a
	_tired_edge.visible = a > 0.0


## Before the player's toss, for the first few serves: what the fingers do.
func show_serve_hint(on: bool, tap_controls: bool) -> void:
	var t := ""
	if on:
		t = ("тап ниже игрока — шаг  ·  " if tap_controls else "") + "тап по корту — подброс\nкороткий свайп вниз до подброса — подача снизу"
	if t != _serve_hint:  # called every frame: the plate only changes with the text
		_serve_hint = t
		announcer.set_hint(t)


func set_rally(text: String) -> void:
	_rally.text = text
	_rally.visible = not _hawkeye.is_showing()  # VAR sits in the same place


## The first match opens "Как играть" once; it holds the match until closed.
func show_tutorial_once() -> void:
	if not Tutorial.is_done():
		_open_help.call_deferred(true)


## "Как играть" from the Club, the coach or the pause. Closing it returns where it was
## opened: the pause (the game still standing) or the Club.
func open_tutorial() -> void:
	_open_help(in_match)


func _open_help(pauses: bool) -> void:
	modals.push("help", _tutorial, pauses)
	_tutorial.open()


func set_debug_text(t: String) -> void:
	_debug_text.visible = Tuning.show_debug_text
	if _debug_text.visible:
		_debug_text.text = t


## Hit / miss verdict, shown at the timing ring above the player.
func popup(text: String, color: Color, sub := "") -> void:
	ring.feedback(text, color, sub, 2 if text == "PERFECT" else (1 if text == "GOOD" else 0))


## Skill level-up: a gold toast in the call column ("ФОРХЕНД 7 · 104 → 109 км/ч").
## Two at a time, the same skill updates its own; `milestone` (every 5 levels) adds the
## perk note and a gold frame.
func level_up(text: String, milestone := false) -> void:
	announcer.toast(text + ("  ·  перк после матча" if milestone else ""), text.get_slice(" ", 0), milestone)


## The point's call: "WINNER!" and, after a newline, "GAME · YOU" (see Calls).
func show_message(text: String, color: Color) -> void:
	var parts := text.split("\n")
	announcer.call_point(parts[0], parts[1] if parts.size() > 1 else "", color)


## `mark` = the ball mark (half-length, half-width, |cos| of its angle to the line's
## normal), see Main._line_call; zero = a round mark of the ball's size.
func hawkeye(margin: float, axis: int, mark := Vector3.ZERO) -> void:
	_hawkeye.show_call(margin, axis, mark)


## The ⚙ / ❚❚ button (and the club's gear, club.gd): the pause in a match, the settings
## anywhere else. With a window already open it closes them all.
func _toggle_debug() -> void:
	if not modals.is_empty():
		resume()
	elif in_match:
		open_pause()
	else:
		open_settings()


func open_pause() -> void:
	pause_sheet.show_pause(_score_line(), not _trophy.visible)
	modals.push("pause", pause_sheet, true)


## ПРОДОЛЖИТЬ: every window closes and the game goes on.
func resume() -> void:
	for sheet in [pause_sheet, settings_sheet, confirm_sheet]:
		(sheet as UiSheet).close()
	if _tutorial.visible:
		_tutorial.visible = false
	modals.clear()


## The settings, from ⚙ or from the pause (which steps aside until ГОТОВО).
func open_settings() -> void:
	settings_sheet.open()
	modals.push("settings", settings_sheet, in_match)
	if pause_sheet.visible:
		pause_sheet.visible = false


func close_settings() -> void:
	settings_sheet.close()
	modals.pop("settings")
	_restore()


## The window under the one just closed shows again (the pause after settings or help).
func _restore() -> void:
	if modals.top() == "pause":
		pause_sheet.visible = true
		pause_sheet.modulate.a = 1.0


## "Выйти в клуб": a tournament match asks first (it starts over, the run is kept); a
## practice match just goes. The trophy mini-game has no exit (see PauseSheet).
func _leave() -> void:
	if _tournament_match:
		confirm_sheet.ask("Выйти из матча?", "Матч начнётся заново, турнир сохранится.", "Выйти", "Остаться")
		modals.push("confirm", confirm_sheet, true)
	else:
		_exit_to_club()


func _on_leave_answer(yes: bool) -> void:
	modals.pop("confirm")
	if yes:
		_exit_to_club()


func _exit_to_club() -> void:
	resume()
	menu_requested.emit()


## "1:0  3:2  30:40" for the pause's header (sets only in a longer match).
func _score_line() -> String:
	if _board == null or not _bug.visible:
		return ""
	var s := _board
	var a: int = s.points[0]
	var b: int = s.points[1]
	var pts: String
	if s.in_tiebreak:
		pts = "%d:%d" % [a, b]
	elif a >= 3 and b >= 3:
		pts = "40:40" if a == b else ("AD:40" if a > b else "40:AD")
	else:
		var names := ["0", "15", "30", "40"]
		pts = "%s:%s" % [names[a], names[b]]
	var line := "%d:%d  %s" % [s.games[0], s.games[1], pts]
	if s.sets_to_win > 1:
		line = "%d:%d  %s" % [s.sets[0], s.sets[1], line]
	return line


## Main tells the HUD whether a match is on: the button is ❚❚ and opens the pause; in the
## menus it is ⚙, the settings.
func set_in_match(on: bool) -> void:
	if on == in_match:
		return
	in_match = on
	_debug_btn.kind = IconButton.PAUSE if on else IconButton.GEAR
	if not on and modals.has("pause"):
		resume()


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _anchor_top(c: Control, top: float, height: float) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_WIDE)
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = top
	c.offset_bottom = top + height


func _anchor_band(c: Control, anchor_y: float, height: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = anchor_y
	c.anchor_bottom = anchor_y
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = -height * 0.5
	c.offset_bottom = height * 0.5
