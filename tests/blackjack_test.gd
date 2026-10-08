extends SceneTree
## Blackjack at the bar (docs/superpowers/specs/2026-10-08-v02-blackjack.md): the rules on
## fixed shoes, every side-bet payout, the exact side-bet edges and a simulation of
## 200 000 hands of basic strategy that prints the house edge.
##   godot --headless --path . -s tests/blackjack_test.gd [-- --hands=2000000] [--no-scene]

var failures := 0
var hands_n := 200000
var scene := true


func _initialize() -> void:
	SaveData.enabled = false  # never the developer's save
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hands="):
			hands_n = int(a.get_slice("=", 1))
		elif a == "--no-scene":
			scene = false
	test_cards()
	test_shoe()
	test_rules()
	test_split_and_double()
	test_side_bets()
	test_limits_and_save()
	test_exact_side_edges()
	test_simulation()
	if scene:
		await test_table()
	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if failures == 0 else "TESTS FAILED", failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


## A card by its name: C("A", "s"), C("10", "h"), C("K", "d"); suits s h d c.
func C(r: String, s: String) -> int:
	var ranks := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	return "shdc".find(s) * 13 + ranks.find(r)


## A game on a stacked shoe: the cards come in this order (player, dealer, player, then
## whatever is drawn next).
func stacked(cards: Array) -> Blackjack:
	var g := Blackjack.new(1)
	g.set_shoe(cards)
	return g


func test_cards() -> void:
	print("cards")
	check(Blackjack.value(C("A", "s")) == 11 and Blackjack.value(C("K", "h")) == 10 and Blackjack.value(C("7", "d")) == 7, "values: A 11, K 10, 7 7")
	check(Blackjack.total([C("A", "s"), C("6", "h")]) == 17 and Blackjack.is_soft([C("A", "s"), C("6", "h")]), "A+6 = soft 17")
	check(Blackjack.total([C("A", "s"), C("6", "h"), C("10", "c")]) == 17 and not Blackjack.is_soft([C("A", "s"), C("6", "h"), C("10", "c")]), "A+6+10 = hard 17")
	check(Blackjack.total([C("A", "s"), C("A", "h"), C("9", "c")]) == 21, "A+A+9 = 21")
	check(Blackjack.total([C("K", "s"), C("Q", "h"), C("2", "c")]) == 22, "K+Q+2 = 22")
	check(Blackjack.is_blackjack([C("A", "s"), C("J", "d")]) and not Blackjack.is_blackjack([C("7", "s"), C("7", "d"), C("7", "c")]), "A+J is blackjack, 7+7+7 is not")
	check(Blackjack.is_red(C("5", "h")) and Blackjack.is_red(C("5", "d")) and not Blackjack.is_red(C("5", "s")), "hearts and diamonds are red")
	check(Blackjack.card_name(C("10", "h")) == "10♥" and Blackjack.card_name(C("A", "s")) == "A♠", "names: 10♥, A♠")


func test_shoe() -> void:
	print("shoe")
	var g := Blackjack.new(7)
	check(g.shoe.size() == 312, "six decks: 312 cards")
	var counts := {}
	for c in g.shoe:
		counts[c] = int(counts.get(c, 0)) + 1
	var six := counts.size() == 52
	for c in counts:
		six = six and counts[c] == 6
	check(six, "every card six times")
	var a := Blackjack.new(7)
	check(a.shoe == g.shoe, "the same seed shuffles the same way")
	var b := Blackjack.new(8)
	check(b.shoe != g.shoe, "another seed, another order")
	# The cut: fewer than 1.5 decks left -> a fresh shuffle before the next deal.
	g.at = 312 - Blackjack.CUT
	check(not g.needs_shuffle(), "78 cards left: no shuffle yet")
	g.at += 1
	check(g.needs_shuffle(), "77 left: shuffle before the next deal")
	var shuffles := g.shuffles
	g.deal(10, 0, 0)
	check(g.shuffles == shuffles + 1 and g.left() == 312 - g.used_this_round(), "the deal reshuffled the whole shoe")
	check(g.events.size() > 0 and g.events[0]["kind"] == "shuffle", "the table is told about the shuffle")
	# The cards come in shoe order, nothing picks them.
	var h := Blackjack.new(9)
	var top := [h.shoe[0], h.shoe[1], h.shoe[2]]
	h.deal(10, 0, 0)
	check(h.hands[0]["cards"][0] == top[0] and h.dealer[0] == top[1] and h.hands[0]["cards"][1] == top[2], "player, dealer, player: straight from the shoe")


