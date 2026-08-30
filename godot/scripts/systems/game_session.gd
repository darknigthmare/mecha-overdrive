class_name GameSessionService
extends Node
## Sanitizes race requests, commits results once, and owns Grand Prix state.

signal session_configured(config_data: Dictionary)
signal race_completed(result_data: Dictionary)
signal championship_changed(championship_data: Dictionary)

const MODES: Array[String] = ["quick", "time_trial", "elimination", "grand_prix"]
# Legacy wrapper for callers/tests. The authoritative list lives in
# GameDatabase.CHAMPIONSHIPS[command_cup].track_ids.
const GRAND_PRIX_TRACKS: Array[String] = ["foundry", "tempest", "glacier", "orbital"]
const MAX_RACERS := 8

var config: Dictionary = {}
var last_result: Dictionary = {}
var championship: Dictionary = {}
var _result_committed := false
var _pending_result: Dictionary = {}
var _pending_championship: Dictionary = {}
var _pending_championship_snapshot: Dictionary = {}
var _session_counter := 0
var _save_system_override: Node = null


func _ready() -> void:
	restore_championship()


func restore_championship() -> Dictionary:
	championship = {}
	var save_system := _save_system()
	if save_system == null or not save_system.has_method(&"get_championship"):
		return {}
	var restored: Variant = save_system.call(&"get_championship")
	if not restored is Dictionary:
		return {}
	var restored_data: Dictionary = restored
	var round_index := int(restored_data.get("round_index", -1))
	var entrants: Variant = restored_data.get("entrants", [])
	var tracks: Variant = restored_data.get("tracks", [])
	if not bool(restored_data.get("active", false)):
		return {}
	if not tracks is Array or Array(tracks).is_empty() or round_index < 0 or round_index >= Array(tracks).size():
		return {}
	if not entrants is Array or Array(entrants).size() != MAX_RACERS:
		return {}
	championship = restored_data.duplicate(true)
	championship_changed.emit(championship.duplicate(true))
	return championship.duplicate(true)


