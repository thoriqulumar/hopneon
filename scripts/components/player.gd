class_name NeonPlayer
extends CharacterBody2D

signal died
signal jumped

@export var jump_velocity: float = -700.0
@export var gravity: float = 1900.0
@export var max_fall_speed: float = 1050.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.13
var active: bool = true
var alive: bool = true
var paused: bool = false
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var squash_tween: Tween
@onready var visual: Node2D = $Visual

func _physics_process(delta: float) -> void:
	if not active or paused:
		return
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	if alive and jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_perform_jump()
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()
	if is_on_floor() and not was_on_floor and velocity.y >= 0.0:
		_animate_land()
	was_on_floor = is_on_floor()
	rotation = lerpf(rotation, clampf(velocity.y / 1300.0, -0.35, 0.55), delta * 8.0)
	if global_position.y > get_viewport_rect().size.y + 80.0:
		kill()

func request_jump() -> void:
	if alive and active and not paused:
		jump_buffer_timer = jump_buffer_time

func _perform_jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_animate_jump()
	jumped.emit()

func kill() -> void:
	if not alive:
		return
	alive = false
	active = true
	died.emit()

func reset_player(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	rotation = 0.0
	alive = true
	active = true
	paused = false
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	was_on_floor = false
	visual.scale = Vector2.ONE

func set_paused(value: bool) -> void:
	paused = value
	visual.set_animation_paused(value)
	if squash_tween != null and squash_tween.is_valid():
		if value:
			squash_tween.pause()
		else:
			squash_tween.play()

func _animate_jump() -> void:
	_start_squash(Vector2(0.76, 1.28), Vector2(1.08, 0.94), 0.08)

func _animate_land() -> void:
	_start_squash(Vector2(1.25, 0.72), Vector2(0.94, 1.08), 0.07)

func _start_squash(first_scale: Vector2, second_scale: Vector2, duration: float) -> void:
	if squash_tween != null and squash_tween.is_valid():
		squash_tween.kill()
	squash_tween = create_tween()
	squash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	squash_tween.tween_property(visual, "scale", first_scale, duration)
	squash_tween.tween_property(visual, "scale", second_scale, duration)
	squash_tween.tween_property(visual, "scale", Vector2.ONE, duration * 1.4)
