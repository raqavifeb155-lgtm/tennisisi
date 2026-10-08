class_name ClubLevels
## What each construction shows at each level (docs/club/CLUB_BRIEF.md 3, H2_SPEC 8):
## built in code from boxes and cylinders under ClubMaterial, in world coordinates, into
## a root node ClubWorld gives (and rebuilds when the level changes). The same function
## builds the ghost of the next level on the foreman's card (`ghost`: no obstacles, no
## side effects). Prices and perks live in ClubBuilds; this only draws.

const HX := Scenery.HX
const HZ := Scenery.HZ
const STANDS_X0 := Scenery.HX + 0.8      # the stands hug the court's east fence
const STANDS_X1 := Scenery.HX + 4.2
const GATE_Z := 41.0
const TROPHY := Vector3(-18, 0, -28.8)    # the trophy wall, behind its circle
const BAR := Vector3(20, 0, -33.2)        # the roulette table (ClubWorld._build_bar_table)


static func has(id: String) -> bool:
	return id in ["court", "stands", "gate", "trophy", "bar"]


static func build(w: ClubWorld, id: String, root: Node3D, lv: int, ghost := false) -> void:
	match id:
		"court":
			_court(w, root, lv, ghost)
		"stands":
			_stands(w, root, lv, ghost)
		"gate":
			_gate(w, root, lv, ghost)
		"trophy":
			_trophy(w, root, lv, ghost)
		"bar":
			_bar(w, root, lv, ghost)


# --- Small builders -----------------------------------------------------------------

