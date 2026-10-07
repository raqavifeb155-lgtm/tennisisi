class_name PerfMeter
extends Node
## Frame statistics over a window, for the server telemetry ("beat") and for profiling
## runs: what a phone really gets, and whether it waits on the CPU (scripts, physics)
## or on the GPU (pixels, draw calls).
##   fps      average over the window
##   low      the frame rate of the slowest 5% of frames (stutter)
##   worst    the longest frame, ms
##   cpu      our scripts per frame, ms: from the first _process in the frame to the last
##            plus the same for _physics_process (the meter runs first, its end marker
##            last). Engine rendering is not in it. Single-threaded on the web.
##   draws    draw calls per frame, tris: primitives per frame (thousands)
##   px       3D render resolution (thousands of pixels)
## A frame at 60 fps is 16.7 ms: when cpu takes most of it, scripts are the bottleneck;
## when cpu is small and fps still low, it's the GPU or the browser.

var _frames: PackedFloat32Array = PackedFloat32Array()
var _cpu_us := 0
var _draws := 0.0
var _tris := 0.0
var _n := 0
var _t0 := 0
var _p0 := 0


## Runs last in every frame: closes the measurement the meter opened first.
class EndMark extends Node:
	var meter: PerfMeter

	func _process(_d: float) -> void:
		meter._cpu_us += Time.get_ticks_usec() - meter._t0

	func _physics_process(_d: float) -> void:
		meter._cpu_us += Time.get_ticks_usec() - meter._p0


func _ready() -> void:
	process_priority = -100000
	process_physics_priority = -100000
	var end := EndMark.new()
	end.meter = self
	end.process_priority = 100000
	end.process_physics_priority = 100000
	add_child(end)


func _physics_process(_d: float) -> void:
	_p0 = Time.get_ticks_usec()


func _process(delta: float) -> void:
	_t0 = Time.get_ticks_usec()
	_frames.append(delta)
	_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_n += 1


## The window so far as a Dictionary, then a fresh window starts.
func take() -> Dictionary:
	if _n == 0:
		return {}
	var total := 0.0
	var worst := 0.0
	for d in _frames:
		total += d
		worst = maxf(worst, d)
	var sorted := _frames.duplicate()
	sorted.sort()
	var slow := sorted[clampi(int(sorted.size() * 0.95), 0, sorted.size() - 1)]
	var vp := get_viewport()
	var win := Vector2(DisplayServer.window_get_size())
	var px := win * vp.scaling_3d_scale if win.x > 0.0 else Vector2(vp.get_visible_rect().size) * vp.scaling_3d_scale
	var out := {
		"fps": roundi(_n / maxf(total, 0.001)),
		"low": roundi(1.0 / maxf(slow, 0.001)),
		"worst": roundi(worst * 1000.0),
		"cpu": snappedf(_cpu_us / 1000.0 / _n, 0.1),
		"draws": roundi(_draws / _n),
		"tris": snappedf(_tris / _n / 1000.0, 0.1),
		"px": roundi(px.x * px.y / 1000.0),
	}
	_frames.clear()
	_cpu_us = 0
	_draws = 0.0
	_tris = 0.0
	_n = 0
	return out
