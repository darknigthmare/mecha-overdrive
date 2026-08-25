extends SceneTree
## Targeted first-person presentation contract:
## godot --headless --path godot --script res://tests/fps_presentation_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const MechaFactoryScript = preload("res://scripts/mecha/mecha_factory.gd")

const EXPECTED_MODES := {
	"biped": "cockpit",
	"tripod": "cockpit",
	"quadruped": "cockpit",
	"hexapod": "sensorium",
	"octopod": "cockpit",
	"hover": "cockpit",
	"tracked": "cockpit",
	"monowheel": "cockpit",
	"orb": "sensorium",
	"centurion": "sensorium",
}
const REQUIRED_FIRST_PERSON_FIELDS: Array[String] = [
	"mode", "profile", "label", "fov", "operator_presence",
]
const COCKPIT_MESH_BUDGET := 24
const COCKPIT_TRIANGLE_BUDGET := 3500

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run_tests")


func _run_tests() -> void:
	_test_chassis_and_factory_contract()
	await _test_hud_contract()
	if _failures.is_empty():
		print("MECHA FPS PRESENTATION: PASS (10 profiles, 7 pilot cockpits, 3 autonomous sensoriums, exclusive geometry, anchors, Web budgets, desktop/mobile HUD)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA FPS PRESENTATION: %s" % failure)
	quit(1)


func _test_chassis_and_factory_contract() -> void:
	_expect(DatabaseScript.CHASSIS.size() == EXPECTED_MODES.size(), "la base doit publier exactement les dix architectures homologuées")
	var mode_counts := {"cockpit": 0, "sensorium": 0}
	for chassis: Dictionary in DatabaseScript.CHASSIS:
		var chassis_id := String(chassis.get("id", "unknown"))
		var expected_mode := String(EXPECTED_MODES.get(chassis_id, ""))
		_expect(not expected_mode.is_empty(), "%s : architecture absente du contrat FPS" % chassis_id)

		var first_person_value: Variant = chassis.get("first_person", {})
		var first_person: Dictionary = {}
		if first_person_value is Dictionary:
			first_person = Dictionary(first_person_value)
		_expect(not first_person.is_empty(), "%s : fiche first_person absente" % chassis_id)
		for field_name: String in REQUIRED_FIRST_PERSON_FIELDS:
			_expect(first_person.has(field_name), "%s : first_person.%s absent" % [chassis_id, field_name])
		var mode := String(first_person.get("mode", ""))
		_expect(mode == expected_mode, "%s : mode FPS %s au lieu de %s" % [chassis_id, mode, expected_mode])
		if mode_counts.has(mode):
			mode_counts[mode] = int(mode_counts[mode]) + 1
		_expect(not String(first_person.get("profile", "")).is_empty(), "%s : profil de présentation FPS vide" % chassis_id)
		_expect(not String(first_person.get("label", "")).is_empty(), "%s : libellé de vue FPS vide" % chassis_id)
		_expect(not String(first_person.get("operator_presence", "")).is_empty(), "%s : présence opérateur non documentée" % chassis_id)
		var fov := float(first_person.get("fov", 0.0))
		_expect(fov >= 55.0 and fov <= 110.0, "%s : FOV %.1f hors enveloppe jouable" % [chassis_id, fov])

		var loadout_value: Variant = chassis.get("default_loadout", {})
		var loadout: Dictionary = Dictionary(loadout_value).duplicate(true) if loadout_value is Dictionary else {}
		var visual := MechaFactoryScript.build(
			chassis,
			Color(String(chassis.get("paint", "#5EE7FF"))),
			true,
			loadout
		) as Node3D
		root.add_child(visual)
		_expect(String(visual.get_meta("first_person_mode", "")) == mode, "%s : meta first_person_mode désynchronisée" % chassis_id)
		_expect(String(visual.get_meta("first_person_profile", "")) == String(first_person.get("profile", "")), "%s : meta first_person_profile désynchronisée" % chassis_id)
		_expect(String(visual.get_meta("operator_presence", "")) == String(first_person.get("operator_presence", "")), "%s : meta operator_presence désynchronisée" % chassis_id)

		var fps_anchor := visual.call(&"camera_anchor", "fps") as Marker3D
		var tps_anchor := visual.call(&"camera_anchor", "tps") as Marker3D
		_expect(fps_anchor != null and fps_anchor.name == &"CameraFPS", "%s : ancre CameraFPS absente" % chassis_id)
		_expect(tps_anchor != null and tps_anchor.name == &"CameraTPS", "%s : ancre CameraTPS absente" % chassis_id)
		if fps_anchor != null and tps_anchor != null:
			_expect(fps_anchor.position.distance_to(tps_anchor.position) >= 1.0, "%s : ancres FPS/TPS indifférenciées" % chassis_id)

		var cockpit_root := visual.find_child("FPSInteriorRoot", true, false)
		var cockpit_canopy := visual.find_child("CockpitCanopy", true, false)
		var sensor_origin := visual.find_child("SensorOrigin", true, false)
		var pilot_cockpit_count := _group_node_count(visual, &"mecha_pilot_cockpit")
		var cockpit_interior_count := _group_node_count(visual, &"mecha_cockpit_interior")
		var sensor_array_count := _group_node_count(visual, &"mecha_sensor_array")
		if mode == "cockpit":
			_expect(cockpit_root != null, "%s : FPSInteriorRoot absent du châssis piloté" % chassis_id)
			_expect(cockpit_canopy != null, "%s : verrière CockpitCanopy absente du châssis piloté" % chassis_id)
			_expect(sensor_origin == null and sensor_array_count == 0, "%s : un cockpit piloté embarque par erreur le sensorium autonome" % chassis_id)
			_expect(pilot_cockpit_count > 0, "%s : groupe mecha_pilot_cockpit vide" % chassis_id)
			_expect(cockpit_interior_count > 0, "%s : groupe mecha_cockpit_interior vide" % chassis_id)
			if cockpit_root != null:
				var cockpit_meshes := _mesh_count(cockpit_root)
				var cockpit_triangles := _triangle_count(cockpit_root)
				_expect(cockpit_meshes > 0 and cockpit_meshes <= COCKPIT_MESH_BUDGET, "%s : cockpit hors budget meshes (%d/%d)" % [chassis_id, cockpit_meshes, COCKPIT_MESH_BUDGET])
				_expect(cockpit_triangles > 0 and cockpit_triangles <= COCKPIT_TRIANGLE_BUDGET, "%s : cockpit hors budget triangles (%d/%d)" % [chassis_id, cockpit_triangles, COCKPIT_TRIANGLE_BUDGET])
				_validate_optional_metric(visual, &"first_person_mesh_count", cockpit_meshes, chassis_id)
				_validate_optional_metric(visual, &"first_person_triangle_count", cockpit_triangles, chassis_id)
			visual.call(&"set_camera_mode", "fps")
			_expect(_visible_group_node_count(visual, &"mecha_cockpit_interior") > 0, "%s : intérieur invisible après passage FPS" % chassis_id)
			visual.call(&"set_camera_mode", "tps")
			_expect(_visible_group_node_count(visual, &"mecha_cockpit_interior") == 0, "%s : intérieur cockpit encore visible en TPS" % chassis_id)
		else:
			_expect(cockpit_root == null and cockpit_canopy == null, "%s : le robot autonome conserve un cockpit de pilote" % chassis_id)
			_expect(pilot_cockpit_count == 0 and cockpit_interior_count == 0, "%s : groupes cockpit présents sur le robot autonome" % chassis_id)
			_expect(sensor_origin != null, "%s : SensorOrigin absent du robot autonome" % chassis_id)
			_expect(sensor_array_count > 0, "%s : groupe extérieur mecha_sensor_array vide" % chassis_id)
		visual.free()

	_expect(int(mode_counts.get("cockpit", 0)) == 7, "la flotte doit contenir sept châssis pilotés")
	_expect(int(mode_counts.get("sensorium", 0)) == 3, "la flotte doit contenir trois robots autonomes")


