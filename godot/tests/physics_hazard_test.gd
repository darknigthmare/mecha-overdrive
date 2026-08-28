extends SceneTree
## Physical race-space regression suite.
## Run with: godot --headless --path godot --script res://tests/physics_hazard_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const CatalogScript = preload("res://scripts/data/locomotion_catalog.gd")
const TrackSafetyScript = preload("res://scripts/world/track_safety.gd")
const TrackFactoryScript = preload("res://scripts/world/track_factory.gd")
const HazardScript = preload("res://scripts/world/track_hazard_system.gd")
const CollisionScript = preload("res://scripts/race/race_collision_system.gd")
const RacerScript = preload("res://scripts/race/racer_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_all_configuration_volumes()
	_test_oriented_box_contacts()
	_test_lane_aware_hazard_response()
	_test_track_collision_geometry()
	if _failures.is_empty():
		print("MECHA PHYSICS + HAZARDS: PASS (500 volumes, OBB contacts, 8 tracks, lane-aware zones, camera collision bodies)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA PHYSICS + HAZARDS: %s" % failure)
	quit(1)


func _test_all_configuration_volumes() -> void:
	var tested := 0
	for chassis: Dictionary in DatabaseScript.get_all_chassis():
		var chassis_id := String(chassis.get("id", ""))
		for configuration: Dictionary in CatalogScript.get_configurations_for_family(chassis_id):
			var size := TrackSafetyScript.vehicle_collision_size(chassis_id, configuration)
			_expect(size.x >= 2.2 and size.x <= TrackSafetyScript.MAX_HOMOLOGATED_WIDTH, "largeur collider invalide: %s %s" % [chassis_id, size])
			_expect(size.z >= 2.6 and size.z <= TrackSafetyScript.MAX_HOMOLOGATED_LENGTH, "longueur collider invalide: %s %s" % [chassis_id, size])
			_expect(size.y >= 1.6 and size.y <= 7.0, "hauteur collider invalide: %s %s" % [chassis_id, size])
			tested += 1
	_expect(tested == 500, "les volumes 3D doivent couvrir les 500 configurations")


func _test_oriented_box_contacts() -> void:
	var first := Node3D.new()
	first.name = "CollisionFirst"
	get_root().add_child(first)
	var second := Node3D.new()
	second.name = "CollisionSecond"
	get_root().add_child(second)
	var first_area := CollisionScript.install_vehicle_collider(first, "first", Vector3(4.0, 3.0, 5.0))
	var second_area := CollisionScript.install_vehicle_collider(second, "second", Vector3(4.0, 3.0, 5.0))
	_expect(first_area is Area3D and second_area is Area3D, "chaque mécha doit recevoir un Area3D")
	_expect(first_area.collision_layer == CollisionScript.VEHICLE_LAYER, "couche collision véhicule incorrecte")
	_expect(first_area.get_node_or_null("RaceCollisionShape") is CollisionShape3D, "BoxShape3D véhicule absent")
	var first_shape := first_area.get_node("RaceCollisionShape") as CollisionShape3D
	_expect(first_shape.shape is BoxShape3D, "le volume véhicule doit être un BoxShape3D rapide")

	first.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	second.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(24.0)), Vector3(2.7, 0.0, 0.2))
	first.force_update_transform()
	second.force_update_transform()
	var overlap := CollisionScript.contact_between(first, second)
	_expect(bool(overlap.get("colliding", false)), "deux BoxShape3D orientées superposées doivent entrer en contact")
	_expect(float(overlap.get("penetration", 0.0)) > 0.0, "la pénétration 3D doit être mesurée")
	var normal: Vector3 = overlap.get("normal", Vector3.ZERO)
	_expect(normal.length() > 0.99, "la normale de contact doit être normalisée")

	second.global_position = Vector3(9.0, 0.0, 0.0)
	second.force_update_transform()
	_expect(not bool(CollisionScript.contact_between(first, second).get("colliding", true)), "des colliders séparés latéralement ne doivent pas se toucher")
	second.global_position = Vector3(0.0, 6.0, 0.0)
	second.force_update_transform()
	_expect(not bool(CollisionScript.contact_between(first, second).get("colliding", true)), "la séparation verticale doit compter dans le contact 3D")
	first.free()
	second.free()


