extends SceneTree
## Headless smoke test: godot --headless --path godot --script res://tests/smoke_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const SaveScript = preload("res://scripts/systems/save_system.gd")
const SessionScript = preload("res://scripts/systems/game_session.gd")
const RacerScript = preload("res://scripts/race/racer_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_database()
	_test_profile_contract()
	_test_session_modes()
	_test_deterministic_racer()
	if _failures.is_empty():
		print("MECHA GODOT SMOKE: PASS (catalogue, save, modes, deterministic racer)")
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
		for key in ["sky", "ground", "road", "shoulder", "glow", "accent", "key"]:
			_expect(palette.has(key), "palette %s incomplète : %s" % [track.get("id", "?"), key])


func _test_profile_contract() -> void:
	var service = SaveScript.new()
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
		var service = SessionScript.new()
		var configured: Dictionary = service.configure({"mode": mode, "track_id": "foundry", "difficulty": "pilot"})
		_expect(String(configured.get("mode", "")) == mode, "mode non configurable : %s" % mode)
		_expect(int(configured.get("racer_count", 0)) == (1 if mode == "time_trial" else 8), "grille incorrecte : %s" % mode)
		service.free()


func _test_deterministic_racer() -> void:
	var spec := {
		"racer_id": "test", "display_name": "TEST", "chassis_id": "biped",
		"difficulty": "pilot", "track_length": 400.0, "total_laps": 1, "seed": 441,
	}
	var first = RacerScript.new().configure(spec)
	var second = RacerScript.new().configure(spec)
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
