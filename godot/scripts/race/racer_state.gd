class_name RacerState
extends RefCounted
## Deterministic, rendering-agnostic racer simulation.
##
## The race controller owns the fixed timestep and feeds normalized controls:
## `throttle`, `brake`, `steer`, `drift`, `boost`. Context accepts `elapsed`,
## `race_active`, `grip`, `curvature`, `hazard`, and `speed_multiplier`.

const TrackSafetyType := preload("res://scripts/world/track_safety.gd")

const BASE_TOP_SPEED := 56.0
const BASE_ACCELERATION := 25.0
const BASE_ARMOR := 100.0
const MAX_LANE := 1.12
const RESET_STUCK_DELAY := 2.25
const RESET_COOLDOWN := 7.0
const QUADRUPED_RECOVERY_DURATION := 0.85
const MONOWHEEL_EXIT_THRUST_DURATION := 0.32
const BOOST_PAD_COOLING := 0.38
const BIPED_CONTROL_FACTOR := 0.60
const TRIPOD_CONTROL_FACTOR := 0.42

var racer_id := "racer"
var display_name := "RACER"
var chassis_id := "biped"
var locomotion_id := "biped__mecha_legs__balanced"
var drive_id := "mecha_legs"
var mount_id := "balanced"
var pilot_id := "vex"
var is_player := false
var difficulty_id := "pilot"
var seed := 1
var ai_trait := "adaptive"
var ai_aggression := 0.50
var ai_precision := 0.70
var ai_risk := 0.50

var track_length := 1000.0
var track_width := TrackSafetyType.MIN_ROAD_WIDTH
var total_laps := 3
var grid_index := 0
var vehicle_width := 3.5
var vehicle_length := 4.0
var lane_limit := MAX_LANE
var offroad_lane := 0.82
var distance := 0.0
var lane := 0.0
var lane_velocity := 0.0
var speed := 0.0
var top_speed := BASE_TOP_SPEED
var acceleration := BASE_ACCELERATION
var handling := 1.0
var mass := 1.0
var offroad_efficiency := 1.0
var armor_max := BASE_ARMOR
var armor := BASE_ARMOR
var heat := 0.0
var heat_generation := 1.0
var boost_energy := 0.55
var boosting := false
var item := ""
var position := 1
var lap := 1
var laps_completed := 0
var finish_time := 0.0
var finished := false
var dnf := false
var eliminated := false
var reason := ""

var _shield_time := 0.0
var _emp_time := 0.0
var _impact_velocity := 0.0
var _stuck_time := 0.0
var _reset_cooldown := 0.0
var _last_elapsed := 0.0
var _recovery_time := 0.0
var _was_drifting := false
var _drift_exit_thrust_time := 0.0
var _last_impact_thrust := 0.0
var _ai_steer_memory := 0.0


