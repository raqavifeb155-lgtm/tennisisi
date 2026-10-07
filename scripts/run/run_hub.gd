class_name RunHub
extends Node
## The roguelike layer of a match (v0.2 stream A), listening to GameEvents instead of
## living inside Main: style points now; gear effects, the opponent's stamina and bets
## later. Main creates it once (run_hub.setup(self)); it reads Main's state and touches
## only a few things: experience for style, the run's gold.

signal style_scored(result: Dictionary)

var main: Node
var meter := StyleMeter.new()
var boosts := {}                  # style boosts from the gear (RunEffects, A-2)
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
	plate = StylePlate.new()
	overlay.add_child(plate)
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


func _on_stroke(info: Dictionary) -> void:
	meter.on_stroke(info, main.cpu.position, recorder.frame)


# --- Recording the rallies -----------------------------------------------------

## Every rally is recorded from the serve to 1.5 s after the point; the best one is kept.
func _physics_process(_delta: float) -> void:
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
	var r := meter.on_point(info, comeback, boosts)
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


func _on_match_finished(_info: Dictionary) -> void:
	if not _in_match:
		return
	_in_match = false
	plate.hide_now()  # the menus come next
	if not in_tournament():
		return
	var t: Tournament = main.tournament
	var g := meter.gold(float(t.format_info()["reward"]), t.stage)
	t.gold += g
	last_match = {"points": meter.match_points, "gold": g, "best": meter.best}
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
