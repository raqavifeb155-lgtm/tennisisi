class_name RunHub
extends Node
## The roguelike layer of a match (v0.2 stream A), listening to GameEvents instead of
## living inside Main: style points, the best point's replay, the gear's effects and the
## opponent's stamina (MatchEffects, tournament only). Main creates it once
## (run_hub.setup(self)); it reads Main's state and touches only what MatchEffects
## describes, experience for style and the run's gold.

signal style_scored(result: Dictionary)

var main: Node
var meter := StyleMeter.new()
var match_fx: MatchEffects         # the gear and the opponent's stamina, this match (tournament)
var view: OppStaminaView
var last_match := {}              # the finished match: points, gold, best (for the result screen)
var overlay: CanvasLayer          # over the HUD (1), under the menus (TournamentUI, 10)
var plate: StylePlate
var recorder: PointRecorder
var share_image: Image            # a frame of the last replay with the style plate on it
var _in_match := false
var _recording := false
var _tick := 0
var _post_roll := -1              # frames still to record after the point ended (-1 = not ending)
var _end_is_best := false
var _end_frame := -1
var _best_end := -1               # the best point's frame where it was decided
var _playing := false
var _play_t := 0.0
var _play_i := -1
var _snap := {}
var _on_done: Callable
var _skip: Control

const REPLAY_HZ := 30.0
const POST_ROLL := 45             # 1.5 s after the point: the ball dies, the plate plays out
const SHOT_AFTER := 27            # the share picture: 0.9 s after the point, plate on screen
const LEAD_IN := 240              # the replay starts 8 s before the point was decided


func setup(m: Node) -> void:
	main = m
	overlay = CanvasLayer.new()
	overlay.layer = 5
	add_child(overlay)
	view = OppStaminaView.new()
	overlay.add_child(view)
	plate = StylePlate.new()
	overlay.add_child(plate)  # over the bar
	style_scored.connect(func(r: Dictionary) -> void:
		if not main.autoplay:
			plate.show_result(r))
	recorder = PointRecorder.new([main.player, main.cpu, main.ball] as Array[Node3D])
	_skip = Control.new()
	_skip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip.visible = false
	_skip.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_finish_replay())
	overlay.add_child(_skip)
	var tag := Label.new()
	tag.text = "ПОВТОР  ·  тап — пропустить"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", UiTheme.text_bold())
	tag.add_theme_font_size_override("font_size", UiTheme.T_SMALL + 2)
	tag.add_theme_color_override("font_color", UiTheme.INK)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	tag.add_theme_constant_override("outline_size", 8)
	tag.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tag.offset_top = 120
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip.add_child(tag)
	# The autoload by path: tools and tests compile this script before autoload names exist.
	var ev: Node = get_node("/root/GameEvents")
	ev.match_started.connect(_on_match_started)
	ev.match_finished.connect(_on_match_finished)
	ev.player_stroke.connect(_on_stroke)
	ev.shot.connect(func(who: int, info: Dictionary) -> void:
		if match_fx:
			match_fx.on_shot(who, info))
	ev.bounce.connect(meter.on_bounce)
	ev.knocked.connect(meter.on_knocked)
	ev.point.connect(_on_point)


func in_tournament() -> bool:
	return main.tournament_mode and main.tournament != null


func _on_match_started(_info: Dictionary) -> void:
	_in_match = true
	last_match = {}
	share_image = null
	recorder.keep_best({})
	_best_end = -1
	_recording = false
	_post_roll = -1
	meter.start_match()
	if match_fx:
		match_fx.finish()
	match_fx = null
	view.reset()
	view.shown = false
	if in_tournament():
		match_fx = MatchEffects.new(main, main.tournament)
		match_fx.damaged.connect(_on_damaged)
		view.shown = not main.autoplay
		if main.tournament.current_lineup().get("golden", false):
			_golden_entrance()


## A golden opponent: the kit in gold, the racket glowing, his name announced.
func _golden_entrance() -> void:
	var opp: Dictionary = main.tournament.opponent()
	main.cpu.set_look(Golden.look(opp.get("look", Looks.from_shirt(opp.get("shirt", Color(0.22, 0.28, 0.42))))))
	main.cpu.set_racket_look(UiTheme.GOLD, 1.6)
	# After Main's own "round · name" message, which comes right after this event.
	main.hud.show_message.call_deferred("ЗОЛОТОЙ\n%s" % String(opp["short"]), UiTheme.GOLD)


