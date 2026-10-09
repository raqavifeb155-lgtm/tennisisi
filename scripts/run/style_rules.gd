class_name StyleRules
## Style points (How to Fish's killscore, Balatro's chips x mult): a point the player wins
## is scored by its tricks. Each trick multiplies; the point is worth BASE x mult.
## Pure data and one function, so it is tested headless and gear (RunEffects) can boost
## any trick by id. Hidden tricks are not listed anywhere before they happen.

const BASE := 10
const MASTERPIECE_AT := 5.0
const TRICKS := [
	{"id": "ace", "name": "Эйс", "x": 1.3, "hidden": false},
	{"id": "cannon", "name": "Пушка", "x": 1.5, "hidden": false},
	{"id": "dead_ball", "name": "Мёртвый мяч", "x": 1.3, "hidden": false},
	{"id": "lob_over", "name": "Через голову", "x": 1.5, "hidden": false},
	{"id": "on_line", "name": "По линии", "x": 1.3, "hidden": false},
	{"id": "marathon", "name": "Марафон", "x": 1.5, "hidden": false},
	{"id": "curl", "name": "Выкрут", "x": 1.2, "hidden": false},
	{"id": "knife", "name": "Слайс-нож", "x": 1.2, "hidden": false},
	{"id": "smash", "name": "Молот", "x": 1.2, "hidden": true},
	{"id": "knockout", "name": "Нокаут", "x": 2.0, "hidden": true},
	{"id": "dive", "name": "В прыжке", "x": 1.5, "hidden": true},
	{"id": "comeback", "name": "Камбэк", "x": 1.3, "hidden": true},
	{"id": "hole", "name": "Дыра слева", "x": 1.4, "hidden": false},
	{"id": "perfect", "name": "Идеально", "x": 1.5, "hidden": false},
	{"id": "masterpiece", "name": "Шедевр", "x": 2.0, "hidden": true},
	{"id": "vented", "name": "Психанул", "x": 1.2, "hidden": true},   # the point after a smashed racket (R)
]
const SERVICE_LINE := 6.4     # m from the net: a drop shot dying inside it is a dead ball
const LINE_CM := 0.10         # a winner this close inside the line (VAR) is "on the line"
const NET_PLAYER := 5.0       # an opponent this close to the net can be lobbed
const MARATHON := 20
const CURL := 1.3


static func find(id: String) -> Dictionary:
	for t in TRICKS:
		if t["id"] == id:
			return t
	return {}


## Which tricks a finished point earned and what it is worth.
##   ctx: won, reason, rally, serve_kmh, last {type, label, curl_k, diving, smash},
##        labels (every player stroke's timing), line_margin (-1 = no call),
##        opp_net_dist, second_bounce_z (-1 = none), knocked, comeback, cannon_kmh
##   boosts: {trick id: x, "all": x} from the player's gear
## -> {"tricks": [{id, name, x}], "mult": float, "points": int}
static func evaluate(ctx: Dictionary, boosts := {}) -> Dictionary:
	var ids: Array[String] = []
	if ctx.get("won", false):
		var last: Dictionary = ctx.get("last", {})
		var type := String(last.get("type", ""))
		var reason := String(ctx.get("reason", ""))
		var clean := reason == "WINNER" or reason == "ACE"
		if reason == "ACE":
			ids.append("ace")
			if float(ctx.get("serve_kmh", 0.0)) >= float(ctx.get("cannon_kmh", 200.0)):
				ids.append("cannon")
		var sb := float(ctx.get("second_bounce_z", -1.0))
		if type == "DROP SHOT" and sb >= 0.0 and sb < SERVICE_LINE:
			ids.append("dead_ball")
		if type == "LOB" and float(ctx.get("opp_net_dist", 99.0)) < NET_PLAYER:
			ids.append("lob_over")
		var m := float(ctx.get("line_margin", -1.0))
		if reason == "WINNER" and m >= 0.0 and m <= LINE_CM:
			ids.append("on_line")
		if int(ctx.get("rally", 0)) >= MARATHON:
			ids.append("marathon")
		if clean and type == "TOPSPIN" and float(last.get("curl_k", 1.0)) >= CURL:
			ids.append("curl")
		if clean and type == "SLICE":
			ids.append("knife")
		if clean and (type == "SMASH" or last.get("smash", false)):
			ids.append("smash")
		if reason == "WINNER" and ctx.get("hole", false):
			ids.append("hole")  # G-7: the opponent's weak-backhand trait found out
		if ctx.get("knocked", false):
			ids.append("knockout")
		if last.get("diving", false):
			ids.append("dive")
		if ctx.get("comeback", false):
			ids.append("comeback")
		if ctx.get("vented", false):
			ids.append("vented")
		var labels: Array = ctx.get("labels", [])
		if labels.size() >= 3 and labels.all(func(l): return l == "PERFECT"):
			ids.append("perfect")
	var tricks: Array = []
	var mult := 1.0
	var all := float(boosts.get("all", 1.0))
	for id in ids:
		var x := float(find(id)["x"]) * float(boosts.get(id, 1.0)) * all
		tricks.append({"id": id, "name": find(id)["name"], "x": x})
		mult *= x
	if mult >= MASTERPIECE_AT:
		var x := float(find("masterpiece")["x"])
		tricks.append({"id": "masterpiece", "name": find("masterpiece")["name"], "x": x})
		mult *= x
	return {"tricks": tricks, "mult": mult, "points": 0 if tricks.is_empty() else roundi(BASE * mult)}
