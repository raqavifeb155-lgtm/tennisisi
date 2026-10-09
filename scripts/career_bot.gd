class_name CareerBot
## The autoplay bot through a whole career (L1): --autoplay --tournament --career-runs=N plays
## N tournaments in a row instead of one; the retirement after the 20th goes by itself (the
## best thing becomes the relic, the first heir is taken) and the heir plays on.
## --career-reload: after every run the save goes through text and back (SaveData._to_config
## -> ConfigFile.parse -> SaveData._apply), as a page reload would, and is checked.
##   godot --headless --path . --fixed-fps 60 -- --autoplay --tournament --format=0 --bot-sd=0.07 --career-runs=21 --career-reload

static var runs := -1              # tournaments to play (-1 = not asked: one tournament, as before)
static var reload := false
static var done := 0
static var reload_fails := 0


static func _args() -> void:
	if runs >= 0:
		return
	runs = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--career-runs="):
			runs = int(a.get_slice("=", 1))
		elif a == "--career-reload":
			reload = true


## Main._autoplay_after_match, the run is over: true = another tournament was started.
static func next(m: Node) -> bool:
	_args()
	if runs <= 0:
		return false
	done += 1
	var t: Tournament = m.get("tournament")
	if t != null and not t.banked:
		SaveData.record_run(t)  # the bot gave up a too long run: it still counts
	var c := Career.data()
	var last: Dictionary = (c["cells"] as Array).back() if not (c["cells"] as Array).is_empty() else ((Career.last_season().get("cells", [{}]) as Array).back())
	print("CAREER run %d/%d · gen %d · season %d · %d/4 · age %d · +%d pts%s · bank %d" % [done, runs, int(c["gen"]), Career.season(),
		int(c["in_season"]), int(c["age"]), int(last.get("pts", 0)), " (final)" if last.get("final", false) else "", SaveData.gold])
	if int(c["season_due"]) > 0:
		var s := Career.last_season()
		print("SEASON %d over: %d pts · %s · +%d gold" % [int(s["season"]), int(s["pts"]), Career.rank_text(int(s["rank"])), int(s["gold"])])
		c["season_due"] = 0
	if reload:
		_reload()
	if done >= runs:
		print("\n=== CAREER ===\nruns %d · generation %d · retired %d · season %d %d/4 · reload checks failed %d" % [done, int(c["gen"]),
			(c["retired"] as Array).size(), Career.season(), int(c["in_season"]), reload_fails])
		return false
	m.call_deferred("_start_tournament", int(m.get("_autoplay_format")))
	return true


## The save through text and back: the career, the skills and the look must come back.
static func _reload() -> void:
	var before := SaveData.career.duplicate(true)
	var levels := {}
	for id in Skills.LIST:
		levels[id] = Skills.level(id)
	var perks := Skills.perks.duplicate()
	var look := SaveData.look.duplicate(true)
	var gold := SaveData.gold
	var cf := ConfigFile.new()
	cf.parse(SaveData._to_config().encode_to_text())
	SaveData._apply(cf)
	var ok := SaveData.career == before and Skills.perks == perks and SaveData.look == look and SaveData.gold == gold
	for id in Skills.LIST:
		ok = ok and Skills.level(id) == int(levels[id])
	if not ok:
		reload_fails += 1
	print("  reload: %s" % ("ok" if ok else "FAIL"))


## The ceremony without screens: the rarest thing is the relic, the first heir plays on and
## spends his starting points like the bot's first player did.
static func auto_retire(m: Node) -> void:
	var t: Tournament = m.get("tournament")
	var opts := Career.relic_options(t)
	var relic := {}
	for o in opts:
		if relic.is_empty() or int(o["item"].get("rarity", 0)) > int(relic["item"].get("rarity", 0)):
			relic = o
	var heirs := Career.heir_candidates()
	var rec := Career.retire(heirs[0], relic, t)
	print("RETIRED %s (gen %d): %d runs, %d titles, best %s, best skill %s %d%s" % [rec["name"], int(rec["gen"]), int(rec["runs"]),
		int(rec["titles"]), Career.rank_text(int(rec["best_rank"])), rec["best_skill"], int(rec["levels"][rec["best_skill"]]),
		", relic " + String(rec["relic"]["name"]) if not (rec["relic"] as Dictionary).is_empty() else ""])
	print("HEIR %s (%s): %s" % [heirs[0]["name"], heirs[0]["origin"], CareerUi.levels_text(heirs[0]["levels"])])
	for id in ["forehand", "backhand", "serve"]:
		Skills.spend_point(id)
	var p = m.get("player")
	if p != null:
		p.set_look(SaveData.look)
