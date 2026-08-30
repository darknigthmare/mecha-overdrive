extends SceneTree
## Targeted narrative/progression regression suite.
## Run with: godot --headless --path godot --script res://tests/narrative_progression_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const LoreScript = preload("res://scripts/data/lore_database.gd")
const LocomotionScript = preload("res://scripts/data/locomotion_catalog.gd")
const BroadcastScript = preload("res://scripts/data/race_broadcast.gd")
const SessionScript = preload("res://scripts/systems/game_session.gd")
const SaveScript = preload("res://scripts/systems/save_system.gd")
const MainMenuScene = preload("res://scenes/main_menu.tscn")
const ResultsScene = preload("res://scenes/results.tscn")


class SessionSaveStub:
	extends Node

	var profile: Dictionary = {
		"selected_chassis": "biped", "pilot_name": "PILOTE TEST",
		"paints": {}, "loadouts": {}, "settings": {"camera_view": "tps"},
		"stats": {"championships": 0},
	}
	var championship: Dictionary = {}
	var fail_championship_saves := false
	var fail_race_saves := false
	var record_calls := 0
	var granted_rewards := 0

	func get_championship() -> Dictionary:
		return championship.duplicate(true)

	func save_championship(value: Dictionary) -> bool:
		if fail_championship_saves:
			return false
		championship = value.duplicate(true)
		return true

	func clear_championship() -> bool:
		if fail_championship_saves:
			return false
		championship = {}
		return true

	func record_race_result(result: Dictionary) -> bool:
		record_calls += 1
		if fail_race_saves:
			return false
		granted_rewards += maxi(0, int(result.get("reward", 0)))
		return true

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run_tests")


func _run_tests() -> void:
	_test_database_access_contract()
	_test_broadcast_and_lore_contracts()
	_test_game_session_access_and_roster()
	_test_championship_points_and_tie_break()
	_test_save_title_contract()
	_test_save_rollback_contract()
	_test_session_persistence_failures()
	await _test_main_menu_access_states()
	await _test_open_epilogue_branches()
	if _failures.is_empty():
		print("MECHA NARRATIVE PROGRESSION: PASS (Grand Open lock/unlock/resume + broadcasts + scoring + roster + save rollback/titles + player/Vex/rival epilogues)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MECHA NARRATIVE PROGRESSION: %s" % failure)
	quit(1)


func _test_database_access_contract() -> void:
	var locked := DatabaseScript.championship_access("nexus_open", {"championships": 0}, {})
	_expect(not bool(locked.get("available", true)), "le Grand Open doit être verrouillé avant tout titre")
	_expect(int(locked.get("minimum", 0)) == 1, "le seuil data-driven du Grand Open doit être d’un titre")
	var unlocked := DatabaseScript.championship_access("nexus_open", {"championships": 1}, {})
	_expect(bool(unlocked.get("available", false)) and bool(unlocked.get("unlocked", false)), "un titre doit déverrouiller le Grand Open")
	var resume := DatabaseScript.championship_access("nexus_open", {"championships": 0}, {"active": true, "championship_id": "nexus_open"})
	_expect(bool(resume.get("available", false)) and bool(resume.get("resume", false)), "un Grand Open actif doit rester reprenable même sans titre historique")
	var wrong_resume := DatabaseScript.championship_access("nexus_open", {"championships": 0}, {"active": true, "championship_id": "command_cup"})
	_expect(not bool(wrong_resume.get("available", true)), "une autre Coupe active ne doit pas contourner le verrou du Grand Open")
	for championship: Dictionary in DatabaseScript.get_all_championships():
		if String(championship.get("id", "")) == "nexus_open":
			continue
		var access := DatabaseScript.championship_access(String(championship.get("id", "")), {"championships": 0}, {})
		_expect(bool(access.get("available", false)), "%s doit rester disponible sans titre" % String(championship.get("name", "Coupe dédiée")))


