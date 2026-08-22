class_name RacerVisual
extends Node3D

## Lightweight procedural animation for every mech architecture. The race
## controller only supplies motion state; this node owns all visual response.

var speed_ratio := 0.0
var steering := 0.0
var boosting := false
var damage_ratio := 0.0
var reduced_motion := false
var _time := 0.0


func set_motion(next_speed_ratio: float, next_steering: float, is_boosting: bool, next_damage_ratio: float) -> void:
	speed_ratio = clampf(next_speed_ratio, 0.0, 1.6)
	steering = clampf(next_steering, -1.0, 1.0)
	boosting = is_boosting
	damage_ratio = clampf(next_damage_ratio, 0.0, 1.0)


func set_accessibility(use_reduced_motion: bool) -> void:
	reduced_motion = use_reduced_motion


func _process(delta: float) -> void:
	_time += delta * lerpf(1.2, 9.0, clampf(speed_ratio, 0.0, 1.0))
	var lean_target := 0.0 if reduced_motion else -steering * 0.14
	rotation.z = lerp_angle(rotation.z, lean_target, 1.0 - exp(-delta * 7.0))
	var bounce := 0.0 if reduced_motion else sin(_time * 2.0) * 0.045 * speed_ratio
	position.y = bounce

	for child in get_tree().get_nodes_in_group("mecha_limb"):
		if not is_ancestor_of(child):
			continue
		var phase := float(child.get_meta("phase", 0.0))
		var stride := sin(_time + phase) * 0.2 * clampf(speed_ratio, 0.0, 1.0)
		child.rotation.x = stride

	for glow in get_tree().get_nodes_in_group("mecha_glow"):
		if not is_ancestor_of(glow):
			continue
		var pulse := 1.0 + sin(_time * 1.7) * 0.05
		if boosting:
			pulse += 0.34
		glow.scale = Vector3.ONE * pulse

	for damaged in get_tree().get_nodes_in_group("mecha_damage_part"):
		if not is_ancestor_of(damaged):
			continue
		damaged.visible = damage_ratio < 0.88 or int(_time * 8.0 + damaged.get_instance_id()) % 3 != 0
