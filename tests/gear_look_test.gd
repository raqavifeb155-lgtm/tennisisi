extends SceneTree
## Gear on the player (v0.2 F, docs/superpowers/specs/2026-10-08-v02-gear-skins.md):
##   godot --headless --path . --fixed-fps 60 -s tests/gear_look_test.gd [-- --body=1]
## Every catalog item has its own look, the racket follows the hand through a swing,
## the glow goes by rarity (no real light anywhere), a mythic shows on the court, the
## gear costs at most 3 draw calls more than none, and the body's rebuild keeps it.

const DT := 1.0 / 60.0
const BUDGET := 3               # extra draw calls per player for the gear (spec 6)
const RACKET_KEYS := ["frame", "tube", "color", "accent", "grip", "wrap", "strings", "pattern", "halo"]
const PATTERNS := ["", "edge", "stripe", "spiral", "segments", "twotone", "veins", "core"]
const HALOS := ["", "rays", "flames", "bolts", "double", "spiral"]
const SHOE_KEYS := ["body", "sole", "stripe", "pattern"]
const SHOE_PATTERNS := ["", "stripe", "two", "toe", "heel", "zigzag", "gradient", "wind"]
const BAND_KEYS := ["color", "second", "pattern"]
const BAND_PATTERNS := ["", "stripe", "edges", "dots", "stripes", "zigzag", "crown"]

