class_name ClubBlackjack
extends Node3D
## Blackjack on the bar's terrace (docs/superpowers/specs/2026-10-08-v02-blackjack.md):
## a half-moon table with the pay table printed on its felt, a dealer (an Athlete in a
## waistcoat), cards and chips that fly, and the buttons at the bottom of the screen.
## The rules and the payouts are Blackjack's (scripts/run/blackjack.gd): every action is
## decided there first, gold moves and is saved at once; the table only shows it.
##
## Club's contract (stream B): the place's button calls the static open(club); the scene
## stands on ClubWorld.blackjack_root(); attach() in Club.open builds it with the world.
## The table hides the club's bottom bar while it is open and gives it back; the club's
## gold chip and gear stay where they are.
##
## Budget: the felt, the wood, all cards (one MultiMesh) and all chips (another) are
## five draw calls; the dealer is an Athlete plus his waistcoat.
##
## Local frame: the table's centre on the floor, the dealer at -z, the player at +z.

signal closed

const TOP := 0.86                       # the felt
const EDGE_Z := -0.55                   # the dealer's straight edge
const RADIUS := 1.45                    # the players' arc, round (0, EDGE_Z)
const FELT_W := 2.0                     # the printed part of the felt: x -1..1,
const FELT_D := 1.25                    # z EDGE_Z .. EDGE_Z + 1.25
const CARD := Vector2(0.15, 0.21)       # bigger than real ones: read from a phone
const CARD_T := 0.004
const CHIP_R := BallPhysics.RADIUS * 1.3
const CHIP_H := 0.013
const DEAL := 0.25                      # a card's flight
const DEALER_GAP := 0.35                # the dealer's own draws come slower
const NEAR := 32.0                      # the dealer is drawn and moves within this of the camera
const DEALER_Z := -0.98
const SHOE := Vector3(0.66, TOP + 0.13, -0.38)
const TRAY := Vector3(-0.42, TOP + 0.02, -0.43)
const DEALER_CARDS := Vector3(0.0, TOP + 0.003, -0.16)
const PLAYER_CARDS := Vector3(0.0, TOP + 0.003, 0.3)
const SPOTS := {"pp": Vector3(-0.3, TOP, 0.62), "main": Vector3(0.0, TOP, 0.58), "t3": Vector3(0.3, TOP, 0.62)}
const SPOT_NAMES := {"pp": "Пары", "main": "Ставка", "t3": "21+3"}
## The camera from the player's seat: betting (the circles) and playing (the dealer).
const CAM_BET := [Vector3(0, 2.2, 2.7), Vector3(0, 0.85, -0.1)]
const CAM_PLAY := [Vector3(0, 2.15, 2.15), Vector3(0, 0.8, -0.35)]
const CHIP_COLORS := {
	5: Color(0.95, 0.95, 0.92), 10: Color(0.85, 0.2, 0.2), 25: Color(0.15, 0.6, 0.32), 50: Color(0.2, 0.42, 0.92),
	100: Color(0.13, 0.13, 0.16), 250: Color(0.55, 0.25, 0.75), 500: Color(0.95, 0.55, 0.15), 1000: Color(0.95, 0.8, 0.2),
}
const BALL := Color(0.86, 0.95, 0.3)
const FELT := Color(0.09, 0.42, 0.3)
const DEALER_LOOK := {"skin": 3, "hair": 3, "hair_color": 1, "beard": 2, "head": 0, "shirt": 0, "shorts": 3, "accent": 13}
const ATLAS_COLS := 8
const CELL := Vector2i(128, 180)
const BACK := 52
const CHIP_CELL := {5: 53, 10: 54, 25: 55, 50: 56, 100: 57, 250: 58, 500: 59, 1000: 60}
const MAX_CARDS := 24
const MAX_CHIPS := 180
const OUTCOME := {"blackjack": "Блэкджек!", "win": "Выигрыш", "push": "Ничья", "lose": "Проигрыш", "bust": "Перебор"}
const LINES := {
	"hello": "Делайте ставки",
	"break": "Три руки мимо. Может, перерыв?",
	"shuffle": "Перетасовка",
	"player_bj": "Блэкджек! Поздравляю",
	"dealer_bj": "Блэкджек у дилера",
	"bust": "Перебор",
}

var club: Club
var game := Blackjack.new()
var bets := {"pp": 0, "main": 0, "t3": 0}
var chip := 25
var chips_override: Array = []          # for tests and shots: a bigger bar than the build has
var limit_override := 0
var spot := "main"
var _open := false
var _hero := Vector3.ZERO
var _queue: Array = []                  # the game's events still to show
var _wait := 0.0
var _view := {"hands": [], "dealer": [], "active": 0}
var _cards: Array = []                  # {key, card, from, to, t, dur, arc}
var _stacks: Array = []                 # {key, amount, from, to, t, dur, gone}
var _cards_mm: MultiMeshInstance3D
var _chips_mm: MultiMeshInstance3D
var _tray: Array = []                   # the dealer's rack: static chip transforms
var _felt_mat: StandardMaterial3D
var _atlas_mat: ShaderMaterial
var _dealer: Athlete
var _ui: BlackjackHud
var _round_net := 0
var _round_note := ""
var _show_done := true                  # the last round's result is on show
var _last_bets := {"pp": 0, "main": 0, "t3": 0}
var _textures_ready := false


## The club's button (ClubPlaces "blackjack", action club_blackjack): Club calls this.
static func open(c: Club) -> void:
	attach(c).enter()


## The table in the club's world, on the node ClubWorld keeps for it (blackjack_root():
## the table's centre, -z toward the dealer and the river); B's placeholder steps aside.
static func attach(c: Club) -> ClubBlackjack:
	var root: Node3D = c.world.blackjack_root()
	var t := root.get_node_or_null("blackjack") as ClubBlackjack
	if t == null:
		t = ClubBlackjack.new()
		t.name = "blackjack"
		t.club = c
		root.add_child(t)
		var ph := root.get_node_or_null("placeholder") as Node3D
		if ph:
			ph.visible = false
		# The straight edge is wider than the world's round obstacle: its corners too.
		var o := root.global_position if root.is_inside_tree() else root.position
		c.world.walk.add_box(Rect2(o.x - 1.62, o.z + DEALER_Z - 0.3, 3.24, -DEALER_Z + 0.3 + EDGE_Z + 0.65))
	t.club = c
	return t


func _ready() -> void:
	_build_table()
	_build_multimeshes()
	_build_dealer()
	_ui = BlackjackHud.new()
	_ui.table = self
	add_child(_ui)
	_load_sounds()
	_render_textures()


# --- Opening and closing -----------------------------------------------------------------

func is_open() -> bool:
	return _open


## Cards still on their way (a chip dropping on a spot doesn't count).
func busy() -> bool:
	return not _queue.is_empty() or _wait > 0.0 or _cards_moving()


func _cards_moving() -> bool:
	for c in _cards:
		if float(c["t"]) < 1.0:
			return true
	return false


## Into the table's view (the camera at the player's seat, the panel at the bottom).
func enter() -> void:
	if _open or club == null:
		return
	_open = true
	var main = club.main
	_hero = main.player.position
	main.player.move_input = Vector2.ZERO
	main.player.velocity = Vector3.ZERO
	main.player.visible = false        # he sits right under the camera
	club._move_target = Vector3.INF
	club.hud.hide_place()
	_club_bottom(false)
	_frame(false, 0.45)
	if not main.hud.touch.blocked_controls.has(_ui.catcher):
		main.hud.touch.blocked_controls.append(_ui.catcher)
	_ui.show_table()
	_fit_bets()
	_resume_saved()
	_refresh()
	if Bets.needs_break(SaveData.bets):
		say(LINES["break"])
	else:
		say(LINES["hello"])


## Back to the club. A hand still on is played out by standing (and paid).
func close() -> void:
	if not _open:
		return
	if game.phase == Blackjack.Phase.PLAYER:
		game.finish_standing()
		_after_action()
	skip()
	_open = false
	_ui.hide_table()
	_club_bottom(true)
	if is_instance_valid(club) and club.active:
		club.main.player.visible = true
		club.main.player.position = _hero
		club.cam.release()
		club._place = ""
		club._update_place()
	closed.emit()


## The club's bottom bar (quick travel, the place's button) steps aside for the table.
func _club_bottom(on: bool) -> void:
	if not is_instance_valid(club) or club.hud == null:
		return
	var b = club.hud.get("_bottom")
	if b is Control:
		(b as Control).visible = on
	if not on and club.hud.has_method("_toggle_travel"):
		club.hud._toggle_travel(false)


func _frame(playing: bool, t := 0.4) -> void:
	var v: Array = CAM_PLAY if playing else CAM_BET
	club.cam.frame(to_global(v[0]), to_global(v[1]), t)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(global_position) < NEAR
	if _dealer and _dealer.visible != near:
		_dealer.visible = near
		_dealer.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
	if _open:
		if not is_instance_valid(club) or not club.active:
			close()
			return
		_ui.set_safe(club.main._safe)
	_play_queue(delta)
	_update_cards(delta)
	_update_chips(delta)
	if _open:
		_ui.place_labels()
		if _dealer:
			var look := _look_at()
			_dealer.look_target = look


func _physics_process(_delta: float) -> void:
	if _open and is_instance_valid(club):
		var p: Athlete = club.main.player
		p.move_input = Vector2.ZERO
		p.velocity = Vector3.ZERO
		p.position = _hero


# --- Bets -------------------------------------------------------------------------------

