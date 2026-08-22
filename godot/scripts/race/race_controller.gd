class_name RaceController
extends Node3D

## Complete arcade race loop for the reconstructed Godot branch.
## The simulation runs at a fixed step, while procedural visuals interpolate at
## display rate. This keeps pickups, AI and finishing rules frame independent.

signal race_finished(result: Dictionary)
signal menu_requested
signal retry_requested(config: Dictionary)

const TrackFactoryType := preload("res://scripts/world/track_factory.gd")
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

var _config: Dictionary = {}
var _track: Node3D
var _track_length := 1.0
var _racers: Array[RefCounted] = []
var _visuals: Dictionary[String, RacerVisual] = {}
var _snapshots: Array[Dictionary] = []
var _player: RefCounted
var _camera: Camera3D
var _camera_mode := "tps"
var _hud: RaceHUD
var _audio: AudioDirector
var _accumulator := 0.0
var _elapsed := 0.0
var _countdown := 3.5
var _running := false
var _finished := false
var _paused := false
var _item_was_pressed := false
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
	if _hud != null and _hud.has_method(&"show_countdown"):
		_hud.call(&"show_countdown", 3)


func _process(delta: float) -> void:
	if _finished or _track == null:
		return
	if _paused:
		_update_camera(delta)
		return

	if _countdown > 0.0:
		var previous_second := ceili(_countdown)
		_countdown -= delta
		var next_second := ceili(maxf(0.0, _countdown))
		if next_second != previous_second:
			if _hud != null and _hud.has_method(&"show_countdown"):
				_hud.call(&"show_countdown", next_second)
			_audio.play_event("go" if next_second == 0 else "count")
		if _countdown <= 0.0:
			_running = true
		_update_camera(delta)
		return

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
		var snapshot: Dictionary = _player.call(&"snapshot")
		if bool(_player.call(&"can_reset")):
			_player.call(&"reset_to_checkpoint", maxf(0.0, float(snapshot.get("distance", 0.0)) - 15.0), 0.0)
			_audio.play_event("shield")
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
		context["curvature"] = _curvature_at(float(before.get("distance", 0.0)))
		context["hazard"] = _hazard_at(float(before.get("distance", 0.0)))
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
	var steer := Input.get_action_strength(&"race_right") - Input.get_action_strength(&"race_left")
	return {
		"throttle": Input.get_action_strength(&"race_accelerate"),
		"brake": Input.get_action_strength(&"race_brake"),
		"steer": clampf(steer, -1.0, 1.0),
		"drift": Input.is_action_pressed(&"race_drift"),
		"boost": Input.is_action_pressed(&"race_boost"),
	}


func _handle_item_input() -> void:
	var pressed := Input.is_action_pressed(&"race_item")
	if pressed and not _item_was_pressed and _player != null:
		var item_id := String(_player.call(&"use_item"))
		if not item_id.is_empty():
			_apply_item(_player, item_id)
	_item_was_pressed = pressed


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
	var gap_ahead := _nearest_racer_gap(source, 1, 108.0)
	var gap_behind := _nearest_racer_gap(source, -1, 28.0)
	var nearby_count := _nearby_racer_count(source, 24.0)
	match item_id:
		"repair":
			return armor_ratio <= 0.66
		"shield":
			var threatened := gap_ahead <= 24.0 or gap_behind <= 24.0
			return not bool(state.get("shielded", false)) and armor_ratio <= 0.82 and (threatened or armor_ratio <= 0.48)
		"overdrive":
			var on_straight := absf(_curvature_at(distance)) <= STRAIGHT_CURVATURE_LIMIT
			var needs_energy := float(state.get("boost_energy", 0.0)) <= 0.72
			return on_straight and speed_ratio >= 0.45 and float(state.get("heat_ratio", 0.0)) < 0.88 and (needs_energy or rank > 1)
		"emp", "shockwave":
			# Chasers attack a nearby racer ahead; leaders only fire defensively
			# against a close pursuer or when the pack is clustered.
			return nearby_count >= 2 or (rank > 1 and gap_ahead <= 24.0) or (rank == 1 and gap_behind <= 12.0)
		"mine":
			return gap_behind <= 18.0
		"ion":
			return rank > 1 and gap_ahead <= 72.0
		"rail":
			return rank > 1 and gap_ahead <= 108.0
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
		if bool(a.get("dnf", false)) or bool(a.get("finished", false)):
			continue
		for second_index in range(first_index + 1, _racers.size()):
			var second: RefCounted = _racers[second_index]
			var b: Dictionary = second.call(&"snapshot")
			if bool(b.get("dnf", false)) or bool(b.get("finished", false)):
				continue
			if absf(float(a.get("distance", 0.0)) - float(b.get("distance", 0.0))) < 1.65 and absf(float(a.get("lane", 0.0)) - float(b.get("lane", 0.0))) < 0.18:
				var direction := -1.0 if float(a.get("lane", 0.0)) < float(b.get("lane", 0.0)) else 1.0
				var first_strength := float(first.call(&"contact_damage_multiplier"))
				var second_strength := float(second.call(&"contact_damage_multiplier"))
				# Each chassis authors the damage and shove it deals to the rival.
				first.call(&"apply_hit", 0.018 * second_strength, direction * 0.04 * second_strength)
				second.call(&"apply_hit", 0.018 * first_strength, -direction * 0.04 * first_strength)


