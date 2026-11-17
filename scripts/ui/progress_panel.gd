extends Control
## Responsive native collection screen. All progression mutations use GameState.

signal closed
const Preview := preload("res://scripts/ui/cosmetic_preview.gd")
const INK := Color("e9f5ff")
const MUTED := Color("8594b5")
const CYAN := Color("16f4ff")

var content: VBoxContainer
var status_label: Label
var cosmetic_buttons: Dictionary = {}
var cards: Dictionary = {}
var stat_labels: Dictionary = {}
var milestone_cards: Dictionary = {}
var reset_dialog: ConfirmationDialog
var hero_preview: Control
var hero_name: Label
var collection_count: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("070b1b")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var safe := MarginContainer.new()
	safe.set_script(preload("res://scripts/components/safe_area_container.gd"))
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 18)
	safe.add_child(shell)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	shell.add_child(header)
	var back := _button("‹", _close)
	back.custom_minimum_size = Vector2(56, 56)
	header.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_label(titles, "YOUR COLLECTION", 13, CYAN)
	_label(titles, "Glow & grow", 30)
	collection_count = _label(header, "", 17, MUTED)
	collection_count.custom_minimum_size.x = 64.0
	collection_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	collection_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	collection_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	scroll.add_child(content)
	_build_hero()
	_section("CHOOSE YOUR GLOW", "Level up your look. Preview every effect.")
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	content.add_child(grid)
	for cosmetic in ["cyan", "violet", "gold"]:
		_build_cosmetic(grid, cosmetic)
	_section("TODAY'S SESSION", Time.get_date_string_from_system(false))
	var today := HBoxContainer.new()
	today.add_theme_constant_override("separation", 10)
	content.add_child(today)
	_stat(today, "today_runs", "RUNS", CYAN)
	_stat(today, "today_best", "BEST", Color("c48aff"))
	_stat(today, "today_minutes", "MINUTES", Color("ffdf70"))
	_section("YOUR JOURNEY", "Every run counts.")
	var lifetime := HBoxContainer.new()
	lifetime.add_theme_constant_override("separation", 10)
	content.add_child(lifetime)
	_stat(lifetime, "distance", "TOTAL DISTANCE", CYAN)
	_stat(lifetime, "runs", "TOTAL RUNS", Color("c48aff"))
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 12)
	content.add_child(detail)
	stat_labels.today_distance = _label(detail, "", 15, MUTED)
	stat_labels.total_time = _label(detail, "", 15, MUTED)
	stat_labels.today_distance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_labels.total_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section("MILESTONES", "Personal best targets")
	var milestones := HBoxContainer.new()
	milestones.add_theme_constant_override("separation", 8)
	content.add_child(milestones)
	for target in [100, 250, 500, 1000]:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		milestones.add_child(tile)
		var stack := VBoxContainer.new()
		tile.add_child(stack)
		var icon := _label(stack, "◇", 28, MUTED)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var caption := _label(stack, str(target), 17)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		milestone_cards[target] = {"tile": tile, "icon": icon}
	status_label = _label(content, "", 16, Color("ffbc9c"))
	var reset := _button("Reset progress…", _ask_reset)
	reset.add_theme_color_override("font_color", MUTED)
	reset.add_theme_font_size_override("font_size", 17)
	content.add_child(reset)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Reset all progress?"
	reset_dialog.dialog_text = "Erase your best score, daily statistics,\nmilestones, and cosmetic unlocks?\nThis cannot be undone."
	reset_dialog.ok_button_text = "ERASE PROGRESS"
	reset_dialog.confirmed.connect(_confirm_reset)
	add_child(reset_dialog)
	_refresh()
	back.grab_focus()

func _build_hero() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("102537"), Color("21566b"), 20))
	content.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_label(words, "EQUIPPED GLOW", 13, CYAN)
	hero_name = _label(words, "", 29)
	_label(words, "PERSONAL BEST", 13, MUTED)
	stat_labels.best = _label(words, "0", 40)
	hero_preview = _preview(row, 140.0)
	hero_preview.custom_minimum_size = Vector2(145, 155)

func _build_cosmetic(parent: Control, cosmetic: String) -> void:
	var color: Color = GameState.COSMETIC_COLORS[cosmetic]
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tile)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	tile.add_child(stack)
	var name_label := _label(stack, cosmetic.capitalize(), 19, color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var effect_label := _label(stack, {"cyan": "CORE GLOW", "violet": "ORBIT AURA", "gold": "SOLAR TRAIL"}[cosmetic], 11, color)
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var preview := _preview(stack, 112.0)
	preview.update_state(color, false, cosmetic)
	var badge := _label(stack, "", 12, MUTED)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("202840"), Color.TRANSPARENT, 3, 0))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 3, 0))
	stack.add_child(bar)
	var requirement := _label(stack, "", 12, MUTED)
	requirement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	requirement.custom_minimum_size.y = 34
	var button := _button("", func() -> void: _select(cosmetic))
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 15)
	stack.add_child(button)
	cosmetic_buttons[cosmetic] = button
	cards[cosmetic] = {"tile": tile, "preview": preview, "badge": badge, "bar": bar, "requirement": requirement}

