class_name BagChip
extends PanelContainer
## The bag's chip in the top bar (v0.2 L-3): a satchel and how many things the player has
## (worn and carried; in the shop: kept in the locker). A thing that is taken, bought or
## put on flies into it (ItemFx.fly_item), the chip hops and shows «+1» for a moment. It is
## only a sign, not a button: it sits on the screens where taking happens, and a tap that
## left the screen would lose the choice.

var count := 0
var _label: Label
var _icon: Control
var _badge: Badge
var _bump := 0


## The satchel, drawn (no textures).
class Icon extends Control:
	func _draw() -> void:
		var c := UiTheme.INK
		draw_arc(Vector2(20, 14), 9.0, PI, TAU, 14, c, 3.0, true)
		draw_style_box(UiTheme.box(Color(UiTheme.GOLD, 0.2), c, 3, 9, 0), Rect2(3, 13, 34, 25))
		draw_line(Vector2(5, 22), Vector2(35, 22), Color(c, 0.7), 2.0)
		draw_circle(Vector2(20, 24), 3.5, UiTheme.GOLD)


## «+1», under the chip's corner; it ignores the container's layout (top level).
class Badge extends Control:
	var text := "+1"
	var _t := 0.0

	func _init() -> void:
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(54, 34)
		size = Vector2(54, 34)
		visible = false

	func _draw() -> void:
		draw_style_box(UiTheme.box(UiTheme.GOLD, Color(UiTheme.BASE, 0.9), 2, 17, 0), Rect2(Vector2.ZERO, size))
		var f := UiTheme.text_bold()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2((size.x - w) * 0.5, 25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiTheme.GOLD_INK)


func _init() -> void:
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), UiTheme.LINE, 2, 40, 12)
	sb.content_margin_left = 14
	sb.content_margin_right = 20
	add_theme_stylebox_override("panel", sb)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_icon = Icon.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_icon)
	_label = Label.new()
	_label.add_theme_font_override("font", UiTheme.display())
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", UiTheme.INK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_label)
	_badge = Badge.new()
	add_child(_badge)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	set_count(0)


func set_count(n: int) -> void:
	count = n
	_label.text = str(n)


## Where a thing lands (the middle of the satchel), in screen coordinates.
func icon_center() -> Vector2:
	return _icon.get_global_rect().get_center()


## A thing has flown in: the count is the new one, the chip hops, «+1» shows and fades.
func land(new_count: int, gain := 1) -> void:
	set_count(new_count)
	_bump += gain
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "scale", Vector2(1.22, 1.22), 0.07).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_badge.text = "+%d" % _bump
	_badge.visible = true
	_badge.modulate.a = 1.0
	_badge.global_position = get_global_rect().position + Vector2(size.x - 60.0, size.y - 12.0)
	_badge.queue_redraw()
	var bt := _badge.create_tween()
	bt.set_ignore_time_scale(true)
	bt.tween_property(_badge, "global_position:y", _badge.global_position.y + 10.0, 0.25).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	bt.tween_interval(0.9)
	bt.tween_property(_badge, "modulate:a", 0.0, 0.3)
	bt.tween_callback(func() -> void:
		_badge.visible = false
		_bump = 0)


## The badge's text while it shows (for the tests), "" when it is gone.
func badge_text() -> String:
	return _badge.text if _badge.visible else ""
