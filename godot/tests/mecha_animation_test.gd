extends SceneTree
## Targeted test: godot --headless --path godot --script res://tests/mecha_animation_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const FactoryScript = preload("res://scripts/mecha/mecha_factory.gd")
const DRIVE_IDS: Array[String] = [
	"mecha_legs", "wheels", "treads", "multi_support", "sphere_drive",
	"mono_gyro", "hover_skids", "twin_antigrav", "articulated_rail", "ducted_fans",
]


var _failures: Array[String] = []
var _max_render_triangles := 0
var _max_locomotion_triangles := 0
var _max_render_meshes := 0
var _max_locomotion_meshes := 0
var _max_mesh_configuration := ""
var _max_budget_configuration := ""



func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_articulated_gait_and_body_inertia()
	_test_reduced_motion_stability()
	_test_wheel_suspension_and_rotation()
	_test_tread_link_cycle()
	_test_propulsion_variation()
	_test_polygon_budget()
	if _failures.is_empty():
		print("MECHA ANIMATION: PASS (articulated gait, inertia, suspension, tracks, fans, impacts, reduced motion, max %d/%d tris on %s, %d/%d meshes on %s)" % [_max_render_triangles, _max_locomotion_triangles, _max_budget_configuration, _max_render_meshes, _max_locomotion_meshes, _max_mesh_configuration])
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA ANIMATION: %s" % failure)
	quit(1)


func _test_articulated_gait_and_body_inertia() -> void:
	var visual := _build_visual("biped__mecha_legs__racing")
	var root_transform := visual.transform
	visual.set_motion(0.0, 0.0, false, 0.0)
	_step_visual(visual, 2)
	var segments := _group_nodes(visual, "mecha_articulated_segment")
	var joints := _group_nodes(visual, "mecha_locomotion_joint")
	var contacts := _group_nodes(visual, "mecha_locomotion_contact")
	var bodies := _group_nodes(visual, "mecha_chassis_body")
	_expect(visual.is_in_group("mecha_animated_racer"), "le RacerVisual doit exposer le groupe stable mecha_animated_racer")
	_expect(String(visual.get_meta("animation_detail_tier", "")) == "race_midpoly_cached", "le niveau de détail d'animation doit être publié")
	_expect(int(visual.get_meta("motion_animation_version", 0)) == 2, "le contrat d'animation doit être en version 2")
	_expect(String(visual.get_meta("motion_animation_budget", "")) == "cached_procedural_web", "le budget Web doit être déclaré")
	_expect(segments.size() == 6, "un bipède doit avoir 3 segments articulés par jambe")
	_expect(joints.size() == 6, "un bipède doit exposer hanche, genou et cheville par jambe")
	_expect(contacts.size() == 2, "les deux contacts plantaires doivent rester testables")
	_expect(not bodies.is_empty(), "la carrosserie inertielle doit rester présente")
	_expect(_has_segment_role(segments, "upper") and _has_segment_role(segments, "lower") and _has_segment_role(segments, "ankle"), "les rôles multi-segments doivent être complets")
	var segment_baseline := _capture_transforms(segments)
	var body_baseline := _capture_transforms(bodies)
	visual.set_motion(0.96, 0.72, true, 0.08)
	_step_visual(visual, 20)
	_expect(_count_transform_changes(segments, segment_baseline) >= 4, "la télémétrie de course doit déplacer plusieurs segments")
	_expect(_count_transform_changes(bodies, body_baseline) >= 1, "direction, accélération et boost doivent produire une inertie de carrosserie")
	_expect(visual.transform.is_equal_approx(root_transform), "l'animation interne ne doit pas écraser la pose de piste du RacerVisual")
	visual.notify_landing(9.5)
	_step_visual(visual, 1)
	var snapshot: Dictionary = visual.animation_snapshot()
	_expect(absf(float(snapshot.get("impact_offset", 0.0))) > 0.0001, "un atterrissage doit armer la suspension d'impact")
	_expect(float(snapshot.get("boost_blend", 0.0)) > 0.0, "la transition de boost doit être lissée")
	_expect(String(snapshot.get("drive_id", "")) == "mecha_legs", "le profil technologique marche doit être détecté")
	visual.free()


