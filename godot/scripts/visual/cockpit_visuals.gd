class_name CockpitVisuals
extends RefCounted

## Data-driven first-person presentation. Crewed chassis receive an authored
## physical interior; remotely operated racing bodies expose a sensor origin
## and leave instrumentation to the full-screen Sensorium HUD.

const HERO_INTERIOR_MESH_LIMIT := 24
const HERO_INTERIOR_TRIANGLE_LIMIT := 3500
const SPHERE_SEGMENTS := 16
const SPHERE_RINGS := 8


static func install(
	root: RacerVisual,
	chassis: Dictionary,
	is_player: bool,
	primary: Material,
	dark: Material,
	cockpit: Material,
	glow: Material
) -> void:
	var spec: Dictionary = chassis.get("first_person", {}) if chassis.get("first_person", {}) is Dictionary else {}
	var mode := String(spec.get("mode", "cockpit"))
	var profile := String(spec.get("profile", "command_canopy"))
	var operator_presence := String(spec.get("operator_presence", "onboard"))
	root.set_meta("first_person_mode", mode)
	root.set_meta("first_person_profile", profile)
	root.set_meta("first_person_label", String(spec.get("label", "COCKPIT TACTIQUE")))
	root.set_meta("first_person_fov", float(spec.get("fov", 79.0)))
	root.set_meta("operator_presence", operator_presence)

	var cockpit_offset: Vector3 = chassis.get("cockpit_offset", Vector3(0.0, 2.65, 0.10))
	if mode == "sensorium":
		_build_sensor_array(root, cockpit_offset, profile, dark, glow)
		var sensor_origin := Marker3D.new()
		sensor_origin.name = "SensorOrigin"
		sensor_origin.position = cockpit_offset + Vector3(spec.get("eye_offset", Vector3(0.0, 0.1, -0.5)))
		sensor_origin.add_to_group("mecha_sensor_origin")
		root.add_child(sensor_origin)
		root.set_meta("cockpit_interior_mesh_count", 0)
		root.set_meta("cockpit_interior_triangle_count", 0)
		root.set_meta("cockpit_interior_budget_ok", true)
		return

	_build_crewed_shell(root, cockpit_offset, profile, primary, dark, cockpit, glow)
	if not is_player:
		root.set_meta("cockpit_interior_mesh_count", 0)
		root.set_meta("cockpit_interior_triangle_count", 0)
		root.set_meta("cockpit_interior_budget_ok", true)
		return
	var eye_offset: Vector3 = spec.get("eye_offset", Vector3(0.0, 0.0, -1.12))
	var instrument_glow := _instrument_glow(glow)
	var holder := _build_crewed_interior(root, cockpit_offset, eye_offset, profile, cockpit, dark, instrument_glow)
	var mesh_count := _mesh_count(holder)
	var triangle_count := _triangle_count(holder)
	holder.set_meta("mesh_count", mesh_count)
	holder.set_meta("triangle_count", triangle_count)
	holder.set_meta("mesh_limit", HERO_INTERIOR_MESH_LIMIT)
	holder.set_meta("triangle_limit", HERO_INTERIOR_TRIANGLE_LIMIT)
	root.set_meta("cockpit_interior_mesh_count", mesh_count)
	root.set_meta("cockpit_interior_triangle_count", triangle_count)
	root.set_meta("cockpit_interior_budget_ok", mesh_count <= HERO_INTERIOR_MESH_LIMIT and triangle_count <= HERO_INTERIOR_TRIANGLE_LIMIT)


static func _build_crewed_shell(
	root: Node3D,
	origin: Vector3,
	profile: String,
	primary: Material,
	dark: Material,
	cockpit: Material,
	glow: Material
) -> void:
	var dimensions := _profile_dimensions(profile)
	var canopy_scale: Vector3 = dimensions.get("canopy_scale", Vector3(1.2, 0.65, 1.6))
	var canopy := _exterior_sphere(root, "CockpitCanopy", 0.72, origin + Vector3(0.0, 0.20, -0.45), cockpit, canopy_scale)
	canopy.set_meta("cockpit_profile", profile)
	var width := float(dimensions.get("width", 1.55))
	_exterior_box(root, "CockpitVisor", Vector3(width * 0.66, 0.16, 0.54), origin + Vector3(0.0, 0.24, -1.22), glow)
	_exterior_box(root, "CockpitArmorLeft", Vector3(0.16, 0.58, 1.22), origin + Vector3(-width * 0.48, -0.10, -0.60), primary)
	_exterior_box(root, "CockpitArmorRight", Vector3(0.16, 0.58, 1.22), origin + Vector3(width * 0.48, -0.10, -0.60), dark)


static func _build_sensor_array(root: Node3D, origin: Vector3, profile: String, dark: Material, glow: Material) -> void:
	var width := 1.45
	var height := 0.72
	if profile == "inertial_omniscan":
		width = 1.18
		height = 0.92
	elif profile == "distributed_command":
		width = 1.82
		height = 0.62
	var core := _exterior_sphere(root, "SensorArray", 0.38, origin + Vector3(0.0, 0.16, -0.48), dark, Vector3(width, height, 1.18))
	core.add_to_group("mecha_sensor_array")
	core.set_meta("sensor_profile", profile)
	var lens := _exterior_sphere(root, "SensorLens", 0.22, origin + Vector3(0.0, 0.18, -0.92), glow, Vector3(1.2, 0.72, 0.38))
	lens.add_to_group("mecha_sensor_array")
	for side: float in [-1.0, 1.0]:
		var band := _exterior_box(root, "SensorBandLeft" if side < 0.0 else "SensorBandRight", Vector3(0.44, 0.12, 0.22), origin + Vector3(side * width * 0.44, 0.14, -0.62), glow)
		band.add_to_group("mecha_sensor_array")