func test_rules() -> void:
	print("rules")
	# Blackjack pays 3:2; the dealer's second card comes after the player (no hole card).
	var g := stacked([C("A", "s"), C("9", "h"), C("K", "d"), C("7", "c")])
	check(g.deal(10, 0, 0), "a deal goes")
	check(g.phase == Blackjack.Phase.DONE and g.hands[0]["outcome"] == "blackjack", "player blackjack: done at once")
	check(int(g.hands[0]["paid"]) == 25 and g.returned() == 25 and g.staked() == 10, "blackjack pays 3:2 (10 -> 25 back)")
	check(g.dealer.size() == 2, "the dealer only takes his second card")
	g = stacked([C("A", "s"), C("9", "h"), C("K", "d"), C("7", "c")])
	g.deal(5, 0, 0)
	check(g.returned() == 13, "3:2 of 5 is rounded up: 5 + 8")
	# Blackjack against blackjack: a push.
	g = stacked([C("A", "s"), C("A", "h"), C("K", "d"), C("Q", "c")])
	g.deal(10, 0, 0)
	check(g.hands[0]["outcome"] == "push" and g.returned() == 10, "blackjack vs blackjack = push")
	# The dealer stands on soft 17.
	g = stacked([C("10", "s"), C("6", "h"), C("7", "d"), C("A", "c"), C("5", "s")])
	g.deal(10, 0, 0)
	check(g.phase == Blackjack.Phase.PLAYER and g.can_hit() and g.can_stand(), "17 vs 6: the player's turn")
	g.stand()
	check(g.dealer.size() == 2 and Blackjack.total(g.dealer) == 17 and Blackjack.is_soft(g.dealer), "dealer stands on soft 17")
	check(g.hands[0]["outcome"] == "push" and g.returned() == 10, "17 vs 17: push")
	# The dealer hits 16.
	g = stacked([C("10", "s"), C("9", "h"), C("9", "d"), C("7", "c"), C("5", "s")])
	g.deal(10, 0, 0)
	g.stand()
	check(g.dealer.size() == 3 and Blackjack.total(g.dealer) == 21, "dealer hits 16 (9+7+5 = 21)")
	check(g.hands[0]["outcome"] == "lose" and g.returned() == 0, "19 vs 21: lost")
	# A win, a dealer bust.
	g = stacked([C("10", "s"), C("6", "h"), C("8", "d"), C("10", "c"), C("9", "s")])
	g.deal(10, 0, 0)
	g.stand()
	check(g.hands[0]["outcome"] == "win" and g.returned() == 20, "18 vs dealer bust: 1:1")
	# The player busts: the dealer takes one card and stops.
	g = stacked([C("10", "s"), C("5", "h"), C("6", "d"), C("9", "c"), C("2", "s"), C("10", "h")])
	g.deal(10, 0, 0)
	g.hit()
	check(g.hands[0]["outcome"] == "bust" and g.phase == Blackjack.Phase.DONE, "25: bust")
	check(g.dealer.size() == 2, "nothing left to beat: the dealer stops at two cards")
	# 21 stands by itself.
	g = stacked([C("5", "s"), C("7", "h"), C("6", "d"), C("10", "c"), C("10", "s")])
	g.deal(10, 0, 0)
	g.hit()
	check(bool(g.hands[0]["done"]) and g.phase == Blackjack.Phase.DONE, "21 stands by itself")
	check(g.hands[0]["outcome"] == "win" and g.returned() == 20, "21 vs 17: win")
	# Nothing works out of turn.
	check(not g.hit() and not g.stand() and not g.double() and not g.split(), "no moves once the round is over")


