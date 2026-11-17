class_name NeonObstacle
extends Area2D

signal hit_player
signal cleared

@export var move_speed: float = 330.0
var running: bool = true
var was_cleared: bool = false
var obstacle_size: Vector2 = Vector2(62.0, 96.0)
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var shape := RectangleShape2D.new()
	shape.size = obstacle_size
	collision_shape.shape = shape
	queue_redraw()

func _process(delta: float) -> void:
	if not running:
		return
	position.x -= move_speed * delta
	if not was_cleared and position.x < 104.0:
		was_cleared = true
		cleared.emit()
	if position.x < -100.0:
		queue_free()

func stop() -> void:
	running = false

func resume() -> void:
	running = true

func _on_body_entered(body: Node2D) -> void:
	if running and body is NeonPlayer:
		hit_player.emit()

func _draw() -> void:
	var rect := Rect2(-obstacle_size * 0.5, obstacle_size)
	draw_rect(rect.grow(8.0), Color(1.0, 0.1, 0.8, 0.11))
	draw_rect(rect, Color("2a0a48"))
	draw_rect(rect.grow(3.0), Color(0.55, 0.08, 0.9, 0.18), false, 7.0)
	draw_rect(rect, Color("ff2bd6"), false, 4.0)
	var spike_width := obstacle_size.x / 3.0
	for index in 3:
		var left := rect.position.x + float(index) * spike_width
		var points := PackedVector2Array([Vector2(left, rect.position.y), Vector2(left + spike_width * 0.5, rect.position.y - 18.0), Vector2(left + spike_width, rect.position.y)])
		draw_colored_polygon(points, Color("ff2bd6"))
	for stripe_y in range(int(rect.position.y + 15.0), int(rect.end.y), 22):
		draw_line(Vector2(rect.position.x + 8.0, stripe_y), Vector2(rect.end.x - 8.0, stripe_y), Color(0.0, 0.9, 1.0, 0.55), 2.0)
