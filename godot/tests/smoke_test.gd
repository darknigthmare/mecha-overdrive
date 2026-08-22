extends SceneTree
## Headless smoke test: godot --headless --path godot --script res://tests/smoke_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const SaveScript = preload("res://scripts/systems/save_system.gd")
const SessionScript = preload("res://scripts/systems/game_session.gd")
const RacerScript = preload("res://scripts/race/racer_state.gd")
const AudioScript = preload("res://scripts/audio/audio_director.gd")
const GarageScript = preload("res://scripts/ui/garage.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_database()
	_test_profile_contract()
	_test_session_modes()
	_test_time_trial_results_contract()
	_test_grand_prix_persistence()
	_test_garage_current_chassis()
	_test_backup_recovery()
	_test_deterministic_racer()
	_test_boost_pad_contract()
	_test_chassis_abilities()
	_test_audio_event_lifecycle()
	if _failures.is_empty():
		print("MECHA GODOT SMOKE: PASS (catalogue, save recovery, results, GP resume, garage, racer, pads, 10 abilities, audio)")
		quit(0)
		return
	for failure in _failures:
		push_error("MECHA GODOT SMOKE: %s" % failure)
	quit(1)


func _test_database() -> void:
	_expect(DatabaseScript.CHASSIS.size() == 10, "le catalogue doit contenir 10 châssis")
	_expect(DatabaseScript.TRACKS.size() == 4, "le catalogue doit contenir 4 circuits")
	_expect(DatabaseScript.ITEMS.size() == 8, "le catalogue doit contenir 8 objets")
	var expected := {
		"biped": "Raptor R2", "tripod": "Triarch T3", "quadruped": "Fenrir Q4",
		"hexapod": "Mantis H6", "octopod": "Arachne O8", "hover": "Wraith V0",
		"tracked": "Bastion C2", "monowheel": "Cyclops M1", "orb": "Orb S7",
		"centurion": "Centurion S12",
	}
	for chassis_id: String in expected:
		var chassis: Dictionary = DatabaseScript.get_chassis(chassis_id)
		_expect(String(chassis.get("name", "")) == expected[chassis_id], "châssis canonique manquant : %s" % chassis_id)
	for track: Dictionary in DatabaseScript.TRACKS:
		_expect(float(track.get("verticality", 0.0)) >= 4.0, "relief trop faible : %s" % track.get("id", "?"))
		var palette: Dictionary = track.get("palette", {})
		for key: String in ["sky", "ground", "road", "shoulder", "glow", "accent", "key"]:
			_expect(palette.has(key), "palette %s incomplète : %s" % [track.get("id", "?"), key])


func _test_profile_contract() -> void:
	var service: SaveSystemService = SaveScript.new()
	var clean: Dictionary = service._sanitize_profile({
		"version": -4,
		"credits": -900,
		"selected_chassis": "inconnu",
		"records": {"foundry": {"time_trial": -2.0}},
	})
	_expect(int(clean.get("version", 0)) == SaveScript.SAVE_VERSION, "migration de version invalide")
	_expect(int(clean.get("credits", -1)) == 0, "les crédits négatifs doivent être normalisés")
	_expect(String(clean.get("selected_chassis", "")) == "biped", "fallback châssis invalide")
	_expect(Dictionary(clean.get("records", {})).is_empty(), "un chrono invalide ne doit pas survivre")
	service.free()


func _test_session_modes() -> void:
	for mode in SessionScript.MODES:
		var service: GameSessionService = SessionScript.new()
		var configured: Dictionary = service.configure({"mode": mode, "track_id": "foundry", "difficulty": "pilot"})
		_expect(String(configured.get("mode", "")) == mode, "mode non configurable : %s" % mode)
		_expect(int(configured.get("racer_count", 0)) == (1 if mode == "time_trial" else 8), "grille incorrecte : %s" % mode)
		service.free()


func _test_time_trial_results_contract() -> void:
	var service: SaveSystemService = _new_test_save("time_trial")
	service.profile = service._default_profile()
	_expect(service.save_profile(), "préparation sauvegarde TT impossible")
	var session: GameSessionService = SessionScript.new()
	session._save_system_override = service
	var configured: Dictionary = session.configure({
		"mode": "time_trial", "track_id": "foundry", "difficulty": "pilot", "laps": 1,
	})
	var result: Dictionary = session.complete_race({
		"finished": true,
		"position": 1,
		"elapsed": 71.25,
		"laps_completed": 1,
		"classification": [{"racer_id": "player", "display_name": "PILOTE 01", "elapsed": 71.25}],
	})
	_expect(int(configured.get("racer_count", 0)) == 1, "le TT doit configurer un seul pilote")
	_expect(int(result.get("racer_count", 0)) == 1 and int(result.get("total_racers", 0)) == 1, "Results doit recevoir 1/1 en TT")
	_expect(String(result.get("track_name", "")) == "Fonderie Néon", "Results doit recevoir le nom canonique du circuit")
	_expect(bool(result.get("new_record", false)), "le premier TT terminé doit créer un record")
	_expect(is_equal_approx(float(result.get("best_time", 0.0)), 71.25), "le meilleur temps TT doit être le chrono homologué")
	var result_classification: Array = result.get("classification", [])
	_expect(not result_classification.is_empty() and String(Dictionary(result_classification[0]).get("name", "")) == "PILOTE 01", "le classement Results doit conserver le nom du pilote")

	session.configure({"mode": "time_trial", "track_id": "foundry", "difficulty": "pilot", "laps": 1})
	var slower_result: Dictionary = session.complete_race({
		"finished": true,
		"position": 1,
		"elapsed": 79.0,
		"laps_completed": 1,
		"classification": [{"racer_id": "player", "display_name": "PILOTE 01", "elapsed": 79.0}],
	})
	_expect(not bool(slower_result.get("new_record", true)), "un TT plus lent ne doit pas annoncer un nouveau record")
	_expect(is_equal_approx(float(slower_result.get("best_time", 0.0)), 71.25), "Results doit conserver le meilleur temps antérieur")
	_cleanup_test_storage(service)
	session.free()
	service.free()


func _test_grand_prix_persistence() -> void:
	var service: SaveSystemService = _new_test_save("grand_prix")
	service.profile = service._default_profile()
	_expect(service.save_profile(), "préparation sauvegarde GP impossible")
	var session: GameSessionService = SessionScript.new()
	session._save_system_override = service
	var first_config: Dictionary = session.configure({
		"mode": "grand_prix", "difficulty": "pilot", "new_championship": true, "laps": 1,
	})
	_expect(String(first_config.get("track_id", "")) == "foundry", "le GP doit commencer à la Fonderie")
	var first_result: Dictionary = _complete_grand_prix_round(session, 82.0)
	_expect(int(first_result.get("round", 0)) == 1 and int(first_result.get("total_rounds", 0)) == 4, "Results doit afficher la manche GP 1/4")
	_expect(bool(first_result.get("can_continue", false)) and not bool(first_result.get("championship_complete", true)), "la manche GP 1 doit proposer la suivante")
	_expect(int(first_result.get("points", 0)) == 15, "une victoire GP doit attribuer 15 points")
	_expect(_championship_player_points(first_result) == 15, "le classement GP doit cumuler les points de la manche 1")
	_expect(int(service.get_championship().get("round_index", -1)) == 1, "la manche GP 1 doit être persistée")

	session.free()
	service.free()
	var restored_service: SaveSystemService = _new_test_save("grand_prix", false)
	var restored_profile: Dictionary = restored_service.load_profile()
	_expect(not restored_profile.is_empty(), "le profil GP doit être relu depuis le disque")
	var restored_session: GameSessionService = SessionScript.new()
	restored_session._save_system_override = restored_service
	var resumed: Dictionary = restored_session.restore_championship()
	_expect(int(resumed.get("round_index", -1)) == 1, "le GP doit reprendre après la manche 1")
	var next_config: Dictionary = restored_session.start_next_grand_prix_round()
	var final_result: Dictionary = {}
	for expected_round in range(2, 5):
		_expect(String(next_config.get("track_id", "")) == SessionScript.GRAND_PRIX_TRACKS[expected_round - 1], "circuit GP incorrect à la manche %d" % expected_round)
		var round_result: Dictionary = _complete_grand_prix_round(restored_session, 82.0 + expected_round)
		_expect(int(round_result.get("round", 0)) == expected_round, "Results doit afficher la manche GP %d/4" % expected_round)
		_expect(_championship_player_points(round_result) == expected_round * 15, "points GP cumulés incorrects à la manche %d" % expected_round)
		final_result = round_result
		if expected_round < 4:
			_expect(bool(round_result.get("can_continue", false)), "la manche GP %d doit proposer la suivante" % expected_round)
			next_config = restored_session.start_next_grand_prix_round()

	_expect(bool(final_result.get("championship_complete", false)), "la quatrième manche doit clore le championnat")
	_expect(not bool(final_result.get("can_continue", true)), "Results ne doit pas proposer de cinquième manche")
	_expect(bool(final_result.get("championship_won", false)), "quatre victoires doivent sacrer le joueur")
	_expect(restored_service.get_championship().is_empty(), "un championnat terminé ne doit plus être repris")
	_expect(restored_session.start_next_grand_prix_round().is_empty(), "aucune configuration ne doit suivre la finale GP")
	var gp_stats: Dictionary = restored_service.profile.get("stats", {})
	_expect(int(gp_stats.get("championships", 0)) == 1, "le titre GP doit être comptabilisé une seule fois")
	_cleanup_test_storage(restored_service)
	restored_session.free()
	restored_service.free()


func _test_garage_current_chassis() -> void:
	var service: SaveSystemService = _new_test_save("garage")
	service.profile = service._default_profile()
	_expect(service.save_profile(), "préparation sauvegarde garage impossible")
	var garage: GarageScreen = GarageScript.new()
	garage._current_id = "tripod"
	var credits_before := int(service.profile.get("credits", 0))
	_expect(garage._purchase_current_upgrade(service, "engine"), "l'achat moteur du châssis parcouru doit réussir")
	_expect(service.get_upgrade_level("engine", "tripod") == 1, "le moteur du tripod parcouru doit augmenter")
	_expect(service.get_upgrade_level("engine", "biped") == 0, "le biped actif ne doit pas être amélioré à la place")
	_expect(int(service.profile.get("credits", 0)) == credits_before - 650, "le coût garage doit être débité une seule fois")
	garage.free()
	service.free()

	var restored_service: SaveSystemService = _new_test_save("garage", false)
	restored_service.load_profile()
	_expect(restored_service.get_upgrade_level("engine", "tripod") == 1, "l'amélioration du tripod doit survivre au rechargement")
	_expect(restored_service.get_upgrade_level("engine", "biped") == 0, "le biped doit rester inchangé après rechargement")
	_cleanup_test_storage(restored_service)
	restored_service.free()


func _test_backup_recovery() -> void:
	var service: SaveSystemService = _new_test_save("backup_valid")
	var backup_profile: Dictionary = service._default_profile()
	backup_profile["credits"] = 4321
	_expect(_write_test_text(service._backup_path, JSON.stringify(backup_profile)), "écriture du backup valide impossible")
	_expect(_write_test_text(service._save_path, "{profil-corrompu"), "écriture du profil corrompu impossible")
	var recovered: Dictionary = service.load_profile()
	_expect(int(recovered.get("credits", 0)) == 4321, "un backup valide doit être restauré avant un profil neuf")
	_expect(FileAccess.file_exists(service._save_path), "le backup restauré doit être promu en profil principal")
	_expect(FileAccess.file_exists(service._backup_path), "le backup valide ne doit pas être écrasé pendant sa promotion")
	_expect(FileAccess.file_exists(service._corrupt_path), "le profil principal corrompu doit être archivé")
	var preserved_backup: Dictionary = service._read_profile_candidate(service._backup_path)
	var preserved_data: Dictionary = preserved_backup.get("data", {})
	_expect(bool(preserved_backup.get("valid", false)) and int(preserved_data.get("credits", 0)) == 4321, "le contenu du backup restauré doit rester intact")
	_cleanup_test_storage(service)
	service.free()

	var missing_service: SaveSystemService = _new_test_save("backup_missing")
	var missing_backup: Dictionary = missing_service._default_profile()
	missing_backup["credits"] = 5432
	_expect(_write_test_text(missing_service._backup_path, JSON.stringify(missing_backup)), "écriture du backup sans principal impossible")
	var missing_recovered: Dictionary = missing_service.load_profile()
	_expect(int(missing_recovered.get("credits", 0)) == 5432, "un backup valide doit restaurer un principal manquant")
	_expect(FileAccess.file_exists(missing_service._backup_path), "le backup d'un principal manquant doit être conservé")
	_cleanup_test_storage(missing_service)
	missing_service.free()

	var invalid_service: SaveSystemService = _new_test_save("backup_invalid")
	_expect(_write_test_text(invalid_service._save_path, "{invalide"), "écriture du principal invalide impossible")
	_expect(_write_test_text(invalid_service._backup_path, "[invalide"), "écriture du backup invalide impossible")
	var rebuilt: Dictionary = invalid_service.load_profile()
	_expect(int(rebuilt.get("credits", 0)) == 1800, "deux sauvegardes invalides doivent produire le profil sain par défaut")
	_expect(FileAccess.file_exists(invalid_service._corrupt_path), "le principal invalide doit être archivé")
	_expect(FileAccess.file_exists(invalid_service._backup_corrupt_path), "le backup invalide doit être archivé séparément")
	_cleanup_test_storage(invalid_service)
	invalid_service.free()


func _complete_grand_prix_round(session: GameSessionService, elapsed: float) -> Dictionary:
	var current: Dictionary = session.current_config()
	return session.complete_race({
		"finished": true,
		"position": 1,
		"elapsed": elapsed,
		"laps_completed": int(current.get("laps", 3)),
		"classification": _championship_classification(session),
	})


func _championship_classification(session: GameSessionService) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var entrants: Array = session.championship.get("entrants", [])
	for entrant_value: Variant in entrants:
		if not entrant_value is Dictionary:
			continue
		var entrant: Dictionary = entrant_value
		output.append({
			"racer_id": String(entrant.get("id", "")),
			"display_name": String(entrant.get("name", "PILOTE")),
			"elapsed": 80.0 + output.size(),
		})
	return output


func _championship_player_points(result: Dictionary) -> int:
	var championship_value: Variant = result.get("championship", {})
	if not championship_value is Dictionary:
		return -1
	var championship_data: Dictionary = championship_value
	var standings_value: Variant = championship_data.get("standings", [])
	if not standings_value is Array:
		return -1
	for entry_value: Variant in standings_value:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if String(entry.get("racer_id", "")) == "player":
				return int(entry.get("points", -1))
	return -1


func _new_test_save(suffix: String, cleanup_before: bool = true) -> SaveSystemService:
	var service: SaveSystemService = SaveScript.new()
	var stem := "user://mecha_overdrive_contract_%s" % suffix
	service._save_path = "%s.json" % stem
	service._temp_path = "%s.tmp" % stem
	service._backup_path = "%s.backup.json" % stem
	service._corrupt_path = "%s.corrupt.json" % stem
	service._backup_corrupt_path = "%s.backup.corrupt.json" % stem
	if cleanup_before:
		_cleanup_test_storage(service)
	return service


func _cleanup_test_storage(service: SaveSystemService) -> void:
	var paths: Array[String] = [
		service._save_path,
		service._temp_path,
		service._backup_path,
		service._corrupt_path,
		service._backup_corrupt_path,
	]
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		_expect(remove_error == OK, "nettoyage du fichier user:// de test impossible : %s" % path)


func _write_test_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error == OK


func _test_deterministic_racer() -> void:
	var spec := {
		"racer_id": "test", "display_name": "TEST", "chassis_id": "biped",
		"difficulty": "pilot", "track_length": 400.0, "total_laps": 1, "seed": 441,
	}
	var first: RacerState = RacerScript.new().configure(spec)
	var second: RacerState = RacerScript.new().configure(spec)
	var controls := {"throttle": 1.0, "brake": 0.0, "steer": 0.12, "drift": false, "boost": true}
	for tick in range(300):
		var elapsed := (tick + 1) / 60.0
		var context := {"elapsed": elapsed, "race_active": true, "grip": 1.0, "curvature": 0.08, "hazard": "", "speed_multiplier": 1.0}
		first.step(1.0 / 60.0, controls, context)
		second.step(1.0 / 60.0, controls, context)
	var first_snapshot: Dictionary = first.snapshot()
	var second_snapshot: Dictionary = second.snapshot()
	_expect(is_equal_approx(float(first_snapshot.get("distance", -1.0)), float(second_snapshot.get("distance", -2.0))), "simulation non déterministe")
	_expect(first_snapshot.has("max_armor"), "snapshot max_armor absent")
	_expect(float(first_snapshot.get("distance", 0.0)) > 0.0, "le racer ne progresse pas")


func _test_boost_pad_contract() -> void:
	var first: RacerState = _configured_racer("biped", "pad_a", 0.24)
	var second: RacerState = _configured_racer("biped", "pad_b", 0.24)
	first.heat = 0.79
	second.heat = 0.79
	_expect(first.grant_item("shield") and second.grant_item("shield"), "précondition objet du boost pad invalide")
	_expect(first.apply_boost_pad() and second.apply_boost_pad(), "le boost pad doit s'activer")
	var first_state: Dictionary = first.snapshot()
	var second_state: Dictionary = second.snapshot()
	_expect(String(first_state.get("item", "")) == "shield", "le boost pad ne doit pas consommer l'objet tenu")
	_expect(String(first.use_item()) == "shield", "l'objet tenu doit rester utilisable après le boost pad")
	_expect(is_equal_approx(float(first_state.get("boost_energy", 0.0)), 1.0), "le boost pad doit recharger le réacteur")
	_expect(is_equal_approx(float(first_state.get("boost_energy", -1.0)), float(second_state.get("boost_energy", -2.0))), "boost pad non déterministe")
	_expect(is_equal_approx(float(first_state.get("heat", -1.0)), float(second_state.get("heat", -2.0))), "refroidissement boost pad non déterministe")


func _test_chassis_abilities() -> void:
	var expected_ids := {
		"biped": "gyro_correction", "tripod": "vector_anchor",
		"quadruped": "predator_stride", "hexapod": "adaptive_steps",
		"octopod": "distributed_ram", "hover": "magnetic_cushion",
		"tracked": "heavy_transmission", "monowheel": "gyro_drift",
		"orb": "inertial_rebound", "centurion": "walking_wave",
	}
	for chassis_id: String in expected_ids:
		var racer: RacerState = _configured_racer(chassis_id, "ability_%s" % chassis_id)
		var ability: Dictionary = racer.chassis_ability_snapshot()
		_expect(String(ability.get("id", "")) == String(expected_ids[chassis_id]), "contrat capacité absent : %s" % chassis_id)
		_expect(String(Dictionary(racer.snapshot().get("ability", {})).get("id", "")) == String(expected_ids[chassis_id]), "snapshot capacité absent : %s" % chassis_id)

	var biped: RacerState = _configured_racer("biped", "ability_biped")
	biped.apply_hit(0.0, 1.0)
	_expect(is_equal_approx(float(biped.chassis_ability_snapshot().get("control_loss_factor", 0.0)), 0.60), "gyro-correction bipède non branchée")

	var tripod: RacerState = _configured_racer("tripod", "ability_tripod")
	tripod.apply_hit(10.0, 1.0)
	_expect(is_equal_approx(float(tripod.chassis_ability_snapshot().get("control_loss_factor", 0.0)), 0.42), "ancrage tripode non branché")
	_expect(float(tripod.snapshot().get("armor", 0.0)) > tripod.armor_max - 10.0, "résistance tripode aux impacts absente")

	var quadruped: RacerState = _configured_racer("quadruped", "ability_quadruped")
	quadruped.apply_hit(1.0, 0.0)
	_expect(bool(quadruped.chassis_ability_snapshot().get("active", false)), "reprise quadrupède non déclenchée après impact")

	var hexapod: RacerState = _configured_racer("hexapod", "ability_hexapod")
	_expect(hexapod.offroad_drag_factor() < 0.5, "pas adaptatifs hexapode non branchés")
	_expect(float(hexapod.chassis_ability_snapshot().get("low_speed_steering_factor", 1.0)) > 1.0, "braquage basse vitesse hexapode absent")

	var octopod: RacerState = _configured_racer("octopod", "ability_octopod")
	_expect(octopod.contact_damage_multiplier() > 1.5, "bélier octopode non branché")
	_expect(float(octopod.chassis_ability_snapshot().get("momentum_loss_factor", 1.0)) < 0.5, "inertie octopode absente")

	var hover: RacerState = _configured_racer("hover", "ability_hover")
	var hover_armor := hover.armor
	_expect(not hover.apply_ground_mine(), "le hover doit ignorer les mines au sol")
	_expect(is_equal_approx(hover.armor, hover_armor) and hover.offroad_drag_factor() < 0.2, "coussin magnétique hover incomplet")

	var tracked: RacerState = _configured_racer("tracked", "ability_tracked")
	_expect(is_zero_approx(tracked._hazard_drag("sand")) and is_zero_approx(tracked._hazard_drag("debris")), "chenilles : sable/débris encore pénalisants")
	_expect(tracked.contact_damage_multiplier() > 1.3, "poussée de contact chenilles absente")

	var monowheel: RacerState = _configured_racer("monowheel", "ability_monowheel")
	monowheel.speed = monowheel.top_speed * 0.62
	monowheel.heat = 0.80
	var context := {"elapsed": 1.0, "race_active": true, "grip": 1.0, "curvature": 0.3, "hazard": "", "speed_multiplier": 1.0}
	monowheel.step(0.05, {"throttle": 0.8, "brake": 0.0, "steer": 0.8, "drift": true, "boost": false}, context)
	context["elapsed"] = 1.05
	monowheel.step(0.05, {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "drift": false, "boost": false}, context)
	_expect(bool(monowheel.chassis_ability_snapshot().get("active", false)), "micro-poussée de sortie de drift absente")
	_expect(monowheel.heat < 0.80, "refroidissement de drift monoroue absent")

	var orb: RacerState = _configured_racer("orb", "ability_orb")
	orb.speed = 18.0
	orb.apply_hit(0.0, 0.5)
	_expect(orb.speed > 18.0 and float(orb.chassis_ability_snapshot().get("impact_thrust", 0.0)) > 0.0, "conversion d'impact Orb en poussée absente")

	var centurion: RacerState = _configured_racer("centurion", "ability_centurion")
	var baseline: RacerState = _configured_racer("biped", "ability_baseline")
	_expect(centurion._hazard_drag("debris") < baseline._hazard_drag("debris"), "résistance Centurion aux débris absente")
	_expect(centurion._hazard_drag("gravity") < baseline._hazard_drag("gravity"), "résistance Centurion à la gravité absente")


func _test_audio_event_lifecycle() -> void:
	var director: AudioDirector = AudioScript.new()
	director.configure({"master_volume": 0.7, "music_volume": 0.4, "effects_volume": 0.8})
	_expect(director.procedural_audio_enabled(), "l'audio procédural doit rester actif, y compris sur Web")
	director.play_event("count")
	_expect(director._events.size() == 1, "événement audio procédural non créé")
	for _sample in range(5000):
		director._sample_frame()
	_expect(director._events.is_empty(), "événement audio expiré non compacté")
	director.free()


func _configured_racer(chassis_id: String, racer_id: String, initial_boost: float = 0.55) -> RacerState:
	return RacerScript.new().configure({
		"racer_id": racer_id, "display_name": racer_id, "chassis_id": chassis_id,
		"difficulty": "pilot", "track_length": 400.0, "total_laps": 1,
		"seed": racer_id.hash(), "boost_energy": initial_boost,
	})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
