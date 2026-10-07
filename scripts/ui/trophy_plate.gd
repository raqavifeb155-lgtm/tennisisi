class_name TrophyPlate
extends PanelContainer
## The trophy mini-game's plate where the score bug sits: "ТРОФЕЙ" and a ball for every
## serve, the spent ones dimmed (UI_FLOW_TZ 4.6). Replaces "ТРОФЕЙ · мячей: 5" in plain
## text across the top.

const BALL := Color(0.86, 0.95, 0.3)

var left := 5
var total := 5
var _balls: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.92), Color(1, 1, 1, 0.1), 1, 10, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	var l := Label.new()
	l.text = "ТРОФЕЙ"
	l.add_theme_font_override("font", UiTheme.display())
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	_balls = Control.new()
	_balls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balls.draw.connect(_draw_balls)
	h.add_child(_balls)
	set_balls(5, 5)


func set_balls(n_left: int, n_total: int) -> void:
	left = n_left
	total = n_total
	_balls.custom_minimum_size = Vector2(total * 30.0, 36.0)
	_balls.queue_redraw()


func _draw_balls() -> void:
	for i in total:
		var c := Vector2(15.0 + i * 30.0, 18.0)
		if i < left:
			_balls.draw_circle(c, 11.0, BALL)
		else:
			_balls.draw_arc(c, 10.0, 0.0, TAU, 24, Color(1, 1, 1, 0.3), 2.0, true)
