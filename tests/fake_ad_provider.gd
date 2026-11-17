extends "res://scripts/ads/ad_provider.gd"
## Local event fixture only: no SDK, network, UI simulation, or impressions.

var ready_ads: Dictionary = {"rewarded": false, "interstitial": false}
var load_calls: Array[Dictionary] = []
var show_calls: Array[Dictionary] = []
var consent_calls: int = 0
var form_calls: int = 0
var init_calls: int = 0
var auto_load: bool = true

func update_consent() -> void:
	consent_calls += 1

func show_consent_form() -> void:
	form_calls += 1

func show_privacy_options() -> void:
	form_calls += 1

func initialize_sdk() -> void:
	init_calls += 1
	initialized.emit(true)

func load_ad(kind: String, unit_id: String) -> void:
	load_calls.append({"kind": kind, "id": unit_id})
	if auto_load:
		ready_ads[kind] = true
		loaded.emit(kind)

func available(kind: String) -> bool:
	return ready_ads.get(kind, false)

func show_ad(kind: String, token: int) -> void:
	ready_ads[kind] = false
	show_calls.append({"kind": kind, "token": token})
	presented.emit(kind, token)

func clear_ads() -> void:
	ready_ads = {"rewarded": false, "interstitial": false}
