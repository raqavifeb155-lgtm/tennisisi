extends SceneTree
## End-to-end check of the best-point replay: the bot plays one quick tournament match
## (a tiebreak) in a window, the first stylish point is played back and photographed.
##   godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/replay_check.gd

var main: Node
var out := ""
var _done := false


func _initialize() -> void:
	out = ProjectSettings.globalize_path("user://replay_check_")
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _run() -> void:
	root.size = Vector2i(720, 1564)
	SaveData.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	main.run_hub.style_scored.connect(func(_r: Dictionary) -> void: _done = true)
	for id in Skills.LIST:
		Skills.add_xp(id, 2500.0)  # a strong bot: aces and winners come sooner
	main.autoplay = true
	main._start_tournament(1)
	await create_timer(0.3).timeout
	main.hud._tutorial.visible = false
	paused = false
	var t0 := Time.get_ticks_msec()
	while not _done and Time.get_ticks_msec() - t0 < 400000:
		await process_frame
	await create_timer(2.0).timeout  # the post-roll after the point
	main.autoplay = false
	main._stop_match()
	var hub: RunHub = main.run_hub
	print("style points %d, best %s, replay frames %d, decided at %d" % [hub.meter.match_points, hub.meter.best.get("mult", 0.0),
		PointRecorder.length(hub.recorder.best_frames), hub._best_end])
	if not hub.has_replay():
		print("no stylish point this match: run again")
		quit(1)
		return
	main.ui.close()
	hub.play_best(func() -> void: print("replay finished"))
	var n := PointRecorder.length(hub.recorder.best_frames)
	for k in 4:
		await create_timer(n / 30.0 / 4.0).timeout
		await _shot("%d" % k)
	await create_timer(1.0).timeout
	print("share image: ", hub.share_image != null)
	await _shot("after")
	quit()
