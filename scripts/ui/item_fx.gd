class_name ItemFx
extends RefCounted
## Things moving between the card and the player (v0.2 L-3): a taken, put-on or bought thing
## lifts off its card as its picture and flies in an arc into the bag's chip, which hops and
## shows «+1»; a sold one pours coins into the gold chip. TournamentUI._press runs the plan
## a button carries (TournamentUI.carry / carry_coins) after its dip, before the screen
## changes, so the flight is seen and the chip is right when the next screen builds.

const FLIGHT := 0.55


## The plan of a button: what flies when it is pressed.
static func item_plan(item: Dictionary, from: Control, count_after: int, slot := "", spend := 0) -> Dictionary:
	return {"kind": "item", "item": item, "from": from, "count": count_after, "slot": slot, "spend": spend}


static func coin_plan(from: Control, gain: int, to_value: int, into_run: bool) -> Dictionary:
	return {"kind": "coins", "from": from, "gain": gain, "to_value": to_value, "run": into_run}


## Runs a plan and returns when everything has landed.
static func run(ui: TournamentUI, plan: Dictionary) -> void:
	var from = plan.get("from")
	if not (from is Control) or not is_instance_valid(from):
		from = null
	if int(plan.get("spend", 0)) > 0:
		spend(ui, int(plan["spend"]))
	match String(plan.get("kind", "")):
		"item":
			await fly_item(ui, plan["item"], from, int(plan["count"]), String(plan.get("slot", "")))
		"coins":
			await ui._fly_coins(from, int(plan["gain"]), int(plan["to_value"]), bool(plan["run"]), false, true)


## The picture's rectangle on a card (or the control itself when it has none).
static func picture_rect(from: Control) -> Rect2:
	var v = from.get("_thumb") if from is GameCard else from
	if v is Control and (v as Control).is_visible_in_tree():
		return (v as Control).get_global_rect()
	var c := from.get_global_rect().get_center()
	return Rect2(c - Vector2(66, 66), Vector2(132, 132))


## The thing lifts off `from` and lands in the bag's chip: coroutine, done when it has landed.
static func fly_item(ui: TournamentUI, item: Dictionary, from: Control, count_after: int, slot := "") -> void:
	var chip: BagChip = ui.bag_chip
	if chip == null:
		return
	if from == null or not chip.is_visible_in_tree():
		chip.set_count(count_after)
		return
	var rect := picture_rect(from)
	var sprite := ItemThumb.view(item, slot, rect.size.x)
	sprite.position = rect.position
	sprite.pivot_offset = rect.size * 0.5
	ui.root.add_child(sprite)
	var src: Control = from.get("_thumb") if from is GameCard else from
	if src != null and src != from:
		src.modulate.a = 0.0  # the picture has left the card
	elif from is ItemThumb.ThumbView:
		from.modulate.a = 0.0
	if from is GameCard:
		var dim := from.create_tween()
		dim.set_ignore_time_scale(true)
		dim.tween_property(from, "modulate:a", 0.45, 0.18)
	var p0 := rect.get_center()
	var p1 := chip.icon_center()
	var mid := (p0 + p1) * 0.5 + Vector2(-60.0, 120.0)  # a bow down and out, then up into the corner
	var tw := sprite.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(func(k: float) -> void:
		var q := (1.0 - k) * (1.0 - k) * p0 + 2.0 * (1.0 - k) * k * mid + k * k * p1
		sprite.position = q - sprite.size * 0.5
		var s := lerpf(1.0, 0.3, k * k) + 0.18 * sin(k * PI)
		sprite.scale = Vector2(s, s)
		sprite.rotation = k * 0.9, 0.0, 1.0, FLIGHT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ui.sfx_request.emit("hit", -12.0, 1.9)
	await tw.finished
	sprite.queue_free()
	chip.land(count_after)
	ui.sfx_request.emit("bounce", -8.0, 1.6)


## A purchase: the bank chip counts down by the price.
static func spend(ui: TournamentUI, price: int) -> void:
	var from_v := ui._gold_shown
	var tw := ui.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(func(v: float) -> void: ui._set_chip(roundi(v)), float(from_v), float(maxi(0, from_v - price)), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var chip: Control = ui._chip
	chip.pivot_offset = chip.size * 0.5
	var p := chip.create_tween()
	p.set_ignore_time_scale(true)
	p.tween_property(chip, "scale", Vector2(0.92, 0.92), 0.06)
	p.tween_property(chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui.sfx_request.emit("bounce", -12.0, 1.2)
