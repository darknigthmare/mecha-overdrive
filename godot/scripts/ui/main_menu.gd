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
@onready var track_select: OptionButton = %TrackSelect
@onready var difficulty_select: OptionButton = %DifficultySelect
@onready var grid_policy_select: OptionButton = %GridPolicySelect
@onready var championship_select: OptionButton = %ChampionshipSelect
@onready var rule_summary: Label = %RuleSummary

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
	_setup_race_options()
	if OS.has_feature("web"):
		quit_button.hide()
	_bind_actions()
	_bind_services()
	_refresh_profile()
	_apply_accessibility(false)
	call_deferred("_configure_focus")
	call_deferred("_play_entrance")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		if not is_node_ready():
			return
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
	track_select.item_selected.connect(_on_race_option_selected)
	difficulty_select.item_selected.connect(_on_race_option_selected)
	grid_policy_select.item_selected.connect(_on_race_option_selected)
	championship_select.item_selected.connect(_on_race_option_selected)

	for control in _focus_controls():
		control.focus_entered.connect(_remember_focus.bind(control))


func _bind_services() -> void:
	var save := _save_system()
	if save == null:
		return
	var refresh_callable := Callable(self, "_on_profile_changed")
	var profile_signals: Array[StringName] = [&"profile_loaded", &"profile_changed"]
	for signal_name: StringName in profile_signals:
		if save.has_signal(signal_name) and not save.is_connected(signal_name, refresh_callable):
			save.connect(signal_name, refresh_callable)
	var failure_callable := Callable(self, "_on_save_failed")
	if save.has_signal(&"save_failed") and not save.is_connected(&"save_failed", failure_callable):
		save.connect(&"save_failed", failure_callable)


func _start_mode(mode: StringName) -> void:
	var track_id := _selected_track_id()
	var track := GameDatabase.get_track(track_id)
	var profile := _profile()
	var selected_chassis := GameDatabase.get_chassis(_string_value(profile, ["selected_chassis", "selectedChassis"], "biped"))
	var selected_chassis_id := String(selected_chassis.get("id", "biped"))
	var active_category := GameDatabase.get_race_category_for_chassis(selected_chassis_id)
	var active_division := String(selected_chassis.get("division_id", "command"))
	var grid_policy := _selected_grid_policy()
	var config := {
		"mode": String(mode),
		"track_id": track_id,
		"difficulty": _selected_difficulty_id(),
		"laps": int(track.get("default_laps", 3)),
		"division_id": active_division,
		"race_category_id": String(active_category.get("id", selected_chassis_id)),
		"category_chassis_id": selected_chassis_id,
		"grid_policy": grid_policy,
		"ruleset_id": "open_mixed" if grid_policy == "mixed" else "division_locked",
		"new_championship": false,
	}
	if mode == &"grand_prix":
		var cup_id := _selected_championship_id()
		var cup := GameDatabase.get_championship(cup_id)
		var access := _championship_access(cup_id)
		if not bool(access.get("available", false)):
			_show_championship_locked(access)
			return
		var cup_division := String(cup.get("division_id", ""))
		var cup_chassis_id := String(cup.get("category_chassis_id", ""))
		var active_championship := _active_championship()
		var resume_active := not active_championship.is_empty() and String(active_championship.get("championship_id", "")) == cup_id
		if not resume_active and not bool(cup.get("mixed_divisions", false)) and cup_chassis_id != selected_chassis_id:
			var required_category := GameDatabase.get_race_category_for_chassis(cup_chassis_id)
			status_message.theme_type_variation = &"WarningLabel"
			status_message.text = "CATÉGORIE INCOMPATIBLE // ÉQUIPEZ UN %s AU GARAGE" % String(required_category.get("name", cup_chassis_id)).to_upper()
			return
		config["new_championship"] = not resume_active
		config["championship_id"] = cup_id
		config["cup_id"] = cup_id
		config["division_id"] = cup_division if not cup_division.is_empty() else active_division
		config["category_chassis_id"] = cup_chassis_id if not cup_chassis_id.is_empty() else selected_chassis_id
		config["race_category_id"] = String(GameDatabase.get_race_category_for_chassis(String(config["category_chassis_id"])).get("id", config["category_chassis_id"]))
		config["grid_policy"] = "mixed" if bool(cup.get("mixed_divisions", false)) else "division"
	var session := _game_session()
	if session != null and session.has_method(&"configure"):
		var configured: Variant = session.call(&"configure", config)
		if configured is Dictionary:
			config = configured
	status_message.theme_type_variation = &"MutedLabel"
	status_message.text = _mode_status(mode)
	race_requested.emit(config)


