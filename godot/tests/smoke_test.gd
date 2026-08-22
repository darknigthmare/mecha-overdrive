extends SceneTree
## Headless smoke test: godot --headless --path godot --script res://tests/smoke_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const SaveScript = preload("res://scripts/systems/save_system.gd")
const SessionScript = preload("res://scripts/systems/game_session.gd")
const RacerScript = preload("res://scripts/race/racer_state.gd")
const AudioScript = preload("res://scripts/audio/audio_director.gd")
const GarageScript = preload("res://scripts/ui/garage.gd")
const MechaFactoryScript = preload("res://scripts/mecha/mecha_factory.gd")
const RaceControllerScript = preload("res://scripts/race/race_controller.gd")
const TrackFactoryScript = preload("res://scripts/world/track_factory.gd")
const GaragePreviewScene = preload("res://scenes/components/garage_preview.tscn")

var _failures: Array[String] = []


func _init() -> void:
	_test_database()
	_test_asset_manifest_contract()
	_test_profile_contract()
	_test_session_modes()
	_test_division_grids()
	_test_modular_contract()
	_test_module_purchase_contract()
	_test_performance_classes()
	_test_mecha_visual_contract()
	_test_track_visual_contract()
	_test_championship_migration_and_tamper_guard()
	_test_time_trial_results_contract()
	_test_grand_prix_persistence()
	_test_garage_current_chassis()
	_test_garage_preview_contract()
	_test_backup_recovery()
	_test_deterministic_racer()
	_test_boost_pad_contract()
	_test_chassis_abilities()
	_test_audio_event_lifecycle()
	if _failures.is_empty():
		print("MECHA GODOT SMOKE: PASS (10 chassis, 5 divisions, 8 tracks, 6 cups, 18 modules, 12 textures, garage preview, TPS/FPS, save v4, GP resume, racer, audio)")
		quit(0)
		return
	for failure in _failures:
		push_error("MECHA GODOT SMOKE: %s" % failure)
	quit(1)


