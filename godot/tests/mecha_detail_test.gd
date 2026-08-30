extends SceneTree
## Targeted production test:
## godot --headless --path godot --script res://tests/mecha_detail_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const MechaFactoryScript = preload("res://scripts/mecha/mecha_factory.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run_tests")


func _run_tests() -> void:
	var hero_counts: Dictionary = {}
	var race_counts: Dictionary = {}
	for chassis: Dictionary in DatabaseScript.CHASSIS:
		var chassis_id := String(chassis.get("id", "unknown"))
		_validate_current_identity(chassis)
		for hero_detail: bool in [false, true]:
			var visual: RacerVisual = MechaFactoryScript.build(
				chassis,
				Color(String(chassis.get("paint", "#5EE7FF"))),
				hero_detail,
				Dictionary(chassis.get("default_loadout", {})).duplicate(true)
			)
			root.add_child(visual)
			var expected_tier := 2 if hero_detail else 1
			var detail_holder := visual.get_node_or_null("ChassisDetail_%s" % chassis_id) as Node3D
			var detail_count := _mesh_count(detail_holder)
			var visual_count := _mesh_count(visual)
			var detail_triangle_count := _triangle_count(detail_holder)
			var triangle_count := _triangle_count(visual)
			var declared_detail_count := int(visual.get_meta("detail_mesh_count", -1))
			var declared_visual_count := int(visual.get_meta("visual_mesh_count", -1))
			var detail_budget := int(visual.get_meta("visual_detail_part_budget", 0))
			var web_budget := int(visual.get_meta("web_mesh_budget", 0))
			var triangle_budget := int(visual.get_meta("visual_triangle_budget", 0))
			var detail_triangle_budget := int(visual.get_meta("chassis_detail_triangle_budget", 0))
			_expect(int(visual.get_meta("visual_detail_tier", 0)) == expected_tier, "%s : tier de détail incorrect" % chassis_id)
			_expect(detail_holder != null, "%s : holder de détail architectural absent" % chassis_id)
			_expect(detail_count == declared_detail_count, "%s : detail_mesh_count ne reflète pas les MeshInstance3D réels" % chassis_id)
			_expect(visual_count == declared_visual_count, "%s : visual_mesh_count ne reflète pas le montage complet" % chassis_id)
			_expect(detail_count > 0 and detail_count <= detail_budget, "%s : budget de pièces architecturales dépassé" % chassis_id)
			_expect(visual_count <= web_budget and bool(visual.get_meta("web_mesh_budget_ok", false)), "%s : budget Web/mobile dépassé (%d > %d)" % [chassis_id, visual_count, web_budget])
			_expect(triangle_count == int(visual.get_meta("visual_triangle_count", -1)), "%s : visual_triangle_count ne reflète pas la géométrie réelle" % chassis_id)
			_expect(triangle_count <= triangle_budget and bool(visual.get_meta("visual_triangle_budget_ok", false)), "%s : budget triangles total dépassé (%d > %d)" % [chassis_id, triangle_count, triangle_budget])
			_expect(detail_triangle_count == int(visual.get_meta("chassis_detail_triangle_count", -1)), "%s : métrique triangles du détail châssis incorrecte" % chassis_id)
			_expect(detail_triangle_count <= detail_triangle_budget and bool(detail_holder.get_meta("triangle_budget_ok", false)), "%s : budget triangles du détail châssis dépassé (%d > %d)" % [chassis_id, detail_triangle_count, detail_triangle_budget])
			print("MECHA DETAIL METRIC: %s tier=%d meshes=%d/%d triangles=%d/%d chassis_detail=%d/%d" % [chassis_id, expected_tier, visual_count, web_budget, triangle_count, triangle_budget, detail_triangle_count, detail_triangle_budget])
			_expect(_all_detail_meshes_tagged(detail_holder, "mecha_chassis_detail_part"), "%s : groupe de détail architectural incomplet" % chassis_id)
			_expect(_has_panel_texture(detail_holder), "%s : la texture mecha_detail_panels.png n'habille aucun panneau secondaire" % chassis_id)
			if chassis_id == "tracked":
				_expect(_has_named_node(detail_holder, "AetherPylonFairing"), "tracked : pylônes de Pod Aether absents")
				_expect(not _has_named_node(detail_holder, "TrackFender") and not _has_named_node(detail_holder, "CommandCupola"), "tracked : ancienne silhouette de char encore présente")
			elif chassis_id == "centurion":
				_expect(_has_named_node(detail_holder, "SkimmerFieldProjector"), "centurion : projecteurs d'effet de sol Skimmer absents")
				_expect(not _has_named_node(detail_holder, "DorsalScale") and not _has_named_node(detail_holder, "CenturionHead"), "centurion : ancienne silhouette myriapode encore présente")
			var module_detail_count := int(visual.get_meta("module_detail_mesh_count", -1))
			var module_detail_triangles := _group_triangle_count(visual, "mecha_module_detail_part")
			_expect(module_detail_count == _group_mesh_count(visual, "mecha_module_detail_part"), "%s : métrique de micro-détails modulaires incorrecte" % chassis_id)
			_expect(module_detail_count > 0 and module_detail_count <= int(visual.get_meta("module_detail_mesh_budget", 0)), "%s : budget de micro-détails modulaires invalide" % chassis_id)
			_expect(module_detail_triangles == int(visual.get_meta("module_detail_triangle_count", -1)), "%s : métrique triangles des micro-détails modulaires incorrecte" % chassis_id)
			_expect(module_detail_triangles <= int(visual.get_meta("module_detail_triangle_budget", 0)) and bool(visual.get_meta("module_detail_triangle_budget_ok", false)), "%s : budget triangles des micro-détails modulaires dépassé" % chassis_id)
			for slot_name: String in ["ModuleCore_", "ModuleMobility_", "ModuleUtility_"]:
				var module_holder := _find_child_prefix(visual, slot_name)
				var manufacturing := module_holder.get_node_or_null("ManufacturingDetail") as Node3D if module_holder != null else null
				_expect(manufacturing != null, "%s : détail manufacturé absent pour %s" % [chassis_id, slot_name])
				if manufacturing != null:
					_expect(_mesh_count(manufacturing) == int(manufacturing.get_meta("detail_mesh_count", -1)), "%s : comptage réel du slot %s incohérent" % [chassis_id, slot_name])
					_expect(_mesh_count(manufacturing) <= int(manufacturing.get_meta("detail_part_limit", 0)), "%s : limite du slot %s dépassée" % [chassis_id, slot_name])
					_expect(_triangle_count(manufacturing) == int(manufacturing.get_meta("triangle_count", -1)), "%s : comptage triangles du slot %s incohérent" % [chassis_id, slot_name])
					_expect(_triangle_count(manufacturing) <= int(manufacturing.get_meta("triangle_budget", 0)) and bool(manufacturing.get_meta("triangle_budget_ok", false)), "%s : budget triangles du slot %s dépassé" % [chassis_id, slot_name])
					_expect(_has_panel_texture(manufacturing), "%s : texture de panneau absente du slot %s" % [chassis_id, slot_name])
			if hero_detail:
				hero_counts[chassis_id] = detail_count
			else:
				race_counts[chassis_id] = detail_count
			visual.free()

	for chassis_id: String in hero_counts:
		_expect(int(hero_counts[chassis_id]) >= int(race_counts.get(chassis_id, 0)), "%s : le modèle hero est moins détaillé que le LOD course" % chassis_id)

	if _failures.is_empty():
		print("MECHA DETAIL PRODUCTION: PASS (10 architectures, hero/race LOD, textured panels, modular greebles, measured mesh/triangle budgets)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA DETAIL PRODUCTION: %s" % failure)
	quit(1)


