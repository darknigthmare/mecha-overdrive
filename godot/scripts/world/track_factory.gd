class_name TrackFactory
extends RefCounted

## Builds deterministic, closed 3D racing circuits from data-only specifications.
## The generated node stores the Curve3D, gameplay markers and track dimensions
## as metadata so the race simulation remains independent from the visuals.

const TrackSafetyType := preload("res://scripts/world/track_safety.gd")
const RaceCollisionSystemType := preload("res://scripts/race/race_collision_system.gd")
const TrackHazardSystemType := preload("res://scripts/world/track_hazard_system.gd")

const DEFAULT_WIDTH := 35.0
const SAMPLE_STEP := 4.0
const POINT_COUNT := 48
const GOLDEN_DISTRIBUTION := 0.61803398875
const SCENERY_GROUND_Y := -18.0
const SCENERY_SIDE_PATTERN := [-1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0]


static func build(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Track_%s" % String(spec.get("id", "unknown"))

	var curve := _build_curve(spec)
	var length := curve.get_baked_length()
	var width := maxf(float(spec.get("width", DEFAULT_WIDTH)), TrackSafetyType.minimum_road_width())
	var effective_spec := spec.duplicate(true)
	effective_spec["width"] = width
	root.set_meta("spec", effective_spec)
	root.set_meta("curve", curve)
	root.set_meta("length", length)
	root.set_meta("width", width)
	root.set_meta("safety_report", TrackSafetyType.track_report(effective_spec))

	_build_environment(root, effective_spec)
	_build_road(root, curve, length, width, effective_spec)
	_build_hazard_zones(root, curve, length, width, effective_spec)
	_build_scenery(root, curve, length, width, effective_spec)
	_build_start_finish_complex(root, curve, length, width, effective_spec)
	_build_gameplay_markers(root, curve, length, width, effective_spec)
	return root


static func sample_pose(track: Node3D, distance: float, lane: float = 0.0, reverse: bool = false) -> Transform3D:
	var curve: Curve3D = track.get_meta("curve")
	var length: float = maxf(1.0, float(track.get_meta("length")))
	var offset := fposmod(-distance if reverse else distance, length)
	var pose := curve.sample_baked_with_rotation(offset, true, true)
	var width: float = float(track.get_meta("width"))
	pose.origin += pose.basis.x.normalized() * clampf(lane, -1.12, 1.12) * width * TrackSafetyType.LANE_SCALE
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
	_build_road_surface_collision(root, road_mesh)

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
	_build_barrier_collision(root, curve, length, width)


static func _build_road_surface_collision(root: Node3D, road_mesh: ArrayMesh) -> void:
	var body := StaticBody3D.new()
	body.name = "RoadCollisionBody"
	body.collision_layer = RaceCollisionSystemType.TRACK_SURFACE_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "RoadCollisionShape"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(road_mesh.get_faces())
	collision.shape = shape
	body.add_child(collision)
	body.set_meta("collision_kind", "static_road_trimesh")
	body.set_meta("triangle_count", int(shape.get_faces().size() / 3.0))
	root.add_child(body)


static func _build_barrier_collision(root: Node3D, curve: Curve3D, length: float, width: float) -> void:
	var faces := PackedVector3Array()
	var segment_count := maxi(32, int(ceil(length / 8.0)))
	var lateral_offset := width * 0.5 + 0.34
	var barrier_height := 2.45
	for index in range(segment_count):
		var d0 := length * float(index) / float(segment_count)
		var d1 := length * float(index + 1) / float(segment_count)
		var p0 := curve.sample_baked_with_rotation(d0, true, true)
		var p1 := curve.sample_baked_with_rotation(fposmod(d1, length), true, true)
		for side: float in [-1.0, 1.0]:
			var bottom0 := p0.origin + p0.basis.x.normalized() * lateral_offset * side
			var bottom1 := p1.origin + p1.basis.x.normalized() * lateral_offset * side
			var top0 := bottom0 + p0.basis.y.normalized() * barrier_height
			var top1 := bottom1 + p1.basis.y.normalized() * barrier_height
			faces.append_array(PackedVector3Array([
				bottom0, top0, top1,
				bottom0, top1, bottom1,
			]))
	var body := StaticBody3D.new()
	body.name = "TrackBarrierBody"
	body.collision_layer = RaceCollisionSystemType.TRACK_BARRIER_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "TrackBarrierShape"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collision.shape = shape
	body.add_child(collision)
	body.set_meta("collision_kind", "static_barrier_trimesh")
	body.set_meta("segment_count", segment_count * 2)
	root.add_child(body)


static func _build_hazard_zones(root: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary) -> void:
	var zones := TrackHazardSystemType.zones(spec, length)
	root.set_meta("hazard_zones", zones)
	var holder := Node3D.new()
	holder.name = "HazardZones3D"
	holder.set_meta("zone_count", zones.size())
	holder.set_meta("collision_layer", RaceCollisionSystemType.HAZARD_LAYER)
	root.add_child(holder)
	var authored_segments := 0
	for zone: Dictionary in zones:
		var start_distance := float(zone.get("start_distance", 0.0))
		var zone_length := maxf(1.0, float(zone.get("length", 1.0)))
		var segment_count := maxi(2, int(ceil(zone_length / 14.0)))
		var lane_center := float(zone.get("lane_center", 0.0))
		var lane_half_width := float(zone.get("lane_half_width", 0.28))
		var zone_width := maxf(2.0, lane_half_width * 2.0 * width * TrackSafetyType.LANE_SCALE)
		for segment in range(segment_count):
			var segment_length := zone_length / float(segment_count)
			var center_distance := start_distance + (float(segment) + 0.5) * segment_length
			var pose := curve.sample_baked_with_rotation(fposmod(center_distance, length), true, true)
			pose.origin += pose.basis.x.normalized() * lane_center * width * TrackSafetyType.LANE_SCALE
			pose.origin += pose.basis.y.normalized() * 0.10
			var area := Area3D.new()
			area.name = "%s_%02d" % [String(zone.get("id", "hazard")), segment]
			area.transform = pose
			area.collision_layer = RaceCollisionSystemType.HAZARD_LAYER
			area.collision_mask = RaceCollisionSystemType.VEHICLE_LAYER
			area.monitoring = false
			area.monitorable = true
			area.set_meta("hazard_id", String(zone.get("hazard_id", "")))
			area.set_meta("lane_center", lane_center)
			area.set_meta("lane_half_width", lane_half_width)
			area.set_meta("sector", int(zone.get("sector", 0)))
			var collision := CollisionShape3D.new()
			collision.name = "HazardCollisionShape"
			var box := BoxShape3D.new()
			box.size = Vector3(zone_width, 0.32, segment_length + 1.5)
			collision.shape = box
			area.add_child(collision)
			var visual := MeshInstance3D.new()
			visual.name = "HazardSurface"
			var visual_box := BoxMesh.new()
			visual_box.size = Vector3(zone_width, 0.045, segment_length + 1.5)
			visual.mesh = visual_box
			visual.material_override = _hazard_zone_material(Color(zone.get("color", Color("ffd45b"))))
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			area.add_child(visual)
			holder.add_child(area)
			authored_segments += 1
	holder.set_meta("segment_count", authored_segments)


static func _hazard_zone_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var transparent := color
	transparent.a = 0.22
	material.albedo_color = transparent
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.7
	return material


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
	var profile := TrackVisualProfiles.scenery_profile(spec)
	var report := {
		"profile": String(profile.get("id", "industrial")),
		"signature": String(profile.get("signature", "forge_crane")),
		"trackside_props": int(profile.get("trackside_props", 30)),
		"hero_props": int(profile.get("hero_props", 6)),
		"infrastructure": int(profile.get("infrastructure", 9)),
		"background_silhouettes": int(profile.get("background_silhouettes", 48)),
		"background_groups": int(profile.get("background_groups", 3)),
		"dynamic_lights": int(profile.get("dynamic_lights", 5)),
		"minimum_clearance": float(profile.get("clearance", 8.5)),
		"animated_props": 0,
		"node_budget": int(profile.get("node_budget", 210)),
		"foreground_lod": float(profile.get("foreground_lod", 230.0)),
		"midfield_lod": float(profile.get("midfield_lod", 390.0)),
		"background_lod": float(profile.get("background_lod", 920.0)),
	}
	_build_midfield_props(holder, curve, length, width, spec, profile, seed, accent, glow)
	_build_corner_landmarks(holder, curve, length, width, spec, profile, seed, accent, glow)
	_build_track_infrastructure(holder, curve, length, width, spec, profile, seed, accent, glow)
	_build_background_silhouettes(holder, curve, length, width, spec, profile, seed, accent)
	_build_scenery_lights(holder, curve, length, width, profile, seed, accent, glow)
	var trackside_count := int(report["trackside_props"])
	var hero_count := int(report["hero_props"])
	var infrastructure_count := int(report["infrastructure"])
	report["estimated_render_nodes"] = (
		trackside_count + int(ceil(float(trackside_count) / 5.0)) + hero_count * 4
		+ infrastructure_count * 4 + int(ceil(float(infrastructure_count) / 3.0)) * 3
		+ int(report["background_groups"]) + int(report["dynamic_lights"])
	)
	var actual_descendants := _count_descendants(holder)
	var detail_prop_count := (
		trackside_count + hero_count + infrastructure_count
		+ int(report["background_silhouettes"])
	)
	report["actual_descendants"] = actual_descendants
	report["detail_prop_count"] = detail_prop_count
	holder.set_meta("environment_detail_tier", "production_web")
	holder.set_meta("detail_prop_count", detail_prop_count)
	holder.set_meta("web_prop_budget", int(report["node_budget"]))
	holder.set_meta("actual_descendants", actual_descendants)
	holder.add_to_group(&"track_production_detail", true)
	root.set_meta("environment_detail_tier", "production_web")
	root.set_meta("detail_prop_count", detail_prop_count)
	root.set_meta("web_prop_budget", int(report["node_budget"]))
	root.set_meta("scenery_budget", profile.duplicate(true))
	root.set_meta("scenery_report", report)


static func _build_midfield_props(
	holder: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary,
	profile: Dictionary, seed: int, accent: Color, glow: Color
) -> void:
	var props := Node3D.new()
	props.name = "MidfieldProps"
	holder.add_child(props)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 104729 + 31
	var count := int(profile.get("trackside_props", 30))
	var clearance := float(profile.get("clearance", 8.5))
	var lod_end := float(profile.get("midfield_lod", 390.0))
	for index in range(count):
		var normalized := fposmod(0.085 + (float(index) + 0.5) * GOLDEN_DISTRIBUTION + float(seed % 101) * 0.0037, 1.0)
		if normalized < 0.055 or normalized > 0.95:
			normalized = fposmod(normalized + 0.11, 1.0)
		var pose := curve.sample_baked_with_rotation(length * normalized, true, true)
		var anchor := Node3D.new()
		anchor.name = "PropAnchor_%02d" % index
		anchor.transform = pose
		props.add_child(anchor)
		var side := _scenery_side(index, seed)
		var lateral := side * (width * 0.5 + clearance + rng.randf_range(0.5, 18.0))
		var prop := MeshInstance3D.new()
		prop.name = "Prop_%02d" % index
		prop.mesh = TrackVisualProfiles.prop_mesh_for_tier(spec, posmod(index * 5 + seed, 13), rng, "midfield")
		var tint := Color.WHITE.lerp(accent, rng.randf_range(0.10, 0.32)).darkened(rng.randf_range(0.0, 0.14))
		prop.material_override = MaterialLibrary.prop_for(spec, tint, rng.randf_range(1.8, 3.4))
		prop.position = Vector3(lateral, 0.0, rng.randf_range(-5.0, 5.0))
		prop.rotation.y = rng.randf_range(-PI, PI)
		var scale_value := rng.randf_range(0.72, 1.16)
		prop.scale = Vector3(scale_value, scale_value * float(profile.get("vertical_scale", 1.0)), scale_value)
		_align_mesh_to_surface(prop)
		prop.visibility_range_end = lod_end
		anchor.add_child(prop)
		var cluster: Array[MeshInstance3D] = [prop]

		if index % 5 == 1:
			var marker := MeshInstance3D.new()
			marker.name = "IdentityLight_%02d" % index
			var marker_mesh := CylinderMesh.new()
			marker_mesh.top_radius = rng.randf_range(0.24, 0.42)
			marker_mesh.bottom_radius = marker_mesh.top_radius
			marker_mesh.height = rng.randf_range(0.12, 0.22)
			marker_mesh.radial_segments = 12
			marker.mesh = marker_mesh
			marker.material_override = _emissive_material(glow if index % 2 == 0 else accent, 2.5)
			marker.position = Vector3(lateral, rng.randf_range(1.2, 3.2), prop.position.z)
			marker.rotation.x = PI * 0.5
			marker.visibility_range_end = lod_end
			anchor.add_child(marker)
			cluster.append(marker)
		_enforce_trackside_clearance(cluster, width, clearance, side)


static func _build_corner_landmarks(
	holder: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary,
	profile: Dictionary, seed: int, accent: Color, glow: Color
) -> void:
	var landmarks := Node3D.new()
	landmarks.name = "CornerLandmarks"
	holder.add_child(landmarks)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 130363 + 71
	var distances := _corner_feature_distances(curve, length, int(profile.get("hero_props", 6)), seed)
	var clearance := float(profile.get("clearance", 8.5)) + 2.0
	var lod_end := float(profile.get("foreground_lod", 230.0))
	for index in range(distances.size()):
		var distance: float = distances[index]
		var pose := curve.sample_baked_with_rotation(distance, true, true)
		var anchor := Node3D.new()
		anchor.name = "Hero_%02d_%s" % [index, String(profile.get("signature", "landmark"))]
		anchor.transform = pose
		landmarks.add_child(anchor)
		var side := _scenery_side(index * 3 + 1, seed)
		var lateral := side * (width * 0.5 + clearance + rng.randf_range(1.5, 7.0))

		var plinth := MeshInstance3D.new()
		plinth.name = "Foundation"
		var plinth_mesh := BoxMesh.new()
		plinth_mesh.size = Vector3(rng.randf_range(4.8, 7.2), 0.5, rng.randf_range(4.0, 7.0))
		plinth_mesh.subdivide_width = 2
		plinth_mesh.subdivide_depth = 2
		plinth.mesh = plinth_mesh
		plinth.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.16), 2.6)
		plinth.position = Vector3(lateral, 0.25, 0.0)
		plinth.visibility_range_end = lod_end
		anchor.add_child(plinth)

		var main := MeshInstance3D.new()
		main.name = "SignatureBody"
		main.mesh = TrackVisualProfiles.prop_mesh_for_tier(spec, posmod(index * 7 + seed, 17), rng, "foreground")
		main.material_override = MaterialLibrary.prop_for(spec, Color.WHITE.lerp(accent, 0.25), 3.4)
		main.position = Vector3(lateral, 0.5, 0.0)
		main.rotation.y = rng.randf_range(-0.5, 0.5)
		var hero_scale := float(profile.get("hero_scale", 1.2)) * rng.randf_range(0.92, 1.12)
		main.scale = Vector3(hero_scale, hero_scale * float(profile.get("vertical_scale", 1.0)), hero_scale)
		_align_mesh_to_surface(main, 0.5)
		main.visibility_range_end = lod_end
		anchor.add_child(main)

		var collar := MeshInstance3D.new()
		collar.name = "EnergyCollar"
		var collar_mesh := CylinderMesh.new()
		collar_mesh.top_radius = 1.25 * hero_scale
		collar_mesh.bottom_radius = collar_mesh.top_radius
		collar_mesh.height = 0.18
		collar_mesh.radial_segments = 20
		collar.mesh = collar_mesh
		collar.material_override = _emissive_material(glow if index % 2 == 0 else accent, 3.0)
		collar.position = Vector3(lateral, main.position.y + maxf(1.6, main.mesh.get_aabb().size.y * main.scale.y * 0.48), 0.0)
		collar.rotation.x = PI * 0.5
		collar.visibility_range_end = lod_end
		anchor.add_child(collar)

		var fin := MeshInstance3D.new()
		fin.name = "RecognitionFin"
		var fin_mesh := PrismMesh.new()
		fin_mesh.size = Vector3(0.3, rng.randf_range(2.2, 3.8), rng.randf_range(2.8, 4.6))
		fin.mesh = fin_mesh
		fin.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.32), 2.0)
		fin.position = Vector3(lateral + side * 1.5, 2.0, -0.8)
		fin.rotation.z = deg_to_rad(10.0 * side)
		fin.visibility_range_end = lod_end
		anchor.add_child(fin)

		var landmark_parts: Array[MeshInstance3D] = [plinth, main, collar, fin]
		_enforce_trackside_clearance(landmark_parts, width, float(profile.get("clearance", 8.5)), side)