func _test_database() -> void:
	_expect(DatabaseScript.CHASSIS.size() == 10, "le catalogue doit contenir 10 châssis")
	_expect(DatabaseScript.TRACKS.size() == 8, "le catalogue doit contenir 8 circuits")
	_expect(DatabaseScript.ITEMS.size() == 8, "le catalogue doit contenir 8 objets")
	_expect(DatabaseScript.DIVISIONS.size() == 5, "le catalogue doit contenir 5 divisions")
	_expect(DatabaseScript.MODULE_SLOTS.size() == 3, "la customisation doit exposer 3 emplacements")
	_expect(DatabaseScript.CHAMPIONSHIPS.size() == 6, "le catalogue doit contenir 6 championnats")
	var module_count := 0
	var module_ids: Dictionary = {}
	for slot: Dictionary in DatabaseScript.MODULE_SLOTS:
		var options: Array = slot.get("options", [])
		_expect(options.size() == 6, "chaque emplacement doit proposer 6 modules : %s" % slot.get("id", "?"))
		module_count += options.size()
		for option_value: Variant in options:
			if not option_value is Dictionary:
				_expect(false, "option module invalide : %s" % slot.get("id", "?"))
				continue
			var option: Dictionary = option_value
			var module_id := String(option.get("id", ""))
			_expect(not module_id.is_empty() and not module_ids.has(module_id), "identifiant module absent ou dupliqué : %s" % module_id)
			module_ids[module_id] = true
			_expect(int(option.get("cost", -1)) >= 0, "coût module invalide : %s" % module_id)
			_expect(not String(option.get("visual_profile", "")).is_empty(), "profil visuel module absent : %s" % module_id)
			_expect(not String(option.get("texture_set", "")).is_empty(), "texture de module absente : %s" % module_id)
	_expect(module_count == 18 and module_ids.size() == 18, "la customisation doit contenir 18 modules uniques")
	var expected := {
		"biped": "Raptor R2", "tripod": "Triarch T3", "quadruped": "Fenrir Q4",
		"hexapod": "Mantis H6", "octopod": "Arachne O8", "hover": "Wraith V0",
		"tracked": "Bastion C2", "monowheel": "Cyclops M1", "orb": "Orb S7",
		"centurion": "Centurion S12",
	}
	for chassis_id: String in expected:
		var chassis: Dictionary = DatabaseScript.get_chassis(chassis_id)
		_expect(String(chassis.get("name", "")) == expected[chassis_id], "châssis canonique manquant : %s" % chassis_id)
		_expect(not DatabaseScript.get_division(String(chassis.get("division_id", ""))).is_empty(), "division invalide : %s" % chassis_id)
		_expect(Dictionary(chassis.get("default_loadout", {})).size() == 3, "loadout incomplet : %s" % chassis_id)
		_expect(chassis.has("cockpit_offset"), "ancrage cockpit absent : %s" % chassis_id)
	for track: Dictionary in DatabaseScript.TRACKS:
		_expect(float(track.get("verticality", 0.0)) >= 4.0, "relief trop faible : %s" % track.get("id", "?"))
		_expect(float(track.get("base_grip", 0.0)) > 0.0, "adhérence absente : %s" % track.get("id", "?"))
		_expect(not String(track.get("layout_profile", "")).is_empty(), "profil visuel absent : %s" % track.get("id", "?"))
		var palette: Dictionary = track.get("palette", {})
		for key: String in ["sky", "ground", "road", "shoulder", "glow", "accent", "key"]:
			_expect(palette.has(key), "palette %s incomplète : %s" % [track.get("id", "?"), key])
	for cup: Dictionary in DatabaseScript.CHAMPIONSHIPS:
		var mixed := bool(cup.get("mixed_divisions", false))
		var division_id := String(cup.get("division_id", ""))
		_expect(Array(cup.get("track_ids", [])).size() >= 4, "championnat trop court : %s" % cup.get("id", "?"))
		if mixed:
			_expect(division_id.is_empty(), "un Open mixte ne doit pas imposer de division")
		else:
			_expect(not DatabaseScript.get_division(division_id).is_empty(), "coupe dédiée sans division")
	for texture_path: String in [
		"res://assets/textures/openai/mecha_armor.png",
		"res://assets/textures/openai/track_surface.png",
		"res://assets/textures/openai/cockpit_composite.png",
		"res://assets/textures/openai/environment_panels.png",
		"res://assets/textures/openai/mecha_armor_light.png",
		"res://assets/textures/openai/mecha_armor_heavy.png",
		"res://assets/textures/openai/module_energy.png",
		"res://assets/textures/openai/module_mobility.png",
		"res://assets/textures/openai/module_utility.png",
		"res://assets/textures/openai/track_thermal.png",
		"res://assets/textures/openai/track_cryo.png",
		"res://assets/textures/openai/garage_bay.png",
	]:
		_expect(ResourceLoader.exists(texture_path), "texture OpenAI absente : %s" % texture_path)


func _test_asset_manifest_contract() -> void:
	var manifest_file := FileAccess.open("res://assets/textures/openai/manifest.json", FileAccess.READ)
	_expect(manifest_file != null, "manifest OpenAI absent")
	if manifest_file == null:
		return
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	_expect(parsed is Dictionary, "manifest OpenAI invalide")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	_expect(int(manifest.get("schema_version", 0)) == 2, "le manifest OpenAI doit utiliser le schema 2")
	var expected_files: Array[String] = [
		"mecha_armor.png", "track_surface.png", "cockpit_composite.png", "environment_panels.png",
		"mecha_armor_light.png", "mecha_armor_heavy.png", "module_energy.png", "module_mobility.png",
		"module_utility.png", "track_thermal.png", "track_cryo.png", "garage_bay.png",
	]
	var assets: Array = manifest.get("assets", [])
	var seen: Dictionary = {}
	_expect(assets.size() == 12, "le manifest OpenAI doit décrire 12 textures")
	for asset_value: Variant in assets:
		if not asset_value is Dictionary:
			_expect(false, "entrée du manifest OpenAI invalide")
			continue
		var file_name := String(Dictionary(asset_value).get("file", ""))
		_expect(expected_files.has(file_name), "texture inattendue dans le manifest : %s" % file_name)
		_expect(not seen.has(file_name), "texture dupliquée dans le manifest : %s" % file_name)
		seen[file_name] = true
	for file_name: String in expected_files:
		_expect(seen.has(file_name), "texture absente du manifest : %s" % file_name)


