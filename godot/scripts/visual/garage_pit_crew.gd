class_name GaragePitCrew
extends Node3D

## Lightweight procedural pit crew for the full-screen garage. The silhouettes,
## roles and animation language are original to the Nexus racing paddock.

const CREW_TEXTURE: Texture2D = preload("res://assets/textures/openai/garage_crew.png")

const CYAN := Color("61E7FF")
const ORANGE := Color("FF8A48")
const YELLOW := Color("FFD95A")
const NAVY := Color("172838")
const STEEL := Color("667988")
const VISOR := Color("9AF4FF")

var reduced_motion := false
var _phase := 0.0
var _inspection_arm: Node3D
var _engineer_arm: Node3D
var _robot_arm: Node3D
var _drone: Node3D
var _scan_disc: MeshInstance3D
var _inspector: Node3D
var _engineer: Node3D
var _service_bot: Node3D
var _toolbox: Node3D
var _sparks: Array[MeshInstance3D] = []
var _drone_base_y := 2.25

var _suit_cyan: StandardMaterial3D
var _suit_orange: StandardMaterial3D
var _tool_material: StandardMaterial3D
var _dark_material: StandardMaterial3D
var _steel_material: StandardMaterial3D
var _cyan_glow: StandardMaterial3D
var _yellow_glow: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_crew()
	set_meta(&"pit_crew_actor_count", 4)
	set_meta(&"web_lightweight", true)
	set_reduced_motion(reduced_motion)


func _process(delta: float) -> void:
	if reduced_motion:
		return
	_phase += delta
	_apply_pivot_wave(_inspection_arm, sin(_phase * 1.35) * 0.16, Vector3.RIGHT)
	_apply_pivot_wave(_engineer_arm, sin(_phase * 1.8 + 0.8) * 0.2, Vector3.FORWARD)
	_apply_pivot_wave(_robot_arm, sin(_phase * 1.55 + 1.4) * 0.22, Vector3.FORWARD)
	if is_instance_valid(_drone):
		_drone.position.y = _drone_base_y + sin(_phase * 1.7) * 0.12
		_drone.rotation.y = wrapf(_drone.rotation.y + delta * 0.38, -PI, PI)
	if is_instance_valid(_scan_disc):
		var scan_scale := 0.72 + (sin(_phase * 2.2) * 0.5 + 0.5) * 0.34
		_scan_disc.scale = Vector3(scan_scale, 1.0, scan_scale)
	for index in range(_sparks.size()):
		var spark := _sparks[index]
		var pulse := fmod(_phase * 1.9 + float(index) * 0.21, 1.0)
		spark.visible = pulse < 0.24
		spark.position = Vector3(-0.68 + float(index) * 0.08, 1.36 + pulse * 0.42, -0.35 - pulse * 0.2)
		spark.scale = Vector3.ONE * (0.7 + pulse * 0.8)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	set_process(not reduced_motion)
	_restore_rest_pose()
	for spark: MeshInstance3D in _sparks:
		spark.visible = false


## Keeps the crew outside the selected frame, including the widest locomotion
## modules, while preserving the centre sightline to the mecha.
func arrange_around(vehicle_radius: float) -> void:
	var spread := clampf(vehicle_radius + 0.65, 2.7, 3.65)
	# The camera approaches from +X/+Z. Distribute actors along its image plane
	# so every silhouette stays human-sized instead of looming in the foreground.
	if is_instance_valid(_inspector):
		_inspector.position = Vector3(-spread * 0.80, 0.0, spread * 0.48)
		_face_stage(_inspector)
	if is_instance_valid(_engineer):
		_engineer.position = Vector3(spread * 0.55, 0.0, spread * 0.40)
		_face_stage(_engineer)
	if is_instance_valid(_service_bot):
		_service_bot.position = Vector3(-spread * 0.78, 0.0, 0.05)
		_face_stage(_service_bot)
	if is_instance_valid(_drone):
		_drone.position.x = spread * 0.50
		_drone.position.z = spread * 0.10
	if is_instance_valid(_toolbox):
		_toolbox.position = Vector3(spread * 0.62, 0.34, spread * 0.36)


func actor_count() -> int:
	return get_tree().get_nodes_in_group(&"garage_pit_crew_actor").filter(
		func(actor: Node) -> bool: return is_ancestor_of(actor)
	).size()


