extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var state := root.get_node("GameState")
	state.store.save_path = "user://neon_hop_test_menu.json"
	state.load_progress()
	state.reset_progress()
	state.best_score = 42
	state.data.best_score = 42
	state.data.unlocked = ["cyan", "violet"]
	create_timer(8.0).timeout.connect(func() -> void: quit(1))
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var menu := main.get_node("MainMenu")
	menu.get_node("SafeArea/Center/Menu/ProgressButton").emit_signal("pressed")
	var panel: Variant = menu.progress_panel
	_check(panel.cosmetic_buttons.gold.disabled, "locked cosmetic cannot be selected")
	panel.cosmetic_buttons.violet.emit_signal("pressed")
	_check(state.data.selected == "violet", "equip card updates progression selection")
	_check(panel.hero_preview.character.glow_color == state.COSMETIC_COLORS.violet, "hero preview renders actual equipped color")
	_check(panel.hero_preview.character.cosmetic == "violet", "equipped hero previews the orbit effect")
	_check(panel.cards.gold.preview.character.cosmetic == "gold", "locked gold still previews its solar effects")
	_check(panel.cards.violet.badge.text == "● EQUIPPED" and panel.cards.cyan.badge.text == "AVAILABLE", "card badges update visually after selection")
	panel.call("_ask_reset")
	_check(state.best_score == 42, "opening reset confirmation preserves progress")
	panel.reset_dialog.emit_signal("canceled")
	panel.reset_dialog.hide()
	_check(state.best_score == 42, "cancel preserves progress")
	panel.call("_ask_reset")
	panel.reset_dialog.emit_signal("confirmed")
	panel.reset_dialog.hide()
	_check(state.best_score == 0, "confirmation clears progress")
	panel.closed.emit()
	panel.queue_free()
	await process_frame
	_check(menu.get_node("SafeArea/Center/Menu/BestLabel").text == "BEST  0", "menu refreshes after reset")
	var button := main.get_node("MainMenu/SafeArea/Center/Menu/PlayButton") as Button
	button.pressed.emit()
	await create_timer(0.4).timeout
	_check(main.has_node("Game") and not main.has_node("MainMenu"), "menu transitions to gameplay")
	for failure in failures:
		push_error(failure)
	print("MENU & RESET TEST: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