func _open_screen(screen_id: StringName) -> void:
	status_message.text = "OUVERTURE // %s" % String(screen_id).to_upper()
	screen_requested.emit(screen_id)


func _request_quit() -> void:
	quit_requested.emit()


func _on_race_option_selected(_index: int) -> void:
	_refresh_rule_summary()
	_refresh_championship_action()
	var access := _championship_access()
	if not bool(access.get("available", false)):
		_show_championship_locked(access)
		return
	status_message.theme_type_variation = &"MutedLabel"
	status_message.text = "CONFIGURATION // %s" % rule_summary.text


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
	var chassis: Dictionary = GameDatabase.get_chassis(selected_id)
	var division := GameDatabase.get_division(String(chassis.get("division_id", "command")))
	chassis_class.text = "%s  //  %s" % [_string_value(chassis, ["category", "class_name"], "ARCHITECTURE").to_upper(), String(division.get("name", "DIVISION")).to_upper()]
	chassis_name.text = _string_value(chassis, ["name"], selected_id).to_upper()
	chassis_trait.text = _string_value(chassis, ["subtitle", "trait"], "Configuration prête")

	var stats := _dictionary_value(profile, ["stats"], {})
	career_summary.text = _career_text(stats)
	var active_championship := _active_championship()
	_refresh_championship_items()
	if active_championship.is_empty():
		_select_championship_for_chassis(String(chassis.get("id", "biped")))
	else:
		_select_championship_by_id(String(active_championship.get("championship_id", "command_cup")))
		_select_difficulty_by_id(String(active_championship.get("difficulty", "pilot")))
	_refresh_rule_summary()
	_refresh_championship_action()
	status_message.text = _season_status(active_championship)


func _season_status(active_championship: Dictionary) -> String:
	if active_championship.is_empty():
		for championship: Dictionary in GameDatabase.get_all_championships():
			var requirement_value: Variant = championship.get("unlock_requirement", {})
			if not requirement_value is Dictionary:
				continue
			var requirement: Dictionary = requirement_value
			if requirement.is_empty():
				continue
			var access := _championship_access(String(championship.get("id", "")))
			if not bool(access.get("available", false)):
				return String(access.get("locked_status", "SAISON 03 // CHAMPIONNAT VERROUILLÉ"))
			return String(access.get("unlocked_status", "SAISON 03 // CHAMPIONNAT DISPONIBLE"))
		return "SAISON 03 // GAGNEZ UNE COUPE • DÉFIEZ VEX • PRENEZ LA COURONNE"
	var tracks: Array = active_championship.get("tracks", [])
	var total := maxi(tracks.size(), 1)
	var round_number := clampi(int(active_championship.get("round_index", 0)) + 1, 1, total)
	var championship_id := String(active_championship.get("championship_id", ""))
	if championship_id == "nexus_open":
		return "GRAND OPEN // MANCHE %d/%d • CIRCUIT ZERO EN LIGNE DE MIRE" % [round_number, total]
	return "OBJECTIF SAISON // %s • MANCHE %d/%d" % [
		String(active_championship.get("name", "COUPE DE DIVISION")).to_upper(), round_number, total,
	]


func _career_text(stats: Dictionary) -> String:
	var races := roundi(_number_value(stats, ["races"], 0.0))
	var wins := roundi(_number_value(stats, ["wins"], 0.0))
	var podiums := roundi(_number_value(stats, ["podiums"], 0.0))
	var championships := roundi(_number_value(stats, ["championships"], 0.0))
	return "%d COURSES   •   %d VICTOIRES\n%d PODIUMS   •   %d CHAMPIONNATS" % [races, wins, podiums, championships]


