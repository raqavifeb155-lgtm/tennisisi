class_name HawkEye
extends Control
## Line-call replay for close balls: a zoomed top-down view of the ball mark against
## the line, with the verdict and the distance. Touching the line counts as in.

const PANEL := Vector2(300, 190)
const LINE_W := 0.05          # line width (m)
const SHOW_SECONDS := 2.6

var top_inset := 0.0          # Telegram's buttons and the notch in full screen (HUD sets it)
var top_px := -1.0            # the slot the HUD's call column reserved for it (-1: none)

var _margin := 0.0            # metres; > 0 = in
var _axis := 0                # 0 = deciding line runs along the court length (vertical here)
var _mark := Vector3.ZERO     # half-length, half-width (m), |cos| of the angle to the normal
var _until_ms := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_call(margin: float, axis: int, mark := Vector3.ZERO) -> void:
	_margin = margin
	_axis = axis
	_mark = mark if mark.x > 0.0 else Vector3(BallPhysics.RADIUS, BallPhysics.RADIUS, 1.0)
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
	# In the call column, right under the point's call (HudAnnouncer.reserve): on the sky
	# and the city, clear of the score, of the far court and of the thumbs.
	var origin := Vector2((vp.x - PANEL.x) * 0.5, top_px) if top_px >= 0.0 else Vector2(vp.x - PANEL.x - 14.0, top_inset + 128.0)
	var rect := Rect2(origin, PANEL)
	var font := get_theme_default_font()
	var is_in := _margin >= 0.0

	draw_rect(rect, Color(0.05, 0.08, 0.12, 0.92 * alpha))
	var view := Rect2(origin + Vector2(10, 34), Vector2(PANEL.x - 20, PANEL.y - 74))
	draw_rect(view, Color(0.2, 0.38, 0.66, alpha))
	var mid := view.get_center()
	# Zoom so that the line and the whole ball mark always fit in the view, at true
	# proportions (the mark as the ball left it, line 5 cm). The margin is measured from
	# the mark's edge nearest the line: the same mark the court shows.
	var a := _mark.x
	var b := _mark.y
	var c := clampf(_mark.z, 0.0, 1.0)
	var s := sqrt(1.0 - c * c)
	var reach := Vector2(a * c, b * s).length()  # how far the mark reaches toward the line
	var ball_off_m := reach - _margin  # mark centre past the line's outer edge (m)
	var half := (view.size.x if _axis == 0 else view.size.y) * 0.5 - 8.0
	var need := maxf(absf(ball_off_m) + maxf(a, b), LINE_W + maxf(a, b)) + 0.01
	var scale := clampf(half / need, 120.0, 900.0)
	var lw := LINE_W * scale
	var off := ball_off_m * scale
	# The line's outer edge sits at the centre; the court is on the left / top. The mark's
	# long axis leans from the line's normal by the angle the ball came in at.
	if _axis == 0:
		draw_rect(Rect2(Vector2(mid.x, view.position.y), Vector2(view.end.x - mid.x, view.size.y)), Color(0.24, 0.5, 0.4, alpha))
		draw_rect(Rect2(Vector2(mid.x - lw, view.position.y), Vector2(lw, view.size.y)), Color(0.97, 0.97, 0.97, alpha))
		_draw_mark(Vector2(mid.x + off, mid.y), Vector2(c, s), a * scale, b * scale, alpha)
	else:
		draw_rect(Rect2(view.position, Vector2(view.size.x, mid.y - view.position.y)), Color(0.24, 0.5, 0.4, alpha))
		draw_rect(Rect2(Vector2(view.position.x, mid.y), Vector2(view.size.x, lw)), Color(0.97, 0.97, 0.97, alpha))
		_draw_mark(Vector2(mid.x, mid.y - off), Vector2(s, -c), a * scale, b * scale, alpha)
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


## The ball's mark: an oval with half-length `ra` along `dir` and half-width `rb`.
func _draw_mark(c: Vector2, dir: Vector2, ra: float, rb: float, alpha: float) -> void:
	var across := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		pts.append(c + dir * (cos(t) * ra) + across * (sin(t) * rb))
	draw_colored_polygon(pts, Color(0.86, 0.95, 0.2, 0.85 * alpha))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.3, 0.35, 0.05, alpha), 2.0, true)
