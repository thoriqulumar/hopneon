extends Node

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const GAME_SCENE := preload("res://scenes/gameplay/game.tscn")

var current_screen: Node
var transitioning: bool = false
@onready var transition_rect: ColorRect = $TransitionLayer/TransitionRect

func _ready() -> void:
	transition_rect.modulate.a = 1.0
	show_menu()

func show_menu() -> void:
	if transitioning:
		return
	var menu := await _transition_to(MENU_SCENE.instantiate())
	menu.connect("play_requested", start_game)

func start_game() -> void:
	if transitioning or AdManager.privacy_busy or not AdManager.active.is_empty():
		return
	var game := await _transition_to(GAME_SCENE.instantiate())
	game.connect("return_to_menu", show_menu)

func _transition_to(next_screen: Node) -> Node:
	transitioning = true
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(current_screen):
		var fade_out := create_tween()
		fade_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_out.tween_property(transition_rect, "modulate:a", 1.0, 0.16)
		await fade_out.finished
		current_screen.free()
	current_screen = next_screen
	add_child(current_screen)
	move_child($TransitionLayer, get_child_count() - 1)
	var fade_in := create_tween()
	fade_in.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(transition_rect, "modulate:a", 0.0, 0.22)
	await fade_in.finished
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transitioning = false
	return current_screen
