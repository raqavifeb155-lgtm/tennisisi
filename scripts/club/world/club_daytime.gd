class_name ClubDaytime
extends Node
## The hour of the day in the club (stream H, CLUB_BRIEF 8): by the phone's clock. The
## morning of the start is Scenery's own; from the late afternoon the sun sinks and goes
## orange, the sky turns, and the street lamps come on - each a warm glow and a pool of
## light on the ground (no real lights: two MultiMeshes). Deep in the night the sun is a
## cold moon. Runs after Scenery's _process (a child of it), so what it sets wins.
##
## `force_hour` pins the hour (tools/club_shots.gd --hour=21, tests).

static var force_hour := -1.0

const DAY_SUN := Color(1.0, 0.85, 0.66)
const EVE_SUN := Color(1.0, 0.5, 0.26)
const NIGHT_SUN := Color(0.5, 0.6, 0.95)

var _world: ClubWorld
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _clouds: Array = []
var _cloud_base: Array[Color] = []
var _glows: MultiMeshInstance3D
var _pools: MultiMeshInstance3D
var _glow_mat: StandardMaterial3D
var _pool_mat: StandardMaterial3D
var _day := {}
var _eve := 0.0
var _dark := 0.0
var _lamp_count := 0
var _last := Vector2(-1, -1)


func _ready() -> void:
	_world = get_parent().world
	for c in _world.get_children():
		if c is WorldEnvironment:
			_env = (c as WorldEnvironment).environment
	_sun = _world.get("_sun")
	if _env != null:
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
		_day = {
			"top": _sky.sky_top_color, "horizon": _sky.sky_horizon_color, "ground": _sky.ground_horizon_color,
			"bottom": _sky.ground_bottom_color, "ambient": _env.ambient_light_color, "ambient_e": _env.ambient_light_energy,
			"fog": _env.fog_light_color, "exposure": _env.tonemap_exposure,
		}
	for c in _world.get("_clouds"):
		var m := ((c as MeshInstance3D).material_override as StandardMaterial3D)
		_clouds.append(m)
		_cloud_base.append(m.albedo_color)
	_build_glows()


## Hour of the day, 0..24: pinned for shots and tests, else the phone's clock.
static func hour() -> float:
	if force_hour >= 0.0:
		return force_hour
	var t := Time.get_datetime_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0


## 0 = day, 1 = evening or night; and how deep the night is (0 evening .. 1 midnight).
static func evening(h: float) -> Vector2:
	var e := smoothstep(17.0, 19.5, h) if h >= 12.0 else 1.0 - smoothstep(5.0, 7.5, h)
	var d := smoothstep(20.5, 22.5, h) if h >= 12.0 else 1.0 - smoothstep(4.0, 5.8, h)
	return Vector2(e, d)


func _process(_delta: float) -> void:
	var ed := evening(hour())
	_eve = ed.x
	_dark = ed.y
	_apply()


func _apply() -> void:
	if _env == null or _sun == null:
		return
	var e := _eve
	var d := _dark
	_apply_sun(e, d)
	# The sky and the haze only when the hour has moved: a new sky colour makes the engine
	# redraw the sky's reflection, which is not a thing to do every frame.
	if absf(e - _last.x) < 0.004 and absf(d - _last.y) < 0.004:
		return
	_last = Vector2(e, d)
	_apply_sky(e, d)


func _apply_sun(e: float, d: float) -> void:
	# the sun: sinks toward the horizon in the evening, a cold moon high up at night
	var sun_col := DAY_SUN.lerp(EVE_SUN, e).lerp(NIGHT_SUN, d)
	_sun.light_color = sun_col
	if e > 0.0:
		var elev := lerpf(_sun.rotation_degrees.x, -9.0, e)
		elev = lerpf(elev, -38.0, d)
		_sun.rotation_degrees.x = elev
		_sun.light_energy = lerpf(_sun.light_energy, 0.85, e) * lerpf(1.0, 0.36, d)
	_lamps_lit(e, d)