func test_split_and_double() -> void:
	print("split and double")
	# Double: one card, the bet doubles.
	var g := stacked([C("5", "s"), C("6", "h"), C("6", "d"), C("10", "c"), C("10", "h"), C("10", "s")])
	g.deal(10, 0, 0)
	check(g.can_double() and g.extra_needed() == 10, "11: double for 10 more")
	g.double()
	var h: Dictionary = g.hands[0]
	check(h["cards"].size() == 3 and int(h["bet"]) == 20 and bool(h["doubled"]) and bool(h["done"]), "doubled: one card, bet 20, done")
	check(h["outcome"] == "win" and g.returned() == 40 and g.staked() == 20, "21 vs bust: 40 back")
	# No double after a hit.
	g = stacked([C("2", "s"), C("6", "h"), C("3", "d"), C("4", "c"), C("10", "h")])
	g.deal(10, 0, 0)
	g.hit()
	check(not g.can_double(), "no double on three cards")
	# Double on any two (soft 18 too).
	g = stacked([C("A", "s"), C("5", "h"), C("7", "d"), C("2", "c")])
	g.deal(10, 0, 0)
	check(g.can_double(), "double on any two: soft 18")
	# Split 8s, double after split, no resplit.
	g = stacked([C("8", "s"), C("7", "h"), C("8", "h"), C("3", "c"), C("10", "d"), C("8", "d"), C("10", "s")])
	g.deal(10, 0, 0)
	check(g.can_split() and g.extra_needed() == 10, "a pair of 8s splits for 10 more")
	g.split()
	check(g.hands.size() == 2 and g.active == 0 and g.hands[0]["cards"] == [C("8", "s"), C("3", "c")], "split: two hands, the first gets its card")
	check(g.can_double(), "double after split")
	g.double()
	check(g.active == 1 and g.hands[1]["cards"] == [C("8", "h"), C("8", "d")], "the second hand gets its card when its turn comes")
	check(not g.can_split(), "no second split")
	g.stand()
	check(g.phase == Blackjack.Phase.DONE and Blackjack.total(g.dealer) == 17, "dealer 7+10 = 17")
	check(g.hands[0]["outcome"] == "win" and int(g.hands[0]["paid"]) == 40, "8+3+10 = 21, doubled: 40 back")
	check(g.hands[1]["outcome"] == "lose" and int(g.hands[1]["paid"]) == 0, "8+8 = 16 vs 17: lost")
	check(g.staked() == 30 and g.returned() == 40, "staked 10 + 10 double + 10 split = 30")
	# Split aces: one card each, closed; A+10 after a split is 21, not a blackjack.
	g = stacked([C("A", "s"), C("9", "h"), C("A", "h"), C("K", "c"), C("9", "d"), C("10", "s")])
	g.deal(10, 0, 0)
	g.split()
	check(g.phase == Blackjack.Phase.DONE, "split aces: both hands closed at once")
	check(g.hands[0]["cards"].size() == 2 and g.hands[1]["cards"].size() == 2, "one card on each ace")
	check(g.hands[0]["outcome"] == "win" and int(g.hands[0]["paid"]) == 20, "A+K after a split pays 1:1, not 3:2")
	check(g.hands[1]["outcome"] == "win" and g.returned() == 40, "A+9 = 20 vs 19: win")
	# Tens of any kind split (K+Q), once.
	g = stacked([C("K", "s"), C("5", "h"), C("Q", "h")])
	g.deal(10, 0, 0)
	check(g.can_split(), "K and Q: a pair of tens")
	g = stacked([C("9", "s"), C("5", "h"), C("8", "h")])
	g.deal(10, 0, 0)
	check(not g.can_split(), "9 and 8: no split")
	# No hole card: a dealer blackjack takes the double too.
	g = stacked([C("6", "s"), C("A", "h"), C("5", "d"), C("9", "c"), C("K", "s")])
	g.deal(10, 0, 0)
	g.double()
	check(Blackjack.is_blackjack(g.dealer) and g.hands[0]["outcome"] == "lose" and g.returned() == 0 and g.staked() == 20, "dealer blackjack takes the doubled 20")
	# 21 of three cards loses to a dealer blackjack, pushes against a dealer 21.
	g = stacked([C("7", "s"), C("10", "h"), C("4", "d"), C("10", "c"), C("4", "s"), C("7", "h")])
	g.deal(10, 0, 0)
	g.hit()
	check(Blackjack.total(g.hands[0]["cards"]) == 21 and Blackjack.total(g.dealer) == 21 and g.hands[0]["outcome"] == "push", "21 vs dealer's 21 of three: push")


