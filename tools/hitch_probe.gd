extends SceneTree
## Hitch probe (hotfix F-B): the longest frame in the places a phone stutters - walking the
## club among people, the club opening, a chest, loot on the opponent, the knocked-out
## racket, the loot card. Real render (the same GL as the web), so run it on a display:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/hitch_probe.gd \
##       [-- --only=walk,enter,chest,opp,drop,card] [--size=1280] [--gfx=1] [--runs=2]
## Prints per scenario: median frame, the worst frames (ms, and how many frames into the
## scenario they came), so a one-off spike stands out from a slow machine. A frame is the
## wall time between two frames (script + render), a shader compile or a body build is in it.
## Scenarios are run in the order given; "first time" costs only show in the first run of a
## kind of thing, so use --only to look at one thing on a fresh start. Never writes the save.

const SPIKE_MS := 50.0

var main: Node
var h := 1280
var gfx := -1
var only: Array = []
var runs := 2
var report: Array = []
var _last_us := 0
var _meter: PerfMeter
var cpu: Array = []     # script ms of each frame in the last _frames() run (PerfMeter, first _process to last)
var call_ms := 0.0      # what the `at` callables took in the last _frames() run (the scenario's own work, a build, a set_gear)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--gfx="):
			gfx = int(a.get_slice("=", 1))
		elif a.begins_with("--only="):
			only = a.get_slice("=", 1).split(",")
		elif a.begins_with("--runs="):
			runs = int(a.get_slice("=", 1))
	_run.call_deferred()


func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)


## Frames for `secs`; `at` = {frame: Callable} run just before that frame. Returns the list
## of frame times in ms.
func _frames(secs: float, at := {}) -> Array:
	var out: Array = []
	cpu = []
	call_ms = 0.0
	var t := 0.0
	var f := 0
	await process_frame
	_meter.take()
	_last_us = Time.get_ticks_usec()
	while t < secs:
		if at.has(f):
			var c0 := Time.get_ticks_usec()
			(at[f] as Callable).call()
			call_ms = maxf(call_ms, (Time.get_ticks_usec() - c0) / 1000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - _last_us) / 1000.0
		_last_us = now
		out.append(ms)
		cpu.append(float(_meter.take().get("cpu", 0.0)))
		t += ms / 1000.0
		f += 1
	return out


## Frames until `done` is true (at most `max_secs`).
func _frames_until(done: Callable, max_secs: float) -> Array:
	var out: Array = []
	cpu = []
	var t := 0.0
	await process_frame
	_meter.take()
	_last_us = Time.get_ticks_usec()
	while t < max_secs and not done.call():
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - _last_us) / 1000.0
		_last_us = now
		out.append(ms)
		cpu.append(float(_meter.take().get("cpu", 0.0)))
		t += ms / 1000.0
	return out


func _summary(name: String, fr: Array) -> void:
	var sorted := fr.duplicate()
	sorted.sort()
	var med: float = sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0
	var worst: Array = []
	for i in fr.size():
		if fr[i] > maxf(SPIKE_MS, med * 2.5):
			worst.append("%.0f@%d(cpu %.0f)" % [fr[i], i, cpu[i] if i < cpu.size() else -1.0])
	var top: float = sorted.back() if not sorted.is_empty() else 0.0
	for i in cpu.size():
		if cpu[i] > 20.0 and not worst.has("%.0f@%d(cpu %.0f)" % [fr[i], i, cpu[i]]):
			worst.append("[script %.0f@%d]" % [cpu[i], i])
	var line := "%-34s frames %4d  median %5.1f ms  worst %6.1f ms  call %5.0f ms  spikes: %s" % [name, fr.size(), med, top, call_ms, ", ".join(worst) if not worst.is_empty() else "-"]
	print(line)
	report.append([name, med, top])


