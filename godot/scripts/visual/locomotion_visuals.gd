class_name LocomotionVisuals
extends RefCounted

## Procedural visual layer for LocomotionCatalog configurations.  The stock
## chassis remains recognisable while each propulsion and mounting choice adds
## a concrete silhouette, animated contacts and manufacturer-readable details.


const SUPPORT_COUNT_BY_FAMILY := {
	"biped": 2, "tripod": 3, "quadruped": 4, "hexapod": 6, "octopod": 8,
	"hover": 4, "tracked": 4, "monowheel": 2, "orb": 4, "centurion": 12,
}

const CURVED_RADIAL_SEGMENTS := 12
const CURVED_RINGS := 8
const TORUS_RINGS := 12
const TORUS_RING_SEGMENTS := 8
const RACE_TRIANGLE_BUDGET := 50000
const HERO_TRIANGLE_BUDGET := 70000
const RACE_MESH_BUDGET := 140
const HERO_MESH_BUDGET := 200


static func install(
	root: RacerVisual,
	chassis: Dictionary,
	customization: Dictionary,
	primary: Material,
	dark: Material,
	joint: Material,
	glow: Material
) -> Dictionary:
	var configuration := LocomotionCatalog.resolve_configuration(chassis, customization)
	var suppressed_native_count := _suppress_native_locomotion(root)
	var visual: Dictionary = configuration.get("visual", {}) if configuration.get("visual", {}) is Dictionary else {}
	var drive_id := String(visual.get("drive_id", "mecha_legs"))
	var family_id := String(chassis.get("id", "biped"))
	var textured_surface := MaterialLibrary.locomotion_for(
		drive_id,
		Color(String(chassis.get("accent", "#D9FBFF")))
	)
	var support_count := int(SUPPORT_COUNT_BY_FAMILY.get(family_id, 4))
	var holder := Node3D.new()
	holder.name = "Locomotion_%s" % String(configuration.get("id", "stock"))
	holder.add_to_group("mecha_locomotion_module")
	holder.set_meta("configuration_id", configuration.get("id", ""))
	holder.set_meta("drive_id", drive_id)
	holder.set_meta("mount_id", visual.get("mount_id", "balanced"))
	holder.set_meta("family_id", family_id)
	holder.set_meta("support_count", support_count)
	holder.set_meta("surface_texture_path", textured_surface.get_meta("texture_path", ""))
	holder.set_meta("uses_antigrav_texture", bool(textured_surface.get_meta("uses_antigrav_texture", false)))
	holder.set_meta("suppressed_native_count", suppressed_native_count)
	root.add_child(holder)
	root.add_to_group("mecha_animated_racer")
	root.set_meta("animation_detail_tier", "race_midpoly_cached")
	root.set_meta("animation_reduced_motion", root.reduced_motion)
	holder.set_meta("animation_schema", 2)
	holder.set_meta("animation_budget", "web_cached_50k_140_meshes")

	var dimensions := Vector3(
		float(visual.get("width", 1.0)),
		float(visual.get("height", 1.0)),
		float(visual.get("length", 1.0))
	)
	var anchors := _anchors_for(family_id, dimensions)
	match drive_id:
		"wheels": _wheels(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		"treads": _treads(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		"multi_support": _multi_support(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		"sphere_drive": _sphere_drive(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		"mono_gyro": _mono_gyro(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		"hover_skids": _hover_skids(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		"twin_antigrav": _twin_antigrav(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		"articulated_rail": _articulated_rail(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		"ducted_fans": _ducted_fans(holder, anchors, dimensions, textured_surface, dark, joint, glow)
		_: _mecha_legs(holder, anchors, dimensions, textured_surface, dark, joint, glow)
	_mount_signature(holder, String(visual.get("mount_id", "balanced")), anchors, dimensions, textured_surface, dark, glow)
	var locomotion_triangles := _visible_triangle_count(holder)
	var render_triangles := _visible_triangle_count(root)
	var budget_status := "race" if render_triangles <= RACE_TRIANGLE_BUDGET else ("hero" if render_triangles <= HERO_TRIANGLE_BUDGET else "over_budget")
	holder.set_meta("triangle_count", locomotion_triangles)
	holder.set_meta("triangle_budget", RACE_TRIANGLE_BUDGET)
	root.set_meta("locomotion_triangle_count", locomotion_triangles)
	root.set_meta("render_triangle_count", render_triangles)
	root.set_meta("triangle_budget_race", RACE_TRIANGLE_BUDGET)
	root.set_meta("triangle_budget_hero", HERO_TRIANGLE_BUDGET)
	root.set_meta("triangle_budget_status", budget_status)
	var locomotion_meshes := _visible_mesh_count(holder)
	var render_meshes := _visible_mesh_count(root)
	var mesh_budget_status := "race" if render_meshes <= RACE_MESH_BUDGET else ("hero" if render_meshes <= HERO_MESH_BUDGET else "over_budget")
	holder.set_meta("mesh_count", locomotion_meshes)
	holder.set_meta("mesh_budget", RACE_MESH_BUDGET)
	root.set_meta("locomotion_mesh_count", locomotion_meshes)
	root.set_meta("render_mesh_count", render_meshes)
	root.set_meta("mesh_budget_race", RACE_MESH_BUDGET)
	root.set_meta("mesh_budget_hero", HERO_MESH_BUDGET)
	root.set_meta("mesh_budget_status", mesh_budget_status)
	root.set_meta("locomotion_id", configuration.get("id", ""))
	root.set_meta("locomotion_configuration", configuration.duplicate(true))
	return configuration


static func _anchors_for(family_id: String, dimensions: Vector3) -> Dictionary:
	var half_width := 1.45
	var half_length := 1.35
	var ground_y := 0.35
	match family_id:
		"tripod":
			half_width = 1.7
			half_length = 1.55
		"quadruped":
			half_width = 1.75
			half_length = 1.75
		"hexapod":
			half_width = 2.15
			half_length = 1.75
		"octopod":
			half_width = 2.45
			half_length = 2.0
		"hover":
			half_width = 2.0
			half_length = 2.15
			ground_y = 0.55
		"tracked":
			half_width = 1.95
			half_length = 2.15
		"monowheel":
			half_width = 1.35
			half_length = 1.45
		"orb":
			half_width = 1.8
			half_length = 1.6
		"centurion":
			half_width = 1.75
			half_length = 2.8
	return {
		"x": half_width * dimensions.x,
		"z": half_length * dimensions.z,
		"y": ground_y * dimensions.y,
		"family_id": family_id,
		"support_count": int(SUPPORT_COUNT_BY_FAMILY.get(family_id, 4)),
	}


static func _mecha_legs(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var ground := float(anchors.y)
	var family_id := String(anchors.get("family_id", "biped"))
	var support_count := int(anchors.get("support_count", 4))
	var compact_race_lod := support_count >= 6
	holder.set_meta("support_animation_lod", "race_2_segment_contact_joint" if compact_race_lod else "hero_3_segment")
	var positions := _support_positions(support_count, float(anchors.x), float(anchors.z) * 0.78)
	for index in range(positions.size()):
		var planar: Vector3 = positions[index]
		var hip := planar * 0.5 + Vector3.UP * (ground + 1.15 * dimensions.y)
		var knee := planar * 0.82 + Vector3.UP * (ground + 0.58 * dimensions.y)
		var foot := planar + Vector3.UP * ground
		var phase := TAU * float(index) / float(maxi(1, support_count))
		_limb(holder, hip, knee, 0.11 * dimensions.y, dark, phase, index, "upper", "hip", "knee")
		if compact_race_lod:
			_limb(holder, knee, foot, 0.14 * dimensions.y, joint, phase, index, "lower", "knee", "foot")
			var contact := _box(holder, Vector3(0.55, 0.16, 0.92) * dimensions, foot + Vector3(0, -0.02, -0.22), primary)
			_mark_ground_contact(contact, index, family_id, phase)
			_mark_joint(contact, index, "foot", phase)
		else:
			var ankle := planar * 0.96 + Vector3.UP * (ground + 0.18 * dimensions.y)
			_limb(holder, knee, ankle, 0.14 * dimensions.y, joint, phase, index, "lower", "knee", "ankle")
			_limb(holder, ankle, foot, 0.10 * dimensions.y, dark, phase, index, "ankle", "ankle", "foot")
			var contact := _box(holder, Vector3(0.55, 0.16, 0.92) * dimensions, foot + Vector3(0, -0.02, -0.22), primary)
			_mark_ground_contact(contact, index, family_id, phase)
			_mark_joint(_sphere(holder, 0.11, hip, glow), index, "hip", phase)
			_mark_joint(_sphere(holder, 0.1, knee, glow), index, "knee", phase)
			_mark_joint(_sphere(holder, 0.085, ankle, glow), index, "ankle", phase)


static func _wheels(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var x := float(anchors.x)
	var z := float(anchors.z) * 0.72
	var y := float(anchors.y) + 0.18
	for side: float in [-1.0, 1.0]:
		for longitudinal: float in [-1.0, 1.0]:
			var position := Vector3(side * x, y, longitudinal * z)
			var suspension := _motion_holder(holder, "WheelSuspension_%s_%s" % [int(side), int(longitudinal)], position, "mecha_suspension")
			suspension.set_meta("side", side)
			suspension.set_meta("longitudinal", longitudinal)
			suspension.set_meta("suspension_phase", longitudinal * 0.8 + side)
			suspension.set_meta("steering_factor", 1.0 if longitudinal < 0.0 else 0.16)
			var wheel := _torus(suspension, 0.48 * dimensions.y, 0.72 * dimensions.y, Vector3.ZERO, dark, Vector3(0, 0, PI / 2.0))
			_rotor(wheel, Vector3.RIGHT, 7.5, longitudinal * 0.8 + side, "wheel")
			_cylinder(suspension, 0.2, 0.56 * dimensions.x, Vector3.ZERO, joint, Vector3(0, 0, PI / 2.0))
			_sphere(suspension, 0.15, Vector3(side * 0.12, 0, 0), glow)
			_box(suspension, Vector3(0.18, 0.16, 0.75) * dimensions, Vector3(-side * 0.3, 0.45, 0), primary)


static func _treads(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var x := float(anchors.x)
	var z := float(anchors.z)
	var y := float(anchors.y) + 0.14
	for side: float in [-1.0, 1.0]:
		var tread := _motion_holder(holder, "TreadSuspension_%s" % int(side), Vector3(side * x, y, 0), "mecha_suspension")
		tread.set_meta("side", side)
		tread.set_meta("longitudinal", 0.0)
		tread.set_meta("suspension_phase", side * 0.7)
		tread.set_meta("steering_factor", 0.0)
		_box(tread, Vector3(0.72, 0.68, z * 2.15), Vector3.ZERO, dark)
		_box(tread, Vector3(0.82, 0.13, z * 2.0), Vector3(0, 0.4, 0), primary)
		for longitudinal: float in [-0.72, 0.0, 0.72]:
			var wheel_position := Vector3(side * 0.02, 0, longitudinal * z)
			var wheel := _torus(tread, 0.25, 0.38, wheel_position, joint, Vector3(0, 0, PI / 2.0))
			_rotor(wheel, Vector3.RIGHT, 5.2, longitudinal + side, "track_roller")
		for link_index in range(10):
			var track_phase := float(link_index) / 10.0
			var link := _box(tread, Vector3(0.84, 0.11, maxf(0.32, z * 0.34)), Vector3(0, 0.46, lerpf(-z * 0.92, z * 0.92, track_phase)), primary)
			link.add_to_group("mecha_track_link")
			link.set_meta("track_phase", track_phase)
			link.set_meta("track_x", 0.0)
			link.set_meta("track_center_y", 0.0)
			link.set_meta("track_z_extent", z * 0.92)
		_sphere(tread, 0.14, Vector3(0, 0.35, z * 0.82), glow)


static func _multi_support(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var ground := float(anchors.y)
	var family_id := String(anchors.get("family_id", "biped"))
	var support_count := int(anchors.get("support_count", 4))
	var compact_race_lod := support_count >= 6
	holder.set_meta("support_animation_lod", "race_2_segment_contact_joint" if compact_race_lod else "hero_3_segment")
	var positions := _support_positions(support_count, float(anchors.x), float(anchors.z))
	for index in range(positions.size()):
		var planar: Vector3 = positions[index]
		var hip := planar * 0.48 + Vector3.UP * (ground + 1.0 * dimensions.y)
		var knee := planar * 0.82 + Vector3.UP * (ground + 0.48 * dimensions.y)
		var foot := planar + Vector3.UP * ground
		var phase := TAU * float(index) / float(maxi(1, support_count))
		_limb(holder, hip, knee, 0.1 * dimensions.y, dark, phase, index, "upper", "hip", "knee")
		if compact_race_lod:
			_limb(holder, knee, foot, 0.12 * dimensions.y, joint, phase, index, "lower", "knee", "foot")
			var contact := _sphere(holder, 0.2 * dimensions.y, foot, primary, Vector3(1.35, 0.5, 1.0))
			_mark_ground_contact(contact, index, family_id, phase)
			_mark_joint(contact, index, "foot", phase)
		else:
			var ankle := planar * 0.95 + Vector3.UP * (ground + 0.16 * dimensions.y)
			_limb(holder, knee, ankle, 0.12 * dimensions.y, joint, phase, index, "lower", "knee", "ankle")
			_limb(holder, ankle, foot, 0.085 * dimensions.y, dark, phase, index, "ankle", "ankle", "foot")
			var contact := _sphere(holder, 0.2 * dimensions.y, foot, primary, Vector3(1.35, 0.5, 1.0))
			_mark_ground_contact(contact, index, family_id, phase)
			_mark_joint(_sphere(holder, 0.09, hip, glow), index, "hip", phase)
			_mark_joint(_sphere(holder, 0.08, knee, glow), index, "knee", phase)
			_mark_joint(_sphere(holder, 0.07, ankle, glow), index, "ankle", phase)


static func _sphere_drive(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var x := float(anchors.x) * 0.9
	var z := float(anchors.z) * 0.68
	var y := float(anchors.y) + 0.16
	for side: float in [-1.0, 1.0]:
		for longitudinal: float in [-1.0, 1.0]:
			var position := Vector3(side * x, y, longitudinal * z)
			var suspension := _motion_holder(holder, "SphereSuspension_%s_%s" % [int(side), int(longitudinal)], position, "mecha_suspension")
			suspension.set_meta("side", side)
			suspension.set_meta("longitudinal", longitudinal)
			suspension.set_meta("suspension_phase", side + longitudinal)
			suspension.set_meta("steering_factor", 0.72 if longitudinal < 0.0 else 0.18)
			var contact := _sphere(suspension, 0.43 * dimensions.y, Vector3.ZERO, primary)
			_rotor(contact, Vector3.RIGHT, 5.8, side + longitudinal, "sphere")
			_torus(suspension, 0.48 * dimensions.y, 0.57 * dimensions.y, Vector3.ZERO, dark, Vector3(PI / 2.0, 0, 0))
			_sphere(suspension, 0.1, Vector3(0, 0.5, 0), glow)


static func _mono_gyro(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var y := float(anchors.y) + 0.72 * dimensions.y
	var radius := minf(float(anchors.x) * 0.72, 1.35 * dimensions.y)
	for longitudinal: float in [-1.0, 1.0]:
		var position := Vector3(0, y, longitudinal * float(anchors.z) * 0.56)
		var ring := _torus(holder, radius * 0.72, radius, position, dark, Vector3(PI / 2.0, 0, 0))
		_rotor(ring, Vector3.RIGHT, 6.8, longitudinal * PI, "gyro")
		_cylinder(holder, 0.2, radius * 1.5, position, joint, Vector3(0, 0, PI / 2.0))
		_sphere(holder, 0.17, position + Vector3(0, 0, longitudinal * 0.12), glow)
	_box(holder, Vector3(0.45, 0.35, float(anchors.z) * 1.2), Vector3(0, y, 0), primary)


static func _hover_skids(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var x := float(anchors.x) * 0.82
	var z := float(anchors.z)
	var y := float(anchors.y)
	for side: float in [-1.0, 1.0]:
		var skid := _motion_holder(holder, "HoverSkid_%s" % int(side), Vector3(side * x, y, 0), "mecha_propulsion_pod")
		skid.set_meta("side", side)
		skid.set_meta("pod_phase", side * PI * 0.5)
		_box(skid, Vector3(0.38, 0.18, z * 2.0), Vector3.ZERO, dark)
		_box(skid, Vector3(0.24, 0.08, z * 1.86), Vector3(0, -0.14, 0), glow)
		for longitudinal: float in [-0.68, 0.68]:
			_cylinder(skid, 0.22, 0.32, Vector3(0, 0.18, longitudinal * z), primary)
			_sphere(skid, 0.12, Vector3(0, -0.2, longitudinal * z), glow)


static func _twin_antigrav(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var x := float(anchors.x) * 1.22
	var z := float(anchors.z)
	var y := float(anchors.y) + 0.72 * dimensions.y
	for side: float in [-1.0, 1.0]:
		var pod := Vector3(side * x, y, 0)
		var pod_holder := _motion_holder(holder, "AntigravPod_%s" % int(side), pod, "mecha_propulsion_pod")
		pod_holder.set_meta("side", side)
		pod_holder.set_meta("pod_phase", side * 0.7)
		_box(pod_holder, Vector3(0.88, 0.66, z * 1.9), Vector3.ZERO, primary)
		_box(pod_holder, Vector3(0.68, 0.4, z * 1.98), Vector3(0, -0.06, 0.08), dark)
		var intake := _torus(pod_holder, 0.3, 0.45, Vector3(0, 0, -z), joint, Vector3(PI / 2.0, 0, 0))
		_rotor(intake, Vector3.FORWARD, 2.4, side, "gyro")
		var exhaust := _sphere(pod_holder, 0.3, Vector3(0, 0, z), glow, Vector3(1.0, 0.72, 1.5))
		exhaust.add_to_group("mecha_glow")
		_box(holder, Vector3(x * 0.78, 0.12, 0.2), Vector3(side * x * 0.5, y + 0.1, 0), joint)
		_cylinder(pod_holder, 0.11, 0.72, Vector3(0, 0.5, -z * 0.3), dark, Vector3(0, 0, side * PI / 5.0))
	_box(holder, Vector3(0.32, 0.16, z * 0.92), Vector3(0, y + 0.1, 0), dark)


static func _articulated_rail(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var x := float(anchors.x) * 0.82
	var z := float(anchors.z)
	var y := float(anchors.y)
	for side: float in [-1.0, 1.0]:
		for segment in range(5):
			var segment_z := lerpf(-z, z, float(segment) / 4.0)
			var rail := _box(holder, Vector3(0.5, 0.18, z * 0.36), Vector3(side * x, y, segment_z), primary if segment % 2 == 0 else dark)
			rail.add_to_group("mecha_rail_segment")
			rail.set_meta("rail_index", segment)
			rail.set_meta("side", side)
			var roller := _cylinder(holder, 0.16, 0.52, Vector3(side * x, y - 0.12, segment_z), joint, Vector3(0, 0, PI / 2.0))
			_rotor(roller, Vector3.RIGHT, 8.0, float(segment), "track_roller")
		_box(holder, Vector3(0.16, 0.1, z * 1.9), Vector3(side * x, y - 0.18, 0), glow)


static func _ducted_fans(holder: Node3D, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var x := float(anchors.x)
	var z := float(anchors.z) * 0.68
	var y := float(anchors.y) + 0.42
	for side: float in [-1.0, 1.0]:
		for longitudinal: float in [-1.0, 1.0]:
			var position := Vector3(side * x, y, longitudinal * z)
			var pod := _motion_holder(holder, "DuctedPod_%s_%s" % [int(side), int(longitudinal)], position, "mecha_propulsion_pod")
			pod.set_meta("side", side)
			pod.set_meta("pod_phase", side + longitudinal * 0.6)
			_torus(pod, 0.38, 0.58, Vector3.ZERO, primary, Vector3(PI / 2.0, 0, 0))
			var rotor := _motion_holder(pod, "FanRotor", Vector3.ZERO, "mecha_locomotion_rotor")
			rotor.set_meta("rotation_axis", Vector3.UP)
			rotor.set_meta("rotation_rate", 12.0)
			rotor.set_meta("phase", side + longitudinal)
			rotor.set_meta("rotor_role", "fan")
			_cylinder(rotor, 0.32, 0.08, Vector3.ZERO, dark)
			for blade in range(3):
				var angle := TAU * float(blade) / 3.0
				_box(rotor, Vector3(0.08, 0.05, 0.5), Vector3(sin(angle) * 0.15, 0, cos(angle) * 0.15), joint, Vector3(0, angle, 0))
			_sphere(pod, 0.1, Vector3(0, -0.16, 0), glow)


static func _support_positions(count: int, half_width: float, half_length: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	match count:
		2:
			positions.append(Vector3(-half_width, 0, 0))
			positions.append(Vector3(half_width, 0, 0))
		3:
			for index in range(3):
				var angle := TAU * float(index) / 3.0 - PI / 2.0
				positions.append(Vector3(cos(angle) * half_width, 0, sin(angle) * half_length))
		4:
			for side: float in [-1.0, 1.0]:
				for longitudinal: float in [-1.0, 1.0]:
					positions.append(Vector3(side * half_width, 0, longitudinal * half_length))
		12:
			for row in range(6):
				var longitudinal := lerpf(-half_length, half_length, float(row) / 5.0)
				positions.append(Vector3(-half_width, 0, longitudinal))
				positions.append(Vector3(half_width, 0, longitudinal))
		_:
			for index in range(count):
				var angle := TAU * float(index) / float(maxi(1, count))
				positions.append(Vector3(cos(angle) * half_width, 0, sin(angle) * half_length))
	return positions


static func _mark_ground_contact(node: Node3D, support_index: int, family_id: String, phase: float) -> void:
	node.add_to_group("mecha_locomotion_contact")
	node.set_meta("support_index", support_index)
	node.set_meta("family_id", family_id)
	node.set_meta("contact_role", "ground")
	node.set_meta("gait_phase", phase)


static func _mark_joint(node: Node3D, support_index: int, role: String, phase: float) -> void:
	node.add_to_group("mecha_locomotion_joint")
	node.set_meta("support_index", support_index)
	node.set_meta("joint_role", role)
	node.set_meta("gait_phase", phase)


static func _suppress_native_locomotion(root: RacerVisual) -> int:
	var suppressed := 0
	for child: Node in root.get_children():
		if child.is_in_group("mecha_native_locomotion"):
			_hide_native_tree(child)
			suppressed += 1
	root.set_meta("native_locomotion_suppressed", suppressed > 0)
	root.set_meta("native_locomotion_suppressed_count", suppressed)
	return suppressed


static func _hide_native_tree(node: Node) -> void:
	node.set_meta("native_locomotion_suppressed", true)
	if node is Node3D:
		(node as Node3D).visible = false
	for child: Node in node.get_children():
		_hide_native_tree(child)


static func _visible_triangle_count(node: Node, ancestors_visible: bool = true) -> int:
	var branch_visible := ancestors_visible
	if node is Node3D:
		branch_visible = ancestors_visible and (node as Node3D).visible
	if not branch_visible:
		return 0
	var total := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			total += mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		total += _visible_triangle_count(child, branch_visible)
	return total


static func _visible_mesh_count(node: Node, ancestors_visible: bool = true) -> int:
	var branch_visible := ancestors_visible
	if node is Node3D:
		branch_visible = ancestors_visible and (node as Node3D).visible
	if not branch_visible:
		return 0
	var total := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		total += _visible_mesh_count(child, branch_visible)
	return total


static func _mount_signature(holder: Node3D, mount_id: String, anchors: Dictionary, dimensions: Vector3, primary: Material, dark: Material, glow: Material) -> void:
	var y := float(anchors.y) + 1.0 * dimensions.y
	var z := float(anchors.z)
	match mount_id:
		"compact":
			_box(holder, Vector3(1.0, 0.2, 0.72), Vector3(0, y, z * 0.45), primary)
		"wide":
			_box(holder, Vector3(float(anchors.x) * 1.85, 0.16, 0.34), Vector3(0, y, 0), dark)
			for side: float in [-1.0, 1.0]:
				_sphere(holder, 0.12, Vector3(side * float(anchors.x), y, 0), glow)
		"endurance":
			for side: float in [-1.0, 1.0]:
				_box(holder, Vector3(0.42, 0.62, z * 0.88), Vector3(side * float(anchors.x) * 0.66, y, 0), primary)
				_box(holder, Vector3(0.18, 0.12, z * 0.72), Vector3(side * float(anchors.x) * 0.66, y + 0.38, 0), glow)
		"racing":
			_box(holder, Vector3(0.18, 0.44, z * 1.15), Vector3(0, y + 0.16, -z * 0.05), dark, Vector3(-0.05, 0, 0))
			for side: float in [-1.0, 1.0]:
				_box(holder, Vector3(0.12, 0.5, z * 0.55), Vector3(side * float(anchors.x) * 0.56, y, z * 0.28), primary, Vector3(0, 0, side * 0.14))
		_:
			_box(holder, Vector3(0.72, 0.16, 0.52), Vector3(0, y, z * 0.34), dark)


static func _rotor(node: Node3D, axis: Vector3, rate: float, phase: float, role: String = "contact") -> void:
	node.add_to_group("mecha_locomotion_rotor")
	node.set_meta("rotation_axis", axis)
	node.set_meta("rotation_rate", rate)
	node.set_meta("phase", phase)
	node.set_meta("rotor_role", role)


static func _motion_holder(parent: Node3D, node_name: String, position: Vector3, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = position
	node.add_to_group(group_name)
	parent.add_child(node)
	return node


static func _mesh_node(holder: Node3D, mesh: Mesh, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.rotation = rotation
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	node.add_to_group("mecha_fps_occluder")
	node.add_to_group("mecha_locomotion_part")
	holder.add_child(node)
	return node


static func _box(holder: Node3D, size: Vector3, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_node(holder, mesh, position, material, rotation)


static func _sphere(holder: Node3D, radius: float, position: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = CURVED_RADIAL_SEGMENTS
	mesh.rings = CURVED_RINGS
	var node := _mesh_node(holder, mesh, position, material)
	node.scale = scale_value
	return node


static func _cylinder(holder: Node3D, radius: float, height: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = CURVED_RADIAL_SEGMENTS
	mesh.rings = 1
	return _mesh_node(holder, mesh, position, material, rotation)


static func _torus(holder: Node3D, inner_radius: float, outer_radius: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = TORUS_RINGS
	mesh.ring_segments = TORUS_RING_SEGMENTS
	return _mesh_node(holder, mesh, position, material, rotation)


static func _limb(holder: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material, phase: float, support_index: int, segment_role: String, start_role: String, end_role: String) -> MeshInstance3D:
	var direction := finish - start
	var node := _cylinder(holder, radius, direction.length(), (start + finish) * 0.5, material)
	if direction.length_squared() > 0.0001:
		node.quaternion = Quaternion(Vector3.UP, direction.normalized())
	node.add_to_group("mecha_limb")
	node.add_to_group("mecha_articulated_segment")
	node.set_meta("phase", phase)
	node.set_meta("gait_phase", phase)
	node.set_meta("support_index", support_index)
	node.set_meta("segment_role", segment_role)
	node.set_meta("start_role", start_role)
	node.set_meta("end_role", end_role)
	node.set_meta("base_start", start)
	node.set_meta("base_end", finish)
	node.set_meta("segment_length", direction.length())
	return node