func configure(request: Dictionary) -> Dictionary:
	var mode := String(request.get("mode", "quick"))
	if not mode in MODES:
		mode = "quick"
	var difficulty := String(request.get("difficulty", "pilot"))
	if not GameDatabase.has_difficulty(difficulty):
		difficulty = "pilot"
	var track_id := String(request.get("track_id", "foundry"))
	if not GameDatabase.has_track(track_id):
		track_id = "foundry"

	var profile_data := _profile()
	var selected_chassis := String(profile_data.get("selected_chassis", "biped"))
	var category_chassis_id := String(request.get("category_chassis_id", selected_chassis))
	if not GameDatabase.has_chassis(category_chassis_id):
		category_chassis_id = selected_chassis
	var race_category := GameDatabase.get_race_category_for_chassis(category_chassis_id)
	var race_category_id := String(race_category.get("id", category_chassis_id))
	var player_division := _chassis_division(selected_chassis)
	var requested_division := String(request.get("division_id", player_division))
	var division_id := requested_division if not GameDatabase.get_division(requested_division).is_empty() else player_division
	var grid_policy := _sanitize_grid_policy(String(request.get("grid_policy", "division")))
	var ruleset_id := String(request.get("ruleset_id", "open_mixed" if grid_policy == "mixed" else "division_locked"))
	var ruleset := GameDatabase.get_ruleset(ruleset_id)
	var expects_mixed := grid_policy == "mixed"
	if ruleset.is_empty() or bool(ruleset.get("mixed_divisions", false)) != expects_mixed:
		ruleset_id = "open_mixed" if expects_mixed else "division_locked"
		ruleset = GameDatabase.get_ruleset(ruleset_id)
	var performance_class_id := String(request.get("performance_class_id", ruleset.get("performance_class_id", "tuned")))
	if GameDatabase.get_performance_class(performance_class_id).is_empty():
		performance_class_id = "tuned"

	if mode == "grand_prix":
		if bool(request.get("new_championship", false)) or championship.is_empty() or not bool(championship.get("active", false)):
			if not _start_championship(request, difficulty, profile_data):
				config = {}
				return {}
		var gp_tracks: Array = championship.get("tracks", GRAND_PRIX_TRACKS)
		if gp_tracks.is_empty():
			return {}
		difficulty = String(championship.get("difficulty", difficulty))
		track_id = String(gp_tracks[clampi(int(championship.get("round_index", 0)), 0, gp_tracks.size() - 1)])
		division_id = String(championship.get("division_id", division_id))
		category_chassis_id = String(championship.get("category_chassis_id", selected_chassis))
		race_category = GameDatabase.get_race_category_for_chassis(category_chassis_id)
		race_category_id = String(race_category.get("id", category_chassis_id))
		grid_policy = _sanitize_grid_policy(String(championship.get("grid_policy", "division")))
		ruleset_id = String(championship.get("ruleset_id", "division_locked"))
		ruleset = GameDatabase.get_ruleset(ruleset_id)
		performance_class_id = String(championship.get("performance_class_id", "tuned"))

	var track := GameDatabase.get_track(track_id)
	var laps := clampi(int(request.get("laps", track.get("default_laps", 3))), 1, 9)
	# Championship standings are homologated for eight stable entrants. A
	# request-level racer_count may never desynchronise the race from its table.
	var racer_count := 1 if mode == "time_trial" else (MAX_RACERS if mode == "grand_prix" else clampi(int(request.get("racer_count", MAX_RACERS)), 2, MAX_RACERS))
	_session_counter += 1
	var session_seed := int(request.get("seed", int(track.get("seed", 1)) + _session_counter * 97))
	var roster: Array = Array(championship.get("entrants", [])).duplicate(true) if mode == "grand_prix" else _build_roster(profile_data, racer_count, division_id, grid_policy, session_seed, performance_class_id, category_chassis_id)
	if mode == "time_trial" and roster.size() > 1:
		roster.resize(1)
	config = {
		"session_id": _session_counter,
		"mode": mode,
		"track_id": track_id,
		"difficulty": difficulty,
		"laps": laps,
		"racer_count": racer_count,
		"items_enabled": mode != "time_trial" and bool(ruleset.get("items_enabled", true)),
		"division_id": division_id,
		"race_category_id": race_category_id,
		"category_chassis_id": category_chassis_id,
		"grid_policy": grid_policy,
		"mixed_divisions": grid_policy == "mixed",
		"ruleset_id": ruleset_id,
		"performance_class_id": performance_class_id,
		"championship_id": String(championship.get("championship_id", "")) if mode == "grand_prix" else "",
		"cup_id": String(championship.get("championship_id", "")) if mode == "grand_prix" else "",
		"roster": roster,
		"camera_view": _camera_view(profile_data),
		"elimination_interval": clampf(float(request.get("elimination_interval", 32.0)), 15.0, 90.0) if mode == "elimination" else 0.0,
		"time_limit": clampf(float(request.get("time_limit", 900.0)), 60.0, 1800.0),
		"seed": session_seed,
	}
	_result_committed = false
	_clear_pending_persistence()
	last_result = {}
	session_configured.emit(config.duplicate(true))
	return config.duplicate(true)


func current_config() -> Dictionary:
	return config.duplicate(true)


