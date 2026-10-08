class_name UiTheme
## The menus' one visual system: colors, fonts, sizes and the Theme every menu Control
## inherits, so screens don't repeat add_theme_*_override. See PRODUCT.md.
##
## One brand color (gold on a near-black blue-gray base). The only other saturated
## colors are the rarities and win/lose: a purple or red edge always means loot.
## Sizes are in the 720-wide logical canvas (project stretch "expand"): on a 440 pt
## iPhone 1 pt ~ 1.64 px here, so a 48 pt touch target is ~80 px.

const BASE := Color(0.047, 0.055, 0.075)        # behind everything (the veil's tint)
const SURFACE := Color(0.094, 0.11, 0.14)       # cards, rows, tiles
const SURFACE_HI := Color(0.13, 0.15, 0.19)     # pressed / raised surface
const LINE := Color(1, 1, 1, 0.09)              # hairlines and quiet borders
const INK := Color(0.96, 0.965, 0.975)          # main text
const MUTED := Color(0.72, 0.75, 0.80)          # secondary text (>= 4.5:1 on SURFACE)
const GOLD := Color(1.0, 0.84, 0.26)            # the brand color: primary actions, current
const GOLD_INK := Color(0.11, 0.08, 0.01)       # text on gold
const WIN := Color(0.42, 0.95, 0.5)
const LOSE := Color(1.0, 0.42, 0.36)

## Five rarities: gray, blue, purple, orange (legendary), red (mythic).
const RARITY := [
	Color(0.70, 0.73, 0.78),
	Color(0.33, 0.6, 1.0),
	Color(0.7, 0.38, 1.0),
	Color(1.0, 0.55, 0.12),
	Color(1.0, 0.24, 0.24),
]
const RARITY_NAMES := ["Обычная", "Редкая", "Эпическая", "Легендарная", "Мифическая"]

## The layer map (UI_FLOW_TZ 5.5): CanvasLayer numbers live here and nowhere else. A modal
## window is the topmost thing and takes every tap (a full-screen STOP veil).
const LAYER_HUD := 1             # score, ring, joystick, the announcer: never modal
const LAYER_STYLE := 5           # the style plate and the replay (v0.2 A)
const LAYER_CLUB := 9            # the walkable club's HUD (v0.2 B), under the screens
const LAYER_SCREENS := 10        # TournamentUI: the Club list, bracket, result, rooms
const LAYER_SHEETS := 15         # confirmations over a screen
const LAYER_PAUSE := 20          # the pause and the settings sheet, the ⚙ / ❚❚ button
const LAYER_CONFIRM := 25        # "leave the match?" over the pause
const LAYER_HELP := 30           # "Как играть"
const LAYER_LOADING := 100       # the boot loader

const RADIUS := 22
const TAP := 84.0                # minimum height of anything tappable (~51 pt)
const GUTTER := 28               # screen side margin

# Type scale (px in the 720 canvas). Display face for titles and big numbers only.
const T_HERO := 76
const T_TITLE := 54
const T_HEAD := 34
const T_BODY := 27
const T_SMALL := 22

static var _theme: Theme
static var _display: Font
static var _text: Font
static var _text_bold: Font


## Russo One: sporty display face for titles and numbers (Cyrillic). Falls back to the
## engine font if the file is missing (tests that run before import).
static func display() -> Font:
	if _display == null:
		_display = _load("res://assets/fonts/RussoOne-Regular.ttf", 0)
	return _display


## Golos Text (variable), regular weight: everything people read.
static func text() -> Font:
	if _text == null:
		_text = _load("res://assets/fonts/GolosText.ttf", 450)
	return _text


## Golos Text at semibold: buttons, labels that must hold their own.
static func text_bold() -> Font:
	if _text_bold == null:
		_text_bold = _load("res://assets/fonts/GolosText.ttf", 640)
	return _text_bold


static func _load(path: String, weight: int) -> Font:
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var base: Font = load(path)
	if weight <= 0:
		return base
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


static func rarity_color(r: int) -> Color:
	return RARITY[clampi(r, 0, RARITY.size() - 1)]


## A flat rounded box: the one stylebox shape of the menus.
static func box(bg: Color, border := Color(0, 0, 0, 0), border_w := 0, radius := RADIUS, pad := 20) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if border.a > 0.0 and border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border
	sb.anti_aliasing = true
	return sb


## The Theme set on the menus' root: Labels and Buttons get the fonts and colors from
## here; primary/secondary buttons are type variations ("Primary", "Quiet").
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = text()
	t.default_font_size = T_BODY
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))

	# Secondary button: a dark surface, white text.
	t.set_font("font", "Button", text_bold())
	t.set_font_size("font_size", "Button", T_BODY + 2)
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.35))
	t.set_stylebox("normal", "Button", box(SURFACE, LINE, 2))
	t.set_stylebox("hover", "Button", box(SURFACE_HI, LINE, 2))
	t.set_stylebox("pressed", "Button", box(SURFACE.darkened(0.25), LINE, 2))
	t.set_stylebox("disabled", "Button", box(Color(SURFACE, 0.6), LINE, 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	# Primary: gold, dark text. One per screen, at the bottom.
	t.set_type_variation("Primary", "Button")
	t.set_font_size("font_size", "Primary", T_BODY + 4)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Primary", GOLD_INK)
	t.set_stylebox("normal", "Primary", box(GOLD))
	t.set_stylebox("hover", "Primary", box(GOLD.lightened(0.08)))
	t.set_stylebox("pressed", "Primary", box(GOLD.darkened(0.18)))

	# Quiet: text-only (give up, small secondary choices).
	t.set_type_variation("Quiet", "Button")
	t.set_font_size("font_size", "Quiet", T_SMALL + 2)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Quiet", MUTED)
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0)
	empty.set_content_margin_all(14)
	for k in ["normal", "hover", "pressed"]:
		t.set_stylebox(k, "Quiet", empty)

	# Scroll bars: thin and quiet.
	var grab := box(Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), 0, 4, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 3))
	_theme = t
	return t
