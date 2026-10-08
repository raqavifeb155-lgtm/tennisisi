class_name ItemThumb
extends RefCounted
## The picture of a thing (v0.2 L-2, docs/superpowers/specs/2026-10-08-v02-L-loot-cards.md):
## its real mesh from AthleteGear (the racket, a pair of sneakers, a wristband on a forearm)
## rendered once in a little SubViewport, three quarters, transparent background, and kept
## as a texture. Cards, the bag, the locker and the shop show it, and it is what flies
## into the bag.
##
## The cache is in memory, by the look: a catalog thing by its id, a generated one by slot
## and rarity ("level" does not change the look, so it is not in the key: a small «ур. N»
## is drawn over the picture instead). The budget: one frame per thing (the model is put in
## front of the camera, drawn and read back in the same frame) and at most POOL (3) things
## in one frame; the viewports exist only while there is something to draw.
##
## ThumbView is the Control that shows it: a glow of the rarity behind (calm for commons,
## alive from epic up), the picture, the level. Empty `item` + slot = the stock thing.

const SIZE := 192            # pixels of the rendered picture
const POOL := 3              # things drawn in one frame, at most

static var _cache := {}      # key -> ImageTexture
static var _queue: Array = []  # [key, item, slot]
static var _queued := {}
static var _renderer: Node
## For the tests and the profiler: things drawn in all, the most in one frame, pictures
## the renderer could not read back (a headless run draws nothing).
static var renders := 0
static var max_batch := 0
static var failed := 0


## "gen|racket|2" for a generated thing, "id|sun" for a catalog one, "stock|shoes" for none.
static func key(item: Dictionary, slot := "") -> String:
	if item.is_empty():
		return "stock|%s" % slot
	var s := AthleteGear.slot_of(item)
	var id := String(item.get("id", ""))
	if id != "" and Items.find(id).has("skin"):
		return "id|%s" % id
	return "gen|%s|%d" % [s, AthleteGear.rarity_of(item)]


## The picture if it is ready (else null, and it is asked for).
static func texture(item: Dictionary, slot := "") -> Texture2D:
	var k := key(item, slot)
	if _cache.has(k):
		return _cache[k]
	if not _queued.has(k):
		_queued[k] = true
		_queue.append([k, item.duplicate(), slot])
		_wake()
	return null


static func ready_for(item: Dictionary, slot := "") -> bool:
	return _cache.has(key(item, slot))


static func pending() -> int:
	return _queue.size()


## A forgotten cache (tests, a changed look: the forearm wears the player's skin).
static func clear() -> void:
	_cache.clear()
	_queue.clear()
	_queued.clear()
	renders = 0
	max_batch = 0
	failed = 0


## The view for a card: a square of `px`.
static func view(item: Dictionary, slot := "", px := 132.0) -> ThumbView:
	var v := ThumbView.new()
	v.item = item
	v.slot = slot
	v.custom_minimum_size = Vector2(px, px)
	v.size = Vector2(px, px)
	return v


static func _wake() -> void:
	if _renderer != null and is_instance_valid(_renderer):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_renderer = ThumbRenderer.new()
	_renderer.process_mode = Node.PROCESS_MODE_ALWAYS  # the pause does not stop the pictures
	tree.root.add_child.call_deferred(_renderer)


