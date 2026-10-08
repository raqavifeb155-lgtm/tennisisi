class_name SmashButton
extends Button
## «Разбить ракетку»: the round button beside the stamina ring, offered for 2.5 s after a
## point lost to the player's own error (docs/superpowers/specs/2026-10-09-racket-smash.md 2).
## A dark disc with a gold rim like ⚙/❚❚, a racket with a crack, the words under it, and
## a gold ring round the disc that runs out with the window (it blinks in the last 0.7 s).
## It follows the timing ring's anchor (the stamina circle over the hero), to its right.

const SIZE := 96.0
const GAP := 118.0              # from the ring's centre to the button's centre
const EDGE := 16.0
const CAPTION := "Разбить ракетку"
const BLINK_FROM := 0.28        # the last 28% of the window (0.7 s of 2.5)

var left := 1.0:                # 1 .. 0 of the window still open
	set(v):
		left = clampf(v, 0.0, 1.0)
		queue_redraw()
var ring: TimingRing            # whose anchor (the ring's centre on screen) it stands beside
var anchor := Vector2.ZERO      # used when there is no ring (tests)
var top_inset := 0.0
var bottom_inset := 0.0
var _t := 0.0


func _init() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	visible = false
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.7), 3, int(SIZE * 0.5), 0)
	var down := UiTheme.box(UiTheme.SURFACE_HI, Color(UiTheme.GOLD, 1.0), 3, int(SIZE * 0.5), 0)
	for k in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(k, sb)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tooltip_text = CAPTION


## Where the button sits for a ring at `ring`: right of it, kept inside the screen and out of
## the top band (the ❚❚ button) and the bottom.
static func place_for(ring: Vector2, vp: Vector2, top: float, bottom: float) -> Vector2:
	var c := ring + Vector2(GAP, 0.0)
	c.x = clampf(c.x, EDGE + 100.0, vp.x - EDGE - 100.0)
	c.y = clampf(c.y, top + 150.0, vp.y - bottom - 330.0)
	return c - Vector2(SIZE, SIZE) * 0.5


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if ring:
		anchor = ring.anchor
	position = place_for(anchor, get_viewport_rect().size, top_inset, bottom_inset)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var g := UiTheme.GOLD
	var blink := left < BLINK_FROM and fmod(_t, 0.24) < 0.12
	# The window's ring, running out clockwise from the top.
	draw_arc(c, SIZE * 0.5 + 8.0, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 6.0, true)
	if left > 0.0:
		draw_arc(c, SIZE * 0.5 + 8.0, -PI * 0.5, -PI * 0.5 + TAU * left, maxi(6, int(48 * left)), UiTheme.LOSE if blink else g, 6.0, true)
	# The racket, tilted, with a crack across its head.
	draw_set_transform(c + Vector2(-2.0, -4.0), deg_to_rad(38.0), Vector2.ONE)
	var rim := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		rim.append(Vector2(cos(a) * 14.0, sin(a) * 19.0 - 10.0))
	draw_polyline(rim, g, 4.0, true)
	draw_line(Vector2(-9, -10), Vector2(9, -10), Color(g, 0.45), 1.5, true)
	draw_line(Vector2(0, -26), Vector2(0, 5), Color(g, 0.45), 1.5, true)
	draw_line(Vector2(0, 9), Vector2(0, 34), g, 6.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var crack := PackedVector2Array([c + Vector2(4, -30), c + Vector2(-1, -22), c + Vector2(7, -15), c + Vector2(0, -7), c + Vector2(8, 1)])
	draw_polyline(crack, UiTheme.LOSE, 3.0, true)
	# The words under the disc.
	var f := UiTheme.text_bold()
	var w := f.get_string_size(CAPTION, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var at := Vector2(c.x - w * 0.5, SIZE + 34.0)
	draw_string_outline(f, at, CAPTION, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 7, Color(0, 0, 0, 0.85))
	draw_string(f, at, CAPTION, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiTheme.INK)
