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

const SAVE_VERSION := 6
const CHAMPIONSHIP_SCHEMA_VERSION := 4
const CHAMPIONSHIP_CANONICAL_RULES_VERSION := 3
const LEGACY_DIVISION_CHAMPIONSHIP_IDS: Array[String] = [
	"command_cup", "stabilized_cup", "swarm_cup", "ground_cup", "experimental_cup",
]
const HISTORIC_MODULE_IDS: Array[String] = [
	"core_balanced", "core_overdrive", "core_bastion",
	"mobility_vector", "mobility_sprint", "mobility_adaptive",
	"utility_coolant", "utility_aegis", "utility_scanner",
]
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


func set_module(chassis_id: String, slot_id: String, module_id: String) -> bool:
	if not GameDatabase.has_chassis(chassis_id) or GameDatabase.get_module_option(slot_id, module_id).is_empty():
		return false
	var division_id := String(GameDatabase.get_chassis(chassis_id).get("division_id", ""))
	if not GameDatabase.is_module_allowed_for_division(module_id, division_id) or not is_module_owned(module_id):
		return false
	var loadouts: Dictionary = profile.get("loadouts", {})
	var loadout := _sanitize_loadout(loadouts.get(chassis_id, {}), chassis_id)
	loadout[slot_id] = module_id
	loadouts[chassis_id] = loadout
	profile["loadouts"] = loadouts
	return _commit_profile()


func set_locomotion(chassis_id: String, locomotion_id: String) -> bool:
	if not GameDatabase.has_chassis(chassis_id):
		return false
	var configuration := LocomotionCatalog.get_configuration(locomotion_id)
	if configuration.is_empty() or String(configuration.get("family_id", "")) != chassis_id:
		return false
	if not is_locomotion_owned(locomotion_id):
		return false
	var locomotions: Dictionary = profile.get("locomotions", {})
	locomotions[chassis_id] = locomotion_id
	profile["locomotions"] = locomotions
	return _commit_profile()


func get_locomotion(chassis_id: String = "") -> String:
	if chassis_id.is_empty():
		chassis_id = String(profile.get("selected_chassis", "biped"))
	if not GameDatabase.has_chassis(chassis_id):
		return ""
	var locomotions: Dictionary = profile.get("locomotions", {}) if profile.get("locomotions", {}) is Dictionary else {}
	var requested := String(locomotions.get(chassis_id, LocomotionCatalog.get_default_configuration_id(chassis_id)))
	var configuration := LocomotionCatalog.get_configuration(requested)
	if configuration.is_empty() or String(configuration.get("family_id", "")) != chassis_id:
		return LocomotionCatalog.get_default_configuration_id(chassis_id)
	return requested


func is_module_owned(module_id: String) -> bool:
	var owned: Variant = profile.get("owned_modules", [])
	return owned is Array and module_id in owned


func get_owned_modules() -> Array[String]:
	var output: Array[String] = []
	var owned: Variant = profile.get("owned_modules", [])
	if owned is Array:
		for module_id: Variant in owned:
			output.append(String(module_id))
	return output


func is_locomotion_owned(locomotion_id: String) -> bool:
	var owned: Variant = profile.get("owned_locomotions", [])
	return owned is Array and locomotion_id in owned


func get_owned_locomotions() -> Array[String]:
	var output: Array[String] = []
	var owned: Variant = profile.get("owned_locomotions", [])
	if owned is Array:
		for locomotion_id: Variant in owned:
			output.append(String(locomotion_id))
	return output


func get_locomotion_cost(chassis_id: String, locomotion_id: String) -> int:
	if not GameDatabase.has_chassis(chassis_id):
		return -1
	var configuration := LocomotionCatalog.get_configuration(locomotion_id)
	if configuration.is_empty() or String(configuration.get("family_id", "")) != chassis_id:
		return -1
	return 0 if is_locomotion_owned(locomotion_id) else maxi(0, int(configuration.get("cost", 0)))


func get_garage_cost(chassis_id: String, requested_loadout: Dictionary, locomotion_id: String) -> int:
	var module_cost := get_loadout_cost(chassis_id, requested_loadout)
	var locomotion_cost := get_locomotion_cost(chassis_id, locomotion_id)
	if module_cost < 0 or locomotion_cost < 0:
		return -1
	return module_cost + locomotion_cost