func _test_broadcast_and_lore_contracts() -> void:
	var foundry_quick := BroadcastScript.briefing({"mode": "quick", "track_id": "foundry"})
	var abyss_quick := BroadcastScript.briefing({"mode": "quick", "track_id": "abyss"})
	var caldera_quick := BroadcastScript.briefing({"mode": "quick", "track_id": "caldera"})
	_expect(not String(foundry_quick.get("lore", "")).to_lower().contains("s’ouvre"), "la Fonderie en course rapide ne doit pas prétendre ouvrir le Grand Tour")
	_expect(not String(abyss_quick.get("lore", "")).to_lower().contains("avant-dernière"), "Néréide hors championnat ne doit pas être annoncée comme avant-dernière escale")
	_expect(not String(caldera_quick.get("lore", "")).to_lower().contains("finale"), "Circuit Zero hors Grand Open ne doit pas être annoncé comme finale")

	var cup_briefing := BroadcastScript.briefing({"mode": "grand_prix", "track_id": "foundry", "championship_id": "command_cup"})
	var open_briefing := BroadcastScript.briefing({"mode": "grand_prix", "track_id": "foundry", "championship_id": "nexus_open"})
	var cup_announcer := String(cup_briefing.get("announcer", ""))
	var open_announcer := String(open_briefing.get("announcer", ""))
	_expect(cup_announcer.contains("COUPE BIPÈDE") and cup_announcer.contains("titre de catégorie") and cup_announcer.contains("invitation au Grand Open"), "une Coupe dédiée doit annoncer sa catégorie et sa qualification")
	_expect(open_announcer.contains("huit mondes") and open_announcer.contains("dix catégories") and open_announcer.contains("Circuit Zero"), "le Grand Open doit annoncer sa tournée complète, les dix catégories et Circuit Zero")

	var grand_tour_entry: Dictionary = {}
	for entry: Dictionary in LoreScript.ENTRIES:
		if String(entry.get("id", "")) == "grand_tour":
			grand_tour_entry = entry
			break
	_expect(String(grand_tour_entry.get("protocol_description", "")).contains("Chaque position homologuée à l’arrivée rapporte des points"), "le Codex doit exclure les DNF non homologués de la promesse de points")
	var codex_lore := str(LoreScript.get_all())
	_expect(codex_lore.contains("Dix Coupes de catégorie"), "le Codex doit annoncer les dix Coupes de catégorie")
	_expect(codex_lore.contains("Skimmer LS9") and not codex_lore.contains("Centurion"), "le Codex doit employer l’identité Land Speeder Skimmer actuelle")
	_expect(not String(DatabaseScript.get_track("abyss").get("description", "")).contains("Avant-dernière"), "la description catalogue de Néréide doit rester neutre hors séquence")

	var canonical_runtime_text := "%s\n%s\n%s\n%s\n%s" % [
		str(DatabaseScript.get_all_tracks()), str(DatabaseScript.get_all_chassis()),
		str(LoreScript.ENTRIES), str(LocomotionScript.DRIVE_OPTIONS), str(BroadcastScript.TRACK_LORE),
	]
	_expect(not canonical_runtime_text.contains("Circuit Zéro"), "les données narratives runtime doivent employer uniquement le nom canonique Circuit Zero")


func _test_game_session_access_and_roster() -> void:
	var stub := SessionSaveStub.new()
	var session: Node = SessionScript.new()
	session.set("_save_system_override", stub)
	var open_request := {
		"mode": "grand_prix", "championship_id": "nexus_open",
		"new_championship": true, "difficulty": "pilot", "seed": 250803,
	}
	var locked_value: Variant = session.call(&"configure", open_request)
	var locked_config: Dictionary = locked_value if locked_value is Dictionary else {}
	_expect(locked_config.is_empty() and Dictionary(session.get("championship")).is_empty(), "GameSession doit refuser un nouveau Grand Open à zéro titre")

	session.set("config", open_request.duplicate(true))
	var ghost_result: Dictionary = {}
	session.call(&"_apply_championship_result", ghost_result)
	_expect(Dictionary(session.get("championship")).is_empty() and ghost_result.is_empty(), "un résultat orphelin ne doit pas créer un championnat verrouillé fantôme")

	stub.profile["stats"] = {"championships": 1}
	var unlocked_value: Variant = session.call(&"configure", open_request)
	var unlocked_config: Dictionary = unlocked_value if unlocked_value is Dictionary else {}
	var first_roster: Array = Array(unlocked_config.get("roster", [])).duplicate(true)
	_expect(String(unlocked_config.get("championship_id", "")) == "nexus_open", "GameSession doit démarrer le Grand Open après un titre")
	_expect(DatabaseScript.get_all_pilots().size() + 1 == 10, "le canon doit contenir neuf rivaux et le joueur, soit dix pilotes")
	_expect(int(unlocked_config.get("racer_count", 0)) == 8 and first_roster.size() == 8, "un championnat doit homologuer huit des dix pilotes")
	var seen_ids: Dictionary = {}
	for entrant_value: Variant in first_roster:
		if entrant_value is Dictionary:
			seen_ids[String(Dictionary(entrant_value).get("id", ""))] = true
	_expect(seen_ids.size() == 8 and seen_ids.has("player"), "la grille de huit doit être unique et inclure le joueur")

	var active_value: Variant = session.get("championship")
	var active_open: Dictionary = Dictionary(active_value).duplicate(true) if active_value is Dictionary else {}
	active_open["round_index"] = 2
	session.set("championship", active_open)
	stub.profile["stats"] = {"championships": 0}
	var resumed_value: Variant = session.call(&"configure", {
		"mode": "grand_prix", "championship_id": "nexus_open",
		"new_championship": false, "difficulty": "pilot", "racer_count": 2, "seed": 999999,
	})
	var resumed_config: Dictionary = resumed_value if resumed_value is Dictionary else {}
	_expect(String(resumed_config.get("track_id", "")) == "glacier", "un Grand Open actif doit reprendre sa troisième manche même sans titre historique")
	_expect(Array(resumed_config.get("roster", [])) == first_roster and int(resumed_config.get("racer_count", 0)) == 8, "la reprise doit conserver la grille homologuée de huit pilotes")
	session.free()
	stub.free()


func _test_championship_points_and_tie_break() -> void:
	var points_session: Node = SessionScript.new()
	points_session.set("config", {"track_id": "foundry", "difficulty": "pilot", "championship_id": "command_cup"})
	points_session.set("championship", {
		"active": true, "championship_id": "command_cup", "tracks": ["foundry", "tempest"],
		"round_index": 0, "completed_tracks": [],
		"entrants": [
			{"id": "player", "name": "PILOTE TEST", "points": 0},
			{"id": "vex", "name": "MARA VEX", "points": 0},
			{"id": "iris", "name": "IRIS QUELL", "points": 0},
		],
	})
	var dnf_result := {
		"position": 3,
		"classification": [
			{"racer_id": "player", "dnf": true},
			{"racer_id": "vex", "finished": true},
			{"racer_id": "iris", "finished": true},
		],
	}
	points_session.call(&"_apply_championship_result", dnf_result)
	var scored_championship: Dictionary = points_session.get("championship")
	_expect(int(dnf_result.get("points", -1)) == 0 and _entrant_points(scored_championship, "player") == 0, "un DNF ne doit recevoir aucun point de championnat")
	_expect(_entrant_points(scored_championship, "vex") == int(DatabaseScript.CHAMPIONSHIP_POINTS[0]), "le premier pilote homologué à l’arrivée doit recevoir les points de victoire")
	_expect(_entrant_points(scored_championship, "iris") == int(DatabaseScript.CHAMPIONSHIP_POINTS[1]), "le deuxième pilote homologué doit recevoir les points de deuxième place")
	points_session.free()

	var tie_session: Node = SessionScript.new()
	tie_session.set("config", {"track_id": "foundry", "difficulty": "pilot", "championship_id": "command_cup"})
	tie_session.set("championship", {
		"active": true, "championship_id": "command_cup", "tracks": ["foundry"],
		"round_index": 0, "completed_tracks": [],
		"entrants": [
			{"id": "vex", "name": "MARA VEX", "points": 20},
			{"id": "player", "name": "PILOTE TEST", "points": 20},
		],
	})
	var tie_result := {"position": 2, "classification": [{"racer_id": "vex", "dnf": true}, {"racer_id": "player", "dnf": true}]}
	tie_session.call(&"_apply_championship_result", tie_result)
	var tie_championship: Dictionary = tie_session.get("championship")
	var table_value: Variant = tie_session.call(&"_championship_result")
	var table: Dictionary = table_value if table_value is Dictionary else {}
	var standings: Array = table.get("standings", [])
	var leader_id := String(Dictionary(standings[0]).get("racer_id", "")) if not standings.is_empty() and standings[0] is Dictionary else ""
	_expect(not leader_id.is_empty() and String(tie_championship.get("champion_id", "")) == leader_id, "champion_id doit toujours correspondre au premier du classement après égalité")
	tie_session.free()


