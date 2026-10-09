class_name ClubPaths
extends RefCounted
## The club's paths as data (stream H-7): a graph of nodes (the gate, the wicket to the
## embankment, the court's four sides, every place and plot, the bar, the arena, the academy,
## the corners) and edges with a width. ONE continuous mesh is built from it: a ribbon along
## every edge, a junction polygon at every node (corners chamfered, T-junctions with no
## overlap and no gap), a kerb of one height along both sides of everything, laid on the
## ground - the path 4 cm above the lawn, the kerb 10 cm above the path - and rising only
## where it meets something that stands higher (the court's apron, a pavilion's floor, the
## pavement outside the gate, the promenade), over three metres, never a step.
##
## The same graph answers where a path is (`near`, `surface_y`: props keep off it), how to
## get from here to there along paths (`route`: the auto-run, the strollers) and whether the
## mesh really covers every edge (`covers`, for the tests). Widths: the main alley 2.8 m,
## the others 1.8 m.

const GROUND := -0.21          # a path's surface on the lawn (Scenery.LAWN_Y + 4 cm)
const KERB_H := 0.10
const KERB_W := 0.16
const RAMP := 3.0              # metres over which a path climbs to a higher thing
const MAIN := 2.8
const SIDE := 1.8

## id -> [x, z, surface height or null for the lawn's]. Heights: the apron (0.0), a
## pavilion's floor at its door, the pavement outside the gate, the promenade.
const NODES := {
	"street": [0.0, 46.2, 0.05],
	"gate": [0.0, 41.0, 0.05],
	"a": [0.0, 32.5, null],
	"court_s": [0.0, 20.9, 0.0],
	"sw": [-52.0, 32.5, null], "w16": [-16.0, 32.5, null], "lk": [-14.0, 32.5, null], "w9": [-9.0, 32.5, null],
	"e11": [11.0, 32.5, null], "ch": [16.0, 32.5, null], "se": [52.0, 32.5, null],
	"locker_door": [-14.0, 28.95, 0.12], "coach_door": [16.0, 28.95, 0.12],
	"w9n": [-9.0, 23.0, null], "wr": [-16.0, 19.0, null],
	"e11n": [11.0, 23.0, null], "er": [16.0, 19.0, null],
	"w_a": [-16.0, 0.0, null], "wn": [-16.0, -22.0, null],
	"arena": [-21.6, 0.0, null], "court_w": [-12.2, 0.0, 0.0], "trophy": [-17.6, -24.4, null],
	"ea": [16.0, 14.0, null], "academy": [30.0, 14.0, null],
	"e_shop": [16.0, 6.2, null], "court_e": [12.2, 6.2, 0.0], "shop_s": [22.0, 8.6, null], "shop_door": [22.0, 4.95, 0.12],
	"e_b": [16.0, -14.0, null], "board": [20.4, -14.0, null],
	"ne": [16.0, -22.0, null], "nb": [16.0, -29.2, null], "bar": [20.0, -29.4, null], "blackjack": [26.5, -29.2, null],
	"nj": [-3.0, -22.0, null], "wicket": [-3.0, -40.9, null], "prom": [-3.0, -42.3, -0.15],
	"nw": [-52.0, -33.0, null], "ne_c": [52.0, -33.0, null],
}

## [from, to, width]
const EDGES := [
	["street", "gate", MAIN], ["gate", "a", MAIN], ["a", "court_s", MAIN],
	["sw", "w16", SIDE], ["w16", "lk", SIDE], ["lk", "w9", SIDE], ["w9", "a", SIDE], ["a", "e11", SIDE], ["e11", "ch", SIDE], ["ch", "se", SIDE],
	["lk", "locker_door", SIDE], ["ch", "coach_door", SIDE],
	["w9", "w9n", SIDE], ["w9n", "wr", SIDE], ["e11", "e11n", SIDE], ["e11n", "er", SIDE],
	["wr", "w_a", SIDE], ["w_a", "wn", SIDE], ["er", "ea", SIDE], ["ea", "e_shop", SIDE], ["e_shop", "e_b", SIDE], ["e_b", "ne", SIDE], ["ne", "nb", SIDE],
	["w_a", "arena", SIDE], ["w_a", "court_w", SIDE], ["wn", "trophy", SIDE],
	["ea", "academy", SIDE], ["e_shop", "court_e", SIDE], ["e_shop", "shop_s", SIDE], ["shop_s", "shop_door", SIDE], ["e_b", "board", SIDE],
	["nb", "bar", SIDE], ["bar", "blackjack", SIDE],
	["wn", "nj", SIDE], ["nj", "ne", SIDE], ["nj", "wicket", MAIN], ["wicket", "prom", MAIN],
	["sw", "nw", SIDE], ["se", "ne_c", SIDE],
]