func _test_profile_contract() -> void:
	var service: SaveSystemService = SaveScript.new()
	_expect(SaveScript.SAVE_VERSION == 4, "SAVE_VERSION doit être 4")
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
	_expect(Dictionary(clean.get("loadouts", {})).size() == 10, "la migration v4 doit créer 10 loadouts")
	_expect(String(Dictionary(clean.get("settings", {})).get("camera_view", "")) == "tps", "la migration v4 doit utiliser la vue TPS")
	var historic_modules: Array[String] = [
		"core_balanced", "core_overdrive", "core_bastion",
		"mobility_vector", "mobility_sprint", "mobility_adaptive",
		"utility_coolant", "utility_aegis", "utility_scanner",
	]
	var owned_modules: Array = clean.get("owned_modules", [])
	_expect(owned_modules.size() == historic_modules.size(), "les 9 modules historiques doivent rester acquis")
	for module_id: String in historic_modules:
		_expect(owned_modules.has(module_id), "module historique non acquis après migration : %s" % module_id)
	for chassis_id: String in Dictionary(clean.get("loadouts", {})).keys():
		_expect(Dictionary(Dictionary(clean.get("loadouts", {}))[chassis_id]).size() == 3, "loadout migré incomplet : %s" % chassis_id)
	service.free()


func _test_session_modes() -> void:
	for mode in SessionScript.MODES:
		var service: GameSessionService = SessionScript.new()
		var configured: Dictionary = service.configure({"mode": mode, "track_id": "foundry", "difficulty": "pilot"})
		_expect(String(configured.get("mode", "")) == mode, "mode non configurable : %s" % mode)
		_expect(int(configured.get("racer_count", 0)) == (1 if mode == "time_trial" else 8), "grille incorrecte : %s" % mode)
		service.free()


