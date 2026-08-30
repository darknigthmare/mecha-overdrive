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
			var test_profile := profile.duplicate(true)
			test_profile["selected_chassis"] = "biped"
			var test_loadouts: Dictionary = test_profile.get("loadouts", {})
			test_loadouts["biped"] = {
				"core": "core_overdrive",
				"mobility": "mobility_sprint",
				"utility": "utility_scanner",
			}
			test_profile["loadouts"] = test_loadouts
			var test_locomotions: Dictionary = test_profile.get("locomotions", {})
			test_locomotions["biped"] = LocomotionCatalog.get_default_configuration_id("biped")
			test_profile["locomotions"] = test_locomotions
			var test_stats: Dictionary = test_profile.get("stats", {})
			# The flow exercises the qualified Grand Open after the dedicated cup.
			test_stats["championships"] = maxi(1, int(test_stats.get("championships", 0)))
			test_profile["stats"] = test_stats
			var test_settings: Dictionary = test_profile.get("settings", {})
			test_settings["camera_view"] = "tps"
			test_profile["settings"] = test_settings
			_save_system.set("profile", test_profile)

	# New profiles receive the three-part season opening. Dismiss it through its
	# public accessibility seam without persisting into the real user profile.
	var opening: Node = app.get("_active_screen") as Node
	if opening != null and opening.name == &"SeasonIntro" and opening.has_method(&"complete_now"):
		opening.call(&"complete_now", false)
		await process_frame
		await process_frame

	var menu: Node = app.get("_active_screen") as Node
	_expect(menu != null and menu.name == &"MainMenu", "la scène principale doit afficher MainMenu")
	if menu == null or not menu.has_signal(&"race_requested"):
		_finish()
		return

	# Exercise the real garage before the race: the preview must use the same
	# MechaFactory and update a draft module without writing the profile.
	menu.emit_signal(&"screen_requested", &"garage")
	var garage: Node = await _wait_for_screen(app, &"Garage", STARTUP_TIMEOUT_MS)
	_expect(garage != null, "le garage réel doit être accessible depuis le menu")
	if garage != null:
		await process_frame
		await process_frame
		var preview := garage.find_child("GaragePreview", true, false)
		_expect(preview != null and preview.has_method(&"current_visual"), "le garage doit exposer sa prévisualisation 3D")
		var preview_visual: Node = preview.call(&"current_visual") as Node if preview != null and preview.has_method(&"current_visual") else null
		_expect(preview_visual != null and preview_visual.is_inside_tree(), "le vrai modèle 3D doit être construit dans la baie")
		if preview_visual != null:
			var preview_loadout: Dictionary = preview_visual.get_meta("module_loadout", {})
			_expect(preview_loadout.size() == 3, "l’aperçu doit monter les trois emplacements modulaires")
		var core_option := garage.find_child("CoreOption", true, false) as OptionButton
		if core_option != null:
			for module_index in range(core_option.item_count):
				if String(core_option.get_item_metadata(module_index)) == "core_tactical_relay":
					core_option.select(module_index)
					garage.call(&"_on_module_selected", module_index, "core", core_option)
					await process_frame
					await process_frame
					break
			preview_visual = preview.call(&"current_visual") as Node
			var draft_loadout: Dictionary = preview_visual.get_meta("module_loadout", {}) if preview_visual != null else {}
			_expect(String(draft_loadout.get("core", "")) == "core_tactical_relay", "le brouillon module doit reconstruire immédiatement le visuel")
			garage.call(&"_cancel_draft")
			await process_frame
			await process_frame
			preview_visual = preview.call(&"current_visual") as Node
			var cancelled_loadout: Dictionary = preview_visual.get_meta("module_loadout", {}) if preview_visual != null else {}
			_expect(String(cancelled_loadout.get("core", "")) == "core_overdrive", "Annuler doit restaurer le module sauvegardé dans le profil")
		garage.emit_signal(&"back_requested")
		menu = await _wait_for_screen(app, &"MainMenu", STARTUP_TIMEOUT_MS)
		_expect(menu != null, "le retour garage doit reconstruire le menu principal")
		if menu == null:
			_finish()
			return

	var config: Dictionary = {
		"mode": "quick",
		"track_id": "foundry",
		"difficulty": "pilot",
		"laps": 1,
		"racer_count": 8,
		"division_id": "command",
		"grid_policy": "division",
		"ruleset_id": "division_locked",
		"performance_class_id": "tuned",
		"time_limit": 60.0,
		"seed": 240817,
	}
	var session: Node = root.get_node_or_null("GameSession")
	if _save_system != null and session != null:
		_configure_isolated_save(_save_system)
		session.set("_save_system_override", _save_system)
	if session != null and session.has_method(&"configure"):
		var configured: Variant = session.call(&"configure", config)
		if configured is Dictionary:
			config = configured

	# Configuration only reads the isolated test profile. Hide the autoload
	# before RaceController exists, so no test transition can write user data.
	if _save_system != null:
		_save_system.name = &"SaveSystem_RuntimeFlowIsolated"
	_expect(String(config.get("grid_policy", "")) == "division" and not bool(config.get("mixed_divisions", true)), "le flux rapide doit rester en catégorie dédiée")
	_expect(String(config.get("category_chassis_id", "")) == "biped", "la course rapide doit verrouiller la catégorie Bipède")
	_expect(String(config.get("ruleset_id", "")) == "division_locked", "le flux rapide doit utiliser le règlement dédié")
	var configured_roster: Array = config.get("roster", [])
	_expect(configured_roster.size() == 8, "la configuration doit fournir 8 entrants stables")
	for entrant_value: Variant in configured_roster:
		if entrant_value is Dictionary:
			var entrant: Dictionary = entrant_value
			_expect(String(entrant.get("division_id", "")) == "command", "un entrant hors Commandement a contaminé la grille dédiée")
			_expect(String(entrant.get("chassis_id", "")) == "biped", "un châssis hors catégorie Bipède a contaminé la grille dédiée")
			var entrant_chassis := GameDatabase.get_chassis(String(entrant.get("chassis_id", "")))
			_expect(String(entrant_chassis.get("division_id", "")) == "command", "le roster annonce une division incohérente avec son châssis")

	menu.emit_signal(&"race_requested", config)
	var race: Node = await _wait_for_race(app)
	if race == null:
		_expect(false, "RaceController n'a pas été créé après race_requested")
		_finish()
		return

	_expect(race.get_script() == RACE_CONTROLLER_SCRIPT, "le nœud de course doit utiliser RaceController")
	var track: Node = race.get("_track") as Node
	var hud: Node = race.get("_hud") as Node
	var audio: Node = race.get("_audio") as Node
	var racers_value: Variant = race.get("_racers")
	var racer_count: int = 0
	if racers_value is Array:
		var racers: Array = racers_value
		racer_count = racers.size()
	_expect(track != null and track.is_inside_tree(), "le circuit 3D réel doit être instancié")
	_expect(hud != null and hud.is_inside_tree(), "le HUD réel doit être instancié")
	_expect(audio != null and bool(audio.call(&"procedural_audio_enabled")), "l'audio procédural doit être actif")
	if audio != null:
		_expect(bool(audio.call(&"uses_stream_playback")), "AudioStreamGenerator doit forcer PLAYBACK_TYPE_STREAM")
	_expect(racer_count == 8, "la course rapide doit contenir exactement 8 pilotes")
	_expect(race.has_signal(&"race_finished"), "RaceController doit exposer race_finished")
	if race.has_signal(&"race_finished"):
		race.connect(&"race_finished", Callable(self, "_on_race_finished"))
	var actual_roster_ids: Array[String] = []
	if racers_value is Array:
		for racer_value: Variant in racers_value:
			if racer_value is RefCounted:
				var racer_ref: RefCounted = racer_value as RefCounted
				var racer_snapshot: Dictionary = racer_ref.call(&"snapshot")
				actual_roster_ids.append(String(racer_snapshot.get("racer_id", "")))
				_expect(String(racer_snapshot.get("division_id", "")) == "command", "la simulation a construit un châssis hors division")
	var configured_roster_ids: Array[String] = []
	for entrant_value: Variant in configured_roster:
		if entrant_value is Dictionary:
			configured_roster_ids.append(String(Dictionary(entrant_value).get("id", "")))
	_expect(actual_roster_ids == configured_roster_ids, "RaceController doit respecter l'ordre du roster homologué")
	var player_state: RacerState = race.get("_player") as RacerState
	if player_state != null:
		var baseline := RacerState.new().configure({"racer_id": "baseline", "chassis_id": "biped", "track_length": 400.0, "total_laps": 1})
		_expect(player_state.top_speed > baseline.top_speed, "le noyau Overdrive doit atteindre la simulation réelle")
		_expect(player_state.acceleration > baseline.acceleration, "les articulations Sprint doivent atteindre la simulation réelle")
		_expect(player_state.handling > baseline.handling, "le Scanner Apex doit atteindre la simulation réelle")
		_expect(player_state.armor_max < baseline.armor_max, "les compromis de modules doivent atteindre la simulation réelle")
		_expect(player_state.snapshot().get("division_id", "") == "command", "la division doit survivre dans les snapshots")

	var runtime_aether := RacerState.new().configure({
		"racer_id": "runtime_aether", "chassis_id": "biped",
		"locomotion_id": "biped__twin_antigrav__racing", "track_length": 400.0, "total_laps": 1,
	})
	var runtime_aether_state := runtime_aether.snapshot()
	_expect(String(runtime_aether_state.get("drive_id", "")) == "twin_antigrav", "runtime: le drive Aether n'est pas résolu")
	_expect(String(runtime_aether_state.get("locomotion_id", "")) == "biped__twin_antigrav__racing", "runtime: la locomotion Aether n'est pas exposée")
	_expect(not runtime_aether.apply_ground_mine() and runtime_aether.offroad_drag_factor() < 0.2, "runtime: Aether n'applique pas son profil sans contact")
	var runtime_legged_hover := RacerState.new().configure({
		"racer_id": "runtime_hover_legs", "chassis_id": "hover",
		"locomotion_id": "hover__mecha_legs__balanced", "track_length": 400.0, "total_laps": 1,
	})
	_expect(runtime_legged_hover.apply_ground_mine(), "runtime: un hover sur jambes ignore encore les mines")
	_expect(not bool(Dictionary(runtime_legged_hover.snapshot().get("ability", {})).get("mine_immune", true)), "runtime: profil d'aptitude hover sur jambes incohérent")
	var runtime_treads := RacerState.new().configure({
		"racer_id": "runtime_treads", "chassis_id": "biped",
		"locomotion_id": "biped__treads__balanced", "track_length": 400.0, "total_laps": 1,
	})
	_expect(is_zero_approx(runtime_treads._hazard_drag("sand")) and is_zero_approx(runtime_treads._hazard_drag("debris")) and runtime_treads._hazard_drag("mud") <= 0.10, "runtime: résistances chenilles absentes")
	var runtime_multi := RacerState.new().configure({
		"racer_id": "runtime_multi", "chassis_id": "biped",
		"locomotion_id": "biped__multi_support__balanced", "track_length": 400.0, "total_laps": 1,
	})
	_expect(runtime_multi.offroad_drag_factor() < runtime_legged_hover.offroad_drag_factor(), "runtime: avantage hors-piste multi-appuis absent")

	# The broadcast grid is a real blocking phase, followed by three locked
	# lights. Accelerating early must not move the player and applies a short,
	# explicit start penalty.
	_expect(String(race.call(&"start_phase")) == "briefing", "la course doit ouvrir sur le briefing de grille")
	_expect(hud.has_method(&"is_briefing_visible") and bool(hud.call(&"is_briefing_visible")), "le HUD doit afficher circuit, règlement et grille")
	var prestart_camera := race.get("_camera") as Camera3D
	var prestart_visuals_value: Variant = race.get("_visuals")
	var prestart_player_visual: Node3D
	if prestart_visuals_value is Dictionary:
		prestart_player_visual = Dictionary(prestart_visuals_value).get("player") as Node3D
	var prestart_fps_anchor: Marker3D = prestart_player_visual.call(&"camera_anchor", "fps") as Marker3D if prestart_player_visual != null else null
	race.call(&"_set_camera_mode", "fps", false)
	race.set("_paused", true)
	race.call(&"_process", 1.0 / 60.0)
	_expect(prestart_camera != null and prestart_player_visual != null and prestart_fps_anchor != null, "le départ doit exposer caméra, visuel et ancre FPS")
	if prestart_camera != null and prestart_player_visual != null and prestart_fps_anchor != null:
		_expect(not bool(prestart_player_visual.get("first_person")), "une préférence FPS ne doit pas masquer la coque pendant une pause de briefing")
		_expect(prestart_camera.global_position.distance_to(prestart_fps_anchor.global_position) > 2.0, "la pause pré-départ doit conserver la caméra de grille externe")
	race.set("_paused", false)

	# The same saved FPS choice must remain external throughout the countdown.
	var initial_distance := float(player_state.snapshot().get("distance", 0.0)) if player_state != null else -1.0
	race.set("_briefing_remaining", 0.0)
	hud.call(&"hide_race_briefing")
	hud.call(&"show_countdown", 3)
	race.set("_countdown", 2.75)
	Input.action_press(&"race_accelerate", 1.0)
	await process_frame
	Input.action_release(&"race_accelerate")
	_expect(String(race.call(&"start_phase")) == "countdown", "les feux 3-2-1 doivent précéder la simulation")
	_expect(bool(race.call(&"has_false_start")), "une accélération sous feux rouges doit déclencher un faux départ")
	_expect(is_equal_approx(float(player_state.snapshot().get("distance", 0.0)), initial_distance), "la simulation doit rester bloquée pendant le compte à rebours")
	if prestart_camera != null and prestart_player_visual != null and prestart_fps_anchor != null:
		_expect(not bool(prestart_player_visual.get("first_person")), "la coque doit rester visible sous les feux avec une préférence FPS")
		_expect(prestart_camera.global_position.distance_to(prestart_fps_anchor.global_position) > 2.0, "le compte à rebours doit rester sur la caméra de grille")
	race.call(&"_set_camera_mode", "tps", false)

	var countdown_notice: Label = hud.get("_countdown_notice_label") as Label
	_expect(countdown_notice != null and countdown_notice.visible and countdown_notice.text.contains("FAUX DÉPART"), "le HUD doit expliquer la pénalité de faux départ")

	# Skip the remaining display duration; movement still runs through the real
	# input map and fixed-step race simulation.
	race.set("_countdown", 0.000001)
	await process_frame
	_expect(String(race.call(&"start_phase")) == "racing" and float(race.call(&"start_penalty_remaining")) > 0.0, "GO doit libérer la simulation et armer la pénalité")
	Input.action_press(&"race_accelerate", 1.0)
	var penalized_controls: Dictionary = race.call(&"_player_controls")
	Input.action_release(&"race_accelerate")
	_expect(is_zero_approx(float(penalized_controls.get("throttle", 1.0))), "la pénalité doit verrouiller réellement la propulsion du joueur")
	race.set("_start_penalty_remaining", 0.0)
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

	var camera: Camera3D = race.get("_camera") as Camera3D
	var visuals_value: Variant = race.get("_visuals")
	var player_visual: Node3D
	if visuals_value is Dictionary:
		var visuals: Dictionary = visuals_value
		player_visual = visuals.get("player") as Node3D
	_expect(camera != null and player_visual != null, "la caméra et le mécha joueur doivent exister")
	if camera != null and player_visual != null:
		var to_player := (player_visual.global_position - camera.global_position).normalized()
		var camera_forward := -camera.global_basis.z.normalized()
		_expect(camera_forward.dot(to_player) > 0.55, "la Camera3D doit regarder le joueur et la piste")

	if not is_instance_valid(race) or player == null:
		_expect(false, "la course ne doit pas disparaître avant la fin forcée")
		_finish()
		return
	var tps_anchor: Marker3D = player_visual.call(&"camera_anchor", "tps") as Marker3D
	var fps_anchor: Marker3D = player_visual.call(&"camera_anchor", "fps") as Marker3D
	_expect(tps_anchor != null and fps_anchor != null, "chaque mécha doit exposer ses ancres TPS et cockpit")
	var module_loadout: Dictionary = player_visual.get_meta("module_loadout", {})
	_expect(String(module_loadout.get("core", "")) == "core_overdrive", "le module noyau visuel doit correspondre au loadout")
	_expect(player_visual.get_node_or_null("ModuleCore_core_overdrive") != null, "le module noyau doit être visible")
	_expect(player_visual.get_node_or_null("ModuleMobility_mobility_sprint") != null, "le module mobilité doit être visible")
	_expect(player_visual.get_node_or_null("ModuleUtility_utility_scanner") != null, "le module utilitaire doit être visible")
	race.call(&"_update_camera", 1.0)
	if tps_anchor != null:
		_expect(camera.global_position.distance_to(tps_anchor.global_position) < 0.2, "la vue TPS doit consommer l'ancre propre au châssis")
	_expect(String(race.call(&"switch_camera_view")) == "fps", "la bascule publique doit ouvrir la vue cockpit")
	race.call(&"_update_camera", 1.0)
	race.call(&"_update_feedback")
	_expect(bool(player_visual.get("first_person")), "le visuel joueur doit entrer en mode cockpit")
	if fps_anchor != null:
		_expect(camera.global_position.distance_to(fps_anchor.global_position) < 0.2, "la vue cockpit doit consommer l'ancre FPS")
		var visual_transform := player_visual.global_transform
		player_visual.global_position += Vector3(0.0, 0.0, 6.0)
		race.call(&"_update_camera", 1.0 / 60.0)
		_expect(camera.global_position.distance_to(fps_anchor.global_position) < 0.01, "la caméra FPS doit rester verrouillée à l''ancre pendant un déplacement 60 Hz")
		player_visual.global_transform = visual_transform
		race.call(&"_update_camera", 1.0 / 60.0)
	player_visual.call(&"_process", 0.016)
	var has_hidden_occluder := false
	var has_visible_interior := false
	for node_value: Variant in get_nodes_in_group(&"mecha_fps_occluder"):
		var candidate := node_value as Node3D
		if candidate != null and player_visual.is_ancestor_of(candidate) and not candidate.visible:
			has_hidden_occluder = true
	for node_value: Variant in get_nodes_in_group(&"mecha_cockpit_interior"):
		var candidate := node_value as Node3D
		if candidate != null and player_visual.is_ancestor_of(candidate) and candidate.visible:
			has_visible_interior = true
	_expect(has_hidden_occluder and has_visible_interior, "la vue cockpit doit masquer la coque et afficher l'intérieur")
	var visible_exterior := 0
	for node_value: Variant in get_nodes_in_group(&"mecha_damage_part"):
		var candidate := node_value as Node3D
		if candidate != null and player_visual.is_ancestor_of(candidate) and candidate.visible and not candidate.is_in_group(&"mecha_cockpit_interior"):
			visible_exterior += 1
	_expect(visible_exterior == 0, "aucune coque ou module extérieur ne doit couper la vue cockpit")
	var item_label: Label = hud.get("_item_label") as Label
	_expect(item_label != null and item_label.text.contains("VUE COCKPIT"), "le HUD doit annoncer la vue cockpit")
	_expect(String(race.call(&"switch_camera_view")) == "tps", "la seconde bascule doit restaurer la vue TPS")
	race.call(&"_update_camera", 1.0)
	_expect(not bool(player_visual.get("first_person")), "la coque doit être restaurée en TPS")
	if tps_anchor != null:
		_expect(camera.global_position.distance_to(tps_anchor.global_position) < 0.2, "la caméra doit revenir sur l'ancre TPS")

	player.call(&"mark_dnf", "runtime_flow_test")
	race.call(&"_check_end_conditions")
	await process_frame
	_expect(String(race.call(&"start_phase")) == "finish", "l’arrivée doit ouvrir une courte séquence cinématique")
	_expect(hud.has_method(&"is_finish_visible") and bool(hud.call(&"is_finish_visible")), "le drapeau à damier doit être annoncé avant Results")
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
	var podium: Node = results.get_node_or_null("%PodiumPresenter")
	var podium_headline: Label = results.get_node_or_null("%PodiumHeadline") as Label
	var podium_panel: Control = results.find_child("PodiumPanel", true, false) as Control
	var official_podium: Array = Array(podium.call(&"top_three")) if podium != null and podium.has_method(&"top_three") else []
	_expect(not official_podium.is_empty() and String(Dictionary(official_podium[0]).get("racer_id", "")) != "player" and int(Dictionary(official_podium[0]).get("position", 0)) == 1, "un abandon joueur doit couronner le premier rival éligible")
	_expect(podium_panel != null and podium_panel.visible, "le podium rival officiel doit rester visible après un DNF joueur")
	_expect(not official_podium.any(func(entry: Dictionary) -> bool: return String(entry.get("racer_id", "")) == "player"), "le joueur DNF doit être exclu du podium officiel")
	_expect(podium_headline != null and not podium_headline.text.contains("TROPHÉE"), "un joueur DNF ne doit jamais recevoir un trophée")
	var podium_text := ""
	if podium != null:
		for label_value: Node in podium.find_children("*", "Label", true, false):
			podium_text += (label_value as Label).text + "\n"
	_expect(not podium_text.contains("VOUS"), "un joueur DNF ne doit jamais être mis en avant sur le podium")

	results.call(&"present", {
		"mode": "time_trial", "track_name": "FONDERIE 7", "position": 1,
		"total_racers": 1, "dnf": false, "new_record": true,
		"elapsed": 72.4, "best_time": 72.4,
		"classification": [{"racer_id": "player", "pilot": "PILOTE 01", "position": 1, "finished": true, "player": true}],
	})
	await process_frame
	_expect(result_title.text == "NOUVEAU RECORD", "Results doit annoncer un record de contre-la-montre")
	_expect(podium_panel != null and not podium_panel.visible, "Results ne doit jamais afficher de podium en contre-la-montre")
	results.call(&"present", {
		"mode": "time_trial", "track_name": "FONDERIE 7", "position": 1,
		"total_racers": 1, "dnf": false, "new_record": false,
		"elapsed": 74.8, "best_time": 72.4,
		"classification": [{"racer_id": "player", "pilot": "PILOTE 01", "position": 1, "finished": true, "player": true}],
	})
	await process_frame
	_expect(result_title.text == "CHRONO HOMOLOGUÉ", "Results ne doit jamais transformer une première place chrono en victoire")
	results.call(&"present", _received_result)
	await process_frame
	_expect(results.has_signal(&"retry_requested"), "Results doit permettre de recommencer")
	if results.has_signal(&"retry_requested"):
		results.emit_signal(&"retry_requested")
	var retry_race: Node = await _wait_for_race(app)
	_expect(retry_race != null, "Recommencer doit reconstruire une course")
	if session != null:
		_expect(not bool(session.get("_result_committed")), "Recommencer doit ouvrir une nouvelle transaction de résultat")
	if retry_race != null:
		retry_race.call(&"_request_menu")
	var returned_menu: Node = await _wait_for_screen(app, &"MainMenu", STARTUP_TIMEOUT_MS)
	_expect(returned_menu != null, "le retour depuis la course recommencée doit restaurer MainMenu")
	_expect(app.get("_race") == null, "aucun RaceController ne doit rester actif au menu")
	if session != null and session.has_method(&"configure"):
		var dedicated_cup: Dictionary = session.call(&"configure", {"mode": "grand_prix", "championship_id": "command_cup", "new_championship": true, "seed": 99})
		var dedicated_ids := _roster_signature(dedicated_cup.get("roster", []))
		var resumed_cup: Dictionary = session.call(&"configure", {"mode": "grand_prix", "championship_id": "command_cup", "new_championship": false, "seed": 12345})
		_expect(_roster_signature(resumed_cup.get("roster", [])) == dedicated_ids, "un championnat doit conserver son roster entre les manches")
		_expect(String(dedicated_cup.get("grid_policy", "")) == "division" and _chassis_count(dedicated_cup.get("roster", [])) == 1, "la Coupe Bipède doit rester strictement mono-catégorie")
		if returned_menu != null:
			returned_menu.call(&"refresh")
			var resume_button: Button = returned_menu.get_node_or_null("%GrandPrixButton") as Button
			_expect(resume_button != null and resume_button.text.begins_with("REPRENDRE"), "le menu doit exposer la reprise du championnat sauvegardé")
		var open_cup: Dictionary = session.call(&"configure", {"mode": "grand_prix", "championship_id": "nexus_open", "new_championship": true, "seed": 777})
		_expect(String(open_cup.get("grid_policy", "")) == "mixed" and bool(open_cup.get("mixed_divisions", false)), "le Grand Open doit être explicitement mixte")
		_expect(_division_count(open_cup.get("roster", [])) > 1, "le Grand Open doit réellement réunir plusieurs divisions")

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


