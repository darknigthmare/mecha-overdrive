class_name RacerVisual
extends Node3D

## Cached procedural animation rig shared by every mech architecture. Race and
## garage code only feed normalized motion state; this node turns it into a
## technology-specific, articulated response without AnimationPlayer assets.

const IDLE_SPEED_THRESHOLD := 0.16
const MAX_FRAME_DELTA := 0.05
const IMPACT_SPRING := 34.0
const IMPACT_DAMPING := 8.5

var speed_ratio := 0.0
var steering := 0.0
var boosting := false
var damage_ratio := 0.0
var reduced_motion := false
var first_person := false

var _time := 0.0
var _gait_time := 0.0
var _smoothed_speed := 0.0
var _smoothed_steering := 0.0
var _steering_velocity := 0.0
var _longitudinal_load := 0.0
var _pending_speed_delta := 0.0
var _boost_blend := 0.0
var _impact_offset := 0.0
var _impact_velocity := 0.0
var _impact_roll := 0.0
var _last_received_speed := 0.0
var _last_received_steering := 0.0
var _last_damage_ratio := 0.0
var _motion_received := false
var _cache_ready := false
var _drive_id := "mecha_legs"

var _body_nodes: Array[Node3D] = []
var _segments: Array[Node3D] = []
var _contacts: Array[Node3D] = []
var _joints: Array[Node3D] = []
var _rotors: Array[Node3D] = []
var _suspension_nodes: Array[Node3D] = []
var _track_links: Array[Node3D] = []
var _rail_segments: Array[Node3D] = []
var _propulsion_pods: Array[Node3D] = []
var _glow_nodes: Array[Node3D] = []
var _damage_nodes: Array[Node3D] = []


func set_motion(next_speed_ratio: float, next_steering: float, is_boosting: bool, next_damage_ratio: float) -> void:
	var clamped_speed := clampf(next_speed_ratio, 0.0, 1.6)
	var clamped_steering := clampf(next_steering, -1.0, 1.0)
	var clamped_damage := clampf(next_damage_ratio, 0.0, 1.0)
	if _motion_received:
		var speed_step := clamped_speed - _last_received_speed
		var damage_step := clamped_damage - _last_damage_ratio
		_pending_speed_delta = clampf(speed_step, -0.5, 0.5)
		if speed_step < -0.16:
			notify_impact(clampf(-speed_step * 1.65, 0.12, 0.8), signf(clamped_steering))
		if damage_step > 0.025:
			notify_impact(clampf(0.18 + damage_step * 2.4, 0.18, 1.0), _impact_side())
		if is_boosting and not boosting:
			_pending_speed_delta = minf(0.5, _pending_speed_delta + 0.14)
	_last_received_speed = clamped_speed
	_last_received_steering = clamped_steering
	_last_damage_ratio = clamped_damage
	_motion_received = true
	speed_ratio = clamped_speed
	steering = clamped_steering
	boosting = is_boosting
	damage_ratio = clamped_damage
	_enforce_native_locomotion_hidden()


func set_accessibility(use_reduced_motion: bool) -> void:
	reduced_motion = use_reduced_motion
	set_meta("animation_reduced_motion", reduced_motion)
	if reduced_motion:
		_impact_offset = 0.0
		_impact_velocity = 0.0
		_impact_roll = 0.0


func notify_impact(strength: float, side: float = 0.0) -> void:
	## Optional hook for future physical contacts. Current race code also derives
	## impulses from sharp deceleration and armor loss through set_motion().
	if reduced_motion:
		return
	var impulse := clampf(strength, 0.0, 1.0)
	_impact_velocity -= impulse * 2.1
	_impact_roll += clampf(side, -1.0, 1.0) * impulse * 0.055


func notify_landing(vertical_speed: float) -> void:
	notify_impact(clampf(absf(vertical_speed) / 12.0, 0.0, 1.0), 0.0)


func animation_snapshot() -> Dictionary:
	## Small deterministic surface used by headless QA and debug overlays.
	return {
		"drive_id": _drive_id,
		"speed": _smoothed_speed,
		"steering": _smoothed_steering,
		"longitudinal_load": _longitudinal_load,
		"impact_offset": _impact_offset,
		"boost_blend": _boost_blend,
		"reduced_motion": reduced_motion,
		"motion_scale": _motion_scale(),
		"cached_nodes": _cached_node_count(),
	}


