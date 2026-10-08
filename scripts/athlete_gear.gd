class_name AthleteGear
extends RefCounted
## What a player wears, drawn on the body (v0.2 F, docs/superpowers/specs/2026-10-08-v02-gear-skins.md):
## the racket (frame shape and colours, the grip's wrap, the strings, the glow of its
## rarity), the shoes and the wristbands. The look of an item is data: `skin` in the
## catalog (Items.LIST); generated commons and rares look like their slot and rarity.
##
## Draw calls (docs/PERFORMANCE.md): the racket is ONE mesh (rim, throat, shaft and grip
## coloured per vertex) plus the strings, plus one glow mesh (unshaded, additive) from
## epic up; a mythic adds a pulsing ring on the court. Shoes and wristbands are the
## body's own meshes recoloured: no new draw calls. The glow is material only: no real
## light on any preset (a light is an extra pass for every body part near it).
##
## One per Athlete; `dress()` runs after every (re)build of the body.

const SLOTS := ["racket", "shoes", "band"]

## Racket head shapes: half width a, half length b, superellipse power n (2 = an oval),
## tear: wider at the top.
const FRAMES := {
	"classic": {"a": 0.1165, "b": 0.151, "n": 2.0},
	"round": {"a": 0.127, "b": 0.143, "n": 2.0},
	"wide": {"a": 0.134, "b": 0.158, "n": 2.0},
	"slim": {"a": 0.101, "b": 0.158, "n": 2.0},
	"square": {"a": 0.12, "b": 0.148, "n": 3.0},
	"teardrop": {"a": 0.122, "b": 0.155, "n": 2.0, "tear": 0.22},
}
const HEAD_Y := Athlete.RACKET_REACH - 0.02  # centre of the head on the racket's +Y
const TUBE := 0.0115                         # the rim's tube radius
const RIM_SAMPLES := 32
const TUBE_SEGS := 6

## The stock racket (nothing in the slot) and the generated items by slot and rarity.
const STOCK := {"frame": "classic", "color": "#262633", "accent": "#3a3a4a", "grip": "#1b1b1f", "wrap": "#2c2c33", "strings": "#f2f2e6"}
const GENERIC := {
	"racket": [
		{"frame": "classic", "color": "#8b9099", "accent": "#5d626b", "grip": "#1d1d22", "wrap": "#3a3d44", "strings": "#f0f0ea"},
		{"frame": "classic", "color": "#2f6fe0", "accent": "#a9c8ff", "grip": "#f2f4f8", "wrap": "#2f6fe0", "strings": "#eef4ff", "pattern": "stripe"},
	],
}

## Glow by rarity: shader effect, energy of the frame's emission, of the glow mesh, and
## the glow mesh's width (m). Effects: 0 none, 1 a gloss sweeping the frame every 3 s,
## 2 a soft glow with a light running round the rim, 3 a pulse, 4 a heartbeat.
const GLOW := [
	{"fx": 0, "frame": 0.0, "halo": 0.0, "width": 0.0},
	{"fx": 1, "frame": 0.9, "halo": 0.0, "width": 0.0},
	{"fx": 2, "frame": 0.7, "halo": 1.0, "width": 0.035},
	{"fx": 3, "frame": 0.55, "halo": 1.0, "width": 0.06},
	{"fx": 4, "frame": 0.9, "halo": 1.3, "width": 0.09},
]
## Glow colours: the rarity's (UiTheme.RARITY) made purer, so that light added on top
## stays purple, orange or red instead of washing out to white; a rare's gloss is white.
const GLOW_COLORS := [Color(0.7, 0.73, 0.78), Color(0.85, 0.92, 1.0), Color(0.62, 0.3, 1.0),
	Color(1.0, 0.45, 0.05), Color(1.0, 0.1, 0.07)]