func _build_materials() -> void:
	_suit_cyan = _material(Color("46C8D8"), CYAN, 0.45, 0.42, true)
	_suit_orange = _material(Color("E8793C"), ORANGE, 0.38, 0.48, true)
	_tool_material = _material(Color("8A98A1"), Color.TRANSPARENT, 0.72, 0.28, true)
	_dark_material = _material(NAVY, Color.TRANSPARENT, 0.65, 0.32)
	_steel_material = _material(STEEL, Color.TRANSPARENT, 0.72, 0.4)
	_cyan_glow = _material(Color("1C5663"), CYAN, 0.3, 0.25)
	_yellow_glow = _material(Color("6A5220"), YELLOW, 0.2, 0.3)


func _build_crew() -> void:
	_inspector = _build_humanoid(
		"NexusInspector", Vector3(-3.0, 0.0, 0.35), _suit_cyan, "inspection", true
	)
	_engineer = _build_humanoid(
		"VectorEngineer", Vector3(3.0, 0.0, -1.65), _suit_orange, "tool_calibration", false
	)
	_service_bot = _build_service_bot()
	_drone = _build_diagnostic_drone()
	_toolbox = Node3D.new()
	_toolbox.name = "OpenAIToolCrate"
	add_child(_toolbox)
	_part(_toolbox, "Crate", _box(Vector3(1.1, 0.62, 0.62)), _tool_material)
	_part(_toolbox, "CrateLatch", _box(Vector3(0.34, 0.08, 0.66)), _yellow_glow, Vector3(0.0, 0.08, 0.0))
	arrange_around(2.2)


func _build_humanoid(
	actor_name: String,
	actor_position: Vector3,
	suit_material: StandardMaterial3D,
	role: String,
	is_inspector: bool
) -> Node3D:
	var actor := Node3D.new()
	actor.name = actor_name
	actor.position = actor_position
	actor.add_to_group(&"garage_pit_crew_actor")
	actor.set_meta(&"actor_kind", "humanoid")
	actor.set_meta(&"pit_role", role)
	add_child(actor)
	_face_stage(actor)

	_part(actor, "Torso", _box(Vector3(0.72, 0.92, 0.42)), suit_material, Vector3(0.0, 1.18, 0.0))
	_part(actor, "Harness", _box(Vector3(0.82, 0.16, 0.46)), _tool_material, Vector3(0.0, 1.34, 0.0))
	_part(actor, "Backpack", _box(Vector3(0.52, 0.64, 0.24)), _tool_material, Vector3(0.0, 1.2, 0.32))
	_part(actor, "Helmet", _sphere(0.31), suit_material, Vector3(0.0, 1.91, 0.0))
	_part(actor, "Visor", _box(Vector3(0.43, 0.18, 0.07)), _cyan_glow, Vector3(0.0, 1.94, -0.29))
	for side: float in [-1.0, 1.0]:
		_part(actor, "Leg", _cylinder(0.11, 0.62), _dark_material, Vector3(side * 0.2, 0.46, 0.0))

	var left_arm := _arm(actor, "InspectionArm" if is_inspector else "SupportArm", -0.48, -0.16)
	var right_arm := _arm(actor, "TabletArm" if is_inspector else "ToolArm", 0.48, 0.2)
	if is_inspector:
		_inspection_arm = left_arm
		_part(right_arm, "DiagnosticTablet", _box(Vector3(0.34, 0.08, 0.46)), _tool_material, Vector3(0.0, -0.72, -0.12), Vector3(0.35, 0.0, 0.0))
		_part(right_arm, "TabletScreen", _box(Vector3(0.25, 0.025, 0.32)), _cyan_glow, Vector3(0.0, -0.75, -0.23), Vector3(0.35, 0.0, 0.0))
	else:
		_engineer_arm = right_arm
		_part(right_arm, "VectorWrench", _cylinder(0.055, 0.56), _tool_material, Vector3(0.0, -0.78, -0.08), Vector3(0.0, 0.0, PI * 0.5))
		_part(right_arm, "WrenchEmitter", _sphere(0.08), _yellow_glow, Vector3(0.28, -0.78, -0.08))
	return actor


