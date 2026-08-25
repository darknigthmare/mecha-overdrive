extends SceneTree
## Targeted test: godot --headless --path godot --script res://tests/locomotion_catalog_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const CatalogScript = preload("res://scripts/data/locomotion_catalog.gd")
const FactoryScript = preload("res://scripts/mecha/mecha_factory.gd")
const SaveScript = preload("res://scripts/systems/save_system.gd")
const GarageScene = preload("res://scenes/garage.tscn")

const REQUIRED_DRIVES: Array[String] = [
	"mecha_legs", "wheels", "treads", "multi_support", "sphere_drive", "twin_antigrav",
]
const SUPPORT_COUNTS := {
	"biped": 2, "tripod": 3, "quadruped": 4, "hexapod": 6, "octopod": 8,
	"hover": 4, "tracked": 4, "monowheel": 2, "orb": 4, "centurion": 12,
}
const ANTIGRAV_TEXTURE := "res://assets/textures/openai/locomotion_antigrav.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_catalogue_volume()
	_test_resolution_and_compatibility()
	_test_procedural_visuals()
	_test_family_support_contract()
	_test_aether_texture()
	await _test_save_migration_and_garage_selector()
	if _failures.is_empty():
		print("MECHA LOCOMOTION: PASS (10 families, 50 configurations/family, 500 total, native isolation, family contacts, Aether texture)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA LOCOMOTION: %s" % failure)
	quit(1)


func _test_catalogue_volume() -> void:
	_expect(CatalogScript.get_family_ids().size() == 10, "le catalogue doit conserver les 10 familles")
	_expect(CatalogScript.get_drive_options().size() == 10, "10 technologies motrices sont attendues")
	_expect(CatalogScript.get_mount_options().size() == 5, "5 géométries de montage sont attendues")
	_expect(CatalogScript.get_total_configuration_count() == 500, "le catalogue doit exposer 500 configurations")
	var global_ids := {}
	for family_id: String in CatalogScript.get_family_ids():
		var configurations: Array[Dictionary] = CatalogScript.get_configurations_for_family(family_id)
		_expect(configurations.size() == 50, "%s doit proposer exactement 50 configurations" % family_id)
		var seen_drives := {}
		for configuration: Dictionary in configurations:
			var configuration_id := String(configuration.get("id", ""))
			_expect(not configuration_id.is_empty() and not global_ids.has(configuration_id), "identifiant absent ou dupliqué: %s" % configuration_id)
			global_ids[configuration_id] = true
			seen_drives[String(configuration.get("drive_id", ""))] = true
			_expect(String(configuration.get("family_id", "")) == family_id, "famille incohérente: %s" % configuration_id)
			_expect(Dictionary(configuration.get("stats", {})).size() == 6, "statistiques incomplètes: %s" % configuration_id)
			_expect(int(configuration.get("cost", -1)) >= 0, "coût invalide: %s" % configuration_id)
			_expect(not String(configuration.get("lore", "")).is_empty(), "lore absent: %s" % configuration_id)
		for drive_id: String in REQUIRED_DRIVES:
			_expect(seen_drives.has(drive_id), "%s ne propose pas %s" % [family_id, drive_id])
	_expect(global_ids.size() == 500, "les 500 configurations doivent être uniques")
	var catalogue_text := JSON.stringify(CatalogScript.get_drive_options()).to_lower()
	_expect("star wars" not in catalogue_text, "la gamme antigrav doit rester une création originale")


