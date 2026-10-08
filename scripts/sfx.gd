class_name Sfx
extends Node
## Tiny voice pool for one-shot sound effects, plus the sound of each location.
## Racket hits and ball bounces are real recordings (several takes each, picked at
## random so consecutive sounds never repeat); the rest are procedural (tools/gen_sfx.py).
##
## A location sounds in two layers:
##   amb_<id>.ogg          the bed: a seamless one-minute loop (the park falls back to
##                         birds.ogg). Mono, levelled to -23 LUFS by tools/prep_audio.py.
##   amb_<id>_<what>.ogg   accents (ACCENTS below): a bell, a ship's horn, a gull. Each
##                         is placed in the world and pans with the camera, and comes
##                         back at random intervals, so the one-minute loop never feels
##                         like a loop. A missing file is simply skipped.
## The bed sits back during a rally and under the menu music and comes forward between
## points. Every voice is a stream mixed by the engine (see _voice()), the same way the
## music always played; strokes and ambience go to the Master bus.
##
## Other drop-in sounds: any name, e.g. coin.ogg, reward.ogg, applause.ogg,
## crowd_ooh.ogg, music_menu.ogg: play("coin") finds assets/sfx/coin.ogg (or .wav/.mp3).
##
## Keep beds at about a minute, mono: OGG is decoded on the fly while it plays.
##
## Loading: the music, the beds and the accents (is_lazy()) are most of the game's
## megabytes but nothing needs them in the first second. The web export leaves them out
## of the game pack (export_presets.cfg, exclude_filter) and tools/build_web.sh puts
## them next to the page in sfx/; here they are downloaded when a location or the menu
## first asks for one, and start playing the moment they arrive. Everywhere else
## (desktop, tests) they are simply loaded from res://.

const NAMES := ["bounce", "net", "swing", "point", "miss"]
const HIT_TAKES := ["hit_real_1", "hit_real_2", "hit_real_3"]
const BOUNCE_TAKES := ["bounce_real_1", "bounce_real_2", "bounce_real_3", "bounce_real_4"]

const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"
const BUS_EFFECTS := "Effects"

const BED_DB := -5.0          # the bed between points (beds are -20 LUFS, lows cut for phone speakers)
const DUCK_RALLY_DB := -2.0   # during a rally: the ball and the racket come first
const DUCK_MENU_DB := -7.0    # under the menu music
const DUCK_SPEED := 4.0       # dB per second, slow enough not to be noticed

## Accents of each location: where the sound comes from (world position, the camera
## looks toward -Z), when it first plays (s after arriving) and how often it returns.
## Volumes are relative to files levelled by tools/prep_audio.py (-20 LUFS one-shots).
## Rare and far is the rule: an accent you notice every minute stops being alive. The bells
## (owner, 09.10: too frequent) ring first after 2..4 minutes and then every 7..12, 3 dB softer.
const ACCENTS := {
	"park": [
		# East River Park: the city across the water, boats, a playground somewhere behind.
		{"sound": "amb_park_horn", "pos": Vector3(70.0, 6.0, -150.0), "first": [20.0, 45.0], "every": [70.0, 140.0], "db": -12.0},
		{"sound": "amb_park_ship", "pos": Vector3(-80.0, 0.0, -110.0), "first": [40.0, 80.0], "every": [120.0, 220.0], "db": -10.0},
		{"sound": "amb_park_siren", "pos": Vector3(120.0, 10.0, -200.0), "first": [60.0, 120.0], "every": [180.0, 320.0], "db": -15.0},
		{"sound": "amb_park_kids", "pos": Vector3(-45.0, 1.0, 30.0), "first": [15.0, 35.0], "every": [90.0, 180.0], "db": -14.0},
		{"sound": "amb_pigeons", "pos": Vector3(18.0, 3.0, -25.0), "first": [30.0, 70.0], "every": [80.0, 160.0], "db": -6.0},
	],
	"clay": [
		# A club on the seafront: gulls over the water, the beach below, the village behind.
		{"sound": "amb_clay_gull", "pos": Vector3(-30.0, 15.0, -70.0), "first": [8.0, 20.0], "every": [25.0, 60.0], "db": -10.0},
		{"sound": "amb_clay_bell", "pos": Vector3(60.0, 20.0, -120.0), "first": [120.0, 240.0], "every": [420.0, 720.0], "db": -14.0},
		{"sound": "amb_clay_kids", "pos": Vector3(-25.0, -2.0, -60.0), "first": [20.0, 40.0], "every": [90.0, 170.0], "db": -15.0},
		{"sound": "amb_clay_chimes", "pos": Vector3(22.0, 3.0, -30.0), "first": [12.0, 30.0], "every": [60.0, 120.0], "db": -12.0},
	],
	"grass": [
		# The clock tower of the town across the street (scenery_grass.gd).
		{"sound": "amb_grass_bell", "pos": Vector3(-32.0, 24.0, -104.0), "first": [120.0, 240.0], "every": [420.0, 720.0], "db": -9.0},
		{"sound": "amb_grass_crow", "pos": Vector3(20.0, 12.0, -20.0), "first": [15.0, 35.0], "every": [50.0, 110.0], "db": -11.0},
		{"sound": "amb_pigeons", "pos": Vector3(-14.0, 4.0, -28.0), "first": [40.0, 80.0], "every": [90.0, 170.0], "db": -6.0},
		{"sound": "amb_grass_bus", "pos": Vector3(25.0, 2.0, -30.0), "first": [25.0, 50.0], "every": [60.0, 120.0], "db": -11.0},
	],
}