func _arm(actor: Node3D, arm_name: String, x_position: float, rest_z: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = arm_name
	pivot.position = Vector3(x_position, 1.51, 0.0)
	pivot.rotation.z = rest_z
	pivot.set_meta(&"rest_rotation", pivot.rotation)
	actor.add_child(pivot)
	_part(pivot, "Sleeve", _cylinder(0.105, 0.66), _steel_material, Vector3(0.0, -0.31, 0.0))
	_part(pivot, "Glove", _sphere(0.12), _dark_material, Vector3(0.0, -0.67, 0.0))
	return pivot


func _build_service_bot() -> Node3D:
	var actor := Node3D.new()
	actor.name = "TorqueServiceBot"
	actor.position = Vector3(-2.2, 0.0, -2.7)
	actor.add_to_group(&"garage_pit_crew_actor")
	actor.set_meta(&"actor_kind", "robot")
	actor.set_meta(&"pit_role", "reactor_service")
	add_child(actor)
	_face_stage(actor)
	_part(actor, "DriveBase", _box(Vector3(0.98, 0.34, 0.74)), _dark_material, Vector3(0.0, 0.28, 0.0))
	_part(actor, "ServiceBody", _box(Vector3(0.74, 0.82, 0.58)), _tool_material, Vector3(0.0, 0.82, 0.0))
	_part(actor, "StatusEye", _box(Vector3(0.36, 0.12, 0.07)), _cyan_glow, Vector3(0.0, 1.0, -0.32))
	for side: float in [-1.0, 1.0]:
		_part(actor, "DriveWheel", _cylinder(0.23, 0.16), _steel_material, Vector3(side * 0.52, 0.25, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	_robot_arm = Node3D.new()
	_robot_arm.name = "ArticulatedToolArm"
	_robot_arm.position = Vector3(-0.42, 1.08, -0.08)
	_robot_arm.rotation = Vector3(-0.3, 0.0, -0.48)
	_robot_arm.set_meta(&"rest_rotation", _robot_arm.rotation)
	actor.add_child(_robot_arm)
	_part(_robot_arm, "ArmRail", _cylinder(0.075, 0.72), _steel_material, Vector3(0.0, 0.32, 0.0))
	_part(_robot_arm, "FusionTool", _box(Vector3(0.18, 0.28, 0.18)), _tool_material, Vector3(0.0, 0.73, 0.0))
	_part(_robot_arm, "ToolGlow", _sphere(0.09), _yellow_glow, Vector3(0.0, 0.9, 0.0))
	for spark_index in range(3):
		var spark := _part(actor, "ServiceSpark%d" % spark_index, _box(Vector3(0.035, 0.12, 0.035)), _yellow_glow)
		spark.add_to_group(&"garage_pit_crew_spark")
		spark.visible = false
		_sparks.append(spark)
	return actor


func _build_diagnostic_drone() -> Node3D:
	var actor := Node3D.new()
	actor.name = "HaloDiagnosticDrone"
	actor.position = Vector3(1.75, _drone_base_y, -2.75)
	actor.add_to_group(&"garage_pit_crew_actor")
	actor.set_meta(&"actor_kind", "robot")
	actor.set_meta(&"pit_role", "aero_diagnostic")
	add_child(actor)
	_part(actor, "DroneCore", _sphere(0.34), _tool_material)
	_part(actor, "DroneEye", _box(Vector3(0.26, 0.11, 0.07)), _cyan_glow, Vector3(0.0, 0.03, 0.32))
	for side: float in [-1.0, 1.0]:
		_part(actor, "Stabilizer", _box(Vector3(0.52, 0.08, 0.22)), _dark_material, Vector3(side * 0.44, 0.0, 0.0))
	_scan_disc = _part(actor, "DiagnosticScan", _cylinder(0.72, 0.018), _cyan_glow, Vector3(0.0, -0.45, 0.0))
	return actor


func _restore_rest_pose() -> void:
	for pivot: Node3D in [_inspection_arm, _engineer_arm, _robot_arm]:
		if is_instance_valid(pivot):
			pivot.rotation = pivot.get_meta(&"rest_rotation", Vector3.ZERO)
	if is_instance_valid(_drone):
		_drone.position.y = _drone_base_y
	if is_instance_valid(_scan_disc):
		_scan_disc.scale = Vector3(0.82, 1.0, 0.82)


func _apply_pivot_wave(pivot: Node3D, amount: float, axis: Vector3) -> void:
	if not is_instance_valid(pivot):
		return
	var rest: Vector3 = pivot.get_meta(&"rest_rotation", Vector3.ZERO)
	pivot.rotation = rest + axis * amount


func _face_stage(actor: Node3D) -> void:
	if is_instance_valid(actor) and actor.position.length_squared() > 0.001:
		actor.look_at(Vector3(0.0, actor.position.y, 0.0), Vector3.UP)


func _part(
	parent: Node3D,
	part_name: String,
	mesh: Mesh,
	material: Material,
	part_position: Vector3 = Vector3.ZERO,
	part_rotation: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = part_position
	instance.rotation = part_rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _material(
	color: Color,
	emission_color: Color = Color.TRANSPARENT,
	metallic: float = 0.0,
	roughness: float = 0.5,
	use_crew_texture: bool = false
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if use_crew_texture:
		material.albedo_texture = CREW_TEXTURE
		material.uv1_scale = Vector3(1.6, 1.6, 1.0)
	if emission_color.a > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 3.8
	return material


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh
