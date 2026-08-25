extends SceneTree
## Targeted homologation regression suite.
## Run with: godot --headless --path godot --script res://tests/gameplay_safety_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const SessionScript = preload("res://scripts/systems/game_session.gd")
const RacerScript = preload("res://scripts/race/racer_state.gd")
const RaceControllerScript = preload("res://scripts/race/race_controller.gd")
const TrackSafetyScript = preload("res://scripts/world/track_safety.gd")
const RaceHUDScript = preload("res://scripts/ui/race_hud.gd")
const PodiumScene = preload("res://scenes/components/podium_presenter.tscn")
const MIN_TOUCH_TARGET := 88.0

class ProfileStub:
	extends Node
	var profile: Dictionary = {}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_runtime_homologation()
	_test_ai_passing_target()
	_test_classification_contract()
	_test_championship_dnf_contract()
	await _test_mobile_control_geometry()
	if _failures.is_empty():
		print("MECHA GAMEPLAY SAFETY: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("MECHA GAMEPLAY SAFETY: %s" % failure)
	quit(1)


func _test_runtime_homologation() -> void:
	var save: Node = get_root().get_node_or_null("SaveSystem")
	var owns_save := save == null
	if save == null:
		save = ProfileStub.new()
		save.name = &"SaveSystem"
		get_root().add_child(save)
	var original_profile: Dictionary = {}
	var current_profile: Variant = save.get("profile")
	if current_profile is Dictionary:
		original_profile = Dictionary(current_profile).duplicate(true)
	var test_profile := {
		"selected_chassis": "biped",
		"pilot_name": "PILOTE TEST",
		"paints": {},
		"loadouts": {},
		"locomotions": {},
		"upgrades": {},
		"settings": {"camera_view": "tps", "reduced_motion": true},
	}
	save.set("profile", test_profile)
	var controller: Node = RaceControllerScript.new()
	get_root().add_child(controller)
	controller.call(&"start", {
		"mode": "quick",
		"track_id": "foundry",
		"difficulty": "ace",
		"laps": 1,
		"racer_count": 8,
		"division_id": "command",
		"grid_policy": "division",
		"performance_class_id": "tuned",
	})

	var width := float(controller.get("_track_width"))
	_expect(width >= TrackSafetyScript.minimum_road_width(), "la largeur runtime doit respecter l'homologation")
	_expect(TrackSafetyScript.passing_columns(width) >= TrackSafetyScript.REQUIRED_SIDE_BY_SIDE, "le circuit doit offrir trois colonnes de dépassement")
	var racers: Array = controller.get("_racers")
	_expect(racers.size() == 8, "la grille homologuée doit contenir huit concurrents")
	var row_counts: Dictionary = {}
	var snapshots: Array[Dictionary] = []
	for index in range(racers.size()):
		var racer: RefCounted = racers[index]
		var state: Dictionary = racer.call(&"snapshot")
		snapshots.append(state)
		var expected_distance := TrackSafetyScript.grid_distance(index)
		row_counts[expected_distance] = int(row_counts.get(expected_distance, 0)) + 1
		_expect(is_equal_approx(float(state.get("distance", 99.0)), expected_distance), "distance de grille invalide au rang %d" % index)
		_expect(is_equal_approx(float(state.get("lane", 99.0)), TrackSafetyScript.grid_lane(index)), "couloir de grille invalide au rang %d" % index)
		_expect(float(state.get("track_width", 0.0)) == width, "la largeur physique doit atteindre chaque RacerState")
		_expect(float(state.get("vehicle_width", 0.0)) > 0.0 and float(state.get("vehicle_length", 0.0)) > 0.0, "le gabarit véhicule doit être publié dans les snapshots")
	_expect(row_counts.size() == 4, "la grille 2x4 doit utiliser exactement quatre rangées")
	for row_distance: Variant in row_counts.keys():
		_expect(int(row_counts[row_distance]) == 2, "chaque rangée de grille doit contenir deux concurrents")
	if snapshots.size() >= 2:
		var first_grid := snapshots[0]
		var second_grid := snapshots[1]
		var grid_gap := TrackSafetyScript.lateral_gap_meters(float(first_grid.get("lane", 0.0)), float(second_grid.get("lane", 0.0)), width)
		var required_gap := (float(first_grid.get("vehicle_width", 0.0)) + float(second_grid.get("vehicle_width", 0.0))) * 0.5 + TrackSafetyScript.PASSING_GAP_METERS
		_expect(grid_gap >= required_gap, "la première ligne doit séparer physiquement les deux gabarits")

	_expect(bool(controller.get("_reduced_motion")), "le réglage reduced motion doit atteindre la course")
	var visuals: Dictionary = controller.get("_visuals")
	var player_visual: Node = visuals.get("player") as Node
	_expect(player_visual != null and bool(player_visual.get("reduced_motion")), "le mecha de course doit couper rebond et inclinaison en reduced motion")

	var player: RefCounted = controller.get("_player") as RefCounted
	var ace_speed := float(DatabaseScript.get_difficulty("ace").get("speed", 1.0))
	_expect(is_equal_approx(float(controller.call(&"_simulation_speed_multiplier", player.call(&"snapshot"), ace_speed)), 1.0), "la difficulté IA ne doit jamais accélérer le joueur")
	if racers.size() >= 2:
		var rival: RefCounted = racers[1]
		var rival_state: Dictionary = rival.call(&"snapshot")
		var expected_ai := clampf(ace_speed * float(controller.call(&"_bounded_ai_catchup", rival_state)), 0.25, 1.75)
		_expect(is_equal_approx(float(controller.call(&"_simulation_speed_multiplier", rival_state, ace_speed)), expected_ai), "la difficulté doit rester active pour les rivaux")

	var rookie_player: RacerState = RacerScript.new().configure({"racer_id": "rookie_player", "is_player": true, "difficulty": "rookie", "track_length": 500.0, "total_laps": 1})
	var ace_player: RacerState = RacerScript.new().configure({"racer_id": "ace_player", "is_player": true, "difficulty": "ace", "track_length": 500.0, "total_laps": 1})
	var controls := {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "drift": false, "boost": false}
	for tick in range(240):
		var elapsed := float(tick + 1) / 120.0
		var common := {"elapsed": elapsed, "race_active": true, "grip": 1.0, "curvature": 0.0, "hazard": ""}
		var rookie_context := common.duplicate(true)
		rookie_context["speed_multiplier"] = controller.call(&"_simulation_speed_multiplier", rookie_player.snapshot(), float(DatabaseScript.get_difficulty("rookie").get("speed", 1.0)))
		var ace_context := common.duplicate(true)
		ace_context["speed_multiplier"] = controller.call(&"_simulation_speed_multiplier", ace_player.snapshot(), ace_speed)
		rookie_player.step(1.0 / 120.0, controls, rookie_context)
		ace_player.step(1.0 / 120.0, controls, ace_context)
	_expect(is_equal_approx(rookie_player.distance, ace_player.distance), "un même pilotage doit produire le même chrono à toutes les difficultés")

	if racers.size() >= 2:
		var first: RacerState = racers[0] as RacerState
		var second: RacerState = racers[1] as RacerState
		var first_armor := first.armor
		var second_armor := second.armor
		controller.call(&"_resolve_close_contacts")
		_expect(is_equal_approx(first.armor, first_armor) and is_equal_approx(second.armor, second_armor), "deux gabarits séparés sur la grille ne doivent pas entrer en collision")
		first.distance = 0.0
		second.distance = 0.0
		first.lane = 0.0
		second.lane = 0.0
		controller.call(&"_resolve_close_contacts")
		_expect(first.armor < first_armor and second.armor < second_armor, "des enveloppes physiques superposées doivent produire un contact")

	controller.free()
	if owns_save:
		save.free()
	else:
		save.set("profile", original_profile)


func _test_ai_passing_target() -> void:
	var spec := {
		"chassis_id": "biped",
		"pilot_id": "iris",
		"difficulty": "ace",
		"track_length": 800.0,
		"track_width": TrackSafetyScript.minimum_road_width(),
		"total_laps": 2,
		"seed": 31337,
	}
	var first: RacerState = RacerScript.new().configure(spec.merged({"racer_id": "pass_a"}, true))
	var second: RacerState = RacerScript.new().configure(spec.merged({"racer_id": "pass_b"}, true))
	first.distance = 100.0
	second.distance = 100.0
	first.lane = -0.10
	second.lane = -0.10
	first.speed = first.top_speed * 0.70
	second.speed = second.top_speed * 0.70
	var traffic_lane := 0.0
	var traffic_width := first.vehicle_width
	var required_delta := ((first.vehicle_width + traffic_width) * 0.5 + TrackSafetyScript.PASSING_GAP_METERS) / (first.track_width * TrackSafetyScript.LANE_SCALE)
	var ai_limit := maxf(0.46, first.lane_limit - 0.05)
	var explicit_target := float(first.call(&"_passing_target_lane", traffic_lane, required_delta, ai_limit, 2))
	_expect(is_equal_approx(explicit_target, traffic_lane - required_delta), "la cible de dépassement doit être ancrée au couloir du trafic")
	var context := {
		"position": 2,
		"curvature": 0.0,
		"curvature_ahead": 0.0,
		"curvature_far": 0.0,
		"hazard": "",
		"hazard_ahead": "",
		"hazard_far": "",
		"racers": [{"racer_id": "obstacle", "distance": 110.0, "lane": traffic_lane, "vehicle_width": traffic_width, "finished": false, "dnf": false, "eliminated": false}],
	}
	var first_controls: Dictionary = first.ai_controls(context)
	var second_controls: Dictionary = second.ai_controls(context)
	_expect(float(first_controls.get("steer", 0.0)) < 0.0, "l'IA placée à gauche doit dépasser par la gauche")
	_expect(is_equal_approx(float(first_controls.get("steer", 0.0)), float(second_controls.get("steer", 1.0))), "le choix de dépassement doit rester déterministe")
	first.lane = explicit_target - 0.12
	var held_target := float(first.call(&"_passing_target_lane", traffic_lane, required_delta, ai_limit, 2))
	_expect(held_target <= first.lane + 0.0001, "une IA déjà dégagée ne doit pas revenir vers l'obstacle")
	first.lane = 0.10
	var right_target := float(first.call(&"_passing_target_lane", traffic_lane, required_delta, ai_limit, 2))
	_expect(is_equal_approx(right_target, traffic_lane + required_delta), "l'IA placée à droite doit viser explicitement la droite du trafic")


func _test_mobile_control_geometry() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	get_root().add_child(viewport)
	var hud: Control = RaceHUDScript.new()
	viewport.add_child(hud)
	await process_frame
	hud.call(&"configure", {"mode": "quick", "track_id": "foundry", "racer_count": 8, "force_touch_controls": true})
	await process_frame
	await process_frame
	var controls: Control = hud.get("_mobile_controls") as Control
	_expect(controls != null and controls.visible, "la surface tactile forcée doit être visible")
	var bottom_panel: Control = hud.get("_bottom_panel") as Control
	var mobile_status_panel: Control = hud.get("_mobile_status_panel") as Control
	_expect(bottom_panel != null and not bottom_panel.visible, "le grand HUD inférieur doit disparaître en tactile")
	_expect(mobile_status_panel != null and mobile_status_panel.visible, "la télémétrie tactile compacte doit remplacer le grand HUD")
	if controls != null and mobile_status_panel != null:
		await _assert_mobile_layout(viewport, hud, controls, mobile_status_panel, Vector2i(1280, 720), "paysage 1280x720")
		await _assert_mobile_layout(viewport, hud, controls, mobile_status_panel, Vector2i(844, 390), "paysage compact 844x390")
		await _assert_mobile_layout(viewport, hud, controls, mobile_status_panel, Vector2i(390, 844), "portrait 390x844")
	var top_left_panel: Control = hud.get("_top_left_panel") as Control
	_expect(top_left_panel != null and not top_left_panel.visible, "le panneau piste doit se compacter en portrait tactile")
	viewport.free()
func _assert_mobile_layout(viewport: SubViewport, hud: Control, controls: Control, telemetry: Control, viewport_size: Vector2i, layout_name: String) -> void:
	viewport.size = viewport_size
	await process_frame
	await process_frame
	controls.call(&"_layout_controls")
	hud.call(&"_layout_mobile_status")
	await process_frame
	var regions: Dictionary = controls.call(&"control_regions")
	_assert_regions_do_not_overlap(regions, layout_name)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	for region_name: String in ["steering", "actions", "utilities"]:
		var region: Rect2 = regions.get(region_name, Rect2())
		_expect(_rect_inside(region, viewport_rect), "zone tactile %s %s hors viewport %s en %s" % [region_name, region, viewport_rect, layout_name])
	var buttons: Dictionary = controls.get("_buttons")
	for action: Variant in buttons.keys():
		var button: Button = buttons[action] as Button
		_expect(button != null and button.size.x >= MIN_TOUCH_TARGET and button.size.y >= MIN_TOUCH_TARGET, "cible tactile %s inférieure à 88 px en %s" % [String(action), layout_name])
	var telemetry_rect := Rect2(telemetry.position, telemetry.size)
	_expect(telemetry.visible and telemetry_rect.size.x > 0.0 and telemetry_rect.size.y > 0.0, "télémétrie absente en %s" % layout_name)
	_expect(_rect_inside(telemetry_rect, viewport_rect), "télémétrie %s hors viewport %s en %s" % [telemetry_rect, viewport_rect, layout_name])
	_expect(telemetry_rect.size.x >= 180.0, "télémétrie trop étroite en %s : %s" % [layout_name, telemetry_rect])
	_expect(telemetry_rect.size.y <= 96.0, "télémétrie trop haute en %s : %s" % [layout_name, telemetry_rect])
	_expect(telemetry_rect.size.y <= float(viewport_size.y) * 0.22, "télémétrie supérieure à 22%% du viewport en %s : %s" % [layout_name, telemetry_rect])
	if viewport_size == Vector2i(844, 390):
		var steering: Rect2 = regions.get("steering", Rect2())
		var actions: Rect2 = regions.get("actions", Rect2())
		_expect(
			telemetry_rect.position.x >= steering.end.x and telemetry_rect.end.x <= actions.position.x,
			"télémétrie hors gutter steering/actions en %s : %s" % [layout_name, telemetry_rect]
		)
	for region_name: String in ["steering", "actions", "utilities"]:
		var region: Rect2 = regions.get(region_name, Rect2())
		_expect(not telemetry_rect.intersects(region), "télémétrie superposée à %s en %s" % [region_name, layout_name])


func _assert_regions_do_not_overlap(regions: Dictionary, layout_name: String) -> void:
	var names: Array[String] = ["steering", "actions", "utilities"]
	for first_index in range(names.size()):
		var first: Rect2 = regions.get(names[first_index], Rect2())
		_expect(first.size.x > 0.0 and first.size.y > 0.0, "zone tactile %s absente en %s" % [names[first_index], layout_name])
		for second_index in range(first_index + 1, names.size()):
			var second: Rect2 = regions.get(names[second_index], Rect2())
			_expect(not first.intersects(second), "zones tactiles %s/%s superposées en %s" % [names[first_index], names[second_index], layout_name])
func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.size.x > 0.0 and inner.size.y > 0.0 and outer.encloses(inner)





func _test_classification_contract() -> void:
	var controller: Node = RaceControllerScript.new()
	controller.set("_config", {"mode": "quick"})
	controller.set("_elapsed", 70.0)
	var entries: Array[Dictionary] = [
		{"racer_id": "player", "is_player": true, "distance": 1000.0, "finished": true, "finish_time": 70.0, "dnf": false, "eliminated": false},
		{"racer_id": "iris", "distance": 1000.0, "finished": true, "finish_time": 72.0, "dnf": false, "eliminated": false},
		{"racer_id": "brakk", "distance": 900.0, "finished": false, "finish_time": 0.0, "dnf": true, "eliminated": false},
	]
	controller.set("_snapshots", entries)
	controller.call(&"_prepare_official_classification", entries[0])
	var official: Array = controller.get("_snapshots")
	_expect(official.size() == 3, "le classement officiel doit conserver tous les concurrents")
	if official.size() == 3:
		_expect(is_equal_approx(float(Dictionary(official[0]).get("elapsed", 0.0)), 70.0) and is_equal_approx(float(Dictionary(official[0]).get("finish_time", 0.0)), 70.0), "le temps du leader doit être normalisé")
		_expect(String(Dictionary(official[0]).get("delta", "")) == "—", "le leader chronométré doit avoir un écart neutre")
		_expect(String(Dictionary(official[1]).get("delta", "")) == "+2.000 s", "l'écart arrivée doit être calculé depuis finish_time")
		_expect(String(Dictionary(official[2]).get("delta", "")) == "DNF" and not bool(Dictionary(official[2]).get("classified", false)), "un abandon ne doit jamais être classé")
	var dnf_entries: Array[Dictionary] = [
		{"racer_id": "player", "is_player": true, "distance": 2000.0, "finished": false, "finish_time": 0.0, "dnf": false, "eliminated": false},
		{"racer_id": "iris", "distance": 900.0, "finished": false, "finish_time": 0.0, "dnf": false, "eliminated": false},
		{"racer_id": "vex", "distance": 800.0, "finished": false, "finish_time": 0.0, "dnf": false, "eliminated": false},
		{"racer_id": "brakk", "distance": 700.0, "finished": false, "finish_time": 0.0, "dnf": false, "eliminated": true},
	]
	controller.set("_snapshots", dnf_entries)
	controller.call(&"_prepare_official_classification", {
		"racer_id": "player", "is_player": true, "distance": 2000.0,
		"finished": false, "dnf": true, "eliminated": false, "reason": "test_dnf",
	})
	var dnf_official: Array = controller.get("_snapshots")
	_expect(dnf_official.size() == 4, "le classement DNF doit conserver les quatre concurrents")
	if dnf_official.size() == 4:
		_expect(String(Dictionary(dnf_official[0]).get("racer_id", "")) == "iris" and int(Dictionary(dnf_official[0]).get("position", 0)) == 1 and bool(Dictionary(dnf_official[0]).get("classified", false)), "le premier rival éligible doit devenir vainqueur officiel")
		_expect(String(Dictionary(dnf_official[1]).get("racer_id", "")) == "vex" and bool(Dictionary(dnf_official[1]).get("classified", false)), "tous les rivaux actifs doivent précéder le DNF")
		_expect(String(Dictionary(dnf_official[2]).get("racer_id", "")) == "player" and int(Dictionary(dnf_official[2]).get("position", 0)) == 3 and not bool(Dictionary(dnf_official[2]).get("classified", true)), "le joueur DNF en tête de piste doit être démoté derrière les éligibles")
		_expect(String(Dictionary(dnf_official[3]).get("racer_id", "")) == "brakk" and not bool(Dictionary(dnf_official[3]).get("classified", true)), "un éliminé doit rester hors classement")
	controller.free()


func _test_championship_dnf_contract() -> void:
	var session: GameSessionService = SessionScript.new()
	session.configure({"mode": "grand_prix", "championship_id": "command_cup", "new_championship": true, "difficulty": "pilot", "laps": 1, "seed": 9201})
	var championship: Dictionary = session.get("championship")
	var entrants: Array = championship.get("entrants", [])
	var ai_ids: Array[String] = []
	for entrant_value: Variant in entrants:
		if entrant_value is Dictionary:
			var entrant_id := String(Dictionary(entrant_value).get("id", ""))
			if entrant_id != "player":
				ai_ids.append(entrant_id)
	_expect(ai_ids.size() >= 3, "le championnat de test doit fournir trois rivaux")
	if ai_ids.size() < 3:
		session.free()
		return
	var controller: Node = RaceControllerScript.new()
	controller.set("_config", {"mode": "grand_prix"})
	controller.set("_elapsed", 72.50)
	var official_source: Array[Dictionary] = [
		{"racer_id": "player", "is_player": true, "distance": 2000.0, "finished": false, "finish_time": 0.0, "dnf": false, "eliminated": false},
		{"racer_id": ai_ids[0], "distance": 1900.0, "finished": false, "finish_time": 0.0, "dnf": false, "eliminated": true},
		{"racer_id": ai_ids[1], "distance": 1000.0, "finished": true, "finish_time": 71.25, "dnf": false, "eliminated": false},
		{"racer_id": ai_ids[2], "distance": 1000.0, "finished": true, "finish_time": 72.50, "dnf": false, "eliminated": false},
	]
	var finish_order: Array[String] = [ai_ids[1], ai_ids[2]]
	controller.set("_finish_order", finish_order)
	controller.set("_snapshots", official_source)
	controller.call(&"_prepare_official_classification", {
		"racer_id": "player", "is_player": true, "distance": 2000.0,
		"finished": false, "dnf": true, "eliminated": false, "reason": "championship_test_dnf",
	})
	var official: Array = controller.get("_snapshots")
	_expect(official.size() == 4 and String(Dictionary(official[0]).get("racer_id", "")) == ai_ids[1] and int(Dictionary(official[0]).get("position", 0)) == 1, "le rival arrivé doit gagner malgré la distance supérieure du joueur DNF")
	var podium: Node = PodiumScene.instantiate()
	get_root().add_child(podium)
	podium.call(&"present", official, 3, true, "grand_prix")
	var podium_top: Array = podium.call(&"top_three")
	_expect(not podium_top.is_empty() and String(Dictionary(podium_top[0]).get("racer_id", "")) == ai_ids[1], "le podium doit couronner le premier classé éligible")
	podium.free()
	var result := session.complete_race({
		"finished": false,
		"dnf": true,
		"position": 3,
		"elapsed": 72.50,
		"classification": official,
	})
	var updated_championship: Dictionary = session.get("championship")
	_expect(int(result.get("points", -1)) == 0 and _entrant_points(updated_championship, "player") == 0, "un joueur DNF ne doit recevoir aucun point")
	_expect(_entrant_points(updated_championship, ai_ids[0]) == 0, "un concurrent éliminé ne doit recevoir aucun point")
	_expect(_entrant_points(updated_championship, ai_ids[1]) == int(DatabaseScript.CHAMPIONSHIP_POINTS[0]), "le champion du podium doit recevoir les points de victoire")
	_expect(_entrant_points(updated_championship, ai_ids[2]) == int(DatabaseScript.CHAMPIONSHIP_POINTS[1]), "le deuxième classé doit recevoir les points de deuxième place")
	var classification: Array = result.get("classification", [])
	if classification.size() >= 2:
		var winner: Dictionary = classification[0]
		var runner_up: Dictionary = classification[1]
		_expect(String(winner.get("racer_id", "")) == ai_ids[1] and int(winner.get("position", 0)) == 1, "le vainqueur Results doit rester le champion crédité")
		_expect(is_equal_approx(float(runner_up.get("finish_time", 0.0)), 72.50) and is_equal_approx(float(runner_up.get("elapsed", 0.0)), 72.50), "GameSession doit conserver finish_time et elapsed normalisés")
		_expect(String(runner_up.get("delta", "")) == "+1.250 s" and String(runner_up.get("gap", "")) == "+1.250 s", "GameSession doit conserver un écart unique")
	controller.free()
	session.free()


func _entrant_points(championship: Dictionary, racer_id: String) -> int:
	for entrant_value: Variant in championship.get("entrants", []):
		if entrant_value is Dictionary and String(Dictionary(entrant_value).get("id", "")) == racer_id:
			return int(Dictionary(entrant_value).get("points", 0))
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