func complete_race(raw_result: Dictionary) -> Dictionary:
	if _result_committed:
		return last_result.duplicate(true)
	if config.is_empty():
		configure({})

	var dnf := bool(raw_result.get("dnf", false))
	var eliminated := bool(raw_result.get("eliminated", false))
	var finished := bool(raw_result.get("finished", false)) and not dnf and not eliminated
	var elapsed := maxf(0.0, float(raw_result.get("elapsed", 0.0)))
	var position := clampi(int(raw_result.get("position", config.get("racer_count", MAX_RACERS))), 1, int(config.get("racer_count", MAX_RACERS)))
	var laps_completed := clampi(int(raw_result.get("laps_completed", 0)), 0, int(config.get("laps", 3)))
	var mode := String(config.get("mode", "quick"))
	var track_id := String(config.get("track_id", "foundry"))
	var track := GameDatabase.get_track(track_id)
	var racer_count := int(config.get("racer_count", MAX_RACERS))
	var save_system := _save_system()
	var result := {
		"session_id": int(config.get("session_id", 0)),
		"mode": mode,
		"track_id": track_id,
		"difficulty": String(config.get("difficulty", "pilot")),
		"track_name": String(track.get("name", track_id)),
		"racer_count": racer_count,
		"total_racers": racer_count,
		"finished": finished,
		"dnf": not finished,
		"eliminated": eliminated,
		"reason": String(raw_result.get("reason", "finished" if finished else "dnf")),
		"position": position,
		"elapsed": elapsed,
		"laps_completed": laps_completed,
		"reward": _calculate_reward(position, finished, elapsed),
		"record_valid": finished and elapsed > 0.0,
		"classification": _sanitize_classification(raw_result.get("classification", [])),
	}
	_apply_record_contract(result, save_system)

	var championship_snapshot := championship.duplicate(true)
	var championship_applied := true

	if mode == "grand_prix":
		championship_applied = _apply_championship_result(result)
		if championship_applied:
			var championship_result := _championship_result()
			result["championship"] = championship_result
			result["round"] = int(championship_result.get("round", 1))
			result["total_rounds"] = int(championship_result.get("total_rounds", _championship_tracks().size()))
			result["championship_standings"] = championship_result.get("standings", [])
			result["championship_complete"] = bool(championship_result.get("complete", false))
			result["can_continue"] = bool(championship_result.get("can_continue", false))

	if not championship_applied:
		championship = championship_snapshot
		_clear_pending_persistence()
		var invalid_result := _persistence_failure_result(result, false)
		invalid_result["save_error_message"] = "Le championnat n’est plus disponible. Retournez au paddock."
		_result_committed = false
		last_result = invalid_result.duplicate(true)
		return invalid_result.duplicate(true)

	var candidate_championship := championship.duplicate(true)
	var persistence_ok := false
	if save_system == null:
		# Detached sessions are intentionally in-memory for deterministic unit tests.
		persistence_ok = not is_inside_tree()
	elif save_system.has_method(&"record_race_result"):
		persistence_ok = bool(save_system.call(&"record_race_result", result.duplicate(true)))
	if not persistence_ok:
		_pending_result = result.duplicate(true)
		_pending_championship = candidate_championship
		_pending_championship_snapshot = championship_snapshot
		championship = championship_snapshot
		var failed_result := _persistence_failure_result(result, true)
		_result_committed = false
		last_result = failed_result.duplicate(true)
		return failed_result.duplicate(true)

	return _finalize_persisted_result(result)


func retry_result_persistence() -> Dictionary:
	if _result_committed:
		return last_result.duplicate(true)
	if _pending_result.is_empty():
		return last_result.duplicate(true)

	var save_system := _save_system()
	var persistence_ok := false
	if save_system == null:
		persistence_ok = not is_inside_tree()
	elif save_system.has_method(&"record_race_result"):
		persistence_ok = bool(save_system.call(&"record_race_result", _pending_result.duplicate(true)))
	if not persistence_ok:
		championship = _pending_championship_snapshot.duplicate(true)
		var failed_result := _persistence_failure_result(_pending_result, true)
		last_result = failed_result.duplicate(true)
		return failed_result.duplicate(true)

	championship = _pending_championship.duplicate(true)
	return _finalize_persisted_result(_pending_result.duplicate(true))


func has_pending_persistence() -> bool:
	return not _pending_result.is_empty() and not _result_committed


func _persistence_failure_result(candidate: Dictionary, retry_available: bool) -> Dictionary:
	var failure := candidate.duplicate(true)
	failure["persisted"] = false
	failure["save_failed"] = true
	failure["result_homologated"] = false
	failure["persistence_retry_available"] = retry_available
	failure["save_error_message"] = "Progression non enregistrée. Réessayez la sauvegarde avant de quitter."
	failure["reward"] = 0
	failure["new_record"] = false
	failure["record"] = false
	failure["best_time"] = float(failure.get("previous_record", 0.0))
	failure["record_time"] = failure["best_time"]
	if String(failure.get("mode", "quick")) == "grand_prix":
		var restored := _championship_result() if not championship.is_empty() else {}
		if not restored.is_empty():
			restored["complete"] = false
			restored["championship_complete"] = false
			restored["can_continue"] = false
			restored["champion_id"] = ""
		failure["championship"] = restored
		failure["round"] = int(restored.get("round", 0))
		failure["total_rounds"] = int(restored.get("total_rounds", 0))
		failure["championship_standings"] = restored.get("standings", [])
		failure["championship_complete"] = false
		failure["championship_won"] = false
		failure["championship_points"] = 0
		failure["points"] = 0
		failure["can_continue"] = false
	return failure