func test_side_bets() -> void:
	print("side bets")
	check(Blackjack.perfect_pairs(C("8", "s"), C("8", "s")) == "perfect", "8♠ 8♠: perfect pair")
	check(Blackjack.perfect_pairs(C("8", "h"), C("8", "d")) == "colored", "8♥ 8♦: colored pair")
	check(Blackjack.perfect_pairs(C("8", "s"), C("8", "h")) == "mixed", "8♠ 8♥: mixed pair")
	check(Blackjack.perfect_pairs(C("8", "s"), C("9", "s")) == "", "8♠ 9♠: nothing")
	check(Blackjack.perfect_pairs(C("K", "s"), C("Q", "s")) == "", "K♠ Q♠: not a pair (only the same rank)")
	var t := {
		"suited_trips": [C("7", "h"), C("7", "h"), C("7", "h")],
		"straight_flush": [C("5", "c"), C("7", "c"), C("6", "c")],
		"trips": [C("7", "s"), C("7", "h"), C("7", "d")],
		"straight": [C("A", "d"), C("3", "h"), C("2", "s")],
		"flush": [C("2", "h"), C("9", "h"), C("K", "h")],
	}
	for k in t:
		var c: Array = t[k]
		check(Blackjack.twenty_one_3(c[0], c[1], c[2]) == k, "21+3 %s %s" % [k, " ".join(c.map(func(x): return Blackjack.card_name(x)))])
	check(Blackjack.twenty_one_3(C("Q", "s"), C("K", "s"), C("A", "s")) == "straight_flush", "Q K A of spades: straight flush (ace high)")
	check(Blackjack.twenty_one_3(C("Q", "h"), C("A", "c"), C("K", "s")) == "straight", "Q K A: straight")
	check(Blackjack.twenty_one_3(C("K", "s"), C("A", "h"), C("2", "d")) == "", "K A 2: no straight round the corner")
	check(Blackjack.twenty_one_3(C("2", "h"), C("2", "h"), C("9", "h")) == "flush", "2♥ 2♥ 9♥: a flush")
	check(Blackjack.twenty_one_3(C("2", "h"), C("9", "s"), C("K", "h")) == "", "2♥ 9♠ K♥: nothing")
	# Every payout through a whole round: player's two cards and the dealer's up card.
	var pays := {
		"perfect": [[C("8", "s"), C("2", "h"), C("8", "s")], 25],
		"colored": [[C("8", "h"), C("2", "s"), C("8", "d")], 12],
		"mixed": [[C("8", "s"), C("2", "h"), C("8", "h")], 6],
	}
	for k in pays:
		var cards: Array = pays[k][0]
		var g := stacked(cards + [C("10", "c"), C("10", "d")])
		g.deal(10, 10, 0)
		check(g.pp_hit == k and g.pp_paid == 10 * (1 + int(pays[k][1])), "Perfect Pairs %s pays %d:1 (%d back)" % [k, pays[k][1], g.pp_paid])
	var t3 := {
		"suited_trips": [[C("7", "h"), C("7", "h"), C("7", "h")], 100],
		"straight_flush": [[C("5", "c"), C("6", "c"), C("7", "c")], 40],
		"trips": [[C("7", "s"), C("7", "h"), C("7", "d")], 25],
		"straight": [[C("9", "s"), C("10", "h"), C("J", "d")], 10],
		"flush": [[C("2", "d"), C("9", "d"), C("K", "d")], 5],
	}
	for k in t3:
		var cards: Array = t3[k][0]
		# Shoe order: player, dealer (the up card), player.
		var g := stacked([cards[0], cards[2], cards[1], C("10", "c"), C("10", "d"), C("10", "s")])
		g.deal(10, 0, 10)
		check(g.t3_hit == k and g.t3_paid == 10 * (1 + int(t3[k][1])), "21+3 %s pays %d:1 (%d back)" % [k, t3[k][1], g.t3_paid])
	var g := stacked([C("8", "s"), C("2", "h"), C("9", "s"), C("10", "c"), C("10", "d")])
	g.deal(10, 5, 5)
	check(g.pp_paid == 0 and g.t3_paid == 0 and g.staked() == 20, "side bets lost: they stay with the dealer")
	check(g.pp_hit == "" and g.t3_hit == "", "nothing hit")


