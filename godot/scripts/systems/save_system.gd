class_name SaveSystemService
extends Node
## Versioned, defensive profile persistence for MECHA OVERDRIVE.
##
## Every public mutation validates its input, writes through a temporary file,
## and emits an immutable profile copy. Race records are accepted only for a
## genuinely finished run; a DNF may count as a race but can never set a record.

signal profile_loaded(profile_data: Dictionary)
signal profile_changed(profile_data: Dictionary)
signal save_failed(message: String)

const SAVE_VERSION := 2
const SAVE_PATH := "user://mecha_overdrive_profile.json"
const TEMP_PATH := "user://mecha_overdrive_profile.tmp"
const BACKUP_PATH := "user://mecha_overdrive_profile.backup.json"
const CORRUPT_PATH := "user://mecha_overdrive_profile.corrupt.json"
const BACKUP_CORRUPT_PATH := "user://mecha_overdrive_profile.backup.corrupt.json"
const MAX_UPGRADE_LEVEL := 4
const CHAMPIONSHIP_TRACKS: Array[String] = ["foundry", "dunes", "glacier", "orbital"]
const CHAMPIONSHIP_RACER_COUNT := 8

var profile: Dictionary = {}
var _save_path := SAVE_PATH
var _temp_path := TEMP_PATH
var _backup_path := BACKUP_PATH
var _corrupt_path := CORRUPT_PATH
var _backup_corrupt_path := BACKUP_CORRUPT_PATH


func _ready() -> void:
	load_profile()


func load_profile() -> Dictionary:
	var source: Dictionary = {}
	var primary := _read_profile_candidate(_save_path)
	var backup: Dictionary = {}
	var recovered_from_backup := false
	if bool(primary.get("valid", false)):
		source = Dictionary(primary.get("data", {}))
	else:
		backup = _read_profile_candidate(_backup_path)
		if bool(backup.get("valid", false)):
			source = Dictionary(backup.get("data", {}))
			recovered_from_backup = true

	var invalid_primary := bool(primary.get("exists", false)) and not bool(primary.get("valid", false))
	var invalid_backup := bool(backup.get("exists", false)) and not bool(backup.get("valid", false))
	if invalid_primary:
		_archive_invalid_file(_save_path, _corrupt_path)
	if invalid_backup:
		_archive_invalid_file(_backup_path, _backup_corrupt_path)

	profile = _sanitize_profile(source)
	if invalid_primary and not recovered_from_backup:
		save_failed.emit("Profil et backup illisibles : un profil sain a été recréé")
	elif invalid_backup and source.is_empty():
		save_failed.emit("Backup illisible : un profil sain a été recréé")
	if not bool(primary.get("valid", false)) or recovered_from_backup or source.is_empty() or int(source.get("version", 0)) != SAVE_VERSION:
		save_profile()
	profile_loaded.emit(profile.duplicate(true))
	return profile.duplicate(true)


func save_profile() -> bool:
	profile["version"] = SAVE_VERSION
	var file := FileAccess.open(_temp_path, FileAccess.WRITE)
	if file == null:
		_report_save_failure("Impossible d’ouvrir le fichier temporaire")
		return false
	file.store_string(JSON.stringify(profile, "\t", false))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_report_save_failure("Écriture incomplète du profil")
		return false

	var target_absolute := ProjectSettings.globalize_path(_save_path)
	var temp_absolute := ProjectSettings.globalize_path(_temp_path)
	var backup_absolute := ProjectSettings.globalize_path(_backup_path)
	var secured_previous_save := false
	if FileAccess.file_exists(_save_path):
		if FileAccess.file_exists(_backup_path):
			var remove_error := DirAccess.remove_absolute(backup_absolute)
			if remove_error != OK:
				_report_save_failure("Impossible de remplacer le backup précédent")
				return false
		var backup_error := DirAccess.rename_absolute(target_absolute, backup_absolute)
		if backup_error != OK:
			_report_save_failure("Impossible de sécuriser l’ancienne sauvegarde")
			return false
		secured_previous_save = true
	var replace_error := DirAccess.rename_absolute(temp_absolute, target_absolute)
	if replace_error != OK:
		if secured_previous_save and FileAccess.file_exists(_backup_path):
			DirAccess.rename_absolute(backup_absolute, target_absolute)
		_report_save_failure("Impossible de finaliser la sauvegarde")
		return false
	return true


func reset_profile() -> Dictionary:
	profile = _default_profile()
	_commit_profile()
	return profile.duplicate(true)


func select_chassis(chassis_id: String) -> bool:
	if not GameDatabase.has_chassis(chassis_id):
		return false
	profile["selected_chassis"] = chassis_id
	return _commit_profile()


