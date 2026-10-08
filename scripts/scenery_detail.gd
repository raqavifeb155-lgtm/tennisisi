class_name SceneryDetail
extends Node3D
## The tournament locations' second layer (stream H-6): props from the club's model pack and
## a few procedural people, baked into two meshes of one material - people in the stands
## and at the fence, benches, lamps, parasols, bikes, palms, flower beds. Each location's
## own Scenery calls `SceneryDetail.apply(self, id)` at the end of its _ready; this node
## draws everything in two calls (one more on High for what casts a shadow) and follows the
## graphics preset (Low keeps half the people) and the pack's arrival by itself.
##
## Budget (the owner's, 08.10): at most +15 draw calls on High and +5 on Low a match.
##
## Placed outside the court's fence, in the places the match camera (behind the near
## player, looking up the court) sees: beside the court and beyond its far end.

const HX := Scenery.HX
const HZ := Scenery.HZ
const LAWN := Scenery.LAWN_Y

var scenery: Node3D
var location := ""
var props := ClubProps.new()
var _nodes := {}
var _gen := -1
var _high := true
var _tuning: Node
var _rng := RandomNumberGenerator.new()
var _dim := 1.0                 # people's colours: duller on a grey day


## The one call from a Scenery's _ready (the club's own world has its own: ClubScenery).
static func apply(s: Node3D, id: String) -> void:
	if s is ClubWorld:
		return
	var d := SceneryDetail.new()
	d.name = "SceneryDetail"
	d.scenery = s
	d.location = id
	s.add_child(d)


func _ready() -> void:
	_rng.seed = 6000 + location.hash() % 1000
	_tuning = get_node_or_null("/root/Tuning")
	_high = _is_high()
	match location:
		"park":
			_park()
		"clay":
			_clay()
		"grass":
			_grass()
		"paris":
			_paris()
	ClubPack.request(self)
	_refresh()


func _process(_delta: float) -> void:
	var high := _is_high()
	if high != _high or ClubPack.generation != _gen:
		_high = high
		_refresh()


func _is_high() -> bool:
	return bool(_tuning.get("gfx_details")) if _tuning != null else true


func _refresh() -> void:
	_gen = ClubPack.generation
	var list := props.visible(func(_o: String) -> int: return 0, _high)
	var baked := ClubProps.bake_one(list, _high)
	for k in ["big", "tall"]:
		var mi: MeshInstance3D = _nodes.get(k)
		if mi == null:
			if not baked.has(k):
				continue
			mi = MeshInstance3D.new()
			mi.name = "detail_" + k
			mi.material_override = ClubScenery.prop_material()
			add_child(mi)
			_nodes[k] = mi
		mi.mesh = baked.get(k)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (k == "tall" and _high) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Helpers ------------------------------------------------------------------------

