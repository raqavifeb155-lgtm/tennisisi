extends Node
## The match's events, for systems that react to play without living inside Main:
## style points, gear effects, opponent stamina as HP, the betting desk, the club.
## Main emits; anyone connects (GameEvents.point.connect(...)). Autoload "GameEvents".
## Payloads are plain Dictionaries so new fields can be added without breaking anyone.
## Who: 0 = player, 1 = CPU (Main.Who).

## Any shot launched (both sides), after the ball leaves the racket.
##   contact: Vector3, speed: m/s, top: spin (rpm-ish, + topspin / - backspin), q: 0..1,
##   lob, drop: bool
signal shot(who: int, info: Dictionary)

## The player's own stroke or serve, with what the swipe meant.
##   type: "TOPSPIN" | "FLAT" | "SLICE" | "DROP SHOT" | "LOB" | "SMASH" | "SERVE"
##   label: "PERFECT" | "GOOD" | "EARLY" | "LATE", kmh, q, curl_k, volley, smash, diving,
##   serve, skill (Skills id), side (+1 forehand / -1 backhand)
signal player_stroke(info: Dictionary)

## The ball bounced. pos, speed, bounces (since the last hit), last_hitter
signal bounce(info: Dictionary)

## A point is over. winner, reason ("WINNER" | "ACE" | "OUT" | "NET" | "DOUBLE FAULT"),
## rally (hits), server, close_call ({} or the line call: margin m, axis), best (bool)
signal point(info: Dictionary)

## A player was knocked off balance by a heavy ball (who).
signal knocked(who: int)

## A match starts (tournament or practice): {"tournament": bool, "opponent": id or ""}
signal match_started(info: Dictionary)

## A match is over: {"won": bool, "score": "6:3", "tournament": bool}
signal match_finished(info: Dictionary)