static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if size.y > 1.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _cyl(root: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material, segs := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 0
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if h > 1.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _label(root: Node3D, text: String, pos: Vector3, px: float, col: Color, outline := Color(0, 0, 0, 0)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.display()
	l.font_size = 72
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 12 if outline.a > 0.0 else 0
	l.outline_modulate = outline
	l.shaded = false
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.position = pos
	root.add_child(l)
	return l


static func _obstacle_box(w: ClubWorld, ghost: bool, tag: String, r: Rect2) -> void:
	if not ghost:
		w.walk.add_box(r, tag)


static func _obstacle_circle(w: ClubWorld, ghost: bool, tag: String, c: Vector2, r: float) -> void:
	if not ghost:
		w.walk.add_circle(c, r, tag)


static func _car(root: Node3D, at: Vector3, col: Color, sport: bool) -> void:
	var body := ClubMaterial.get_mat(col)
	var glass := ClubMaterial.pal(ClubMaterial.GLASS, false)
	var tyre := ClubMaterial.pal(ClubMaterial.BLACK, false)
	var len := 4.2 if sport else 3.8
	var h := 0.55 if sport else 0.75
	_box(root, Vector3(1.8, h, len), at + Vector3(0, 0.3 + h * 0.5, 0), body)
	var cab := Vector3(1.6, 0.45 if sport else 0.7, len * (0.4 if sport else 0.55))
	_box(root, cab, at + Vector3(0, 0.3 + h + cab.y * 0.5, 0.15 if sport else 0.2), glass)
	for x in [-0.85, 0.85]:
		for z in [-len * 0.32, len * 0.32]:
			var t := _cyl(root, 0.32, 0.32, 0.25, at + Vector3(x, 0.32, z), tyre, 10)
			t.rotation.z = PI * 0.5


static func _crowd(root: Node3D, places: Array, shirt: Color, rng_seed: int) -> void:
	if places.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var bodies: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var cols: Array[Color] = []
	var skins: Array[Color] = []
	for p in places:
		var at: Vector3 = p
		bodies.append(Transform3D(Basis.IDENTITY, at + Vector3(0, 0.38, 0)))
		heads.append(Transform3D(Basis.IDENTITY, at + Vector3(0, 0.92, 0)))
		cols.append(shirt.lightened(rng.randf_range(-0.15, 0.25)) if rng.randf() < 0.8 else ClubMaterial.PALETTE[ClubMaterial.WHITE])
		skins.append(Looks.SKIN[rng.randi() % Looks.SKIN.size()])
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 0.76
	cap.radial_segments = 6
	cap.rings = 1
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.radial_segments = 6
	head.rings = 3
	_mm(root, cap, bodies, cols)
	_mm(root, head, heads, skins)


static func _mm(root: Node3D, mesh: Mesh, xf: Array[Transform3D], cols: Array[Color]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ClubMaterial.tinted()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	return mmi


# --- Main court -----------------------------------------------------------------------

static func _court(w: ClubWorld, root: Node3D, lv: int, ghost: bool) -> void:
	if not ghost:
		w.set_worn(lv == 0)  # level 1: fresh paint, bright lines
	var tag := "lvl_court"
	if lv >= 2:
		# New posts and lamps at the corners, benches for the players by the west fence.
		var dark := ClubMaterial.pal(ClubMaterial.METAL_DARK)
		for x in [-HX - 0.4, HX + 0.4]:
			for z in [-HZ + 1.0, HZ - 1.0]:
				_cyl(root, 0.08, 0.1, 6.0, Vector3(x, 3.0, z), dark, 6)
				_box(root, Vector3(0.9, 0.18, 0.45), Vector3(x - signf(x) * 0.3, 6.0, z), ClubMaterial.pal(ClubMaterial.METAL_DARK, false))
				_box(root, Vector3(0.8, 0.05, 0.35), Vector3(x - signf(x) * 0.3, 5.9, z), ClubMaterial.glow(ClubMaterial.PALETTE[ClubMaterial.NEON], 1.0))
				_obstacle_circle(w, ghost, tag, Vector2(x, z), 0.25)
		for z in [-6.0, 6.0]:
			_box(root, Vector3(0.5, 0.08, 2.4), Vector3(-HX - 1.4, 0.45, z), ClubMaterial.pal(ClubMaterial.WOOD))
			_box(root, Vector3(0.08, 0.5, 2.4), Vector3(-HX - 1.65, 0.75, z), ClubMaterial.pal(ClubMaterial.WOOD))
			_obstacle_box(w, ghost, tag, Rect2(-HX - 1.7, z - 1.2, 0.6, 2.4))
	if lv >= 3:
		# The club's colour on the run-off around the doubles court.
		var c := ClubMaterial.get_mat(ClubBuilds.club_color(), false)
		var dx := Court.DOUBLES_HALF_WIDTH + 0.06
		var dz := Court.HALF_LENGTH + 0.06
		var y := 0.03
		_box(root, Vector3(HX - dx, 0.01, HZ * 2.0), Vector3(-(dx + HX) * 0.5, y, 0), c)
		_box(root, Vector3(HX - dx, 0.01, HZ * 2.0), Vector3((dx + HX) * 0.5, y, 0), c)
		_box(root, Vector3(dx * 2.0, 0.01, HZ - dz), Vector3(0, y, (dz + HZ) * 0.5), c)
		_box(root, Vector3(dx * 2.0, 0.01, HZ - dz), Vector3(0, y, -(dz + HZ) * 0.5), c)
	if lv >= 4:
		# The logo behind the near baseline and the name on the far backdrop.
		var logo := _label(root, ClubBuilds.club_name().to_upper(), Vector3(0, 0.05, 15.2), 0.014, UiTheme.GOLD, Color(0.08, 0.06, 0.1, 0.8))
		logo.rotation.x = -PI * 0.5
		_box(root, Vector3(10.0, 1.3, 0.06), Vector3(0, 1.4, -HZ + 0.2), ClubMaterial.get_mat(ClubBuilds.club_color()))
		var back := _label(root, ClubBuilds.club_name().to_upper(), Vector3(0, 1.4, -HZ + 0.25), 0.012, Color.WHITE)
		back.double_sided = false


# --- Stands ---------------------------------------------------------------------------

static func _stands(w: ClubWorld, root: Node3D, lv: int, ghost: bool) -> void:
	var tag := "lvl_stands"
	var x0 := STANDS_X0
	var x1 := STANDS_X1
	var z0 := -14.0
	var z1 := -4.0
	if lv == 0:
		var corners := [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]
		var wood := ClubMaterial.pal(ClubMaterial.WOOD, false)
		var red := ClubMaterial.pal(ClubMaterial.RED, false)
		var white := ClubMaterial.pal(ClubMaterial.WHITE, false)
		for c in corners:
			_box(root, Vector3(0.08, 0.9, 0.08), (c as Vector3) + Vector3(0, 0.45, 0), wood)
		for i in 4:
			var a: Vector3 = corners[i] + Vector3(0, 0.8, 0)
			var b: Vector3 = corners[(i + 1) % 4] + Vector3(0, 0.8, 0)
			var n := int(a.distance_to(b) / 0.5)
			for k in n:
				var p := a.lerp(b, (k + 0.5) / n)
				var along := (b - a).normalized()
				_box(root, Vector3(0.5 if absf(along.x) > 0.5 else 0.05, 0.05, 0.05 if absf(along.x) > 0.5 else 0.5), p, red if k % 2 == 0 else white)
		if not ghost:
			w.stands_sign(true, "Здесь будут трибуны · %d" % ClubBuilds.next_price("stands"))
		_obstacle_box(w, ghost, tag, Rect2(x0, z0, x1 - x0, z1 - z0))
		return
	if not ghost:
		w.stands_sign(false, "")
	var wood := ClubMaterial.pal(ClubMaterial.WOOD)
	var seat := ClubMaterial.get_mat(ClubBuilds.club_color()) if lv >= 3 else wood
	if lv == 1:
		for z in [-11.5, -6.5]:
			_box(root, Vector3(0.5, 0.08, 2.6), Vector3(x0 + 1.2, 0.45, z), wood)
			_box(root, Vector3(0.08, 0.5, 2.6), Vector3(x0 + 1.45, 0.75, z), wood)
			for dz in [-1.1, 1.1]:
				_box(root, Vector3(0.4, 0.42, 0.08), Vector3(x0 + 1.2, 0.21, z + dz), ClubMaterial.pal(ClubMaterial.METAL_DARK, false))
			_obstacle_box(w, ghost, tag, Rect2(x0 + 0.9, z - 1.3, 0.7, 2.6))
		return
	# A stand of three steps along the court; longer from level 3.
	if lv >= 3:
		z0 = -17.0
		z1 = 1.0
	var steps := 3
	var dx := (x1 - x0) / steps
	for i in steps:
		var h := 0.45 * (i + 1)
		_box(root, Vector3(dx, h, z1 - z0), Vector3(x0 + dx * (i + 0.5), h * 0.5, (z0 + z1) * 0.5), ClubMaterial.pal(ClubMaterial.CONCRETE))
		_box(root, Vector3(dx * 0.6, 0.08, z1 - z0 - 0.2), Vector3(x0 + dx * (i + 0.65), h + 0.04, (z0 + z1) * 0.5), seat)
	_box(root, Vector3(0.06, 1.0, z1 - z0), Vector3(x1 + 0.03, 1.35 + 0.5, (z0 + z1) * 0.5), ClubMaterial.pal(ClubMaterial.METAL, false))
	_obstacle_box(w, ghost, tag, Rect2(x0, z0, x1 - x0, z1 - z0))
	if lv >= 3:
		var people: Array = []
		var full := lv >= 5
		var every := 1 if full else 2
		var low := not w.high_quality()
		var n := 0
		for i in steps:
			var h := 0.45 * (i + 1)
			var z := z0 + 0.6
			while z < z1 - 0.4:
				n += 1
				if n % every == 0 and not (low and n % 2 == 1):
					people.append(Vector3(x0 + dx * (i + 0.65), h + 0.08, z + (0.15 if i % 2 == 1 else 0.0)))
				z += 0.75
		_crowd(root, people, ClubBuilds.club_color(), 31 + lv)
	if lv >= 4:
		# A canopy on posts and the club's flags.
		var dark := ClubMaterial.pal(ClubMaterial.METAL_DARK)
		# A cantilever over the back rows (the front rows and the crowd stay in view).
		for z in [z0 + 0.3, (z0 + z1) * 0.5, z1 - 0.3]:
			_cyl(root, 0.07, 0.07, 3.6, Vector3(x1 - 0.2, 1.8, z), dark, 6)
		var roof := _box(root, Vector3(1.8, 0.12, z1 - z0 + 0.4), Vector3(x1 - 0.7, 3.65, (z0 + z1) * 0.5), ClubMaterial.get_mat(ClubBuilds.club_color()))
		roof.rotation.z = deg_to_rad(10.0)
		for k in 3:
			var z := lerpf(z0 + 2.0, z1 - 2.0, k / 2.0)
			_cyl(root, 0.03, 0.03, 2.0, Vector3(x1 + 0.1, 4.6, z), dark, 6)
			_box(root, Vector3(0.03, 0.6, 1.0), Vector3(x1 + 0.1, 5.25, z + 0.5), ClubMaterial.get_mat(ClubBuilds.club_color() if k != 1 else UiTheme.GOLD, false))


# --- The way in -----------------------------------------------------------------------

static func _gate(w: ClubWorld, root: Node3D, lv: int, ghost: bool) -> void:
	var tag := "lvl_gate"
	var z := GATE_Z
	if lv == 0:
		_label(root, "PUBLIC COURTS", Vector3(0, 2.25, z + 0.05), 0.006, Color(0.95, 0.93, 0.86), Color(0.12, 0.2, 0.16))
		return
	var name := ClubBuilds.club_name().to_upper()
	if lv >= 3:
		# Stone pillars and a neon sign.
		var stone := ClubMaterial.pal(ClubMaterial.CONCRETE)
		for s in [-1.0, 1.0]:
			_box(root, Vector3(1.0, 3.6, 1.0), Vector3(s * 1.9, 1.8, z), stone)
			_box(root, Vector3(1.2, 0.25, 1.2), Vector3(s * 1.9, 3.7, z), ClubMaterial.pal(ClubMaterial.PLASTER))
		_box(root, Vector3(4.8, 0.7, 0.3), Vector3(0, 3.35, z), ClubMaterial.pal(ClubMaterial.METAL_DARK))
		_label(root, name, Vector3(0, 3.35, z + 0.17), 0.0075, ClubMaterial.PALETTE[ClubMaterial.NEON] * 1.4, Color(1.0, 0.55, 0.2, 0.9))
	else:
		# A wooden sign on a beam over the gate.
		_box(root, Vector3(4.2, 0.2, 0.2), Vector3(0, 2.75, z), ClubMaterial.pal(ClubMaterial.WOOD_DARK))
		_box(root, Vector3(3.6, 0.65, 0.08), Vector3(0, 3.2, z), ClubMaterial.pal(ClubMaterial.WOOD))
		_label(root, name, Vector3(0, 3.2, z + 0.05), 0.0055, Color(0.24, 0.15, 0.08))
	if lv >= 2:
		# The car park inside the gate, east of the path, with a hatchback.
		var park := Rect2(4.0, 33.5, 9.0, 6.0)
		_box(root, Vector3(park.size.x, 0.02, park.size.y), Vector3(park.get_center().x, 0.03, park.get_center().y), ClubMaterial.pal(ClubMaterial.METAL_DARK, false))
		for k in 4:
			_box(root, Vector3(0.1, 0.012, 4.5), Vector3(park.position.x + 0.4 + k * 2.8, 0.045, park.get_center().y), ClubMaterial.pal(ClubMaterial.WHITE, false))
		_car(root, Vector3(5.6, 0, 36.5), ClubMaterial.PALETTE[ClubMaterial.RED], false)
		_obstacle_box(w, ghost, tag, Rect2(4.6, 34.5, 2.0, 4.0))
	if lv >= 4:
		_car(root, Vector3(8.4, 0, 36.5), UiTheme.GOLD, true)
		_obstacle_box(w, ghost, tag, Rect2(7.4, 34.3, 2.0, 4.4))


# --- Trophy room ----------------------------------------------------------------------

static func _trophy(w: ClubWorld, root: Node3D, lv: int, ghost: bool) -> void:
	if lv == 0:
		return
	var tag := "lvl_trophy"
	var at := TROPHY
	var wood := ClubMaterial.pal(ClubMaterial.WOOD_DARK)
	_box(root, Vector3(4.0, 0.12, 2.0), at + Vector3(0, 0.06, 0.4), ClubMaterial.pal(ClubMaterial.WOOD, false))
	_box(root, Vector3(4.0, 2.6, 0.25), at + Vector3(0, 1.3, -0.3), wood)
	for y in [0.9, 1.6]:
		_box(root, Vector3(3.6, 0.07, 0.45), at + Vector3(0, y, -0.05), ClubMaterial.pal(ClubMaterial.WOOD))
	_obstacle_box(w, ghost, tag, Rect2(at.x - 2.0, at.z - 0.5, 4.0, 0.8))
	# A cup for every title (up to 12; more is "×N").
	var cups: Array[Transform3D] = []
	var gold: Array[Color] = []
	var n := mini(SaveData.titles, 12) if not ghost else 6
	for i in n:
		var row := i / 6
		cups.append(Transform3D(Basis.IDENTITY, at + Vector3(-1.5 + (i % 6) * 0.6, 0.93 + row * 0.7 + 0.12, -0.05)))
		gold.append(UiTheme.GOLD)
	if not cups.is_empty():
		var cup := CylinderMesh.new()
		cup.top_radius = 0.11
		cup.bottom_radius = 0.05
		cup.height = 0.24
		cup.radial_segments = 8
		cup.rings = 0
		_mm(root, cup, cups, gold)
	if SaveData.titles > 12 and not ghost:
		_label(root, "×%d" % SaveData.titles, at + Vector3(1.6, 2.2, -0.15), 0.006, UiTheme.GOLD)
	if lv >= 2:
		# A glass case: the best things glow in their rarity's colour.
		_box(root, Vector3(1.4, 0.9, 0.7), at + Vector3(3.0, 0.45, 0.2), ClubMaterial.pal(ClubMaterial.METAL_DARK, false))
		_box(root, Vector3(1.4, 0.6, 0.7), at + Vector3(3.0, 1.2, 0.2), ClubMaterial.pal(ClubMaterial.GLASS, false))
		var glows := [Color(0.62, 0.4, 0.95), UiTheme.GOLD, Color(0.35, 0.6, 1.0)]
		for k in 3:
			_box(root, Vector3(0.22, 0.3, 0.06), at + Vector3(2.6 + k * 0.4, 1.15, 0.2), ClubMaterial.glow(glows[k], 1.2))
		_obstacle_box(w, ghost, tag, Rect2(at.x + 2.3, at.z - 0.15, 1.4, 0.7))
	if lv >= 3:
		# The hall: a pedestal with the big cup under a spotlight.
		_cyl(root, 0.45, 0.55, 1.0, at + Vector3(-3.0, 0.5, 0.3), ClubMaterial.pal(ClubMaterial.PLASTER), 10)
		_cyl(root, 0.28, 0.12, 0.55, at + Vector3(-3.0, 1.3, 0.3), ClubMaterial.glow(UiTheme.GOLD, 1.0), 10)
		var beam := _cyl(root, 0.08, 0.7, 3.2, at + Vector3(-3.0, 2.6, 0.3), ClubMaterial.ghost(), 10)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_obstacle_circle(w, ghost, tag, Vector2(at.x - 3.0, at.z + 0.3), 0.6)


# --- Bar ------------------------------------------------------------------------------

static func _bar(w: ClubWorld, root: Node3D, lv: int, ghost: bool) -> void:
	if lv == 0:
		return
	var tag := "lvl_bar"
	var at := BAR
	# Level 1: a soda kiosk with a striped awning.
	var k := at + Vector3(3.8, 0, -1.6)
	_box(root, Vector3(2.4, 2.2, 1.6), k + Vector3(0, 1.1, 0), ClubMaterial.pal(ClubMaterial.TEAL))
	for i in 5:
		_box(root, Vector3(0.48, 0.08, 1.2), k + Vector3(-0.96 + i * 0.48, 2.35, 1.1), ClubMaterial.pal(ClubMaterial.RED if i % 2 == 0 else ClubMaterial.WHITE, false))
	_label(root, "ГАЗИРОВКА", k + Vector3(0, 1.8, 0.82), 0.0045, Color.WHITE)
	_obstacle_box(w, ghost, tag, Rect2(k.x - 1.2, k.z - 0.8, 2.4, 1.6))
	if lv >= 2:
		for z in [-0.6, 2.2]:
			var t := at + Vector3(-4.0, 0, z)
			_cyl(root, 0.45, 0.45, 0.06, t + Vector3(0, 0.75, 0), ClubMaterial.pal(ClubMaterial.WHITE), 10)
			_cyl(root, 0.05, 0.05, 0.72, t + Vector3(0, 0.36, 0), ClubMaterial.pal(ClubMaterial.METAL_DARK, false), 6)
			for dx in [-0.7, 0.7]:
				_box(root, Vector3(0.4, 0.45, 0.4), t + Vector3(dx, 0.22, 0), ClubMaterial.pal(ClubMaterial.WOOD, false))
			_cyl(root, 0.03, 0.03, 2.3, t + Vector3(0, 1.15, 0), ClubMaterial.pal(ClubMaterial.METAL, false), 6)
			_cyl(root, 0.04, 1.1, 0.35, t + Vector3(0, 2.35, 0), ClubMaterial.pal(ClubMaterial.ORANGE if z < 0 else ClubMaterial.TEAL), 8)
			_obstacle_circle(w, ghost, tag, Vector2(t.x, t.z), 0.9)
	if lv >= 3:
		# The terrace by the water: a rail, a neon sign, a string of lights.
		var rail := ClubMaterial.pal(ClubMaterial.WOOD_DARK)
		_box(root, Vector3(13.0, 0.08, 0.08), at + Vector3(0, 1.0, -4.6), rail)
		for i in 7:
			_box(root, Vector3(0.1, 1.0, 0.1), at + Vector3(-6.0 + i * 2.0, 0.5, -4.6), rail)
		_box(root, Vector3(13.0, 0.1, 3.0), at + Vector3(0, 0.05, -3.4), ClubMaterial.pal(ClubMaterial.WOOD, false))
		_label(root, "БАР", k + Vector3(0, 2.9, 0.4), 0.012, ClubMaterial.PALETTE[ClubMaterial.NEON] * 1.4, Color(1.0, 0.3, 0.5, 0.9))
		var bulbs: Array[Transform3D] = []
		var cols: Array[Color] = []
		for i in 14:
			var x := -6.0 + i * (12.0 / 13.0)
			bulbs.append(Transform3D(Basis.IDENTITY, at + Vector3(x, 2.6 - 0.25 * sin(PI * i / 13.0), -4.6)))
			cols.append(ClubMaterial.PALETTE[ClubMaterial.NEON] * 1.3)
		var bulb := SphereMesh.new()
		bulb.radius = 0.07
		bulb.height = 0.14
		bulb.radial_segments = 6
		bulb.rings = 3
		var mmi := _mm(root, bulb, bulbs, cols)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.vertex_color_use_as_albedo = true
		mmi.material_override = glow
		_obstacle_box(w, ghost, tag, Rect2(at.x - 6.5, at.z - 4.8, 13.0, 0.4))
