class_name AiVsAi
extends Node
## Autoplay "AI against AI" (D-6): no input, tiebreaks to 7 (the format of the academy's
## juniors, ACADEMY_LEGACY_TZ 6). Side A is the autoplay bot on the player's side with the skills
## of a profile; side B is OpponentAI with a stats dictionary. Prints every match and a total.
##   godot --headless --path . --fixed-fps 60 -- --ai-vs-ai --profile-a=lv=6,sd=0.05 --profile-b=rublev --matches=5
## --matches=N tiebreaks one after another (A serves first in the odd ones), --seed=S for the dice.
## Main only starts it (Main._ready, one line) and gives _start_practice a scoreboard.

const TIEBREAK_TO := 7

var main: Node
var profile_a := {}
var profile_b := {}
var matches := 1
var seed_v := -1
var _done := 0
var _a_wins := 0
var _points := 0
var _rallies := 0
var _rally_sum := 0
var _first_a := true
var _tags := ""


static func requested() -> bool:
	return "--ai-vs-ai" in OS.get_cmdline_user_args()


func start(m: Node) -> void:
	main = m
	var spec_a := "lv=4"
	var spec_b := "dzumhur"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile-a="):
			spec_a = a.substr(a.find("=") + 1)
		elif a.begins_with("--profile-b="):
			spec_b = a.substr(a.find("=") + 1)
		elif a.begins_with("--matches="):
			matches = maxi(1, int(a.get_slice("=", 1)))
		elif a.begins_with("--seed="):
			seed_v = int(a.get_slice("=", 1))
	profile_a = AiProfile.parse_player(spec_a)
	profile_b = AiProfile.parse_opponent(spec_b)
	AiProfile.apply_levels(profile_a["levels"])
	main._bot_sd = float(profile_a["sd"])
	main.autoplay_points = 1000000  # the match ends by the score, not by a point count
	if seed_v >= 0:
		main.rng.seed = seed_v
		main.ai.rng.seed = seed_v + 1
	GameEvents.match_started.connect(_on_match_started)  # after OpponentAI's own reset of its profile
	GameEvents.point.connect(_on_point)
	print("AI vs AI: A [%s]  vs  B %s (%s, skill %.2f, stats %s)" % [spec_a, profile_b["name"], profile_b.get("play_style", Opponents.DEFAULT_STYLE), float(profile_b["skill"]), str(profile_b["stats"])])
	_next_match()


func _next_match() -> void:
	_first_a = _done % 2 == 0
	main.cpu_label = String(profile_b["name"]).to_upper()
	main.cpu_call = main.cpu_label
	main._start_practice(MatchScore.new(1, 0, 0, main.Who.PLAYER if _first_a else main.Who.CPU, main.cpu_label))


func _process(_delta: float) -> void:
	# The booth watches the rally and the serve close, the whole court between the points.
	if main != null and main.cam != null and main.cam.booth:
		main.cam.booth_wide = main.phase != main.Phase.RALLY and main.phase != main.Phase.SERVE


func _on_match_started(_info: Dictionary) -> void:
	main.ai.set_profile(profile_b)
	main.ai.spared = 0.0  # a duel is not eased for a beginner
	Tuning.ai_skill = float(profile_b["skill"])


func _on_point(info: Dictionary) -> void:
	_points += 1
	_rallies += 1
	_rally_sum += int(info.get("rally", 0))
	# Main adds the point to the scoreboard after this signal: look at it a frame later.
	_check_end.call_deferred()


func _check_end() -> void:
	var sb: MatchScore = main.scoreboard
	if sb == null or not sb.is_over():
		return
	_done += 1
	var a_won: bool = sb.winner == main.Who.PLAYER
	if a_won:
		_a_wins += 1
	print("AIVSAI match %d: %s   (%s won; %s served first)" % [_done, sb.final_text(), "A" if a_won else "B", "A" if _first_a else "B"])
	if _done >= matches:
		print("\n=== AI VS AI ===\nA wins %d of %d tiebreaks   points %d   avg rally %.1f" % [_a_wins, _done, _points, float(_rally_sum) / maxf(_rallies, 1)])
		if main.metrics:
			print(main.metrics.report())
		main.get_tree().quit()
		return
	_next_match()
