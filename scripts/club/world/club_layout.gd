class_name ClubLayout
extends RefCounted
## Where the club's props stand (stream H): the park's trees and bushes, benches, lamps
## and bins along the paths, the street behind the gate with its parked cars and its
## shop fronts - and, belonging to the places that are not built yet, the ruin of the
## start: weeds, junk, a dumped sofa, an abandoned car, boards on the doors that are
## shut. Every ruin prop knows its owner and the level at which it is gone, so each
## construction cleans up its own corner (ClubProps.visible).
##
## Coordinates as in the rest of the club: x east, z south (the river is -z), the main
## court at the origin. The camera is low now: what stands within ~40 m of the paths is
## seen close, so the near props are real models and the far ones are few and big.

const HX := Scenery.HX
const HZ := Scenery.HZ
const LAWN := Scenery.LAWN_Y
const PATH_TOP := 0.05
const SHORE := Scenery.SHORE_Z

## The club's paths (ClubWorld._build_paths and Scenery._build_ground), as rectangles.
const PATHS := [
	Rect2(-1.2, 17.9, 2.4, 22.0), Rect2(-16.0, 29.8, 34.0, 2.4), Rect2(13.4, -28.0, 2.4, 40.0),
	Rect2(14.6, -31.2, 8.0, 2.4), Rect2(-21.5, -1.2, 13.0, 2.4), Rect2(-14.2, -26.0, 2.4, 26.0),
	Rect2(-21.5, -27.2, 9.0, 2.4), Rect2(15.2, 5.0, 8.6, 2.4), Rect2(22.6, -31.2, 6.0, 2.4),
	Rect2(-4.2, -41.0, 2.4, 20.2), Rect2(-80.0, -45.0, 160.0, 4.0),
]

const FACADES := [Color(1.0, 0.88, 0.7), Color(0.95, 0.62, 0.5), Color(0.75, 0.86, 0.95), Color(1.0, 0.95, 0.82), Color(0.82, 0.9, 0.78), Color(0.98, 0.78, 0.6)]
const OAKS := ["tree_round", "tree_fat", "tree_round", "tree_oak", "tree_fat", "tree_small", "tree_round"]

static var _rng := RandomNumberGenerator.new()


## Everything, into `p`. Deterministic: the same club every time.
static func fill(p: ClubProps) -> void:
	_rng.seed = 4242
	_park(p)
	_promenade(p)
	_paths(p)
	_kiosks(p)
	_street(p)
	_details(p)
	_perimeter(p)
	_ruin(p)
	_tidy(p)


# --- Helpers ------------------------------------------------------------------------

static func gy(pos: Vector2) -> float:
	for r in PATHS:
		if (r as Rect2).has_point(pos):
			return PATH_TOP
	if absf(pos.x) < HX + 2.0 and absf(pos.y) < HZ + 2.0:
		return 0.0
	return LAWN


## Whether a prop may stand here: off the court, the reserved squares (places, the arena
## site, the gate), the paths and the circles of the places.
static func open_at(q: Vector2, margin := 0.0) -> bool:
	if absf(q.x) < HX + 2.0 + margin and absf(q.y) < HZ + 2.0 + margin:
		return false
	for r in ClubWorld.RESERVED:
		if (r as Rect2).grow(margin).has_point(q):
			return false
	for r in PATHS:
		if (r as Rect2).grow(margin + 0.5).has_point(q):
			return false
	for pl in ClubPlaces.LIST:
		var c: Vector3 = pl["pos"]
		if Vector2(q.x - c.x, q.y - c.z).length() < float(pl["r"]) + 1.6 + margin:
			return false
	return q.y > ClubFence.NORTH + 0.9 and q.y < ClubFence.SOUTH - 0.9 and absf(q.x) < ClubFence.EAST - 0.9


static func yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)    # -z toward `to` (the hero's own heading)


## A model's front is +z (glTF): the yaw that turns it to face `to`.
static func face(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x, d.y)


