extends SceneTree
## Location sound and graphics presets, without a sound card or a GPU:
##   godot --headless --path . -s tests/audio_test.gd

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


## A timer fires at the start of a frame, BEFORE that frame's tweens and _process calls run, and
## under load one frame can be longer than the whole wait: two more frames let the things the
## wait was for (a fade's callback, a smoothed volume, a timer in _process) catch up.
func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
	await process_frame
	await process_frame


## Waits for a state, not for a time (a stream swap after a fade, a bell after its timer): asks
## again every 50 ms for up to `limit` s; the check after it is as strict as before.
func _until(cond: Callable, limit := 10.0) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await create_timer(0.05, true, false, true).timeout
		t += 0.05


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("location beds")
	for id in ["park", "clay", "grass"]:
		var path := "res://assets/sfx/amb_%s.ogg" % id
		if id == "park" and not ResourceLoader.exists(path):
			path = "res://assets/sfx/birds.ogg"
		var s: AudioStream = load(path)
		_check(s != null, "%s: %s loads" % [id, path.get_file()])
		if s:
			var len_s := s.get_length()
			_check(len_s >= 30.0 and len_s <= 75.0, "%s: bed is %.0f s (30..75 s keeps browser memory low)" % [id, len_s])

	print("no helicopter")
	# 10.10: the park / club bed carried one (tools/rebed_park.py); nothing named so may come back.
	var dir := DirAccess.open("res://assets/sfx")
	var bad := 0
	for f in dir.get_files():
		var fl := f.to_lower()
		if fl.contains("heli") or fl.contains("rotor") or fl.contains("chopper") or fl.contains("plane"):
			bad += 1
	_check(bad == 0, "no helicopter / plane sound files in assets/sfx")
	for loc in Sfx.ACCENTS:
		for spec in Sfx.ACCENTS[loc]:
			var snd: String = spec["sound"]
			var sl := snd.to_lower()
			_check(not (sl.contains("heli") or sl.contains("rotor") or sl.contains("chopper") or sl.contains("plane")), "%s accent %s is not a helicopter" % [loc, snd])

	var sfx := Sfx.new()
	root.add_child(sfx)
	await process_frame
	for bus in [Sfx.BUS_MUSIC, Sfx.BUS_AMBIENCE, Sfx.BUS_EFFECTS]:
		_check(AudioServer.get_bus_index(bus) > 0, "bus %s exists" % bus)

	print("switching to London")
	sfx.set_ambience(true)
	sfx.set_location("grass")
	var amb: AudioStreamPlayer = sfx._ambience
	await _until(func() -> bool: return amb.stream != null and amb.stream.resource_path.ends_with("amb_grass.ogg") and not sfx._accents.is_empty())
	_check(amb.stream != null and amb.stream.resource_path.ends_with("amb_grass.ogg"), "bed swapped to amb_grass.ogg")
	_check((amb.stream as AudioStreamOggVorbis).loop, "bed loops")
	_check(amb.bus == "Master", "bed plays on Master")
	var bell: Dictionary = {}
	for a in sfx._accents:
		if (a["player"] as AudioStreamPlayer).stream.resource_path.ends_with("amb_grass_bell.ogg"):
			bell = a
	_check(not bell.is_empty(), "the clock tower bell is an accent")
	if not bell.is_empty():
		_check(float(bell["timer"]) >= 120.0 and float(bell["timer"]) <= 240.0, "the first bell comes after 2..4 minutes (%.0f s left)" % bell["timer"])
		bell["timer"] = 0.05
		await _until(func() -> bool: return float(bell["timer"]) >= 420.0)
		_check(float(bell["timer"]) >= 420.0, "after ringing, the next bell is 7+ minutes away (%.0f s)" % bell["timer"])

	print("ducking")
	await _wait(2.5)
	var open_db := amb.volume_db
	sfx.rally = true
	await _wait(1.5)
	_check(amb.volume_db < open_db - 1.5, "bed sits back during a rally (%.1f -> %.1f dB)" % [open_db, amb.volume_db])
	sfx.rally = false
	await _wait(1.5)
	_check(absf(amb.volume_db - open_db) < 0.5, "and comes back between points (%.1f dB)" % amb.volume_db)

	print("toggles")
	sfx.set_ambience(false)
	_check(not amb.playing, "ambience off stops the bed")
	sfx.set_location("clay")
	await _until(func() -> bool: return amb.stream != null and amb.stream.resource_path.ends_with("amb_clay.ogg"))
	_check(amb.stream.resource_path.ends_with("amb_clay.ogg") and not amb.playing, "a location change while off stays silent")
	sfx.set_ambience(true)
	_check(amb.playing, "ambience on plays the sea")

	print("the next court")
	sfx.set_location("grass")
	await _until(func() -> bool: return sfx._bed_location == "grass" and not sfx._streams.has("amb_clay"))
	_check(not sfx._streams.has("amb_clay") and not sfx._streams.has("amb_clay_gull"), "leaving Spain lets its sounds go")
	sfx._neighbor_timer = 0.0
	await _wait(0.1)
	# The real hits are 50-90 ms long, so "still playing" can't be the check: the rally has
	# shots left and the next one is scheduled (the first hit already went out).
	_check(sfx._neighbor_shots > 0 and sfx._neighbor_timer > 0.0 and sfx._neighbor.any(func(p: AudioStreamPlayer) -> bool: return p.stream != null), "a rally starts on the next court")
	sfx.rally = true
	await _wait(0.1)
	_check(sfx._neighbor_shots == 0, "and stops when our point starts")
	sfx.rally = false

	print("the stands")
	sfx.crowd("applause", -6.0)
	for i in 14:
		sfx.play("bounce" if i % 2 else "hit")  # the next point's dribbles and strokes
	await _wait(0.2)
	_check(sfx._crowd.playing, "strokes and bounces never cut the applause")
	sfx.settle_crowd()
	await _wait(1.0)
	_check(sfx._crowd.playing and sfx._crowd.volume_db < -12.0, "it dies away when the next serve gets ready (%.0f dB)" % sfx._crowd.volume_db)
	await _wait(1.3)
	_check(not sfx._crowd.playing, "and is gone two seconds later")

	print("downloaded later")
	# On the web the music, beds and accents are not in the game pack: they download after
	# the start. Simulated here: the London bed is "on its way" while we travel there.
	sfx.set_location("clay")
	await _until(func() -> bool: return sfx._bed_location == "clay")
	sfx._pending["amb_grass"] = true
	sfx._streams.erase("amb_grass")
	sfx.set_location("grass")
	await _until(func() -> bool: return sfx._bed_location == "grass")
	_check(amb.stream == null and not amb.playing, "London without its bed while it downloads")
	sfx._arrived("amb_grass", load("res://assets/sfx/amb_grass.ogg"))
	_check(amb.stream != null and amb.stream.resource_path.ends_with("amb_grass.ogg") and amb.playing, "the bed starts the moment it arrives")
	sfx._pending["amb_clay_gull"] = true
	sfx._arrived("amb_clay_gull", load("res://assets/sfx/amb_clay_gull.ogg"))
	_check(not sfx._streams.has("amb_clay_gull"), "a sound of a location we left is let go")
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var excluded := String(cfg.get_value("preset.0", "exclude_filter", "")).split(",")
	var lazy_ok := true
	for f in DirAccess.get_files_at("res://assets/sfx"):
		if f.get_extension() == "ogg" and Sfx.is_lazy(f.get_basename()):
			var out := false
			for pat in excluded:
				out = out or ("assets/sfx/" + f).match(pat.strip_edges())
			lazy_ok = lazy_ok and out
	_check(lazy_ok, "the web pack leaves out every downloaded sound (exclude_filter)")
	_check(not Sfx.is_lazy("hit_real_1") and not Sfx.is_lazy("applause") and not Sfx.is_lazy("click"),
		"strokes, crowd and UI stay in the pack: they play in the first seconds")

	print("racket hits")
	_check(Sfx.HIT_TAKES.size() == 13, "13 hit takes (3 Pixabay + 10 cut from a match)")
	var in_group := {}
	for g in Sfx.HIT_GROUPS:
		_check((Sfx.HIT_GROUPS[g] as Array).size() >= 3, "%s: at least 3 takes to alternate" % g)
		for n in Sfx.HIT_GROUPS[g]:
			in_group[n] = true
			_check(Sfx.HIT_TAKES.has(n), "%s: %s is a take" % [g, n])
	_check(in_group.size() == Sfx.HIT_TAKES.size(), "every take plays in some group")
	for n in Sfx.HIT_TAKES:
		var take: AudioStreamWAV = load("res://assets/sfx/%s.wav" % n)
		_check(take != null and take.get_length() > 0.03 and take.get_length() < 0.4, "%s: %.0f ms, loads" % [n, take.get_length() * 1000.0])
	_check(Sfx.hit_group({"serve": true, "top": -300.0}) == "power", "a serve is power")
	_check(Sfx.hit_group({"top": 40.0}) == "power", "a flat shot is power")
	_check(Sfx.hit_group({"top": 350.0}) == "spin", "topspin is spin")
	_check(Sfx.hit_group({"top": -200.0}) == "soft" and Sfx.hit_group({"drop": true, "top": 300.0}) == "soft" and Sfx.hit_group({"lob": true}) == "soft", "slice, drop and lob are soft")
	for g in ["power", "spin", "soft"]:
		sfx._shot_group = g
		sfx.play("hit")
		_check(sfx._shot_group == "", "%s: the stroke is spent by its hit" % g)
	sfx._shot_group = "soft"
	var before: int = sfx.plays
	sfx.play("hit_perfect")
	_check(sfx.plays == before + 1, "a perfect hit plays from a group too")

	print("web playback")
	# Web Audio samples (the web default) copied the whole sound, built ~10 audio nodes
	# and a worklet on every play: on iPhone the strokes stayed silent and the page was
	# killed after a couple of minutes. Streams go through the mixer the music uses.
	_check(ProjectSettings.get_setting("audio/general/default_playback_type.web") == 0,
		"the web build plays sounds as streams, not samples")
	sfx.set_music(true)
	sfx.play("hit")
	var players := sfx.find_children("*", "AudioStreamPlayer", true, false)
	var sampled := players.filter(func(p: AudioStreamPlayer) -> bool:
		return p.playback_type != AudioServer.PLAYBACK_TYPE_STREAM)
	_check(players.size() >= 15 and sampled.is_empty(), "all %d players stream (%d would be samples)" % [players.size(), sampled.size()])
	sfx.set_music(false)

	print("graphics presets")
	var g := GraphicsQuality.new()
	var sc := Scenery.new()
	root.add_child(sc)
	g.scenery = sc
	root.add_child(g)
	await process_frame
	var reach := {}
	for p in [GraphicsQuality.LOW, GraphicsQuality.MEDIUM, GraphicsQuality.HIGH, GraphicsQuality.MAX, GraphicsQuality.AUTO]:
		g.set_preset(p)
		reach[p] = sc.sun().directional_shadow_max_distance
		print("       %s: 3D x%.2f, msaa %d, shadows to %.0f m" % [GraphicsQuality.NAMES[p], g.scale_3d, root.msaa_3d, reach[p]])
	_check(reach[GraphicsQuality.MAX] > reach[GraphicsQuality.HIGH] and reach[GraphicsQuality.HIGH] > reach[GraphicsQuality.LOW], "shadows reach further with each preset")
	g.set_preset(GraphicsQuality.MAX)
	_check(is_equal_approx(g.scale_3d, 1.0) and root.msaa_3d == Viewport.MSAA_4X, "Max: native resolution, 4x MSAA")
	g.set_preset(GraphicsQuality.AUTO)
	_check(g.level == GraphicsQuality.HIGH, "Auto starts at High")
	var tuning := root.get_node("Tuning")
	tuning.gfx_shadows = 0
	tuning.gfx_res = 0.6
	tuning.gfx_aa = 0
	g.set_preset(GraphicsQuality.CUSTOM)
	_check(not sc.sun().shadow_enabled and is_equal_approx(g.scale_3d, 0.6) and root.msaa_3d == Viewport.MSAA_DISABLED, "Своя: shadows off, 60% sharpness, no MSAA")
	tuning.gfx_shadows = 3
	g.set_preset(GraphicsQuality.CUSTOM)
	_check(sc.sun().shadow_enabled, "Своя re-applies on every change: shadows back on")
	g.set_preset(GraphicsQuality.LOW)
	_check(sc.sun().shadow_enabled and tuning.gfx_shadows == 1 and tuning.gfx_aa == 0, "a preset fills the manual parts in (Низкая: hard shadows, no MSAA)")

	print("\nAUDIO TEST " + ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	quit(1 if _fails else 0)