func _finalize_persisted_result(candidate: Dictionary) -> Dictionary:
	var result := candidate.duplicate(true)
	result["persisted"] = true
	result["save_failed"] = false
	result["result_homologated"] = true
	result["persistence_retry_available"] = false
	_result_committed = true
	last_result = result.duplicate(true)
	_clear_pending_persistence()
	if String(result.get("mode", "quick")) == "grand_prix":
		championship_changed.emit(championship.duplicate(true))
	race_completed.emit(result.duplicate(true))
	return result.duplicate(true)


func _clear_pending_persistence() -> void:
	_pending_result = {}
	_pending_championship = {}
	_pending_championship_snapshot = {}


func abort_race(reason: String = "abandoned") -> Dictionary:
	return complete_race({
		"finished": false,
		"dnf": true,
		"reason": reason,
		"position": int(config.get("racer_count", MAX_RACERS)),
		"elapsed": 0.0,
		"laps_completed": 0,
	})


func start_next_championship_round() -> Dictionary:
	if championship.is_empty() or not bool(championship.get("active", false)):
		return {}
	return configure({
		"mode": "grand_prix",
		"difficulty": String(championship.get("difficulty", "pilot")),
		"championship_id": String(championship.get("championship_id", "command_cup")),
		"new_championship": false,
	})


func start_next_grand_prix_round() -> Dictionary:
	# Compatibility wrapper for v2 callers.
	return start_next_championship_round()


func abandon_championship() -> bool:
	if championship.is_empty():
		return true
	var snapshot := championship.duplicate(true)
	championship["active"] = false
	championship["abandoned"] = true
	if not _persist_championship():
		championship = snapshot
		return false
	championship_changed.emit(championship.duplicate(true))
	return true


func _start_championship(request: Dictionary, difficulty: String, profile_data: Dictionary = {}) -> bool:
	if profile_data.is_empty():
		profile_data = _profile()
	var championship_id := String(request.get("championship_id", request.get("cup_id", "command_cup")))
	var definition := GameDatabase.get_championship(championship_id)
	if definition.is_empty():
		championship_id = "command_cup"
		definition = GameDatabase.get_championship(championship_id)
	var stats_value: Variant = profile_data.get("stats", {})
	var profile_stats: Dictionary = stats_value if stats_value is Dictionary else {}
	var access := GameDatabase.championship_access(championship_id, profile_stats, {})
	if not bool(access.get("available", false)):
		return false

	var tracks: Array = Array(definition.get("track_ids", GRAND_PRIX_TRACKS)).duplicate()
	var mixed_divisions := bool(definition.get("mixed_divisions", false))
	var grid_policy := "mixed" if mixed_divisions else "division"
	var division_id := String(definition.get("division_id", ""))
	var category_chassis_id := String(definition.get("category_chassis_id", profile_data.get("selected_chassis", "biped")))
	if not GameDatabase.has_chassis(category_chassis_id):
		category_chassis_id = String(profile_data.get("selected_chassis", "biped"))
	if division_id.is_empty():
		division_id = _chassis_division(String(profile_data.get("selected_chassis", "biped")))
	var ruleset_id := String(definition.get("ruleset_id", "open_mixed" if mixed_divisions else "division_locked"))
	var performance_class_id := String(definition.get("performance_class_id", "tuned"))
	var roster_seed := int(request.get("seed", championship_id.hash()))
	var entrants := _build_roster(profile_data, MAX_RACERS, division_id, grid_policy, roster_seed, performance_class_id, category_chassis_id)
	for entrant_index in range(entrants.size()):
		var entrant: Dictionary = entrants[entrant_index]
		entrant["points"] = 0
		entrants[entrant_index] = entrant
	var championship_snapshot := championship.duplicate(true)
	championship = {
		"active": true,
		"abandoned": false,
		"championship_id": championship_id,
		"cup_id": championship_id,
		"name": String(definition.get("name", championship_id)),
		"difficulty": difficulty,
		"division_id": division_id,
		"race_category_id": String(GameDatabase.get_race_category_for_chassis(category_chassis_id).get("id", category_chassis_id)),
		"category_chassis_id": category_chassis_id,
		"ruleset_id": ruleset_id,
		"grid_policy": grid_policy,
		"mixed_divisions": mixed_divisions,
		"performance_class_id": performance_class_id,
		"round_index": 0,
		"tracks": tracks,
		"completed_tracks": [],
		"entrants": entrants,
		"champion_id": "",
	}
	if not _persist_championship():
		championship = championship_snapshot
		return false
	championship_changed.emit(championship.duplicate(true))

	return true