static func _build_track_infrastructure(
	holder: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary,
	profile: Dictionary, seed: int, accent: Color, glow: Color
) -> void:
	var infrastructure := Node3D.new()
	infrastructure.name = "TrackInfrastructure"
	holder.add_child(infrastructure)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 15485863 + 101
	var count := int(profile.get("infrastructure", 9))
	var clearance := float(profile.get("clearance", 8.5))
	var lod_end := float(profile.get("midfield_lod", 390.0))
	for index in range(count):
		var normalized := fposmod(0.12 + (float(index) + 0.5) * GOLDEN_DISTRIBUTION + float(seed % 37) * 0.0061, 1.0)
		if normalized < 0.07 or normalized > 0.94:
			normalized = fposmod(normalized + 0.16, 1.0)
		var pose := curve.sample_baked_with_rotation(length * normalized, true, true)
		var installation := Node3D.new()
		installation.name = "Infrastructure_%02d" % index
		installation.transform = pose
		infrastructure.add_child(installation)
		var side := _scenery_side(index * 2 + 2, seed)
		var outside := side * (width * 0.5 + clearance + 2.2)
		var height := rng.randf_range(5.4, 8.4)

		var base := MeshInstance3D.new()
		base.name = "ServiceFoundation"
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(3.8, 0.6, 3.2)
		base.mesh = base_mesh
		base.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.12), 2.8)
		base.position = Vector3(outside, 0.3, 0.0)
		base.visibility_range_end = lod_end
		installation.add_child(base)

		var pylon := MeshInstance3D.new()
		pylon.name = "TelemetryPylon"
		var pylon_mesh := CylinderMesh.new()
		pylon_mesh.top_radius = 0.34
		pylon_mesh.bottom_radius = 0.62
		pylon_mesh.height = height
		pylon_mesh.radial_segments = 12
		pylon_mesh.rings = 3
		pylon.mesh = pylon_mesh
		pylon.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.18), 3.2)
		pylon.position = Vector3(outside, height * 0.5 + 0.6, 0.0)
		pylon.visibility_range_end = lod_end
		installation.add_child(pylon)

		var arm := MeshInstance3D.new()
		arm.name = "CameraArm"
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(3.6, 0.26, 0.38)
		arm.mesh = arm_mesh
		arm.material_override = MaterialLibrary.infrastructure(Color.WHITE, 2.2)
		arm.position = Vector3(outside - side * 1.65, height - 0.15, 0.0)
		arm.rotation.z = deg_to_rad(-4.0 * side)
		arm.visibility_range_end = lod_end
		installation.add_child(arm)

		var sector_signal := MeshInstance3D.new()
		sector_signal.name = "SectorSignal"
		var signal_mesh := SphereMesh.new()
		signal_mesh.radius = 0.42
		signal_mesh.height = 0.84
		signal_mesh.radial_segments = 14
		signal_mesh.rings = 7
		sector_signal.mesh = signal_mesh
		sector_signal.material_override = _emissive_material(glow if index % 2 == 0 else accent, 2.8)
		sector_signal.position = Vector3(outside - side * 3.25, height - 0.15, 0.0)
		sector_signal.visibility_range_end = lod_end
		installation.add_child(sector_signal)

		var installation_parts: Array[MeshInstance3D] = [base, pylon, arm, sector_signal]
		_enforce_trackside_clearance(installation_parts, width, clearance, side)
		if index % 3 == 0:
			_build_clearance_gantry(installation, width, clearance, height + 3.8, index, accent, lod_end)