## What the shown picture is made of: slot -> model, in a pivot, turned three quarters.
static func stage(item: Dictionary, slot: String) -> Node3D:
	var s := AthleteGear.slot_of(item) if not item.is_empty() else (slot if slot in AthleteGear.SLOTS else "racket")
	var pivot := Node3D.new()
	match s:
		"shoes":
			var skin := AthleteGear.skin_of(item, "shoes")
			if skin.is_empty():
				skin = AthleteGear.GENERIC["shoes"][0]
			var r := AthleteGear.rarity_of(item)
			var glows := r >= Gear.EPIC
			var g: Dictionary = AthleteGear.GLOW[maxi(r, 0)]
			var sole := Color(String(skin.get("sole", "#d8d8d8"))).srgb_to_linear()
			var mat := AthleteGear.gear_material(true, int(g["fx"]) if glows else 0, AthleteGear.GLOW_COLORS[maxi(r, 0)], float(g["frame"]) if glows else 0.0, sole)
			for k in 2:  # a pair: one nearer, one behind and a bit higher on the view
				var mi := MeshInstance3D.new()
				mi.mesh = AthleteGear.shoe_mesh(skin, true)
				mi.material_override = mat
				mi.rotation = Vector3(0, deg_to_rad(8 - 16 * k), deg_to_rad(-90 + (6 if k == 0 else -2)))
				mi.position = Vector3(-0.01 + 0.03 * k, 0.0, 0.075 - 0.15 * k)
				pivot.add_child(mi)
			pivot.rotation = Vector3(deg_to_rad(28), deg_to_rad(-24), 0)
		"band":
			var skin2 := AthleteGear.skin_of(item, "band")
			if skin2.is_empty():
				skin2 = AthleteGear.GENERIC["band"][0]
			var look: Dictionary = SaveData.look if not SaveData.look.is_empty() else Looks.DEFAULT
			var arm := Looks.skin(look)
			var mi2 := MeshInstance3D.new()
			mi2.mesh = AthleteGear.band_mesh(skin2, true, arm)
			var r2 := AthleteGear.rarity_of(item)
			if r2 >= Gear.EPIC:
				var g2: Dictionary = AthleteGear.GLOW[r2]
				mi2.material_override = AthleteGear.gear_material(true, int(g2["fx"]), AthleteGear.GLOW_COLORS[r2], float(g2["frame"]))
			else:
				mi2.material_override = _body_material()
			mi2.position = Vector3(0, -0.03, 0)  # the whole forearm shows, the band a bit nearer the middle
			pivot.add_child(mi2)
			pivot.rotation = Vector3(deg_to_rad(8), deg_to_rad(-30), deg_to_rad(-52))
		_:
			var m := AthleteGear.racket_model(item)
			m.position = Vector3(0, -0.34, 0)  # the middle of the racket is the pivot
			pivot.add_child(m)
			pivot.rotation = Vector3(deg_to_rad(6), deg_to_rad(-36), deg_to_rad(-30))
	return pivot


static var _body_mat: StandardMaterial3D


## The toon body's material for vertex-coloured parts (a wristband below epic).
static func _body_material() -> StandardMaterial3D:
	if _body_mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.55
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		m.specular_mode = BaseMaterial3D.SPECULAR_TOON
		m.rim_enabled = true
		m.rim = 0.55
		m.rim_tint = 0.4
		m.next_pass = outline()
		_body_mat = m
	return _body_mat


## The toon outline of the body, made here when no player has been built yet.
static func outline() -> StandardMaterial3D:
	if Athlete._toon_outline == null:
		var o := StandardMaterial3D.new()
		o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		o.albedo_color = Color(0.13, 0.1, 0.18)
		o.cull_mode = BaseMaterial3D.CULL_FRONT
		o.grow = true
		o.grow_amount = 0.007
		Athlete._toon_outline = o
	return Athlete._toon_outline


## How far the camera stands for a slot (the field of view is fixed at 28 degrees).
static func camera_distance(slot: String) -> float:
	match slot:
		"shoes":
			return 0.82
		"band":
			return 0.74
	return 1.42