func camera_anchor(mode: String = "tps") -> Marker3D:
	var anchor_name := "CameraFPS" if mode.to_lower() == "fps" else "CameraTPS"
	return get_node_or_null(anchor_name) as Marker3D


func set_camera_mode(mode: String) -> void:
	first_person = mode.to_lower() == "fps"
	_apply_camera_visibility(self)
	_enforce_native_locomotion_hidden()


func _process(delta: float) -> void:
	_enforce_native_locomotion_hidden()
	if not _cache_ready:
		_rebuild_animation_cache()
	if delta <= 0.0 or not visible:
		return
	var frame_delta := minf(delta, MAX_FRAME_DELTA)
	_time += frame_delta
	_update_motion_response(frame_delta)
	_animate_body_response()
	_animate_articulated_locomotion()
	_animate_suspension()
	_animate_track_links()
	_animate_rail_segments()
	_animate_propulsion_pods()
	_animate_rotors(frame_delta)
	_animate_glow()
	_update_damage_visibility()


func _update_motion_response(delta: float) -> void:
	var speed_response := 1.0 - exp(-delta * (7.5 if speed_ratio > _smoothed_speed else 10.0))
	_smoothed_speed = lerpf(_smoothed_speed, speed_ratio, speed_response)
	var previous_steering := _smoothed_steering
	_smoothed_steering = lerpf(_smoothed_steering, steering, 1.0 - exp(-delta * 9.0))
	var raw_steering_velocity := (_smoothed_steering - previous_steering) / maxf(delta, 0.001)
	_steering_velocity = lerpf(_steering_velocity, clampf(raw_steering_velocity, -5.0, 5.0), 1.0 - exp(-delta * 12.0))
	_boost_blend = lerpf(_boost_blend, 1.0 if boosting else 0.0, 1.0 - exp(-delta * (8.0 if boosting else 4.5)))
	var acceleration_target := clampf((_pending_speed_delta / maxf(delta, 0.001)) * 0.08, -1.0, 1.0)
	if boosting:
		acceleration_target = maxf(acceleration_target, 0.28)
	var load_response := 4.0 if acceleration_target > _longitudinal_load else 7.0
	_longitudinal_load = lerpf(_longitudinal_load, acceleration_target, 1.0 - exp(-delta * load_response))
	_pending_speed_delta = move_toward(_pending_speed_delta, 0.0, delta * 1.25)

	if not reduced_motion:
		_impact_velocity += (-_impact_offset * IMPACT_SPRING - _impact_velocity * IMPACT_DAMPING) * delta
		_impact_offset = clampf(_impact_offset + _impact_velocity * delta, -0.18, 0.08)
		_impact_roll = lerpf(_impact_roll, 0.0, 1.0 - exp(-delta * 7.0))
	else:
		_impact_offset = 0.0
		_impact_velocity = 0.0
		_impact_roll = 0.0

	var locomotion_speed := _locomotion_speed()
	_gait_time += delta * _gait_rate(locomotion_speed)


func _animate_body_response() -> void:
	var motion_scale := _motion_scale()
	var locomotion_speed := _locomotion_speed()
	var idle_servo := sin(_time * 1.45 + float(get_instance_id() % 13) * 0.17) * 0.012
	var technology_bob := _technology_bob(locomotion_speed)
	var anticipated_steering := clampf(_smoothed_steering + _steering_velocity * 0.055, -1.0, 1.0)
	var roll := (-anticipated_steering * _roll_response() + _impact_roll) * motion_scale
	var yaw := -anticipated_steering * 0.032 * motion_scale
	var pitch := (-_longitudinal_load * _pitch_response() - _boost_blend * 0.018) * motion_scale
	var vertical := (idle_servo + technology_bob + _impact_offset) * motion_scale
	var lateral := -anticipated_steering * locomotion_speed * 0.028 * motion_scale
	for node: Node3D in _body_nodes:
		if not is_instance_valid(node):
			continue
		var base: Transform3D = node.get_meta("animation_base_transform", node.transform)
		var cockpit_weight := 1.12 if String(node.name).to_lower().contains("cockpit") else 1.0
		var response_basis := Basis.IDENTITY
		response_basis = response_basis.rotated(Vector3.RIGHT, pitch * cockpit_weight)
		response_basis = response_basis.rotated(Vector3.UP, yaw * cockpit_weight)
		response_basis = response_basis.rotated(Vector3.BACK, roll * cockpit_weight)
		node.transform = Transform3D(response_basis, Vector3(lateral, vertical, 0.0)) * base


