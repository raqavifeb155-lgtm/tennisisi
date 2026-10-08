class_name Blackjack
extends RefCounted
## Blackjack at the club's bar (docs/superpowers/specs/2026-10-08-v02-blackjack.md, hub
## spec 6): the rules, the shoe and the payouts - no scene, no gold. ClubBlackjack shows
## a round and moves the gold (SaveData); this only says what the cards are and pay.
##
## As in a European casino: six decks, a fresh shuffle once fewer than 1.5 decks are left,
## no hole card (the dealer's second card comes after the player), the dealer stands on
## soft 17, blackjack pays 3:2, double on any two, split once (aces get one card each),
## double after split, no surrender, no insurance. Side bets on the player's two cards
## and the dealer's up card: Perfect Pairs and 21+3. Game gold only.
##
## Cards are ints 0..51: rank = c % 13 (0 ace, 1..8 = 2..9, 9 ten, 10 J, 11 Q, 12 K),
## suit = c / 13 (0 spades, 1 hearts, 2 diamonds, 3 clubs).

enum Phase { BETTING, PLAYER, DEALER, DONE }

const DECKS := 6
const CUT := 78                        # fewer cards left than this: shuffle before the deal
## The chips by default (the table asks the bar for its own set: ClubBuilds.bar_chips()),
## and every chip there is a face for.
const CHIPS := [5, 25, 50, 100]
const ALL_CHIPS := [5, 10, 25, 50, 100, 250, 500, 1000]
const DEALER_STANDS := 17              # soft 17 too
## "N:1": the stake comes back plus N stakes.
const PERFECT_PAIRS := {"perfect": 25, "colored": 12, "mixed": 6}
const TWENTY_ONE_3 := {"suited_trips": 100, "straight_flush": 40, "trips": 25, "straight": 10, "flush": 5}
const PP_ORDER := ["perfect", "colored", "mixed"]
const T3_ORDER := ["suited_trips", "straight_flush", "trips", "straight", "flush"]
const NAMES := {
	"perfect": "Идеальная пара", "colored": "Пара одного цвета", "mixed": "Разноцветная пара",
	"suited_trips": "Тройка одной масти", "straight_flush": "Стрит-флеш", "trips": "Тройка",
	"straight": "Стрит", "flush": "Флеш",
}
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := ["♠", "♥", "♦", "♣"]

var rng := RandomNumberGenerator.new()
var shoe := PackedInt32Array()
var at := 0                            # the next card in the shoe
var shuffles := 0
var record_events := true              # off in the simulation
## What happened since the table last looked, in order: {"kind": "shuffle"},
## {"kind": "card", "to": "player"|"dealer", "hand": i, "card": c}, {"kind": "split"},
## {"kind": "double", "hand": i}, {"kind": "turn", "hand": i}, {"kind": "settle"}.
var events: Array = []

var phase := Phase.BETTING
## A hand: {cards, bet, doubled, split (came from a split), aces (split aces: closed),
## done, outcome ("blackjack" | "win" | "push" | "lose" | "bust" | ""), paid (stake included)}.
var hands: Array = []
var active := 0
var dealer: Array = []
var pp_bet := 0
var t3_bet := 0
var pp_hit := ""
var t3_hit := ""
var pp_paid := 0
var t3_paid := 0


## seed 0: shuffled from the clock (the table); any other: the same shoe every time (tests).
func _init(seed := 0) -> void:
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	shuffle()


# --- Cards ---------------------------------------------------------------------------

static func rank(c: int) -> int:
	return c % 13


static func suit(c: int) -> int:
	return c / 13


static func is_red(c: int) -> bool:
	return suit(c) == 1 or suit(c) == 2


static func value(c: int) -> int:
	var r := rank(c)
	return 11 if r == 0 else mini(r + 1, 10)


static func card_name(c: int) -> String:
	return RANKS[rank(c)] + SUITS[suit(c)]


static func _hard(cards: Array) -> int:
	var t := 0
	for c in cards:
		t += 1 if rank(c) == 0 else value(c)
	return t


static func _has_ace(cards: Array) -> bool:
	for c in cards:
		if rank(c) == 0:
			return true
	return false


