class_name MechaFactory
extends RefCounted

## Procedural factory for the ten original racing architectures. Every model is
## assembled from Godot primitives, keeping the source portable and editable.


static func build(chassis: Dictionary, paint: Color, is_player: bool = false) -> RacerVisual:
	var root := RacerVisual.new()
	root.name = "Mecha_%s" % String(chassis.get("id", "unknown"))
	root.set_meta("chassis_id", chassis.get("id", "biped"))

	var primary := _material(paint, 0.82, 0.24)
	var dark := _material(paint.darkened(0.64), 0.9, 0.31)
	var joint := _material(Color("18212c"), 0.88, 0.28)
	var glow_color := Color("64ebff") if is_player else Color(String(chassis.get("glow", "ff9c55")))
	var glow := _emissive(glow_color, 3.4 if is_player else 2.3)

	match String(chassis.get("id", "biped")):
		"tripod": _radial(root, 3, 2.35, primary, dark, joint, glow, 0.0)
		"quadruped": _quadruped(root, primary, dark, joint, glow)
		"hexapod": _radial(root, 6, 2.7, primary, dark, joint, glow, PI / 6.0)
		"octopod": _radial(root, 8, 3.1, primary, dark, joint, glow, PI / 8.0)
		"hover": _hover(root, primary, dark, glow)
		"tracked": _tracked(root, primary, dark, joint, glow)
		"monowheel": _monowheel(root, primary, dark, joint, glow)
		"orb": _orb(root, primary, dark, glow)
		"centurion": _centurion(root, primary, dark, joint, glow)
		_: _biped(root, primary, dark, joint, glow)

	_cockpit(root, primary, dark, glow)
	root.scale = Vector3.ONE * float(chassis.get("visual_scale", 1.0))
	return root


static func _biped(root: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	_box(root, Vector3(2.8, 1.0, 3.6), Vector3(0, 2.4, 0.15), primary)
	for index in range(2):
		var x := -0.92 if index == 0 else 0.92
		var hip := Vector3(x, 2.1, 0.2)
		var knee := Vector3(x * 1.12, 1.0, 0.25)
		var foot := Vector3(x * 1.18, 0.12, -0.15)
		_limb(root, hip, knee, 0.24, dark, index * PI)
		_limb(root, knee, foot, 0.29, joint, index * PI + 0.4)
		_box(root, Vector3(0.8, 0.3, 1.55), foot + Vector3(0, 0.04, -0.42), primary)
	_reactor(root, Vector3(0, 2.5, 1.8), Vector3(1.7, 0.45, 0.2), glow)


static func _quadruped(root: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	_box(root, Vector3(3.35, 0.95, 4.5), Vector3(0, 1.75, 0), primary)
	var anchors := [Vector3(-1.25, 1.55, -1.5), Vector3(1.25, 1.55, -1.5), Vector3(-1.25, 1.55, 1.4), Vector3(1.25, 1.55, 1.4)]
	for index in range(anchors.size()):
		var hip: Vector3 = anchors[index]
		var knee := hip + Vector3(signf(hip.x) * 0.7, -0.65, 0.18)
		var foot := knee + Vector3(signf(hip.x) * 0.45, -0.78, -0.18)
		_limb(root, hip, knee, 0.2, dark, index * PI * 0.5)
		_limb(root, knee, foot, 0.23, joint, index * PI * 0.5 + 0.5)
		_sphere(root, 0.32, foot, primary, Vector3(1.35, 0.55, 1.0))
	_reactor(root, Vector3(0, 1.85, 2.15), Vector3(2.2, 0.34, 0.22), glow)


static func _radial(root: Node3D, count: int, radius: float, primary: Material, dark: Material, joint: Material, glow: Material, offset: float) -> void:
	var body_radius := 1.55 + count * 0.08
	_cylinder(root, body_radius, 0.75, Vector3(0, 1.9, 0), primary)
	_sphere(root, body_radius * 0.72, Vector3(0, 2.25, -0.15), dark, Vector3(1.0, 0.55, 1.15))
	for index in range(count):
		var angle := TAU * float(index) / float(count) + offset
		var direction := Vector3(cos(angle), 0, sin(angle))
		var hip := direction * body_radius * 0.72 + Vector3.UP * 1.8
		var knee := direction * radius + Vector3.UP * 0.9
		var foot := direction * (radius + 0.65) + Vector3.UP * 0.1
		_limb(root, hip, knee, 0.18 + count * 0.008, dark, angle)
		_limb(root, knee, foot, 0.21 + count * 0.008, joint, angle + PI)
		_sphere(root, 0.26, foot, primary, Vector3(1.35, 0.55, 1.0))
	_reactor(root, Vector3(0, 1.95, body_radius * 0.9), Vector3(body_radius * 1.15, 0.3, 0.2), glow)


static func _hover(root: Node3D, primary: Material, dark: Material, glow: Material) -> void:
	_box(root, Vector3(4.2, 0.75, 5.4), Vector3(0, 1.35, 0), primary)
	_box(root, Vector3(2.5, 0.65, 3.5), Vector3(0, 1.9, -0.25), dark)
	for x: float in [-1.75, 1.75]:
		for z: float in [-1.55, 1.55]:
			_cylinder(root, 0.52, 1.35, Vector3(x, 0.72, z), dark, Vector3(PI / 2.0, 0, 0))
			_sphere(root, 0.34, Vector3(x, 0.55, z + 0.3), glow)
	_reactor(root, Vector3(0, 1.25, 2.74), Vector3(3.4, 0.22, 0.18), glow)


static func _tracked(root: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	_box(root, Vector3(3.5, 1.4, 4.4), Vector3(0, 1.55, -0.1), primary)
	for x: float in [-1.72, 1.72]:
		_box(root, Vector3(1.0, 0.95, 5.2), Vector3(x, 0.68, 0), dark)
		for z: float in [-1.65, -0.55, 0.55, 1.65]:
			_cylinder(root, 0.42, 0.95, Vector3(x, 0.65, z), joint, Vector3(0, 0, PI / 2.0))
	_reactor(root, Vector3(0, 1.6, 2.2), Vector3(2.6, 0.3, 0.22), glow)


static func _monowheel(root: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	var wheel := TorusMesh.new()
	wheel.inner_radius = 1.25
	wheel.outer_radius = 2.05
	var wheel_node := MeshInstance3D.new()
	wheel_node.name = "GyroWheel"
	wheel_node.mesh = wheel
	wheel_node.material_override = dark
	wheel_node.rotation_degrees = Vector3(90, 0, 0)
	wheel_node.position = Vector3(0, 1.72, 0)
	wheel_node.add_to_group("mecha_limb")
	wheel_node.set_meta("phase", 0.0)
	root.add_child(wheel_node)
	_box(root, Vector3(1.55, 2.1, 2.5), Vector3(0, 1.8, 0), primary)
	_sphere(root, 0.65, Vector3(0, 1.8, 0.2), joint)
	_reactor(root, Vector3(0, 1.75, 1.35), Vector3(1.0, 0.25, 0.18), glow)


static func _orb(root: Node3D, primary: Material, dark: Material, glow: Material) -> void:
	_sphere(root, 1.75, Vector3(0, 1.8, 0), primary, Vector3(1.0, 1.0, 1.15))
	for axis in range(3):
		var ring := TorusMesh.new()
		ring.inner_radius = 1.78
		ring.outer_radius = 1.94
		var node := MeshInstance3D.new()
		node.mesh = ring
		node.material_override = dark
		node.position = Vector3(0, 1.8, 0)
		node.rotation = Vector3(PI / 2.0 if axis == 0 else 0.0, PI / 2.0 if axis == 1 else 0.0, PI / 2.0 if axis == 2 else 0.0)
		node.add_to_group("mecha_limb")
		node.set_meta("phase", axis * 1.8)
		root.add_child(node)
	_reactor(root, Vector3(0, 1.8, 1.72), Vector3(1.5, 0.28, 0.18), glow)


static func _centurion(root: Node3D, primary: Material, dark: Material, joint: Material, glow: Material) -> void:
	for segment in range(6):
		var z := (float(segment) - 2.5) * 0.95
		_box(root, Vector3(2.0, 0.75, 1.05), Vector3(0, 1.45, z), primary if segment % 2 == 0 else dark)
		for side: float in [-1.0, 1.0]:
			var hip := Vector3(side * 0.82, 1.35, z)
			var knee := Vector3(side * 1.55, 0.75, z + (0.2 if segment % 2 == 0 else -0.2))
			var foot := Vector3(side * 2.05, 0.12, z)
			_limb(root, hip, knee, 0.12, dark, segment * 0.72 + (PI if side > 0 else 0.0))
			_limb(root, knee, foot, 0.15, joint, segment * 0.72)
	_reactor(root, Vector3(0, 1.5, 3.0), Vector3(1.5, 0.25, 0.18), glow)


static func _cockpit(root: Node3D, primary: Material, dark: Material, glow: Material) -> void:
	_sphere(root, 0.72, Vector3(0, 2.85, -0.35), dark, Vector3(1.2, 0.65, 1.6))
	_box(root, Vector3(0.95, 0.18, 0.58), Vector3(0, 2.88, -1.15), glow)
	_box(root, Vector3(0.16, 0.55, 1.25), Vector3(-0.72, 2.55, -0.5), primary)
	_box(root, Vector3(0.16, 0.55, 1.25), Vector3(0.72, 2.55, -0.5), primary)


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
	root.add_child(node)
	return node


static func _sphere(root: Node3D, radius: float, position: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.scale = scale_value
	node.material_override = material
	node.add_to_group("mecha_damage_part")
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
	node.rotation = rotation
	node.material_override = material
	node.add_to_group("mecha_damage_part")
	root.add_child(node)
	return node


static func _limb(root: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material, phase: float) -> void:
	var direction := finish - start
	var node := _cylinder(root, radius, direction.length(), (start + finish) * 0.5, material)
	if direction.length_squared() > 0.0001:
		node.quaternion = Quaternion(Vector3.UP, direction.normalized())
	node.add_to_group("mecha_limb")
	node.set_meta("phase", phase)


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
