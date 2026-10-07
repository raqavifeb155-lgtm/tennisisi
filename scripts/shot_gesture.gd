class_name ShotGesture
## Reads the shape of a swipe and turns it into a shot, the way the racket would move.
## The first thing read is where the stroke starts going:
##   UP (low to high, the racket coming through):
##     straight                          -> FLAT
##     up, then a turn of the wrist      -> TOPSPIN (the bigger and quicker the turn, the more spin)
##     a slow lift up along an arc       -> LOB (scooped up high over the opponent)
##   DOWN (high to low, the racket cutting under the ball):
##     long                              -> SLICE
##     short                             -> DROP shot (same look as a slice: disguised)
## A stroke that starts up never becomes a slice, so a topspin can't be misread as one.
## The ball goes where the finger goes, along a line from the player: for an up stroke
## the line from the start to the turning point (the curl only adds spin), for a down
## stroke the start-to-end line mirrored upward, so down-right aims right.
## Points are in screen coordinates (y grows downward).

enum Type { TOPSPIN, FLAT, SLICE, DROP, LOB }

const NAMES := ["TOPSPIN", "FLAT", "SLICE", "DROP SHOT", "LOB"]


class Result:
	var type := Type.FLAT
	var start := Vector2.ZERO
	var apex := Vector2.ZERO        # aim point: the line start -> apex is where the ball goes
	var speed := 0.0                # screen heights per second over the main stroke
	var curl_k := 1.0               # topspin strength from the turn of the wrist, 0.8..1.4


## curl_min: the curl (path after the turning point) must be at least this fraction of
## the upward stroke for a topspin. turn_min_deg: how sharply the finger must turn away
## from the stroke to count as a curl. drop_len: a down stroke shorter than this
## (fraction of the screen height) is a drop shot. dead_deg / side_gain: a down stroke
## within dead_deg of vertical goes straight; past it, the sideways angle is softened
## by side_gain (a thumb cutting down drifts sideways more than it means to).
## lob_speed / lob_bend: an up stroke slower on average than lob_speed (screen heights
## per second) that bends off its chord by at least lob_bend of its length is a lob.
static func classify(points: PackedVector2Array, times: PackedInt32Array, screen_h: float, curl_min := 0.12, turn_min_deg := 45.0, drop_len := 0.11, dead_deg := 12.0, side_gain := 0.6, lob_speed := 1.4, lob_bend := 0.1) -> Result:
	var r := Result.new()
	var n := points.size()
	if n == 0:
		return r
	r.start = points[0]
	r.apex = points[n - 1]

	# Which way does the stroke start: the first vertical move of 3% of the screen.
	var dir := 0
	for i in n:
		var dy := points[i].y - r.start.y
		if absf(dy) >= screen_h * 0.03:
			dir = 1 if dy > 0.0 else -1
			break
	if dir == 0:
		# Mostly sideways: no stroke to read, a flat push toward the end point.
		r.type = Type.FLAT
		r.speed = _speed(points, times, n - 1, screen_h)
		return r

	if dir > 0:
		_read_down(r, points, times, screen_h, drop_len, dead_deg, side_gain)
	else:
		if not _read_lob(r, points, times, screen_h, lob_speed, lob_bend):
			_read_up(r, points, times, screen_h, curl_min, turn_min_deg)
	return r


## A slow scoop up along an arc: aimed from the start to the top-most point.
static func _read_lob(r: Result, points: PackedVector2Array, times: PackedInt32Array, screen_h: float, lob_speed: float, lob_bend: float) -> bool:
	var n := points.size()
	var dt := (times[n - 1] - times[0]) / 1000.0
	if dt <= 0.0:
		return false
	var length := 0.0
	var top_i := 0
	for i in range(1, n):
		length += (points[i] - points[i - 1]).length()
		if points[i].y < points[top_i].y:
			top_i = i
	if length / screen_h / dt >= lob_speed:
		return false
	var chord := points[n - 1] - r.start
	var chord_len := chord.length()
	if chord_len < screen_h * 0.05:
		return false
	var normal := Vector2(-chord.y, chord.x) / chord_len
	var bend := 0.0
	for p in points:
		bend = maxf(bend, absf((p - r.start).dot(normal)))
	if bend < lob_bend * chord_len:
		return false
	r.type = Type.LOB
	r.apex = points[top_i]
	r.speed = length / screen_h / dt
	return true


static func _read_down(r: Result, points: PackedVector2Array, times: PackedInt32Array, screen_h: float, drop_len: float, dead_deg: float, side_gain: float) -> void:
	var n := points.size()
	var end := points[n - 1]
	var chord := end - r.start
	var length := 0.0
	for i in range(1, n):
		length += (points[i] - points[i - 1]).length()
	var down := chord.y
	r.type = Type.DROP if down < screen_h * drop_len and length < screen_h * drop_len * 1.8 else Type.SLICE
	# Aim: the chord's angle off vertical, with a dead zone and a softened sideways part.
	var ang := atan2(chord.x, maxf(chord.y, 0.001))
	var off := absf(ang) - deg_to_rad(dead_deg)
	ang = signf(ang) * off * side_gain if off > 0.0 else 0.0
	var l := maxf(chord.length(), 1.0)
	r.apex = r.start + Vector2(sin(ang), -cos(ang)) * l
	r.speed = _speed(points, times, n - 1, screen_h)


static func _read_up(r: Result, points: PackedVector2Array, times: PackedInt32Array, screen_h: float, curl_min: float, turn_min_deg: float) -> void:
	var n := points.size()
	# The turning point: the first place, once the stroke has some length, where the
	# finger turns away from it. Without one, the top-most point.
	var turn_i := -1
	var cos_min := cos(deg_to_rad(turn_min_deg))
	for i in range(1, n - 1):
		var c := points[i] - r.start
		if c.length() < screen_h * 0.05 or c.y >= 0.0:
			continue
		var j := i + 1
		while j < n - 1 and (points[j] - points[i]).length() < screen_h * 0.012:
			j += 1
		var l := points[j] - points[i]
		if l.length() < screen_h * 0.012:
			break
		if c.normalized().dot(l.normalized()) < cos_min:
			turn_i = i
			break
	if turn_i < 0:
		turn_i = 0
		for i in n:
			if points[i].y < points[turn_i].y:
				turn_i = i
	r.apex = points[turn_i]
	var forward := (r.apex - r.start).length()
	var curl := 0.0
	for i in range(turn_i + 1, n):
		curl += (points[i] - points[i - 1]).length()
	r.speed = _speed(points, times, turn_i, screen_h)
	if forward > 1.0 and curl >= curl_min * forward and curl >= screen_h * 0.02:
		r.type = Type.TOPSPIN
		var dt := maxf((times[n - 1] - times[turn_i]) / 1000.0, 0.03)
		var curl_speed := curl / screen_h / dt
		# A curl half as long as the stroke, as quick as it, is the full turn of the wrist.
		var size := minf(curl / forward / 0.5, 1.0)
		var quick := minf(curl_speed / maxf(r.speed, 0.01), 1.0)
		r.curl_k = clampf(0.8 + 0.6 * size * quick, 0.8, 1.4)
	else:
		r.type = Type.FLAT


## Finger speed over the last ~150 ms before index i, in screen heights per second.
static func _speed(points: PackedVector2Array, times: PackedInt32Array, i: int, screen_h: float) -> float:
	var j := i
	while j > 0 and times[i] - times[j] < 150:
		j -= 1
	var dt := maxf((times[i] - times[j]) / 1000.0, 0.03)
	return (points[i] - points[j]).length() / screen_h / dt
