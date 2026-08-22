class_name RacerState
extends RefCounted
## Deterministic, rendering-agnostic racer simulation.
##
## The race controller owns the fixed timestep and feeds normalized controls:
## `throttle`, `brake`, `steer`, `drift`, `boost`. Context accepts `elapsed`,
## `race_active`, `grip`, `curvature`, `hazard`, and `speed_multiplier`.

const BASE_TOP_SPEED := 56.0
const BASE_ACCELERATION := 25.0
const BASE_ARMOR := 100.0
const MAX_LANE := 1.75
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
var pilot_id := "vex"
var is_player := false
var difficulty_id := "pilot"
var seed := 1

var track_length := 1000.0
var total_laps := 3
var grid_index := 0
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
	seed = int(spec.get("seed", 1))
	track_length = maxf(100.0, float(spec.get("track_length", 1000.0)))
	total_laps = clampi(int(spec.get("total_laps", 3)), 1, 9)
	grid_index = maxi(0, int(spec.get("grid_index", 0)))

	var chassis := GameDatabase.get_chassis(chassis_id)
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

	distance = maxf(0.0, float(spec.get("distance", 0.0)))
	lane = clampf(float(spec.get("lane", _grid_lane(grid_index))), -1.0, 1.0)
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

	if chassis_id == "monowheel":
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
	lane = clampf(lane + lane_velocity * dt, -MAX_LANE, MAX_LANE)

	var offroad_amount := clampf((absf(lane) - 0.92) / (MAX_LANE - 0.92), 0.0, 1.0)
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
		heat = maxf(0.0, heat - dt * (0.145 if chassis_id == "monowheel" else 0.075) / heat_generation)
	else:
		heat = maxf(0.0, heat - dt * (0.105 if throttle < 0.6 else 0.055) / heat_generation)

	if heat >= 0.985:
		speed = minf(speed, top_speed * 0.72)
	var ability_speed_factor := 1.06 if chassis_id == "monowheel" and _drift_exit_thrust_time > 0.0 else 1.0
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
	var wave := sin(distance * 0.0105 + seed * 0.731) * (0.20 - skill * 0.11)
	var target_lane := clampf(-curvature * (0.62 + skill * 0.22) + wave, -0.82, 0.82)
	var steer := clampf((target_lane - lane) * (1.8 + skill * 1.1), -1.0, 1.0)
	var corner_load := absf(curvature)
	var target_speed_ratio := clampf(1.04 - corner_load * (0.50 - skill * 0.24), 0.50, 1.04)
	var speed_ratio := speed / maxf(1.0, top_speed)
	var throttle := 1.0 if speed_ratio < target_speed_ratio else 0.25
	var brake := clampf((speed_ratio - target_speed_ratio) * 2.8, 0.0, 1.0)
	var hazard := _hazard_drag(context.get("hazard", ""))
	if hazard > 0.4:
		throttle *= 0.82 + skill * 0.14
	return {
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"drift": corner_load > (0.54 + (1.0 - skill) * 0.10) and speed_ratio > 0.45,
		"boost": corner_load < 0.16 and speed_ratio > 0.64 and boost_energy > 0.24 and heat < 0.76,
	}


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
	if chassis_id == "hover" or finished or dnf or eliminated:
		return false
	apply_hit(damage, lateral_impulse)
	return true


func contact_damage_multiplier() -> float:
	match chassis_id:
		"octopod": return 1.65
		"tracked": return 1.38
		_: return 1.0


func offroad_drag_factor() -> float:
	match chassis_id:
		"hexapod": return 0.38
		"hover": return 0.16
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
			ability.merge({"low_speed_steering_factor": 1.30, "offroad_drag_factor": offroad_drag_factor()}, true)
		"octopod":
			ability.merge({"contact_damage_factor": contact_damage_multiplier(), "momentum_loss_factor": 0.45}, true)
		"hover":
			ability.merge({"mine_immune": true, "offroad_drag_factor": offroad_drag_factor()}, true)
		"tracked":
			ability.merge({"contact_damage_factor": contact_damage_multiplier(), "sand_debris_drag": 0.0}, true)
		"monowheel":
			ability.merge({"active": _drift_exit_thrust_time > 0.0, "exit_thrust_time": _drift_exit_thrust_time, "drift_cooling": 0.145}, true)
		"orb":
			ability.merge({"active": _last_impact_thrust > 0.0, "impact_thrust": _last_impact_thrust, "control_loss_factor": 0.36}, true)
		"centurion":
			ability.merge({"debris_drag": _hazard_drag("debris"), "gravity_drag": _hazard_drag("gravity")}, true)
	return ability


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
	return not finished and not dnf and not eliminated and _reset_cooldown <= 0.0 and (_stuck_time >= RESET_STUCK_DELAY or absf(lane) >= MAX_LANE - 0.03)


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
		"division_id": String(GameDatabase.get_chassis(chassis_id).get("division_id", "command")),
		"pilot_id": pilot_id,
		"is_player": is_player,
		"distance": maxf(0.0, distance),
		"lane": lane,
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
		"ability": chassis_ability_snapshot(),
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
	if chassis_id == "tracked" and hazard_id in ["sand", "debris", "mud"]:
		return 0.10 if hazard_id == "mud" else 0.0
	if chassis_id == "hover" and hazard_id in ["sand", "mud"]:
		return 0.03 if hazard_id == "sand" else 0.06
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
	if index == 0:
		return 0.0
	var row := ceili(index / 2.0)
	return (-0.34 if index % 2 == 1 else 0.34) * minf(1.0, 0.70 + row * 0.08)