func _test_save_title_contract() -> void:
	var service: Node = _new_isolated_save()
	var default_value: Variant = service.call(&"_default_profile")
	service.set("profile", Dictionary(default_value).duplicate(true) if default_value is Dictionary else {})
	service.call(&"record_race_result", _title_result(false, true, "player"))
	_expect(_saved_title_count(service) == 0, "un booléen de victoire faux ne doit jamais ajouter de titre")
	service.call(&"record_race_result", _title_result(true, false, "player"))
	_expect(_saved_title_count(service) == 0, "un championnat partiel ne doit jamais ajouter de titre")
	service.call(&"record_race_result", _title_result(true, true, "vex"))
	_expect(_saved_title_count(service) == 0, "le titre d’un rival ne doit jamais déverrouiller le Grand Open pour le joueur")
	var missing_championship := _title_result(true, true, "player")
	missing_championship.erase("championship")
	service.call(&"record_race_result", missing_championship)
	_expect(_saved_title_count(service) == 0, "un booléen top-level sans bloc championnat ne doit jamais ajouter de titre")
	service.call(&"record_race_result", _title_result(true, true, ""))
	_expect(_saved_title_count(service) == 0, "un champion_id vide ne doit jamais être assimilé au joueur")
	service.call(&"record_race_result", _title_result(true, true, "player"))
	_expect(_saved_title_count(service) == 1, "seul un championnat complet remporté par le joueur doit ajouter un titre")
	_cleanup_isolated_save(service)
	service.free()


func _test_save_rollback_contract() -> void:
	var service: Node = _new_isolated_save()
	var default_value: Variant = service.call(&"_default_profile")
	service.set("profile", Dictionary(default_value).duplicate(true) if default_value is Dictionary else {})
	var original_temp_path := String(service.get("_temp_path"))
	service.set("_temp_path", "user://")
	var finished_snapshot: Dictionary = Dictionary(service.get("profile")).duplicate(true)
	var finished_result := _title_result(false, false, "")
	finished_result["elapsed"] = 42.0
	finished_result["reward"] = 950
	_expect(not bool(service.call(&"record_race_result", finished_result)), "un résultat fini doit exposer l’échec de commit")
	_expect(Dictionary(service.get("profile")) == finished_snapshot, "un résultat fini non persisté doit restaurer tout le profil")
	var dnf_result := finished_result.duplicate(true)
	dnf_result["finished"] = false
	dnf_result["dnf"] = true
	_expect(not bool(service.call(&"record_race_result", dnf_result)), "un DNF doit exposer l’échec de commit")
	_expect(Dictionary(service.get("profile")) == finished_snapshot, "un DNF non persisté doit restaurer tout le profil")
	var sentinel_profile := finished_snapshot.duplicate(true)
	sentinel_profile["championship"] = {"sentinel": "unchanged"}
	# Keep the expected value independent from the service mutation under test.
	service.set("profile", sentinel_profile.duplicate(true))
	_expect(not bool(service.call(&"save_championship", {})), "save_championship doit exposer l’échec de commit")
	_expect(Dictionary(service.get("profile")) == sentinel_profile, "save_championship doit rollback sa mutation")
	_expect(not bool(service.call(&"clear_championship")), "clear_championship doit exposer l’échec de commit")
	_expect(Dictionary(service.get("profile")) == sentinel_profile, "clear_championship doit rollback sa mutation")
	service.set("_temp_path", original_temp_path)
	_cleanup_isolated_save(service)
	service.free()


