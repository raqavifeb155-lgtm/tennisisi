extends SceneTree
## Realistic pairs for the calibration of the students' matches (T-4): a student as the academy
## makes him (JuniorGen, some of them trained a few steps) against the opponent as JuniorMatch
## makes one for him, written as the cases file of `--junior-duel` / tools/junior_sim_check.gd:
##   godot --headless --path . -s tools/junior_cases.gd -- --count=14 --seed=1 --n=14 --out=cases.json
## Traits are left out: the instant result does not know them.

func _initialize() -> void:
	var count := 14
	var seed_v := 1
	var n := 14
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--count="):
			count = int(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			seed_v = int(a.get_slice("=", 1))
		elif a.begins_with("--n="):
			n = int(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			path = a.get_slice("=", 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out: Array = []
	for i in count:
		var tier := rng.randi_range(0, 3)
		var st := JuniorGen.make(rng, tier, false)
		if rng.randf() < 0.5:
			for k in rng.randi_range(2, 8):
				var key: String = Opponents.STAT_KEYS[rng.randi() % Opponents.STAT_KEYS.size()]
				st["stats"][key] = mini(10, int(st["stats"][key]) + 1)
		var otier := clampi(tier + rng.randi_range(-1, 1), 0, 3)
		var m := {"opp": {"seed": rng.randi_range(1, 900000), "tier": otier, "mean": snappedf(JuniorMatch.mean_stat(st["stats"]), 0.01)}}
		var opp := JuniorMatch.opponent_of(m)
		out.append({"id": "R%d_%d" % [seed_v, i], "n": n, "seed": seed_v * 100 + i, "a": {"stats": st["stats"]}, "b": {"stats": opp["stats"], "play_style": opp["play_style"]}})
	var text := JSON.stringify(out)
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	else:
		print(text)
	quit()