func _test_hud_contract() -> void:
	var hud_script := load("res://scripts/ui/race_hud.gd") as GDScript
	_expect(hud_script != null and hud_script.can_instantiate(), "RaceHUD et ses dépendances doivent compiler avant le test de présentation")
	if hud_script == null or not hud_script.can_instantiate():
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var hud: Control = hud_script.new() as Control
	viewport.add_child(hud)
	await process_frame
	await process_frame
	var hud_contract_ready := (
		hud.has_method(&"first_person_interface_mode")
		and hud.has_method(&"sensor_overlay_visible")
	)
	_expect(hud_contract_ready, "RaceHUD doit exposer first_person_interface_mode() et sensor_overlay_visible()")
	if not hud_contract_ready:
		viewport.queue_free()
		await process_frame
		return

	var base_snapshot := {
		"lap": 1,
		"laps": 3,
		"position": 1,
		"racers": 8,
		"elapsed": 12.45,
		"speed_kmh": 286.0,
		"heat": 0.41,
		"armor": 92.0,
		"max_armor": 100.0,
		"item_id": "",
	}

	hud.call(&"configure", {"mode": "quick", "track_id": "foundry", "racer_count": 8, "chassis_id": "biped"})
	hud.call(&"update_race", base_snapshot.merged({"chassis_id": "biped", "camera_view": "fps"}, true))
	await process_frame
	_expect(String(hud.call(&"first_person_interface_mode")) == "cockpit", "le HUD doit sélectionner le cockpit pour Raptor R2")
	_expect(not bool(hud.call(&"sensor_overlay_visible")), "le sensorium ne doit pas recouvrir un cockpit piloté")
	var item_label := hud.get("_item_label") as Label
	_expect(item_label != null and item_label.text.contains("VUE COCKPIT"), "la télémétrie doit annoncer la vue cockpit")

	hud.call(&"configure", {"mode": "quick", "track_id": "foundry", "racer_count": 8, "chassis_id": "hexapod"})
	hud.call(&"update_race", base_snapshot.merged({"chassis_id": "hexapod", "camera_view": "fps"}, true))
	await process_frame
	_expect(String(hud.call(&"first_person_interface_mode")) == "sensorium", "le HUD doit sélectionner le sensorium pour Mantis H6")
	_expect(bool(hud.call(&"sensor_overlay_visible")), "le sensorium autonome doit être visible en FPS")
	item_label = hud.get("_item_label") as Label
	_expect(item_label != null and item_label.text.contains("VUE ") and not item_label.text.contains("VUE COCKPIT"), "la télémétrie autonome ne doit pas annoncer un faux cockpit")
	var sensor_overlay := _find_sensor_overlay(hud)
	_expect(sensor_overlay != null, "le HUD autonome doit exposer un overlay sensorium identifiable")
	if sensor_overlay != null:
		_expect(sensor_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "le sensorium doit laisser passer toutes les commandes")
		_expect(sensor_overlay.visible, "l’overlay sensorium identifié doit être visible en FPS")
		_expect(_non_empty_label_count(sensor_overlay) >= 2, "le sensorium doit afficher au moins deux diagnostics lisibles")

	hud.call(&"update_race", base_snapshot.merged({"chassis_id": "hexapod", "camera_view": "tps"}, true))
	await process_frame
	_expect(String(hud.call(&"first_person_interface_mode")) == "tps", "la vue externe doit restaurer le mode HUD TPS")
	_expect(not bool(hud.call(&"sensor_overlay_visible")), "le sensorium doit disparaître en TPS")
	item_label = hud.get("_item_label") as Label
	_expect(item_label != null and item_label.text.contains("VUE TPS"), "la télémétrie doit annoncer le retour TPS")

	viewport.size = Vector2i(844, 390)
	hud.call(&"force_mobile_controls", true)
	hud.call(&"update_race", base_snapshot.merged({"chassis_id": "orb", "camera_view": "fps"}, true))
	await process_frame
	await process_frame
	_expect(bool(hud.call(&"mobile_controls_visible")), "les commandes tactiles forcées doivent rester actives avec le sensorium")
	_expect(String(hud.call(&"first_person_interface_mode")) == "sensorium" and bool(hud.call(&"sensor_overlay_visible")), "Orb S7 doit conserver son sensorium en paysage mobile compact")
	sensor_overlay = _find_sensor_overlay(hud)
	if sensor_overlay != null:
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
		var overlay_rect := Rect2(sensor_overlay.position, sensor_overlay.size)
		_expect(sensor_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "le sensorium mobile ne doit capturer aucun toucher")
		_expect(overlay_rect.size.x > 0.0 and overlay_rect.size.y > 0.0 and viewport_rect.encloses(overlay_rect), "le sensorium mobile doit rester dans le viewport 844x390")
	var first_person_overlay := hud.get("_first_person_overlay") as Control
	var mobile_left_panel := first_person_overlay.get("_sensor_left_panel") as Control if first_person_overlay != null else null
	var mobile_right_panel := first_person_overlay.get("_sensor_right_panel") as Control if first_person_overlay != null else null
	_expect(mobile_left_panel != null and not mobile_left_panel.visible, "le diagnostic gauche doit se replier en paysage mobile compact")
	_expect(mobile_right_panel != null and not mobile_right_panel.visible, "le diagnostic droit doit se replier en paysage mobile compact")
	var mobile_sensor_header := first_person_overlay.get("_sensor_header") as Label if first_person_overlay != null else null
	_expect(mobile_sensor_header != null and mobile_sensor_header.offset_top >= 150.0, "le titre sensorium compact doit rester sous l’en-tête de course")

	viewport.queue_free()
	await process_frame


