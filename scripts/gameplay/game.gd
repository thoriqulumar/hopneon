extends Node2D

signal return_to_menu

const OBSTACLE_SCENE := preload("res://scenes/components/obstacle.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/game_over.tscn")
const NeonRunState := preload("res://scripts/gameplay/run_state.gd")
const NeonGameHud := preload("res://scripts/ui/game_hud.gd")
const NeonParticles := preload("res://scripts/components/neon_particles.gd")
const FLOOR_Y: float = 840.0
const PLAYER_SPAWN := Vector2(104.0, 805.0)
const SPAWN_X: float = 620.0
const FIRST_OBSTACLE_DISTANCE: float = 430.0
const SPAWN_SEED: int = 74821
const MIN_GAP_PIXELS: float = 500.0
const MAX_GAP_PIXELS: float = 650.0
const MAX_OBSTACLE_HEIGHT: float = 105.0

var run := NeonRunState.new()
var rng := RandomNumberGenerator.new()
var next_spawn_distance: float = FIRST_OBSTACLE_DISTANCE
var scroll_offset: float = 0.0
var game_over_overlay: Control
var settings_panel: Control

@onready var player: NeonPlayer = $Player
@onready var obstacles: Node2D = $Obstacles
@onready var effects: NeonParticles = $Effects
@onready var hud: NeonGameHud = %HudScript
@onready var collision_camera: Camera2D = $CollisionCamera

func _ready() -> void:
	player.died.connect(_end_run)
	player.jumped.connect(_on_player_jumped)
	hud.pause_requested.connect(_pause_run)
	hud.resume_requested.connect(_resume_run)
	hud.settings_requested.connect(_open_settings)
	GameState.progression_notice.connect(hud.show_notice)
	AdManager.reward_completed.connect(_on_reward_completed)
	_reset_run()