func _sort_and_rank_snapshots() -> void:
	_snapshots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_finished := String(a.get("racer_id", "")) in _finish_order
		var b_finished := String(b.get("racer_id", "")) in _finish_order
		if a_finished and b_finished:
			return _finish_order.find(String(a.get("racer_id", ""))) < _finish_order.find(String(b.get("racer_id", "")))
		if a_finished != b_finished:
			return a_finished
		return float(a.get("distance", 0.0)) > float(b.get("distance", 0.0))
	)
	for index in range(_snapshots.size()):
		_snapshots[index]["position"] = index + 1


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


func _finish_race(player_state: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	_sort_and_rank_snapshots()
	var result := player_state.duplicate(true)
	result["position"] = _player_position()
	result["elapsed"] = _elapsed
	result["track_id"] = String(_config.get("track_id", "foundry"))
	result["mode"] = String(_config.get("mode", "quick"))
	result["finished"] = bool(player_state.get("finished", false)) and not bool(player_state.get("eliminated", false))
	result["dnf"] = not bool(result["finished"])
	result["record_valid"] = bool(result["finished"])
	result["classification"] = _snapshots.duplicate(true)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"complete_race"):
		var normalized: Variant = session.call(&"complete_race", result)
		if normalized is Dictionary:
			result = normalized
	_audio.play_event("finish" if bool(result.get("finished", false)) else "impact")
	if _hud != null:
		_hud.visible = false
	await get_tree().create_timer(0.35, true, false, true).timeout
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
		"racers": _snapshots.duplicate(true),
	}


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
		var loadout := _loadout_for_class(requested_loadout, chassis_id, performance_class_id)
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
			"total_laps": int(_config.get("laps", 3)),
			"upgrades": _player_upgrades(profile, chassis_id, performance_class_id) if is_player else {},
			"module_stats": _module_stats(loadout),
			"grid_index": index,
			"seed": String(_config.get("track_id", "foundry")).hash() + index * 733,
		}
		racer.call(&"configure", spec)
		_racers.append(racer)
		if is_player:
			_player = racer
		var visual: RacerVisual = MechaFactoryType.build(chassis, Color(paint_text), is_player, loadout)
		visual.name = racer_id
		# Animate limbs first, then reapply the authored track elevation.
		# This prevents visual bounce from flattening vertical circuits.
		visual.process_priority = -10
		add_child(visual)
		_visuals[racer_id] = visual


func _player_paint(profile: Dictionary, chassis: Dictionary) -> String:
	var paints: Dictionary = profile.get("paints", {}) if profile.get("paints", {}) is Dictionary else {}
	var chassis_id := String(chassis.get("id", "biped"))
	return String(paints.get(chassis_id, chassis.get("paint", "#5EE7FF")))


func _player_loadout(profile: Dictionary, chassis_id: String) -> Dictionary:
	var loadouts: Dictionary = profile.get("loadouts", {}) if profile.get("loadouts", {}) is Dictionary else {}
	var value: Variant = loadouts.get(chassis_id, {})
	return Dictionary(value).duplicate(true) if value is Dictionary else _default_loadout(chassis_id)


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


func _loadout_for_class(value: Variant, chassis_id: String, performance_class_id: String) -> Dictionary:
	var defaults := _default_loadout(chassis_id)
	var performance_class := GameDatabase.get_performance_class(performance_class_id)
	if String(performance_class.get("module_policy", "all")) == "defaults_only":
		return defaults
	var source: Dictionary = value if value is Dictionary else {}
	for slot_id: String in defaults.keys():
		var option_id := String(source.get(slot_id, defaults[slot_id]))
		if not GameDatabase.get_module_option(slot_id, option_id).is_empty():
			defaults[slot_id] = option_id
	return defaults


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


func _on_hud_pause(paused: bool) -> void:
	_paused = paused


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
	var target_fov := 72.0 + minf(10.0, float(state.get("speed_ratio", 0.0)) * 5.5)
	var anchor: Marker3D = player_visual.camera_anchor(_camera_mode) if player_visual != null and player_visual.has_method(&"camera_anchor") else null
	if anchor != null:
		target_position = anchor.global_position
		forward = -anchor.global_basis.z.normalized()
		if _camera_mode == "fps":
			look_target = target_position + forward * 28.0 + anchor.global_basis.y.normalized() * 0.12
			response = 15.0
			target_fov = 79.0 + minf(5.0, float(state.get("speed_ratio", 0.0)) * 3.0)
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