func _apply_championship_result(result: Dictionary) -> bool:
	if championship.is_empty():
		if not _start_championship(config, String(config.get("difficulty", "pilot"))):
			return false
	var entrants: Array = championship.get("entrants", [])
	var classification: Array = result.get("classification", [])
	if classification.is_empty():
		classification = _fallback_classification(int(result.get("position", MAX_RACERS)))
	var awarded: Dictionary = {}
	var player_points := 0
	result["championship_won"] = false
	var points_rank := 0
	for rank in range(classification.size()):
		var entry: Dictionary = classification[rank]
		if bool(entry.get("dnf", false)) or bool(entry.get("eliminated", false)):
			continue
		var racer_id := String(entry.get("racer_id", ""))
		if racer_id.is_empty() or awarded.has(racer_id):
			continue
		awarded[racer_id] = true
		var points := GameDatabase.CHAMPIONSHIP_POINTS[points_rank] if points_rank < GameDatabase.CHAMPIONSHIP_POINTS.size() else 0
		points_rank += 1
		if racer_id == "player":
			player_points = points
		for entrant_index in range(entrants.size()):
			var entrant: Dictionary = entrants[entrant_index]
			if String(entrant.get("id", "")) == racer_id:
				entrant["points"] = maxi(0, int(entrant.get("points", 0))) + points
				entrants[entrant_index] = entrant
				break

	championship["entrants"] = entrants
	result["points"] = player_points
	result["championship_points"] = player_points
	var completed_tracks: Array = championship.get("completed_tracks", [])
	completed_tracks.append(String(config.get("track_id", "foundry")))
	championship["completed_tracks"] = completed_tracks
	championship["round_index"] = int(championship.get("round_index", 0)) + 1
	if int(championship["round_index"]) >= _championship_tracks().size():
		championship["active"] = false
		var sorted_entrants := entrants.duplicate(true)
		sorted_entrants.sort_custom(Callable(self, "_championship_entry_precedes"))
		var champion_id := ""
		if not sorted_entrants.is_empty():
			var champion: Dictionary = sorted_entrants[0]
			champion_id = String(champion.get("id", ""))
		championship["champion_id"] = champion_id
		result["championship_won"] = champion_id == "player"
	return true


func _apply_record_contract(result: Dictionary, save_system: Node) -> void:
	var record_valid := bool(result.get("record_valid", false))
	var elapsed := float(result.get("elapsed", 0.0))
	var track_id := String(result.get("track_id", ""))
	var mode := String(result.get("mode", "quick"))
	var previous_record := 0.0
	if save_system != null:
		var profile_value: Variant = save_system.get("profile")
		if profile_value is Dictionary:
			var profile_data: Dictionary = profile_value
			var records_value: Variant = profile_data.get("records", {})
			if records_value is Dictionary:
				var records: Dictionary = records_value
				var track_records_value: Variant = records.get(track_id, {})
				if track_records_value is Dictionary:
					var track_records: Dictionary = track_records_value
					previous_record = maxf(0.0, float(track_records.get(mode, 0.0)))

	var new_record := record_valid and elapsed > 0.0 and (previous_record <= 0.0 or elapsed < previous_record)
	var best_time := elapsed if new_record else previous_record
	result["previous_record"] = previous_record
	result["new_record"] = new_record
	result["record"] = new_record
	result["best_time"] = best_time
	result["record_time"] = best_time


