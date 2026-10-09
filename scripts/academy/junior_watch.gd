class_name JuniorWatch
extends Node
## A student's match, watched live (spec 4, mode `spectate`): Main plays it on the club court with
## the student on the near side (JuniorBot instead of the hero's hands) and OpponentAI across
## the net; nobody touches the court. This node
##   * swaps the hero's skills out for the student's profile and puts them back (also when the
##     player leaves by the pause: Main._stop_match calls on_stop);
##   * frames it: the booth (the corner behind the baseline, 2.4 m) or the match camera behind the
##     student, the TV frame between points; the buttons «Будка/Матч», «×2», «Советы», «Итог»,
##     «← В клуб» (84 px);
##   * stops the match after a point when the coach is asked (JuniorBot.situation), offers four
##     setups, holds the one chosen for four points and shows «Установка: … · ещё N»;
##   * ends: the result goes to JuniorMatch.complete, the screen to AcademyMatchUi.
## Without a face (`headless`: the calibration, JuniorDuel) it does the same, with a fixed setup
## or the autopilot in place of the questions, and reports the points in `done`.

signal done(info: Dictionary)

const PLATE_MARGIN := 14.0

var main: Node
var active := false
var headless := false
var autopilot := false          # the coach decides (advice off, or a test)
var fixed_stance := ""          # headless: this setup for the whole match
var fixed_boost := NAN          # headless: this many units of boost whatever the fit
var m: Dictionary               # the match (JuniorMatch)
var st: Dictionary              # the student (Academy's record, or a made-up one in the calibration)
var opp: Dictionary
var bot: JuniorBot
var cam_mode := "booth"         # "booth" | "match"
var speed := 1
var left := 0                   # points the setup in force still has at full weight
var fade := 0                   # then this many fading
var stance_id := ""
var advice_count := 0
var last_advice_at := -99
var streak_b := 0
var points_played := 0
var saw_match_point := false
var log: Array = []             # who won each point, 0 = the student
var stats := {"srv_a": 0, "srv_a_won": 0, "srv_b": 0, "srv_b_won": 0}
var ended := false

var _saved := {}
var _layer: CanvasLayer
var _root: Control
var _plate: PanelContainer
var _plate_label: Label
var _btn_cam: Button
var _btn_speed: Button
var _btn_advice: Button
var _advice_sheet: AcademyAdvice
var _advice_open := false
var _undo_look := {}
var _finish_pending := false


func setup(m_: Node) -> void:
	main = m_
	process_mode = Node.PROCESS_MODE_ALWAYS


## Starts a student's match. entry: the booth's match; opts: headless, autopilot, fixed_stance,
## fixed_boost, student, opponent, seed (the calibration passes its own people).
func start(entry: Dictionary, opts := {}) -> bool:
	if active or main == null:
		return false
	m = entry
	headless = bool(opts.get("headless", false))
	st = opts["student"] if opts.has("student") else Academy.student(String(m.get("sid", "")))
	if st.is_empty():
		return false
	opp = opts["opponent"] if opts.has("opponent") else JuniorMatch.opponent_of(m)
	autopilot = bool(opts.get("autopilot", false)) or (not headless and not JuniorMatch.advice_on())
	fixed_stance = String(opts.get("fixed_stance", ""))
	fixed_boost = float(opts.get("fixed_boost", NAN))
	cam_mode = "booth"
	speed = 1
	left = 0
	fade = 0
	stance_id = ""
	advice_count = int((m.get("setups", []) as Array).size())
	last_advice_at = -99
	streak_b = 0
	points_played = 0
	saw_match_point = false
	ended = false
	log = []
	stats = {"srv_a": 0, "srv_a_won": 0, "srv_b": 0, "srv_b_won": 0}
	_finish_pending = false
	_swap_in()
	m["state"] = "live"
	var seed_v := int(m.get("seed", 1))
	main.rng.seed = seed_v
	main.ai.rng.seed = seed_v + 1
	GameEvents.match_started.connect(_on_match_started)
	GameEvents.point.connect(_on_point)
	GameEvents.shot.connect(_on_shot)
	var first_srv: int = main.Who.PLAYER if int(m.get("first", 0)) == 0 else main.Who.CPU
	var label := String(opp.get("short", opp["name"])).to_upper()
	active = true
	main.spectate = self
	main._start_practice(MatchScore.new(1, 0, 0, first_srv, label))
	main.cpu_label = label
	main.cpu_call = String(opp.get("short_en", label))
	main.cpu.set_look(opp.get("look", Looks.from_shirt(Color(0.22, 0.28, 0.42))))
	Tuning.ai_skill = float(opp.get("skill", 0.5))
	main.hud.show_board(main.scoreboard, [main.me_name(), main.cpu_label])
	if not headless:
		_build_ui()
		_apply_camera()
	if fixed_stance != "":
		_set_stance(fixed_stance, 999)
	return true