func _test_session_persistence_failures() -> void:
	var stub := SessionSaveStub.new()
	var session: Node = SessionScript.new()
	session.set("_save_system_override", stub)
	var committed_results: Array[Dictionary] = []
	session.connect(&"race_completed", func(value: Dictionary) -> void: committed_results.append(value.duplicate(true)))
	var request := {
		"mode": "grand_prix", "championship_id": "command_cup",
		"new_championship": true, "difficulty": "pilot", "laps": 1, "seed": 4242,
	}
	stub.fail_championship_saves = true
	var rejected_value: Variant = session.call(&"configure", request)
	_expect(rejected_value is Dictionary and Dictionary(rejected_value).is_empty(), "un championnat ne doit pas démarrer si sa sauvegarde échoue")
	_expect(Dictionary(session.get("championship")).is_empty(), "le championnat local doit rollback après un démarrage non persisté")
	stub.fail_championship_saves = false
	var config_value: Variant = session.call(&"configure", request)
	var configured: Dictionary = config_value if config_value is Dictionary else {}
	var final_round_state: Dictionary = Dictionary(session.get("championship")).duplicate(true)
	var final_tracks: Array = final_round_state.get("tracks", [])
	final_round_state["round_index"] = maxi(0, final_tracks.size() - 1)
	final_round_state["completed_tracks"] = final_tracks.slice(0, maxi(0, final_tracks.size() - 1))
	session.set("championship", final_round_state)
	var before_result := final_round_state.duplicate(true)
	var classification: Array[Dictionary] = []
	for entrant_value: Variant in configured.get("roster", []):
		if entrant_value is Dictionary:
			classification.append({"racer_id": String(Dictionary(entrant_value).get("id", "")), "finished": true})
	var raw_result := {"finished": true, "position": 1, "elapsed": 72.0, "laps_completed": 1, "classification": classification}
	stub.fail_race_saves = true
	var failed_value: Variant = session.call(&"complete_race", raw_result)
	var failed: Dictionary = failed_value if failed_value is Dictionary else {}
	_expect(bool(failed.get("save_failed", false)) and not bool(failed.get("persisted", true)), "un résultat non persisté doit retourner save_failed")
	_expect(bool(failed.get("persistence_retry_available", false)) and bool(session.call(&"has_pending_persistence")), "l’échec doit exposer une nouvelle tentative de sauvegarde")
	_expect(not bool(session.get("_result_committed")) and Dictionary(session.get("championship")) == before_result, "un échec résultat doit rollback le championnat et rester retentable")
	var failed_championship: Dictionary = failed.get("championship", {}) if failed.get("championship", {}) is Dictionary else {}
	_expect(not bool(failed.get("championship_complete", true)) and not bool(failed_championship.get("complete", true)), "une finale non sauvegardée ne doit jamais être présentée comme terminée")
	_expect(String(failed_championship.get("champion_id", "ghost")).is_empty(), "une finale non sauvegardée ne doit jamais annoncer de champion")
	_expect(int(failed.get("round", -1)) == int(before_result.get("round_index", -2)), "le payload d’échec doit revenir à la manche réellement sauvegardée")
	_expect(committed_results.is_empty(), "un échec de sauvegarde ne doit pas émettre de résultat homologué")
	_expect(stub.granted_rewards == 0, "un commit échoué ne doit accorder aucune récompense")
	stub.fail_race_saves = false
	var saved_value: Variant = session.call(&"retry_result_persistence")
	var saved: Dictionary = saved_value if saved_value is Dictionary else {}
	_expect(bool(saved.get("persisted", false)) and not bool(saved.get("save_failed", true)), "la nouvelle tentative doit pouvoir persister le résultat")
	_expect(bool(saved.get("championship_complete", false)), "la finale ne doit être homologuée qu’après la sauvegarde réussie")
	var repeated_value: Variant = session.call(&"complete_race", raw_result)
	var repeated: Dictionary = repeated_value if repeated_value is Dictionary else {}
	_expect(stub.record_calls == 2 and stub.granted_rewards == int(saved.get("reward", -1)), "un résultat réussi ne doit être crédité qu’une seule fois")
	_expect(committed_results.size() == 1, "le retry réussi doit émettre exactement une homologation")
	_expect(repeated == saved, "une répétition après succès doit retourner le résultat immuable déjà commité")
	session.free()
	stub.free()


