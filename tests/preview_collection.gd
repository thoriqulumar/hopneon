extends SceneTree
## Visual QA utility. Does not write player progress. Captures go to .godot/.

func _initialize() -> void:
	await process_frame
	var state := root.get_node("GameState")
	state.dirty = false
	state.data = state.store.defaults()
	state.best_score = 437
	state.data.best_score = 437
	state.data.total_distance = 16800.0
	state.data.total_runs = 12
	state.data.total_seconds = 386.0
	state.data.unlocked = ["cyan", "violet"]
	state.data.selected = "violet"
	state.data.milestones = [100, 250]
	root.size = Vector2i(405, 720)
	root.content_scale_size = Vector2i(540, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var panel := Control.new()
	var sound_preview := "--settings" in OS.get_cmdline_user_args()
	panel.set_script(load("res://scripts/ui/feedback_settings.gd" if sound_preview else "res://scripts/ui/progress_panel.gd"))
	root.add_child(panel)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/feedback-settings-preview.png" if sound_preview else "res://.godot/collection-preview.png")
	var scroll := _find_scroll(panel)
	if scroll != null:
		scroll.scroll_vertical = 10000
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/collection-preview-bottom.png")
	quit()

func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var result := _find_scroll(child)
		if result != null:
			return result
	return null
