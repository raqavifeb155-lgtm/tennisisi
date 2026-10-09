class_name HousePose
extends Node
## Poses of a real Athlete for the Academy house, without touching athlete.gd: sit, watch (sit
## back), eat, squat, talk, stand, cheer, sad, stretch. `attach(athlete, pose)` hangs this node on
## the athlete; it runs AFTER the athlete's own _process (process_priority) and lays every limb
## again from a few key points - pelvis, chest, head, feet, hands - through the athlete's own IK
## (_ik, _reach, _set_bone, _place_hand...), model space (forward = -z, hips 0.92 m standing).
##
## The athlete is dressed for walking about (meta "casual": no racket), and kept small by
## AthleteCasual.set_junior; the pose never moves the athlete's node: whoever places it puts the
## root on the floor (a seated pose has its hips at 0.46 m: a chair seat) and turns it.
## A sleeper is not a pose: lay the athlete's PARENT on its back (rotation.x = PI / 2) - see
## `lie_parent`. Playing (table tennis) is the athlete's own prepare()/swing().
## What the house has to do with it: AthleteCasual.set_pose (spec 3.4) may later do the same
## inside Athlete; this is the stand-in with the same names.

const POSES := ["stand", "talk", "sit", "watch", "eat", "squat", "cheer", "sad", "stretch"]

var athlete: Athlete
var pose := "stand"
var t := 0.0
var phase := 0.0            # so two kids in one pose do not move together


static func attach(a: Athlete, pose_name: String, phase_ := 0.0) -> HousePose:
	var hp := HousePose.new()
	hp.athlete = a
	hp.pose = pose_name
	hp.phase = phase_
	hp.process_priority = 1000
	a.set_meta("casual", true)
	a.add_child(hp)
	return hp


