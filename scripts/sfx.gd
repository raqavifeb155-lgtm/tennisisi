class_name Sfx
extends Node
## Tiny voice pool for one-shot sound effects.
## Racket hits and ball bounces are real recordings (several takes each, picked at
## random so consecutive sounds never repeat); the rest are procedural (tools/gen_sfx.py).
##
## Drop-in sounds (no code changes needed, just put the file in assets/sfx/):
##   amb_park.ogg / amb_clay.ogg / amb_grass.ogg   looping background of each location
##                                                (the park falls back to birds.ogg)
##   any other name, e.g. coin.ogg, reward.ogg, applause.ogg, crowd_ooh.ogg: play("coin")
##   finds assets/sfx/coin.ogg (or .wav); a missing sound is simply silent.

const NAMES := ["bounce", "net", "swing", "point", "miss"]
const HIT_TAKES := ["hit_real_1", "hit_real_2", "hit_real_3"]
const BOUNCE_TAKES := ["bounce_real_1", "bounce_real_2", "bounce_real_3", "bounce_real_4"]

var _streams := {}
var _hits: Array[AudioStream] = []
var _bounces: Array[AudioStream] = []
var _last_hit := -1
var _last_bounce := -1
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: AudioStreamPlayer


func _ready() -> void:
	for n in NAMES:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for n in HIT_TAKES:
		_hits.append(load("res://assets/sfx/%s.wav" % n))
	for n in BOUNCE_TAKES:
		_bounces.append(load("res://assets/sfx/%s.wav" % n))
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# Calm morning birds, a seamless one-minute loop.
	_ambience = AudioStreamPlayer.new()
	var amb: AudioStream = load("res://assets/sfx/amb_park.ogg") if ResourceLoader.exists("res://assets/sfx/amb_park.ogg") else load("res://assets/sfx/birds.ogg")
	if amb is AudioStreamOggVorbis:
		(amb as AudioStreamOggVorbis).loop = true
	_ambience.stream = amb
	_ambience.volume_db = -8.0
	add_child(_ambience)


var _music: AudioStreamPlayer
var _ambience_on := false
var _location := "park"


func set_ambience(on: bool) -> void:
	_ambience_on = on
	if on and not _ambience.playing and _ambience.stream != null:
		_ambience.play()
	elif not on and _ambience.playing:
		_ambience.stop()


## The looping background of a location: assets/sfx/amb_<id>.ogg. Crossfades.
func set_location(id: String) -> void:
	if id == _location:
		return
	_location = id
	var path := "res://assets/sfx/amb_%s.ogg" % id
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif id == "park":
		stream = load("res://assets/sfx/birds.ogg")
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var tw := create_tween()
	tw.tween_property(_ambience, "volume_db", -40.0, 0.6)
	tw.tween_callback(func() -> void:
		_ambience.stop()
		_ambience.stream = stream
		_ambience.volume_db = -8.0
		if _ambience_on and stream != null:
			_ambience.play())


## Menu music (assets/sfx/music_menu.ogg if present): fades in on menus, out in matches.
func set_music(on: bool) -> void:
	if _music == null:
		var s := _stream_for("music_menu")
		if s == null:
			return
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		_music = AudioStreamPlayer.new()
		_music.stream = s
		_music.volume_db = -40.0
		add_child(_music)
	var tw := create_tween()
	if on:
		if not _music.playing:
			_music.play()
		tw.tween_property(_music, "volume_db", -10.0, 1.0)
	else:
		tw.tween_property(_music, "volume_db", -40.0, 0.8)
		tw.tween_callback(_music.stop)


## True if a sound exists (built in or dropped into assets/sfx/).
func has(sound: String) -> bool:
	return sound in ["hit", "hit_perfect", "bounce"] or _stream_for(sound) != null


func _stream_for(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var s: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/sfx/%s.%s" % [sound, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_streams[sound] = s
	return s



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
