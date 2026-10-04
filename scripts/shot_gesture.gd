class_name ShotGesture
## Reads the shape of a swipe and turns it into a shot, the way the racket would move:
##   straight push forward             -> FLAT
##   forward arc, a "C" bending sideways -> TOPSPIN (brushing up the back of the ball)
##   forward then hooking back to you   -> SLICE (cutting under the ball)
##   a short, small hook                -> DROP shot (same look as a slice: disguised)
## The aim is the line from the start of the gesture to its most forward point (the apex),
## so a hook that curls back still aims where the forward part pointed.
## Points are in screen coordinates (y grows downward).

enum Type { TOPSPIN, FLAT, SLICE, DROP }

const NAMES := ["TOPSPIN", "FLAT", "SLICE", "DROP SHOT"]


class Result:
	var type := Type.FLAT
	var start := Vector2.ZERO
	var apex := Vector2.ZERO        # most forward (top-most) point
	var speed := 0.0                # screen heights per second over the forward stroke
	var curve := 0.0                # max sideways bulge / chord length
	var hook := 0.0                 # how far the end came back toward the player / forward length


## curve_min: bulge ratio above which a forward stroke counts as topspin.
## hook_min: fraction of the forward length the finger must come back for a slice.
## drop_len: a slice hook whose forward stroke is shorter than this (fraction of the
## screen height) becomes a drop shot.
static func classify(points: PackedVector2Array, times: PackedInt32Array, screen_h: float, curve_min := 0.14, hook_min := 0.15, drop_len := 0.11) -> Result:
	var r := Result.new()
	var n := points.size()
	if n == 0:
		return r
	r.start = points[0]
	var apex_i := 0
	for i in n:
		if points[i].y < points[apex_i].y:
			apex_i = i
	r.apex = points[apex_i]
	var forward := r.start.y - r.apex.y
	if forward < screen_h * 0.02:
		# Mostly sideways: no forward stroke to read, treat as a flat push toward the end point.
		r.apex = points[n - 1]
		r.type = Type.FLAT
		r.speed = _speed(points, times, n - 1, screen_h)
		return r

	# Hook back toward the player after the apex -> slice.
	var back := points[n - 1].y - r.apex.y
	r.hook = back / forward

	# Sideways bulge of the forward stroke relative to its chord -> topspin.
	var chord := r.apex - r.start
	var chord_len := chord.length()
	var normal := Vector2(-chord.y, chord.x) / maxf(chord_len, 0.001)
	var bulge := 0.0
	for i in range(0, apex_i + 1):
		bulge = maxf(bulge, absf((points[i] - r.start).dot(normal)))
	r.curve = bulge / maxf(chord_len, 0.001)

	if r.hook >= hook_min and back > screen_h * 0.015:
		r.type = Type.DROP if forward < screen_h * drop_len else Type.SLICE
	elif r.curve >= curve_min:
		r.type = Type.TOPSPIN
	else:
		r.type = Type.FLAT
	r.speed = _speed(points, times, apex_i, screen_h)
	return r


## Finger speed over the last ~150 ms before index i, in screen heights per second.
static func _speed(points: PackedVector2Array, times: PackedInt32Array, i: int, screen_h: float) -> float:
	var j := i
	while j > 0 and times[i] - times[j] < 150:
		j -= 1
	var dt := maxf((times[i] - times[j]) / 1000.0, 0.03)
	return (points[i] - points[j]).length() / screen_h / dt