func configure(spec: Dictionary) -> RacerState:
	racer_id = String(spec.get("racer_id", "racer"))
	display_name = String(spec.get("display_name", racer_id)).to_upper()
	chassis_id = String(spec.get("chassis_id", "biped"))
	if not GameDatabase.has_chassis(chassis_id):
		chassis_id = "biped"
	pilot_id = String(spec.get("pilot_id", "vex"))
	is_player = bool(spec.get("is_player", false))
	difficulty_id = String(spec.get("difficulty", "pilot"))
	if not GameDatabase.has_difficulty(difficulty_id):
		difficulty_id = "pilot"
	var pilot := GameDatabase.get_pilot(pilot_id)
	ai_trait = String(spec.get("ai_trait", pilot.get("trait", "adaptive")))
	var difficulty := GameDatabase.get_difficulty(difficulty_id)
	var personality := _ai_personality(ai_trait)
	ai_aggression = clampf(float(difficulty.get("aggression", 0.50)) + float(personality.get("aggression", 0.0)), 0.08, 0.96)
	ai_precision = clampf(float(difficulty.get("skill", 0.69)) + float(personality.get("precision", 0.0)), 0.28, 0.98)
	ai_risk = clampf(0.34 + ai_aggression * 0.48 + float(personality.get("risk", 0.0)), 0.12, 0.94)
	seed = int(spec.get("seed", 1))
	track_length = maxf(100.0, float(spec.get("track_length", 1000.0)))
	track_width = maxf(TrackSafetyType.minimum_road_width(), float(spec.get("track_width", TrackSafetyType.MIN_ROAD_WIDTH)))
	total_laps = clampi(int(spec.get("total_laps", 3)), 1, 9)
	grid_index = maxi(0, int(spec.get("grid_index", 0)))

	var chassis := GameDatabase.get_chassis(chassis_id)
	var locomotion := LocomotionCatalog.resolve_configuration(chassis, {
		"locomotion_id": String(spec.get("locomotion_id", "")),
	})
	locomotion_id = String(locomotion.get("id", LocomotionCatalog.get_default_configuration_id(chassis_id)))
	drive_id = String(locomotion.get("drive_id", "mecha_legs"))
	mount_id = String(locomotion.get("mount_id", "balanced"))
	var footprint := TrackSafetyType.vehicle_footprint(chassis_id, locomotion)
	vehicle_width = footprint.x
	vehicle_length = footprint.y
	lane_limit = minf(MAX_LANE, TrackSafetyType.safe_lane_limit(track_width, vehicle_width))
	offroad_lane = minf(lane_limit - 0.04, TrackSafetyType.offroad_lane_threshold(track_width, vehicle_width))
	var physics: Dictionary = chassis.get("physics", {})
	var upgrades: Dictionary = spec.get("upgrades", {}) if spec.get("upgrades", {}) is Dictionary else {}
	var engine_level := clampi(int(upgrades.get("engine", 0)), 0, 4)
	var servo_level := clampi(int(upgrades.get("servos", 0)), 0, 4)
	var reactor_level := clampi(int(upgrades.get("reactor", 0)), 0, 4)
	var armor_level := clampi(int(upgrades.get("armor", 0)), 0, 4)
	var module_stats: Dictionary = spec.get("module_stats", {}) if spec.get("module_stats", {}) is Dictionary else {}
	var module_speed := clampf(float(module_stats.get("speed", 0.0)) / 100.0, -0.25, 0.25)
	var module_acceleration := clampf(float(module_stats.get("acceleration", 0.0)) / 100.0, -0.25, 0.25)
	var module_handling := clampf(float(module_stats.get("handling", 0.0)) / 100.0, -0.25, 0.25)
	var module_armor := clampf(float(module_stats.get("armor", 0.0)) / 100.0, -0.25, 0.25)
	var module_stability := clampf(float(module_stats.get("stability", 0.0)) / 100.0, -0.25, 0.25)
	var module_reactor := clampf(float(module_stats.get("reactor", 0.0)) / 100.0, -0.25, 0.25)

	top_speed = BASE_TOP_SPEED * float(physics.get("top_speed", 1.0)) * (1.0 + engine_level * 0.035) * (1.0 + module_speed)
	acceleration = BASE_ACCELERATION * float(physics.get("acceleration", 1.0)) * (1.0 + servo_level * 0.045) * (1.0 + module_acceleration)
	handling = float(physics.get("handling", 1.0)) * (1.0 + servo_level * 0.035) * (1.0 + module_handling)
	mass = maxf(0.45, float(physics.get("mass", 1.0)))
	offroad_efficiency = clampf(float(physics.get("offroad", 1.0)) * (1.0 + module_stability), 0.65, 1.60)
	heat_generation = maxf(0.55, float(physics.get("heat", 1.0))) / ((1.0 + reactor_level * 0.055) * (1.0 + module_reactor))
	armor_max = BASE_ARMOR * float(physics.get("armor", 1.0)) * (1.0 + armor_level * 0.060) * (1.0 + module_armor)
	armor = armor_max
	boost_energy = clampf(float(spec.get("boost_energy", 0.55 + reactor_level * 0.07)), 0.0, 1.0)

	distance = float(spec.get("distance", TrackSafetyType.grid_distance(grid_index)))
	lane = clampf(float(spec.get("lane", _grid_lane(grid_index))), -lane_limit, lane_limit)
	lane_velocity = 0.0
	speed = 0.0
	heat = 0.0
	position = grid_index + 1
	lap = 1
	laps_completed = 0
	finish_time = 0.0
	finished = false
	dnf = false
	eliminated = false
	reason = ""
	item = ""
	_shield_time = 0.0
	_emp_time = 0.0
	_impact_velocity = 0.0
	_stuck_time = 0.0
	_reset_cooldown = 0.0
	_last_elapsed = 0.0
	_recovery_time = 0.0
	_was_drifting = false
	_drift_exit_thrust_time = 0.0
	_last_impact_thrust = 0.0
	_ai_steer_memory = 0.0
	return self