func _physics_process(delta: float) -> void:
	if not run.is_playing():
		return
	run.advance(delta)
	GameState.update_run(run.score, run.distance_pixels, run.elapsed_seconds)
	_update_obstacle_speeds()
	if run.distance_pixels >= next_spawn_distance:
		_spawn_obstacle()
	hud.set_score(run.score)
	hud.set_best(GameState.best_score)
	scroll_offset = fmod(scroll_offset + run.speed * delta * 0.22, 54.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	# Touch is handled natively below. Its emulated mouse event is only for UI.
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if is_instance_valid(settings_panel):
		return
	if event.is_action_pressed("ui_cancel") and run.phase in [NeonRunState.Phase.RUNNING, NeonRunState.Phase.PAUSED]:
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if not run.is_playing():
		return
	var touch_pressed: bool = event is InputEventScreenTouch and event.pressed
	if touch_pressed or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		player.request_jump()
		get_viewport().set_input_as_handled()

func _spawn_obstacle() -> void:
	var obstacle := OBSTACLE_SCENE.instantiate() as NeonObstacle
	var height := rng.randf_range(70.0, MAX_OBSTACLE_HEIGHT)
	obstacle.obstacle_size = Vector2(rng.randf_range(52.0, 70.0), height)
	obstacle.move_speed = run.speed
	obstacle.position = Vector2(SPAWN_X, FLOOR_Y - height * 0.5)
	obstacle.hit_player.connect(player.kill)
	obstacles.add_child(obstacle)
	# Heights remain below the configured jump arc, and there is only one
	# ground obstacle per gap. Even at maximum speed, the minimum spacing is
	# longer than a complete jump, guaranteeing time to land and jump again.
	var speed_ratio := inverse_lerp(NeonRunState.START_SPEED, NeonRunState.MAX_SPEED, run.speed)
	var difficulty_gap := lerpf(MAX_GAP_PIXELS, MIN_GAP_PIXELS, speed_ratio)
	var variation := rng.randf_range(0.0, 55.0)
	next_spawn_distance = run.distance_pixels + difficulty_gap + variation

func _update_obstacle_speeds() -> void:
	for child in obstacles.get_children():
		var obstacle := child as NeonObstacle
		if obstacle != null:
			obstacle.move_speed = run.speed

func _pause_run() -> void:
	if run.phase != NeonRunState.Phase.RUNNING:
		return
	run.toggle_pause()
	_set_world_paused(true)
	hud.set_paused(true)
	GameState.flush()

func _resume_run() -> void:
	if run.phase != NeonRunState.Phase.PAUSED:
		return
	run.toggle_pause()
	_set_world_paused(false)
	hud.set_paused(false)

func _toggle_pause() -> void:
	if run.phase == NeonRunState.Phase.RUNNING:
		_pause_run()
	elif run.phase == NeonRunState.Phase.PAUSED:
		_resume_run()

func _set_world_paused(value: bool) -> void:
	player.set_paused(value)
	effects.set_paused(value)
	for child in obstacles.get_children():
		var obstacle := child as NeonObstacle
		if obstacle != null:
			if value:
				obstacle.stop()
			else:
				obstacle.resume()

func _end_run() -> void:
	if run.phase == NeonRunState.Phase.GAME_OVER:
		return
	run.end_run()
	AdManager.game_over()
	Feedback.play_collision()
	collision_camera.shake()
	effects.emit_collision(player.position)
	_set_world_paused(true)
	effects.set_paused(false)
	# Keep this same progression run open while an optional continue is possible.
	GameState.update_run(run.score, run.distance_pixels, run.elapsed_seconds)
	GameState.flush()
	var is_new_best: bool = run.score > GameState.run_start_best
	game_over_overlay = GAME_OVER_SCENE.instantiate() as Control
	$CanvasLayer.add_child(game_over_overlay)
	game_over_overlay.call("setup", run.score, GameState.best_score, is_new_best)
	game_over_overlay.connect("retry_requested", _request_retry)
	game_over_overlay.connect("menu_requested", _request_menu)
	game_over_overlay.connect("continue_requested", _request_continue)

func _reset_run() -> void:
	if is_instance_valid(game_over_overlay):
		game_over_overlay.queue_free()
	game_over_overlay = null
	for child in obstacles.get_children():
		child.queue_free()
	rng.seed = SPAWN_SEED
	run.reset()
	run.start()
	AdManager.begin_run()
	GameState.begin_run()
	next_spawn_distance = FIRST_OBSTACLE_DISTANCE
	scroll_offset = 0.0
	player.reset_player(PLAYER_SPAWN)
	collision_camera.reset_shake()
	player.visual.set_cosmetic(str(GameState.data.selected), GameState.selected_color())
	player.visual.set_animation_paused(false)
	effects.clear()
	effects.set_paused(false)
	hud.reset()
	hud.set_best(GameState.best_score)
	queue_redraw()

func _request_retry() -> void:
	if AdManager.context != "game_over":
		return
	GameState.finish_run(run.score, run.distance_pixels, run.elapsed_seconds)
	AdManager.request_game_over_break(_reset_run)

func _request_menu() -> void:
	if AdManager.context != "game_over":
		return
	GameState.finish_run(run.score, run.distance_pixels, run.elapsed_seconds)
	AdManager.request_game_over_break(func() -> void: return_to_menu.emit())

func _request_continue() -> void:
	if run.phase == NeonRunState.Phase.GAME_OVER:
		AdManager.request_extra_life()

func _on_reward_completed(granted: bool) -> void:
	if not granted or run.phase != NeonRunState.Phase.GAME_OVER or not AdManager.reward_used:
		return
	# The completion callback was confirmed and the ad has closed. Preserve the
	# run's score, elapsed time, difficulty, RNG sequence, and progression snapshot.
	if is_instance_valid(game_over_overlay):
		game_over_overlay.queue_free()
	game_over_overlay = null
	for child in obstacles.get_children():
		obstacles.remove_child(child)
		child.queue_free()
	next_spawn_distance = run.distance_pixels + 360.0
	player.reset_player(PLAYER_SPAWN)
	collision_camera.reset_shake()
	effects.clear()
	run.phase = NeonRunState.Phase.RUNNING
	_set_world_paused(false)
	AdManager.resume_rewarded_run()
	hud.show_notice("EXTRA LIFE · KEEP HOPPING")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
		_pause_run()

func _on_player_jumped() -> void:
	effects.emit_jump(player.position, GameState.selected_color(), str(GameState.data.selected))
	Feedback.play_jump()

func _open_settings() -> void:
	if run.phase != NeonRunState.Phase.PAUSED or is_instance_valid(settings_panel):
		return
	settings_panel = Control.new()
	settings_panel.set_script(preload("res://scripts/ui/feedback_settings.gd"))
	$CanvasLayer.add_child(settings_panel)

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(0.0, FLOOR_Y, viewport_size.x, viewport_size.y - FLOOR_Y), Color("100a25"))
	draw_line(Vector2(0.0, FLOOR_Y), Vector2(viewport_size.x, FLOOR_Y), Color("16f4ff"), 4.0)
	for index in range(-1, 13):
		var x := float(index) * 54.0 - scroll_offset
		draw_line(Vector2(x, FLOOR_Y), Vector2(x - 32.0, viewport_size.y), Color(0.0, 0.9, 1.0, 0.13), 1.0)
	for index in range(4):
		var y := FLOOR_Y + float(index + 1) * 28.0
		draw_line(Vector2(0.0, y), Vector2(viewport_size.x, y), Color(0.0, 0.9, 1.0, 0.10), 1.0)
