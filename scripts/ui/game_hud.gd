class_name NeonGameHud
extends Control

signal pause_requested
signal resume_requested
signal settings_requested

@onready var score_label: Label = %ScoreLabel
@onready var pause_button: Button = %PauseButton
@onready var paused_panel: Control = %PausedPanel
var best_label: Label
var notice_label: Label
var notices: Array[String] = []
var notice_tween: Tween

func _ready() -> void:
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	%ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	%SoundButton.pressed.connect(func() -> void: settings_requested.emit())
	best_label = Label.new()
	best_label.position = Vector2(0.0, 65.0)
	best_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	best_label.offset_top = 65.0
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override("font_size", 20)
	best_label.modulate = Color("cbd8f5")
	best_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(best_label)
	notice_label = Label.new()
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice_label.offset_top = 112.0
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 22)
	notice_label.modulate = Color("ffdf70")
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notice_label)

func reset() -> void:
	if notice_tween != null and notice_tween.is_valid():
		notice_tween.kill()
	notices.clear()
	notice_label.text = ""
	set_score(0)
	set_paused(false)

func set_score(value: int) -> void:
	score_label.text = "%06d" % value

func set_best(value: int) -> void:
	best_label.text = "BEST  %d" % value

func show_notice(message: String) -> void:
	notices.append(message)
	if notice_tween == null or not notice_tween.is_valid():
		_next_notice()

func _next_notice() -> void:
	if notices.is_empty():
		notice_label.text = ""
		return
	notice_label.text = notices.pop_front()
	notice_label.modulate.a = 0.0
	notice_tween = create_tween()
	notice_tween.tween_property(notice_label, "modulate:a", 1.0, 0.15)
	notice_tween.tween_interval(2.2)
	notice_tween.tween_property(notice_label, "modulate:a", 0.0, 0.2)
	notice_tween.tween_callback(_next_notice)

func set_paused(value: bool) -> void:
	paused_panel.visible = value
	pause_button.visible = not value
	if value:
		%ResumeButton.grab_focus()