## The next court of the club: now and then somebody plays a rally there, made of the
## same hit and bounce recordings, far to the side and quiet. Stops when ours starts,
## so it never muddles the player's timing.
const NEIGHBOR_X := {"park": 32.0, "clay": -30.0, "grass": 30.0}
const NEIGHBOR_EVERY := [35.0, 80.0]
const NEIGHBOR_HIT_DB := -21.0
const NEIGHBOR_BOUNCE_DB := -29.0

var rally := false            # set by the game every frame: a rally is being played
var plays := 0                # sounds started (the crash log reports it)

var _streams := {}
var _hits: Array[AudioStream] = []
var _bounces: Array[AudioStream] = []
var _last_hit := -1
var _last_bounce := -1
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: AudioStreamPlayer
var _ambience_on := false
var _location := "park"
var _fade := 1.0              # crossfade between locations, 0..1
var _duck := 0.0              # current duck of the bed (dB), eases toward its target
var _amb_db := 0.0            # the bed volume last sent to the player
var _accents: Array[Dictionary] = []   # {player, timer, every, db}
var _neighbor: Array[AudioStreamPlayer] = []
var _neighbor_next := 0
var _neighbor_timer := 20.0
var _neighbor_shots := 0      # shots left in the rally on the next court
var _neighbor_side := 1.0
var _music: AudioStreamPlayer
var _crowd: AudioStreamPlayer     # the stands have a voice of their own (see crowd())
var _crowd_tw: Tween
var _music_wanted := false
var _music_enabled := true
var _rng := RandomNumberGenerator.new()
var _pending := {}            # sound -> true while it downloads
var _bed_location := "park"   # the location whose bed the bed player holds


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for bus in [BUS_MUSIC, BUS_AMBIENCE, BUS_EFFECTS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for n in NAMES:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for n in HIT_TAKES:
		_hits.append(load("res://assets/sfx/%s.wav" % n))
	for n in BOUNCE_TAKES:
		_bounces.append(load("res://assets/sfx/%s.wav" % n))
	for i in 10:
		var p := _voice()
		add_child(p)
		_players.append(p)
	for i in 3:
		var n := _far_player()
		add_child(n)
		_neighbor.append(n)
	_ambience = _voice()
	_ambience.stream = _bed_for(_location)
	_ambience.volume_db = BED_DB
	add_child(_ambience)
	_build_accents()
	_crowd = _voice()
	add_child(_crowd)


func _process(delta: float) -> void:
	# Real time: slow-motion must not slow the fades or the bell.
	var dt := delta / maxf(Engine.time_scale, 0.05)
	var target := DUCK_RALLY_DB if rally else 0.0
	if _music != null and _music_wanted and _music_enabled:
		target = minf(target, DUCK_MENU_DB)
	_duck = move_toward(_duck, target, DUCK_SPEED * dt)
	var db := BED_DB + _duck + linear_to_db(maxf(_fade, 0.001))
	if absf(db - _amb_db) > 0.01:
		_amb_db = db
		_ambience.volume_db = db
	if not _ambience_on:
		return
	for a in _accents:
		a["timer"] -= dt
		if a["timer"] <= 0.0:
			var every: Array = a["every"]
			a["timer"] = _rng.randf_range(every[0], every[1])
			var p: AudioStreamPlayer = a["player"]
			p.volume_db = float(a["db"]) + 3.0 + _duck + _rng.randf_range(-2.0, 1.0)
			p.pitch_scale = _rng.randf_range(0.97, 1.03)
			p.play()
	_update_neighbor(dt)


func _update_neighbor(dt: float) -> void:
	if rally or not NEIGHBOR_X.has(_location):
		_neighbor_shots = 0  # our point starts: theirs ends
		return
	_neighbor_timer -= dt
	if _neighbor_timer > 0.0:
		return
	if _neighbor_shots <= 0:
		_neighbor_shots = _rng.randi_range(4, 12)
		_neighbor_side = 1.0 if _rng.randf() < 0.5 else -1.0
	var x: float = NEIGHBOR_X[_location]
	var pace := _rng.randf_range(0.95, 1.35)  # seconds between hits on that court
	_far_play(_hits[_rng.randi() % _hits.size()], Vector3(x, 1.0, 11.0 * _neighbor_side), NEIGHBOR_HIT_DB, 0.0)
	_far_play(_bounces[_rng.randi() % _bounces.size()], Vector3(x, 0.0, -6.0 * _neighbor_side), NEIGHBOR_BOUNCE_DB, pace * 0.55)
	_neighbor_side = -_neighbor_side
	_neighbor_shots -= 1
	_neighbor_timer = pace if _neighbor_shots > 0 else _rng.randf_range(NEIGHBOR_EVERY[0], NEIGHBOR_EVERY[1])


func _far_play(stream: AudioStream, pos: Vector3, db: float, delay: float) -> void:
	var p := _neighbor[_neighbor_next]
	_neighbor_next = (_neighbor_next + 1) % _neighbor.size()
	if delay > 0.0:
		get_tree().create_timer(delay, true, false, true).timeout.connect(func() -> void:
			if _ambience_on and not rally:
				_far_start(p, stream, pos, db))
	else:
		_far_start(p, stream, pos, db)


func _far_start(p: AudioStreamPlayer, stream: AudioStream, pos: Vector3, db: float) -> void:
	p.stream = stream
	p.volume_db = db + _rng.randf_range(-2.0, 1.5)
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.play()


## A far-away voice: no fall-off with distance, only the direction (panning) matters.
func _far_player() -> AudioStreamPlayer:
	# Plain (not positional) players: on the web every positional play built new Web
	# Audio nodes, and with the next court hitting every second the page's memory grew
	# until iOS killed it after about two minutes. The world positions in ACCENTS stay
	# as documentation of where each sound lives.
	return _voice()


## Every voice streams: the engine mixes it, like the music. As Web Audio samples (the
## web default) each play copied the whole sound and built a worklet and ~10 audio nodes:
## on iPhone the strokes stayed silent and the page was killed within a few minutes.
## The project sets the same for the web (audio/general/default_playback_type.web).
static func _voice(bus := "Master") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	return p


func set_ambience(on: bool) -> void:
	_ambience_on = on
	if on and not _ambience.playing and _ambience.stream != null:
		_ambience.play()
	elif not on:
		_ambience.stop()
		for a in _accents:
			(a["player"] as AudioStreamPlayer).stop()


## The sound of a location: crossfades the bed, swaps the accents.
func set_location(id: String) -> void:
	if id == _location:
		return
	var old := _location
	_location = id
	var stream := _bed_for(id)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "_fade", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		_ambience.stop()
		_ambience.stream = _bed_for(id) if stream == null else stream  # it may have arrived meanwhile
		_bed_location = id
		_build_accents()
		_forget(old)
		if _ambience_on and _ambience.stream != null:
			_ambience.play())
	tw.tween_property(self, "_fade", 1.0, 1.2)


