extends SceneTree
## Stream A (v0.2) screens and overlays as the phone sees them:
##   godot --path . --rendering-driver opengl3 -s tools/run_shots.gd [-- --size=1480]
## 720 x 1564 by default (iPhone 17 Pro Max), --size=1480 a small Android. PNGs go to
## the user data folder (path printed). Progress is not saved.

var main: Node
var h := 1564
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
	out = ProjectSettings.globalize_path("user://run_%d_" % h)
	_run.call_deferred()


func _shot(name: String, wait := 0.7) -> void:
	await create_timer(wait).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _best() -> Dictionary:
	return {"tricks": [{"id": "ace", "name": "Эйс", "x": 1.3}, {"id": "cannon", "name": "Пушка", "x": 1.5}, {"id": "on_line", "name": "По линии", "x": 1.3}],
		"mult": 2.535, "points": 25, "rally": 1, "skill": "serve", "stroke_frame": 10}


func _run() -> void:
	root.size = Vector2i(720, h)
	SaveData.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout  # loading screen
	SaveData.control_chosen = true
	var hub: RunHub = main.run_hub
	var t := Tournament.new(1)
	main.tournament = t
	main.tournament_mode = true
	main._play_match()
	await create_timer(0.3).timeout
	main.hud._tutorial.visible = false  # the first-match tutorial would cover everything
	paused = false
	main.hud.show_message("WINNER!
GAME YOU", UiTheme.WIN)  # the verdict shows in the same frame
	hub.plate.show_result(_best())
	await _shot("a1_plate", 0.75)

	# A recorded "best point": the opponent runs across, the ball flies to his side.
	main._stop_match()
	hub.recorder.begin()
	for i in 60:
		var k := i / 59.0
		main.cpu.position = Vector3(lerpf(-3.0, 3.5, k), 0, -12.0)
		main.ball.visible = true
		main.ball.position = Vector3(lerpf(0.5, 3.0, k), 1.0 + sin(k * PI) * 2.5, lerpf(10.0, -11.0, k))
		hub.recorder.capture(main.ball.position, true)
	hub.recorder.keep_best(hub.recorder.end_point())
	hub._best_end = 30
	hub.meter.best = _best()
	hub.last_match = {"points": 64, "gold": 6, "best": _best()}
	main.cpu.position = Vector3(0, 0, -12.6)
	main.ball.visible = false
	t.record_match(true, "6:3", RandomNumberGenerator.new())
	main.ui.show_result(t, true, "6:3", {"perfect": 12, "aces": 3, "best_rally": 14})
	await _shot("a1_result")
	RunHub.ui_action(main, "replay")
	await _shot("a1_replay", 1.45)
	await create_timer(1.5).timeout
	await _shot("a1_result_share")
	print("share image: ", hub.share_image != null)
	if hub.share_image:
		hub.share_image.save_png(out + "a1_share_picture.png")
		print("share caption: ", RunShare.caption(hub.meter.best))
	await _a2(hub)
	quit()


## A-2: the bracket with the bag row, the bag, an item against the worn one, the trophy,
## the opponent's stamina bar with damage numbers in a match.
func _a2(hub: RunHub) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var t := Tournament.new(1, 77)
	t.equip["racket"] = Items.instance(Items.find("sledgehammer"))
	t.equip["band"] = Gear._affix_item(Gear.COMMON, rng, "band")
	t.bag = [Gear._affix_item(Gear.RARE, rng, "racket"), Items.instance(Items.find("springs")), Gear._affix_item(Gear.COMMON, rng, "shoes")]
	t.lineup[1]["gear"]["racket"] = Items.instance(Items.find("cutter"))
	t.lineup[2]["gear"]["band"] = Items.instance(Items.find("cold_pack"))
	main.tournament = t
	main.tournament_mode = true
	main.ui.show_bracket(t)
	await _shot("a2_bracket")
	main._on_ui("bag", 0)
	await _shot("a2_bag")
	main._on_ui("bag_item", 10)
	await _shot("a2_item")
	t.pending_loot = Items.instance(Items.find("thunderer"))
	main.ui.show_loot(t)
	await _shot("a2_loot")
	t.pending_loot = {}
	main._play_match()
	await create_timer(1.0).timeout
	main.hud._tutorial.visible = false
	paused = false
	hub.match_fx._hurt(12.0, "run")
	await create_timer(0.15).timeout
	hub.match_fx._hurt(31.0, "item")
	await _shot("a2_stamina", 0.12)
	hub.match_fx._hurt(30.0, "heavy")
	await _shot("a2_stamina_tired", 0.7)
