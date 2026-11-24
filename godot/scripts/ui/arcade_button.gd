extends Button

const FACE = preload("res://assets/fonts/Roboto-Bold.ttf")
const MINT = Color("#95f6dd")
const PAPER = Color("#f6f4f2")
const INK = Color("#142129")
const MUTED = Color("#b7b9ca")

var glyph := ""
var variant := "row"
var detail := ""
var ordinal := ""


func configure(caption: String, icon: String, treatment: String, note: String = "", number: String = "") -> void:
	text = caption
	glyph = icon
	variant = treatment
	detail = note
	ordinal = number
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	add_theme_font_override("font", FACE)
	add_theme_font_size_override("font_size", 16 if variant == "link" else 21)
	var left := 50.0
	if variant in ["tab", "selected_tab"]:
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		left = 12.0
	elif variant == "link":
		left = 24.0
	elif variant == "track":
		left = 66.0
	elif variant == "primary":
		left = 54.0
	elif variant == "icon":
		left = 0.0
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.content_margin_left = left
		box.content_margin_right = 14
		var paper := PAPER
		var fill := Color(0.055, 0.067, 0.103, 0.86)
		var border := Color(0.52, 0.59, 0.67, 0.45)
		if variant == "primary":
			fill = MINT
			paper = INK
			border = MINT
		elif variant == "selected_tab":
			fill = Color("#25453f")
			paper = MINT
			border = MINT
		if variant == "link":
			fill = Color.TRANSPARENT
			border = Color.TRANSPARENT
			paper = MUTED
		if state == "hover" or state == "pressed" or state == "hover_pressed":
			if variant == "primary":
				fill = Color("#d6ffec") if state == "hover" else Color("#76d7c9")
				border = fill
			else:
				fill = Color("#263540") if variant != "link" else Color.TRANSPARENT
				paper = MINT
				border = MINT if variant != "link" else Color.TRANSPARENT
		if state == "disabled":
			fill = Color(0.06, 0.065, 0.10, 0.72)
			paper = Color("#9a99a9")
			border = Color("#45434f")
		if state == "focus":
			box.draw_center = false
			border = Color("#f6f5f0")
			if variant == "link":
				box.border_width_bottom = 1
			else:
				box.set_border_width_all(2)
				for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					box.set_expand_margin(edge, 3)
		else:
			box.set_border_width_all(0 if variant == "link" else 1)
			add_theme_color_override("font_color" if state == "normal" else "font_%s_color" % state, paper)
		box.bg_color = fill
		box.border_color = border
		add_theme_stylebox_override(state, box)
	add_theme_color_override("font_focus_color", INK if variant == "primary" else PAPER)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var color := INK if variant == "primary" else MINT
	if disabled:
		color = Color("#90909e")
	elif variant == "link" and not is_hovered() and not has_focus():
		color = MUTED
	var center := Vector2(26, size.y / 2.0)
	if variant == "link":
		center.x = 9
	elif variant == "icon":
		center.x = size.x / 2.0
	if variant == "track":
		draw_string(FACE, Vector2(17, center.y + 6), ordinal, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
		draw_line(Vector2(48, center.y - 9), Vector2(48, center.y + 9), Color("#565560"), 1.0)
	else:
		_draw_icon(center, color)
	if not detail.is_empty():
		var tone := Color("#c9cbd2") if not disabled else Color("#9b9aa7")
		var extent := FACE.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(FACE, Vector2(size.x - extent - 40, center.y + 5), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tone)
	if variant in ["row", "track", "primary"]:
		var p := Vector2(size.x - 24, center.y)
		if disabled and variant == "track":
			draw_arc(p - Vector2(0, 1), 3.6, PI, TAU, 10, color, 1.4, true)
			draw_rect(Rect2(p - Vector2(5, 1), Vector2(10, 8)), color, false, 1.4)
		else:
			draw_polyline(PackedVector2Array([p + Vector2(-3, -4), p + Vector2(1, 0), p + Vector2(-3, 4)]), color, 2.0, true)
			if variant == "primary":
				draw_line(p - Vector2(14, 0), p, color, 2.0, true)


func _draw_icon(p: Vector2, c: Color) -> void:
	match glyph:
		"music":
			draw_line(p + Vector2(-3,-5), p + Vector2(-3,6), c, 2.0, true)
			draw_line(p + Vector2(6,-8), p + Vector2(6,3), c, 2.0, true)
			draw_line(p + Vector2(-3,-5), p + Vector2(6,-8), c, 2.4, true)
			draw_circle(p + Vector2(-5,6), 3, c)
			draw_circle(p + Vector2(4,3), 3, c)
		"play":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -8), p + Vector2(7, 0), p + Vector2(-5, 8)]), c)
		"route":
			for shift in [-6, 0, 6]:
				draw_line(p + Vector2(-8, shift + 2), p + Vector2(5, shift + 2), c, 1.7, true)
			draw_line(p + Vector2(6, -5), p + Vector2(10, -5), c, 1.7, true)
		"settings":
			for shift in [-5, 4]:
				var x := -2 if shift < 0 else 4
				draw_line(p + Vector2(-9, shift), p + Vector2(9, shift), c, 1.7, true)
				draw_rect(Rect2(p + Vector2(x - 1.5, shift - 3), Vector2(3, 6)), c)
		"back":
			draw_polyline(PackedVector2Array([p + Vector2(2, -5), p + Vector2(-4, 0), p + Vector2(2, 5)]), c, 1.8, true)
			draw_line(p + Vector2(-3, 0), p + Vector2(7, 0), c, 1.8, true)
		"pause":
			for x in [-5, 2]:
				draw_rect(Rect2(p + Vector2(x, -7), Vector2(3, 14)), c)
		"sound":
			draw_polyline(PackedVector2Array([p + Vector2(-8,-3),p + Vector2(-4,-3),p + Vector2(2,-8),p + Vector2(2,8),p + Vector2(-4,3),p + Vector2(-8,3),p + Vector2(-8,-3)]), c, 1.5, true)
			draw_arc(p + Vector2(1, 0), 7, -0.8, 0.8, 9, c, 1.5, true)
		"retry":
			draw_arc(p, 7, -2.6, 2.6, 25, c, 1.8, true)
			draw_polyline(PackedVector2Array([p+Vector2(-7,-9),p+Vector2(-7,-3),p+Vector2(-1,-4)]), c, 1.8, true)
		"exit":
			draw_polyline(PackedVector2Array([p+Vector2(1,-7),p+Vector2(-6,-7),p+Vector2(-6,7),p+Vector2(1,7)]), c, 1.5, true)
			draw_line(p+Vector2(-1,0),p+Vector2(7,0),c,1.5,true)
			draw_polyline(PackedVector2Array([p+Vector2(4,-3),p+Vector2(7,0),p+Vector2(4,3)]),c,1.5,true)
		"info":
			draw_arc(p, 7, 0, TAU, 20, c, 1.4, true)
			draw_line(p+Vector2(0,-1),p+Vector2(0,4),c,1.5)
			draw_circle(p+Vector2(0,-4),1,c)
