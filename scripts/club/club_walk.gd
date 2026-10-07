class_name ClubWalk
extends RefCounted
## Where the hero can walk in the club: a rectangle of ground with round and boxy
## obstacles (posts, pavilions, the fence, the stands). Works on the ground plane, x/z as
## a Vector2. The body is a circle; it never ends inside an obstacle and slides along
## walls instead of sticking to them.

var bounds := Rect2(-60, -44, 120, 100)
var circles: Array = []   # [Vector2 centre, float radius]
var boxes: Array = []     # Rect2 in x/z


func add_circle(c: Vector2, r: float) -> void:
	circles.append([c, r])


func add_box(r: Rect2) -> void:
	boxes.append(r)


## A box from two corners (any order), for walls given as segments with a thickness.
func add_wall(a: Vector2, b: Vector2, thick := 0.3) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * thick * 0.5
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * thick * 0.5
	add_box(Rect2(lo, hi - lo))


func blocked(p: Vector2, radius := 0.35) -> bool:
	var r := radius - 0.002  # a body resolved onto an obstacle's edge is not inside it
	if not bounds.grow(-r).has_point(p):
		return true
	for c in circles:
		if p.distance_to(c[0]) < float(c[1]) + r:
			return true
	for b in boxes:
		if _box_push(p, b, r) != Vector2.ZERO:
			return true
	return false


## Where a body moving from `from` toward `to` ends up: pushed out of every obstacle it
## would overlap, so it slides along them.
func resolve(_from: Vector2, to: Vector2, radius := 0.35) -> Vector2:
	var p := to
	for it in 3:
		var moved := false
		for c in circles:
			var d: Vector2 = p - (c[0] as Vector2)
			var need := float(c[1]) + radius
			if d.length() < need:
				p = (c[0] as Vector2) + (d.normalized() if d.length() > 0.0001 else Vector2.RIGHT) * need
				moved = true
		for b in boxes:
			var push := _box_push(p, b, radius)
			if push != Vector2.ZERO:
				p += push
				moved = true
		var inner := bounds.grow(-radius)
		p = Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
		if not moved:
			break
	return p


## Direction (length up to 1) toward `target`; zero when there. Slows down for the last
## metre so the body stops on the spot instead of overshooting.
func steer(pos: Vector2, target: Vector2) -> Vector2:
	var d := target - pos
	var l := d.length()
	if l < 0.15:
		return Vector2.ZERO
	return d / l * clampf(l / 0.8, 0.3, 1.0)


## How far to push a circle at `p` out of box `b` (zero if they don't touch).
func _box_push(p: Vector2, b: Rect2, radius: float) -> Vector2:
	var q := Vector2(clampf(p.x, b.position.x, b.end.x), clampf(p.y, b.position.y, b.end.y))
	var d := p - q
	var l := d.length()
	if l >= radius:
		return Vector2.ZERO
	if l > 0.0001:
		return d / l * (radius - l)
	# The centre is inside the box: out through the nearest side.
	var outs := [
		Vector2(b.position.x - radius - p.x, 0), Vector2(b.end.x + radius - p.x, 0),
		Vector2(0, b.position.y - radius - p.y), Vector2(0, b.end.y + radius - p.y),
	]
	var best: Vector2 = outs[0]
	for o in outs:
		if (o as Vector2).length() < best.length():
			best = o
	return best