func _boot() -> void:
	_meter = PerfMeter.new()
	root.add_child(_meter)
	root.size = Vector2i(h * 720 / 1564, h)
	SaveData.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if "--nowarm" in OS.get_cmdline_user_args() and main.get_node_or_null("ShaderWarm") != null:
		main.get_node("ShaderWarm").free()   # the A of an A/B: no loot shaders compiled at the boot
	await create_timer(3.0).timeout
	for i in 120:
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
	SaveData.control_chosen = true
	SaveData.played = 1
	SaveData.titles = 0
	SaveData.club = {"met_coach": true, "walk_hint": true, "hire_hint": true, "lots": {"n7": "academy"}, "levels": {"academy": 3}}
	SaveData.active = null
	SaveData.run = {}
	SaveData.academy = {}
	Skills.points = 0
	Skills.pending = []
	ClubDaytime.force_hour = 11.0


func _students(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in n:
		var st: Dictionary = JuniorGen.make(rng, 1)
		st["id"] = "s%d" % (i + 1)
		st["age0"] = 10 + i * 4
		st["since"] = SaveData.played
		Academy.students().append(st)
	Academy.data()["free_given"] = true
	Academy.data()["trained_at"] = SaveData.played


func _run() -> void:
	await _boot()
	print("hitch probe: loot pictures drawn at the boot: %d (failed %d), ShaderWarm still there: %s" % [ItemThumb.renders, ItemThumb.failed, main.get_node_or_null("ShaderWarm") != null])
	print("hitch probe: window %dx%d, gfx %d" % [root.size.x, root.size.y, main.graphics.preset if "preset" in main.graphics else -1])
	# The boot: how long frames are right after the loading screen goes.
	_summary("idle after boot (menu over club)", await _frames(2.0))
	if _want("enter"):
		await _enter()
	if _want("walk"):
		await _walk()
	if _want("travel"):
		await _travel()
	if _want("route"):
		await _route()
	if _want("pack"):
		await _pack()
	if _want("light"):
		await _light()
	if _want("swap"):
		await _swap()
	if _want("build"):
		await _build()
	if _want("chest"):
		await _chest()
	if _want("opp"):
		await _opp()
	if _want("drop"):
		await _drop()
	if _want("card"):
		await _card()
	var w := 0.0
	for r in report:
		w = maxf(w, r[2])
	print("HITCH WORST %.0f ms" % w)
	quit(0)


## The club, closed and opened again (the way back from a match or a screen).
func _enter() -> void:
	_students(3)
	for k in runs:
		main.club.close()
		main.set_location(Locations.LIST[0]["id"])
		_summary("enter: open the club #%d" % (k + 1), await _frames(2.5, {2: func() -> void: main._show_menu()}))


## Hero walks past the people: they turn from light figures into real bodies and back.
func _walk() -> void:
	_students(3)
	main.club.close()
	main.set_location(Locations.LIST[0]["id"])
	main._show_menu()
	await create_timer(1.0).timeout
	var club = main.club
	club.hud._bubble.visible = false
	var spots := [Vector3(-2.5, 0, 11.0), Vector3(2.5, 0, 9.0), Vector3(5.0, 0, 12.5), Vector3(-6.0, 0, 14.5)]
	var i := 0
	for n in club.npc_life.people():
		n.pos = spots[i % spots.size()]
		n.route = []
		n.dwell = 999.0
		n.activity = "train" if i % 2 == 0 else "idle"
		i += 1
	var far := Vector3(0.0, 0.0, 40.0)
	var near := Vector3(0.0, 0.0, 11.0)
	for k in runs:
		# far away -> straight into the middle of them (bodies appear), then away (they go).
		var fr: Array = await _frames(1.0, {0: func() -> void: main.player.position = far})
		_summary("walk: far, no bodies #%d" % (k + 1), fr)
		fr = await _frames(2.0, {0: func() -> void: main.player.position = near})
		_summary("walk: bodies appear #%d" % (k + 1), fr)
		fr = await _frames(2.0, {0: func() -> void: main.player.position = far})
		_summary("walk: bodies leave #%d" % (k + 1), fr)
	# A real walk in: ten metres a second is a sprint; one frame at a time.
	var steps: Array = []
	cpu = []
	_meter.take()
	var p := 40.0
	main.player.position = Vector3(0.0, 0.0, p)
	await process_frame
	_last_us = Time.get_ticks_usec()
	while p > 9.0:
		p -= 0.12
		main.player.position = Vector3(0.0, 0.0, p)
		await process_frame
		var now := Time.get_ticks_usec()
		steps.append((now - _last_us) / 1000.0)
		cpu.append(float(_meter.take().get("cpu", 0.0)))
		_last_us = now
	_summary("walk: approach step by step", steps)


## The hero runs between places across the club (the quick travel), people about.
func _travel() -> void:
	_students(3)
	main.club.close()
	main.set_location(Locations.LIST[0]["id"])
	main._show_menu()
	await create_timer(1.0).timeout
	var club = main.club
	club.hud._bubble.visible = false
	for k in runs:
		for id in ["court", "gate", "bar", "shop", "academy", "coach", "locker", "trophy", "arena"]:
			club._travel("gate" if k == 0 and id == "court" else id)
			await _frames(0.3)
			var far: String = {"court": "gate", "gate": "bar", "bar": "shop", "shop": "academy", "academy": "coach", "coach": "locker", "locker": "trophy", "trophy": "arena", "arena": "court"}[id]
			club.travel_run(far)
			var bodies := 0
			var fr: Array = await _frames_until(func() -> bool: return club.running_to() == "", 14.0)
			for n in club.npc_life.people():
				if n.body != null:
					bodies += 1
			_summary("travel: %s -> %s (bodies %d)" % [id, far, bodies], fr)


## Path finding on the club's walk grid, the time of one call (the people pick a stop and
## ask for a way; the hero's tap on the ground asks too).
func _route() -> void:
	main.club.close()
	main.set_location(Locations.LIST[0]["id"])
	main._show_menu()
	await create_timer(1.0).timeout
	var walk = main.club.world.walk
	if "--cold" not in OS.get_cmdline_user_args():
		await create_timer(12.0).timeout   # the club warms the graph while it is open (Club._process)
	print("route: %d waypoints, %d circles, %d boxes" % [walk.waypoints.size(), walk.circles.size(), walk.boxes.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	if "--check" in OS.get_cmdline_user_args():
		var bad := 0
		var crng := RandomNumberGenerator.new()
		crng.seed = 11
		for q in 600:
			var a2 := Vector2(crng.randf_range(-40, 40), crng.randf_range(-35, 45))
			var b2 := a2 + Vector2(crng.randf_range(-12, 12), crng.randf_range(-12, 12)) * (4.0 if q % 5 == 0 else 1.0)
			var ref := true
			var cnt := maxi(1, ceili(a2.distance_to(b2) / 0.25))
			for k in cnt + 1:
				if walk.blocked(a2.lerp(b2, float(k) / cnt)):
					ref = false
					break
			if ref != walk.clear(a2, b2):
				bad += 1
		print("route check: clear() against blocked() on 600 segments: %d differ" % bad)
	var worst := 0.0
	var total := 0.0
	var n := 0
	for i in 80:
		if i == 40:
			print("route: first 40 calls: mean %.1f ms, worst %.1f ms" % [total / n, worst])
			total = 0.0
			n = 0
			worst = 0.0
			rng.seed = 3
		var a := Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 36))
		var b := Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 36))
		var t0 := Time.get_ticks_usec()
		var r: Array = walk.route(a, b)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		total += ms
		n += 1
		if ms > 60.0:
			print("   slow route %d: %.0f ms (%s -> %s) %d points" % [i, ms, a, b, r.size()])
		if i < 40 and "--check" in OS.get_cmdline_user_args():
			var want := _ref_length(walk, a, b)
			var got := _length(a, r)
			if (want < 0.0) != r.is_empty() or (want >= 0.0 and absf(want - got) > 0.01):
				print("   ROUTE MISMATCH %d: reference %.3f, got %.3f" % [i, want, got])
	print("route: %d calls, mean %.1f ms, worst %.1f ms" % [n, total / n, worst])
	report.append(["route worst", total / n, worst])