func _on_stroke(info: Dictionary) -> void:
	meter.on_stroke(info, main.cpu.position, recorder.frame)
	if match_fx:
		match_fx.on_stroke(info)


func _on_damaged(amount: float, kind: String) -> void:
	if view.shown:
		view.hit(amount, kind, match_fx.opp.value)


## The bar follows him on screen (its look: Tuning.opp_bar_style), keeps off the ball and
## off the score plate's own cells.
func _process_view() -> void:
	if not view.shown:
		return
	view.style = Tuning.opp_bar_style
	var cam: Camera3D = main.cam
	var bug = main.hud._bug
	if bug != null and bug.visible:
		view.board_rect = bug.get_global_rect()
		var rows: Array = bug._rows
		view.name_rect = (rows[1]["name"] as Control).get_global_rect() if rows.size() > 1 else Rect2()
	if cam == null:
		return
	var ball: Node3D = main.ball
	if ball != null and ball.visible and not cam.is_position_behind(ball.global_position):
		view.ball_px = cam.unproject_position(ball.global_position)
	else:
		view.ball_px = Vector2(-1e4, -1e4)
	var head: Vector3 = main.cpu.global_position + Vector3(0, 2.25, 0)
	if cam.is_position_behind(head):
		return
	view.anchor = cam.unproject_position(head)
	view.unit_px = (cam.unproject_position(head + cam.global_transform.basis.x) - view.anchor).length()


# --- Recording the rallies -----------------------------------------------------

## Every rally is recorded from the serve to 1.5 s after the point; the best one is kept.
func _physics_process(_delta: float) -> void:
	if _in_match and main.phase == main.Phase.IDLE and not _playing:
		_abandon()  # left for the menu mid-match: no match_finished comes
	if match_fx:
		match_fx.physics(main.phase == main.Phase.RALLY)
	if _playing:
		return
	var live: bool = main.phase == main.Phase.SERVE or main.phase == main.Phase.RALLY
	if live and not _recording:
		# A fault ends the recording (the phase leaves SERVE): the rally starts again
		# with the serve that counted. A quick serve may skip SERVE in a single tick.
		recorder.begin()
		_recording = true
		_tick = 0
		_post_roll = -1
	if not _recording:
		return
	_tick += 1
	if _tick % 2 == 0:
		recorder.capture(main.ball.position, main.ball.visible)
		if _post_roll > 0:
			_post_roll -= 1
	if _post_roll == 0 or (not live and _post_roll < 0):
		var frames := recorder.end_point()
		if _end_is_best and _post_roll == 0:
			recorder.keep_best(frames)
			_best_end = _end_frame
		_recording = false
		_post_roll = -1
		_end_is_best = false


func _on_point(info: Dictionary) -> void:
	# Main emits before the score moves on: the board still shows the score the point was
	# played at.
	var sb: MatchScore = main.scoreboard
	var comeback: bool = not sb.in_tiebreak and sb.points[0] == 0 and sb.points[1] == 3
	var before := meter.best_index
	var last_type := String(meter.last_stroke().get("type", ""))
	var r := meter.on_point(info, comeback, match_fx.style_boosts() if match_fx else {})
	if match_fx:
		match_fx.on_point(info, r, last_type)
	if _recording:
		_post_roll = POST_ROLL
		_end_frame = recorder.frame
		_end_is_best = meter.best_index != before
	if r["points"] <= 0:
		return
	SaveData.note_style(r)
	if in_tournament() and r["skill"] != "":
		main._gain_xp(r["skill"], "", Skills.BASE_XP * (float(r["mult"]) - 1.0) * 2.0)
	style_scored.emit(r)


## The match was left unfinished (menu, give up): put everything back, count nothing.
func _abandon() -> void:
	_in_match = false
	plate.hide_now()
	view.shown = false
	if match_fx:
		match_fx.finish()
		match_fx = null
	_recording = false
	_post_roll = -1


