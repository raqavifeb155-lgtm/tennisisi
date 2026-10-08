extends SceneTree
## The pictures of the things (v0.2 L-2): every catalog thing, the generated commons and
## rares, and the stock ones, as ItemThumb draws them, on one sheet:
##   godot --path . --rendering-driver opengl3 -s tools/thumb_shots.gd [-- --tag=l]
## Prints how many frames it took and the most drawn in one frame (the budget: 1 and 3).
## The PNG goes to the user data folder (path printed).

var tag := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720, 1564)
	var bg := ColorRect.new()
	bg.color = UiTheme.BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(8, 8)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	root.add_child(grid)
	var items: Array = []
	for slot in Gear.SLOTS:
		items.append({})  # stock, with the slot
	for e in Items.LIST:
		items.append(Items.instance(e))
	for slot in Gear.SLOTS:
		for r in 2:
			items.append({"slot": slot, "rarity": r, "name": "gen", "mods": {}, "lines": []})
	var frames := 0
	var views: Array = []
	for i in items.size():
		var slot: String = Gear.SLOTS[i] if i < 3 else ""
		var v := ItemThumb.view(items[i], slot, 168.0)
		v.dim = i < 3
		grid.add_child(v)
		views.append(v)
	while ItemThumb.pending() > 0 or ItemThumb.renders + ItemThumb.failed < _keys(items).size():
		await process_frame
		frames += 1
		if frames > 600:
			break
	await create_timer(0.5).timeout
	await process_frame
	var out := ProjectSettings.globalize_path("user://thumbs_%s.png" % tag)
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	print("things %d, drawn %d, failed %d, most in one frame %d, frames %d" % [items.size(), ItemThumb.renders, ItemThumb.failed, ItemThumb.max_batch, frames])
	quit()


func _keys(items: Array) -> Dictionary:
	var d := {}
	for i in items.size():
		d[ItemThumb.key(items[i], Gear.SLOTS[i] if i < 3 else "")] = true
	return d
