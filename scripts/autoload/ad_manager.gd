extends Node
## Only this coordinator may present ads. Loading never schedules a later show.

signal availability_changed
signal reward_completed(granted: bool)
signal privacy_changed
signal fullscreen_started

const Provider := preload("res://scripts/ads/poing_provider.gd")
const TEST_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL: String = "ca-app-pub-3940256099942544/1033173712"
const MIN_BREAK_RUNS: int = 3
const INTERSTITIAL_COOLDOWN: float = 120.0
const REWARDED_COOLDOWN: float = 30.0
const MAX_INTERSTITIALS: int = 3

var provider: Node
var config := ConfigFile.new()
var enabled: bool = false
var test_ads: bool = true
var consent_allowed: bool = false
var consent_pending: bool = false
var consent_form_pending: bool = false
var privacy_busy: bool = false
var privacy_required: bool = false
var sdk_ready: bool = false
var initializing: bool = false
var initialization_attempted: bool = false
var context: String = "menu"
var status: String = "Ads disabled"
var run_id: int = 0
var reward_attempted: bool = false
var reward_used: bool = false
var completed_runs: int = 0
var finalized_run: int = -1
var interstitial_count: int = 0
var runs_at_last_interstitial: int = 0
var last_fullscreen: float = -100000.0
var session_started: float = 0.0
var token_counter: int = 0
var active: Dictionary = {}
var pending_break: Callable
var loading: Dictionary = {"rewarded": false, "interstitial": false}
var retry_at: Dictionary = {"rewarded": 0.0, "interstitial": 0.0}
var attempts: Dictionary = {"rewarded": 0, "interstitial": 0}
var poll_elapsed: float = 0.0

func _ready() -> void:
	session_started = _now()
	if config.load("res://config/ads.cfg") != OK:
		return
	enabled = config.get_value("ads", "enabled", false) == true
	test_ads = OS.is_debug_build() or config.get_value("ads", "test_ads", true) != false
	if not enabled:
		return
	if not _configuration_safe():
		enabled = false
		status = "Ads disabled: finish audience, consent, and identifier setup"
		return
	var candidate := Provider.new()
	if not candidate.supported():
		candidate.free()
		status = "Ads unavailable: Android Poing v5.1.0 plugin not installed"
		return
	_bind_provider(candidate)
	status = "Privacy choices need checking"

func _configuration_safe() -> bool:
	if config.get_value("ads", "audience_reviewed", false) != true or config.get_value("ads", "consent_messages_configured", false) != true:
		return false
	if config.get_value("ads", "audience", "unconfigured") != "general_audience":
		return false
	if test_ads:
		return true
	if config.get_value("ads", "production_ready", false) != true:
		return false
	var id_pattern := RegEx.new()
	id_pattern.compile("^ca-app-pub-[0-9]{16}/[0-9]{10}$")
	var app_pattern := RegEx.new()
	app_pattern.compile("^ca-app-pub-[0-9]{16}~[0-9]{10}$")
	var app_id := str(config.get_value("ads", "android_app_id", ""))
	if app_pattern.search(app_id) == null or app_id == TEST_APP_ID:
		return false
	# Prevent an app-ID mismatch: this project setting is read by Poing's exporter.
	if str(ProjectSettings.get_setting("admob/general/android/app_id", "")) != app_id:
		return false
	for key in ["rewarded_unit_id", "interstitial_unit_id"]:
		var unit := str(config.get_value("ads", key, ""))
		if id_pattern.search(unit) == null or unit.begins_with("ca-app-pub-3940256099942544/"):
			return false
	return true

func _bind_provider(value: Node) -> void:
	provider = value
	add_child(provider)
	provider.consent_form_ready.connect(_consent_form_ready)
	provider.consent_resolved.connect(_consent_resolved)
	provider.initialized.connect(_initialized)
	provider.loaded.connect(_loaded)
	provider.load_failed.connect(_load_failed)
	provider.presented.connect(_presented)
	provider.dismissed.connect(_dismissed)
	provider.show_failed.connect(_show_failed)
	provider.reward_earned.connect(_reward_earned)

func enter_menu() -> void:
	if not active.is_empty():
		return
	context = "menu"
	if provider == null:
		return
	if consent_form_pending:
		_show_pending_consent()
	elif consent_allowed:
		_start_sdk()
	elif not consent_pending:
		consent_pending = true
		provider.update_consent()

func begin_run() -> void:
	if privacy_busy or not active.is_empty():
		return
	run_id += 1
	reward_attempted = false
	reward_used = false
	context = "playing"
	availability_changed.emit()

func game_over() -> void:
	if active.is_empty():
		context = "game_over"
	availability_changed.emit()

func resume_rewarded_run() -> void:
	if reward_used and active.is_empty():
		context = "playing"
	availability_changed.emit()

func reward_available() -> bool:
	return context == "game_over" and run_id > 0 and not reward_used and not reward_attempted and _can_request() and active.is_empty() and _now() - last_fullscreen >= REWARDED_COOLDOWN and provider.available("rewarded")

func request_extra_life() -> bool:
	if not reward_available():
		return false
	reward_attempted = true
	_start_show("rewarded")
	return true

