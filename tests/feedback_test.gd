extends SceneTree

const Store := preload("res://scripts/autoload/progress_store.gd")
const PATH: String = "user://neon_hop_test_feedback.json"
var failures: Array[String] = []
var played: Array[StringName] = []

func _initialize() -> void:
	await process_frame
	create_timer(8.0).timeout.connect(func() -> void: quit(1))
	var state := root.get_node("GameState")
	var feedback := root.get_node("Feedback")
	state.store.save_path = PATH
	state.load_progress()
	if "--restart-read" in OS.get_cmdline_user_args():
		_check(state.data.feedback.muted and is_equal_approx(state.data.feedback.sfx_volume, 0.27), "mute and volume survive process restart")
		_check(not state.data.feedback.haptics and not state.data.feedback.screen_shake, "feedback preferences survive process restart")
		_check(AudioServer.is_bus_mute(feedback.bus_index), "saved mute is applied before gameplay")
		_finish()
		return
	state.reset_progress()
	state.set_feedback_setting("muted", false)
	state.set_feedback_setting("sfx_volume", 0.65)
	feedback.effect_played.connect(func(effect: StringName) -> void: played.append(effect))
	for effect in feedback.voices:
		var voice: AudioStreamPlayer = feedback.voices[effect]
		var wave := voice.stream as AudioStreamWAV
		_check(wave != null and wave.mix_rate == 24000 and not wave.stereo, "generated mono PCM stream")
		_check(wave.data.size() > 1000 and wave.data.size() <= 14400, "short precomputed waveform stays bounded")
		var peak: int = 0
		for index in range(0, wave.data.size(), 2):
			peak = maxi(peak, absi(wave.data.decode_s16(index)))
		_check(peak > 100 and peak < 16384, "audible waveform with clipping headroom")
	feedback.play_jump()
	feedback.play_jump()
	_check(played.count(&"jump") == 1, "repeat effects are rate limited")
	state.set_feedback_setting("muted", true)
	feedback.play_collision()
	_check(not played.has(&"collision") and AudioServer.is_bus_mute(feedback.bus_index), "mute blocks playback immediately")
	state.set_feedback_setting("muted", false)
	feedback.play_collision()
	_check(played.has(&"collision"), "collision sound plays after unmute")
	state.set_feedback_setting("sfx_volume", 0.0)
	feedback.play_button()
	_check(not played.has(&"button"), "zero volume suppresses new effects")
	state.set_feedback_setting("sfx_volume", 0.65)
	var button := Button.new()
	root.add_child(button)
	button.pressed.emit()
	_check(played.has(&"button"), "new UI buttons automatically receive audio")
	button.queue_free()
	state.begin_run()
	state.update_run(100, 3200.0, 10.0)
	_check(played.has(&"milestone"), "earned score milestone triggers its sound")
	var settings := Control.new()
	settings.set_script(load("res://scripts/ui/feedback_settings.gd"))
	root.add_child(settings)
	settings.volume_slider.value = 27.0
	settings.mute_button.button_pressed = true
	_check(state.data.feedback.muted and is_equal_approx(state.data.feedback.sfx_volume, 0.27), "settings controls change actual mixer preferences")
	settings.queue_free()
	state.set_feedback_setting("haptics", false)
	state.set_feedback_setting("screen_shake", false)
	_check(state.reset_progress() == OK, "progression reset keeps accessibility preferences")
	_check(state.data.feedback.muted and is_equal_approx(state.data.feedback.sfx_volume, 0.27), "reset preserves audio settings")
	state.flush()
	var store := Store.new()
	store.save_path = PATH
	_check(store.load_progress().feedback.muted, "audio settings durably written")
	var legacy := store.normalize({"version": 2, "best_score": 987})
	_check(legacy.best_score == 987 and is_equal_approx(legacy.feedback.sfx_volume, 0.65), "old saves keep best score and receive audio defaults")
	var malformed := store.normalize({"version": 3, "best_score": 5, "feedback": {"sfx_volume": -20, "muted": "bad"}})
	_check(malformed.feedback.sfx_volume == 0.0 and malformed.feedback.muted == false, "invalid preferences are sanitized")
	feedback.stop_all()
	# Let the audio mixer release stopped playback before the headless process exits.
	await create_timer(0.15).timeout
	_finish()

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("FEEDBACK TEST: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
