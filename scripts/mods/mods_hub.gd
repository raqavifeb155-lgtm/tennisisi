class_name ModsHub
extends Node
## The modifiers of a match (v0.2 stream G): on GameEvents.match_started it applies the
## run's conditions, the opponent's auras and --mods (Modifiers.match_set) through the
## ModEffects primitives; on match_finished, or when the match is left for the menu, it
## runs their undo list backwards and everything is as before. Main creates it once
## (mods_hub.setup(self)) right after RunHub, and reads its switches in a few one-line
## hooks: start_stamina, no_ring, ring_late, mirror, cpu_covers().
##
## It also shows them: each aura and the run's conditions in the TV strip at the start
## ("???" auras are named on the first point), the aura's glow under the opponent and on
## the ball he hits (2 draw calls), the fog, the night glow of the ball.

const CPU := 1
const FOG_NEAR := 7.5             # m from the player: the ball is clear up to here...
const FOG_FAR := 12.5             # ...and gone from here
const BALL_NIGHT := Color(1.0, 1.0, 0.55)

var main: Node
var rng := RandomNumberGenerator.new()
var active: Array = []            # ids applied this match
var auras: Array = []             # ...of them, the opponent's own (lineup), for the glow
var undo: Array[Callable] = []

# Read by Main's hooks.
var start_stamina := 1.0
var no_ring := false
var ring_late := INF
var mirror := false

# Read here, on the match's events and every frame.
var pace := [1.0, 1.0]            # rally shots x, by who
var serve_pace := [1.0, 1.0]
var echo_every := 0
var reaction_add := 0.0
var drain_on_loss := 0.0
var heal_on_win := 0.0
var wind_side := 0.0
var fog := false
var night := false
var aura_color := Color(0, 0, 0, 0)
var hole := false                 # «Дыра слева»: the player's strokes are checked for his backhand side
var traits: Array = []            # his traits this match (ids), shown by the strip and a small glow

var _in_match := false
var _points := 0
var _cpu_rally_shots := 0
var _ball_mat: StandardMaterial3D
var _ball_emission := Color.BLACK
var _ball_energy := 1.0
var _halo: MeshInstance3D
var _column: MeshInstance3D
var _t := 0.0
var _trail_was := true
var _twins: Node                  # ModsTwins while "Близнецы" plays


func setup(m: Node) -> void:
	main = m
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mods="):
			Modifiers.forced = Array(a.get_slice("=", 1).split(",", false))
	var ev: Node = get_node("/root/GameEvents")
	ev.match_started.connect(_on_match_started)
	ev.match_finished.connect(func(_i: Dictionary) -> void: revert())
	ev.shot.connect(_on_shot)
	ev.player_stroke.connect(_on_stroke)
	ev.point.connect(_on_point)
	var mi: MeshInstance3D = main.ball._mesh
	_ball_mat = mi.material_override as StandardMaterial3D
	if _ball_mat:
		_ball_emission = _ball_mat.emission
		_ball_energy = _ball_mat.emission_energy_multiplier
	_build_glow()


## Main's twins hook: does the main opponent take this ball (the other one's half)?
func cpu_covers() -> bool:
	return _twins == null or _twins.main_covers()


# --- The match ---------------------------------------------------------------------

func _on_match_started(_info: Dictionary) -> void:
	revert()
	var t: Tournament = main.tournament if main.tournament_mode else null
	var list := Modifiers.match_set(t)
	if t == null and not main.autoplay:
		list = []  # practice: no modifiers (only the bot's --mods runs)
	apply(list)
	if t != null:
		var mine: Array = t.current_lineup()["mods"].filter(func(id): return list.has(id))
		auras = mine.filter(func(id): return not Traits.has(id))
		traits = mine.filter(func(id): return Traits.has(id))
	_show_glow()
	if not list.is_empty():
		_announce.call_deferred(list)


func apply(list: Array) -> void:
	_in_match = true
	_points = 0
	_cpu_rally_shots = 0
	for id in list:
		var e := Modifiers.find(id)
		if e.is_empty():
			continue
		for f in e["fx"]:
			ModEffects.apply(self, f)
		active.append(id)


## Everything back as it was before the match (safe to call twice).
func revert() -> void:
	for i in range(undo.size() - 1, -1, -1):
		undo[i].call()
	undo.clear()
	active = []
	auras = []
	traits = []
	hole = false
	Traits.hole_hit = false
	_in_match = false
	start_stamina = 1.0
	no_ring = false
	ring_late = INF
	mirror = false
	pace = [1.0, 1.0]
	serve_pace = [1.0, 1.0]
	echo_every = 0
	reaction_add = 0.0
	drain_on_loss = 0.0
	heal_on_win = 0.0
	wind_side = 0.0
	fog = false
	night = false
	aura_color = Color(0, 0, 0, 0)
	if _halo:
		_halo.visible = false
		_column.visible = false
	_restore_ball()


