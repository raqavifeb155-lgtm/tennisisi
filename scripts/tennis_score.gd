class_name TennisScore
extends RefCounted
## Standard tennis game scoring: 0/15/30/40, deuce, advantage, games.
## Index 0 = player, 1 = CPU (matches Main.Who). The server alternates every game.

var points := [0, 0]
var games := [0, 0]
var server := 0


## Even number of points played in the game = serve from the deuce (right) side.
func deuce_side() -> bool:
	return (points[0] + points[1]) % 2 == 0


## Adds a point; returns true if it finished a game.
func add_point(winner: int) -> bool:
	points[winner] += 1
	var other := 1 - winner
	if points[winner] >= 4 and points[winner] - points[other] >= 2:
		games[winner] += 1
		points = [0, 0]
		server = 1 - server
		return true
	return false


func point_text() -> String:
	var a: int = points[0]
	var b: int = points[1]
	if a >= 3 and b >= 3:
		if a == b:
			return "DEUCE"
		return "AD YOU" if a > b else "AD CPU"
	var names := ["0", "15", "30", "40"]
	return "YOU  %s : %s  CPU" % [names[a], names[b]]


func games_text() -> String:
	return "games %d–%d" % [games[0], games[1]]
