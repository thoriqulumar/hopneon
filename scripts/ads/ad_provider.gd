extends Node
## Project-owned contract. SDK-specific APIs belong only in poing_provider.gd.

signal consent_form_ready
signal consent_resolved(allowed: bool, privacy_required: bool)
signal initialized(success: bool)
signal loaded(kind: String)
signal load_failed(kind: String)
signal presented(kind: String, token: int)
signal dismissed(kind: String, token: int)
signal show_failed(kind: String, token: int)
signal reward_earned(token: int)

func supported() -> bool:
	return false

func update_consent() -> void:
	consent_resolved.emit(false, false)

func show_consent_form() -> void:
	consent_resolved.emit(false, false)

func show_privacy_options() -> void:
	consent_resolved.emit(false, false)

func initialize_sdk() -> void:
	initialized.emit(false)

func load_ad(_kind: String, _unit_id: String) -> void:
	pass

func available(_kind: String) -> bool:
	return false

func show_ad(kind: String, token: int) -> void:
	show_failed.emit(kind, token)

func clear_ads() -> void:
	pass