func _bed_for(id: String) -> AudioStream:
	var s := _stream_for("amb_" + id)
	if s == null and id == "park" and not _pending.has("amb_park"):
		s = _stream_for("birds")
	_set_loop(s)
	return s


## Lets go of the sounds of a location we left, so they can be freed instead of piling
## up in the browser's memory as the player travels.
func _forget(id: String) -> void:
	var keep := ["amb_" + _location]
	for spec in ACCENTS.get(_location, []):
		keep.append(spec["sound"])
	var drop := ["amb_" + id, "birds" if id == "park" else ""]
	for spec in ACCENTS.get(id, []):
		drop.append(spec["sound"])
	for sound in drop:
		if sound != "" and not sound in keep:
			_streams.erase(sound)


func _build_accents() -> void:
	for a in _accents:
		(a["player"] as Node).queue_free()
	_accents.clear()
	_neighbor_shots = 0
	_neighbor_timer = _rng.randf_range(12.0, 30.0)
	for spec in ACCENTS.get(_location, []):
		var s := _stream_for(spec["sound"])
		if s == null:
			continue
		var p := _far_player()
		p.stream = s
		add_child(p)
		var first: Array = spec["first"]
		_accents.append({"player": p, "timer": _rng.randf_range(first[0], first[1]), "every": spec["every"], "db": spec["db"]})


## Menu music (assets/sfx/music_menu.ogg if present): fades in on menus, out in matches.
func set_music(on: bool) -> void:
	_music_wanted = on
	_update_music()