## The places and where their path ends (ClubPlaces ids and plots).
const PLACE_NODE := {
	"court": "court_s", "gate": "gate", "locker": "locker_door", "coach": "coach_door", "shop": "shop_door",
	"trophy": "trophy", "bar": "bar", "blackjack": "blackjack", "arena": "arena", "academy": "academy",
	"board": "board", "machine": "court_s", "booth": "court_s", "stands": "court_e",  # the stands sit by the court's east side
}

## Strolls for the passers-by: chains of nodes walked back and forth.
const WALKS := [
	["street", "gate", "a", "court_s"],
	["sw", "w16", "lk", "a", "e11", "ch", "se"],
	["w9n", "wr", "w_a", "wn", "nj", "ne"],
	["er", "ea", "e_shop", "e_b", "ne", "nb", "bar", "blackjack"],
	["nj", "wicket", "prom"],
]

static var _built := false
static var _pos := {}            # id -> Vector2
static var _y := {}              # id -> float
static var _adj := {}            # id -> Array of [other id, width, edge index]
static var _tris := PackedVector2Array()
static var _grid := {}


static func _prepare() -> void:
	if _built:
		return
	_built = true
	for id in NODES:
		var n: Array = NODES[id]
		_pos[id] = Vector2(float(n[0]), float(n[1]))
		_y[id] = float(n[2]) if n[2] != null else GROUND
		_adj[id] = []
	for i in EDGES.size():
		var e: Array = EDGES[i]
		(_adj[e[0]] as Array).append([e[1], float(e[2]), i])
		(_adj[e[1]] as Array).append([e[0], float(e[2]), i])


static func node(id: String) -> Vector2:
	_prepare()
	return _pos[id]


static func ids() -> Array:
	return NODES.keys()


## The surface height along edge `i` at distance `s` from its first node: the lawn's until a
## higher node is near, then a smooth climb over RAMP metres.
static func _edge_y(i: int, s: float, length: float) -> float:
	var e: Array = EDGES[i]
	var ya: float = _y[e[0]]
	var yb: float = _y[e[1]]
	var y := GROUND
	if ya != GROUND:
		var k := clampf(1.0 - s / minf(RAMP, length), 0.0, 1.0)
		y = lerpf(y, ya, k * k * (3.0 - 2.0 * k))
	if yb != GROUND:
		var k := clampf(1.0 - (length - s) / minf(RAMP, length), 0.0, 1.0)
		y = lerpf(y, yb, k * k * (3.0 - 2.0 * k))
	return y


# --- Where a path is ------------------------------------------------------------------

## The nearest edge to `p`: {"edge", "s" (along it), "dist", "point"}.
static func nearest(p: Vector2) -> Dictionary:
	_prepare()
	var best := {"edge": -1, "dist": INF}
	for i in EDGES.size():
		var e: Array = EDGES[i]
		var a: Vector2 = _pos[e[0]]
		var b: Vector2 = _pos[e[1]]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < float(best["dist"]):
			best = {"edge": i, "dist": d, "point": q, "s": a.distance_to(q)}
	return best


## Whether `p` is on a path (within half its width + margin).
static func near(p: Vector2, margin := 0.0) -> bool:
	_prepare()
	for i in EDGES.size():
		var e: Array = EDGES[i]
		var a: Vector2 = _pos[e[0]]
		var b: Vector2 = _pos[e[1]]
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < float(e[2]) * 0.5 + margin:
			return true
	return false


## The height of the ground at `p` if it is on a path (else `GROUND - 0.04`, the lawn's).
static func surface_y(p: Vector2) -> float:
	var n := nearest(p)
	if int(n["edge"]) < 0 or float(n["dist"]) > float((EDGES[n["edge"]] as Array)[2]) * 0.5 + 0.3:
		return GROUND - 0.04
	var e: Array = EDGES[n["edge"]]
	var length: float = (_pos[e[0]] as Vector2).distance_to(_pos[e[1]])
	return _edge_y(int(n["edge"]), float(n["s"]), length)


