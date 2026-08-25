class_name MechaOverdriveApp
extends Node

## Top-level screen coordinator. Gameplay, menus and persistence stay separated,
## while this node owns transitions and input defaults shared by every scene.

const MAIN_MENU_SCENE := preload("res://scenes/main_menu.tscn")
const SEASON_INTRO_SCENE := preload("res://scenes/season_intro.tscn")
const GARAGE_SCENE := preload("res://scenes/garage.tscn")
const CODEX_SCENE := preload("res://scenes/codex.tscn")
const RESULTS_SCENE := preload("res://scenes/results.tscn")
const RaceControllerType := preload("res://scripts/race/race_controller.gd")
const SEASON_INTRO_SETTING := "season_intro_arc_2_seen"

var _active_screen: Node
var _race: RaceController
var _last_config: Dictionary = {}


func _ready() -> void:
	_register_input_defaults()
	_show_opening()


func _show_opening() -> void:
	if _season_intro_seen():
		_show_main_menu()
		return
	var intro := SEASON_INTRO_SCENE.instantiate() as SeasonIntroScreen
	if intro == null:
		push_error("Season intro scene root must use SeasonIntroScreen.")
		_show_main_menu()
		return
	intro.completed.connect(_complete_opening)
	_replace_screen(intro)


func _complete_opening(mark_seen: bool = true) -> void:
	if mark_seen:
		var save := get_node_or_null("/root/SaveSystem")
		if save != null and save.has_method(&"update_settings"):
			var intro_setting := {}
			intro_setting[SEASON_INTRO_SETTING] = true
			save.call(&"update_settings", intro_setting)
	_show_main_menu()


func _season_intro_seen() -> bool:
	var save := get_node_or_null("/root/SaveSystem")
	if save == null:
		return false
	var profile_value: Variant = save.get("profile")
	if profile_value is Dictionary:
		var settings_value: Variant = Dictionary(profile_value).get("settings", {})
		if settings_value is Dictionary:
			return bool(Dictionary(settings_value).get(SEASON_INTRO_SETTING, false))
	return false


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(_active_screen):
		_active_screen.queue_free()
	_active_screen = next_screen
	add_child(next_screen)


func _show_main_menu() -> void:
	_end_race_node()
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenuScreen
	if menu == null:
		push_error("Main menu scene root must use MainMenuScreen.")
		return
	menu.race_requested.connect(_start_race)
	menu.screen_requested.connect(_show_secondary_screen)
	menu.quit_requested.connect(_quit_game)
	_replace_screen(menu)


func _show_secondary_screen(screen_id: StringName) -> void:
	match screen_id:
		&"garage":
			var garage := GARAGE_SCENE.instantiate() as GarageScreen
			if garage == null:
				push_error("Garage scene root must use GarageScreen.")
				return
			garage.back_requested.connect(_show_main_menu)
			_replace_screen(garage)
		&"codex":
			var codex := CODEX_SCENE.instantiate() as CodexScreen
			if codex == null:
				push_error("Codex scene root must use CodexScreen.")
				return
			codex.back_requested.connect(_show_main_menu)
			_replace_screen(codex)
		_: return


func _start_race(config: Dictionary) -> void:
	_last_config = config.duplicate(true)
	if is_instance_valid(_active_screen):
		_active_screen.queue_free()
		_active_screen = null
	_end_race_node()
	var race := RaceControllerType.new() as RaceController
	if race == null:
		push_error("Race controller script must instantiate RaceController.")
		_show_main_menu()
		return
	_race = race
	race.race_finished.connect(_show_results)
	race.menu_requested.connect(_show_main_menu)
	race.retry_requested.connect(_start_race)
	add_child(race)
	race.start(config)


func _show_results(result: Dictionary) -> void:
	_end_race_node()
	var results := RESULTS_SCENE.instantiate() as ResultsScreen
	if results == null:
		push_error("Results scene root must use ResultsScreen.")
		_show_main_menu()
		return
	results.retry_requested.connect(_retry_last_race)
	results.menu_requested.connect(_show_main_menu)
	results.next_requested.connect(_start_next_round)
	_replace_screen(results)
	results.call_deferred(&"present", result)


func _retry_last_race() -> void:
	var request := _last_config.duplicate(true)
	var session := get_node_or_null("/root/GameSession") as GameSessionService
	if session != null and session.has_method(&"configure"):
		# The last round has already been committed on the results screen. A
		# completed championship therefore restarts the same cup; other modes
		# simply reset their race transaction before rebuilding the controller.
		if String(request.get("mode", "quick")) == "grand_prix":
			request["new_championship"] = not bool(session.championship.get("active", false))
		var configured: Variant = session.call(&"configure", request)
		if configured is Dictionary:
			request = configured
	if request.is_empty():
		_show_main_menu()
		return
	_start_race(request)


func _start_next_round() -> void:
	var session := get_node_or_null("/root/GameSession") as GameSessionService
	if session == null:
		_show_main_menu()
		return
	var config := session.start_next_championship_round() if session.has_method(&"start_next_championship_round") else session.start_next_grand_prix_round()
	if not config.is_empty():
		_start_race(config)
	else:
		_show_main_menu()


func _end_race_node() -> void:
	if is_instance_valid(_race):
		_race.queue_free()
	_race = null


func _quit_game() -> void:
	get_tree().quit()


func _register_input_defaults() -> void:
	_add_key_action(&"race_accelerate", [KEY_W, KEY_Z, KEY_UP])
	_add_key_action(&"race_brake", [KEY_S, KEY_DOWN])
	_add_key_action(&"race_left", [KEY_A, KEY_Q, KEY_LEFT])
	_add_key_action(&"race_right", [KEY_D, KEY_RIGHT])
	_add_key_action(&"race_drift", [KEY_CTRL, KEY_C])
	_add_key_action(&"race_boost", [KEY_SHIFT, KEY_X])
	_add_key_action(&"race_item", [KEY_SPACE, KEY_E, KEY_ENTER])
	_add_key_action(&"race_reset", [KEY_R])
	_add_key_action(&"race_camera", [KEY_V, KEY_TAB])
	_add_key_action(&"race_pause", [KEY_ESCAPE, KEY_P])
	_add_joy_button(&"race_accelerate", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button(&"race_brake", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button(&"race_drift", JOY_BUTTON_B)
	_add_joy_button(&"race_boost", JOY_BUTTON_X)
	_add_joy_button(&"race_item", JOY_BUTTON_A)
	_add_joy_button(&"race_camera", JOY_BUTTON_Y)
	_add_joy_button(&"race_pause", JOY_BUTTON_START)
	_add_joy_axis(&"race_left", JOY_AXIS_LEFT_X, -0.22)
	_add_joy_axis(&"race_right", JOY_AXIS_LEFT_X, 0.22)


func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
	if not InputMap.action_get_events(action).is_empty():
		return
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _add_joy_button(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_joy_axis(action: StringName, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
