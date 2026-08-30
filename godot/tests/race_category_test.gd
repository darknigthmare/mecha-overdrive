extends SceneTree
## Category-contract regression suite.
## Run with: godot --headless --path godot --script res://tests/race_category_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const CatalogScript = preload("res://scripts/data/locomotion_catalog.gd")
const RacerScript = preload("res://scripts/race/racer_state.gd")
const RaceControllerScript = preload("res://scripts/race/race_controller.gd")
const SessionScript = preload("res://scripts/systems/game_session.gd")

const EXPECTED_CATEGORIES := {
	"pod": "tracked",
	"cycle": "monowheel",
	"roll": "orb",
	"biped": "biped",
	"tripod": "tripod",
	"quadruped": "quadruped",
	"hexapod": "hexapod",
	"octopod": "octopod",
	"hover": "hover",
	"land_speeder": "centurion",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_category_catalog()
	_test_distinct_motion_profiles()
	_test_category_locked_rosters()
	_test_dedicated_runtime_fallback()
	_test_category_championships()
	if _failures.is_empty():
		print("MECHA RACE CATEGORIES: PASS (10 distinct handling models, 10 locked cups, 1 explicit Open, 500 modular configurations)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA RACE CATEGORIES: %s" % failure)
	quit(1)


func _test_category_catalog() -> void:
	var categories := DatabaseScript.get_all_race_categories()
	_expect(categories.size() == 10, "exactement dix catégories de course sont requises")
	var seen_chassis: Dictionary = {}
	var seen_motion: Dictionary = {}
	for category: Dictionary in categories:
		var category_id := String(category.get("id", ""))
		var chassis_id := String(category.get("chassis_id", ""))
		_expect(EXPECTED_CATEGORIES.get(category_id, "") == chassis_id, "mapping catégorie/châssis invalide: %s -> %s" % [category_id, chassis_id])
		_expect(not DatabaseScript.get_chassis(chassis_id).is_empty(), "châssis de catégorie absent: %s" % category_id)
		_expect(not seen_chassis.has(chassis_id), "un châssis ne peut appartenir à deux catégories: %s" % chassis_id)
		seen_chassis[chassis_id] = true
		var motion: Dictionary = category.get("motion", {}) if category.get("motion", {}) is Dictionary else {}
		var signature := "%.2f|%.2f|%.2f|%.2f|%.2f" % [
			float(motion.get("throttle_response", 0.0)),
			float(motion.get("steer_response", 0.0)),
			float(motion.get("high_speed_steer", 0.0)),
			float(motion.get("drift_grip", 0.0)),
			float(motion.get("brake_factor", 0.0)),
		]
		_expect(not seen_motion.has(signature), "deux catégories partagent le même modèle de conduite: %s" % signature)
		seen_motion[signature] = true
		_expect(CatalogScript.get_configurations_for_chassis(chassis_id).size() == 50, "cinquante variantes modulaires requises: %s" % category_id)
	_expect(seen_chassis.size() == 10 and CatalogScript.get_total_configuration_count() == 500, "les dix catégories doivent conserver les 500 variantes")
	_expect(CatalogScript.get_default_configuration_id("tracked").contains("__twin_antigrav__"), "le Pod doit sortir d'usine avec deux nacelles")
	_expect(CatalogScript.get_default_configuration_id("monowheel").contains("__mono_gyro__"), "le Cycle doit sortir d'usine en montage gyro")
	_expect(CatalogScript.get_default_configuration_id("orb").contains("__sphere_drive__"), "le Rouleur doit sortir d'usine en sphère")
	_expect(CatalogScript.get_default_configuration_id("centurion").contains("__hover_skids__"), "le Land Speeder doit sortir d'usine en effet de sol")


func _test_distinct_motion_profiles() -> void:
	var states: Dictionary = {}
	var controls := {"throttle": 1.0, "brake": 0.0, "steer": 0.72, "drift": false, "boost": false}
	for category_id: String in EXPECTED_CATEGORIES:
		var chassis_id := String(EXPECTED_CATEGORIES[category_id])
		var racer: RacerState = RacerScript.new().configure({
			"racer_id": category_id,
			"chassis_id": chassis_id,
			"track_length": 2000.0,
			"track_width": 42.0,
			"total_laps": 1,
		})
		for tick in range(240):
			racer.step(1.0 / 120.0, controls, {"elapsed": float(tick) / 120.0, "race_active": true, "grip": 1.0, "curvature": 0.0, "speed_multiplier": 1.0})
		states[category_id] = racer.snapshot()
		_expect(String(racer.snapshot().get("race_category_id", "")) == category_id, "catégorie absente du snapshot: %s" % category_id)
	_expect(float(Dictionary(states["pod"]).get("speed", 0.0)) > float(Dictionary(states["biped"]).get("speed", 0.0)) * 1.8, "le Pod doit accélérer nettement plus fort que le bipède lourd")
	_expect(absf(float(Dictionary(states["cycle"]).get("lane", 0.0))) > absf(float(Dictionary(states["tripod"]).get("lane", 0.0))), "le Cycle doit changer de voie plus vite que le Tripode")
	_expect(float(Dictionary(states["biped"]).get("speed", 0.0)) < float(Dictionary(states["quadruped"]).get("speed", 0.0)), "le bipède lourd doit conserver une allure plus lente que le quadrupède")


func _test_category_locked_rosters() -> void:
	var session: GameSessionService = SessionScript.new()
	var profile_stub := _ProfileStub.new()
	session._save_system_override = profile_stub
	for category_id: String in EXPECTED_CATEGORIES:
		var chassis_id := String(EXPECTED_CATEGORIES[category_id])
		profile_stub.profile["selected_chassis"] = chassis_id
		var dedicated := session.configure({"mode": "quick", "grid_policy": "division", "seed": category_id.hash()})
		var chassis_seen: Dictionary = {}
		var locomotions_seen: Dictionary = {}
		for entrant_value: Variant in dedicated.get("roster", []):
			if entrant_value is Dictionary:
				var entrant: Dictionary = entrant_value
				chassis_seen[String(entrant.get("chassis_id", ""))] = true
				locomotions_seen[String(entrant.get("locomotion_id", ""))] = true
				_expect(String(entrant.get("race_category_id", "")) == category_id, "entrant mal catégorisé: %s" % category_id)
		_expect(chassis_seen.size() == 1 and chassis_seen.has(chassis_id), "la grille dédiée doit rester 100 %% %s" % category_id)
		_expect(locomotions_seen.size() >= 4, "les IA d'une catégorie doivent exposer plusieurs montages: %s" % category_id)
	profile_stub.profile["selected_chassis"] = "biped"
	var open := session.configure({"mode": "quick", "grid_policy": "mixed", "ruleset_id": "open_mixed", "seed": 8127})
	var open_categories: Dictionary = {}
	for entrant_value: Variant in open.get("roster", []):
		if entrant_value is Dictionary:
			open_categories[String(Dictionary(entrant_value).get("race_category_id", ""))] = true
	_expect(open_categories.size() >= 6, "l'Open explicite doit réellement mélanger les catégories")
	session.free()
	profile_stub.free()


func _test_dedicated_runtime_fallback() -> void:
	var save := root.get_node_or_null("SaveSystem")
	var profile: Dictionary = {}
	if save != null:
		var profile_value: Variant = save.get("profile")
		if profile_value is Dictionary:
			profile = Dictionary(profile_value)
	var selected_id := String(profile.get("selected_chassis", "biped"))
	var category_chassis_id := "tracked" if selected_id != "tracked" else "biped"
	var category := DatabaseScript.get_race_category_for_chassis(category_chassis_id)
	var category_chassis := DatabaseScript.get_chassis(category_chassis_id)
	var controller: RaceController = RaceControllerScript.new()
	root.add_child(controller)
	controller.set("_config", {
		"grid_policy": "division",
		"category_chassis_id": category_chassis_id,
		"division_id": String(category_chassis.get("division_id", "command")),
		"performance_class_id": "tuned",
		"racer_count": 3,
		"track_id": "foundry",
		"laps": 1,
		"roster": [
			{"id": "player", "is_player": true, "chassis_id": "invalid_player_chassis"},
			{"id": "altered_rival", "chassis_id": selected_id},
		],
	})
	controller.call("_build_racers")
	var racers_value: Variant = controller.get("_racers")
	var racers: Array = racers_value if racers_value is Array else []
	_expect(racers.size() == 3, "le runtime doit compléter un roster dédié incomplet")
	for racer_value: Variant in racers:
		if racer_value is RefCounted:
			var racer_ref: RefCounted = racer_value as RefCounted
			var snapshot: Dictionary = racer_ref.call("snapshot")
			_expect(String(snapshot.get("chassis_id", "")) == category_chassis_id, "un fallback runtime a quitté la catégorie dédiée")
			_expect(String(snapshot.get("race_category_id", "")) == String(category.get("id", "")), "un fallback runtime annonce une mauvaise catégorie")
	controller.free()


func _test_category_championships() -> void:
	_expect(DatabaseScript.CHAMPIONSHIPS.size() == 11, "dix coupes dédiées et un Grand Open sont requis")
	var dedicated_categories: Dictionary = {}
	var open_count := 0
	for cup: Dictionary in DatabaseScript.CHAMPIONSHIPS:
		if bool(cup.get("mixed_divisions", false)):
			open_count += 1
			_expect(String(cup.get("id", "")) == "nexus_open", "seul le Grand Open peut mélanger les catégories")
			var open_tracks: Array = cup.get("track_ids", [])
			_expect(open_tracks.size() == 8 and String(open_tracks.back()) == "caldera", "Circuit Zero doit conclure exclusivement le Grand Open")
			continue
		_expect(not Array(cup.get("track_ids", [])).has("caldera"), "Circuit Zero ne doit apparaître dans aucune Coupe dédiée: %s" % cup.get("id", "?"))
		var chassis_id := String(cup.get("category_chassis_id", ""))
		var category := DatabaseScript.get_race_category_for_chassis(chassis_id)
		var category_id := String(category.get("id", ""))
		_expect(not category_id.is_empty(), "coupe sans catégorie valide: %s" % cup)
		_expect(not dedicated_categories.has(category_id), "deux coupes dédiées pour la même catégorie: %s" % category_id)
		dedicated_categories[category_id] = true
	_expect(dedicated_categories.size() == 10 and open_count == 1, "chaque catégorie doit avoir exactement une coupe")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class _ProfileStub:
	extends Node
	var profile := {
		"selected_chassis": "biped",
		"pilot_name": "PILOTE TEST",
		"paints": {},
		"loadouts": {},
		"locomotions": {},
		"settings": {"camera_view": "tps"},
	}

	func get_profile() -> Dictionary:
		return profile.duplicate(true)

	func get_championship() -> Dictionary:
		return {}

	func save_championship(_value: Dictionary) -> bool:
		return true