## The best total: an ace counts 11 while that doesn't bust.
static func total(cards: Array) -> int:
	var t := _hard(cards)
	return t + 10 if _has_ace(cards) and t + 10 <= 21 else t


## An ace still counted as 11.
static func is_soft(cards: Array) -> bool:
	return _has_ace(cards) and _hard(cards) + 10 <= 21


static func is_blackjack(cards: Array) -> bool:
	return cards.size() == 2 and total(cards) == 21


# --- Side bets -----------------------------------------------------------------------

## The player's first two cards: "perfect" (same suit), "colored", "mixed" or "".
static func perfect_pairs(a: int, b: int) -> String:
	if rank(a) != rank(b):
		return ""
	if suit(a) == suit(b):
		return "perfect"
	return "colored" if is_red(a) == is_red(b) else "mixed"


## The player's two cards and the dealer's up card as a three-card poker hand. An ace is
## low (A-2-3) or high (Q-K-A), never round the corner (K-A-2).
static func twenty_one_3(a: int, b: int, up: int) -> String:
	var flush := suit(a) == suit(b) and suit(b) == suit(up)
	if rank(a) == rank(b) and rank(b) == rank(up):
		return "suited_trips" if flush else "trips"
	var r := [rank(a), rank(b), rank(up)]
	r.sort()
	var straight: bool = (r[1] == r[0] + 1 and r[2] == r[1] + 1) or r == [0, 11, 12]
	if straight and flush:
		return "straight_flush"
	if straight:
		return "straight"
	return "flush" if flush else ""


## Perfect Pairs' house edge from six decks, exactly (every pair of two cards).
static func exact_pp_edge() -> float:
	var n := DECKS * 52
	var all := n * (n - 1) / 2.0
	var same := DECKS * (DECKS - 1) / 2.0              # one rank and suit: C(6, 2)
	var perfect := 52 * same
	var colored := 13 * 2 * DECKS * DECKS              # the other suit of the same colour
	var mixed := 13 * 4 * DECKS * DECKS                # a suit of the other colour
	var won := perfect * PERFECT_PAIRS["perfect"] + colored * PERFECT_PAIRS["colored"] + mixed * PERFECT_PAIRS["mixed"]
	return -(won - (all - perfect - colored - mixed)) / all


## 21+3's house edge from six decks, exactly: every three cards of the 312.
static func exact_t3_edge() -> float:
	var n := DECKS * 52
	var all := n * (n - 1) * (n - 2) / 6.0
	var won := 0.0
	var hit := 0.0
	for i in 52:
		for j in range(i, 52):
			for k in range(j, 52):
				var ways := 0.0
				if i == j and j == k:
					ways = DECKS * (DECKS - 1) * (DECKS - 2) / 6.0
				elif i == j or j == k:
					ways = DECKS * (DECKS - 1) / 2.0 * DECKS
				else:
					ways = float(DECKS * DECKS * DECKS)
				var h := twenty_one_3(i, j, k)
				if h != "":
					won += ways * TWENTY_ONE_3[h]
					hit += ways
	return -(won - (all - hit)) / all


# --- The shoe ------------------------------------------------------------------------

