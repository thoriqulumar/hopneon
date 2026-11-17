extends SceneTree

const Store := preload("res://scripts/autoload/progress_store.gd")
const Fixture := preload("res://tests/progress_fixture.gd")
const PATH: String = "user://neon_hop_test_progression.json"
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# A failed assertion or runtime error must never leave CI hanging.
	create_timer(8.0).timeout.connect(func() -> void: quit(1))
	if "--restart-read" in OS.get_cmdline_user_args():
		var restart_store := Store.new()
		restart_store.save_path = "user://neon_hop_test_restart.json"
		var persisted := restart_store.load_progress()
		_check(persisted.best_score == 150 and persisted.selected == "violet", "best and equipped cosmetic survive a process restart")
		_check(persisted.daily.has("2026-10-23") and persisted.milestones.has(100), "daily history and milestone survive a process restart")
		for failure in failures:
			push_error(failure)
		print("PROCESS RESTART TEST: ", "PASS" if failures.is_empty() else "FAIL")
		quit(0 if failures.is_empty() else 1)
		return
	# All writes are isolated from actual player progress, including backup/reset.
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	var store := Store.new()
	store.save_path = PATH
	_check(store.load_progress().best_score == 0, "missing file defaults")
	var data := store.defaults()
	data.best_score = 123
	_check(store.save_progress(data) == OK, "save succeeds in user storage")
	var reader := Store.new()
	reader.save_path = PATH
	_check(reader.load_progress().best_score == 123, "fresh instance reads durable best")
	_check(reader.save_progress(data) == OK, "second save rotates validated backup")
	_write(PATH, "{broken json")
	_check(reader.load_progress().best_score == 123, "corrupted primary recovers backup")
	_check(reader.save_progress(data) == OK, "recovery can repair primary")
	_write(PATH, "{broken json")
	_write(PATH + ".bak", "[]")
	_check(reader.load_progress().best_score == 0, "both files corrupt defaults safely")
	_write(PATH, JSON.stringify({"version": 1, "best_score": 87}))
	_check(reader.load_progress().best_score == 87, "version 1 migrates without score loss")
	_write(PATH, JSON.stringify({"version": 999, "best_score": 987}))
	reader.load_progress()
	_check(reader.read_only and reader.save_progress(data) == ERR_UNAVAILABLE, "future schema preserved read-only")
	_check(JSON.parse_string(FileAccess.get_file_as_string(PATH)).best_score == 987, "future file not overwritten")
	_write(PATH, JSON.stringify({"version": 2, "best_score": "bad", "daily": [], "unlocked": 12, "selected": [], "total_seconds": -10}))
	var sanitized := reader.load_progress()
	_check(sanitized.best_score == 0 and sanitized.selected == "cyan" and sanitized.total_seconds == 0, "malformed fields sanitized")

	var state := Fixture.new()
	state.store.save_path = PATH
	root.add_child(state)
	_check(state.reset_progress() == OK, "reset writes fresh primary and backup")
	state.begin_run()
	state.update_run(120, 3840.0, 12.0)
	state.update_run(120, 3840.0, 12.0)
	_check(state.data.total_distance == 3840.0 and state.today_stats().runs == 1, "repeated snapshots do not double count")
	_check(state.select_cosmetic("violet"), "earned cosmetic can be selected")
	_check(not state.select_cosmetic("gold"), "locked cosmetic cannot be equipped")
	state.date = "2026-10-23"
	state.update_run(150, 4800.0, 15.0)
	_check(state.today_stats().distance == 960.0 and state.today_stats().runs == 0, "midnight attributes new activity to new day")
	_check(state.finish_run(150, 4800.0, 15.0), "finish recognizes personal best")
	_check(not state.finish_run(150, 4800.0, 15.0), "repeated finish is ignored")
	state.load_progress()
	_check(state.best_score == 150 and state.data.selected == "violet" and state.data.milestones.has(100), "score, selection, milestones survive reload")
	_check(state.data.daily["2026-10-22"].distance == 3840.0 and state.data.daily["2026-10-23"].seconds == 3.0, "daily history persists after reload")
	var restart_store := Store.new()
	restart_store.save_path = "user://neon_hop_test_restart.json"
	_check(restart_store.save_progress(state.data) == OK, "write fixture for separate-process restart verification")
	state.begin_run()
	state.finish_run(1000, 32000.0, 100.0)
	_check(state.data.unlocked.has("gold"), "lifetime distance earns gold")
	_check(state.reset_progress() == OK, "confirmed reset succeeds")
	_write(PATH, "corrupted after reset")
	state.load_progress()
	_check(state.best_score == 0 and state.data.total_runs == 0 and state.data.unlocked == ["cyan"], "backup cannot resurrect cleared progress")
	state.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("PROGRESSION TEST: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "test storage writable")
		return
	file.store_string(text)
	file.close()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