func test_limits_and_save() -> void:
	print("limits and save")
	var g := Blackjack.new(3)
	check(not g.deal(10, 15, 0) and not g.deal(10, 0, 11) and not g.deal(0, 0, 0), "a side bet never over the main one")
	check(g.deal(10, 10, 10), "side bets equal to the main one: fine")
	check(not g.deal(10, 0, 0) or g.phase == Blackjack.Phase.PLAYER, "no new deal in the middle of a hand")
	check(Blackjack.max_bet(400, 150) == 100 and Blackjack.max_bet(4000, 150) == 150 and Blackjack.max_bet(10, 25) == 2, "main bet: the bar's limit and a quarter of the gold")
	check(Blackjack.chips_for(400, 150) == [5, 25, 50, 100] and Blackjack.chips_for(60, 25) == [5], "chips that still fit")
	check(Blackjack.chips_for(100000, 1000, [10, 25, 50, 100, 250, 500, 1000]) == [10, 25, 50, 100, 250, 500, 1000] and Blackjack.chips_for(1000, 1000, [10, 25, 50, 100, 250, 500, 1000]) == [10, 25, 50, 100, 250], "the bar's own set of chips: all the way to 1000, a quarter of the gold")
	for v in [10, 250, 500, 1000]:
		check(ClubBlackjack.CHIP_CELL.has(v) and ClubBlackjack.CHIP_COLORS.has(v) and Blackjack.ALL_CHIPS.has(v), "a chip face for %d" % v)
	check(ClubBlackjack.breakdown(1000) == [1000] and ClubBlackjack.breakdown(785) == [500, 250, 25, 10], "stacks of the big chips: 1000 is one chip, 785 is four")
	# A round saved mid-hand comes back and is finished by standing.
	g = stacked([C("10", "s"), C("6", "h"), C("8", "d"), C("10", "c"), C("9", "s")])
	g.deal(10, 5, 0)
	var d := g.to_dict()
	var back := Blackjack.new(4)
	check(back.from_dict(d) and back.phase == Blackjack.Phase.PLAYER and back.hands[0]["cards"] == g.hands[0]["cards"] and back.dealer == g.dealer, "a saved round comes back as it was")
	back.finish_standing()
	check(back.phase == Blackjack.Phase.DONE and bool(back.hands[0]["done"]), "an unfinished round is played out by standing")
	check(back.staked() == 15, "with its stakes")
	check(not Blackjack.new(5).from_dict({}), "nothing saved: nothing comes back")


## The side bets' house edges, exactly: every two-card (Perfect Pairs) and three-card
## (21+3) draw from six decks.
func test_exact_side_edges() -> void:
	print("exact side-bet edges (6 decks)")
	var pp := Blackjack.exact_pp_edge()
	var t3 := Blackjack.exact_t3_edge()
	print("  Perfect Pairs 25/12/6: house edge %.3f%%" % (pp * 100.0))
	print("  21+3 100/40/25/10/5:   house edge %.3f%%" % (t3 * 100.0))
	check(absf(pp - 2964.0 / 48516.0) < 1e-9, "Perfect Pairs: 2964/48516 = 6.11%")
	# By hand: suited trips 0.021%, straight flush 0.207%, trips 0.504%, straight 3.102%,
	# flush 5.842% -> 100*0.00021 + 40*0.00207 + 25*0.00504 + 10*0.03102 + 5*0.05842 - 0.90324.
	check(absf(t3 - 0.0715) < 0.0005, "21+3: %.2f%% (the hand count says 7.15%%)" % (t3 * 100.0))


