class_name ClubHud
extends CanvasLayer
## What the club puts on the screen (docs/club/CLUB_BRIEF.md 4): the gold chip, quick
## travel in the bottom left corner, the one button of the place the hero stands in, red
## counts over the places and the coach's speech bubble. Nothing else: the rest is the
## world. Settings stay on Hud's НАСТР button (top right). Styled by UiTheme.

signal chosen(action: String, arg: int)
signal travel(place_id: String)
signal settings
signal roulette_chip(chip: int)
signal roulette_bet(bet: String)
signal roulette_back
signal foreman_step(dir: int)       # -1 / +1: the card to the left / right
signal foreman_build
signal foreman_color(i: int)
signal upgrade(place_id: String)    # the small "↑ 340" by a place's button
signal skip                         # a tap during the build moment

const HUD_BUTTON_W := 132.0      # room kept free at the top right for НАСТР (as TournamentUI)
const TRAVEL := 92.0             # the quick-travel button (a circle)
const GEAR := 84.0               # the settings button (a circle, top right)

var root: Control
var buttons: Array[Control] = []    # what the touch layer must leave alone (TouchInput.blocked_controls)
var _chip_label: Label
var _bottom: HBoxContainer
var _place_box: VBoxContainer
var _primary: Button
var _second_row: HBoxContainer
var _travel_btn: Button
var gear: Button                    # settings: Hud's sheet (НАСТР is hidden while the club shows)
var _roulette: VBoxContainer         # the Totalizator's bets at the bar
var _roulette_result: Label
var _roulette_note: Label
var _roulette_chips: HBoxContainer
var _roulette_bets: Array[Button] = []
var _roulette_back: Button
var _foreman: VBoxContainer          # the foreman's card strip (one card, ‹ ›, build)
var _foreman_card_slot: HBoxContainer
var _foreman_colors: HBoxContainer
var _foreman_build: Button
var _upgrade: Button                 # "↑ 340" right of the place's button
var _skip_catcher: Control           # the whole screen during the build moment
var _travel_list: VBoxContainer
var _badges := {}                   # place id -> TournamentUI.Badge
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_t := 0.0
var _hint: PanelContainer
var _hint_shown := false
var _place_id := ""
var _place_tw: Tween
var _pulse: Tween
var _safe_top := 0.0
var _safe_bottom := 0.0


func _ready() -> void:
	layer = 9  # under the menus (TournamentUI 10) and the settings (20)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	add_child(root)
	_build_chip()
	_build_gear()
	_build_bottom()
	_build_bubble()
	_build_roulette()
	_build_foreman()
	_layout()
	visible = false


func set_safe_area(top: float, bottom: float) -> void:
	_safe_top = top
	_safe_bottom = bottom
	_layout()


func _layout() -> void:
	if _bottom == null:
		return
	_bottom.offset_left = UiTheme.GUTTER
	_bottom.offset_right = -UiTheme.GUTTER
	_bottom.offset_bottom = -26.0 - _safe_bottom
	_roulette.offset_left = UiTheme.GUTTER
	_roulette.offset_right = -UiTheme.GUTTER
	_roulette.offset_bottom = -26.0 - _safe_bottom
	_roulette_back.position = Vector2(UiTheme.GUTTER, 18.0 + _safe_top)
	_foreman.offset_left = UiTheme.GUTTER
	_foreman.offset_right = -UiTheme.GUTTER
	_foreman.offset_bottom = -26.0 - _safe_bottom
	var chip := _chip_label.get_parent().get_parent() as Control
	chip.offset_top = 14.0 + _safe_top + 8.0
	chip.offset_right = -HUD_BUTTON_W - 14.0
	gear.offset_top = 14.0 + _safe_top
	gear.offset_bottom = gear.offset_top + GEAR


# --- Gold ---------------------------------------------------------------------------

func _build_chip() -> void:
	var chip := PanelContainer.new()
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.55), 2, 40, 14)
	sb.content_margin_left = 18
	sb.content_margin_right = 22
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(chip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(h)
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(28, 28)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_box)
	var coin := TournamentUI.Coin.new()
	coin.position = Vector2(14, 14)
	icon_box.add_child(coin)
	_chip_label = Label.new()
	_chip_label.add_theme_font_override("font", UiTheme.display())
	_chip_label.add_theme_font_size_override("font_size", 30)
	_chip_label.add_theme_color_override("font_color", UiTheme.GOLD)
	h.add_child(_chip_label)