## The hero's state out, the student's in. Undone by _swap_out.
func _swap_in() -> void:
	_saved = {"skills": Skills.to_profile(), "layer": Skills.mods_layer.duplicate(), "gear": Skills.gear.duplicate(), "lifetime": SaveData.lifetime_xp,
		"autoplay": main.autoplay, "points": main.autoplay_points, "bot_sd": main._bot_sd, "loc": main._next_location, "me": main.me_label,
		"look": SaveData.look.duplicate(), "scale": Engine.time_scale, "score": Tuning.ai_skill, "club": main.club.active,
		"cam_booth": main.cam.booth, "cam_wide": main.cam.booth_wide}
	if main.club.active:
		main.club.stand_at(ClubPlaces.find("booth")["pos"])
		main.club.close()
	Skills.load_profile(JuniorBot.skill_profile(st))
	Skills.mods_layer = {}
	Skills.gear = {}
	main.autoplay = true
	main.autoplay_points = 1000000
	main._bot_sd = JuniorBot.sd_of(st)
	main._next_location = "club" if not headless else main._next_location   # the calibration runs on the light park (same hard court, no club scenery)
	main.me_label = String(st.get("name", "ВЫ")).get_slice(" ", 0).to_upper()
	main.player.set_look(st.get("look", SaveData.look))
	if int(st.get("age", 18)) < 18:
		AthleteCasual.set_junior(main.player, JuniorGen.junior_t(float(Academy.age(st)) if st.has("since") else float(st.get("age", 15))))
	bot = JuniorBot.new(st, opp, int(m.get("seed", 1)))
	bot.begin()


func _swap_out() -> void:
	if _saved.is_empty():
		return
	if bot != null:
		bot.end()
	Skills.load_profile(_saved["skills"])
	Skills.mods_layer = _saved["layer"]
	Skills.gear = _saved["gear"]
	SaveData.lifetime_xp = float(_saved["lifetime"])
	main.autoplay = bool(_saved["autoplay"])
	main.autoplay_points = int(_saved["points"])
	main._bot_sd = float(_saved["bot_sd"])
	main._next_location = String(_saved["loc"])
	main.me_label = String(_saved["me"])
	main.player.set_look(SaveData.look)
	AthleteCasual.set_junior(main.player, 1.0)
	Engine.time_scale = 1.0
	if main.cam != null:
		main.cam.booth = bool(_saved["cam_booth"])
		main.cam.booth_wide = bool(_saved["cam_wide"])
		main.cam.spectate = false
	_saved = {}


# --- The bot's tick, the points -----------------------------------------------------------------

## Main._autoplay_tick, while this is watched.
func bot_tick() -> void:
	if bot != null and not ended:
		bot.tick(main)


func _on_match_started(_info: Dictionary) -> void:
	main.ai.set_profile(opp)
	main.ai.spared = 0.0   # a duel is not eased for anyone
	Tuning.ai_skill = float(opp.get("skill", 0.5))


func _on_shot(who: int, info: Dictionary) -> void:
	if bot != null:
		bot.on_shot(who, info)


func _on_point(info: Dictionary) -> void:
	if not active or ended:
		return
	var winner := int(info.get("winner", 0))
	var server := int(info.get("server", 0))
	if server == 0:
		stats["srv_a"] += 1
		stats["srv_a_won"] += 1 if winner == 0 else 0
	else:
		stats["srv_b"] += 1
		stats["srv_b_won"] += 1 if winner == 1 else 0
	log.append(winner)
	points_played += 1
	if winner == 1:
		streak_b += 1
	else:
		streak_b = 0
	bot.on_point()
	_after_point.call_deferred()


