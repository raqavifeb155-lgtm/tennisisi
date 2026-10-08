extends SceneTree
## The loot and reward cards as the phone sees them (v0.2 L, spec 2026-10-08-v02-L-loot-cards):
##   godot --path . --rendering-driver opengl3 -s tools/loot_shots.gd [-- --size=1480] [--tag=l]
## The reward's backs, a turn in the middle, the opened row, a mythic's moment; the loot
## card in every rarity; a thing in flight to the bag; the bag, a thing, the shop and the
## locker. 720 x 1564 by default, --size=1480 a small Android; PNGs go to the user data
## folder (path printed). Progress is not saved.

var main: Node
var h := 1564
var out := ""
var tag := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			h = int(a.get_slice("=", 1))
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1) + "_"
	out = ProjectSettings.globalize_path("user://loot_%s%d_" % [tag, h])
	_run.call_deferred()


func _shot(name: String, wait := 0.7) -> void:
	await create_timer(wait).timeout
	await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
	print("saved ", out + name + ".png")


func _item(id: String) -> Dictionary:
	return Items.instance(Items.find(id))


func _gen(slot: String, r: int, seed_i := 3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	return Gear._affix_item(r, rng, slot)


func _offer(items: Array) -> Array:
	var cards: Array = []
	for it in items:
		cards.append({"kind": "item", "item": it, "title": it["name"], "desc": Gear.describe(it)})
	return cards


func _run() -> void:
	root.size = Vector2i(720, h)
	SaveData.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(7.0).timeout  # loading screen
	SaveData.control_chosen = true
	SaveData.enabled = false
	Skills.pending = []
	ItemThumb.clear()
	# The screens are reached through load(): a tool script compiles before the autoloads exist.
	var ui = main.ui
	var ItemFxS = load("res://scripts/ui/item_fx.gd")
	var RunBagS = load("res://scripts/ui/screens/run_bag.gd")
	var RunLockerS = load("res://scripts/ui/screens/run_locker.gd")
	var RunShopS = load("res://scripts/ui/screens/run_shop.gd")
	var t := Tournament.new(1, 11)
	main.tournament = t
	main.tournament_mode = true
	t.equip["racket"] = _item("sledgehammer")
	t.equip["band"] = _gen("band", 0)
	t.bag = [_gen("racket", 1), _item("springs"), _gen("shoes", 0)]
	t.gold = 40
	t.stage = 1

	# The reward: a mixed row (common item, wildcard, perk), then one with a legendary.
	t.state = Tournament.State.REWARD
	t.offer = Rewards.offer([], RandomNumberGenerator.new())
	t.offer.insert(1, _offer([_gen("shoes", 1)])[0])
	ui.show_reward(t)
	await _shot("r1_backs", 0.35)
	await _shot("r2_turning", 0.55)
	await _shot("r3_open", 1.6)
	t.offer = _offer([_item("cutter"), _item("terry_band"), _item("heavy_steps")])
	ui.show_reward(t)
	await _shot("r4_backs_rarities", 0.45)
	await _shot("r5_open_rarities", 1.9)
	t.offer = _offer([_item("sun"), _gen("racket", 0), _item("ace_counter")])
	ui.show_reward(t)
	await _shot("r6_mythic_moment", 1.15)
	await _shot("r7_mythic_open", 2.8)

	# The loot in every rarity.
	var loot := [_gen("racket", 0), _gen("shoes", 1), _item("twister"), _item("ghost_sneakers"), _item("sun")]
	for i in loot.size():
		t.pending_loot = loot[i]
		ui.show_loot(t)
		await _shot("l%d_loot_%d" % [i + 1, i], 1.4)
	t.pending_loot = _item("crown")
	ui.show_loot(t)
	await _shot("l6_loot_band", 1.4)
	# Taking it: the picture in flight into the bag's chip.
	var plan: Dictionary = (ui._actions.get_child(0) as Button).get_meta("fly")
	var done := [false]
	(func() -> void:
		await ItemFxS.run(ui, plan)
		done[0] = true).call()
	await _shot("f1_flight", 0.28)
	while not done[0]:
		await process_frame
	await _shot("f2_landed", 0.12)
	t.pending_loot = {}

	# The bag, a thing in it, the locker and the shop.
	RunBagS.show_bag(ui, t)
	await _shot("b1_bag")
	RunBagS.show_item(ui, t, RunBagS.BAG_ARG + 1)
	await _shot("b2_item")
	SaveData.gold = 700
	Locker.items().clear()
	Locker.next_items().clear()
	Locker.items().append(_item("lightning_rod"))
	Locker.items().append(_item("second_wind"))
	Locker.next_items().append(_item("lucky_coin"))
	RunLockerS.show_locker(ui)
	await _shot("c1_locker")
	RunShopS.back_to = "menu"
	RunShopS._from = "shop"
	RunShopS.picked = 1
	RunShopS.show_shop(ui)
	await _shot("s1_shop")
	var buy: Button = ui._actions.get_child(0)
	if buy.has_meta("fly"):
		var done2 := [false]
		var plan2: Dictionary = buy.get_meta("fly")
		(func() -> void:
			await ItemFxS.run(ui, plan2)
			done2[0] = true).call()
		await _shot("s2_buy_flight", 0.3)
		while not done2[0]:
			await process_frame
	RunShopS.show_owned(ui, 0)
	await _shot("s3_owned")
	quit()
