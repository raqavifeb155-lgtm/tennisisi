class_name RunChest
## The chest by the net (v0.2 A-7): what a win may leave instead of «1 из 3». The screen shows
## the closed chest, a tap opens it (the lid flies up, the rarity's reveal effect, the gold
## flies into the run's chip), then the things inside as cards and «ДАЛЬШЕ» carries the item
## into the bag chip. The logic is Tournament.make_chest / open_chest / take_chest.
##
## Actions (Main -> RunShop.route): chest_open, chest_next.


## The chest, drawn: a wooden body with a gold band and lock, a lid that opens (open: 0..1).
class ChestArt extends Control:
	var open := 0.0
	var color := UiTheme.GOLD
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.58)
		var w := minf(size.x * 0.62, 400.0)
		var h := w * 0.5
		var bob := sin(_t * 2.2) * 5.0 if open < 0.01 else 0.0
		c.y += bob
		# a glow behind: it grows when the chest is open
		draw_circle(c + Vector2(0, -h * 0.4), w * (0.62 + 0.25 * open + 0.03 * sin(_t * 3.0)), Color(color, 0.10 + 0.14 * open))
		var wood := Color(0.50, 0.30, 0.14)
		var wood_hi := Color(0.62, 0.40, 0.2)
		var band := Color(0.95, 0.74, 0.2)
		# the body
		draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), wood)
		draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h * 0.16), wood_hi)
		draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), Color(0, 0, 0, 0.35), false, 4.0)
		for k in [-0.34, 0.34]:
			draw_rect(Rect2(c.x + w * k - w * 0.045, c.y - h * 0.5, w * 0.09, h), band)
		# the inside, lit, when it is open
		if open > 0.02:
			draw_rect(Rect2(c.x - w * 0.46, c.y - h * 0.5, w * 0.92, h * 0.12), Color(color.lightened(0.5), 0.9))
		# the lid: a half-round, hinged at the back, turning up and over as it opens
		var hinge := Vector2(c.x - w * 0.5, c.y - h * 0.5)
		var ang := -open * 1.35
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			pts.append(Vector2(w * 0.5 - cos(a) * w * 0.5, -sin(a) * h * 0.55))
		var tx := Transform2D(ang, hinge)
		var lid := PackedVector2Array()
		for p in pts:
			lid.append(tx * p)
		draw_colored_polygon(lid, wood_hi)
		draw_polyline(lid, Color(0, 0, 0, 0.4), 4.0)
		for k in [0.16, 0.84]:
			draw_line(tx * Vector2(w * k, -h * 0.5), tx * Vector2(w * k, 0), band, w * 0.09)
		# the lock
		if open < 0.5:
			var lk := Vector2(c.x, c.y - h * 0.5)
			draw_rect(Rect2(lk.x - 18, lk.y - 10, 36, 40), band)
			draw_circle(lk + Vector2(0, 8), 6.0, Color(0.2, 0.12, 0.02))
		# sparkles over the closed chest: it is worth a tap
		if open < 0.01:
			for i in 5:
				var a2 := _t * 1.3 + i * 1.26
				var p2 := c + Vector2(cos(a2) * w * 0.55, -h * 0.5 - 40.0 + sin(a2 * 1.7) * 36.0)
				var r := 5.0 + 3.0 * sin(_t * 4.0 + i)
				draw_circle(p2, r, Color(1, 0.95, 0.6, 0.8))


static func ui_action(m: Node, action: String, arg: int) -> void:
	var ui: TournamentUI = m.ui
	var t: Tournament = m.tournament
	if t == null:
		return
	match action:
		"chest_open":
			t.open_chest()
			SaveData.save()
			show_chest(ui, t, true)
		"chest_next":
			var over := t.state == Tournament.State.OVER
			t.take_chest()
			SaveData.save()
			if over:
				ui.show_summary(t)
			else:
				ui.show_bracket(t)


## The closed chest (a tap opens it) or the opened one with what is inside.
static func show_chest(ui: TournamentUI, t: Tournament, just_opened := false) -> void:
	var c: Dictionary = t.chest
	if c.is_empty():
		ui.show_bracket(t)
		return
	ui._open(t)
	ui.show_stash(RunBag.carried(t))
	var opened: bool = c.get("opened", false)
	ui._title("Сундук!" if not opened else "В сундуке")
	ui._sub("Он стоял у сетки. Тап — открыть" if not opened else "Всё твоё")
	var art := ChestArt.new()
	art.custom_minimum_size = Vector2(0, 360 if not opened else 330)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not opened:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 360)
		b.add_child(art)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(func() -> void: ui._press(b, "chest_open", 0))
		ui._box.add_child(b)
		ui._primary("ОТКРЫТЬ", "chest_open")
		return
	ui._box.add_child(art)
	art.open = 0.0 if not just_opened else 0.0
	var tw := art.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(art, "open", 1.0, 0.35 if just_opened else 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui.sfx_request.emit("reward", -8.0, 1.0)
	var gold_card: GameCard = null
	var item_card: GameCard = null
	if int(c["gold"]) > 0:
		gold_card = ui._card({"tag": "Золото", "title": "+%d" % int(c["gold"]), "desc": "в золото забега"}, "", 0, UiTheme.GOLD)
	var it: Dictionary = c["item"]
	if not it.is_empty():
		item_card = RunShop.item_card(ui, it, RunBag.reward_tag(t, it).split("  ·  ")[-1], "")
	if String(c["perk"]) != "":
		var p := Rewards.find_perk(String(c["perk"]))
		ui._card({"tag": "Перк турнира", "title": p["title"], "desc": p["desc"]}, "", 0, UiTheme.GOLD)
	if c["wildcard"]:
		ui._card({"tag": "Вайлд-кард", "title": Rewards.WILDCARD["title"], "desc": Rewards.WILDCARD["desc"]}, "", 0, Color(0.55, 0.8, 1.0))
	var next := ui._primary("ДАЛЬШЕ", "chest_next")
	if item_card != null:
		ui.carry(next, it, item_card, RunBag.carried(t) + 1, String(it.get("slot", "racket")))
	if just_opened:
		_celebrate.call_deferred(ui, t, gold_card, item_card, c)


static func _celebrate(ui: TournamentUI, t: Tournament, gold_card: GameCard, item_card: GameCard, c: Dictionary) -> void:
	await ui.get_tree().create_timer(0.3, true, false, true).timeout
	if item_card != null and is_instance_valid(item_card):
		RevealFx.play(ui, item_card, int(c["item"]["rarity"]))
	if gold_card != null and is_instance_valid(gold_card):
		ui._fly_coins(gold_card, int(c["gold"]), t.gold, true)