func _test_resolution_and_compatibility() -> void:
	for chassis: Dictionary in DatabaseScript.get_all_chassis():
		var chassis_id := String(chassis.get("id", ""))
		var default_id := CatalogScript.get_default_configuration_id(chassis_id)
		var resolved: Dictionary = CatalogScript.resolve_configuration(chassis, {})
		_expect(String(resolved.get("id", "")) == default_id, "une ancienne sauvegarde doit recevoir le montage constructeur: %s" % chassis_id)
		var selected_id := "%s__twin_antigrav__racing" % chassis_id
		var selected := CatalogScript.resolve_configuration(chassis, {"locomotion_id": selected_id})
		_expect(String(selected.get("id", "")) == selected_id, "sélection antigrav perdue: %s" % chassis_id)
		var foreign := CatalogScript.resolve_configuration(chassis, {"locomotion_id": "biped__wheels__wide"})
		if chassis_id != "biped":
			_expect(String(foreign.get("id", "")) == default_id, "un montage d'une autre famille ne doit pas traverser la sauvegarde")


func _test_procedural_visuals() -> void:
	var chassis: Dictionary = DatabaseScript.get_chassis("biped")
	for drive_id: String in REQUIRED_DRIVES:
		var configuration_id := "biped__%s__wide" % drive_id
		var visual: RacerVisual = FactoryScript.build(
			chassis,
			Color(String(chassis.get("paint", "#5EE7FF"))),
			true,
			{"locomotion_id": configuration_id}
		)
		get_root().add_child(visual)
		_expect(String(visual.get_meta("locomotion_id", "")) == configuration_id, "MechaFactory n'applique pas %s" % drive_id)
		_expect(_count_group(visual, "mecha_locomotion_module") == 1, "un seul support configuré est attendu pour %s" % drive_id)
		_expect(_count_group(visual, "mecha_native_locomotion") == 1, "la locomotion native doit être isolée pour %s" % drive_id)
		_expect(_count_group(visual, "mecha_native_locomotion_part") > 0, "les pièces natives doivent être marquées pour %s" % drive_id)
		_expect(_all_group_hidden(visual, "mecha_native_locomotion") and _all_group_hidden(visual, "mecha_native_locomotion_part"), "superposition native détectée pour %s" % drive_id)
		_expect(bool(visual.get_meta("native_locomotion_suppressed", false)), "le remplacement natif n'est pas déclaré pour %s" % drive_id)
		_expect(_count_group(visual, "mecha_chassis_body") > 0, "la carrosserie a été supprimée pour %s" % drive_id)
		_expect(visual.get_node_or_null("CockpitCanopy") != null, "le cockpit a été supprimé pour %s" % drive_id)
		_expect(_count_group(visual, "mecha_module_core") == 1 and _count_group(visual, "mecha_module_mobility") == 1 and _count_group(visual, "mecha_module_utility") == 1, "les modules ont été supprimés pour %s" % drive_id)
		_expect(_count_group(visual, "mecha_locomotion_part") >= 4, "silhouette procédurale insuffisante pour %s" % drive_id)
		if drive_id in ["wheels", "treads", "sphere_drive"]:
			_expect(_count_group(visual, "mecha_locomotion_rotor") >= 4, "contacts animés absents pour %s" % drive_id)
		visual.set_camera_mode("fps")
		visual.set_motion(0.8, 0.2, false, 0.95)
		visual.call("_process", 0.2)
		visual.set_camera_mode("tps")
		_expect(_all_group_hidden(visual, "mecha_native_locomotion") and _all_group_hidden(visual, "mecha_native_locomotion_part"), "caméra ou dégâts ont réactivé la locomotion native pour %s" % drive_id)
		visual.free()


