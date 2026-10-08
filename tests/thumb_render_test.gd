extends SceneTree
## The pictures of the things really drawn (v0.2 L-2): needs a renderer, so not headless:
##   godot --path . --rendering-driver opengl3 -s tests/thumb_render_test.gd
## All 25 catalog things, the generated ones and the stock ones get a picture; a frame never
## draws more than 3; each thing takes one frame; the pictures differ from one another.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: thumb_render_test needs a renderer (run without --headless)")
		quit(0)
		return
	root.size = Vector2i(720, 1564)
	ItemThumb.clear()
	var things: Array = []
	for e in Items.LIST:
		things.append([Items.instance(e), ""])
	for slot in Gear.SLOTS:
		things.append([{}, slot])
		for r in 2:
			things.append([{"slot": slot, "rarity": r, "name": "x", "mods": {}, "lines": []}, ""])
	var keys := {}
	for th in things:
		keys[ItemThumb.key(th[0], th[1])] = true
	var host := Control.new()
	root.add_child(host)
	for th in things:
		host.add_child(ItemThumb.view(th[0], th[1]))
	var frames := 0
	while ItemThumb._cache.size() < keys.size() and frames < 300:
		await process_frame
		frames += 1
	check(ItemThumb._cache.size() == keys.size(), "%d looks, %d pictures" % [keys.size(), ItemThumb._cache.size()])
	check(ItemThumb.failed == 0, "nothing came back empty: %d failed" % ItemThumb.failed)
	check(ItemThumb.max_batch <= 3, "at most 3 in one frame: %d" % ItemThumb.max_batch)
	var need := ceili(float(keys.size()) / 3.0)
	check(frames <= need + 4, "one frame per thing, three at a time: %d frames for %d (at least %d)" % [frames, keys.size(), need])
	var seen := {}
	var catalog_ok := true
	for e in Items.LIST:
		var tex := ItemThumb.texture(Items.instance(e)) as Texture2D
		if tex == null:
			catalog_ok = false
			continue
		var img := tex.get_image()
		seen[hash(img.get_data())] = true
		catalog_ok = catalog_ok and img.get_width() == ItemThumb.SIZE
	check(catalog_ok and seen.size() == 25, "all 25 catalog things have a picture of their own: %d different" % seen.size())
	var again := ItemThumb.renders
	for th in things:
		ItemThumb.texture(th[0], th[1])
	await process_frame
	check(ItemThumb.renders == again and ItemThumb.pending() == 0, "asked again: from the cache, nothing drawn")
	print("\n%s (%d failures)" % ["THUMB RENDER TESTS PASSED" if failures == 0 else "THUMB RENDER TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)