func _test_lane_aware_hazard_response() -> void:
	var forest := DatabaseScript.get_track("canopy")
	var nominal_length := 1200.0
	var zones: Array[Dictionary] = HazardScript.zones(forest, nominal_length)
	_expect(zones.size() == 3, "un circuit doit exposer trois fenêtres de danger")
	for zone: Dictionary in zones:
		var center_distance := float(zone.get("center_distance", 0.0))
		var center_lane := float(zone.get("lane_center", 0.0))
		var active := HazardScript.sample(forest, nominal_length, center_distance, center_lane)
		var safe_lane := -1.0 if center_lane >= 0.0 else 1.0
		var safe := HazardScript.sample(forest, nominal_length, center_distance, safe_lane)
		_expect(bool(active.get("active", false)), "le danger doit être actif dans sa voie: %s" % zone)
		_expect(float(active.get("intensity", 0.0)) > 0.95, "le centre de zone doit fournir son intensité maximale")
		_expect(not bool(safe.get("active", true)), "une voie libre ne doit pas subir le danger voisin")
		var escape := HazardScript.avoidance_target(active, center_lane, 1.05, 71)
		_expect(absf(escape - center_lane) > float(zone.get("lane_half_width", 0.0)), "l''IA doit viser au-delà de la largeur dangereuse")

	var common_spec := {"racer_id": "hazard", "chassis_id": "biped", "track_length": 900.0, "track_width": 36.0, "total_laps": 1}
	var exposed: RacerState = RacerScript.new().configure(common_spec)
	var protected: RacerState = RacerScript.new().configure(common_spec.merged({"racer_id": "safe"}, true))
	var controls := {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "drift": false, "boost": false}
	for tick in range(240):
		var base := {"elapsed": float(tick) / 120.0, "race_active": true, "grip": 1.0, "curvature": 0.0, "speed_multiplier": 1.0}
		var exposed_context := base.merged({"hazard": "mud", "hazard_intensity": 1.0}, true)
		var safe_context := base.merged({"hazard": "", "hazard_intensity": 0.0}, true)
		exposed.step(1.0 / 120.0, controls, exposed_context)
		protected.step(1.0 / 120.0, controls, safe_context)
	_expect(exposed.speed < protected.speed, "la voie boueuse doit ralentir le mécha exposé sans pénaliser la voie libre")


func _test_track_collision_geometry() -> void:
	for track_spec: Dictionary in DatabaseScript.get_all_tracks():
		var track: Node3D = TrackFactoryScript.build(track_spec)
		get_root().add_child(track)
		var road_body := track.get_node_or_null("RoadCollisionBody") as StaticBody3D
		var barrier_body := track.get_node_or_null("TrackBarrierBody") as StaticBody3D
		var hazards := track.get_node_or_null("HazardZones3D") as Node3D
		_expect(road_body != null and road_body.collision_layer == CollisionScript.TRACK_SURFACE_LAYER, "surface statique absente: %s" % track.name)
		_expect(barrier_body != null and barrier_body.collision_layer == CollisionScript.TRACK_BARRIER_LAYER, "barrières statiques absentes: %s" % track.name)
		if road_body != null:
			var road_shape := road_body.get_node_or_null("RoadCollisionShape") as CollisionShape3D
			_expect(road_shape != null and road_shape.shape is ConcavePolygonShape3D, "trimesh de route absent: %s" % track.name)
		if barrier_body != null:
			var barrier_shape := barrier_body.get_node_or_null("TrackBarrierShape") as CollisionShape3D
			_expect(barrier_shape != null and barrier_shape.shape is ConcavePolygonShape3D, "trimesh de rails absent: %s" % track.name)
			_expect(int(barrier_body.get_meta("segment_count", 0)) >= 64, "rails physiques trop peu segmentés: %s" % track.name)
		_expect(hazards != null and int(hazards.get_meta("zone_count", 0)) == 3, "trois zones 3D sont requises: %s" % track.name)
		if hazards != null:
			_expect(int(hazards.get_meta("segment_count", 0)) >= 6, "volumes de danger insuffisants: %s" % track.name)
			for child: Node in hazards.get_children():
				var area := child as Area3D
				_expect(area != null and area.collision_layer == CollisionScript.HAZARD_LAYER, "zone de danger sans Area3D: %s" % track.name)
				if area != null:
					_expect(area.get_node_or_null("HazardCollisionShape") is CollisionShape3D, "BoxShape3D de danger absent: %s" % area.name)
					_expect(not String(area.get_meta("hazard_id", "")).is_empty(), "identité de danger absente: %s" % area.name)
		track.free()
	_expect(CollisionScript.CAMERA_COLLISION_MASK == (CollisionScript.TRACK_SURFACE_LAYER | CollisionScript.TRACK_BARRIER_LAYER), "la caméra TPS doit interroger route et barrières")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

