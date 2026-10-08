extends SceneTree
## The blackjack table at the bar as the phone sees it (stream E, docs spec 2026-10-08-v02-blackjack 3):
##   godot --path . --rendering-driver opengl3 -s tools/blackjack_shots.gd [-- --size=1480] [--tag=e]
## 720x1564 = iPhone 17 Pro Max (440x956), --size=1480 = a small Android (360x740).
## PNGs go to the user data folder: club_<tag>_<h>_bj*.png (path printed), with the draw
## calls of each frame. Never writes the save. Hands are played on stacked shoes.

var main: Node
var h := 1564
var tag := ""
var out := ""
var worst := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://club_%s%d_" % [tag, h])
	_run.call_deferred()


func C(r: String, s: String) -> int:
	var ranks := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	return "shdc".find(s) * 13 + ranks.find(r)


func _stack(cards: Array) -> Blackjack:
	var g := Blackjack.new(1)
	g.set_shoe(cards)
	return g


func _shot(name: String, settle := 0.8) -> void:
	await create_timer(settle).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	var d := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	# The table's own part: the same frame without it (the felt, the wood, the cards, the chips, the dealer).
	var t = main.club.world.blackjack_root().get_node_or_null("blackjack")
	var own := -1
	if t != null:
		t.visible = false
		await process_frame
		await process_frame
		own = d - int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		t.visible = true
		var dl: Node3D = t.get("_dealer")
		t.set_process(false)  # (it shows the dealer again by itself)
		dl.visible = false
		await process_frame
		await process_frame
		var no_dealer := d - int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		dl.visible = true
		t.set_process(true)
		await process_frame
		print("   without the dealer: -%d" % no_dealer)
	worst = maxi(worst, own)
	print("saved %s%s.png   draws %d  (the table's own: %d)" % [out, name, d, own])


func _run() -> void:
	root.size = Vector2i(720, h)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SaveData.enabled = false
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	SaveData.played = 1
	SaveData.titles = 1
	SaveData.gold = 420
	SaveData.club = {"met_coach": true}
	SaveData.active = null
	SaveData.run = {}
	SaveData.bets = {}
	Skills.pending = []
	main._show_menu()
	await create_timer(1.0).timeout
	main.club._travel("blackjack")
	await _shot("bj00_at_the_table", 1.0)
	main.club._on_choice("club_blackjack", 0)
	var t: ClubBlackjack = main.club.world.blackjack_root().get_node("blackjack")
	await _shot("bj01_empty", 1.2)
	t.clear_bets()
	t.add_chip(25, "main")
	t.add_chip(5, "pp")
	t.add_chip(5, "t3")
	await _shot("bj02_bets", 0.8)
	# A pair of 8s against a 6: split, double, stand.
	t.game = _stack([C("8", "s"), C("6", "h"), C("8", "h"), C("3", "c"), C("10", "d"), C("8", "d"), C("10", "s"), C("5", "s")])
	t.deal()
	await _shot("bj03_dealing", 0.3)
	await _shot("bj04_play", 1.6)
	t.split()
	await _shot("bj05_split", 1.6)
	t.double()
	await _shot("bj06_double", 1.4)
	t.stand()
	await _shot("bj07_result", 3.0)
	# A blackjack with all three bets, then a lost hand: three in a row -> the break.
	SaveData.bets["loss_streak"] = 2
	t.game = _stack([C("10", "s"), C("10", "h"), C("7", "d"), C("9", "c")])
	t.bets = {"pp": 5, "main": 25, "t3": 5}
	t.deal()
	await create_timer(1.6).timeout
	t.stand()
	await _shot("bj08_break", 3.2)
	# A big hand: five cards and a split on the felt at once.
	t.bets = {"pp": 0, "main": 25, "t3": 0}
	t.game = _stack([C("2", "s"), C("5", "h"), C("3", "d"), C("4", "c"), C("5", "s"), C("6", "d"), C("K", "h")])
	t.deal()
	await create_timer(1.6).timeout
	t.hit()
	await create_timer(0.6).timeout
	t.hit()
	await _shot("bj09_five_cards", 1.6)
	# The top bar (stream B: chips up to 1000): the row of seven.
	t.chips_override = [10, 25, 50, 100, 250, 500, 1000]
	t.limit_override = 1000
	SaveData.gold = 9000
	t.bets = {"pp": 0, "main": 0, "t3": 0}
	t.game = _stack([C("K", "s"), C("9", "h"), C("K", "d"), C("7", "c")])
	t._ui.fill_chips()
	t.clear_bets()
	t.add_chip(500, "main")
	t.add_chip(250, "main")
	t.add_chip(100, "pp")
	t.add_chip(10, "t3")
	await _shot("bj11_top_bar_chips", 1.2)
	print("worst frame of the table itself: %d draw calls" % worst)
	t.close()
	await _shot("bj10_back_in_the_club", 1.0)
	quit()
