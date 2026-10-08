class_name DrillHud
extends CanvasLayer
## What the ball machine's drill puts on the screen (docs/superpowers/specs/2026-10-08-p-ball-machine.md):
##   top card    the task ("ТОПСПИН", "1 / 3"), a dot per exercise, the verdict of the last ball
##               flashing in place of the title (ЗАСЧИТАНО / НЕ ТОТ УДАР / МИМО)
##   hint card   the gesture drawn and animated (a finger and an arrow, like the tutorial) and
##               the coach's line; it dims while the ball is in the air
##   exit pill   «Позже» in the first lesson, «Выйти» after it
##   summary     the lap's result: a row per exercise, PERFECT, experience, gold
## Everything sits in the top band under the safe area; nothing is drawn over the timing ring
## (above the player) or the joystick (under the player's feet). Taps pass through all of it
## except the pill and the summary.

signal exit_pressed
signal again_pressed

const CARD_X := 14.0
const CARD_Y := 14.0
const RIGHT_KEEP := 112.0        # the pause button's column (84 + gutters)
const HINT_GAP := 100.0          # the call strip (HudAnnouncer) runs under the top card
const FLASH_HOLD := 1.15

var _root: Control
var _safe_top := 0.0
var _card: PanelContainer
var _title: Label
var _count: Label
var _dots: Control
var _note: Label
var _hint: PanelContainer
var _anim: Control
var _coach_tag: Label
var _coach: Label
var _exit: Button
var _summary: PanelContainer
var _sum_box: VBoxContainer
var _sum_again: Button
var _sum_exit: Button

var _t := 0.0
var _gesture := 0
var _states: Array = []          # per exercise: 0 todo / 1 current / 2 done
var _base_title := ""
var _base_color := UiTheme.INK
var _flash_t := 0.0
var _dim := false
var _line_t := 0.0               # a passing coach line shows this long, then the instruction returns
var _instruction := ""
var _vp := Vector2(720, 1564)


func _init() -> void:
	layer = UiTheme.LAYER_HUD + 1
	visible = false


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_card()
	_build_hint()
	_build_exit()
	_build_summary()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.93), Color(1, 1, 1, 0.1), 1, 18, 14))
	_root.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	_title = _label("", UiTheme.display(), 40, UiTheme.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	row.add_child(_title)
	_count = _label("", UiTheme.display(), 44, UiTheme.GOLD)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_count)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 14)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row2)
	_dots = Control.new()
	_dots.custom_minimum_size = Vector2(8 * 30.0, 22.0)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	row2.add_child(_dots)
	_note = _label("", UiTheme.text_bold(), 21, UiTheme.GOLD)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.clip_text = true
	row2.add_child(_note)


func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.9), Color(1, 1, 1, 0.1), 1, 18, 12))
	_root.add_child(_hint)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(h)
	_anim = Control.new()
	_anim.custom_minimum_size = Vector2(150, 170)
	_anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim.draw.connect(_draw_anim)
	h.add_child(_anim)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_coach_tag = _label("ТРЕНЕР", UiTheme.text_bold(), 20, UiTheme.GOLD)
	v.add_child(_coach_tag)
	_coach = _label("", UiTheme.text(), 25, UiTheme.INK)
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_coach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coach.custom_minimum_size = Vector2(250, 0)
	v.add_child(_coach)


func _build_exit() -> void:
	_exit = Button.new()
	_exit.text = "Выйти"
	_exit.theme_type_variation = "Quiet"
	_exit.focus_mode = Control.FOCUS_NONE
	_exit.custom_minimum_size = Vector2(170, 64)
	_exit.add_theme_stylebox_override("normal", UiTheme.box(Color(UiTheme.SURFACE, 0.9), Color(1, 1, 1, 0.14), 1, 32, 10))
	_exit.add_theme_stylebox_override("hover", UiTheme.box(Color(UiTheme.SURFACE_HI, 0.95), Color(1, 1, 1, 0.2), 1, 32, 10))
	_exit.add_theme_stylebox_override("pressed", UiTheme.box(Color(UiTheme.SURFACE_HI, 0.95), Color(1, 1, 1, 0.2), 1, 32, 10))
	_exit.theme = UiTheme.theme()
	_exit.pressed.connect(func() -> void: exit_pressed.emit())
	_root.add_child(_exit)