static func _r(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


static func _pick(list: Array) -> String:
	return list[_rng.randi() % list.size()]


## A prop on the ground at (x, z): y from the ground there.
static func put(p: ClubProps, id: String, x: float, z: float, yaw := 0.0, size = 1.0, tilt := Vector3.ZERO) -> ClubProps.Prop:
	return p.at(id, Vector3(x, gy(Vector2(x, z)), z), yaw, size, tilt)


static func _tree(p: ClubProps, x: float, z: float, kind := "", scale := -1.0) -> void:
	var q := Vector2(x, z)
	if not open_at(q, 0.8):
		return
	var t := put(p, kind if kind != "" else _pick(OAKS), x, z, _r(0.0, TAU), scale if scale > 0.0 else _r(0.85, 1.2))
	var g := _r(0.9, 1.08)
	t.tint = Color(g, g * _r(0.97, 1.05), g * _r(0.9, 1.0))
	t.solid = 0.42
	t.shadow = true
	t.far = true
	t.high = _rng.randf() < 0.4


## A clump of trees around a centre.
static func _clump(p: ClubProps, c: Vector2, n: int, spread: float, kinds: Array = []) -> void:
	for i in n:
		var a := _r(0.0, TAU)
		var d := spread * sqrt(_r(0.05, 1.0))
		_tree(p, c.x + cos(a) * d, c.y + sin(a) * d * 0.8, "" if kinds.is_empty() else _pick(kinds))


static func _bushes(p: ClubProps, c: Vector2, n: int, spread: float, big := 0.35) -> void:
	for i in n:
		var a := _r(0.0, TAU)
		var d := spread * sqrt(_r(0.05, 1.0))
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d * 0.8
		if not open_at(Vector2(x, z), 0.3):
			continue
		var b := put(p, "bush_large" if _rng.randf() < big else "bush", x, z, _r(0.0, TAU), _r(0.85, 1.3))
		var g := _r(0.88, 1.08)
		b.tint = Color(g, g, g * 0.95)
		b.high = _rng.randf() < 0.45


## A bench seat facing `look`.
static func _bench(p: ClubProps, x: float, z: float, look: Vector2, owner := "", from := 0) -> ClubProps.Prop:
	var b := put(p, "bench", x, z, face(Vector2(x, z), look), 1.35)
	b.solid = 0.7
	b.owner = owner
	b.from = from
	return b


static func _bin(p: ClubProps, x: float, z: float) -> void:
	var b := put(p, "trash_bin", x, z, _r(0.0, TAU), 1.0)
	b.solid = 0.3


## A street light, its arm toward `toward` (the model's arm points -x): `lean` tips it over
## (a ruin).
static func lamp(p: ClubProps, x: float, z: float, toward: Vector2, owner := "", need := 0, lean := 0.0) -> ClubProps.Prop:
	var d := toward - Vector2(x, z)
	var yaw := atan2(d.y, -d.x)
	var l := put(p, "streetlight", x, z, yaw, 1.0, Vector3(lean * 0.6, 0.0, lean))
	l.solid = 0.22
	l.tag = "lamp"
	l.far = true
	l.owner = owner
	l.need = need
	l.shadow = false
	return l


# --- The park -----------------------------------------------------------------------

static func _park(p: ClubProps) -> void:
	# The lawn north of the court is kept open (the river and the bridge are the view);
	# trees stand at the edges, bunched, never in rows.
	_clump(p, Vector2(-44.0, -33.0), 6, 7.0)
	_clump(p, Vector2(-30.0, -36.0), 3, 4.5, ["tree_round", "tree_fat"])
	_clump(p, Vector2(36.0, -37.0), 4, 5.0)
	_clump(p, Vector2(50.0, -30.0), 5, 5.5)
	_clump(p, Vector2(-10.0, -37.0), 2, 2.5, ["tree_fat"])
	_clump(p, Vector2(10.0, -38.0), 2, 2.5, ["tree_round"])
	# the east lawn, around the academy's plot
	_clump(p, Vector2(46.0, -12.0), 5, 6.0)
	_clump(p, Vector2(52.0, 4.0), 4, 4.5)
	_clump(p, Vector2(42.0, 25.0), 6, 7.0)
	_clump(p, Vector2(32.0, 38.0), 4, 5.0)
	_clump(p, Vector2(50.0, 36.0), 4, 5.0)
	_tree(p, 36.0, 3.0, "tree_oak", 1.25)
	# the west lawn, below and above the arena's plot
	_clump(p, Vector2(-45.0, 30.0), 6, 8.0)
	_clump(p, Vector2(-30.0, 38.0), 4, 6.0)
	_clump(p, Vector2(-52.0, 40.0), 3, 3.5)
	_clump(p, Vector2(-26.0, 12.0), 2, 2.5, ["tree_round"])
	_clump(p, Vector2(-25.0, -10.0), 2, 2.5, ["tree_fat"])
	# between the court and the pavilions, and by the paths
	_tree(p, -24.0, 24.0, "tree_oak")
	_tree(p, 27.0, 22.0, "tree_round")
	_tree(p, -8.0, 38.0, "tree_fat", 0.9)
	_tree(p, 9.0, 44.0, "tree_fat", 0.9)
	# bushes: the fence line, the pavilions' backs, the lawn corners
	for x in [-9.5, -6.0, 6.0, 9.5]:
		_bushes(p, Vector2(x, 21.4), 1, 0.5)
	_bushes(p, Vector2(-16.0, 21.0), 4, 3.0)
	_bushes(p, Vector2(19.0, 21.5), 4, 3.0)
	_bushes(p, Vector2(-34.0, -24.0), 5, 5.0)
	_bushes(p, Vector2(30.0, -22.0), 5, 5.0)
	_bushes(p, Vector2(-8.0, -33.0), 3, 3.5)
	_bushes(p, Vector2(8.0, -33.0), 3, 3.5)
	_bushes(p, Vector2(40.0, 14.0), 5, 6.0)
	_bushes(p, Vector2(-40.0, 22.0), 5, 6.0)
	_bushes(p, Vector2(-30.0, 44.0), 6, 7.0)
	_bushes(p, Vector2(30.0, 44.0), 6, 7.0)
	_bushes(p, Vector2(0.0, 44.5), 3, 3.0)
	# rocks by the water and on the lawn
	for k in 7:
		var x := _r(-50.0, 50.0)
		var z := _r(SHORE + 5.0, SHORE + 9.0)
		if open_at(Vector2(x, z), 0.5):
			put(p, "rock", x, z, _r(0.0, TAU), _r(1.2, 2.4))


static func _promenade(p: ClubProps) -> void:
	var z := SHORE + 3.4
	var x := -48.0
	while x <= 48.0:
		lamp(p, x, z, Vector2(x, SHORE - 8.0)).high = absf(x) > 30.0
		x += 16.0
	for bx in [-40.0, -24.0, 20.0, 36.0, 4.0]:
		_bench(p, bx, SHORE + 3.0, Vector2(bx, SHORE - 6.0))
	for bx in [-30.0, 0.0, 30.0]:
		_bin(p, bx + 2.0, SHORE + 3.0)
	# someone's flowers and a rail's worth of rocks by the steps down to the water
	for k in 5:
		var x2 := -44.0 + k * 22.0 + _r(-3.0, 3.0)
		put(p, "bush", x2, SHORE + 5.0, _r(0, TAU), _r(1.0, 1.4))


## Two snack kiosks with a parasol and a couple of tables each.
static func _kiosks(p: ClubProps) -> void:
	for spec in [[Vector3(-30.0, 0.0, -38.6), Vector2(-30.0, -50.0)], [Vector3(30.0, 0.0, -17.0), Vector2(10.0, -17.0)]]:
		var c: Vector3 = spec[0]
		var look: Vector2 = spec[1]
		var yaw := face(Vector2(c.x, c.z), look)
		var k := put(p, "kiosk", c.x, c.z, yaw)
		k.solid = 1.5
		k.far = true
		var fwd := Vector2(sin(yaw), cos(yaw))
		var side := Vector2(fwd.y, -fwd.x)
		var base := Vector2(c.x, c.z) + fwd * 3.4
		for sgn: float in [-1.0, 1.0]:
			var q := base + side * sgn * 2.6
			var t := put(p, "bar_table", q.x, q.y, 0.0, 1.1)
			t.high = true
			t.solid = 0.55
			for a in 2:
				var ca: float = a * PI + 0.8
				var cq := q + Vector2(cos(ca), sin(ca)) * 0.9
				var ch := put(p, "bar_chair", cq.x, cq.y, face(cq, q), 1.0)
				ch.high = true
		var pa := put(p, "parasol", base.x, base.y, 0.0, 1.0)
		pa.far = true
		pa.high = true
		pa.solid = 0.2
		_bin(p, c.x + side.x * 2.2 + fwd.x * 1.2, c.z + side.y * 2.2 + fwd.y * 1.2)


static func _paths(p: ClubProps) -> void:
	# lamps and benches along the paths (the court's own lamps are level 2 of the court)
	for lz in [22.0, 35.5]:
		lamp(p, -2.1, lz, Vector2(0.0, lz))
	lamp(p, 2.1, 27.5, Vector2(0.0, 27.5))
	lamp(p, -10.0, 33.4, Vector2(-10.0, 31.0))
	lamp(p, 10.0, 33.4, Vector2(10.0, 31.0)).high = true
	for lx in [-18.0, 18.0]:
		lamp(p, lx, 33.4, Vector2(lx, 31.0)).high = true
	for lz in [-22.0, -6.0]:
		lamp(p, 17.0, lz, Vector2(14.6, lz))
	lamp(p, 17.0, 10.0, Vector2(14.6, 10.0)).high = true
	lamp(p, -10.5, -14.0, Vector2(-13.0, -14.0))
	# benches facing the court and the paths
	_bench(p, 17.0, -8.0, Vector2(0.0, -8.0))
	_bench(p, 17.0, 3.4, Vector2(0.0, 3.4))
	_bench(p, -16.2, -14.0, Vector2(0.0, -14.0))
	_bench(p, -16.2, 6.0, Vector2(0.0, 6.0))
	_bench(p, 3.5, 20.0, Vector2(3.5, 30.0)).owner = ""
	_bench(p, -3.5, 20.0, Vector2(-3.5, 30.0))
	_bench(p, -8.0, -22.5, Vector2(-8.0, -32.0))
	_bench(p, -20.0, 32.0, Vector2(-20.0, 20.0))
	_bin(p, 18.0, -4.0)
	_bin(p, -15.5, 8.0)
	_bin(p, 4.8, 29.0)
	_bin(p, -4.8, 29.0)
	_bin(p, 21.0, 32.4)
	# a hydrant by the gate, a few signs
	var h := put(p, "hydrant", -3.2, 38.5, 0.0, 1.1)
	h.solid = 0.25
	put(p, "sign", 3.0, 41.8, 0.0, 1.2).solid = 0.2


## The street behind the gate: kerb, parked cars, shop fronts, a second row far off.
static func _street(p: ClubProps) -> void:
	# shop fronts, one row, facing the gate (the street's far side)
	var z := 66.0
	var x := -66.0
	var kinds := ["shop_a", "shop_wide_a", "shop_b", "building_a", "shop_c", "shop_wide_b", "building_b", "shop_a", "shop_b", "shop_c"]
	var i := 0
	# model sizes (m, as baked: width, height, depth) and the width each is stretched to
	var dims := {"shop_a": Vector3(3.0, 12.0, 3.0), "shop_wide_a": Vector3(8.2, 9.0, 4.1), "shop_b": Vector3(4.0, 14.0, 4.0),
		"building_a": Vector3(7.0, 9.0, 8.4), "shop_c": Vector3(2.5, 10.0, 2.5), "shop_wide_b": Vector3(7.8, 9.0, 3.9), "building_b": Vector3(10.4, 10.0, 8.4)}
	var want := {"shop_a": 9.0, "shop_wide_a": 13.0, "shop_b": 10.0, "building_a": 9.0, "shop_c": 8.0, "shop_wide_b": 12.0, "building_b": 11.0}
	var cafe_x := []
	while x < 72.0:
		var id: String = kinds[i % kinds.size()]
		var d: Vector3 = dims[id]
		var w: float = want[id]
		var sx := w / d.x
		var sy := _r(0.62, 0.8) if d.y > 11.0 else _r(0.85, 1.05)
		var sz := minf(sx, 2.4) * _r(0.9, 1.0)
		var fz := z + _r(-0.8, 0.8)
		var b := p.at(id, Vector3(x + w * 0.5, 0.0, fz), PI, Vector3(sx, sy, sz))   # fronts to the gate (-z)
		b.tint = FACADES[_rng.randi() % FACADES.size()]
		b.high = absf(x) > 40.0
		b.far = true
		b.tag = "facade"
		# an awning over each ground floor, in the street's colours
		var front := fz - d.z * sz * 0.5
		var aw := p.at("awning_wide", Vector3(x + w * 0.5, 3.05, front - 0.1), PI, Vector3(w * 0.5 / 1.8, 1.0, 1.4))
		aw.tint = [Color(1.0, 0.45, 0.4), Color(0.4, 0.8, 0.7), Color(1.0, 0.85, 0.4), Color(0.5, 0.65, 1.0)][i % 4]
		aw.high = b.high
		cafe_x.append([x + w * 0.5, front - 1.0])
		x += w + _r(0.4, 1.6)
		i += 1
	# a cafe table with a parasol on the far pavement before two of the fronts
	for k in [2, 5]:
		var cx0: float = cafe_x[k][0]
		var cz0: float = cafe_x[k][1] - 1.2
		if absf(cx0) > 60.0:
			continue
		for dx in [-1.6, 1.6]:
			var t := p.at("bar_table", Vector3(cx0 + dx, 0.0, cz0), 0.0, 1.0)
			t.high = true
			for a in 2:
				var ang: float = a * PI + 0.6
				var q := Vector2(cx0 + dx, cz0) + Vector2(cos(ang), sin(ang)) * 0.85
				p.at("bar_chair", Vector3(q.x, 0.0, q.y), face(q, Vector2(cx0 + dx, cz0)), 1.0).high = true
		var pb := p.at("parasol_b", Vector3(cx0, 0.0, cz0), 0.0, 1.0)
		pb.high = true
		pb.far = true
	# parked cars along the kerb
	var cars := ["car_hatch", "car_sedan", "car_wagon"]
	var cx := [-31.0, -9.0, 27.0]
	for k in 3:
		var c := p.at(cars[k], Vector3(cx[k], 0.0, 53.2), PI * 0.5 + _r(-0.03, 0.03), 1.0)
		c.high = k != 1
		c.far = true
		c.tint = Color(_r(0.9, 1.1), _r(0.9, 1.1), _r(0.9, 1.1))
	# street lights and trees on the pavement, bins
	for sx in [-34.0, -4.0, 22.0, 44.0]:
		lamp(p, sx, 48.8, Vector2(sx, 56.0)).high = absf(sx) > 30.0
	for tx in [-52.0, -34.0, -18.0, 22.0, 40.0, 56.0]:
		var q := Vector2(tx, 49.6)
		var t := put(p, _pick(["tree_round", "tree_oak", "tree_fat"]), tx, q.y, _r(0, TAU), _r(0.8, 1.0))
		t.far = true
	_bin(p, -8.0, 48.6)
	_bin(p, 8.0, 48.6)
	put(p, "hydrant", 20.0, 48.4, 0.0, 1.1)
	# the far side's trees and a water tower on a roof
	var wt := p.at("watertower", Vector3(-20.0, 11.5, 66.0), 0.0, 1.0)
	wt.high = true
	wt.far = true
	# the street ends: forest on both sides
	for k in 10:
		var side := -1.0 if k % 2 == 0 else 1.0
		var tz := 46.0 + 8.0 + k * 3.0
		put(p, "tree_pine" if k % 3 != 0 else "tree_round", side * (60.0 + _r(0.0, 8.0)), tz - 40.0 + _r(-6.0, 6.0), _r(0, TAU), _r(0.9, 1.3))


# --- The ruin of the start ---------------------------------------------------------

## One owner's junk and weeds in an area: junk is gone from the owner's level 1, weeds
## thin out at 1 and are gone at 2.
static func _junk(p: ClubProps, owner: String, area: Rect2, list: Array, n: int, need := 1) -> void:
	var tries := 0
	var placed := 0
	while placed < n and tries < n * 12:
		tries += 1
		var q := Vector2(_r(area.position.x, area.end.x), _r(area.position.y, area.end.y))
		if not open_at(q, 0.2):
			continue
		var id: String = _pick(list)
		var y := _r(0.0, TAU)
		var t := put(p, id, q.x, q.y, y, _r(0.85, 1.2))
		t.owner = owner
		t.need = need
		if id in ["tyre", "trash_bags", "crate", "box_a", "box_b", "dumpster", "trash_bin"]:
			t.solid = 0.4
		placed += 1


static func _weeds(p: ClubProps, owner: String, area: Rect2, n: int, mask_free := true) -> void:
	var tries := 0
	var placed := 0
	while placed < n and tries < n * 12:
		tries += 1
		var q := Vector2(_r(area.position.x, area.end.x), _r(area.position.y, area.end.y))
		if mask_free and not open_at(q, 0.1):
			continue
		var t := put(p, "tuft" if _rng.randf() < 0.7 else "tuft_dry", q.x, q.y, _r(0.0, TAU), _r(0.8, 1.5))
		t.owner = owner
		t.need = 1 if placed % 2 == 0 else 2
		t.high = placed % 3 != 0
		placed += 1


static func _ruin(p: ClubProps) -> void:
	# The court: weeds in the cracks and along the fence, a flat ball, a tyre by the gate.
	for k in 26:
		var side := -1.0 if k % 2 == 0 else 1.0
		var zz := _r(-HZ + 0.6, HZ - 0.6)
		var t := p.at("tuft" if k % 3 != 0 else "tuft_dry", Vector3(side * (HX - 0.55), 0.0, zz), _r(0, TAU), _r(0.9, 1.6))
		t.owner = "court"
		t.need = 1 if k % 2 == 0 else 2
		t.high = k % 3 != 0
	for k in 14:
		var t := p.at("tuft_dry", Vector3(_r(-HX + 1.0, HX - 1.0), 0.03, _r(-HZ + 0.8, -HZ + 2.2) if k % 2 == 0 else _r(HZ - 2.2, HZ - 0.8)), _r(0, TAU), _r(0.5, 0.9))
		t.owner = "court"
		t.need = 1
	# crack weeds on the court's baselines and service lines
	for k in 10:
		var t := p.at("tuft_dry", Vector3(_r(-4.0, 4.0), 0.04, [-Court.SERVICE_LINE, Court.SERVICE_LINE, -Court.HALF_LENGTH + 0.3, Court.HALF_LENGTH - 0.3][k % 4] + _r(-0.6, 0.6)), _r(0, TAU), _r(0.3, 0.6))
		t.owner = "court"
		t.need = 1
	# The gate: rubbish heaped by the wall, a dumped sofa, a tipped dumpster.
	var gate := Rect2(-15.0, 35.5, 11.5, 8.0)
	_junk(p, "gate", gate, ["trash_bags", "box_a", "box_b", "crate", "trash_bags"], 8)
	var east := Rect2(14.0, 35.5, 12.0, 8.0)
	_junk(p, "gate", east, ["trash_bags", "box_b", "crate", "bumper"], 6)
	var d := put(p, "dumpster", -9.0, 42.4, 0.4, 1.0, Vector3(0.0, 0.0, 0.18))
	d.owner = "gate"
	d.need = 1
	d.solid = 1.0
	var s := put(p, "armchair", -12.5, 40.2, PI - 0.9, 1.15, Vector3(0.0, 0.0, 0.12))
	s.owner = "gate"
	s.need = 2
	s.high = true
	put(p, "table_low", -11.0, 41.6, 0.3, 1.2, Vector3(0.0, 0.0, 0.5)).owner = "gate"
	p.props[-1].need = 2
	p.props[-1].high = true
	_weeds(p, "gate", Rect2(-16.0, 36.0, 32.0, 9.0), 26)
	# an abandoned car by the east fence of the gate yard: rusty, a flat tyre
	var car := put(p, "car_sedan", 22.0, 41.0, PI * 0.5 + 0.25, 1.0, Vector3(0.0, 0.0, 0.04))
	car.tint = Color(0.78, 0.6, 0.5)
	car.owner = "gate"
	car.need = 2
	car.high = true
	car.solid = 1.3
	# The stands' site: old chairs and weeds east of the path.
	_junk(p, "stands", Rect2(16.5, -17.0, 6.0, 14.0), ["crate", "box_b", "chair_wood", "trash_bags", "log"], 5)
	_weeds(p, "stands", Rect2(9.0, -20.0, 14.0, 24.0), 18, true)
	# The trophy room's plot: a broken colonnade, rubble, weeds.
	for k in 3:
		var c := put(p, "column_broken", -26.0 + k * 3.2 + _r(-0.5, 0.5), -33.2 + _r(-0.4, 0.4), _r(0, TAU), _r(0.9, 1.2), Vector3(_r(-0.12, 0.12), 0.0, _r(-0.12, 0.12)))
		c.owner = "trophy"
		c.need = 1
		c.solid = 0.4
	_junk(p, "trophy", Rect2(-27.0, -36.0, 12.0, 7.0), ["rock", "rock", "log", "stump", "box_b"], 6)
	_weeds(p, "trophy", Rect2(-27.0, -37.0, 22.0, 12.0), 22, true)
	# The bar's plot: crates, tipped chairs, a heap of rubbish west of the terrace.
	_junk(p, "bar", Rect2(8.0, -38.0, 5.0, 10.0), ["crate", "bar_chair", "bar_stool", "trash_bags", "box_a"], 7)
	_weeds(p, "bar", Rect2(8.0, -39.0, 24.0, 12.0), 20, true)
	# The arena's plot: a builder's yard that never got built.
	_junk(p, "arena", Rect2(-27.0, -22.0, 6.0, 8.0), ["tyre", "cone", "crate", "box_a", "box_b", "trash_bags"], 8, 1)
	_junk(p, "arena", Rect2(-27.0, 16.0, 7.0, 7.0), ["cone", "crate", "box_b", "log_stack"], 6, 1)
	_weeds(p, "arena", Rect2(-56.0, -24.0, 36.0, 48.0), 30, true)
	# The shop and the locker room while they're shut: weeds at the doors, a pile of boxes.
	_junk(p, "shop", Rect2(26.0, -2.0, 4.0, 8.0), ["box_a", "box_b", "crate", "trash_bags"], 4)
	_weeds(p, "shop", Rect2(17.0, -2.0, 14.0, 10.0), 10, true)
	_junk(p, "locker", Rect2(-22.0, 22.0, 4.0, 8.0), ["box_a", "crate", "trash_bags"], 4)
	_weeds(p, "locker", Rect2(-22.0, 21.0, 12.0, 11.0), 10, true)
	# Bare earth where feet and balls wore the grass: by the court's gate and the benches.
	for q in [Vector2(-5.5, 22.0), Vector2(5.5, 22.5), Vector2(-15.0, 3.0), Vector2(17.5, -5.0), Vector2(0.0, 44.0), Vector2(-6.0, 41.5), Vector2(8.0, 42.0), Vector2(-20.0, -23.0)]:
		var bare := put(p, "dirt", q.x, q.y, _r(0, TAU), _r(1.2, 2.2))
		bare.owner = "court" if absf(q.y) < 30.0 else "gate"
		bare.need = 2
	# Weeds in the paving everywhere: the cracks of a path nobody sweeps.
	for k in 36:
		var r: Rect2 = PATHS[k % (PATHS.size() - 1)]
		var q := Vector2(_r(r.position.x + 0.1, r.end.x - 0.1), _r(r.position.y + 0.1, r.end.y - 0.1))
		var t := p.at("tuft_dry" if k % 2 == 0 else "tuft", Vector3(q.x, PATH_TOP, q.y), _r(0, TAU), _r(0.4, 0.8))
		t.owner = "gate" if q.y > 20.0 else ("trophy" if q.y < -20.0 else "court")
		t.need = 2
		t.high = k % 2 == 0
	# Leaning, half-dead lamps on the court's side (the court's level 2 puts new ones up).
	for sx in [-1.0, 1.0]:
		lamp(p, sx * (HX + 4.0), HZ + 3.0, Vector2(0.0, HZ), "court", 2, sx * 0.14).tag = "lamp_dead"
	lamp(p, -(HX + 4.0), -HZ - 2.0, Vector2(0.0, -HZ), "court", 2, 0.2).tag = "lamp_dead"
	lamp(p, -17.0, -9.0, Vector2(-13.0, -9.0), "court", 2, -0.1).tag = "lamp_dead"


## What a built place has around it that a ruin doesn't: flowers, planters, a bench.
static func _tidy(p: ClubProps) -> void:
	# the gate (level 1: the wooden sign): planters and flower beds either side of the way
	for s in [-1.0, 1.0]:
		var pl := put(p, "planter", s * 3.4, 38.6, 0.0, 1.3)
		pl.owner = "gate"
		pl.from = 1
		pl.solid = 0.4
		var bed := put(p, "flower_patch", s * 3.8, 24.5, _r(0, TAU), 1.8)
		bed.owner = "gate"
		bed.from = 1
	# the court (level 1: fresh hard): beds by the way in, bright bushes
	for s in [-1.0, 1.0]:
		var bed := put(p, "flower_patch", s * 4.2, 21.0, 0.0, 2.0)
		bed.owner = "court"
		bed.from = 1
	# the stands (level 1+): a couple of bins and a flower bed on their side
	var b := put(p, "flower_patch", 17.4, -18.5, 0.0, 1.8)
	b.owner = "stands"
	b.from = 1
	# the bar (level 1+): crates of bottles and a menu board
	var m := put(p, "menu_board", 23.0, -29.3, 0.0, 1.6)
	m.owner = "bar"
	m.from = 1
	# the trophy room (level 1+): flower beds before it
	for s in [-1.0, 1.0]:
		var f := put(p, "flower_patch", -18.0 + s * 4.2, -24.0, 0.0, 1.8)
		f.owner = "trophy"
		f.from = 1
	# the shop and the locker room once open: a planter at each door, a bench
	for id in ["shop", "locker"]:
		var pos: Vector3 = ClubPlaces.find(id)["pos"]
		var q := put(p, "planter", pos.x + 3.6, pos.z + 3.4, 0.0, 1.2)
		q.owner = id
		q.from = 1
		q.solid = 0.4
	# the arena's plot (level 1+): flower beds along the way
	var a := put(p, "flower_patch", -19.5, 3.0, 0.0, 1.8)
	a.owner = "arena"
	a.from = 1


## The second pass: the little things that make a path a place - people on benches, bicycles,
## bins, flower beds, a poster at the gate, bunting, traffic lights and manholes in the street.
static func _details(p: ClubProps) -> void:
	# somebody sits on the benches once the court is fresh (court level 1)
	var sitters := ["sitter_a", "sitter_b", "sitter_c"]
	var n := 0
	for pr: ClubProps.Prop in p.props.duplicate():
		if pr.id != "bench":
			continue
		n += 1
		if n % 2 == 0:
			continue
		var sid: String = sitters[n % 3]
		var yaw := pr.xf.basis.get_euler().y
		var seat := pr.xf.origin + pr.xf.basis * Vector3(_r(-0.35, 0.35), 0.0, 0.02)
		var sit := p.at(sid, Vector3(seat.x, seat.y + 0.06, seat.z), yaw, 1.0)
		sit.owner = "court"
		sit.from = 1
		sit.high = n % 4 == 1
	# bicycles on their stands: the gate yard, by each kiosk, at the pavilions
	for spec in [[Vector2(-3.9, 37.8), 1.4], [Vector2(-4.5, 38.3), 1.5], [Vector2(-27.6, -35.6), 0.2], [Vector2(32.0, -14.4), -0.4], [Vector2(-19.8, 28.4), 1.6], [Vector2(12.4, 28.6), 1.7]]:
		var q: Vector2 = spec[0]
		var bike := put(p, "bicycle", q.x, q.y, float(spec[1]), 1.0, Vector3(0.0, 0.0, 0.18))
		bike.tint = [Color(1, 1, 1), Color(0.5, 0.75, 1.1), Color(1.1, 1.1, 0.55), Color(0.6, 1.0, 0.8)][int(absf(q.x)) % 4]
		bike.solid = 0.35
		bike.high = int(absf(q.y)) % 2 == 0
	# more bins, more beds
	for q in [Vector2(-21.0, 30.0), Vector2(20.0, 33.0), Vector2(15.5, -20.0), Vector2(-15.0, -20.0), Vector2(30.0, 12.0)]:
		_bin(p, q.x, q.y)
	for q in [Vector2(-8.0, -41.0), Vector2(12.0, -41.2), Vector2(-3.4, -39.6), Vector2(26.0, 30.0), Vector2(-26.0, 29.0), Vector2(-10.8, 35.0), Vector2(10.8, 35.4)]:
		var bed := put(p, "flower_patch", q.x, q.y, _r(0, TAU), _r(1.3, 1.9))
		bed.high = int(absf(q.x)) % 2 == 0
	# the gate: tournament posters on posts inside the wall (their text is a Label3D in ClubScenery)
	for sx in [-6.0, 6.0]:
		var po := put(p, "poster", sx, 40.3, PI, 1.0)
		po.solid = 0.5
	# bunting at each kiosk, between two poles
	for spec in [[Vector3(-30.0, 0.0, -38.6), Vector2(-30.0, -50.0)], [Vector3(30.0, 0.0, -17.0), Vector2(10.0, -17.0)]]:
		var c: Vector3 = spec[0]
		var yaw := face(Vector2(c.x, c.z), spec[1])
		var fwd := Vector2(sin(yaw), cos(yaw))
		var side := Vector2(fwd.y, -fwd.x)
		var mid := Vector2(c.x, c.z) + fwd * 4.6
		var bn := put(p, "bunting", mid.x, mid.y, atan2(-side.y, side.x), 1.0)
		bn.high = true
		for sg: float in [-1.0, 1.0]:
			var pp := mid + side * 3.0 * sg
			var pole := put(p, "pole", pp.x, pp.y, 0.0, 1.0)
			pole.solid = 0.12
			pole.high = true
	# at the bar once it is built: bunting between two poles west of the terrace
	var bar_b := put(p, "bunting", 11.5, -34.0, PI * 0.5, 1.0)
	bar_b.owner = "bar"
	bar_b.from = 1
	bar_b.high = true
	for z in [-37.0, -31.0]:
		var bp := put(p, "pole", 11.5, z, 0.0, 1.0)
		bp.owner = "bar"
		bp.from = 1
		bp.high = true
	# the street: traffic lights at the crossing, manholes and patches
	for sx in [-4.2, 4.2]:
		var tl := put(p, "trafficlight", sx, 49.7, PI if sx > 0.0 else 0.0, 1.0)
		tl.far = true
		tl.high = true
	for q in [Vector2(-12.0, 52.5), Vector2(15.0, 56.0), Vector2(-26.0, 55.5), Vector2(34.0, 52.8)]:
		p.at("manhole", Vector3(q.x, 0.04, q.y), _r(0, TAU), 1.0)
	# the ball fridge by the players' chairs once the court is fresh
	var fr := p.at("fridge", Vector3(-HX + 0.9, 0.0, -3.7), PI * 0.5, 1.0)
	fr.owner = "court"
	fr.from = 1
	fr.high = true


## The fence's company: the wicket's two posts and the hedges that grow along it in places.
static func _perimeter(p: ClubProps) -> void:
	for x in [-4.35, -1.65]:
		var gp := p.at("gatepost", Vector3(x, LAWN, ClubFence.NORTH), 0.0, 1.0)
		gp.far = true
	var spots := []
	for x in [-48.0, -33.0, -14.0, 14.0, 30.0, 47.0]:
		spots.append([Vector2(x, ClubFence.NORTH + 0.9), Vector2(1, 0)])
	for x in [-47.0, -30.0, 22.0, 40.0]:
		spots.append([Vector2(x, ClubFence.SOUTH - 0.9), Vector2(1, 0)])
	for z in [-30.0, -14.0, 4.0, 22.0, 34.0]:
		spots.append([Vector2(ClubFence.WEST + 0.9, z), Vector2(0, 1)])
		spots.append([Vector2(ClubFence.EAST - 0.9, z + 6.0), Vector2(0, 1)])
	var k := 0
	for sp in spots:
		var c: Vector2 = sp[0]
		var along: Vector2 = sp[1]
		for i in 5:
			var q := c + along * (i - 2) * 0.95
			var h := put(p, "bush_large", q.x, q.y, _r(0.0, TAU), _r(1.0, 1.35))
			h.tint = Color(_r(0.85, 1.0), _r(0.9, 1.05), _r(0.8, 0.95))
			h.high = (k + i) % 2 == 0
		k += 1