var worn := {"racket": {}, "shoes": {}, "band": {}}
var tint := {}                  # set_racket_look: {"color": c, "glow": g} over the racket's skin
var frame: MeshInstance3D       # rim + throat + shaft + grip
var strings: MeshInstance3D
var halo: MeshInstance3D        # the glow round the rim (epic+)
var aura: MeshInstance3D        # a mythic's ring on the court


# --- What is worn -------------------------------------------------------------------

## Items by slot ({} = the stock one); an item without a slot is a racket (old saves).
func wear(items: Array) -> void:
	worn = {"racket": {}, "shoes": {}, "band": {}}
	for it in items:
		if it is Dictionary and not (it as Dictionary).is_empty():
			worn[slot_of(it)] = it
	tint = {}


static func slot_of(item: Dictionary) -> String:
	var s := String(item.get("slot", "racket"))
	return s if s in SLOTS else "racket"


## -1 for an empty slot.
static func rarity_of(item: Dictionary) -> int:
	return -1 if item.is_empty() else clampi(int(item.get("rarity", 0)), 0, Gear.MYTHIC)


## An equip Dictionary {slot: item} as set_gear's list.
static func items_of(equip: Dictionary) -> Array:
	var out: Array = []
	for s in SLOTS:
		out.append(equip.get(s, {}))
	return out


## The look of an item: its own from the catalog, else by slot and rarity.
static func skin_of(item: Dictionary, slot: String) -> Dictionary:
	if item.is_empty():
		return STOCK if slot == "racket" else {}
	var e := Items.find(String(item.get("id", "")))
	if e.has("skin"):
		return e["skin"]
	var r := rarity_of(item)
	var by: Array = GENERIC.get(slot, [])
	if r < by.size():
		return by[r]
	# Epic and up are always catalog items; a stray one wears its rarity's colour.
	var c := "#" + UiTheme.rarity_color(r).to_html(false)
	var base: Dictionary = (by.back() if not by.is_empty() else {}).duplicate()
	for k in ["color", "body", "stripe"]:
		base[k] = c
	return base


static func _c(skin: Dictionary, key: String, fallback: String) -> Color:
	return Color(String(skin.get(key, fallback)))


# --- Dressing the body --------------------------------------------------------------

## Builds the racket and recolours shoes and wristbands for what is worn. The body
## (Athlete._build) must exist; the racket node it poses (_racket) gets new children.
func dress(ath: Athlete) -> void:
	if ath._model == null or ath._racket == null:
		return
	_build_racket(ath)
	_build_aura(ath)


func _build_racket(ath: Athlete) -> void:
	for c in ath._racket.get_children():
		ath._racket.remove_child(c)
		c.queue_free()
	var parts := racket_parts(worn["racket"], ath._body == Athlete.Body.TOON, tint)
	frame = parts[0]
	strings = parts[1]
	halo = parts[2] if parts.size() > 2 else null
	for p in parts:
		ath._racket.add_child(p)


## The racket's meshes for an item: [frame, strings] and the glow from epic up, in
## racket space. `tint` {"color", "glow"} paints the frame and sets the glow (old API).
static func racket_parts(item: Dictionary, toon: bool, tint := {}) -> Array:
	var skin := skin_of(item, "racket")
	var r := rarity_of(item)
	var glow_c: Color = GLOW_COLORS[maxi(r, 0)]
	if not tint.is_empty():
		skin = skin.duplicate()
		skin["color"] = "#" + (tint["color"] as Color).to_html(false)
		r = _tier_of_glow(float(tint["glow"]))
		glow_c = tint["color"]
	var g: Dictionary = GLOW[maxi(r, 0)]
	var f := MeshInstance3D.new()
	f.name = "Frame"
	f.mesh = racket_mesh(skin)
	f.material_override = gear_material(toon, int(g["fx"]), glow_c, float(g["frame"]))
	var s := MeshInstance3D.new()
	s.name = "Strings"
	s.mesh = strings_mesh(skin)
	s.material_override = _strings_material(_c(skin, "strings", "#f2f2e6"))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var out: Array = [f, s]
	if float(g["width"]) > 0.0:
		var h := MeshInstance3D.new()
		h.name = "Glow"
		h.mesh = halo_mesh(skin, float(g["width"]), String(skin.get("halo", "")))
		h.material_override = glow_material(int(g["fx"]), glow_c, float(g["halo"]))
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(h)
	return out


