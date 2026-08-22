class_name MechaOverdriveApp
extends Node

## Top-level screen coordinator. Gameplay, menus and persistence stay separated,
## while this node owns transitions and input defaults shared by every scene.

const MAIN_MENU_SCENE := preload("res://scenes/main_menu.tscn")
const GARAGE_SCENE := preload("res://scenes/garage.tscn")
const CODEX_SCENE := preload("res://scenes/codex.tscn")
const RESULTS_SCENE := preload("res://scenes/results.tscn")
const RaceControllerType := preload("res://scripts/race/race_controller.gd")

var _active_screen: Node
var _race: Node
var _last_config: Dictionary = {}


func _ready() -> void:
	_register_input_defaults()
	_show_main_menu()


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(_active_screen):
		_active_screen.queue_free()
	_active_screen = next_screen
	add_child(next_screen)


func _show_main_menu() -> void:
	_end_race_node()
	var menu := MAIN_MENU_SCENE.instantiate()
	menu.race_requested.connect(_start_race)
	menu.screen_requested.connect(_show_secondary_screen)
	menu.quit_requested.connect(_quit_game)
	_replace_screen(menu)


func _show_secondary_screen(screen_id: StringName) -> void:
	var screen: Node
	match screen_id:
		&"garage": screen = GARAGE_SCENE.instantiate()
		&"codex": screen = CODEX_SCENE.instantiate()
		_: return
	if screen.has_signal(&"back_requested"):
		screen.connect(&"back_requested", _show_main_menu)
	_replace_screen(screen)


func _start_race(config: Dictionary) -> void:
	_last_config = config.duplicate(true)
	if is_instance_valid(_active_screen):
		_active_screen.queue_free()
		_active_screen = null
	_end_race_node()
	_race = RaceControllerType.new()
	_race.race_finished.connect(_show_results)
	_race.menu_requested.connect(_show_main_menu)
	add_child(_race)
	_race.start(config)


func _show_results(result: Dictionary) -> void:
	_end_race_node()
	var results := RESULTS_SCENE.instantiate()
	results.retry_requested.connect(_start_race.bind(_last_config))
	results.menu_requested.connect(_show_main_menu)
	results.next_requested.connect(_start_next_round)
	_replace_screen(results)
	results.call_deferred(&"present", result)


func _start_next_round() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method(&"start_next_grand_prix_round"):
		_show_main_menu()
		return
	var config: Variant = session.call(&"start_next_grand_prix_round")
	if config is Dictionary and not config.is_empty():
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
	_add_key_action(&"race_pause", [KEY_ESCAPE, KEY_P])
	_add_joy_button(&"race_accelerate", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button(&"race_brake", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button(&"race_drift", JOY_BUTTON_B)
	_add_joy_button(&"race_boost", JOY_BUTTON_X)
	_add_joy_button(&"race_item", JOY_BUTTON_A)
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


func _add_joy_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