func step(delta: float, controls: Dictionary, context: Dictionary) -> Dictionary:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return snapshot()
	_last_elapsed = maxf(_last_elapsed, float(context.get("elapsed", _last_elapsed + dt)))
	_shield_time = maxf(0.0, _shield_time - dt)
	_emp_time = maxf(0.0, _emp_time - dt)
	_reset_cooldown = maxf(0.0, _reset_cooldown - dt)
	_recovery_time = maxf(0.0, _recovery_time - dt)
	_drift_exit_thrust_time = maxf(0.0, _drift_exit_thrust_time - dt)
	_last_impact_thrust = move_toward(_last_impact_thrust, 0.0, dt * acceleration * 2.0)
	boosting = false

	if finished or dnf or eliminated:
		speed = move_toward(speed, 0.0, acceleration * 0.45 * dt)
		return snapshot()

	var race_active := bool(context.get("race_active", true))
	var throttle := clampf(float(controls.get("throttle", 0.0)), 0.0, 1.0) if race_active else 0.0
	var brake := clampf(float(controls.get("brake", 0.0)), 0.0, 1.0)
	var steer := clampf(float(controls.get("steer", 0.0)), -1.0, 1.0)
	var drifting := bool(controls.get("drift", false)) and speed > top_speed * 0.25
	var grip := clampf(float(context.get("grip", 1.0)), 0.35, 1.35)
	var hazard_value: Variant = context.get("hazard", "")
	var curvature := clampf(float(context.get("curvature", 0.0)), -1.0, 1.0)
	var speed_multiplier := clampf(float(context.get("speed_multiplier", 1.0)), 0.25, 1.75)
	var hazard_drag := _hazard_drag(hazard_value)
	if chassis_id == "centurion" and String(hazard_value) in ["debris", "gravity"]:
		grip = maxf(grip, 0.98)
	# Every authored circuit hazard changes the deterministic vehicle model.
	match String(hazard_value):
		"mud":
			grip *= 0.82
		"spores":
			grip *= 0.92
			heat = minf(1.0, heat + dt * 0.025)
		"rain":
			grip *= 0.78
		"crosswind":
			lane_velocity += sin(distance * 0.055 + seed * 0.13) * dt * 0.78
		"current":
			lane_velocity += sin(distance * 0.041 + seed * 0.17) * dt * 1.05
		"pressure":
			throttle *= 0.88
		"lava":
			heat = minf(1.0, heat + dt * 0.22)
			armor = maxf(0.0, armor - dt * 1.5)
		"eruption":
			heat = minf(1.0, heat + dt * 0.14)
			_impact_velocity += sin(distance * 0.09 + seed) * dt * 0.32
	if _emp_time > 0.0:
		grip *= 0.55
		throttle *= 0.72

	if drive_id == "mono_gyro":
		if _was_drifting and not drifting:
			_drift_exit_thrust_time = MONOWHEEL_EXIT_THRUST_DURATION
			speed = minf(top_speed * 1.06, speed + acceleration * 0.16)
		_was_drifting = drifting

	var steering_power := handling * grip * (1.25 if drifting else 0.92)
	var current_speed_ratio := speed / maxf(1.0, top_speed)
	if chassis_id == "hexapod" and current_speed_ratio < 0.45:
		steering_power *= 1.30
	var desired_lane_velocity := steer * steering_power * (1.2 + speed / maxf(1.0, top_speed))
	lane_velocity = move_toward(lane_velocity, desired_lane_velocity, (4.4 if drifting else 6.8) * dt)
	lane_velocity += _impact_velocity * dt
	_impact_velocity = move_toward(_impact_velocity, 0.0, 5.0 * dt)
	lane = clampf(lane + lane_velocity * dt, -lane_limit, lane_limit)

	var offroad_amount := clampf((absf(lane) - offroad_lane) / maxf(0.04, lane_limit - offroad_lane), 0.0, 1.0)
	if chassis_id == "quadruped" and brake > 0.45 and speed > top_speed * 0.15:
		_recovery_time = maxf(_recovery_time, QUADRUPED_RECOVERY_DURATION)
	var drive_force := acceleration * throttle
	drive_force *= 1.22 if chassis_id == "quadruped" and _recovery_time > 0.0 else 1.0
	var brake_force := acceleration * (1.5 + 0.25 / mass) * brake
	var aerodynamic_drag := (0.012 + 0.010 * hazard_drag) * speed * speed / maxf(1.0, top_speed)
	var rolling_drag := 1.2 + offroad_amount * (13.0 / offroad_efficiency) * offroad_drag_factor()
	var corner_drag := absf(curvature) * speed * (0.055 if drifting else 0.085) / maxf(0.65, handling)
	speed += (drive_force - brake_force - aerodynamic_drag - rolling_drag - corner_drag) * dt

	if bool(controls.get("boost", false)) and race_active and boost_energy > 0.015 and heat < 0.96:
		boosting = true
		boost_energy = maxf(0.0, boost_energy - dt * 0.22 * heat_generation)
		heat = minf(1.0, heat + dt * 0.19 * heat_generation)
		speed += acceleration * 1.38 * dt
	elif drifting and absf(steer) > 0.25:
		boost_energy = minf(1.0, boost_energy + dt * 0.028)
		heat = maxf(0.0, heat - dt * (0.145 if drive_id == "mono_gyro" else 0.075) / heat_generation)
	else:
		heat = maxf(0.0, heat - dt * (0.105 if throttle < 0.6 else 0.055) / heat_generation)

	if heat >= 0.985:
		speed = minf(speed, top_speed * 0.72)
	var ability_speed_factor := 1.06 if drive_id == "mono_gyro" and _drift_exit_thrust_time > 0.0 else 1.0
	var allowed_speed := top_speed * maxf(1.23 if boosting else 1.0, ability_speed_factor)
	speed = clampf(speed, 0.0, allowed_speed)
	distance += speed * speed_multiplier * dt
	_update_lap_and_finish()

	if speed < 1.0 and throttle > 0.55:
		_stuck_time += dt
	elif offroad_amount > 0.9:
		_stuck_time += dt * 0.65
	else:
		_stuck_time = maxf(0.0, _stuck_time - dt * 1.5)
	if armor <= 0.0:
		mark_dnf("destroyed")
	return snapshot()


