class_name MatchTally
extends RefCounted
## The match's numbers for the result screen (HANDOFF 7.3): you on the left, the opponent
## on the right. Fed with GameEvents payloads (Hud connects them): `match_started` ->
## start(), `shot`, `fault`, `point`, `match_finished` -> finish(). Index 0 = the player,
## 1 = the opponent (Main.Who). Pure data: no nodes, so tests feed it by hand.
##
## Unforced error: a point lost by an out or the net (not a serve) off a ball that came in
## slower than UNFORCED_BELOW (no pressure, see Main.error_chance); off a faster ball it
## was forced. First serve %: own service points where the first serve went in.

const UNFORCED_BELOW := 24.0       # m/s (~86 km/h)

var on := false
var forehands := [0, 0]
var backhands := [0, 0]
var aces := [0, 0]
var doubles := [0, 0]
var winners := [0, 0]
var unforced := [0, 0]
var serve_points := [0, 0]
var first_faults := [0, 0]
var best_rally := 0
var points := 0
var _incoming := [-1.0, -1.0]     # the speed of the ball each side last hit this point (-1: none)


func start() -> void:
	forehands = [0, 0]
	backhands = [0, 0]
	aces = [0, 0]
	doubles = [0, 0]
	winners = [0, 0]
	unforced = [0, 0]
	serve_points = [0, 0]
	first_faults = [0, 0]
	best_rally = 0
	points = 0
	_incoming = [-1.0, -1.0]
	on = true


func finish() -> void:
	on = false


## Any shot: info has side (+1 forehand, -1 backhand), serve, incoming (m/s).
func shot(who: int, info: Dictionary) -> void:
	if not on or who < 0 or who > 1:
		return
	if info.get("serve", false):
		return
	if int(info.get("side", 1)) >= 0:
		forehands[who] += 1
	else:
		backhands[who] += 1
	_incoming[who] = float(info.get("incoming", 0.0))


## A serve that missed: server, second (the second serve, a double fault follows).
func fault(info: Dictionary) -> void:
	if not on:
		return
	var s := int(info.get("server", -1))
	if s >= 0 and s <= 1 and not info.get("second", false):
		first_faults[s] += 1


## A point is over: winner, reason, rally, server (GameEvents.point).
func point(info: Dictionary) -> void:
	if not on:
		return
	var w := int(info.get("winner", 0))
	var l := 1 - w
	var s := int(info.get("server", 0))
	if s >= 0 and s <= 1:
		serve_points[s] += 1
	points += 1
	best_rally = maxi(best_rally, int(info.get("rally", 0)))
	match String(info.get("reason", "")):
		"ACE":
			aces[w] += 1
		"WINNER":
			winners[w] += 1
		"DOUBLE FAULT":
			doubles[l] += 1
		"OUT", "NET":
			if _incoming[l] >= 0.0 and _incoming[l] < UNFORCED_BELOW:
				unforced[l] += 1
	_incoming = [-1.0, -1.0]


## Share of own service points where the first serve went in, 0..100; -1 = never served.
func first_serve_pct(who: int) -> int:
	if serve_points[who] <= 0:
		return -1
	return clampi(roundi(100.0 * (serve_points[who] - first_faults[who]) / serve_points[who]), 0, 100)


func has_data() -> bool:
	return points > 0


## [caption, you, them] for the screen.
func rows() -> Array:
	var pct := func(who: int) -> String:
		var p := first_serve_pct(who)
		return "—" if p < 0 else "%d%%" % p
	return [
		["Эйсы", str(aces[0]), str(aces[1])],
		["Двойные", str(doubles[0]), str(doubles[1])],
		["Виннеры", str(winners[0]), str(winners[1])],
		["Невынужденные", str(unforced[0]), str(unforced[1])],
		["Первая подача", pct.call(0), pct.call(1)],
		["Форхенды", str(forehands[0]), str(forehands[1])],
		["Бэкхенды", str(backhands[0]), str(backhands[1])],
	]