func _mode_status(mode: StringName) -> String:
	match mode:
		&"grand_prix":
			var cup := GameDatabase.get_championship(_selected_championship_id())
			return "%s // %d MANCHES" % [String(cup.get("name", "CHAMPIONNAT")).to_upper(), Array(cup.get("track_ids", [])).size()]
		&"time_trial": return "TÉLÉMÉTRIE SOLO // CHRONO"
		&"elimination": return "PROTOCOLE ÉLIMINATION // DERNIER EXCLU"
		_: return "COURSE RAPIDE // SEPT RIVAUX"


func _configure_focus() -> void:
	ThemeFactory.connect_focus_chain(_focus_controls())
	_restore_focus()


func _focus_controls() -> Array[Control]:
	var controls: Array[Control] = [
		track_select, difficulty_select, grid_policy_select, championship_select,
		quick_button, grand_prix_button, time_trial_button, elimination_button,
		garage_button, codex_button, contrast_toggle, motion_toggle, text_toggle,
	]
	if quit_button.visible:
		controls.append(quit_button)
	return controls


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


func _setup_race_options() -> void:
	track_select.clear()
	for track: Dictionary in GameDatabase.TRACKS:
		var track_index := track_select.item_count
		track_select.add_item(String(track.get("name", "CIRCUIT ZERO")).to_upper())
		track_select.set_item_metadata(track_index, String(track.get("id", "foundry")))
	difficulty_select.clear()
	for difficulty: Dictionary in GameDatabase.DIFFICULTIES:
		var difficulty_index := difficulty_select.item_count
		difficulty_select.add_item(String(difficulty.get("name", "PILOTE")).to_upper())
		difficulty_select.set_item_metadata(difficulty_index, String(difficulty.get("id", "pilot")))
		if String(difficulty.get("id", "")) == "pilot":
			difficulty_select.select(difficulty_index)
	grid_policy_select.clear()
	grid_policy_select.add_item("CATÉGORIE ACTIVE  //  GRILLE FERMÉE")
	grid_policy_select.set_item_metadata(0, "division")
	grid_policy_select.add_item("OPEN / TOUTES CATÉGORIES  //  MIXTE")
	grid_policy_select.set_item_metadata(1, "mixed")
	grid_policy_select.select(0)
	championship_select.clear()
	for championship: Dictionary in GameDatabase.get_all_championships():
		var index := championship_select.item_count
		var category := GameDatabase.get_race_category_for_chassis(String(championship.get("category_chassis_id", "")))
		var open_badge := "OPEN" if bool(championship.get("mixed_divisions", false)) else String(category.get("short", "CAT"))
		championship_select.add_item("%s  //  %s" % [String(championship.get("name", "COUPE")).to_upper(), open_badge])
		championship_select.set_item_metadata(index, String(championship.get("id", "command_cup")))


func _selected_grid_policy() -> String:
	if grid_policy_select.item_count > 0 and grid_policy_select.selected >= 0:
		return "mixed" if String(grid_policy_select.get_item_metadata(grid_policy_select.selected)) == "mixed" else "division"
	return "division"


func _selected_championship_id() -> String:
	if championship_select.item_count > 0 and championship_select.selected >= 0:
		var value := String(championship_select.get_item_metadata(championship_select.selected))
		if not GameDatabase.get_championship(value).is_empty():
			return value
	return "command_cup"


func _select_championship_for_chassis(chassis_id: String) -> void:
	var current := GameDatabase.get_championship(_selected_championship_id())
	if bool(current.get("mixed_divisions", false)) or String(current.get("category_chassis_id", "")) == chassis_id:
		return
	for index in range(championship_select.item_count):
		var candidate := GameDatabase.get_championship(String(championship_select.get_item_metadata(index)))
		if not bool(candidate.get("mixed_divisions", false)) and String(candidate.get("category_chassis_id", "")) == chassis_id:
			championship_select.select(index)
			return


func _select_championship_by_id(championship_id: String) -> void:
	for index in range(championship_select.item_count):
		if String(championship_select.get_item_metadata(index)) == championship_id:
			championship_select.select(index)
			return


