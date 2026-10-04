class_name MatchScore
extends RefCounted
## Match scoring for every format: games (0/15/30/40, deuce, advantage), sets and
## tiebreaks to 7 (win by 2). Index 0 = player, 1 = opponent (matches Main.Who).
##
##   games_per_set = 0  -> every set is just a tiebreak (the quick format)
##   games_per_set = 4, tiebreak_at = 3 -> short sets: first to 4 games, tiebreak at 3:3
##   games_per_set = 6, tiebreak_at = 6 -> classic set, tiebreak at 6:6
## A set is won with games_per_set games and a two-game lead, or by the tiebreak.
## Serve: alternates every game. In a tiebreak the first server serves one point, then
## the serve changes every two points; the side alternates every point (even total =
## deuce side). Whoever received first in a tiebreak serves the next game.

enum Event { POINT, GAME, SET, MATCH }

const TIEBREAK_POINTS := 7

var sets_to_win := 1
var games_per_set := 0
var tiebreak_at := 0
var opponent_name := "CPU"

var points := [0, 0]
var games := [0, 0]
var sets := [0, 0]
var set_scores: Array = []        # finished sets: [player games, opponent games] (tiebreak-only: points)
var server := 0
var winner := -1
var in_tiebreak := false
var _tb_first := 0                # who served the first point of the current tiebreak


func _init(sets_needed := 1, games := 0, tb_at := 0, first_server := 0, opp := "CPU") -> void:
	sets_to_win = sets_needed
	games_per_set = games
	tiebreak_at = tb_at
	opponent_name = opp
	server = first_server
	in_tiebreak = games_per_set == 0
	_tb_first = first_server


func is_over() -> bool:
	return winner != -1


func deuce_side() -> bool:
	return (points[0] + points[1]) % 2 == 0


## Adds a point and returns what it finished (Event).
func add_point(w: int) -> int:
	if is_over():
		return Event.POINT
	points[w] += 1
	var lead: int = points[w] - points[1 - w]
	if in_tiebreak:
		if points[w] >= TIEBREAK_POINTS and lead >= 2:
			return _win_tiebreak(w)
		var n: int = points[0] + points[1]
		server = _tb_first if ((n + 1) / 2) % 2 == 0 else 1 - _tb_first
		return Event.POINT
	if points[w] >= 4 and lead >= 2:
		return _win_game(w)
	return Event.POINT


func _win_game(w: int) -> int:
	games[w] += 1
	points = [0, 0]
	server = 1 - server
	if games[w] >= games_per_set and games[w] - games[1 - w] >= 2:
		return _win_set(w, games.duplicate())
	if tiebreak_at > 0 and games[0] == tiebreak_at and games[1] == tiebreak_at:
		in_tiebreak = true
		_tb_first = server
	return Event.GAME


func _win_tiebreak(w: int) -> int:
	var score: Array = points.duplicate()
	points = [0, 0]
	if games_per_set == 0:
		_tb_first = 1 - _tb_first
		server = _tb_first
		return _win_set(w, score)
	games[w] += 1
	server = 1 - _tb_first
	return _win_set(w, games.duplicate())


func _win_set(w: int, score: Array) -> int:
	sets[w] += 1
	set_scores.append(score)
	games = [0, 0]
	in_tiebreak = games_per_set == 0
	if sets[w] >= sets_to_win:
		winner = w
		return Event.MATCH
	return Event.SET


## True when one more point for `w` wins the match ("МАТЧБОЛ").
func match_point_for(w: int) -> bool:
	if is_over():
		return false
	var c := MatchScore.new(sets_to_win, games_per_set, tiebreak_at, server, opponent_name)
	c.points = points.duplicate()
	c.games = games.duplicate()
	c.sets = sets.duplicate()
	c.in_tiebreak = in_tiebreak
	c._tb_first = _tb_first
	return c.add_point(w) == Event.MATCH


func point_text() -> String:
	var a: int = points[0]
	var b: int = points[1]
	if in_tiebreak:
		return "YOU  %d : %d  %s" % [a, b, opponent_name]
	if a >= 3 and b >= 3:
		if a == b:
			return "DEUCE"
		return "AD YOU" if a > b else "AD " + opponent_name
	var names := ["0", "15", "30", "40"]
	return "YOU  %s : %s  %s" % [names[a], names[b], opponent_name]


func games_text() -> String:
	if games_per_set == 0:
		return "тай-брейк до 7" if sets_to_win == 1 else "тай-брейки %d–%d" % [sets[0], sets[1]]
	var s := "геймы %d–%d" % [games[0], games[1]]
	if in_tiebreak:
		s = "ТАЙ-БРЕЙК"
	if sets_to_win > 1:
		s = "сеты %d–%d  ·  %s" % [sets[0], sets[1], s]
	return s


## "4:2 · 3:4 · 4:1" for the result screen.
func final_text() -> String:
	var parts: Array[String] = []
	for s in set_scores:
		parts.append("%d:%d" % [s[0], s[1]])
	return " · ".join(parts)
