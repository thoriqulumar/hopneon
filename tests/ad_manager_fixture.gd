extends "res://scripts/autoload/ad_manager.gd"

var clock_seconds: float = 1000.0

func _now() -> float:
	return clock_seconds
