class_name RaceController
extends Node3D

## Complete arcade race loop for the reconstructed Godot branch.
## The simulation runs at a fixed step, while procedural visuals interpolate at
## display rate. This keeps pickups, AI and finishing rules frame independent.

signal race_finished(result: Dictionary)
signal menu_requested
signal retry_requested(config: Dictionary)

const TrackFactoryType := preload("res://scripts/world/track_factory.gd")
const TrackSafetyType := preload("res://scripts/world/track_safety.gd")
const MechaFactoryType := preload("res://scripts/mecha/mecha_factory.gd")
const RacerStateType := preload("res://scripts/race/racer_state.gd")
const AudioDirectorType := preload("res://scripts/audio/audio_director.gd")
const RaceHUDType := preload("res://scripts/ui/race_hud.gd")

const FIXED_STEP := 1.0 / 120.0
const GRID_SIZE := 8
const MAX_RACE_SECONDS := 480.0
const ELIMINATION_START := 42.0
const ELIMINATION_INTERVAL := 34.0
const AI_ITEM_PICKUP_DELAY := 0.45
const AI_ITEM_REEVALUATE_INTERVAL := 0.30
const AI_ITEM_REUSE_DELAY := 1.25
const STRAIGHT_CURVATURE_LIMIT := 0.15
const GRID_BRIEFING_SECONDS := 2.45
const COUNTDOWN_SECONDS := 3.0
const FALSE_START_PENALTY_SECONDS := 0.85
const FINISH_BROADCAST_SECONDS := 1.65

var _config: Dictionary = {}
var _track: Node3D
var _track_length := 1.0
var _track_width := TrackSafetyType.MIN_ROAD_WIDTH
var _racers: Array[RefCounted] = []
var _visuals: Dictionary[String, RacerVisual] = {}
var _snapshots: Array[Dictionary] = []
var _player: RefCounted
var _camera: Camera3D
var _camera_mode := "tps"
var _reduced_motion := false
var _hud: RaceHUD
var _audio: AudioDirector
var _accumulator := 0.0
var _elapsed := 0.0
var _briefing_remaining := GRID_BRIEFING_SECONDS
var _countdown := COUNTDOWN_SECONDS
var _last_countdown_number := 3
var _running := false
var _finished := false
var _finish_cinematic := false
var _cinematic_elapsed := 0.0
var _paused := false
var _false_start := false
var _false_start_latched := false
var _start_penalty_remaining := 0.0
var _item_was_pressed := false
var _mobile_item_pending := false
var _mobile_control_strengths: Dictionary[StringName, float] = {}
var _next_elimination := ELIMINATION_START
var _marker_cooldowns: Dictionary[String, float] = {}
var _ai_item_cooldowns: Dictionary[String, float] = {}
var _finish_order: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_unhandled_input(true)


func start(request: Dictionary) -> void:
	_config = request.duplicate(true)
	var profile := _profile()
	var settings: Dictionary = profile.get("settings", {}) if profile.get("settings", {}) is Dictionary else {}
	_reduced_motion = bool(settings.get("reduced_motion", false))
	_briefing_remaining = GRID_BRIEFING_SECONDS
	_countdown = COUNTDOWN_SECONDS
	_last_countdown_number = 3
	_false_start = false
	_false_start_latched = false
	_start_penalty_remaining = 0.0
	_finish_cinematic = false
	_cinematic_elapsed = 0.0
	_camera_mode = String(_config.get("camera_view", "tps"))
	if _camera_mode not in ["tps", "fps"]:
		_camera_mode = "tps"
	_build_track()
	_build_racers()
	_build_camera()
	_build_feedback()
	_update_racer_visuals(0.0)
	_set_camera_mode(_camera_mode, false)
	if _hud != null and _hud.has_method(&"configure"):
		_hud.call(&"configure", _config)
	if _hud != null and _hud.has_method(&"show_race_briefing"):
		_hud.call(&"show_race_briefing", _config, _grid_preview())


func _process(delta: float) -> void:
	if _track == null:
		return
	if _finish_cinematic:
		_cinematic_elapsed += delta
		_update_finish_camera(delta)
		return
	if _finished:
		return
	if _paused:
		_update_camera(delta)
		return

	if _briefing_remaining > 0.0:
		_briefing_remaining -= delta
		if _briefing_remaining <= 0.0:
			if _hud != null and _hud.has_method(&"hide_race_briefing"):
				_hud.call(&"hide_race_briefing")
			if _hud != null and _hud.has_method(&"show_countdown"):
				_hud.call(&"show_countdown", 3)
			_audio.play_event("count")
		_update_grid_camera(delta)
		return

	if _countdown > 0.0:
		_detect_false_start()
		_countdown -= delta
		var next_second := clampi(ceili(maxf(0.0, _countdown)), 0, 3)
		if next_second != _last_countdown_number:
			_last_countdown_number = next_second
			if _hud != null and _hud.has_method(&"show_countdown"):
				_hud.call(&"show_countdown", next_second)
			_audio.play_event("go" if next_second == 0 else "count")
		if _countdown <= 0.0:
			_running = true
			_start_penalty_remaining = FALSE_START_PENALTY_SECONDS if _false_start else 0.0
		_update_camera(delta)
		return

	if _start_penalty_remaining > 0.0:
		_start_penalty_remaining = maxf(0.0, _start_penalty_remaining - delta)

	_accumulator = minf(_accumulator + delta, FIXED_STEP * 8.0)
	while _accumulator >= FIXED_STEP:
		_step_simulation(FIXED_STEP)
		_accumulator -= FIXED_STEP
	_update_racer_visuals(delta)
	_update_camera(delta)
	_update_feedback()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"race_pause"):
		_paused = not _paused
		if _hud != null and _hud.has_method(&"show_pause"):
			_hud.call(&"show_pause", _paused)
		get_viewport().set_input_as_handled()
	elif _paused and event.is_action_pressed(&"ui_cancel"):
		_paused = false
		if _hud != null and _hud.has_method(&"show_pause"):
			_hud.call(&"show_pause", false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"race_camera") and not _paused:
		switch_camera_view()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"race_reset") and _running and _player != null:
		_try_reset_player()
		get_viewport().set_input_as_handled()


