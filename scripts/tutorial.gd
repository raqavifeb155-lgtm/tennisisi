class_name Tutorial
extends Control
## First-launch tutorial: a few cards with animated drawings instead of permanent
## on-screen hints. Pauses the game while open; reopen it from the settings panel.

signal finished

const DONE_FILE := "user://tutorial_done_v2"  # v2: joystick controls
const PAGES := [
	{
		"title": "Бег",
		"text": "Большой палец левой руки — внизу, под игроком: это джойстик. Веди пальцем, и игрок бежит.\nОтпустишь — он сам подстроится под мяч. Режим управления меняется в меню и в «НАСТР».",
		"pic": "run",
	},
	{
		"title": "Удар",
		"text": "Правым пальцем свайпни выше игрока: мяч полетит по этой линии от игрока. Чем быстрее свайп, тем сильнее удар.\nБей, когда кольцо сожмётся до круга: будет PERFECT.",
		"pic": "ring",
	},
	{
		"title": "Вращение",
		"text": "Форма свайпа задаёт удар. Вверх — атака, вниз — подрезка:\nвверх прямо — FLAT, быстрый и низкий;\nвверх и выкрут в конце — TOPSPIN: ныряет и прыгает, чем сильнее выкрут, тем злее;\nвниз — SLICE, режет и стелется (почти вертикально — прямо, наискосок — в сторону);\nкороткий вниз — УКОРОЧЕННЫЙ: падает сразу за сеткой;\nмедленно вверх по дуге — СВЕЧА, высоко над соперником у сетки.",
		"pic": "spin",
	},
	{
		"title": "Подача",
		"text": "Встань в другое место за линией: джойстиком или тапом ниже игрока (держи палец — идёт за ним). Тап по корту — подброс. Свайп в диагональный квадрат, когда кольцо сожмётся.\nПрямо вверх — плоская (до 200+ км/ч), вверх с выкрутом — кик, вниз — резаная, уходит в сторону.\nКороткий свайп вниз ДО подброса (как укороченный) — подача снизу, как у Бублика.",
		"pic": "serve",
	},
	{
		"title": "У сетки",
		"text": "Подбеги к сетке джойстиком: мячи до отскока станут ударом с лёта.\nВысокий мяч над головой — смэш.",
		"pic": "net",
	},
]

const TAP_RUN_TEXT := "Тапни по корту — игрок побежит туда. Держи палец — бежит за пальцем.\nОтпустишь — он сам подстроится под мяч. Режим управления меняется в меню и в «НАСТР»."

var _page := 0
var _t := 0.0
var _card: PanelContainer
var _title: Label
var _text: Label
var _pic: Control
var _dots: Label
var _next: Button


static func is_done() -> bool:
	return FileAccess.file_exists(DONE_FILE)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -300.0
	_card.offset_right = 300.0
	_card.offset_top = -380.0
	_card.offset_bottom = 380.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.16, 0.96)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(26)
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_card.add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_pic = Control.new()
	_pic.custom_minimum_size = Vector2(540, 300)
	_pic.draw.connect(_draw_pic)
	v.add_child(_pic)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 25)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(540, 200)
	v.add_child(_text)
	_dots = Label.new()
	_dots.add_theme_font_size_override("font_size", 26)
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_dots)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(540, 70)
	_next.add_theme_font_size_override("font_size", 28)
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(_advance)
	v.add_child(_next)
	_show_page()
	get_viewport().size_changed.connect(_layout)


## Centre the card and shrink it to fit any screen (phone browsers, in-app viewers,
## landscape windows), instead of trusting fixed offsets.
func _layout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card.scale = Vector2.ONE
	_card.size = Vector2.ZERO
	var need := _card.get_combined_minimum_size()
	_card.size = need
	var k := minf(1.0, minf((vp.x - 24.0) / need.x, (vp.y - 24.0) / need.y))
	_card.scale = Vector2(k, k)
	_card.position = ((vp - need * k) * 0.5).floor()
	queue_redraw()


func open() -> void:
	_page = 0
	_show_page()
	visible = true
	get_tree().paused = true


