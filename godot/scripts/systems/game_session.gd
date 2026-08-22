class_name GameSessionService
extends Node
## Sanitizes race requests, commits results once, and owns Grand Prix state.

signal session_configured(config_data: Dictionary)
signal race_completed(result_data: Dictionary)
signal championship_changed(championship_data: Dictionary)

const MODES: Array[String] = ["quick", "time_trial", "elimination", "grand_prix"]
const GRAND_PRIX_TRACKS: Array[String] = ["foundry", "dunes", "glacier", "orbital"]
const MAX_RACERS := 8

var config: Dictionary = {}
var last_result: Dictionary = {}
var championship: Dictionary = {}
var _result_committed := false
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
	if not bool(restored_data.get("active", false)):
		return {}
	if round_index < 0 or round_index >= GRAND_PRIX_TRACKS.size():
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

	if mode == "grand_prix":
		if bool(request.get("new_championship", false)) or championship.is_empty() or not bool(championship.get("active", false)):
			_start_championship(difficulty)
		track_id = GRAND_PRIX_TRACKS[clampi(int(championship.get("round_index", 0)), 0, GRAND_PRIX_TRACKS.size() - 1)]

	var track := GameDatabase.get_track(track_id)
	var laps := clampi(int(request.get("laps", track.get("default_laps", 3))), 1, 9)
	var racer_count := 1 if mode == "time_trial" else clampi(int(request.get("racer_count", MAX_RACERS)), 2, MAX_RACERS)
	_session_counter += 1
	config = {
		"session_id": _session_counter,
		"mode": mode,
		"track_id": track_id,
		"difficulty": difficulty,
		"laps": laps,
		"racer_count": racer_count,
		"items_enabled": mode != "time_trial",
		"elimination_interval": clampf(float(request.get("elimination_interval", 32.0)), 15.0, 90.0) if mode == "elimination" else 0.0,
		"time_limit": clampf(float(request.get("time_limit", 900.0)), 60.0, 1800.0),
		"seed": int(request.get("seed", int(track.get("seed", 1)) + _session_counter * 97)),
	}
	_result_committed = false
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

	if mode == "grand_prix":
		_apply_championship_result(result)
		var championship_result := _championship_result()
		result["championship"] = championship_result
		result["round"] = int(championship_result.get("round", 1))
		result["total_rounds"] = int(championship_result.get("total_rounds", GRAND_PRIX_TRACKS.size()))
		result["championship_standings"] = championship_result.get("standings", [])
		result["championship_complete"] = bool(championship_result.get("complete", false))
		result["can_continue"] = bool(championship_result.get("can_continue", false))

	_result_committed = true
	last_result = result.duplicate(true)
	# SaveSystem was resolved before result normalization.
	if save_system != null and save_system.has_method(&"record_race_result"):
		save_system.call(&"record_race_result", result.duplicate(true))
	race_completed.emit(result.duplicate(true))
	return result.duplicate(true)


func abort_race(reason: String = "abandoned") -> Dictionary:
	return complete_race({
		"finished": false,
		"dnf": true,
		"reason": reason,
		"position": int(config.get("racer_count", MAX_RACERS)),
		"elapsed": 0.0,
		"laps_completed": 0,
	})


func start_next_grand_prix_round() -> Dictionary:
	if championship.is_empty() or not bool(championship.get("active", false)):
		return {}
	return configure({
		"mode": "grand_prix",
		"difficulty": String(championship.get("difficulty", "pilot")),
		"new_championship": false,
	})


func abandon_championship() -> void:
	if championship.is_empty():
		return
	championship["active"] = false
	championship["abandoned"] = true
	_persist_championship()
	championship_changed.emit(championship.duplicate(true))


func _start_championship(difficulty: String) -> void:
	var entrants: Array[Dictionary] = [{"id": "player", "name": "PILOTE 01", "points": 0}]
	for index in range(MAX_RACERS - 1):
		var pilot: Dictionary = GameDatabase.PILOTS[index % GameDatabase.PILOTS.size()]
		entrants.append({"id": String(pilot.get("id", "ai_%d" % index)), "name": String(pilot.get("name", "RIVAL %02d" % (index + 1))), "points": 0})
	championship = {
		"active": true,
		"abandoned": false,
		"difficulty": difficulty,
		"round_index": 0,
		"tracks": GRAND_PRIX_TRACKS.duplicate(),
		"completed_tracks": [],
		"entrants": entrants,
		"champion_id": "",
	}
	_persist_championship()
	championship_changed.emit(championship.duplicate(true))


func _apply_championship_result(result: Dictionary) -> void:
	if championship.is_empty():
		_start_championship(String(config.get("difficulty", "pilot")))
	var entrants: Array = championship.get("entrants", [])
	var classification: Array = result.get("classification", [])
	if classification.is_empty():
		classification = _fallback_classification(int(result.get("position", MAX_RACERS)))
	var awarded: Dictionary = {}
	var player_points := 0
	result["championship_won"] = false
	for rank in range(classification.size()):
		var entry: Dictionary = classification[rank]
		var racer_id := String(entry.get("racer_id", ""))
		if racer_id.is_empty() or awarded.has(racer_id):
			continue
		awarded[racer_id] = true
		var points := GameDatabase.CHAMPIONSHIP_POINTS[rank] if rank < GameDatabase.CHAMPIONSHIP_POINTS.size() else 0
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
	if int(championship["round_index"]) >= GRAND_PRIX_TRACKS.size():
		championship["active"] = false
		var sorted_entrants := entrants.duplicate(true)
		sorted_entrants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("points", 0)) > int(b.get("points", 0)))
		var champion_id := ""
		if not sorted_entrants.is_empty():
			var champion: Dictionary = sorted_entrants[0]
			champion_id = String(champion.get("id", ""))
		championship["champion_id"] = champion_id
		result["championship_won"] = champion_id == "player"
	championship_changed.emit(championship.duplicate(true))


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
	var total_rounds := GRAND_PRIX_TRACKS.size()
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


func _championship_entry_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_points := int(a.get("points", 0))
	var b_points := int(b.get("points", 0))
	if a_points == b_points:
		return String(a.get("id", "")) < String(b.get("id", ""))
	return a_points > b_points


func _persist_championship() -> void:
	var save_system := _save_system()
	if save_system == null:
		return
	if bool(championship.get("active", false)) and save_system.has_method(&"save_championship"):
		save_system.call(&"save_championship", championship.duplicate(true))
	elif save_system.has_method(&"clear_championship"):
		save_system.call(&"clear_championship")


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
		output.append({
			"racer_id": racer_id,
			"name": display_name,
			"pilot": display_name,
			"player": racer_id == "player" or bool(entry.get("player", false)),
			"delta": String(entry.get("delta", entry.get("gap", ""))),
			"position": output.size() + 1,
			"elapsed": maxf(0.0, float(entry.get("elapsed", 0.0))),
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