func _step_simulation(delta: float) -> void:
	_elapsed += delta
	_update_marker_cooldowns(delta)
	_update_ai_item_cooldowns(delta)
	var base_context := _race_context()
	_snapshots.clear()

	for racer in _racers:
		var before: Dictionary = racer.call(&"snapshot")
		if bool(before.get("finished", false)) or bool(before.get("dnf", false)) or bool(before.get("eliminated", false)):
			_snapshots.append(before)
			continue
		var context: Dictionary = base_context.duplicate(true)
		var racer_distance := float(before.get("distance", 0.0))
		var lookahead := clampf(18.0 + float(before.get("speed", 0.0)) * 0.82, 18.0, 66.0)
		context["curvature"] = _curvature_at(racer_distance)
		context["curvature_ahead"] = _curvature_at(racer_distance + lookahead)
		context["curvature_far"] = _curvature_at(racer_distance + lookahead * 1.75)
		context["hazard"] = _hazard_at(racer_distance)
		context["hazard_ahead"] = _hazard_at(racer_distance + lookahead)
		context["hazard_far"] = _hazard_at(racer_distance + lookahead * 1.75)
		context["lookahead_distance"] = lookahead
		context["position"] = _rank_in_snapshots(String(before.get("racer_id", "")), Array(base_context.get("racers", [])))
		context["race_progress"] = clampf(racer_distance / maxf(1.0, _track_length * int(_config.get("laps", 3))), 0.0, 1.0)
		context["speed_multiplier"] = _simulation_speed_multiplier(before, float(base_context.get("speed_multiplier", 1.0)))
		var controls: Dictionary = _player_controls() if bool(before.get("is_player", false)) else racer.call(&"ai_controls", context)
		var after: Dictionary = racer.call(&"step", delta, controls, context)
		_process_marker_contact(racer, after)
		if bool(after.get("finished", false)):
			var racer_id := String(after.get("racer_id", ""))
			if not racer_id in _finish_order:
				_finish_order.append(racer_id)
		_snapshots.append(after)

	_resolve_close_contacts()
	_sort_and_rank_snapshots()
	_handle_ai_items()
	_handle_item_input()
	_handle_elimination_mode()
	_check_end_conditions()


func _player_controls() -> Dictionary:
	var left := maxf(Input.get_action_strength(&"race_left"), float(_mobile_control_strengths.get(&"race_left", 0.0)))
	var right := maxf(Input.get_action_strength(&"race_right"), float(_mobile_control_strengths.get(&"race_right", 0.0)))
	var steer := right - left
	var controls := {
		"throttle": maxf(Input.get_action_strength(&"race_accelerate"), float(_mobile_control_strengths.get(&"race_accelerate", 0.0))),
		"brake": maxf(Input.get_action_strength(&"race_brake"), float(_mobile_control_strengths.get(&"race_brake", 0.0))),
		"steer": clampf(steer, -1.0, 1.0),
		"drift": Input.is_action_pressed(&"race_drift") or float(_mobile_control_strengths.get(&"race_drift", 0.0)) > 0.5,
		"boost": Input.is_action_pressed(&"race_boost") or float(_mobile_control_strengths.get(&"race_boost", 0.0)) > 0.5,
	}
	if _start_penalty_remaining > 0.0:
		controls["throttle"] = 0.0
		controls["boost"] = false
	return controls


func _detect_false_start() -> void:
	if _false_start_latched or _briefing_remaining > 0.0:
		return
	var throttle := maxf(Input.get_action_strength(&"race_accelerate"), float(_mobile_control_strengths.get(&"race_accelerate", 0.0)))
	var boost := Input.is_action_pressed(&"race_boost") or float(_mobile_control_strengths.get(&"race_boost", 0.0)) > 0.5
	if throttle < 0.12 and not boost:
		return
	_false_start = true
	_false_start_latched = true
	if _hud != null and _hud.has_method(&"show_false_start"):
		_hud.call(&"show_false_start", FALSE_START_PENALTY_SECONDS)
	_audio.play_event("impact")


func start_phase() -> String:
	if _finish_cinematic:
		return "finish"
	if _briefing_remaining > 0.0:
		return "briefing"
	if _countdown > 0.0:
		return "countdown"
	return "racing" if _running else "stopped"


func has_false_start() -> bool:
	return _false_start


func start_penalty_remaining() -> float:
	return _start_penalty_remaining


func _handle_item_input() -> void:
	var physical_pressed := Input.is_action_pressed(&"race_item")
	var pressed := physical_pressed or _mobile_item_pending
	if pressed and not _item_was_pressed and _player != null:
		var item_id := String(_player.call(&"use_item"))
		if not item_id.is_empty():
			_apply_item(_player, item_id)
	_mobile_item_pending = false
	_item_was_pressed = physical_pressed


## AI item decisions are evaluated on the fixed simulation clock. Racers keep
## an item until its tactical condition is met, so render framerate never
## changes consumption order and dense pickup sections cannot cause spam.
func _handle_ai_items() -> void:
	for racer: RefCounted in _racers:
		if racer == _player:
			continue
		var state: Dictionary = racer.call(&"snapshot")
		if not _is_active_racer_state(state):
			continue
		var racer_id := String(state.get("racer_id", ""))
		if float(_ai_item_cooldowns.get(racer_id, 0.0)) > 0.0:
			continue
		var item_id := String(state.get("item", ""))
		if item_id.is_empty():
			continue
		if not _should_ai_use_item(racer, state, item_id):
			_ai_item_cooldowns[racer_id] = AI_ITEM_REEVALUATE_INTERVAL
			continue
		var used_item := String(racer.call(&"use_item"))
		if used_item.is_empty():
			continue
		_apply_item(racer, used_item)
		_ai_item_cooldowns[racer_id] = AI_ITEM_REUSE_DELAY


func _should_ai_use_item(source: RefCounted, state: Dictionary, item_id: String) -> bool:
	var armor_ratio := float(state.get("armor_ratio", 1.0))
	var speed_ratio := float(state.get("speed_ratio", 0.0))
	var distance := float(state.get("distance", 0.0))
	var rank := _rank_for_racer(String(state.get("racer_id", "")))
	var ai_style := String(state.get("ai_trait", "adaptive"))
	var aggression := clampf(float(state.get("ai_aggression", 0.50)), 0.0, 1.0)
	var progress := clampf(distance / maxf(1.0, _track_length * int(_config.get("laps", 3))), 0.0, 1.0)
	var gap_ahead := _nearest_racer_gap(source, 1, 108.0)
	var gap_behind := _nearest_racer_gap(source, -1, 28.0)
	var nearby_count := _nearby_racer_count(source, 24.0)
	match item_id:
		"repair":
			var repair_threshold := 0.74 if ai_style == "defensive" else 0.62
			if ai_style in ["aggressive", "rammer"]:
				repair_threshold = 0.54
			if progress > 0.88 and rank <= 2:
				repair_threshold -= 0.08
			return armor_ratio <= repair_threshold
		"shield":
			var threatened := gap_ahead <= 22.0 or gap_behind <= (26.0 if rank == 1 else 20.0)
			var shield_threshold := 0.92 if ai_style == "defensive" else 0.80
			return not bool(state.get("shielded", false)) and armor_ratio <= shield_threshold and (threatened or armor_ratio <= 0.46)
		"overdrive":
			var lookahead := clampf(20.0 + float(state.get("speed", 0.0)) * 0.72, 20.0, 58.0)
			var on_straight := absf(_curvature_at(distance)) <= STRAIGHT_CURVATURE_LIMIT and absf(_curvature_at(distance + lookahead)) <= STRAIGHT_CURVATURE_LIMIT * 1.25
			var safe_sector := _hazard_at(distance + lookahead).is_empty()
			var needs_energy := float(state.get("boost_energy", 0.0)) <= 0.72
			var tactical_window := needs_energy or rank > 1 or progress > 0.90
			return on_straight and safe_sector and speed_ratio >= 0.45 and float(state.get("heat_ratio", 0.0)) < (0.82 + aggression * 0.07) and tactical_window
		"emp", "shockwave":
			# Chasers attack a nearby racer ahead; leaders only fire defensively
			# against a close pursuer or when the pack is clustered.
			var attack_reach := 18.0 + aggression * 10.0
			return nearby_count >= (2 if aggression < 0.70 else 1) or (rank > 1 and gap_ahead <= attack_reach) or (rank == 1 and gap_behind <= 10.0 + aggression * 6.0)
		"mine":
			var mine_reach := 14.0 + aggression * 7.0
			return gap_behind <= mine_reach and (rank <= 4 or progress > 0.72)
		"ion":
			return rank > 1 and gap_ahead <= 58.0 + aggression * 18.0
		"rail":
			return rank > 1 and gap_ahead <= 88.0 + aggression * 20.0 and (speed_ratio > 0.38 or progress > 0.82)
		_:
			return false