# --- Getting about along them ---------------------------------------------------------

## The way along the graph from `from` to `to`: the points to walk through, from the path
## nearest `from` to the path nearest `to` (Dijkstra over the nodes); [] when both are on
## one edge (just walk). `from` and `to` themselves are not in it.
static func route(from: Vector2, to: Vector2) -> Array:
	_prepare()
	var a := nearest(from)
	var b := nearest(to)
	var ea: Array = EDGES[a["edge"]]
	var eb: Array = EDGES[b["edge"]]
	# start and goal as virtual nodes on their edges
	var start: Vector2 = a["point"]
	var goal: Vector2 = b["point"]
	if int(a["edge"]) == int(b["edge"]):
		return [start, goal]
	var dist := {}
	var prev := {}
	var open := {}
	for end_id in [ea[0], ea[1]]:
		var d := start.distance_to(_pos[end_id])
		dist[end_id] = d
		prev[end_id] = "<start>"
		open[end_id] = true
	var done := {}
	var best_total := INF
	var best_last := ""
	while not open.is_empty():
		var cur := ""
		var cd := INF
		for k in open:
			if float(dist[k]) < cd:
				cd = float(dist[k])
				cur = k
		open.erase(cur)
		done[cur] = true
		if cd >= best_total:
			break
		if cur == eb[0] or cur == eb[1]:
			var total := cd + (_pos[cur] as Vector2).distance_to(goal)
			if total < best_total:
				best_total = total
				best_last = cur
		for nb in _adj[cur]:
			var oid: String = nb[0]
			if done.has(oid):
				continue
			var nd := cd + (_pos[cur] as Vector2).distance_to(_pos[oid])
			if not dist.has(oid) or nd < float(dist[oid]):
				dist[oid] = nd
				prev[oid] = cur
				open[oid] = true
	if best_last == "":
		return []
	var chain: Array = []
	var at := best_last
	while at != "<start>":
		chain.push_front(_pos[at])
		at = prev[at]
	chain.push_front(start)
	chain.append(goal)
	return chain


## A random point on a path (weighted by length), for weeds in the paving.
static func sample(rng: RandomNumberGenerator) -> Vector2:
	_prepare()
	var total := 0.0
	for e in EDGES:
		total += (_pos[e[0]] as Vector2).distance_to(_pos[e[1]])
	var r := rng.randf() * total
	for e in EDGES:
		var a: Vector2 = _pos[e[0]]
		var b: Vector2 = _pos[e[1]]
		var l := a.distance_to(b)
		if r <= l:
			var d := (b - a) / l
			return a + d * r + Vector2(-d.y, d.x) * rng.randf_range(-0.7, 0.7) * float(e[2]) * 0.5
		r -= l
	return _pos["a"]


## The points of a stroll (WALKS) as a polyline.
static func walk_points(i: int) -> Array:
	_prepare()
	var out: Array = []
	for id in WALKS[i]:
		out.append(_pos[id])
	return out


## Whether every node can be reached from every other.
static func connected() -> bool:
	_prepare()
	var seen := {"gate": true}
	var stack := ["gate"]
	while not stack.is_empty():
		var c: String = stack.pop_back()
		for nb in _adj[c]:
			if not seen.has(nb[0]):
				seen[nb[0]] = true
				stack.append(nb[0])
	return seen.size() == NODES.size()


## Positions along the main edges at a spacing, with the edge's direction and normal, for
## lamps and benches: [{"pos", "dir", "side"}].
static func furniture(spacing: float, first: float, main_only: bool) -> Array:
	_prepare()
	var out: Array = []
	var k := 0
	for i in EDGES.size():
		var e: Array = EDGES[i]
		if main_only and float(e[2]) < MAIN:
			continue
		var a: Vector2 = _pos[e[0]]
		var b: Vector2 = _pos[e[1]]
		var l := a.distance_to(b)
		var d := (b - a) / l
		var nrm := Vector2(-d.y, d.x)
		var s := first
		while s < l - 2.5:
			if s > 3.0:
				var side := 1.0 if k % 2 == 0 else -1.0
				out.append({"pos": a + d * s, "dir": d, "nrm": nrm * side, "half": float(e[2]) * 0.5, "edge": i})
				k += 1
			s += spacing
	return out