func get_loadout_cost(chassis_id: String, requested_loadout: Dictionary) -> int:
	if not GameDatabase.has_chassis(chassis_id):
		return -1
	var division_id := String(GameDatabase.get_chassis(chassis_id).get("division_id", ""))
	var owned := get_owned_modules()
	var counted: Dictionary = {}
	var cost := 0
	for slot: Dictionary in GameDatabase.MODULE_SLOTS:
		var slot_id := String(slot.get("id", ""))
		var module_id := String(requested_loadout.get(slot_id, ""))
		var option := GameDatabase.get_module_option(slot_id, module_id)
		if option.is_empty() or not GameDatabase.is_module_allowed_for_division(module_id, division_id):
			return -1
		if module_id not in owned and not counted.has(module_id):
			cost += maxi(0, int(option.get("cost", 0)))
			counted[module_id] = true
	return cost


func purchase_and_equip_loadout(chassis_id: String, requested_loadout: Dictionary) -> bool:
	var paints: Dictionary = profile.get("paints", {})
	var current_paint := String(paints.get(chassis_id, GameDatabase.get_chassis(chassis_id).get("paint", "#5EE7FF")))
	return purchase_and_apply_garage(chassis_id, current_paint, requested_loadout)


func purchase_and_apply_garage(chassis_id: String, paint_hex: String, requested_loadout: Dictionary, locomotion_id: String = "") -> bool:
	if not Color.html_is_valid(paint_hex):
		return false
	if locomotion_id.is_empty():
		locomotion_id = get_locomotion(chassis_id)
	var locomotion := LocomotionCatalog.get_configuration(locomotion_id)
	if locomotion.is_empty() or String(locomotion.get("family_id", "")) != chassis_id:
		return false
	var cost := get_garage_cost(chassis_id, requested_loadout, locomotion_id)
	var credits := maxi(0, int(profile.get("credits", 0)))
	if cost < 0 or credits < cost:
		return false
	var snapshot := profile.duplicate(true)
	var owned := get_owned_modules()
	for slot: Dictionary in GameDatabase.MODULE_SLOTS:
		var module_id := String(requested_loadout.get(String(slot.get("id", "")), ""))
		if module_id not in owned:
			owned.append(module_id)
	var owned_locomotions := get_owned_locomotions()
	if locomotion_id not in owned_locomotions:
		owned_locomotions.append(locomotion_id)
	var loadouts: Dictionary = profile.get("loadouts", {})
	loadouts[chassis_id] = _sanitize_loadout(requested_loadout, chassis_id)
	var paints: Dictionary = profile.get("paints", {})
	paints[chassis_id] = Color(paint_hex).to_html(false).to_upper()
	var locomotions: Dictionary = profile.get("locomotions", {})
	locomotions[chassis_id] = locomotion_id
	profile["owned_modules"] = owned
	profile["owned_locomotions"] = owned_locomotions
	profile["loadouts"] = loadouts
	profile["paints"] = paints
	profile["locomotions"] = locomotions
	profile["credits"] = credits - cost
	if _commit_profile():
		return true
	profile = snapshot
	return false


func get_loadout(chassis_id: String = "") -> Dictionary:
	if chassis_id.is_empty():
		chassis_id = String(profile.get("selected_chassis", "biped"))
	if not GameDatabase.has_chassis(chassis_id):
		return {}
	var loadouts: Dictionary = profile.get("loadouts", {})
	return _sanitize_loadout(loadouts.get(chassis_id, {}), chassis_id).duplicate(true)


func set_camera_view(camera_view: String) -> bool:
	if camera_view not in ["tps", "fps"]:
		return false
	var settings: Dictionary = profile.get("settings", {})
	settings["camera_view"] = camera_view
	profile["settings"] = settings
	return _commit_profile()


func get_camera_view() -> String:
	var settings: Dictionary = profile.get("settings", {})
	return _sanitize_camera_view(String(settings.get("camera_view", "tps")))


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
	for key: String in ["high_contrast", "reduced_motion", "large_text", "camera_shake", "metric_units", "season_intro_arc_2_seen"]:
		if changes.has(key) and changes[key] is bool:
			settings[key] = changes[key]
	for key: String in ["master_volume", "music_volume", "effects_volume"]:
		if changes.has(key) and (changes[key] is int or changes[key] is float):
			settings[key] = clampf(float(changes[key]), 0.0, 1.0)
	if changes.has("camera_view"):
		settings["camera_view"] = _sanitize_camera_view(String(changes["camera_view"]))
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
	var snapshot := profile.duplicate(true)
	profile["championship"] = _sanitize_championship(championship_data)
	if _commit_profile():
		return true
	profile = snapshot
	return false