func _championship_result() -> Dictionary:
	var output := championship.duplicate(true)
	var total_rounds := _championship_tracks().size()
	var completed_rounds := clampi(int(championship.get("round_index", 0)), 0, total_rounds)
	var complete := completed_rounds >= total_rounds and not bool(championship.get("active", false)) and not bool(championship.get("abandoned", false))
	var entrants: Array = championship.get("entrants", [])
	var sorted_entrants := entrants.duplicate(true)
	sorted_entrants.sort_custom(Callable(self, "_championship_entry_precedes"))
	var standings: Array[Dictionary] = []
	for index in range(sorted_entrants.size()):
		var entrant: Dictionary = sorted_entrants[index]
		var entrant_id := String(entrant.get("id", ""))
		var entrant_name := String(entrant.get("name", "PILOTE"))
		standings.append({
			"racer_id": entrant_id,
			"id": entrant_id,
			"pilot": entrant_name,
			"name": entrant_name,
			"points": maxi(0, int(entrant.get("points", 0))),
			"position": index + 1,
			"player": entrant_id == "player",
		})
	output["round"] = clampi(completed_rounds, 1, total_rounds)
	output["total_rounds"] = total_rounds
	output["standings"] = standings
	output["complete"] = complete
	output["championship_complete"] = complete
	output["can_continue"] = bool(championship.get("active", false)) and completed_rounds < total_rounds
	return output


func _championship_tracks() -> Array:
	var tracks: Variant = championship.get("tracks", GRAND_PRIX_TRACKS)
	return tracks if tracks is Array and not Array(tracks).is_empty() else GRAND_PRIX_TRACKS


func _profile() -> Dictionary:
	var save_system := _save_system()
	if save_system != null:
		var profile_value: Variant = save_system.get("profile")
		if profile_value is Dictionary:
			return Dictionary(profile_value).duplicate(true)
	return {"selected_chassis": "biped", "pilot_name": "PILOTE 01", "paints": {}, "loadouts": {}, "settings": {"camera_view": "tps"}}


func _camera_view(profile_data: Dictionary) -> String:
	var settings: Dictionary = profile_data.get("settings", {}) if profile_data.get("settings", {}) is Dictionary else {}
	var value := String(settings.get("camera_view", "tps"))
	return value if value in ["tps", "fps"] else "tps"


func _sanitize_grid_policy(value: String) -> String:
	# Mixed divisions are never inferred from malformed input.
	return "mixed" if value == "mixed" else "division"


func _chassis_division(chassis_id: String) -> String:
	var division_id := String(GameDatabase.get_chassis(chassis_id).get("division_id", "command"))
	return division_id if not GameDatabase.get_division(division_id).is_empty() else "command"


func _build_roster(profile_data: Dictionary, racer_count: int, division_id: String, grid_policy: String, seed_value: int, performance_class_id: String = "tuned", category_chassis_id: String = "") -> Array[Dictionary]:
	var all_chassis := GameDatabase.get_all_chassis()
	var selected_id := String(profile_data.get("selected_chassis", "biped"))
	if category_chassis_id.is_empty() or not GameDatabase.has_chassis(category_chassis_id):
		category_chassis_id = selected_id
	var pool: Array[Dictionary] = []
	if grid_policy == "mixed":
		pool.assign(all_chassis)
	else:
		pool.append(GameDatabase.get_chassis(category_chassis_id))
	if pool.is_empty():
		pool = [GameDatabase.get_chassis("biped")]
	if grid_policy == "division" and selected_id != category_chassis_id:
		selected_id = category_chassis_id
	var paints: Dictionary = profile_data.get("paints", {}) if profile_data.get("paints", {}) is Dictionary else {}
	var loadouts: Dictionary = profile_data.get("loadouts", {}) if profile_data.get("loadouts", {}) is Dictionary else {}
	var pilots := GameDatabase.get_all_pilots()
	var roster: Array[Dictionary] = []
	for index in range(clampi(racer_count, 1, MAX_RACERS)):
		var is_player := index == 0
		var chassis: Dictionary = GameDatabase.get_chassis(selected_id) if is_player else pool[(index + abs(seed_value)) % pool.size()]
		var chassis_id := String(chassis.get("id", "biped"))
		var category := GameDatabase.get_race_category_for_chassis(chassis_id)
		var locomotion_id := _roster_locomotion(profile_data, chassis, is_player, index + abs(seed_value), performance_class_id)
		var pilot: Dictionary = pilots[(index - 1 + abs(seed_value)) % pilots.size()] if not is_player else {}
		var racer_id := "player" if is_player else String(pilot.get("id", "rival_%02d" % index))
		var loadout := _sanitize_loadout(loadouts.get(chassis_id, {}), chassis_id, performance_class_id) if is_player else _variant_loadout(index + abs(seed_value), chassis_id, performance_class_id)
		var paint := String(paints.get(chassis_id, chassis.get("paint", "#5EE7FF"))) if is_player else String(pilot.get("paint", chassis.get("paint", "#5EE7FF")))
		if not Color.html_is_valid(paint):
			paint = String(chassis.get("paint", "#5EE7FF"))
		roster.append({
			"id": racer_id, "racer_id": racer_id,
			"name": String(profile_data.get("pilot_name", "PILOTE 01")) if is_player else String(pilot.get("callsign", pilot.get("name", "RIVAL"))),
			"pilot_id": "player" if is_player else String(pilot.get("id", racer_id)),
			"chassis_id": chassis_id,
			"division_id": _chassis_division(chassis_id),
			"race_category_id": String(category.get("id", chassis_id)),
			"locomotion_id": locomotion_id,
			"paint": Color(paint).to_html(false).to_upper(),
			"loadout": loadout,
			"module_variant": String(loadout.get("core", "core_balanced")),
			"points": 0,
		})
	return roster