# --- The mesh ---------------------------------------------------------------------------

## {"surface": ArrayMesh (no UVs: the paving material is laid in world space), "curb": ArrayMesh
## (vertex colours), "curb_low": the same kerb's top strip alone - a third of the triangles, for
## the Low preset: a 10 cm step is a pixel there}. Also fills the triangle list `covers` looks in.
static func build_meshes(lawn_y: float) -> Dictionary:
	_prepare()
	_tris = PackedVector2Array()
	_grid = {}
	var sv := PackedVector3Array()          # surface
	var sn := PackedVector3Array()
	var cv := PackedVector3Array()          # curb
	var cn := PackedVector3Array()
	var cc := PackedColorArray()
	var lv := PackedVector3Array()          # curb, top strip only
	var ln := PackedVector3Array()
	var lc := PackedColorArray()
	var kerb_col := Color("a8a398")
	# a surface triangle, wound to face up
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.y > 0.0:
			var t := b
			b = c
			c = t
		for v in [a, b, c]:
			sv.append(v)
			sn.append(Vector3.UP)
		_tris.append(Vector2(a.x, a.z))
		_tris.append(Vector2(b.x, b.z))
		_tris.append(Vector2(c.x, c.z))
	# a kerb along a polyline of 3D points (surface heights), `out` = +1/-1 which side is outside
	var kerb := func(pts: Array, out_side: float) -> void:
		for k in range(pts.size() - 1):
			var p0: Vector3 = pts[k]
			var p1: Vector3 = pts[k + 1]
			var d := Vector2(p1.x - p0.x, p1.z - p0.z)
			if d.length() < 0.001:
				continue
			d = d.normalized()
			var o := Vector2(-d.y, d.x) * out_side
			var ow := o * KERB_W
			var t0 := p0 + Vector3(0, KERB_H, 0)
			var t1 := p1 + Vector3(0, KERB_H, 0)
			var b0 := Vector3(p0.x, lawn_y - 0.08, p0.z)
			var b1 := Vector3(p1.x, lawn_y - 0.08, p1.z)
			var quad := func(a: Vector3, b: Vector3, c: Vector3, dd: Vector3, nrm: Vector3) -> void:
				for v in [a, b, c, a, c, dd]:
					cv.append(v)
					cn.append(nrm)
					cc.append(kerb_col)
					if nrm == Vector3.UP:
						lv.append(v)
						ln.append(nrm)
						lc.append(kerb_col)
			var o3 := Vector3(o.x, 0, o.y)
			var ow3 := Vector3(ow.x, 0, ow.y)
			# top
			var top_n := Vector3.UP
			var ta := t0
			var tb := t1
			var tc := t1 + ow3
			var td := t0 + ow3
			if (tb - ta).cross(tc - ta).y > 0.0:
				quad.call(ta, td, tc, tb, top_n)
			else:
				quad.call(ta, tb, tc, td, top_n)
			# outer face
			var oa := t0 + ow3
			var ob := t1 + ow3
			var oc := Vector3(p1.x, lawn_y - 0.08, p1.z) + ow3
			var od := Vector3(p0.x, lawn_y - 0.08, p0.z) + ow3
			if (ob - oa).cross(oc - oa).dot(o3) > 0.0:
				quad.call(oa, ob, oc, od, o3)
			else:
				quad.call(oa, od, oc, ob, o3)
			# inner face (what the walker sees)
			var ia := t0
			var ib := t1
			var ic := p1
			var id_ := p0
			if (ib - ia).cross(ic - ia).dot(-o3) > 0.0:
				quad.call(ia, ib, ic, id_, -o3)
			else:
				quad.call(ia, id_, ic, ib, -o3)
	# --- junction geometry per node -------------------------------------------------------
	# per node: edges sorted by angle; for each its left/right setbacks (distance along the
	# edge from the node where its boundary starts) and the polygon points
	var setback := {}      # "edge:node" -> [left, right]  (in that node's frame, edge leaving the node)
	var hubs := {}         # node id -> Array of Vector2 (polygon points CCW)
	for id in NODES:
		var inc: Array = _adj[id]
		var c: Vector2 = _pos[id]
		var arms: Array = []
		for nb in inc:
			var d := ((_pos[nb[0]] as Vector2) - c).normalized()
			arms.append({"d": d, "w": nb[1], "edge": nb[2], "ang": atan2(d.y, d.x)})
		arms.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["ang"] < q["ang"])
		var n := arms.size()
		if n == 1:
			setback["%d:%s" % [arms[0]["edge"], id]] = [0.0, 0.0]
			continue
		var poly: Array = []
		var lefts := []
		var rights := []
		lefts.resize(n)
		rights.resize(n)
		var corner_pts := []     # per i: [on i's left boundary, on j's right boundary]
		corner_pts.resize(n)
		for i in n:
			var ai: Dictionary = arms[i]
			var aj: Dictionary = arms[(i + 1) % n]
			var di: Vector2 = ai["d"]
			var dj: Dictionary = aj
			var ni := Vector2(-di.y, di.x)
			var nj := Vector2(-(aj["d"] as Vector2).y, (aj["d"] as Vector2).x)
			var wi: float = ai["w"]
			var wj: float = aj["w"]
			# left line of i: c + ni*wi/2 + di*t ; right line of j: c - nj*wj/2 + dj*u
			var pi := c + ni * wi * 0.5
			var pj := c - nj * wj * 0.5
			var dj_d: Vector2 = aj["d"]
			var cross := di.cross(dj_d)
			var p: Vector2
			var ti := 0.0
			var tj := 0.0
			if absf(cross) < 0.12:
				p = pi
				ti = 0.0
				tj = (pi - pj).dot(dj_d) * 0.0
				corner_pts[i] = [pi, pj]
				lefts[i] = 0.0
				rights[(i + 1) % n] = 0.0
				continue
			# solve pi + di*ti = pj + dj*tj
			var r := pj - pi
			ti = r.cross(dj_d) / cross
			tj = r.cross(di) / cross
			ti = clampf(ti, -wi * 1.2, wi * 3.0)
			tj = clampf(tj, -wj * 1.2, wj * 3.0)
			var gap := fposmod(aj["ang"] - ai["ang"], TAU)
			var cham := minf(0.7, 0.4 * minf(wi, wj))
			var pa := pi + di * (ti + cham)
			var pb := pj + dj_d * (tj + cham)
			if absf(cross) > 0.99 or (gap > 2.9 and gap < 3.4):
				pa = pi + di * ti
				pb = pj + dj_d * tj
				cham = 0.0
			lefts[i] = ti + cham
			rights[(i + 1) % n] = tj + cham
			corner_pts[i] = [pa, pb]
		for i in n:
			var ai: Dictionary = arms[i]
			setback["%d:%s" % [ai["edge"], id]] = [lefts[i], rights[i]]
		# the polygon: for each arm its right-start then left-start, then the next corner
		for i in n:
			var ai: Dictionary = arms[i]
			var di: Vector2 = ai["d"]
			var ni := Vector2(-di.y, di.x)
			var w: float = ai["w"]
			poly.append(c - ni * w * 0.5 + di * float(rights[i]))
			poly.append(c + ni * w * 0.5 + di * float(lefts[i]))
		hubs[id] = poly
		# fan
		var cy: float = _y[id]
		for k in poly.size():
			var p0: Vector2 = poly[k]
			var p1: Vector2 = poly[(k + 1) % poly.size()]
			if p0.distance_to(p1) < 0.001:
				continue
			var y0 := _hub_y(id, p0)
			var y1 := _hub_y(id, p1)
			tri.call(Vector3(c.x, cy, c.y), Vector3(p0.x, y0, p0.y), Vector3(p1.x, y1, p1.y))
		# kerbs along the corners (exterior gaps)
		for i in n:
			var cp: Array = corner_pts[i]
			var pa: Vector2 = cp[0]
			var pb: Vector2 = cp[1]
			if pa.distance_to(pb) > 0.01:
				var ya := _hub_y(id, pa)
				var yb := _hub_y(id, pb)
				# outside = away from the node
				var mid := (pa + pb) * 0.5
				var d := (pb - pa).normalized()
				var nrm := Vector2(-d.y, d.x)
				var side := 1.0 if nrm.dot(mid - c) > 0.0 else -1.0
				kerb.call([Vector3(pa.x, ya, pa.y), Vector3(pb.x, yb, pb.y)], side)
	# --- ribbons and kerbs along every edge ------------------------------------------------
	for i in EDGES.size():
		var e: Array = EDGES[i]
		var a: Vector2 = _pos[e[0]]
		var b: Vector2 = _pos[e[1]]
		var w: float = e[2]
		var length := a.distance_to(b)
		var d := (b - a) / length
		var nrm := Vector2(-d.y, d.x)
		var sa: Array = setback["%d:%s" % [i, e[0]]]
		var sb: Array = setback["%d:%s" % [i, e[1]]]
		# physical left (CCW normal) at a is a's left; at b it is b's right
		var l0: float = sa[0]
		var l1: float = length - float(sb[1])
		var r0: float = sa[1]
		var r1: float = length - float(sb[0])
		var steps := maxi(1, ceili(length / 1.0))
		var left_pts: Array = []
		var right_pts: Array = []
		for k in steps + 1:
			var u := float(k) / steps
			var sl := lerpf(l0, l1, u)
			var sr := lerpf(r0, r1, u)
			var pl := a + d * sl + nrm * w * 0.5
			var pr := a + d * sr - nrm * w * 0.5
			left_pts.append(Vector3(pl.x, _edge_y(i, clampf(sl, 0.0, length), length), pl.y))
			right_pts.append(Vector3(pr.x, _edge_y(i, clampf(sr, 0.0, length), length), pr.y))
		for k in steps:
			tri.call(left_pts[k], right_pts[k], left_pts[k + 1])
			tri.call(left_pts[k + 1], right_pts[k], right_pts[k + 1])
		# kerbs: the left side is outside toward +nrm, the right toward -nrm
		kerb.call(left_pts, 1.0)
		kerb.call(right_pts, -1.0)
	var out := {}
	out["surface"] = _mesh(sv, sn, PackedColorArray())
	out["curb"] = _mesh(cv, cn, cc)
	out["curb_low"] = _mesh(lv, ln, lc)
	return out