func set_paint(chassis_id: String, paint_hex: String = "") -> bool:
	# `set_paint("#AABBCC")` is accepted as a convenience for the selected chassis.
	if paint_hex.is_empty() and chassis_id.begins_with("#"):
		paint_hex = chassis_id
		chassis_id = String(profile.get("selected_chassis", "biped"))
	if not GameDatabase.has_chassis(chassis_id) or not Color.html_is_valid(paint_hex):
		return false
	var paints: Dictionary = profile.get("paints", {})
	paints[chassis_id] = Color(paint_hex).to_html(false).to_upper()
	profile["paints"] = paints
	return _commit_profile()


func buy_upgrade(upgrade_id: String, chassis_id: String = "") -> bool:
	if chassis_id.is_empty():
		chassis_id = String(profile.get("selected_chassis", "biped"))
	# Also tolerate the natural `(chassis_id, upgrade_id)` ordering.
	if GameDatabase.has_chassis(upgrade_id) and not GameDatabase.get_upgrade(chassis_id).is_empty():
		var swap := chassis_id
		chassis_id = upgrade_id
		upgrade_id = swap
	if not GameDatabase.has_chassis(chassis_id):
		return false
	var upgrade := GameDatabase.get_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false
	var current_level := get_upgrade_level(upgrade_id, chassis_id)
	var costs: Array = upgrade.get("costs", [])
	if current_level >= MAX_UPGRADE_LEVEL or current_level >= costs.size():
		return false
	var cost := maxi(0, int(costs[current_level]))
	var credits := maxi(0, int(profile.get("credits", 0)))
	if credits < cost:
		return false
	var all_upgrades: Dictionary = profile.get("upgrades", {})
	var chassis_upgrades: Dictionary = all_upgrades.get(chassis_id, {})
	chassis_upgrades[upgrade_id] = current_level + 1
	all_upgrades[chassis_id] = chassis_upgrades
	profile["upgrades"] = all_upgrades
	profile["credits"] = credits - cost
	return _commit_profile()


func get_upgrade_level(upgrade_id: String, chassis_id: String = "") -> int:
	if chassis_id.is_empty():
		chassis_id = String(profile.get("selected_chassis", "biped"))
	var all_upgrades: Dictionary = profile.get("upgrades", {})
	var chassis_upgrades: Dictionary = all_upgrades.get(chassis_id, {})
	return clampi(int(chassis_upgrades.get(upgrade_id, 0)), 0, MAX_UPGRADE_LEVEL)


func get_upgrade_cost(upgrade_id: String, chassis_id: String = "") -> int:
	var upgrade := GameDatabase.get_upgrade(upgrade_id)
	var costs: Array = upgrade.get("costs", [])
	var level := get_upgrade_level(upgrade_id, chassis_id)
	return int(costs[level]) if level < costs.size() else -1


func update_settings(changes: Dictionary) -> bool:
	var settings: Dictionary = profile.get("settings", {})
	for key: String in ["high_contrast", "reduced_motion", "large_text", "camera_shake", "metric_units"]:
		if changes.has(key) and changes[key] is bool:
			settings[key] = changes[key]
	for key: String in ["master_volume", "music_volume", "effects_volume"]:
		if changes.has(key) and (changes[key] is int or changes[key] is float):
			settings[key] = clampf(float(changes[key]), 0.0, 1.0)
	profile["settings"] = settings
	return _commit_profile()


func set_pilot_name(pilot_name: String) -> bool:
	var sanitized := pilot_name.strip_edges().substr(0, 18)
	if sanitized.is_empty():
		return false
	profile["pilot_name"] = sanitized
	return _commit_profile()


func get_championship() -> Dictionary:
	var value: Variant = profile.get("championship", {})
	if value is Dictionary:
		var championship_data: Dictionary = value
		return championship_data.duplicate(true)
	return {}


func save_championship(championship_data: Dictionary) -> bool:
	profile["championship"] = _sanitize_championship(championship_data)
	return _commit_profile()


func clear_championship() -> bool:
	var current: Variant = profile.get("championship", {})
	if current is Dictionary and Dictionary(current).is_empty():
		return true
	profile["championship"] = {}
	return _commit_profile()