func _build_summary() -> void:
	_summary = PanelContainer.new()
	_summary.theme = UiTheme.theme()
	_summary.visible = false
	_summary.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.97), Color(UiTheme.GOLD, 0.6), 2, 24, 26))
	_root.add_child(_summary)
	_sum_box = VBoxContainer.new()
	_sum_box.add_theme_constant_override("separation", 8)
	_summary.add_child(_sum_box)


# --- Layout -------------------------------------------------------------------

func set_safe_area(top: float, _bottom: float) -> void:
	_safe_top = top
	_layout()


func _layout() -> void:
	if _root == null or not is_inside_tree():
		return
	_vp = get_viewport().get_visible_rect().size
	var w := _vp.x - CARD_X - RIGHT_KEEP
	_card.position = Vector2(CARD_X, CARD_Y + _safe_top)
	_card.size = Vector2(w, 0)
	_card.reset_size()
	_card.custom_minimum_size.x = w
	_card.size.x = w
	var hint_y := _card.position.y + 118.0 + HINT_GAP
	_hint.position = Vector2(CARD_X, hint_y)
	_hint.reset_size()
	_hint.size.x = minf(w, 560.0)
	_exit.position = Vector2(_vp.x - CARD_X - _exit.custom_minimum_size.x, hint_y + _hint.size.y + 10.0)
	_exit.size = _exit.custom_minimum_size
	_layout_summary()


func _layout_summary() -> void:
	_summary.reset_size()
	var w := minf(_vp.x - 56.0, 620.0)
	_summary.custom_minimum_size.x = w
	_summary.size = Vector2(w, 0)
	_summary.reset_size()
	_summary.position = Vector2((_vp.x - _summary.size.x) * 0.5, maxf(_safe_top + 90.0, (_vp.y - _summary.size.y) * 0.42))


## The rects that are on the screen now, for the overlay probe: every one must stay clear
## of the timing ring and the joystick.
func rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not visible:
		return out
	for c in [_card, _hint, _exit, _summary]:
		if (c as Control).is_visible_in_tree():
			out.append((c as Control).get_global_rect())
	return out


func blocking() -> Array[Control]:
	return [_exit, _summary]


func hint_rect() -> Rect2:
	return _hint.get_global_rect()


func summary_shown() -> bool:
	return _summary.visible


func buttons() -> Array[Button]:
	var out: Array[Button] = [_exit]
	if _sum_again != null and _summary.visible:
		out.append(_sum_again)
	if _sum_exit != null and _summary.visible:
		out.append(_sum_exit)
	return out


# --- Content --------------------------------------------------------------------

func show_hud(on: bool) -> void:
	visible = on
	if on:
		_layout.call_deferred()


## The exercise on the card. `states`: 0 todo / 1 current / 2 done for each exercise.
func set_task(title: String, got: int, need: int, states: Array, note := "") -> void:
	_base_title = title
	_states = states
	if _flash_t <= 0.0:
		_title.text = title
		_title.add_theme_color_override("font_color", UiTheme.INK)
	_base_color = UiTheme.INK
	_count.text = "%d / %d" % [got, need]
	_note.text = note
	_dots.queue_redraw()


func set_gesture(kind: int, instruction: String) -> void:
	_gesture = kind
	_instruction = instruction
	_line_t = 0.0
	_coach.text = instruction
	_t = 0.0
	_layout.call_deferred()


## A passing line from the coach ("Отлично!"); the instruction returns after `seconds`.
func say(text: String, seconds := 2.6) -> void:
	_coach.text = text
	_line_t = seconds
	_layout.call_deferred()


func current_line() -> String:
	return _coach.text


## The ball's verdict flashes in place of the title.
func flash(text: String, color: Color) -> void:
	_title.text = text
	_title.add_theme_color_override("font_color", color)
	_flash_t = FLASH_HOLD


func flash_text() -> String:
	return _title.text if _flash_t > 0.0 else ""


func set_note(text: String) -> void:
	_note.text = text


func set_exit_label(text: String) -> void:
	_exit.text = text
	_layout.call_deferred()


## The hint card dims while the ball is in the air: the far court is not hidden.
func set_dim(on: bool) -> void:
	_dim = on


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_title.text = _base_title
			_title.add_theme_color_override("font_color", UiTheme.INK)
	if _line_t > 0.0:
		_line_t -= delta
		if _line_t <= 0.0:
			_coach.text = _instruction
	var a := 0.32 if _dim and not _summary.visible else 1.0
	_hint.modulate.a = lerpf(_hint.modulate.a, a, 1.0 - exp(-10.0 * delta))
	_anim.queue_redraw()


