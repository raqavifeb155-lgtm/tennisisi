class_name RunResult
## The roguelike part of the match result (v0.2 A): the style the match earned and the
## best point to watch again and share. TournamentUI.show_result calls extra() once; the
## numbers come from RunHub (Main's child), which saw the match.


static func hub(ui: TournamentUI) -> RunHub:
	var m := ui.get_parent()
	return m.get("run_hub") if m != null else null


## Gold the match's style added to the run (already in Tournament.gold).
static func style_gold(ui: TournamentUI) -> int:
	var h := hub(ui)
	return int(h.last_match.get("gold", 0)) if h != null else 0


## What the win put into the bag (and sold when it was full), the style of the match,
## the replay card, and after a replay "Поделиться".
static func extra(ui: TournamentUI, t: Tournament) -> void:
	if t != null and not t.new_items.is_empty():
		var names: Array[String] = []
		for it in t.new_items:
			names.append(String(it["name"]))
		var l := ui._text("В сумку: " + ", ".join(names), UiTheme.text_bold(), UiTheme.T_SMALL + 2, Gear.color(t.new_items[0]))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui._box.add_child(l)
	if t != null and t.auto_sold > 0:
		ui._note("Сумка полна: лишнее продано за %d золота" % t.auto_sold)
	var h := hub(ui)
	if h == null or int(h.last_match.get("points", 0)) <= 0:
		return
	var best: Dictionary = h.last_match.get("best", {})
	var line := "Стиль: %d очков · лучший ×%s" % [int(h.last_match["points"]), StylePlate._x(float(best.get("mult", 1.0)))]
	var g := int(h.last_match.get("gold", 0))
	if g > 0:
		line += " · +%d золота" % g
	ui._box.add_child(ui._text(line, UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.GOLD))
	if not h.has_replay():
		return
	var names: Array[String] = []
	for tr in best.get("tricks", []):
		names.append(String(tr["name"]))
	ui._card({"tag": "Повтор", "title": "Лучшее очко  ▶", "desc": "%s  ·  ×%s" % [" · ".join(names), StylePlate._x(float(best["mult"]))]}, "replay", 0, UiTheme.GOLD)
	if h.share_image != null:
		var b := ui._make_button("Поделиться в чат", "share", 0, "")
		b.add_theme_color_override("font_color", UiTheme.GOLD)
		ui._box.add_child(b)
