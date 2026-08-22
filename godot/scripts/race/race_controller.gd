class_name RaceController
extends Node3D

## Complete arcade race loop for the reconstructed Godot branch.
## The simulation runs at a fixed step, while procedural visuals interpolate at
## display rate. This keeps pickups, AI and finishing rules frame independent.

signal race_finished(result: Dictionary)
signal menu_requested

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

var _config: Dictionary = {}
var _track: Node3D
var _track_length := 1.0
var _racers: Array = []
var _visuals: Dictionary = {}
var _snapshots: Array[Dictionary] = []
var _player: RefCounted
var _camera: Camera3D
var _hud: Node
var _audio: AudioDirector
var _accumulator := 0.0
var _elapsed := 0.0
var _countdown := 3.5
var _running := false
var _finished := false
var _paused := false
var _item_was_pressed := false
var _next_elimination := ELIMINATION_START
var _marker_cooldowns: Dictionary = {}
var _finish_order: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_unhandled_input(true)


func start(request: Dictionary) -> void:
	_config = request.duplicate(true)
	_build_track()
	_build_racers()
	_build_camera()
	_build_feedback()
	_update_racer_visuals(0.0)
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
	elif event.is_action_pressed(&"race_reset") and _running and _player != null:
		var snapshot: Dictionary = _player.call(&"snapshot")
		if bool(_player.call(&"can_reset")):
			_player.call(&"reset_to_checkpoint", maxf(0.0, float(snapshot.get("distance", 0.0)) - 15.0), 0.0)
			_audio.play_event("shield")
		get_viewport().set_input_as_handled()


func _step_simulation(delta: float) -> void:
	_elapsed += delta
	_update_marker_cooldowns(delta)
	var base_context := _race_context()
	_snapshots.clear()

	for racer in _racers:
		var before: Dictionary = racer.call(&"snapshot")
		if bool(before.get("finished", false)) or bool(before.get("dnf", false)) or bool(before.get("eliminated", false)):
			_snapshots.append(before)
			continue
		var controls := _player_controls() if bool(before.get("is_player", false)) else racer.call(&"ai_controls", base_context)
		var context := base_context.duplicate(true)
		context["curvature"] = _curvature_at(float(before.get("distance", 0.0)))
		context["hazard"] = _hazard_at(float(before.get("distance", 0.0)))
		var after: Dictionary = racer.call(&"step", delta, controls, context)
		_process_marker_contact(racer, after)
		if bool(after.get("finished", false)):
			var racer_id := String(after.get("racer_id", ""))
			if not racer_id in _finish_order:
				_finish_order.append(racer_id)
		_snapshots.append(after)

	_resolve_close_contacts()
	_sort_and_rank_snapshots()
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


func _apply_item(source: RefCounted, item_id: String) -> void:
	var source_state: Dictionary = source.call(&"snapshot")
	var source_distance := float(source_state.get("distance", 0.0))
	var source_lane := float(source_state.get("lane", 0.0))
	match item_id:
		"repair":
			source.call(&"apply_hit", -28.0, 0.0)
		"shield", "overdrive":
			pass # Timed defensive/mobility effects are activated inside RacerState.use_item().
		"emp", "shockwave":
			for target in _racers:
				if target == source:
					continue
				var state: Dictionary = target.call(&"snapshot")
				if absf(float(state.get("distance", 0.0)) - source_distance) < 24.0:
					target.call(&"apply_hit", 10.0 if item_id == "emp" else 16.0, signf(float(state.get("lane", 0.0)) - source_lane) * 0.35)
		"mine":
			var target := _nearest_racer(source, false, 18.0)
			if target != null:
				target.call(&"apply_hit", 18.0, 0.48)
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


func _process_marker_contact(racer: RefCounted, snapshot: Dictionary) -> void:
	var distance := float(snapshot.get("distance", 0.0))
	var lap_distance := fposmod(distance, _track_length)
	var lane := float(snapshot.get("lane", 0.0))
	for marker in TrackFactoryType.gameplay_markers(_track):
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
			var item: Dictionary = GameDatabase.ITEMS[(String(snapshot.get("racer_id", "0")).hash() + roundi(distance)) % GameDatabase.ITEMS.size()]
			racer.call(&"grant_item", String(item.get("id", "overdrive")))
			if racer == _player:
				_audio.play_event("pickup")
		else:
			# The pad is represented as a short-lived overdrive cell.
			racer.call(&"grant_item", "overdrive")
			var used := String(racer.call(&"use_item"))
			if racer == _player and not used.is_empty():
				_audio.play_event("boost")


func _resolve_close_contacts() -> void:
	for first_index in range(_racers.size()):
		var first := _racers[first_index]
		var a: Dictionary = first.call(&"snapshot")
		if bool(a.get("dnf", false)) or bool(a.get("finished", false)):
			continue
		for second_index in range(first_index + 1, _racers.size()):
			var second := _racers[second_index]
			var b: Dictionary = second.call(&"snapshot")
			if bool(b.get("dnf", false)) or bool(b.get("finished", false)):
				continue
			if absf(float(a.get("distance", 0.0)) - float(b.get("distance", 0.0))) < 1.65 and absf(float(a.get("lane", 0.0)) - float(b.get("lane", 0.0))) < 0.18:
				var direction := -1.0 if float(a.get("lane", 0.0)) < float(b.get("lane", 0.0)) else 1.0
				first.call(&"apply_hit", 0.018, direction * 0.04)
				second.call(&"apply_hit", 0.018, -direction * 0.04)


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
	_next_elimination += ELIMINATION_INTERVAL
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
	elif _elapsed >= MAX_RACE_SECONDS:
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
	return GRID_SIZE


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
	match String(_config.get("track_id", "foundry")):
		"glacier": return 0.82
		"dunes": return 0.91
		"orbital": return 0.88
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
	return String(hazards[section % hazards.size()]) if section % 4 == 2 else ""