func _test_main_menu_access_states() -> void:
	var save: Node = get_root().get_node_or_null("SaveSystem")
	var session: Node = get_root().get_node_or_null("GameSession")
	_expect(save != null, "SaveSystem doit être disponible pour tester le menu")
	_expect(session != null, "GameSession doit être disponible pour tester la reprise")
	if save == null or session == null:
		return
	var original_profile_value: Variant = save.get("profile")
	var original_profile: Dictionary = Dictionary(original_profile_value).duplicate(true) if original_profile_value is Dictionary else {}
	var original_championship_value: Variant = session.get("championship")
	var original_championship: Dictionary = Dictionary(original_championship_value).duplicate(true) if original_championship_value is Dictionary else {}
	var test_profile := original_profile.duplicate(true)
	test_profile["selected_chassis"] = "biped"
	test_profile["settings"] = {"reduced_motion": true}
	var stats_value: Variant = test_profile.get("stats", {})
	var stats: Dictionary = Dictionary(stats_value).duplicate(true) if stats_value is Dictionary else {}
	stats["championships"] = 0
	test_profile["stats"] = stats
	save.set("profile", test_profile)
	session.set("championship", {})

	var menu := MainMenuScene.instantiate() as Control
	get_root().add_child(menu)
	await process_frame
	await process_frame
	var selector := menu.get_node("%ChampionshipSelect") as OptionButton
	var action := menu.get_node("%GrandPrixButton") as Button
	var status := menu.get_node("%StatusMessage") as Label
	var open_index := _find_championship_item(selector, "nexus_open")
	_expect(open_index >= 0, "le Grand Open doit apparaître dans le sélecteur")
	if open_index >= 0:
		_expect(selector.is_item_disabled(open_index), "l’item Grand Open doit être désactivé à zéro titre")
		_expect(selector.get_item_text(open_index).contains("VERROUILLÉ"), "l’item verrouillé doit afficher son badge")
		_expect(selector.get_popup().get_item_tooltip(open_index).contains("Coupe de catégorie"), "l’item verrouillé doit expliquer comment obtenir l’invitation")
	var dedicated_available := 0
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) != "nexus_open" and not selector.is_item_disabled(index):
			dedicated_available += 1
	_expect(dedicated_available == 10, "les dix Coupes de catégorie doivent rester sélectionnables")
	_expect(status.text.contains("GRAND OPEN VERROUILLÉ"), "le statut de saison doit annoncer le verrou du Grand Open")
	if open_index >= 0:
		selector.set_item_disabled(open_index, false)
		selector.select(open_index)
		menu.call(&"_on_race_option_selected", open_index)
		_expect(action.disabled, "le bouton Grand Prix doit refuser un Grand Open verrouillé")
		_expect(action.text.contains("GRAND OPEN VERROUILLÉ"), "le bouton verrouillé doit avoir un libellé explicite")
		_expect(action.tooltip_text.contains("Coupe de catégorie"), "le bouton verrouillé doit reprendre l’instruction data-driven")
		_expect(selector.tooltip_text.contains("Coupe de catégorie"), "le sélecteur doit exposer le même tooltip de verrouillage")
		_expect(status.text.contains("GRAND OPEN VERROUILLÉ"), "une tentative de sélection doit conserver le statut de verrouillage")

	stats["championships"] = 1
	test_profile["stats"] = stats
	save.set("profile", test_profile)
	menu.call(&"refresh")
	await process_frame
	if open_index >= 0:
		_expect(not selector.is_item_disabled(open_index), "le Grand Open doit être activé après un titre")
		_expect(selector.get_item_text(open_index).contains("OPEN"), "l’item déverrouillé doit retrouver son badge OPEN")
		_expect(not action.disabled and action.text.contains("NOUVEAU CHAMPIONNAT"), "le bouton doit permettre de démarrer le Grand Open déverrouillé")
		_expect(selector.tooltip_text.contains("Invitation obtenue"), "le tooltip doit confirmer l’invitation obtenue")
	_expect(status.text.contains("INVITATION ACQUISE"), "le statut de saison doit confirmer le déverrouillage")

	stats["championships"] = 0
	test_profile["stats"] = stats
	save.set("profile", test_profile)
	var open_definition := DatabaseScript.get_championship("nexus_open")
	session.set("championship", {
		"active": true,
		"championship_id": "nexus_open",
		"cup_id": "nexus_open",
		"name": open_definition.get("name", "Grand Open des Huit Mondes"),
		"tracks": Array(open_definition.get("track_ids", [])).duplicate(),
		"round_index": 2,
		"difficulty": "pilot",
	})
	menu.call(&"refresh")
	await process_frame
	if open_index >= 0:
		_expect(selector.selected == open_index, "un Grand Open actif doit être sélectionné automatiquement")
		_expect(not selector.is_item_disabled(open_index), "l’exception de reprise doit réactiver l’item")
		_expect(selector.get_item_text(open_index).contains("REPRISE"), "l’item actif doit afficher le badge REPRISE")
		_expect(not action.disabled and action.text.contains("REPRENDRE"), "le bouton doit reprendre le Grand Open actif")
		_expect(action.tooltip_text.contains("sauvegardé"), "le tooltip de reprise doit annoncer la grille et les points sauvegardés")
	_expect(status.text.contains("MANCHE 3/8"), "le statut de reprise doit afficher la manche active")

	menu.queue_free()
	await process_frame
	save.set("profile", original_profile)
	session.set("championship", original_championship)


