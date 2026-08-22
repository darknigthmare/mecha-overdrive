class_name TrackFactory
extends RefCounted

## Builds deterministic, closed 3D racing circuits from data-only specifications.
## The generated node stores the Curve3D, gameplay markers and track dimensions
## as metadata so the race simulation remains independent from the visuals.

const DEFAULT_WIDTH := 14.0
const SAMPLE_STEP := 4.0
const POINT_COUNT := 48


static func build(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Track_%s" % String(spec.get("id", "unknown"))

	var curve := _build_curve(spec)
	var length := curve.get_baked_length()
	var width := float(spec.get("width", DEFAULT_WIDTH))
	root.set_meta("spec", spec.duplicate(true))
	root.set_meta("curve", curve)
	root.set_meta("length", length)
	root.set_meta("width", width)

	_build_environment(root, spec)
	_build_road(root, curve, length, width, spec)
	_build_scenery(root, curve, length, width, spec)
	_build_gameplay_markers(root, curve, length, width, spec)
	return root


static func sample_pose(track: Node3D, distance: float, lane: float = 0.0, reverse: bool = false) -> Transform3D:
	var curve: Curve3D = track.get_meta("curve")
	var length: float = maxf(1.0, float(track.get_meta("length")))
	var offset := fposmod(-distance if reverse else distance, length)
	var pose := curve.sample_baked_with_rotation(offset, true, true)
	var width: float = float(track.get_meta("width"))
	pose.origin += pose.basis.x.normalized() * clampf(lane, -1.25, 1.25) * width * 0.42
	if reverse:
		pose.basis = pose.basis.rotated(pose.basis.y.normalized(), PI)
	return pose


static func track_length(track: Node3D) -> float:
	return float(track.get_meta("length", 1.0))


static func gameplay_markers(track: Node3D) -> Array:
	return track.get_meta("gameplay_markers", [])


static func _build_curve(spec: Dictionary) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 1.5
	var points := PackedVector3Array()
	var radius := float(spec.get("radius", 128.0))
	var verticality := float(spec.get("verticality", 8.0))
	var seed := int(spec.get("seed", 1))
	var harmonic_a := 2 + posmod(seed, 3)
	var harmonic_b := 3 + posmod(int(seed / 3.0), 4)

	for index in range(POINT_COUNT):
		var angle := TAU * float(index) / float(POINT_COUNT)
		points.append(TrackVisualProfiles.curve_point(spec, angle, radius, verticality, seed, harmonic_a, harmonic_b))

	# Duplicate the first point at the end. Bezier handles preserve a smooth seam.
	for index in range(POINT_COUNT + 1):
		var source_index := posmod(index, POINT_COUNT)
		var previous := points[posmod(source_index - 1, POINT_COUNT)]
		var next := points[posmod(source_index + 1, POINT_COUNT)]
		var tangent := (next - previous) * 0.18
		curve.add_point(points[source_index], -tangent, tangent)
	return curve


static func _build_environment(root: Node3D, spec: Dictionary) -> void:
	var palette: Dictionary = spec.get("palette", {})
	var sky_color := _color(palette.get("sky", "#07111f"), Color("07111f"))
	var fog_color := _color(palette.get("fog", "#162a3d"), Color("162a3d"))

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = sky_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = sky_color.lightened(0.38)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = fog_color
	environment.fog_density = float(spec.get("fog_density", 0.0024))
	world.environment = environment
	root.add_child(world)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_color = _color(palette.get("key", "#b9e8ff"), Color("b9e8ff"))
	key_light.light_energy = 1.7
	key_light.shadow_enabled = true
	key_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	root.add_child(key_light)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800.0, 1800.0)
	ground.mesh = plane
	ground.position.y = -18.0
	ground.material_override = MaterialLibrary.environment(_color(palette.get("ground", "#05080d"), Color("05080d")), 0.05, 0.92, 8.0)
	root.add_child(ground)