func ai_controls(context: Dictionary) -> Dictionary:
	var skill := float(GameDatabase.get_difficulty(difficulty_id).get("skill", 0.69))
	var curvature := clampf(float(context.get("curvature", 0.0)), -1.0, 1.0)
	var curvature_ahead := clampf(float(context.get("curvature_ahead", curvature)), -1.0, 1.0)
	var curvature_far := clampf(float(context.get("curvature_far", curvature_ahead)), -1.0, 1.0)
	var personality := _ai_personality(ai_trait)
	var position_value := maxi(1, int(context.get("position", position)))
	var adaptive_push := clampf((position_value - 1) * 0.018, 0.0, 0.10) if ai_trait in ["adaptive", "opportunist"] else 0.0
	var anticipation := clampf(0.48 + ai_precision * 0.42 + float(personality.get("anticipation", 0.0)), 0.45, 0.96)
	var planned_curvature := lerpf(curvature, curvature_ahead, anticipation)
	planned_curvature = lerpf(planned_curvature, curvature_far, anticipation * 0.24)

	# Outside/inside/outside racing line: prepare on the opposite side of the
	# upcoming bend, then converge smoothly toward its apex.
	var entry_weight := clampf((absf(planned_curvature) - absf(curvature)) * 2.2 + 0.45, 0.16, 0.86)
	var target_lane := -planned_curvature * entry_weight * (0.64 + ai_precision * 0.20)
	target_lane += curvature * (1.0 - entry_weight) * 0.28
	var wave_amplitude := maxf(0.018, (0.17 - skill * 0.10) * float(personality.get("line_noise", 1.0)))
	target_lane += sin(distance * 0.0105 + seed * 0.731) * wave_amplitude

	var hazard_now := _hazard_drag(context.get("hazard", ""))
	var hazard_ahead := _hazard_drag(context.get("hazard_ahead", ""))
	var hazard_far := _hazard_drag(context.get("hazard_far", ""))
	var hazard_load := maxf(hazard_now, maxf(hazard_ahead * 0.88, hazard_far * 0.62))
	if hazard_ahead > 0.18 or hazard_far > 0.28:
		var escape_side := -1.0 if posmod(seed, 2) == 0 else 1.0
		target_lane += escape_side * minf(0.34, hazard_load * (0.30 + ai_precision * 0.18))

	var ai_lane_limit := maxf(0.46, lane_limit - 0.05)
	var traffic := _traffic_ahead(context)
	if bool(traffic.get("found", false)):
		var traffic_gap := float(traffic.get("gap", 999.0))
		var traffic_lane := float(traffic.get("lane", 0.0))
		var traffic_width := float(traffic.get("vehicle_width", vehicle_width))
		var lane_gap := traffic_lane - lane
		var required_pass_delta := ((vehicle_width + traffic_width) * 0.5 + TrackSafetyType.PASSING_GAP_METERS) / (track_width * TrackSafetyType.LANE_SCALE)
		if ai_trait == "rammer" and traffic_gap < 12.0 and ai_aggression > 0.62:
			target_lane = lerpf(target_lane, traffic_lane, 0.30)
		elif traffic_gap < 34.0 and absf(lane_gap) < required_pass_delta:
			target_lane = _passing_target_lane(traffic_lane, required_pass_delta, ai_lane_limit, position_value)

	target_lane = clampf(target_lane, -ai_lane_limit, ai_lane_limit)
	var raw_steer := clampf((target_lane - lane) * (1.70 + ai_precision * 1.20), -1.0, 1.0)
	_ai_steer_memory = move_toward(_ai_steer_memory, raw_steer, 0.085 + ai_precision * 0.11)
	var steer := clampf(_ai_steer_memory, -1.0, 1.0)
	var corner_load := maxf(absf(curvature), maxf(absf(curvature_ahead) * 0.92, absf(curvature_far) * 0.70))
	var conservative_factor := 0.12 if ai_trait == "defensive" else 0.0
	var target_speed_ratio := 1.04 + float(personality.get("pace", 0.0)) + adaptive_push
	target_speed_ratio -= corner_load * (0.55 - skill * 0.25 - ai_risk * 0.08)
	target_speed_ratio -= hazard_load * (0.22 + conservative_factor - ai_risk * 0.07)
	if bool(traffic.get("found", false)) and float(traffic.get("gap", 999.0)) < 10.0 and ai_trait != "rammer":
		target_speed_ratio -= 0.08
	target_speed_ratio = clampf(target_speed_ratio, 0.46, 1.075)
	var speed_ratio := speed / maxf(1.0, top_speed)
	var throttle := 1.0 if speed_ratio < target_speed_ratio else clampf(0.16 + ai_risk * 0.24, 0.16, 0.40)
	var brake := clampf((speed_ratio - target_speed_ratio) * (3.0 + ai_precision * 0.9), 0.0, 1.0)
	if hazard_load > 0.4:
		throttle *= 0.78 + skill * 0.15
	var drift_threshold := 0.50 + (1.0 - skill) * 0.12 - (0.10 if ai_trait == "drifter" else 0.0)
	var boost_heat_limit := 0.70 + ai_risk * 0.16
	return {
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"drift": corner_load > drift_threshold and speed_ratio > 0.42 and hazard_now < 0.48,
		"boost": corner_load < 0.18 and absf(curvature_ahead) < 0.22 and speed_ratio > 0.58 and boost_energy > (0.19 + (1.0 - ai_risk) * 0.13) and heat < boost_heat_limit,
	}