func _rank_for_racer(racer_id: String) -> int:
	for index in range(_snapshots.size()):
		if String(_snapshots[index].get("racer_id", "")) == racer_id:
			return index + 1
	return maxi(1, _racers.size())


func _nearest_racer_gap(source: RefCounted, direction: int, reach: float) -> float:
	var source_state: Dictionary = source.call(&"snapshot")
	var source_distance := float(source_state.get("distance", 0.0))
	var best_gap := INF
	for target: RefCounted in _racers:
		if target == source:
			continue
		var state: Dictionary = target.call(&"snapshot")
		if not _is_active_racer_state(state):
			continue
		var signed_gap := float(state.get("distance", 0.0)) - source_distance
		if direction > 0 and signed_gap <= 0.0:
			continue
		if direction < 0 and signed_gap >= 0.0:
			continue
		var gap := absf(signed_gap)
		if gap <= reach and gap < best_gap:
			best_gap = gap
	return best_gap


func _nearby_racer_count(source: RefCounted, reach: float) -> int:
	var source_state: Dictionary = source.call(&"snapshot")
	var source_distance := float(source_state.get("distance", 0.0))
	var count := 0
	for target: RefCounted in _racers:
		if target == source:
			continue
		var state: Dictionary = target.call(&"snapshot")
		if _is_active_racer_state(state) and absf(float(state.get("distance", 0.0)) - source_distance) <= reach:
			count += 1
	return count


func _is_active_racer_state(state: Dictionary) -> bool:
	return not bool(state.get("finished", false)) and not bool(state.get("dnf", false)) and not bool(state.get("eliminated", false))


func _apply_item(source: RefCounted, item_id: String) -> void:
	var source_state: Dictionary = source.call(&"snapshot")
	var source_distance := float(source_state.get("distance", 0.0))
	var source_lane := float(source_state.get("lane", 0.0))
	match item_id:
		"repair":
			pass # RacerState.use_item() has already restored armor.
		"shield", "overdrive":
			pass # Timed defensive/mobility effects are activated inside RacerState.use_item().
		"emp", "shockwave":
			for target in _racers:
				if target == source:
					continue
				var state: Dictionary = target.call(&"snapshot")
				if _is_active_racer_state(state) and absf(float(state.get("distance", 0.0)) - source_distance) < 24.0:
					target.call(&"apply_hit", 10.0 if item_id == "emp" else 16.0, signf(float(state.get("lane", 0.0)) - source_lane) * 0.35)
					if item_id == "emp":
						# EMP combines light impact damage with its authored control debuff.
						target.call(&"apply_emp", 1.8)
		"mine":
			var target := _nearest_racer_behind(source, 18.0)
			if target != null:
				target.call(&"apply_ground_mine", 18.0, 0.48)
		"ion", "rail":
			var target := _nearest_racer(source, true, 72.0 if item_id == "ion" else 108.0)
			if target != null:
				target.call(&"apply_hit", 20.0 if item_id == "ion" else 25.0, 0.24)
	_audio.play_event(item_id if item_id in ["emp", "shield", "boost"] else "impact")


func _nearest_racer(source: RefCounted, forward: bool, reach: float) -> RefCounted:
	var source_state: Dictionary = source.call(&"snapshot")
	var source_distance := float(source_state.get("distance", 0.0))
	var best: RefCounted
	var best_gap := INF
	for target in _racers:
		if target == source:
			continue
		var state: Dictionary = target.call(&"snapshot")
		if bool(state.get("dnf", false)) or bool(state.get("eliminated", false)):
			continue
		var gap := float(state.get("distance", 0.0)) - source_distance
		if forward and gap < 0.0:
			continue
		if not forward:
			gap = absf(gap)
		if gap <= reach and gap < best_gap:
			best_gap = gap
			best = target
	return best


func _nearest_racer_behind(source: RefCounted, reach: float) -> RefCounted:
	var source_state: Dictionary = source.call(&"snapshot")
	var source_distance := float(source_state.get("distance", 0.0))
	var best: RefCounted
	var best_gap := INF
	for target: RefCounted in _racers:
		if target == source:
			continue
		var state: Dictionary = target.call(&"snapshot")
		if not _is_active_racer_state(state):
			continue
		var signed_gap := float(state.get("distance", 0.0)) - source_distance
		if signed_gap >= 0.0:
			continue
		var gap := absf(signed_gap)
		if gap <= reach and gap < best_gap:
			best_gap = gap
			best = target
	return best


func _process_marker_contact(racer: RefCounted, snapshot: Dictionary) -> void:
	if not bool(_config.get("items_enabled", true)):
		return
	var distance := float(snapshot.get("distance", 0.0))
	var lap_distance := fposmod(distance, _track_length)
	var lane := float(snapshot.get("lane", 0.0))
	for marker: Dictionary in TrackFactoryType.gameplay_markers(_track):
		var marker_id := String(marker.get("id", ""))
		var key := "%s:%s" % [String(snapshot.get("racer_id", "")), marker_id]
		if float(_marker_cooldowns.get(key, 0.0)) > 0.0:
			continue
		var longitudinal := absf(float(marker.get("progress", 0.0)) - lap_distance)
		longitudinal = minf(longitudinal, _track_length - longitudinal)
		if longitudinal > 2.8 or absf(float(marker.get("lane", 0.0)) - lane) > 0.28:
			continue
		_marker_cooldowns[key] = 2.4
		if String(marker.get("kind", "pickup")) == "pickup":
			var racer_id := String(snapshot.get("racer_id", "0"))
			var item_index := posmod(racer_id.hash() + roundi(distance), GameDatabase.ITEMS.size())
			var item: Dictionary = GameDatabase.ITEMS[item_index]
			var granted := bool(racer.call(&"grant_item", String(item.get("id", "overdrive"))))
			if granted and racer == _player:
				_audio.play_event("pickup")
			elif granted:
				# Stable ID staggering avoids a whole pack firing on the same tick.
				_ai_item_cooldowns[racer_id] = AI_ITEM_PICKUP_DELAY + float(posmod(racer_id.hash(), 4)) * 0.05
		else:
			# Dedicated reactor recharge: a pad never consumes the held item.
			var activated := bool(racer.call(&"apply_boost_pad"))
			if racer == _player and activated:
				_audio.play_event("boost")