## Settings: a gear in a dark disc where НАСТР stands in the menus.
func _build_gear() -> void:
	gear = GearButton.new()
	gear.focus_mode = Control.FOCUS_NONE
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -14.0 - GEAR - 10.0
	gear.offset_right = -14.0 - 10.0
	gear.pressed.connect(func() -> void:
		_tap(gear)
		settings.emit())
	root.add_child(gear)
	buttons.append(gear)


func set_gold(v: int) -> void:
	_chip_label.text = str(v)


# --- The bottom: quick travel and the place's button ------------------------------------

func _build_bottom() -> void:
	_bottom = HBoxContainer.new()
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.alignment = BoxContainer.ALIGNMENT_BEGIN
	_bottom.add_theme_constant_override("separation", 14)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bottom)

	var travel_col := VBoxContainer.new()
	travel_col.alignment = BoxContainer.ALIGNMENT_END
	travel_col.add_theme_constant_override("separation", 12)
	travel_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(travel_col)
	_travel_list = VBoxContainer.new()
	_travel_list.add_theme_constant_override("separation", 10)
	_travel_list.visible = false
	travel_col.add_child(_travel_list)
	buttons.append(_travel_list)
	_travel_btn = TravelButton.new()
	_travel_btn.custom_minimum_size = Vector2(TRAVEL, TRAVEL)
	_travel_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_travel_btn.focus_mode = Control.FOCUS_NONE
	_travel_btn.pressed.connect(func() -> void: _toggle_travel(not _travel_list.visible))
	travel_col.add_child(_travel_btn)
	buttons.append(_travel_btn)

	_place_box = VBoxContainer.new()
	_place_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place_box.alignment = BoxContainer.ALIGNMENT_END
	_place_box.add_theme_constant_override("separation", 12)
	_place_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(_place_box)
	_second_row = HBoxContainer.new()
	_second_row.add_theme_constant_override("separation", 12)
	_place_box.add_child(_second_row)
	buttons.append(_second_row)
	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 12)
	main_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primary = Button.new()
	_primary.theme_type_variation = "Primary"
	_primary.custom_minimum_size = Vector2(0, TRAVEL)
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary.clip_text = true
	_primary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.pressed.connect(func() -> void:
		var a: String = _primary.get_meta("action", "")
		if a != "":
			_tap(_primary)
			chosen.emit(a, int(_primary.get_meta("arg", 0))))
	main_row.add_child(_primary)
	_place_box.add_child(main_row)
	buttons.append(_primary)
	_upgrade = Button.new()
	_upgrade.custom_minimum_size = Vector2(TRAVEL + 40.0, TRAVEL)
	_upgrade.focus_mode = Control.FOCUS_NONE
	_upgrade.add_theme_font_override("font", UiTheme.display())
	_upgrade.add_theme_font_size_override("font_size", 26)
	_upgrade.add_theme_color_override("font_color", UiTheme.GOLD)
	var usb := UiTheme.box(Color(UiTheme.SURFACE, 0.96), UiTheme.GOLD, 3, 46, 0)
	for k in ["normal", "hover", "pressed"]:
		_upgrade.add_theme_stylebox_override(k, usb)
	_upgrade.visible = false
	_upgrade.pressed.connect(func() -> void:
		_tap(_upgrade)
		upgrade.emit(_place_id))
	main_row.add_child(_upgrade)
	buttons.append(_upgrade)
	_place_box.modulate.a = 0.0


## The place under the hero: its main action and up to two small ones above it.
## `extra`: [[label, action], ...]. `upgrade_price` > 0: the "↑ price" button beside it.
func show_place(id: String, label: String, action: String, extra: Array = [], upgrade_price := 0) -> void:
	_primary.text = label
	_upgrade.visible = upgrade_price > 0
	_upgrade.text = "↑ %d" % upgrade_price
	_primary.set_meta("action", action)
	for c in _second_row.get_children():
		c.queue_free()
	for e in extra:
		var b := Button.new()
		b.text = e[0]
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", UiTheme.T_BODY - 2)
		var act: String = e[1]
		b.pressed.connect(func() -> void:
			_tap(b)
			chosen.emit(act, 0))
		_second_row.add_child(b)
	_second_row.visible = not extra.is_empty()
	if id == _place_id:
		return
	_place_id = id
	_slide(true)


## A quiet pulse on the place's main button (the first lesson is done: «Новая игра» is next).
func pulse_primary(on: bool) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_primary.self_modulate = Color.WHITE
	if not on:
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_primary, "self_modulate", Color(1.35, 1.3, 1.0), 0.55).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_primary, "self_modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)


func pulsing() -> bool:
	return _pulse != null and _pulse.is_valid() and _pulse.is_running()


func hide_place() -> void:
	if _place_id == "":
		return
	_place_id = ""
	_slide(false)


func current_place() -> String:
	return _place_id


## The button rises into place (0.2 s) or drops away; it can't be pressed while hidden.
func _slide(on: bool) -> void:
	if _place_tw:
		_place_tw.kill()
	_place_box.visible = true
	_primary.disabled = not on
	_place_tw = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_place_tw.tween_property(_place_box, "modulate:a", 1.0 if on else 0.0, 0.2)
	_place_tw.tween_property(_place_box, "position:y", 0.0 if on else 40.0, 0.2).from(40.0 if on else 0.0)
	if not on:
		_place_tw.chain().tween_callback(func() -> void: _place_box.visible = false)


func _tap(b: Control) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(0.96, 0.96), 0.06)
	tw.tween_property(b, "scale", Vector2.ONE, 0.1)


## The places quick travel offers (only the open ones), plus "how to play".
func set_places(places: Array) -> void:
	for c in _travel_list.get_children():
		c.queue_free()
	for p in places:
		var b := Button.new()
		b.text = p["name"]
		b.custom_minimum_size = Vector2(300, 84)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var id: String = p["id"]
		b.pressed.connect(func() -> void:
			_toggle_travel(false)
			travel.emit(id))
		_travel_list.add_child(b)
	var how := Button.new()
	how.text = "?  Как играть"
	how.custom_minimum_size = Vector2(300, 76)
	how.alignment = HORIZONTAL_ALIGNMENT_LEFT
	how.focus_mode = Control.FOCUS_NONE
	how.add_theme_color_override("font_color", UiTheme.GOLD)
	how.pressed.connect(func() -> void:
		_toggle_travel(false)
		chosen.emit("howto", 0))
	_travel_list.add_child(how)


func _toggle_travel(on: bool) -> void:
	_travel_list.visible = on
	(_travel_btn as TravelButton).open = on
	_travel_btn.queue_redraw()


func travel_open() -> bool:
	return _travel_list.visible


# --- The Totalizator at the bar ------------------------------------------------------

const BET_IDS := ["blue", "red", "net"]
const BET_NAMES := ["Синее ×2", "Красное ×2", "Сетка ×35"]
const BET_COLORS := [Color(0.27, 0.47, 0.86), Color(0.86, 0.32, 0.3), Color(0.2, 0.55, 0.35)]


