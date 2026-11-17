extends SceneTree
## Regenerate distributable PNGs from the original vector artwork. No plugins.

func _initialize() -> void:
	var names: Array[String] = ["launcher", "adaptive_foreground", "adaptive_background", "adaptive_monochrome", "boot_splash"]
	for name in names:
		var base := "res://assets/android/" + name
		var svg := FileAccess.get_file_as_string(base + ".svg")
		var image := Image.new()
		if image.load_svg_from_string(svg) != OK or image.save_png(base + ".png") != OK:
			push_error("Failed to generate " + base + ".png")
			quit(1)
			return
		print(name, ": ", image.get_width(), "x", image.get_height())
	quit(0)