func _resolve_close_contacts() -> void:
	for first_index in range(_racers.size()):
		var first: RefCounted = _racers[first_index]
		var a: Dictionary = first.call(&"snapshot")
		if bool(a.get("dnf", false)) or bool(a.get("finished", false)) or bool(a.get("eliminated", false)):
			continue
		for second_index in range(first_index + 1, _racers.size()):
			var second: RefCounted = _racers[second_index]
			var b: Dictionary = second.call(&"snapshot")
			if bool(b.get("dnf", false)) or bool(b.get("finished", false)) or bool(b.get("eliminated", false)):
				continue
			var contact_length := (maxf(1.0, float(a.get("vehicle_length", 4.0))) + maxf(1.0, float(b.get("vehicle_length", 4.0)))) * 0.5
			var contact_width := (maxf(1.0, float(a.get("vehicle_width", 3.5))) + maxf(1.0, float(b.get("vehicle_width", 3.5)))) * 0.5
			var physical_track_width := maxf(_track_width, maxf(float(a.get("track_width", _track_width)), float(b.get("track_width", _track_width))))
			var lateral_gap := TrackSafetyType.lateral_gap_meters(float(a.get("lane", 0.0)), float(b.get("lane", 0.0)), physical_track_width)
			if absf(float(a.get("distance", 0.0)) - float(b.get("distance", 0.0))) < contact_length and lateral_gap < contact_width:
				var direction := -1.0 if float(a.get("lane", 0.0)) < float(b.get("lane", 0.0)) else 1.0
				var first_strength := float(first.call(&"contact_damage_multiplier"))
				var second_strength := float(second.call(&"contact_damage_multiplier"))
				# Each chassis authors the damage and shove it deals to the rival.
				first.call(&"apply_hit", 0.018 * second_strength, direction * 0.04 * second_strength)
				second.call(&"apply_hit", 0.018 * first_strength, -direction * 0.04 * first_strength)


func _sort_and_rank_snapshots() -> void:
	_snapshots.sort_custom(Callable(self, "_classification_precedes"))
	for index in range(_snapshots.size()):
		_snapshots[index]["position"] = index + 1


func _classification_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_id := String(a.get("racer_id", ""))
	var b_id := String(b.get("racer_id", ""))
	var a_ineligible := bool(a.get("dnf", false)) or bool(a.get("eliminated", false))
	var b_ineligible := bool(b.get("dnf", false)) or bool(b.get("eliminated", false))
	if a_ineligible != b_ineligible:
		return not a_ineligible
	var a_distance := float(a.get("distance", 0.0))
	var b_distance := float(b.get("distance", 0.0))
	if a_ineligible:
		if not is_equal_approx(a_distance, b_distance):
			return a_distance > b_distance
		return a_id.naturalnocasecmp_to(b_id) < 0

	var a_finish_index := _finish_order.find(a_id)
	var b_finish_index := _finish_order.find(b_id)
	var a_finished := a_finish_index >= 0 or bool(a.get("finished", false))
	var b_finished := b_finish_index >= 0 or bool(b.get("finished", false))
	if a_finished != b_finished:
		return a_finished
	if a_finished:
		if a_finish_index >= 0 and b_finish_index >= 0 and a_finish_index != b_finish_index:
			return a_finish_index < b_finish_index
		if (a_finish_index >= 0) != (b_finish_index >= 0):
			return a_finish_index >= 0
		var a_finish_time := maxf(0.0, float(a.get("finish_time", a.get("elapsed", 0.0))))
		var b_finish_time := maxf(0.0, float(b.get("finish_time", b.get("elapsed", 0.0))))
		if a_finish_time > 0.0 and b_finish_time > 0.0 and not is_equal_approx(a_finish_time, b_finish_time):
			return a_finish_time < b_finish_time
		if (a_finish_time > 0.0) != (b_finish_time > 0.0):
			return a_finish_time > 0.0
	if not is_equal_approx(a_distance, b_distance):
		return a_distance > b_distance
	return a_id.naturalnocasecmp_to(b_id) < 0


func _handle_elimination_mode() -> void:
	if String(_config.get("mode", "quick")) != "elimination" or _elapsed < _next_elimination:
		return
	_next_elimination += float(_config.get("elimination_interval", ELIMINATION_INTERVAL))
	var candidates: Array = []
	for racer in _racers:
		var state: Dictionary = racer.call(&"snapshot")
		if not bool(state.get("eliminated", false)) and not bool(state.get("finished", false)) and not bool(state.get("dnf", false)):
			candidates.append(racer)
	if candidates.size() <= 1:
		return
	candidates.sort_custom(func(a: RefCounted, b: RefCounted) -> bool: return float(a.call(&"race_distance")) < float(b.call(&"race_distance")))
	var eliminated: RefCounted = candidates[0]
	eliminated.call(&"eliminate", "last_at_gate")
	if eliminated == _player:
		_audio.play_event("impact")


func _check_end_conditions() -> void:
	if _player == null:
		return
	var player_state: Dictionary = _player.call(&"snapshot")
	var active_count := 0
	for racer in _racers:
		var state: Dictionary = racer.call(&"snapshot")
		if not bool(state.get("eliminated", false)) and not bool(state.get("dnf", false)) and not bool(state.get("finished", false)):
			active_count += 1
	if String(_config.get("mode", "quick")) == "elimination" and active_count <= 1 and not bool(player_state.get("eliminated", false)):
		player_state["finished"] = true
		_finish_race(player_state)
	elif bool(player_state.get("finished", false)) or bool(player_state.get("dnf", false)) or bool(player_state.get("eliminated", false)):
		_finish_race(player_state)
	elif _elapsed >= float(_config.get("time_limit", MAX_RACE_SECONDS)):
		_player.call(&"mark_dnf", "timeout")
		_finish_race(_player.call(&"snapshot"))


## Freezes an official classification when the player's session ends. Racers
## still on track are classified by their live order without being mislabeled
## as finish-line crossers; DNF and eliminated entries remain ineligible.
func _prepare_official_classification(player_state: Dictionary) -> void:
	var player_finished := bool(player_state.get("finished", false)) \
		and not bool(player_state.get("dnf", false)) \
		and not bool(player_state.get("eliminated", false))
	var player_finish_time := maxf(0.0, float(player_state.get("finish_time", 0.0)))
	if player_finished and player_finish_time <= 0.0:
		player_finish_time = _elapsed
	for index in range(_snapshots.size()):
		var entry: Dictionary = _snapshots[index]
		if not bool(entry.get("is_player", false)) and String(entry.get("racer_id", "")) != "player":
			continue
		entry["finished"] = player_finished
		entry["dnf"] = bool(player_state.get("dnf", false)) or bool(player_state.get("eliminated", false))
		entry["eliminated"] = bool(player_state.get("eliminated", false))
		entry["reason"] = String(player_state.get("reason", entry.get("reason", "")))
		entry["finish_time"] = player_finish_time
		_snapshots[index] = entry
		var racer_id := String(entry.get("racer_id", "player"))
		if player_finished and not racer_id in _finish_order:
			_finish_order.append(racer_id)
		break
	_sort_and_rank_snapshots()
	var allow_podium := String(_config.get("mode", "quick")) != "time_trial"
	for index in range(_snapshots.size()):
		var entry: Dictionary = _snapshots[index]
		entry["classified"] = allow_podium and not bool(entry.get("dnf", false)) and not bool(entry.get("eliminated", false))
		_snapshots[index] = entry
	_decorate_classification()