## The settings toggles: menu music, and the whole ambience bus.
func set_music_enabled(on: bool) -> void:
	_music_enabled = on
	_update_music()


## Temporary (owner's request, 08.10): no menu music in the build while the club is being
## tested on phones. Flip back to true to restore the settings toggle's effect.
const MUSIC_IN_BUILD := false


func _update_music() -> void:
	var on := _music_wanted and _music_enabled and MUSIC_IN_BUILD
	if _music == null:
		if not on:
			return
		var s := _stream_for("music_menu")
		if s == null:
			return
		_set_loop(s)
		_music = _voice(BUS_MUSIC)
		_music.stream = s
		_music.volume_db = -40.0
		add_child(_music)
	var tw := create_tween().set_ignore_time_scale(true)
	if on:
		if not _music.playing:
			_music.play()
		tw.tween_property(_music, "volume_db", -10.0, 1.0)
	else:
		tw.tween_property(_music, "volume_db", -40.0, 0.8)
		tw.tween_callback(_music.stop)


static func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)


## True if a sound exists (built in or dropped into assets/sfx/).
func has(sound: String) -> bool:
	return sound in ["hit", "hit_perfect", "bounce"] or _stream_for(sound) != null


func _stream_for(sound: String) -> AudioStream:
	if _pending.has(sound):
		return null
	if _streams.has(sound):
		return _streams[sound]
	var s: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/sfx/%s.%s" % [sound, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s == null and is_lazy(sound) and OS.has_feature("web"):
		_download(sound)
		return null
	_streams[sound] = s
	return s


## Sounds the web build downloads after the start instead of packing them (see the top).
static func is_lazy(sound: String) -> bool:
	return sound.begins_with("amb_") or sound.begins_with("music_") or sound == "birds"


func _download(sound: String) -> void:
	_pending[sound] = true
	var base := String(JavaScriptBridge.eval("location.href.split('#')[0].split('?')[0].replace(/[^/]*$/, '')", true))
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var s: AudioStream = null
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			s = AudioStreamOggVorbis.load_from_buffer(body)
		_arrived(sound, s))
	if req.request(base + "sfx/%s.ogg" % sound) != OK:
		req.queue_free()
		_arrived(sound, null)


## A downloaded sound: kept if this location or the menu still wants it, and started
## where it belongs. null = it could not be had (the game simply goes without it).
func _arrived(sound: String, s: AudioStream) -> void:
	_pending.erase(sound)
	_streams[sound] = s
	if s == null:
		return
	if sound.begins_with("music_"):
		_update_music()
		return
	var accent: bool = ACCENTS.get(_location, []).any(func(spec: Dictionary) -> bool: return spec["sound"] == sound)
	var bed := sound == "amb_" + _location or (sound == "birds" and _location == "park")
	if not bed and not accent:
		_streams.erase(sound)  # the player has moved on
	elif _bed_location != _location:
		pass  # the location change's fade is under way: it picks the sound up itself
	elif bed and _ambience.stream == null:
		_ambience.stream = _bed_for(_location)
		if _ambience_on:
			_ambience.play()
	elif accent:
		_build_accents()


## The stands: applause, an "ooh". Their own voice, so the next point's dribbles and
## strokes never steal it from the pool and cut it dead.
func crowd(sound: String, volume_db := 0.0) -> void:
	var s := _stream_for(sound)
	if s == null:
		return
	if _crowd_tw:
		_crowd_tw.kill()
	_crowd.stream = s
	_crowd.volume_db = volume_db
	_crowd.play()
	plays += 1


## The next point is getting ready: whatever the stands still do dies away over two
## seconds (a fall in dB, which the ear hears as an even fade) instead of stopping dead.
func settle_crowd() -> void:
	if not _crowd.playing or (_crowd_tw and _crowd_tw.is_running()):
		return
	_crowd_tw = create_tween().set_ignore_time_scale(true)
	_crowd_tw.tween_property(_crowd, "volume_db", _crowd.volume_db - 35.0, 2.0)
	_crowd_tw.tween_callback(_crowd.stop)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStream
	if sound == "hit" or sound == "hit_perfect":
		# A different take each time; a perfect hit is fuller: louder and a touch lower.
		var i := randi() % _hits.size()
		if i == _last_hit:
			i = (i + 1) % _hits.size()
		_last_hit = i
		stream = _hits[i]
		if sound == "hit_perfect":
			volume_db += 3.0
			pitch *= 0.94
	elif sound == "bounce":
		var j := randi() % _bounces.size()
		if j == _last_bounce:
			j = (j + 1) % _bounces.size()
		_last_bounce = j
		stream = _bounces[j]
	else:
		stream = _stream_for(sound)
		if stream == null:
			return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	plays += 1