func clear_championship() -> bool:
	var current: Variant = profile.get("championship", {})
	if current is Dictionary and Dictionary(current).is_empty():
		return true
	var snapshot := profile.duplicate(true)
	profile["championship"] = {}
	if _commit_profile():
		return true
	profile = snapshot
	return false


func record_race_result(result: Dictionary) -> bool:
	var snapshot := profile.duplicate(true)
	var championship_data: Dictionary = {}
	if result.has("championship") and result["championship"] is Dictionary:
		championship_data = Dictionary(result["championship"]).duplicate(true)
		profile["championship"] = _sanitize_championship(championship_data)
	var finished := bool(result.get("finished", false)) and not bool(result.get("dnf", false))
	var stats: Dictionary = profile.get("stats", {})
	stats["races"] = maxi(0, int(stats.get("races", 0))) + 1
	if finished:
		var position := maxi(1, int(result.get("position", 99)))
		if position == 1:
			stats["wins"] = maxi(0, int(stats.get("wins", 0))) + 1
		if position <= 3:
			stats["podiums"] = maxi(0, int(stats.get("podiums", 0))) + 1
	var champion_id := String(championship_data.get("champion_id", ""))
	var championship_won := (
		bool(result.get("championship_won", false))
		and not championship_data.is_empty()
		and bool(championship_data.get("complete", false))
		and champion_id == "player"
	)
	if championship_won:
		stats["championships"] = maxi(0, int(stats.get("championships", 0))) + 1
	profile["stats"] = stats

	# DNF results deliberately stop here: no credits, no best time, no record.
	if not finished:
		if _commit_profile():
			return true
		profile = snapshot
		return false

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
	if _commit_profile():
		return true
	profile = snapshot
	return false


func _commit_profile() -> bool:
	profile = _sanitize_profile(profile)
	var did_save := save_profile()
	if did_save:
		profile_changed.emit(profile.duplicate(true))
	return did_save


