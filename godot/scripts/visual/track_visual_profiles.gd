class_name TrackVisualProfiles
extends RefCounted

## Data-driven geometry language for the eight circuits. Explicit spec fields
## win; legacy ids keep deterministic defaults for backward compatibility.


static func layout(spec: Dictionary) -> String:
	var selected := String(spec.get("layout_profile", "")).to_lower()
	if not selected.is_empty():
		return selected
	match String(spec.get("id", "foundry")):
		"dunes": return "speed_bowls"
		"glacier": return "technical_ridges"
		"orbital": return "orbital_wave"
		"canopy": return "jungle_switchback"
		"tempest", "megacity": return "urban_chicane"
		"abyss": return "abyss_spiral"
		"caldera", "volcano", "reactor": return "volcanic_crown"
		_: return "industrial_loop"


static func curve_point(spec: Dictionary, angle: float, radius: float, verticality: float, seed: int, harmonic_a: int, harmonic_b: int) -> Vector3:
	var profile := layout(spec)
	var radial_wave := sin(angle * harmonic_a + seed * 0.17) * radius * 0.16
	radial_wave += cos(angle * harmonic_b - seed * 0.11) * radius * 0.08
	var elevation := sin(angle * (1 + posmod(seed, 2)) + seed) * verticality
	elevation += cos(angle * 3.0 - seed * 0.3) * verticality * 0.36
	match profile:
		"speed_bowls":
			radial_wave = cos(angle * 2.0) * radius * 0.2 + sin(angle * 6.0) * radius * 0.025
			elevation = sin(angle * 2.0) * verticality * 0.3
		"technical_ridges":
			radial_wave = sin(angle * 5.0) * radius * 0.13 + cos(angle * 9.0) * radius * 0.015
			elevation = pow(sin(angle * 3.0), 2.0) * verticality - verticality * 0.45
		"orbital_wave":
			radial_wave = sin(angle * 3.0) * radius * 0.11
			elevation = sin(angle * 2.0) * verticality * 1.7 + cos(angle * 5.0) * verticality * 0.32
		"jungle_switchback":
			radial_wave = sin(angle * 3.0) * radius * 0.12 + sin(angle * 7.0) * radius * 0.045
			elevation = sin(angle * 4.0) * verticality * 0.85
		"urban_chicane":
			radial_wave = sin(angle * 8.0) * radius * 0.055 + cos(angle * 2.0) * radius * 0.16
			elevation = sin(angle * 2.0) * verticality * 0.22
		"abyss_spiral":
			radial_wave = sin(angle * 3.0) * radius * 0.19 + cos(angle * 7.0) * radius * 0.035
			elevation = sin(angle) * verticality * 1.45 + sin(angle * 4.0) * verticality * 0.3
		"volcanic_crown":
			radial_wave = cos(angle * 6.0) * radius * 0.085 + sin(angle * 2.0) * radius * 0.13
			elevation = (1.0 - cos(angle * 3.0)) * verticality * 0.72 - verticality * 0.55
	var local_radius := radius + radial_wave
	return Vector3(cos(angle) * local_radius, elevation, sin(angle) * local_radius)