func _test_division_grids() -> void:
	var service: GameSessionService = SessionScript.new()
	var dedicated: Dictionary = service.configure({"mode": "quick", "track_id": "foundry", "seed": 23})
	_expect(String(dedicated.get("grid_policy", "")) == "division", "la grille rapide doit être dédiée par défaut")
	_expect(not bool(dedicated.get("mixed_divisions", true)), "une grille dédiée ne doit pas être marquée mixte")
	_expect(_roster_divisions(dedicated).size() == 1 and _roster_divisions(dedicated).has("command"), "la grille dédiée doit rester en Commandement")
	var invalid: Dictionary = service.configure({"mode": "quick", "grid_policy": "future_open", "seed": 23})
	_expect(String(invalid.get("grid_policy", "")) == "division", "une politique inconnue doit échouer en mode dédié")
	_expect(_roster_divisions(invalid).size() == 1, "une politique invalide ne doit jamais ouvrir la grille")
	var mixed: Dictionary = service.configure({"mode": "quick", "grid_policy": "mixed", "ruleset_id": "open_mixed", "seed": 23})
	_expect(String(mixed.get("grid_policy", "")) == "mixed" and bool(mixed.get("mixed_divisions", false)), "l'Open explicite doit activer la grille mixte")
	_expect(_roster_divisions(mixed).size() >= 3, "l'Open doit réellement mélanger plusieurs divisions")
	var mixed_mismatch: Dictionary = service.configure({"mode": "quick", "grid_policy": "mixed", "ruleset_id": "division_locked", "seed": 23})
	_expect(String(mixed_mismatch.get("ruleset_id", "")) == "open_mixed", "une grille mixte ne doit jamais conserver un règlement dédié")
	var division_mismatch: Dictionary = service.configure({"mode": "quick", "grid_policy": "division", "ruleset_id": "open_mixed", "seed": 23})
	_expect(String(division_mismatch.get("ruleset_id", "")) == "division_locked", "une grille dédiée ne doit jamais conserver un règlement Open")
	var cup: Dictionary = service.configure({"mode": "grand_prix", "championship_id": "nexus_open", "difficulty": "ace", "new_championship": true, "racer_count": 2, "seed": 91})
	_expect(String(cup.get("championship_id", "")) == "nexus_open", "le Grand Open doit être sélectionnable")
	_expect(String(cup.get("grid_policy", "")) == "mixed" and _roster_divisions(cup).size() >= 3, "le Grand Open doit conserver sa grille interdivision")
	_expect(Array(service.championship.get("tracks", [])).size() == 8, "le Grand Open doit parcourir les 8 circuits")
	var resumed_cup: Dictionary = service.configure({"mode": "grand_prix", "championship_id": "nexus_open", "difficulty": "rookie", "new_championship": false})
	_expect(String(resumed_cup.get("difficulty", "")) == "ace", "la reprise doit conserver la difficulté homologuée du championnat")
	service.free()
	_expect(int(cup.get("racer_count", 0)) == 8 and Array(cup.get("roster", [])).size() == 8, "un GP doit toujours homologuer et lancer 8 concurrents")


func _test_modular_contract() -> void:
	var service: SaveSystemService = _new_test_save("modules")
	service.profile = service._default_profile()
	_expect(service.set_module("biped", "core", "core_overdrive"), "le module Overdrive doit être installable")
	_expect(String(service.get_loadout("biped").get("core", "")) == "core_overdrive", "le module installé doit être relu")
	_expect(not service.set_module("biped", "core", "utility_aegis"), "un module d'un autre emplacement doit être rejeté")
	_expect(service.set_camera_view("fps") and service.get_camera_view() == "fps", "la vue cockpit doit être persistée")
	_expect(not service.set_camera_view("cinematic") and service.get_camera_view() == "fps", "une vue inconnue doit être rejetée")
	var baseline: RacerState = RacerScript.new().configure({"chassis_id": "biped", "racer_id": "baseline", "module_stats": {}})
	var tuned: RacerState = RacerScript.new().configure({"chassis_id": "biped", "racer_id": "tuned", "module_stats": {"speed": 6, "armor": -5, "handling": 8}})
	_expect(tuned.top_speed > baseline.top_speed, "le module vitesse doit modifier la simulation")
	_expect(tuned.armor_max < baseline.armor_max, "le compromis de blindage doit modifier la simulation")
	_expect(tuned.handling > baseline.handling, "le module de maniabilité doit modifier la simulation")
	_cleanup_test_storage(service)
	service.free()


