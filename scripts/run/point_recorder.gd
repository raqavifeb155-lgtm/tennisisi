class_name PointRecorder
extends RefCounted
## Records a rally so the best point of the match can be watched again: every frame the
## local transform of each Node3D under the given roots (both players' bodies and
## rackets) and where the ball was. Playback puts them back frame by frame, so the replay
## is exactly what happened, poses included, without re-simulating anything.
## RunHub captures at 30 Hz; a frame list is a Dictionary {nodes, t, ball, vis}.

const MAX_FRAMES := 900           # 30 s at 30 Hz; a longer rally keeps its last 30 s

var frame := 0                    # frames captured this rally (the index of the next one)
var best_frames := {}
var _roots: Array[Node3D] = []
var _cur := {}


func _init(roots: Array[Node3D]) -> void:
	_roots = roots


## Starts a new rally. The bodies are walked again: a new look rebuilds them.
func begin() -> void:
	var nodes: Array[Node3D] = []
	for r in _roots:
		if is_instance_valid(r):
			_collect(r, nodes)
	_cur = {"nodes": nodes, "t": [], "ball": PackedVector3Array(), "vis": []}
	frame = 0


func _collect(n: Node, out: Array[Node3D]) -> void:
	if n is GPUParticles3D or n is CPUParticles3D:
		return
	if n is Node3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func capture(ball_pos: Vector3, ball_visible: bool) -> void:
	if _cur.is_empty():
		begin()
	var t: Array = []
	t.resize(_cur["nodes"].size())
	var i := 0
	for n in _cur["nodes"]:
		t[i] = n.transform if is_instance_valid(n) else Transform3D()
		i += 1
	if _cur["t"].size() >= MAX_FRAMES:
		_cur["t"].pop_front()
		_cur["ball"].remove_at(0)
		_cur["vis"].pop_front()
	_cur["t"].append(t)
	_cur["ball"].append(ball_pos)
	_cur["vis"].append(ball_visible)
	frame += 1


## The rally just finished; the next capture starts a fresh one.
func end_point() -> Dictionary:
	var done := _cur
	_cur = {}
	frame = 0
	return done


func keep_best(frames: Dictionary) -> void:
	best_frames = frames


static func length(frames: Dictionary) -> int:
	return frames.get("t", []).size()


## Puts frame i back: every recorded node and the ball (any Node3D).
func apply(frames: Dictionary, i: int, ball: Node3D) -> void:
	var n := length(frames)
	if n == 0:
		return
	i = clampi(i, 0, n - 1)
	var t: Array = frames["t"][i]
	var nodes: Array = frames["nodes"]
	for k in mini(nodes.size(), t.size()):
		if is_instance_valid(nodes[k]):
			nodes[k].transform = t[k]
	if ball:
		ball.position = frames["ball"][i]
		ball.visible = frames["vis"][i]


## The live pose of everything recorded (to put back after a replay).
func snapshot() -> Dictionary:
	begin()
	capture(Vector3.ZERO, false)
	return end_point()


func restore(snap: Dictionary) -> void:
	apply(snap, 0, null)