func _passing_target_lane(traffic_lane: float, required_delta: float, ai_lane_limit: float, position_value: int) -> float:
	var safe_limit := maxf(0.05, ai_lane_limit)
	var separation := maxf(0.02, required_delta)
	var left_target := clampf(traffic_lane - separation, -safe_limit, safe_limit)
	var right_target := clampf(traffic_lane + separation, -safe_limit, safe_limit)
	var pass_side := -1.0
	if lane > traffic_lane + 0.04:
		pass_side = 1.0
	elif absf(lane - traffic_lane) <= 0.04:
		pass_side = -1.0 if posmod(seed + position_value, 2) == 0 else 1.0
		var left_clearance := traffic_lane - left_target
		var right_clearance := right_target - traffic_lane
		if pass_side < 0.0 and left_clearance + 0.0001 < right_clearance:
			pass_side = 1.0
		elif pass_side > 0.0 and right_clearance + 0.0001 < left_clearance:
			pass_side = -1.0
	var explicit_target := left_target if pass_side < 0.0 else right_target
	# Once committed to a side, never steer back toward the obstacle merely
	# because the authored racing line is closer to the track centre.
	if pass_side < 0.0:
		explicit_target = minf(lane, explicit_target)
	else:
		explicit_target = maxf(lane, explicit_target)
	return clampf(explicit_target, -safe_limit, safe_limit)


func _traffic_ahead(context: Dictionary) -> Dictionary:
	var racers_value: Variant = context.get("racers", [])
	if not racers_value is Array:
		return {"found": false}
	var best_gap := INF
	var best_lane := 0.0
	var best_width := vehicle_width
	for value: Variant in racers_value:
		if not value is Dictionary:
			continue
		var state: Dictionary = value
		if String(state.get("racer_id", "")) == racer_id or bool(state.get("finished", false)) or bool(state.get("dnf", false)) or bool(state.get("eliminated", false)):
			continue
		var gap := float(state.get("distance", 0.0)) - distance
		if gap > 0.0 and gap < best_gap and gap <= 42.0:
			best_gap = gap
			best_lane = float(state.get("lane", 0.0))
			best_width = maxf(1.0, float(state.get("vehicle_width", vehicle_width)))
	return {"found": best_gap < INF, "gap": best_gap, "lane": best_lane, "vehicle_width": best_width}