## A node to put the athlete under to lay it on its back on a bed (head toward `head_dir`: -z or +z).
static func lie_parent(a: Athlete, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.position = at + Vector3(0, 0.2, 0)
	n.rotation = Vector3(PI * 0.5, 0, 0)
	var w := Node3D.new()
	w.rotation.y = yaw
	w.add_child(n)
	n.add_child(a)
	return w


func _process(delta: float) -> void:
	t += delta
	if athlete != null and athlete._model != null:
		apply(athlete, pose, t + phase)


## Lays the athlete's body for this pose at time t (seconds).
static func apply(a: Athlete, pose_name: String, time: float) -> void:
	var breath := sin(time * 1.6) * 0.006
	var p := Vector3(0, Athlete.HIP_H - 0.02 + breath, 0)
	var chest := p + Vector3(0, 0.5, 0)
	var feet := [Vector3(0.17, 0.05, 0.0), Vector3(-0.17, 0.05, 0.0)]
	var hands := [Vector3(0.3, 0.8, 0.0), Vector3(-0.3, 0.8, 0.0)]
	var head_pitch := 0.0
	var head_yaw := 0.0
	var twist := 0.0
	var pole_out := 0.55
	match pose_name:
		"talk":
			var g := 0.5 + 0.5 * sin(time * 3.1)
			var nod := sin(time * 2.3)
			hands[0] = Vector3(0.3, 1.0 + 0.1 * g, -0.28 - 0.1 * g)
			hands[1] = Vector3(-0.28, 0.9, -0.1) if int(time * 0.35) % 2 == 0 else Vector3(-0.3, 0.8, 0.0)
			head_pitch = 0.05 * nod
			head_yaw = 0.12 * sin(time * 0.9)
			twist = 0.1 * sin(time * 0.9)
		"sit", "watch", "eat":
			p = Vector3(0, 0.46, 0.05)
			var back := 0.0 if pose_name != "watch" else 0.1
			chest = p + Vector3(0, 0.5, 0.0) + Vector3(0, 0, back)
			feet = [Vector3(0.15, 0.05, -0.5), Vector3(-0.15, 0.05, -0.5)]
			hands = [Vector3(0.2, 0.62, -0.38), Vector3(-0.2, 0.62, -0.38)]
			head_pitch = 0.0 if pose_name != "watch" else -0.12
			if pose_name == "eat":
				var k := 0.5 + 0.5 * sin(time * 2.4)
				var up := smoothstep(0.35, 0.8, k)
				var to_mouth := Vector3(0.05, 1.22, -0.13)
				var at_table := Vector3(0.18, 0.78, -0.42)
				hands[0] = at_table.lerp(to_mouth, up)
				hands[1] = Vector3(-0.18, 0.8, -0.42)
				head_pitch = 0.18 * (1.0 - up)
				chest += Vector3(0, 0, -0.04 * (1.0 - up))
			if pose_name == "sit":
				head_yaw = 0.2 * sin(time * 0.5)
		"squat":
			var d := 0.5 + 0.5 * sin(time * 2.6)
			p = Vector3(0, Athlete.HIP_H - 0.02 - 0.4 * d, 0.1 * d)
			chest = p + Vector3(0, 0.5 - 0.06 * d, -0.16 * d)
			hands = [Vector3(0.12, 1.05 - 0.4 * d, -0.45), Vector3(-0.12, 1.05 - 0.4 * d, -0.45)]
			feet = [Vector3(0.22, 0.05, 0.0), Vector3(-0.22, 0.05, 0.0)]
			head_pitch = -0.1 * d
		"cheer":
			var h := 0.5 + 0.5 * sin(time * 7.0)
			p.y += 0.04 * h
			chest = p + Vector3(0, 0.5, 0)
			hands = [Vector3(0.3, 1.9 + 0.1 * h, -0.05), Vector3(-0.3, 1.9 + 0.1 * (1.0 - h), -0.05)]
			head_pitch = -0.25
			pole_out = 0.3
		"sad":
			p = Vector3(0, Athlete.HIP_H - 0.06, 0)
			chest = p + Vector3(0, 0.46, -0.1)
			hands = [Vector3(0.2, 0.7, -0.05), Vector3(-0.2, 0.7, -0.05)]
			head_pitch = 0.5
			feet = [Vector3(0.14, 0.05, 0.0), Vector3(-0.14, 0.05, 0.0)]
		"stretch":
			var s := 0.5 + 0.5 * sin(time * 1.4)
			chest = p + Vector3(0, 0.5, 0)
			hands = [Vector3(0.12, 1.95, -0.05 - 0.1 * s), Vector3(-0.12, 1.95, -0.05 - 0.1 * s)]
			head_pitch = -0.3 * s
			pole_out = 0.2
	_put(a, p, chest, feet, hands, head_pitch, head_yaw, twist, pole_out)


static func _put(a: Athlete, p: Vector3, chest: Vector3, feet: Array, hands: Array, head_pitch: float, head_yaw: float, twist: float, pole_out: float) -> void:
	# legs
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var hip := p + Vector3(0.11 * sgn, 0, 0)
		var foot: Vector3 = feet[i]
		var knee: Vector3 = a._ik(hip, foot, Athlete.THIGH, Athlete.SHIN, hip + Vector3(0.08 * sgn, 0.15, -1.0))
		var ankle: Vector3 = a._reach(knee, foot, Athlete.SHIN)
		a._set_bone("thigh%d" % i, hip, knee)
		a._set_joint("knee%d" % i, knee)
		a._set_bone("shin%d" % i, knee, ankle)
		var heel := ankle + Vector3(0, -0.03, 0.05)
		var toe := ankle + Vector3(0.0, -0.0, -0.14)
		toe.y = maxf(0.03, toe.y - maxf(0.0, ankle.y - 0.1) * 0.8)
		a._set_bone("shoe%d" % i, heel, toe)
	# trunk
	a._set_bone("hips", p + Vector3(-0.1, 0, 0), p + Vector3(0.1, 0, 0))
	a._set_torso("waist", p + Vector3(0, 0.08, 0), chest.lerp(p, 0.45), twist * 0.5, 1.1, 0.8)
	a._set_torso("chest", p + Vector3(0, 0.06, 0), chest + Vector3(0, -0.04, 0), twist, 1.12, 0.76)
	var tw := Basis(Vector3.UP, twist)
	var r_sh := chest + tw * Vector3(Athlete.SHOULDER_W, 0, 0)
	var l_sh := chest + tw * Vector3(-Athlete.SHOULDER_W, 0, 0)
	a._set_bone("shoulders", l_sh, r_sh)
	a._set_bone("neck", chest, chest + Vector3(0, 0.16, 0))
	var up := (chest - p).normalized()
	a._head.position = chest + up * 0.3 * (1.04 if a._body == Athlete.Body.TOON else 1.0)
	a._head.rotation = Vector3(head_pitch, head_yaw, 0.0)
	# arms
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var sh := r_sh if i == 0 else l_sh
		var target: Vector3 = hands[i]
		var pole := sh + Vector3(pole_out * sgn, -0.8, 0.3)
		var elbow: Vector3 = a._ik(sh, target, Athlete.UPPER_ARM, Athlete.FOREARM, pole)
		var hand: Vector3 = a._reach(elbow, target, Athlete.FOREARM)
		var side := "r" if i == 0 else "l"
		a._set_bone("upper_" + side, sh, elbow)
		a._set_joint("elbow_" + side, elbow)
		a._set_bone("fore_" + side, elbow, hand)
		a._place_hand(a._hand_r if i == 0 else a._hand_l, elbow, hand)
	if a._racket != null:
		a._racket.visible = false
