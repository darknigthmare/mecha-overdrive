extends Control
class_name MainMenuScreen

signal race_requested(config: Dictionary)
signal screen_requested(screen_id: StringName)
signal quit_requested

const ThemeFactory = preload("res://scripts/ui/ui_theme.gd")

@onready var credits_value: Label = %CreditsValue
@onready var pilot_value: Label = %PilotValue
@onready var chassis_class: Label = %ChassisClass
@onready var chassis_name: Label = %ChassisName
@onready var chassis_trait: Label = %ChassisTrait
@onready var career_summary: Label = %CareerSummary
@onready var status_message: Label = %StatusMessage
@onready var hero_panel: PanelContainer = %HeroPanel
@onready var contrast_toggle: CheckButton = %ContrastToggle
@onready var motion_toggle: CheckButton = %MotionToggle
@onready var text_toggle: CheckButton = %TextToggle

@onready var quick_button: Button = %QuickButton
@onready var grand_prix_button: Button = %GrandPrixButton
@onready var time_trial_button: Button = %TimeTrialButton
@onready var elimination_button: Button = %EliminationButton
@onready var garage_button: Button = %GarageButton
@onready var codex_button: Button = %CodexButton
@onready var quit_button: Button = %QuitButton

var _settings: Dictionary = {}
var _last_focused: Control


func _ready() -> void:
	_bind_actions()
	_bind_services()
	_refresh_profile()
	_apply_accessibility(false)
	call_deferred("_configure_focus")
	call_deferred("_play_entrance")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_refresh_profile()
		call_deferred("_restore_focus")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(_last_focused):
			_last_focused.grab_focus()
		else:
			quick_button.grab_focus()


func refresh() -> void:
	_refresh_profile()
	_apply_accessibility(false)


func restore_focus() -> void:
	_restore_focus()


func _bind_actions() -> void:
	quick_button.pressed.connect(_start_mode.bind(&"quick"))
	grand_prix_button.pressed.connect(_start_mode.bind(&"grand_prix"))
	time_trial_button.pressed.connect(_start_mode.bind(&"time_trial"))
	elimination_button.pressed.connect(_start_mode.bind(&"elimination"))
	garage_button.pressed.connect(_open_screen.bind(&"garage"))
	codex_button.pressed.connect(_open_screen.bind(&"codex"))
	quit_button.pressed.connect(_request_quit)
	contrast_toggle.toggled.connect(_on_accessibility_toggled)
	motion_toggle.toggled.connect(_on_accessibility_toggled)
	text_toggle.toggled.connect(_on_accessibility_toggled)

	for control in _focus_controls():
		control.focus_entered.connect(_remember_focus.bind(control))


func _bind_services() -> void:
	var save := _save_system()
	if save == null:
		return
	var refresh_callable := Callable(self, "_on_profile_changed")
	for signal_name in [&"profile_loaded", &"profile_changed"]:
		if save.has_signal(signal_name) and not save.is_connected(signal_name, refresh_callable):
			save.connect(signal_name, refresh_callable)
	var failure_callable := Callable(self, "_on_save_failed")
	if save.has_signal(&"save_failed") and not save.is_connected(&"save_failed", failure_callable):
		save.connect(&"save_failed", failure_callable)


func _start_mode(mode: StringName) -> void:
	var track_id := _default_track_id()
	var config := {
		"mode": String(mode),
		"track_id": track_id,
		"difficulty": "pilot",
		"laps": 3,
		"new_championship": mode == &"grand_prix",
	}
	var session := _game_session()
	if session != null and session.has_method(&"configure"):
		var configured: Variant = session.call(&"configure", config)
		if configured is Dictionary:
			config = configured
	status_message.text = _mode_status(mode)
	race_requested.emit(config)


func _open_screen(screen_id: StringName) -> void:
	status_message.text = "OUVERTURE // %s" % String(screen_id).to_upper()
	screen_requested.emit(screen_id)


func _request_quit() -> void:
	quit_requested.emit()


func _on_accessibility_toggled(_enabled: bool) -> void:
	if not is_node_ready():
		return
	_settings["high_contrast"] = contrast_toggle.button_pressed
	_settings["reduced_motion"] = motion_toggle.button_pressed
	_settings["large_text"] = text_toggle.button_pressed
	var save := _save_system()
	if save != null and save.has_method(&"update_settings"):
		save.call(&"update_settings", _settings.duplicate(true))
	_apply_accessibility(true)
	status_message.text = "RÉGLAGES D’ACCESSIBILITÉ ENREGISTRÉS"


func _apply_accessibility(keep_focus: bool) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner() if keep_focus else null
	theme = ThemeFactory.create_theme(_settings)
	if is_instance_valid(focus_owner):
		focus_owner.call_deferred("grab_focus")