func _ai_personality(trait_id: String) -> Dictionary:
	match trait_id:
		"aggressive": return {"aggression": 0.18, "risk": 0.12, "precision": -0.03, "pace": 0.012, "line_noise": 1.15}
		"technical": return {"aggression": -0.03, "risk": -0.02, "precision": 0.09, "anticipation": 0.10, "line_noise": 0.55}
		"defensive": return {"aggression": -0.18, "risk": -0.14, "precision": 0.04, "anticipation": 0.08, "pace": -0.012, "line_noise": 0.65}
		"opportunist": return {"aggression": 0.07, "risk": 0.05, "precision": 0.03, "anticipation": 0.04, "line_noise": 0.80}
		"clean_line": return {"aggression": -0.05, "risk": -0.04, "precision": 0.11, "anticipation": 0.09, "line_noise": 0.28}
		"rammer": return {"aggression": 0.24, "risk": 0.15, "precision": -0.06, "pace": 0.008, "line_noise": 1.20}
		"strategist": return {"aggression": -0.01, "risk": 0.00, "precision": 0.08, "anticipation": 0.14, "line_noise": 0.48}
		"drifter": return {"aggression": 0.08, "risk": 0.10, "precision": 0.01, "pace": 0.010, "line_noise": 0.82}
		_: return {"aggression": 0.0, "risk": 0.0, "precision": 0.02, "anticipation": 0.05, "line_noise": 0.72}


func apply_hit(damage: float, lateral_impulse: float = 0.0) -> void:
	if finished or dnf or eliminated:
		return
	var shield_factor := 0.15 if _shield_time > 0.0 else 1.0
	var applied_damage := maxf(0.0, damage)
	var control_factor := 1.0
	var momentum_loss_factor := 1.0
	match chassis_id:
		"biped":
			control_factor = BIPED_CONTROL_FACTOR
		"tripod":
			control_factor = TRIPOD_CONTROL_FACTOR
			applied_damage *= 0.88
		"octopod":
			control_factor = 0.72
			momentum_loss_factor = 0.45
		"orb":
			control_factor = 0.36
	armor = maxf(0.0, armor - applied_damage * shield_factor)
	_impact_velocity += lateral_impulse / maxf(0.5, mass) * shield_factor * control_factor
	speed *= clampf(1.0 - applied_damage * 0.003 / mass * momentum_loss_factor, 0.68, 1.0)
	if chassis_id == "quadruped":
		_recovery_time = maxf(_recovery_time, QUADRUPED_RECOVERY_DURATION)
	elif chassis_id == "orb" and not is_zero_approx(lateral_impulse):
		_last_impact_thrust = absf(lateral_impulse) * acceleration * 0.42 * shield_factor
		speed = minf(top_speed * 1.08, speed + _last_impact_thrust)
	_stuck_time = 0.0


func apply_emp(duration: float = 1.8) -> void:
	if _shield_time <= 0.0:
		_emp_time = maxf(_emp_time, maxf(0.0, duration))


## Boost pads recharge the reactor directly and never touch the held item slot.
func apply_boost_pad() -> bool:
	if finished or dnf or eliminated:
		return false
	boost_energy = 1.0
	heat = maxf(0.0, heat - BOOST_PAD_COOLING)
	return true


func apply_ground_mine(damage: float = 18.0, lateral_impulse: float = 0.48) -> bool:
	if drive_id in ["hover_skids", "twin_antigrav"] or finished or dnf or eliminated:
		return false
	apply_hit(damage, lateral_impulse)
	return true


func contact_damage_multiplier() -> float:
	var multiplier := 1.65 if chassis_id == "octopod" else 1.0
	match drive_id:
		"treads": multiplier = maxf(multiplier, 1.38)
		"multi_support": multiplier = maxf(multiplier, 1.08)
		"articulated_rail": multiplier = maxf(multiplier, 1.12)
	return multiplier


func offroad_drag_factor() -> float:
	match drive_id:
		"twin_antigrav": return 0.12
		"hover_skids": return 0.16
		"multi_support": return 0.38
		"treads": return 0.44
		"ducted_fans": return 0.68
		"sphere_drive": return 0.72
		"mecha_legs": return 0.82
		"mono_gyro": return 0.92
		"articulated_rail": return 1.05
		"wheels": return 1.10
		_: return 1.0


func chassis_ability_id() -> String:
	match chassis_id:
		"biped": return "gyro_correction"
		"tripod": return "vector_anchor"
		"quadruped": return "predator_stride"
		"hexapod": return "adaptive_steps"
		"octopod": return "distributed_ram"
		"hover": return "magnetic_cushion"
		"tracked": return "heavy_transmission"
		"monowheel": return "gyro_drift"
		"orb": return "inertial_rebound"
		"centurion": return "walking_wave"
		_: return "standard"


