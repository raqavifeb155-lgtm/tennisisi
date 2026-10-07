class_name ClubMaterial
## The club's one look (docs/club/CLUB_BRIEF.md 8): the players' soft toon - wrapped
## light, a small toon highlight, a light rim - with colours from one 32x1 palette, and
## a dark outline (the back faces of a slightly grown copy) on big things.
##
## Materials are shared per colour: MeshMerge folds every static box of one material into
## one mesh, so a club built from palette colours costs a few draw calls, not one a box.
## Outlines are a second pass per mesh: only on things bigger than ~0.5 m, and only from
## the Medium preset up (set_outlines, called by ClubWorld.set_high_quality).

## The palette (assets/club/palette.png is the same row, written by tools/club_palette.gd).
const PALETTE := [
	Color("2a54a3"), Color("3d806a"), Color("f5f5f5"), Color("8f8a80"), Color("5e5a54"),   # court: hard, out, lines, concrete, cracks
	Color("c08a55"), Color("6b4a32"),                                                       # wood: light, dark
	Color("25272b"), Color("b9bec4"), Color("8c4a2a"),                                      # metal: dark, light, rust
	Color("a0523d"), Color("e3d6c3"), Color("8fb8c9"),                                      # walls: brick, plaster, glass
	Color("4d7a33"), Color("668f3b"), Color("436b38"),                                      # leaves (scenery.gd LEAVES)
	Color("ffd642"), Color("ffe27a"), Color("2a54a3"), Color("1e3a73"),                     # gold (UiTheme.GOLD), neon, club colour + its dark
	Color("f2f0ea"), Color("d9473b"), Color("1e2a44"),                                      # fabric: white, red, navy
	Color("141219"), Color("9e968a"), Color("bdb3a3"), Color("ede3cc"), Color("29392f"),    # outline, gravel, paving, board, chalkboard
	Color("6b7f94"), Color("3fb8af"), Color("f08a3c"), Color("101114"),                     # steel blue, soda teal, orange, black
]
enum {
	HARD, OUT, LINES, CONCRETE, CRACKS, WOOD, WOOD_DARK, METAL_DARK, METAL, RUST,
	BRICK, PLASTER, GLASS, LEAF_1, LEAF_2, LEAF_3, GOLD, NEON, CLUB, CLUB_DARK,
	WHITE, RED, NAVY, OUTLINE, GRAVEL, PAVING, BOARD, CHALKBOARD, STEEL, TEAL, ORANGE, BLACK,
}
## The club's colour (main court level 3): blue, emerald, burgundy, graphite.
const CLUB_COLORS := [Color("2a54a3"), Color("1f8a6a"), Color("8a2433"), Color("3a3f47")]
const CLUB_NAMES := ["Синий", "Изумрудный", "Бордовый", "Графит"]
const OUTLINE_BIG := 0.02       # metres
const PALETTE_PATH := "res://assets/club/palette.png"

static var _cache := {}         # "rrggbbaa|big" -> StandardMaterial3D
static var _outline: StandardMaterial3D
static var _outlines_on := true
static var _palette_tex: Texture2D


## The shared material of a colour. big: gets the outline (when outlines are on).
static func get_mat(c: Color, big := true) -> StandardMaterial3D:
	var key := "%s|%d" % [c.to_html(), int(big)]
	var m: StandardMaterial3D = _cache.get(key)
	if m == null:
		m = StandardMaterial3D.new()
		m.albedo_color = c
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		m.specular_mode = BaseMaterial3D.SPECULAR_TOON
		m.roughness = 0.7
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.5
		if big and _outlines_on:
			m.next_pass = _outline_mat()
		m.set_meta("club_big", big)
		_cache[key] = m
	return m


## A palette colour by its index (ClubMaterial.BRICK...).
static func pal(i: int, big := true) -> StandardMaterial3D:
	return get_mat(PALETTE[i], big)


## Something that glows by itself (neon, lamps at night): no light, no outline.
static func glow(c: Color, energy := 1.6) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [c.to_html(), energy]
	var m: StandardMaterial3D = _cache.get(key)
	if m == null:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(c.r * energy, c.g * energy, c.b * energy)
		_cache[key] = m
	return m


## Outlines on (Medium and up) or off (Low): every shared big material at once.
static func set_outlines(on: bool) -> void:
	_outlines_on = on
	for k in _cache:
		var m: StandardMaterial3D = _cache[k]
		if m.get_meta("club_big", false):
			m.next_pass = _outline_mat() if on else null


static func outlines_on() -> bool:
	return _outlines_on


static func _outline_mat() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.albedo_color = PALETTE[OUTLINE]
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = OUTLINE_BIG
	return _outline


## The palette as a 32x1 texture (for imported models whose UVs point into it).
static func palette_texture() -> Texture2D:
	if _palette_tex == null:
		if ResourceLoader.exists(PALETTE_PATH):
			_palette_tex = load(PALETTE_PATH)
		else:
			_palette_tex = ImageTexture.create_from_image(palette_image())
	return _palette_tex


static func palette_image() -> Image:
	var img := Image.create(PALETTE.size(), 1, false, Image.FORMAT_RGB8)
	for i in PALETTE.size():
		img.set_pixel(i, 0, PALETTE[i])
	return img


## The same look with the colour from the mesh's vertices (one mesh, many colours: the
## roulette wheel, crowds). No outline.
static func tinted() -> StandardMaterial3D:
	var m: StandardMaterial3D = _cache.get("tinted")
	if m == null:
		m = get_mat(Color.WHITE, false).duplicate()
		m.vertex_color_use_as_albedo = true
		_cache["tinted"] = m
	return m


## A ghost of something not built yet (H2: the next level on the foreman's card):
## see-through gold, no outline.
static func ghost() -> StandardMaterial3D:
	var m: StandardMaterial3D = _cache.get("ghost")
	if m == null:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(UiTheme.GOLD, 0.35)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		_cache["ghost"] = m
	return m
