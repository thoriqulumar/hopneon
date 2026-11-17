extends Node
## Owns durable progression. Gameplay supplies cumulative run snapshots; UI reads summaries.

signal progression_notice(message: String)
signal progress_changed
signal feedback_settings_changed
signal milestone_reached(score: int)

const Store := preload("res://scripts/autoload/progress_store.gd")
const CHECKPOINT_SECONDS: float = 5.0
const MILESTONES: Array[int] = [100, 250, 500, 1000]
const COSMETIC_COLORS: Dictionary = {"cyan": Color("16f4ff"), "violet": Color("c48aff"), "gold": Color("ffdf70")}
var store := Store.new()
var data: Dictionary = {}
var best_score: int = 0
var current_score: int = 0
var run_active: bool = false
var run_start_best: int = 0
var previous_distance: float = 0.0
var previous_seconds: float = 0.0
var checkpoint_elapsed: float = 0.0
var dirty: bool = false

func _ready() -> void:
	load_progress()

func load_progress() -> void:
	dirty = false
	data = store.load_progress()
	# Migrate the original project save only when no JSON save or backup exists.
	if not FileAccess.file_exists(store.save_path) and not FileAccess.file_exists(store.save_path + ".bak") and store.save_path == "user://neon_hop_progress.json":
		var legacy := ConfigFile.new()
		if legacy.load("user://neon_hop.cfg") == OK:
			data.best_score = int(store.number(legacy.get_value("scores", "best", 0)))
			dirty = true
	best_score = int(data.best_score)
	run_active = false
	current_score = 0
	_evaluate_rewards(false)
	flush()
	feedback_settings_changed.emit()

func begin_run() -> void:
	run_active = true
	run_start_best = best_score
	current_score = 0
	previous_distance = 0.0
	previous_seconds = 0.0
	checkpoint_elapsed = 0.0
	data.total_runs = int(data.total_runs) + 1
	var day := today_stats()
	day.runs = int(day.runs) + 1
	data.daily[_today()] = day
	dirty = true
	flush()

func update_run(score: int, distance: float, seconds: float) -> void:
	if not run_active:
		return
	var distance_delta := maxf(0.0, distance - previous_distance)
	var seconds_delta := maxf(0.0, seconds - previous_seconds)
	previous_distance = maxf(distance, previous_distance)
	previous_seconds = maxf(seconds, previous_seconds)
	current_score = maxi(current_score, score)
	best_score = maxi(best_score, current_score)
	data.best_score = best_score
	data.total_distance = float(data.total_distance) + distance_delta
	data.total_seconds = float(data.total_seconds) + seconds_delta
	var day := today_stats()
	day.distance = float(day.distance) + distance_delta
	day.seconds = float(day.seconds) + seconds_delta
	day.best = maxi(int(day.best), current_score)
	data.daily[_today()] = day
	dirty = true
	checkpoint_elapsed += seconds_delta
	_evaluate_rewards(true)
	if checkpoint_elapsed >= CHECKPOINT_SECONDS:
		checkpoint_elapsed = 0.0
		flush()

func finish_run(score: int, distance: float, seconds: float) -> bool:
	if not run_active:
		return false
	update_run(score, distance, seconds)
	run_active = false
	flush()
	progress_changed.emit()
	return score > run_start_best

func _evaluate_rewards(notify: bool) -> void:
	for milestone in MILESTONES:
		if best_score >= milestone and not milestone in data.milestones:
			data.milestones.append(milestone)
			dirty = true
			if notify:
				progression_notice.emit("MILESTONE · %d POINTS" % milestone)
				milestone_reached.emit(milestone)
	for cosmetic in ["violet", "gold"]:
		var earned: bool = best_score >= 100 if cosmetic == "violet" else float(data.total_distance) >= 32000.0
		if earned and not cosmetic in data.unlocked:
			data.unlocked.append(cosmetic)
			dirty = true
			if notify:
				progression_notice.emit("UNLOCKED · %s GLOW" % cosmetic.to_upper())

func today_stats() -> Dictionary:
	return data.get("daily", {}).get(_today(), {"runs": 0, "distance": 0.0, "seconds": 0.0, "best": 0}).duplicate()

func _today() -> String:
	return Time.get_date_string_from_system(false)

func select_cosmetic(cosmetic: String) -> bool:
	if not cosmetic in data.unlocked:
		return false
	data.selected = cosmetic
	dirty = true
	flush()
	progress_changed.emit()
	return true

func selected_color() -> Color:
	return COSMETIC_COLORS.get(data.get("selected", "cyan"), Color("16f4ff"))

func reset_progress() -> Error:
	# The UI asks for confirmation. Replace both primary and backup so recovery
	# cannot restore progress the player explicitly cleared.
	var fresh := store.defaults()
	fresh.feedback = data.get("feedback", fresh.feedback).duplicate(true)
	var error := store.save_progress(fresh, true)
	if error != OK:
		return error
	data = fresh
	best_score = 0
	current_score = 0
	run_active = false
	dirty = false
	progress_changed.emit()
	return OK

func set_feedback_setting(key: String, value: Variant) -> void:
	if not key in ["sfx_volume", "muted", "haptics", "screen_shake"]:
		return
	if key == "sfx_volume":
		if not (value is int or value is float) or not is_finite(float(value)):
			return
		value = clampf(float(value), 0.0, 1.0)
	elif not value is bool:
		return
	if data.feedback[key] == value:
		return
	data.feedback[key] = value
	dirty = true
	feedback_settings_changed.emit()

func flush() -> void:
	if dirty and not store.read_only:
		if store.save_progress(data) == OK:
			dirty = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()

func _exit_tree() -> void:
	flush()
