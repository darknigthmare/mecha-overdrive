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
	var result := {
		"session_id": int(config.get("session_id", 0)),
		"mode": String(config.get("mode", "quick")),
		"track_id": String(config.get("track_id", "foundry")),
		"difficulty": String(config.get("difficulty", "pilot")),
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

	if String(config.get("mode", "")) == "grand_prix":
		_apply_championship_result(result)
		result["championship"] = championship.duplicate(true)

	_result_committed = true
	last_result = result.duplicate(true)
	var save_system := get_node_or_null("/root/SaveSystem")
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
	championship_changed.emit(championship.duplicate(true))


func _apply_championship_result(result: Dictionary) -> void:
	if championship.is_empty():
		_start_championship(String(config.get("difficulty", "pilot")))
	var entrants: Array = championship.get("entrants", [])
	var classification: Array = result.get("classification", [])
	if classification.is_empty():
		classification = _fallback_classification(int(result.get("position", MAX_RACERS)))
	var awarded: Dictionary = {}
	for rank in range(classification.size()):
		var entry: Dictionary = classification[rank]
		var racer_id := String(entry.get("racer_id", ""))
		if racer_id.is_empty() or awarded.has(racer_id):
			continue
		awarded[racer_id] = true
		var points := GameDatabase.CHAMPIONSHIP_POINTS[rank] if rank < GameDatabase.CHAMPIONSHIP_POINTS.size() else 0
		for entrant_index in range(entrants.size()):
			var entrant: Dictionary = entrants[entrant_index]
			if String(entrant.get("id", "")) == racer_id:
				entrant["points"] = maxi(0, int(entrant.get("points", 0))) + points
				entrants[entrant_index] = entrant
				break

	championship["entrants"] = entrants
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
		output.append({
			"racer_id": racer_id,
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