func _find_sensor_overlay(hud: Node) -> Control:
	for candidate: Node in hud.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control == null:
			continue
		var normalized_name := String(control.name).to_lower()
		if control.is_in_group(&"mecha_sensorium_hud") or (normalized_name.contains("sensor") and normalized_name.contains("overlay")):
			return control
	return null


func _group_node_count(node: Node, group_name: StringName) -> int:
	var count := 1 if node.is_in_group(group_name) else 0
	for child: Node in node.get_children():
		count += _group_node_count(child, group_name)
	return count


func _visible_group_node_count(node: Node, group_name: StringName) -> int:
	var count := 0
	if node is Node3D and node.is_in_group(group_name) and (node as Node3D).visible:
		count = 1
	for child: Node in node.get_children():
		count += _visible_group_node_count(child, group_name)
	return count


func _mesh_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _mesh_count(child)
	return count


func _triangle_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			count += mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		count += _triangle_count(child)
	return count


func _validate_optional_metric(visual: Node, meta_name: StringName, measured: int, chassis_id: String) -> void:
	if visual.has_meta(meta_name):
		_expect(int(visual.get_meta(meta_name, -1)) == measured, "%s : meta %s incohérente avec la géométrie réelle" % [chassis_id, meta_name])


func _non_empty_label_count(node: Node) -> int:
	var count := 1 if node is Label and not (node as Label).text.strip_edges().is_empty() else 0
	for child: Node in node.get_children():
		count += _non_empty_label_count(child)
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