func _roster_locomotion(profile_data: Dictionary, chassis: Dictionary, is_player: bool, variant_seed: int, performance_class_id: String) -> String:
	var chassis_id := String(chassis.get("id", "biped"))
	if is_player:
		var locomotions: Dictionary = profile_data.get("locomotions", {}) if profile_data.get("locomotions", {}) is Dictionary else {}
		return String(locomotions.get(chassis_id, LocomotionCatalog.get_default_configuration_id(chassis_id)))
	var configurations := LocomotionCatalog.get_configurations_for_chassis(chassis_id)
	var performance_class := GameDatabase.get_performance_class(performance_class_id)
	var allowed: Array[Dictionary] = []
	for configuration: Dictionary in configurations:
		if LocomotionCatalog.is_configuration_allowed_for_class(configuration, performance_class):
			allowed.append(configuration)
	if allowed.is_empty():
		return LocomotionCatalog.get_default_configuration_id(chassis_id)
	return String(allowed[posmod(variant_seed, allowed.size())].get("id", LocomotionCatalog.get_default_configuration_id(chassis_id)))


func _default_loadout(chassis_id: String = "") -> Dictionary:
	var output: Dictionary = {}
	var chassis := GameDatabase.get_chassis(chassis_id)
	var authored: Dictionary = chassis.get("default_loadout", {}) if chassis.get("default_loadout", {}) is Dictionary else {}
	for slot: Dictionary in GameDatabase.MODULE_SLOTS:
		var slot_id := String(slot.get("id", ""))
		var option_id := String(authored.get(slot_id, slot.get("default_option_id", "")))
		if not slot_id.is_empty() and not GameDatabase.get_module_option(slot_id, option_id).is_empty():
			output[slot_id] = option_id
	return output


func _sanitize_loadout(value: Variant, chassis_id: String = "", performance_class_id: String = "tuned") -> Dictionary:
	var performance_class := GameDatabase.get_performance_class(performance_class_id)
	var output := _default_loadout(chassis_id)
	if String(performance_class.get("module_policy", "all")) == "defaults_only":
		return output
	var source: Dictionary = value if value is Dictionary else {}
	var division_id := String(GameDatabase.get_chassis(chassis_id).get("division_id", ""))
	var max_tier := int(performance_class.get("max_module_tier", 1))
	for slot_id: String in output.keys():
		var option_id := String(source.get(slot_id, output[slot_id]))
		var option := GameDatabase.get_module_option(slot_id, option_id)
		if not option.is_empty() and int(option.get("tier", 0)) <= max_tier and GameDatabase.is_module_allowed_for_division(option_id, division_id):
			output[slot_id] = option_id
	return output


func _variant_loadout(variant_index: int, chassis_id: String = "", performance_class_id: String = "tuned") -> Dictionary:
	var performance_class := GameDatabase.get_performance_class(performance_class_id)
	if String(performance_class.get("module_policy", "all")) == "defaults_only":
		return _default_loadout(chassis_id)
	var output: Dictionary = {}
	var division_id := String(GameDatabase.get_chassis(chassis_id).get("division_id", ""))
	var max_tier := int(performance_class.get("max_module_tier", 1))
	var slot_index := 0
	for slot: Dictionary in GameDatabase.MODULE_SLOTS:
		var candidates: Array[Dictionary] = []
		for option: Dictionary in slot.get("options", []):
			var module_id := String(option.get("id", ""))
			if int(option.get("tier", 0)) <= max_tier and GameDatabase.is_module_allowed_for_division(module_id, division_id):
				candidates.append(option)
		if not candidates.is_empty():
			var selected_index := posmod(variant_index + slot_index * 2, candidates.size())
			output[String(slot.get("id", ""))] = String(candidates[selected_index].get("id", slot.get("default_option_id", "")))
		slot_index += 1
	return output