func limit() -> int:
	return limit_override if limit_override > 0 else ClubBuilds.bet_limit()


## The chips on this bar's desk at its level (stream B: ClubBuilds.bar_chips(), up to 1000
## at the top). Until that is in the build: 5 / 25 / 50 / 100 up to the limit.
func table_chips() -> Array:
	var from_bar: Array = chips_override.duplicate()
	var scr: GDScript = ClubBuilds
	for m in scr.get_script_method_list():
		if m["name"] == "bar_chips" and from_bar.is_empty():
			from_bar = scr.call("bar_chips")
	var out: Array = []
	for v in (from_bar if not from_bar.is_empty() else Blackjack.CHIPS):
		if Blackjack.ALL_CHIPS.has(int(v)) and int(v) <= limit():
			out.append(int(v))
	if out.is_empty():
		out.append(int(Blackjack.CHIPS[0]))
	return out


## The smallest chip: no stake under it.
func unit() -> int:
	return int(table_chips()[0])


## Can `amount` be laid out in the chips on the desk?
func _makeable(amount: int) -> bool:
	var ok := PackedByteArray()
	ok.resize(amount + 1)
	ok[0] = 1
	for a in range(1, amount + 1):
		for c in table_chips():
			if int(c) <= a and ok[a - int(c)] == 1:
				ok[a] = 1
				break
	return ok[amount] == 1


## The biggest main bet now: the bar's limit and a quarter of the gold.
func max_main() -> int:
	return Blackjack.max_bet(SaveData.gold, limit())


## What a spot can still take.
func room(id: String) -> int:
	if id == "main":
		return max_main() - int(bets["main"])
	var others := 0
	for k in bets:
		if k != id:
			others += int(bets[k])
	return mini(int(bets["main"]), SaveData.gold - others) - int(bets[id])


func can_bet() -> bool:
	return Bets.unlocked() and game.phase != Blackjack.Phase.PLAYER and not busy()


## A chip of `value` onto a spot (the selected one by default). false: it doesn't fit.
func add_chip(value: int, id := "") -> bool:
	if id == "":
		id = spot
	if not can_bet() or not table_chips().has(value) or value > room(id):
		return false
	_clear_shown_round()
	bets[id] = int(bets[id]) + value
	_bet_stacks()
	_sfx("bj_chip", -6.0)
	_refresh()
	return true


func clear_bets() -> void:
	if not can_bet():
		return
	bets = {"pp": 0, "main": 0, "t3": 0}
	_bet_stacks()
	_refresh()


## The last round's bets again, as far as the gold and the limit allow.
func _fit_bets() -> void:
	var m := mini(int(bets["main"]), max_main())
	while m > 0 and not _makeable(m):
		m -= 1
	bets["main"] = maxi(m, 0)
	for k in ["pp", "t3"]:
		bets[k] = mini(int(bets[k]), int(bets["main"]))
	var over := int(bets["main"]) + int(bets["pp"]) + int(bets["t3"]) - SaveData.gold
	if over > 0:
		bets["pp"] = 0
		bets["t3"] = 0
	var allowed := Blackjack.chips_for(SaveData.gold, limit(), table_chips())
	if not allowed.is_empty() and not allowed.has(chip):
		chip = allowed.back()
	_bet_stacks()


func select_chip(value: int) -> void:
	chip = value
	_refresh()


func select_spot(id: String) -> void:
	spot = id
	_refresh()


# --- A round ----------------------------------------------------------------------------

## Cards out. The stakes leave the gold now and the save is written (a reload can't take
## them back). false: nothing on the table, or the round can't go.
func deal() -> bool:
	if not can_bet():
		return false
	var main := int(bets["main"])
	var total := main + int(bets["pp"]) + int(bets["t3"])
	if main <= 0 or main > max_main() or total > SaveData.gold:
		return false
	if not game.deal(main, int(bets["pp"]), int(bets["t3"])):
		return false
	_last_bets = bets.duplicate()
	SaveData.gold -= total
	_reset_view()
	_bet_stacks_round()
	_after_action()
	_frame(true, 0.5)
	club.hud.set_gold(SaveData.gold)
	return true


func hit() -> bool:
	skip()
	if not game.hit():
		return false
	_after_action()
	return true


func stand() -> bool:
	skip()
	if not game.stand():
		return false
	_after_action()
	return true


func double() -> bool:
	skip()
	if not game.can_double() or SaveData.gold < game.extra_needed():
		return false
	var extra := game.extra_needed()
	SaveData.gold -= extra
	game.double()
	_after_action()
	club.hud.set_gold(SaveData.gold)
	return true


func split() -> bool:
	skip()
	if not game.can_split() or SaveData.gold < game.extra_needed():
		return false
	var extra := game.extra_needed()
	SaveData.gold -= extra
	game.split()
	_after_action()
	club.hud.set_gold(SaveData.gold)
	return true


## After every move: the events go to the queue; the round is saved while it lasts and
## paid out (once) when it's over.
func _after_action() -> void:
	_queue.append_array(game.events)
	game.events = []
	if game.phase == Blackjack.Phase.DONE:
		_pay()
	else:
		SaveData.bets["bj_round"] = game.to_dict()
		SaveData.save()
	_refresh()


func _pay() -> void:
	var back := game.returned()
	SaveData.gold += back
	_round_net = back - game.staked()
	if _round_net != 0:
		Bets.note(SaveData.bets, _round_net > 0)
	SaveData.bets["bj_rounds"] = int(SaveData.bets.get("bj_rounds", 0)) + 1
	if _round_net > 0:
		SaveData.bets["bj_won"] = int(SaveData.bets.get("bj_won", 0)) + 1
	for h in game.hands:
		if h["outcome"] == "blackjack":
			SaveData.bets["bj_blackjacks"] = int(SaveData.bets.get("bj_blackjacks", 0)) + 1
	SaveData.bets.erase("bj_round")
	SaveData.save()


## A round left in the middle last time (the game was closed): played out by standing.
func _resume_saved() -> void:
	var d: Dictionary = SaveData.bets.get("bj_round", {})
	if d.is_empty():
		return
	if not game.from_dict(d) or game.phase != Blackjack.Phase.PLAYER:
		SaveData.bets.erase("bj_round")
		SaveData.save()
		return
	_reset_view()
	for h in game.hands.size():
		for c in game.hands[h]["cards"]:
			_queue.append({"kind": "card", "to": "player", "hand": h, "card": c})
	for c in game.dealer:
		_queue.append({"kind": "card", "to": "dealer", "hand": -1, "card": c})
	game.finish_standing()
	_round_note = "Прошлая рука доиграна: «Хватит»"
	_bet_stacks_round()
	_after_action()
	_frame(true, 0.0)


# --- Showing the events -------------------------------------------------------------------

func _reset_view() -> void:
	_view = {"hands": [[]], "dealer": [], "active": 0, "settled": false, "sides": false}
	_cards = []
	_round_note = ""
	_show_done = false


## The previous round's cards leave the felt when a new bet goes down.
func _clear_shown_round() -> void:
	if _view.get("settled", false) or _show_done:
		_cards = []
		_view = {"hands": [], "dealer": [], "active": 0}
		_show_done = false


func _play_queue(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
	var was := not _queue.is_empty()
	while _wait <= 0.0 and not _queue.is_empty():
		_wait += _apply(_queue.pop_front())
	if was and _queue.is_empty():
		_refresh()
	if _queue.is_empty() and _wait <= 0.0 and game.phase == Blackjack.Phase.DONE and not _show_done and not _animating():
		_round_over()


func _animating() -> bool:
	for c in _cards:
		if float(c["t"]) < 1.0:
			return true
	for s in _stacks:
		if float(s["t"]) < 1.0:
			return true
	return false


## Shows one event; returns how long until the next.
func _apply(e: Dictionary) -> float:
	match e["kind"]:
		"shuffle":
			say(LINES["shuffle"])
			_sfx("bj_shuffle", -4.0)
			return 0.7
		"card":
			var to: String = e["to"]
			var hands: Array = _view["hands"]
			var key := ""
			if to == "dealer":
				(_view["dealer"] as Array).append(e["card"])
				key = "d%d" % (_view["dealer"].size() - 1)
			else:
				var h := int(e["hand"])
				while hands.size() <= h:
					hands.append([])
				(hands[h] as Array).append(e["card"])
				key = "p%d_%d" % [h, hands[h].size() - 1]
			_cards.append({"key": key, "card": e["card"], "from": _shoe_xf(), "to": Transform3D(), "t": 0.0, "dur": DEAL, "arc": 0.12})
			_layout_cards()
			_sfx("bj_card", -5.0, randf_range(0.9, 1.15))
			var slow: bool = to == "dealer" and _view["dealer"].size() > 1
			return DEAL + (DEALER_GAP if slow else 0.04)
		"split":
			var hands: Array = _view["hands"]
			var c0: Array = hands[0]
			hands[0] = [c0[0]]
			hands.append([c0[1]])
			for c in _cards:
				if c["key"] == "p0_1":
					c["key"] = "p1_0"
			_layout_cards()
			_bet_stacks_round()
			_sfx("bj_chip", -6.0)
			return 0.3
		"double":
			_view["doubled_%d" % int(e["hand"])] = true
			_bet_stacks_round()
			_sfx("bj_chip", -6.0)
			return 0.15
		"turn":
			_view["active"] = int(e["hand"])
			_refresh()
			return 0.0
		"settle":
			_view["settled"] = true
			_settle_stacks()
			return 0.2
	return 0.0


## Straight to the end of what's playing (a tap on the table).
func skip() -> void:
	var guard := 0
	while not _queue.is_empty() and guard < 200:
		_apply(_queue.pop_front())
		guard += 1
	_wait = 0.0
	for c in _cards:
		c["t"] = 1.0
	for s in _stacks:
		s["t"] = 1.0
	_update_cards(0.0)
	_update_chips(0.0)
	_refresh()


## The round's end on the felt: the result line, the dealer's word, a break if needed.
func _round_over() -> void:
	_show_done = true
	var bj := false
	var dbj := Blackjack.is_blackjack(game.dealer) and game.dealer.size() == 2
	for h in game.hands:
		bj = bj or h["outcome"] == "blackjack"
	if bj:
		say(LINES["player_bj"])
	elif dbj:
		say(LINES["dealer_bj"])
	club.hud.set_gold(SaveData.gold)
	if club.main.sfx:
		club.main.sfx.play("point" if _round_net > 0 else "miss", -8.0)
	if Bets.needs_break(SaveData.bets) and _round_net < 0:
		say(LINES["break"])
	_fit_bets()
	_frame(false, 0.6)
	_refresh()


# --- Cards on the felt ----------------------------------------------------------------------

func _shoe_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.FORWARD, PI) * Basis(Vector3.RIGHT, -0.5), SHOE + Vector3(-0.08, 0.02, 0.04))