func chassis_ability_snapshot() -> Dictionary:
	var ability := {"id": chassis_ability_id(), "active": false}
	match chassis_id:
		"biped":
			ability.merge({"control_loss_factor": BIPED_CONTROL_FACTOR, "control_disruption": absf(_impact_velocity)}, true)
		"tripod":
			ability.merge({"control_loss_factor": TRIPOD_CONTROL_FACTOR, "control_disruption": absf(_impact_velocity)}, true)
		"quadruped":
			ability.merge({"active": _recovery_time > 0.0, "recovery_time": _recovery_time, "drive_factor": 1.22}, true)
		"hexapod":
			ability.merge({"low_speed_steering_factor": 1.30}, true)
		"octopod":
			ability.merge({"contact_damage_factor": contact_damage_multiplier(), "momentum_loss_factor": 0.45}, true)
		"hover":
			ability.merge({"stabilized_frame": true}, true)
		"tracked":
			ability.merge({"armored_bed": true}, true)
		"monowheel":
			ability.merge({"gyro_frame": true}, true)
		"orb":
			ability.merge({"active": _last_impact_thrust > 0.0, "impact_thrust": _last_impact_thrust, "control_loss_factor": 0.36}, true)
		"centurion":
			ability.merge({"debris_drag": _hazard_drag("debris"), "gravity_drag": _hazard_drag("gravity")}, true)
	return ability


func locomotion_ability_snapshot() -> Dictionary:
	var mine_immune := drive_id in ["hover_skids", "twin_antigrav"]
	return {
		"id": "drive_%s" % drive_id,
		"drive_id": drive_id,
		"locomotion_id": locomotion_id,
		"mount_id": mount_id,
		"mine_immune": mine_immune,
		"offroad_drag_factor": offroad_drag_factor(),
		"contact_damage_factor": contact_damage_multiplier(),
		"sand_drag": _hazard_drag("sand"),
		"mud_drag": _hazard_drag("mud"),
		"debris_drag": _hazard_drag("debris"),
		"active": drive_id == "mono_gyro" and _drift_exit_thrust_time > 0.0,
		"exit_thrust_time": _drift_exit_thrust_time if drive_id == "mono_gyro" else 0.0,
		"drift_cooling": 0.145 if drive_id == "mono_gyro" else 0.075,
	}


func ability_profile_snapshot() -> Dictionary:
	var chassis_ability := chassis_ability_snapshot()
	var drive_ability := locomotion_ability_snapshot()
	var profile := chassis_ability.duplicate(true)
	profile["chassis"] = chassis_ability
	profile["locomotion"] = drive_ability
	profile["drive_id"] = drive_id
	profile["locomotion_id"] = locomotion_id
	profile["mine_immune"] = bool(drive_ability.get("mine_immune", false))
	profile["offroad_drag_factor"] = offroad_drag_factor()
	profile["contact_damage_factor"] = contact_damage_multiplier()
	profile["active"] = bool(chassis_ability.get("active", false)) or bool(drive_ability.get("active", false))
	return profile


func grant_item(item_id: String) -> bool:
	if not item.is_empty() or GameDatabase.get_item(item_id).is_empty():
		return false
	item = item_id
	return true


func use_item() -> String:
	var used_item := item
	item = ""
	match used_item:
		"shield":
			_shield_time = maxf(_shield_time, 4.0)
		"repair":
			armor = minf(armor_max, armor + armor_max * 0.34)
		"overdrive":
			boost_energy = 1.0
			heat = maxf(0.0, heat - 0.38)
	return used_item


func can_reset() -> bool:
	return not finished and not dnf and not eliminated and _reset_cooldown <= 0.0 and (_stuck_time >= RESET_STUCK_DELAY or absf(lane) >= lane_limit - 0.03)


func reset_to_checkpoint(checkpoint_distance: float, checkpoint_lane: float = 0.0) -> bool:
	if not can_reset():
		return false
	distance = clampf(checkpoint_distance, 0.0, track_length * total_laps)
	lane = clampf(checkpoint_lane, -0.7, 0.7)
	lane_velocity = 0.0
	speed = minf(speed, top_speed * 0.22)
	heat = minf(heat, 0.55)
	_stuck_time = 0.0
	_reset_cooldown = RESET_COOLDOWN
	if chassis_id == "quadruped":
		_recovery_time = maxf(_recovery_time, QUADRUPED_RECOVERY_DURATION)
	return true