static func _build_road(root: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary) -> void:
	var palette: Dictionary = spec.get("palette", {})
	var road_color := _color(palette.get("road", "#202733"), Color("202733"))
	var shoulder_color := _color(palette.get("shoulder", "#4c6575"), Color("4c6575"))
	var glow_color := _color(palette.get("glow", "#38ddff"), Color("38ddff"))
	var tuning := TrackVisualProfiles.texture_tuning(spec)

	var road_mesh := _strip_mesh(curve, length, width, road_color, 0.0)
	var road := MeshInstance3D.new()
	road.name = "Road"
	road.mesh = road_mesh
	var road_material := MaterialLibrary.road_for(spec, Color.WHITE, true)
	road_material.metallic = float(tuning.get("metallic", 0.58))
	road_material.roughness = float(tuning.get("roughness", 0.38))
	road_material.uv1_scale.y = float(tuning.get("road_repeat", 0.055))
	road.material_override = road_material
	root.add_child(road)

	# Slightly wider shoulder is rendered first and lowered to avoid z-fighting.
	var shoulder := MeshInstance3D.new()
	shoulder.name = "MagneticShoulder"
	shoulder.mesh = _strip_mesh(curve, length, width + 3.6, shoulder_color, -0.12)
	var shoulder_material := MaterialLibrary.road_for(spec, Color.WHITE, true)
	shoulder_material.metallic = 0.34
	shoulder_material.roughness = 0.56
	shoulder_material.uv1_scale.y = float(tuning.get("road_repeat", 0.055)) * 0.72
	shoulder_material.vertex_color_use_as_albedo = true
	shoulder.material_override = shoulder_material
	root.add_child(shoulder)
	root.move_child(shoulder, road.get_index())

	for side: float in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = "GlowRail_%s" % ("L" if side < 0.0 else "R")
		rail.mesh = _ribbon_mesh(curve, length, width * 0.5 * side, 0.22, 0.1)
		rail.material_override = _emissive_material(glow_color, 2.8)
		root.add_child(rail)


static func _strip_mesh(curve: Curve3D, length: float, width: float, color: Color, y_offset: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(24, int(ceil(length / SAMPLE_STEP)))
	for index in range(count):
		var d0 := length * float(index) / float(count)
		var d1 := length * float(index + 1) / float(count)
		var p0 := curve.sample_baked_with_rotation(d0, true, true)
		var p1 := curve.sample_baked_with_rotation(d1, true, true)
		var left0 := p0.origin - p0.basis.x.normalized() * width * 0.5 + Vector3.UP * y_offset
		var right0 := p0.origin + p0.basis.x.normalized() * width * 0.5 + Vector3.UP * y_offset
		var left1 := p1.origin - p1.basis.x.normalized() * width * 0.5 + Vector3.UP * y_offset
		var right1 := p1.origin + p1.basis.x.normalized() * width * 0.5 + Vector3.UP * y_offset
		var stripe := color.lightened(0.055) if posmod(int(index / 4.0), 2) == 0 else color
		# Counter-clockwise from the driving side so road normals face the racers/camera.
		_add_triangle(surface, left0, right1, right0, stripe, Vector2(0, d0), Vector2(1, d1), Vector2(1, d0))
		_add_triangle(surface, left0, left1, right1, stripe, Vector2(0, d0), Vector2(0, d1), Vector2(1, d1))
	surface.index()
	surface.generate_normals()
	return surface.commit()


static func _ribbon_mesh(curve: Curve3D, length: float, lane_offset: float, width: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(24, int(ceil(length / 6.0)))
	for index in range(count):
		var d0 := length * float(index) / float(count)
		var d1 := length * float(index + 1) / float(count)
		var p0 := curve.sample_baked_with_rotation(d0, true, true)
		var p1 := curve.sample_baked_with_rotation(d1, true, true)
		var c0 := p0.origin + p0.basis.x.normalized() * lane_offset + Vector3.UP * height
		var c1 := p1.origin + p1.basis.x.normalized() * lane_offset + Vector3.UP * height
		var a0 := c0 - p0.basis.x.normalized() * width
		var b0 := c0 + p0.basis.x.normalized() * width
		var a1 := c1 - p1.basis.x.normalized() * width
		var b1 := c1 + p1.basis.x.normalized() * width
		_add_triangle(surface, a0, b1, b0, Color.WHITE, Vector2.ZERO, Vector2.ONE, Vector2.RIGHT)
		_add_triangle(surface, a0, a1, b1, Color.WHITE, Vector2.ZERO, Vector2.DOWN, Vector2.ONE)
	surface.generate_normals()
	return surface.commit()


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	var vertices: Array[Vector3] = [a, b, c]
	var uvs: Array[Vector2] = [uv_a, uv_b, uv_c]
	for index in range(vertices.size()):
		surface.set_color(color)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])