func _test_module_purchase_contract() -> void:
	var service: SaveSystemService = _new_test_save("module_purchase")
	service.profile = service._default_profile()
	service.profile["credits"] = 6000
	var command_loadout := {
		"core": "core_tactical_relay",
		"mobility": "mobility_gyro_rail",
		"utility": "utility_command_uplink",
	}
	var first_cost := service.get_loadout_cost("biped", command_loadout)
	_expect(first_cost == 4550, "le prix groupé des nouveaux modules Commandement doit être 4550")
	_expect(service.purchase_and_apply_garage("biped", "#4FA9FF", command_loadout), "l'achat atomique des nouveaux modules doit réussir")
	_expect(int(service.profile.get("credits", -1)) == 6000 - first_cost, "les nouveaux modules doivent être débités exactement une fois")
	for module_id: String in command_loadout.values():
		_expect(service.is_module_owned(module_id), "module acheté non acquis : %s" % module_id)
	_expect(service.get_loadout("biped") == command_loadout, "le loadout acheté doit être équipé atomiquement")
	var credits_after_first_purchase := int(service.profile.get("credits", -1))
	_expect(service.get_loadout_cost("biped", command_loadout) == 0, "un module déjà acquis ne doit plus être facturé")
	_expect(service.purchase_and_apply_garage("biped", "#4FA9FF", command_loadout), "réappliquer un loadout acquis doit réussir")
	_expect(int(service.profile.get("credits", -1)) == credits_after_first_purchase, "réappliquer un loadout ne doit jamais débiter deux fois")
	_cleanup_test_storage(service)
	service.free()

	var atomic_service: SaveSystemService = _new_test_save("module_atomic_failure")
	atomic_service.profile = atomic_service._default_profile()
	var prototype_loadout := {
		"core": "core_phase_lattice",
		"mobility": "mobility_phase_skates",
		"utility": "utility_phase_sink",
	}
	var prototype_cost := atomic_service.get_loadout_cost("hover", prototype_loadout)
	_expect(prototype_cost == 7050, "le prix groupé Prototype doit être 7050")
	atomic_service.profile["credits"] = prototype_cost - 1
	var before_failure := atomic_service.profile.duplicate(true)
	_expect(not atomic_service.purchase_and_apply_garage("hover", "#B86BFF", prototype_loadout), "un achat sans crédits suffisants doit être refusé")
	_expect(atomic_service.profile == before_failure, "un achat refusé doit laisser tout le profil inchangé")
	for module_id: String in prototype_loadout.values():
		_expect(not atomic_service.is_module_owned(module_id), "un achat refusé ne doit acquérir aucun module : %s" % module_id)
	_cleanup_test_storage(atomic_service)
	atomic_service.free()


func _test_performance_classes() -> void:
	var controller: RaceController = RaceControllerScript.new()
	var requested := {"core": "core_overdrive", "mobility": "mobility_sprint", "utility": "utility_scanner"}
	var stock: Dictionary = controller._loadout_for_class(requested, "tripod", "stock")
	var authored: Dictionary = DatabaseScript.get_chassis("tripod").get("default_loadout", {})
	_expect(stock == authored, "la classe Série doit imposer le loadout constructeur")
	_expect(controller._loadout_for_class(requested, "tripod", "tuned") == requested, "la classe Préparé doit accepter les modules homologués")
	var upgrades := {"biped": {"engine": 4, "servos": 4, "reactor": 4, "armor": 4}}
	var tuned_upgrades: Dictionary = controller._player_upgrades({"upgrades": upgrades}, "biped", "tuned")
	var unlimited_upgrades: Dictionary = controller._player_upgrades({"upgrades": upgrades}, "biped", "unlimited")
	var stock_upgrades: Dictionary = controller._player_upgrades({"upgrades": upgrades}, "biped", "stock")
	_expect(int(tuned_upgrades.get("engine", -1)) == 2, "la classe Préparé doit plafonner les améliorations à 2")
	_expect(int(unlimited_upgrades.get("engine", -1)) == 4, "la classe Prototype doit autoriser le niveau 4")
	_expect(int(stock_upgrades.get("engine", -1)) == 0, "la classe Série doit neutraliser les améliorations")
	controller._config = {"track_id": "canopy"}
	controller._track_length = 1200.0
	_expect(controller._hazard_at(250.0) == "mud", "le premier secteur de danger doit exposer la boue")
	_expect(controller._hazard_at(650.0) == "spores", "le second secteur de danger doit exposer les spores")
	for hazard_id: String in ["mud", "spores", "rain", "crosswind", "current", "pressure", "lava", "eruption"]:
		var racer: RacerState = _configured_racer("biped", "hazard_%s" % hazard_id)
		_expect(racer._hazard_drag(hazard_id) > 0.0, "danger sans effet physique : %s" % hazard_id)
	_expect(_configured_racer("tracked", "hazard_tracked")._hazard_drag("mud") < _configured_racer("biped", "hazard_biped")._hazard_drag("mud"), "les chenilles doivent mieux franchir la boue")
	controller.free()


