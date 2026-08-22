extends SceneTree
## End-to-end headless flow: real app scene -> quick race -> DNF -> results -> menu.
## Run with:
## godot --headless --path godot --script res://tests/runtime_flow_test.gd

const APP_SCENE: PackedScene = preload("res://scenes/app.tscn")
const RACE_CONTROLLER_SCRIPT: Script = preload("res://scripts/race/race_controller.gd")
const STARTUP_TIMEOUT_MS := 5000
const MOVEMENT_TIMEOUT_MS := 5000
const RESULTS_TIMEOUT_MS := 5000

var _failures: Array[String] = []
var _received_result: Dictionary = {}
var _save_system: Node
var _profile_before: Dictionary = {}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var app: Node = APP_SCENE.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	_save_system = root.get_node_or_null("SaveSystem")
	if _save_system != null:
		var profile_value: Variant = _save_system.get("profile")
		if profile_value is Dictionary:
			var profile: Dictionary = profile_value
			_profile_before = profile.duplicate(true)

	var menu: Node = app.get("_active_screen") as Node
	_expect(menu != null and menu.name == &"MainMenu", "la scène principale doit afficher MainMenu")
	if menu == null or not menu.has_signal(&"race_requested"):
		_finish()
		return

	var config: Dictionary = {
		"mode": "quick",
		"track_id": "foundry",
		"difficulty": "pilot",
		"laps": 1,
		"racer_count": 8,
		"time_limit": 60.0,
		"seed": 240817,
	}
	var session: Node = root.get_node_or_null("GameSession")
	if session != null and session.has_method(&"configure"):
		var configured: Variant = session.call(&"configure", config)
		if configured is Dictionary:
			config = configured

	menu.emit_signal(&"race_requested", config)
	var race: Node = await _wait_for_race(app)
	if race == null:
		_expect(false, "RaceController n'a pas été créé après race_requested")
		_finish()
		return

	_expect(race.get_script() == RACE_CONTROLLER_SCRIPT, "le nœud de course doit utiliser RaceController")
	var track: Node = race.get("_track") as Node
	var hud: Node = race.get("_hud") as Node
	var racers_value: Variant = race.get("_racers")
	var racer_count: int = 0
	if racers_value is Array:
		var racers: Array = racers_value
		racer_count = racers.size()
	_expect(track != null and track.is_inside_tree(), "le circuit 3D réel doit être instancié")
	_expect(hud != null and hud.is_inside_tree(), "le HUD réel doit être instancié")
	_expect(racer_count == 8, "la course rapide doit contenir exactement 8 pilotes")
	_expect(race.has_signal(&"race_finished"), "RaceController doit exposer race_finished")
	if race.has_signal(&"race_finished"):
		race.connect(&"race_finished", Callable(self, "_on_race_finished"))

	# Skip only the presentation countdown; movement still runs through the real
	# input map and fixed-step race simulation.
	race.set("_countdown", 0.000001)
	await process_frame
	Input.action_press(&"race_accelerate", 1.0)
	var player: RefCounted = race.get("_player") as RefCounted
	var movement_deadline := Time.get_ticks_msec() + MOVEMENT_TIMEOUT_MS
	var distance := 0.0
	while is_instance_valid(race) and player != null and Time.get_ticks_msec() < movement_deadline:
		await process_frame
		var snapshot: Dictionary = player.call(&"snapshot")
		distance = float(snapshot.get("distance", 0.0))
		if distance > 1.0:
			break
	Input.action_release(&"race_accelerate")
	_expect(distance > 1.0, "le joueur doit avancer sous accélération réelle")

	if not is_instance_valid(race) or player == null:
		_expect(false, "la course ne doit pas disparaître avant la fin forcée")
		_finish()
		return

	# Keep the real service/profile in memory, but hide the autoload path while
	# GameSession commits the synthetic DNF. This prevents test telemetry from
	# ever reaching the user's persistent save or its backup.
	if _save_system != null:
		_save_system.name = &"SaveSystem_RuntimeFlowIsolated"
	player.call(&"mark_dnf", "runtime_flow_test")
	race.call(&"_check_end_conditions")
	var results: Node = await _wait_for_screen(app, &"Results", RESULTS_TIMEOUT_MS)
	_expect(not _received_result.is_empty(), "race_finished doit transmettre un résultat")
	_expect(bool(_received_result.get("dnf", false)), "la fin contrôlée doit être classée DNF")
	_expect(float(_received_result.get("elapsed", 0.0)) > 0.0, "le résultat doit conserver le temps de course")
	_expect(results != null, "l'application doit afficher l'écran Results")
	if results == null:
		_finish()
		return

	var result_title: Label = results.get_node_or_null("%ResultTitle") as Label
	_expect(result_title != null and result_title.text == "COURSE INTERROMPUE", "Results doit présenter le statut DNF")
	_expect(results.has_signal(&"menu_requested"), "Results doit permettre le retour au menu")
	if results.has_signal(&"menu_requested"):
		results.emit_signal(&"menu_requested")
	var returned_menu: Node = await _wait_for_screen(app, &"MainMenu", STARTUP_TIMEOUT_MS)
	_expect(returned_menu != null, "le retour depuis Results doit restaurer MainMenu")
	_expect(app.get("_race") == null, "aucun RaceController ne doit rester actif au menu")
	# Let short UI tweens release their runtime objects before SceneTree quits.
	# This keeps the flow gate warning-free without weakening leak detection.
	await create_timer(0.65, true, false, true).timeout
	await process_frame
	_finish()


func _wait_for_race(app: Node) -> Node:
	var deadline := Time.get_ticks_msec() + STARTUP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		var race: Node = app.get("_race") as Node
		if race != null and race.is_inside_tree():
			return race
		await process_frame
	return null


func _wait_for_screen(app: Node, expected_name: StringName, timeout_ms: int) -> Node:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var screen: Node = app.get("_active_screen") as Node
		if screen != null and screen.name == expected_name and screen.is_inside_tree():
			await process_frame
			return screen
		await process_frame
	return null


func _on_race_finished(result: Dictionary) -> void:
	_received_result = result.duplicate(true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _restore_profile() -> void:
	if _save_system == null:
		return
	_save_system.name = &"SaveSystem"
	if not _profile_before.is_empty():
		_save_system.set("profile", _profile_before.duplicate(true))


func _finish() -> void:
	Input.action_release(&"race_accelerate")
	_restore_profile()
	if _failures.is_empty():
		print("MECHA GODOT RUNTIME FLOW: PASS (menu, 3D race, HUD, 8 racers, movement, DNF, results, menu)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA GODOT RUNTIME FLOW: %s" % failure)
	quit(1)
