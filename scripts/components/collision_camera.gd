extends Camera2D
## Only the world camera moves. HUD and touch targets remain fixed.

const DURATION: float = 0.18
const STRENGTH: float = 4.0
var remaining: float = 0.0

func _ready() -> void:
	get_viewport().size_changed.connect(_align_view)
	_align_view()

func _align_view() -> void:
	position = get_viewport_rect().size * 0.5

func shake() -> void:
	if GameState.data.feedback.screen_shake:
		remaining = DURATION

func reset_shake() -> void:
	remaining = 0.0
	offset = Vector2.ZERO
	force_update_scroll()

func _process(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(remaining - delta, 0.0)
	var elapsed := DURATION - remaining
	var strength := STRENGTH * pow(remaining / DURATION, 2.0)
	offset = Vector2(sin(elapsed * 130.0), sin(elapsed * 97.0)).limit_length(1.0) * strength
	if remaining == 0.0:
		offset = Vector2.ZERO
