extends Control

signal play_requested
var progress_panel: Control
var settings_panel: Control
@onready var best_label: Label = %BestLabel
@onready var play_button: Button = %PlayButton

func _ready() -> void:
	best_label.text = "BEST  %d" % GameState.best_score
	play_button.pressed.connect(func() -> void: play_requested.emit())
	play_button.grab_focus()
	%ProgressButton.pressed.connect(_open_progress)
	%SoundButton.pressed.connect(_open_settings)
	GameState.progress_changed.connect(_refresh_best)
	%PrivacyButton.pressed.connect(AdManager.request_privacy_options)
	AdManager.privacy_changed.connect(_refresh_privacy)
	_refresh_privacy()
	AdManager.enter_menu.call_deferred()
	_animate_entrance()

func _animate_entrance() -> void:
	var items: Array[Control] = []
	for child in $SafeArea/Center/Menu.get_children():
		if child is Control:
			items.append(child)
	for item in items:
		item.modulate.a = 0.0
	for index in items.size():
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(float(index) * 0.045)
		tween.tween_property(items[index], "modulate:a", 1.0, 0.22)

func _unhandled_input(event: InputEvent) -> void:
	if AdManager.privacy_busy:
		return
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if is_instance_valid(progress_panel) or is_instance_valid(settings_panel):
		return
	var touch_pressed: bool = event is InputEventScreenTouch and event.pressed
	if touch_pressed or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		Feedback.play_button()
		play_requested.emit()
		get_viewport().set_input_as_handled()

func _open_progress() -> void:
	if is_instance_valid(progress_panel):
		return
	progress_panel = Control.new()
	progress_panel.set_script(preload("res://scripts/ui/progress_panel.gd"))
	add_child(progress_panel)

func _refresh_best() -> void:
	best_label.text = "BEST  %d" % GameState.best_score

func _open_settings() -> void:
	if is_instance_valid(settings_panel):
		return
	settings_panel = Control.new()
	settings_panel.set_script(preload("res://scripts/ui/feedback_settings.gd"))
	add_child(settings_panel)

func _refresh_privacy() -> void:
	play_button.disabled = AdManager.privacy_busy
	%PrivacyButton.visible = AdManager.privacy_entry_available()
	%PrivacyButton.disabled = AdManager.privacy_busy
	%PrivacyButton.text = "PRIVACY OPTIONS" if AdManager.privacy_required else "PRIVACY · RETRY CHECK"