## Draws the things asked for, up to POOL a frame, one frame each.
class ThumbRenderer extends Node:
	var _vps: Array[SubViewport] = []
	var _busy := false
	var _idle := 0.0

	func _process(delta: float) -> void:
		if _busy:
			return
		if ItemThumb._queue.is_empty():
			_idle += delta
			if _idle > 3.0 and not _vps.is_empty():
				_free_pool()  # nothing to draw for a while: the viewports go
			return
		_idle = 0.0
		_busy = true
		_batch()

	func _batch() -> void:
		var jobs: Array = []
		while jobs.size() < ItemThumb.POOL and not ItemThumb._queue.is_empty():
			jobs.append(ItemThumb._queue.pop_front())
		ItemThumb.outline()
		_ensure_pool()
		var staged: Array = []
		for i in jobs.size():
			var vp := _vps[i]
			var item: Dictionary = jobs[i][1]
			var slot: String = jobs[i][2]
			var pivot := ItemThumb.stage(item, slot)
			vp.add_child(pivot)
			var cam: Camera3D = vp.get_node("Cam")
			var s := AthleteGear.slot_of(item) if not item.is_empty() else slot
			cam.position = Vector3(0, 0, ItemThumb.camera_distance(s))
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			staged.append(pivot)
		await RenderingServer.frame_post_draw
		var drawn := 0
		for i in jobs.size():
			var vp := _vps[i]
			var img: Image = vp.get_texture().get_image() if is_instance_valid(vp) else null
			var k: String = jobs[i][0]
			ItemThumb._queued.erase(k)
			if img != null and not img.is_empty() and _has_pixels(img):
				ItemThumb._cache[k] = ImageTexture.create_from_image(img)
				drawn += 1
			else:
				ItemThumb.failed += 1
			(staged[i] as Node).queue_free()
		ItemThumb.renders += drawn
		ItemThumb.max_batch = maxi(ItemThumb.max_batch, jobs.size())
		_busy = false

	## A headless run (the dummy renderer) hands back an empty image: nothing is cached.
	static func _has_pixels(img: Image) -> bool:
		var step := 16
		for y in range(0, img.get_height(), step):
			for x in range(0, img.get_width(), step):
				if img.get_pixel(x, y).a > 0.05:
					return true
		return false

	func _ensure_pool() -> void:
		if not _vps.is_empty():
			return
		for i in ItemThumb.POOL:
			var vp := SubViewport.new()
			vp.size = Vector2i(ItemThumb.SIZE, ItemThumb.SIZE)
			vp.own_world_3d = true
			vp.transparent_bg = true
			vp.msaa_3d = Viewport.MSAA_4X
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			var env := WorldEnvironment.new()
			var e := Environment.new()
			e.background_mode = Environment.BG_CLEAR_COLOR
			e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			e.ambient_light_color = Color(0.8, 0.82, 0.9)
			e.ambient_light_energy = 0.6
			e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.environment = e
			vp.add_child(env)
			var sun := DirectionalLight3D.new()
			sun.rotation = Vector3(-0.75, 0.55, 0.0)
			sun.light_energy = 1.1
			vp.add_child(sun)
			var cam := Camera3D.new()
			cam.name = "Cam"
			cam.fov = 28.0
			cam.current = true
			vp.add_child(cam)
			add_child(vp)
			_vps.append(vp)

	func _free_pool() -> void:
		for vp in _vps:
			vp.queue_free()
		_vps.clear()

	func _exit_tree() -> void:
		ItemThumb._renderer = null


## Shows a thing: its rarity's glow behind the picture, the picture floating a little from
## epic up, the level. A picture still being drawn shows the glow alone.
class ThumbView extends Control:
	var item := {}
	var slot := ""
	var dim := false            # an empty slot: the stock thing, quiet
	var _tex: Texture2D
	var _t := 0.0
	var _phase := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_phase = randf() * TAU

	func _ready() -> void:
		_look()

	func _look() -> void:
		_tex = ItemThumb.texture(item, slot)
		set_process(_tex == null or _rarity() >= Gear.EPIC)

	func texture() -> Texture2D:
		return _tex

	func _rarity() -> int:
		return AthleteGear.rarity_of(item)

	func _process(delta: float) -> void:
		_t += delta
		if _tex == null:
			_look()
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := _rarity()
		var col := UiTheme.rarity_color(maxi(r, 0)) if r >= 0 else UiTheme.MUTED
		var pulse := 0.5 + 0.5 * sin(_t * 2.4 + _phase)
		var rad := size.x * 0.5
		# The glow: layers of a disc, stronger and livelier with the rarity.
		var strength: float = [0.05, 0.09, 0.15, 0.2, 0.26][clampi(r, 0, 4)] if r >= 0 else 0.03
		if r >= Gear.EPIC:
			strength *= 0.8 + 0.4 * pulse
		for i in 5:
			var k := 1.0 - i * 0.17
			draw_circle(c, rad * k, Color(col, strength * (0.35 + 0.2 * i) * 0.5))
		if _tex != null:
			var bob := sin(_t * 1.8 + _phase) * 3.0 if r >= Gear.EPIC else 0.0
			var tint := Color(1, 1, 1, 0.45 if dim else 1.0)
			draw_texture_rect(_tex, Rect2(Vector2(0, bob), size), false, tint)
		var lv := Items.level(item)
		if lv > 1:
			var f := UiTheme.text_bold()
			var s := "ур. %d" % lv
			var fs := 20
			var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pill := Rect2(size.x - w - 20, size.y - 30, w + 16, 28)
			draw_style_box(UiTheme.box(Color(UiTheme.BASE, 0.85), Color(col, 0.8), 2, 14, 0), pill)
			draw_string(f, Vector2(pill.position.x + 8, pill.position.y + 21), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.INK)
