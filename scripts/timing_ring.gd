class_name TimingRing
extends Control
## Top Spin-style timing cue: a ring shrinks onto a fixed circle hanging above the player.
## Swipe when the ring meets the circle. The ring runs on game time, so it slows down
## together with the slow-motion window.

const INNER := 30.0          # target circle radius (px)
const PX_PER_SEC := 105.0    # ring radius per game second remaining
const GOLD := Color(1.0, 0.85, 0.25)
const GOOD := Color(0.55, 1.0, 0.6)
const LATE := Color(1.0, 0.55, 0.25)

var _active := false
var _pos := Vector2.ZERO
var _t_left := 0.0
var _perfect := 0.035
var _good := 0.09


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_ring(pos: Vector2, t_left: float, perfect_window: float, good_window: float) -> void:
	_active = true
	_pos = pos
	_t_left = t_left
	_perfect = perfect_window
	_good = good_window
	queue_redraw()


func hide_ring() -> void:
	if _active:
		_active = false
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var a := absf(_t_left)
	var col := Color(1, 1, 1, 0.95)
	if a <= _perfect:
		col = GOLD
	elif a <= _good:
		col = GOOD
	elif _t_left < 0.0:
		col = LATE
	# Target circle + centre dot
	draw_circle(_pos, INNER, Color(0, 0, 0, 0.18))
	draw_arc(_pos, INNER, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 4.0, true)
	draw_circle(_pos, 5.0, Color(1, 1, 1, 0.9))
	# Shrinking ring
	var r := INNER + _t_left * PX_PER_SEC
	if r > 6.0:
		draw_arc(_pos, r, 0.0, TAU, 64, col, 6.0, true)
	if a <= _perfect:
		draw_arc(_pos, INNER + 9.0, 0.0, TAU, 48, Color(GOLD, 0.5), 3.0, true)