func _build_track() -> void:
	var track_spec := GameDatabase.get_track(String(_config.get("track_id", "foundry")))
	_track = TrackFactoryType.build(track_spec)
	add_child(_track)
	_track_length = TrackFactoryType.track_length(_track)


func _build_racers() -> void:
	var profile := _profile()
	var selected_id := String(profile.get("selected_chassis", "biped"))
	var selected_paint := Color(String(profile.get("paint", GameDatabase.get_chassis(selected_id).get("paint", "#5EE7FF"))))
	var chassis_entries := GameDatabase.get_all_chassis()
	var pilots := GameDatabase.get_all_pilots()
	var player_index := 0
	for index in range(GRID_SIZE):
		var is_player := index == player_index
		var chassis: Dictionary = GameDatabase.get_chassis(selected_id) if is_player else chassis_entries[(index + 2) % chassis_entries.size()]
		var pilot: Dictionary = pilots[0] if is_player else pilots[(index + 1) % pilots.size()]
		var racer := RacerStateType.new()
		var spec := {
			"racer_id": "player" if is_player else "rival_%02d" % index,
			"display_name": String(profile.get("pilot_name", "PILOTE 01")) if is_player else String(pilot.get("callsign", pilot.get("name", "RIVAL"))),
			"chassis_id": String(chassis.get("id", "biped")),
			"pilot_id": String(pilot.get("id", "vex")),
			"is_player": is_player,
			"difficulty": String(_config.get("difficulty", "pilot")),
			"track_length": _track_length,
			"total_laps": int(_config.get("laps", 3)),
			"upgrades": _player_upgrades(profile, selected_id) if is_player else {},
			"grid_index": index,
			"seed": String(_config.get("track_id", "foundry")).hash() + index * 733,
		}
		racer.call(&"configure", spec)
		_racers.append(racer)
		if is_player:
			_player = racer
		var paint := selected_paint if is_player else Color(String(pilot.get("paint", chassis.get("paint", "#5EE7FF"))))
		var visual: RacerVisual = MechaFactoryType.build(chassis, paint, is_player)
		visual.name = String(spec["racer_id"])
		add_child(visual)
		_visuals[String(spec["racer_id"])] = visual


func _player_upgrades(profile: Dictionary, chassis_id: String) -> Dictionary:
	var all_upgrades: Variant = profile.get("upgrades", {})
	if all_upgrades is Dictionary:
		var selected: Variant = all_upgrades.get(chassis_id, all_upgrades)
		if selected is Dictionary:
			return selected.duplicate(true)
	return {}


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ChaseCamera"
	_camera.current = true
	_camera.fov = 72.0
	add_child(_camera)


func _build_feedback() -> void:
	_audio = AudioDirectorType.new()
	add_child(_audio)
	_audio.configure(_profile().get("settings", {}))
	_hud = RaceHUDType.new()
	add_child(_hud)


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
	var pose := TrackFactoryType.sample_pose(_track, float(state.get("distance", 0.0)), float(state.get("lane", 0.0)))
	var forward := -pose.basis.z.normalized()
	var target_position := pose.origin - forward * 12.5 + Vector3.UP * 6.1
	var look_target := pose.origin + forward * (10.0 + float(state.get("speed_ratio", 0.0)) * 7.0) + Vector3.UP * 1.8
	var weight := 1.0 - exp(-delta * 6.5)
	_camera.global_position = _camera.global_position.lerp(target_position, weight)
	var next_basis := _camera.global_transform.looking_at(look_target, Vector3.UP, true).basis
	_camera.global_basis = _camera.global_basis.slerp(next_basis, weight)
	_camera.fov = lerpf(_camera.fov, 72.0 + minf(10.0, float(state.get("speed_ratio", 0.0)) * 5.5), weight)


func _update_feedback() -> void:
	if _player == null:
		return
	var player_state: Dictionary = _player.call(&"snapshot")
	if _hud != null and _hud.has_method(&"update_race"):
		var hud_snapshot := player_state.duplicate(true)
		hud_snapshot["elapsed"] = _elapsed
		hud_snapshot["position"] = _player_position()
		hud_snapshot["racer_count"] = GRID_SIZE
		hud_snapshot["mode"] = String(_config.get("mode", "quick"))
		hud_snapshot["next_elimination"] = maxf(0.0, _next_elimination - _elapsed)
		_hud.call(&"update_race", hud_snapshot)
	_audio.set_motion(float(player_state.get("speed_ratio", 0.0)), bool(player_state.get("boosting", false)), 1.0 - float(player_state.get("armor_ratio", 1.0)), _chassis_tone(String(player_state.get("chassis_id", "biped"))))


func _update_marker_cooldowns(delta: float) -> void:
	for key in _marker_cooldowns.keys():
		var remaining := float(_marker_cooldowns[key]) - delta
		if remaining <= 0.0:
			_marker_cooldowns.erase(key)
		else:
			_marker_cooldowns[key] = remaining


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
