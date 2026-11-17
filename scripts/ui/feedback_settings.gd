extends Control

signal closed
var volume_slider: HSlider
var volume_label: Label
var mute_button: CheckButton
var haptic_button: CheckButton
var shake_button: CheckButton
var status_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.025, 0.08, 0.98)
	add_child(shade)
	var safe := MarginContainer.new()
	safe.set_script(preload("res://scripts/components/safe_area_container.gd"))
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	var center := CenterContainer.new()
	safe.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 440.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101a2e")
	style.border_color = Color("27576a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	_label(content, "SOUND & FEEDBACK", 27)
	var row := HBoxContainer.new()
	content.add_child(row)
	var caption := _label(row, "Sound effects", 22)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_label = _label(row, "", 22)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.custom_minimum_size.y = 48.0
	volume_slider.value_changed.connect(func(value: float) -> void: GameState.set_feedback_setting("sfx_volume", value / 100.0))
	volume_slider.drag_ended.connect(_preview_volume)
	content.add_child(volume_slider)
	mute_button = _toggle(content, "Mute sound", "muted")
	haptic_button = _toggle(content, "Haptic feedback", "haptics")
	if OS.get_name() != "Android":
		haptic_button.disabled = true
		_label(content, "Haptics are available on supported Android phones.", 16)
	shake_button = _toggle(content, "Gentle collision shake", "screen_shake")
	status_label = _label(content, "", 16)
	var back := Button.new()
	back.text = "DONE"
	back.custom_minimum_size.y = 64.0
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_close)
	content.add_child(back)
	GameState.feedback_settings_changed.connect(_sync)
	_sync()
	back.grab_focus()

func _toggle(parent: Node, text: String, key: String) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.custom_minimum_size.y = 56.0
	button.add_theme_font_size_override("font_size", 21)
	button.toggled.connect(func(value: bool) -> void: GameState.set_feedback_setting(key, value))
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, size_value: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Color("dcf3ff"))
	parent.add_child(label)
	return label

func _sync() -> void:
	var settings: Dictionary = GameState.data.feedback
	volume_slider.set_value_no_signal(roundf(float(settings.sfx_volume) * 100.0))
	volume_label.text = "%d%%" % int(volume_slider.value)
	volume_label.custom_minimum_size.x = 60.0
	volume_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	mute_button.set_pressed_no_signal(settings.muted)
	haptic_button.set_pressed_no_signal(settings.haptics)
	shake_button.set_pressed_no_signal(settings.screen_shake)
	status_label.text = GameState.store.status
	status_label.visible = not status_label.text.is_empty()

func _preview_volume(changed: bool) -> void:
	if changed:
		Feedback.play_button()

func _close() -> void:
	GameState.flush()
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
