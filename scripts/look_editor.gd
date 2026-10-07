class_name LookEditor
extends VBoxContainer
## The character editor: a turning 3D preview of the player on top, the categories
## (hair, colours, beard, headwear, kit) as tabs, the options of the chosen one as a
## grid (colour swatches or named styles), and "random" / "done" at the bottom.
## Drag the preview to turn the player. Works on its own copy of the look; `done`
## hands the result back (TournamentUI -> Main saves it).

signal done(look: Dictionary)
signal sfx(sound: String, volume_db: float, pitch: float)

const GOLD := Color(1.0, 0.85, 0.25)
const DIM := Color(1, 1, 1, 0.6)
## [key, tab title, kind]: kind "style" lists names, "color" shows swatches.
const TABS := [
	["hair", "Причёска", "style"], ["hair_color", "Волосы", "color"], ["skin", "Кожа", "color"],
	["beard", "Борода", "style"], ["head", "Убор", "style"], ["accent", "Цвет убора", "color"],
	["shirt", "Футболка", "color"], ["shorts", "Шорты", "color"],
]
## Close-up for the head things, the whole body for the kit: [camera, look-at point].
const CAM_FACE := [Vector3(-0.35, 1.72, -1.75), Vector3(0, 1.55, 0)]
const CAM_BODY := [Vector3(-0.6, 1.3, -3.3), Vector3(0, 1.0, 0)]

var look: Dictionary = Looks.DEFAULT.duplicate()
var ui: TournamentUI          # for the shared button styles
var _tab := 0
var _athlete: Athlete
var _cam: Camera3D
var _cam_t := 0.0             # 0 face .. 1 body, eased toward the tab's framing
var _spin_pause := 0.0
var _tabs_box: GridContainer
var _options: GridContainer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	look = Looks.sanitize(look)
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_preview()
	_tabs_box = GridContainer.new()
	_tabs_box.columns = 4
	_tabs_box.add_theme_constant_override("h_separation", 8)
	_tabs_box.add_theme_constant_override("v_separation", 8)
	add_child(_tabs_box)
	_options = GridContainer.new()
	_options.custom_minimum_size = Vector2(0, 340)  # the tallest tab: the screen keeps still
	_options.add_theme_constant_override("h_separation", 10)
	_options.add_theme_constant_override("v_separation", 10)
	add_child(_options)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	row.add_child(_wide_button("СЛУЧАЙНО", false, _randomize))
	row.add_child(_wide_button("ГОТОВО", true, func() -> void:
		sfx.emit("hit", -16.0, 1.6)
		done.emit(look.duplicate())))
	_refresh()


func _process(delta: float) -> void:
	if _athlete == null:
		return
	_spin_pause -= delta
	if _spin_pause <= 0.0:
		_athlete.rotation.y += delta * 0.6
	var want := 1.0 if TABS[_tab][0] in ["shirt", "shorts"] else 0.0
	_cam_t = lerpf(_cam_t, want, 1.0 - exp(-6.0 * delta))
	var from: Vector3 = (CAM_FACE[0] as Vector3).lerp(CAM_BODY[0], _cam_t)
	var at: Vector3 = (CAM_FACE[1] as Vector3).lerp(CAM_BODY[1], _cam_t)
	_cam.look_at_from_position(from, at, Vector3.UP)


# --- Preview ----------------------------------------------------------------------

func _build_preview() -> void:
	# A dark card behind the player, so the court behind the menu doesn't show through.
	var frame := PanelContainer.new()
	var sb := ui._style(Color(0.07, 0.09, 0.13, 0.92))
	sb.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(0, 330)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_on_preview_input)
	frame.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.82, 0.84, 0.9)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 150, 0)
	key.light_energy = 1.1
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -20, 0)
	rim.light_energy = 0.45
	rim.light_color = Color(0.75, 0.85, 1.0)
	vp.add_child(rim)
	_athlete = Athlete.new()
	vp.add_child(_athlete)
	_athlete.setup(-1.0, look, Rect2(-5, -5, 10, 10))
	_athlete.rotation.y = 0.5
	_cam = Camera3D.new()
	_cam.fov = 34.0
	vp.add_child(_cam)
	_cam.look_at_from_position(CAM_FACE[0], CAM_FACE[1], Vector3.UP)


func _on_preview_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_athlete.rotation.y += ev.relative.x * 0.012
		_spin_pause = 2.5


# --- Tabs and options -----------------------------------------------------------

func _refresh() -> void:
	for c in _tabs_box.get_children():
		_tabs_box.remove_child(c)
		c.queue_free()
	for i in TABS.size():
		var b := _chip(TABS[i][1], i == _tab, 20, Vector2(0, 58))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func() -> void:
			sfx.emit("hit", -18.0, 1.8)
			_tab = idx
			_refresh())
		_tabs_box.add_child(b)
	for c in _options.get_children():
		_options.remove_child(c)
		c.queue_free()
	var key: String = TABS[_tab][0]
	var n: int = Looks.SIZES[key]
	var current := int(look[key])
	if TABS[_tab][2] == "color":
		_options.columns = 8 if n > 12 else (6 if n > 10 else 5)
		var palette: Array = _palette(key)
		for i in n:
			_options.add_child(_swatch(palette[i], i == current, key, i))
	else:
		_options.columns = 3
		var names: Array = _names(key)
		for i in n:
			var b := _chip(names[i], i == current, 22, Vector2(0, 60))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var idx := i
			b.pressed.connect(func() -> void: _pick(key, idx))
			_options.add_child(b)


func _pick(key: String, i: int) -> void:
	sfx.emit("hit", -16.0, 1.6)
	look[key] = i
	_athlete.set_look(look)
	_refresh()


func _randomize() -> void:
	sfx.emit("hit", -16.0, 1.3)
	look = Looks.random(_rng)
	_athlete.set_look(look)
	_refresh()


func _palette(key: String) -> Array:
	match key:
		"skin":
			return Looks.SKIN
		"hair_color":
			return Looks.HAIR_COLORS
	return Looks.KIT


func _names(key: String) -> Array:
	match key:
		"beard":
			return Looks.BEARD_NAMES
		"head":
			return Looks.HEAD_NAMES
	return Looks.HAIR_NAMES


# --- Widgets ----------------------------------------------------------------------

func _chip(text: String, selected: bool, font: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.clip_text = true
	b.add_theme_font_size_override("font_size", font)
	var bg := Color(0.12, 0.15, 0.2, 0.95)
	var border := GOLD if selected else Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", ui._style(bg, border))
	b.add_theme_stylebox_override("hover", ui._style(bg.lightened(0.08), border))
	b.add_theme_stylebox_override("pressed", ui._style(bg.darkened(0.2), border))
	var fg := GOLD if selected else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fg)
	return b


func _swatch(c: Color, selected: bool, key: String, i: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c.lightened(0.08) if state == "hover" else (c.darkened(0.15) if state == "pressed" else c)
		sb.set_corner_radius_all(32)
		sb.set_border_width_all(5 if selected else 2)
		sb.border_color = GOLD if selected else Color(1, 1, 1, 0.25)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(func() -> void: _pick(key, i))
	return b


func _wide_button(text: String, primary: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 90)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	var bg := GOLD if primary else Color(0.12, 0.15, 0.2, 0.95)
	var fg := Color(0.1, 0.08, 0.02) if primary else Color.WHITE
	b.add_theme_stylebox_override("normal", ui._style(bg))
	b.add_theme_stylebox_override("hover", ui._style(bg.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", ui._style(bg.darkened(0.2)))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.pressed.connect(action)
	return b
