extends SceneTree
## The hero's club walk, from the side (stream H, athlete_casual.gd): a strip of frames
## for standing, walking, a jog and the auto-run, to look at the gait and the arms.
##   godot --path . --rendering-driver opengl3 -s tools/casual_shots.gd
## PNGs: user://casual_<name>_<n>.png (path printed); strips are cut with tools/casual_strip.py

var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(540, 540)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SaveData.enabled = false
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	SaveData.played = 0
	SaveData.club = {"met_coach": true}
	main._show_menu()
	await create_timer(0.5).timeout
	var club = main.club
	var p: Athlete = main.player
	main.cpu.visible = false
	club.hud.visible = false
	club.set_process(false)
	club.set_physics_process(false)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.3
	root.add_child(cam)
	cam.current = true
	var out := ProjectSettings.globalize_path("user://casual_")
	print("out ", out)
	for case in [["stand", 0.0], ["walk", 1.4], ["slow", 2.6], ["jog", 4.6], ["run", 8.0]]:
		var speed: float = case[1]
		p.position = Vector3(-12.0, 0.0, 36.0)
		p.rotation.y = -PI * 0.5   # facing +x... rotation.y = -90deg: forward (-z) turns toward +x
		p.velocity = Vector3.ZERO
		p.area = Rect2(-60, -40, 120, 100)
		p.max_speed = maxf(speed, 0.1)
		p.move_input = Vector2(1.0, 0.0) if speed > 0.0 else Vector2.ZERO
		await create_timer(0.8).timeout
		for n in 8:
			p.move_input = Vector2(1.0, 0.0) if speed > 0.0 else Vector2.ZERO
			await create_timer(0.07).timeout
			var q := p.position
			cam.global_position = Vector3(q.x + 0.3, 1.3, q.z + 4.2)
			cam.look_at(Vector3(q.x + 0.3, 0.9, q.z), Vector3.UP)
			await process_frame
			root.get_texture().get_image().save_png("%s%s_%d.png" % [out, case[0], n])
		if p.position.x > 40.0:
			pass
	quit()
