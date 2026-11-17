extends MarginContainer

@export var extra_padding: int = 20

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

func _apply_safe_area() -> void:
	var viewport_size := get_viewport_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_rect := DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe_rect.size == Vector2i.ZERO:
		_set_margins(extra_padding, extra_padding, extra_padding, extra_padding)
		return
	var scale := viewport_size / window_size
	var right_px := window_size.x - float(safe_rect.end.x)
	var bottom_px := window_size.y - float(safe_rect.end.y)
	_set_margins(maxi(0, int(float(safe_rect.position.x) * scale.x)) + extra_padding, maxi(0, int(float(safe_rect.position.y) * scale.y)) + extra_padding, maxi(0, int(right_px * scale.x)) + extra_padding, maxi(0, int(bottom_px * scale.y)) + extra_padding)

func _set_margins(left: int, top: int, right: int, bottom: int) -> void:
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