func _physics_process(_delta: float) -> void:
	if _in_match and main.phase == main.Phase.IDLE:
		revert()  # left for the menu mid-match: no match_finished comes


## Right after a shot leaves the racket: the same bounce at another speed (fast ball,
## a cannon), or a drop shot instead (echo). The solver and the predictions see it as a
## shot like any other.
func _on_shot(who: int, info: Dictionary) -> void:
	if not _in_match or main.phase == main.Phase.BONUS:
		return
	var ball: Ball = main.ball
	var contact: Vector3 = info.get("contact", ball.state.pos)
	var is_serve: bool = main.rally <= 1
	if who == CPU and not is_serve and echo_every > 0:
		_cpu_rally_shots += 1
		if _cpu_rally_shots % echo_every == 0 and not info.get("lob", false) and absf(contact.z) > 4.0:
			var target := Vector3(rng.randf_range(-2.5, 2.5), BallPhysics.RADIUS, rng.randf_range(1.6, 2.6) * signf(-contact.z))
			var d := ShotSolver.solve_drop(contact, target, -280.0)
			ball.launch(contact, d.velocity, d.spin)
			return
	var k: float = serve_pace[who] if is_serve else pace[who]
	if absf(k - 1.0) < 0.001 or info.get("lob", false) or info.get("drop", false):
		return
	var pred := BallPhysics.predict(ball.state, 4.0, 1.0 / 120.0, 1)
	if pred.net_hit or pred.bounce_points.is_empty():
		return  # a ball into the net stays one
	var r := ShotSolver.solve(contact, pred.bounce_points[0], float(info.get("speed", 20.0)) * k, float(info.get("top", 0.0)), 0.12 if is_serve else 0.3)
	ball.launch(contact, r.velocity, r.spin)


func _on_stroke(info: Dictionary) -> void:
	if _in_match and hole and not info.get("serve", false):
		# «Дыра слева»: did this stroke go to his backhand (a right-hander's left: -right() side)?
		var tg: Vector2 = main.last_shot.get("target", Vector2.ZERO)
		Traits.hole_hit = tg.x * (main.cpu as Athlete).right().x < -0.8
	if _in_match and reaction_add != 0.0:
		main.ai._reaction = maxf(0.02, float(main.ai._reaction) + reaction_add)


func _on_point(info: Dictionary) -> void:
	if not _in_match:
		return
	_points += 1
	var w := int(info.get("winner", -1))
	var clean := ["WINNER", "ACE"].has(String(info.get("reason", "")))
	if clean and w == CPU and drain_on_loss > 0.0:
		main.stamina = maxf(main.stamina - drain_on_loss, 0.0)
	elif clean and w == 0 and heal_on_win > 0.0:
		main.stamina = minf(main.stamina + heal_on_win, 1.0)
	if _points == 1 and main.tournament_mode and main.tournament != null:
		var lu: Dictionary = main.tournament.current_lineup()
		var hid: Array = lu.get("hidden", [])
		for id in hid:
			var e := Modifiers.find(id)
			_strip("АУРА РАСКРЫТА", Modifiers.human_name(id) + "  ·  " + Modifiers.human_desc(id).to_lower(), e.get("color", Color(0.8, 0.8, 0.85)))
		lu["hidden"] = []


# --- What it looks like ------------------------------------------------------------

func _announce(list: Array) -> void:
	if not _in_match:
		return
	var lu: Dictionary = main.tournament.current_lineup() if main.tournament_mode and main.tournament != null else {}
	var conds: Array[String] = []
	var tn: Array[String] = []
	for id in list:
		var e := Modifiers.find(id)
		if traits.has(id):
			tn.append(Modifiers.human_name(id))
			continue
		if auras.has(id):
			var hid: bool = lu.get("hidden", []).has(id)
			_strip("АУРА", "???" if hid else _name_now(e), Color(0.8, 0.8, 0.85) if hid else e["color"])
		else:
			conds.append(_name_now(e))
	if not tn.is_empty():
		_strip("ЧЕРТА" if tn.size() == 1 else "ЧЕРТЫ", ", ".join(tn), Modifiers.find(traits[0])["color"])
	if not conds.is_empty():
		_strip("УСЛОВИЯ", ", ".join(conds), UiTheme.GOLD)


func _name_now(e: Dictionary) -> String:
	if e.get("id", "") == "wind" and wind_side != 0.0:
		return "Ветер " + ("вправо" if wind_side > 0.0 else "влево")
	return Modifiers.human_name(String(e.get("id", "")))


func _strip(head: String, tail: String, c: Color) -> void:
	var a = main.hud.announcer
	a._enqueue({"kind": "moment", "main": head, "tail": tail, "color": c, "frame": c, "hold": 1.6, "tail_font": "display"})


func environment() -> Environment:
	if main.scenery == null:
		return null
	var found: Array = main.scenery.find_children("*", "WorldEnvironment", true, false)
	return (found[0] as WorldEnvironment).environment if not found.is_empty() else null