func _build_roulette() -> void:
	_roulette = VBoxContainer.new()
	_roulette.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_roulette.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_roulette.add_theme_constant_override("separation", 12)
	_roulette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roulette.visible = false
	root.add_child(_roulette)
	_roulette_result = Label.new()
	_roulette_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roulette_result.add_theme_font_override("font", UiTheme.display())
	_roulette_result.add_theme_font_size_override("font_size", UiTheme.T_HEAD)
	_roulette_result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_roulette_result.add_theme_constant_override("outline_size", 10)
	_roulette.add_child(_roulette_result)
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.35), 2, UiTheme.RADIUS, 18)
	card.add_theme_stylebox_override("panel", sb)
	_roulette.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var title := Label.new()
	title.text = "Мяч в поле: синее и красное ×2, сетка ×35"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", UiTheme.text_bold())
	title.add_theme_font_size_override("font_size", UiTheme.T_SMALL)
	title.add_theme_color_override("font_color", UiTheme.MUTED)
	v.add_child(title)
	_roulette_note = Label.new()
	_roulette_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roulette_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roulette_note.add_theme_font_size_override("font_size", UiTheme.T_SMALL)
	_roulette_note.add_theme_color_override("font_color", UiTheme.MUTED)
	v.add_child(_roulette_note)
	_roulette_chips = HBoxContainer.new()
	_roulette_chips.add_theme_constant_override("separation", 10)
	v.add_child(_roulette_chips)
	var bets := HBoxContainer.new()
	bets.add_theme_constant_override("separation", 10)
	v.add_child(bets)
	for i in BET_IDS.size():
		var b := Button.new()
		b.text = BET_NAMES[i]
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", UiTheme.T_BODY - 4)
		b.add_theme_color_override("font_color", (BET_COLORS[i] as Color).lightened(0.4))
		var bet: String = BET_IDS[i]
		b.pressed.connect(func() -> void:
			_tap(b)
			roulette_bet.emit(bet))
		bets.add_child(b)
		_roulette_bets.append(b)
	buttons.append(_roulette)
	# "← Назад" where every screen has it: top left.
	_roulette_back = Button.new()
	_roulette_back.text = "←  Назад"
	_roulette_back.custom_minimum_size = Vector2(196, 76)
	_roulette_back.add_theme_font_size_override("font_size", UiTheme.T_BODY)
	_roulette_back.focus_mode = Control.FOCUS_NONE
	_roulette_back.position = Vector2(UiTheme.GUTTER, 18.0)
	_roulette_back.visible = false
	_roulette_back.pressed.connect(func() -> void: roulette_back.emit())
	root.add_child(_roulette_back)
	buttons.append(_roulette_back)


## The desk under the wheel. `allowed`: chips the player may put down now.
func show_roulette(all_chips: Array, allowed: Array, chip: int, result := "", won := false, note := "") -> void:
	_toggle_travel(false)
	_bottom.visible = false
	_roulette.visible = true
	_roulette_back.visible = true
	_roulette_result.text = result
	_roulette_result.add_theme_color_override("font_color", UiTheme.WIN if won else (UiTheme.LOSE if result != "" else UiTheme.INK))
	_roulette_note.text = note
	_roulette_note.visible = note != ""
	for c in _roulette_chips.get_children():
		_roulette_chips.remove_child(c)
		c.queue_free()
	for c in all_chips:
		var b := Button.new()
		b.text = str(c)
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.theme_type_variation = "Primary" if c == chip and allowed.has(c) else ""
		b.disabled = not allowed.has(c)
		var v: int = c
		b.pressed.connect(func() -> void: roulette_chip.emit(v))
		_roulette_chips.add_child(b)
	for b in _roulette_bets:
		b.disabled = allowed.is_empty()


## While the ball rolls the desk waits (a tap on the wheel shows the end).
func roulette_spinning(on: bool) -> void:
	for b in _roulette_bets:
		b.disabled = on
	for b in _roulette_chips.get_children():
		(b as Button).disabled = on or (b as Button).disabled
	if on:
		_roulette_result.text = ""


func hide_roulette() -> void:
	_roulette.visible = false
	_roulette_back.visible = false
	_bottom.visible = true


func roulette_visible() -> bool:
	return _roulette.visible


# --- The foreman: the constructions' cards -------------------------------------------

func _build_foreman() -> void:
	_foreman = VBoxContainer.new()
	_foreman.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_foreman.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_foreman.add_theme_constant_override("separation", 14)
	_foreman.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreman.visible = false
	root.add_child(_foreman)
	_foreman_card_slot = HBoxContainer.new()
	_foreman_card_slot.add_theme_constant_override("separation", 10)
	_foreman_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreman.add_child(_foreman_card_slot)
	_foreman_colors = HBoxContainer.new()
	_foreman_colors.alignment = BoxContainer.ALIGNMENT_CENTER
	_foreman_colors.add_theme_constant_override("separation", 22)
	_foreman.add_child(_foreman_colors)
	_foreman_build = Button.new()
	_foreman_build.custom_minimum_size = Vector2(0, TRAVEL)
	_foreman_build.focus_mode = Control.FOCUS_NONE
	_foreman_build.pressed.connect(func() -> void:
		_tap(_foreman_build)
		foreman_build.emit())
	_foreman.add_child(_foreman_build)
	buttons.append(_foreman)
	_skip_catcher = Control.new()
	_skip_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skip_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_catcher.visible = false
	_skip_catcher.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			skip.emit())
	root.add_child(_skip_catcher)
	buttons.append(_skip_catcher)