## Main adds the point to the scoreboard after the signal: look at it a frame later.
func _after_point() -> void:
	if not active or ended:
		return
	var sb: MatchScore = main.scoreboard
	if sb.is_over():
		_finish_live()
		return
	var mp := sb.match_point_for(0) or sb.match_point_for(1)
	saw_match_point = saw_match_point or mp
	bot.at_break_point = mp
	bot.refresh_sd()
	# The setup in force counts its points down, then fades out.
	if stance_id != "" and fixed_stance == "":
		if left > 0:
			left -= 1
			if left == 0:
				fade = JuniorBot.FADE_POINTS
		elif fade > 0:
			fade -= 1
		_apply_stance()
	m["pa"] = int(sb.points[0])
	m["pb"] = int(sb.points[1])
	m["played"] = points_played
	main.phase_timer = maxf(main.phase_timer, 1.1)   # a breath for the TV frame and the score
	if headless or fixed_stance != "":
		return
	var sit := JuniorBot.situation(int(sb.points[0]), int(sb.points[1]), streak_b, main.stamina, points_played - last_advice_at, advice_count, 0.35, sb.match_point_for(1))
	if sit == "":
		return
	var options := JuniorBot.options_for(sit, int(sb.server) == 0)
	if autopilot:
		_choose(JuniorBot.pick(options, st, opp, 1, _tired()), true)
	else:
		_ask(sit, options)


func _tired() -> float:
	return clampf((0.35 - main.stamina) / 0.35, 0.0, 1.0)


func _choose(id: String, auto := false) -> void:
	advice_count += 1
	last_advice_at = points_played
	(m["setups"] as Array).append({"at": points_played, "id": id})
	_set_stance(id, JuniorBot.POINTS_PER_STANCE)
	if not headless and auto:
		main.hud.announcer.toast("Тренер: %s" % JuniorBot.name_of(id), "advice", false)


func _set_stance(id: String, points: int) -> void:
	stance_id = id
	left = points
	fade = 0
	if not is_nan(fixed_boost):
		_apply_stance()
		return
	_apply_stance()


func _apply_stance() -> void:
	var w := 0.0
	if stance_id != "":
		if left > 0:
			w = 1.0
		elif fade > 0:
			w = float(fade) / float(JuniorBot.FADE_POINTS + 1)
	bot.set_stance(stance_id if w > 0.0 else "", w, _tired())
	if not is_nan(fixed_boost) and w > 0.0:
		# the calibration: a given boost in place of the one the fit would give
		Traits.undo_side(bot._boost_undo)
		bot._boost_undo = []
		for k in JuniorBot.BOOST:
			var v := float(JuniorBot.BOOST[k]) * fixed_boost
			Skills.mods_layer[k] = float(Skills.mods_layer.get(k, 0.0)) + v
			bot._boost_undo.append([k, v])
	if w <= 0.0:
		stance_id = ""


# --- Ending ----------------------------------------------------------------------------------------------

func _finish_live() -> void:
	if ended:
		return
	ended = true
	var sb: MatchScore = main.scoreboard
	var score: Array = sb.set_scores[0] if not sb.set_scores.is_empty() else [sb.points[0], sb.points[1]]
	main.phase_timer = 1000000.0   # nothing more is played
	if headless:
		_swap_out()
		_teardown()
		done.emit({"pa": int(score[0]), "pb": int(score[1]), "log": log, "stats": stats, "match_point": saw_match_point})
		return
	var res := JuniorMatch.complete(m, st, int(score[0]), int(score[1]), {"mode": "live", "watched_points": points_played, "total_points": points_played, "setups": m.get("setups", []), "match_point": saw_match_point})
	_show_result_later(res)