## What making a real person costs the script (no render): a body from nothing, a new look on
## a body that exists, the gear put on. The numbers behind the club's "bodies appear" hitch.
func _build() -> void:
	main.club.close()
	main.set_location(Locations.LIST[0]["id"])
	main._show_menu()
	await create_timer(1.0).timeout
	var world = main.club.world
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 3:
		var t0 := Time.get_ticks_usec()
		var a := Athlete.new()
		world.add_child(a)
		a.setup(-1.0, Looks.DEFAULT.duplicate(), world.walk.bounds)
		var t1 := Time.get_ticks_usec()
		await process_frame
		var t2 := Time.get_ticks_usec()
		var look: Dictionary = Looks.DEFAULT.duplicate()
		look["shirt"] = Looks.nearest_kit(Color(rng.randf(), rng.randf(), rng.randf()))
		look["beard"] = 1
		a.set_look(look)
		await process_frame
		var t3 := Time.get_ticks_usec()
		a.set_gear([_item(Gear.EPIC), _item(Gear.MYTHIC)])
		await process_frame
		var t4 := Time.get_ticks_usec()
		print("build #%d: new+setup %.0f ms, next frame %.0f ms, set_look+frame %.0f ms, set_gear+frame %.0f ms" % [k, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0])
		a.queue_free()