func _decorate_classification() -> void:
	if _snapshots.is_empty():
		return
	var leader_index := -1
	var leader_distance := 0.0
	var leader_finish_time := 0.0
	for index in range(_snapshots.size()):
		var candidate: Dictionary = _snapshots[index]
		if bool(candidate.get("dnf", false)) or bool(candidate.get("eliminated", false)):
			continue
		leader_index = index
		leader_distance = float(candidate.get("distance", 0.0))
		leader_finish_time = maxf(0.0, float(candidate.get("finish_time", 0.0)))
		if leader_finish_time <= 0.0:
			leader_finish_time = maxf(0.0, float(candidate.get("elapsed", 0.0)))
		break
	for index in range(_snapshots.size()):
		var entry: Dictionary = _snapshots[index]
		var finish_time := maxf(0.0, float(entry.get("finish_time", 0.0)))
		if finish_time <= 0.0:
			finish_time = maxf(0.0, float(entry.get("elapsed", 0.0)))
		entry["position"] = index + 1
		entry["finish_time"] = finish_time
		entry["elapsed"] = finish_time
		var delta_text := ""
		if bool(entry.get("eliminated", false)):
			delta_text = "ÉLIMINÉ"
		elif bool(entry.get("dnf", false)):
			delta_text = "DNF"
		elif index == leader_index:
			delta_text = "—" if leader_finish_time > 0.0 else "LEADER"
		elif finish_time > 0.0 and leader_finish_time > 0.0:
			delta_text = "+%.3f s" % maxf(0.0, finish_time - leader_finish_time)
		elif leader_index >= 0:
			delta_text = "+%.0f m" % maxf(0.0, leader_distance - float(entry.get("distance", 0.0)))
		entry["delta"] = delta_text
		entry["gap"] = delta_text
		_snapshots[index] = entry


func _finish_race(player_state: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	_finish_cinematic = true
	_cinematic_elapsed = 0.0
	_release_mobile_controls()
	_prepare_official_classification(player_state)
	var result := player_state.duplicate(true)
	result["position"] = _player_position()
	result["elapsed"] = _elapsed
	result["track_id"] = String(_config.get("track_id", "foundry"))
	result["mode"] = String(_config.get("mode", "quick"))
	result["finished"] = bool(player_state.get("finished", false)) \
		and not bool(player_state.get("dnf", false)) \
		and not bool(player_state.get("eliminated", false))
	result["dnf"] = not bool(result["finished"])
	result["record_valid"] = bool(result["finished"])
	result["classification"] = _snapshots.duplicate(true)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"complete_race"):
		var normalized: Variant = session.call(&"complete_race", result)
		if normalized is Dictionary:
			result = normalized
	result["ruleset_id"] = String(_config.get("ruleset_id", "division_locked"))
	result["performance_class_id"] = String(_config.get("performance_class_id", "tuned"))
	_audio.play_event("finish" if bool(result.get("finished", false)) else "impact")
	if _hud != null and _hud.has_method(&"show_finish"):
		_hud.call(&"show_finish", result)
	await get_tree().create_timer(FINISH_BROADCAST_SECONDS, true, false, true).timeout
	_finish_cinematic = false
	race_finished.emit(result)


func _player_position() -> int:
	for index in range(_snapshots.size()):
		if bool(_snapshots[index].get("is_player", false)):
			return index + 1
	return maxi(1, _racers.size())


func _race_context() -> Dictionary:
	var difficulty := GameDatabase.get_difficulty(String(_config.get("difficulty", "pilot")))
	return {
		"elapsed": _elapsed,
		"race_active": _running,
		"grip": _track_grip(),
		"curvature": 0.0,
		"hazard": "",
		"speed_multiplier": float(difficulty.get("speed", 1.0)),
		"difficulty_skill": float(difficulty.get("skill", 0.69)),
		"difficulty_aggression": float(difficulty.get("aggression", 0.50)),
		"racers": _snapshots.duplicate(true),
	}


func _simulation_speed_multiplier(state: Dictionary, base_multiplier: float) -> float:
	# Difficulty authors rival pace only. Applying it to the player's travelled
	# distance made records and identical inputs depend on the selected AI tier.
	if bool(state.get("is_player", false)):
		return 1.0
	return clampf(base_multiplier * _bounded_ai_catchup(state), 0.25, 1.75)


func _bounded_ai_catchup(state: Dictionary) -> float:
	if _player == null or _racers.size() <= 1:
		return 1.0
	var player_state: Dictionary = _player.call(&"snapshot")
	var gap := float(player_state.get("distance", 0.0)) - float(state.get("distance", 0.0))
	var normalized_gap := clampf(gap / maxf(220.0, _track_length * 0.55), -1.0, 1.0)
	var race_progress := clampf(float(state.get("distance", 0.0)) / maxf(1.0, _track_length * int(_config.get("laps", 3))), 0.0, 1.0)
	var late_race_falloff := lerpf(1.0, 0.55, race_progress)
	return 1.0 + normalized_gap * 0.035 * late_race_falloff


func _rank_in_snapshots(racer_id: String, racers: Array) -> int:
	for index in range(racers.size()):
		var value: Variant = racers[index]
		if value is Dictionary and String(Dictionary(value).get("racer_id", "")) == racer_id:
			return index + 1
	return maxi(1, _racers.size())


func _track_grip() -> float:
	var track := GameDatabase.get_track(String(_config.get("track_id", "foundry")))
	if track.has("base_grip"):
		return clampf(float(track.get("base_grip", 1.0)), 0.65, 1.2)
	match String(_config.get("track_id", "foundry")):
		"glacier": return 0.82
		"dunes": return 0.91
		"orbital": return 0.88
		"canopy": return 0.86
		"tempest": return 0.90
		"abyss": return 0.84
		"caldera": return 0.92
		_: return 1.0


func _curvature_at(distance: float) -> float:
	var current := TrackFactoryType.sample_pose(_track, distance)
	var future := TrackFactoryType.sample_pose(_track, distance + 18.0)
	var current_forward := -current.basis.z.normalized()
	var future_forward := -future.basis.z.normalized()
	return clampf(current_forward.signed_angle_to(future_forward, Vector3.UP) * 2.2, -1.0, 1.0)


func _hazard_at(distance: float) -> String:
	var track_spec := GameDatabase.get_track(String(_config.get("track_id", "foundry")))
	var hazards: Array = track_spec.get("hazards", [])
	if hazards.is_empty():
		return ""
	var section := int(fposmod(distance, _track_length) / maxf(1.0, _track_length) * 12.0)
	if section % 4 != 2:
		return ""
	var hazard_sector := int(section / 4)
	return String(hazards[hazard_sector % hazards.size()])


func _build_track() -> void:
	var track_spec := GameDatabase.get_track(String(_config.get("track_id", "foundry")))
	_track = TrackFactoryType.build(track_spec)
	add_child(_track)
	_track_length = TrackFactoryType.track_length(_track)
	_track_width = maxf(TrackSafetyType.minimum_road_width(), float(_track.get_meta("width", TrackSafetyType.MIN_ROAD_WIDTH)))