func _configure_isolated_save(service: Node) -> void:
	var stem := "user://mecha_overdrive_runtime_flow"
	service.set("_save_path", "%s.json" % stem)
	service.set("_temp_path", "%s.tmp" % stem)
	service.set("_backup_path", "%s.backup.json" % stem)
	service.set("_corrupt_path", "%s.corrupt.json" % stem)
	service.set("_backup_corrupt_path", "%s.backup.corrupt.json" % stem)
	_cleanup_isolated_save(service)


func _cleanup_isolated_save(service: Node) -> void:
	for property_name: String in [
		"_save_path", "_temp_path", "_backup_path", "_corrupt_path", "_backup_corrupt_path",
	]:
		var path := String(service.get(property_name))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _restore_profile() -> void:
	if _save_system == null:
		return
	_cleanup_isolated_save(_save_system)
	_save_system.name = &"SaveSystem"
	if not _profile_before.is_empty():
		_save_system.set("profile", _profile_before.duplicate(true))


func _finish() -> void:
	Input.action_release(&"race_accelerate")
	_restore_profile()
	if _failures.is_empty():
		print("MECHA GODOT RUNTIME FLOW: PASS (menu, garage 3D, briefing grille, countdown bloquant, faux départ, movement, TPS/FPS cockpit, arrivée cinématique, podium, results, dedicated cup, Open cup)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA GODOT RUNTIME FLOW: %s" % failure)
	quit(1)


func _roster_signature(roster_value: Variant) -> Array[String]:
	var output: Array[String] = []
	if not roster_value is Array:
		return output
	for entrant_value: Variant in roster_value:
		if entrant_value is Dictionary:
			var entrant: Dictionary = entrant_value
			output.append("%s|%s|%s|%s" % [entrant.get("id", ""), entrant.get("chassis_id", ""), entrant.get("division_id", ""), JSON.stringify(entrant.get("loadout", {}))])
	return output


func _division_count(roster_value: Variant) -> int:
	var divisions: Dictionary = {}
	if roster_value is Array:
		for entrant_value: Variant in roster_value:
			if entrant_value is Dictionary:
				divisions[String(Dictionary(entrant_value).get("division_id", ""))] = true
	return divisions.size()


func _chassis_count(roster_value: Variant) -> int:
	var chassis_ids: Dictionary = {}
	if roster_value is Array:
		for entrant_value: Variant in roster_value:
			if entrant_value is Dictionary:
				chassis_ids[String(Dictionary(entrant_value).get("chassis_id", ""))] = true
	return chassis_ids.size()
