extends SceneTree
## The club as the phone sees it (docs/club/H1_SPEC.md 9), for design review:
##   godot --path . --rendering-driver opengl3 -s tools/club_shots.gd [-- --size=1480] [--gfx=1]
## 720x1564 = iPhone 17 Pro Max (440x956), --size=1480 = a small Android (360x740).
## PNGs go to the user data folder (path printed). Never writes the save.
## --gfx=N: graphics preset (1 Low .. 4 Max), and the draw calls are printed per shot.

var main: Node
var h := 1564
var gfx := -1
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--gfx="):
			gfx = int(a.get_slice("=", 1))
	out = ProjectSettings.globalize_path("user://club_%d_" % h)
	_run.call_deferred()


func _shot(name: String, settle := 0.8) -> void:
	await create_timer(settle).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	var d := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var t := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	# The club's own budget is for the world: the same frame without the two people.
	main.player.visible = false
	main.cpu.visible = false
	await process_frame
	await process_frame
	var wd := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var wt := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	main.player.visible = true
	main.cpu.visible = true
	print("saved %s%s.png   draws %d  tris %.1fk   world: draws %d  tris %.1fk" % [out, name, d, t, wd, wt])


func _go(id: String) -> void:
	main.club._travel(id)


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SaveData.enabled = false  # look, don't touch the player's progress
	await create_timer(7.0).timeout  # loading screen
	if gfx >= 0:
		main.graphics.set_preset(gfx)
	SaveData.control_chosen = true
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.club = {}
	SaveData.active = null
	SaveData.run = {}
	Skills.points = 2
	Skills.pending = []
	main._show_menu()
	print("club active=%s location=%s scenery=%s" % [main.club.active, main.location_id, main.scenery.get_script().resource_path])
	await _shot("01_start", 1.6)
	main.club.hud._toggle_travel(true)
	await _shot("02_travel", 0.4)
	main.club.hud._toggle_travel(false)
	_go("coach")
	await _shot("03_coach_room")
	SaveData.played = 1
	main.club._refresh()
	_go("locker")
	await _shot("04_locker_room")
	# Out on the path between the pavilions: the walk, the signs, the arena site.
	main.player.position = Vector3(-6, 0, 31)
	main.club._update_place()
	await _shot("05_path", 1.2)
	main.player.position = Vector3(-14, 0, -18)
	await _shot("06_trophy_sign", 1.6)
	var t := Tournament.new(1)
	t.stage = 3
	SaveData.active = t
	SaveData.club = {"last_location": "clay", "last_format": 1, "met_coach": true}
	_go("court")
	await _shot("07_continue", 1.2)
	SaveData.active = null
	main.club._place = ""
	main.club._update_place()
	await _shot("08_last_tournament", 0.6)
	quit()