func _build_racers() -> void:
	var profile := _profile()
	var selected_id := String(profile.get("selected_chassis", "biped"))
	var selected_chassis := GameDatabase.get_chassis(selected_id)
	var selected_division := String(selected_chassis.get("division_id", "command"))
	var grid_policy := "mixed" if String(_config.get("grid_policy", "division")) == "mixed" else "division"
	var division_id := String(_config.get("division_id", selected_division))
	if GameDatabase.get_division(division_id).is_empty():
		division_id = selected_division
	var chassis_pool := GameDatabase.get_all_chassis() if grid_policy == "mixed" else GameDatabase.get_chassis_for_division(division_id)
	if chassis_pool.is_empty():
		chassis_pool = [selected_chassis]
	var pilots := GameDatabase.get_all_pilots()
	var roster_value: Variant = _config.get("roster", [])
	var roster: Array = roster_value if roster_value is Array else []
	var performance_class_id := String(_config.get("performance_class_id", "tuned"))
	var performance_class := GameDatabase.get_performance_class(performance_class_id)
	if performance_class.is_empty():
		performance_class_id = "tuned"
		performance_class = GameDatabase.get_performance_class("tuned")
	var racer_count := clampi(int(_config.get("racer_count", GRID_SIZE)), 1, GRID_SIZE)
	for index in range(racer_count):
		var entrant: Dictionary = roster[index] if index < roster.size() and roster[index] is Dictionary else {}
		var is_player := bool(entrant.get("is_player", entrant.get("player", index == 0))) or String(entrant.get("racer_id", entrant.get("id", ""))) == "player"
		var fallback_chassis := selected_chassis if is_player else chassis_pool[index % chassis_pool.size()]
		var chassis_id := String(entrant.get("chassis_id", fallback_chassis.get("id", "biped")))
		var chassis := GameDatabase.get_chassis(chassis_id)
		if chassis.is_empty() or (grid_policy == "division" and String(chassis.get("division_id", "")) != division_id):
			chassis = fallback_chassis
			chassis_id = String(chassis.get("id", "biped"))
		var pilot_id := String(entrant.get("pilot_id", "player" if is_player else pilots[(index - 1) % pilots.size()].get("id", "vex")))
		var pilot := GameDatabase.get_pilot(pilot_id)
		if pilot.is_empty() and not is_player:
			pilot = pilots[(index - 1) % pilots.size()]
		var racer_id := "player" if is_player else String(entrant.get("racer_id", entrant.get("id", pilot.get("id", "rival_%02d" % index))))
		var fallback_loadout := _player_loadout(profile, chassis_id) if is_player else _default_loadout(chassis_id)
		var requested_loadout: Variant = entrant.get("loadout", fallback_loadout)
		var fallback_locomotion := _player_locomotion(profile, chassis_id) if is_player else LocomotionCatalog.get_default_configuration_id(chassis_id)
		var requested_locomotion := String(entrant.get("locomotion_id", fallback_locomotion))
		var locomotion := LocomotionCatalog.homologate_configuration(chassis, requested_locomotion, performance_class)
		var locomotion_id := String(locomotion.get("id", fallback_locomotion))
		if is_player and requested_locomotion != locomotion_id:
			_config["homologation_notice"] = "HOMOLOGATION // %s REFUSÉ EN %s — MONTAGE CONSTRUCTEUR APPLIQUÉ" % [
				String(LocomotionCatalog.get_configuration(requested_locomotion).get("short_name", "MONTAGE")),
				String(performance_class.get("name", performance_class_id)).to_upper(),
			]
		var loadout := _loadout_for_class(requested_loadout, chassis_id, performance_class_id, int(locomotion.get("power_draw", 0)))
		var tuning_stats := _module_stats(loadout)
		var locomotion_stats: Dictionary = locomotion.get("stats", {}) if locomotion.get("stats", {}) is Dictionary else {}
		for stat_id: String in tuning_stats.keys():
			tuning_stats[stat_id] = float(tuning_stats[stat_id]) + float(locomotion_stats.get(stat_id, 0.0))
		var paint_text := String(entrant.get("paint", _player_paint(profile, chassis) if is_player else pilot.get("paint", chassis.get("paint", "#5EE7FF"))))
		if not Color.html_is_valid(paint_text):
			paint_text = String(chassis.get("paint", "#5EE7FF"))
		var racer := RacerStateType.new()
		var spec := {
			"racer_id": racer_id,
			"display_name": String(entrant.get("name", profile.get("pilot_name", "PILOTE 01") if is_player else pilot.get("callsign", pilot.get("name", "RIVAL")))),
			"chassis_id": chassis_id,
			"pilot_id": pilot_id,
			"is_player": is_player,
			"difficulty": String(_config.get("difficulty", "pilot")),
			"track_length": _track_length,
			"track_width": _track_width,
			"total_laps": int(_config.get("laps", 3)),
			"upgrades": _player_upgrades(profile, chassis_id, performance_class_id) if is_player else {},
			"module_stats": tuning_stats,
			"locomotion_id": locomotion_id,
			"grid_index": index,
			"seed": String(_config.get("track_id", "foundry")).hash() + index * 733,
		}
		racer.call(&"configure", spec)
		_racers.append(racer)
		if is_player:
			_player = racer
		var customization := loadout.duplicate(true)
		customization["locomotion_id"] = locomotion_id
		var visual: RacerVisual = MechaFactoryType.build(chassis, Color(paint_text), is_player, customization)
		visual.name = racer_id
		visual.set_accessibility(_reduced_motion)
		# Animate limbs first, then reapply the authored track elevation.
		# This prevents visual bounce from flattening vertical circuits.
		visual.process_priority = -10
		add_child(visual)
		_visuals[racer_id] = visual


func _grid_preview() -> Array[Dictionary]:
	var grid: Array[Dictionary] = []
	for racer: RefCounted in _racers:
		var snapshot: Dictionary = racer.call(&"snapshot")
		grid.append({
			"racer_id": String(snapshot.get("racer_id", "")),
			"display_name": String(snapshot.get("display_name", "PILOTE")),
			"chassis_id": String(snapshot.get("chassis_id", "")),
			"division_id": String(snapshot.get("division_id", "")),
			"is_player": bool(snapshot.get("is_player", false)),
		})
	return grid


func _player_paint(profile: Dictionary, chassis: Dictionary) -> String:
	var paints: Dictionary = profile.get("paints", {}) if profile.get("paints", {}) is Dictionary else {}
	var chassis_id := String(chassis.get("id", "biped"))
	return String(paints.get(chassis_id, chassis.get("paint", "#5EE7FF")))


func _player_loadout(profile: Dictionary, chassis_id: String) -> Dictionary:
	var loadouts: Dictionary = profile.get("loadouts", {}) if profile.get("loadouts", {}) is Dictionary else {}
	var value: Variant = loadouts.get(chassis_id, {})
	return Dictionary(value).duplicate(true) if value is Dictionary else _default_loadout(chassis_id)