## Where every card shown should lie (recomputed after every card: hands re-centre).
func _slot(key: String) -> Vector3:
	if key.begins_with("d"):
		var i := int(key.substr(1))
		var n: int = _view["dealer"].size()
		return DEALER_CARDS + Vector3((i - (n - 1) * 0.5) * 0.105, i * 0.0012, 0.0)
	var parts := key.substr(1).split("_")
	var h := int(parts[0])
	var i := int(parts[1])
	var hands: Array = _view["hands"]
	var x := 0.0
	if hands.size() > 1:
		x = -0.2 if h == 0 else 0.2
	var n: int = (hands[h] as Array).size()
	return PLAYER_CARDS + Vector3(x + (i - (n - 1) * 0.5) * 0.05, i * 0.0012, -i * 0.035)


func _layout_cards() -> void:
	for c in _cards:
		var to := Transform3D(Basis(Vector3.UP, _jitter(String(c["key"]))), _slot(c["key"]))
		if float(c["t"]) >= 1.0:
			c["from"] = c["to"]
			c["t"] = 0.0
			c["dur"] = 0.18
			c["arc"] = 0.0
		c["to"] = to


func _jitter(key: String) -> float:
	return (float(hash(key) % 1000) / 1000.0 - 0.5) * 0.08


func _card_xf(c: Dictionary) -> Transform3D:
	var k := clampf(float(c["t"]), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var from: Transform3D = c["from"]
	var to: Transform3D = c["to"]
	var p := from.origin.lerp(to.origin, e) + Vector3.UP * float(c["arc"]) * sin(k * PI)
	var b := from.basis.slerp(to.basis, e)
	return Transform3D(b, p)


func _update_cards(delta: float) -> void:
	if _cards_mm == null:
		return
	var mm := _cards_mm.multimesh
	var n := mini(_cards.size(), MAX_CARDS)
	for i in n:
		var c: Dictionary = _cards[i]
		c["t"] = minf(float(c["t"]) + delta / maxf(float(c["dur"]), 0.001), 1.0)
		mm.set_instance_transform(i, _card_xf(c))
		mm.set_instance_custom_data(i, Color(float(c["card"]), float(BACK), 0.0, 0.0))
	mm.visible_instance_count = n


# --- Chips ----------------------------------------------------------------------------------

## The chips a stack of `amount` is built from, biggest first (at most 12 shown).
static func breakdown(amount: int) -> Array:
	var out := []
	var left := amount
	for v in [1000, 500, 250, 100, 50, 25, 10, 5]:
		while left >= v and out.size() < 12:
			out.append(v)
			left -= v
	return out


func _stack(key: String) -> Dictionary:
	for s in _stacks:
		if s["key"] == key and not s["gone"]:
			return s
	return {}


## A stack at a place: moved there if it's elsewhere, created (dropped in) if new.
func _put(key: String, amount: int, at: Vector3, from := Vector3.INF, dur := 0.22) -> void:
	var s := _stack(key)
	if amount <= 0:
		if not s.is_empty():
			_stacks.erase(s)
		return
	if s.is_empty():
		s = {"key": key, "amount": amount, "from": at + Vector3.UP * 0.12 if from == Vector3.INF else from, "to": at, "t": 0.0, "dur": dur, "gone": false}
		_stacks.append(s)
		return
	s["amount"] = amount
	if (s["to"] as Vector3).distance_to(at) > 0.001:
		s["from"] = _stack_pos(s)
		s["to"] = at
		s["t"] = 0.0
		s["dur"] = dur


## A stack slides away (to the dealer's rack or to the player) and is gone.
func _take(key: String, to: Vector3, delay := 0.0) -> void:
	var s := _stack(key)
	if s.is_empty():
		return
	s["from"] = _stack_pos(s)
	s["to"] = to
	s["t"] = -delay / 0.45
	s["dur"] = 0.45
	s["gone"] = true


func _stack_pos(s: Dictionary) -> Vector3:
	var k := clampf(float(s["t"]), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	return (s["from"] as Vector3).lerp(s["to"], e)


## While betting: the three spots' stacks.
func _bet_stacks() -> void:
	_stacks = _stacks.filter(func(s): return not String(s["key"]).begins_with("h") and not String(s["key"]).begins_with("pay"))
	for id in SPOTS:
		_put(id, int(bets[id]), SPOTS[id])


## During a round: a stack per hand (and its double beside it), the side bets.
func _bet_stacks_round() -> void:
	var n: int = maxi(game.hands.size(), 1)
	var shown: int = maxi((_view["hands"] as Array).size(), 1)
	for id in ["pp", "t3"]:
		if not _view.get("sides", false):
			_put(id, int(bets[id]) if game.phase != Blackjack.Phase.BETTING else 0, SPOTS[id])
	_put("main", 0, SPOTS["main"])
	for h in mini(n, shown):
		var x := 0.0 if shown == 1 else (-0.2 if h == 0 else 0.2)
		var base := int(game.hands[h]["bet"]) / (2 if game.hands[h]["doubled"] else 1) if h < game.hands.size() else 0
		var at := SPOTS["main"] + Vector3(x, 0, 0)
		_put("h%d" % h, base, at, SPOTS["main"] if h == 0 else Vector3.INF)
		if _view.get("doubled_%d" % h, false):
			_put("h%d_x2" % h, base, at + Vector3(0.075, 0, 0.02))


## The round settles on the felt: lost stacks go to the dealer, wins are paid beside the
## bet, then everything that's the player's comes back to him.
func _settle_stacks() -> void:
	var to_player := club.cam.global_position if is_instance_valid(club) else to_global(Vector3(0, 1.5, 2.0))
	to_player = to_local(to_player) + Vector3(0, -0.6, 0)
	for h in game.hands.size():
		var hand: Dictionary = game.hands[h]
		var keys := ["h%d" % h, "h%d_x2" % h]
		var at: Vector3 = _stack(keys[0]).get("to", SPOTS["main"])
		match String(hand["outcome"]):
			"lose", "bust":
				for k in keys:
					_take(k, TRAY, 0.15)
			"win", "blackjack":
				var won := int(hand["paid"]) - int(hand["bet"])
				_put("pay%d" % h, won, at + Vector3(-0.08, 0, 0.03), TRAY, 0.4)
				for k in keys + ["pay%d" % h]:
					_take(k, to_player, 0.9)
			_:
				for k in keys:
					_take(k, to_player, 0.6)


## The side bets are decided by the first three cards: paid or taken once they're down.
func _settle_sides() -> void:
	if _view.get("sides", false):
		return
	_view["sides"] = true
	var to_player := to_local(club.cam.global_position) + Vector3(0, -0.6, 0) if is_instance_valid(club) else Vector3(0, 1, 2)
	for id in ["pp", "t3"]:
		var paid := game.pp_paid if id == "pp" else game.t3_paid
		var bet := game.pp_bet if id == "pp" else game.t3_bet
		if bet <= 0:
			continue
		if paid > 0:
			_put("pay_" + id, paid - bet, SPOTS[id] + Vector3(0.0, 0, -0.08), TRAY, 0.4)
			_take(id, to_player, 0.8)
			_take("pay_" + id, to_player, 0.8)
		else:
			_take(id, TRAY, 0.1)


func _update_chips(delta: float) -> void:
	if _chips_mm == null:
		return
	if _view.get("dealt_sides", false) == false and (_view["dealer"] as Array).size() >= 1 and (_view["hands"] as Array).size() >= 1 and (_view["hands"][0] as Array).size() >= 2:
		_view["dealt_sides"] = true
		_settle_sides()
	var mm := _chips_mm.multimesh
	var i := 0
	for xf in _tray:
		if i >= MAX_CHIPS:
			break
		mm.set_instance_transform(i, xf[0])
		mm.set_instance_custom_data(i, Color(float(CHIP_CELL[xf[1]]), 0, 0, 0))
		i += 1
	var done: Array = []
	for s in _stacks:
		s["t"] = minf(float(s["t"]) + delta / maxf(float(s["dur"]), 0.001), 1.0)
		if s["gone"] and float(s["t"]) >= 1.0:
			done.append(s)
			continue
		var p := _stack_pos(s)
		var k := clampf(float(s["t"]), 0.0, 1.0)
		p.y += sin(k * PI) * (0.05 if s["gone"] else 0.0)
		var chips := breakdown(int(s["amount"]))
		for j in chips.size():
			if i >= MAX_CHIPS:
				break
			var b := Basis(Vector3.UP, float(j) * 0.7 + float(hash(s["key"]) % 7))
			mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, CHIP_H * 0.5 + j * CHIP_H * 1.02, 0)))
			mm.set_instance_custom_data(i, Color(float(CHIP_CELL[chips[j]]), 0, 0, 0))
			i += 1
	for s in done:
		_stacks.erase(s)
	mm.visible_instance_count = i