func _select_difficulty_by_id(difficulty_id: String) -> void:
	for index in range(difficulty_select.item_count):
		if String(difficulty_select.get_item_metadata(index)) == difficulty_id:
			difficulty_select.select(index)
			return


func _active_championship() -> Dictionary:
	var session := _game_session()
	if session == null:
		return {}
	var value: Variant = session.get("championship")
	if value is Dictionary and bool(Dictionary(value).get("active", false)):
		return Dictionary(value).duplicate(true)
	return {}

func _championship_access(championship_id: String = "") -> Dictionary:
	var requested_id := championship_id if not championship_id.is_empty() else _selected_championship_id()
	var stats := _dictionary_value(_profile(), ["stats"], {})
	return GameDatabase.championship_access(requested_id, stats, _active_championship())


func _championship_badge(cup: Dictionary, access: Dictionary) -> String:
	if not bool(access.get("available", false)):
		return String(access.get("locked_badge", "VERROUILLÉ"))
	if bool(access.get("resume", false)):
		return String(access.get("resume_badge", "REPRISE"))
	if bool(cup.get("mixed_divisions", false)):
		return "OPEN"
	var category := GameDatabase.get_race_category_for_chassis(String(cup.get("category_chassis_id", "")))
	return String(category.get("short", "CAT"))


func _championship_item_label(cup: Dictionary, access: Dictionary) -> String:
	var badge := _championship_badge(cup, access)
	return "%s  //  %s" % [String(cup.get("name", "COUPE")).to_upper(), badge]


func _championship_tooltip(cup: Dictionary, access: Dictionary) -> String:
	if not bool(access.get("available", false)):
		return String(access.get("locked_tooltip", "Championnat verrouillé."))
	if bool(access.get("resume", false)):
		return "Reprendre %s avec sa grille et ses points sauvegardés." % String(cup.get("name", "ce championnat"))
	var requirement_value: Variant = cup.get("unlock_requirement", {})
	if requirement_value is Dictionary and not Dictionary(requirement_value).is_empty():
		return String(access.get("unlocked_tooltip", cup.get("description", "Championnat disponible.")))
	return String(cup.get("description", "Démarrer la coupe sélectionnée."))


func _refresh_championship_items() -> void:
	var popup := championship_select.get_popup()
	for index in range(championship_select.item_count):
		var cup := GameDatabase.get_championship(String(championship_select.get_item_metadata(index)))
		var access := _championship_access(String(cup.get("id", "")))
		championship_select.set_item_disabled(index, not bool(access.get("available", false)))
		championship_select.set_item_text(index, _championship_item_label(cup, access))
		popup.set_item_tooltip(index, _championship_tooltip(cup, access))


func _show_championship_locked(access: Dictionary) -> void:
	status_message.theme_type_variation = &"WarningLabel"
	status_message.text = String(access.get("locked_status", "CHAMPIONNAT VERROUILLÉ"))


func _refresh_championship_action() -> void:
	var cup := GameDatabase.get_championship(_selected_championship_id())
	var cup_name := String(cup.get("name", "CHAMPIONNAT")).to_upper()
	var active_championship := _active_championship()
	var access := _championship_access(String(cup.get("id", "")))
	var selector_tooltip := _championship_tooltip(cup, access)
	championship_select.tooltip_text = selector_tooltip
	if not bool(access.get("available", false)):
		grand_prix_button.disabled = true
		grand_prix_button.text = "%s   //   %d/%d" % [String(access.get("locked_label", "CHAMPIONNAT VERROUILLÉ")), int(access.get("current", 0)), int(access.get("minimum", 1))]
		grand_prix_button.tooltip_text = selector_tooltip
		return
	grand_prix_button.disabled = false
	if not active_championship.is_empty() and String(active_championship.get("championship_id", "")) == _selected_championship_id():
		var tracks: Array = active_championship.get("tracks", [])
		var total := maxi(tracks.size(), 1)
		var round_number := clampi(int(active_championship.get("round_index", 0)) + 1, 1, total)
		grand_prix_button.text = "REPRENDRE %s   //   MANCHE %d/%d" % [cup_name, round_number, total]
		grand_prix_button.tooltip_text = "Reprendre le championnat sauvegardé avec sa grille et ses points"
	else:
		grand_prix_button.text = "NOUVEAU CHAMPIONNAT   //   %s" % cup_name
		grand_prix_button.tooltip_text = "Démarrer la coupe sélectionnée avec une grille stable. %s" % selector_tooltip


