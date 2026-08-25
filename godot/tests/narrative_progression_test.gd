extends SceneTree
## Targeted narrative/progression regression suite.
## Run with: godot --headless --path godot --script res://tests/narrative_progression_test.gd

const DatabaseScript = preload("res://scripts/data/game_database.gd")
const MainMenuScene = preload("res://scenes/main_menu.tscn")
const ResultsScene = preload("res://scenes/results.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run_tests")


func _run_tests() -> void:
	_test_database_access_contract()
	await _test_main_menu_access_states()
	await _test_open_epilogue_branches()
	if _failures.is_empty():
		print("MECHA NARRATIVE PROGRESSION: PASS (Grand Open lock/unlock/resume + player/Vex/rival epilogues)")
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
		_expect(selector.get_popup().get_item_tooltip(open_index).contains("Coupe de division"), "l’item verrouillé doit expliquer comment obtenir l’invitation")
	var dedicated_available := 0
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) != "nexus_open" and not selector.is_item_disabled(index):
			dedicated_available += 1
	_expect(dedicated_available == 5, "les cinq Coupes dédiées doivent rester sélectionnables")
	_expect(status.text.contains("GRAND OPEN VERROUILLÉ"), "le statut de saison doit annoncer le verrou du Grand Open")
	if open_index >= 0:
		selector.set_item_disabled(open_index, false)
		selector.select(open_index)
		menu.call(&"_on_race_option_selected", open_index)
		_expect(action.disabled, "le bouton Grand Prix doit refuser un Grand Open verrouillé")
		_expect(action.text.contains("GRAND OPEN VERROUILLÉ"), "le bouton verrouillé doit avoir un libellé explicite")
		_expect(action.tooltip_text.contains("Coupe de division"), "le bouton verrouillé doit reprendre l’instruction data-driven")
		_expect(selector.tooltip_text.contains("Coupe de division"), "le sélecteur doit exposer le même tooltip de verrouillage")
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


func _find_championship_item(selector: OptionButton, championship_id: String) -> int:
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == championship_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