func shuffle() -> void:
	shoe = PackedInt32Array()
	for d in DECKS:
		for c in 52:
			shoe.append(c)
	for i in range(shoe.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := shoe[i]
		shoe[i] = shoe[j]
		shoe[j] = t
	at = 0
	shuffles += 1


## Tests: these cards come first, in this order, then a shuffled shoe.
func set_shoe(cards: Array) -> void:
	shuffle()
	var s := PackedInt32Array(cards)
	s.append_array(shoe)
	shoe = s
	at = 0


func left() -> int:
	return shoe.size() - at


func needs_shuffle() -> bool:
	return left() < CUT


func used_this_round() -> int:
	var n := dealer.size()
	for h in hands:
		n += (h["cards"] as Array).size()
	return n


func _draw() -> int:
	if at >= shoe.size():
		shuffle()  # never reached with the cut at 1.5 decks; just in case
	var c := shoe[at]
	at += 1
	return c


func _event(e: Dictionary) -> void:
	if record_events:
		events.append(e)


func _give(i: int) -> void:
	var c := _draw()
	(hands[i]["cards"] as Array).append(c)
	_event({"kind": "card", "to": "player", "hand": i, "card": c})


func _give_dealer() -> void:
	var c := _draw()
	dealer.append(c)
	_event({"kind": "card", "to": "dealer", "hand": -1, "card": c})


static func _hand(bet: int) -> Dictionary:
	return {"cards": [], "bet": bet, "doubled": false, "split": false, "aces": false, "done": false, "outcome": "", "paid": 0}


# --- Gold rules (shared with Bets) ---------------------------------------------------

## The biggest main bet: the bar's limit and a quarter of the gold (as at the roulette).
static func max_bet(gold: int, limit: int, min_chip := 0) -> int:
	return mini(limit, Bets.max_stake(gold, min_chip))


static func chips_for(gold: int, limit: int, set: Array = CHIPS) -> Array:
	var m := max_bet(gold, limit, int(set[0]) if not set.is_empty() else 0)
	return set.filter(func(c): return c <= m)


# --- A round -------------------------------------------------------------------------

## Bets down, cards out: player, dealer (face up), player. Side bets are settled at once.
## false: a bet that can't go (none, a side bet over the main one, a hand still on).
func deal(bet: int, pp := 0, t3 := 0) -> bool:
	if phase == Phase.PLAYER or phase == Phase.DEALER:
		return false
	if bet <= 0 or pp < 0 or t3 < 0 or pp > bet or t3 > bet:
		return false
	events = []
	if needs_shuffle():
		shuffle()
		_event({"kind": "shuffle"})
	hands = [_hand(bet)]
	active = 0
	dealer = []
	pp_bet = pp
	t3_bet = t3
	_give(0)
	_give_dealer()
	_give(0)
	var cards: Array = hands[0]["cards"]
	pp_hit = perfect_pairs(cards[0], cards[1]) if pp > 0 else ""
	t3_hit = twenty_one_3(cards[0], cards[1], dealer[0]) if t3 > 0 else ""
	pp_paid = pp * (1 + int(PERFECT_PAIRS[pp_hit])) if pp_hit != "" else 0
	t3_paid = t3 * (1 + int(TWENTY_ONE_3[t3_hit])) if t3_hit != "" else 0
	phase = Phase.PLAYER
	if is_blackjack(cards):
		hands[0]["done"] = true
	_advance()
	return true


func _live() -> bool:
	return phase == Phase.PLAYER and active < hands.size() and not hands[active]["done"]


func can_hit() -> bool:
	return _live() and not hands[active]["aces"]


func can_stand() -> bool:
	return _live()


func can_double() -> bool:
	return _live() and (hands[active]["cards"] as Array).size() == 2 and not hands[active]["aces"]


## A pair of one value (any two tens too), once per round.
func can_split() -> bool:
	if not _live() or hands.size() != 1:
		return false
	var c: Array = hands[active]["cards"]
	return c.size() == 2 and value(c[0]) == value(c[1])


## What a double or a split costs on top (the hand's bet).
func extra_needed() -> int:
	return int(hands[active]["bet"]) if _live() else 0


func hit() -> bool:
	if not can_hit():
		return false
	_give(active)
	if total(hands[active]["cards"]) >= 21:
		hands[active]["done"] = true  # bust, or 21: it stands by itself
	_advance()
	return true


func stand() -> bool:
	if not can_stand():
		return false
	hands[active]["done"] = true
	_advance()
	return true


## The bet doubles, exactly one card.
func double() -> bool:
	if not can_double():
		return false
	hands[active]["bet"] = int(hands[active]["bet"]) * 2
	hands[active]["doubled"] = true
	_event({"kind": "double", "hand": active})
	_give(active)
	hands[active]["done"] = true
	_advance()
	return true


## Two hands of one card each, the same bet on the second. The first gets its card now,
## the second when its turn comes; split aces get one card each and close.
func split() -> bool:
	if not can_split():
		return false
	var c: Array = hands[0]["cards"]
	var aces := rank(c[0]) == 0
	var second := _hand(int(hands[0]["bet"]))
	second["cards"] = [c[1]]
	hands[0]["cards"] = [c[0]]
	for h in [hands[0], second]:
		h["split"] = true
		h["aces"] = aces
	hands.append(second)
	_event({"kind": "split"})
	_give(0)
	if aces:
		_give(1)
		hands[0]["done"] = true
		hands[1]["done"] = true
	elif total(hands[0]["cards"]) == 21:
		hands[0]["done"] = true
	_advance()
	return true


## On to the next hand that still plays (its second card first, after a split), else the
## dealer's turn.
func _advance() -> void:
	while active < hands.size():
		var h: Dictionary = hands[active]
		if (h["cards"] as Array).size() == 1:
			_give(active)
			if total(h["cards"]) == 21:
				h["done"] = true
		if not h["done"]:
			_event({"kind": "turn", "hand": active})
			return
		active += 1
	_dealer_turn()


func _dealer_turn() -> void:
	phase = Phase.DEALER
	_give_dealer()
	var live := false
	for h in hands:
		if total(h["cards"]) <= 21 and not (is_blackjack(h["cards"]) and not h["split"]):
			live = true
	if live and not is_blackjack(dealer):
		while total(dealer) < DEALER_STANDS:
			_give_dealer()
	_settle()


func _settle() -> void:
	var d := total(dealer)
	var dbj := is_blackjack(dealer)
	for h in hands:
		var t := total(h["cards"])
		var bet := int(h["bet"])
		var bj: bool = is_blackjack(h["cards"]) and not h["split"]
		var outcome := ""
		if t > 21:
			outcome = "bust"
		elif bj:
			outcome = "push" if dbj else "blackjack"
		elif dbj:
			outcome = "lose"  # no hole card: the dealer's blackjack takes doubles and splits too
		elif d > 21 or t > d:
			outcome = "win"
		elif t == d:
			outcome = "push"
		else:
			outcome = "lose"
		h["outcome"] = outcome
		match outcome:
			"blackjack":
				h["paid"] = bet + ceili(bet * 1.5)  # 3:2, a half rounded up for the player
			"win":
				h["paid"] = bet * 2
			"push":
				h["paid"] = bet
			_:
				h["paid"] = 0
		h["done"] = true
	active = hands.size()
	phase = Phase.DONE
	_event({"kind": "settle"})


## Everything the round staked (main bets with doubles and splits, side bets).
func staked() -> int:
	return main_staked() + pp_bet + t3_bet


func main_staked() -> int:
	var n := 0
	for h in hands:
		n += int(h["bet"])
	return n


## What comes back to the player (stakes included); side bets count from the deal.
func returned() -> int:
	return main_returned() + pp_paid + t3_paid


func main_returned() -> int:
	var n := 0
	for h in hands:
		n += int(h["paid"])
	return n


## A round left in the middle (the game was closed): every hand still on stands.
func finish_standing() -> void:
	while phase == Phase.PLAYER:
		stand()


# --- Saving a round in progress --------------------------------------------------------

func to_dict() -> Dictionary:
	return {"phase": int(phase), "hands": hands.duplicate(true), "active": active, "dealer": dealer.duplicate(),
		"pp_bet": pp_bet, "t3_bet": t3_bet, "pp_hit": pp_hit, "t3_hit": t3_hit, "pp_paid": pp_paid, "t3_paid": t3_paid}


## A saved round back on the table (its cards; the shoe is this table's own). false: none.
func from_dict(d: Dictionary) -> bool:
	if d.is_empty() or not d.has("hands"):
		return false
	phase = int(d.get("phase", Phase.BETTING)) as Phase
	hands = []
	for h in d["hands"]:
		var hh := _hand(int(h.get("bet", 0)))
		for k in hh:
			if h.has(k):
				hh[k] = h[k]
		hh["cards"] = (h.get("cards", []) as Array).map(func(x): return int(x))
		hands.append(hh)
	active = int(d.get("active", 0))
	dealer = (d.get("dealer", []) as Array).map(func(x): return int(x))
	pp_bet = int(d.get("pp_bet", 0))
	t3_bet = int(d.get("t3_bet", 0))
	pp_hit = String(d.get("pp_hit", ""))
	t3_hit = String(d.get("t3_hit", ""))
	pp_paid = int(d.get("pp_paid", 0))
	t3_paid = int(d.get("t3_paid", 0))
	events = []
	return not hands.is_empty()