func _test_mecha_visual_contract() -> void:
	var customization := {"core": "core_bastion", "mobility": "mobility_adaptive", "utility": "utility_scanner"}
	for chassis: Dictionary in DatabaseScript.CHASSIS:
		var visual: RacerVisual = MechaFactoryScript.build(chassis, Color(String(chassis.get("paint", "#5EE7FF"))), true, customization)
		_expect(visual.camera_anchor("tps") != null, "ancrage TPS absent : %s" % chassis.get("id", "?"))
		_expect(visual.camera_anchor("fps") != null, "ancrage cockpit absent : %s" % chassis.get("id", "?"))
		var cockpit_offset: Vector3 = chassis.get("cockpit_offset", Vector3(0, 2.65, 0.10))
		var dashboard := visual.get_node_or_null("CockpitDashboard") as Node3D
		var fps_anchor := visual.camera_anchor("fps")
		_expect(fps_anchor != null and fps_anchor.position.is_equal_approx(cockpit_offset + Vector3(0, 0, -1.12)), "ancrage FPS mal aligné : %s" % chassis.get("id", "?"))
		_expect(dashboard != null and dashboard.position.is_equal_approx(cockpit_offset + Vector3(0, -0.68, -2.05)), "intérieur cockpit mal aligné : %s" % chassis.get("id", "?"))
		_expect(visual.get_node_or_null("CockpitTopFrame") != null, "traverse cockpit absente : %s" % chassis.get("id", "?"))
		_expect(visual.get_node_or_null("ModuleCore_core_bastion") != null, "module noyau non visible : %s" % chassis.get("id", "?"))
		_expect(visual.get_node_or_null("ModuleMobility_mobility_adaptive") != null, "module mobilité non visible : %s" % chassis.get("id", "?"))
		_expect(visual.get_node_or_null("ModuleUtility_utility_scanner") != null, "module utilitaire non visible : %s" % chassis.get("id", "?"))
		visual.free()
		var authored_visual: RacerVisual = MechaFactoryScript.build(chassis, Color(String(chassis.get("paint", "#5EE7FF"))), false, {})
		_expect(Dictionary(authored_visual.get_meta("module_loadout", {})) == Dictionary(chassis.get("default_loadout", {})), "le visuel sans réglage doit utiliser le loadout constructeur : %s" % chassis.get("id", "?"))
		authored_visual.free()
	var reference_chassis: Dictionary = DatabaseScript.get_chassis("biped")
	var holder_prefix := {
		"core": "ModuleCore_",
		"mobility": "ModuleMobility_",
		"utility": "ModuleUtility_",
	}
	for slot: Dictionary in DatabaseScript.MODULE_SLOTS:
		var slot_id := String(slot.get("id", ""))
		for option_value: Variant in slot.get("options", []):
			if not option_value is Dictionary:
				continue
			var module_id := String(Dictionary(option_value).get("id", ""))
			var loadout: Dictionary = Dictionary(reference_chassis.get("default_loadout", {})).duplicate(true)
			loadout[slot_id] = module_id
			var module_visual: RacerVisual = MechaFactoryScript.build(reference_chassis, Color("#5EE7FF"), true, loadout)
			var holder := module_visual.get_node_or_null("%s%s" % [holder_prefix.get(slot_id, ""), module_id])
			_expect(holder != null and holder.get_child_count() > 0, "silhouette module vide : %s" % module_id)
			module_visual.free()