func _animate_articulated_locomotion() -> void:
	var motion_scale := _motion_scale()
	for segment: Node3D in _segments:
		if not is_instance_valid(segment):
			continue
		var phase := float(segment.get_meta("gait_phase", segment.get_meta("phase", 0.0)))
		var start_role := String(segment.get_meta("start_role", "hip"))
		var end_role := String(segment.get_meta("end_role", "foot"))
		var base_start: Vector3 = segment.get_meta("base_start", segment.position)
		var base_end: Vector3 = segment.get_meta("base_end", segment.position)
		var start := _articulated_point(base_start, start_role, phase, motion_scale)
		var finish := _articulated_point(base_end, end_role, phase, motion_scale)
		_pose_segment(segment, start, finish)

	for contact: Node3D in _contacts:
		if not is_instance_valid(contact):
			continue
		var base_position: Vector3 = contact.get_meta("animation_base_position", contact.position)
		var phase := float(contact.get_meta("gait_phase", 0.0))
		contact.position = _articulated_point(base_position, "foot", phase, motion_scale)
		var foot_pitch := -sin(_gait_time + phase) * 0.10 * _locomotion_speed() * motion_scale
		var base_rotation: Vector3 = contact.get_meta("animation_base_rotation", contact.rotation)
		contact.rotation = base_rotation + Vector3(foot_pitch, 0.0, 0.0)

	for joint_node: Node3D in _joints:
		if not is_instance_valid(joint_node):
			continue
		var base_position: Vector3 = joint_node.get_meta("animation_base_position", joint_node.position)
		var role := String(joint_node.get_meta("joint_role", "knee"))
		var phase := float(joint_node.get_meta("gait_phase", 0.0))
		joint_node.position = _articulated_point(base_position, role, phase, motion_scale)


func _articulated_point(base: Vector3, role: String, phase: float, motion_scale: float) -> Vector3:
	var locomotion_speed := _locomotion_speed()
	var cycle := _gait_time + phase
	var swing := sin(cycle)
	var lift_wave := maxf(0.0, cos(cycle))
	var stride := _stride_length() * locomotion_speed * motion_scale
	var lift := _step_height() * sqrt(locomotion_speed) * motion_scale
	if speed_ratio <= IDLE_SPEED_THRESHOLD:
		stride = 0.0
		lift = (0.012 + sin(_time * 1.7 + phase) * 0.006) * motion_scale
	var role_weight := 0.0
	var lift_weight := 0.0
	match role:
		"knee": role_weight = 0.34; lift_weight = 0.42
		"ankle": role_weight = 0.74; lift_weight = 0.82
		"foot": role_weight = 1.0; lift_weight = 1.0
		_: role_weight = 0.08; lift_weight = 0.12
	var steer_offset := _smoothed_steering * absf(base.x) * 0.035 * role_weight * locomotion_speed * motion_scale
	return base + Vector3(steer_offset, lift * lift_wave * lift_weight + _impact_offset * (1.0 - role_weight) * motion_scale, -swing * stride * role_weight)