func eliminate(elimination_reason: String = "eliminated") -> void:
	if finished or dnf:
		return
	eliminated = true
	dnf = true
	reason = elimination_reason
	boosting = false


func mark_dnf(dnf_reason: String = "timeout") -> void:
	if finished:
		return
	dnf = true
	reason = dnf_reason
	boosting = false


func set_position(value: int) -> void:
	position = maxi(1, value)


func race_distance() -> float:
	return maxf(0.0, distance)


func normalized_progress() -> float:
	return clampf(maxf(0.0, distance) / (track_length * total_laps), 0.0, 1.0)


func snapshot() -> Dictionary:
	return {
		"racer_id": racer_id,
		"display_name": display_name,
		"chassis_id": chassis_id,
		"locomotion_id": locomotion_id,
		"drive_id": drive_id,
		"mount_id": mount_id,
		"division_id": String(GameDatabase.get_chassis(chassis_id).get("division_id", "command")),
		"pilot_id": pilot_id,
		"ai_trait": ai_trait,
		"ai_aggression": ai_aggression,
		"ai_precision": ai_precision,
		"is_player": is_player,
		"distance": distance,
		"lane": lane,
		"track_width": track_width,
		"vehicle_width": vehicle_width,
		"vehicle_length": vehicle_length,
		"lane_limit": lane_limit,
		"speed": speed,
		"speed_ratio": clampf(speed / maxf(1.0, top_speed), 0.0, 1.23),
		"lap": lap,
		"laps_completed": laps_completed,
		"total_laps": total_laps,
		"position": position,
		"armor": armor,
		"max_armor": armor_max,
		"armor_ratio": clampf(armor / maxf(1.0, armor_max), 0.0, 1.0),
		"heat": heat,
		"heat_ratio": heat,
		"boost_energy": boost_energy,
		"item": item,
		"boosting": boosting,
		"shielded": _shield_time > 0.0,
		"ability": ability_profile_snapshot(),
		"finished": finished,
		"finish_time": finish_time,
		"dnf": dnf,
		"eliminated": eliminated,
		"reason": reason,
		"can_reset": can_reset(),
	}


func _update_lap_and_finish() -> void:
	var total_distance := track_length * total_laps
	laps_completed = clampi(floori(maxf(0.0, distance) / track_length), 0, total_laps)
	lap = clampi(laps_completed + 1, 1, total_laps)
	if distance >= total_distance:
		distance = total_distance
		laps_completed = total_laps
		lap = total_laps
		finished = true
		finish_time = _last_elapsed
		reason = "finished"
		boosting = false


func _hazard_drag(hazard: Variant) -> float:
	if hazard is int or hazard is float:
		return clampf(float(hazard), 0.0, 1.0)
	if hazard is Dictionary:
		var hazard_data: Dictionary = hazard
		return clampf(float(hazard_data.get("drag", hazard_data.get("strength", 0.0))), 0.0, 1.0)
	var hazard_id := String(hazard)
	if drive_id == "treads" and hazard_id in ["sand", "debris", "mud"]:
		return 0.10 if hazard_id == "mud" else 0.0
	if drive_id == "hover_skids" and hazard_id in ["sand", "mud"]:
		return 0.03 if hazard_id == "sand" else 0.06
	if drive_id == "twin_antigrav" and hazard_id in ["sand", "mud", "debris"]:
		match hazard_id:
			"sand": return 0.02
			"mud": return 0.04
			_: return 0.08
	if drive_id == "multi_support" and hazard_id in ["sand", "mud", "debris"]:
		match hazard_id:
			"sand": return 0.34 / offroad_efficiency
			"mud": return 0.28 / offroad_efficiency
			_: return 0.16
	if drive_id == "ducted_fans" and hazard_id in ["rain", "current", "pressure"]:
		match hazard_id:
			"rain": return 0.08
			"current": return 0.10
			_: return 0.12
	if chassis_id == "centurion" and hazard_id in ["debris", "gravity", "crosswind"]:
		match hazard_id:
			"debris": return 0.06
			"gravity": return 0.09
			_: return 0.11
	match hazard_id:
		"sand": return 0.60 / offroad_efficiency
		"ice": return 0.28
		"gravity": return 0.36
		"debris": return 0.24
		"vent": return 0.20
		"mud": return 0.52 / offroad_efficiency
		"spores": return 0.16
		"rain": return 0.18
		"crosswind": return 0.27
		"current": return 0.34
		"pressure": return 0.23
		"lava": return 0.48
		"eruption": return 0.40
		_: return 0.0


func _grid_lane(index: int) -> float:
	return TrackSafetyType.grid_lane(index)