func _on_match_finished(info: Dictionary) -> void:
	if not _in_match:
		return
	_in_match = false
	plate.hide_now()  # the menus come next
	view.shown = false
	if match_fx:
		if main.autoplay:
			print("  OPP STA: lowest %d%%, damage %d (asked %d over %d points)" % [roundi(match_fx.lowest), roundi(match_fx.damage_dealt), roundi(match_fx.raw_damage), match_fx.points])
		match_fx.finish()
		match_fx = null
	if not in_tournament():
		return
	var t: Tournament = main.tournament
	var g := meter.gold(float(t.format_info()["reward"]), t.stage)
	t.earn("style", g)
	last_match = {"points": meter.match_points, "gold": g, "best": meter.best}
	if bool(info.get("won", false)) and t.current_lineup().get("golden", false):
		Golden.note_beaten(String(t.opponent()["id"]))
		last_match["golden"] = true
	if not t.bet.is_empty():
		var stake := int(t.bet["stake"])
		last_match["bet"] = {"stake": stake, "paid": Bets.settle_match(t, main.scoreboard)}
		last_match["bet"].merge(Bets.last_result)  # E-5: side, odds, the disqualification and its fine
	Bets.note_form(SaveData.bets, bool(info.get("won", false)))  # the bookmaker's form
	if main.autoplay:
		print("  STYLE: %d points, +%d gold, best x%.2f" % [meter.match_points, g, float(meter.best.get("mult", 1.0))])


# --- The replay ----------------------------------------------------------------

func has_replay() -> bool:
	return PointRecorder.length(recorder.best_frames) > 0 and not meter.best.is_empty()


## Plays the match's best point on the court (players and ball frozen meanwhile), the
## style plate at the moment it was won; a tap skips. on_done runs after.
func play_best(on_done: Callable) -> void:
	_on_done = on_done
	if not has_replay():
		_on_done.call()
		return
	_snap = recorder.snapshot()
	for n in [main.player, main.cpu, main.ball]:
		n.process_mode = Node.PROCESS_MODE_DISABLED
	_playing = true
	_play_t = maxi(0, _best_end - LEAD_IN) / REPLAY_HZ
	_play_i = -1
	_skip.visible = true


func _process(delta: float) -> void:
	if plate.visible and not _playing and main.ui.is_open():
		plate.hide_now()  # a menu screen is up: the plate must not show through its veil
	_process_view()
	if not _playing:
		return
	_play_t += delta / maxf(Engine.time_scale, 0.01)
	var i := int(_play_t * REPLAY_HZ)
	var n := PointRecorder.length(recorder.best_frames)
	if i >= n:
		_finish_replay()
		return
	if i == _play_i:
		return
	recorder.apply(recorder.best_frames, i, main.ball)
	if _play_i < _best_end and i >= _best_end:
		plate.show_result(meter.best)
	if share_image == null and i >= mini(_best_end + SHOT_AFTER, n - 1):
		_grab_share_image.call_deferred()
	_play_i = i


func _grab_share_image() -> void:
	await RenderingServer.frame_post_draw
	if share_image == null:
		share_image = get_viewport().get_texture().get_image()


func _finish_replay() -> void:
	if not _playing:
		return
	_playing = false
	_skip.visible = false
	recorder.restore(_snap)
	for n in [main.player, main.cpu, main.ball]:
		n.process_mode = Node.PROCESS_MODE_INHERIT
	main.ball.visible = false
	if _on_done.is_valid():
		_on_done.call()


## Main._on_ui hands the result screen's "replay" and "share" here.
static func ui_action(m: Node, action: String) -> void:
	var h: RunHub = m.run_hub
	match action:
		"replay":
			m.ui.close()
			h.play_best(func() -> void:
				var t: Tournament = m.tournament
				if t == null or t.results.is_empty():
					m.ui.show_menu()
					return
				var last: Dictionary = t.results.back()
				m.ui.show_result(t, bool(last["won"]), String(last["score"]), m._match_stats))
		"share":
			var how := RunShare.share(h.share_image, h.meter.best)
			TelegramApp.log_event("share", {"how": how, "mult": snappedf(float(h.meter.best.get("mult", 1.0)), 0.1)})
