extends "res://scripts/ads/ad_provider.gd"
## Adapter verified against Poing Studios v5.1.0 tagged source, not legacy v3/v4 APIs.
## Dynamic Script loading keeps this file parseable when the optional addon is absent.

const ROOT: String = "res://addons/admob/gdscript/src/"
const PATHS: Dictionary = {
	"MobileAds": "api/MobileAds.gd",
	"AdRequest": "api/core/AdRequest.gd",
	"RequestConfiguration": "api/core/RequestConfiguration.gd",
	"RewardedAdLoader": "api/RewardedAdLoader.gd",
	"InterstitialAdLoader": "api/InterstitialAdLoader.gd",
	"RewardedAdLoadCallback": "api/listeners/RewardedAdLoadCallback.gd",
	"InterstitialAdLoadCallback": "api/listeners/InterstitialAdLoadCallback.gd",
	"FullScreenContentCallback": "api/listeners/FullScreenContentCallback.gd",
	"OnUserEarnedRewardListener": "api/listeners/OnUserEarnedRewardListener.gd",
	"OnInitializationCompleteListener": "api/listeners/OnInitializationCompleteListener.gd",
	"UserMessagingPlatform": "ump/api/UserMessagingPlatform.gd",
	"ConsentRequestParameters": "ump/core/ConsentRequestParameters.gd"
}
var api: Dictionary = {}
var ads: Dictionary = {}
var loaded_at: Dictionary = {}
var generations: Dictionary = {"rewarded": 0, "interstitial": 0}
var requests: Dictionary = {}
var consent_epoch: int = 0
var consent_form: Object
var consent_allowed: bool = false
var consent_update_pending: bool = false
var sdk_initialized: bool = false
var initialization_listener: Object
var active_ad: Object
var reward_listener: Object

func _ready() -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.connect("feedback_settings_changed", _sync_ad_audio)

func _sync_ad_audio() -> void:
	if not sdk_initialized:
		return
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var data: Dictionary = state.get("data")
	var settings: Dictionary = data.get("feedback", {})
	api.MobileAds.set_app_volume(float(settings.get("sfx_volume", 0.65)))
	api.MobileAds.set_app_muted(bool(settings.get("muted", false)) or float(settings.get("sfx_volume", 0.65)) <= 0.0)

func supported() -> bool:
	if OS.get_name() != "Android":
		return false
	for singleton in ["PoingGodotAdMob", "PoingGodotAdMobRewardedAd", "PoingGodotAdMobInterstitialAd", "PoingGodotAdMobConsentInformation", "PoingGodotAdMobUserMessagingPlatform"]:
		if not Engine.has_singleton(singleton):
			return false
	var version := ConfigFile.new()
	if version.load("res://addons/admob/plugin.cfg") != OK or str(version.get_value("plugin", "version", "")).trim_prefix("v") != "5.1.0":
		return false
	for name in PATHS:
		if not ResourceLoader.exists(ROOT + str(PATHS[name])):
			return false
	for name in PATHS:
		api[name] = load(ROOT + str(PATHS[name]))
		if api[name] == null:
			return false
	return true

func update_consent() -> void:
	consent_allowed = false
	consent_update_pending = true
	clear_ads()
	consent_epoch += 1
	var epoch := consent_epoch
	var parameters: Object = api.ConsentRequestParameters.new()
	parameters.tag_for_under_age_of_consent = false
	var info: Object = api.UserMessagingPlatform.consent_information
	info.update(parameters, _info_updated.bind(epoch), _consent_error.bind(epoch))
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if epoch == consent_epoch and consent_update_pending:
			consent_epoch += 1
			consent_update_pending = false
			consent_resolved.emit(false, false)
	)

func _info_updated(epoch: int) -> void:
	if epoch != consent_epoch:
		return
	var info: Object = api.UserMessagingPlatform.consent_information
	# v5.1.0 exposes ConsentStatus (no can_request_ads method): 0 unknown,
	# 1 not required, 2 required, 3 obtained. Never infer permission from geography.
	if int(info.get_consent_status()) == 2:
		if not info.get_is_consent_form_available():
			_consent_error(null, epoch)
			return
		api.UserMessagingPlatform.load_consent_form(_form_loaded.bind(epoch), _consent_error.bind(epoch))
	else:
		_resolve_consent(null)

func _form_loaded(form: Object, epoch: int) -> void:
	if epoch != consent_epoch:
		return
	consent_form = form
	consent_update_pending = false
	# Manager waits until the menu is active before permitting form presentation.
	consent_form_ready.emit()

func show_consent_form() -> void:
	if consent_form != null:
		consent_form.show(_resolve_consent)

func show_privacy_options() -> void:
	consent_allowed = false
	consent_epoch += 1
	consent_update_pending = false
	clear_ads()
	api.UserMessagingPlatform.show_privacy_options_form(_resolve_consent)