func _test_family_support_contract() -> void:
	for family_id: String in SUPPORT_COUNTS.keys():
		var chassis: Dictionary = DatabaseScript.get_chassis(family_id)
		var expected := int(SUPPORT_COUNTS[family_id])
		for drive_id: String in ["mecha_legs", "multi_support"]:
			var configuration_id := "%s__%s__balanced" % [family_id, drive_id]
			var visual: RacerVisual = FactoryScript.build(
				chassis,
				Color(String(chassis.get("paint", "#5EE7FF"))),
				false,
				{"locomotion_id": configuration_id}
			)
			var configured_holder: Node = _find_group_node(visual, "mecha_locomotion_module")
			_expect(configured_holder != null, "holder configuré absent: %s" % configuration_id)
			if configured_holder != null:
				_expect(int(configured_holder.get_meta("support_count", -1)) == expected, "meta appuis incorrecte: %s" % configuration_id)
			_expect(_count_group(visual, "mecha_locomotion_contact") == expected, "%s doit créer %d contacts testables" % [configuration_id, expected])
			_expect(_count_group(visual, "mecha_chassis_body") > 0, "carrosserie perdue: %s" % configuration_id)
			var first_person: Dictionary = chassis.get("first_person", {}) if chassis.get("first_person", {}) is Dictionary else {}
			if String(first_person.get("mode", "cockpit")) == "sensorium":
				_expect(visual.get_node_or_null("CockpitCanopy") == null, "un robot distant ne doit pas recevoir de verrière: %s" % configuration_id)
				_expect(visual.get_node_or_null("SensorOrigin") != null, "origine sensorium perdue: %s" % configuration_id)
			else:
				_expect(visual.get_node_or_null("CockpitCanopy") != null, "cockpit perdu: %s" % configuration_id)
			_expect(_count_group(visual, "mecha_module_core") == 1 and _count_group(visual, "mecha_module_mobility") == 1 and _count_group(visual, "mecha_module_utility") == 1, "modules perdus: %s" % configuration_id)
			_expect(_all_group_hidden(visual, "mecha_native_locomotion"), "locomotion native visible: %s" % configuration_id)
			visual.free()


func _test_aether_texture() -> void:
	var chassis: Dictionary = DatabaseScript.get_chassis("biped")
	var visual: RacerVisual = FactoryScript.build(chassis, Color("#5EE7FF"), true, {"locomotion_id": "biped__twin_antigrav__racing"})
	var holder: Node = _find_group_node(visual, "mecha_locomotion_module")
	_expect(holder != null, "holder Aether absent")
	if holder != null:
		_expect(String(holder.get_meta("drive_id", "")) == "twin_antigrav", "drive Aether incohérent")
		_expect(String(holder.get_meta("surface_texture_path", "")) == ANTIGRAV_TEXTURE, "la texture Aether n'est pas sélectionnée")
		_expect(bool(holder.get_meta("uses_antigrav_texture", false)), "la meta texture Aether n'est pas active")
	_expect(_has_active_texture(visual, ANTIGRAV_TEXTURE), "locomotion_antigrav.png n'est liée à aucun mesh Aether")
	visual.free()


