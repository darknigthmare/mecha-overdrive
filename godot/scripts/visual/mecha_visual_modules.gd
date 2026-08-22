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
	var slot_surface := MaterialLibrary.module_for("core", _material_tint(primary, Color("9bc6d8")))
	match module_id:
		"core_balanced":
			for x: float in [-0.62, 0.62]:
				_cylinder(holder, 0.28, 1.05, Vector3(x, 3.14, 0.72), slot_surface, Vector3(PI / 2.0, 0, 0))
				_sphere(holder, 0.22, Vector3(x, 3.14, 1.28), glow)
			_box(holder, Vector3(0.72, 0.18, 0.62), Vector3(0, 3.14, 0.62), joint)
		"core_overdrive":
			for x: float in [-0.72, 0.72]:
				_cylinder(holder, 0.36, 1.32, Vector3(x, 2.98, 0.82), slot_surface, Vector3(PI / 2.0, 0, 0))
				_torus(holder, 0.38, 0.5, Vector3(x, 2.98, 1.5), glow, Vector3(PI / 2.0, 0, 0))
			_box(holder, Vector3(0.34, 0.38, 1.1), Vector3(0, 2.98, 0.86), joint)
		"core_bastion":
			_box(holder, Vector3(1.25, 0.34, 1.85), Vector3(-1.48, 2.62, 0.2), slot_surface)
			_box(holder, Vector3(1.25, 0.34, 1.85), Vector3(1.48, 2.62, 0.2), slot_surface)
			_box(holder, Vector3(1.18, 0.3, 0.58), Vector3(0, 2.78, 0.82), joint)
		"core_tactical_relay":
			_box(holder, Vector3(1.7, 0.28, 0.92), Vector3(0, 2.92, 0.42), slot_surface)
			_cylinder(holder, 0.1, 1.18, Vector3(0, 3.58, 0.42), joint)
			_torus(holder, 0.46, 0.6, Vector3(0, 4.05, 0.42), slot_surface)
			for x: float in [-0.72, 0.72]:
				_sphere(holder, 0.13, Vector3(x, 3.0, 0.62), glow)
		"core_hive_capacitor":
			_box(holder, Vector3(1.75, 0.22, 0.8), Vector3(0, 2.88, 0.46), joint)
			for offset: Vector3 in [Vector3(0, 0, 0), Vector3(-0.52, 0, 0), Vector3(0.52, 0, 0), Vector3(-0.26, 0.42, 0), Vector3(0.26, 0.42, 0)]:
				_cylinder(holder, 0.2, 0.66, Vector3(0, 3.02, 0.86) + offset, slot_surface, Vector3(PI / 2.0, 0, 0))
				_sphere(holder, 0.11, Vector3(0, 3.02, 1.22) + offset, glow)
		"core_phase_lattice":
			_sphere(holder, 0.48, Vector3(0, 3.12, 0.58), slot_surface)
			_torus(holder, 0.62, 0.78, Vector3(0, 3.12, 0.58), slot_surface)
			_torus(holder, 0.62, 0.78, Vector3(0, 3.12, 0.58), slot_surface, Vector3(PI / 2.0, 0, 0))
			_torus(holder, 0.62, 0.78, Vector3(0, 3.12, 0.58), slot_surface, Vector3(0, 0, PI / 2.0))
			_sphere(holder, 0.2, Vector3(0, 3.12, 0.58), glow)
		_:
			_box(holder, Vector3(1.4, 0.3, 1.0), Vector3(0, 2.95, 0.55), slot_surface)
			_sphere(holder, 0.18, Vector3(0, 3.18, 1.08), glow)


