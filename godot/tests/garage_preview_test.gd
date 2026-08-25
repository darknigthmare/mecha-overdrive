extends SceneTree
## Targeted test: godot --headless --path godot --script res://tests/garage_preview_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const GaragePreviewScene = preload("res://scenes/components/garage_preview.tscn")

const DEFAULT_YAW := -0.34
const DEFAULT_ZOOM := 0.96

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run_tests")


func _run_tests() -> void:
	var preview := GaragePreviewScene.instantiate() as Control
	root.add_child(preview)
	await process_frame
	await process_frame

	preview.call(&"set_reduced_motion", true)
	var stack := preview.get_node_or_null("Stack") as Control
	var viewport := preview.get_node_or_null("Stack/ViewportContainer/PreviewViewport") as SubViewport
	var overlay := preview.get_node_or_null("Stack/Overlay") as MarginContainer
	var turntable := preview.get_node_or_null("Stack/ViewportContainer/PreviewViewport/PreviewWorld/Turntable") as Node3D
	_expect(stack != null and stack.size.x > 0.0 and stack.size.is_equal_approx(preview.size), "le Stack 3D doit remplir tout le garage")
	_expect(viewport != null and preview.find_children("*", "SubViewport", true, false).size() == 1, "un unique SubViewport réactif est attendu")
	_expect(overlay != null and is_equal_approx(overlay.anchor_left, 0.205) and is_equal_approx(overlay.anchor_right, 0.705), "le HUD de preview doit rester ancré dans la scène centrale")

	var controls_value: Variant = preview.call(&"focus_controls")
	var controls: Array = controls_value if controls_value is Array else []
	_expect(controls.size() == 5, "les cinq contrôles de cadrage doivent être exposés au focus")
	for control_value: Variant in controls:
		var control := control_value as Control
		_expect(control != null and control.focus_mode == Control.FOCUS_ALL, "chaque contrôle de cadrage doit accepter le focus clavier/manette")
		_expect(control != null and control.custom_minimum_size.y >= 44.0, "chaque contrôle tactile doit mesurer au moins 44 px")

	var crew := preview.call(&"pit_crew") as Node3D
	_expect(crew != null and int(crew.get_meta(&"pit_crew_actor_count", 0)) == 4, "le paddock doit contenir quatre mécanos procéduraux")
	_expect(crew != null and bool(crew.get_meta(&"web_lightweight", false)), "l’équipe mécano doit déclarer son profil léger Web/mobile")
	var crew_actors: Array[Node] = []
	for actor: Node in get_nodes_in_group(&"garage_pit_crew_actor"):
		if crew != null and crew.is_ancestor_of(actor):
			crew_actors.append(actor)
	_expect(crew_actors.size() == 4, "deux humanoïdes et deux robots de stand sont attendus")
	var kinds: Dictionary = {}
	var roles: Dictionary = {}
	for actor: Node in crew_actors:
		kinds[String(actor.get_meta(&"actor_kind", ""))] = int(kinds.get(String(actor.get_meta(&"actor_kind", "")), 0)) + 1
		roles[String(actor.get_meta(&"pit_role", ""))] = true
	_expect(int(kinds.get("humanoid", 0)) == 2 and int(kinds.get("robot", 0)) == 2, "le paddock doit mélanger humanoïdes en combinaison et robots originaux")
	_expect(roles.size() == 4, "chaque mécano doit avoir un rôle de stand distinct")
	var crew_meshes: Array = crew.find_children("*", "MeshInstance3D", true, false) if crew != null else []
	_expect(crew_meshes.size() <= 46, "le budget géométrique de l’équipe mécano doit rester léger")
	var crew_texture_found := false
	for candidate: Node in crew_meshes:
		var part := candidate as MeshInstance3D
		var material := part.material_override as StandardMaterial3D if part != null else null
		if material != null and material.albedo_texture != null and material.albedo_texture.resource_path.ends_with("garage_crew.png"):
			crew_texture_found = true
			break
	_expect(crew_texture_found, "la texture OpenAI garage_crew.png doit habiller combinaisons et outils")
	_expect(crew != null and not crew.is_processing(), "reduced_motion doit immobiliser l’équipe mécano")
	var drone := crew.get_node_or_null("HaloDiagnosticDrone") as Node3D if crew != null else null
	var drone_rest_y := drone.position.y if drone != null else 0.0
	preview.call(&"set_reduced_motion", false)
	if crew != null:
		crew.call(&"_process", 0.5)
	_expect(crew != null and crew.is_processing(), "les animations de stand doivent pouvoir reprendre")
	_expect(drone != null and not is_equal_approx(drone.position.y, drone_rest_y), "le drone diagnostic doit animer son inspection")
	preview.call(&"set_reduced_motion", true)
	_expect(drone != null and is_equal_approx(drone.position.y, drone_rest_y), "reduced_motion doit restaurer la pose de diagnostic stable")
	for spark: Node in get_nodes_in_group(&"garage_pit_crew_spark"):
		if crew != null and crew.is_ancestor_of(spark):
			var spark_mesh := spark as MeshInstance3D
			_expect(spark_mesh != null and not spark_mesh.visible, "les étincelles doivent disparaître en mouvement réduit")

	var chassis := DatabaseScript.get_chassis("biped")
	var loadout: Dictionary = Dictionary(chassis.get("default_loadout", {})).duplicate(true)
	preview.call(&"configure", chassis, "#5EE7FF", loadout)
	await process_frame
	await process_frame
	_expect(preview.call(&"current_visual") != null, "le modèle 3D réel doit être construit dans la preview plein écran")

	var camera := preview.get_node_or_null("Stack/ViewportContainer/PreviewViewport/PreviewWorld/PreviewCamera") as Camera3D
	for actor: Node in crew_actors:
		var actor_3d := actor as Node3D
		_expect(camera != null and actor_3d != null and camera.is_position_in_frustum(actor_3d.to_global(Vector3(0.0, 1.0, 0.0))), "%s doit rester visible dans le cadre" % actor.name)
		if camera != null and actor_3d != null and viewport != null:
			var screen_position := camera.unproject_position(actor_3d.to_global(Vector3(0.0, 1.0, 0.0)))
			var screen_x := screen_position.x / maxf(1.0, float(viewport.size.x))
			_expect(screen_x >= 0.205 and screen_x <= 0.705, "%s sort de la zone centrale translucide (x=%.3f)" % [actor.name, screen_x])
			_expect(absf(screen_x - 0.455) >= 0.075, "%s masque la silhouette centrale (x=%.3f)" % [actor.name, screen_x])
		_expect(actor_3d != null and absf(actor_3d.position.x) >= 1.3, "les mécanos ne doivent pas masquer l’axe central du mécha")

	preview.call(&"rotate", 0.63)
	preview.call(&"zoom", 0.17)
	var preserved_yaw := turntable.rotation.y if turntable != null else 0.0
	var preserved_zoom := float(preview.get("_zoom_factor"))
	loadout["core"] = "core_tactical_relay"
	preview.call(&"configure", chassis, "#FF8A48", loadout)
	await process_frame
	await process_frame
	_expect(turntable != null and is_equal_approx(turntable.rotation.y, preserved_yaw), "changer peinture ou module ne doit pas réinitialiser l’angle")
	_expect(is_equal_approx(float(preview.get("_zoom_factor")), preserved_zoom), "changer peinture ou module ne doit pas réinitialiser le zoom")
	var configured_visual := preview.call(&"current_visual") as Node
	var configured_loadout: Dictionary = configured_visual.get_meta("module_loadout", {}) if configured_visual != null else {}
	_expect(String(configured_loadout.get("core", "")) == "core_tactical_relay", "le module sélectionné doit être visible immédiatement")

	var tripod := DatabaseScript.get_chassis("tripod")
	preview.call(&"configure", tripod, "#FFD95A", tripod.get("default_loadout", {}))
	await process_frame
	await process_frame
	_expect(turntable != null and is_equal_approx(turntable.rotation.y, DEFAULT_YAW), "un changement de châssis doit recentrer le cadre")
	_expect(is_equal_approx(float(preview.get("_zoom_factor")), DEFAULT_ZOOM), "un changement de châssis doit restaurer le zoom par défaut")

	if viewport != null:
		var landscape_size := viewport.size
		preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
		preview.size = Vector2(1000.0, 1600.0)
		preview.call(&"_sync_viewport_size")
		await process_frame
		var portrait_size := viewport.size
		_expect(portrait_size != landscape_size, "le SubViewport doit suivre les changements de taille")
		_expect(absf(float(portrait_size.x) / maxf(1.0, float(portrait_size.y)) - 0.625) < 0.08, "le SubViewport doit conserver le ratio portrait sans recadrage horizontal")
		_expect(portrait_size.x * portrait_size.y <= 1450000, "la preview doit respecter son budget de pixels desktop")

	preview.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MECHA GARAGE PREVIEW: PASS (fullscreen, reactive viewport, focus/touch, preserved frame, live modules, 4 animated textured pit crew actors)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA GARAGE PREVIEW: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