func _advance() -> void:
	_page += 1
	if _page >= PAGES.size():
		visible = false
		get_tree().paused = false
		var f := FileAccess.open(DONE_FILE, FileAccess.WRITE)
		if f:
			f.store_string("1")
		finished.emit()
		return
	_show_page()


func _show_page() -> void:
	var p: Dictionary = PAGES[_page]
	_title.text = p["title"]
	_text.text = TAP_RUN_TEXT if p["pic"] == "run" and Tuning.tap_controls else p["text"]
	_dots.text = "%d / %d" % [_page + 1, PAGES.size()]
	_next.text = "ИГРАТЬ" if _page == PAGES.size() - 1 else "ДАЛЬШЕ"
	_t = 0.0
	_layout.call_deferred()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_pic.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))


# --- Drawings -------------------------------------------------------------------

const C_COURT := Color(0.2, 0.38, 0.66)
const C_LINE := Color(0.95, 0.95, 0.95)
const C_ACCENT := Color(1.0, 0.85, 0.25)
const C_FINGER := Color(0.6, 0.95, 1.0)


func _draw_pic() -> void:
	var sz := _pic.size
	var c := sz * 0.5
	match PAGES[_page]["pic"]:
		"run" when Tuning.tap_controls:
			# Tap mode: a finger taps a spot on the court, the player runs there.
			_court(sz)
			var u := fmod(_t, 2.4) / 2.4
			var spots := [Vector2(c.x + 140, sz.y - 120), Vector2(c.x - 140, sz.y - 90)]
			var k := int(fmod(_t, 4.8) / 2.4)
			var target: Vector2 = spots[k]
			var from: Vector2 = spots[1 - k]
			var player := from.lerp(target, clampf((u - 0.15) / 0.6, 0.0, 1.0))
			_pic.draw_circle(player, 16, Color(0.92, 0.36, 0.26))
			if u < 0.5:
				_pic.draw_arc(target, 18 + u * 30, 0, TAU, 32, Color(C_FINGER, 1.0 - u * 2.0), 4)
				_pic.draw_circle(target, 14, C_FINGER)
		"run":
			# The court above, the joystick under the player: the thumb slides, he runs.
			var court := Vector2(sz.x, sz.y - 95)
			_court(court)
			var u := fmod(_t, 3.0) / 3.0
			var dir := Vector2(cos(u * TAU), sin(u * TAU) * 0.5)
			var player := Vector2(c.x, court.y - 40) + dir * Vector2(110, 30)
			_pic.draw_circle(player, 16, Color(0.92, 0.36, 0.26))
			var stick := Vector2(c.x, sz.y - 46)
			_pic.draw_circle(stick, 44, Color(0, 0, 0, 0.3))
			_pic.draw_arc(stick, 44, 0, TAU, 40, Color(1, 1, 1, 0.5), 3)
			_pic.draw_circle(stick + dir * Vector2(26, 40), 20, C_FINGER)
		"ring":
			_court(sz)
			var spot := Vector2(c.x + 40, sz.y - 90)
			var u := fmod(_t, 2.2) / 2.2
			var r := lerpf(110.0, 30.0, minf(u * 1.3, 1.0))
			_pic.draw_arc(spot, 30, 0, TAU, 40, Color(1, 1, 1, 0.7), 4)
			_pic.draw_arc(spot, r, 0, TAU, 48, C_ACCENT if r < 36 else Color.WHITE, 6)
			if r < 36:
				var a := Vector2(c.x - 60, sz.y - 30)
				_arrow(a, a + Vector2(30, -170), C_FINGER)
				_pic.draw_string(get_theme_default_font(), Vector2(spot.x + 50, spot.y - 40), "PERFECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, C_ACCENT)
		"spin":
			var w := sz.x / 5.0
			var names := ["FLAT", "TOPSPIN", "SLICE", "DROP", "LOB"]
			for i in 5:
				var base := Vector2(w * i + w * 0.5, sz.y - 50)
				# The lob is drawn slowly: speed is what makes it a lob.
				var pts := _gesture(i, base, minf(fmod(_t, 1.8) / (1.6 if i == 4 else 0.9), 1.0))
				if pts.size() > 1:
					_pic.draw_polyline(pts, C_FINGER, 7, true)
					_pic.draw_circle(pts[pts.size() - 1], 9, C_FINGER)
				_pic.draw_string(get_theme_default_font(), Vector2(base.x - w * 0.5, sz.y - 8), names[i], HORIZONTAL_ALIGNMENT_CENTER, w, 22, C_ACCENT)
		"serve":
			_court(sz)
			var server := Vector2(c.x + 60, sz.y - 40)
			var u := fmod(_t, 2.4) / 2.4
			var ball_y := server.y - 40 - sin(clampf(u * 1.6, 0.0, 1.0) * PI) * 110
			_pic.draw_circle(server, 16, Color(0.92, 0.36, 0.26))
			_pic.draw_circle(Vector2(server.x, ball_y), 8, Color(0.86, 0.95, 0.2))
			# Diagonal service box on the far side
			var box := Rect2(Vector2(c.x - 150, 40), Vector2(140, 70))
			_pic.draw_rect(box, Color(C_ACCENT, 0.25))
			_pic.draw_rect(box, C_ACCENT, false, 3)
			if u > 0.55:
				_arrow(server, box.get_center(), C_FINGER)
		"net":
			_court(sz)
			var u := fmod(_t, 2.0) / 2.0
			var p := Vector2(c.x, sz.y - 50).lerp(Vector2(c.x + 20, 150), minf(u * 1.5, 1.0))
			_pic.draw_circle(p, 16, Color(0.92, 0.36, 0.26))
			_pic.draw_circle(Vector2(c.x + 70, 110 + sin(_t * 6.0) * 6), 8, Color(0.86, 0.95, 0.2))


func _court(sz: Vector2) -> void:
	var top := 30.0
	var bot := sz.y - 10.0
	var poly := PackedVector2Array([Vector2(sz.x * 0.3, top), Vector2(sz.x * 0.7, top), Vector2(sz.x * 0.95, bot), Vector2(sz.x * 0.05, bot)])
	_pic.draw_colored_polygon(poly, C_COURT)
	_pic.draw_polyline(poly + PackedVector2Array([poly[0]]), C_LINE, 3)
	var net_y := lerpf(top, bot, 0.42)
	_pic.draw_line(Vector2(sz.x * 0.15, net_y), Vector2(sz.x * 0.85, net_y), Color(0.1, 0.1, 0.12), 6)


func _gesture(kind: int, base: Vector2, progress: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := int(30 * progress)
	for i in n + 1:
		var u := float(i) / 30.0
		match kind:
			0:
				# FLAT: straight up.
				pts.append(base + Vector2(6 * u, -200 * u))
			1:
				# TOPSPIN: up, then the turn of the wrist over to the side and down.
				if u < 0.7:
					pts.append(base + Vector2(0, -200 * u / 0.7))
				else:
					var a := (u - 0.7) / 0.3 * PI * 0.5
					pts.append(base + Vector2(40 * sin(a), -200 + 40 * (1.0 - cos(a))))
			2:
				# SLICE: cut down from high on the left to low on the right.
				pts.append(base + Vector2(-35 + 60 * u, -200 + 180 * u))
			3:
				# DROP: a short stroke down.
				pts.append(base + Vector2(8 * sin(u * PI), -110 + 60 * u))
			_:
				# LOB: a slow scoop up along an arc.
				pts.append(base + Vector2(-38 * sin(u * PI), -200 * u))
	return pts


func _dashed(a: Vector2, b: Vector2) -> void:
	var n := 14
	for i in n:
		if i % 2 == 0:
			_pic.draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(1, 1, 1, 0.6), 3)


func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	_pic.draw_line(a, b, col, 6)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	_pic.draw_colored_polygon(PackedVector2Array([b + d * 16, b - d * 6 + n * 13, b - d * 6 - n * 13]), col)
