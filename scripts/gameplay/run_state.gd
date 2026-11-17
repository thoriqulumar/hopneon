class_name NeonRunState
extends RefCounted

enum Phase { READY, RUNNING, PAUSED, GAME_OVER }

const START_SPEED: float = 315.0
const MAX_SPEED: float = 560.0
const SPEED_PER_DISTANCE: float = 0.012
const PIXELS_PER_POINT: float = 32.0

var phase: Phase = Phase.READY
var elapsed_seconds: float = 0.0
var distance_pixels: float = 0.0
var speed: float = START_SPEED
var score: int = 0

func reset() -> void:
	phase = Phase.READY
	elapsed_seconds = 0.0
	distance_pixels = 0.0
	speed = START_SPEED
	score = 0

func start() -> void:
	if phase == Phase.READY:
		phase = Phase.RUNNING

func advance(delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	elapsed_seconds += delta
	distance_pixels += speed * delta
	speed = minf(START_SPEED + SPEED_PER_DISTANCE * distance_pixels, MAX_SPEED)
	score = int(floorf(distance_pixels / PIXELS_PER_POINT))

func toggle_pause() -> bool:
	if phase == Phase.RUNNING:
		phase = Phase.PAUSED
		return true
	if phase == Phase.PAUSED:
		phase = Phase.RUNNING
	return false

func end_run() -> void:
	phase = Phase.GAME_OVER

func is_playing() -> bool:
	return phase == Phase.RUNNING
