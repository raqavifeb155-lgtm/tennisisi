class_name RunEffects
extends RefCounted
## The effect bus of the player's gear (ROGUELIKE_DESIGN 5.4, 14.2): an event happens
## (a stroke, a PERFECT, an ace, a won point, a break), every worn item with a trigger on
## it checks its condition and does its primitives. Pure logic, no nodes: RunHub feeds
## the events and carries out what comes back.
##
## fire() returns the actions that reach outside: ["opp_stamina", n], ["self_stamina", f],
## ["money", n]. The rest stays here: temp_mod (until the point ends), point_style (this
## point's style x), run_mod (into the run's mods, Tournament.run_mods, for the rest of
## the run).
##
## Conditions ("if"): type, label, reason (of the stroke / point), every_n (the player's
## n-th stroke of the rally: ctx.rally_n), streak (PERFECTs in a row, a multiple of n),
## tricks (the point had style tricks).

var _items: Array = []            # catalog entries of the worn unique items
var _base := {}                   # mods of everything worn
var _temp := {}                   # until the point ends
var _run_mods: Dictionary         # Tournament.run_mods, shared: lasts the run
var _point_style := 1.0
var _streak := 0                  # PERFECTs in a row this point


func _init(equip: Dictionary, run_mods := {}) -> void:
	_run_mods = run_mods
	for slot in equip:
		var it: Dictionary = equip[slot]
		if it.is_empty():
			continue
		for k in it.get("mods", {}):
			_base[k] = float(_base.get(k, 0.0)) + float(it["mods"][k])
		var e := Items.find(String(it.get("id", "")))
		if not e.is_empty():
			_items.append(e)


## Every stat mod in force now. state: {"tiebreak": bool} for conditional mods.
func mods(state := {}) -> Dictionary:
	var out := _base.duplicate()
	for src in [_temp, _run_mods]:
		for k in src:
			out[k] = float(out.get(k, 0.0)) + float(src[k])
	for e in _items:
		for c in e.get("cond_mods", []):
			if _state_ok(c["if"], state):
				var m := Items.expand(c["mods"])
				for k in m:
					out[k] = float(out.get(k, 0.0)) + float(m[k])
	return out


func _state_ok(cond: Dictionary, state: Dictionary) -> bool:
	for k in cond:
		if state.get(k, null) != cond[k]:
			return false
	return true


## StyleRules boosts of the worn gear: {trick: x, "all": x}, multiplied together.
func style_boosts() -> Dictionary:
	var out := {}
	for e in _items:
		var s: Dictionary = e.get("style", {})
		for k in s:
			out[k] = float(out.get(k, 1.0)) * float(s[k])
	return out


## A special rule of the worn gear (0 = none): cannon_kmh, dive_free, run_dmg, second_wind.
func rule(name: String) -> float:
	for e in _items:
		if e.get("rules", {}).has(name):
			return float(e["rules"][name])
	return 0.0


func point_style() -> float:
	return _point_style


func end_point() -> void:
	_temp = {}
	_point_style = 1.0
	_streak = 0


## An event: returns the actions for RunHub (see the class comment).
func fire(event: String, ctx: Dictionary) -> Array:
	if event == "on_hit":
		_streak = _streak + 1 if ctx.get("label", "") == "PERFECT" else 0
	var out: Array = []
	for e in _items:
		for tr in e.get("triggers", []):
			if tr["on"] != event or not _ok(tr.get("if", {}), ctx):
				continue
			for act in tr["do"]:
				_do(act, out)
	return out


func _ok(cond: Dictionary, ctx: Dictionary) -> bool:
	for k in cond:
		var v = cond[k]
		match k:
			"every_n":
				var n := int(ctx.get("rally_n", 0))
				if n <= 0 or n % int(v) != 0:
					return false
			"streak":
				if _streak <= 0 or _streak % int(v) != 0:
					return false
			"tricks":
				if (not ctx.get("tricks", []).is_empty()) != bool(v):
					return false
			_:
				if ctx.get(k, null) != v:
					return false
	return true


func _do(act: Array, out: Array) -> void:
	match String(act[0]):
		"temp_mod":
			var m := Items.expand({act[1]: act[2]})
			for k in m:
				_temp[k] = float(_temp.get(k, 0.0)) + float(m[k])
		"run_mod":
			var m := Items.expand({act[1]: act[2]})
			for k in m:
				_run_mods[k] = float(_run_mods.get(k, 0.0)) + float(m[k])
		"point_style":
			_point_style *= float(act[1])
		_:
			out.append(act.duplicate())
