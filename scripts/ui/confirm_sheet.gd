class_name ConfirmSheet
extends UiSheet
## "Are you sure?" from the bottom (UI_FLOW_TZ 5.5, rule 6): what is about to be lost, the
## safe choice in gold, the irreversible one beside it. A tap on the veil is the safe one.

signal answered(yes: bool)

var _title: Label
var _text: Label
var _yes: Button
var _no: Button


func _ready() -> void:
	super._ready()
	_title = label("", UiTheme.display(), UiTheme.T_HEAD, UiTheme.INK)
	body.add_child(_title)
	_text = label("", UiTheme.text(), UiTheme.T_BODY, UiTheme.MUTED)
	body.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	actions.add_child(row)
	_yes = button("", func() -> void: _answer(true))
	_yes.add_theme_color_override("font_color", UiTheme.LOSE)
	_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_yes)
	_no = button("", func() -> void: _answer(false), "Primary")
	_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_no)
	veil_tapped.connect(func() -> void: _answer(false))


## title: the question; text: what is lost; yes: the irreversible action; no: the way back.
func ask(title: String, text: String, yes: String, no: String) -> void:
	_title.text = title
	_text.text = text
	_yes.text = yes
	_no.text = no
	open()


func _answer(yes: bool) -> void:
	if not visible:
		return
	close()
	answered.emit(yes)
