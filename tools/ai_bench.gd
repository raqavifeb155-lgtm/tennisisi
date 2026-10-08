extends SceneTree
## Bot bench for stream D (difficulty, serve, AI tactics): the autoplay bot plays a long
## practice set against one opponent and prints Main's summary with AiMetrics.
##   godot --headless --path . --fixed-fps 60 -s tools/ai_bench.gd -- --points=300 --bot-sd=0.07 --level=0 --opp=rublev --seed=1
## --level=N: every skill at level N (0 = a fresh beginner who spent the 3 starting
## points like the tournament bot), --xp=N: every skill gets N experience instead.
## --opp=id: an Opponents.ROSTER profile (skill and, with D-3, the play style);
## --skill=S overrides the AI skill. --style=id forces an AI style. --serve=wide: the
## bot serves every ball out wide (the HANDOFF 9.4 exploit).

var main: Node
var frame := 0
var seed_v := -1
var level := 0
var xp := -1.0
var opp_id := "rublev"
var skill := -1.0
var style := ""
var serve_x := -1.0
var opp := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = int(a.get_slice("=", 1))
		elif a.begins_with("--ease="):
			Opponents.ease_max = float(a.get_slice("=", 1))
		elif a.begins_with("--xp="):
			xp = float(a.get_slice("=", 1))
		elif a.begins_with("--opp="):
			opp_id = a.get_slice("=", 1)
		elif a.begins_with("--skill="):
			skill = float(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			seed_v = int(a.get_slice("=", 1))
		elif a == "--serve=wide":
			serve_x = 3.6  # an exploiting player: every serve out wide
		elif a.begins_with("--style="):
			style = a.get_slice("=", 1)
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.autoplay = true
	if serve_x > 0.0:
		main.bot_serve_x = serve_x
	root.add_child(main)
	# Skills like the tournament bot: a beginner who spent the starting points, then levels.
	Skills.reset()
	for id in ["forehand", "backhand", "serve"]:
		Skills.spend_point(id)
	var add := xp
	if add < 0.0 and level > 0:
		add = 0.0
		for n in range(1, level + 1):
			add += Skills.cost(n)
	if add > 0.0:
		Skills.xp = {}
		for id in Skills.LIST:
			Skills.add_xp(id, add)
	Skills.pending = []
	for o in Opponents.ROSTER:
		if o["id"] == opp_id:
			opp = o
	# Main's _ready runs once the tree starts: it reads this skill for the practice match.
	root.get_node("Tuning").ai_skill = skill if skill >= 0.0 else Opponents.adapted_skill(float(opp.get("skill", 0.5)), -1.0, bool(opp.get("boss", false)))  # D-5: like a tournament match


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		if seed_v >= 0:
			main.rng.seed = seed_v
			main.ai.rng.seed = seed_v + 1
		# After Main's _ready (the practice match_started set the all-rounder).
		if main.ai.has_method("set_profile"):
			var prof := opp.duplicate()
			if style != "":
				prof["play_style"] = style
			main.ai.set_profile(prof)
		var lv := PackedStringArray()
		for id in Skills.LIST:
			lv.append("%s %d" % [id, Skills.level(id)])
		print("BENCH opp=%s skill=%.2f style=%s levels: %s" % [opp_id, root.get_node("Tuning").ai_skill, main.ai.get("style_id"), ", ".join(lv)])
	return false