func _apply_sky(e: float, d: float) -> void:
	var eve_top := Color(0.24, 0.27, 0.54)
	var eve_hor := Color(1.0, 0.52, 0.34)
	var night_top := Color(0.025, 0.04, 0.12)
	var night_hor := Color(0.1, 0.12, 0.27)
	_sky.sky_top_color = (_day["top"] as Color).lerp(eve_top, e).lerp(night_top, d)
	_sky.sky_horizon_color = (_day["horizon"] as Color).lerp(eve_hor, e).lerp(night_hor, d)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = (_day["bottom"] as Color).lerp(Color(0.2, 0.18, 0.26), e).lerp(Color(0.04, 0.05, 0.1), d)
	_env.fog_light_color = (_day["fog"] as Color).lerp(Color(0.85, 0.52, 0.42), e).lerp(Color(0.1, 0.12, 0.24), d)
	_env.ambient_light_color = (_day["ambient"] as Color).lerp(Color(0.66, 0.52, 0.66), e).lerp(Color(0.36, 0.42, 0.7), d)
	_env.ambient_light_energy = lerpf(float(_day["ambient_e"]), 0.42, e) * lerpf(1.0, 0.85, d)
	_env.tonemap_exposure = lerpf(float(_day["exposure"]), 0.98, e) * lerpf(1.0, 1.05, d)
	for i in _clouds.size():
		var m := _clouds[i] as StandardMaterial3D
		var base := _cloud_base[i]
		m.albedo_color = base.lerp(Color(1.0, 0.7, 0.6), e * 0.7).lerp(Color(0.14, 0.17, 0.3), d)


func _lamps_lit(e: float, d: float) -> void:
	# the lamps: lit from the late afternoon on
	var lit := smoothstep(0.35, 0.8, e)
	_glows.visible = lit > 0.01 and _lamp_count > 0
	_pools.visible = _glows.visible
	if _glows.visible:
		_glow_mat.albedo_color = Color(1.0, 0.82, 0.5).lerp(Color(1.0, 0.9, 0.62), d) * lerpf(0.5, 2.2, lit)
		_pool_mat.albedo_color = Color(1.0, 0.72, 0.38, 0.5 * lit)


func _build_glows() -> void:
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.3
	head.radial_segments = 6
	head.rings = 2
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.albedo_color = Color(1.0, 0.82, 0.5)
	_glows = _mm(head, _glow_mat)
	var pool := PlaneMesh.new()
	pool.size = Vector2(7.0, 7.0)
	_pool_mat = StandardMaterial3D.new()
	_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pool_mat.albedo_texture = _pool_texture()
	_pool_mat.albedo_color = Color(1.0, 0.72, 0.38, 0.0)
	_pool_mat.disable_receive_shadows = true
	_pool_mat.no_depth_test = false
	_pools = _mm(pool, _pool_mat)


## Where the lamps stand now (from ClubScenery's props, after a level changed them).
func refresh(lamps: Array[ClubProps.Prop]) -> void:
	var pos: Array[Vector3] = []
	var head_local := _lamp_head()
	for p in lamps:
		if p.tag != "lamp":
			continue
		pos.append(p.xf * head_local)
	_lamp_count = pos.size()
	_glows.multimesh.instance_count = pos.size()
	_pools.multimesh.instance_count = pos.size()
	for i in pos.size():
		_glows.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos[i]))
		_pools.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(pos[i].x, ClubLayout.gy(Vector2(pos[i].x, pos[i].z)) + 0.08, pos[i].z)))


## Where a street light's lamp hangs in the model's own space: the middle of its top slice.
static func _lamp_head() -> Vector3:
	var mesh := ClubPack.mesh("streetlight")
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var top := mesh.get_aabb().end.y
	var sum := Vector3.ZERO
	var n := 0
	for v in verts:
		if v.y > top - 0.3:
			sum += v
			n += 1
	return sum / maxf(float(n), 1.0) - Vector3(0, 0.1, 0) if n > 0 else Vector3(0.4, top - 0.14, 0)


func _mm(mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible = false
	add_child(mmi)
	return mmi


static func _pool_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a) * 0.9
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