static func _build_clearance_gantry(
	parent: Node3D, width: float, clearance: float, height: float, index: int, accent: Color, lod_end: float
) -> void:
	var safe_x := width * 0.5 + clearance + 0.3
	for side: float in [-1.0, 1.0]:
		var support := MeshInstance3D.new()
		support.name = "GantrySupport_%s_%02d" % ["L" if side < 0.0 else "R", index]
		var support_mesh := BoxMesh.new()
		support_mesh.size = Vector3(0.55, height, 0.75)
		support.mesh = support_mesh
		support.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.18), 3.0)
		support.position = Vector3(safe_x * side, height * 0.5, 0.0)
		support.visibility_range_end = lod_end
		parent.add_child(support)
	var beam := MeshInstance3D.new()
	beam.name = "HighClearanceBeam_%02d" % index
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(safe_x * 2.0, 0.52, 0.84)
	beam.mesh = beam_mesh
	beam.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.22), 3.6)
	beam.position = Vector3(0.0, height, 0.0)
	beam.visibility_range_end = lod_end
	parent.add_child(beam)


static func _build_background_silhouettes(
	holder: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary,
	profile: Dictionary, seed: int, accent: Color
) -> void:
	var skyline := Node3D.new()
	skyline.name = "DistantSilhouettes"
	holder.add_child(skyline)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 32452843 + 211
	var total_count := int(profile.get("background_silhouettes", 48))
	var group_count := int(profile.get("background_groups", 3))
	var far_min := float(profile.get("far_min", 54.0))
	var far_max := float(profile.get("far_max", 120.0))
	var lod_end := float(profile.get("background_lod", 920.0))
	var profile_id := String(profile.get("id", "industrial"))
	for group_index in range(group_count):
		var instance_count := int(total_count / group_count) + (1 if group_index < total_count % group_count else 0)
		var primitive := TrackVisualProfiles.prop_mesh_for_tier(spec, seed + group_index * 7, rng, "background")
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = primitive
		multimesh.instance_count = instance_count
		var mesh_aabb := primitive.get_aabb()
		for local_index in range(instance_count):
			var global_index := group_index + local_index * group_count
			var normalized := fposmod((float(global_index) + 0.35) * GOLDEN_DISTRIBUTION + float(seed % 83) * 0.0049, 1.0)
			var pose := curve.sample_baked_with_rotation(length * normalized, true, true)
			var side := _scenery_side(global_index + 5, seed)
			var offset := side * (width * 0.5 + rng.randf_range(far_min, far_max))
			var origin := pose.origin + pose.basis.x.normalized() * offset
			var horizontal_scale := rng.randf_range(1.8, 4.2)
			var vertical_scale := horizontal_scale * rng.randf_range(1.1, 2.1) * float(profile.get("vertical_scale", 1.0))
			var scale := Vector3(horizontal_scale, vertical_scale, horizontal_scale * rng.randf_range(0.8, 1.3))
			if profile_id == "orbital":
				origin.y = pose.origin.y + rng.randf_range(-18.0, 22.0)
			else:
				origin.y = SCENERY_GROUND_Y - mesh_aabb.position.y * scale.y
			var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(scale)
			multimesh.set_instance_transform(local_index, Transform3D(basis, origin))
		var skyline_group := MultiMeshInstance3D.new()
		skyline_group.name = "Skyline_%02d" % group_index
		skyline_group.multimesh = multimesh
		var tint := Color.WHITE.lerp(accent, 0.12 + float(group_index) * 0.07).darkened(0.18 + float(group_index) * 0.05)
		if profile_id in ["industrial", "urban", "orbital"]:
			skyline_group.material_override = MaterialLibrary.infrastructure(tint, 1.8 + float(group_index))
		else:
			skyline_group.material_override = MaterialLibrary.prop_for(spec, tint, 1.8 + float(group_index))
		skyline_group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skyline_group.visibility_range_end = lod_end
		skyline_group.extra_cull_margin = 96.0
		skyline.add_child(skyline_group)