## The scenery swap that entering the club is (a fresh ClubWorld built from code).
func _swap() -> void:
	for k in 3:
		main.club.close()
		var t0 := Time.get_ticks_usec()
		main.set_location("park")
		var t1 := Time.get_ticks_usec()
		await process_frame
		await process_frame
		var t2 := Time.get_ticks_usec()
		main.set_location("club")
		var t3 := Time.get_ticks_usec()
		await process_frame
		var t4 := Time.get_ticks_usec()
		await process_frame
		var t5 := Time.get_ticks_usec()
		print("swap #%d: to park %.0f ms (+2 frames %.0f), to club %.0f ms (+frame %.0f, +frame %.0f)" % [k, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0, (t5 - t4) / 1000.0])


## The model pack's arrival on the web (ClubPack._arrived, then ClubScenery redraws every prop):
## what each piece costs the script, and the frames around the redraw.
func _pack() -> void:
	main.club.close()
	main.set_location(Locations.LIST[0]["id"])
	main._show_menu()
	await create_timer(1.0).timeout
	var bytes := FileAccess.get_file_as_bytes(ClubPack.RES_PATH)
	var t0 := Time.get_ticks_usec()
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_buffer(bytes, "", st)
	var t1 := Time.get_ticks_usec()
	var scene := doc.generate_scene(st)
	var t2 := Time.get_ticks_usec()
	scene.free()
	print("pack: parse %.0f ms, generate_scene %.0f ms (%d bytes)" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, bytes.size()])
	var cs: ClubScenery = main.club.world.get_node("ClubScenery")
	for k in 3:
		var list := cs.props.visible(cs.level_of, true)
		var b0 := Time.get_ticks_usec()
		var baked := ClubProps.bake(list, true)
		var b1 := Time.get_ticks_usec()
		print("pack: bake %d props into %d squares: %.0f ms" % [list.size(), baked.size(), (b1 - b0) / 1000.0])
	for k in 2:
		var r0 := Time.get_ticks_usec()
		cs._refresh(false)
		print("pack: ClubScenery._refresh: %.0f ms" % [(Time.get_ticks_usec() - r0) / 1000.0])
	ClubPack.generation += 1
	_summary("pack: the club's frames at the arrival", await _frames(1.5))

## A light that was not there before, on the court (the knock-out racket used to carry one):
## every body and the court near it draw with another shader variant. `--nolight`: the same
## frames without the light, to tell the light from the noise.
func _light() -> void:
	main.club.close()
	main.set_location("park")
	main.player.position = Vector3(0, 0, 12.4)
	main.cpu.position = Vector3(0, 0, -8)
	await _frames(1.5)
	var node: Node3D = Node3D.new() if "--nolight" in OS.get_cmdline_user_args() else OmniLight3D.new()
	if node is OmniLight3D:
		(node as OmniLight3D).light_energy = 1.2
		(node as OmniLight3D).omni_range = 4.0
	main.add_child(node)
	node.global_position = Vector3(0.0, 1.0, 11.0)
	_summary("light: %s added near the player" % node.get_class(), await _frames(2.0))
	node.queue_free()
	_summary("light: %s removed" % node.get_class(), await _frames(1.5))


