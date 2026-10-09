extends SceneTree
## The academy's house as the phone sees it (AH-1), for design review and the budget:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/house_shots.gd -- --tag=ah [--size=1480]
## 720x1564 = iPhone 17 Pro Max (440x956), --size=1480 = a small Android (360x740). PNGs go to the user data
## folder (path printed), never over the player's save.
##   --levels=N   every room at level N (default 3); the building at 5 unless --academy=L says
##   --academy=L  the academy building's level (rooms above it stay shut)
##   --gfx=N      graphics preset (1 Low .. 4 Max)
##   --stats      the budget: draw calls and triangles of the world of the house in the hall and in each room,
##                on Low, Medium and High, with every room at level 5 (no pictures)
##   --flow       the door, the fade, the way out, the sheet, the quiet button, the scaffolding

var main: Node
var h := 1564
var gfx := -1
var out := ""
var levels := 3
var academy := 5
var stats := false
var flow := false
var tag := ""
var hour := 11.0
var noshadow := false
var only: Array = []      # --rooms=dorm,gym: just these rooms (and no hall shots)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--gfx="):
			gfx = int(a.get_slice("=", 1))
		elif a.begins_with("--levels="):
			levels = int(a.get_slice("=", 1))
		elif a.begins_with("--academy="):
			academy = int(a.get_slice("=", 1))
		elif a == "--stats":
			stats = true
		elif a == "--flow":
			flow = true
		elif a == "--noshadow":
			noshadow = true
		elif a.begins_with("--rooms="):
			only = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--hour="):
			hour = float(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://house_%s%d_" % [tag, h])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	DisplayServer.window_set_position(Vector2i(rng.randi_range(0, 900), rng.randi_range(0, 120)))
	_run.call_deferred()


## Draw calls and thousands of triangles of the frame, and of the same frame without the hero and the coach.
func _measure() -> Array:
	var pv: bool = main.player.visible
	main.player.visible = false
	await process_frame
	await process_frame
	var wd := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var wt := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	main.player.visible = pv
	await process_frame
	return [wd, wt]


func _shot(name: String, settle := 0.9) -> void:
	await create_timer(settle).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	var d := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var t := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0
	var w: Array = await _measure()
	print("saved %s%s.png   draws %d  tris %.1fk   world: draws %d  tris %.1fk" % [out, name, d, t, w[0], w[1]])


func _setup() -> void:
	SaveData.enabled = false
	SaveData.control_chosen = true
	SaveData.played = 9
	SaveData.titles = 2
	SaveData.gold = 3000
	SaveData.academy = {}
	var lv := {}
	for r in HouseRooms.ids():
		lv[r] = levels
	SaveData.house = {"levels": lv}
	SaveData.club = {"met_coach": true, "walk_hint": true, "hire_hint": true, "lots": {"n7": "academy", "n2": "coach"}, "levels": {"academy": academy, "coach": 2}}
	SaveData.active = null
	SaveData.run = {}
	Skills.points = 2
	Skills.pending = []
	ClubDaytime.force_hour = hour


func _enter() -> void:
	var club = main.club
	club.hud._bubble.visible = false
	main.player.position = ClubPlaces.find("academy")["pos"]
	club._place = ""
	club._update_place()
	club.cam.snap()
	club.ui_action("club_house", 0)
	for i in 120:
		await process_frame
		if club.house.inside:
			break
	await create_timer(0.7).timeout
	club.hud._bubble.visible = false
	if noshadow:
		club.house.world.set_shadows(false)


func _to(room: String, dx := 0.0, dz := 0.0) -> void:
	var c := HouseWorld.room_center(room)
	main.player.position = Vector3(c.x + dx, 0, c.z + dz)
	main.player.velocity = Vector3.ZERO
	await create_timer(0.3).timeout


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SaveData.enabled = false
	await create_timer(3.0).timeout
	for i in 60:
		var loading := false
		for c in main.get_children():
			if c is CanvasLayer and (c as CanvasLayer).layer == 100:
				loading = true
		if not loading:
			break
		await create_timer(0.5).timeout
	await create_timer(0.5).timeout
	if gfx >= 0:
		main.graphics.set_preset(gfx)
	_setup()
	main._show_menu()
	await create_timer(1.0).timeout
	if stats:
		await _stats()
		quit()
		return
	if flow:
		await _flow()
		quit()
		return
	var club = main.club
	main.player.position = ClubPlaces.find("academy")["pos"]
	club._place = ""
	club._update_place()
	club.cam.snap()
	if only.is_empty():
		await _shot("00_door", 1.2)
	await _enter()
	if only.is_empty():
		await _shot("01_hall_in", 0.5)
		main.player.position = HouseWorld.ORIGIN + Vector3(0, 0, -12.0)
		await _shot("02_hall_mid", 1.2)
		main.player.position = HouseWorld.ORIGIN + Vector3(0, 0, -22.0)
		await _shot("03_hall_end", 1.2)
	for r in HouseRooms.ids():
		if not only.is_empty() and not only.has(r):
			continue
		await _to(r, -HouseRooms.ROOMS[r]["side"] * 1.6, HouseWorld.DOOR_DZ)
		await _shot("room_%s" % r, 1.1)
	quit()


func _stats() -> void:
	var club = main.club
	var lv := {}
	for r in HouseRooms.ids():
		lv[r] = 5
	SaveData.house = {"levels": lv}
	await _enter()
	for preset in [1, 2, 3]:
		main.graphics.set_preset(preset)
		HousePack.detail = preset - 1
		await create_timer(0.6).timeout
		main.player.position = HouseWorld.spawn()
		await create_timer(1.0).timeout
		var w: Array = await _measure()
		var line := "preset %d  hall (door): draws %d  tris %.1fk" % [preset, w[0], w[1]]
		main.player.position = HouseWorld.ORIGIN + Vector3(0, 0, -12.0)
		await create_timer(1.0).timeout
		w = await _measure()
		line += "   hall (mid): draws %d  tris %.1fk" % [w[0], w[1]]
		var worst := [0, 0.0, ""]
		for r in HouseRooms.ids():
			await _to(r, -HouseRooms.ROOMS[r]["side"] * 1.6, HouseWorld.DOOR_DZ)
			await create_timer(0.9).timeout
			var m: Array = await _measure()
			print("   preset %d  room %-8s draws %2d  tris %.1fk" % [preset, r, m[0], m[1]])
			if m[0] > worst[0]:
				worst = [m[0], m[1], r]
		print(line + "   worst room: %s draws %d tris %.1fk" % [worst[2], worst[0], worst[1]])


func _flow() -> void:
	var club = main.club
	main.player.position = ClubPlaces.find("academy")["pos"]
	club._place = ""
	club._update_place()
	club.cam.snap()
	await _shot("f00_door", 1.0)
	club.ui_action("club_house", 0)
	await _shot("f01_fade_out", 0.12)
	await _shot("f02_inside", 0.7)
	# the shut doors of a young academy
	SaveData.club["levels"]["academy"] = 1
	SaveData.house = {"levels": {"dorm": 1}}
	club.house.world.sync()
	main.player.position = HouseWorld.ORIGIN + Vector3(0, 0, -11.0)
	await _shot("f03_shut_doors", 1.2)
	await _to("dorm", 1.6, HouseWorld.DOOR_DZ)
	await _shot("f04_dorm_quiet_button", 1.2)
	club.ui_action("club_house_room:dorm", 0)
	await _shot("f05_sheet", 0.9)
	main.ui._scroll.scroll_vertical = 900
	await _shot("f05b_sheet_bottom", 0.4)
	club.ui_action("club_house_back", 0)
	SaveData.club["levels"]["academy"] = 4
	SaveData.house = {"levels": {"dorm": 3, "canteen": 3}, "building": {"dorm": {"level": 4, "until": 99}}}
	club.house.world.sync()
	club.house.refresh_place()
	await _to("dorm", 1.6, HouseWorld.DOOR_DZ)
	await _shot("f06_scaffold", 1.2)
	main.player.position = HouseWorld.exit_center()
	await _shot("f07_exit_button", 1.0)
	club.ui_action("club_house_exit", 0)
	await _shot("f08_fade_out", 0.12)
	await _shot("f09_back_in_the_club", 0.9)
