class_name IconButton
extends Button
## A round 84 px button with a drawn icon (UI_FLOW_TZ P1-4): ⚙ settings outside a match,
## ❚❚ pause in a match, ? help. A dark disc with a gold icon, like the club's gear.

enum { GEAR, PAUSE, HELP }

const SIZE := 84.0

var kind := GEAR:
	set(v):
		kind = v
		tooltip_text = ["Настройки", "Пауза", "Как играть"][v]
		queue_redraw()


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SIZE, SIZE)
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.55), 2, int(SIZE * 0.5), 0)
	var down := UiTheme.box(UiTheme.SURFACE_HI, Color(UiTheme.GOLD, 0.8), 2, int(SIZE * 0.5), 0)
	for k in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(k, sb)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _draw() -> void:
	var c := size * 0.5
	var g := UiTheme.GOLD
	match kind:
		PAUSE:
			draw_rect(Rect2(c + Vector2(-13, -17), Vector2(9, 34)), g)
			draw_rect(Rect2(c + Vector2(4, -17), Vector2(9, 34)), g)
		HELP:
			var f := UiTheme.display()
			var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
			draw_string(f, c + Vector2(-w * 0.5, 16), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, g)
		_:
			var teeth := 8
			var pts := PackedVector2Array()
			for i in teeth * 4:
				var a := TAU * i / (teeth * 4.0)
				var r := 23.0 if (i % 4) in [0, 1] else 17.0
				pts.append(c + Vector2.from_angle(a + TAU / (teeth * 8.0)) * r)
			draw_colored_polygon(pts, g)
			draw_circle(c, 7.5, UiTheme.SURFACE)