func _r(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


## The ground under (x, z): the court's apron, else the lawn a curb lower.
static func gy(x: float, z: float) -> float:
	return 0.0 if absf(x) < 12.0 and absf(z) < 20.9 else LAWN


func _put(id: String, x: float, z: float, yaw := 0.0, size = 1.0, y := -99.0) -> ClubProps.Prop:
	return props.at(id, Vector3(x, gy(x, z) if y < -90.0 else y, z), yaw, size)


## A person on a stand: `seat_top` is the height of the seat they sit on.
func _sitter(x: float, z: float, seat_top: float, side: float) -> void:
	var id: String = "sitter_" + ["a", "b", "c"][_rng.randi() % 3]
	var p := props.at(id, Vector3(x, seat_top - 0.55, z), -PI * 0.5 * side, 1.0)
	p.tint = Color(_r(0.8, 1.15), _r(0.8, 1.15), _r(0.8, 1.15)) * _dim
	p.high = _rng.randf() < 0.5


## Somebody standing at a fence or a baseline, facing along `yaw` (front is +z).
func _standee(x: float, z: float, yaw: float, y := -99.0) -> ClubProps.Prop:
	var id: String = "standee_" + ["a", "b", "c"][_rng.randi() % 3]
	var p := _put(id, x, z, yaw, _r(0.94, 1.06), y)
	p.tint = Color(_r(0.8, 1.15), _r(0.8, 1.15), _r(0.8, 1.15))
	p.high = _rng.randf() < 0.5
	return p


func _tree(id: String, x: float, z: float, size := 1.0) -> void:
	var t := _put(id, x, z, _r(0.0, TAU), size * _r(0.9, 1.15))
	t.shadow = true
	t.high = _rng.randf() < 0.4


func _bush_row(from: Vector2, to: Vector2, n: int) -> void:
	for i in n:
		var q := from.lerp(to, (i + 0.5) / n)
		var b := _put("bush_large", q.x, q.y, _r(0.0, TAU), _r(1.0, 1.4))
		b.tint = Color(_r(0.85, 1.0), _r(0.9, 1.05), _r(0.8, 0.95))
		b.high = i % 2 == 0


func _bed(x: float, z: float) -> void:
	var b := _put("flower_patch", x, z, _r(0, TAU), _r(1.4, 2.0))
	b.high = _rng.randf() < 0.6


func _bench(x: float, z: float, toward_x: float) -> void:
	var yaw := PI * 0.5 if toward_x > x else -PI * 0.5
	_put("bench", x, z, yaw, 1.35)
	if _rng.randf() < 0.7:
		var p := _put("sitter_" + ["a", "b", "c"][_rng.randi() % 3], x, z, yaw, 1.0, gy(x, z) + 0.06)
		p.high = _rng.randf() < 0.5


func _lamp(x: float, z: float, toward: Vector2) -> void:
	var d := toward - Vector2(x, z)
	var l := _put("streetlight", x, z, atan2(d.y, -d.x), 1.0)
	l.far = true


func _bike(x: float, z: float, yaw: float) -> void:
	var b := _put("bicycle", x, z, yaw, 1.0)
	b.tint = [Color(1, 1, 1), Color(0.5, 0.75, 1.1), Color(1.1, 1.1, 0.55)][_rng.randi() % 3]
	b.high = true


# --- Locations ----------------------------------------------------------------------

## New York: the aluminium bleachers get their watchers, the fence its leaners, the park its
## lamps, benches with people, bikes, a snack kiosk, beds.
func _park() -> void:
	for r in 4:
		var x := HX + 1.3 + r * 0.7
		var top := 0.4 + r * 0.45 + 0.03
		var z := -14.2
		while z < -3.6:
			if _rng.randf() < 0.55:
				_sitter(x, z, top, 1.0)
			z += 1.1
	for z in [3.0, 5.4, 8.0, 10.6]:
		_standee(HX + 0.9, z, -PI * 0.5)
	for z in [-9.0, -3.0, 4.0, 9.0, 13.0]:
		_standee(-HX - 0.9, z, PI * 0.5)
	for z in [-24.0, -8.0, 8.0]:
		_lamp(HX + 6.0, z, Vector2(HX, z))
		_lamp(-HX - 6.0, z, Vector2(-HX, z))
	_bench(-HX - 3.2, 3.0, -HX)
	_bench(-HX - 3.2, -11.0, -HX)
	_bench(HX + 4.5, 9.0, HX)
	_bike(-HX - 1.2, 7.0, 1.57)
	_bike(-HX - 1.2, 7.9, 1.6)
	var k := _put("kiosk", -HX - 8.0, -13.0, PI * 0.5)
	k.far = true
	var pb := _put("parasol_b", -HX - 5.0, -12.0)
	pb.high = true
	for q in [Vector2(-HX - 4.0, -9.0), Vector2(HX + 3.0, 6.0), Vector2(-HX - 2.5, 12.0)]:
		_bed(q.x, q.y)
	for q in [Vector2(-HX - 4.5, -17.0), Vector2(HX + 4.0, 14.0), Vector2(-HX - 6.5, 9.0)]:
		_put("trash_bin", q.x, q.y, _r(0, TAU))
	_tree("tree_round", HX + 9.0, 2.0)
	_tree("tree_fat", -HX - 10.0, -4.0)


## Spain: spectators on the small white stands, fans at the fence, parasols and tables on the
## terrace, palms, bicycles by the club house, bunting between two palms.
func _clay() -> void:
	for r in 4:
		var x := HX + 1.2 + r * 0.75
		var top := 0.42 + r * 0.45 + 0.03
		var z := -6.0
		while z < 6.2:
			if _rng.randf() < 0.6:
				_sitter(x, z, top, 1.0)
			z += 1.15
	for z in [-9.5, 8.0, 10.5, 12.5]:
		_standee(HX + 0.9, z, -PI * 0.5)
	for z in [-8.0, -2.0, 5.0, 9.0]:
		_standee(-HX - 0.9, z, PI * 0.5)
	for z in [-9.0, -2.0, 5.0]:
		var pb := _put("parasol_b", -HX - 5.0, z)
		pb.high = z != -2.0
		pb.far = true
		var t := _put("bar_table", -HX - 5.0, z, 0.0, 1.1)
		t.high = true
		for a in 2:
			var ang := a * PI + 0.7
			var q := Vector2(-HX - 5.0, z) + Vector2(cos(ang), sin(ang)) * 0.9
			var ch := _put("bar_chair", q.x, q.y, atan2(-cos(ang), -sin(ang)), 1.0)
			ch.high = true
	for q in [Vector2(HX + 9.0, -14.0), Vector2(HX + 12.0, 8.0), Vector2(-HX - 8.0, -20.0)]:
		var pl := _put("palm", q.x, q.y, _r(0, TAU), _r(0.9, 1.1))
		pl.shadow = true
		pl.far = true
	_bike(-HX - 1.2, 9.0, 1.5)
	_bike(-HX - 1.2, 9.9, 1.55)
	for q in [Vector2(HX + 4.5, 14.0), Vector2(-HX - 3.0, 13.0), Vector2(-HX - 4.0, -14.0)]:
		_bed(q.x, q.y)
	for q in [Vector2(HX + 3.8, -12.0), Vector2(-HX - 3.5, 14.5)]:
		_put("trash_bin", q.x, q.y, _r(0, TAU))
	var bn := _put("bunting", HX + 10.5, -3.0, PI * 0.5)
	bn.high = true
	for z in [-6.0, 0.0]:
		_put("pole", HX + 10.5, z).high = true


## England: spectators (some under umbrellas) in the cream stands, fans at the fence, hedges
## and beds behind, benches, bicycles, a flower basket or two.
func _grass() -> void:
	_dim = 0.62
	for side in [1.0, -1.0]:
		var rows := 7 if side > 0.0 else 4
		for r in rows:
			var y := 0.45 + r * 0.42
			var xc: float = side * (HX + 0.5 + (r + 0.5) * 0.85)
			var z := -14.6
			while z < 2.6:
				if absf(z + 6.0) > 0.7 and _rng.randf() < (0.4 if side > 0.0 else 0.55):
					_sitter(xc - side * 0.05, z, y + 0.4, side)
				z += 1.12
	var up := 0
	for q in [Vector2(HX + 2.2, -7.0), Vector2(HX + 3.8, -2.0), Vector2(-HX - 2.0, -10.0), Vector2(-HX - 2.6, -4.0)]:
		var um := _put("parasol", q.x, q.y, 0.0, 0.7, 0.6 + up * 0.42)
		um.tint = [Color(0.3, 0.2, 0.45), Color(0.15, 0.3, 0.22), Color(0.25, 0.25, 0.3), Color(0.35, 0.2, 0.4)][up % 4]
		um.high = up % 2 == 0
		up += 1
	for z in [4.5, 7.5, 11.0]:
		_standee(HX + 0.9, z, -PI * 0.5)
		_standee(-HX - 0.9, z + 1.0, PI * 0.5)
	_bush_row(Vector2(HX + 9.0, -22.0), Vector2(HX + 9.0, -2.0), 8)
	_bush_row(Vector2(-HX - 6.5, -24.0), Vector2(-HX - 6.5, -4.0), 7)
	for q in [Vector2(HX + 3.0, 8.0), Vector2(-HX - 3.0, 8.0), Vector2(-HX - 3.0, -14.0), Vector2(HX + 3.0, 15.0)]:
		_bed(q.x, q.y)
	_bench(-HX - 3.5, 6.0, -HX)
	_bench(HX + 4.2, 8.5, HX)
	_bike(-HX - 1.4, 10.0, 1.5)
	_put("trash_bin", HX + 3.3, 11.5)
	_put("trash_bin", -HX - 3.3, 12.5)
	for x in [-HX - 12.0, HX + 13.0]:
		_tree("tree_round", x, -6.0)


## Paris: the crowd is the stands' own; here the ball kids stand at the baselines' corners,
## and the flower beds line the clay's edge.
func _paris() -> void:
	for q in [Vector2(-5.8, -12.7), Vector2(5.8, -12.7), Vector2(-5.8, 12.7), Vector2(5.8, 12.7), Vector2(-HX + 0.6, 0.0), Vector2(HX - 0.6, 0.0)]:
		var yaw := atan2(-q.x, -q.y) if absf(q.x) < 7.0 else (PI * 0.5 if q.x < 0.0 else -PI * 0.5)
		var p := _standee(q.x, q.y, yaw, 0.0)
		p.tint = Color(0.35, 0.5, 0.95)
		p.high = false
	for sx in [-1.0, 1.0]:
		for z in [-8.0, 0.0, 8.0]:
			var b := _put("flower_patch", sx * (HX + 0.1), z, 0.0, 1.3, 0.0)
			b.high = z != 0.0
