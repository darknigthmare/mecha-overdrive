extends Control
class_name ResultsScreen

signal retry_requested
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
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
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

	result_eyebrow.text = "%s // %s" % [_mode_name(mode), track_name.to_upper()]
	if dnf:
		result_title.text = "COURSE INTERROMPUE"
		position_value.text = "DNF"
		result_summary.text = "La télémétrie a été conservée, mais aucun record ni bonus de classement n’est attribué."
	elif position == 1:
		result_title.text = "VICTOIRE"
		position_value.text = "1ER / %d" % total
		result_summary.text = "Trajectoire homologuée. Le Nexus enregistre une nouvelle référence de course."
	else:
		result_title.text = "ARRIVÉE HOMOLOGUÉE"
		position_value.text = "%s / %d" % [_ordinal(position), total]
		result_summary.text = "Course validée. Analysez les écarts puis ajustez votre architecture au garage."

	var elapsed := float(_value(["time", "elapsed", "race_time"], 0.0))
	var best := float(_value(["best_lap", "best_time", "record_time"], 0.0))
	time_value.text = _format_time(elapsed) if elapsed > 0.0 else "--:--.---"
	best_value.text = ("NOUVEAU  •  " if is_record else "") + (_format_time(best) if best > 0.0 else "--:--.---")
	var credits := int(_value(["credits", "credits_earned", "reward"], 0))
	var points := int(_value(["points", "championship_points"], 0))
	reward_value.text = "+%d CR" % credits
	if points > 0:
		reward_value.text += "   •   +%d PTS" % points

	_populate_standings(position, total)
	_populate_championship(mode)
	var championship_complete := bool(_value(["championship_complete", "series_complete"], false))
	var can_continue := bool(_value(["can_continue", "has_next_race"], mode == "grand_prix" and not championship_complete))
	next_button.visible = can_continue
	next_button.disabled = not can_continue
	retry_button.visible = not can_continue
	ThemeFactory.connect_focus_chain([next_button if can_continue else retry_button, menu_button])
	(next_button if can_continue else retry_button).call_deferred("grab_focus")
	_play_entrance()


func _populate_standings(player_position: int, total: int) -> void:
	standings_list.clear()
	var entries: Variant = _value(["standings", "classification", "racers"], [])
	if entries is Array and not entries.is_empty():
		for index in range(entries.size()):
			var entry: Variant = entries[index]
			if entry is Dictionary:
				var rank := int(entry.get("position", entry.get("rank", index + 1)))
				var pilot := String(entry.get("pilot", entry.get("name", "PILOTE %02d" % (index + 1))))
				var delta := String(entry.get("delta", entry.get("gap", "")))
				standings_list.add_item("%02d   %-18s   %s" % [rank, pilot.to_upper(), delta])
				if bool(entry.get("player", false)) or rank == player_position:
					standings_list.select(index)
	else:
		for rank in range(1, total + 1):
			var pilot := "VOUS" if rank == player_position else "RIVAL %02d" % rank
			standings_list.add_item("%02d   %s" % [rank, pilot])
			if rank == player_position:
				standings_list.select(rank - 1)
	standings_list.mouse_filter = Control.MOUSE_FILTER_STOP


func _populate_championship(mode: String) -> void:
	var championship: Variant = _value(["championship", "series"], {})
	championship_panel.visible = mode == "grand_prix" or championship is Dictionary and not championship.is_empty()
	if not championship_panel.visible:
		return
	var round_index := int(_dictionary_value(championship, "round", _value(["round"], 1)))
	var round_total := int(_dictionary_value(championship, "total_rounds", 4))
	var standings: Variant = _dictionary_value(championship, "standings", [])
	var lines := PackedStringArray(["MANCHE %d / %d" % [round_index, round_total]])
	if standings is Array:
		for index in range(mini(standings.size(), 5)):
			var entry: Variant = standings[index]
			if entry is Dictionary:
				lines.append("%02d  %-14s  %d PTS" % [index + 1, String(entry.get("pilot", entry.get("name", "PILOTE"))).to_upper(), int(entry.get("points", 0))])
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


func _value(keys: Array[String], fallback: Variant) -> Variant:
	for key in keys:
		if _result.has(key):
			return _result[key]
	return fallback


func _dictionary_value(source: Variant, key: String, fallback: Variant) -> Variant:
	return source.get(key, fallback) if source is Dictionary else fallback


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
		var value: Variant = profile.get("settings", {})
		return value if value is Dictionary else {}
	return {}
