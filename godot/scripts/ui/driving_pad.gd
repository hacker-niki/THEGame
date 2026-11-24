extends TouchScreenButton

const LABEL = preload("res://assets/fonts/Roboto-Bold.ttf")
const INK = Color("#101320")
const MINT = Color("#95f6dd")
const PEACH = Color("#ffc195")
var hit_size := Vector2(150, 142)
var caption := ""


func configure(binding: String, text: String, extent := Vector2(150, 142)) -> void:
	action = binding
	caption = text
	hit_size = extent
	var area := RectangleShape2D.new()
	area.size = hit_size
	shape = area
	shape_centered = false
	shape_visible = false
	pressed.connect(queue_redraw)
	released.connect(queue_redraw)


func _draw() -> void:
	var color := PEACH if action == "brake_run" else MINT
	var down := is_pressed()
	var ink := INK if down else color
	var frame := Rect2(-hit_size / 2 + Vector2.ONE * 2, hit_size - Vector2.ONE * 4)
	draw_rect(frame, color if down else Color(0.045, 0.055, 0.09, 0.78))
	draw_rect(frame, color, false, 2, true)
	match action:
		"steer_left", "steer_right":
			var sign_x := -1.0 if action == "steer_left" else 1.0
			draw_polyline(PackedVector2Array([Vector2(-8 * sign_x, -13), Vector2(6 * sign_x, 0), Vector2(-8 * sign_x, 13)]), ink, 4.0, true)
		"brake_run":
			for i in 3:
				draw_line(Vector2(-14, -17 + 5 * i), Vector2(14, -17 + 5 * i), ink, 2.5, true)
	if not caption.is_empty():
		draw_string(LABEL, Vector2(-hit_size.x / 2.0, 17), caption, HORIZONTAL_ALIGNMENT_CENTER, hit_size.x, 15, ink)
