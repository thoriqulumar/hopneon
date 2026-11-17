extends Node
## Four short, original PCM effects synthesized once at startup; no audio files.

signal effect_played(effect: StringName)
const SAMPLE_RATE: int = 24000
const BUS: StringName = &"SFX"
const COOLDOWNS: Dictionary = {&"jump": 80, &"collision": 220, &"milestone": 1200, &"button": 65}
var voices: Dictionary = {}
var last_played: Dictionary = {}
var save_timer: Timer
var bus_index: int = -1

func _ready() -> void:
	bus_index = AudioServer.get_bus_index(BUS)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, BUS)
		AudioServer.set_bus_send(bus_index, &"Master")
	for effect in [&"jump", &"collision", &"milestone", &"button"]:
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS
		voice.stream = _synthesize(effect)
		add_child(voice)
		voices[effect] = voice
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.35
	save_timer.timeout.connect(GameState.flush)
	add_child(save_timer)
	GameState.feedback_settings_changed.connect(_apply_settings)
	GameState.milestone_reached.connect(play_milestone)
	_apply_settings()
	get_tree().node_added.connect(_wire_button)
	_wire_existing(get_tree().root)

func _wire_existing(node: Node) -> void:
	_wire_button(node)
	for child in node.get_children():
		_wire_existing(child)

func _wire_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play_button):
		node.pressed.connect(play_button)

func _apply_settings() -> void:
	var settings: Dictionary = GameState.data.feedback
	var volume: float = settings.sfx_volume
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus_index, settings.muted or volume <= 0.0)
	if settings.muted or volume <= 0.0:
		stop_all()
	if is_instance_valid(save_timer):
		save_timer.start()

func play_jump() -> void:
	_play(&"jump")
	_haptic(12, 0.18)

func play_collision() -> void:
	(voices[&"jump"] as AudioStreamPlayer).stop()
	(voices[&"milestone"] as AudioStreamPlayer).stop()
	_play(&"collision")
	_haptic(35, 0.35)

func play_milestone(_score: int = 0) -> void:
	_play(&"milestone")

func play_button() -> void:
	_play(&"button")

func _play(effect: StringName) -> bool:
	var settings: Dictionary = GameState.data.feedback
	if settings.muted or float(settings.sfx_volume) <= 0.0:
		return false
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(effect, -10000)) < int(COOLDOWNS[effect]):
		return false
	last_played[effect] = now
	(voices[effect] as AudioStreamPlayer).play()
	effect_played.emit(effect)
	return true

func _haptic(duration_ms: int, amplitude: float) -> void:
	if OS.get_name() == "Android" and GameState.data.feedback.haptics:
		# Godot safely ignores this when no vibrator is available. No plugin or
		# runtime permission prompt is needed; VIBRATE is in the export preset.
		Input.vibrate_handheld(duration_ms, amplitude)

func stop_all() -> void:
	for voice in voices.values():
		(voice as AudioStreamPlayer).stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		stop_all()

func _exit_tree() -> void:
	stop_all()
	for voice in voices.values():
		(voice as AudioStreamPlayer).stream = null

func _synthesize(effect: StringName) -> AudioStreamWAV:
	var duration: float = {&"jump": 0.12, &"collision": 0.22, &"milestone": 0.30, &"button": 0.045}[effect]
	var count := int(duration * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 8741
	for index in count:
		var time := float(index) / SAMPLE_RATE
		var fraction := time / duration
		var frequency: float = 440.0
		var gain: float = 0.30
		var envelope := minf(time / 0.004, 1.0) * pow(1.0 - fraction, 2.0)
		match effect:
			&"jump":
				frequency = lerpf(420.0, 900.0, fraction)
			&"collision":
				frequency = lerpf(145.0, 48.0, fraction)
				gain = 0.38
			&"milestone":
				var note := mini(int(time / 0.10), 2)
				frequency = [622.25, 783.99, 932.33][note]
				var note_time := fmod(time, 0.10)
				envelope = minf(note_time / 0.005, 1.0) * minf((0.10 - note_time) / 0.035, 1.0) * (1.0 - fraction * 0.4)
				gain = 0.22
			&"button":
				frequency = lerpf(920.0, 680.0, fraction)
				gain = 0.16
		phase += TAU * frequency / SAMPLE_RATE
		var sample := sin(phase) + sin(phase * 2.0) * 0.12
		if effect == &"collision":
			sample = sin(phase) * 0.8 + rng.randf_range(-1.0, 1.0) * 0.2
		pcm.encode_s16(index * 2, int(clampf(sample * gain * envelope, -0.9, 0.9) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream
