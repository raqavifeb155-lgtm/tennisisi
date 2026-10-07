extends SceneTree
## Where the menu's draw calls go: the scene on the "Low" preset, then with one part
## hidden at a time. For the club's budget (docs/PERFORMANCE.md, CLUB_HUB_TZ 9).
##   godot --path . --rendering-driver opengl3 --resolution 720x1564 -s tools/draw_breakdown.gd [-- --nodes]
## --nodes: also every scenery node on its own (slow), the 15 heaviest printed.

var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _measure() -> Vector2:
	await process_frame
	await process_frame
	var d := 0.0
	var t := 0.0
	for i in 8:
		await process_frame
		d += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		t += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return Vector2(d / 8.0, t / 8.0 / 1000.0)


func _print(label: String, v: Vector2) -> void:
	print("%-34s draws %4d   tris %6.1fk" % [label, roundi(v.x), v.y])


func _run() -> void:
	root.size = Vector2i(720, 1564)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	main.graphics.set_preset(1)
	await create_timer(1.0).timeout
	main.ui.close()
	var all := await _measure()
	_print("all (Low, menu closed)", all)
	var parts := {"player": main.player, "cpu": main.cpu, "court": main.court, "scenery": main.scenery}
	for k in parts:
		parts[k].visible = false
		_print("without " + k, await _measure())
		parts[k].visible = true
	if not "--nodes" in OS.get_cmdline_user_args():
		quit()
		return
	var rows: Array = []
	for c in main.scenery.get_children():
		if not (c is Node3D) or not c.visible:
			continue
		c.visible = false
		var v := await _measure()
		c.visible = true
		rows.append([all.x - v.x, all.y - v.y, "%s %s" % [c.get_class(), c.name]])
	rows.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for r in rows.slice(0, 15):
		print("%-46s -%3d draws  -%6.1fk tris" % [r[2], roundi(r[0]), r[1]])
	quit()