func record_race_result(result: Dictionary) -> bool:
	if result.has("championship") and result["championship"] is Dictionary:
		profile["championship"] = _sanitize_championship(result["championship"])
	var finished := bool(result.get("finished", false)) and not bool(result.get("dnf", false))
	var stats: Dictionary = profile.get("stats", {})
	stats["races"] = maxi(0, int(stats.get("races", 0))) + 1
	if finished:
		var position := maxi(1, int(result.get("position", 99)))
		if position == 1:
			stats["wins"] = maxi(0, int(stats.get("wins", 0))) + 1
		if position <= 3:
			stats["podiums"] = maxi(0, int(stats.get("podiums", 0))) + 1
		if bool(result.get("championship_won", false)):
			stats["championships"] = maxi(0, int(stats.get("championships", 0))) + 1
	profile["stats"] = stats

	# DNF results deliberately stop here: no credits, no best time, no record.
	if not finished:
		return _commit_profile()

	var reward := maxi(0, int(result.get("reward", 0)))
	profile["credits"] = maxi(0, int(profile.get("credits", 0))) + reward
	stats["credits_earned"] = maxi(0, int(stats.get("credits_earned", 0))) + reward
	profile["stats"] = stats

	var elapsed := float(result.get("elapsed", 0.0))
	var track_id := String(result.get("track_id", ""))
	var mode := String(result.get("mode", "quick"))
	if bool(result.get("record_valid", true)) and elapsed > 0.0 and GameDatabase.has_track(track_id):
		var records: Dictionary = profile.get("records", {})
		var track_records: Dictionary = records.get(track_id, {})
		var previous := float(track_records.get(mode, INF))
		if elapsed < previous:
			track_records[mode] = elapsed
			records[track_id] = track_records
			profile["records"] = records
	return _commit_profile()


func _commit_profile() -> bool:
	profile = _sanitize_profile(profile)
	var did_save := save_profile()
	if did_save:
		profile_changed.emit(profile.duplicate(true))
	return did_save


func _default_profile() -> Dictionary:
	var paints: Dictionary = {}
	var upgrades: Dictionary = {}
	var chassis_ids: Array[String] = []
	for chassis: Dictionary in GameDatabase.CHASSIS:
		var chassis_id := String(chassis.get("id", "biped"))
		chassis_ids.append(chassis_id)
		paints[chassis_id] = String(chassis.get("paint", "#5EE7FF")).trim_prefix("#").to_upper()
		var levels: Dictionary = {}
		for upgrade_id: String in GameDatabase.get_upgrade_ids():
			levels[upgrade_id] = 0
		upgrades[chassis_id] = levels
	return {
		"version": SAVE_VERSION,
		"pilot_name": "PILOTE 01",
		"credits": 1800,
		"selected_chassis": "biped",
		"owned_chassis": chassis_ids,
		"paints": paints,
		"unlocked_paints": GameDatabase.DEFAULT_PAINTS.duplicate(),
		"upgrades": upgrades,
		"records": {},
		"championship": {},
		"stats": {"races": 0, "wins": 0, "podiums": 0, "championships": 0, "credits_earned": 0},
		"settings": {
			"high_contrast": false, "reduced_motion": false, "large_text": false,
			"camera_shake": true, "metric_units": true,
			"master_volume": 0.85, "music_volume": 0.65, "effects_volume": 0.85,
		},
	}


func _sanitize_profile(source: Dictionary) -> Dictionary:
	var clean := _default_profile()
	clean["pilot_name"] = String(source.get("pilot_name", source.get("pilotName", clean["pilot_name"]))).strip_edges().substr(0, 18)
	if String(clean["pilot_name"]).is_empty():
		clean["pilot_name"] = "PILOTE 01"
	clean["credits"] = clampi(int(source.get("credits", clean["credits"])), 0, 99999999)
	var selected := String(source.get("selected_chassis", source.get("selectedChassis", "biped")))
	clean["selected_chassis"] = selected if GameDatabase.has_chassis(selected) else "biped"

	var source_paints: Dictionary = source.get("paints", {}) if source.get("paints", {}) is Dictionary else {}
	var clean_paints: Dictionary = clean["paints"]
	for chassis_id: String in clean_paints.keys():
		var paint_value := String(source_paints.get(chassis_id, clean_paints[chassis_id]))
		if Color.html_is_valid(paint_value):
			clean_paints[chassis_id] = Color(paint_value).to_html(false).to_upper()
	clean["paints"] = clean_paints

	var source_upgrades: Dictionary = source.get("upgrades", {}) if source.get("upgrades", {}) is Dictionary else {}
	var clean_upgrades: Dictionary = clean["upgrades"]
	for chassis_id: String in clean_upgrades.keys():
		var old_levels: Dictionary = source_upgrades.get(chassis_id, {}) if source_upgrades.get(chassis_id, {}) is Dictionary else {}
		var new_levels: Dictionary = clean_upgrades[chassis_id]
		for upgrade_id: String in new_levels.keys():
			new_levels[upgrade_id] = clampi(int(old_levels.get(upgrade_id, 0)), 0, MAX_UPGRADE_LEVEL)
		clean_upgrades[chassis_id] = new_levels
	clean["upgrades"] = clean_upgrades

	var old_settings: Dictionary = source.get("settings", {}) if source.get("settings", {}) is Dictionary else {}
	var new_settings: Dictionary = clean["settings"]
	for key: String in new_settings.keys():
		if not old_settings.has(key):
			continue
		if new_settings[key] is bool and old_settings[key] is bool:
			new_settings[key] = old_settings[key]
		elif new_settings[key] is float and (old_settings[key] is int or old_settings[key] is float):
			new_settings[key] = clampf(float(old_settings[key]), 0.0, 1.0)
	clean["settings"] = new_settings

	var old_stats: Dictionary = source.get("stats", {}) if source.get("stats", {}) is Dictionary else {}
	var new_stats: Dictionary = clean["stats"]
	for key: String in new_stats.keys():
		new_stats[key] = clampi(int(old_stats.get(key, 0)), 0, 99999999)
	clean["stats"] = new_stats
	clean["records"] = _sanitize_records(source.get("records", {}))
	clean["championship"] = _sanitize_championship(source.get("championship", {}))
	clean["version"] = SAVE_VERSION
	return clean


