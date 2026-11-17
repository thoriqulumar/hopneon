extends Control

signal retry_requested
signal menu_requested
signal continue_requested

func setup(score: int, best_score: int, is_new_best: bool) -> void:
	%ScoreLabel.text = "SCORE  %d" % score
	%BestLabel.text = "BEST  %d" % best_score
	%NewBestLabel.visible = is_new_best

func _ready() -> void:
	%RetryButton.pressed.connect(func() -> void: retry_requested.emit())
	%MenuButton.pressed.connect(func() -> void: menu_requested.emit())
	%ContinueButton.pressed.connect(func() -> void: continue_requested.emit())
	AdManager.availability_changed.connect(_update_ads)
	_update_ads()
	%RetryButton.grab_focus()
	var panel := $SafeArea/Center/Panel
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.88, 0.88)
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.28)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)

func _update_ads() -> void:
	var busy: bool = not AdManager.active.is_empty()
	%RetryButton.disabled = busy
	%MenuButton.disabled = busy
	%ContinueButton.visible = AdManager.reward_available() or (busy and AdManager.active.get("kind", "") == "rewarded")
	%ContinueButton.disabled = busy
