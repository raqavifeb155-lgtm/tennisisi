class_name SmashPrompt
extends Control
## The three swipes of the racket smash, drawn as three discs with an arrow (up, down, down),
## in the upper third of the screen over the far court: the ones done are gold, the next one
## pulses and its arrow nudges the way the finger goes, the rest are dim. A swipe that did
## not count flashes the current disc red. Takes no touches.

const DISC := 96.0
const STEP := 128.0
const PATTERN := [-1, 1, 1]      # -1 up, +1 down
const Y_AT := 0.27               # of the screen height (below the call strip, above the hero)

var step := 0                    # swipes done
var flash := 0.0                 # > 0: the last swipe did not count
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_prompt(done: int, red: float) -> void:
	visible = true
	step = done
	flash = red


## The centre of disc i, in screen pixels.
func centre(i: int) -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x * 0.5 + (i - 1) * STEP, vp.y * Y_AT)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	for i in 3:
		var c := centre(i)
		var dir: int = PATTERN[i]
		var done := i < step
		var now := i == step
		var pulse := 1.0 + (0.06 * sin(_t * 9.0) if now else 0.0)
		var r := DISC * 0.5 * pulse
		var fill := Color(UiTheme.GOLD, 0.95) if done else Color(UiTheme.SURFACE, 0.9 if now else 0.55)
		var rim := Color(UiTheme.GOLD, 1.0 if now else 0.4)
		var ink := UiTheme.GOLD_INK if done else (UiTheme.GOLD if now else Color(1, 1, 1, 0.35))
		if now and flash > 0.0:
			rim = UiTheme.LOSE
			ink = UiTheme.LOSE
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 40, rim, 4.0, true)
		var nudge := (sin(_t * 8.0) * 6.0 if now else 0.0) * dir
		var p := c + Vector2(0.0, nudge)
		var s := 18.0
		# An arrow: a shaft and a head, drawn (no font has the glyphs). The tip points the way the finger goes.
		var tip := p + Vector2(0, s * dir)
		draw_line(p - Vector2(0, s * dir), tip, ink, 7.0, true)
		draw_line(tip, tip + Vector2(-s * 0.8, -s * 0.9 * dir), ink, 7.0, true)
		draw_line(tip, tip + Vector2(s * 0.8, -s * 0.9 * dir), ink, 7.0, true)
