class_name AiProfile
extends RefCounted
## Profiles for the AI-against-AI autoplay (D-6, ACADEMY_LEGACY_TZ 6.3, 6.11). A spec is text
## from the command line, so a bot and a test can describe a player without a roster id:
##   side A, the bot on the player's side:   "lv=5,sd=0.06,serve=7"  (Skills levels; lv = all
##                                            skills, sd = its timing error, s)
##   side B, OpponentAI:                     "rublev"  or  "junior:skill=0.4,serve=7,style=counter"
##                                            (a roster id, or a name, then: skill 0..1, the six
##                                            stats 1..10, style = a play style id)
## The result of parse_opponent() is exactly what OpponentAI.set_profile() takes.

const STYLE_KEY := "style"


## "name:key=value,key=value" -> {"name": .., "pairs": {key: value}}.
static func _split(spec: String) -> Dictionary:
	var head := spec
	var tail := ""
	if ":" in spec:
		head = spec.get_slice(":", 0)
		tail = spec.substr(spec.find(":") + 1)
	elif "=" in spec:
		head = ""
		tail = spec
	var pairs := {}
	for part in tail.split(",", false):
		var kv := part.strip_edges().split("=", false, 1)
		if kv.size() == 2:
			pairs[kv[0].strip_edges()] = kv[1].strip_edges()
	return {"name": head.strip_edges(), "pairs": pairs}


## Side A: {"levels": {skill id: level}, "sd": timing error}.
static func parse_player(spec: String, default_sd := 0.05) -> Dictionary:
	var p: Dictionary = _split(spec)["pairs"]
	var levels := {}
	if p.has("lv"):
		for id in Skills.LIST:
			levels[id] = clampi(int(p["lv"]), 0, Skills.MAX_LEVEL)
	for id in Skills.LIST:
		if p.has(id):
			levels[id] = clampi(int(p[id]), 0, Skills.MAX_LEVEL)
	return {"levels": levels, "sd": float(p.get("sd", default_sd))}


## Side B: an Opponents-like dictionary for OpponentAI.set_profile().
static func parse_opponent(spec: String) -> Dictionary:
	var sp := _split(spec)
	var opp: Dictionary = Opponents.find(String(sp["name"])).duplicate(true)
	if opp.is_empty():
		opp = {"id": "custom", "name": String(sp["name"]) if sp["name"] != "" else "Соперник", "skill": 0.5}
	var p: Dictionary = sp["pairs"]
	if p.has("skill"):
		opp["skill"] = clampf(float(p["skill"]), 0.0, 1.0)
	if p.has(STYLE_KEY) and Opponents.PLAY_STYLES.has(String(p[STYLE_KEY])):
		opp["play_style"] = String(p[STYLE_KEY])
	var st: Dictionary = Opponents.stats(opp).duplicate()
	for k in Opponents.STAT_KEYS:
		if p.has(k):
			st[k] = clampi(int(p[k]), 1, 10)
	opp["stats"] = st
	return opp


## Skills of a player from levels: experience that brings each skill exactly to its level.
static func apply_levels(levels: Dictionary) -> void:
	Skills.reset()
	Skills.xp = {}
	for id in levels:
		var total := 0.0
		for n in range(1, int(levels[id]) + 1):
			total += Skills.cost(n)
		if total > 0.0:
			Skills.xp[id] = total
	Skills.pending = []
	Skills.points = 0