func _test_track_visual_contract() -> void:
	var sampled_profiles: Dictionary = {}
	for track_spec: Dictionary in DatabaseScript.TRACKS:
		var track: Node3D = TrackFactoryScript.build(track_spec)
		var track_id := String(track_spec.get("id", ""))
		var length := float(TrackFactoryScript.track_length(track))
		var quarter_pose: Transform3D = TrackFactoryScript.sample_pose(track, length * 0.25)
		var road := track.get_node_or_null("Road") as MeshInstance3D
		var road_material := road.material_override as StandardMaterial3D if road != null else null
		_expect(length > 300.0, "circuit 3D trop court : %s" % track_id)
		_expect(quarter_pose.origin.is_finite(), "échantillonnage non fini : %s" % track_id)
		_expect(road != null and road.mesh != null, "chaussée 3D absente : %s" % track_id)
		_expect(road_material != null and road_material.albedo_texture != null, "texture OpenAI non branchée sur la chaussée : %s" % track_id)
		_expect(track.get_node_or_null("Scenery") != null, "décor procédural absent : %s" % track_id)
		_expect(TrackFactoryScript.gameplay_markers(track).size() >= 8, "marqueurs gameplay insuffisants : %s" % track_id)
		sampled_profiles["%d:%d:%d" % [roundi(length), roundi(quarter_pose.origin.y * 10.0), roundi(quarter_pose.origin.x)]] = true
		track.free()
	_expect(sampled_profiles.size() >= 6, "les 8 circuits doivent produire des géométries réellement distinctes")


func _test_championship_migration_and_tamper_guard() -> void:
	var division_chassis := {"command": "biped", "stabilized": "tripod", "swarm": "hexapod", "ground": "tracked", "experimental": "hover"}
	for division_id: String in division_chassis:
		var service: SaveSystemService = SaveScript.new()
		var profile_v2: Dictionary = service._default_profile()
		profile_v2["version"] = 2
		profile_v2["selected_chassis"] = division_chassis[division_id]
		var session: GameSessionService = SessionScript.new()
		var entrants := session._build_roster(profile_v2, 8, division_id, "division", 51, "tuned")
		profile_v2["championship"] = {
			"active": true, "difficulty": "pilot", "round_index": 1,
			"tracks": ["foundry", "dunes", "glacier", "orbital"], "entrants": entrants,
		}
		var migrated: Dictionary = service._sanitize_profile(profile_v2)
		var migrated_cup: Dictionary = migrated.get("championship", {})
		_expect(String(migrated_cup.get("championship_id", "")) == "%s_cup" % division_id, "le GP v2 doit migrer vers la coupe %s" % division_id)
		_expect(String(migrated_cup.get("division_id", "")) == division_id, "la migration GP v2 doit conserver la division %s" % division_id)
		session.free()
		service.free()

	var guard_service: SaveSystemService = SaveScript.new()
	var guard_profile: Dictionary = guard_service._default_profile()
	guard_profile["version"] = 3
	var guard_session: GameSessionService = SessionScript.new()
	var command_roster := guard_session._build_roster(guard_profile, 8, "command", "division", 72, "tuned")
	guard_profile["championship"] = {
		"active": true, "championship_id": "command_cup", "difficulty": "pilot", "round_index": 0,
		"tracks": ["abyss"], "division_id": "ground", "ruleset_id": "elite_open", "grid_policy": "mixed",
		"mixed_divisions": true, "performance_class_id": "unlimited", "entrants": command_roster,
	}
	var migrated_v3: Dictionary = guard_service._sanitize_profile(guard_profile)
	var guarded: Dictionary = migrated_v3.get("championship", {})
	var command_definition := DatabaseScript.get_championship("command_cup")
	_expect(int(migrated_v3.get("version", 0)) == 4, "une sauvegarde v3 doit migrer vers SAVE_VERSION 4")
	_expect(guarded.get("tracks", []) == command_definition.get("track_ids", []), "une sauvegarde ne doit pas remplacer les circuits canoniques d'une coupe")
	_expect(String(guarded.get("division_id", "")) == "command" and String(guarded.get("ruleset_id", "")) == "division_locked", "une sauvegarde ne doit pas ouvrir une coupe dédiée")
	_expect(not bool(guarded.get("mixed_divisions", true)) and String(guarded.get("performance_class_id", "")) == "tuned", "une sauvegarde ne doit pas modifier la classe d'une coupe")
	guard_session.free()
	guard_service.free()


