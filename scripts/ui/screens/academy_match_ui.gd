class_name AcademyMatchUi
## The booth's screens (spec 4): the list of matches that wait, a match's card, the result. On the
## TournamentUI frame like the other club screens. (Filled in below, T-4.)


static func result(ui: TournamentUI, res: Dictionary) -> void:
	ui._open(null, true, "menu")
	ui._title("%s %s" % [res.get("first_name", ""), res.get("score", "")])