func _player_locomotion(profile: Dictionary, chassis_id: String) -> String:
	var locomotions: Dictionary = profile.get("locomotions", {}) if profile.get("locomotions", {}) is Dictionary else {}
	var requested := String(locomotions.get(chassis_id, LocomotionCatalog.get_default_configuration_id(chassis_id)))
	var configuration := LocomotionCatalog.get_configuration(requested)
	if configuration.is_empty() or String(configuration.get("family_id", "")) != chassis_id:
		return LocomotionCatalog.get_default_configuration_id(chassis_id)
	return requested


func _default_loadout(chassis_id: String = "") -> Dictionary:
	var output: Dictionary = {}
	var chassis := GameDatabase.get_chassis(chassis_id)
	var authored: Dictionary = chassis.get("default_loadout", {}) if chassis.get("default_loadout", {}) is Dictionary else {}
	for slot: Dictionary in GameDatabase.MODULE_SLOTS:
		var slot_id := String(slot.get("id", ""))
		var option_id := String(authored.get(slot_id, slot.get("default_option_id", "")))
		if not slot_id.is_empty() and not GameDatabase.get_module_option(slot_id, option_id).is_empty():
			output[slot_id] = option_id
	return output


func _loadout_for_class(value: Variant, chassis_id: String, performance_class_id: String, reserved_power: int = 0) -> Dictionary:
	var authored_defaults := _default_loadout(chassis_id)
	var performance_class := GameDatabase.get_performance_class(performance_class_id)
	if String(performance_class.get("module_policy", "all")) == "defaults_only":
		return authored_defaults
	var source: Dictionary = value if value is Dictionary else {}
	var division_id := String(GameDatabase.get_chassis(chassis_id).get("division_id", ""))
	var max_tier := int(performance_class.get("max_module_tier", 1))
	var available_power := maxi(0, int(performance_class.get("module_power_budget", 0)) - maxi(0, reserved_power))
	var used_power := 0
	var output: Dictionary = {}
	for slot: Dictionary in GameDatabase.MODULE_SLOTS:
		var slot_id := String(slot.get("id", ""))
		var safe_option_id := String(slot.get("default_option_id", ""))
		var option_id := String(source.get(slot_id, authored_defaults.get(slot_id, safe_option_id)))
		var option := GameDatabase.get_module_option(slot_id, option_id)
		var option_power := maxi(0, int(option.get("power_draw", 0)))
		if not option.is_empty() and int(option.get("tier", 0)) <= max_tier and used_power + option_power <= available_power and GameDatabase.is_module_allowed_for_division(option_id, division_id):
			output[slot_id] = option_id
			used_power += option_power
		else:
			output[slot_id] = safe_option_id
	return output


func _module_stats(loadout: Dictionary) -> Dictionary:
	var output := {"speed": 0.0, "acceleration": 0.0, "handling": 0.0, "armor": 0.0, "stability": 0.0, "reactor": 0.0}
	for slot_id: String in loadout.keys():
		var option := GameDatabase.get_module_option(slot_id, String(loadout[slot_id]))
		var stats: Dictionary = option.get("stats", {}) if option.get("stats", {}) is Dictionary else {}
		for stat_id: String in output.keys():
			output[stat_id] = float(output[stat_id]) + float(stats.get(stat_id, 0.0))
	return output


func _player_upgrades(profile: Dictionary, chassis_id: String, performance_class_id: String) -> Dictionary:
	var performance_class := GameDatabase.get_performance_class(performance_class_id)
	var maximum := clampi(int(performance_class.get("max_upgrade_level", 2)), 0, 4)
	var all_upgrades: Variant = profile.get("upgrades", {})
	if all_upgrades is Dictionary:
		var upgrades: Dictionary = all_upgrades
		var selected: Variant = upgrades.get(chassis_id, upgrades)
		if selected is Dictionary:
			var selected_upgrades: Dictionary = selected
			var output: Dictionary = {}
			for upgrade_id: String in GameDatabase.get_upgrade_ids():
				output[upgrade_id] = clampi(int(selected_upgrades.get(upgrade_id, 0)), 0, maximum)
			return output
	return {}


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "RaceCamera"
	_camera.current = true
	_camera.near = 0.06
	_camera.fov = 72.0
	add_child(_camera)


func _update_grid_camera(delta: float) -> void:
	if _camera == null or _track == null:
		return
	var pose := TrackFactoryType.sample_pose(_track, 0.0, 0.0)
	var forward := -pose.basis.z.normalized()
	var side := pose.basis.x.normalized()
	var progress := clampf(1.0 - _briefing_remaining / GRID_BRIEFING_SECONDS, 0.0, 1.0)
	var target_position := pose.origin - forward * 15.0 + side * lerpf(-10.5, 7.0, progress) + pose.basis.y.normalized() * 7.6
	var look_target := pose.origin + forward * 3.5 + pose.basis.y.normalized() * 1.7
	var weight := 1.0 - exp(-delta * 3.8)
	_camera.global_position = _camera.global_position.lerp(target_position, weight)
	var next_basis := _camera.global_transform.looking_at(look_target, Vector3.UP, false).basis
	_camera.global_basis = _camera.global_basis.slerp(next_basis, weight)
	_camera.fov = lerpf(_camera.fov, 64.0, weight)


func _update_finish_camera(delta: float) -> void:
	if _camera == null or _player == null or _track == null:
		return
	var state: Dictionary = _player.call(&"snapshot")
	var pose := TrackFactoryType.sample_pose(_track, float(state.get("distance", 0.0)), float(state.get("lane", 0.0)))
	var player_visual: RacerVisual = _visuals.get("player")
	if player_visual != null and player_visual.has_method(&"set_camera_mode"):
		player_visual.call(&"set_camera_mode", "tps")
	var forward := -pose.basis.z.normalized()
	var side := pose.basis.x.normalized()
	var orbit := 0.0 if _reduced_motion else sin(_cinematic_elapsed * 0.85)
	var center := pose.origin + pose.basis.y.normalized() * 1.8
	var target_position := center - forward * (10.5 - orbit * 1.2) + side * (5.8 + orbit * 2.2) + pose.basis.y.normalized() * 3.8
	var weight := 1.0 - exp(-delta * 4.4)
	_camera.global_position = _camera.global_position.lerp(target_position, weight)
	var next_basis := _camera.global_transform.looking_at(center + forward * 2.5, Vector3.UP, false).basis
	_camera.global_basis = _camera.global_basis.slerp(next_basis, weight)
	_camera.fov = lerpf(_camera.fov, 57.0, weight)


func camera_mode() -> String:
	return _camera_mode


func switch_camera_view() -> String:
	_set_camera_mode("fps" if _camera_mode == "tps" else "tps", true)
	return _camera_mode


func _set_camera_mode(mode: String, persist: bool) -> void:
	_camera_mode = mode if mode in ["tps", "fps"] else "tps"
	_config["camera_view"] = _camera_mode
	var player_visual: RacerVisual = _visuals.get("player")
	if player_visual != null and player_visual.has_method(&"set_camera_mode"):
		player_visual.call(&"set_camera_mode", _camera_mode)
	if persist:
		var save := get_node_or_null("/root/SaveSystem")
		if save != null and save.has_method(&"set_camera_view"):
			save.call(&"set_camera_view", _camera_mode)