static func _build_crewed_interior(root: Node3D, origin: Vector3, eye_offset: Vector3, profile: String, cockpit: Material, dark: Material, glow: Material) -> Node3D:
	var dimensions := _profile_dimensions(profile)
	var width := float(dimensions.get("width", 1.55))
	var height := float(dimensions.get("height", 0.78))
	var dashboard_y := float(dimensions.get("dashboard_y", -0.58)) - 0.16
	var holder := Node3D.new()
	holder.name = "FPSInteriorRoot"
	holder.position = origin + eye_offset
	holder.add_to_group("mecha_cockpit_interior")
	holder.add_to_group("mecha_pilot_cockpit")
	holder.set_meta("cockpit_profile", profile)
	holder.visible = false
	root.add_child(holder)

	_interior_box(holder, "CockpitDashboard", Vector3(width * 1.02, 0.12, 0.34), Vector3(0.0, dashboard_y, -1.10), dark)
	var center_display := _interior_box(holder, "CockpitDisplay", Vector3(width * 0.44, 0.045, 0.22), Vector3(0.0, dashboard_y + 0.15, -1.16), glow)
	center_display.add_to_group("mecha_cockpit_instrument")
	for side: float in [-1.0, 1.0]:
		var side_name := "Left" if side < 0.0 else "Right"
		var frame_x := side * width * 0.55
		_interior_box(holder, "CockpitFrame%s" % side_name, Vector3(0.075, height * 1.08, 0.12), Vector3(frame_x, 0.01, -1.02), dark)
		var light_rail := _interior_box(holder, "CockpitStatusRail%s" % side_name, Vector3(0.022, height * 0.68, 0.025), Vector3(frame_x - side * 0.055, 0.00, -1.10), glow)
		light_rail.add_to_group("mecha_cockpit_instrument")
		var mfd := _interior_box(holder, "CockpitMFD%s" % side_name, Vector3(width * 0.28, 0.040, 0.20), Vector3(side * width * 0.34, dashboard_y + 0.16, -1.15), glow)
		mfd.rotation.y = side * -0.10
		mfd.add_to_group("mecha_cockpit_instrument")
		_interior_box(holder, "CockpitHarness%s" % side_name, Vector3(0.13, 0.40, 0.42), Vector3(side * width * 0.55, -0.67, -0.22), dark)
	_interior_box(holder, "CockpitTopFrame", Vector3(width * 1.22, 0.075 if profile != "armored_core" else 0.12, 0.12), Vector3(0.0, height * 0.72, -1.02), dark)
	var overhead := _interior_box(holder, "CockpitOverheadStatus", Vector3(width * 0.42, 0.022, 0.025), Vector3(0.0, height * 0.64, -1.11), glow)
	overhead.add_to_group("mecha_cockpit_instrument")
	_interior_box(holder, "CockpitYoke", Vector3(width * 0.52, 0.09, 0.11), Vector3(0.0, dashboard_y - 0.10, -0.52), dark)
	for side: float in [-1.0, 1.0]:
		_interior_box(holder, "CockpitYokeStrutLeft" if side < 0.0 else "CockpitYokeStrutRight", Vector3(0.075, 0.34, 0.075), Vector3(side * width * 0.22, dashboard_y - 0.26, -0.43), dark)
	return holder


static func _profile_dimensions(profile: String) -> Dictionary:
	match profile:
		"tri_vector_harness":
			return {"width": 1.42, "height": 0.88, "dashboard_y": -0.54, "canopy_scale": Vector3(1.05, 0.76, 1.48)}
		"predator_cradle":
			return {"width": 1.70, "height": 0.66, "dashboard_y": -0.48, "canopy_scale": Vector3(1.30, 0.55, 1.78)}
		"armored_core":
			return {"width": 1.50, "height": 0.72, "dashboard_y": -0.55, "canopy_scale": Vector3(1.18, 0.62, 1.35)}
		"aether_flightdeck":
			return {"width": 1.82, "height": 0.63, "dashboard_y": -0.46, "canopy_scale": Vector3(1.42, 0.50, 1.95)}
		"siege_cab":
			return {"width": 1.36, "height": 0.72, "dashboard_y": -0.50, "canopy_scale": Vector3(1.05, 0.62, 1.28)}
		"gyro_capsule":
			return {"width": 1.22, "height": 0.90, "dashboard_y": -0.55, "canopy_scale": Vector3(0.94, 0.82, 1.12)}
		_:
			return {"width": 1.55, "height": 0.78, "dashboard_y": -0.58, "canopy_scale": Vector3(1.20, 0.65, 1.60)}


static func _exterior_box(root: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	node.add_to_group("mecha_fps_occluder")
	node.add_to_group("mecha_chassis_body")
	root.add_child(node)
	return node


static func _exterior_sphere(root: Node3D, node_name: String, radius: float, position: Vector3, material: Material, scale_value: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = SPHERE_SEGMENTS
	mesh.rings = SPHERE_RINGS
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.scale = scale_value
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	node.add_to_group("mecha_fps_occluder")
	node.add_to_group("mecha_chassis_body")
	root.add_child(node)
	return node


static func _interior_box(root: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.material_override = material
	node.add_to_group("mecha_cockpit_interior")
	node.add_to_group("mecha_pilot_cockpit")
	root.add_child(node)
	return node


static func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _mesh_count(child)
	return count


static func _triangle_count(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			count += mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		count += _triangle_count(child)
	return count


static func _instrument_glow(source: Material) -> Material:
	var material := source.duplicate() as Material
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		standard.emission_energy_multiplier = 1.15
		standard.albedo_color = standard.albedo_color.darkened(0.18)
	return material
