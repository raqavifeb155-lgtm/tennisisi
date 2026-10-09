class_name JuniorDuel
extends Node
## Calibration of the students' matches (T-4): the student's bot (JuniorBot) against OpponentAI,
## tiebreaks to 7, headless, many cases in one run:
##   godot --headless --path . --fixed-fps 60 -- --junior-duel --cases=/path/cases.json
## cases.json is a list of {id, n, seed, a: {stats, traits, age}, b: {stats, play_style, skill},
## stance: "aggr" (a setup for the whole match), boost: units (a given boost in place of the fit's)}.
## One line per case: «JDUEL id=.. n=.. a_wins=.. a_pts=.. b_pts=.. srv_a=.. srv_a_won=.. srv_b=.. srv_b_won=..».
## The same JuniorWatch plays it as plays the live match (headless = no screens).

var main: Node
var watch: JuniorWatch
var cases: Array = []
var _ci := -1
var _i := 0
var _acc := {}


static func requested() -> bool:
	return "--junior-duel" in OS.get_cmdline_user_args()


func start(m: Node) -> void:
	main = m
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cases="):
			path = a.substr(a.find("=") + 1)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		cases = parsed
	if cases.is_empty():
		print("JDUEL no cases in '%s'" % path)
		main.get_tree().quit(1)
		return
	watch = JuniorWatch.new()
	main.add_child(watch)
	watch.setup(main)
	watch.done.connect(_on_done)
	_next_case.call_deferred()


func _next_case() -> void:
	_ci += 1
	if _ci >= cases.size():
		print("JDUEL end")
		main.get_tree().quit()
		return
	_i = 0
	var tune: Dictionary = cases[_ci].get("tune", {})
	JuniorBot.lv_a = float(tune.get("lv_a", JuniorBot.lv_a))
	JuniorBot.lv_b = float(tune.get("lv_b", JuniorBot.lv_b))
	JuniorBot.sd_max = float(tune.get("sd_max", JuniorBot.sd_max))
	_acc = {"a_wins": 0, "a_pts": 0, "b_pts": 0, "srv_a": 0, "srv_a_won": 0, "srv_b": 0, "srv_b_won": 0}
	_match()


func _match() -> void:
	var c: Dictionary = cases[_ci]
	var a: Dictionary = (c["a"] as Dictionary).duplicate(true)
	a["id"] = "duel"
	a["name"] = String(a.get("name", "Аня Орлова"))
	a["traits"] = a.get("traits", [])
	a["revealed"] = a.get("revealed", [])
	var b: Dictionary = (c["b"] as Dictionary).duplicate(true)
	b["name"] = String(b.get("name", "Соперник"))
	b["skill"] = float(b.get("skill", clampf((JuniorMatch.mean_stat(b["stats"]) - 2.0) / 7.0, 0.0, 1.0)))
	var seed_v := int(c.get("seed", 1)) * 1000 + _i
	var entry := {"id": "duel", "seed": seed_v, "first": _i % 2, "setups": [], "pa": 0, "pb": 0}
	var opts := {"headless": true, "student": a, "opponent": b, "fixed_stance": String(c.get("stance", ""))}
	if c.get("boost", null) != null:
		opts["fixed_boost"] = float(c["boost"])
		if String(opts["fixed_stance"]) == "":
			opts["fixed_stance"] = "boost"   # a pseudo setup: no change of style, only the given boost
	watch.start(entry, opts)


func _emit(line: String) -> void:
	print(line)
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			path = a.substr(a.find("=") + 1)
	if path != "":
		var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		f.seek_end()
		f.store_line(line)
		f.close()


func _on_done(info: Dictionary) -> void:
	_acc["a_pts"] += int(info["pa"])
	_acc["b_pts"] += int(info["pb"])
	_acc["a_wins"] += 1 if int(info["pa"]) > int(info["pb"]) else 0
	for k in ["srv_a", "srv_a_won", "srv_b", "srv_b_won"]:
		_acc[k] += int(info["stats"][k])
	_i += 1
	var c: Dictionary = cases[_ci]
	if _i >= int(c.get("n", 10)):
		_emit("JDUEL id=%s n=%d a_wins=%d a_pts=%d b_pts=%d srv_a=%d srv_a_won=%d srv_b=%d srv_b_won=%d" % [c.get("id", str(_ci)), _i, _acc["a_wins"], _acc["a_pts"], _acc["b_pts"], _acc["srv_a"], _acc["srv_a_won"], _acc["srv_b"], _acc["srv_b_won"]])
		_next_case.call_deferred()
	else:
		_match.call_deferred()