## Height of a junction polygon point: the node's own near it, the edges' further out.
static func _hub_y(id: String, p: Vector2) -> float:
	var c: Vector2 = _pos[id]
	var cy: float = _y[id]
	var n := nearest_on_edges_of(id, p)
	return n if not is_nan(n) else cy


static func nearest_on_edges_of(id: String, p: Vector2) -> float:
	var best := INF
	var y := NAN
	for nb in _adj[id]:
		var i: int = nb[2]
		var e: Array = EDGES[i]
		var a: Vector2 = _pos[e[0]]
		var b: Vector2 = _pos[e[1]]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < best:
			best = d
			y = _edge_y(i, a.distance_to(q), a.distance_to(b))
	return y


static func _mesh(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray) -> ArrayMesh:
	var m := ArrayMesh.new()
	if v.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	if not c.is_empty():
		arr[Mesh.ARRAY_COLOR] = c
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Whether the built surface covers the ground point `p` (the tests).
static func covers(p: Vector2) -> bool:
	if _grid.is_empty() and not _tris.is_empty():
		for t in range(0, _tris.size(), 3):
			var lo := Vector2(minf(_tris[t].x, minf(_tris[t + 1].x, _tris[t + 2].x)), minf(_tris[t].y, minf(_tris[t + 1].y, _tris[t + 2].y)))
			var hi := Vector2(maxf(_tris[t].x, maxf(_tris[t + 1].x, _tris[t + 2].x)), maxf(_tris[t].y, maxf(_tris[t + 1].y, _tris[t + 2].y)))
			for gx in range(floori(lo.x / 4.0), floori(hi.x / 4.0) + 1):
				for gz in range(floori(lo.y / 4.0), floori(hi.y / 4.0) + 1):
					var key := Vector2i(gx, gz)
					if not _grid.has(key):
						_grid[key] = []
					(_grid[key] as Array).append(t)
	# a point exactly on two triangles' shared edge counts: look at it and a hair either side
	for q in [p, p + Vector2(0.015, 0.011), p + Vector2(-0.011, 0.016)]:
		var cell: Array = _grid.get(Vector2i(floori(q.x / 4.0), floori(q.y / 4.0)), [])
		for t in cell:
			if Geometry2D.point_is_inside_triangle(q, _tris[t], _tris[t + 1], _tris[t + 2]):
				return true
	return false