func _refresh_rule_summary() -> void:
	if not is_instance_valid(rule_summary):
		return
	var profile := _profile()
	var chassis := GameDatabase.get_chassis(_string_value(profile, ["selected_chassis", "selectedChassis"], "biped"))
	var category := GameDatabase.get_race_category_for_chassis(String(chassis.get("id", "biped")))
	var race_grid_label := "OPEN / TOUTES CATÉGORIES" if _selected_grid_policy() == "mixed" else "CATÉGORIE %s" % String(category.get("name", "ACTIVE")).to_upper()
	var cup := GameDatabase.get_championship(_selected_championship_id())
	var cup_category := GameDatabase.get_race_category_for_chassis(String(cup.get("category_chassis_id", "")))
	var cup_grid_label := "OPEN / TOUTES CATÉGORIES" if bool(cup.get("mixed_divisions", false)) else "CATÉGORIE %s" % String(cup_category.get("name", "ACTIVE")).to_upper()
	var race_difficulty := difficulty_select.get_item_text(difficulty_select.selected).to_upper()
	var cup_difficulty := race_difficulty
	var active_championship := _active_championship()
	if not active_championship.is_empty() and String(active_championship.get("championship_id", "")) == _selected_championship_id():
		var saved_difficulty := GameDatabase.get_difficulty(String(active_championship.get("difficulty", "pilot")))
		cup_difficulty = String(saved_difficulty.get("name", "PILOTE")).to_upper()
	var access := _championship_access(String(cup.get("id", "")))
	var access_label := "  •  ACCÈS VERROUILLÉ" if not bool(access.get("available", false)) else ""
	rule_summary.text = "COURSE %s / %s  •  %s / %s / %s%s" % [race_grid_label, race_difficulty, String(cup.get("name", "COUPE")).to_upper(), cup_grid_label, cup_difficulty, access_label]


func _selected_track_id() -> String:
	if track_select.item_count > 0 and track_select.selected >= 0:
		var selected: Variant = track_select.get_item_metadata(track_select.selected)
		if selected is String and GameDatabase.has_track(String(selected)):
			return String(selected)
	return "foundry"


func _selected_difficulty_id() -> String:
	if difficulty_select.item_count > 0 and difficulty_select.selected >= 0:
		var selected: Variant = difficulty_select.get_item_metadata(difficulty_select.selected)
		if selected is String and GameDatabase.has_difficulty(String(selected)):
			return String(selected)
	return "pilot"


func _set_toggle_without_signal(toggle: CheckButton, value: bool) -> void:
	if not is_instance_valid(toggle):
		return
	toggle.set_pressed_no_signal(value)


func _dictionary_value(source: Variant, keys: Array[String], fallback: Dictionary) -> Dictionary:
	var value: Variant = _variant_value(source, keys, fallback)
	return value if value is Dictionary else fallback


func _string_value(source: Variant, keys: Array[String], fallback: String) -> String:
	var value: Variant = _variant_value(source, keys, fallback)
	return str(value) if value != null else fallback


func _number_value(source: Variant, keys: Array[String], fallback: float) -> float:
	var value: Variant = _variant_value(source, keys, fallback)
	return float(value) if value is int or value is float else fallback


func _bool_value(source: Variant, keys: Array[String], fallback: bool) -> bool:
	var value: Variant = _variant_value(source, keys, fallback)
	return bool(value) if value is bool else fallback


func _variant_value(source: Variant, keys: Array[String], fallback: Variant) -> Variant:
	if source is Dictionary:
		var source_dictionary: Dictionary = source
		for key in keys:
			if source_dictionary.has(key):
				return source_dictionary[key]
	return fallback


func _format_number(value: float) -> String:
	var raw := str(roundi(value))
	var output := ""
	while raw.length() > 3:
		output = " %s%s" % [raw.right(3), output]
		raw = raw.left(raw.length() - 3)
	return raw + output
