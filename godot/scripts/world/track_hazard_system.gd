class_name TrackHazardSystem
extends RefCounted

## Deterministic lane-aware hazard authoring shared by gameplay, AI and track
## visuals. Every danger owns a longitudinal 3D zone and a real lateral lane
## window; racers outside that window are not penalized.

const SECTION_COUNT := 12
const HAZARD_SECTIONS: Array[int] = [2, 6, 10]
const LANE_PATTERN: Array[float] = [-0.58, 0.58, 0.0]
const DEFAULT_HALF_WIDTH := 0.28


static func zones(spec: Dictionary, track_length: float) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var hazards: Array = spec.get("hazards", [])
	if hazards.is_empty():
		return output
	var length := maxf(1.0, track_length)
	var seed := int(spec.get("seed", 1))
	for sector in range(HAZARD_SECTIONS.size()):
		var section := HAZARD_SECTIONS[sector]
		var hazard_id := String(hazards[sector % hazards.size()])
		var start_distance := length * float(section) / float(SECTION_COUNT)
		var end_distance := length * float(section + 1) / float(SECTION_COUNT)
		var lane_index := posmod(seed + sector * 5 + hazard_id.hash(), LANE_PATTERN.size())
		var lane_center := LANE_PATTERN[lane_index]
		var half_width := _half_width(hazard_id)
		output.append({
			"id": "hazard_%02d_%s" % [sector, hazard_id],
			"hazard_id": hazard_id,
			"sector": sector,
			"start_distance": start_distance,
			"end_distance": end_distance,
			"center_distance": (start_distance + end_distance) * 0.5,
			"length": end_distance - start_distance,
			"lane_center": lane_center,
			"lane_half_width": half_width,
			"color": hazard_color(hazard_id),
		})
	return output


static func sample(spec: Dictionary, track_length: float, distance: float, lane: float) -> Dictionary:
	var length := maxf(1.0, track_length)
	var lap_distance := fposmod(distance, length)
	for zone: Dictionary in zones(spec, length):
		var start_distance := float(zone.get("start_distance", 0.0))
		var end_distance := float(zone.get("end_distance", 0.0))
		if lap_distance < start_distance or lap_distance >= end_distance:
			continue
		var zone_length := maxf(0.001, end_distance - start_distance)
		var local_progress := clampf((lap_distance - start_distance) / zone_length, 0.0, 1.0)
		var edge_fade := smoothstep(0.0, 0.16, local_progress) * smoothstep(0.0, 0.16, 1.0 - local_progress)
		var lane_center := float(zone.get("lane_center", 0.0))
		var lane_half_width := float(zone.get("lane_half_width", DEFAULT_HALF_WIDTH))
		var lane_delta := absf(lane - lane_center)
		var lane_fade := 1.0 - smoothstep(lane_half_width * 0.72, lane_half_width, lane_delta)
		var active := lane_delta <= lane_half_width and edge_fade > 0.01
		var result := zone.duplicate(true)
		result["lap_distance"] = lap_distance
		result["local_progress"] = local_progress
		result["lane_delta"] = lane_delta
		result["intensity"] = clampf(edge_fade * lane_fade, 0.0, 1.0) if active else 0.0
		result["active"] = active
		result["active_hazard"] = String(zone.get("hazard_id", "")) if active else ""
		return result
	return {
		"id": "",
		"hazard_id": "",
		"active_hazard": "",
		"active": false,
		"intensity": 0.0,
		"lane_center": 0.0,
		"lane_half_width": 0.0,
		"lap_distance": lap_distance,
	}


static func avoidance_target(sample_data: Dictionary, current_lane: float, lane_limit: float, seed: int) -> float:
	if String(sample_data.get("hazard_id", "")).is_empty():
		return clampf(current_lane, -lane_limit, lane_limit)
	var center := float(sample_data.get("lane_center", 0.0))
	var half_width := float(sample_data.get("lane_half_width", DEFAULT_HALF_WIDTH))
	var side := signf(current_lane - center)
	if is_zero_approx(side):
		side = -1.0 if posmod(seed, 2) == 0 else 1.0
	var clearance := half_width + 0.16
	var candidate := center + side * clearance
	if absf(candidate) > lane_limit:
		candidate = center - side * clearance
	return clampf(candidate, -lane_limit, lane_limit)


static func hazard_color(hazard_id: String) -> Color:
	match hazard_id:
		"vent", "crosswind", "current":
			return Color("53d8ff")
		"debris", "sand", "mud":
			return Color("ffb15b")
		"ice", "rain", "pressure":
			return Color("8be8ff")
		"gravity", "spores":
			return Color("c66cff")
		"lava", "eruption":
			return Color("ff4a2f")
		_:
			return Color("ffd45b")


static func _half_width(hazard_id: String) -> float:
	match hazard_id:
		"debris", "lava", "mud", "ice":
			return 0.24
		"vent", "crosswind", "current", "eruption":
			return 0.31
		"rain", "pressure", "sand", "spores", "gravity":
			return 0.35
		_:
			return DEFAULT_HALF_WIDTH
