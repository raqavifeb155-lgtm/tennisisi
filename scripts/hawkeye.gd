class_name HawkEye
extends Control
## Line-call replay for close balls: a zoomed top-down view of the ball mark against
## the line, with the verdict and the distance. Touching the line counts as in.

const PANEL := Vector2(300, 190)
const LINE_W := 0.05          # line width (m)
const SHOW_SECONDS := 1.8

var _margin := 0.0            # metres; > 0 = in
var _axis := 0                # 0 = deciding line runs along the court length (vertical here)
var _until_ms := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_call(margin: float, axis: int) -> void:
	_margin = margin
	_axis = axis
	_until_ms = Time.get_ticks_msec() + int(SHOW_SECONDS * 1000.0)
	queue_redraw()


func _process(_delta: float) -> void:
	if _until_ms > 0:
		queue_redraw()
		if Time.get_ticks_msec() > _until_ms:
			_until_ms = 0


func _draw() -> void:
	if _until_ms == 0:
		return
	var left := Time.get_ticks_msec()
	var alpha := clampf((_until_ms - left) / 300.0, 0.0, 1.0)
	var vp := get_viewport_rect().size
	# Bottom of the screen, below the player: never over the opponent or the far court.
	var origin := Vector2((vp.x - PANEL.x) * 0.5, vp.y - PANEL.y - 40.0)
	var rect := Rect2(origin, PANEL)
	var font := get_theme_default_font()
	var is_in := _margin >= 0.0

	draw_rect(rect, Color(0.05, 0.08, 0.12, 0.92 * alpha))
	var view := Rect2(origin + Vector2(10, 34), Vector2(PANEL.x - 20, PANEL.y - 74))
	draw_rect(view, Color(0.2, 0.38, 0.66, alpha))
	var mid := view.get_center()
	# Zoom so that the line and the whole ball mark always fit in the view, at true
	# proportions (ball 6.6 cm, line 5 cm).
	var r_m := BallPhysics.RADIUS
	var ball_off_m := r_m - _margin  # ball centre past the line's outer edge (m)
	var half := (view.size.x if _axis == 0 else view.size.y) * 0.5 - 8.0
	var need := maxf(absf(ball_off_m) + r_m, LINE_W + r_m) + 0.01
	var scale := clampf(half / need, 120.0, 900.0)
	var r := r_m * scale
	var lw := LINE_W * scale
	var off := ball_off_m * scale
	# The line's outer edge sits at the centre; the court is on the left / top.
	if _axis == 0:
		draw_rect(Rect2(Vector2(mid.x, view.position.y), Vector2(view.end.x - mid.x, view.size.y)), Color(0.24, 0.5, 0.4, alpha))
		draw_rect(Rect2(Vector2(mid.x - lw, view.position.y), Vector2(lw, view.size.y)), Color(0.97, 0.97, 0.97, alpha))
		_draw_mark(Vector2(mid.x + off, mid.y), r, alpha)
	else:
		draw_rect(Rect2(view.position, Vector2(view.size.x, mid.y - view.position.y)), Color(0.24, 0.5, 0.4, alpha))
		draw_rect(Rect2(Vector2(view.position.x, mid.y), Vector2(view.size.x, lw)), Color(0.97, 0.97, 0.97, alpha))
		_draw_mark(Vector2(mid.x, mid.y - off), r, alpha)
	# Scale bar: 5 cm.
	var bar := 0.05 * scale
	var bp := Vector2(view.end.x - bar - 8.0, view.end.y - 8.0)
	draw_line(bp, bp + Vector2(bar, 0), Color(1, 1, 1, 0.9 * alpha), 3.0)
	draw_string(font, bp + Vector2(0, -6), "5 см", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9 * alpha))

	draw_string(font, origin + Vector2(12, 24), "VAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8 * alpha))
	var verdict := "IN" if is_in else "OUT"
	var mm := absf(_margin) * 1000.0
	var amount := ("%.0f мм" % mm) if mm < 10.0 else ("%.1f см" % (mm / 10.0))
	var detail := ("касание " + amount) if is_in else ("аут " + amount)
	var col := Color(0.45, 1.0, 0.5, alpha) if is_in else Color(1.0, 0.4, 0.35, alpha)
	draw_string(font, Vector2(origin.x + 12, rect.end.y - 12), verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	draw_string(font, Vector2(origin.x + 90, rect.end.y - 16), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, alpha))


func _draw_mark(c: Vector2, r: float, alpha: float) -> void:
	# The ball's footprint, slightly stretched along the flight like a real mark.
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 1.12))
	draw_colored_polygon(pts, Color(0.86, 0.95, 0.2, 0.85 * alpha))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.3, 0.35, 0.05, alpha), 2.0, true)
