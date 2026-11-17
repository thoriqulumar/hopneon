extends SceneTree

const Manager := preload("res://tests/ad_manager_fixture.gd")
const Fake := preload("res://tests/fake_ad_provider.gd")
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	create_timer(10.0).timeout.connect(func() -> void: quit(1))
	_check(root.get_node("AdManager").provider == null, "default desktop profile never initializes a plugin")
	var manager := Manager.new()
	root.add_child(manager)
	manager.set_process(false)
	var fake := Fake.new()
	manager._bind_provider(fake)
	manager.enter_menu()
	manager._process(2.0)
	_check(fake.consent_calls == 1 and fake.init_calls == 0 and fake.load_calls.is_empty(), "no initialization or ad requests before consent")
	fake.consent_resolved.emit(false, false)
	manager._process(2.0)
	_check(fake.load_calls.is_empty(), "failed consent stays closed")
	fake.consent_resolved.emit(true, true)
	manager._process(2.0)
	_check(fake.init_calls == 1 and fake.load_calls.size() == 2, "consent permits initialization and preloading")
	_check(fake.load_calls[0].id == manager.TEST_REWARDED and fake.load_calls[1].id == manager.TEST_INTERSTITIAL, "development requests only public test units")
	manager.begin_run()
	_check(not manager.request_extra_life(), "no rewarded ad during active gameplay")
	var actions := [0]
	manager.request_game_over_break(func() -> void: actions[0] += 1)
	_check(fake.show_calls.is_empty(), "no interstitial during active gameplay")
	manager.game_over()
	var rewards: Array[bool] = []
	manager.reward_completed.connect(func(granted: bool) -> void: rewards.append(granted))
	_check(manager.request_extra_life(), "optional extra life starts only at game over")
	var first_token := manager.token_counter
	fake.dismissed.emit("rewarded", first_token)
	_check(rewards == [false] and not manager.reward_used, "dismissal alone never grants reward")
	_check(not manager.request_extra_life(), "one rewarded attempt per run")
	manager.clock_seconds += 31.0
	manager.begin_run()
	manager._process(2.0)
	manager.game_over()
	_check(manager.request_extra_life(), "later run can offer another optional continue")
	var token := manager.token_counter
	fake.reward_earned.emit(first_token)
	_check(not manager.active.earned, "stale reward callback ignored")
	fake.reward_earned.emit(token)
	fake.reward_earned.emit(token)
	_check(rewards.size() == 1, "no revive before full-screen dismissal")
	fake.dismissed.emit("rewarded", token)
	fake.dismissed.emit("rewarded", token)
	_check(rewards == [false, true] and manager.reward_used, "confirmed completion grants exactly one reward")
	_check(not manager.reward_available(), "reward cannot be reused")
	manager.resume_rewarded_run()
	_check(manager.context == "playing", "confirmed continue returns to active run")
	manager._consent_form_ready()
	_check(fake.form_calls == 0, "a late consent form never interrupts gameplay")
	manager.enter_menu()
	_check(fake.form_calls == 1 and manager.privacy_busy, "pending form waits for menu")
	fake.consent_resolved.emit(false, true)
	_check(not manager.consent_allowed and not manager.privacy_busy, "privacy rejection releases UI and blocks ads")
	manager.queue_free()

	var caps := Manager.new()
	root.add_child(caps)
	caps.set_process(false)
	var capped_fake := Fake.new()
	caps._bind_provider(capped_fake)
	capped_fake.consent_resolved.emit(true, false)
	caps._process(2.0)
	for index in 3:
		caps.clock_seconds += 10.0
		caps.begin_run()
		caps.game_over()
		caps.request_game_over_break(func() -> void: actions[0] += 1)
	_check(capped_fake.show_calls.is_empty() and actions[0] == 3, "first two minutes never show interstitials")
	caps.clock_seconds = 1121.0
	caps.begin_run()
	caps.game_over()
	caps.request_game_over_break(func() -> void: actions[0] += 1)
	_check(capped_fake.show_calls.size() == 1 and actions[0] == 3, "eligible natural break waits for interstitial closure")
	capped_fake.show_failed.emit("interstitial", caps.token_counter)
	_check(actions[0] == 4 and caps.context == "game_over", "show failure completes the requested transition")
	for index in 3:
		caps.clock_seconds += 1.0
		caps.begin_run()
		caps.game_over()
		caps.request_game_over_break(func() -> void: actions[0] += 1)
	_check(capped_fake.show_calls.size() == 1 and actions[0] == 7, "cooldown prevents back-to-back interstitials")
	caps.interstitial_count = caps.MAX_INTERSTITIALS
	caps.clock_seconds += 121.0
	caps._process(2.0)
	caps.begin_run()
	caps.game_over()
	caps.request_game_over_break(func() -> void: actions[0] += 1)
	_check(capped_fake.show_calls.size() == 1, "session cap suppresses more interstitials")
	capped_fake.auto_load = false
	capped_fake.ready_ads.rewarded = false
	caps.retry_at.rewarded = 0.0
	caps._process(2.0)
	var load_count := capped_fake.load_calls.size()
	capped_fake.load_failed.emit("rewarded")
	caps._process(2.0)
	_check(capped_fake.load_calls.size() == load_count and caps.retry_at.rewarded > caps.clock_seconds, "offline load failure backs off instead of spinning")
	caps.queue_free()
	await process_frame
	await _test_actual_game()
	for failure in failures:
		push_error(failure)
	print("ADS POLICY & CONTINUE TEST: ", "PASS" if failures.is_empty() else "FAIL", " (local fake provider only)")
	quit(0 if failures.is_empty() else 1)

func _test_actual_game() -> void:
	var state := root.get_node("GameState")
	state.store.save_path = "user://neon_hop_test_ads.json"
	state.load_progress()
	state.reset_progress()
	var manager := root.get_node("AdManager")
	var fake := Fake.new()
	manager._bind_provider(fake)
	manager.enter_menu()
	fake.consent_resolved.emit(true, false)
	manager._process(2.0)
	var scene := load("res://scenes/gameplay/game.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.run.score = 50
	game.run.distance_pixels = 1600.0
	game.run.elapsed_seconds = 5.0
	var runs: int = state.data.total_runs
	game.player.kill()
	_check(state.run_active and game.run.phase == 3, "game over retains progression snapshot for optional continue")
	game.call("_request_continue")
	var token: int = manager.token_counter
	fake.reward_earned.emit(token)
	_check(game.run.phase == 3, "game stays stopped until native ad closure")
	fake.dismissed.emit("rewarded", token)
	_check(game.run.phase == 1 and game.run.score == 50 and game.player.alive, "reward callback revives actual gameplay with preserved score")
	_check(state.data.total_runs == runs and state.run_active, "extra life does not count as another run")
	game.player.kill()
	_check(not manager.reward_available(), "second death cannot offer another continue")
	game.call("_request_retry")
	_check(game.run.score == 0 and state.data.total_runs == runs + 1, "normal retry starts exactly one fresh run")
	fake.reward_earned.emit(token)
	_check(game.run.score == 0 and not manager.reward_used, "late reward cannot affect the new run")
	game.queue_free()
	root.get_node("Feedback").stop_all()
	await create_timer(0.15).timeout

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