static func _build_scenery(root: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Scenery"
	root.add_child(holder)
	var palette: Dictionary = spec.get("palette", {})
	var accent := _color(palette.get("accent", "#ff8a3d"), Color("ff8a3d"))
	var glow := _color(palette.get("glow", "#38ddff"), Color("38ddff"))
	var seed := int(spec.get("seed", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var count := clampi(int(length / 34.0), 18, 56)

	for index in range(count):
		var distance := length * (float(index) + 0.4) / float(count)
		var pose := curve.sample_baked_with_rotation(distance, true, true)
		var side := -1.0 if posmod(index + seed, 2) == 0 else 1.0
		var offset := width * rng.randf_range(1.15, 2.45) * side
		var prop := MeshInstance3D.new()
		prop.name = "Prop_%02d" % index
		var shape_kind := posmod(index + seed, 4)
		prop.mesh = TrackVisualProfiles.prop_mesh(spec, shape_kind, rng)
		prop.material_override = MaterialLibrary.environment(accent.darkened(rng.randf_range(0.25, 0.68)), 0.72, 0.46, 2.4)
		prop.position = pose.origin + pose.basis.x.normalized() * offset
		prop.rotation.y = rng.randf_range(-PI, PI)
		holder.add_child(prop)

		if index % 3 == 0:
			var beacon := OmniLight3D.new()
			beacon.light_color = glow if index % 2 == 0 else accent
			beacon.light_energy = 2.3
			beacon.omni_range = 12.0
			beacon.position = prop.position + Vector3.UP * 2.5
			holder.add_child(beacon)


static func _build_gameplay_markers(root: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary) -> void:
	var markers: Array = []
	var holder := Node3D.new()
	holder.name = "GameplayMarkers"
	root.add_child(holder)
	var palette: Dictionary = spec.get("palette", {})
	var pickup_color := _color(palette.get("glow", "#38ddff"), Color("38ddff"))
	var boost_color := _color(palette.get("accent", "#ff8a3d"), Color("ff8a3d"))
	var seed := int(spec.get("seed", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 8191 + 17

	for index in range(18):
		var kind := "boost" if index % 4 == 0 else "pickup"
		var progress := fposmod(length * (float(index) + 1.25) / 19.0, length)
		var lane := rng.randf_range(-0.72, 0.72)
		markers.append({"id": "%s_%02d" % [kind, index], "kind": kind, "progress": progress, "lane": lane, "active": true})
		var pose := curve.sample_baked_with_rotation(progress, true, true)
		var visual := MeshInstance3D.new()
		visual.name = "%s_%02d" % [kind.capitalize(), index]
		if kind == "pickup":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.42
			capsule.height = 1.35
			visual.mesh = capsule
			visual.material_override = _emissive_material(pickup_color, 2.4)
			visual.position = pose.origin + pose.basis.x.normalized() * lane * width * 0.42 + Vector3.UP * 1.15
		else:
			var pad := BoxMesh.new()
			pad.size = Vector3(2.8, 0.08, 4.8)
			visual.mesh = pad
			visual.material_override = _emissive_material(boost_color, 2.8)
			visual.position = pose.origin + pose.basis.x.normalized() * lane * width * 0.42 + Vector3.UP * 0.06
			visual.basis = pose.basis
		holder.add_child(visual)
	root.set_meta("gameplay_markers", markers)


static func _material(color: Color, metallic: float, roughness: float, vertex_color: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.vertex_color_use_as_albedo = vertex_color
	return material


static func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.58, 0.24)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String and Color.html_is_valid(value):
		return Color(value)
	return fallback