func _test_reduced_motion_stability() -> void:
	var visual := _build_visual("biped__mecha_legs__balanced")
	visual.set_motion(1.0, -0.85, true, 0.0)
	_step_visual(visual, 12)
	visual.notify_impact(0.9, 1.0)
	visual.set_accessibility(true)
	visual.set_motion(0.92, 0.8, false, 0.1)
	_step_visual(visual, 2)
	var controlled_nodes := _group_nodes(visual, "mecha_articulated_segment")
	controlled_nodes.append_array(_group_nodes(visual, "mecha_chassis_body"))
	var stabilized := _capture_transforms(controlled_nodes)
	_step_visual(visual, 12)
	var snapshot: Dictionary = visual.animation_snapshot()
	_expect(bool(visual.get_meta("animation_reduced_motion", false)), "l'état reduced_motion doit être exposé en métadonnée")
	_expect(bool(snapshot.get("reduced_motion", false)), "le snapshot doit confirmer reduced_motion")
	_expect(is_zero_approx(float(snapshot.get("motion_scale", 1.0))), "reduced_motion doit neutraliser les déplacements structurels")
	_expect(is_zero_approx(float(snapshot.get("impact_offset", 1.0))), "reduced_motion doit annuler les secousses d'impact")
	_expect(_count_transform_changes(controlled_nodes, stabilized) == 0, "les pièces articulées et la carrosserie doivent rester stables en mouvement réduit")
	visual.free()


func _test_wheel_suspension_and_rotation() -> void:
	var visual := _build_visual("biped__wheels__wide")
	visual.set_motion(0.0, 0.0, false, 0.0)
	_step_visual(visual, 2)
	var suspensions := _group_nodes(visual, "mecha_suspension")
	var rotors := _group_nodes(visual, "mecha_locomotion_rotor")
	_expect(suspensions.size() == 4, "le train à roues doit exposer quatre suspensions")
	_expect(rotors.size() >= 4, "chaque roue doit avoir une rotation motrice")
	var suspension_baseline := _capture_transforms(suspensions)
	var rotor_baseline := _capture_transforms(rotors)
	visual.set_motion(0.88, 0.74, false, 0.0)
	_step_visual(visual, 18)
	_expect(_count_transform_changes(suspensions, suspension_baseline) >= 2, "charge et braquage doivent animer plusieurs suspensions")
	_expect(_count_transform_changes(rotors, rotor_baseline) >= 4, "les quatre roues doivent tourner avec la vitesse")
	visual.set_motion(0.25, 0.0, false, 0.0)
	_step_visual(visual, 10)
	_expect(float(visual.animation_snapshot().get("longitudinal_load", 0.0)) < 0.0, "une décélération nette doit produire une charge de freinage")
	visual.free()


func _test_tread_link_cycle() -> void:
	var visual := _build_visual("biped__treads__endurance")
	visual.set_motion(0.0, 0.0, false, 0.0)
	_step_visual(visual, 2)
	var links := _group_nodes(visual, "mecha_track_link")
	var rollers := _group_nodes(visual, "mecha_locomotion_rotor")
	_expect(links.size() == 20, "les deux chenilles doivent exposer vingt patins cyclés")
	_expect(rollers.size() >= 6, "les galets de chenille doivent être motorisés")
	var baseline := _capture_transforms(links)
	visual.set_motion(0.82, -0.25, false, 0.0)
	_step_visual(visual, 16)
	_expect(_count_transform_changes(links, baseline) >= 16, "les patins doivent circuler autour du train de chenille")
	_expect(int(visual.animation_snapshot().get("cached_nodes", 9999)) < 220, "le cache d'un mécha à chenilles doit rester dans le budget Web/mobile")
	visual.free()


func _test_propulsion_variation() -> void:
	var fan_visual := _build_visual("biped__ducted_fans__compact")
	fan_visual.set_motion(0.0, 0.0, false, 0.0)
	_step_visual(fan_visual, 2)
	var fan_pods := _group_nodes(fan_visual, "mecha_propulsion_pod")
	var fan_rotors := _group_nodes(fan_visual, "mecha_locomotion_rotor")
	_expect(fan_pods.size() == 4, "les quatre turbines carénées doivent être montées sur pods inertiels")
	_expect(fan_rotors.size() == 4, "les pales de chaque turbine doivent partager un rotor animé")
	var idle_rotors := _capture_transforms(fan_rotors)
	_step_visual(fan_visual, 8)
	_expect(_count_transform_changes(fan_rotors, idle_rotors) == 4, "les turbines doivent conserver un régime de ralenti crédible")
	fan_visual.set_motion(1.05, 0.65, true, 0.0)
	var pod_baseline := _capture_transforms(fan_pods)
	_step_visual(fan_visual, 15)
	_expect(_count_transform_changes(fan_pods, pod_baseline) == 4, "les pods doivent anticiper virage et accélération")
	fan_visual.free()

	var antigrav_visual := _build_visual("biped__twin_antigrav__racing")
	antigrav_visual.set_motion(0.74, -0.7, true, 0.0)
	_step_visual(antigrav_visual, 10)
	_expect(_group_nodes(antigrav_visual, "mecha_propulsion_pod").size() == 2, "la technologie antigrav doit exposer deux pods indépendants")
	_expect(String(antigrav_visual.animation_snapshot().get("drive_id", "")) == "twin_antigrav", "le profil antigrav doit être détecté")
	antigrav_visual.free()


