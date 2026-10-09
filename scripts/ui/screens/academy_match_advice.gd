class_name AcademyAdvice
extends UiSheet
## The coach's pause in a student's match (spec 4): the match stands after a point, the sheet
## says why (the situation and the score), what the opponent is like (his style and weak spot,
## the card's line), and offers four setups. A pick is `picked(id)`; «Не спрашивать» turns the
## questions off (the autopilot decides, JuniorMatch.set_advice).

signal picked(id: String)
signal muted

var _title: Label
var _score: Label
var _opp: Label
var _buttons: Array[Button] = []
var _ids: Array = []
var _skip: Button


func _ready() -> void:
	super._ready()
	_title = label("", UiTheme.display(), UiTheme.T_HEAD, UiTheme.GOLD)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_title)
	_score = label("", UiTheme.text_bold(), UiTheme.T_BODY, UiTheme.INK)
	body.add_child(_score)
	_opp = label("", UiTheme.text(), UiTheme.T_SMALL + 2, UiTheme.MUTED)
	body.add_child(_opp)
	for i in 4:
		var b := button("", func() -> void: _pick(i))
		b.custom_minimum_size = Vector2(0, 104)
		b.clip_text = false
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UiTheme.T_BODY)
		actions.add_child(b)
		_buttons.append(b)
	_skip = button("Не спрашивать, пусть решает тренер", func() -> void: muted.emit(), "Quiet")
	actions.add_child(_skip)
	veil_tapped.connect(func() -> void: pass)   # a tap beside the sheet does not choose for you


## situation: JuniorBot.OFFER key; options: four setup ids; score_line: «Аня 2 : 5 Тайлер»; opp_line: what the card says of him.
func show_advice(situation: String, options: Array, score_line: String, opp_line: String) -> void:
	_title.text = "Тренерская пауза  ·  %s" % String(JuniorBot.SITUATION_TEXT.get(situation, ""))
	_score.text = score_line
	_opp.text = opp_line
	_ids = options
	for i in _buttons.size():
		var id := String(options[i])
		_buttons[i].text = "%s\n%s" % [JuniorBot.name_of(id), String(JuniorBot.STANCES[id]["hint"])]
	open()


func button_for(id: String) -> Button:
	var i := _ids.find(id)
	return _buttons[i] if i >= 0 else null


func _pick(i: int) -> void:
	if i < _ids.size():
		picked.emit(String(_ids[i]))
