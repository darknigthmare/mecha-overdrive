class_name MechaVisualModules
extends RefCounted

## Adds three readable, original module silhouettes to any procedural chassis
## and provides per-architecture camera anchors for TPS/cockpit driving.

const MODULE_DETAIL_PART_LIMIT := 9
const MODULE_DETAIL_TRIANGLE_BUDGET := 2200
const MODULE_RADIAL_SEGMENTS := 16
const MODULE_SPHERE_RINGS := 8
const MODULE_TORUS_RINGS := 20
const MODULE_TORUS_SEGMENTS := 8

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
	var detail_mesh_count := _count_group_meshes(root, "mecha_module_detail_part")
	var detail_triangle_count := _count_group_triangles(root, "mecha_module_detail_part")
	root.set_meta("module_detail_mesh_count", detail_mesh_count)
	root.set_meta("module_detail_mesh_budget", MODULE_DETAIL_PART_LIMIT * 3)
	root.set_meta("module_detail_triangle_count", detail_triangle_count)
	root.set_meta("module_detail_triangle_budget", MODULE_DETAIL_TRIANGLE_BUDGET * 3)
	root.set_meta("module_detail_triangle_budget_ok", detail_triangle_count <= MODULE_DETAIL_TRIANGLE_BUDGET * 3)


static func _core(root: Node3D, module_id: String, primary: Material, joint: Material, glow: Material) -> void:
	var holder := _holder(root, "ModuleCore_%s" % module_id, "mecha_module_core")
	var slot_surface := MaterialLibrary.module_for("core", _material_tint(primary, Color("9bc6d8")))
	var micro_surface := MaterialLibrary.mecha_detail(_material_tint(slot_surface, Color("9bc6d8")), 4.6)
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
	_finish_module(holder, "core", module_id, micro_surface, joint, glow)


static func _mobility(root: Node3D, module_id: String, dark: Material, joint: Material, glow: Material) -> void:
	var holder := _holder(root, "ModuleMobility_%s" % module_id, "mecha_module_mobility")
	var slot_surface := MaterialLibrary.module_for("mobility", _material_tint(dark, Color("344557")))
	var micro_surface := MaterialLibrary.mecha_detail(_material_tint(slot_surface, Color("344557")), 4.8)
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
	_finish_module(holder, "mobility", module_id, micro_surface, joint, glow)


static func _utility(root: Node3D, module_id: String, joint: Material, glow: Material) -> void:
	var holder := _holder(root, "ModuleUtility_%s" % module_id, "mecha_module_utility")
	var slot_surface := MaterialLibrary.module_for("utility", _material_tint(joint, Color("526675")))
	var micro_surface := MaterialLibrary.mecha_detail(_material_tint(slot_surface, Color("526675")), 5.0)
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
	_finish_module(holder, "utility", module_id, micro_surface, joint, glow)


static func _finish_module(
	holder: Node3D,
	slot: String,
	module_id: String,
	panel: Material,
	joint: Material,
	glow: Material
) -> void:
	var detail := _holder(holder, "ManufacturingDetail", "mecha_module_detail")
	detail.set_meta("module_slot", slot)
	detail.set_meta("module_id", module_id)
	detail.set_meta("detail_part_limit", MODULE_DETAIL_PART_LIMIT)
	detail.set_meta("triangle_budget", MODULE_DETAIL_TRIANGLE_BUDGET)
	match slot:
		"core":
			_core_manufacturing_detail(detail, module_id, panel, joint, glow)
		"mobility":
			_mobility_manufacturing_detail(detail, module_id, panel, joint, glow)
		_:
			_utility_manufacturing_detail(detail, module_id, panel, joint, glow)
	var mesh_count := _count_group_meshes(detail, "mecha_module_detail_part")
	var triangle_count := _count_group_triangles(detail, "mecha_module_detail_part")
	detail.set_meta("detail_mesh_count", mesh_count)
	detail.set_meta("triangle_count", triangle_count)
	detail.set_meta("triangle_budget_ok", triangle_count <= MODULE_DETAIL_TRIANGLE_BUDGET)
	holder.set_meta("detail_mesh_count", mesh_count)
	holder.set_meta("detail_mesh_budget", MODULE_DETAIL_PART_LIMIT)
	holder.set_meta("detail_triangle_count", triangle_count)
	holder.set_meta("detail_triangle_budget", MODULE_DETAIL_TRIANGLE_BUDGET)


