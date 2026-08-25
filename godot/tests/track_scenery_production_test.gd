extends SceneTree
## Production scenery regression suite.
## Run with: godot --headless --path godot --script res://tests/track_scenery_production_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const TrackFactoryScript = preload("res://scripts/world/track_factory.gd")
const TrackProfilesScript = preload("res://scripts/visual/track_visual_profiles.gd")
const TrackSafetyScript = preload("res://scripts/world/track_safety.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var signatures: Dictionary = {}
	var foundry_fingerprint := ""
	for spec: Dictionary in DatabaseScript.get_all_tracks():
		var track_id := String(spec.get("id", "unknown"))
		var profile := TrackProfilesScript.scenery_profile(spec)
		var signature := String(profile.get("signature", ""))
		_expect(not signature.is_empty(), "%s doit publier une signature de décor" % track_id)
		_expect(not signatures.has(signature), "signature de décor répétée : %s" % signature)
		signatures[signature] = track_id
		_expect(float(profile.get("clearance", 0.0)) >= 7.5, "%s doit conserver au moins 7,5 m hors chaussée" % track_id)
		_expect(int(profile.get("animated_props", -1)) == 0, "%s ne doit pas imposer d’animation décorative au mode mouvement réduit" % track_id)

		var track: Node3D = TrackFactoryScript.build(spec)
		var scenery := track.get_node_or_null("Scenery") as Node3D
		_expect(scenery != null, "%s doit générer un nœud Scenery" % track_id)
		if scenery == null:
			track.free()
			continue
		var report_value: Variant = track.get_meta("scenery_report", {})
		var report: Dictionary = Dictionary(report_value) if report_value is Dictionary else {}
		var actual_descendants := _count_descendants(scenery)
		var node_budget := int(report.get("node_budget", 0))
		_expect(String(track.get_meta("environment_detail_tier", "")) == "production_web", "%s doit publier le tier production_web" % track_id)
		_expect(scenery.is_in_group(&"track_production_detail"), "%s doit exposer le groupe track_production_detail" % track_id)
		_expect(actual_descendants == int(report.get("actual_descendants", -1)), "%s doit mesurer ses descendants réels" % track_id)
		_expect(node_budget > 0 and actual_descendants <= node_budget, "%s dépasse le budget Web/mobile : %d/%d" % [track_id, actual_descendants, node_budget])
		_expect(int(track.get_meta("web_prop_budget", -1)) == node_budget, "%s doit exposer son budget sur la racine" % track_id)
		_expect(int(track.get_meta("detail_prop_count", 0)) >= 70, "%s doit fournir une densité de production explicite" % track_id)
		_expect(float(report.get("minimum_clearance", 0.0)) >= 7.5, "%s doit reporter sa marge de sécurité" % track_id)
		_expect(float(track.get_meta("width", 0.0)) >= TrackSafetyScript.minimum_road_width(), "%s ne doit jamais rétrécir la piste" % track_id)
		_expect(String(report.get("signature", "")) == signature, "%s doit conserver sa signature du profil au runtime" % track_id)
		_assert_structure(scenery, track_id, report)
		_assert_trackside_clearance(scenery, float(track.get_meta("width", 0.0)), float(report.get("minimum_clearance", 0.0)), track_id)
		_assert_render_contract(scenery, track_id, report)
		_expect(not _contains_animation_player(scenery), "%s ne doit pas animer le décor sans réglage reduced_motion" % track_id)
		var start_complex := track.get_meta("start_complex", null) as Node3D
		_expect(start_complex != null and start_complex.is_in_group(&"track_production_detail"), "%s doit exposer le paddock de départ en production detail" % track_id)
		if start_complex != null:
			var foreground_mesh_count := _count_geometry_instances(start_complex)
			_expect(foreground_mesh_count >= 40 and foreground_mesh_count == int(track.get_meta("start_complex_mesh_count", -1)), "%s doit publier le nombre réel de meshes du paddock" % track_id)
			_assert_start_complex_clearance(start_complex, float(track.get_meta("width", 0.0)), float(report.get("minimum_clearance", 0.0)), track_id)
			_assert_geometry_contract(start_complex, float(report.get("foreground_lod", 0.0)), track_id)
		var infrastructure_root := scenery.get_node_or_null("TrackInfrastructure")
		var uses_infrastructure_texture := _contains_infrastructure_texture(infrastructure_root)
		if start_complex != null:
			uses_infrastructure_texture = uses_infrastructure_texture or _contains_infrastructure_texture(start_complex)
		_expect(uses_infrastructure_texture, "%s doit charger réellement track_infrastructure_detail.png" % track_id)
		print(
			"SCENERY %s [%s]: %d/%d descendants, %d logical props, %d silhouettes, %d start meshes" % [
				track_id, signature, actual_descendants, node_budget,
				int(track.get_meta("detail_prop_count", 0)), int(report.get("background_silhouettes", 0)),
				int(track.get_meta("start_complex_mesh_count", 0)),
			]
		)
		if track_id == "foundry":
			foundry_fingerprint = _layout_fingerprint(scenery)
		track.free()

	_expect(signatures.size() == 8, "les huit circuits doivent avoir huit signatures de biome distinctes")
	_test_determinism(foundry_fingerprint)
	_test_detail_tiers()
	_test_budget_guardrails()
	if _failures.is_empty():
		print("MECHA TRACK SCENERY PRODUCTION: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("MECHA TRACK SCENERY PRODUCTION: %s" % failure)
	quit(1)


func _assert_structure(scenery: Node3D, track_id: String, report: Dictionary) -> void:
	for child_name: String in ["MidfieldProps", "CornerLandmarks", "TrackInfrastructure", "DistantSilhouettes", "SceneryLights"]:
		_expect(scenery.get_node_or_null(child_name) != null, "%s doit générer %s" % [track_id, child_name])
	var midfield := scenery.get_node_or_null("MidfieldProps")
	var landmarks := scenery.get_node_or_null("CornerLandmarks")
	var infrastructure := scenery.get_node_or_null("TrackInfrastructure")
	_expect(midfield != null and midfield.get_child_count() == int(report.get("trackside_props", -1)), "%s doit respecter le budget de props intermédiaires" % track_id)
	_expect(landmarks != null and landmarks.get_child_count() == int(report.get("hero_props", -1)), "%s doit placer les landmarks près des secteurs forts" % track_id)
	_expect(infrastructure != null and infrastructure.get_child_count() == int(report.get("infrastructure", -1)), "%s doit respecter le budget d’infrastructure" % track_id)
	var skyline := scenery.get_node_or_null("DistantSilhouettes")
	var silhouette_instances := 0
	if skyline != null:
		_expect(skyline.get_child_count() == int(report.get("background_groups", -1)), "%s doit limiter la skyline à trois MultiMesh" % track_id)
		for child: Node in skyline.get_children():
			if child is MultiMeshInstance3D:
				var multimesh := (child as MultiMeshInstance3D).multimesh
				if multimesh != null:
					silhouette_instances += multimesh.instance_count
	_expect(silhouette_instances == int(report.get("background_silhouettes", -1)), "%s doit instancier le budget exact de silhouettes" % track_id)


func _assert_trackside_clearance(scenery: Node3D, width: float, clearance: float, track_id: String) -> void:
	var midfield := scenery.get_node_or_null("MidfieldProps")
	if midfield != null:
		for anchor: Node in midfield.get_children():
			var prop := anchor.get_node_or_null("Prop_%02d" % anchor.get_index()) as Node3D
			if prop != null:
				_expect(absf(prop.position.x) >= width * 0.5 + clearance, "%s place un prop intermédiaire dans l’enveloppe de course" % track_id)
			_assert_mesh_children_clearance(anchor, width, clearance, track_id)
	var landmarks := scenery.get_node_or_null("CornerLandmarks")
	if landmarks != null:
		for anchor: Node in landmarks.get_children():
			var foundation := anchor.get_node_or_null("Foundation") as Node3D
			if foundation != null:
				_expect(absf(foundation.position.x) >= width * 0.5 + clearance, "%s place un landmark dans l’enveloppe de course" % track_id)
			_assert_mesh_children_clearance(anchor, width, clearance, track_id)
	var infrastructure := scenery.get_node_or_null("TrackInfrastructure")
	if infrastructure != null:
		for installation: Node in infrastructure.get_children():
			var foundation := installation.get_node_or_null("ServiceFoundation") as Node3D
			if foundation != null:
				_expect(absf(foundation.position.x) >= width * 0.5 + clearance, "%s place une infrastructure dans l’enveloppe de course" % track_id)
			_assert_mesh_children_clearance(installation, width, clearance, track_id, ["HighClearanceBeam"])


func _assert_render_contract(scenery: Node3D, track_id: String, report: Dictionary) -> void:
	var categories := {
		"MidfieldProps": float(report.get("midfield_lod", 0.0)),
		"CornerLandmarks": float(report.get("foreground_lod", 0.0)),
		"TrackInfrastructure": float(report.get("midfield_lod", 0.0)),
		"DistantSilhouettes": float(report.get("background_lod", 0.0)),
	}
	for category_name: String in categories.keys():
		var category := scenery.get_node_or_null(category_name)
		if category != null:
			_assert_geometry_contract(category, float(categories[category_name]), track_id)


func _assert_geometry_contract(node: Node, expected_lod: float, track_id: String) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			_expect(mesh_instance.mesh != null, "%s contient un MeshInstance sans mesh" % track_id)
			_expect(mesh_instance.material_override != null, "%s contient un mesh sans matériau explicite" % track_id)
			_expect(is_equal_approx(mesh_instance.visibility_range_end, expected_lod), "%s publie une distance de culling incohérente" % track_id)
		elif child is MultiMeshInstance3D:
			var multi_instance := child as MultiMeshInstance3D
			var multimesh := multi_instance.multimesh
			_expect(multimesh != null, "%s contient un MultiMeshInstance sans MultiMesh" % track_id)
			if multimesh != null:
				_expect(multimesh.mesh != null, "%s contient un MultiMesh sans géométrie" % track_id)
				_expect(multimesh.instance_count > 0, "%s contient un groupe de silhouettes vide" % track_id)
			_expect(multi_instance.material_override != null, "%s contient un MultiMesh sans matériau explicite" % track_id)
			_expect(is_equal_approx(multi_instance.visibility_range_end, expected_lod), "%s publie un LOD de skyline incohérent" % track_id)
		_assert_geometry_contract(child, expected_lod, track_id)
func _assert_start_complex_clearance(start_complex: Node3D, width: float, clearance: float, track_id: String) -> void:
	var ignored_prefixes: Array[String] = ["StartFinishBeam", "FinishStrip", "StartSignal", "GridSlot"]
	_assert_mesh_children_clearance(start_complex, width, clearance, track_id, ignored_prefixes)


func _assert_mesh_children_clearance(
	node: Node, width: float, clearance: float, track_id: String, ignored_prefixes: Array[String] = []
) -> void:
	for child: Node in node.get_children():
		if not child is MeshInstance3D:
			continue
		var skipped := false
		for prefix: String in ignored_prefixes:
			if String(child.name).begins_with(prefix):
				skipped = true
				break
		if skipped:
			continue
		var mesh_instance := child as MeshInstance3D
		var span := _mesh_x_span(mesh_instance)
		var safe_edge := width * 0.5 + clearance
		var outside_envelope := span.y <= -safe_edge + 0.001 or span.x >= safe_edge - 0.001
		_expect(outside_envelope, "%s laisse %s entrer dans la marge réelle (%.3f..%.3f, limite %.3f)" % [track_id, child.name, span.x, span.y, safe_edge])


func _mesh_x_span(instance: MeshInstance3D) -> Vector2:
	var bounds := instance.mesh.get_aabb()
	var minimum_x := INF
	var maximum_x := -INF
	for x_step in range(2):
		for y_step in range(2):
			for z_step in range(2):
				var corner := bounds.position + Vector3(
					bounds.size.x * float(x_step),
					bounds.size.y * float(y_step),
					bounds.size.z * float(z_step)
				)
				var transformed := instance.transform * corner
				minimum_x = minf(minimum_x, transformed.x)
				maximum_x = maxf(maximum_x, transformed.x)
	return Vector2(minimum_x, maximum_x)
func _contains_infrastructure_texture(node: Node) -> bool:
	if node == null:
		return false
	if node is GeometryInstance3D:
		var material := (node as GeometryInstance3D).material_override
		if material is StandardMaterial3D:
			var standard := material as StandardMaterial3D
			var texture := standard.albedo_texture
			if texture != null and String(texture.resource_path) == "res://assets/textures/openai/track_infrastructure_detail.png":
				return true
	for child: Node in node.get_children():
		if _contains_infrastructure_texture(child):
			return true
	return false


func _test_determinism(expected_fingerprint: String) -> void:
	var duplicate: Node3D = TrackFactoryScript.build(DatabaseScript.get_track("foundry"))
	var scenery := duplicate.get_node_or_null("Scenery") as Node3D
	_expect(scenery != null and _layout_fingerprint(scenery) == expected_fingerprint, "le seed doit reproduire exactement la composition du décor")
	duplicate.free()


func _test_detail_tiers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 117
	var foreground := TrackProfilesScript.prop_mesh_for_tier(DatabaseScript.get_track("foundry"), 0, rng, "foreground")
	rng.seed = 117
	var background := TrackProfilesScript.prop_mesh_for_tier(DatabaseScript.get_track("foundry"), 0, rng, "background")
	_expect(foreground is CylinderMesh and (foreground as CylinderMesh).radial_segments >= 18, "le premier plan doit utiliser un cylindre détaillé")
	_expect(background is CylinderMesh and (background as CylinderMesh).radial_segments <= 8, "la silhouette distante doit utiliser le LOD bas")


func _test_budget_guardrails() -> void:
	var spec: Dictionary = DatabaseScript.get_track("foundry").duplicate(true)
	spec["id"] = "budget_guardrail"
	spec["scenery_budget"] = {
		"trackside_props": 999,
		"hero_props": 999,
		"infrastructure": 999,
		"background_silhouettes": 999,
		"dynamic_lights": 999,
		"clearance": -100.0,
		"far_min": 999.0,
		"far_max": -1.0,
		"background_groups": 999,
		"node_budget": 1,
		"animated_props": 999,
		"foreground_lod": 9999.0,
		"midfield_lod": 9999.0,
		"background_lod": 9999.0,
	}
	var profile := TrackProfilesScript.scenery_profile(spec)
	_expect(int(profile.get("background_groups", -1)) == 3, "les surcharges ne doivent pas multiplier les groupes MultiMesh")
	_expect(int(profile.get("node_budget", -1)) == 210, "le budget Web/mobile ne doit pas être falsifiable par les données")
	_expect(int(profile.get("animated_props", -1)) == 0, "le contrat reduced_motion doit rester fixe")
	_expect(is_equal_approx(float(profile.get("foreground_lod", 0.0)), 230.0), "le culling premier plan doit rester borné")
	_expect(is_equal_approx(float(profile.get("midfield_lod", 0.0)), 390.0), "le culling intermédiaire doit rester borné")
	_expect(is_equal_approx(float(profile.get("background_lod", 0.0)), 920.0), "le culling distant doit rester borné")
	_expect(int(profile.get("trackside_props", 0)) == 35, "la densité maximale doit respecter le vrai budget de descendants")
	_expect(int(profile.get("hero_props", 0)) == 9 and int(profile.get("infrastructure", 0)) == 12, "les catégories lourdes doivent rester plafonnées")
	_expect(float(profile.get("clearance", 0.0)) >= 7.5, "une surcharge ne doit jamais réduire la marge homologuée")
	_expect(float(profile.get("far_max", 0.0)) >= float(profile.get("far_min", 0.0)) + 16.0, "la plage de skyline doit rester ordonnée")
	var track: Node3D = TrackFactoryScript.build(spec)
	var scenery := track.get_node_or_null("Scenery") as Node3D
	var report_value: Variant = track.get_meta("scenery_report", {})
	var report: Dictionary = Dictionary(report_value) if report_value is Dictionary else {}
	_expect(scenery != null, "la configuration maximale protégée doit rester constructible")
	if scenery != null:
		var actual_descendants := _count_descendants(scenery)
		_expect(actual_descendants == int(report.get("actual_descendants", -1)), "le profil maximal doit publier sa mesure réelle")
		_expect(actual_descendants <= int(profile.get("node_budget", 0)), "les plafonds combinés doivent tenir réellement dans 210 descendants")
		var skyline := scenery.get_node_or_null("DistantSilhouettes")
		_expect(skyline != null and skyline.get_child_count() == 3, "la skyline protégée doit conserver trois draw groups")
	track.free()

func _layout_fingerprint(scenery: Node3D) -> String:
	var parts: Array[String] = []
	for category_name: String in ["MidfieldProps", "CornerLandmarks", "TrackInfrastructure"]:
		var category := scenery.get_node_or_null(category_name)
		if category == null:
			continue
		for child: Node in category.get_children():
			if child is Node3D:
				var node := child as Node3D
				parts.append("%s:%.3f:%.3f:%.3f" % [child.name, node.position.x, node.position.y, node.position.z])
	return "|".join(parts)


func _contains_animation_player(node: Node) -> bool:
	if node is AnimationPlayer:
		return true
	for child: Node in node.get_children():
		if _contains_animation_player(child):
			return true
	return false


func _count_descendants(node: Node) -> int:
	var total := node.get_child_count()
	for child: Node in node.get_children():
		total += _count_descendants(child)
	return total


func _count_geometry_instances(node: Node) -> int:
	var total := 0
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			total += 1
		total += _count_geometry_instances(child)
	return total


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
