class_name ShaderWarm
extends Node
## Compiles what the loot needs before it is first shown (hotfix F-B). WebGL builds a shader
## the first time a draw uses it, and that is a stall of a few hundred ms on a phone: the
## first epic racket on the opponent, the first loot card, the first chest. The loading
## screen (BootLoader) holds until frames come out steady, so the work done here, under
## it, is paid for there:
##   - a throw-away Athlete wearing a mythic racket, shoes and wristband, drawn in the
##     scene's own camera (the gear shaders: toon and plain, the glow added on top, the
##     court ring, the outline, the strings), a few frames, then gone;
##   - the loot pictures (ItemThumb: its own little viewport, a shader variant of its own)
##     of one thing for each slot, the shop's and the chest's first sight of a card.
## Nothing here is seen: the Athlete stands in front of the camera at 5 cm tall.

const FRAMES := 4              # the throw-away body is kept this many frames in view

var _frames := 0
var _body: Athlete
var _main: Node


## Starts the warm-up under `main`'s loading screen. A headless run has nothing to compile.
static func start(main: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var w := ShaderWarm.new()
	w.name = "ShaderWarm"
	w._main = main
	main.add_child(w)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 2:
		_dress()
	elif _frames == 2 + FRAMES:
		_ask_pictures()
	elif _frames == 3 + FRAMES:
		if is_instance_valid(_body):
			_body.queue_free()
		queue_free()


## The body in front of the camera, in the most glowing of everything.
func _dress() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var items: Array = []
	for slot in AthleteGear.SLOTS:
		items.append(Gear.roll(Gear.MYTHIC, rng, slot))
	_body = Athlete.new()
	_main.add_child(_body)
	var at := cam.global_position - cam.global_transform.basis.z * 3.0
	_body.setup(-1.0, Looks.DEFAULT.duplicate(), Rect2(at.x - 50.0, at.z - 50.0, 100.0, 100.0))
	_body.set_gear(items)
	_body.process_mode = Node.PROCESS_MODE_DISABLED   # it only stands there, drawn
	_body.scale = Vector3.ONE * 0.05
	_body.global_position = at


## One picture per slot of a glowing thing and of a plain one: the viewport, its shaders.
func _ask_pictures() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for slot in AthleteGear.SLOTS:
		ItemThumb.texture(Gear.roll(Gear.MYTHIC, rng, slot), slot)
		ItemThumb.texture(Gear.roll(Gear.COMMON, rng, slot), slot)
