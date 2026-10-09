class_name ClubWalk
extends RefCounted
## Where the hero can walk in the club: a rectangle of ground with round and boxy
## obstacles (posts, pavilions, the fence, the stands). Works on the ground plane, x/z as
## a Vector2. The body is a circle; it never ends inside an obstacle and slides along
## walls instead of sticking to them.

var bounds := Rect2(-60, -44, 120, 100)
var circles: Array = []   # [Vector2 centre, float radius]
var boxes: Array = []     # Rect2 in x/z
var ground := Callable()  # (Vector2) -> float: the ground's height outside the rooms (paths, apron, lawn...)
var floors: Array = []    # [Rect2, height]: a room's floor stands this high; the walker stands on it
var waypoints: Array = [] # Vector2: gates, doors, path corners - where a route may turn
var _circle_tags: Array = []   # per circle: "" or what built it (a construction's level)
var _box_tags: Array = []
var _sees := {}               # waypoint pair (i * 1000 + j, i < j) -> can walk straight; forgotten when obstacles change
var _sees_radius := -1.0
var _sees_count := 0
var _warm_at := 0             # warm(): the next waypoint pair, counted in a row-by-row walk over i < j


## How high the ground is under `p` for a walker: a room's floor, else the ground (paths, apron, lawn).
func floor_at(p: Vector2) -> float:
	var h := -999.0
	for f in floors:
		if (f[0] as Rect2).has_point(p):
			h = maxf(h, float(f[1]))
	if h > -900.0:
		return h
	return float(ground.call(p)) if ground.is_valid() else 0.0


func add_circle(c: Vector2, r: float, tag := "") -> void:
	circles.append([c, r])
	_circle_tags.append(tag)
	_sees.clear()
	_warm_at = 0


func add_box(r: Rect2, tag := "") -> void:
	boxes.append(r)
	_box_tags.append(tag)
	_sees.clear()
	_warm_at = 0


## Takes away every obstacle added with this tag (a construction rebuilt for a new level).
func clear_tag(tag: String) -> void:
	_sees.clear()
	_warm_at = 0
	for i in range(circles.size() - 1, -1, -1):
		if _circle_tags[i] == tag:
			circles.remove_at(i)
			_circle_tags.remove_at(i)
	for i in range(boxes.size() - 1, -1, -1):
		if _box_tags[i] == tag:
			boxes.remove_at(i)
			_box_tags.remove_at(i)


## A box from two corners (any order), for walls given as segments with a thickness.
func add_wall(a: Vector2, b: Vector2, thick := 0.3, tag := "") -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * thick * 0.5
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * thick * 0.5
	add_box(Rect2(lo, hi - lo), tag)


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
## would overlap, so it slides along them. `agents`: people, [[centre, radius], ...].
func resolve(_from: Vector2, to: Vector2, radius := 0.35, agents: Array = []) -> Vector2:
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
		for a in agents:    # people: round bodies that don't give way (ClubNpc.agent_list)
			var da: Vector2 = p - (a[0] as Vector2)
			var need_a := float(a[1]) + radius
			if da.length() < need_a:
				p = (a[0] as Vector2) + (da.normalized() if da.length() > 0.0001 else Vector2.RIGHT) * need_a
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


## Whether a body can go straight from a to b (sampled every 25 cm). The same answer as
## asking blocked() at every sample, but only the obstacles near the segment are asked:
## path finding calls this thousands of times (a hitch of seconds on a phone before).
func clear(a: Vector2, b: Vector2, radius := 0.35) -> bool:
	var r := radius - 0.002
	var inner := bounds.grow(-r)
	var seg := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()).grow(r + 0.01)
	var near_c: Array = []
	for c in circles:
		if seg.grow(float(c[1])).has_point(c[0]) and Geometry2D.get_closest_point_to_segment(c[0], a, b).distance_to(c[0]) < float(c[1]) + r + 0.01:
			near_c.append(c)
	var near_b: Array = []
	for bx in boxes:
		if seg.intersects(bx, true):
			near_b.append(bx)
	var n := maxi(1, ceili(a.distance_to(b) / 0.25))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if not inner.has_point(p):
			return false
		for c in near_c:
			if p.distance_to(c[0]) < float(c[1]) + r:
				return false
		for bx in near_b:
			if _box_push(p, bx, r) != Vector2.ZERO:
				return false
	return true


## clear() between two route nodes; the pairs of waypoints (fixed until an obstacle comes or
## goes) are remembered, so a second route over the same ground costs little.
func _sees_node(nodes: Array, i: int, j: int, radius: float) -> bool:
	if i < 2 or j < 2:
		return clear(nodes[i], nodes[j], radius)
	if radius != _sees_radius or waypoints.size() != _sees_count:
		_sees.clear()
		_warm_at = 0
		_sees_radius = radius
		_sees_count = waypoints.size()
	var key := mini(i, j) * 1000 + maxi(i, j)
	if not _sees.has(key):
		_sees[key] = clear(nodes[i], nodes[j], radius)
	return _sees[key]


## Fills the waypoint visibility cache a little at a time (`budget_us` microseconds per call),
## so the first routes of a visit do not pay for the whole graph in one frame.
func warm(budget_us: int) -> void:
	var n := waypoints.size()
	var total := n * (n - 1) / 2
	if _warm_at >= total:
		return
	if _sees_radius != 0.35 or n != _sees_count:
		_sees.clear()
		_sees_radius = 0.35
		_sees_count = n
		_warm_at = 0
	var t0 := Time.get_ticks_usec()
	var nodes: Array = [Vector2.ZERO, Vector2.ZERO] + waypoints
	while _warm_at < total and Time.get_ticks_usec() - t0 < budget_us:
		# the _warm_at-th pair (i, j), 2 <= i < j, in row order
		var k := _warm_at
		var i := 2
		var row := n - 1
		while k >= row:
			k -= row
			i += 1
			row -= 1
		var j := i + 1 + k
		_sees_node(nodes, i, j, 0.35)
		_warm_at += 1


## A route from `from` to `to`: the turning points to walk through, ending at `to`. Goes
## straight when nothing is in the way, else through the waypoints (A* over the ones that
## see each other). [] when `to` can't be reached.
func route(from: Vector2, to: Vector2, radius := 0.35) -> Array:
	if blocked(to, radius):
		return []
	if clear(from, to, radius):
		return [to]
	var nodes: Array = [from, to] + waypoints
	# A* with the sight lines asked late: a candidate is [f, g, node, parent] and its line is
	# tested only when it comes up as the cheapest, so most pairs are never tested at all.
	var dist := {}
	var prev := {}
	var cands: Array = [[from.distance_to(to), 0.0, 0, -1]]
	while not cands.is_empty():
		var best := 0
		for k in range(1, cands.size()):
			if float(cands[k][0]) < float(cands[best][0]):
				best = k
		var cand: Array = cands[best]
		cands[best] = cands[cands.size() - 1]
		cands.pop_back()
		var cur: int = cand[2]
		if dist.has(cur):
			continue
		if cur != 0 and not _sees_node(nodes, int(cand[3]), cur, radius):
			continue
		dist[cur] = float(cand[1])
		prev[cur] = int(cand[3])
		if cur == 1:
			break
		for j in nodes.size():
			if j == 0 or dist.has(j):
				continue
			var g: float = float(cand[1]) + (nodes[cur] as Vector2).distance_to(nodes[j])
			cands.append([g + (nodes[j] as Vector2).distance_to(to), g, j, cur])
	if not prev.has(1):
		return []
	var out: Array = []
	var at := 1
	while at != 0:
		out.push_front(nodes[at])
		at = prev[at]
	return out