static func _build_scenery_lights(
	holder: Node3D, curve: Curve3D, length: float, width: float, profile: Dictionary,
	seed: int, accent: Color, glow: Color
) -> void:
	var lights := Node3D.new()
	lights.name = "SceneryLights"
	holder.add_child(lights)
	var count := int(profile.get("dynamic_lights", 5))
	for index in range(count):
		var normalized := fposmod(0.07 + (float(index) + 0.5) / maxf(1.0, float(count)) + float(seed % 19) * 0.009, 1.0)
		var pose := curve.sample_baked_with_rotation(length * normalized, true, true)
		var side := _scenery_side(index * 4, seed)
		var beacon := OmniLight3D.new()
		beacon.name = "TrackBounce_%02d" % index
		beacon.light_color = glow if index % 2 == 0 else accent
		beacon.light_energy = 1.65
		beacon.omni_range = 15.0
		beacon.shadow_enabled = false
		beacon.position = pose.origin + pose.basis.x.normalized() * side * (width * 0.5 + 3.2) + Vector3.UP * 3.4
		lights.add_child(beacon)


static func _corner_feature_distances(curve: Curve3D, length: float, desired_count: int, seed: int) -> Array[float]:
	var candidates: Array[Dictionary] = []
	var sample_count := maxi(32, desired_count * 6)
	for index in range(sample_count):
		var normalized := 0.065 + 0.87 * (float(index) + 0.5) / float(sample_count)
		var distance := length * normalized
		var before := curve.sample_baked_with_rotation(fposmod(distance - 16.0, length), true, true)
		var after := curve.sample_baked_with_rotation(fposmod(distance + 16.0, length), true, true)
		var turn_score := 1.0 - clampf(before.basis.z.normalized().dot(after.basis.z.normalized()), -1.0, 1.0)
		var elevation_score := absf(after.origin.y - before.origin.y) / 40.0
		var tie_breaker := float(posmod(seed + index * 17, 97)) * 0.00001
		candidates.append({"distance": distance, "score": turn_score + elevation_score * 0.24 + tie_breaker})
	var selected: Array[float] = []
	var used: Dictionary = {}
	for _slot in range(desired_count):
		var best_index := -1
		var best_score := -INF
		for candidate_index in range(candidates.size()):
			if used.has(candidate_index):
				continue
			var candidate_distance := float(candidates[candidate_index].get("distance", 0.0))
			var separated := true
			for selected_distance: float in selected:
				var delta := absf(candidate_distance - selected_distance)
				if minf(delta, length - delta) < length * 0.075:
					separated = false
					break
			if not separated:
				continue
			var score := float(candidates[candidate_index].get("score", 0.0))
			if score > best_score:
				best_score = score
				best_index = candidate_index
		if best_index < 0:
			break
		used[best_index] = true
		selected.append(float(candidates[best_index].get("distance", 0.0)))
	return selected