## «Итог»: the rest by the sim from the score it stands at. leave: «← В клуб» (no result screen).
func finish_instant(leave := false) -> Dictionary:
	if ended or not active:
		return {}
	ended = true
	var sb: MatchScore = main.scoreboard
	var pa := int(sb.points[0])
	var pb := int(sb.points[1])
	var played := points_played
	m["pa"] = pa
	m["pb"] = pb
	m["played"] = played
	var r := JuniorSim.simulate(st, opp, {"seed": int(m["seed"]), "first": int(m.get("first", 0)), "from": [pa, pb], "setups": m.get("setups", []), "autopilot": true})
	var total := (r["log"] as Array).size() + pa + pb
	var res := JuniorMatch.complete(m, st, int(r["pa"]), int(r["pb"]), {"mode": "left" if leave else "sim", "watched_points": played, "total_points": total,
		"setups": r["stances"], "match_point": saw_match_point or bool(r["match_point"])})
	main.phase_timer = 1000000.0
	if leave:
		_teardown()
		_swap_out()
		return res
	_show_result_later(res, 0.0)
	return res


func _show_result_later(res: Dictionary, wait := 1.4) -> void:
	_finish_pending = true
	if wait > 0.0:
		await get_tree().create_timer(wait, true, false, true).timeout
	if not active:
		return
	_teardown()
	_swap_out()
	main.phase = main.Phase.IDLE
	main.ball.park()
	main._stop_match()
	AcademyMatchUi.result(main.ui, res)


## On the way out of the match by the pause («Выйти в клуб»): Main._stop_match, before anything
## reads the skills. The rest of the match is the sim's.
func on_stop() -> void:
	if not active:
		return
	if not ended:
		finish_instant(true)
	else:
		_teardown()
		_swap_out()


func _teardown() -> void:
	if not active:
		return
	active = false
	if GameEvents.match_started.is_connected(_on_match_started):
		GameEvents.match_started.disconnect(_on_match_started)
	if GameEvents.point.is_connected(_on_point):
		GameEvents.point.disconnect(_on_point)
	if GameEvents.shot.is_connected(_on_shot):
		GameEvents.shot.disconnect(_on_shot)
	if main.spectate == self:
		main.spectate = null
	if _advice_open:
		_close_advice()
	_destroy_ui()


# --- Interface -------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = UiTheme.LAYER_SHEETS - 1
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.theme()
	_layer.add_child(_root)
	var bottom := maxf(float(main._safe.y), 0.0)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 14
	box.offset_right = -14
	box.offset_bottom = -(14.0 + bottom)
	box.offset_top = -(14.0 + bottom + 2.0 * UiTheme.TAP + 10.0)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row2)
	_btn_cam = _button("", _toggle_camera)
	row1.add_child(_btn_cam)
	_btn_speed = _button("", _toggle_speed)
	row1.add_child(_btn_speed)
	_btn_advice = _button("", _toggle_advice)
	row1.add_child(_btn_advice)
	var b_total := _button("Итог", func() -> void: finish_instant(false))
	row2.add_child(b_total)
	var b_leave := _button("← В клуб", func() -> void: _leave())
	row2.add_child(b_leave)
	_refresh_buttons()
	main.hud.touch.blocked_controls.append(box)
	# The plate over the student's head.
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.BASE, 0.9), UiTheme.GOLD, 2, 14, 10))
	_plate.visible = false
	_plate_label = Label.new()
	_plate_label.add_theme_font_override("font", UiTheme.text_bold())
	_plate_label.add_theme_font_size_override("font_size", 24)
	_plate_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_plate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_plate_label)
	_root.add_child(_plate)
	_advice_sheet = AcademyAdvice.new()
	var sheet_layer := CanvasLayer.new()
	sheet_layer.layer = UiTheme.LAYER_SHEETS
	sheet_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sheet_layer)
	sheet_layer.add_child(_advice_sheet)
	_advice_sheet.picked.connect(_on_picked)
	_advice_sheet.muted.connect(_on_muted)
	main.hud.touch.blocked_controls.append(_advice_sheet)
	_advice_sheet.set_safe_area(maxf(float(main._safe.x), 0.0), bottom)


func _button(caption: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiTheme.TAP)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UiTheme.T_SMALL + 2)
	b.pressed.connect(on_press)
	return b


func _destroy_ui() -> void:
	if _root != null and is_instance_valid(main) and main.hud != null:
		main.hud.touch.blocked_controls.erase(_root.get_child(0))
	if _advice_sheet != null and is_instance_valid(main) and main.hud != null:
		main.hud.touch.blocked_controls.erase(_advice_sheet)
	if _layer != null:
		_layer.queue_free()
		_layer = null
	if _advice_sheet != null:
		var p := _advice_sheet.get_parent()
		if p != null:
			p.queue_free()
		_advice_sheet = null
	_root = null
	_plate = null


