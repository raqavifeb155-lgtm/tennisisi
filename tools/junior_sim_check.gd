extends SceneTree
## The instant tiebreak (JuniorSim) on the cases of a `--junior-duel` run, to set side by side
## with the live numbers (T-4 calibration, spec 4 «Калибровка»):
##   godot --headless --path . -s tools/junior_sim_check.gd -- --cases=cases.json [--n=2000]
## One line per case: «JSIM id=.. n=.. share=.. win=.. a_serve=.. b_serve=..» (the share of the
## student's points, his tiebreaks won, the shares of the points each server wins).

func _initialize() -> void:
	var path := ""
	var n := 2000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cases="):
			path = a.get_slice("=", 1)
		elif a.begins_with("--n="):
			n = int(a.get_slice("=", 1))
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	for c in cases:
		var a: Dictionary = (c["a"] as Dictionary).duplicate(true)
		a["traits"] = a.get("traits", [])
		var b: Dictionary = (c["b"] as Dictionary).duplicate(true)
		var pts_a := 0
		var pts_b := 0
		var wins := 0
		var sa := [0, 0]
		var sb := [0, 0]
		for k in n:
			var first := k % 2
			var r := JuniorSim.simulate(a, b, {"seed": 7919 * (k + 1) + 13, "first": first})
			pts_a += int(r["pa"])
			pts_b += int(r["pb"])
			wins += 1 if int(r["winner"]) == 0 else 0
			var i := 0
			for w in r["log"]:
				var srv := JuniorSim.server_of(i, first)
				if srv == 0:
					sa[0] += 1
					sa[1] += 1 if int(w) == 0 else 0
				else:
					sb[0] += 1
					sb[1] += 1 if int(w) == 1 else 0
				i += 1
		print("JSIM id=%s n=%d share=%.3f win=%.3f a_serve=%.3f b_serve=%.3f" % [c.get("id", "?"), n, float(pts_a) / float(pts_a + pts_b), float(wins) / float(n), float(sa[1]) / maxf(float(sa[0]), 1.0), float(sb[1]) / maxf(float(sb[0]), 1.0)])
	quit()
