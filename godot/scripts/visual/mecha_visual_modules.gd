class_name MechaVisualModules
extends RefCounted

## Adds three readable, original module silhouettes to any procedural chassis
## and provides per-architecture camera anchors for TPS/cockpit driving.


static func install(root: RacerVisual, chassis: Dictionary, customization: Dictionary, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var authored: Dictionary = chassis.get("default_loadout", {}) if chassis.get("default_loadout", {}) is Dictionary else {}
	var modules: Dictionary = customization.get("modules", customization)
	var core_id := _id(modules.get("core", authored.get("core", "core_balanced")), "core_balanced")
	var mobility_id := _id(modules.get("mobility", authored.get("mobility", "mobility_vector")), "mobility_vector")
	var utility_id := _id(modules.get("utility", authored.get("utility", "utility_coolant")), "utility_coolant")
	root.set_meta("module_loadout", {"core": core_id, "mobility": mobility_id, "utility": utility_id})
	_core(root, core_id, primary, joint, glow)
	_mobility(root, mobility_id, dark, joint, glow)
	_utility(root, utility_id, joint, glow)
	_camera_anchors(root, chassis)


static func _core(root: Node3D, module_id: String, primary: Material, joint: Material, glow: Material) -> void:
	var holder := _holder(root, "ModuleCore_%s" % module_id, "mecha_module_core")
	if module_id.contains("fort") or module_id.contains("armor") or module_id.contains("bulwark") or module_id.contains("bastion"):
		_box(holder, Vector3(1.25, 0.34, 1.85), Vector3(-1.48, 2.62, 0.2), primary)
		_box(holder, Vector3(1.25, 0.34, 1.85), Vector3(1.48, 2.62, 0.2), primary)
	else:
		for x: float in [-0.62, 0.62]:
			_cylinder(holder, 0.28, 1.05, Vector3(x, 3.14, 0.72), joint, Vector3(PI / 2.0, 0, 0))
			_sphere(holder, 0.22, Vector3(x, 3.14, 1.28), glow)


static func _mobility(root: Node3D, module_id: String, dark: Material, joint: Material, glow: Material) -> void:
	var holder := _holder(root, "ModuleMobility_%s" % module_id, "mecha_module_mobility")
	if module_id.contains("grip") or module_id.contains("offroad") or module_id.contains("stabil") or module_id.contains("traction") or module_id.contains("adaptive"):
		for x: float in [-1.72, 1.72]:
			_box(holder, Vector3(0.24, 0.72, 2.05), Vector3(x, 1.34, 0.68), dark)
			_box(holder, Vector3(0.52, 0.18, 0.85), Vector3(x, 0.88, 1.28), joint)
	else:
		for x: float in [-1.45, 1.45]:
			_cylinder(holder, 0.38, 1.18, Vector3(x, 1.55, 1.58), dark, Vector3(PI / 2.0, 0, 0))
			_sphere(holder, 0.27, Vector3(x, 1.55, 2.22), glow)


static func _utility(root: Node3D, module_id: String, joint: Material, glow: Material) -> void:
	var holder := _holder(root, "ModuleUtility_%s" % module_id, "mecha_module_utility")
	if module_id.contains("shield") or module_id.contains("aegis") or module_id.contains("defense"):
		for x: float in [-1.2, 1.2]:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.42
			ring.outer_radius = 0.55
			var node := MeshInstance3D.new()
			node.mesh = ring
			node.material_override = glow
			node.position = Vector3(x, 2.78, 0.65)
			node.rotation.x = PI / 2.0
			holder.add_child(node)
	elif module_id.contains("cool") or module_id.contains("thermal"):
		for index in range(4):
			_box(holder, Vector3(0.18, 0.9, 1.1), Vector3((float(index) - 1.5) * 0.42, 2.85, 1.12), joint)
	else:
		_cylinder(holder, 0.08, 1.35, Vector3(0, 3.75, -0.05), joint)
		_sphere(holder, 0.28, Vector3(0, 4.42, -0.05), MaterialLibrary.cockpit(), Vector3(1.0, 0.42, 1.0))
		_sphere(holder, 0.1, Vector3(0, 4.42, -0.34), glow)


static func _camera_anchors(root: RacerVisual, chassis: Dictionary) -> void:
	var chassis_id := String(chassis.get("id", "biped"))
	var cockpit_offset: Vector3 = chassis.get("cockpit_offset", Vector3(0, 2.75, 0.10))
	var tps_height := 5.2
	var tps_distance := 7.4
	match chassis_id:
		"hover", "tracked": tps_height = 4.75
		"orb", "monowheel": tps_height = 5.0; tps_distance = 6.8
		"centurion", "octopod": tps_height = 5.55; tps_distance = 8.2
	var tps := Marker3D.new()
	tps.name = "CameraTPS"
	tps.position = Vector3(0, tps_height, tps_distance)
	root.add_child(tps)
	var fps := Marker3D.new()
	fps.name = "CameraFPS"
	fps.position = cockpit_offset + Vector3(0, 0, -1.12)
	root.add_child(fps)


static func _id(value: Variant, fallback: String) -> String:
	if value is Dictionary:
		var data: Dictionary = value
		return String(data.get("id", data.get("selected", fallback))).to_lower()
	var result := String(value).to_lower()
	return fallback if result.is_empty() else result


static func _holder(root: Node3D, node_name: String, group: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.add_to_group(group)
	root.add_child(holder)
	return holder


static func _box(root: Node3D, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(root, mesh, position, material)


static func _sphere(root: Node3D, radius: float, position: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := _mesh(root, mesh, position, material)
	node.scale = scale_value
	return node


static func _cylinder(root: Node3D, radius: float, height: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := _mesh(root, mesh, position, material)
	node.rotation = rotation
	return node


static func _mesh(root: Node3D, mesh: PrimitiveMesh, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	node.add_to_group("mecha_fps_occluder")
	root.add_child(node)
	return node