func _championship_entry_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_points := int(a.get("points", 0))
	var b_points := int(b.get("points", 0))
	if a_points == b_points:
		return String(a.get("id", "")) < String(b.get("id", ""))
	return a_points > b_points


func _persist_championship() -> bool:
	var save_system := _save_system()
	if save_system == null:
		return not is_inside_tree()
	if bool(championship.get("active", false)):
		if not save_system.has_method(&"save_championship"):
			return false
		return bool(save_system.call(&"save_championship", championship.duplicate(true)))
	if not save_system.has_method(&"clear_championship"):
		return false
	return bool(save_system.call(&"clear_championship"))


func _save_system() -> Node:
	if _save_system_override != null and is_instance_valid(_save_system_override):
		return _save_system_override
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/SaveSystem")


func _fallback_classification(player_position: int) -> Array[Dictionary]:
	var ai_ids: Array[String] = []
	for entrant: Dictionary in championship.get("entrants", []):
		var entrant_id := String(entrant.get("id", ""))
		if entrant_id != "player":
			ai_ids.append(entrant_id)
	var output: Array[Dictionary] = []
	var ai_index := 0
	for rank in range(MAX_RACERS):
		if rank == clampi(player_position - 1, 0, MAX_RACERS - 1):
			output.append({"racer_id": "player", "position": rank + 1})
		elif ai_index < ai_ids.size():
			output.append({"racer_id": ai_ids[ai_index], "position": rank + 1})
			ai_index += 1
	return output


func _sanitize_classification(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not value is Array:
		return output
	var seen: Dictionary = {}
	for raw_entry: Variant in value:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var racer_id := String(entry.get("racer_id", entry.get("id", "")))
		if racer_id.is_empty() or seen.has(racer_id):
			continue
		seen[racer_id] = true
		var display_name := String(entry.get("display_name", entry.get("name", entry.get("pilot", racer_id))))
		var finish_time := maxf(0.0, float(entry.get("finish_time", 0.0)))
		if finish_time <= 0.0:
			finish_time = maxf(0.0, float(entry.get("elapsed", 0.0)))
		var delta_text := String(entry.get("delta", entry.get("gap", "")))
		output.append({
			"racer_id": racer_id,
			"name": display_name,
			"pilot": display_name,
			"player": racer_id == "player" or bool(entry.get("player", false)),
			"chassis_id": String(entry.get("chassis_id", "")),
			"division_id": String(entry.get("division_id", "")),
			"delta": delta_text,
			"gap": delta_text,
			"position": output.size() + 1,
			"elapsed": finish_time,
			"finish_time": finish_time,
			"finished": bool(entry.get("finished", false)),
			"classified": bool(entry.get("classified", entry.get("finished", false))),
			"dnf": bool(entry.get("dnf", entry.get("did_not_finish", false))),
			"eliminated": bool(entry.get("eliminated", false)),
		})
	return output


func _calculate_reward(position: int, finished: bool, elapsed: float) -> int:
	if not finished or elapsed <= 0.0:
		return 0
	var base_by_position: Array[int] = [950, 720, 560, 430, 340, 270, 210, 160]
	var base := base_by_position[clampi(position - 1, 0, base_by_position.size() - 1)]
	var difficulty := GameDatabase.get_difficulty(String(config.get("difficulty", "pilot")))
	var multiplier := float(difficulty.get("reward", 1.0))
	if String(config.get("mode", "quick")) == "time_trial":
		var track := GameDatabase.get_track(String(config.get("track_id", "foundry")))
		var par_total := float(track.get("par_time", 80.0)) * int(config.get("laps", 3))
		base = 700 + (250 if elapsed <= par_total else 0)
	elif String(config.get("mode", "quick")) == "grand_prix":
		base += 180
	return roundi(base * multiplier)
