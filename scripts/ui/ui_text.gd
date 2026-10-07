class_name UiText
## Text that has to fit: the HUD's calls and names come in any length ("ACE!" or
## "BASILASHVILI DOUBLE FAULT"), and a label wider than the screen gets cut at both
## edges. Pick the size first, wrap only below the floor (UI_FLOW_TZ 5.2).


## The biggest size <= max_size at which every line of `text` is at most `width` wide;
## min_size when even that is too wide (the label wraps from there).
static func fit_size(font: Font, text: String, width: float, max_size: int, min_size: int) -> int:
	var s := max_size
	while s > min_size and not fits(font, text, width, s):
		s = maxi(s - 2, min_size)
	return s


static func fits(font: Font, text: String, width: float, size: int) -> bool:
	for line in text.split("\n"):
		if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			return false
	return true
