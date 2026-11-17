extends Control

@export var grid_spacing: float = 54.0
@export var motion_speed: float = 10.0
var elapsed: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.02, 0.08, 0.62))
	var slow_offset := fmod(elapsed * motion_speed, grid_spacing)
	var y := -grid_spacing + slow_offset
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.0, 0.9, 1.0, 0.10), 1.0)
		y += grid_spacing
	var x := -grid_spacing + slow_offset * 0.55
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.0, 0.9, 1.0, 0.10), 1.0)
		x += grid_spacing
	var far_shift := fmod(elapsed * motion_speed * 0.18, size.x + 260.0)
	draw_circle(Vector2(size.x * 0.82 - far_shift * 0.08, size.y * 0.18), 130.0, Color(0.9, 0.1, 1.0, 0.075))
	draw_circle(Vector2(size.x * 0.12 + far_shift * 0.05, size.y * 0.76), 170.0, Color(0.0, 0.85, 1.0, 0.065))
	var horizon := size.y * 0.66
	for index in 14:
		var building_x := fmod(float(index) * 78.0 - elapsed * motion_speed * 0.28, size.x + 120.0) - 60.0
		var building_height := 35.0 + float((index * 37) % 85)
		draw_rect(Rect2(building_x, horizon - building_height, 50.0, building_height), Color(0.04, 0.03, 0.13, 0.72))
		draw_line(Vector2(building_x, horizon - building_height), Vector2(building_x + 50.0, horizon - building_height), Color(0.8, 0.1, 1.0, 0.18), 1.0)