func _roster_divisions(config_data: Dictionary) -> Dictionary:
	var divisions: Dictionary = {}
	for entrant_value: Variant in config_data.get("roster", []):
		if entrant_value is Dictionary:
			divisions[String(Dictionary(entrant_value).get("division_id", ""))] = true
	return divisions


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
		"mode": "grand_prix", "difficulty": "pilot", "championship_id": "command_cup", "new_championship": true, "laps": 1,
	})
	_expect(String(first_config.get("track_id", "")) == "foundry", "le GP doit commencer à la Fonderie")
	_expect(String(first_config.get("championship_id", "")) == "command_cup", "l'identité de la Coupe Commandement doit être conservée")
	_expect(String(first_config.get("grid_policy", "")) == "division", "la Coupe Commandement doit rester dédiée")
	var original_roster: Array = first_config.get("roster", [])
	_expect(_roster_divisions(first_config).size() == 1 and _roster_divisions(first_config).has("command"), "la Coupe Commandement doit homologuer uniquement sa division")
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
	_expect(_roster_signature(Array(next_config.get("roster", []))) == _roster_signature(original_roster), "la grille homologuée doit rester stable entre les manches")
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


func _test_garage_preview_contract() -> void:
	var preview: Node = GaragePreviewScene.instantiate()
	_expect(preview.has_method("configure") and preview.has_method("preview_texture"), "API garage preview incomplète")
	root.add_child(preview)
	var viewport := preview.get_node_or_null("Stack/ViewportContainer/PreviewViewport") as SubViewport
	var anchor := preview.get_node_or_null("Stack/ViewportContainer/PreviewViewport/PreviewWorld/Turntable/MechaAnchor") as Node3D
	_expect(viewport != null, "SubViewport du garage preview absent")
	_expect(preview.find_children("*", "SubViewport", true, false).size() == 1, "le garage preview doit posséder exactement un SubViewport")
	_expect(anchor != null, "ancre mécha du garage preview absente")
	var chassis: Dictionary = DatabaseScript.get_chassis("biped")
	var loadout: Dictionary = chassis.get("default_loadout", {})
	preview.call("configure", chassis, "#5EE7FF", loadout)
	var configured_chassis: Dictionary = preview.get("_chassis")
	var configured_loadout: Dictionary = preview.get("_loadout")
	_expect(String(configured_chassis.get("id", "")) == "biped", "le garage preview doit conserver le vrai châssis MechaFactory avant sa frame ready")
	_expect(configured_loadout == loadout, "le garage preview doit conserver le loadout réel avant sa frame ready")
	preview.call("set_reduced_motion", true)
	_expect(bool(preview.get("reduced_motion")), "le garage preview doit respecter la réduction des mouvements")
	preview.free()


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


func _roster_signature(roster: Array) -> Array[String]:
	var output: Array[String] = []
	for entrant_value: Variant in roster:
		if not entrant_value is Dictionary:
			continue
		var entrant: Dictionary = entrant_value
		output.append("%s|%s|%s|%s|%s" % [
			entrant.get("id", ""), entrant.get("chassis_id", ""), entrant.get("division_id", ""),
			entrant.get("paint", ""), JSON.stringify(entrant.get("loadout", {})),
		])
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