var failures := 0
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--body="):
			Athlete.body_style = int(a.get_slice("=", 1))
			print("body style ", Athlete.body_style)
	test_catalog_skins()
	test_shoes_and_bands()
	test_racket_follows_hand()
	test_glow_by_rarity()
	test_mythic_on_court()
	test_draw_budget()
	test_rebuild_keeps_gear()
	test_old_api()
	print("\n%s (%d failures)" % ["ALL GEAR LOOK TESTS PASSED" if failures == 0 else "GEAR LOOK TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)
	return true


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func fresh() -> Athlete:
	var a := Athlete.new()
	root.add_child(a)
	a.setup(-1.0, Looks.DEFAULT, Rect2(-9, -14, 18, 30))
	a.position = Vector3(0, 0, 11)
	return a


func step(a: Athlete) -> void:
	a._physics_process(DT)
	a._process(DT)


func item(id: String) -> Dictionary:
	return Items.instance(Items.find(id))


func generated(slot: String, rarity: int) -> Dictionary:
	return {"slot": slot, "rarity": rarity, "name": "test", "mods": {}, "lines": []}


func test_catalog_skins() -> void:
	print("catalog: every item has its own skin")
	var seen := {}
	for e in Items.LIST:
		if String(e["slot"]) != "racket":
			continue
		var skin: Dictionary = e.get("skin", {})
		check(not skin.is_empty(), "%s has a skin" % e["id"])
		var ok := AthleteGear.FRAMES.has(String(skin.get("frame", "classic")))
		for k in skin:
			ok = ok and k in RACKET_KEYS
		for k in ["color", "accent", "grip", "wrap", "strings"]:
			ok = ok and Color.html_is_valid(String(skin.get(k, "#000000")))
		ok = ok and String(skin.get("pattern", "")) in PATTERNS and String(skin.get("halo", "")) in HALOS
		check(ok, "%s: the skin's keys, colours and patterns are known" % e["id"])
		var key := str(skin)
		check(not seen.has(key), "%s looks unlike %s" % [e["id"], seen.get(key, "the others")])
		seen[key] = e["id"]


func test_shoes_and_bands() -> void:
	print("shoes and wristbands: a skin each, on the body's own meshes")
	var seen := {}
	for e in Items.LIST:
		var slot := String(e["slot"])
		if slot == "racket":
			continue
		var skin: Dictionary = e.get("skin", {})
		var keys: Array = SHOE_KEYS if slot == "shoes" else BAND_KEYS
		var pats: Array = SHOE_PATTERNS if slot == "shoes" else BAND_PATTERNS
		var ok := not skin.is_empty() and String(skin.get("pattern", "")) in pats
		for k in skin:
			ok = ok and k in keys
			ok = ok and (k == "pattern" or Color.html_is_valid(String(skin[k])))
		check(ok, "%s has a skin with known keys, colours and pattern" % e["id"])
		var key := str(skin)
		check(not seen.has(key), "%s looks unlike %s" % [e["id"], seen.get(key, "the others")])
		seen[key] = e["id"]
	var a := fresh()
	var shoe0: MeshInstance3D = a._bones["shoe0"]
	var fore: MeshInstance3D = a._bones["fore_r"]
	var own_shoe := shoe0.mesh
	var own_fore := fore.mesh
	if a._body == Athlete.Body.CLASSIC:
		a.set_gear([item("second_wind"), item("crown")])
		check(shoe0.mesh == own_shoe, "classic body: capsules stay as they are")
		a.free()
		return
	var colours := {}
	for id in ["runners", "spikes", "second_wind", "berserk", "golden_hand"]:
		a.set_gear([item(id)])
		var m: Mesh = (shoe0 if Items.find(id)["slot"] == "shoes" else fore).mesh
		colours[id] = (m.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray).slice(0, 400)
	check(colours["runners"] != colours["spikes"] and colours["berserk"] != colours["golden_hand"], "different items paint different meshes")
	a.set_gear([item("second_wind"), item("golden_hand")])
	check(shoe0.mesh != own_shoe and (a._bones["shoe1"] as MeshInstance3D).mesh == shoe0.mesh, "both shoes wear it")
	check(fore.mesh != own_fore and (a._bones["fore_l"] as MeshInstance3D).mesh == fore.mesh, "both wrists wear the band")
	check(shoe0.material_override is ShaderMaterial and (shoe0.material_override as ShaderMaterial).get_shader_parameter("energy") > 0.0, "a mythic shoe glows (gear shader)")
	check(fore.material_override is ShaderMaterial, "a mythic band glows (gear shader)")
	a.set_gear([item("runners"), item("terry_band")])
	check(fore.material_override is StandardMaterial3D, "a common band keeps the body's own material")
	a.set_look({"shirt": 3, "accent": 5})
	shoe0 = a._bones["shoe0"]
	check(shoe0.material_override is ShaderMaterial, "set_look: the shoes are dressed again")
	a.set_gear([])
	check(shoe0.mesh == (a._bones["shoe0"] as MeshInstance3D).mesh and shoe0.material_override is StandardMaterial3D, "taken off: the look's own shoes")
	a.free()


func test_racket_follows_hand() -> void:
	print("racket: in the hand through a swing and a serve")
	var a := fresh()
	a.set_gear([item("sun")])
	var worst := 0.0
	for f in 150:
		if f == 10:
			a.prepare(1)
		elif f == 40:
			a.swing(1, 0.3, a.to_global(Vector3(0.75, 0.95, -0.45)), Athlete.Style.TOPSPIN)
		elif f == 90:
			a.serve_ready()
		elif f == 110:
			a.prepare_serve()
		step(a)
		var frame: MeshInstance3D = a._gear.frame
		var wrist: Vector3 = a._model.to_global(a._ends["fore_r"][1])  # the end of the forearm
		worst = maxf(worst, frame.global_position.distance_to(wrist))
	check(worst < 0.001, "the frame's grip stays at the end of the forearm (worst %.4f m)" % worst)
	check(a._gear.frame.get_parent() == a._racket and a._gear.halo.get_parent() == a._racket, "frame and glow ride on the posed racket node")
	a.free()


func test_glow_by_rarity() -> void:
	print("glow: by rarity, material only")
	var a := fresh()
	var cases := [
		[{}, 0, false], [generated("racket", Gear.COMMON), 0, false], [generated("racket", Gear.RARE), 1, false],
		[item("twister"), 2, true], [item("cutter"), 3, true], [item("sun"), 4, true],
	]
	for c in cases:
		a.set_gear([c[0]])
		var fm := a._gear.frame.material_override as ShaderMaterial
		var fx := int(fm.get_shader_parameter("fx"))
		var has_halo: bool = a._gear.halo != null
		var name := String((c[0] as Dictionary).get("name", "stock"))
		check(fx == c[1] and has_halo == c[2], "%s: frame effect %d, glow mesh %s" % [name, fx, has_halo])
		check(a.find_children("*", "Light3D", true, false).is_empty(), "%s: no real light" % name)
	a.set_gear([item("sun")])
	var gm := a._gear.halo.material_override as ShaderMaterial
	var red: Color = gm.get_shader_parameter("glow")
	check(red.r > 0.9 and red.g < 0.4 and int(gm.get_shader_parameter("fx")) == 4, "a mythic glows red with the heartbeat")
	a.free()


func test_mythic_on_court() -> void:
	print("mythic: a ring on the court, any slot")
	var a := fresh()
	a.set_gear([item("cutter")])
	check(a._gear.aura == null, "a legendary has no ring")
	a.set_gear([item("sun")])
	check(a._gear.aura != null and a._gear.aura.is_inside_tree(), "a mythic racket: the ring")
	a.set_gear([{}])
	check(a._gear.aura == null and a.find_children("MythicAura", "", true, false).is_empty(), "taken off: gone")
	a.free()


## Draw calls of what is drawn under `n`: the mesh, its outline (next pass) and its shadow.
func draws(n: Node) -> int:
	var d := 0
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		d += 1
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			d += 1
		if gi.material_override and gi.material_override.next_pass:
			d += 1
	return d


func test_draw_budget() -> void:
	print("draw calls: the gear costs at most %d more than none" % BUDGET)
	var a := fresh()
	a._lighten()
	var stock := draws(a)
	var stock_racket := draws(a._racket)
	for kit in [["sun"], ["sun", "cutter", "twister"], ["thunderer"], ["sun", "second_wind", "golden_hand"], ["twister", "springs", "cold_pack"], ["cutter", "ghost_sneakers", "crown"]]:
		var items: Array = kit.map(func(id): return item(id))
		a.set_gear(items)
		a._lighten()
		var d := draws(a)
		check(d - stock <= BUDGET, "%s: %d draws vs %d with nothing (+%d)" % [kit, d, stock, d - stock])
	# The racket alone used to be a handle and a ring (each mesh + outline + shadow) and the strings: 7.
	check(stock_racket <= 7, "the stock racket draws %d (was 7)" % stock_racket)
	a.free()


func test_rebuild_keeps_gear() -> void:
	print("set_look rebuilds the body, the gear stays")
	var a := fresh()
	a.set_gear([item("sun")])
	a.set_look({"shirt": 3, "accent": 5})
	check(a._gear.halo != null and a._gear.halo.is_inside_tree() and a._gear.frame.get_parent() == a._racket, "the glow is on the new racket")
	check(a._gear.aura != null and a._gear.aura.is_inside_tree(), "the mythic ring is back")
	a.set_gear([])
	check(a._gear.halo == null and int((a._gear.frame.material_override as ShaderMaterial).get_shader_parameter("fx")) == 0, "set_gear([]): the stock racket")
	a.free()


func test_old_api() -> void:
	print("set_racket_look / set_racket")
	var a := fresh()
	a.set_gear([item("cutter")])
	a.set_racket_look(UiTheme.GOLD, 1.6)
	var gm := a._gear.halo.material_override as ShaderMaterial
	check(a._gear.halo != null and (gm.get_shader_parameter("glow") as Color).is_equal_approx(UiTheme.GOLD), "golden: the frame glows gold")
	a.set_racket(item("twister"))
	check(String(a.gear()["racket"].get("id", "")) == "twister", "set_racket swaps the racket")
	a.set_racket({})
	check(a._gear.halo == null, "set_racket({}): stock, no glow")
	a.set_gear([{}, item("second_wind")])
	a.set_racket(item("second_wind"))
	check(String(a.gear()["shoes"].get("id", "")) == "second_wind" and a._gear.halo != null and a.gear()["racket"]["rarity"] == Gear.MYTHIC, "a trophy of another slot: a racket of its rarity, the shoes stay")
	a.free()