func _refresh_buttons() -> void:
	if _btn_cam == null:
		return
	_btn_cam.text = "Камера: Будка" if cam_mode == "booth" else "Камера: Матч"
	_btn_speed.text = "Скорость ×%d" % speed
	_btn_advice.text = "Советы: %s" % ("да" if JuniorMatch.advice_on() else "нет")


func _toggle_camera() -> void:
	cam_mode = "match" if cam_mode == "booth" else "booth"
	_apply_camera()
	_refresh_buttons()


func _apply_camera() -> void:
	var c: GameCamera = main.cam
	c.spectate = true
	c.booth = cam_mode == "booth"


func _toggle_speed() -> void:
	speed = 2 if speed == 1 else 1
	Engine.time_scale = float(speed)
	_refresh_buttons()


func _toggle_advice() -> void:
	JuniorMatch.set_advice(not JuniorMatch.advice_on())
	autopilot = not JuniorMatch.advice_on()
	_refresh_buttons()


func _leave() -> void:
	var res := finish_instant(true)
	main._show_menu()
	if main.club.active:
		main.club.coach.say(String(res.get("text", "")), true)


func _ask(sit: String, options: Array) -> void:
	if _advice_sheet == null:
		_choose(JuniorBot.pick(options, st, opp, 1, _tired()), true)
		return
	var sb: MatchScore = main.scoreboard
	var line := "%s  %d : %d  %s" % [main.me_label.capitalize(), int(sb.points[0]), int(sb.points[1]), String(opp.get("short", opp["name"])).capitalize()]
	var ps: Dictionary = Opponents.play_style(opp)
	var caps := Opponents.captions(Opponents.stats(opp))
	var oline := "Соперник: %s%s" % [ps["name"], ("  ·  " + ", ".join(caps).to_lower()) if not caps.is_empty() else ""]
	_advice_open = true
	_advice_sheet.show_advice(sit, options, line, oline)
	main.hud.modals.push("advice", _advice_sheet, true)


func _on_picked(id: String) -> void:
	_close_advice()
	_choose(id)


func _on_muted() -> void:
	JuniorMatch.set_advice(false)
	autopilot = true
	_close_advice()
	var sb: MatchScore = main.scoreboard
	var sit := JuniorBot.situation(int(sb.points[0]), int(sb.points[1]), streak_b, main.stamina, 99, 0, 0.35, sb.match_point_for(1))
	_choose(JuniorBot.pick(JuniorBot.options_for(sit if sit != "" else "behind", int(sb.server) == 0), st, opp, 1, _tired()), true)
	_refresh_buttons()


func _close_advice() -> void:
	_advice_open = false
	if _advice_sheet != null:
		_advice_sheet.close()
	main.hud.modals.pop("advice")


func _process(_delta: float) -> void:
	if not active or main == null:
		return
	if _advice_open and not main.hud.modals.has("advice") and _advice_sheet.visible:
		main.hud.modals.push("advice", _advice_sheet, true)   # a pause over it was closed: the question still stands
	if main.cam != null and cam_mode in ["booth", "match"]:
		var play: bool = main.phase == main.Phase.RALLY or main.phase == main.Phase.SERVE
		main.cam.booth_wide = not play
	if _plate != null:
		var show: bool = stance_id != "" and (left > 0 or fade > 0) and not _advice_open and main.phase != main.Phase.IDLE
		_plate.visible = show
		if show:
			_plate_label.text = "Установка: %s · ещё %d" % [JuniorBot.name_of(stance_id), maxi(left, 0)] if left > 0 else "Установка: %s · затихает" % JuniorBot.name_of(stance_id)
			var pos: Vector3 = main.player.global_position + Vector3(0, 2.5, 0)
			if not main.cam.is_position_behind(pos):
				var sp: Vector2 = main.cam.unproject_position(pos)
				var vp: Vector2 = get_viewport().get_visible_rect().size
				_plate.reset_size()
				_plate.position = Vector2(clampf(sp.x - _plate.size.x * 0.5, PLATE_MARGIN, vp.x - _plate.size.x - PLATE_MARGIN), clampf(sp.y - _plate.size.y, 150.0, vp.y - 300.0))
