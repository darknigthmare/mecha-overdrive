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
			occluder.visible = not first_person
	for candidate in get_tree().get_nodes_in_group("mecha_cockpit_interior"):
		var interior := candidate as Node3D
		if interior != null and is_ancestor_of(interior):
			interior.visible = first_person


func _process(delta: float) -> void:
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
		if damaged.is_in_group("mecha_cockpit_interior"):
			damaged.visible = first_person
		elif first_person and damaged.is_in_group("mecha_fps_occluder"):
			damaged.visible = false
		else:
			damaged.visible = damage_ratio < 0.88 or int(_time * 8.0 + damaged.get_instance_id()) % 3 != 0