func _build_feedback() -> void:
	_audio = AudioDirectorType.new()
	add_child(_audio)
	_audio.configure(_profile().get("settings", {}))
	_hud = RaceHUDType.new()
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)
	hud_layer.add_child(_hud)
	_hud.pause_requested.connect(_on_hud_pause)
	_hud.retry_requested.connect(_request_retry)
	_hud.menu_requested.connect(_request_menu)
	_hud.mobile_control_changed.connect(_on_mobile_control_changed)
	_hud.mobile_action_triggered.connect(_on_mobile_action_triggered)


func _on_hud_pause(paused: bool) -> void:
	_paused = paused
	if paused:
		_release_mobile_controls()


func _on_mobile_control_changed(action: StringName, strength: float) -> void:
	if action not in MobileTouchControls.HOLD_ACTIONS:
		return
	_mobile_control_strengths[action] = clampf(strength, 0.0, 1.0)


func _on_mobile_action_triggered(action: StringName) -> void:
	match action:
		&"race_item":
			if _running and not _paused:
				_mobile_item_pending = true
		&"race_camera":
			if not _paused:
				switch_camera_view()
		&"race_reset":
			if _running and not _paused:
				_try_reset_player()
		&"race_pause":
			_paused = not _paused
			if _hud != null:
				_hud.show_pause(_paused)
			if _paused:
				_release_mobile_controls()


func _try_reset_player() -> bool:
	if _player == null or not bool(_player.call(&"can_reset")):
		return false
	var snapshot: Dictionary = _player.call(&"snapshot")
	var reset := bool(_player.call(&"reset_to_checkpoint", maxf(0.0, float(snapshot.get("distance", 0.0)) - 15.0), 0.0))
	if reset:
		_audio.play_event("shield")
	return reset


func _release_mobile_controls() -> void:
	_mobile_control_strengths.clear()
	_mobile_item_pending = false
	if _hud != null and _hud.has_method(&"release_mobile_controls"):
		_hud.call(&"release_mobile_controls")


func _request_retry() -> void:
	var next_config := _config.duplicate(true)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"configure"):
		var configured: Variant = session.call(&"configure", next_config)
		if configured is Dictionary:
			next_config = configured
	retry_requested.emit(next_config)


func _request_menu() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"abort_race"):
		session.call(&"abort_race", "abandoned")
	menu_requested.emit()


func _update_racer_visuals(_delta: float) -> void:
	for racer in _racers:
		var state: Dictionary = racer.call(&"snapshot")
		var id := String(state.get("racer_id", ""))
		var visual: RacerVisual = _visuals.get(id)
		if visual == null:
			continue
		var distance := float(state.get("distance", 0.0))
		var lane := float(state.get("lane", 0.0))
		visual.transform = TrackFactoryType.sample_pose(_track, distance, lane)
		visual.visible = not bool(state.get("eliminated", false))
		visual.set_motion(float(state.get("speed_ratio", 0.0)), float(state.get("steer", 0.0)), bool(state.get("boosting", false)), 1.0 - float(state.get("armor_ratio", 1.0)))


func _update_camera(delta: float) -> void:
	if _camera == null or _player == null or _track == null:
		return
	var state: Dictionary = _player.call(&"snapshot")
	var player_visual: RacerVisual = _visuals.get("player")
	var pose := TrackFactoryType.sample_pose(_track, float(state.get("distance", 0.0)), float(state.get("lane", 0.0)))
	var forward := -pose.basis.z.normalized()
	var target_position := pose.origin - forward * 12.5 + Vector3.UP * 6.1
	var look_target := pose.origin + forward * (10.0 + float(state.get("speed_ratio", 0.0)) * 7.0) + Vector3.UP * 1.8
	var response := 6.5
	var target_fov := 72.0 if _reduced_motion else 72.0 + minf(10.0, float(state.get("speed_ratio", 0.0)) * 5.5)
	var anchor: Marker3D = player_visual.camera_anchor(_camera_mode) if player_visual != null and player_visual.has_method(&"camera_anchor") else null
	if anchor != null:
		target_position = anchor.global_position
		forward = -anchor.global_basis.z.normalized()
		if _camera_mode == "fps":
			look_target = target_position + forward * 28.0 + anchor.global_basis.y.normalized() * 0.12
			response = 15.0
			target_fov = 79.0 if _reduced_motion else 79.0 + minf(5.0, float(state.get("speed_ratio", 0.0)) * 3.0)
		else:
			look_target = pose.origin + forward * (11.0 + float(state.get("speed_ratio", 0.0)) * 7.0) + pose.basis.y.normalized() * 1.7
			response = 7.5
	var weight := 1.0 - exp(-delta * response)
	_camera.global_position = _camera.global_position.lerp(target_position, weight)
	# Camera3D looks along -Z; `use_model_front` would turn its view away from the track.
	var next_basis := _camera.global_transform.looking_at(look_target, Vector3.UP, false).basis
	_camera.global_basis = _camera.global_basis.slerp(next_basis, weight)
	_camera.fov = lerpf(_camera.fov, target_fov, weight)


func _update_feedback() -> void:
	if _player == null:
		return
	var player_state: Dictionary = _player.call(&"snapshot")
	if _hud != null and _hud.has_method(&"update_race"):
		var hud_snapshot := player_state.duplicate(true)
		hud_snapshot["elapsed"] = _elapsed
		hud_snapshot["speed"] = float(player_state.get("speed", 0.0)) * 3.6
		hud_snapshot["position"] = _player_position()
		hud_snapshot["racer_count"] = _racers.size()
		hud_snapshot["mode"] = String(_config.get("mode", "quick"))
		hud_snapshot["next_elimination"] = maxf(0.0, _next_elimination - _elapsed)
		hud_snapshot["camera_view"] = _camera_mode
		if _start_penalty_remaining > 0.0:
			hud_snapshot["warning"] = "PÉNALITÉ FAUX DÉPART // PROPULSEURS %.1f S" % _start_penalty_remaining
		_hud.call(&"update_race", hud_snapshot)
	_audio.set_motion(float(player_state.get("speed_ratio", 0.0)), bool(player_state.get("boosting", false)), 1.0 - float(player_state.get("armor_ratio", 1.0)), _chassis_tone(String(player_state.get("chassis_id", "biped"))))


func _update_marker_cooldowns(delta: float) -> void:
	for key: String in _marker_cooldowns.keys():
		var remaining := float(_marker_cooldowns[key]) - delta
		if remaining <= 0.0:
			_marker_cooldowns.erase(key)
		else:
			_marker_cooldowns[key] = remaining


func _update_ai_item_cooldowns(delta: float) -> void:
	for racer_id: String in _ai_item_cooldowns.keys():
		var remaining := float(_ai_item_cooldowns[racer_id]) - delta
		if remaining <= 0.0:
			_ai_item_cooldowns.erase(racer_id)
		else:
			_ai_item_cooldowns[racer_id] = remaining


func _chassis_tone(chassis_id: String) -> float:
	match chassis_id:
		"hover", "monowheel": return 1.35
		"tracked", "octopod": return 0.72
		"orb": return 1.18
		"centurion": return 0.86
		_: return 1.0


func _profile() -> Dictionary:
	var save := get_node_or_null("/root/SaveSystem")
	if save == null:
		return {}
	var value: Variant = save.get("profile")
	return value if value is Dictionary else {}