static func _mobility(root: Node3D, module_id: String, dark: Material, joint: Material, glow: Material) -> void:
	var holder := _holder(root, "ModuleMobility_%s" % module_id, "mecha_module_mobility")
	var slot_surface := MaterialLibrary.module_for("mobility", _material_tint(dark, Color("344557")))
	match module_id:
		"mobility_vector":
			for x: float in [-1.45, 1.45]:
				_cylinder(holder, 0.38, 1.18, Vector3(x, 1.55, 1.58), slot_surface, Vector3(PI / 2.0, 0, 0))
				_sphere(holder, 0.27, Vector3(x, 1.55, 2.22), glow)
		"mobility_sprint":
			for x: float in [-1.52, 1.52]:
				_cylinder(holder, 0.19, 1.62, Vector3(x, 1.32, 1.24), slot_surface, Vector3(PI / 2.0, 0, 0))
				_box(holder, Vector3(0.34, 0.14, 0.92), Vector3(x, 1.62, 1.9), joint)
				_sphere(holder, 0.15, Vector3(x, 1.32, 2.08), glow)
		"mobility_adaptive":
			for x: float in [-1.72, 1.72]:
				_box(holder, Vector3(0.24, 0.72, 2.05), Vector3(x, 1.34, 0.68), slot_surface)
				_box(holder, Vector3(0.52, 0.18, 0.85), Vector3(x, 0.88, 1.28), joint)
		"mobility_gyro_rail":
			for x: float in [-1.68, 1.68]:
				_torus(holder, 0.38, 0.62, Vector3(x, 1.28, 0.82), slot_surface, Vector3(0, 0, PI / 2.0))
				_box(holder, Vector3(0.24, 0.28, 2.2), Vector3(x, 1.28, 1.12), joint)
				_sphere(holder, 0.14, Vector3(x, 1.28, 2.18), glow)
		"mobility_multileg":
			for x: float in [-1.82, 1.82]:
				for z: float in [0.22, 1.42]:
					_box(holder, Vector3(0.32, 0.22, 0.92), Vector3(x, 1.08, z), slot_surface)
					_cylinder(holder, 0.12, 0.72, Vector3(x, 0.7, z + 0.22), joint, Vector3(0, 0, PI / 7.0 if x < 0.0 else -PI / 7.0))
					_sphere(holder, 0.16, Vector3(x, 0.34, z + 0.38), slot_surface, Vector3(1.35, 0.55, 1.0))
		"mobility_phase_skates":
			for x: float in [-1.62, 1.62]:
				_box(holder, Vector3(0.7, 0.12, 2.55), Vector3(x, 0.48, 0.8), slot_surface)
				_box(holder, Vector3(0.16, 0.08, 2.18), Vector3(x, 0.39, 0.94), glow)
				_sphere(holder, 0.18, Vector3(x, 0.66, 1.82), joint, Vector3(1.2, 0.55, 1.0))
		_:
			for x: float in [-1.45, 1.45]:
				_box(holder, Vector3(0.42, 0.28, 1.35), Vector3(x, 1.1, 1.0), slot_surface)


static func _utility(root: Node3D, module_id: String, joint: Material, glow: Material) -> void:
	var holder := _holder(root, "ModuleUtility_%s" % module_id, "mecha_module_utility")
	var slot_surface := MaterialLibrary.module_for("utility", _material_tint(joint, Color("526675")))
	match module_id:
		"utility_coolant":
			for index in range(4):
				_box(holder, Vector3(0.18, 0.9, 1.1), Vector3((float(index) - 1.5) * 0.42, 2.85, 1.12), slot_surface)
			_box(holder, Vector3(1.5, 0.12, 0.16), Vector3(0, 3.3, 1.45), glow)
		"utility_aegis":
			for x: float in [-1.2, 1.2]:
				_box(holder, Vector3(0.32, 0.42, 0.82), Vector3(x, 2.72, 0.62), slot_surface)
				_torus(holder, 0.42, 0.55, Vector3(x, 2.78, 0.65), glow, Vector3(PI / 2.0, 0, 0))
		"utility_scanner":
			_cylinder(holder, 0.08, 1.35, Vector3(0, 3.75, -0.05), slot_surface)
			_sphere(holder, 0.28, Vector3(0, 4.42, -0.05), slot_surface, Vector3(1.0, 0.42, 1.0))
			_sphere(holder, 0.1, Vector3(0, 4.42, -0.34), glow)
		"utility_command_uplink":
			_box(holder, Vector3(1.28, 0.2, 0.72), Vector3(0, 3.0, 0.42), slot_surface)
			for x: float in [-0.44, 0.44]:
				_cylinder(holder, 0.06, 1.05, Vector3(x, 3.55, 0.4), joint)
				_sphere(holder, 0.12, Vector3(x, 4.1, 0.4), glow)
			_sphere(holder, 0.42, Vector3(0, 3.78, 0.3), slot_surface, Vector3(1.0, 0.18, 1.0))
		"utility_impact_ram":
			_box(holder, Vector3(1.65, 0.46, 0.46), Vector3(0, 1.72, -2.02), slot_surface)
			_box(holder, Vector3(1.05, 0.66, 0.52), Vector3(0, 1.72, -2.42), slot_surface)
			_box(holder, Vector3(0.48, 0.86, 0.38), Vector3(0, 1.72, -2.76), joint)
			_sphere(holder, 0.12, Vector3(0, 1.72, -2.98), glow)
		"utility_phase_sink":
			_cylinder(holder, 0.32, 0.7, Vector3(0, 3.18, 0.48), slot_surface)
			for index in range(4):
				var angle := TAU * float(index) / 4.0
				var offset := Vector3(cos(angle) * 0.72, 0, sin(angle) * 0.72)
				_sphere(holder, 0.3, Vector3(0, 3.18, 0.48) + offset, slot_surface, Vector3(1.15, 0.24, 0.62))
			_sphere(holder, 0.2, Vector3(0, 3.18, 0.48), glow)
		_:
			_box(holder, Vector3(1.2, 0.28, 0.82), Vector3(0, 3.0, 0.5), slot_surface)
			_sphere(holder, 0.14, Vector3(0, 3.25, 0.92), glow)


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


static func _material_tint(material: Material, fallback: Color) -> Color:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color
	return fallback


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


static func _torus(root: Node3D, inner_radius: float, outer_radius: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
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
