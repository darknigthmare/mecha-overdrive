class_name TrackSafety
extends RefCounted

## Single source of truth for physical racing-space homologation. Lane values
## remain normalized for the simulation, while every safety decision is made in
## metres so a wide Aether pod is never treated like a compact biped.

const LANE_SCALE := 0.42
const REQUIRED_SIDE_BY_SIDE := 3
const PASSING_GAP_METERS := 1.50
const OUTER_CLEARANCE_METERS := 1.50
const ROAD_EDGE_CLEARANCE_METERS := 0.65
const MAX_HOMOLOGATED_WIDTH := 9.50
const MAX_HOMOLOGATED_LENGTH := 8.50
const MIN_ROAD_WIDTH := 35.0
const GRID_LANE_OFFSET := 0.38
const GRID_ROW_SPACING := 10.5

const FAMILY_HALF_EXTENTS := {
	"biped": Vector2(1.45, 1.35),
	"tripod": Vector2(1.70, 1.55),
	"quadruped": Vector2(1.75, 1.75),
	"hexapod": Vector2(2.15, 1.75),
	"octopod": Vector2(2.45, 2.00),
	"hover": Vector2(2.00, 2.15),
	"tracked": Vector2(1.95, 2.15),
	"monowheel": Vector2(1.35, 1.45),
	"orb": Vector2(1.80, 1.60),
	"centurion": Vector2(1.75, 2.80),
}


static func minimum_road_width() -> float:
	var occupied := MAX_HOMOLOGATED_WIDTH * REQUIRED_SIDE_BY_SIDE
	occupied += PASSING_GAP_METERS * (REQUIRED_SIDE_BY_SIDE - 1)
	occupied += OUTER_CLEARANCE_METERS * 2.0
	return maxf(MIN_ROAD_WIDTH, ceilf(occupied))


static func passing_columns(track_width: float) -> int:
	var usable := maxf(0.0, track_width - OUTER_CLEARANCE_METERS * 2.0)
	return maxi(0, floori((usable + PASSING_GAP_METERS) / (MAX_HOMOLOGATED_WIDTH + PASSING_GAP_METERS)))


static func vehicle_footprint(chassis_id: String, configuration: Dictionary) -> Vector2:
	var family_id := chassis_id if FAMILY_HALF_EXTENTS.has(chassis_id) else "biped"
	var base: Vector2 = FAMILY_HALF_EXTENTS[family_id]
	var visual: Dictionary = configuration.get("visual", {}) if configuration.get("visual", {}) is Dictionary else {}
	var mount_width := clampf(float(visual.get("width", 1.0)), 0.70, 1.35)
	var mount_length := clampf(float(visual.get("length", 1.0)), 0.75, 1.30)
	var mount_height := clampf(float(visual.get("height", 1.0)), 0.75, 1.20)
	var drive_id := String(configuration.get("drive_id", visual.get("drive_id", "mecha_legs")))
	var half_width := base.x * mount_width
	var half_length := base.y * mount_length

	match drive_id:
		"twin_antigrav":
			half_width = half_width * 1.22 + 0.48 * mount_width
			half_length += 0.46 * mount_length
		"wheels", "sphere_drive", "ducted_fans":
			half_width += 0.76 * mount_height
			half_length += 0.32 * mount_length
		"treads":
			half_width += 0.42 * mount_width
			half_length *= 1.08
		"hover_skids", "articulated_rail":
			half_width += 0.30 * mount_width
			half_length *= 1.05
		"multi_support", "mecha_legs":
			half_width += 0.30 * mount_width
			half_length += 0.24 * mount_length
		"mono_gyro":
			half_width = maxf(half_width, 1.45 * mount_height)
			half_length += 0.30 * mount_length

	# Bodywork, articulated contacts and animated suspension need a stable
	# envelope beyond the raw locomotion anchors.
	half_width += 0.30
	half_length += 0.30
	return Vector2(
		clampf(half_width * 2.0, 2.20, MAX_HOMOLOGATED_WIDTH),
		clampf(half_length * 2.0, 2.60, MAX_HOMOLOGATED_LENGTH)
	)


static func safe_lane_limit(track_width: float, vehicle_width: float) -> float:
	var width := maxf(minimum_road_width(), track_width)
	var half_clear := width * 0.5 - maxf(1.0, vehicle_width) * 0.5 - ROAD_EDGE_CLEARANCE_METERS
	return clampf(half_clear / (width * LANE_SCALE), 0.62, 1.12)


static func offroad_lane_threshold(track_width: float, vehicle_width: float) -> float:
	return maxf(0.48, safe_lane_limit(track_width, vehicle_width) - 0.16)


static func grid_lane(index: int) -> float:
	return -GRID_LANE_OFFSET if posmod(maxi(0, index), 2) == 0 else GRID_LANE_OFFSET


static func grid_distance(index: int) -> float:
	return -float(maxi(0, index) / 2) * GRID_ROW_SPACING


static func lateral_gap_meters(first_lane: float, second_lane: float, track_width: float) -> float:
	return absf(first_lane - second_lane) * maxf(minimum_road_width(), track_width) * LANE_SCALE


static func track_report(spec: Dictionary) -> Dictionary:
	var width := float(spec.get("width", 0.0))
	return {
		"track_id": String(spec.get("id", "unknown")),
		"width": width,
		"minimum_width": minimum_road_width(),
		"passing_columns": passing_columns(width),
		"homologated": width >= minimum_road_width() and passing_columns(width) >= REQUIRED_SIDE_BY_SIDE,
	}
