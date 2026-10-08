extends SceneTree
## Gear on the player, as the phone sees it (v0.2 F, spec 2026-10-08-v02-gear-skins):
##   godot --path . --rendering-driver opengl3 -s tools/gear_shots.gd [-- --size=1480] [--draws]
## One 720 x 1564 shot per rarity (stock, common .. mythic): a practice match in New York
## through the match camera with both players in that rarity's kit, and close-ups of the
## kit along the bottom (racket face on, the body, the shoes and the wristband). Plus
## gear_rackets.png: every racket in the catalog and by rarity, face on.
## --draws: draw calls of the match on Low and High, nothing worn vs. both players in
## mythics (the budget: at most +6 for the match, docs/PERFORMANCE.md).
## PNGs go to the user data folder (path printed).

const KITS := [
	["0_stock", []],
	["1_common", [{"slot": "racket", "rarity": 0}, "runners", "terry_band"]],
	["2_rare", [{"slot": "racket", "rarity": 1}, "spikes", "server_band"]],
	["3_epic", ["twister", "springs", "cold_pack"]],
	["4_legendary", ["thunderer", "ghost_sneakers", "crown"]],
	["5_mythic", ["sun", "second_wind", "golden_hand"]],
]
const STRIP_H := 440

var main: Node
var h := 1564
var out := ""
var cells: Array = []        # [SubViewport, Athlete or null, kind]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
	out = ProjectSettings.globalize_path("user://gear_%d_" % h)
	_run.call_deferred()


static func kit_items(kit: Array) -> Array:
	var items: Array = []
	for k in kit:
		if k is String:
			items.append(Items.instance(Items.find(k)))
		else:
			var d: Dictionary = (k as Dictionary).duplicate()
			d["name"] = "%s %s" % [Gear.FORMS[d["slot"]][d["rarity"]], Gear.NOUNS[d["slot"]]]
			items.append(d)
	return items


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout  # loading screen
	SaveData.control_chosen = true
	SaveData.enabled = false  # look, don't touch the player's progress
	Skills.pending = []
	if main.club.active:
		main.club.close()
	main._next_location = "park"
	main._start_practice()
	await create_timer(0.5).timeout
	var tut: Node = main.hud.get("_tutorial")
	if tut and tut.visible:
		tut.visible = false  # closed without marking it done
		paused = false
	main.hud._debug_panel.visible = false  # the settings sheet the club may leave open
	await create_timer(1.0).timeout
	if "--draws" in OS.get_cmdline_user_args():
		await _draws()
		quit()
		return
	_make_strip()
	for kit in KITS:
		var items := kit_items(kit[1])
		main.player.set_gear(items)
		main.cpu.set_gear(items)
		for c in cells:
			if c[1] != null:
				(c[1] as Athlete).set_gear(items)
			elif c[2] == "racket":
				_show_racket(c[0], items[0] if not items.is_empty() else {})
		await create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		for i in cells.size():
			var vp: SubViewport = cells[i][0]
			img.blit_rect(vp.get_texture().get_image(), Rect2i(Vector2i.ZERO, vp.size), cells[i][3])
		img.save_png(out + String(kit[0]) + ".png")
		print("saved ", out + String(kit[0]) + ".png")
	await _rackets_sheet()
	quit()


## The bottom strip: the racket face on | the near player | his shoes over his wrist.
func _make_strip() -> void:
	var y := h - STRIP_H
	cells.append([_viewport(Vector2i(240, STRIP_H)), null, "racket", Vector2i(0, y)])
	var body := _viewport(Vector2i(240, STRIP_H))
	cells.append([body, _dummy(body, Vector3(1.6, 1.25, -3.0), Vector3(0.1, 0.9, 0), 32.0), "body", Vector2i(240, y)])
	var feet := _viewport(Vector2i(240, STRIP_H / 2))
	cells.append([feet, _dummy(feet, Vector3(0.55, 0.42, -0.85), Vector3(0.02, 0.06, -0.05), 36.0), "feet", Vector2i(480, y)])
	var wrist := _viewport(Vector2i(240, STRIP_H / 2))
	cells.append([wrist, _dummy(wrist, Vector3(1.1, 1.1, -0.55), Vector3(0.3, 0.95, -0.35), 30.0), "wrist", Vector2i(480, y + STRIP_H / 2)])


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.15, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.8, 0.86)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	vp.add_child(sun)
	return vp


## A player standing ready in his own little world, seen by a camera from pos to at.
func _dummy(vp: SubViewport, pos: Vector3, at: Vector3, fov: float) -> Athlete:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.38, 0.66)
	ground.material_override = gm
	vp.add_child(ground)
	var a := Athlete.new()
	vp.add_child(a)
	a.setup(-1.0, SaveData.look, Rect2(-50, -50, 100, 100))
	var cam := Camera3D.new()
	cam.fov = fov
	vp.add_child(cam)
	cam.look_at_from_position(pos, at, Vector3.UP)
	return a


func _show_racket(vp: SubViewport, item: Dictionary) -> void:
	for c in vp.get_children():
		if c.name == "Racket":
			vp.remove_child(c)
			c.queue_free()
		if c is Camera3D:
			c.queue_free()
	var r := AthleteGear.racket_model(item)
	vp.add_child(r)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.25, 0.4, 1.55), Vector3(0.0, 0.33, 0), Vector3.UP)


## Every racket face on: stock, generated common and rare, then the catalog's.
func _rackets_sheet() -> void:
	var items: Array = [{}, kit_items([{"slot": "racket", "rarity": 0}])[0], kit_items([{"slot": "racket", "rarity": 1}])[0]]
	for e in Items.LIST:
		if e["slot"] == "racket":
			items.append(Items.instance(e))
	var size := Vector2i(180, 300)
	var vps: Array = []
	for it in items:
		var vp := _viewport(size)
		_show_racket(vp, it)
		vps.append(vp)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var cols := 7
	var rows := ceili(float(vps.size()) / cols)
	var sheet := Image.create(size.x * cols, size.y * rows, false, (vps[0] as SubViewport).get_texture().get_image().get_format())
	sheet.fill(Color(0.13, 0.15, 0.2))
	for i in vps.size():
		sheet.blit_rect((vps[i] as SubViewport).get_texture().get_image(), Rect2i(Vector2i.ZERO, size), Vector2i((i % cols) * size.x, (i / cols) * size.y))
	sheet.save_png(out + "rackets.png")
	print("saved ", out + "rackets.png")


func _measure() -> float:
	await process_frame
	await process_frame
	var d := 0.0
	for i in 30:
		await process_frame
		d += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return d / 30.0


func _draws() -> void:
	for preset in [1, 3]:
		main.graphics.set_preset(preset)
		main.player.set_gear([])
		main.cpu.set_gear([])
		await create_timer(0.5).timeout
		var none := await _measure()
		var mythic := kit_items(KITS[5][1])
		main.player.set_gear(mythic)
		main.cpu.set_gear(mythic)
		await create_timer(0.5).timeout
		var both := await _measure()
		main.player.set_gear(kit_items(KITS[4][1]))
		main.cpu.set_gear(kit_items(KITS[3][1]))
		await create_timer(0.5).timeout
		var mixed := await _measure()
		print("DRAWS %s: nothing worn %.0f | both mythic %.0f (%+.0f) | legendary + epic %.0f (%+.0f)" % [
			main.graphics.level_name(), none, both, both - none, mixed, mixed - none])