static func _align_mesh_to_surface(instance: MeshInstance3D, surface_y: float = 0.0) -> void:
	if instance.mesh == null:
		return
	var bounds := instance.mesh.get_aabb()
	instance.position.y = surface_y - bounds.position.y * instance.scale.y

static func _enforce_trackside_clearance(
	parts: Array[MeshInstance3D], width: float, clearance: float, side: float
) -> void:
	var minimum_x := INF
	var maximum_x := -INF
	for part: MeshInstance3D in parts:
		if part == null or part.mesh == null:
			continue
		var span := _mesh_x_span(part)
		minimum_x = minf(minimum_x, span.x)
		maximum_x = maxf(maximum_x, span.y)
	if minimum_x == INF:
		return
	var safe_edge := width * 0.5 + clearance
	var shift := 0.0
	if side < 0.0:
		shift = minf(0.0, -safe_edge - maximum_x)
	else:
		shift = maxf(0.0, safe_edge - minimum_x)
	if is_zero_approx(shift):
		return
	for part: MeshInstance3D in parts:
		if part != null:
			part.position.x += shift


static func _mesh_x_span(instance: MeshInstance3D) -> Vector2:
	var bounds := instance.mesh.get_aabb()
	var minimum_x := INF
	var maximum_x := -INF
	for x_step in range(2):
		for y_step in range(2):
			for z_step in range(2):
				var corner := bounds.position + Vector3(
					bounds.size.x * float(x_step),
					bounds.size.y * float(y_step),
					bounds.size.z * float(z_step)
				)
				var transformed := instance.transform * corner
				minimum_x = minf(minimum_x, transformed.x)

				maximum_x = maxf(maximum_x, transformed.x)
	return Vector2(minimum_x, maximum_x)