## Basic strategy for 6 decks, dealer stands on soft 17, double on any two, double after
## split, no surrender, no hole card (Wizard of Odds' ENHC chart). up: 2..11 (11 = ace).
## Returns "H", "S", "D" (double, else hit), "Ds" (double, else stand) or "P".
static func basic(cards: Array, up: int, can_split: bool) -> String:
	var t := Blackjack.total(cards)
	if can_split and cards.size() == 2 and Blackjack.value(cards[0]) == Blackjack.value(cards[1]):
		var v := Blackjack.value(cards[0])
		match v:
			11:
				return "P" if up <= 10 else "H"
			10:
				return "S"
			9:
				return "P" if up in [2, 3, 4, 5, 6, 8, 9] else "S"
			8:
				return "P" if up <= 9 else "H"
			7:
				return "P" if up <= 7 else "H"
			6:
				return "P" if up <= 6 else "H"
			4:
				return "P" if up in [5, 6] else "H"
			3, 2:
				return "P" if up <= 7 else "H"
		# 5,5 plays as a hard 10
	if Blackjack.is_soft(cards):
		if t >= 19:
			return "S"
		if t == 18:
			if up in [3, 4, 5, 6]:
				return "Ds"
			return "S" if up in [2, 7, 8] else "H"
		if t == 17:
			return "D" if up in [3, 4, 5, 6] else "H"
		if t in [15, 16]:
			return "D" if up in [4, 5, 6] else "H"
		if t in [13, 14]:
			return "D" if up in [5, 6] else "H"
		return "H"
	if t >= 17:
		return "S"
	if t >= 13:
		return "S" if up <= 6 else "H"
	if t == 12:
		return "S" if up in [4, 5, 6] else "H"
	if t in [10, 11]:
		return "D" if up <= 9 else "H"
	if t == 9:
		return "D" if up in [3, 4, 5, 6] else "H"
	return "H"


func play_basic(g: Blackjack) -> void:
	var up := Blackjack.value(g.dealer[0])
	while g.phase == Blackjack.Phase.PLAYER:
		var h: Dictionary = g.hands[g.active]
		var a := basic(h["cards"], up, g.can_split())
		match a:
			"P":
				g.split()
			"D":
				if g.can_double():
					g.double()
				else:
					g.hit()
			"Ds":
				if g.can_double():
					g.double()
				else:
					g.stand()
			"H":
				g.hit()
			_:
				g.stand()


func test_simulation() -> void:
	print("simulation: %d hands of basic strategy" % hands_n)
	var g := Blackjack.new(20261008)
	g.record_events = false
	var t0 := Time.get_ticks_msec()
	var net := 0.0
	var net2 := 0.0
	var pp_net := 0.0
	var pp2 := 0.0
	var t3_net := 0.0
	var t32 := 0.0
	var bj := 0
	var doubles := 0
	var splits := 0
	var bet := 100
	for i in hands_n:
		g.deal(bet, bet, bet)
		var pp := float(g.pp_paid - bet) / bet
		var t3 := float(g.t3_paid - bet) / bet
		pp_net += pp
		pp2 += pp * pp
		t3_net += t3
		t32 += t3 * t3
		play_basic(g)
		var main := float(g.main_returned() - g.main_staked()) / bet
		net += main
		net2 += main * main
		if g.hands.size() == 1 and Blackjack.is_blackjack(g.hands[0]["cards"]):
			bj += 1
		if g.hands.size() > 1:
			splits += 1
		for h in g.hands:
			if h["doubled"]:
				doubles += 1
	var n := float(hands_n)
	var edge := -net / n
	var se := sqrt(maxf(net2 / n - (net / n) * (net / n), 0.0) / n)
	var pp_edge := -pp_net / n
	var pp_se := sqrt(maxf(pp2 / n - (pp_net / n) * (pp_net / n), 0.0) / n)
	var t3_edge := -t3_net / n
	var t3_se := sqrt(maxf(t32 / n - (t3_net / n) * (t3_net / n), 0.0) / n)
	print("  | bet            | house edge, sim     | exact   |")
	print("  | main game      | %.2f%% ± %.2f%%      | ~0.55%%  |" % [edge * 100.0, 1.96 * se * 100.0])
	print("  | Perfect Pairs  | %.2f%% ± %.2f%%      | %.2f%%   |" % [pp_edge * 100.0, 1.96 * pp_se * 100.0, Blackjack.exact_pp_edge() * 100.0])
	print("  | 21+3           | %.2f%% ± %.2f%%      | %.2f%%   |" % [t3_edge * 100.0, 1.96 * t3_se * 100.0, Blackjack.exact_t3_edge() * 100.0])
	print("  blackjacks %.2f%%, splits %.2f%%, doubles %.2f%% of hands, shuffles %d, %.1f s" % [bj * 100.0 / n, splits * 100.0 / n, doubles * 100.0 / n, g.shuffles, (Time.get_ticks_msec() - t0) / 1000.0])
	# Honest bounds: the true edge (~0.5-0.6%) within four standard errors.
	check(absf(edge - 0.0055) < 4.0 * se + 0.002, "main game: house edge %.2f%% (≈0.5–0.7%% expected, ± %.2f%% noise)" % [edge * 100.0, 1.96 * se * 100.0])
	check(absf(pp_edge - Blackjack.exact_pp_edge()) < 4.0 * pp_se, "Perfect Pairs: the simulation meets the exact edge")
	check(absf(t3_edge - Blackjack.exact_t3_edge()) < 4.0 * t3_se, "21+3: the simulation meets the exact edge")
	check(absf(bj / n - 0.0475) < 4.0 * sqrt(0.0475 * 0.9525 / n) + 0.001, "a blackjack every ~21 hands (%.2f%%)" % (bj * 100.0 / n))