static func _core_manufacturing_detail(root: Node3D, module_id: String, panel: Material, joint: Material, glow: Material) -> void:
	_module_box(root, Vector3(2.18, 0.12, 0.44), Vector3(0, 2.7, 0.26), panel, Vector3.ZERO, "CoreMountRail")
	for side: float in [-1.0, 1.0]:
		_module_box(root, Vector3(0.28, 0.34, 0.72), Vector3(side * 1.02, 2.84, 0.42), panel, Vector3(0, 0, side * 0.08), "CoreClamp")
		_module_sphere(root, 0.09, Vector3(side * 0.86, 2.74, 0.04), joint, Vector3(1.0, 0.54, 1.0), "CoreFastener")
	match module_id:
		"core_overdrive", "core_phase_lattice":
			for side: float in [-1.0, 1.0]:
				_module_torus(root, 0.18, 0.28, Vector3(side * 0.38, 3.18, 0.24), glow, Vector3(PI / 2.0, 0, 0), "FluxCoupler")
		"core_bastion":
			for side: float in [-1.0, 1.0]:
				_module_box(root, Vector3(0.62, 0.16, 0.88), Vector3(side * 1.32, 2.92, -0.12), panel, Vector3(0.08, 0, side * 0.08), "BastionBrace")
		"core_hive_capacitor":
			for side: float in [-1.0, 0.0, 1.0]:
				_module_cylinder(root, 0.07, 0.58, Vector3(side * 0.42, 3.0, 0.32), joint, Vector3(PI / 2.0, 0, 0), "CapacitorFeed")
		"core_tactical_relay":
			_module_box(root, Vector3(1.08, 0.1, 0.28), Vector3(0, 3.42, 0.22), panel, Vector3.ZERO, "RelayBus")
			for side: float in [-1.0, 1.0]:
				_module_sphere(root, 0.08, Vector3(side * 0.44, 3.44, 0.04), glow, Vector3.ONE, "RelayStatus")
		_:
			_module_vent_pair(root, Vector3(0, 3.06, 0.16), panel)


static func _mobility_manufacturing_detail(root: Node3D, module_id: String, panel: Material, joint: Material, glow: Material) -> void:
	_module_box(root, Vector3(3.16, 0.12, 0.38), Vector3(0, 1.18, 1.22), panel, Vector3.ZERO, "MobilityCrossRail")
	for side: float in [-1.0, 1.0]:
		_module_box(root, Vector3(0.34, 0.42, 0.82), Vector3(side * 1.46, 1.34, 1.18), panel, Vector3(0, 0, side * 0.07), "MobilityShroud")
		_module_sphere(root, 0.13, Vector3(side * 1.45, 1.12, 1.48), joint, Vector3(1.2, 0.72, 1.0), "MobilityGimbal")
	match module_id:
		"mobility_vector":
			for side: float in [-1.0, 1.0]:
				_module_torus(root, 0.2, 0.3, Vector3(side * 1.46, 1.54, 2.04), glow, Vector3(PI / 2.0, 0, 0), "VectorTrimRing")
		"mobility_sprint", "mobility_phase_skates":
			for side: float in [-1.0, 1.0]:
				_module_box(root, Vector3(0.22, 0.1, 1.18), Vector3(side * 1.76, 1.38, 1.5), panel, Vector3(0, 0, side * 0.16), "SprintVane")
		"mobility_adaptive", "mobility_multileg":
			for side: float in [-1.0, 1.0]:
				_module_cylinder(root, 0.08, 0.82, Vector3(side * 1.66, 0.92, 1.1), joint, Vector3(0, 0, side * 0.3), "AdaptiveActuator")
		"mobility_gyro_rail":
			for side: float in [-1.0, 1.0]:
				_module_torus(root, 0.22, 0.34, Vector3(side * 1.68, 1.28, 0.82), panel, Vector3(0, 0, PI / 2.0), "GyroBearing")
		_:
			_module_vent_pair(root, Vector3(0, 1.42, 1.08), panel)