func _test_open_epilogue_branches() -> void:
	var results := ResultsScene.instantiate() as Control
	get_root().add_child(results)
	await process_frame
	await process_frame
	var title := results.get_node("%ResultTitle") as Label
	var position := results.get_node("%PositionValue") as Label
	var summary := results.get_node("%ResultSummary") as Label
	var podium_headline := results.get_node("%PodiumHeadline") as Label
	var podium_panel := results.get_node("SafeArea/ContentPanel/Content/Classification/PodiumPanel") as PanelContainer
	var retry_button := results.get_node("%RetryButton") as Button
	var next_button := results.get_node("%NextButton") as Button
	var menu_button := results.get_node("%MenuButton") as Button
	var persistence_retries: Array[bool] = []
	var race_retries: Array[bool] = []
	results.connect(&"persistence_retry_requested", func() -> void: persistence_retries.append(true))
	results.connect(&"retry_requested", func() -> void: race_retries.append(true))

	results.call(&"present", _open_result("player", false, "PILOTE TEST"))
	await process_frame
	_expect(title.text == "COURONNE DES HUIT MONDES", "champion_id=player doit conserver l’épilogue victorieux actuel")
	_expect(position.text == "CHAMPION" and summary.text.contains("Meridian Apex perd sa clause d’exclusivité"), "la victoire du joueur doit protéger la Charte et ouvrir le Conseil")
	_expect(podium_headline.text.contains("GRILLE LIBRE"), "le podium joueur doit prendre la Couronne pour la grille libre")

	results.call(&"present", _open_result("vex", true, "MARA VEX"))
	await process_frame
	_expect(title.text == "COURONNE SOUS EXCLUSIVITÉ" and position.text == "VEX CHAMPIONNE", "champion_id=vex doit primer sur l’ancien booléen championship_won")
	_expect(summary.text.contains("troisième titre") and summary.text.contains("directement menacés"), "la victoire de Vex doit menacer la Charte par l’exclusivité Meridian Apex")
	_expect(podium_headline.text.contains("MARA VEX"), "le podium doit nommer Vex lorsqu’elle gagne l’Open")

	results.call(&"present", _open_result("iris", false, "IRIS KADE"))
	await process_frame
	_expect(title.text == "COURONNE CONTESTÉE" and position.text == "CHARTE PROTÉGÉE", "un autre rival doit produire l’épilogue de Couronne contestée")
	_expect(summary.text.contains("prive Mara Vex de son troisième titre") and summary.text.contains("temporairement protégée"), "un rival vainqueur doit priver Vex du troisième titre et protéger temporairement la Charte")
	_expect(podium_headline.text.contains("ÉCHAPPE À VEX"), "le podium rival doit expliciter que la Couronne échappe à Vex")

	var failed_final := _open_result("player", true, "PILOTE TEST")
	failed_final["save_failed"] = true
	failed_final["persisted"] = false
	failed_final["persistence_retry_available"] = true
	failed_final["save_error_message"] = "Progression non enregistrée. Réessayez la sauvegarde avant de quitter."
	failed_final["reward"] = 0
	results.call(&"present", failed_final)
	await process_frame
	_expect(title.text == "PROGRESSION NON ENREGISTRÉE" and position.text == "À REVALIDER", "Results doit remplacer toute fausse Couronne par l’alerte de sauvegarde")
	_expect(summary.text.contains("Réessayez") and podium_headline.text.contains("PROVISOIRE") and not podium_panel.visible, "le résultat non persisté doit rester provisoire sans afficher de cartes homologuées")
	_expect(not next_button.visible and retry_button.visible and retry_button.text == "RÉESSAYER LA SAUVEGARDE", "l’échec doit bloquer la manche suivante et proposer le retry de commit")
	_expect(menu_button.text == "QUITTER SANS SAUVEGARDER", "la sortie doit annoncer explicitement la perte de progression")
	retry_button.emit_signal(&"pressed")
	await process_frame
	_expect(persistence_retries.size() == 1 and race_retries.is_empty(), "le bouton sauvegarde ne doit jamais relancer la course ni doubler le résultat")

	results.queue_free()
	await process_frame