func _refresh_profile() -> void:
	var profile := _profile()
	_settings = _dictionary_value(profile, ["settings"], {}).duplicate(true)
	_set_toggle_without_signal(contrast_toggle, _bool_value(_settings, ["high_contrast", "highContrast"], false))
	_set_toggle_without_signal(motion_toggle, _bool_value(_settings, ["reduced_motion", "reducedMotion"], false))
	_set_toggle_without_signal(text_toggle, _bool_value(_settings, ["large_text", "largeText"], false))

	credits_value.text = "%s CR" % _format_number(_number_value(profile, ["credits"], 0.0))
	pilot_value.text = _string_value(profile, ["pilot_name", "pilotName"], "PILOTE 01").to_upper()

	var selected_id := _string_value(profile, ["selected_chassis", "selectedChassis"], "biped")
	var chassis: Variant = GameDatabase.get_chassis(selected_id)
	chassis_class.text = _string_value(chassis, ["category", "class_name"], "ARCHITECTURE").to_upper()
	chassis_name.text = _string_value(chassis, ["name"], selected_id).to_upper()
	chassis_trait.text = _string_value(chassis, ["subtitle", "trait"], "Configuration prête")

	var stats := _dictionary_value(profile, ["stats"], {})
	career_summary.text = _career_text(stats)
	status_message.text = "SYSTÈMES PRÊTS // SAISON 01"


func _career_text(stats: Dictionary) -> String:
	var races := roundi(_number_value(stats, ["races"], 0.0))
	var wins := roundi(_number_value(stats, ["wins"], 0.0))
	var podiums := roundi(_number_value(stats, ["podiums"], 0.0))
	var championships := roundi(_number_value(stats, ["championships"], 0.0))
	return "%d COURSES   •   %d VICTOIRES\n%d PODIUMS   •   %d CHAMPIONNATS" % [races, wins, podiums, championships]


func _mode_status(mode: StringName) -> String:
	match mode:
		&"grand_prix": return "GRAND PRIX // QUATRE MANCHES"
		&"time_trial": return "TÉLÉMÉTRIE SOLO // CHRONO"
		&"elimination": return "PROTOCOLE ÉLIMINATION // DERNIER EXCLU"
		_: return "COURSE RAPIDE // SEPT RIVAUX"


func _configure_focus() -> void:
	ThemeFactory.connect_focus_chain(_focus_controls())
	_restore_focus()


func _focus_controls() -> Array[Control]:
	return [
		quick_button, grand_prix_button, time_trial_button, elimination_button,
		garage_button, codex_button, contrast_toggle, motion_toggle, text_toggle, quit_button,
	]


func _remember_focus(control: Control) -> void:
	_last_focused = control


func _restore_focus() -> void:
	if not is_visible_in_tree():
		return
	if is_instance_valid(_last_focused) and _last_focused.is_visible_in_tree():
		_last_focused.grab_focus()
	else:
		quick_button.grab_focus()


func _play_entrance() -> void:
	if not is_instance_valid(hero_panel):
		return
	var duration := ThemeFactory.motion_duration(_settings, 0.24)
	if duration <= 0.0:
		hero_panel.modulate = Color.WHITE
		return
	hero_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(hero_panel, "modulate", Color.WHITE, duration)


func _on_profile_changed(_profile_data: Dictionary = {}) -> void:
	_refresh_profile()
	_apply_accessibility(true)


func _on_save_failed(message: String = "Sauvegarde indisponible") -> void:
	status_message.text = "ALERTE SAUVEGARDE // %s" % message.to_upper()
	status_message.theme_type_variation = &"WarningLabel"


func _save_system() -> Node:
	return get_node_or_null("/root/SaveSystem")


func _game_session() -> Node:
	return get_node_or_null("/root/GameSession")


func _profile() -> Dictionary:
	var save := _save_system()
	if save == null:
		return {}
	var value: Variant = save.get("profile")
	return value if value is Dictionary else {}


func _default_track_id() -> String:
	if not GameDatabase.TRACKS.is_empty():
		return _string_value(GameDatabase.TRACKS[0], ["id"], "foundry")
	return "foundry"


func _set_toggle_without_signal(toggle: CheckButton, value: bool) -> void:
	if not is_instance_valid(toggle):
		return
	toggle.set_pressed_no_signal(value)


func _dictionary_value(source: Variant, keys: Array[String], fallback: Dictionary) -> Dictionary:
	var value := _variant_value(source, keys, fallback)
	return value if value is Dictionary else fallback


func _string_value(source: Variant, keys: Array[String], fallback: String) -> String:
	var value := _variant_value(source, keys, fallback)
	return str(value) if value != null else fallback


func _number_value(source: Variant, keys: Array[String], fallback: float) -> float:
	var value := _variant_value(source, keys, fallback)
	return float(value) if value is int or value is float else fallback


func _bool_value(source: Variant, keys: Array[String], fallback: bool) -> bool:
	var value := _variant_value(source, keys, fallback)
	return bool(value) if value is bool else fallback


func _variant_value(source: Variant, keys: Array[String], fallback: Variant) -> Variant:
	if source is Dictionary:
		for key in keys:
			if source.has(key):
				return source[key]
	return fallback


func _format_number(value: float) -> String:
	var raw := str(roundi(value))
	var output := ""
	while raw.length() > 3:
		output = " %s%s" % [raw.right(3), output]
		raw = raw.left(raw.length() - 3)
	return raw + output