# --- The dealer ---------------------------------------------------------------------------

func _build_dealer() -> void:
	_dealer = Athlete.new()
	_dealer.name = "dealer"
	add_child(_dealer)
	_dealer.setup(1.0, DEALER_LOOK, Rect2(-0.05, DEALER_Z - 0.05, 0.1, 0.1))
	_dealer.position = Vector3(0, 0, DEALER_Z)
	_dealer.max_speed = 0.0
	_dress_dealer.call_deferred()


## The waistcoat over the shirt, a bow tie, no racket.
func _dress_dealer() -> void:
	var racket = _dealer.get("_racket")
	if racket is Node3D:
		(racket as Node3D).visible = false
	var bones = _dealer.get("_bones")
	if not (bones is Dictionary) or not bones.has("chest"):
		return
	# Draw-call budget: below the felt nobody sees him (the legs go), and only the torso and
	# the head throw a shadow (every mesh costs a main, an outline and a shadow draw).
	for part in ["thigh0", "shin0", "shoe0", "thigh1", "shin1", "shoe1"]:
		if bones.has(part):
			(bones[part] as MeshInstance3D).visible = false
	for part in bones:
		if not ["chest", "waist", "neck"].has(part):
			(bones[part] as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for k in (bones[part] as Node).get_children():
				if k is MeshInstance3D:
					(k as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var chest := bones["chest"] as MeshInstance3D
	var vest := MeshInstance3D.new()
	vest.name = "vest"
	vest.mesh = chest.mesh
	var m := (chest.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = false
	m.albedo_color = Color(0.12, 0.13, 0.18)
	vest.material_override = m
	vest.scale = Vector3(1.07, 0.97, 1.07)
	vest.position = Vector3(0, -0.004, 0)
	chest.add_child(vest)
	# The shirt's V and the bow tie, one mesh in front of the waistcoat.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -0.212
	var white := Color(0.97, 0.97, 0.96)
	_tri(st, Vector3(-0.07, 0.125, z), Vector3(0.07, 0.125, z), Vector3(0, 0.0, z - 0.012), white)
	var red := Looks.KIT[13]
	var c := Vector3(0, 0.105, z - 0.016)
	_tri(st, c, Vector3(-0.055, 0.13, z - 0.012), Vector3(-0.055, 0.08, z - 0.012), red)
	_tri(st, c, Vector3(0.055, 0.08, z - 0.012), Vector3(0.055, 0.13, z - 0.012), red)
	for b in [Vector3(0, 0.04, z - 0.03), Vector3(0, -0.02, z - 0.025)]:
		_tri(st, b + Vector3(-0.008, 0.008, 0), b + Vector3(0.008, 0.008, 0), b + Vector3(0, -0.008, 0), UiTheme.GOLD)
	st.generate_normals()
	var front := MeshInstance3D.new()
	front.name = "shirt_front"
	front.mesh = st.commit()
	front.material_override = ClubMaterial.tinted()
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chest.add_child(front)


func _look_at() -> Vector3:
	for i in range(_cards.size() - 1, -1, -1):
		if float(_cards[i]["t"]) < 1.0:
			return to_global(_card_xf(_cards[i]).origin)
	if _open and is_instance_valid(club):
		return club.cam.global_position + Vector3(0, -0.8, 0)
	return to_global(Vector3(0, 1.2, 1.2))


## The dealer says a line (a bubble over his head) with the club's murmur.
func say(text: String) -> void:
	_ui.say(text)
	if is_instance_valid(club) and club.main.sfx:
		for i in clampi(text.length() / 7, 2, 6):
			get_tree().create_timer(i * 0.11 + randf_range(0.0, 0.03)).timeout.connect(func() -> void:
				club.main.sfx.play("club_murmur_%d" % (randi() % ClubCoach.SYLLABLES), -11.0, randf_range(0.8, 0.95)))


func dealer_head() -> Vector3:
	return _dealer.global_position + Vector3(0, 2.35, 0) if _dealer else to_global(Vector3(0, 2.3, DEALER_Z))


# --- Sound ----------------------------------------------------------------------------------

func _load_sounds() -> void:
	if not is_instance_valid(club) or club.main.sfx == null:
		return
	for n in ["bj_card", "bj_chip", "bj_shuffle"]:
		var path := "res://assets/club/%s.wav" % n
		if ResourceLoader.exists(path):
			club.main.sfx._streams[n] = load(path)


func _sfx(n: String, db := 0.0, pitch := 1.0) -> void:
	if is_instance_valid(club) and club.main.sfx and club.main.sfx._streams.has(n):
		club.main.sfx.play(n, db, pitch)


# --- What the panel shows -------------------------------------------------------------------

func _refresh() -> void:
	if _ui == null or not _open:
		return
	_ui.refresh(self)


## Totals over the cards, as the view shows them (what has landed).
func view_total(cards: Array) -> String:
	if cards.is_empty():
		return ""
	var t := Blackjack.total(cards)
	if Blackjack.is_blackjack(cards) and cards.size() == 2 and (_view["hands"] as Array).size() <= 1:
		return "BJ"
	if Blackjack.is_soft(cards) and t < 21:
		return "%d / %d" % [t - 10, t]
	return str(t)


func view() -> Dictionary:
	return _view


func round_net() -> int:
	return _round_net


func round_note() -> String:
	return _round_note


func showing_result() -> bool:
	return _show_done and game.phase == Blackjack.Phase.DONE and not _cards.is_empty()


func last_bets() -> Dictionary:
	return _last_bets


## A spot's circle on the screen (taps on the felt bet there).
func spot_on_screen(id: String) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var p := to_global(SPOTS[id])
	return cam.unproject_position(p) if cam and not cam.is_position_behind(p) else Vector2(-1000, -1000)


func screen_of(local: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var p := to_global(local)
	return cam.unproject_position(p) if cam and not cam.is_position_behind(p) else Vector2(-1000, -1000)


func slot_of(key: String) -> Vector3:
	return _slot(key)


# --- The table ------------------------------------------------------------------------------

func _build_table() -> void:
	# The felt: a half-moon, its print (text, circles) from the felt texture.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	var c0 := Vector3(0, TOP, EDGE_Z)
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		var p0 := c0 + Vector3(-cos(a0) * RADIUS, 0, sin(a0) * RADIUS)
		var p1 := c0 + Vector3(-cos(a1) * RADIUS, 0, sin(a1) * RADIUS)
		for p in [c0, p1, p0]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2((p.x + FELT_W * 0.5) / FELT_W, (p.z - EDGE_Z) / FELT_D))
			st.add_vertex(p)
	var felt := MeshInstance3D.new()
	felt.name = "felt"
	felt.mesh = st.commit()
	_felt_mat = ClubMaterial.get_mat(FELT, false).duplicate()
	_felt_mat.roughness = 0.95
	_felt_mat.rim_enabled = false
	_felt_mat.texture_repeat = false
	felt.material_override = _felt_mat
	felt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(felt)
	# The wood: the padded rail round the arc, the dealer's edge, the base, the shoe and
	# the rack, the players' stools - one mesh, colours in the vertices.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pad := Color(0.2, 0.12, 0.09)
	var wood := ClubMaterial.PALETTE[ClubMaterial.WOOD_DARK]
	var rail_w := 0.11
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		var d0 := Vector3(-cos(a0), 0, sin(a0))
		var d1 := Vector3(-cos(a1), 0, sin(a1))
		var r0 := RADIUS
		var r1 := RADIUS + rail_w
		var y0 := TOP
		var y1 := TOP + 0.05
		# rail top (rounded by two steps), outer face, the apron under it
		_quad(st, c0 + d0 * r0 + Vector3.UP * (y0 - TOP), c0 + d1 * r0 + Vector3.UP * (y0 - TOP), c0 + d1 * (r0 + 0.03) + Vector3.UP * (y1 - TOP), c0 + d0 * (r0 + 0.03) + Vector3.UP * (y1 - TOP), pad.lightened(0.08), Vector3.UP)
		_quad(st, c0 + d0 * (r0 + 0.03) + Vector3.UP * (y1 - TOP), c0 + d1 * (r0 + 0.03) + Vector3.UP * (y1 - TOP), c0 + d1 * r1 + Vector3.UP * (y1 - TOP - 0.01), c0 + d0 * r1 + Vector3.UP * (y1 - TOP - 0.01), pad.lightened(0.15), Vector3.UP)
		_quad(st, c0 + d0 * r1 + Vector3.UP * (y1 - TOP - 0.01), c0 + d1 * r1 + Vector3.UP * (y1 - TOP - 0.01), c0 + d1 * r1 + Vector3.DOWN * 0.1, c0 + d0 * r1 + Vector3.DOWN * 0.1, pad, d0)
		_quad(st, c0 + d0 * r1 + Vector3.DOWN * 0.1, c0 + d1 * r1 + Vector3.DOWN * 0.1, c0 + d1 * (r1 - 0.06) + Vector3.DOWN * 0.16, c0 + d0 * (r1 - 0.06) + Vector3.DOWN * 0.16, wood, d0)
	# The dealer's edge: a wooden ledge along the straight side.
	var ex := RADIUS + rail_w
	_box(st, Vector3(0, TOP - 0.04, EDGE_Z - 0.04), Vector3(ex * 2.0, 0.1, 0.08), wood)
	# The base: a wide pillar and a foot.
	_box(st, Vector3(0, TOP * 0.5, EDGE_Z + 0.45), Vector3(0.7, TOP - 0.12, 0.4), wood.darkened(0.2))
	_box(st, Vector3(0, 0.03, EDGE_Z + 0.45), Vector3(1.1, 0.06, 0.7), wood.darkened(0.3))
	# The shoe (dark red box, open towards the dealer's hand) and the discard holder.
	_box(st, SHOE, Vector3(0.2, 0.22, 0.3), Color(0.45, 0.08, 0.1))
	_box(st, SHOE + Vector3(0, 0.0, 0.15), Vector3(0.18, 0.16, 0.01), Color(0.3, 0.05, 0.07))
	_box(st, Vector3(-0.68, TOP + 0.07, -0.36), Vector3(0.18, 0.14, 0.26), Color(0.12, 0.12, 0.14))
	# The dealer's chip rack: a tray with ten slots.
	_box(st, TRAY + Vector3(0, -0.01, 0), Vector3(0.44, 0.03, 0.14), Color(0.16, 0.16, 0.18))
	# Stools on the players' side.
	for k in [-1.0, 0.0, 1.0]:
		var a: float = PI * 0.5 + k * 0.55
		var p := c0 + Vector3(-cos(a), 0, sin(a)) * (RADIUS + 0.45)
		p.y = 0.0
		_box(st, p + Vector3(0, 0.33, 0), Vector3(0.06, 0.66, 0.06), ClubMaterial.PALETTE[ClubMaterial.METAL_DARK])
		_box(st, p + Vector3(0, 0.69, 0), Vector3(0.42, 0.07, 0.42), pad.lightened(0.1))
	st.generate_normals()
	var wood_mi := MeshInstance3D.new()
	wood_mi.name = "wood"
	wood_mi.mesh = st.commit()
	wood_mi.material_override = ClubMaterial.tinted()
	add_child(wood_mi)
	# The rack's chips lie in it from the start.
	var vals := [100, 100, 50, 50, 25, 25, 25, 5, 5, 5]
	for i in vals.size():
		var x := -0.19 + i * 0.042
		for j in 4:
			var b := Basis(Vector3.FORWARD, PI * 0.5)
			_tray.append([Transform3D(b, TRAY + Vector3(x + j * 0.003, CHIP_R * 0.8, -0.02 + j * 0.012)), vals[i]])


func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var v := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var faces := [[0, 1, 2, 3, Vector3.FORWARD], [5, 4, 7, 6, Vector3.BACK], [4, 0, 3, 7, Vector3.LEFT],
		[1, 5, 6, 2, Vector3.RIGHT], [3, 2, 6, 7, Vector3.UP], [4, 5, 1, 0, Vector3.DOWN]]
	for f in faces:
		_quad(st, c + v[f[0]], c + v[f[1]], c + v[f[2]], c + v[f[3]], col, f[4])


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, facing := Vector3.UP) -> void:
	_tri(st, a, b, c, col, facing)
	_tri(st, a, c, d, col, facing)


## A triangle facing `facing` (front faces are clockwise seen from the front in Godot).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, facing := Vector3.ZERO) -> void:
	if facing == Vector3.ZERO:
		facing = (b - a).cross(c - a) * -1.0
	st.set_color(col)
	if (b - a).cross(c - a).dot(facing) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


# --- Cards and chips: two MultiMeshes over one atlas ------------------------------------------

const SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_toon;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float cols = 8.0;
uniform float rows = 8.0;
uniform vec4 ball : source_color = vec4(0.86, 0.95, 0.3, 1.0);
varying float v_cell;
varying float v_back;
void vertex() {
	v_cell = INSTANCE_CUSTOM.r;
	v_back = INSTANCE_CUSTOM.g;
}
vec3 chip_color(float cell) {
	if (cell < 53.5) return vec3(0.95, 0.95, 0.92);
	if (cell < 54.5) return vec3(0.85, 0.2, 0.2);
	if (cell < 55.5) return vec3(0.15, 0.6, 0.32);
	if (cell < 56.5) return vec3(0.2, 0.42, 0.92);
	if (cell < 57.5) return vec3(0.13, 0.13, 0.16);
	if (cell < 58.5) return vec3(0.55, 0.25, 0.75);
	if (cell < 59.5) return vec3(0.95, 0.55, 0.15);
	return vec3(0.95, 0.8, 0.2);
}
void fragment() {
	float kind = UV2.x;
	if (kind > 3.5) {
		// a chip's edge: the ball's felt with stripes of the chip's colour
		float s = fract(UV.x * 8.0);
		ALBEDO = (s < 0.3) ? chip_color(floor(v_cell + 0.5)) : ball.rgb * 0.9;
	} else if (kind > 2.5) {
		ALBEDO = vec3(0.95, 0.95, 0.93);       // a card's edge
	} else {
		float cell = floor((kind > 0.5 ? v_back : v_cell) + 0.5);
		vec2 c = vec2(mod(cell, cols), floor(cell / cols));
		vec2 uv = (c + clamp(UV, vec2(0.004), vec2(0.996))) / vec2(cols, rows);
		ALBEDO = texture(atlas, uv).rgb;
	}
	ROUGHNESS = 0.7;
	SPECULAR = 0.2;
}
"""


func _build_multimeshes() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	_atlas_mat = ShaderMaterial.new()
	_atlas_mat.shader = sh
	_atlas_mat.set_shader_parameter("ball", BALL)
	_atlas_mat.set_shader_parameter("atlas", _white())
	_cards_mm = _mm(_card_mesh(), MAX_CARDS, "cards")
	_chips_mm = _mm(_chip_mesh(), MAX_CHIPS, "chips")


func _white() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.97, 0.97, 0.95))
	return ImageTexture.create_from_image(img)


func _mm(mesh: Mesh, n: int, nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = _atlas_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 6))
	add_child(mi)
	return mi


## A card lying flat: face on +y (UV2.x 0), back on -y (1), its edge (3). The card's top
## is away from the player (-z).
func _card_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := CARD.x * 0.5
	var d := CARD.y * 0.5
	var t := CARD_T * 0.5
	var top := [Vector3(-w, t, -d), Vector3(w, t, -d), Vector3(w, t, d), Vector3(-w, t, d)]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	_face(st, top, uv, Vector3.UP, 0.0)
	var bot := [Vector3(w, -t, -d), Vector3(-w, -t, -d), Vector3(-w, -t, d), Vector3(w, -t, d)]
	_face(st, bot, [Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)], Vector3.DOWN, 1.0)
	for e in [[0, 1, Vector3.FORWARD], [1, 2, Vector3.RIGHT], [2, 3, Vector3.BACK], [3, 0, Vector3.LEFT]]:
		var a: Vector3 = top[e[0]]
		var b: Vector3 = top[e[1]]
		_face(st, [a, b, b - Vector3(0, CARD_T, 0), a - Vector3(0, CARD_T, 0)], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], e[2], 3.0)
	return st.commit()


## A chip: a flat drum, its top from the atlas (UV2.x 2 -> the cell in INSTANCE_CUSTOM.r),
## its edge striped (4).
func _chip_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 16
	var h := CHIP_H * 0.5
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0), 0, sin(a0)) * CHIP_R
		var p1 := Vector3(cos(a1), 0, sin(a1)) * CHIP_R
		var u0 := Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)
		var u1 := Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)
		_face(st, [Vector3(0, h, 0), p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0)], [Vector2(0.5, 0.5), u1, u0], Vector3.UP, 0.0, true)
		_face(st, [Vector3(0, -h, 0), p0 - Vector3(0, h, 0), p1 - Vector3(0, h, 0)], [Vector2(0.5, 0.5), u0, u1], Vector3.DOWN, 0.0, true)
		_face(st, [p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), p1 - Vector3(0, h, 0), p0 - Vector3(0, h, 0)],
			[Vector2(float(i) / seg, 0), Vector2(float(i + 1) / seg, 0), Vector2(float(i + 1) / seg, 1), Vector2(float(i) / seg, 1)], (p0 + p1).normalized(), 4.0)
	return st.commit()


## A polygon (3 or 4 corners) with its UVs, facing `n`, of kind `kind` (UV2.x).
## `chip`: the top of a chip, whose square in the atlas is the cell's upper part.
func _face(st: SurfaceTool, pts: Array, uvs: Array, n: Vector3, kind: float, chip := false) -> void:
	var idx := [[0, 1, 2]] if pts.size() == 3 else [[0, 1, 2], [0, 2, 3]]
	for tri in idx:
		var a: Vector3 = pts[tri[0]]
		var b: Vector3 = pts[tri[1]]
		var c: Vector3 = pts[tri[2]]
		var order := [tri[0], tri[1], tri[2]]
		if (b - a).cross(c - a).dot(n) > 0.0:
			order = [tri[0], tri[2], tri[1]]
		for k in order:
			var uv: Vector2 = uvs[k]
			if chip:
				uv = Vector2(uv.x, uv.y * float(CELL.x) / float(CELL.y))
			st.set_normal(n)
			st.set_uv(uv)
			st.set_uv2(Vector2(kind, 0))
			st.add_vertex(pts[k])


# --- The textures: drawn once in a SubViewport, kept as ImageTextures with mipmaps ----------

func _render_textures() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var atlas_vp := _viewport(Vector2i(ATLAS_COLS * CELL.x, 8 * CELL.y), CardAtlas.new())
	var felt_vp := _viewport(Vector2i(1024, 640), FeltPrint.new())
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var a := _grab(atlas_vp)
	if a:
		_atlas_mat.set_shader_parameter("atlas", a)
	var f := _grab(felt_vp)
	if f:
		_felt_mat.albedo_texture = f
		_felt_mat.albedo_color = Color.WHITE
	atlas_vp.queue_free()
	felt_vp.queue_free()
	_textures_ready = true


func _viewport(sz: Vector2i, c: Control) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = sz
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	c.size = sz
	vp.add_child(c)
	add_child(vp)
	return vp


func _grab(vp: SubViewport) -> Texture2D:
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The atlas: 52 faces, the back, the four chips' tops (cells of 128 x 180).
class CardAtlas extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.97, 0.97, 0.95))
		for c in 52:
			_card(_cell(c), c)
		_back(_cell(ClubBlackjack.BACK))
		for v in ClubBlackjack.CHIP_CELL:
			_chip(_cell(ClubBlackjack.CHIP_CELL[v]), v)

	func _cell(i: int) -> Rect2:
		var cs := Vector2(ClubBlackjack.CELL)
		return Rect2(Vector2(i % ClubBlackjack.ATLAS_COLS, i / ClubBlackjack.ATLAS_COLS) * cs, cs)

	func _card(r: Rect2, c: int) -> void:
		var ink := Color(0.85, 0.12, 0.15) if Blackjack.is_red(c) else Color(0.1, 0.1, 0.13)
		draw_rect(r, Color(0.98, 0.98, 0.96))
		draw_rect(r.grow(-3), Color(0.82, 0.82, 0.8), false, 3.0)
		var rank: String = Blackjack.RANKS[Blackjack.rank(c)]
		var f := UiTheme.display()
		var fs := 58 if rank != "10" else 50
		# Big rank and suit in the top left (what the phone reads), small ones mirrored.
		draw_string(f, r.position + Vector2(10, 58), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		_suit(r.position + Vector2(30, 88), 22.0, Blackjack.suit(c), ink)
		_suit(r.get_center() + Vector2(14, 34), 40.0, Blackjack.suit(c), ink)
		if Blackjack.rank(c) >= 10:
			draw_rect(Rect2(r.position + Vector2(62, 22), Vector2(54, 64)), Color(ink, 0.12))
			draw_string(f, r.position + Vector2(68, 76), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, ink)

	func _back(r: Rect2) -> void:
		draw_rect(r, Color(0.98, 0.98, 0.96))
		var inner := r.grow(-8)
		draw_rect(inner, Color(0.12, 0.2, 0.42))
		for k in range(-12, 14):
			var x := inner.position.x + k * 16.0
			draw_line(Vector2(x, inner.position.y), Vector2(x + inner.size.y, inner.end.y), Color(UiTheme.GOLD, 0.22), 3.0)
			draw_line(Vector2(x + inner.size.y, inner.position.y), Vector2(x, inner.end.y), Color(UiTheme.GOLD, 0.22), 3.0)
		draw_rect(Rect2(Vector2(inner.position.x, inner.position.y), Vector2(14, inner.size.y)), Color(0.98, 0.98, 0.96))
		draw_rect(Rect2(Vector2(inner.end.x - 14, inner.position.y), Vector2(14, inner.size.y)), Color(0.98, 0.98, 0.96))
		draw_rect(inner.grow(-14), Color(UiTheme.GOLD, 0.8), false, 3.0)
		var c := r.get_center()
		draw_circle(c, 26.0, ClubBlackjack.BALL)
		draw_arc(c + Vector2(-30, 0), 22.0, -0.9, 0.9, 12, Color.WHITE, 4.0)
		draw_arc(c + Vector2(30, 0), 22.0, PI - 0.9, PI + 0.9, 12, Color.WHITE, 4.0)

	func _chip(r: Rect2, v: int) -> void:
		# The chip's top is the cell's upper square (CELL.x x CELL.x).
		var c := r.position + Vector2(r.size.x, r.size.x) * 0.5
		var rad := r.size.x * 0.5
		var col: Color = ClubBlackjack.CHIP_COLORS[v]
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.x)), col)
		draw_circle(c, rad * 0.97, col)
		for k in 8:
			var a := TAU * k / 8.0
			draw_arc(c, rad * 0.86, a - 0.13, a + 0.13, 6, ClubBlackjack.BALL if v != 5 else Color(0.85, 0.9, 0.3), rad * 0.2)
		draw_circle(c, rad * 0.7, ClubBlackjack.BALL)
		# The ball's seam, two arcs.
		draw_arc(c + Vector2(-rad * 0.95, 0), rad * 0.6, -0.75, 0.75, 14, Color(1, 1, 1, 0.95), 4.0)
		draw_arc(c + Vector2(rad * 0.95, 0), rad * 0.6, PI - 0.75, PI + 0.75, 14, Color(1, 1, 1, 0.95), 4.0)
		var f := UiTheme.display()
		var s := str(v)
		var fs := 40 if v < 100 else (34 if v < 1000 else 28)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.1, 0.12))

	## Suits as shapes (no font has them all): spade, heart, diamond, club.
	func _suit(c: Vector2, s: float, suit: int, col: Color) -> void:
		match suit:
			1:
				draw_colored_polygon(ClubBlackjack.heart(c, s), col)
			2:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.72, 0), c + Vector2(0, s), c + Vector2(-s * 0.72, 0)]), col)
			0:
				var h := ClubBlackjack.heart(c + Vector2(0, -s * 0.12), s * 0.95)
				var flipped := PackedVector2Array()
				for p in h:
					flipped.append(Vector2(p.x, 2.0 * c.y - p.y - s * 0.24))
				draw_colored_polygon(flipped, col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.2), c + Vector2(s * 0.3, s), c + Vector2(-s * 0.3, s)]), col)
			3:
				var r := s * 0.36
				draw_circle(c + Vector2(0, -s * 0.45), r, col)
				draw_circle(c + Vector2(-s * 0.42, s * 0.12), r, col)
				draw_circle(c + Vector2(s * 0.42, s * 0.12), r, col)
				draw_circle(c + Vector2(0, 0), r * 0.6, col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(s * 0.28, s), c + Vector2(-s * 0.28, s)]), col)


## A heart of size s round c (pointing down).
static func heart(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var t := TAU * i / 28.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(c + Vector2(x, -y - 2.0) * (s / 17.0))
	return pts


## What is printed on the felt (1024 x 640 over x -1..1, z EDGE_Z..EDGE_Z+1.25 of the table):
## the two arcs of rules, the three betting circles and the pay tables of the side bets.
class FeltPrint extends Control:
	func _draw() -> void:
		var felt := ClubBlackjack.FELT
		draw_rect(Rect2(Vector2.ZERO, size), felt)
		# A soft lighter middle, like a lamp over the table.
		for k in 6:
			draw_circle(_px(Vector3(0, 0, 0.15)), 420.0 - k * 60.0, Color(1, 1, 1, 0.012))
		var gold := Color(UiTheme.GOLD, 0.95)
		var white := Color(1, 1, 1, 0.9)
		_arc_text("БЛЭКДЖЕК ПЛАТИТ 3 К 2", Vector3(0, 0, ClubBlackjack.EDGE_Z), 0.5, 30, gold)
		_arc_text("ДИЛЕР СТОИТ НА МЯГКИХ 17", Vector3(0, 0, ClubBlackjack.EDGE_Z), 0.585, 22, white)
		# The betting circles.
		for id in ClubBlackjack.SPOTS:
			var p := _px(ClubBlackjack.SPOTS[id])
			var r := 46.0 if id == "main" else 34.0
			draw_arc(p, r, 0, TAU, 40, gold if id == "main" else white, 3.0, true)
			var f := UiTheme.text_bold()
			var t: String = ClubBlackjack.SPOT_NAMES[id].to_upper()
			var fs := 15
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, p + Vector2(-w * 0.5, r + 20), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
		# The side bets' pay tables, out of the hands' way, by the dealer (the phone sees only x -0.55..0.55).
		_table(Vector3(-0.36, 0, 0.1), "ПАРЫ", [["одна масть", "25:1"], ["один цвет", "12:1"], ["разные", "6:1"]])
		_table(Vector3(0.36, 0, 0.1), "21+3", [["тройка масти", "100:1"], ["стрит-флеш", "40:1"], ["тройка", "25:1"], ["стрит", "10:1"], ["флеш", "5:1"]])

	func _px(p: Vector3) -> Vector2:
		return Vector2((p.x + ClubBlackjack.FELT_W * 0.5) / ClubBlackjack.FELT_W * size.x, (p.z - ClubBlackjack.EDGE_Z) / ClubBlackjack.FELT_D * size.y)

	func _arc_text(text: String, centre: Vector3, r: float, fs: int, col: Color) -> void:
		var f := UiTheme.display()
		var c := _px(centre)
		var rp := r / ClubBlackjack.FELT_W * size.x
		var total := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var a := PI * 0.5 + total * 0.5 / rp       # from the left, round to the right
		for ch in text:
			var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var mid := a - w * 0.5 / rp
			var p := c + Vector2(cos(mid), sin(mid)) * rp
			draw_set_transform(p, mid - PI * 0.5, Vector2.ONE)
			draw_string(f, Vector2(-w * 0.5, fs * 0.35), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			a -= w / rp
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _table(at: Vector3, title: String, rows: Array) -> void:
		var p := _px(at)
		var f := UiTheme.text_bold()
		var w := 132.0
		var x := p.x - w * 0.5
		var y := p.y - (rows.size() * 17.0 + 22.0) * 0.5
		draw_string(UiTheme.display(), Vector2(x, y + 14), title, HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(UiTheme.GOLD, 0.95))
		for i in rows.size():
			var yy := y + 32 + i * 17.0
			draw_string(f, Vector2(x, yy), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, w, 13, Color(1, 1, 1, 0.85))
			draw_string(f, Vector2(x, yy), rows[i][1], HORIZONTAL_ALIGNMENT_RIGHT, w, 13, Color(1, 1, 1, 0.95))


# --- The buttons and words on the screen ------------------------------------------------------

## The table's own layer: «← Назад» and the rules top left (the club's gold chip and gear
## stay top right), the dealer's bubble, totals over the cards, and the panel at the
## bottom - bets and chips, then «Ещё / Хватит / Удвоить / Разделить».
class BlackjackHud extends CanvasLayer:
	var table: ClubBlackjack
	var root: Control
	var catcher: Control
	var back: Button
	var rules_btn: Button
	var rules: PanelContainer
	var bubble: PanelContainer
	var bubble_label: Label
	var bubble_t := 0.0
	var pills: Array[PanelContainer] = []
	var panel: VBoxContainer
	var result: Label
	var sub: Label
	var card: PanelContainer
	var note: Label
	var spots := {}
	var chips: Array = []
	var chip_row: HBoxContainer
	var clear_btn: Button
	var deal_btn: Button
	var actions: HBoxContainer
	var act := {}
	var safe := Vector2.ZERO

	func _ready() -> void:
		layer = 9
		root = Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.theme = UiTheme.theme()
		add_child(root)
		catcher = Control.new()
		catcher.name = "catcher"
		catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
		catcher.mouse_filter = Control.MOUSE_FILTER_STOP
		catcher.gui_input.connect(_on_catcher)
		root.add_child(catcher)
		for i in 3:
			var p := _pill()
			pills.append(p)
		_build_bubble()
		_build_panel()
		back = Button.new()
		back.text = "←  Назад"
		back.custom_minimum_size = Vector2(196, 76)
		back.add_theme_font_size_override("font_size", UiTheme.T_BODY)
		back.focus_mode = Control.FOCUS_NONE
		back.pressed.connect(func() -> void: table.close())
		root.add_child(back)
		rules_btn = Button.new()
		rules_btn.text = "?"
		rules_btn.custom_minimum_size = Vector2(76, 76)
		rules_btn.add_theme_font_override("font", UiTheme.display())
		rules_btn.add_theme_font_size_override("font_size", 34)
		rules_btn.add_theme_color_override("font_color", UiTheme.GOLD)
		rules_btn.focus_mode = Control.FOCUS_NONE
		rules_btn.pressed.connect(func() -> void: rules.visible = not rules.visible)
		root.add_child(rules_btn)
		_build_rules()
		_layout()
		visible = false

	func set_safe(s: Vector2) -> void:
		var v := Vector2(maxf(s.x, 0.0), maxf(s.y, 0.0))
		if v != safe:
			safe = v
			_layout()

	func _layout() -> void:
		back.position = Vector2(UiTheme.GUTTER, 18.0 + safe.x)
		rules_btn.position = Vector2(UiTheme.GUTTER + 196 + 14, 18.0 + safe.x)
		panel.offset_left = UiTheme.GUTTER
		panel.offset_right = -UiTheme.GUTTER
		panel.offset_bottom = -26.0 - safe.y

	func show_table() -> void:
		visible = true
		rules.visible = false
		fill_chips()

	## The row of chips the bar has at its level (they grow with the bar), before «Сброс».
	func fill_chips() -> void:
		var want: Array = table.table_chips()
		var have: Array = []
		for c in chips:
			have.append((c as ChipButton).value)
		if want == have:
			return
		for c in chips:
			chip_row.remove_child(c)
			c.queue_free()
		chips.clear()
		for value in want:
			var c := ChipButton.new()
			c.value = value
			c.custom_minimum_size = Vector2(0, 84)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.focus_mode = Control.FOCUS_NONE
			var cv: int = value
			c.pressed.connect(func() -> void:
				table.select_chip(cv)
				table.add_chip(cv))
			chip_row.add_child(c)
			chip_row.move_child(c, chips.size())
			chips.append(c)

	func hide_table() -> void:
		visible = false
		bubble.visible = false

	# --- building --------------------------------------------------------------------

	func _pill() -> PanelContainer:
		var p := PanelContainer.new()
		var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.9), Color(UiTheme.GOLD, 0.45), 2, 22, 8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.add_theme_font_override("font", UiTheme.display())
		l.add_theme_font_size_override("font_size", 28)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		p.visible = false
		root.add_child(p)
		return p

	func _build_bubble() -> void:
		bubble = PanelContainer.new()
		bubble.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.96), Color(UiTheme.GOLD, 0.5), 2, 26, 16))
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.visible = false
		bubble_label = Label.new()
		bubble_label.add_theme_font_override("font", UiTheme.text_bold())
		bubble_label.add_theme_font_size_override("font_size", UiTheme.T_BODY)
		bubble.add_child(bubble_label)
		root.add_child(bubble)

	func _build_rules() -> void:
		rules = PanelContainer.new()
		rules.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.97), Color(UiTheme.GOLD, 0.5), 2, UiTheme.RADIUS, 26))
		rules.set_anchors_preset(Control.PRESET_CENTER)
		rules.grow_horizontal = Control.GROW_DIRECTION_BOTH
		rules.grow_vertical = Control.GROW_DIRECTION_BOTH
		rules.custom_minimum_size = Vector2(620, 0)
		rules.mouse_filter = Control.MOUSE_FILTER_STOP
		rules.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
				rules.visible = false)
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", UiTheme.T_SMALL)
		l.text = "\n".join([
			"Блэкджек: 6 колод, перетасовка, когда остаётся меньше полутора.",
			"Блэкджек платит 3 к 2, выигрыш 1 к 1, ничья — ставка назад.",
			"Дилер добирает до 17 и стоит на мягких 17. Вторую карту дилер берёт после тебя: его блэкджек забирает и удвоение, и сплит.",
			"Удвоить — на любых двух картах, ровно одна карта. Разделить пару — один раз, тузам по карте. После разделения удваивать можно.",
			"Пары (на две твои карты): одна масть 25:1, один цвет 12:1, разные цвета 6:1.",
			"21+3 (твои две и открытая дилера): три одной масти 100:1, стрит-флеш 40:1, тройка 25:1, стрит 10:1, флеш 5:1.",
			"Сайд-бет — не больше основной ставки. Только игровое золото. Карты идут подряд из перетасованного шуза: ничего не подкручено.",
			"Преимущество казино: игра ≈ 0.6%, Пары ≈ 6.1%, 21+3 ≈ 7.1%.",
		])
		rules.add_child(l)
		rules.visible = false
		root.add_child(rules)

	func _build_panel() -> void:
		panel = VBoxContainer.new()
		panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		panel.add_theme_constant_override("separation", 10)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(panel)
		result = Label.new()
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result.add_theme_font_override("font", UiTheme.display())
		result.add_theme_font_size_override("font_size", UiTheme.T_HEAD)
		result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		result.add_theme_constant_override("outline_size", 10)
		panel.add_child(result)
		sub = Label.new()
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_override("font", UiTheme.text_bold())
		sub.add_theme_font_size_override("font_size", UiTheme.T_SMALL)
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		sub.add_theme_constant_override("outline_size", 8)
		panel.add_child(sub)
		card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.94), Color(UiTheme.GOLD, 0.35), 2, UiTheme.RADIUS, 16))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		card.add_child(v)
		note = Label.new()
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", UiTheme.T_SMALL)
		note.add_theme_color_override("font_color", UiTheme.MUTED)
		v.add_child(note)
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 10)
		v.add_child(srow)
		for id in ["pp", "main", "t3"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(0, 80)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.size_flags_stretch_ratio = 1.3 if id == "main" else 1.0
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", UiTheme.T_SMALL + 2)
			var sid: String = id
			b.pressed.connect(func() -> void:
				if table.spot == sid:
					table.add_chip(table.chip, sid)
				else:
					table.select_spot(sid))
			srow.add_child(b)
			spots[id] = b
		chip_row = HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 8)
		v.add_child(chip_row)
		clear_btn = Button.new()
		clear_btn.text = "Сброс"
		clear_btn.custom_minimum_size = Vector2(118, 84)
		clear_btn.focus_mode = Control.FOCUS_NONE
		clear_btn.add_theme_font_size_override("font_size", UiTheme.T_SMALL + 2)
		clear_btn.pressed.connect(func() -> void: table.clear_bets())
		chip_row.add_child(clear_btn)
		deal_btn = Button.new()
		deal_btn.theme_type_variation = "Primary"
		deal_btn.custom_minimum_size = Vector2(0, 90)
		deal_btn.focus_mode = Control.FOCUS_NONE
		deal_btn.pressed.connect(func() -> void: table.deal())
		v.add_child(deal_btn)
		actions = HBoxContainer.new()
		actions.add_theme_constant_override("separation", 10)
		actions.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_child(actions)
		for a in [["hit", "Ещё"], ["stand", "Хватит"], ["double", "Удвоить"], ["split", "Разделить"]]:
			var b := Button.new()
			b.text = a[1]
			b.custom_minimum_size = Vector2(0, 96)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.focus_mode = Control.FOCUS_NONE
			b.clip_text = true
			b.add_theme_font_size_override("font_size", UiTheme.T_BODY - 3)
			var id: String = a[0]
			b.pressed.connect(func() -> void: _act(id))
			actions.add_child(b)
			act[id] = b

	func _act(id: String) -> void:
		match id:
			"hit":
				table.hit()
			"stand":
				table.stand()
			"double":
				table.double()
			"split":
				table.split()

	# --- showing -----------------------------------------------------------------------

	func refresh(t: ClubBlackjack) -> void:
		var g := t.game
		var playing := g.phase == Blackjack.Phase.PLAYER or (t.busy() and not t.showing_result())
		card.visible = not playing
		actions.visible = playing
		var idle := not t.busy()
		act["hit"].disabled = not (idle and g.can_hit())
		act["stand"].disabled = not (idle and g.can_stand())
		act["double"].disabled = not (idle and g.can_double() and SaveData.gold >= g.extra_needed())
		act["split"].disabled = not (idle and g.can_split() and SaveData.gold >= g.extra_needed())
		act["hit"].theme_type_variation = "Primary" if not act["hit"].disabled else ""
		# The words over the panel: the result, the side bets, a short note.
		result.text = ""
		sub.text = ""
		if t.showing_result():
			var n := t.round_net()
			result.text = ("+%d золота" % n) if n > 0 else ("−%d" % -n if n < 0 else "При своих")
			result.add_theme_color_override("font_color", UiTheme.WIN if n > 0 else (UiTheme.LOSE if n < 0 else UiTheme.INK))
		var lines: Array = []
		if g.phase != Blackjack.Phase.BETTING and (t.showing_result() or playing) and t.view().get("sides", false):
			if g.pp_bet > 0:
				lines.append("Пары: " + ("%s %d:1, +%d" % [Blackjack.NAMES[g.pp_hit], Blackjack.PERFECT_PAIRS[g.pp_hit], g.pp_paid - g.pp_bet] if g.pp_hit != "" else "мимо"))
			if g.t3_bet > 0:
				lines.append("21+3: " + ("%s %d:1, +%d" % [Blackjack.NAMES[g.t3_hit], Blackjack.TWENTY_ONE_3[g.t3_hit], g.t3_paid - g.t3_bet] if g.t3_hit != "" else "мимо"))
		if t.round_note() != "" and t.showing_result():
			lines.append(t.round_note())
		if playing and idle and g.phase == Blackjack.Phase.PLAYER:
			var need := g.extra_needed() - SaveData.gold
			if (g.can_double() or g.can_split()) and need > 0:
				lines.append("Удвоить или разделить: нужно ещё %d" % need)
		sub.text = "   ·   ".join(lines)
		sub.visible = sub.text != ""
		# Betting: the spots, the chips, the deal.
		var limit := t.limit()
		var mx := t.max_main()
		if mx < t.unit():
			note.text = "Ставка — до четверти золота: нужно хотя бы %d" % ceili(t.unit() / Bets.MAX_SHARE)
		else:
			note.text = "Стол до %d  ·  сайд-бет не больше ставки" % mini(limit, mx)
		for id in spots:
			var b: Button = spots[id]
			var amount := int(t.bets[id])
			var title: String = "СТАВКА" if id == "main" else ClubBlackjack.SPOT_NAMES[id]
			b.text = "%s\n%s" % [title, str(amount) if amount > 0 else "—"]
			b.theme_type_variation = "Primary" if t.spot == id else ""
			b.disabled = not t.can_bet() or (id != "main" and int(t.bets["main"]) <= 0)
		for c in chips:
			var cb := c as ChipButton
			cb.picked = cb.value == t.chip
			cb.disabled = not t.can_bet() or cb.value > t.room(t.spot)
			cb.queue_redraw()
		clear_btn.disabled = not t.can_bet() or (int(t.bets["main"]) + int(t.bets["pp"]) + int(t.bets["t3"])) == 0
		var total := int(t.bets["main"]) + int(t.bets["pp"]) + int(t.bets["t3"])
		deal_btn.text = ("СДАТЬ  ·  %d" % total) if int(t.bets["main"]) > 0 else "ПОЛОЖИ ФИШКУ"
		deal_btn.disabled = not t.can_bet() or int(t.bets["main"]) <= 0 or total > SaveData.gold

	## The totals over the cards and the dealer's bubble follow the camera.
	func place_labels() -> void:
		var t := table
		var v := t.view()
		var dealer: Array = v.get("dealer", [])
		var hands: Array = v.get("hands", [])
		var settled: bool = v.get("settled", false) and not t.busy()
		_pill_at(pills[0], t.view_total(dealer), t.screen_of(ClubBlackjack.DEALER_CARDS + Vector3(0, 0, -0.17)), UiTheme.INK)
		for i in 2:
			var p := pills[i + 1]
			if i >= hands.size() or (hands[i] as Array).is_empty():
				p.visible = false
				continue
			var x := 0.0 if hands.size() == 1 else (-0.2 if i == 0 else 0.2)
			var text := t.view_total(hands[i])
			var col := UiTheme.INK
			if settled and i < t.game.hands.size():
				var h: Dictionary = t.game.hands[i]
				var won := int(h["paid"]) - int(h["bet"])
				match String(h["outcome"]):
					"blackjack":
						text = "БЛЭКДЖЕК  +%d" % won
						col = UiTheme.GOLD
					"win":
						text = "%s  +%d" % [text, won]
						col = UiTheme.WIN
					"push":
						text = "%s  ничья" % text
					"bust":
						text = "ПЕРЕБОР"
						col = UiTheme.LOSE
					_:
						text = "%s  −%d" % [text, int(h["bet"])]
						col = UiTheme.LOSE
			elif hands.size() > 1 and i == int(v.get("active", 0)) and t.game.phase == Blackjack.Phase.PLAYER:
				col = UiTheme.GOLD
			_pill_at(p, text, t.screen_of(ClubBlackjack.PLAYER_CARDS + Vector3(x, 0, 0.19)), col)
		if bubble.visible:
			var head := t.screen_of(t.to_local(t.dealer_head()))
			var s := bubble.size
			var vp := root.get_viewport_rect().size
			bubble.position = Vector2(clampf(head.x - s.x * 0.5, UiTheme.GUTTER, vp.x - UiTheme.GUTTER - s.x), maxf(head.y - s.y - 10.0, 112.0 + safe.x))

	func _pill_at(p: PanelContainer, text: String, at: Vector2, col: Color) -> void:
		p.visible = text != "" and at.x > -999.0
		if not p.visible:
			return
		var l := p.get_child(0) as Label
		l.text = text
		l.add_theme_color_override("font_color", col)
		p.reset_size()
		p.position = at - p.size * 0.5

	func say(text: String, seconds := 3.0) -> void:
		bubble_label.text = text
		bubble.visible = true
		bubble.reset_size()
		bubble_t = seconds

	func _process(delta: float) -> void:
		if bubble_t > 0.0:
			bubble_t -= delta
			if bubble_t <= 0.0:
				bubble.visible = false

	## A tap on the table: during a deal it shows the end at once; while betting, a tap
	## on a circle on the felt puts the chip there.
	func _on_catcher(e: InputEvent) -> void:
		var pressed := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
		if not pressed:
			return
		rules.visible = false
		if table.busy():
			table.skip()
			return
		if not table.can_bet():
			return
		var pos: Vector2 = e.position
		for id in ClubBlackjack.SPOTS:
			if pos.distance_to(table.spot_on_screen(id)) < 70.0:
				table.select_spot(id)
				table.add_chip(table.chip, id)
				return


## A chip in the panel's row: the same ball-chip as on the felt.
class ChipButton extends Button:
	var value := 5
	var picked := false

	func _ready() -> void:
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(k, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(minf(size.y * 0.5, size.x * 0.5) - 7.0, 40.0)
		var a := 0.35 if disabled else 1.0
		if picked:
			draw_circle(c, r + 5.0, Color(UiTheme.GOLD, a))
		var col: Color = ClubBlackjack.CHIP_COLORS[value]
		draw_circle(c, r, Color(col, a))
		for k in 8:
			var ang := TAU * k / 8.0
			draw_arc(c, r * 0.86, ang - 0.14, ang + 0.14, 6, Color(ClubBlackjack.BALL, a), r * 0.2)
		draw_circle(c, r * 0.68, Color(ClubBlackjack.BALL, a))
		draw_arc(c + Vector2(-r * 0.95, 0), r * 0.6, -0.75, 0.75, 12, Color(1, 1, 1, 0.9 * a), 2.5)
		draw_arc(c + Vector2(r * 0.95, 0), r * 0.6, PI - 0.75, PI + 0.75, 12, Color(1, 1, 1, 0.9 * a), 2.5)
		var f := UiTheme.display()
		var s := str(value)
		var fs := 26 if value < 100 else (22 if value < 1000 else 18)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.1, 0.12, a))