func _resolve_consent(error: Object) -> void:
	consent_form = null
	consent_update_pending = false
	var info: Object = api.UserMessagingPlatform.consent_information
	consent_allowed = error == null and int(info.get_consent_status()) in [1, 3]
	consent_resolved.emit(consent_allowed, int(info.get_privacy_options_requirement_status()) == 2)

func _consent_error(_error: Object, epoch: int) -> void:
	if epoch != consent_epoch:
		return
	consent_epoch += 1
	consent_form = null
	consent_update_pending = false
	consent_allowed = false
	consent_resolved.emit(false, false)

func initialize_sdk() -> void:
	if not consent_allowed:
		initialized.emit(false)
		return
	if sdk_initialized:
		initialized.emit(true)
		return
	var configuration: Object = api.RequestConfiguration.new()
	configuration.max_ad_content_rating = "G"
	# Audience must be explicitly reviewed as general audience before enabling.
	configuration.tag_for_child_directed_treatment = 0
	configuration.tag_for_under_age_of_consent = 0
	api.MobileAds.set_request_configuration(configuration)
	api.MobileAds.set_publisher_first_party_id_enabled(false)
	initialization_listener = api.OnInitializationCompleteListener.new()
	initialization_listener.on_initialization_complete = func(_status: Object) -> void:
		sdk_initialized = true
		_sync_ad_audio()
		initialized.emit(true)
	api.MobileAds.initialize(initialization_listener)

func load_ad(kind: String, unit_id: String) -> void:
	if not consent_allowed or not sdk_initialized:
		load_failed.emit(kind)
		return
	generations[kind] = int(generations[kind]) + 1
	var generation: int = generations[kind]
	var loader_name := "RewardedAdLoader" if kind == "rewarded" else "InterstitialAdLoader"
	var callback_name := "RewardedAdLoadCallback" if kind == "rewarded" else "InterstitialAdLoadCallback"
	var loader: Object = api[loader_name].new()
	var callback: Object = api[callback_name].new()
	callback.on_ad_loaded = _loaded.bind(kind, generation)
	callback.on_ad_failed_to_load = _load_error.bind(kind, generation)
	requests[kind] = [loader, callback]
	var request: Object = api.AdRequest.new()
	# Request non-personalized ads even after UMP. This flag does NOT replace
	# storage/access consent. Regional choices/GPP signals remain UMP-managed.
	request.extras = {"npa": "1"}
	loader.load(unit_id, request, callback)
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		if generation == int(generations[kind]) and requests.has(kind):
			generations[kind] = generation + 1
			requests.erase(kind)
			load_failed.emit(kind)
	)

func _loaded(ad: Object, kind: String, generation: int) -> void:
	if generation != int(generations[kind]) or not consent_allowed:
		ad.destroy()
		return
	requests.erase(kind)
	ads[kind] = ad
	loaded_at[kind] = Time.get_ticks_msec()
	loaded.emit(kind)

func _load_error(_error: Object, kind: String, generation: int) -> void:
	if generation != int(generations[kind]):
		return
	requests.erase(kind)
	load_failed.emit(kind)

func available(kind: String) -> bool:
	if not consent_allowed or not ads.has(kind):
		return false
	if Time.get_ticks_msec() - int(loaded_at.get(kind, 0)) > 3300000:
		ads[kind].destroy()
		ads.erase(kind)
		return false
	return true

func show_ad(kind: String, token: int) -> void:
	if not available(kind) or active_ad != null:
		show_failed.emit(kind, token)
		return
	active_ad = ads[kind]
	ads.erase(kind)
	var callbacks: Object = api.FullScreenContentCallback.new()
	callbacks.on_ad_showed_full_screen_content = func() -> void: presented.emit(kind, token)
	callbacks.on_ad_dismissed_full_screen_content = _closed.bind(kind, token, false)
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: Object) -> void: _closed(kind, token, true)
	active_ad.full_screen_content_callback = callbacks
	if kind == "rewarded":
		reward_listener = api.OnUserEarnedRewardListener.new()
		reward_listener.on_user_earned_reward = func(item: Object) -> void:
			if item != null and int(item.amount) > 0:
				reward_earned.emit(token)
		active_ad.show(reward_listener)
	else:
		active_ad.show()

func _closed(kind: String, token: int, failed: bool) -> void:
	if active_ad != null:
		active_ad.destroy()
	active_ad = null
	reward_listener = null
	if failed:
		show_failed.emit(kind, token)
	else:
		dismissed.emit(kind, token)

func clear_ads() -> void:
	for kind in generations:
		generations[kind] = int(generations[kind]) + 1
	requests.clear()
	for ad in ads.values():
		ad.destroy()
	ads.clear()

func _exit_tree() -> void:
	clear_ads()
	if active_ad != null:
		active_ad.destroy()