func _sanitize_records(value: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not value is Dictionary:
		return clean
	var records: Dictionary = value
	for track_id: Variant in records.keys():
		var track_key := String(track_id)
		if not GameDatabase.has_track(track_key) or not records[track_id] is Dictionary:
			continue
		var raw_track: Dictionary = records[track_id]
		var track_records: Dictionary = {}
		for mode: Variant in raw_track.keys():
			var seconds: Variant = raw_track[mode]
			if (seconds is int or seconds is float) and float(seconds) > 0.0:
				track_records[String(mode)] = float(seconds)
		if not track_records.is_empty():
			clean[track_key] = track_records
	return clean


func _sanitize_championship(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	if not bool(source.get("active", false)) or bool(source.get("abandoned", false)):
		return {}
	var difficulty := String(source.get("difficulty", "pilot"))
	if not GameDatabase.has_difficulty(difficulty):
		return {}
	var round_index := int(source.get("round_index", -1))
	if round_index < 0 or round_index >= CHAMPIONSHIP_TRACKS.size():
		return {}

	var entrants: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var has_player := false
	var raw_entrants: Variant = source.get("entrants", [])
	if not raw_entrants is Array:
		return {}
	for raw_entrant: Variant in raw_entrants:
		if not raw_entrant is Dictionary:
			continue
		var entrant: Dictionary = raw_entrant
		var entrant_id := String(entrant.get("id", ""))
		if entrant_id.is_empty() or seen_ids.has(entrant_id):
			continue
		seen_ids[entrant_id] = true
		has_player = has_player or entrant_id == "player"
		var entrant_name := String(entrant.get("name", "PILOTE")).strip_edges().substr(0, 24)
		if entrant_name.is_empty():
			entrant_name = "PILOTE"
		entrants.append({
			"id": entrant_id,
			"name": entrant_name,
			"points": clampi(int(entrant.get("points", 0)), 0, 9999),
		})
	if entrants.size() != CHAMPIONSHIP_RACER_COUNT or not has_player:
		return {}

	var completed_tracks: Array[String] = []
	for track_index in range(round_index):
		completed_tracks.append(CHAMPIONSHIP_TRACKS[track_index])
	return {
		"active": true,
		"abandoned": false,
		"difficulty": difficulty,
		"round_index": round_index,
		"tracks": CHAMPIONSHIP_TRACKS.duplicate(),
		"completed_tracks": completed_tracks,
		"entrants": entrants,
		"champion_id": "",
	}


func _read_profile_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "valid": false, "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true, "valid": false, "data": {}}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"exists": true, "valid": false, "data": {}}
	var decoded: Variant = parser.data
	if decoded is Dictionary:
		return {"exists": true, "valid": true, "data": decoded}
	return {"exists": true, "valid": false, "data": {}}


func _archive_invalid_file(source_path: String, corrupt_path: String) -> void:
	if not FileAccess.file_exists(source_path):
		return
	var corrupt_absolute := ProjectSettings.globalize_path(corrupt_path)
	if FileAccess.file_exists(corrupt_path):
		DirAccess.remove_absolute(corrupt_absolute)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(source_path), corrupt_absolute)


func _report_save_failure(message: String) -> void:
	push_warning(message)
	save_failed.emit(message)
