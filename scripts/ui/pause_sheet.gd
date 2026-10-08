class_name PauseSheet
extends UiSheet
## The short pause (UI_FLOW_TZ 6.1, owner's decision 2): the score, "Как играть" and
## "Настройки" side by side, a quiet "Выйти в клуб", and ПРОДОЛЖИТЬ under the thumb. A tap
## on the dimmed court is ПРОДОЛЖИТЬ too. Hud owns what each button does.

signal resume
signal help
signal settings
signal leave

var _score: Label
var _leave: Button


func _ready() -> void:
	super._ready()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	body.add_child(head)
	var title := label("Пауза", UiTheme.display(), UiTheme.T_TITLE, UiTheme.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_score = label("", UiTheme.display(), UiTheme.T_HEAD, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_score.autowrap_mode = TextServer.AUTOWRAP_OFF
	_score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_score)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	for pair in [["Как играть", help], ["Настройки", settings]]:
		var sig: Signal = pair[1]
		var b := button(pair[0], func() -> void: sig.emit())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_leave = button("Выйти в клуб", func() -> void: leave.emit(), "Quiet")
	actions.add_child(_leave)
	actions.add_child(button("ПРОДОЛЖИТЬ", func() -> void: resume.emit(), "Primary"))
	veil_tapped.connect(func() -> void: resume.emit())


## score: "6:4  3:2  30:40" ("" = none); can_leave: false in the trophy mini-game.
func show_pause(score: String, can_leave: bool) -> void:
	_score.text = score
	_leave.visible = can_leave
	open()