func _preview(parent: Control, height: float) -> Control:
	var preview := Control.new()
	preview.set_script(Preview)
	preview.custom_minimum_size.y = height
	parent.add_child(preview)
	return preview

func _section(title: String, subtitle: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	content.add_child(box)
	_label(box, title, 18)
	_label(box, subtitle, 14, MUTED)

func _stat(parent: Control, key: String, caption: String, color: Color) -> void:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _style(Color("10182c"), Color("202d48")))
	parent.add_child(tile)
	var stack := VBoxContainer.new()
	tile.add_child(stack)
	stat_labels[key] = _label(stack, "0", 30, color)
	_label(stack, caption, 11, MUTED)

func _style(background: Color, border: Color, radius: int = 14, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(parent: Node, text: String, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 56.0
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _style(Color("17243a"), Color("30435d"), 12, 8))
	button.add_theme_stylebox_override("hover", _style(Color("203349"), CYAN, 12, 8))
	button.add_theme_stylebox_override("pressed", _style(Color("174354"), CYAN, 12, 8))
	button.add_theme_stylebox_override("disabled", _style(Color("10182b"), Color("263046"), 12, 8))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Color(CYAN, 0.55), 12, 8))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.pressed.connect(action)
	return button

func _select(cosmetic: String) -> void:
	GameState.select_cosmetic(cosmetic)
	_refresh()

func _refresh() -> void:
	var day := GameState.today_stats()
	stat_labels.best.text = str(GameState.best_score)
	stat_labels.today_runs.text = str(day.runs)
	stat_labels.today_best.text = str(day.best)
	stat_labels.today_minutes.text = "%.1f" % (float(day.seconds) / 60.0)
	stat_labels.distance.text = "%.0f" % (float(GameState.data.total_distance) / 32.0)
	stat_labels.runs.text = str(GameState.data.total_runs)
	stat_labels.today_distance.text = "Today  %.1f distance" % (float(day.distance) / 32.0)
	stat_labels.total_time.text = "Total  %.1f min played" % (float(GameState.data.total_seconds) / 60.0)
	collection_count.text = "%d / 3" % GameState.data.unlocked.size()
	hero_name.text = str(GameState.data.selected).capitalize()
	hero_preview.update_state(GameState.selected_color(), true, str(GameState.data.selected))
	for cosmetic in cards:
		var card: Dictionary = cards[cosmetic]
		var color: Color = GameState.COSMETIC_COLORS[cosmetic]
		var unlocked: bool = cosmetic in GameState.data.unlocked
		var selected: bool = cosmetic == GameState.data.selected
		var button: Button = cosmetic_buttons[cosmetic]
		card.tile.add_theme_stylebox_override("panel", _style(Color("11232f") if selected else Color("101526"), color if selected else Color("27304a"), 16, 9))
		card.preview.update_state(color, selected, cosmetic)
		card.badge.text = "● EQUIPPED" if selected else ("AVAILABLE" if unlocked else "◇ LOCKED")
		card.badge.add_theme_color_override("font_color", color if selected else MUTED)
		button.disabled = not unlocked or selected or GameState.store.read_only
		button.text = "Equipped" if selected else ("Equip" if unlocked else "Locked")
		var earned: float = float(GameState.best_score) if cosmetic == "violet" else float(GameState.data.total_distance) / 32.0
		var target: float = 100.0 if cosmetic == "violet" else 1000.0
		card.bar.value = 100.0 if unlocked else minf(earned / target * 100.0, 100.0)
		card.requirement.text = "Starter glow" if cosmetic == "cyan" else ("100 best score" if cosmetic == "violet" else "%d / 1,000\ndistance" % mini(int(earned), 1000))
	for target in milestone_cards:
		var earned: bool = target in GameState.data.milestones
		var item: Dictionary = milestone_cards[target]
		item.tile.add_theme_stylebox_override("panel", _style(Color("15262b") if earned else Color("101526"), Color("36716a") if earned else Color("27304a"), 12, 9))
		item.icon.text = "◆" if earned else "◇"
		item.icon.add_theme_color_override("font_color", CYAN if earned else MUTED)
	status_label.text = GameState.store.status
	status_label.visible = not status_label.text.is_empty()

func _close() -> void:
	closed.emit()
	queue_free()

func _ask_reset() -> void:
	reset_dialog.popup_centered(Vector2i(410, 230))

func _confirm_reset() -> void:
	GameState.reset_progress()
	_refresh()
