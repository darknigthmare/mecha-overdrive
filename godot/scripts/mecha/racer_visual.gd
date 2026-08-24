class_name RacerVisual
extends Node3D

## Lightweight procedural animation for every mech architecture. The race
## controller only supplies motion state; this node owns all visual response.

var speed_ratio := 0.0
var steering := 0.0
var boosting := false
var damage_ratio := 0.0
var reduced_motion := false
var first_person := false
var _time := 0.0


func set_motion(next_speed_ratio: float, next_steering: float, is_boosting: bool, next_damage_ratio: float) -> void:
	speed_ratio = clampf(next_speed_ratio, 0.0, 1.6)
	steering = clampf(next_steering, -1.0, 1.0)
	boosting = is_boosting
	damage_ratio = clampf(next_damage_ratio, 0.0, 1.0)
	_enforce_native_locomotion_hidden()


func set_accessibility(use_reduced_motion: bool) -> void:
	reduced_motion = use_reduced_motion


func camera_anchor(mode: String = "tps") -> Marker3D:
	var anchor_name := "CameraFPS" if mode.to_lower() == "fps" else "CameraTPS"
	return get_node_or_null(anchor_name) as Marker3D


func set_camera_mode(mode: String) -> void:
	first_person = mode.to_lower() == "fps"
	for candidate in get_tree().get_nodes_in_group("mecha_fps_occluder"):
		var occluder := candidate as Node3D
		if occluder != null and is_ancestor_of(occluder):
			if _is_native_locomotion_node(occluder):
				occluder.visible = false
				continue
			occluder.visible = not first_person
	for candidate in get_tree().get_nodes_in_group("mecha_cockpit_interior"):
		var interior := candidate as Node3D
		if interior != null and is_ancestor_of(interior):
			interior.visible = first_person
	_enforce_native_locomotion_hidden()


func _process(delta: float) -> void:
	_enforce_native_locomotion_hidden()
	_time += delta * lerpf(1.2, 9.0, clampf(speed_ratio, 0.0, 1.0))
	var lean_target := 0.0 if reduced_motion else -steering * 0.14
	rotation.z = lerp_angle(rotation.z, lean_target, 1.0 - exp(-delta * 7.0))
	var bounce := 0.0 if reduced_motion else sin(_time * 2.0) * 0.045 * speed_ratio
	position.y = bounce

	for child_node in get_tree().get_nodes_in_group("mecha_limb"):
		var child := child_node as Node3D
		if child == null or not is_ancestor_of(child):
			continue
		var phase := float(child.get_meta("phase", 0.0))
		var stride := sin(_time + phase) * 0.2 * clampf(speed_ratio, 0.0, 1.0)
		child.rotation.x = stride

	for rotor_node in get_tree().get_nodes_in_group("mecha_locomotion_rotor"):
		var rotor := rotor_node as Node3D
		if rotor == null or not is_ancestor_of(rotor):
			continue
		var axis_value: Variant = rotor.get_meta("rotation_axis", Vector3.RIGHT)
		var axis: Vector3 = axis_value if axis_value is Vector3 else Vector3.RIGHT
		var rate := float(rotor.get_meta("rotation_rate", 6.0))
		var accessibility_scale := 0.35 if reduced_motion else 1.0
		rotor.rotate_object_local(axis.normalized(), delta * rate * speed_ratio * accessibility_scale)

	for glow_node in get_tree().get_nodes_in_group("mecha_glow"):
		var glow := glow_node as Node3D
		if glow == null or not is_ancestor_of(glow):
			continue
		var pulse := 1.0 + sin(_time * 1.7) * 0.05
		if boosting:
			pulse += 0.34
		glow.scale = Vector3.ONE * pulse

	for damaged_node in get_tree().get_nodes_in_group("mecha_damage_part"):
		var damaged := damaged_node as Node3D
		if damaged == null or not is_ancestor_of(damaged):
			continue
		if _is_native_locomotion_node(damaged):
			damaged.visible = false
			continue
		if damaged.is_in_group("mecha_cockpit_interior"):
			damaged.visible = first_person
		elif first_person and damaged.is_in_group("mecha_fps_occluder"):
			damaged.visible = false
		else:
			damaged.visible = damage_ratio < 0.88 or int(_time * 8.0 + damaged.get_instance_id()) % 3 != 0
	_enforce_native_locomotion_hidden()


func _is_native_locomotion_node(node: Node) -> bool:
	var cursor: Node = node
	while cursor != null and cursor != self:
		if cursor.is_in_group("mecha_native_locomotion"):
			return true
		cursor = cursor.get_parent()
	return false


func _enforce_native_locomotion_hidden() -> void:
	if not is_inside_tree():
		return
	for candidate: Node in get_tree().get_nodes_in_group("mecha_native_locomotion"):
		if candidate is Node3D and is_ancestor_of(candidate):
			_hide_native_branch(candidate)


func _hide_native_branch(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	for child: Node in node.get_children():
		_hide_native_branch(child)