func _test_save_migration_and_garage_selector() -> void:
	var service: SaveSystemService = SaveScript.new()
	service.name = "SaveSystem"
	var suffix := str(Time.get_ticks_usec())
	service._save_path = "user://locomotion_%s.json" % suffix
	service._temp_path = "user://locomotion_%s.tmp" % suffix
	service._backup_path = "user://locomotion_%s.backup.json" % suffix
	service._corrupt_path = "user://locomotion_%s.corrupt.json" % suffix
	service._backup_corrupt_path = "user://locomotion_%s.backup.corrupt.json" % suffix
	var existing_save := get_root().get_node_or_null("SaveSystem")
	if existing_save != null:
		get_root().remove_child(existing_save)
	get_root().add_child(service)
	var migrated: Dictionary = service.call("_sanitize_profile", {"version": 4, "pilot_name": "MIGRATION"})
	_expect(int(migrated.get("version", 0)) == 5, "la migration locomotion doit produire une sauvegarde v5")
	var migrated_locomotions: Dictionary = migrated.get("locomotions", {}) if migrated.get("locomotions", {}) is Dictionary else {}
	_expect(migrated_locomotions.size() == 10, "la migration doit créer une locomotion par châssis")
	for family_id: String in CatalogScript.get_family_ids():
		_expect(String(migrated_locomotions.get(family_id, "")) == CatalogScript.get_default_configuration_id(family_id), "montage constructeur de migration absent: %s" % family_id)

	service.profile = migrated
	service.profile["credits"] = 10000
	var loadout: Dictionary = DatabaseScript.get_chassis("biped").get("default_loadout", {})
	var antigrav_id := "biped__twin_antigrav__racing"
	_expect(service.purchase_and_apply_garage("biped", "#5EE7FF", loadout, antigrav_id), "l'application atomique doit sauvegarder la locomotion")
	_expect(service.get_locomotion("biped") == antigrav_id, "la locomotion sauvegardée doit être relue")
	_expect(not service.set_locomotion("tripod", "biped__wheels__wide"), "une locomotion d'une autre famille doit être refusée")

	var garage := GarageScene.instantiate()
	get_root().add_child(garage)
	await process_frame
	var selector := garage.find_child("LocomotionOption", true, false) as OptionButton
	var initial_selected := String(selector.get_item_metadata(selector.selected)) if selector != null and selector.selected >= 0 else "NONE"
	var initial_draft := String(garage.get("_draft_locomotion_id"))
	_expect(selector != null, "le garage doit exposer LocomotionOption")
	if selector != null:
		_expect(selector.item_count == 50, "le sélecteur garage doit être filtré aux 50 configurations du châssis actif")
		_expect(initial_selected == antigrav_id and initial_draft == antigrav_id, "le garage doit sélectionner la locomotion sauvegardée")
		var wheels_index := _find_option_metadata(selector, "biped__wheels__compact")
		_expect(wheels_index >= 0, "la variante bipède à roues doit être visible dans le garage")
		if wheels_index >= 0:
			selector.select(wheels_index)
			selector.item_selected.emit(wheels_index)
			_expect(String(garage.get("_draft_locomotion_id")) == "biped__wheels__compact", "la sélection doit mettre à jour le brouillon instantanément")
			var preview := garage.find_child("GaragePreview", true, false)
			_expect(preview != null and _count_group(preview, "mecha_locomotion_module") == 1, "l'aperçu 3D doit reconstruire la locomotion sélectionnée")
			garage.call("_apply_draft")
			_expect(service.get_locomotion("biped") == "biped__wheels__compact", "APPLIQUER doit persister le choix du garage")
	garage.free()
	get_root().remove_child(service)
	service.free()
	if existing_save != null:
		get_root().add_child(existing_save)
	for path: String in [
		"user://locomotion_%s.json" % suffix,
		"user://locomotion_%s.tmp" % suffix,
		"user://locomotion_%s.backup.json" % suffix,
		"user://locomotion_%s.corrupt.json" % suffix,
		"user://locomotion_%s.backup.corrupt.json" % suffix,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _find_option_metadata(option_button: OptionButton, requested: String) -> int:
	for index in range(option_button.item_count):
		if String(option_button.get_item_metadata(index)) == requested:
			return index
	return -1


func _count_group(node: Node, group_name: StringName) -> int:
	var count := 1 if node.is_in_group(group_name) else 0
	for child: Node in node.get_children():
		count += _count_group(child, group_name)
	return count


func _find_group_node(node: Node, group_name: StringName) -> Node:
	if node.is_in_group(group_name):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_group_node(child, group_name)
		if found != null:
			return found
	return null


func _all_group_hidden(node: Node, group_name: StringName) -> bool:
	if node.is_in_group(group_name) and node is Node3D and (node as Node3D).visible:
		return false
	for child: Node in node.get_children():
		if not _all_group_hidden(child, group_name):
			return false
	return true


func _has_active_texture(node: Node, expected_path: String) -> bool:
	if node is MeshInstance3D:
		var material := (node as MeshInstance3D).material_override as StandardMaterial3D
		if material != null and String(material.get_meta("texture_path", "")) == expected_path:
			return material.albedo_texture != null
	for child: Node in node.get_children():
		if _has_active_texture(child, expected_path):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