func _test_polygon_budget() -> void:
	for family_id: String in ["octopod", "centurion"]:
		var chassis: Dictionary = DatabaseScript.get_chassis(family_id)
		for drive_id: String in DRIVE_IDS:
			var configuration_id := "%s__%s__balanced" % [family_id, drive_id]
			var visual: RacerVisual = FactoryScript.build(chassis, Color("#5EE7FF"), true, {"locomotion_id": configuration_id})
			var render_triangles := int(visual.get_meta("render_triangle_count", -1))
			var locomotion_triangles := int(visual.get_meta("locomotion_triangle_count", -1))
			var render_meshes := int(visual.get_meta("render_mesh_count", -1))
			var locomotion_meshes := int(visual.get_meta("locomotion_mesh_count", -1))
			if render_triangles > _max_render_triangles:
				_max_render_triangles = render_triangles
				_max_budget_configuration = configuration_id
			_max_locomotion_triangles = maxi(_max_locomotion_triangles, locomotion_triangles)
			if render_meshes > _max_render_meshes:
				_max_render_meshes = render_meshes
				_max_mesh_configuration = configuration_id
			_max_locomotion_meshes = maxi(_max_locomotion_meshes, locomotion_meshes)
			_expect(render_triangles > 0 and locomotion_triangles > 0, "les compteurs polygonaux réels doivent être publiés pour %s" % configuration_id)
			_expect(render_triangles <= 50000, "%s dépasse le budget race de 50k triangles: %d" % [configuration_id, render_triangles])
			_expect(String(visual.get_meta("triangle_budget_status", "")) == "race", "le statut de budget doit être race pour %s" % configuration_id)
			_expect(int(visual.get_meta("triangle_budget_race", 0)) == 50000 and int(visual.get_meta("triangle_budget_hero", 0)) == 70000, "les seuils publiés sont incohérents pour %s" % configuration_id)
			_expect(render_meshes > 0 and locomotion_meshes > 0, "les compteurs de meshes réels doivent être publiés pour %s" % configuration_id)
			_expect(render_meshes <= 140, "%s dépasse le budget race de 140 meshes: %d" % [configuration_id, render_meshes])
			_expect(String(visual.get_meta("mesh_budget_status", "")) == "race", "le statut de draw calls doit être race pour %s" % configuration_id)
			_expect(int(visual.get_meta("mesh_budget_race", 0)) == 140 and int(visual.get_meta("mesh_budget_hero", 0)) == 200, "les plafonds de meshes sont incohérents pour %s" % configuration_id)
			visual.free()


func _build_visual(configuration_id: String) -> RacerVisual:
	var chassis: Dictionary = DatabaseScript.get_chassis("biped")
	var visual: RacerVisual = FactoryScript.build(chassis, Color("#5EE7FF"), true, {"locomotion_id": configuration_id})
	visual.set_process(false)
	get_root().add_child(visual)
	return visual


func _step_visual(visual: RacerVisual, frame_count: int) -> void:
	for _frame in range(frame_count):
		visual.call("_process", 1.0 / 60.0)


func _group_nodes(node: Node, group_name: StringName) -> Array[Node3D]:
	var result: Array[Node3D] = []
	_collect_group_nodes(node, group_name, result)
	return result


func _collect_group_nodes(node: Node, group_name: StringName, result: Array[Node3D]) -> void:
	if node is Node3D and node.is_in_group(group_name):
		result.append(node as Node3D)
	for child: Node in node.get_children():
		_collect_group_nodes(child, group_name, result)


func _capture_transforms(nodes: Array[Node3D]) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for node: Node3D in nodes:
		result.append(node.transform)
	return result


func _count_transform_changes(nodes: Array[Node3D], baseline: Array[Transform3D]) -> int:
	var changed := 0
	for index in range(mini(nodes.size(), baseline.size())):
		if not nodes[index].transform.is_equal_approx(baseline[index]):
			changed += 1
	return changed


func _has_segment_role(nodes: Array[Node3D], role: String) -> bool:
	for node: Node3D in nodes:
		if String(node.get_meta("segment_role", "")) == role:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
