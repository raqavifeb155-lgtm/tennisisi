class_name RevealFx
extends RefCounted
## The win when a card opens (v0.2 L-4). Common and rare: only the band of light the card
## itself sweeps. From epic up: a flash in the rarity's colour, a short vibration, a few
## sparks (at most MAX_SPARKS), the «reward» sound pitched by rarity; legendary adds turning
## rays behind the card; a mythic darkens the screen for a moment, lights the card and
## announces «МИФИЧЕСКАЯ». Everything is a handful of nodes that remove themselves.

const MAX_SPARKS := 40
const SPARKS := [0, 0, 14, 26, 40]
const FLASH := [0.0, 0.0, 0.32, 0.45, 0.65]
const PITCH := [1.0, 1.0, 1.0, 1.12, 0.8]
const DB := [0.0, 0.0, -9.0, -6.0, -2.0]
const HAPTIC := ["", "", "medium", "heavy", "perfect"]


## The effect for a card that has just opened with this rarity (-1 none). `lit`: what the
## mythic's darkness leaves alone (the card's own mates).
static func play(ui: TournamentUI, card: Control, rarity: int, lit: Array = []) -> void:
	if card is GameCard:
		(card as GameCard).sweep()
	if rarity < Gear.EPIC:
		return
	var r := clampi(rarity, Gear.EPIC, Gear.MYTHIC)
	var col := UiTheme.rarity_color(r)
	_flash(ui, col, FLASH[r])
	var centre := card.get_global_rect().get_center()
	var sp := Sparks.new()
	sp.setup(centre, col, SPARKS[r])
	ui.root.add_child(sp)
	if card is GameCard:
		(card as GameCard).pop(col)
	if Tuning.vibration:
		TelegramApp.haptic(HAPTIC[r])
	ui.sfx_request.emit("reward", DB[r], PITCH[r])
	if r >= Gear.LEGENDARY:
		_rays(ui, card, col)
	if r == Gear.MYTHIC:
		_mythic(ui, card, col, lit)


static func _flash(ui: TournamentUI, col: Color, strength: float) -> void:
	var f := ColorRect.new()
	f.color = Color(col.lerp(Color.WHITE, 0.45), strength)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.root.add_child(f)
	var tw := f.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(f, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(f.queue_free)


## Rays turn behind the opened card (TournamentUI frees them with the screen).
static func _rays(ui: TournamentUI, card: Control, col: Color) -> void:
	if ui._rays:
		ui._rays.queue_free()
	var rays := TournamentUI.Rays.new()
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.color = col
	ui.root.add_child(rays)
	ui.root.move_child(rays, 1)  # behind the cards, over the dark veil
	rays.centre = card.get_global_rect().get_center()
	ui._rays = rays


## The screen goes dark for a moment, the other cards sink, the card burns, the word.
static func _mythic(ui: TournamentUI, card: Control, col: Color, lit: Array) -> void:
	var veil: ColorRect = ui._veil
	var base := veil.color
	var tw := veil.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(veil, "color", Color(0.0, 0.0, 0.0, 1.0), 0.18)
	tw.tween_interval(1.1)
	tw.tween_property(veil, "color", base, 0.7)
	for c in ui._box.get_children():
		if c != card and c is Control and not lit.has(c):
			var dim := (c as Control).create_tween()
			dim.set_ignore_time_scale(true)
			dim.tween_property(c, "modulate:a", 0.3, 0.18)
			dim.tween_interval(1.1)
			dim.tween_property(c, "modulate:a", 1.0, 0.6)
	var word := Label.new()
	word.text = "МИФИЧЕСКАЯ"
	word.add_theme_font_override("font", UiTheme.display())
	word.add_theme_font_size_override("font_size", UiTheme.T_TITLE)
	word.add_theme_color_override("font_color", col.lightened(0.15))
	word.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0, 0.9))
	word.add_theme_constant_override("outline_size", 10)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.set_anchors_preset(Control.PRESET_TOP_WIDE)
	word.offset_top = ui.root.size.y * 0.64  # the empty ground under the cards, not over the title
	word.offset_bottom = word.offset_top + 80.0
	word.pivot_offset = Vector2(360.0, 40.0)
	ui.root.add_child(word)
	var wt := word.create_tween()
	wt.set_ignore_time_scale(true)
	wt.tween_property(word, "scale", Vector2.ONE, 0.3).from(Vector2(1.7, 1.7)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	wt.parallel().tween_property(word, "modulate:a", 1.0, 0.15).from(0.0)
	wt.tween_interval(1.0)
	wt.tween_property(word, "modulate:a", 0.0, 0.4)
	wt.tween_callback(word.queue_free)


## A burst of small diamonds: one node, at most MAX_SPARKS of them, gone after a second.
class Sparks extends Control:
	var _p: Array = []   # [pos, vel, life, size, spin, bright]
	var _col := Color.WHITE
	var _age := 0.0

	func setup(centre: Vector2, col: Color, n: int) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_col = col
		for i in mini(n, RevealFx.MAX_SPARKS):
			var a := randf() * TAU
			var v := randf_range(220.0, 620.0)
			_p.append([centre, Vector2.from_angle(a) * v + Vector2(0, -120.0), randf_range(0.6, 1.1), randf_range(5.0, 11.0), randf() * TAU, randf() < 0.4])

	func _process(delta: float) -> void:
		_age += delta
		for q in _p:
			q[1] = (q[1] as Vector2) * (1.0 - 2.2 * delta) + Vector2(0, 900.0 * delta)
			q[0] = (q[0] as Vector2) + (q[1] as Vector2) * delta
		if _age > 1.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for q in _p:
			var life: float = q[2]
			var k := 1.0 - _age / life
			if k <= 0.0:
				continue
			var p: Vector2 = q[0]
			var s: float = q[3] * (0.5 + 0.5 * k)
			var c: Color = Color.WHITE if q[5] else _col.lightened(0.25)
			c.a = clampf(k * 1.4, 0.0, 1.0)
			var a: float = float(q[4]) + _age * 4.0
			var d := Vector2.from_angle(a)
			var n := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([p + d * s * 1.6, p + n * s * 0.8, p - d * s * 1.6, p - n * s * 0.8]), c)
