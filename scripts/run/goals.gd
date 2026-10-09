class_name Goals
## «Всегда видна следующая цель, и она близко» (spec 9.1): what the bank's gold can buy
## now and the nearest thing it can't yet — club constructions (ClubBuilds, stream B), the
## shop's next level, the showcase's epic and better items. Read by the summary and the
## shop; stream B can show the same in the club.


## Everything worth gold right now: [{"title", "price", "kind"}], cheapest first.
static func all() -> Array:
	var out: Array = []
	for id in ClubBuilds.ORDER:
		if not ClubBuilds.is_open(id) or ClubBuilds.is_building(id):
			continue  # closed, or already paid and on scaffolding
		var n := ClubBuilds.next(id)
		if n.is_empty():
			continue
		out.append({"title": "%s: %s" % [ClubBuilds.TABLE[id]["name"], n["title"]], "price": ClubBuilds.next_price(id), "kind": "build"})
	var stock := Shop.stock()
	for i in stock.size():
		var it: Dictionary = stock[i]
		if not it.is_empty() and int(it["rarity"]) >= Gear.EPIC:
			out.append({"title": String(it["name"]), "price": Items.price(it), "kind": "item"})
	out.sort_custom(func(a, b): return int(a["price"]) < int(b["price"]))
	return out


## extra: gold of a run that is not in the bank yet (the bracket counts it as nearly there).
static func affordable(extra := 0) -> Array:
	return all().filter(func(g): return int(g["price"]) <= SaveData.gold + extra)


## The cheapest goal the bank can't pay yet, with "left" = how much is missing ({} = none).
static func next_goal(extra := 0) -> Dictionary:
	for g in all():
		if int(g["price"]) > SaveData.gold + extra:
			var d: Dictionary = g.duplicate()
			d["left"] = int(g["price"]) - SaveData.gold - extra
			return d
	return {}


## One line for a screen: "По карману: Трибуны (50) · дальше «Бар» — ещё 12" (what the bank
## buys now, and how far the nearest thing it can't buy yet is).
static func line(extra := 0) -> String:
	var parts: Array[String] = []
	var a := affordable(extra)
	if not a.is_empty():
		var g: Dictionary = a.back()  # the dearest one within reach: the most exciting
		parts.append("По карману: %s · %d" % [g["title"], int(g["price"])])
	var n := next_goal(extra)
	if not n.is_empty():
		parts.append(("дальше «%s» — ещё %d" if not a.is_empty() else "До «%s» ещё %d") % [n["title"], int(n["left"])])
	return "  ·  ".join(parts)