static func prop_mesh(spec: Dictionary, shape_kind: int, rng: RandomNumberGenerator) -> PrimitiveMesh:
	var prop_set := String(spec.get("prop_set", "")).to_lower()
	if prop_set.is_empty():
		prop_set = _default_prop_set(String(spec.get("id", "foundry")))
	if prop_set.contains("jungle") or prop_set.contains("canopy"):
		if shape_kind % 3 == 0:
			var trunk := CylinderMesh.new()
			trunk.top_radius = rng.randf_range(0.3, 0.7)
			trunk.bottom_radius = rng.randf_range(0.8, 1.4)
			trunk.height = rng.randf_range(7.0, 16.0)
			return trunk
		if shape_kind % 3 == 1:
			var crown := SphereMesh.new()
			crown.radius = rng.randf_range(1.4, 3.4)
			crown.height = crown.radius * rng.randf_range(1.1, 1.8)
			return crown
		var root_shard := PrismMesh.new()
		root_shard.size = Vector3(rng.randf_range(2.4, 5.8), rng.randf_range(2.0, 5.5), rng.randf_range(4.0, 9.0))
		return root_shard
	if prop_set.contains("ice") or prop_set.contains("crystal"):
		if shape_kind % 2 == 0:
			var crystal := PrismMesh.new()
			crystal.size = Vector3(rng.randf_range(1.0, 3.0), rng.randf_range(5.0, 14.0), rng.randf_range(1.0, 2.8))
			return crystal
		var ice_boulder := SphereMesh.new()
		ice_boulder.radius = rng.randf_range(1.8, 4.2)
		ice_boulder.height = ice_boulder.radius * rng.randf_range(0.9, 1.35)
		return ice_boulder
	if prop_set.contains("urban") or prop_set.contains("city"):
		if shape_kind % 2 == 0:
			var tower := BoxMesh.new()
			tower.size = Vector3(rng.randf_range(3.0, 7.0), rng.randf_range(9.0, 27.0), rng.randf_range(3.0, 7.0))
			return tower
		var city_spire := CylinderMesh.new()
		city_spire.top_radius = rng.randf_range(0.5, 1.2)
		city_spire.bottom_radius = rng.randf_range(1.4, 3.2)
		city_spire.height = rng.randf_range(10.0, 24.0)
		return city_spire
	if prop_set.contains("abyss") or prop_set.contains("coral"):
		if shape_kind % 2 == 0:
			var vent := CylinderMesh.new()
			vent.top_radius = rng.randf_range(0.35, 0.8)
			vent.bottom_radius = rng.randf_range(1.0, 2.2)
			vent.height = rng.randf_range(4.0, 11.0)
			return vent
		var coral := SphereMesh.new()
		coral.radius = rng.randf_range(1.5, 3.6)
		coral.height = coral.radius * rng.randf_range(1.4, 2.1)
		return coral
	if prop_set.contains("volcan") or prop_set.contains("lava"):
		if shape_kind % 2 == 0:
			var shard := PrismMesh.new()
			shard.size = Vector3(rng.randf_range(2.0, 5.5), rng.randf_range(5.0, 13.0), rng.randf_range(2.0, 5.0))
			return shard
		var chimney := CylinderMesh.new()
		chimney.top_radius = rng.randf_range(0.7, 1.4)
		chimney.bottom_radius = rng.randf_range(1.5, 3.0)
		chimney.height = rng.randf_range(5.0, 14.0)
		return chimney
	if prop_set.contains("orbital") or prop_set.contains("antenna"):
		if shape_kind % 2 == 0:
			var mast := CylinderMesh.new()
			mast.top_radius = rng.randf_range(0.2, 0.55)
			mast.bottom_radius = rng.randf_range(0.7, 1.4)
			mast.height = rng.randf_range(8.0, 19.0)
			return mast
		var salvage := BoxMesh.new()
		salvage.size = Vector3(rng.randf_range(3.0, 8.0), rng.randf_range(2.0, 6.0), rng.randf_range(2.0, 7.0))
		return salvage
	if prop_set.contains("desert") or prop_set.contains("dune"):
		if shape_kind % 2 == 0:
			var monolith := PrismMesh.new()
			monolith.size = Vector3(rng.randf_range(2.5, 6.0), rng.randf_range(3.0, 9.0), rng.randf_range(2.0, 5.0))
			return monolith
		var condenser := CylinderMesh.new()
		condenser.top_radius = rng.randf_range(0.9, 1.8)
		condenser.bottom_radius = rng.randf_range(1.2, 2.4)
		condenser.height = rng.randf_range(4.0, 10.0)
		return condenser
	if shape_kind == 0:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = rng.randf_range(0.5, 1.2)
		cylinder.bottom_radius = rng.randf_range(0.8, 1.6)
		cylinder.height = rng.randf_range(4.0, 12.0)
		return cylinder
	if shape_kind == 1:
		var prism := PrismMesh.new()
		prism.size = Vector3(rng.randf_range(2.0, 5.0), rng.randf_range(2.0, 7.0), rng.randf_range(1.0, 3.0))
		return prism
	var box := BoxMesh.new()
	box.size = Vector3(rng.randf_range(1.4, 4.5), rng.randf_range(2.0, 10.0), rng.randf_range(1.2, 4.0))
	return box


static func texture_tuning(spec: Dictionary) -> Dictionary:
	var texture_set := String(spec.get("texture_set", "industrial")).to_lower()
	match texture_set:
		"sand", "desert": return {"road_repeat": 0.04, "metallic": 0.22, "roughness": 0.78}
		"ice", "glacier": return {"road_repeat": 0.07, "metallic": 0.38, "roughness": 0.2}
		"jungle", "organic": return {"road_repeat": 0.045, "metallic": 0.28, "roughness": 0.7}
		"abyss", "wet": return {"road_repeat": 0.06, "metallic": 0.52, "roughness": 0.2}
		"volcanic", "lava": return {"road_repeat": 0.05, "metallic": 0.42, "roughness": 0.58}
		_: return {"road_repeat": 0.055, "metallic": 0.58, "roughness": 0.38}


static func _default_prop_set(track_id: String) -> String:
	match track_id:
		"dunes": return "desert"
		"glacier": return "ice"
		"orbital": return "orbital"
		"canopy": return "jungle"
		"tempest", "megacity": return "urban"
		"abyss": return "abyss"
		"caldera", "volcano", "reactor": return "volcanic"
		_: return "industrial"