## One construction's card. card: {tag, title, desc, locked}; build: {"text", "can"}
## ("" text = at the top: no button); colors: 0 = none, else how many colour dots
## (the court's level 3), `color` the one picked.
func show_foreman(card: Dictionary, build: Dictionary, has_prev: bool, has_next: bool, colors := 0, color := 0) -> void:
	_toggle_travel(false)
	_bottom.visible = false
	_foreman.visible = true
	_roulette_back.visible = true
	for c in _foreman_card_slot.get_children():
		_foreman_card_slot.remove_child(c)
		c.queue_free()
	_foreman_card_slot.add_child(_arrow("‹", -1, has_prev))
	var gc := GameCard.new()
	gc.tag = card.get("tag", "")
	gc.title = card.get("title", "")
	gc.desc = card.get("desc", "")
	gc.accent = UiTheme.GOLD if card.get("max", false) else Color(UiTheme.GOLD, 0.35)
	gc.selected = card.get("max", false)
	gc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if card.get("locked", false):
		gc.modulate = Color(0.7, 0.7, 0.75)
	_foreman_card_slot.add_child(gc)
	_foreman_card_slot.add_child(_arrow("›", 1, has_next))
	for c in _foreman_colors.get_children():
		_foreman_colors.remove_child(c)
		c.queue_free()
	_foreman_colors.visible = colors > 0
	for i in colors:
		var dot := ColorDot.new()
		dot.color = ClubMaterial.CLUB_COLORS[i]
		dot.picked = i == color
		dot.custom_minimum_size = Vector2(76, 76)
		dot.focus_mode = Control.FOCUS_NONE
		var v := i
		dot.pressed.connect(func() -> void: foreman_color.emit(v))
		_foreman_colors.add_child(dot)
	var text: String = build.get("text", "")
	_foreman_build.visible = text != ""
	_foreman_build.text = text
	_foreman_build.theme_type_variation = "Primary" if build.get("can", false) else ""
	_foreman_build.disabled = false


func _arrow(t: String, dir: int, on: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(64, 170)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 44)
	b.disabled = not on
	b.modulate.a = 1.0 if on else 0.3
	b.pressed.connect(func() -> void: foreman_step.emit(dir))
	return b


func hide_foreman() -> void:
	_foreman.visible = false
	_roulette_back.visible = false
	_bottom.visible = true
	_skip_catcher.visible = false


func foreman_visible() -> bool:
	return _foreman.visible


## During the build moment: the panel steps aside and a tap anywhere skips.
func set_building(on: bool) -> void:
	_skip_catcher.visible = on
	_foreman.modulate.a = 0.0 if on else 1.0
	_foreman_build.disabled = on


## "Нужно ещё 120": the gold chip shakes.
func shake_gold() -> void:
	var chip := _chip_label.get_parent().get_parent() as Control
	var x := chip.position.x
	var tw := create_tween()
	for k in 4:
		tw.tween_property(chip, "position:x", x + (10.0 if k % 2 == 0 else -10.0), 0.05)
	tw.tween_property(chip, "position:x", x, 0.05)


## Coins fly from the gold chip to a point on the screen (the construction).
func fly_coins(to: Vector2) -> void:
	var chip := _chip_label.get_parent().get_parent() as Control
	var from := chip.global_position + chip.size * 0.5
	for i in 8:
		var c := TournamentUI.Coin.new()
		c.position = from
		root.add_child(c)
		var tw := c.create_tween()
		tw.tween_interval(i * 0.04)
		var mid := from.lerp(to, 0.5) + Vector2(randf_range(-80, 80), -120)
		tw.tween_method(func(k: float) -> void:
			c.position = from.lerp(mid, k).lerp(mid.lerp(to, k), k), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)


