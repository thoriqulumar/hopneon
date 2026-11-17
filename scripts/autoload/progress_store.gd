extends RefCounted
## JSON-only, versioned storage. Never deserializes executable Godot objects.

const VERSION: int = 3
const LIMIT: float = 1000000000000.0
var save_path: String = "user://neon_hop_progress.json"
var read_only: bool = false
var status: String = ""

func defaults() -> Dictionary:
	return {"version": VERSION, "best_score": 0, "total_runs": 0,
		"total_distance": 0.0, "total_seconds": 0.0, "daily": {},
		"unlocked": ["cyan"], "selected": "cyan", "milestones": [],
		"feedback": {"sfx_volume": 0.65, "muted": false, "haptics": true, "screen_shake": true}}

func load_progress() -> Dictionary:
	read_only = false
	status = ""
	var raw: Variant = _read(save_path)
	if raw is Dictionary and number(raw.get("version", 1)) > VERSION:
		read_only = true
		status = "Save is from a newer game version. Progress is read-only."
		return defaults()
	var data := normalize(raw)
	if not data.is_empty():
		return data
	var backup: Variant = _read(save_path + ".bak")
	if backup is Dictionary and number(backup.get("version", 1)) > VERSION:
		read_only = true
		status = "Backup is from a newer game version. Progress is read-only."
		return defaults()
	data = normalize(backup)
	if not data.is_empty():
		status = "Recovered progress from backup."
		return data
	if FileAccess.file_exists(save_path):
		status = "Save could not be read. Starting with safe defaults."
	return defaults()

func save_progress(data: Dictionary, replace_backup: bool = false) -> Error:
	if read_only:
		return ERR_UNAVAILABLE
	var clean := normalize(data)
	if clean.is_empty():
		return ERR_INVALID_DATA
	var temporary := save_path + ".tmp"
	var error := _write(temporary, clean)
	if error != OK:
		return _failed(error)
	if normalize(_read(temporary)).is_empty():
		return _failed(ERR_FILE_CORRUPT)
	# Backup only validated data; never replace a healthy backup with corrupt input.
	var previous := normalize(_read(save_path))
	if replace_backup:
		previous = clean
	if not previous.is_empty():
		error = _write(save_path + ".bak.tmp", previous)
		if error != OK:
			return _failed(error)
		error = DirAccess.rename_absolute(save_path + ".bak.tmp", save_path + ".bak")
		if error != OK:
			return _failed(error)
	error = DirAccess.rename_absolute(temporary, save_path)
	if error != OK:
		return _failed(error)
	status = ""
	return OK

func _failed(error: Error) -> Error:
	status = "Progress could not be saved. Check available storage."
	return error

func _write(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4000000:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func number(value: Variant) -> float:
	if not (value is int or value is float):
		return 0.0
	var result := float(value)
	return clampf(result, 0.0, LIMIT) if is_finite(result) else 0.0

func normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var version := int(number(raw.get("version", 1)))
	if version < 1 or version > VERSION or not raw.has("best_score"):
		return {}
	var data := defaults()
	var feedback: Variant = raw.get("feedback", {})
	if feedback is Dictionary:
		var volume: Variant = feedback.get("sfx_volume", 0.65)
		if volume is float or volume is int:
			data.feedback.sfx_volume = clampf(float(volume), 0.0, 1.0) if is_finite(float(volume)) else 0.65
		for key in ["muted", "haptics", "screen_shake"]:
			if feedback.get(key) is bool:
				data.feedback[key] = feedback[key]
	for key in ["best_score", "total_runs"]:
		data[key] = int(number(raw.get(key, 0)))
	for key in ["total_distance", "total_seconds"]:
		data[key] = number(raw.get(key, 0.0))
	var daily: Variant = raw.get("daily", {})
	if daily is Dictionary:
		var date_pattern := RegEx.new()
		date_pattern.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
		for date in daily:
			if not date is String or date_pattern.search(date) == null or not daily[date] is Dictionary:
				continue
			var day: Dictionary = daily[date]
			data.daily[date] = {"runs": int(number(day.get("runs", 0))),
				"distance": number(day.get("distance", 0.0)), "seconds": number(day.get("seconds", 0.0)),
				"best": int(number(day.get("best", 0)))}
	var unlocked: Variant = raw.get("unlocked", [])
	if unlocked is Array:
		for cosmetic in ["violet", "gold"]:
			if cosmetic in unlocked:
				data.unlocked.append(cosmetic)
	if raw.get("selected", "cyan") in data.unlocked:
		data.selected = raw.get("selected", "cyan")
	var milestones: Variant = raw.get("milestones", [])
	if milestones is Array:
		# JSON parses numbers as floats; Array membership is type-sensitive.
		for value in milestones:
			var milestone := int(number(value))
			if milestone in [100, 250, 500, 1000] and not milestone in data.milestones:
				data.milestones.append(milestone)
	return data
