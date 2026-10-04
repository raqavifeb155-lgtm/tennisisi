class_name Sfx
extends Node
## Tiny voice pool for one-shot sound effects.
## Racket hits and ball bounces are real recordings (several takes each, picked at
## random so consecutive sounds never repeat); the rest are procedural (tools/gen_sfx.py).

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
	# Club atmosphere: birds and a distant game on another court, looped quietly.
	_ambience = AudioStreamPlayer.new()
	var amb: AudioStreamOggVorbis = load("res://assets/sfx/ambience.ogg")
	amb.loop = true
	_ambience.stream = amb
	_ambience.volume_db = -14.0
	add_child(_ambience)


func set_ambience(on: bool) -> void:
	if on and not _ambience.playing:
		_ambience.play()
	elif not on and _ambience.playing:
		_ambience.stop()


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
		stream = _streams[sound]
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