## A colour to pick for the club (the court's level 3).
class ColorDot extends Button:
	var color := Color.WHITE
	var picked := false

	func _ready() -> void:
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(k, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		if picked:
			draw_circle(c, 36.0, UiTheme.GOLD)
		draw_circle(c, 30.0, color)


# --- Badges and the coach's words ---------------------------------------------------------

## Red counts over places. `screen`: place id -> screen position (absent = not on screen).
func place_badges(counts: Dictionary, screen: Dictionary) -> void:
	for id in counts:
		var b: TournamentUI.Badge = _badges.get(id)
		if b == null:
			b = TournamentUI.Badge.new()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(b)
			_badges[id] = b
		b.count = counts[id]
		b.visible = counts[id] > 0 and screen.has(id)
		if b.visible:
			b.position = screen[id]
			b.queue_redraw()
	for id in _badges:
		if not counts.has(id):
			(_badges[id] as Control).visible = false


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.96), Color(UiTheme.GOLD, 0.5), 2, 26, 18)
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eats a tap: the first tap walks
	_bubble.visible = false
	_bubble.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_bubble.visible = false)
	root.add_child(_bubble)
	# Not in `buttons`: a tap through the bubble walks the hero (and hides it).
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_override("font", UiTheme.text_bold())
	_bubble_label.add_theme_font_size_override("font_size", UiTheme.T_BODY)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(380, 0)
	_bubble.add_child(_bubble_label)


## The coach says a line (up to ~60 characters) over his head for a few seconds.
func say(text: String, seconds := 3.5) -> void:
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.reset_size()
	_bubble_t = seconds


## A one-off hint at the top (how to walk): a quiet plate, gone after a few seconds.
func show_hint(text: String, seconds := 5.0) -> void:
	if _hint == null:
		_hint = PanelContainer.new()
		_hint.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.92), Color(UiTheme.GOLD, 0.4), 2, 24, 16))
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", UiTheme.text_bold())
		l.add_theme_font_size_override("font_size", UiTheme.T_SMALL + 2)
		_hint.add_child(l)
		root.add_child(_hint)
	(_hint.get_child(0) as Label).text = text
	var vp := root.get_viewport_rect().size
	_hint.custom_minimum_size = Vector2(vp.x - UiTheme.GUTTER * 2.0, 0)
	_hint.position = Vector2(UiTheme.GUTTER, 120.0 + _safe_top)
	_hint.visible = true
	_hint.modulate.a = 1.0
	_hint_shown = true
	var tw := _hint.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _hint.visible = false)


func hint_shown() -> bool:
	return _hint_shown


func is_saying() -> bool:
	return _bubble.visible


## Where the coach's head is on screen (the bubble hangs above it, kept on screen).
func bubble_at(head: Vector2, on_screen: bool) -> void:
	if not _bubble.visible:
		return
	if not on_screen:
		_bubble.visible = false  # the coach walked out of the picture: his line goes with him
		return
	var vp := root.get_viewport_rect().size
	var s := _bubble.size
	var x := clampf(head.x - s.x * 0.5, UiTheme.GUTTER, vp.x - UiTheme.GUTTER - s.x)
	var y := clampf(head.y - s.y - 24.0, 120.0 + _safe_top, vp.y * 0.6)
	_bubble.position = Vector2(x, y)


func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false


## The settings button: a dark disc with a gold gear.
class GearButton extends Button:
	func _ready() -> void:
		var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.55), 2, 42, 0)
		for k in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(k, sb)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var g := UiTheme.GOLD
		var teeth := 8
		var pts := PackedVector2Array()
		for i in teeth * 4:
			var a := TAU * i / (teeth * 4.0)
			var r := 23.0 if (i % 4) in [0, 1] else 17.0
			pts.append(c + Vector2.from_angle(a + TAU / (teeth * 8.0)) * r)
		draw_colored_polygon(pts, g)
		draw_circle(c, 7.5, UiTheme.SURFACE)


## The quick-travel button: a dark disc with a gold map pin (a cross when open).
class TravelButton extends Button:
	var open := false

	func _ready() -> void:
		var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.55), 2, 46, 0)
		for k in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(k, sb)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var g := UiTheme.GOLD
		if open:
			draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), g, 5.0, true)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), g, 5.0, true)
			return
		var head := c + Vector2(0, -6)
		draw_circle(head, 14.0, g)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-12, 7), head + Vector2(12, 7), head + Vector2(0, 26)]), g)
		draw_circle(head, 6.0, UiTheme.SURFACE)