func request_game_over_break(action: Callable) -> void:
	if context != "game_over" or not active.is_empty():
		return
	if finalized_run != run_id:
		finalized_run = run_id
		completed_runs += 1
	if _interstitial_available():
		pending_break = action
		interstitial_count += 1
		runs_at_last_interstitial = completed_runs
		_start_show("interstitial")
	else:
		# No waiting for network, no delayed popup after play has resumed.
		action.call()

func _interstitial_available() -> bool:
	return _can_request() and context == "game_over" and active.is_empty() and completed_runs - runs_at_last_interstitial >= MIN_BREAK_RUNS and interstitial_count < MAX_INTERSTITIALS and _now() - session_started >= INTERSTITIAL_COOLDOWN and _now() - last_fullscreen >= INTERSTITIAL_COOLDOWN and provider.available("interstitial")

func _start_show(kind: String) -> void:
	token_counter += 1
	active = {"kind": kind, "token": token_counter, "run": run_id, "earned": false}
	context = "ad"
	last_fullscreen = _now()
	var feedback := get_node_or_null("/root/Feedback")
	if feedback != null:
		feedback.call("stop_all")
	availability_changed.emit()
	provider.show_ad(kind, token_counter)

func _presented(kind: String, token: int) -> void:
	if _matches(kind, token):
		fullscreen_started.emit()

func _reward_earned(token: int) -> void:
	if _matches("rewarded", token) and not reward_used:
		active.earned = true

func _matches(kind: String, token: int) -> bool:
	return not active.is_empty() and active.kind == kind and int(active.token) == token and int(active.run) == run_id and context == "ad"

func _dismissed(kind: String, token: int) -> void:
	if not _matches(kind, token):
		return
	_finish_show(kind, bool(active.earned))

func _show_failed(kind: String, token: int) -> void:
	if not _matches(kind, token):
		return
	status = "Ad unavailable. You can keep playing."
	_finish_show(kind, false)

func _finish_show(kind: String, earned: bool) -> void:
	active.clear()
	context = "game_over"
	retry_at[kind] = _now() + 30.0
	last_fullscreen = _now()
	availability_changed.emit()
	if kind == "rewarded":
		reward_used = earned
		reward_completed.emit(earned)
	elif pending_break.is_valid():
		var action := pending_break
		pending_break = Callable()
		action.call()

func _can_request() -> bool:
	return provider != null and consent_allowed and sdk_ready and not privacy_busy

func privacy_entry_available() -> bool:
	return provider != null

func request_privacy_options() -> void:
	if context != "menu" or provider == null or privacy_busy or not active.is_empty():
		return
	if not privacy_required:
		if not consent_pending:
			consent_pending = true
			provider.update_consent()
		return
	consent_allowed = false
	privacy_busy = true
	loading = {"rewarded": false, "interstitial": false}
	provider.clear_ads()
	privacy_changed.emit()
	availability_changed.emit()
	provider.show_privacy_options()

func _consent_form_ready() -> void:
	consent_form_pending = true
	if context == "menu":
		_show_pending_consent()

func _show_pending_consent() -> void:
	if context != "menu" or privacy_busy:
		return
	privacy_busy = true
	privacy_changed.emit()
	provider.show_consent_form()

func _consent_resolved(allowed: bool, required: bool) -> void:
	consent_allowed = allowed
	privacy_required = required
	privacy_busy = false
	consent_pending = false
	consent_form_pending = false
	loading = {"rewarded": false, "interstitial": false}
	status = "Ads available after privacy check" if allowed else "Ads unavailable. Play works offline."
	privacy_changed.emit()
	availability_changed.emit()
	if allowed and context == "menu":
		_start_sdk()

func _start_sdk() -> void:
	if sdk_ready or initialization_attempted or not consent_allowed:
		return
	initializing = true
	initialization_attempted = true
	provider.initialize_sdk()
	get_tree().create_timer(35.0).timeout.connect(func() -> void:
		if initializing:
			initializing = false
			status = "Ads unavailable: initialization timed out"
	)

func _initialized(success: bool) -> void:
	initializing = false
	sdk_ready = success
	availability_changed.emit()

func _process(delta: float) -> void:
	poll_elapsed += delta
	if poll_elapsed < 1.0 or not _can_request() or not active.is_empty():
		return
	poll_elapsed = 0.0
	for kind in ["rewarded", "interstitial"]:
		if not loading[kind] and not provider.available(kind) and _now() >= float(retry_at[kind]):
			loading[kind] = true
			var unit: String = TEST_REWARDED if kind == "rewarded" else TEST_INTERSTITIAL
			if not test_ads:
				unit = str(config.get_value("ads", kind + "_unit_id", ""))
			provider.load_ad(kind, unit)
			availability_changed.emit()

func _loaded(kind: String) -> void:
	loading[kind] = false
	attempts[kind] = 0
	availability_changed.emit()

func _load_failed(kind: String) -> void:
	loading[kind] = false
	attempts[kind] = mini(int(attempts[kind]) + 1, 5)
	retry_at[kind] = _now() + minf(30.0 * pow(2.0, int(attempts[kind]) - 1), 300.0)
	status = "Ad unavailable. Play works offline."
	availability_changed.emit()

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