func _pose_segment(node: Node3D, start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	var length := direction.length()
	if length <= 0.0001:
		return
	node.position = (start + finish) * 0.5
	node.quaternion = Quaternion(Vector3.UP, direction / length)
	var base_scale: Vector3 = node.get_meta("animation_base_scale", Vector3.ONE)
	var base_length := maxf(0.001, float(node.get_meta("segment_length", length)))
	node.scale = Vector3(base_scale.x, base_scale.y * length / base_length, base_scale.z)


func _animate_suspension() -> void:
	var motion_scale := _motion_scale()
	var locomotion_speed := _locomotion_speed()
	for suspension: Node3D in _suspension_nodes:
		if not is_instance_valid(suspension):
			continue
		var base: Transform3D = suspension.get_meta("animation_base_transform", suspension.transform)
		var phase := float(suspension.get_meta("suspension_phase", 0.0))
		var side := float(suspension.get_meta("side", 0.0))
		var longitudinal := float(suspension.get_meta("longitudinal", 0.0))
		var road_flutter := sin(_gait_time * 1.7 + phase) * 0.025 * locomotion_speed
		var load_travel := -_impact_offset * 0.72 - _longitudinal_load * longitudinal * 0.045
		load_travel += absf(_smoothed_steering) * side * 0.018
		var steering_factor := float(suspension.get_meta("steering_factor", 0.0))
		var yaw := _smoothed_steering * steering_factor * 0.32 * motion_scale
		var response_basis := base.basis.rotated(Vector3.UP, yaw)
		var response_origin := base.origin + Vector3(0.0, (road_flutter + load_travel) * motion_scale, 0.0)
		suspension.transform = Transform3D(response_basis, response_origin)


func _animate_track_links() -> void:
	var travel := _gait_time * 0.075 * _motion_scale()
	for link: Node3D in _track_links:
		if not is_instance_valid(link):
			continue
		var phase := float(link.get_meta("track_phase", 0.0))
		var loop_position := fposmod(phase + travel, 1.0)
		var x := float(link.get_meta("track_x", link.position.x))
		var center_y := float(link.get_meta("track_center_y", link.position.y))
		var z_extent := float(link.get_meta("track_z_extent", 1.0))
		var top_y := center_y + 0.46
		var bottom_y := center_y - 0.42
		var base_rotation: Vector3 = link.get_meta("animation_base_rotation", link.rotation)
		if loop_position < 0.4:
			var ratio := loop_position / 0.4
			link.position = Vector3(x, top_y, lerpf(-z_extent, z_extent, ratio))
			link.rotation = base_rotation
		elif loop_position < 0.5:
			var ratio := (loop_position - 0.4) / 0.1
			link.position = Vector3(x, lerpf(top_y, bottom_y, ratio), z_extent)
			link.rotation = base_rotation + Vector3(PI / 2.0, 0.0, 0.0)
		elif loop_position < 0.9:
			var ratio := (loop_position - 0.5) / 0.4
			link.position = Vector3(x, bottom_y, lerpf(z_extent, -z_extent, ratio))
			link.rotation = base_rotation
		else:
			var ratio := (loop_position - 0.9) / 0.1
			link.position = Vector3(x, lerpf(bottom_y, top_y, ratio), -z_extent)
			link.rotation = base_rotation + Vector3(PI / 2.0, 0.0, 0.0)


func _animate_rail_segments() -> void:
	var locomotion_speed := _locomotion_speed()
	var motion_scale := _motion_scale()
	for rail: Node3D in _rail_segments:
		if not is_instance_valid(rail):
			continue
		var base: Transform3D = rail.get_meta("animation_base_transform", rail.transform)
		var index := float(rail.get_meta("rail_index", 0))
		var side := float(rail.get_meta("side", 0.0))
		var wave := sin(_gait_time * 0.72 - index * 0.62) * locomotion_speed * motion_scale
		var response_basis := base.basis.rotated(Vector3.RIGHT, wave * 0.055)
		var response_origin := base.origin + Vector3(side * _smoothed_steering * 0.015, wave * 0.055, 0.0)
		rail.transform = Transform3D(response_basis, response_origin)


func _animate_propulsion_pods() -> void:
	var locomotion_speed := _locomotion_speed()
	var motion_scale := _motion_scale()
	for pod: Node3D in _propulsion_pods:
		if not is_instance_valid(pod):
			continue
		var base: Transform3D = pod.get_meta("animation_base_transform", pod.transform)
		var side := float(pod.get_meta("side", 0.0))
		var phase := float(pod.get_meta("pod_phase", 0.0))
		var hover := sin(_time * (2.1 + locomotion_speed * 1.6) + phase) * (0.035 + locomotion_speed * 0.028)
		var pitch := (-_longitudinal_load * 0.07 - _boost_blend * 0.04) * motion_scale
		var roll := (-_smoothed_steering * 0.11 + side * _steering_velocity * 0.008) * motion_scale
		var response_basis := base.basis.rotated(Vector3.RIGHT, pitch).rotated(Vector3.BACK, roll)
		var response_origin := base.origin + Vector3(0.0, (hover + _impact_offset * 0.25) * motion_scale, 0.0)
		pod.transform = Transform3D(response_basis, response_origin)


func _animate_rotors(delta: float) -> void:
	var accessibility_scale := 0.32 if reduced_motion else 1.0
	for rotor: Node3D in _rotors:
		if not is_instance_valid(rotor):
			continue
		var axis_value: Variant = rotor.get_meta("rotation_axis", Vector3.RIGHT)
		var axis: Vector3 = axis_value if axis_value is Vector3 else Vector3.RIGHT
		var rate := float(rotor.get_meta("rotation_rate", 6.0))
		var role := String(rotor.get_meta("rotor_role", "contact"))
		var drive_speed := _smoothed_speed
		match role:
			"fan": drive_speed = 0.22 + _smoothed_speed * 0.92 + _boost_blend * 0.34
			"gyro": drive_speed = 0.08 + _smoothed_speed * 1.08
			"track_roller": drive_speed = _smoothed_speed * 1.12
			_: drive_speed = _smoothed_speed * (1.0 + _boost_blend * 0.12)
		rotor.rotate_object_local(axis.normalized(), delta * rate * drive_speed * accessibility_scale)


func _animate_glow() -> void:
	var pulse_amount := 0.0 if reduced_motion else 0.035
	for glow: Node3D in _glow_nodes:
		if not is_instance_valid(glow):
			continue
		var base_scale: Vector3 = glow.get_meta("animation_glow_base_scale", glow.scale)
		var phase := float(glow.get_meta("animation_glow_phase", 0.0))
		var boost_scale := 0.0 if reduced_motion else _boost_blend * 0.22
		var pulse := 1.0 + sin(_time * 1.7 + phase) * pulse_amount + boost_scale
		glow.scale = base_scale * pulse


func _update_damage_visibility() -> void:
	for damaged: Node3D in _damage_nodes:
		if not is_instance_valid(damaged):
			continue
		if _is_native_locomotion_node(damaged):
			damaged.visible = false
			continue
		if damaged.is_in_group("mecha_cockpit_interior"):
			damaged.visible = first_person
		elif first_person and damaged.is_in_group("mecha_fps_occluder"):
			damaged.visible = false
		elif damage_ratio >= 0.88 and not reduced_motion:
			damaged.visible = int(_time * 7.0 + float(damaged.get_instance_id() % 17)) % 4 != 0
		else:
			damaged.visible = true


func _rebuild_animation_cache() -> void:
	_body_nodes.clear()
	_segments.clear()
	_contacts.clear()
	_joints.clear()
	_rotors.clear()
	_suspension_nodes.clear()
	_track_links.clear()
	_rail_segments.clear()
	_propulsion_pods.clear()
	_glow_nodes.clear()
	_damage_nodes.clear()
	_drive_id = ""
	var configuration_value: Variant = get_meta("locomotion_configuration", {})
	if configuration_value is Dictionary:
		var configuration: Dictionary = configuration_value
		_drive_id = String(configuration.get("drive_id", ""))
	if _drive_id.is_empty():
		_drive_id = _find_drive_id(self)
	for child: Node in get_children():
		if child is Node3D and not (child is Marker3D) and not child.is_in_group("mecha_native_locomotion") and not child.is_in_group("mecha_locomotion_module"):
			var body_node := child as Node3D
			_remember_transform(body_node)
			_body_nodes.append(body_node)
	_scan_animation_nodes(self)
	set_meta("motion_animation_version", 2)
	set_meta("animation_detail_tier", "race_midpoly_cached")
	set_meta("animation_reduced_motion", reduced_motion)
	set_meta("motion_animation_drive", _drive_id)
	set_meta("motion_animation_cached_nodes", _cached_node_count())
	set_meta("motion_animation_budget", "cached_procedural_web")
	_cache_ready = true


func _scan_animation_nodes(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Node3D:
			var spatial := child as Node3D
			if child.is_in_group("mecha_articulated_segment"):
				_remember_transform(spatial)
				_segments.append(spatial)
			if child.is_in_group("mecha_locomotion_contact"):
				_remember_transform(spatial)
				_contacts.append(spatial)
			if child.is_in_group("mecha_locomotion_joint"):
				_remember_transform(spatial)
				_joints.append(spatial)
			if child.is_in_group("mecha_locomotion_rotor"):
				_rotors.append(spatial)
			if child.is_in_group("mecha_suspension"):
				_remember_transform(spatial)
				_suspension_nodes.append(spatial)
			if child.is_in_group("mecha_track_link"):
				_remember_transform(spatial)
				_track_links.append(spatial)
			if child.is_in_group("mecha_rail_segment"):
				_remember_transform(spatial)
				_rail_segments.append(spatial)
			if child.is_in_group("mecha_propulsion_pod"):
				_remember_transform(spatial)
				_propulsion_pods.append(spatial)
			if child.is_in_group("mecha_glow"):
				spatial.set_meta("animation_glow_base_scale", spatial.scale)
				spatial.set_meta("animation_glow_phase", float(spatial.get_instance_id() % 23) * 0.31)
				_glow_nodes.append(spatial)
			if child.is_in_group("mecha_damage_part"):
				_damage_nodes.append(spatial)
		_scan_animation_nodes(child)


func _remember_transform(node: Node3D) -> void:
	if not node.has_meta("animation_base_transform"):
		node.set_meta("animation_base_transform", node.transform)
		node.set_meta("animation_base_position", node.position)
		node.set_meta("animation_base_rotation", node.rotation)
		node.set_meta("animation_base_scale", node.scale)


func _apply_camera_visibility(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Node3D:
			var spatial := child as Node3D
			if spatial.is_in_group("mecha_fps_occluder"):
				spatial.visible = false if _is_native_locomotion_node(spatial) else not first_person
			if spatial.is_in_group("mecha_cockpit_interior"):
				spatial.visible = first_person
		_apply_camera_visibility(child)


func _find_drive_id(node: Node) -> String:
	if node.is_in_group("mecha_locomotion_module"):
		return String(node.get_meta("drive_id", "mecha_legs"))
	for child: Node in node.get_children():
		var found := _find_drive_id(child)
		if not found.is_empty():
			return found
	return ""


func _is_native_locomotion_node(node: Node) -> bool:
	var cursor: Node = node
	while cursor != null and cursor != self:
		if cursor.is_in_group("mecha_native_locomotion"):
			return true
		cursor = cursor.get_parent()
	return false


func _enforce_native_locomotion_hidden() -> void:
	for child: Node in get_children():
		if child.is_in_group("mecha_native_locomotion"):
			_hide_native_branch(child)


func _hide_native_branch(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	for child: Node in node.get_children():
		_hide_native_branch(child)


func _locomotion_speed() -> float:
	return clampf((_smoothed_speed - 0.08) / 0.92, 0.0, 1.35)


func _motion_scale() -> float:
	return 0.0 if reduced_motion else 1.0


func _gait_rate(locomotion_speed: float) -> float:
	match _drive_id:
		"multi_support": return lerpf(1.1, 12.5, clampf(locomotion_speed, 0.0, 1.0))
		"mecha_legs": return lerpf(0.9, 9.2, clampf(locomotion_speed, 0.0, 1.0))
		"treads", "articulated_rail": return lerpf(0.5, 10.5, clampf(locomotion_speed, 0.0, 1.0))
		"wheels", "sphere_drive", "mono_gyro": return lerpf(0.4, 11.0, clampf(locomotion_speed, 0.0, 1.0))
		"ducted_fans": return lerpf(1.6, 8.0, clampf(locomotion_speed, 0.0, 1.0))
		_: return lerpf(0.8, 6.5, clampf(locomotion_speed, 0.0, 1.0))


func _stride_length() -> float:
	return 0.44 if _drive_id == "mecha_legs" else 0.28


func _step_height() -> float:
	return 0.32 if _drive_id == "mecha_legs" else 0.19


func _roll_response() -> float:
	match _drive_id:
		"treads", "articulated_rail": return 0.045
		"multi_support": return 0.065
		"hover_skids", "twin_antigrav", "ducted_fans": return 0.13
		_: return 0.095


func _pitch_response() -> float:
	match _drive_id:
		"treads", "articulated_rail": return 0.042
		"hover_skids", "twin_antigrav": return 0.085
		_: return 0.065


func _technology_bob(locomotion_speed: float) -> float:
	if reduced_motion:
		return 0.0
	match _drive_id:
		"mecha_legs": return sin(_gait_time * 2.0) * 0.036 * locomotion_speed
		"multi_support": return sin(_gait_time * 2.0) * 0.018 * locomotion_speed
		"wheels", "sphere_drive", "mono_gyro": return sin(_gait_time * 1.65) * 0.012 * locomotion_speed
		"treads", "articulated_rail": return sin(_gait_time * 1.35) * 0.007 * locomotion_speed
		"hover_skids", "twin_antigrav", "ducted_fans": return sin(_time * 2.3) * (0.045 + locomotion_speed * 0.018)
		_: return sin(_time * 1.8) * 0.02


func _impact_side() -> float:
	return -1.0 if get_instance_id() % 2 == 0 else 1.0


func _cached_node_count() -> int:
	return _body_nodes.size() + _segments.size() + _contacts.size() + _joints.size() + _rotors.size() + _suspension_nodes.size() + _track_links.size() + _rail_segments.size() + _propulsion_pods.size() + _glow_nodes.size() + _damage_nodes.size()
