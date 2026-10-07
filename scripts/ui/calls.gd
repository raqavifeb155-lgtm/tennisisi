class_name Calls
## The umpire's calls on the court, the way TV shows them: English, upper case, one
## language per line (UI_FLOW_TZ 5.6, the owner's choice). Hints, level-ups and menus
## stay Russian; this is only the shouted part. `cpu` is the opponent's Latin short name
## (Opponents.ROSTER "short_en", "CPU" in practice).

const LET := "LET"
const TOSS_AGAIN := "TOSS AGAIN"


## A point's verdict, from the reason Main._end_point gives it (OUT, NET, WINNER, ACE,
## DOUBLE FAULT) and who won it.
static func point(player_won: bool, reason: String, cpu: String) -> String:
	if player_won:
		return {"OUT": cpu + " OUT", "NET": cpu + " NET", "WINNER": "WINNER!", "ACE": "ACE!",
			"DOUBLE FAULT": cpu + " DOUBLE FAULT"}.get(reason, reason)
	return {"OUT": "OUT", "NET": "NET", "WINNER": "MISSED", "ACE": cpu + " ACE",
		"DOUBLE FAULT": "DOUBLE FAULT"}.get(reason, reason)


## The second line when the point closed a game, a set or the match; "" for a point.
static func score(event: int, player_won: bool, cpu: String) -> String:
	var who := "YOU" if player_won else cpu
	match event:
		MatchScore.Event.GAME:
			return "GAME · " + who
		MatchScore.Event.SET:
			return "SET · " + who
		MatchScore.Event.MATCH:
			return "MATCH · " + who
	return ""


static func fault(kind: String) -> String:
	return "NET · FAULT" if kind == "NET" else "FAULT"