func _open_result(champion_id: String, legacy_won: bool, winner_name: String) -> Dictionary:
	return {
		"mode": "grand_prix",
		"track_name": "Circuit Zero",
		"position": 1 if champion_id == "player" else 2,
		"total_racers": 8,
		"finished": true,
		"dnf": false,
		"championship_complete": true,
		"championship_won": legacy_won,
		"classification": [
			{"position": 1, "pilot": winner_name, "racer_id": champion_id, "classified": true, "finished": true, "chassis_id": "biped"},
			{"position": 2, "pilot": "PILOTE TEST", "racer_id": "player", "player": true, "classified": true, "finished": true, "chassis_id": "biped"},
		],
		"championship": {
			"active": false,
			"complete": true,
			"championship_id": "nexus_open",
			"cup_id": "nexus_open",
			"name": "Grand Open des Huit Mondes",
			"champion_id": champion_id,
			"grid_policy": "mixed",
			"round": 8,
			"total_rounds": 8,
			"standings": [],
		},
	}


func _title_result(won: bool, complete: bool, champion_id: String) -> Dictionary:
	return {
		"finished": true,
		"dnf": false,
		"position": 2,
		"elapsed": 0.0,
		"reward": 0,
		"record_valid": false,
		"track_id": "foundry",
		"mode": "grand_prix",
		"championship_won": won,
		"championship_complete": complete,
		"championship": {
			"active": false,
			"complete": complete,
			"championship_id": "command_cup",
			"champion_id": champion_id,
		},
	}


func _entrant_points(championship_data: Dictionary, racer_id: String) -> int:
	for entrant_value: Variant in championship_data.get("entrants", []):
		if entrant_value is Dictionary and String(Dictionary(entrant_value).get("id", "")) == racer_id:
			return int(Dictionary(entrant_value).get("points", 0))
	return -1


func _new_isolated_save() -> Node:
	var service: Node = SaveScript.new()
	var stem := "user://mecha_overdrive_narrative_progression"
	service.set("_save_path", "%s.json" % stem)
	service.set("_temp_path", "%s.tmp" % stem)
	service.set("_backup_path", "%s.backup.json" % stem)
	service.set("_corrupt_path", "%s.corrupt.json" % stem)
	service.set("_backup_corrupt_path", "%s.backup.corrupt.json" % stem)
	_cleanup_isolated_save(service)
	return service


func _cleanup_isolated_save(service: Node) -> void:
	var property_names: Array[String] = [
		"_save_path", "_temp_path", "_backup_path", "_corrupt_path", "_backup_corrupt_path",
	]
	for property_name: String in property_names:
		var path := String(service.get(property_name))
		if not FileAccess.file_exists(path):
			continue
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		_expect(remove_error == OK, "le fichier de sauvegarde narratif isolé doit pouvoir être nettoyé : %s" % path)


func _saved_title_count(service: Node) -> int:
	var profile_value: Variant = service.get("profile")
	if not profile_value is Dictionary:
		return -1
	var stats_value: Variant = Dictionary(profile_value).get("stats", {})
	return int(Dictionary(stats_value).get("championships", -1)) if stats_value is Dictionary else -1


func _find_championship_item(selector: OptionButton, championship_id: String) -> int:
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == championship_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