## A racket on its own (a trophy on the court, a shop's shelf, snapshots): +Y from the
## grip to the head.
static func racket_model(item: Dictionary, toon := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Racket"
	for p in racket_parts(item, toon):
		root.add_child(p)
	return root


## A glow energy of the old API (Gear.RARITIES glow) -> a rarity's glow.
static func _tier_of_glow(glow: float) -> int:
	if glow > 2.0:
		return Gear.MYTHIC
	if glow > 1.0:
		return Gear.LEGENDARY
	if glow > 0.0:
		return Gear.EPIC
	return Gear.COMMON


## Any mythic worn: a red ring pulses on the court under the player (seen from the
## match camera, far away), in the racket's glow material.
func _build_aura(ath: Athlete) -> void:
	if aura != null and is_instance_valid(aura):
		if aura.get_parent():
			aura.get_parent().remove_child(aura)
		aura.queue_free()
	aura = null
	var mythic := false
	for s in SLOTS:
		if rarity_of(worn[s]) == Gear.MYTHIC:
			mythic = true
	if not mythic:
		return
	aura = MeshInstance3D.new()
	aura.name = "MythicAura"
	aura.mesh = aura_mesh()
	aura.material_override = glow_material(4, GLOW_COLORS[Gear.MYTHIC], 1.6, true)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = Vector3(0, 0.025, 0)
	ath._model.add_child(aura)


# --- Racket geometry (racket space: +Y from the hand to the head, face in XY) ---------

## A point on the rim at s (0..1 round from the bottom) and the in-plane outward normal.
static func rim_point(skin: Dictionary, s: float) -> Vector3:
	var f: Dictionary = FRAMES.get(String(skin.get("frame", "classic")), FRAMES["classic"])
	var th := TAU * s - PI * 0.5
	var e := 2.0 / float(f["n"])
	var cx := cos(th)
	var sy := sin(th)
	var x := float(f["a"]) * signf(cx) * pow(absf(cx), e)
	var y := float(f["b"]) * signf(sy) * pow(absf(sy), e)
	x *= 1.0 + float(f.get("tear", 0.0)) * (y / float(f["b"]))
	return Vector3(x, HEAD_Y + y, 0.0)


static func _rim_frame(skin: Dictionary, s: float) -> Array:
	var p := rim_point(skin, s)
	var t := (rim_point(skin, s + 0.002) - rim_point(skin, s - 0.002)).normalized()
	var out := t.cross(Vector3.BACK).normalized()
	if out.dot(p - Vector3(0, HEAD_Y, 0)) < 0.0:
		out = -out
	return [p, t, out]


## Rim, throat, shaft and grip in one mesh. Vertex colour alpha is the glow mask
## (1 rim accents, 0.55 rim, 0.3 throat, 0 grip); UV.x runs round the rim.
static func racket_mesh(skin: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := _c(skin, "color", "#262633").srgb_to_linear()
	var acc := _c(skin, "accent", "#3a3a4a").srgb_to_linear()
	var grip := _c(skin, "grip", "#1b1b1f").srgb_to_linear()
	var wrap := _c(skin, "wrap", "#2c2c33").srgb_to_linear()
	var pattern := String(skin.get("pattern", ""))
	var tube := TUBE * float(skin.get("tube", 1.0))
	# Rim: a tube along the head's curve.
	var rings: Array = []
	for i in RIM_SAMPLES + 1:
		var s := float(i) / RIM_SAMPLES
		var fr := _rim_frame(skin, fmod(s, 1.0))
		rings.append({"p": fr[0], "n": fr[2], "b": Vector3.BACK, "r": tube, "u": s})
	_tube(st, rings, TUBE_SEGS, func(s: float, phi: float, p: Vector3) -> Color:
		var accent := _rim_accent(pattern, s, phi, p)
		var c := acc if accent else col
		c.a = 1.0 if accent else 0.55
		return c)
	# Throat: two bars from the top of the shaft to the rim's lower sides.
	for side in [-1.0, 1.0]:
		var at := _rim_frame(skin, 0.5 + side * (0.5 - 0.118))
		var from := Vector3(side * 0.012, 0.285, 0.0)
		var to: Vector3 = at[0] - (at[2] as Vector3) * tube * 0.5
		var d := (to - from).normalized()
		var n := d.cross(Vector3.BACK).normalized()
		var bar: Array = []
		for k in 3:
			bar.append({"p": from.lerp(to, k / 2.0), "n": n, "b": Vector3.BACK, "r": tube * 0.78, "u": 0.0})
		_tube(st, bar, TUBE_SEGS, func(_s: float, _phi: float, _p: Vector3) -> Color:
			var c := acc
			c.a = 0.3
			return c)
	# Shaft and grip, straight down +Y: the wrap spirals round the handle; a cap at the butt.
	var hand: Array = []
	hand.append({"p": Vector3(0, -0.036, 0), "r": 0.0, "u": 0.0})
	hand.append({"p": Vector3(0, -0.034, 0), "r": 0.0175, "u": 0.0})
	for k in 17:
		hand.append({"p": Vector3(0, -0.028 + 0.23 * k / 16.0, 0), "r": 0.0185, "u": float(k) / 16.0})
	hand.append({"p": Vector3(0, 0.21, 0), "r": 0.014, "u": 1.0})
	hand.append({"p": Vector3(0, 0.3, 0), "r": 0.011, "u": 1.0})
	for h in hand:
		h["n"] = Vector3.RIGHT
		h["b"] = Vector3.BACK
	_tube(st, hand, 8, func(s: float, phi: float, p: Vector3) -> Color:
		var c: Color
		if p.y < -0.025:
			c = acc                       # butt cap
		elif p.y > 0.205:
			c = col                       # shaft
		else:
			c = wrap if fposmod(s * 5.0 + phi / TAU, 1.0) < 0.32 else grip
		c.a = 0.0
		return c)
	return st.commit()


## Whether a rim vertex takes the accent colour, by the skin's pattern.
static func _rim_accent(pattern: String, s: float, phi: float, p: Vector3) -> bool:
	match pattern:
		"edge":
			return cos(phi) > 0.3                       # the outer edge
		"stripe":
			return cos(phi) > 0.8                       # a thin line round the outside
		"spiral":
			return fposmod(s * 10.0 + phi / TAU, 1.0) < 0.5
		"segments":
			return int(floor(s * 12.0)) % 2 == 1
		"twotone":
			return p.y < HEAD_Y
		"veins":
			return fposmod(s * 7.0 + 0.6 * sin(phi * 2.0), 1.0) < 0.2
		"core":
			return cos(phi) > -0.2                      # bright outside a dark core
	return false


## A tube through rings {p, n, b, r, u}: the circle at each ring spans n (phi 0) and b.
static func _tube(st: SurfaceTool, rings: Array, segs: int, colour: Callable) -> void:
	# SurfaceTool has no vertex count: index from the tool's own running total.
	var base: int = st.get_meta("count", 0)
	for ring in rings:
		var p: Vector3 = ring["p"]
		var n: Vector3 = ring["n"]
		var b: Vector3 = ring["b"]
		var r: float = ring["r"]
		for j in segs + 1:
			var phi := TAU * float(j) / segs
			var dir := n * cos(phi) + b * sin(phi)
			st.set_color(colour.call(float(ring["u"]), phi, p))
			st.set_normal(dir if r > 0.0 else (p - (rings[1]["p"] as Vector3)).normalized())
			st.set_uv(Vector2(float(ring["u"]), phi / TAU))
			st.add_vertex(p + dir * r)
	for i in rings.size() - 1:
		for j in segs:
			var a0 := base + i * (segs + 1) + j
			var b0 := a0 + segs + 1
			st.add_index(a0)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(b0 + 1)
			st.add_index(b0)
	st.set_meta("count", base + rings.size() * (segs + 1))


## The strings: a flat fan inside the rim (two-sided, see-through).
static func strings_mesh(skin: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tube := TUBE * float(skin.get("tube", 1.0))
	var centre := Vector3(0, HEAD_Y, 0)
	st.set_normal(Vector3.BACK)
	st.add_vertex(centre)
	for i in RIM_SAMPLES:
		var fr := _rim_frame(skin, float(i) / RIM_SAMPLES)
		st.add_vertex((fr[0] as Vector3) - (fr[2] as Vector3) * tube * 0.6)
	for i in RIM_SAMPLES:
		st.add_index(0)
		st.add_index(1 + i)
		st.add_index(1 + (i + 1) % RIM_SAMPLES)
	return st.commit()


## The glow round the rim: a soft shell over the tube and a band fading outward in the
## face's plane, plus the skin's pattern (`halo`: rays, flames, bolts, double, spiral).
## Vertex alpha is the strength; UV.x runs round the rim (the running light).
static func halo_mesh(skin: Dictionary, width: float, pattern: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tube := TUBE * float(skin.get("tube", 1.0))
	var shell: Array = []
	for i in RIM_SAMPLES + 1:
		var s := float(i) / RIM_SAMPLES
		var fr := _rim_frame(skin, fmod(s, 1.0))
		shell.append({"p": fr[0], "n": fr[2], "b": Vector3.BACK, "r": tube * 2.4, "u": s})
	_tube(st, shell, TUBE_SEGS, func(_s: float, _phi: float, _p: Vector3) -> Color:
		return Color(1, 1, 1, 0.3))
	# The band: rim edge -> width out, strong to nothing.
	var band: Array = []
	for i in RIM_SAMPLES + 1:
		var s := float(i) / RIM_SAMPLES
		var fr := _rim_frame(skin, fmod(s, 1.0))
		band.append([fr[0] as Vector3 + (fr[2] as Vector3) * tube, fr[2], s])
	_strip(st, band, width, 0.6, 0.0)
	match pattern:
		"rays", "flames":
			var n := 12 if pattern == "rays" else 16
			for k in n:
				var s := (float(k) + 0.5) / n
				var fr := _rim_frame(skin, s)
				var p: Vector3 = fr[0] as Vector3 + (fr[2] as Vector3) * tube
				var t: Vector3 = fr[1]
				var long := (1.25 if k % 2 == 0 else 0.8) if pattern == "rays" else 0.7 + 0.5 * absf(sin(k * 2.3))
				var hw := 0.02 if pattern == "rays" else 0.011
				_tri(st, p - t * hw, p + t * hw, p + (fr[2] as Vector3) * width * long + t * (0.0 if pattern == "rays" else hw * 0.8), s, 0.95)
		"bolts":
			for k in 6:
				var s := (float(k) + 0.25) / 6.0
				var fr := _rim_frame(skin, s)
				var o: Vector3 = fr[2]
				var t: Vector3 = fr[1]
				var p0: Vector3 = fr[0] as Vector3 + o * tube
				var pts := [p0, p0 + o * width * 0.4 + t * 0.014, p0 + o * width * 0.7 - t * 0.01, p0 + o * width * 1.15 + t * 0.008]
				for q in 3:
					var a: Vector3 = pts[q]
					var b: Vector3 = pts[q + 1]
					var side := (b - a).cross(Vector3.BACK).normalized() * 0.004
					_quad(st, a - side, a + side, b + side, b - side, s, 0.95 - 0.2 * q)
		"double":
			var outer: Array = []
			for i in RIM_SAMPLES + 1:
				var s := float(i) / RIM_SAMPLES
				var fr := _rim_frame(skin, fmod(s, 1.0))
				outer.append([fr[0] as Vector3 + (fr[2] as Vector3) * (tube + width * 0.55), fr[2], s])
			_strip(st, outer, 0.008, 0.9, 0.9)
		"spiral":
			for arm in 3:
				var pts: Array = []
				for k in 13:
					var f := float(k) / 12.0
					var s := fposmod(arm / 3.0 + f * 0.6, 1.0)
					var p := Vector3(0, HEAD_Y, 0).lerp(rim_point(skin, s), 0.15 + 0.8 * f)
					pts.append([p, Vector3.RIGHT, s])
				for k in 12:
					var a: Vector3 = pts[k][0]
					var b: Vector3 = pts[k + 1][0]
					var side := (b - a).cross(Vector3.BACK).normalized() * 0.005
					_quad(st, a - side, a + side, b + side, b - side, float(pts[k][2]), 0.9)
	return st.commit()


## A flat band in the face's plane along points [p, out, u], `width` outward, alpha a0 -> a1.
static func _strip(st: SurfaceTool, pts: Array, width: float, a0: float, a1: float) -> void:
	for i in pts.size() - 1:
		var p: Vector3 = pts[i][0]
		var q: Vector3 = pts[i + 1][0]
		var po: Vector3 = p + (pts[i][1] as Vector3) * width
		var qo: Vector3 = q + (pts[i + 1][1] as Vector3) * width
		var u0 := float(pts[i][2])
		var u1 := float(pts[i + 1][2])
		_vert(st, p, u0, a0)
		_vert(st, q, u1, a0)
		_vert(st, qo, u1, a1)
		_vert(st, p, u0, a0)
		_vert(st, qo, u1, a1)
		_vert(st, po, u0, a1)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, tip: Vector3, u: float, alpha: float) -> void:
	_vert(st, a, u, alpha)
	_vert(st, b, u, alpha)
	_vert(st, tip, u, 0.0)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float, alpha: float) -> void:
	for p in [a, b, c, a, c, d]:
		_vert(st, p, u, alpha)


## Glow meshes mix indexed tubes and plain triangles: plain ones are indexed too.
static func _vert(st: SurfaceTool, p: Vector3, u: float, alpha: float) -> void:
	var n: int = st.get_meta("count", 0)
	st.set_color(Color(1, 1, 1, alpha))
	st.set_normal(Vector3.BACK)
	st.set_uv(Vector2(u, 0.0))
	st.add_vertex(p)
	st.add_index(n)
	st.set_meta("count", n + 1)


## A ring on the court (model space, XZ): nothing -> strong -> nothing.
static func aura_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [[0.42, 0.0], [0.66, 0.85], [0.76, 0.85], [1.08, 0.0]]
	var segs := 40
	for k in radii.size() - 1:
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var r0: float = radii[k][0]
			var r1: float = radii[k + 1][0]
			var p := [Vector3(cos(a0) * r0, 0, sin(a0) * r0), Vector3(cos(a1) * r0, 0, sin(a1) * r0),
				Vector3(cos(a1) * r1, 0, sin(a1) * r1), Vector3(cos(a0) * r1, 0, sin(a0) * r1)]
			var al: Array = [radii[k][1], radii[k][1], radii[k + 1][1], radii[k + 1][1]]
			var us: Array = [float(i) / segs, float(i + 1) / segs, float(i + 1) / segs, float(i) / segs]
			for q in [0, 1, 2, 0, 2, 3]:
				_vert(st, p[q], us[q], al[q])
	return st.commit()


# --- Materials (shared: one per look, not per player) --------------------------------

## The pulse of a glow effect (see GLOW), the same in the lit and the glow shaders.
const PULSE := """
float gear_pulse(int mode, float u, float t) {
	if (mode == 1) {
		float p = fract(t / 3.0) * 1.6 - 0.3;
		return smoothstep(0.14, 0.0, abs(u - p));
	}
	if (mode == 2) {
		float s = fract(u - t * 0.4);
		return 0.5 + 0.9 * smoothstep(0.1, 0.0, min(s, 1.0 - s));
	}
	if (mode == 3) {
		return 0.62 + 0.38 * sin(t * 6.0);
	}
	if (mode == 4) {
		float p = fract(t * 1.1);
		float b = exp(-pow(p * 12.0, 2.0)) + exp(-pow((p - 1.0) * 12.0, 2.0)) + 0.75 * exp(-pow((p - 0.24) * 12.0, 2.0));
		return 0.45 + 1.1 * b;
	}
	return 1.0;
}
"""

## Lit like the body (Athlete._toonify: wrap light, toon highlight, rim), coloured by
## the vertices, glowing where the vertex alpha says.
const LIT_TOON := "shader_type spatial;\nrender_mode diffuse_lambert_wrap, specular_toon;\n"
const LIT_PLAIN := "shader_type spatial;\n"
const LIT_BODY := """
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float energy = 0.0;
uniform int fx = 0;
uniform float rough = 0.55;
uniform float rim_amount = 0.55;
%s
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = rough;
	RIM = rim_amount;
	RIM_TINT = 0.4;
	EMISSION = glow.rgb * energy * gear_pulse(fx, UV.x, TIME) * COLOR.a;
}
"""
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 glow : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform int fx = 0;
%s
void fragment() {
	ALBEDO = glow.rgb * energy * gear_pulse(fx, UV.x, TIME);
	ALPHA = clamp(COLOR.a * gear_pulse(fx, UV.x, TIME), 0.0, 1.0);
}
"""

static var _shaders := {}
static var _materials := {}


static func _shader(kind: String) -> Shader:
	if not _shaders.has(kind):
		var sh := Shader.new()
		match kind:
			"toon":
				sh.code = LIT_TOON + LIT_BODY % PULSE
			"plain":
				sh.code = LIT_PLAIN + LIT_BODY % PULSE
			"glow_mix":
				sh.code = (GLOW_SHADER % PULSE).replace("blend_add", "blend_mix")
			_:
				sh.code = GLOW_SHADER % PULSE
		_shaders[kind] = sh
	return _shaders[kind]


## The lit gear material: TOON gets the body's outline as its next pass.
static func gear_material(toon: bool, fx: int, glow: Color, energy: float) -> ShaderMaterial:
	var key := "lit|%s|%d|%s|%.2f" % [toon, fx, glow.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = _shader("toon" if toon else "plain")
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("fx", fx)
	m.set_shader_parameter("rough", 0.55 if toon else 0.8)
	m.set_shader_parameter("rim_amount", 0.55 if toon else 0.0)
	if toon and Athlete._toon_outline != null:
		m.next_pass = Athlete._toon_outline  # made by the TOON body built just before
	_materials[key] = m
	return m


## Unshaded light added on top; `mix`: painted over instead (the court ring: added red
## on a blue court would turn pink).
static func glow_material(fx: int, glow: Color, energy: float, mix := false) -> ShaderMaterial:
	var key := "glow|%d|%s|%.2f|%s" % [fx, glow.to_html(), energy, mix]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = _shader("glow_mix" if mix else "glow")
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("fx", fx)
	m.render_priority = 1
	_materials[key] = m
	return m


static func _strings_material(c: Color) -> StandardMaterial3D:
	var key := "strings|%s" % c.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = m
	return m
