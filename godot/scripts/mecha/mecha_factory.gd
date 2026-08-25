class_name MechaFactory
extends RefCounted

## Procedural factory for the ten original racing architectures. Every model is
## assembled from Godot primitives, keeping the source portable and editable.

const HERO_DETAIL_PART_LIMIT := 46
const RACE_DETAIL_PART_LIMIT := 28
const HERO_CHASSIS_DETAIL_TRIANGLE_BUDGET := 18000
const RACE_CHASSIS_DETAIL_TRIANGLE_BUDGET := 10500
const HERO_VISUAL_TRIANGLE_BUDGET := 70000
const RACE_VISUAL_TRIANGLE_BUDGET := 50000
const HERO_WEB_MESH_BUDGET := 200
const RACE_WEB_MESH_BUDGET := 140
const RADIAL_SEGMENTS := 20
const SPHERE_RINGS := 10
const TORUS_RINGS := 24
const TORUS_SEGMENTS := 10


static func build(chassis: Dictionary, paint: Color, is_player: bool = false, customization: Dictionary = {}) -> RacerVisual:
	var root := RacerVisual.new()
	root.name = "Mecha_%s" % String(chassis.get("id", "unknown"))
	root.set_meta("chassis_id", chassis.get("id", "biped"))
	var chassis_id := String(chassis.get("id", "biped"))
	var detail_tier := 2 if is_player else 1
	root.set_meta("visual_detail_tier", detail_tier)
	root.set_meta("visual_detail_part_budget", HERO_DETAIL_PART_LIMIT if is_player else RACE_DETAIL_PART_LIMIT)
	root.set_meta("chassis_detail_triangle_budget", HERO_CHASSIS_DETAIL_TRIANGLE_BUDGET if is_player else RACE_CHASSIS_DETAIL_TRIANGLE_BUDGET)
	root.set_meta("visual_triangle_budget", HERO_VISUAL_TRIANGLE_BUDGET if is_player else RACE_VISUAL_TRIANGLE_BUDGET)
	var native_locomotion := _native_locomotion_holder(root, chassis_id)

	var primary := MaterialLibrary.mecha_for(chassis, paint, "primary")
	var dark := MaterialLibrary.mecha_for(chassis, paint.darkened(0.64), "secondary")
	var detail_surface := MaterialLibrary.mecha_detail(paint.lerp(Color.WHITE, 0.08), 3.8 if is_player else 3.2)
	var joint := MaterialLibrary.joint()
	var cockpit := MaterialLibrary.cockpit()
	var glow_color := Color("64ebff") if is_player else Color(String(chassis.get("glow", "ff9c55")))
	var glow := MaterialLibrary.emissive(glow_color, 3.4 if is_player else 2.3)

	match chassis_id:
		"tripod": _radial(root, native_locomotion, 3, 2.35, primary, dark, joint, glow, 0.0)
		"quadruped": _quadruped(root, native_locomotion, primary, dark, joint, glow)
		"hexapod": _radial(root, native_locomotion, 6, 2.7, primary, dark, joint, glow, PI / 6.0)
		"octopod": _radial(root, native_locomotion, 8, 3.1, primary, dark, joint, glow, PI / 8.0)
		"hover": _hover(root, native_locomotion, primary, dark, glow)
		"tracked": _tracked(root, native_locomotion, primary, dark, joint, glow)
		"monowheel": _monowheel(root, native_locomotion, primary, dark, joint, glow)
		"orb": _orb(root, native_locomotion, primary, dark, glow)
		"centurion": _centurion(root, native_locomotion, primary, dark, joint, glow)
		_: _biped(root, native_locomotion, primary, dark, joint, glow)
	var detail_holder := _detail_holder(root, chassis_id, is_player)
	_architecture_details(detail_holder, chassis_id, primary, detail_surface, dark, joint, cockpit, glow, detail_tier)
	root.set_meta("procedural_detail_parts", detail_holder.get_child_count())


	_mark_native_locomotion_parts(native_locomotion)
	_mark_chassis_body(root, native_locomotion)

	_cockpit(root, chassis, primary, dark, cockpit, glow)
	MechaVisualModules.install(root, chassis, customization, primary, dark, joint, glow)
	LocomotionVisuals.install(root, chassis, customization, primary, dark, joint, glow)
	var detail_mesh_count := _count_mesh_instances(detail_holder)
	var visual_mesh_count := _count_mesh_instances(root)
	var chassis_detail_triangle_count := _count_mesh_triangles(detail_holder)
	var visual_triangle_count := _count_mesh_triangles(root)
	var web_mesh_budget := HERO_WEB_MESH_BUDGET if is_player else RACE_WEB_MESH_BUDGET
	var visual_triangle_budget := HERO_VISUAL_TRIANGLE_BUDGET if is_player else RACE_VISUAL_TRIANGLE_BUDGET
	root.set_meta("detail_mesh_count", detail_mesh_count)
	root.set_meta("visual_mesh_count", visual_mesh_count)
	root.set_meta("chassis_detail_triangle_count", chassis_detail_triangle_count)
	root.set_meta("visual_triangle_count", visual_triangle_count)
	root.set_meta("web_mesh_budget", web_mesh_budget)
	root.set_meta("web_mesh_budget_ok", visual_mesh_count <= web_mesh_budget)
	root.set_meta("visual_triangle_budget_ok", visual_triangle_count <= visual_triangle_budget)
	detail_holder.set_meta("triangle_count", chassis_detail_triangle_count)
	detail_holder.set_meta("triangle_budget_ok", chassis_detail_triangle_count <= int(detail_holder.get_meta("triangle_budget", 0)))
	root.scale = Vector3.ONE * float(chassis.get("visual_scale", 1.0))
	return root