## Two lines for "Узкий корт" at ±half and the old alleys dimmed: two draw calls.
func narrow_lines(half: float) -> Node3D:
	var root := Node3D.new()
	var lw := Court.LINE_WIDTH
	var y := Court.Y_LINES + 0.004
	var l := Court.HALF_LENGTH
	var lines := _quads([[-half - lw * 0.5, -half + lw * 0.5], [half - lw * 0.5, half + lw * 0.5]], -l, l, y)
	lines.material_override = _flat(Color(0.96, 0.96, 0.96))
	root.add_child(lines)
	var out := Court.SINGLES_HALF_WIDTH + lw * 0.5 + 0.01
	var strips := _quads([[-out, -half - lw * 0.5], [half + lw * 0.5, out]], -l - 0.02, l + 0.02, y - 0.001)
	strips.material_override = _flat(Color(0.05, 0.06, 0.08, 0.72))
	root.add_child(strips)
	main.court.add_child(root)
	return root


func _quads(xs: Array, z0: float, z1: float, y: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for x in xs:
		var a := Vector3(x[0], y, z0)
		var b := Vector3(x[1], y, z0)
		var c := Vector3(x[1], y, z1)
		var d := Vector3(x[0], y, z1)
		for p in [a, b, c, a, c, d]:
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## The aura: a glow on the ground under him and a soft column around him (additive).
func _build_glow() -> void:
	_halo = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.6, 2.6)
	_halo.mesh = pm
	_halo.material_override = _glow_mat(_radial(), false)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.top_level = true
	_halo.visible = false
	add_child(_halo)
	_column = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.7, 2.7)
	_column.mesh = qm
	_column.material_override = _glow_mat(_vertical(), true)
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.top_level = true
	_column.visible = false
	add_child(_column)


func _glow_mat(tex: Texture2D, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	return m


static func _radial() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


static func _vertical() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.5))
	g.add_point(0.6, Color(1, 1, 1, 0.12))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 8
	t.height = 64
	return t


func _show_glow() -> void:
	if auras.is_empty():
		if not traits.is_empty():  # a trait: the ring on the ground only (one draw call)
			var tc: Color = Modifiers.find(traits[0])["color"]
			(_halo.material_override as StandardMaterial3D).albedo_color = Color(tc, 0.6)
			_halo.visible = true
		return
	var c: Color = Modifiers.find(auras[0])["color"]
	var lu: Dictionary = main.tournament.current_lineup() if main.tournament_mode and main.tournament != null else {}
	if lu.get("hidden", []).has(auras[0]):
		c = Color(0.8, 0.8, 0.85)  # "???": a glow, but not its color yet
	aura_color = c
	for mi in [_halo, _column]:
		(mi.material_override as StandardMaterial3D).albedo_color = Color(c, 0.85)
		mi.visible = true


func _process(delta: float) -> void:
	_t += delta
	if not _in_match:
		return
	var cpu: Node3D = main.cpu
	if _halo.visible:
		var pulse := 1.0 + sin(_t * 3.0) * 0.06
		_halo.global_transform = Transform3D(Basis.from_scale(Vector3(pulse, 1, pulse) * cpu.scale.x), cpu.global_position + Vector3(0, 0.045, 0))
		_column.global_position = cpu.global_position + Vector3(0, 1.3 * cpu.scale.y, 0)
	var ball: Ball = main.ball
	if _ball_mat:
		if night:
			_ball_mat.emission = BALL_NIGHT
			_ball_mat.emission_energy_multiplier = 3.2
		elif aura_color.a > 0.0 and main.last_hitter == CPU:
			_ball_mat.emission = aura_color
			_ball_mat.emission_energy_multiplier = 1.4
		else:
			_ball_mat.emission = _ball_emission
			_ball_mat.emission_energy_multiplier = _ball_energy
	if fog:
		var p: Vector3 = main.player.global_position
		var d := Vector2(ball.state.pos.x - p.x, ball.state.pos.z - p.z).length()
		var a := clampf((d - FOG_NEAR) / (FOG_FAR - FOG_NEAR), 0.0, 1.0)
		ball._mesh.transparency = a
		ball._shadow.transparency = a
		main.trail.visible = false
		if a > 0.3:
			main._landing.visible = false  # no peeking at the bounce through the fog


func _restore_ball() -> void:
	if main == null:
		return
	if _ball_mat:
		_ball_mat.emission = _ball_emission
		_ball_mat.emission_energy_multiplier = _ball_energy
	main.ball._mesh.transparency = 0.0
	main.ball._shadow.transparency = 0.0
	if main.trail:
		main.trail.visible = true


# --- "Близнецы" ----------------------------------------------------------------------

func start_twins() -> void:
	pass  # see ModsTwins (G-6)


func stop_twins() -> void:
	if _twins:
		_twins.queue_free()
		_twins = null
