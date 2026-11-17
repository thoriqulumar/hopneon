extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var state := root.get_node("GameState")
	state.store.save_path = "user://neon_hop_test_core.json"
	state.load_progress()
	var packed := load("res://scenes/gameplay/game.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	for frame in 20:
		await physics_frame
	_check(game.run.phase == 1, "run starts in RUNNING state")
	_check(is_equal_approx(game.run.speed, minf(315.0 + game.run.distance_pixels * 0.012, 560.0)), "speed scales with distance")
	_check(game.player.is_on_floor(), "player settles on floor")

	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	game.call("_unhandled_input", emulated_mouse)
	_check(game.player.jump_buffer_timer == 0.0, "emulated touch mouse does not trigger a duplicate jump")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	game.call("_unhandled_input", touch)
	_check(game.player.jump_buffer_timer > 0.0, "native Android touch buffers a jump")
	await physics_frame
	_check(game.player.velocity.y < 0.0, "buffered jump produces upward velocity")
	_check(game.effects.particles.size() > 0, "jump signal emits particles")

	game.call("_pause_run")
	_check(game.run.phase == 2 and game.player.paused, "pause freezes run and player")
	game.call("_open_settings")
	_check(is_instance_valid(game.settings_panel), "sound controls open while paused")
	game.settings_panel.call("_close")
	await process_frame
	_check(game.run.phase == 2, "closing sound controls keeps gameplay paused")
	game.call("_resume_run")
	_check(game.run.phase == 1 and not game.player.paused, "resume restores run and player")

	game.call("_spawn_obstacle")
	var first: Variant = game.obstacles.get_child(0)
	var first_size: Vector2 = first.obstacle_size
	game.call("_reset_run")
	await process_frame
	game.call("_spawn_obstacle")
	var deterministic: Variant = game.obstacles.get_child(0)
	_check(deterministic.obstacle_size == first_size, "spawn sequence resets deterministically")
	_check(deterministic.obstacle_size.y <= 105.0, "obstacle remains below jumpable height")
	_check(game.next_spawn_distance - game.run.distance_pixels >= 500.0, "spawn gap remains achievable")
	if not state.data.unlocked.has("gold"):
		state.data.unlocked.append("gold")
	state.select_cosmetic("gold")

	deterministic.emit_signal("hit_player")
	_check(game.run.phase == 3 and is_instance_valid(game.game_over_overlay), "collision ends run and opens game over")
	_check(game.effects.particles.size() >= 20, "collision signal emits burst particles")
	_check(game.collision_camera.remaining > 0.0, "collision starts a bounded camera shake")
	game.game_over_overlay.emit_signal("retry_requested")
	await process_frame
	_check(game.run.phase == 1 and game.run.score == 0, "retry resets the run in place")
	_check(game.player.visual.cosmetic == "gold", "equipped tier effects are applied in actual gameplay")
	game.player.jumped.emit()
	_check(game.effects.particles.size() == 13 and game.effects.particles[0].color == state.COSMETIC_COLORS.gold, "gold jump emits its upgraded colored burst")
	_check(game.collision_camera.offset == Vector2.ZERO and game.collision_camera.remaining == 0.0, "retry immediately restores camera alignment")
	root.get_node("Feedback").stop_all()
	await create_timer(0.15).timeout

	if failures.is_empty():
		print("CORE GAMEPLAY TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