static func _utility_manufacturing_detail(root: Node3D, module_id: String, panel: Material, joint: Material, glow: Material) -> void:
	_module_box(root, Vector3(1.86, 0.12, 0.52), Vector3(0, 2.72, 0.28), panel, Vector3.ZERO, "UtilityBackplane")
	for side: float in [-1.0, 1.0]:
		_module_box(root, Vector3(0.26, 0.38, 0.64), Vector3(side * 0.92, 2.86, 0.42), panel, Vector3(0, 0, side * 0.07), "UtilityLatch")
		_module_sphere(root, 0.08, Vector3(side * 0.72, 2.7, 0.02), joint, Vector3(1.0, 0.54, 1.0), "UtilityFastener")
	match module_id:
		"utility_scanner", "utility_command_uplink":
			for side: float in [-1.0, 1.0]:
				_module_sphere(root, 0.1, Vector3(side * 0.44, 3.18, 0.08), glow, Vector3(1.28, 0.68, 1.0), "SignalLens")
		"utility_aegis", "utility_phase_sink":
			for side: float in [-1.0, 1.0]:
				_module_torus(root, 0.18, 0.28, Vector3(side * 0.5, 3.12, 0.28), glow, Vector3(PI / 2.0, 0, 0), "FieldCoupler")
		"utility_impact_ram":
			for side: float in [-1.0, 1.0]:
				_module_box(root, Vector3(0.18, 0.34, 1.24), Vector3(side * 0.54, 1.74, -2.28), panel, Vector3(0.08, 0, side * 0.08), "RamBrace")
		"utility_coolant":
			for side: float in [-1.0, 1.0]:
				_module_cylinder(root, 0.08, 0.68, Vector3(side * 0.66, 2.96, 1.08), joint, Vector3(PI / 2.0, 0, 0), "CoolantManifold")
		_:
			_module_vent_pair(root, Vector3(0, 3.08, 0.14), panel)


static func _module_vent_pair(root: Node3D, center: Vector3, material: Material) -> void:
	for side: float in [-1.0, 1.0]:
		_module_box(root, Vector3(0.3, 0.09, 0.44), center + Vector3(side * 0.26, 0, 0), material, Vector3(-0.12, 0, 0), "ModuleVent")


static func _module_slot_available(root: Node3D) -> bool:
	return root.get_child_count() < int(root.get_meta("detail_part_limit", MODULE_DETAIL_PART_LIMIT))


static func _tag_module_detail(root: Node3D, node: MeshInstance3D, kind: String) -> MeshInstance3D:
	node.name = "%s_%02d" % [kind, root.get_child_count()]
	node.add_to_group("mecha_module_detail_part")
	node.set_meta("detail_kind", kind)
	node.set_meta("module_slot", root.get_meta("module_slot", "unknown"))
	return node


static func _module_box(
	root: Node3D,
	size: Vector3,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	kind: String = "ModulePanel"
) -> MeshInstance3D:
	if not _module_slot_available(root):
		return null
	var node := _box(root, size, position, material)
	node.rotation = rotation
	return _tag_module_detail(root, node, kind)


static func _module_sphere(
	root: Node3D,
	radius: float,
	position: Vector3,
	material: Material,
	scale_value: Vector3 = Vector3.ONE,
	kind: String = "ModuleBearing"
) -> MeshInstance3D:
	if not _module_slot_available(root):
		return null
	return _tag_module_detail(root, _sphere(root, radius, position, material, scale_value), kind)


static func _module_cylinder(
	root: Node3D,
	radius: float,
	height: float,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	kind: String = "ModuleConduit"
) -> MeshInstance3D:
	if not _module_slot_available(root):
		return null
	return _tag_module_detail(root, _cylinder(root, radius, height, position, material, rotation), kind)


static func _module_torus(
	root: Node3D,
	inner_radius: float,
	outer_radius: float,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	kind: String = "ModuleCoupler"
) -> MeshInstance3D:
	if not _module_slot_available(root):
		return null
	return _tag_module_detail(root, _torus(root, inner_radius, outer_radius, position, material, rotation), kind)


static func _count_group_meshes(node: Node, group: String) -> int:
	var count := 1 if node is MeshInstance3D and node.is_in_group(group) else 0
	for child: Node in node.get_children():
		count += _count_group_meshes(child, group)
	return count

static func _count_group_triangles(node: Node, group: String) -> int:
	var count := 0
	if node is MeshInstance3D and node.is_in_group(group):
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			count += mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		count += _count_group_triangles(child, group)
	return count


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
	mesh.radial_segments = MODULE_RADIAL_SEGMENTS
	mesh.rings = MODULE_SPHERE_RINGS
	var node := _mesh(root, mesh, position, material)
	node.scale = scale_value
	return node


static func _cylinder(root: Node3D, radius: float, height: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = MODULE_RADIAL_SEGMENTS
	var node := _mesh(root, mesh, position, material)
	node.rotation = rotation
	return node


static func _torus(root: Node3D, inner_radius: float, outer_radius: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = MODULE_TORUS_RINGS
	mesh.ring_segments = MODULE_TORUS_SEGMENTS
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