# --- The lap's summary -----------------------------------------------------------

## rows: [{name, ok, need, perfect}], lines: free text lines under the table (gold / muted),
## `first`: the first lesson (the button leads on, «Ещё круг» is quiet).
func show_summary(rows: Array, perfect: int, total: int, footer: Array, first: bool) -> void:
	for c in _sum_box.get_children():
		c.queue_free()
	var head := _label("КРУГ ПРОЙДЕН", UiTheme.display(), 44, UiTheme.GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_box.add_child(head)
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var n := _label(String(r["name"]), UiTheme.text_bold(), 27, UiTheme.INK)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var star := _label(("★ %d" % int(r["perfect"])) if int(r["perfect"]) > 0 else "", UiTheme.text_bold(), 24, UiTheme.GOLD)
		star.custom_minimum_size.x = 70
		row.add_child(star)
		var ok := _label("%d / %d" % [int(r["ok"]), int(r["need"])], UiTheme.display(), 27, UiTheme.WIN)
		ok.custom_minimum_size.x = 96
		ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(ok)
		_sum_box.add_child(row)
	var pf := _label("PERFECT: %d из %d" % [perfect, total], UiTheme.text_bold(), 26, UiTheme.GOLD)
	pf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_box.add_child(pf)
	for f in footer:
		var l := _label(String(f), UiTheme.text(), 24, UiTheme.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sum_box.add_child(l)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	_sum_box.add_child(btns)
	_sum_again = Button.new()
	_sum_again.text = "Ещё круг"
	_sum_again.focus_mode = Control.FOCUS_NONE
	_sum_again.custom_minimum_size = Vector2(0, UiTheme.TAP)
	_sum_again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sum_again.pressed.connect(func() -> void: again_pressed.emit())
	_sum_exit = Button.new()
	_sum_exit.text = "В КЛУБ"
	_sum_exit.theme_type_variation = "Primary"
	_sum_exit.focus_mode = Control.FOCUS_NONE
	_sum_exit.custom_minimum_size = Vector2(0, UiTheme.TAP)
	_sum_exit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sum_exit.pressed.connect(func() -> void: exit_pressed.emit())
	btns.add_child(_sum_again)
	btns.add_child(_sum_exit)
	_summary.visible = true
	_hint.visible = false
	_exit.visible = false
	_layout.call_deferred()


func hide_summary() -> void:
	_summary.visible = false
	_hint.visible = true
	_exit.visible = true


# --- Drawing ---------------------------------------------------------------------

func _draw_dots() -> void:
	for i in _states.size():
		var c := Vector2(11.0 + i * 30.0, 11.0)
		match int(_states[i]):
			2:
				_dots.draw_circle(c, 9.0, UiTheme.GOLD)
			1:
				_dots.draw_circle(c, 9.0, Color(UiTheme.GOLD, 0.25))
				_dots.draw_arc(c, 9.0, 0.0, TAU, 24, UiTheme.GOLD, 2.5, true)
			_:
				_dots.draw_arc(c, 8.0, 0.0, TAU, 24, Color(1, 1, 1, 0.3), 2.0, true)


const C_COURT := Color(0.2, 0.38, 0.66)
const C_LINE := Color(0.95, 0.95, 0.95)
const C_FINGER := Color(0.6, 0.95, 1.0)
const C_BALL := Color(0.86, 0.95, 0.2)


## The gesture, drawn the way the tutorial draws it: the finger runs the path, an arrowhead
## stays at its end; the lob is slow, the rest quick.
func _draw_anim() -> void:
	var sz := _anim.size
	var rect := Rect2(Vector2.ZERO, sz)
	_anim.draw_rect(rect, Color(0, 0, 0, 0.28))
	var base := Vector2(sz.x * 0.5, sz.y - 22.0)
	var k := (sz.y - 52.0) / 200.0
	if _gesture <= 4:
		var period := 2.6 if _gesture == 4 else 1.9
		var run := 1.7 if _gesture == 4 else 0.9
		var p := minf(fmod(_t, period) / run, 1.0)
		var fade := 1.0 - clampf((fmod(_t, period) - run - 0.35) / 0.3, 0.0, 1.0)
		var pts := PackedVector2Array()
		for q in gesture_path(_gesture, p):
			pts.append(base + q * k)
		if pts.size() > 1:
			var col := Color(C_FINGER, fade)
			_anim.draw_polyline(pts, col, 6.0, true)
			var tip := pts[pts.size() - 1]
			var dir := (tip - pts[maxi(pts.size() - 4, 0)]).normalized()
			if p >= 1.0 and dir.length() > 0.1:
				_arrowhead(tip, dir, col)
			_anim.draw_circle(tip, 10.0, col)
		_anim.draw_circle(base, 4.0, Color(1, 1, 1, 0.35))
		return
	# Exercises that are about where you stand, not about the stroke.
	var u := fmod(_t, 2.6) / 2.6
	var net_y := 38.0
	_anim.draw_line(Vector2(10, net_y), Vector2(sz.x - 10, net_y), Color(1, 1, 1, 0.55), 4.0)
	match _gesture:
		5:  # volley: the player walks up to the net, the ball comes over
			var py := lerpf(sz.y - 26.0, net_y + 36.0, clampf(u * 1.6, 0.0, 1.0))
			_anim.draw_circle(Vector2(sz.x * 0.5, py), 12.0, Color(0.92, 0.36, 0.26))
			var bu := clampf((u - 0.45) / 0.5, 0.0, 1.0)
			_anim.draw_circle(Vector2(sz.x * 0.5 + 34.0 - bu * 22.0, lerpf(-6.0, py - 20.0, bu)), 7.0, C_BALL)
			_arrow(Vector2(sz.x * 0.5 - 38.0, sz.y - 30.0), Vector2(sz.x * 0.5 - 38.0, net_y + 60.0), Color(C_FINGER, 0.8))
		6:  # smash: a high ball falls, a swipe up
			var by := lerpf(-10.0, sz.y * 0.42, clampf(u * 1.3, 0.0, 1.0))
			_anim.draw_circle(Vector2(sz.x * 0.5 + 16.0, by), 8.0, C_BALL)
			_anim.draw_circle(Vector2(sz.x * 0.5, sz.y - 40.0), 12.0, Color(0.92, 0.36, 0.26))
			if u > 0.55:
				var f := clampf((u - 0.55) / 0.3, 0.0, 1.0)
				_arrow(Vector2(sz.x * 0.5 - 40.0, sz.y - 20.0), Vector2(sz.x * 0.5 - 40.0, lerpf(sz.y - 20.0, 60.0, f)), C_FINGER)
		_:  # serve: toss and a swipe
			var ty := sz.y - 52.0 - sin(clampf(u * 1.5, 0.0, 1.0) * PI) * (sz.y - 96.0)
			_anim.draw_circle(Vector2(sz.x * 0.5 + 18.0, ty), 8.0, C_BALL)
			_anim.draw_circle(Vector2(sz.x * 0.5, sz.y - 30.0), 12.0, Color(0.92, 0.36, 0.26))
			if u > 0.45:
				var f2 := clampf((u - 0.45) / 0.3, 0.0, 1.0)
				_arrow(Vector2(sz.x * 0.5 - 42.0, sz.y - 22.0), Vector2(sz.x * 0.5 - 30.0, lerpf(sz.y - 22.0, 56.0, f2)), C_FINGER)


## The finger's path of each stroke (0 flat, 1 topspin, 2 slice, 3 drop, 4 lob) from the
## origin, `progress` 0..1: the shapes of the tutorial's gesture page (px for a 200 px stroke).
static func gesture_path(kind: int, progress: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := int(30 * progress)
	for i in n + 1:
		var u := float(i) / 30.0
		match kind:
			0:
				pts.append(Vector2(6 * u, -200 * u))
			1:
				if u < 0.7:
					pts.append(Vector2(0, -200 * u / 0.7))
				else:
					var a := (u - 0.7) / 0.3 * PI * 0.5
					pts.append(Vector2(40 * sin(a), -200 + 40 * (1.0 - cos(a))))
			2:
				pts.append(Vector2(-35 + 60 * u, -200 + 180 * u))
			3:
				pts.append(Vector2(8 * sin(u * PI), -110 + 60 * u))
			_:
				pts.append(Vector2(-38 * sin(u * PI), -200 * u))
	return pts


func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	_anim.draw_line(a, b, col, 5.0)
	var d := (b - a).normalized()
	if (b - a).length() > 14.0:
		_arrowhead(b, d, col)


func _arrowhead(tip: Vector2, d: Vector2, col: Color) -> void:
	var n := Vector2(-d.y, d.x)
	_anim.draw_colored_polygon(PackedVector2Array([tip + d * 14.0, tip - d * 4.0 + n * 11.0, tip - d * 4.0 - n * 11.0]), col)


func _label(text: String, font: Font, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
