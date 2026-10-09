extends SceneTree
## The trophy game with each kind of loot (hotfix F-A, owner 10.10: the beaten opponent ran with a
## racket whatever he dropped):
##   godot --path . --rendering-driver opengl3 -s tools/trophy_shots.gd [-- --size=1480] [--tag=fa]
## For a racket, shoes and a wristband (epic): the runner in his three items, the knockout, the
## trophy lying on the court. PNGs go to the user data folder (path printed).

var main: Node
var h := 1564
var out := ""
var tag := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://trophy_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	SaveData.enabled = false
	Skills.pending = []
	if main.club.active:
		main.club.close()
	main._next_location = "park"
	main._start_practice()
	await create_timer(1.0).timeout
	var tut: Node = main.hud.get("_tutorial")
	if tut and tut.visible:
		tut.visible = false
		paused = false
	main.hud._debug_panel.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for slot in Gear.SLOTS:
		var t := Tournament.new(2, 31)
		var gear := {}
		for s in Gear.SLOTS:
			gear[s] = Gear.roll(Gear.RARE, rng, s)
		gear[slot] = Gear.roll(Gear.EPIC, rng, slot)
		t.lineup[0]["gear"] = gear
		t.drop_bonus = 1.0
		t.record_match(true, "6:1", rng)
		print(slot, " trophy: ", t.pending_loot.get("name", "-"), " / slot ", t.pending_loot.get("slot", "?"))
		main.tournament = t
		main.tournament_mode = true
		main._stop_match()
		main._start_bonus()
		main.player.area = Rect2(-8.0, -17.0, 16.0, 31.0)
		main.ui.root.visible = false  # the result panel under the bonus game is not what is looked at here
		main.cpu.position = Vector3(0.6, 0.0, 8.6)  # near the camera, to see what he wears
		main.cpu.velocity = Vector3.ZERO
		main._runner_goal = main.cpu.position
		main._runner_timer = 100.0
		await _shot("%s_1_runner" % slot, 0.4)
		main._bonus_hit()
		await _shot("%s_2_flying" % slot, 0.25)
		await _shot("%s_3_landed" % slot, 1.2)
		main._end_bonus()
		await create_timer(0.3).timeout
	quit()