func _mesh_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _mesh_count(child)
	return count


func _group_mesh_count(node: Node, group_name: String) -> int:
	var count := 1 if node is MeshInstance3D and node.is_in_group(group_name) else 0
	for child: Node in node.get_children():
		count += _group_mesh_count(child, group_name)
	return count


func _triangle_count(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			count += mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		count += _triangle_count(child)
	return count


func _group_triangle_count(node: Node, group_name: String) -> int:
	var count := 0
	if node is MeshInstance3D and node.is_in_group(group_name):
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			count += mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		count += _group_triangle_count(child, group_name)
	return count

func _all_detail_meshes_tagged(node: Node, group_name: String) -> bool:
	if node == null:
		return false
	for child: Node in node.get_children():
		if child is MeshInstance3D and not child.is_in_group(group_name):
			return false
		if not _all_detail_meshes_tagged(child, group_name):
			return false
	return true


func _has_panel_texture(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D:
		var material := (node as MeshInstance3D).material_override as StandardMaterial3D
		if material != null and material.albedo_texture != null and material.albedo_texture.resource_path.ends_with("mecha_detail_panels.png"):
			return true
	for child: Node in node.get_children():
		if _has_panel_texture(child):
			return true
	return false


func _find_child_prefix(node: Node, prefix: String) -> Node:
	for child: Node in node.get_children():
		if child.name.begins_with(prefix):
			return child
	return null


func _has_named_node(node: Node, prefix: String) -> bool:
	if node == null:
		return false
	if String(node.name).begins_with(prefix):
		return true
	for child: Node in node.get_children():
		if _has_named_node(child, prefix):
			return true
	return false


func _validate_current_identity(chassis: Dictionary) -> void:
	var chassis_id := String(chassis.get("id", ""))
	var lore := String(chassis.get("lore", ""))
	match chassis_id:
		"tracked":
			_expect(lore.contains("Aether Lance P2") and not lore.contains("Bastion"), "tracked : lore Pod Aether désynchronisé")
		"monowheel":
			_expect(lore.contains("Valkyr C1") and not lore.contains("Cyclops"), "monowheel : lore Cycle Valkyr désynchronisé")
		"centurion":
			_expect(lore.contains("Skimmer LS9") and not lore.contains("myriapode"), "centurion : lore Land Speeder Skimmer désynchronisé")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