static func _biped(root: Node3D, native_locomotion: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	_box(root, Vector3(2.8, 1.0, 3.6), Vector3(0, 2.4, 0.15), primary)
	for index in range(2):
		var x := -0.92 if index == 0 else 0.92
		var hip := Vector3(x, 2.1, 0.2)
		var knee := Vector3(x * 1.12, 1.0, 0.25)
		var foot := Vector3(x * 1.18, 0.12, -0.15)
		_limb(native_locomotion, hip, knee, 0.24, dark, index * PI)
		_limb(native_locomotion, knee, foot, 0.29, joint, index * PI + 0.4)
		_box(native_locomotion, Vector3(0.8, 0.3, 1.55), foot + Vector3(0, 0.04, -0.42), primary)
	_reactor(root, Vector3(0, 2.5, 1.8), Vector3(1.7, 0.45, 0.2), glow)


static func _quadruped(root: Node3D, native_locomotion: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	_box(root, Vector3(3.35, 0.95, 4.5), Vector3(0, 1.75, 0), primary)
	var anchors := [Vector3(-1.25, 1.55, -1.5), Vector3(1.25, 1.55, -1.5), Vector3(-1.25, 1.55, 1.4), Vector3(1.25, 1.55, 1.4)]
	for index in range(anchors.size()):
		var hip: Vector3 = anchors[index]
		var knee := hip + Vector3(signf(hip.x) * 0.7, -0.65, 0.18)
		var foot := knee + Vector3(signf(hip.x) * 0.45, -0.78, -0.18)
		_limb(native_locomotion, hip, knee, 0.2, dark, index * PI * 0.5)
		_limb(native_locomotion, knee, foot, 0.23, joint, index * PI * 0.5 + 0.5)
		_sphere(native_locomotion, 0.32, foot, primary, Vector3(1.35, 0.55, 1.0))
	_reactor(root, Vector3(0, 1.85, 2.15), Vector3(2.2, 0.34, 0.22), glow)


static func _radial(root: Node3D, native_locomotion: Node3D, count: int, radius: float, primary: Material, dark: Material, joint: Material, glow: Material, offset: float) -> void:
	var body_radius := 1.55 + count * 0.08
	_cylinder(root, body_radius, 0.75, Vector3(0, 1.9, 0), primary)
	_sphere(root, body_radius * 0.72, Vector3(0, 2.25, -0.15), dark, Vector3(1.0, 0.55, 1.15))
	for index in range(count):
		var angle := TAU * float(index) / float(count) + offset
		var direction := Vector3(cos(angle), 0, sin(angle))
		var hip := direction * body_radius * 0.72 + Vector3.UP * 1.8
		var knee := direction * radius + Vector3.UP * 0.9
		var foot := direction * (radius + 0.65) + Vector3.UP * 0.1
		_limb(native_locomotion, hip, knee, 0.18 + count * 0.008, dark, angle)
		_limb(native_locomotion, knee, foot, 0.21 + count * 0.008, joint, angle + PI)
		_sphere(native_locomotion, 0.26, foot, primary, Vector3(1.35, 0.55, 1.0))
	_reactor(root, Vector3(0, 1.95, body_radius * 0.9), Vector3(body_radius * 1.15, 0.3, 0.2), glow)


static func _hover(root: Node3D, native_locomotion: Node3D, primary: Material, dark: Material, glow: Material) -> void:
	_box(root, Vector3(4.2, 0.75, 5.4), Vector3(0, 1.35, 0), primary)
	_box(root, Vector3(2.5, 0.65, 3.5), Vector3(0, 1.9, -0.25), dark)
	for x: float in [-1.75, 1.75]:
		for z: float in [-1.55, 1.55]:
			_cylinder(native_locomotion, 0.52, 1.35, Vector3(x, 0.72, z), dark, Vector3(PI / 2.0, 0, 0))
			_sphere(native_locomotion, 0.34, Vector3(x, 0.55, z + 0.3), glow)
	_reactor(root, Vector3(0, 1.25, 2.74), Vector3(3.4, 0.22, 0.18), glow)


static func _tracked(root: Node3D, native_locomotion: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	_box(root, Vector3(3.5, 1.4, 4.4), Vector3(0, 1.55, -0.1), primary)
	for x: float in [-1.72, 1.72]:
		_box(native_locomotion, Vector3(1.0, 0.95, 5.2), Vector3(x, 0.68, 0), dark)
		for z: float in [-1.65, -0.55, 0.55, 1.65]:
			_cylinder(native_locomotion, 0.42, 0.95, Vector3(x, 0.65, z), joint, Vector3(0, 0, PI / 2.0))
	_reactor(root, Vector3(0, 1.6, 2.2), Vector3(2.6, 0.3, 0.22), glow)


static func _monowheel(root: Node3D, native_locomotion: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var wheel := TorusMesh.new()
	wheel.inner_radius = 1.25
	wheel.outer_radius = 2.05
	var wheel_node := MeshInstance3D.new()
	wheel.rings = TORUS_RINGS
	wheel.ring_segments = TORUS_SEGMENTS
	wheel_node.name = "GyroWheel"
	wheel_node.mesh = wheel
	wheel_node.material_override = dark
	wheel_node.rotation_degrees = Vector3(90, 0, 0)
	wheel_node.position = Vector3(0, 1.72, 0)
	wheel_node.add_to_group("mecha_limb")
	wheel_node.set_meta("phase", 0.0)
	native_locomotion.add_child(wheel_node)
	_box(root, Vector3(1.55, 2.1, 2.5), Vector3(0, 1.8, 0), primary)
	_sphere(root, 0.65, Vector3(0, 1.8, 0.2), joint)
	_reactor(root, Vector3(0, 1.75, 1.35), Vector3(1.0, 0.25, 0.18), glow)


static func _orb(root: Node3D, native_locomotion: Node3D, primary: Material, dark: Material, glow: Material) -> void:
	_sphere(root, 1.75, Vector3(0, 1.8, 0), primary, Vector3(1.0, 1.0, 1.15))
	for axis in range(3):
		var ring := TorusMesh.new()
		ring.inner_radius = 1.78
		ring.outer_radius = 1.94
		var node := MeshInstance3D.new()
		ring.rings = TORUS_RINGS
		ring.ring_segments = TORUS_SEGMENTS
		node.mesh = ring
		node.material_override = dark
		node.position = Vector3(0, 1.8, 0)
		node.rotation = Vector3(PI / 2.0 if axis == 0 else 0.0, PI / 2.0 if axis == 1 else 0.0, PI / 2.0 if axis == 2 else 0.0)
		node.add_to_group("mecha_limb")
		node.set_meta("phase", axis * 1.8)
		native_locomotion.add_child(node)
	_reactor(root, Vector3(0, 1.8, 1.72), Vector3(1.5, 0.28, 0.18), glow)


static func _centurion(root: Node3D, native_locomotion: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	for segment in range(6):
		var z := (float(segment) - 2.5) * 0.95
		_box(root, Vector3(2.0, 0.75, 1.05), Vector3(0, 1.45, z), primary if segment % 2 == 0 else dark)
		for side: float in [-1.0, 1.0]:
			var hip := Vector3(side * 0.82, 1.35, z)
			var knee := Vector3(side * 1.55, 0.75, z + (0.2 if segment % 2 == 0 else -0.2))
			var foot := Vector3(side * 2.05, 0.12, z)
			_limb(native_locomotion, hip, knee, 0.12, dark, segment * 0.72 + (PI if side > 0 else 0.0))
			_limb(native_locomotion, knee, foot, 0.15, joint, segment * 0.72)
	_reactor(root, Vector3(0, 1.5, 3.0), Vector3(1.5, 0.25, 0.18), glow)


static func _detail_holder(root: Node3D, chassis_id: String, hero_detail: bool) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ChassisDetail_%s" % chassis_id
	holder.add_to_group("mecha_chassis_detail")
	holder.set_meta("detail_tier", 2 if hero_detail else 1)
	holder.set_meta("detail_part_limit", HERO_DETAIL_PART_LIMIT if hero_detail else RACE_DETAIL_PART_LIMIT)
	holder.set_meta("triangle_budget", HERO_CHASSIS_DETAIL_TRIANGLE_BUDGET if hero_detail else RACE_CHASSIS_DETAIL_TRIANGLE_BUDGET)
	root.add_child(holder)
	return holder


static func _architecture_details(
	root: Node3D,
	chassis_id: String,
	primary: Material,
	detail_surface: Material,
	dark: Material,
	joint: Material,
	cockpit: Material,
	glow: Material,
	detail_tier: int
) -> void:
	match chassis_id:
		"tripod":
			_radial_architecture_detail(root, 3, 1.72, detail_surface, dark, joint, cockpit, glow, detail_tier, 0.0)
		"quadruped":
			_quadruped_detail(root, detail_surface, dark, joint, cockpit, glow, detail_tier)
		"hexapod":
			_radial_architecture_detail(root, 6, 2.02, detail_surface, dark, joint, cockpit, glow, detail_tier, PI / 6.0)
		"octopod":
			_radial_architecture_detail(root, 8, 2.34, detail_surface, dark, joint, cockpit, glow, detail_tier, PI / 8.0)
		"hover":
			_hover_detail(root, detail_surface, dark, joint, cockpit, glow, detail_tier)
		"tracked":
			_tracked_detail(root, detail_surface, dark, joint, cockpit, glow, detail_tier)
		"monowheel":
			_monowheel_detail(root, detail_surface, dark, joint, cockpit, glow, detail_tier)
		"orb":
			_orb_detail(root, detail_surface, dark, joint, cockpit, glow, detail_tier)
		"centurion":
			_centurion_detail(root, detail_surface, dark, joint, cockpit, glow, detail_tier)
		_:
			_biped_detail(root, detail_surface, dark, joint, cockpit, glow, detail_tier)
	_common_surface_detail(root, chassis_id, primary, detail_surface, dark, joint, cockpit, glow, detail_tier)


static func _biped_detail(root: Node3D, panel: Material, dark: Material, joint: Material, cockpit: Material, glow: Material, detail_tier: int) -> void:
	_detail_box(root, Vector3(1.72, 0.22, 1.72), Vector3(0, 2.66, -0.48), panel, Vector3(-0.09, 0, 0), "ChestPlate")
	_detail_box(root, Vector3(1.18, 0.16, 1.34), Vector3(0, 2.83, -0.76), dark, Vector3(-0.16, 0, 0), "ChestInset")
	for side: float in [-1.0, 1.0]:
		_detail_box(root, Vector3(0.62, 0.62, 1.64), Vector3(side * 1.46, 2.66, 0.02), panel, Vector3(0, 0, side * 0.15), "ShoulderPauldron")
		_detail_sphere(root, 0.26, Vector3(side * 1.22, 2.26, 0.42), joint, Vector3(1.35, 0.82, 1.0), "HipBearing")
		_detail_piston(root, Vector3(side * 1.16, 2.46, 0.54), Vector3(side * 0.96, 1.76, 0.64), 0.09, dark, joint)
		_detail_box(root, Vector3(0.28, 0.42, 0.86), Vector3(side * 1.16, 2.18, -0.85), dark, Vector3(0.12, 0, side * 0.08), "TorsoLatch")
	for plate_index in range(3):
		_detail_box(root, Vector3(0.92 - plate_index * 0.12, 0.13, 0.34), Vector3(0, 2.48 + plate_index * 0.27, 1.78), panel, Vector3(0.18, 0, 0), "SpineArmor")
	_detail_vent_bank(root, Vector3(0, 2.35, 1.94), Vector3(0.36, 0, 0), Vector3(0.22, 0.12, 0.52), 5 if detail_tier > 1 else 3, dark)
	_detail_sensor_cluster(root, Vector3(0, 3.25, -1.32), cockpit, glow, 0.78)


static func _quadruped_detail(root: Node3D, panel: Material, dark: Material, joint: Material, cockpit: Material, glow: Material, detail_tier: int) -> void:
	_detail_box(root, Vector3(2.34, 0.22, 1.42), Vector3(0, 2.23, -1.42), panel, Vector3(-0.16, 0, 0), "ForwardCarapace")
	_detail_box(root, Vector3(1.78, 0.18, 1.02), Vector3(0, 2.36, -2.04), dark, Vector3(-0.24, 0, 0), "ForwardInset")
	for z: float in [-1.34, 1.28]:
		for side: float in [-1.0, 1.0]:
			_detail_box(root, Vector3(0.48, 0.52, 1.12), Vector3(side * 1.68, 1.92, z), panel, Vector3(0, 0, side * 0.13), "ShoulderArmor")
			_detail_sphere(root, 0.22, Vector3(side * 1.44, 1.62, z), joint, Vector3(1.22, 0.82, 1.0), "ShoulderBearing")
	for plate_index in range(5 if detail_tier > 1 else 3):
		var z := (float(plate_index) - (2.0 if detail_tier > 1 else 1.0)) * 0.72
		_detail_box(root, Vector3(1.36, 0.14, 0.52), Vector3(0, 2.3, z), panel, Vector3(0.05, 0, 0), "SpinalPlate")
	_detail_piston(root, Vector3(-1.32, 1.48, -0.82), Vector3(1.32, 1.48, -0.82), 0.08, dark, joint)
	_detail_vent_bank(root, Vector3(0, 1.92, 2.26), Vector3(0.42, 0, 0), Vector3(0.24, 0.12, 0.48), 5 if detail_tier > 1 else 3, dark)
	_detail_sensor_cluster(root, Vector3(0, 2.44, -2.28), cockpit, glow, 0.68)


static func _radial_architecture_detail(
	root: Node3D,
	count: int,
	radius: float,
	panel: Material,
	dark: Material,
	joint: Material,
	cockpit: Material,
	glow: Material,
	detail_tier: int,
	offset: float
) -> void:
	var architecture_prefix := "Tripod" if count == 3 else ("Hexapod" if count == 6 else "Octopod")
	_detail_cylinder(root, 1.02 + count * 0.045, 0.18, Vector3(0, 2.64, -0.08), panel, Vector3.ZERO, "%sCrown" % architecture_prefix)
	_detail_torus(root, 0.72 + count * 0.04, 0.88 + count * 0.04, Vector3(0, 2.48, -0.08), dark, Vector3.ZERO, "%sCollar" % architecture_prefix)
	for index in range(count):
		var angle := TAU * float(index) / float(count) + offset
		var direction := Vector3(cos(angle), 0, sin(angle))
		var tangent := Vector3(-direction.z, 0, direction.x)
		_detail_box(
			root,
			Vector3(0.68 if count < 8 else 0.54, 0.24, 1.12),
			direction * radius + Vector3.UP * 2.22,
			panel,
			Vector3(0.08, -angle, tangent.x * 0.035),
			"%sRadialPlate" % architecture_prefix
		)
		_detail_sphere(root, 0.18, direction * (radius - 0.34) + Vector3.UP * 2.03, joint, Vector3(1.34, 0.72, 1.0), "%sBearing" % architecture_prefix)
		if count <= 6 or index % 2 == 0:
			_detail_box(root, Vector3(0.16, 0.3, 0.68), direction * (radius + 0.18) + Vector3.UP * 2.46, dark, Vector3(0, -angle, 0), "%sOuterRib" % architecture_prefix)
		if detail_tier > 1 and (count < 8 or index % 2 == 0):
			_detail_sphere(root, 0.09, direction * (radius + 0.28) + Vector3.UP * 2.58, glow, Vector3(1.0, 0.68, 1.0), "%sStatusNode" % architecture_prefix)
	_detail_sensor_cluster(root, Vector3(0, 3.0 + count * 0.035, -1.08 - count * 0.035), cockpit, glow, 0.58 + count * 0.025)
	_detail_vent_bank(root, Vector3(0, 2.24, 1.3 + count * 0.05), Vector3(0.3, 0, 0), Vector3(0.16, 0.11, 0.44), 5 if detail_tier > 1 else 3, dark)


static func _hover_detail(root: Node3D, panel: Material, dark: Material, joint: Material, cockpit: Material, glow: Material, detail_tier: int) -> void:
	_detail_box(root, Vector3(2.26, 0.18, 1.62), Vector3(0, 1.88, -1.68), panel, Vector3(-0.16, 0, 0), "HoverNoseArmor")
	_detail_box(root, Vector3(1.54, 0.13, 1.08), Vector3(0, 2.03, -2.18), dark, Vector3(-0.26, 0, 0), "HoverNoseInset")
	for side: float in [-1.0, 1.0]:
		_detail_box(root, Vector3(1.24, 0.18, 2.76), Vector3(side * 2.12, 1.38, 0.14), panel, Vector3(0, 0, side * 0.08), "HoverWingPanel")
		_detail_box(root, Vector3(0.18, 0.38, 2.3), Vector3(side * 2.58, 1.18, 0.42), dark, Vector3(0, 0, side * 0.18), "HoverEdgeVane")
		_detail_cylinder(root, 0.28, 0.62, Vector3(side * 1.64, 1.38, 2.44), joint, Vector3(PI / 2.0, 0, 0), "VectorGimbal")
		_detail_torus(root, 0.24, 0.36, Vector3(side * 1.64, 1.38, 2.76), glow, Vector3(PI / 2.0, 0, 0), "VectorNozzle")
	_detail_vent_bank(root, Vector3(0, 2.26, 0.82), Vector3(0.42, 0, 0), Vector3(0.24, 0.11, 0.82), 5 if detail_tier > 1 else 3, dark)
	_detail_sensor_cluster(root, Vector3(0, 2.42, -2.46), cockpit, glow, 0.62)


static func _tracked_detail(root: Node3D, panel: Material, dark: Material, joint: Material, cockpit: Material, glow: Material, detail_tier: int) -> void:
	for side: float in [-1.0, 1.0]:
		_detail_box(root, Vector3(0.48, 0.22, 4.7), Vector3(side * 1.66, 1.28, 0.04), panel, Vector3(0, 0, side * 0.04), "TrackFender")
		for z: float in [-1.46, 0.0, 1.46]:
			_detail_box(root, Vector3(0.62, 0.18, 0.86), Vector3(side * 1.65, 1.44, z), dark, Vector3(0, 0, side * 0.05), "FenderSegment")
	_detail_box(root, Vector3(2.42, 0.22, 1.38), Vector3(0, 2.34, -1.45), panel, Vector3(-0.22, 0, 0), "GlacisPlate")
	_detail_box(root, Vector3(1.46, 0.48, 1.52), Vector3(0, 2.4, -0.18), dark, Vector3.ZERO, "CommandCupola")
	_detail_torus(root, 0.5, 0.64, Vector3(0, 2.66, -0.28), joint, Vector3.ZERO, "CupolaRing")
	_detail_sensor_cluster(root, Vector3(0, 2.84, -0.72), cockpit, glow, 0.54)
	_detail_vent_bank(root, Vector3(0, 2.04, 2.15), Vector3(0.4, 0, 0), Vector3(0.22, 0.12, 0.54), 5 if detail_tier > 1 else 3, dark)


static func _monowheel_detail(root: Node3D, panel: Material, dark: Material, joint: Material, cockpit: Material, glow: Material, detail_tier: int) -> void:
	for side: float in [-1.0, 1.0]:
		_detail_box(root, Vector3(0.3, 2.82, 0.48), Vector3(side * 1.16, 1.75, 0.06), panel, Vector3(0, 0, side * 0.08), "GyroFork")
		_detail_torus(root, 0.46, 0.62, Vector3(side * 1.02, 1.74, 0.0), joint, Vector3(0, 0, PI / 2.0), "HubCollar")
		_detail_cylinder(root, 0.31, 0.72, Vector3(side * 0.82, 1.74, 0.0), dark, Vector3(0, 0, PI / 2.0), "HubActuator")
	for index in range(6 if detail_tier > 1 else 4):
		var angle := TAU * float(index) / float(6 if detail_tier > 1 else 4)
		var offset := Vector3(cos(angle) * 0.88, sin(angle) * 0.88, -0.62)
		_detail_box(root, Vector3(0.38, 0.18, 0.54), Vector3(0, 1.78, 0) + offset, panel, Vector3(0, 0, -angle), "HubArmor")
	_detail_sensor_cluster(root, Vector3(0, 2.92, -1.06), cockpit, glow, 0.55)
	_detail_vent_bank(root, Vector3(0, 1.66, 1.34), Vector3(0.3, 0, 0), Vector3(0.16, 0.12, 0.4), 3, dark)


static func _orb_detail(root: Node3D, panel: Material, dark: Material, joint: Material, cockpit: Material, glow: Material, detail_tier: int) -> void:
	var shell_count := 8 if detail_tier > 1 else 6
	for index in range(shell_count):
		var angle := TAU * float(index) / float(shell_count)
		var direction := Vector3(cos(angle), 0, sin(angle))
		_detail_box(root, Vector3(0.58, 0.13, 0.86), direction * 1.62 + Vector3.UP * 1.8, panel, Vector3(0, -angle, direction.x * 0.08), "OrbShellPlate")
		if index % 2 == 0:
			_detail_sphere(root, 0.1, direction * 1.78 + Vector3.UP * 1.8, glow, Vector3(1.0, 0.7, 1.0), "OrbPhaseNode")
	for side: float in [-1.0, 1.0]:
		_detail_cylinder(root, 0.42, 0.42, Vector3(side * 1.86, 1.8, 0), joint, Vector3(0, 0, PI / 2.0), "OrbAxisHub")
		_detail_torus(root, 0.38, 0.52, Vector3(side * 1.98, 1.8, 0), dark, Vector3(0, 0, PI / 2.0), "OrbAxisCollar")
	_detail_sensor_cluster(root, Vector3(0, 2.54, -1.45), cockpit, glow, 0.5)
	_detail_vent_bank(root, Vector3(0, 2.6, 0.76), Vector3(0.28, 0, 0), Vector3(0.14, 0.1, 0.36), 3, dark)


static func _centurion_detail(root: Node3D, panel: Material, dark: Material, joint: Material, cockpit: Material, glow: Material, detail_tier: int) -> void:
	for segment in range(6):
		var z := (float(segment) - 2.5) * 0.95
		_detail_box(root, Vector3(1.52, 0.16, 0.72), Vector3(0, 1.9, z), panel, Vector3(0.06, 0, 0), "DorsalScale")
		if detail_tier > 1 or segment % 2 == 0:
			for side: float in [-1.0, 1.0]:
				_detail_box(root, Vector3(0.28, 0.38, 0.74), Vector3(side * 1.12, 1.56, z), dark, Vector3(0, 0, side * 0.11), "SegmentRib")
	_detail_box(root, Vector3(1.3, 0.44, 1.1), Vector3(0, 1.86, -3.02), panel, Vector3(-0.15, 0, 0), "CenturionHead")
	_detail_sensor_cluster(root, Vector3(0, 2.12, -3.62), cockpit, glow, 0.52)
	_detail_piston(root, Vector3(-0.72, 1.48, 2.46), Vector3(0.72, 1.48, 2.9), 0.07, dark, joint)
	_detail_vent_bank(root, Vector3(0, 1.72, 2.98), Vector3(0.28, 0, 0), Vector3(0.16, 0.1, 0.38), 3, dark)


static func _common_surface_detail(
	root: Node3D,
	chassis_id: String,
	_primary: Material,
	panel: Material,
	dark: Material,
	joint: Material,
	cockpit: Material,
	glow: Material,
	detail_tier: int
) -> void:
	var compact_height := 2.16 if chassis_id in ["hover", "tracked", "orb", "monowheel", "centurion"] else 2.7
	_detail_box(root, Vector3(0.12, 0.16, 1.24), Vector3(0, compact_height, -1.36), dark, Vector3.ZERO, "CenterSeam")
	for side: float in [-1.0, 1.0]:
		_detail_sphere(root, 0.09, Vector3(side * 0.54, compact_height + 0.08, -1.42), joint, Vector3(1.0, 0.52, 1.0), "PanelFastener")
	if detail_tier > 1:
		_detail_box(root, Vector3(1.18, 0.08, 0.22), Vector3(0, compact_height + 0.32, -1.43), panel, Vector3.ZERO, "IdentificationRail")
		_detail_sphere(root, 0.08, Vector3(0, compact_height + 0.33, -1.57), glow, Vector3(1.5, 0.5, 1.0), "IdentificationLight")
		_detail_sphere(root, 0.14, Vector3(0, compact_height + 0.54, -1.34), cockpit, Vector3(1.0, 0.62, 1.0), "TelemetryLens")


static func _detail_sensor_cluster(root: Node3D, position: Vector3, cockpit: Material, glow: Material, width: float) -> void:
	_detail_box(root, Vector3(width, 0.28, 0.36), position, cockpit, Vector3(-0.08, 0, 0), "SensorBrow")
	for side: float in [-1.0, 1.0]:
		_detail_sphere(root, 0.1, position + Vector3(side * width * 0.28, -0.02, -0.2), glow, Vector3(1.25, 0.72, 0.58), "SensorLens")


static func _detail_vent_bank(
	root: Node3D,
	center: Vector3,
	spacing_axis: Vector3,
	slat_size: Vector3,
	count: int,
	material: Material
) -> void:
	var midpoint := float(count - 1) * 0.5
	for index in range(count):
		_detail_box(root, slat_size, center + spacing_axis * (float(index) - midpoint), material, Vector3(-0.12, 0, 0), "HeatVent")


static func _detail_piston(root: Node3D, start: Vector3, finish: Vector3, radius: float, sleeve: Material, rod: Material) -> void:
	var direction := finish - start
	if direction.length_squared() <= 0.0001:
		return
	var sleeve_end := start.lerp(finish, 0.56)
	var rod_start := start.lerp(finish, 0.42)
	var sleeve_node := _detail_cylinder(root, radius * 1.35, start.distance_to(sleeve_end), start.lerp(sleeve_end, 0.5), sleeve, Vector3.ZERO, "ActuatorSleeve")
	var rod_node := _detail_cylinder(root, radius * 0.72, rod_start.distance_to(finish), rod_start.lerp(finish, 0.5), rod, Vector3.ZERO, "ActuatorRod")
	for node: MeshInstance3D in [sleeve_node, rod_node]:
		if node != null:
			node.quaternion = Quaternion(Vector3.UP, direction.normalized())
			node.add_to_group("mecha_actuator")
			node.set_meta("mechanical_axis", direction.normalized())


static func _detail_slot_available(root: Node3D) -> bool:
	return root.get_child_count() < int(root.get_meta("detail_part_limit", RACE_DETAIL_PART_LIMIT))


static func _tag_detail(root: Node3D, node: MeshInstance3D, kind: String) -> MeshInstance3D:
	node.name = "%s_%02d" % [kind, root.get_child_count()]
	node.add_to_group("mecha_chassis_detail_part")
	node.set_meta("detail_kind", kind)
	node.set_meta("detail_lod", int(root.get_meta("detail_tier", 1)))
	return node


static func _detail_box(
	root: Node3D,
	size: Vector3,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	kind: String = "ArmorPanel"
) -> MeshInstance3D:
	if not _detail_slot_available(root):
		return null
	var node := _box(root, size, position, material)
	node.rotation = rotation
	return _tag_detail(root, node, kind)


static func _detail_sphere(
	root: Node3D,
	radius: float,
	position: Vector3,
	material: Material,
	scale_value: Vector3 = Vector3.ONE,
	kind: String = "Joint"
) -> MeshInstance3D:
	if not _detail_slot_available(root):
		return null
	return _tag_detail(root, _sphere(root, radius, position, material, scale_value), kind)


static func _detail_cylinder(
	root: Node3D,
	radius: float,
	height: float,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	kind: String = "MechanicalCollar"
) -> MeshInstance3D:
	if not _detail_slot_available(root):
		return null
	return _tag_detail(root, _cylinder(root, radius, height, position, material, rotation), kind)


static func _detail_torus(
	root: Node3D,
	inner_radius: float,
	outer_radius: float,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	kind: String = "ServiceRing"
) -> MeshInstance3D:
	if not _detail_slot_available(root):
		return null
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = TORUS_RINGS
	mesh.ring_segments = TORUS_SEGMENTS
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.rotation = rotation
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	node.add_to_group("mecha_fps_occluder")
	root.add_child(node)
	return _tag_detail(root, node, kind)


static func _native_locomotion_holder(root: RacerVisual, chassis_id: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = "NativeLocomotion_%s" % chassis_id
	holder.add_to_group("mecha_native_locomotion")
	holder.set_meta("native_locomotion", true)
	holder.set_meta("family_id", chassis_id)
	root.add_child(holder)
	return holder


static func _mark_native_locomotion_parts(holder: Node) -> void:
	for child: Node in holder.get_children():
		child.add_to_group("mecha_native_locomotion_part")
		child.set_meta("native_locomotion", true)
		if child.get_child_count() > 0:
			_mark_native_locomotion_parts(child)


static func _mark_chassis_body(root: RacerVisual, native_locomotion: Node3D) -> void:
	for child: Node in root.get_children():
		if child == native_locomotion:
			continue
		child.add_to_group("mecha_chassis_body")
		child.set_meta("chassis_body", true)


static func _cockpit(root: Node3D, chassis: Dictionary, primary: Material, dark: Material, cockpit: Material, glow: Material) -> void:
	var cockpit_offset: Vector3 = chassis.get("cockpit_offset", Vector3(0, 2.65, 0.10))
	var canopy := _sphere(root, 0.72, cockpit_offset + Vector3(0, 0.20, -0.45), cockpit, Vector3(1.2, 0.65, 1.6))
	canopy.name = "CockpitCanopy"
	canopy.add_to_group("mecha_fps_occluder")
	var visor := _box(root, Vector3(0.95, 0.18, 0.58), cockpit_offset + Vector3(0, 0.23, -1.25), glow)
	visor.name = "CockpitVisor"
	visor.add_to_group("mecha_fps_occluder")
	var left_frame := _box(root, Vector3(0.16, 0.55, 1.25), cockpit_offset + Vector3(-0.72, -0.10, -0.60), primary)
	left_frame.add_to_group("mecha_fps_occluder")
	var right_frame := _box(root, Vector3(0.16, 0.55, 1.25), cockpit_offset + Vector3(0.72, -0.10, -0.60), primary)
	right_frame.add_to_group("mecha_fps_occluder")
	var dashboard := _box(root, Vector3(1.55, 0.12, 0.34), cockpit_offset + Vector3(0, -0.68, -2.05), cockpit)
	dashboard.name = "CockpitDashboard"
	dashboard.add_to_group("mecha_cockpit_interior")
	var display := _box(root, Vector3(0.72, 0.05, 0.18), cockpit_offset + Vector3(0, -0.56, -2.17), glow)
	display.name = "CockpitDisplay"
	display.add_to_group("mecha_cockpit_interior")
	for side: float in [-1.0, 1.0]:
		var inner_frame := _box(root, Vector3(0.10, 0.78, 0.12), cockpit_offset + Vector3(side * 1.55, 0.02, -2.02), cockpit)
		inner_frame.name = "CockpitFrameLeft" if side < 0.0 else "CockpitFrameRight"
		inner_frame.add_to_group("mecha_cockpit_interior")
	var top_frame := _box(root, Vector3(3.15, 0.08, 0.12), cockpit_offset + Vector3(0, 0.90, -2.04), cockpit)
	top_frame.name = "CockpitTopFrame"
	top_frame.add_to_group("mecha_cockpit_interior")


static func _reactor(root: Node3D, position: Vector3, size: Vector3, material: Material) -> void:
	var node := _box(root, size, position, material)
	node.add_to_group("mecha_glow")


static func _box(root: Node3D, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	node.add_to_group("mecha_fps_occluder")
	root.add_child(node)
	return node


static func _sphere(root: Node3D, radius: float, position: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	mesh.radial_segments = RADIAL_SEGMENTS
	mesh.rings = SPHERE_RINGS
	node.position = position
	node.scale = scale_value
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	node.add_to_group("mecha_fps_occluder")
	root.add_child(node)
	return node


static func _cylinder(root: Node3D, radius: float, height: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	mesh.radial_segments = RADIAL_SEGMENTS
	node.rotation = rotation
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	node.add_to_group("mecha_fps_occluder")
	root.add_child(node)
	return node


static func _limb(root: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material, phase: float) -> void:
	var direction := finish - start
	var node := _cylinder(root, radius, direction.length(), (start + finish) * 0.5, material)
	if direction.length_squared() > 0.0001:
		node.quaternion = Quaternion(Vector3.UP, direction.normalized())
	node.add_to_group("mecha_limb")
	node.set_meta("phase", phase)


static func _count_mesh_instances(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_mesh_instances(child)
	return count

static func _count_mesh_triangles(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			count += mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		count += _count_mesh_triangles(child)
	return count



static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.65, 0.22)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