func _default_profile() -> Dictionary:
	var paints: Dictionary = {}
	var upgrades: Dictionary = {}
	var loadouts: Dictionary = {}
	var locomotions: Dictionary = {}
	var owned_locomotions: Array[String] = []
	var chassis_ids: Array[String] = []
	for chassis: Dictionary in GameDatabase.CHASSIS:
		var chassis_id := String(chassis.get("id", "biped"))
		chassis_ids.append(chassis_id)
		paints[chassis_id] = String(chassis.get("paint", "#5EE7FF")).trim_prefix("#").to_upper()
		var levels: Dictionary = {}
		for upgrade_id: String in GameDatabase.get_upgrade_ids():
			levels[upgrade_id] = 0
		upgrades[chassis_id] = levels
		loadouts[chassis_id] = _default_loadout(chassis_id)
		var default_locomotion := LocomotionCatalog.get_default_configuration_id(chassis_id)
		locomotions[chassis_id] = default_locomotion
		owned_locomotions.append(default_locomotion)
	return {
		"version": SAVE_VERSION,
		"pilot_name": "PILOTE 01",
		"credits": 1800,
		"selected_chassis": "biped",
		"owned_chassis": chassis_ids,
		"paints": paints,
		"unlocked_paints": GameDatabase.DEFAULT_PAINTS.duplicate(),
		"upgrades": upgrades,
		"loadouts": loadouts,
		"locomotions": locomotions,
		"owned_locomotions": owned_locomotions,
		"owned_modules": HISTORIC_MODULE_IDS.duplicate(),
		"records": {},
		"championship": {},
		"stats": {"races": 0, "wins": 0, "podiums": 0, "championships": 0, "credits_earned": 0},
		"settings": {
			"high_contrast": false, "reduced_motion": false, "large_text": false,
			"camera_shake": true, "metric_units": true,
			"season_intro_arc_2_seen": false,
			"master_volume": 0.85, "music_volume": 0.65, "effects_volume": 0.85,
			"camera_view": "tps",
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

	# v2 profiles have no modular loadouts. Missing or invalid slots migrate to
	# the catalog defaults without invalidating the rest of the profile.
	var source_loadouts: Dictionary = source.get("loadouts", {}) if source.get("loadouts", {}) is Dictionary else {}
	var clean_loadouts: Dictionary = clean["loadouts"]
	for chassis_id: String in clean_loadouts.keys():
		clean_loadouts[chassis_id] = _sanitize_loadout(source_loadouts.get(chassis_id, {}), chassis_id)
	clean["loadouts"] = clean_loadouts

	# v4 and older profiles have no locomotion choice. They migrate to the
	# constructor mounting for each chassis; cross-family or stale IDs are
	# rejected without affecting paint, modules, upgrades or championship data.
	var source_locomotions: Dictionary = source.get("locomotions", {}) if source.get("locomotions", {}) is Dictionary else {}
	var clean_locomotions: Dictionary = clean["locomotions"]
	for chassis_id: String in clean_locomotions.keys():
		var requested_locomotion := String(source_locomotions.get(chassis_id, clean_locomotions[chassis_id]))
		var configuration := LocomotionCatalog.get_configuration(requested_locomotion)
		if not configuration.is_empty() and String(configuration.get("family_id", "")) == chassis_id:
			clean_locomotions[chassis_id] = requested_locomotion
	clean["locomotions"] = clean_locomotions

	# The unreleased v5 schema may already contain a selected drive. Preserve it
	# while granting every chassis its constructor configuration by default.
	var owned_locomotions: Array[String] = []
	var clean_owned_value: Variant = clean.get("owned_locomotions", [])
	if clean_owned_value is Array:
		for default_id: Variant in clean_owned_value:
			owned_locomotions.append(String(default_id))
	var source_owned_locomotions: Variant = source.get("owned_locomotions", [])
	if source_owned_locomotions is Array:
		for raw_locomotion_id: Variant in source_owned_locomotions:
			var owned_id := String(raw_locomotion_id)
			if not LocomotionCatalog.get_configuration(owned_id).is_empty() and owned_id not in owned_locomotions:
				owned_locomotions.append(owned_id)
	for selected_locomotion: Variant in clean_locomotions.values():
		var selected_id := String(selected_locomotion)
		if selected_id not in owned_locomotions:
			owned_locomotions.append(selected_id)
	clean["owned_locomotions"] = owned_locomotions

	# v3 exposed the original nine modules without purchase. They remain owned
	# forever; v4 adds only validated catalogue IDs to that historical grant.
	var valid_module_ids: Dictionary = {}
	for option: Dictionary in GameDatabase.get_all_module_options():
		valid_module_ids[String(option.get("id", ""))] = true
	var owned_modules: Array[String] = []
	for module_id: String in HISTORIC_MODULE_IDS:
		if valid_module_ids.has(module_id):
			owned_modules.append(module_id)
	var source_owned: Variant = source.get("owned_modules", [])
	if source_owned is Array:
		for raw_module_id: Variant in source_owned:
			var module_id := String(raw_module_id)
			if valid_module_ids.has(module_id) and module_id not in owned_modules:
				owned_modules.append(module_id)
	clean["owned_modules"] = owned_modules
	for chassis_id: String in clean_loadouts.keys():
		var owned_loadout: Dictionary = clean_loadouts[chassis_id]
		var fallback_loadout := _default_loadout(chassis_id)
		for slot_id: String in owned_loadout.keys():
			if String(owned_loadout[slot_id]) not in owned_modules:
				owned_loadout[slot_id] = fallback_loadout.get(slot_id, owned_loadout[slot_id])
		clean_loadouts[chassis_id] = owned_loadout
	clean["loadouts"] = clean_loadouts

	var old_settings: Dictionary = source.get("settings", {}) if source.get("settings", {}) is Dictionary else {}
	var new_settings: Dictionary = clean["settings"]
	for key: String in new_settings.keys():
		if not old_settings.has(key):
			continue
		if new_settings[key] is bool and old_settings[key] is bool:
			new_settings[key] = old_settings[key]
		elif new_settings[key] is float and (old_settings[key] is int or old_settings[key] is float):
			new_settings[key] = clampf(float(old_settings[key]), 0.0, 1.0)
		elif key == "camera_view":
			new_settings[key] = _sanitize_camera_view(String(old_settings[key]))
	clean["settings"] = new_settings

	var old_stats: Dictionary = source.get("stats", {}) if source.get("stats", {}) is Dictionary else {}
	var new_stats: Dictionary = clean["stats"]
	for key: String in new_stats.keys():
		new_stats[key] = clampi(int(old_stats.get(key, 0)), 0, 99999999)
	clean["stats"] = new_stats
	clean["records"] = _sanitize_records(source.get("records", {}))
	clean["championship"] = _sanitize_championship(source.get("championship", {}), clean, int(source.get("version", 1)))
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


func _sanitize_championship(value: Variant, profile_context: Dictionary = {}, source_version: int = SAVE_VERSION) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	if not bool(source.get("active", false)) or bool(source.get("abandoned", false)):
		return {}
	var difficulty := String(source.get("difficulty", "pilot"))
	if not GameDatabase.has_difficulty(difficulty):
		return {}

	var selected_chassis := String(profile_context.get("selected_chassis", profile.get("selected_chassis", "biped")))
	if not GameDatabase.has_chassis(selected_chassis):
		selected_chassis = "biped"
	var selected_division := String(GameDatabase.get_chassis(selected_chassis).get("division_id", "command"))
	var selected_category := GameDatabase.get_race_category_for_chassis(selected_chassis)
	var selected_category_id := String(selected_category.get("id", selected_chassis))
	var selected_cup := GameDatabase.get_championship_for_chassis(selected_chassis)
	var legacy_cup_id := String(selected_cup.get("id", "%s_cup" % selected_division))
	if GameDatabase.get_championship(legacy_cup_id).is_empty():
		legacy_cup_id = "command_cup"
	# v2 only knew one anonymous GP. Migrate it to the dedicated cup matching
	# the selected chassis so an existing championship is never silently lost.
	var default_cup_id := legacy_cup_id if source_version < CHAMPIONSHIP_SCHEMA_VERSION else "command_cup"
	var championship_id := String(source.get("championship_id", source.get("cup_id", default_cup_id)))
	# Until v5, the five dedicated IDs represented whole technical divisions.
	# In v6 they identify exact categories, so every legacy dedicated cup must
	# follow the selected chassis -- including the second chassis of a division.
	if source_version < SAVE_VERSION and championship_id in LEGACY_DIVISION_CHAMPIONSHIP_IDS:
		championship_id = legacy_cup_id
	var definition := GameDatabase.get_championship(championship_id)
	if definition.is_empty():
		return {}
	# From v3 onward, a saved cup references immutable catalogue rules. This
	# closes tampering and prevents stale fields from rewriting its homologation.
	var track_source: Variant = source.get("tracks", definition.get("track_ids", CHAMPIONSHIP_TRACKS)) if source_version < CHAMPIONSHIP_CANONICAL_RULES_VERSION else definition.get("track_ids", CHAMPIONSHIP_TRACKS)
	var tracks := _sanitize_track_list(track_source)
	if tracks.is_empty():
		return {}
	var round_index := int(source.get("round_index", -1))
	if round_index < 0 or round_index >= tracks.size():
		return {}
	var authored_division := String(definition.get("division_id", ""))
	var division_id := _sanitize_division(selected_division if authored_division.is_empty() else authored_division)
	var category_chassis_id := String(definition.get("category_chassis_id", selected_chassis))
	if not GameDatabase.has_chassis(category_chassis_id):
		category_chassis_id = selected_chassis
	var race_category_id := String(GameDatabase.get_race_category_for_chassis(category_chassis_id).get("id", selected_category_id))
	var ruleset_id := String(definition.get("ruleset_id", "division_locked"))
	var ruleset := GameDatabase.get_ruleset(ruleset_id)
	if ruleset.is_empty():
		ruleset_id = "open_mixed" if bool(definition.get("mixed_divisions", false)) else "division_locked"
		ruleset = GameDatabase.get_ruleset(ruleset_id)
	var mixed_divisions := bool(definition.get("mixed_divisions", false))
	var grid_policy := "mixed" if mixed_divisions else "division"
	var performance_class_id := String(definition.get("performance_class_id", ruleset.get("performance_class_id", "tuned")))
	if GameDatabase.get_performance_class(performance_class_id).is_empty():
		performance_class_id = "tuned"
	var performance_class := GameDatabase.get_performance_class(performance_class_id)
	var profile_loadouts: Dictionary = profile_context.get("loadouts", profile.get("loadouts", {}))

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
		var chassis_id := String(entrant.get("chassis_id", selected_chassis if entrant_id == "player" else _fallback_chassis_id(entrants.size(), division_id, grid_policy)))
		if not GameDatabase.has_chassis(chassis_id):
			return {}
		if grid_policy == "division" and chassis_id != category_chassis_id:
			if source_version < SAVE_VERSION:
				chassis_id = category_chassis_id
			else:
				return {}
		if grid_policy == "division" and String(GameDatabase.get_chassis(chassis_id).get("division_id", "")) != division_id:
			return {}
		var entrant_chassis := GameDatabase.get_chassis(chassis_id)
		var constructor_locomotion_id := LocomotionCatalog.get_default_configuration_id(chassis_id)
		var requested_locomotion_id := String(entrant.get("locomotion_id", constructor_locomotion_id))
		var homologated_locomotion := LocomotionCatalog.homologate_configuration(entrant_chassis, requested_locomotion_id, performance_class)
		if homologated_locomotion.is_empty() or String(homologated_locomotion.get("family_id", "")) != chassis_id:
			homologated_locomotion = LocomotionCatalog.get_configuration(constructor_locomotion_id)
		var locomotion_id := String(homologated_locomotion.get("id", constructor_locomotion_id))
		var paint := String(entrant.get("paint", entrant_chassis.get("paint", "#5EE7FF")))
		if not Color.html_is_valid(paint):
			paint = String(entrant_chassis.get("paint", "#5EE7FF"))
		var loadout_source: Variant = entrant.get("loadout", profile_loadouts.get(chassis_id, {}))
		entrants.append({
			"id": entrant_id,
			"racer_id": entrant_id,
			"name": entrant_name,
			"pilot_id": String(entrant.get("pilot_id", "player" if entrant_id == "player" else entrant_id)),
			"chassis_id": chassis_id,
			"division_id": String(entrant_chassis.get("division_id", division_id)),
			"race_category_id": String(GameDatabase.get_race_category_for_chassis(chassis_id).get("id", chassis_id)),
			"locomotion_id": locomotion_id,
			"paint": Color(paint).to_html(false).to_upper(),
			"loadout": _sanitize_loadout(loadout_source, chassis_id),
			"module_variant": String(entrant.get("module_variant", "standard")),
			"points": clampi(int(entrant.get("points", 0)), 0, 9999),
		})
	if entrants.size() != CHAMPIONSHIP_RACER_COUNT or not has_player:
		return {}

	var completed_tracks: Array[String] = []
	for track_index in range(round_index):
		completed_tracks.append(tracks[track_index])
	return {
		"active": true,
		"abandoned": false,
		"championship_id": championship_id,
		"cup_id": championship_id,
		"name": String(definition.get("name", championship_id)),
		"difficulty": difficulty,
		"division_id": division_id,
		"race_category_id": race_category_id,
		"category_chassis_id": category_chassis_id,
		"ruleset_id": ruleset_id,
		"grid_policy": grid_policy,
		"mixed_divisions": mixed_divisions,
		"performance_class_id": performance_class_id,
		"round_index": round_index,
		"tracks": tracks,
		"completed_tracks": completed_tracks,
		"entrants": entrants,
		"champion_id": "",
	}


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


func _sanitize_loadout(value: Variant, chassis_id: String = "") -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var output := _default_loadout(chassis_id)
	var division_id := String(GameDatabase.get_chassis(chassis_id).get("division_id", ""))
	for slot_id: String in output.keys():
		var option_id := String(source.get(slot_id, output[slot_id]))
		if not GameDatabase.get_module_option(slot_id, option_id).is_empty() and GameDatabase.is_module_allowed_for_division(option_id, division_id):
			output[slot_id] = option_id
	return output


func _sanitize_camera_view(value: String) -> String:
	return value if value in ["tps", "fps"] else "tps"


func _sanitize_grid_policy(value: String) -> String:
	# Fail closed: malformed or future policies can never silently open a grid.
	return "mixed" if value == "mixed" else "division"


func _sanitize_division(value: String) -> String:
	return value if not GameDatabase.get_division(value).is_empty() else "command"


func _sanitize_track_list(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if not value is Array:
		return output
	for raw_id: Variant in value:
		var track_id := String(raw_id)
		if GameDatabase.has_track(track_id) and track_id not in output:
			output.append(track_id)
	return output


func _fallback_chassis_id(index: int, division_id: String, grid_policy: String) -> String:
	var pool: Array[Dictionary] = GameDatabase.get_all_chassis() if grid_policy == "mixed" else GameDatabase.get_chassis_for_division(division_id)
	if pool.is_empty():
		return "biped"
	return String(pool[index % pool.size()].get("id", "biped"))


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
