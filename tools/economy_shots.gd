extends SceneTree
## Stream A economy screens as the phone sees them (v0.2 A-2..A-4): the run's summary with
## income lines and the locker choice, the shop at three levels, a thing and its strings,
## the locker room, the islands, the bracket and the bag with the locker.
##   godot --path . --rendering-driver opengl3 -s tools/economy_shots.gd -- --tag=a [--size=1480]
## PNGs go to the user data folder as eco_<tag>_<h>_<name>.png (path printed). Nothing is saved.

var main: Node
var h := 1564
var tag := ""
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://eco_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String, wait := 0.8) -> void:
	await create_timer(wait).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _reset(gold: int) -> void:
	SaveData.gold = gold
	SaveData.locker = {}
	SaveData.club = {}
	SaveData.titles = 0
	SaveData.titles_by_loc = {}
	SaveData.played = 12


func _run() -> void:
	root.size = Vector2i(720, h)
	SaveData.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout
	SaveData.control_chosen = true
	main._stop_match()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41

	# The summary: out in the first round, a rare worn, commons in the bag.
	_reset(120)
	var t := Tournament.new(1, 9)
	t.equip["racket"] = Gear._affix_item(Gear.RARE, rng, "racket")
	t.equip["shoes"] = Items.set_level(Items.instance(Items.find("springs")) if not Items.find("springs").is_empty() else Gear._affix_item(Gear.EPIC, rng, "shoes"), 2)
	t.bag = [Gear._affix_item(Gear.COMMON, rng, "band")]
	t.earn("prize", 20)
	t.earn("style", 14)
	t.earn("sell", 5)
	t.record_match(false, "2:6", rng)
	t.earn("quests", 0)
	main.tournament = t
	SaveData.record_run(t)
	main.ui.show_summary(t)
	await _shot("sum_lost", 2.4)
	main._on_ui("sum_keep", 0)
	await _shot("sum_kept", 0.6)

	# A champion with a legendary: insurance, not enough gold on one, a full locker.
	_reset(30)
	var t2 := Tournament.new(1, 19)
	t2.stage = 4
	t2.equip["racket"] = Items.instance(Items.find("thunderer"))
	t2.equip["band"] = Items.instance(Items.find("crown"))
	t2.bag = [Gear._affix_item(Gear.RARE, rng, "racket")]
	t2.record_match(true, "6:4", rng)
	t2.earn("style", 40)
	main.tournament = t2
	SaveData.record_run(t2)
	t2.banked = true
	main.ui.show_summary(t2)
	await _shot("sum_champion", 2.6)
	SaveData.gold = 400
	main.ui.show_summary(t2)
	await _shot("sum_champion_rich", 0.6)
	Locker.put(Gear._affix_item(Gear.RARE, rng, "band"), 0)
	main._on_ui("sum_keep", 1)
	await _shot("sum_replace", 0.5)

	# The shop: stall, shop, boutique.
	for lv in [0, 1, ClubBuilds.max_level("shop")]:
		_reset(500)
		SaveData.club = {"levels": {"shop": lv, "locker": 1}}
		SaveData.played = 20 + lv
		SaveData.titles_by_loc = {"park": 1, "clay": 1} if lv > 0 else {}
		SaveData.titles = 1 if lv > 0 else 0
		Locker.put(Items.set_level(Items.instance(Items.find("cutter")), 2), 5)
		main._on_ui("club_shop", 0)
		await _shot("shop%d" % lv, 0.7)
		if lv == ClubBuilds.max_level("shop"):
			main._on_ui("shop_pick", 1)
			await _shot("shop_picked", 0.5)
			main._on_ui("shop_buy", 1)
			await _shot("shop_bought", 0.5)
			main._on_ui("shop_owned", 0)
			await _shot("shop_owned", 0.5)
			main._on_ui("shop_strings", 0)
			await _shot("shop_strings", 0.5)
			main._on_ui("shop_strings_go", 0)
			await _shot("shop_strings_done", 0.5)
	# The locker room.
	main._on_ui("club_locker", 0)
	await _shot("locker_room", 0.6)

	# The islands: a new player and one with a title in Spain.
	_reset(50)
	main.ui.show_locations()
	await _shot("islands_new", 0.7)
	SaveData.titles = 1
	SaveData.titles_by_loc = {"park": 1, "clay": 1}
	main.ui.show_locations()
	await _shot("islands_open", 0.7)

	# The bracket and the bag with the locker before the first match.
	_reset(80)
	Locker.put(Items.instance(Items.find("cutter")), 5) if false else null
	SaveData.locker = {"items": [Gear._affix_item(Gear.RARE, rng, "shoes")], "next": [Gear._affix_item(Gear.RARE, rng, "band")]}
	var t3 := Tournament.new(1, 31)
	main.tournament = t3
	Locker.board(t3)
	main.ui.show_bracket(t3)
	await _shot("bracket_locker", 0.7)
	main._on_ui("bag", 0)
	await _shot("bag_locker", 0.6)
	# The chest by the net: closed, then opened (gold, an epic, a wildcard).
	_reset(40)
	var tc := Tournament.new(1, 21)
	tc.stage = 2
	tc.state = Tournament.State.REWARD
	tc.chest = {"round": 1, "gold": 22, "item": Items.instance(Items.find("cutter")), "perk": "", "wildcard": false, "opened": false}
	main.tournament = tc
	main.ui.show_reward(tc)
	await _shot("chest_closed", 0.9)
	main._on_ui("chest_open", 0)
	await _shot("chest_open", 1.2)
	main._on_ui("chest_next", 0)
	await _shot("chest_after", 0.6)
	await _flow()
	_chest_flow()
	print("%s (%d failures)" % ["FLOW OK" if failures == 0 else "FLOW FAILED", failures])
	quit(1 if failures > 0 else 0)