static func _count_descendants(node: Node) -> int:
	var total := node.get_child_count()
	for child: Node in node.get_children():
		total += _count_descendants(child)
	return total


static func _count_geometry_instances(node: Node) -> int:
	var total := 0
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			total += 1
		total += _count_geometry_instances(child)
	return total


static func _scenery_side(index: int, seed: int) -> float:
	return float(SCENERY_SIDE_PATTERN[posmod(index * 5 + seed, SCENERY_SIDE_PATTERN.size())])


static func _build_start_finish_complex(root: Node3D, curve: Curve3D, length: float, width: float, spec: Dictionary) -> void:
	var complex := Node3D.new()
	complex.name = "IntergalacticRaceComplex"
	complex.transform = curve.sample_baked_with_rotation(fposmod(length * 0.002, length), true, true)
	root.add_child(complex)
	complex.add_to_group(&"track_production_detail", true)

	var palette: Dictionary = spec.get("palette", {})
	var glow := _color(palette.get("glow", "#38ddff"), Color("38ddff"))
	var accent := _color(palette.get("accent", "#ff8a3d"), Color("ff8a3d"))
	var structure_material := MaterialLibrary.infrastructure(Color.WHITE, 2.2)
	var profile := TrackVisualProfiles.scenery_profile(spec)
	var safe_edge := width * 0.5 + float(profile.get("clearance", 8.5))
	var foreground_lod := float(profile.get("foreground_lod", 230.0))

	for side: float in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		pillar.name = "GantryPillar_%s" % ("L" if side < 0.0 else "R")
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.9, 8.4, 1.2)
		pillar.mesh = pillar_mesh
		pillar.material_override = structure_material
		pillar.position = Vector3((safe_edge + 0.5) * side, 4.2, 0.0)
		pillar.visibility_range_end = foreground_lod
		complex.add_child(pillar)

		var grandstand := MeshInstance3D.new()
		grandstand.name = "Grandstand_%s" % ("L" if side < 0.0 else "R")
		var stand_mesh := BoxMesh.new()
		stand_mesh.size = Vector3(8.0, 3.4, 16.0)
		grandstand.mesh = stand_mesh
		grandstand.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.18), 3.4)
		grandstand.position = Vector3((safe_edge + 4.5) * side, 1.4, 10.0)
		grandstand.rotation.z = deg_to_rad(-7.0 * side)
		grandstand.visibility_range_end = float(profile.get("foreground_lod", 230.0))
		complex.add_child(grandstand)

		# Layered seating, service bays and media fixtures create a readable paddock
		# silhouette without placing any geometry inside the homologated envelope.
		for tier_index in range(3):
			var tier := MeshInstance3D.new()
			tier.name = "StandTier_%s_%02d" % ["L" if side < 0.0 else "R", tier_index]
			var tier_mesh := BoxMesh.new()
			tier_mesh.size = Vector3(4.8, 0.72, 15.0 - float(tier_index) * 1.4)
			tier_mesh.subdivide_depth = 3
			tier.mesh = tier_mesh
			tier.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.14 + float(tier_index) * 0.06), 4.0)
			tier.position = Vector3((safe_edge + 2.5 + float(tier_index) * 1.35) * side, 0.75 + float(tier_index) * 0.82, 10.0)
			tier.visibility_range_end = float(profile.get("foreground_lod", 230.0))
			complex.add_child(tier)

		var canopy := MeshInstance3D.new()
		canopy.name = "StandCanopy_%s" % ("L" if side < 0.0 else "R")
		var canopy_mesh := PrismMesh.new()
		canopy_mesh.size = Vector3(7.2, 0.45, 17.0)
		canopy.mesh = canopy_mesh
		canopy.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.22), 3.2)
		canopy.position = Vector3((safe_edge + 5.1) * side, 5.0, 10.0)
		canopy.rotation.z = deg_to_rad(-5.0 * side)
		canopy.visibility_range_end = float(profile.get("foreground_lod", 230.0))
		complex.add_child(canopy)

		for bay_index in range(3):
			var bay_z := 23.0 + float(bay_index) * 7.0
			var bay := MeshInstance3D.new()
			bay.name = "ServiceBay_%s_%02d" % ["L" if side < 0.0 else "R", bay_index]
			var bay_mesh := BoxMesh.new()
			bay_mesh.size = Vector3(6.8, 3.2, 5.8)
			bay_mesh.subdivide_width = 2
			bay_mesh.subdivide_height = 2
			bay.mesh = bay_mesh
			bay.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.10 + float(bay_index) * 0.05), 3.6)
			bay.position = Vector3((safe_edge + 5.8) * side, 1.6, bay_z)
			bay.visibility_range_end = float(profile.get("foreground_lod", 230.0))
			complex.add_child(bay)

			var bay_strip := MeshInstance3D.new()
			bay_strip.name = "ServiceBaySignal_%s_%02d" % ["L" if side < 0.0 else "R", bay_index]
			var bay_strip_mesh := BoxMesh.new()
			bay_strip_mesh.size = Vector3(5.6, 0.16, 0.24)
			bay_strip.mesh = bay_strip_mesh
			bay_strip.material_override = _emissive_material(glow if bay_index % 2 == 0 else accent, 2.7)
			bay_strip.position = Vector3((safe_edge + 5.8) * side, 2.5, bay_z - 2.92)
			bay_strip.visibility_range_end = float(profile.get("foreground_lod", 230.0))
			complex.add_child(bay_strip)

		var camera_mast := MeshInstance3D.new()
		camera_mast.name = "BroadcastMast_%s" % ("L" if side < 0.0 else "R")
		var camera_mesh := CylinderMesh.new()
		camera_mesh.top_radius = 0.22
		camera_mesh.bottom_radius = 0.48
		camera_mesh.height = 9.5
		camera_mesh.radial_segments = 14
		camera_mesh.rings = 3
		camera_mast.mesh = camera_mesh
		camera_mast.material_override = MaterialLibrary.infrastructure(Color.WHITE, 2.5)
		camera_mast.position = Vector3((safe_edge + 1.2) * side, 4.75, -12.0)
		camera_mast.visibility_range_end = float(profile.get("foreground_lod", 230.0))
		complex.add_child(camera_mast)

	var beam := MeshInstance3D.new()
	beam.name = "StartFinishBeam"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(width * 1.42, 0.85, 1.35)
	beam.mesh = beam_mesh
	beam.material_override = structure_material
	beam.position = Vector3(0.0, 8.15, 0.0)
	complex.add_child(beam)
	beam.visibility_range_end = foreground_lod

	var race_control := MeshInstance3D.new()
	race_control.name = "RaceControlTower"
	var control_mesh := BoxMesh.new()
	control_mesh.size = Vector3(7.4, 8.2, 6.0)
	control_mesh.subdivide_width = 2
	control_mesh.subdivide_height = 3
	race_control.mesh = control_mesh
	race_control.material_override = MaterialLibrary.infrastructure(Color.WHITE.lerp(accent, 0.16), 4.2)
	race_control.position = Vector3(-(safe_edge + 8.0), 4.1, -18.0)
	race_control.visibility_range_end = float(profile.get("foreground_lod", 230.0))
	complex.add_child(race_control)

	for panel_index in range(3):
		var media_panel := MeshInstance3D.new()
		media_panel.name = "LeaguePanel_%02d" % panel_index
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(5.6, 1.25, 0.18)
		media_panel.mesh = panel_mesh
		media_panel.material_override = _emissive_material(glow if panel_index % 2 == 0 else accent, 2.2)
		media_panel.position = Vector3(
			(safe_edge + 3.0) * (-1.0 if panel_index % 2 == 0 else 1.0),
			4.0 + float(panel_index) * 1.35,
			-6.0 - float(panel_index) * 4.0
		)
		media_panel.rotation.y = deg_to_rad(8.0 * (-1.0 if panel_index % 2 == 0 else 1.0))
		media_panel.visibility_range_end = float(profile.get("foreground_lod", 230.0))
		complex.add_child(media_panel)

	var finish_strip := MeshInstance3D.new()
	finish_strip.name = "FinishStrip"
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(width, 0.075, 1.25)
	finish_strip.mesh = strip_mesh
	finish_strip.material_override = MaterialLibrary.ceremonial(Color.WHITE, 1.0)
	finish_strip.position = Vector3(0.0, 0.08, 0.0)
	complex.add_child(finish_strip)

	finish_strip.visibility_range_end = foreground_lod
	for light_index in range(5):
		var signal_light := MeshInstance3D.new()
		signal_light.name = "StartSignal_%d" % light_index
		var signal_mesh := SphereMesh.new()
		signal_mesh.radius = 0.34
		signal_mesh.height = 0.68
		signal_light.mesh = signal_mesh
		signal_light.material_override = _emissive_material(glow if light_index >= 3 else accent, 3.4)
		signal_light.position = Vector3((float(light_index) - 2.0) * 1.15, 7.95, -0.75)
		complex.add_child(signal_light)

		signal_light.visibility_range_end = foreground_lod
	for grid_index in range(8):
		var slot := MeshInstance3D.new()
		slot.name = "GridSlot_%02d" % (grid_index + 1)
		var slot_mesh := BoxMesh.new()
		slot_mesh.size = Vector3(5.4, 0.025, 7.2)
		slot.mesh = slot_mesh
		slot.material_override = _emissive_material(glow if grid_index % 2 == 0 else accent, 0.7)
		slot.position = Vector3(
			TrackSafetyType.grid_lane(grid_index) * width * TrackSafetyType.LANE_SCALE, 0.055,
			float(grid_index / 2) * TrackSafetyType.GRID_ROW_SPACING + 4.5
		)
		slot.visibility_range_end = foreground_lod
		complex.add_child(slot)

	complex.set_meta("environment_detail_tier", "production_web")
	var foreground_mesh_count := _count_geometry_instances(complex)
	complex.set_meta("foreground_mesh_count", foreground_mesh_count)
	root.set_meta("start_complex_mesh_count", foreground_mesh_count)
	root.set_meta("start_complex", complex)


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