func _length(a: Vector2, r: Array) -> float:
	var l := 0.0
	var at := a
	for p in r:
		l += at.distance_to(p)
		at = p
	return l


## The shortest way by plain Dijkstra over every waypoint pair (the slow, sure way): -1 when none.
func _ref_length(walk, a: Vector2, b: Vector2) -> float:
	if walk.blocked(b):
		return -1.0
	if walk.clear(a, b):
		return a.distance_to(b)
	var nodes: Array = [a, b] + walk.waypoints
	var dist := {0: 0.0}
	var done := {}
	while true:
		var cur := -1
		for k in dist:
			if not done.has(k) and (cur < 0 or dist[k] < dist[cur]):
				cur = k
		if cur < 0:
			return -1.0
		if cur == 1:
			return dist[1]
		done[cur] = true
		for j in nodes.size():
			if j != cur and not done.has(j) and walk.clear(nodes[cur], nodes[j]):
				var nd: float = dist[cur] + (nodes[cur] as Vector2).distance_to(nodes[j])
				if not dist.has(j) or nd < dist[j]:
					dist[j] = nd
	return -1.0


func _item(rarity: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5 + rarity
	return Gear.roll(rarity, rng)


## Chest screen, every rarity inside.
func _chest() -> void:
	var t := Tournament.new(1, 11)
	main.tournament = t
	main.tournament_mode = true
	t.stage = 1
	for r in [Gear.EPIC, Gear.LEGENDARY, Gear.MYTHIC, Gear.EPIC]:
		var it := _item(r)
		t.chest = {"gold": 40, "item": it, "perk": "", "wildcard": false, "opened": false}
		var ui = main.ui
		var RunChestS = load("res://scripts/ui/screens/run_chest.gd")
		_summary("chest: closed, rarity %d" % r, await _frames(1.5, {0: func() -> void: RunChestS.show_chest(ui, t, false)}))
		t.chest["opened"] = true
		_summary("chest: opened + reveal, rarity %d" % r, await _frames(3.0, {0: func() -> void: RunChestS.show_chest(ui, t, true)}))
	main.ui.close()


## The opponent shown with loot: his racket (and the rest) put on.
func _opp() -> void:
	main.club.close()
	main.set_location("park")
	main.player.position = Vector3(0, 0, 12.4)
	main.cpu.position = Vector3(0, 0, -8)
	await _frames(1.0)
	var k := 0
	for r in [Gear.EPIC, Gear.LEGENDARY, Gear.MYTHIC, Gear.COMMON, Gear.RARE, Gear.EPIC, Gear.MYTHIC]:
		var it := _item(r)
		var items: Array = [it, _item(r), _item(r)]
		_summary("opp: set_gear rarity %d #%d" % [r, k], await _frames(1.2, {1: func() -> void: main.cpu.set_gear(items)}))
		k += 1


## The racket that flies out of the knocked-out opponent: its model, a light, a pickup.
func _drop() -> void:
	main.club.close()
	main.set_location("park")
	await _frames(1.0)
	var k := 0
	for r in [Gear.EPIC, Gear.LEGENDARY, Gear.MYTHIC, Gear.EPIC]:
		var it := _item(r)
		var holder: Array = [null]
		_summary("drop: knock-out racket rarity %d #%d" % [r, k], await _frames(1.5, {1: func() -> void:
			holder[0] = main._make_drop_racket(it)
			main.add_child(holder[0])
			holder[0].global_position = Vector3(0, 1.0, 0)
			main.cpu.set_racket({})
			main.player.set_racket(it)}))
		if is_instance_valid(holder[0]):
			holder[0].queue_free()
		k += 1


## The loot card with its picture (the thumbnail renders on first sight).
func _card() -> void:
	var t := Tournament.new(1, 11)
	main.tournament = t
	main.tournament_mode = true
	t.stage = 1
	ItemThumb.clear()
	var k := 0
	for r in [Gear.EPIC, Gear.LEGENDARY, Gear.MYTHIC, Gear.EPIC]:
		t.pending_loot = _item(r)
		var ui = main.ui
		_summary("card: loot card rarity %d #%d" % [r, k], await _frames(2.0, {0: func() -> void: ui.show_loot(t)}))
		k += 1
	main.ui.close()