## The table at the bar in the club: the place, the bets, the gold of every move, a hand
## left in the middle, the break after three losses.
func test_table() -> void:
	print("table at the bar")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	SaveData.enabled = false
	SaveData.club = {"met_coach": true}
	SaveData.active = null
	SaveData.run = {}
	SaveData.played = 1
	SaveData.titles = 1
	SaveData.gold = 400
	SaveData.bets = {}
	Skills.pending = []
	main._show_menu()
	await _frames(3)
	var club = main.club
	check(club.world.blackjack_root().get_node_or_null("blackjack") == null, "the table is built by the place's button, not before")
	var place := ClubPlaces.find("blackjack")
	check(not place.is_empty() and ClubPlaces.state("blackjack")["action"] == "club_blackjack", "the place blackjack, its button opens the table")
	check(not ClubPlaces.is_open(place, 5, 0) and ClubPlaces.is_open(place, 5, 1), "it opens after the first title, as the roulette")
	var pp: Vector3 = place["pos"]
	check(not club.world.walk.route(Vector2(0, 14), Vector2(pp.x, pp.z)).is_empty(), "a way from the court to the table")
	check(not club.world.walk.blocked(Vector2(pp.x, pp.z), 0.3), "its circle is free to stand in")
	main.player.position = place["pos"]
	club._update_place()
	await _frames(2)
	check(club.hud.current_place() == "blackjack", "the hero at the table: its button is up")
	club._on_choice("club_blackjack", 0)
	await _frames(3)
	var t = club.world.blackjack_root().get_node_or_null("blackjack")
	check(t is ClubBlackjack and t.get_parent() == club.world.blackjack_root(), "ClubBlackjack.open builds the table on the world's blackjack node")
	check(not club.world.blackjack_root().get_node("placeholder").visible, "the placeholder steps aside")
	check(t.is_open() and not main.ui.is_open(), "the table is a 3D scene, not a screen")
	check(not main.player.visible and not (club.hud.get("_bottom") as Control).visible, "the hero steps aside, the club's bottom bar too")
	check(main.hud.touch.blocked_controls.has(t._ui.catcher), "the joystick leaves the table alone")
	var tc: Array = t.table_chips()
	var tc_ok: bool = not tc.is_empty() and tc.size() == t._ui.chips.size()
	for v in tc:
		tc_ok = tc_ok and Blackjack.ALL_CHIPS.has(v) and v <= t.limit()
	check(tc_ok, "the chip row is the bar's set at its level: %s" % str(tc))
	# Bets: the bar's limit (25 at level 0), a quarter of the gold, side bets <= main.
	t.clear_bets()
	check(t.max_main() == 25, "level 0 bar: the main bet up to 25")
	check(t.add_chip(25, "main") and not t.add_chip(5, "main"), "25 on the main spot, not a chip more")
	check(t.add_chip(25, "pp") and not t.add_chip(5, "pp"), "a side bet up to the main one")
	# A whole round on a stacked shoe: pair of 8s (a mixed pair), split, double, stand.
	t.game = stacked([C("8", "s"), C("7", "h"), C("8", "h"), C("3", "c"), C("10", "d"), C("8", "d"), C("10", "s")])
	check(t.deal() and SaveData.gold == 350, "the deal takes both stakes at once (400 -> 350)")
	check(SaveData.bets.has("bj_round"), "a hand in progress is saved")
	check(t.game.pp_hit == "mixed", "a mixed pair on the side bet")
	t.skip()
	await _frames(2)
	check(not t._ui.act["split"].disabled and not t._ui.act["double"].disabled, "split and double are offered")
	check(t.split() and SaveData.gold == 325, "split: 25 more")
	check(t.double() and SaveData.gold == 300, "double after split: 25 more")
	check(t.stand(), "stand on 16")
	check(t.game.phase == Blackjack.Phase.DONE and SaveData.gold == 300 + 100 + 175, "paid at once: the doubled 21 (100) and the pair 6:1 (175)")
	check(not SaveData.bets.has("bj_round") and int(SaveData.bets.get("loss_streak", 0)) == 0, "the round is closed; a win resets the streak")
	t.skip()
	for i in 90:
		await process_frame
	check(not t.busy() and t.showing_result(), "a tap shows the end at once")
	check(t._cards.size() == 7, "seven cards on the felt (%d)" % t._cards.size())
	check(not t._ui.card.visible == false, "the bets panel is back for the next round")
	check(int(t.bets["main"]) == 25 and int(t.bets["pp"]) == 25, "the same bets stay for the next round")
	# Closing in the middle of a hand plays it out by standing.
	var g0: int = SaveData.gold
	t.bets = {"pp": 0, "main": 25, "t3": 0}
	t.game = stacked([C("10", "s"), C("6", "h"), C("8", "d"), C("10", "c"), C("9", "s")])
	t.deal()
	check(SaveData.gold == g0 - 25, "the next stake goes")
	t.close()
	await _frames(3)
	check(not t.is_open() and SaveData.gold == g0 + 25, "«Назад» mid-hand: stands and is paid (18 vs bust)")
	check(main.player.visible and (club.hud.get("_bottom") as Control).visible and club.hud.current_place() == "blackjack", "back in the club at the table's circle")
	# A hand left when the game was closed comes back and is played out by standing.
	var left := stacked([C("10", "s"), C("6", "h"), C("9", "d"), C("10", "c"), C("9", "s")])
	left.deal(25, 0, 0)
	SaveData.bets["bj_round"] = left.to_dict()
	g0 = SaveData.gold
	club._on_choice("club_blackjack", 0)
	await _frames(2)
	check(t.is_open() and not SaveData.bets.has("bj_round") and t.game.phase == Blackjack.Phase.DONE, "a saved hand is played out on the way in")
	check(SaveData.gold >= g0, "and its winnings, if any, are paid (%d -> %d)" % [g0, SaveData.gold])
	t.skip()
	await _frames(2)
	# Three losses in a row: the dealer suggests a break; the table stays open.
	SaveData.bets["loss_streak"] = 2
	t.bets = {"pp": 0, "main": 25, "t3": 0}
	t.game = stacked([C("10", "s"), C("10", "h"), C("7", "d"), C("9", "c")])
	t.deal()
	t.stand()
	t.skip()
	for i in 10:
		await process_frame
	check(Bets.needs_break(SaveData.bets), "three hands lost in a row")
	check(t._ui.bubble.visible and t._ui.bubble_label.text.contains("ерерыв"), "the dealer: «Перерыв?» (%s)" % t._ui.bubble_label.text)
	check(not t._ui.deal_btn.disabled, "the table stays open")
	# Little gold: a quarter of it is the limit.
	SaveData.gold = 30
	t.clear_bets()
	t._refresh()
	var u: int = t.unit()
	check(t.max_main() == 7 and t.add_chip(u, "main") == (u <= 7) and not t.add_chip(u, "main"), "30 gold: one smallest chip (%d) if it fits, never two" % u)
	SaveData.gold = 12
	t.clear_bets()
	t._refresh()
	check(not t.add_chip(u, "main") and t._ui.deal_btn.disabled, "12 gold: no bet at all")
	t.close()
	await _frames(2)
	main.queue_free()
	await _frames(2)
	SaveData.played = 0
	SaveData.titles = 0
	SaveData.gold = 0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
