extends Control
## Uses the same visual as the playable character, including its actual glow.

const PlayerVisual := preload("res://scripts/components/player_visual.gd")
var color: Color = Color("16f4ff")
var equipped: bool = false
var cosmetic: String = "cyan"
var character: Node2D
var motion: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	character = Node2D.new()
	character.set_script(PlayerVisual)
	character.set_cosmetic(cosmetic, color)
	add_child(character)
	resized.connect(_layout_character)
	_layout_character()

func _layout_character() -> void:
	if character == null:
		return
	if motion != null:
		motion.kill()
	character.position = size * Vector2(0.5, 0.46)
	# Leave room for Gold's corona and trailing sparks in the small cards.
	character.scale = Vector2.ONE * minf(size.x / 115.0, 1.65)
	motion = create_tween().set_loops()
	motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(character, "position:y", character.position.y - 5.0, 1.3)
	motion.tween_property(character, "position:y", character.position.y, 1.3)
	queue_redraw()

func update_state(tint: Color, selected: bool, cosmetic_id: String = "cyan") -> void:
	color = tint
	equipped = selected
	cosmetic = cosmetic_id
	if character != null:
		character.set_cosmetic(cosmetic, color)
	queue_redraw()

func _draw() -> void:
	var center := size * Vector2(0.5, 0.46)
	var radius := minf(size.x * 0.38, size.y * 0.40)
	draw_circle(center, radius, Color(color, 0.045))
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.2 if equipped else 0.08), 1.0, true)
	draw_line(Vector2(size.x * 0.22, size.y * 0.88), Vector2(size.x * 0.78, size.y * 0.88), Color(color, 0.3), 2.0, true)
