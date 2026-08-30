extends Control
class_name ResultsScreen

signal retry_requested
signal persistence_retry_requested
signal menu_requested
signal next_requested

const ThemeFactory = preload("res://scripts/ui/ui_theme.gd")

@onready var result_eyebrow: Label = %ResultEyebrow
@onready var result_title: Label = %ResultTitle
@onready var position_value: Label = %PositionValue
@onready var time_value: Label = %TimeValue
@onready var best_value: Label = %BestValue
@onready var reward_value: Label = %RewardValue
@onready var result_summary: Label = %ResultSummary
@onready var podium_headline: Label = %PodiumHeadline
@onready var podium: PodiumPresenter = %PodiumPresenter
@onready var podium_panel: PanelContainer = $SafeArea/ContentPanel/Content/Classification/PodiumPanel
@onready var standings_list: ItemList = %StandingsList
@onready var championship_panel: PanelContainer = %ChampionshipPanel
@onready var championship_summary: Label = %ChampionshipSummary
@onready var retry_button: Button = %RetryButton
@onready var next_button: Button = %NextButton
@onready var menu_button: Button = %MenuButton
@onready var content_panel: PanelContainer = %ContentPanel

var _result: Dictionary = {}
var _present_when_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = ThemeFactory.create_theme(_settings())
	retry_button.pressed.connect(_on_retry_pressed)
	next_button.pressed.connect(func() -> void: next_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	if _present_when_ready:
		_apply_result()
	else:
		present({})


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()


func _on_retry_pressed() -> void:
	if bool(_result.get("save_failed", false)) and bool(_result.get("persistence_retry_available", false)):
		persistence_retry_requested.emit()
		return
	retry_requested.emit()


func present(result: Dictionary) -> void:
	_result = result.duplicate(true)
	if not is_node_ready():
		_present_when_ready = true
		return
	_apply_result()


func _apply_result() -> void:
	theme = ThemeFactory.create_theme(_settings())
	var position := int(_value(["position", "rank"], 0))
	var total := maxi(int(_value(["total_racers", "racer_count", "field_size"], 8)), 1)
	var dnf := bool(_value(["dnf", "did_not_finish", "eliminated"], false))
	var mode := String(_value(["mode"], "quick"))
	var track_name := String(_value(["track_name", "track"], "CIRCUIT ZERO"))
	var is_record := bool(_value(["new_record", "record"], false))
	var save_failed := bool(_value(["save_failed"], false))
	var championship := _championship_data()
	var championship_complete := not save_failed and bool(_value(["championship_complete", "series_complete"], championship.get("complete", false)))
	var championship_won := bool(_value(["championship_won", "series_won"], false))
	var championship_id := String(championship.get("championship_id", championship.get("cup_id", "")))
	var champion_id := String(championship.get("champion_id", ""))
	if champion_id.is_empty() and championship_won:
		champion_id = "player"

	result_eyebrow.text = "%s // %s" % [_mode_name(mode), track_name.to_upper()]
	if dnf:
		result_title.text = "COURSE INTERROMPUE"
		position_value.text = "DNF"
		result_summary.text = "La télémétrie a été conservée, mais aucun record ni bonus de classement n’est attribué."
	elif mode == "time_trial":
		result_title.text = "NOUVEAU RECORD" if is_record else "CHRONO HOMOLOGUÉ"
		position_value.text = "RECORD" if is_record else "VALIDÉ"
		result_summary.text = "Nouvelle référence enregistrée dans les archives des Huit Mondes." if is_record else "Session validée. Analysez la télémétrie pour attaquer la référence au prochain passage."
	elif position == 1:
		result_title.text = "VICTOIRE"
		position_value.text = "1ER / %d" % total
		result_summary.text = "Victoire homologuée. Votre signature gagne du terrain face à Meridian Apex."
	else:
		result_title.text = "ARRIVÉE HOMOLOGUÉE"
		position_value.text = "%s / %d" % [_ordinal(position), total]
		result_summary.text = "Course validée. Analysez les écarts puis ajustez votre architecture au garage."
	if save_failed:
		result_eyebrow.text = "SAUVEGARDE // ACTION REQUISE"
		result_title.text = "PROGRESSION NON ENREGISTRÉE"
		position_value.text = "À REVALIDER"
		result_summary.text = String(_value(["save_error_message"], "La course reste provisoire tant que la sauvegarde n’a pas abouti."))
	elif championship_complete:
		_apply_championship_epilogue(championship_id, champion_id)

	var elapsed := float(_value(["time", "elapsed", "race_time"], 0.0))
	var best := float(_value(["best_lap", "best_time", "record_time"], 0.0))
	time_value.text = _format_time(elapsed) if elapsed > 0.0 else "--:--.---"
	best_value.text = ("NOUVEAU  •  " if is_record else "") + (_format_time(best) if best > 0.0 else "--:--.---")
	var credits := int(_value(["credits", "credits_earned", "reward"], 0))
	var points := int(_value(["points", "championship_points"], 0))
	reward_value.text = "+%d CR" % credits
	if points > 0:
		reward_value.text += "   •   +%d PTS" % points

	var classification: Variant = _value(["standings", "classification", "racers"], [])
	podium.present(classification, position, dnf, mode)
	var winner := podium.winner_name().to_upper()
	podium_headline.text = "PODIUM // CLASSEMENT HOMOLOGUÉ"
	podium_panel.visible = not save_failed and mode != "time_trial" and not podium.top_three().is_empty()
	if save_failed:
		podium_headline.text = "CLASSEMENT PROVISOIRE // SAUVEGARDE REQUISE"
	elif podium_panel.visible and not dnf and not winner.is_empty():
		podium_headline.text = "PODIUM // %s PREND LE TROPHÉE" % winner
	if not save_failed and championship_complete and championship_id == "nexus_open":
		match champion_id:
			"player":
				podium_headline.text = "PODIUM // LA GRILLE LIBRE PREND LA COURONNE"
			"vex":
				podium_headline.text = "PODIUM // MARA VEX PREND LA COURONNE"
			_:
				if not champion_id.is_empty():
					podium_headline.text = "PODIUM // LA COURONNE ÉCHAPPE À VEX"
	_populate_standings(position, total)
	_populate_championship(mode)
	var can_continue := not save_failed and bool(_value(["can_continue", "has_next_race"], mode == "grand_prix" and not championship_complete))
	var persistence_retry_available := bool(_value(["persistence_retry_available"], false))
	next_button.visible = can_continue
	next_button.disabled = not can_continue
	retry_button.visible = not can_continue
	retry_button.disabled = save_failed and not persistence_retry_available
	if save_failed:
		retry_button.text = "RÉESSAYER LA SAUVEGARDE"
		menu_button.text = "QUITTER SANS SAUVEGARDER"
	else:
		retry_button.text = "REJOUER LA SAISON" if championship_complete else "RECOMMENCER"
		menu_button.text = "RETOUR AU PADDOCK" if championship_complete else "MENU PRINCIPAL"
	var focus_button: Button = next_button if can_continue else retry_button
	if focus_button.disabled:
		focus_button = menu_button
	var focus_chain: Array[Control] = [focus_button]
	if focus_button != menu_button:
		focus_chain.append(menu_button)
	ThemeFactory.connect_focus_chain(focus_chain)
	focus_button.call_deferred("grab_focus")
	_play_entrance()


func _apply_championship_epilogue(championship_id: String, champion_id: String) -> void:
	var player_champion := champion_id == "player"
	if championship_id == "nexus_open":
		result_eyebrow.text = "FINALE // CIRCUIT ZERO"
		if player_champion:
			result_title.text = "COURONNE DES HUIT MONDES"
			position_value.text = "CHAMPION"
			result_summary.text = "Meridian Apex perd sa clause d’exclusivité. Le Hangar 08 protège la Charte libre et gagne son siège au Conseil des constructeurs."
		elif champion_id == "vex":
			result_title.text = "COURONNE SOUS EXCLUSIVITÉ"
			position_value.text = "VEX CHAMPIONNE"
			result_summary.text = "Mara Vex décroche son troisième titre. Meridian Apex exige désormais la clause d’exclusivité : la Charte libre et l’accès ouvert à la grille sont directement menacés."
		else:
			result_title.text = "COURONNE CONTESTÉE"
			position_value.text = "CHARTE PROTÉGÉE"
			result_summary.text = "Un autre rival prive Mara Vex de son troisième titre. Sans la Couronne nécessaire à Meridian Apex pour imposer son exclusivité, la Charte libre reste temporairement protégée."
	elif player_champion:
		result_title.text = "COUPE REMPORTÉE"
		position_value.text = "CHAMPION"
		result_summary.text = "Votre titre de catégorie offre au Hangar 08 son invitation sportive au Grand Open des Huit Mondes."
	else:
		result_summary.text = "La Coupe se termine sans titre. Renforcez votre architecture avant de repartir chercher l’invitation au Grand Open."


func _populate_standings(player_position: int, total: int) -> void:
	standings_list.clear()
	var entries: Variant = _value(["standings", "classification", "racers"], [])
	var has_entries := false
	if entries is Array:
		var entries_array: Array = entries
		has_entries = not entries_array.is_empty()
		for index in range(entries_array.size()):
			var entry: Variant = entries_array[index]
			if entry is Dictionary:
				var entry_dictionary: Dictionary = entry
				var rank := int(entry_dictionary.get("position", entry_dictionary.get("rank", index + 1)))
				var pilot := String(entry_dictionary.get("pilot", entry_dictionary.get("name", entry_dictionary.get("display_name", "PILOTE %02d" % (index + 1)))))
				var delta := String(entry_dictionary.get("delta", entry_dictionary.get("gap", "")))
				standings_list.add_item("%02d   %-18s   %s" % [rank, pilot.to_upper(), delta])
				if bool(entry_dictionary.get("player", false)) or rank == player_position:
					standings_list.select(index)
	if not has_entries:
		for rank in range(1, total + 1):
			var pilot := "VOUS" if rank == player_position else "RIVAL %02d" % rank
			standings_list.add_item("%02d   %s" % [rank, pilot])
			if rank == player_position:
				standings_list.select(rank - 1)
	standings_list.mouse_filter = Control.MOUSE_FILTER_STOP


func _populate_championship(mode: String) -> void:
	var championship: Variant = _value(["championship", "series"], {})
	var championship_dictionary: Dictionary = {}
	if championship is Dictionary:
		championship_dictionary = championship
	championship_panel.visible = mode == "grand_prix" or not championship_dictionary.is_empty()
	if not championship_panel.visible:
		return
	var round_index := int(_dictionary_value(championship_dictionary, "round", _value(["round"], 1)))
	var round_total := int(_dictionary_value(championship_dictionary, "total_rounds", 4))
	var standings: Variant = _dictionary_value(championship_dictionary, "standings", [])
	var championship_name := String(_dictionary_value(championship_dictionary, "name", "CHAMPIONNAT"))
	var grid_policy := String(_dictionary_value(championship_dictionary, "grid_policy", "division"))
	var category_chassis_id := String(_dictionary_value(championship_dictionary, "category_chassis_id", ""))
	var category := GameDatabase.get_race_category_for_chassis(category_chassis_id)
	var grid_label := "OPEN / TOUTES CATÉGORIES" if grid_policy == "mixed" else "CATÉGORIE %s" % String(category.get("name", "ACTIVE")).to_upper()
	var lines := PackedStringArray([
		championship_name.to_upper(),
		"MANCHE %d / %d" % [round_index, round_total],
		"RÈGLEMENT // %s" % grid_label,
	])
	if standings is Array:
		var standings_array: Array = standings
		for index in range(mini(standings_array.size(), 5)):
			var entry: Variant = standings_array[index]
			if entry is Dictionary:
				var entry_dictionary: Dictionary = entry
				lines.append("%02d  %-14s  %d PTS" % [index + 1, String(entry_dictionary.get("pilot", entry_dictionary.get("name", "PILOTE"))).to_upper(), int(entry_dictionary.get("points", 0))])
	championship_summary.text = "\n".join(lines)


func _play_entrance() -> void:
	if not is_instance_valid(content_panel):
		return
	var duration := ThemeFactory.motion_duration(_settings(), 0.26)
	if duration <= 0.0:
		content_panel.modulate = Color.WHITE
		content_panel.position.y = 0.0
		return
	content_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	content_panel.position.y = 24.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(content_panel, "modulate", Color.WHITE, duration)
	tween.tween_property(content_panel, "position:y", 0.0, duration)


func _championship_data() -> Dictionary:
	var value: Variant = _value(["championship", "series"], {})
	return Dictionary(value).duplicate(true) if value is Dictionary else {}


func _value(keys: Array[String], fallback: Variant) -> Variant:
	for key in keys:
		if _result.has(key):
			return _result[key]
	return fallback


func _dictionary_value(source: Variant, key: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		var source_dictionary: Dictionary = source
		return source_dictionary.get(key, fallback)
	return fallback


func _mode_name(mode: String) -> String:
	match mode:
		"grand_prix": return "GRAND PRIX"
		"time_trial": return "CONTRE-LA-MONTRE"
		"elimination": return "ÉLIMINATION"
		_: return "COURSE RAPIDE"


func _ordinal(value: int) -> String:
	if value <= 0:
		return "--"
	return "%dE" % value


func _format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	var remainder := seconds - minutes * 60.0
	return "%02d:%06.3f" % [minutes, remainder]


func _settings() -> Dictionary:
	var save := get_node_or_null("/root/SaveSystem")
	if save == null:
		return {}
	var profile: Variant = save.get("profile")
	if profile is Dictionary:
		var profile_dictionary: Dictionary = profile
		var value: Variant = profile_dictionary.get("settings", {})
		return value if value is Dictionary else {}
	return {}
