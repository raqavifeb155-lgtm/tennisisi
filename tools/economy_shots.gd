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
	for lv in 3:
		_reset(500)
		SaveData.club = {"levels": {"shop": lv, "locker": 1}}
		SaveData.played = 20 + lv
		SaveData.titles_by_loc = {"park": 1, "clay": 1} if lv > 0 else {}
		SaveData.titles = 1 if lv > 0 else 0
		Locker.put(Items.set_level(Items.instance(Items.find("cutter")), 2), 5)
		main._on_ui("club_shop", 0)
		await _shot("shop%d" % lv, 0.7)
		if lv == 2:
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
	quit()