var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _cards() -> int:
	return main.ui._box.get_child_count()


func _flow() -> void:
	print("flow through the real Main")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	_reset(0)
	SaveData.played = 5
	SaveData.gold = 1000
	SaveData.club = {"levels": {"shop": ClubBuilds.max_level("shop"), "locker": 1}}
	main._on_ui("club_shop", 0)
	check(_cards() > 4, "club_shop opens the showcase (%d blocks)" % _cards())
	check(not RunShop.route(main, "bag_back_x", 0), "the router leaves other actions to Main")
	main._on_ui("shop_pick", 0)
	check(RunShop.picked == 0, "a tap picks a card")
	var g := SaveData.gold
	var price := Items.price(Shop.stock()[0])
	main._on_ui("shop_buy", 0)
	check(SaveData.gold == g - price and Locker.next_items().size() == 1, "a second tap buys (-%d)" % price)
	main._on_ui("shop_owned", 10)
	main._on_ui("shop_strings", 10)
	var before: Dictionary = Locker.next_items()[0].duplicate(true)
	main._on_ui("shop_strings_go", 10)
	check(Locker.next_items()[0] != before and SaveData.gold < g - price, "strings: paid, the item changed")
	main._on_ui("shop_owned", 10)
	g = SaveData.gold
	var item_epic: Dictionary = Locker.next_items()[0]
	main._on_ui("shop_sell", 10)
	if int(item_epic["rarity"]) >= Gear.EPIC:
		check(Locker.next_items().size() == 1, "an epic needs a second tap to sell")
		main._on_ui("shop_sell", 10)
	check(Locker.next_items().is_empty() and SaveData.gold > g, "sold into the bank")
	main._on_ui("club_locker", 0)
	check(_cards() > 2, "the locker room opens")
	SaveData.club = {"levels": {"shop": ClubBuilds.max_level("shop")}}  # one cell
	SaveData.locker["items"] = [Gear._affix_item(Gear.RARE, rng, "shoes")]
	main._on_ui("club_locker", 0)
	# the summary
	var t := Tournament.new(1, 5)
	t.equip["racket"] = Gear._affix_item(Gear.RARE, rng, "racket")
	t.bag = [Gear._affix_item(Gear.COMMON, rng, "band")]
	t.record_match(false, "1:6", rng)
	main.tournament = t
	SaveData.record_run(t)
	main.ui.show_summary(t)
	check(_cards() >= 5, "the summary shows income, goal and candidates (%d blocks)" % _cards())
	main._on_ui("sum_keep", 0)  # the locker (1 slot, 1 used) is full: the replace screen
	check(not t.locker_done, "full locker: asks what to replace first")
	main._on_ui("sum_replace", 0)
	check(t.locker_done and Locker.items().size() == 1 and Locker.items()[0]["slot"] == "racket", "replaced: the racket is kept")
	main._on_ui("sum_shop", 0)
	check(RunShop.back_to == "to_summary", "the shop from the summary comes back to it")
	# the bag with the locker, the bracket row, the islands
	var t2 := Tournament.new(1, 6)
	main.tournament = t2
	main.ui.show_bracket(t2)
	RunBag.show_bag(main.ui, t2)
	main._on_ui("locker_take", 0)
	check(t2.equip["racket"]["slot"] == "racket" and Locker.items().is_empty(), "locker_take: into the run")
	main.ui.show_locations()
	check(_cards() >= 5, "the islands screen")
	_reset(0)


func _chest_flow() -> void:
	print("chest flow")
	_reset(0)
	var t := Tournament.new(1, 31)
	main.tournament = t
	main.tournament_mode = true
	t.dry = 2  # the pity: this win must leave a chest
	t.record_match(true, "6:2", RandomNumberGenerator.new())
	check(t.state == Tournament.State.REWARD and not t.chest.is_empty(), "a win after two dry ones leaves a chest")
	main.ui.show_result(t, true, "6:2", {"perfect": 3, "aces": 1, "best_rally": 7})
	main._on_ui("to_reward", 0)
	check(not t.chest.get("opened", true), "the closed chest is on screen")
	main._on_ui("chest_open", 0)
	check(t.chest.get("opened", false), "a tap opens it")
	var gold := t.gold
	main._on_ui("chest_next", 0)
	check(t.chest.is_empty() and t.state == Tournament.State.BRACKET and t.gold == gold, "next: the run goes on to the bracket")
	t.dry = 0
	t.chest = {}
	t.state = Tournament.State.BRACKET
	main.ui.show_result(t, true, "6:2", {"perfect": 0, "aces": 0, "best_rally": 0})
	main._on_ui("to_bracket", 0)
	check(main.ui.is_open(), "no chest: «ДАЛЬШЕ» goes straight to the bracket")
