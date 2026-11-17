extends SceneTree
## Static preparation checks only. This script does NOT export an Android build.

var failures: Array[String] = []

func _initialize() -> void:
	_check(ProjectSettings.get_setting("display/window/handheld/orientation") == 1, "portrait orientation")
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "canvas scaling")
	_check(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "touch UI emulation")
	_check(not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"), "no duplicate desktop touch emulation")
	var config := ConfigFile.new()
	_check(config.load("res://export_presets.cfg") == OK, "export config loads")
	var native_ads: bool = ProjectSettings.get_setting("admob/general/android/enabled", false)
	var package_pattern := RegEx.new()
	package_pattern.compile("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")
	for index in 2:
		var section := "preset.%d.options" % index
		_check(package_pattern.search(config.get_value(section, "package/unique_name")) != null, "valid configurable package identifier")
		_check(config.get_value(section, "package/name") == "Neon Hop", "app label")
		_check(config.get_value(section, "version/code") > 0 and config.get_value(section, "version/name") == ProjectSettings.get_setting("application/config/version"), "consistent release version")
		for key in ["keystore/debug", "keystore/debug_password", "keystore/debug_user", "keystore/release", "keystore/release_user", "keystore/release_password"]:
			_check(config.get_value(section, key, "") == "", "no embedded signing values")
		for key in config.get_section_keys(section):
			if key.begins_with("permissions/") and key != "permissions/vibrate" and key != "permissions/custom_permissions":
				var network_permission: bool = key in ["permissions/internet", "permissions/access_network_state"]
				_check(config.get_value(section, key) == (native_ads and network_permission), "permissions match optional ads packaging")
			if key.begins_with("launcher_icons/"):
				var image := _source_png(config.get_value(section, key))
				_check(image != null and image.get_width() >= 432 and image.get_height() >= 432, "launcher PNG dimensions")
		_check(config.get_value(section, "permissions/vibrate"), "haptics permission")
		_check(not config.get_value(section, "user_data_backup/allow"), "local-only save preference")
		_check("config/*.cfg" in str(config.get_value("preset.%d" % index, "include_filter", "")), "ads feature config included in exports")
		if native_ads:
			_check(config.get_value(section, "gradle_build/use_gradle_build"), "native ads require Gradle")
	if not native_ads:
		_check(not config.get_value("preset.0.options", "gradle_build/use_gradle_build"), "offline debug prebuilt APK")
	_check(config.get_value("preset.1.options", "gradle_build/use_gradle_build"), "release Gradle build")
	_check(config.get_value("preset.1.options", "gradle_build/export_format") == 1, "release AAB")
	_check(config.get_value("preset.1.options", "gradle_build/target_sdk") == "36", "release target API 36")
	var splash := _source_png(ProjectSettings.get_setting("application/boot_splash/image"))
	_check(splash != null and splash.get_size() == Vector2i(540, 960), "portrait splash exists")
	var foreground := _source_png("res://assets/android/adaptive_foreground.png")
	var background := _source_png("res://assets/android/adaptive_background.png")
	_check(foreground != null and foreground.get_pixel(0, 0).a == 0.0, "transparent adaptive foreground")
	_check(background != null and background.get_pixel(0, 0).a == 1.0, "opaque full-bleed background")
	for failure in failures:
		push_error(failure)
	print("ANDROID CONFIG CHECK: ", "PASS" if failures.is_empty() else "FAIL", " (no APK/AAB built)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _source_png(path: String) -> Image:
	# This tooling script checks original files and is excluded from exports.
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return image
