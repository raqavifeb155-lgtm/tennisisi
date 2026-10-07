class_name StylePlate
extends Control
## The style plate after a point the player won with tricks (StyleRules): the tricks pop
## in one by one, "×2.4" ticks up with them, the points flash and the plate floats away.
## About 1.6 s, real time (slow motion and hit-stop don't stretch it), never takes a tap.
## Sits under the point's verdict (Hud message), clear of the far court and the ball.
## Its place is TOP and nothing else (stream C may move it into a HUD announcer column).

const TOP := 0.255                # of the screen height: below the verdict (y 214..384 of 1564)
const WIDTH := 540.0
const STEP := 0.18                # s between tricks

var _panel: PanelContainer
var _tricks: VBoxContainer
var _head: Label                  # "СТИЛЬ", then "СТИЛЬ  +25"
var _mult: Label
var _points := ""
var _tween: Tween
var _result := {}


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	_panel.add_child(h)
	_tricks = VBoxContainer.new()
	_tricks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tricks.alignment = BoxContainer.ALIGNMENT_CENTER
	_tricks.add_theme_constant_override("separation", 2)
	h.add_child(_tricks)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	h.add_child(right)
	_head = _label("СТИЛЬ", UiTheme.text_bold(), UiTheme.T_SMALL, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_head)
	_mult = _label("×1.0", UiTheme.display(), UiTheme.T_TITLE, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_mult)
	resized.connect(_place)


func _label(s: String, f: Font, fs: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = align
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _place() -> void:
	if _panel == null:
		return
	_panel.size = Vector2(WIDTH, 0)
	_panel.reset_size()
	_panel.size.x = minf(WIDTH, size.x - 2.0 * UiTheme.GUTTER)
	_panel.position = Vector2((size.x - _panel.size.x) * 0.5, size.y * TOP)
	_panel.pivot_offset = _panel.size * 0.5


## Plays the plate for a scored point: {"tricks": [{name, x}], "mult", "points"}.
func show_result(r: Dictionary) -> void:
	if _tween:
		_tween.kill()
	_result = r
	for c in _tricks.get_children():
		_tricks.remove_child(c)
		c.queue_free()
	var mythic := false
	for t in r.get("tricks", []):
		var l := _label("%s  ×%s" % [t["name"], _x(float(t["x"]))], UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.INK)
		l.modulate.a = 0.0
		_tricks.add_child(l)
		mythic = mythic or t.get("id", "") == "masterpiece"
	var edge := UiTheme.RARITY[4] if mythic else UiTheme.GOLD
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.94), edge, 3, UiTheme.RADIUS, 20))
	_mult.text = "×1.0"
	_set_points("")
	visible = true
	modulate.a = 1.0
	_place.call_deferred()
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.92, 0.92)
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.12)
	_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var running := 1.0
	var lines := _tricks.get_children()
	for i in lines.size():
		running *= float(r["tricks"][i]["x"])
		var shown := running
		var l: Label = lines[i]
		_tween.tween_interval(STEP if i > 0 else 0.05)
		_tween.tween_callback(func() -> void:
			l.modulate.a = 1.0
			_mult.text = "×" + _x(shown)
			_mult.pivot_offset = _mult.size * 0.5
			_mult.scale = Vector2(1.25, 1.25))
		_tween.tween_property(_mult, "scale", Vector2.ONE, 0.12)
	_tween.tween_callback(func() -> void:
		_mult.text = "×" + _x(float(r["mult"]))
		_set_points("+%d" % int(r["points"])))
	_tween.tween_property(_panel, "modulate", Color(1.35, 1.3, 1.1, 1.0), 0.08)
	_tween.tween_property(_panel, "modulate", Color.WHITE, 0.15)
	_tween.tween_interval(0.55)
	_tween.tween_property(_panel, "position:y", size.y * TOP - 60.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func() -> void: visible = false)


## Jumps to the end state (tests, a skipped replay): every trick shown, the full numbers.
func finish_now() -> void:
	if _tween:
		_tween.kill()
	for l in _tricks.get_children():
		(l as Label).modulate.a = 1.0
	_panel.modulate = Color.WHITE
	_panel.scale = Vector2.ONE
	_mult.text = "×" + _x(float(_result.get("mult", 1.0)))
	_set_points("+%d" % int(_result.get("points", 0)))


func hide_now() -> void:
	if _tween:
		_tween.kill()
	visible = false


func _set_points(s: String) -> void:
	_points = s
	_head.text = "СТИЛЬ" if s == "" else "СТИЛЬ  " + s
	_head.add_theme_color_override("font_color", UiTheme.MUTED if s == "" else UiTheme.INK)


func trick_count() -> int:
	return _tricks.get_child_count()


func mult_text() -> String:
	return _mult.text


func points_text() -> String:
	return _points


static func _x(v: float) -> String:
	return "%.1f" % v
