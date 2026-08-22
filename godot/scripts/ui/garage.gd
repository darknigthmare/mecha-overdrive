extends Control
class_name GarageScreen

signal back_requested

const ThemeFactory = preload("res://scripts/ui/ui_theme.gd")

@onready var credits_value: Label = %CreditsValue
@onready var chassis_list: ItemList = %ChassisList
@onready var chassis_category: Label = %ChassisCategory
@onready var chassis_name: Label = %ChassisName
@onready var chassis_subtitle: Label = %ChassisSubtitle
@onready var chassis_description: Label = %ChassisDescription
@onready var ability_name: Label = %AbilityName
@onready var ability_description: Label = %AbilityDescription
@onready var selected_badge: Label = %SelectedBadge
@onready var paint_option: OptionButton = %PaintOption
@onready var paint_preview: ColorRect = %PaintPreview
@onready var select_button: Button = %SelectButton
@onready var back_button: Button = %BackButton
@onready var status_message: Label = %StatusMessage

@onready var speed_bar: ProgressBar = %SpeedBar
@onready var acceleration_bar: ProgressBar = %AccelerationBar
@onready var handling_bar: ProgressBar = %HandlingBar
@onready var armor_bar: ProgressBar = %ArmorBar
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var reactor_bar: ProgressBar = %ReactorBar

@onready var engine_level: Label = %EngineLevel
@onready var servos_level: Label = %ServosLevel
@onready var reactor_level: Label = %ReactorLevel
@onready var armor_level: Label = %ArmorLevel
@onready var engine_button: Button = %EngineButton
@onready var servos_button: Button = %ServosButton
@onready var reactor_button: Button = %ReactorButton
@onready var armor_button: Button = %ArmorButton

var _entries: Array[Dictionary] = []
var _current_id := ""
var _profile: Dictionary = {}


func _ready() -> void:
	theme = ThemeFactory.create_theme(_settings())
	_bind_actions()
	_populate_paints()
	_bind_save_events()
	refresh()
	call_deferred("_configure_focus")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and is_node_ready():
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func refresh() -> void:
	_profile = _read_profile()
	theme = ThemeFactory.create_theme(_settings())
	credits_value.text = "%s CR" % _format_number(_number(_profile, "credits", 0.0))
	var previous_id := _current_id
	if previous_id.is_empty():
		previous_id = _string(_profile, "selected_chassis", "biped")
	_entries = GameDatabase.get_all_chassis()
	chassis_list.clear()
	var selection_index := 0
	for index in range(_entries.size()):
		var chassis := _entries[index]
		var chassis_id := String(chassis.get("id", ""))
		var locked := not _is_unlocked(chassis_id)
		var prefix := "VERROUILLÉ  //  " if locked else ""
		chassis_list.add_item("%s%s\n%s" % [prefix, String(chassis.get("category", "ARCHITECTURE")), String(chassis.get("name", chassis_id))])
		chassis_list.set_item_metadata(index, chassis_id)
		chassis_list.set_item_disabled(index, locked)
		if chassis_id == previous_id:
			selection_index = index
	if not _entries.is_empty():
		if chassis_list.is_item_disabled(selection_index):
			selection_index = _first_unlocked_index()
		chassis_list.select(selection_index)
		_show_chassis(selection_index)


func _bind_actions() -> void:
	chassis_list.item_selected.connect(_show_chassis)
	chassis_list.item_activated.connect(_activate_chassis)
	paint_option.item_selected.connect(_on_paint_selected)
	select_button.pressed.connect(_select_current)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	engine_button.pressed.connect(_buy_upgrade.bind("engine"))
	servos_button.pressed.connect(_buy_upgrade.bind("servos"))
	reactor_button.pressed.connect(_buy_upgrade.bind("reactor"))
	armor_button.pressed.connect(_buy_upgrade.bind("armor"))


func _bind_save_events() -> void:
	var save := _save_system()
	if save == null:
		return
	var callback := Callable(self, "_on_profile_changed")
	var profile_signals: Array[StringName] = [&"profile_loaded", &"profile_changed"]
	for signal_name: StringName in profile_signals:
		if save.has_signal(signal_name) and not save.is_connected(signal_name, callback):
			save.connect(signal_name, callback)
	var failure := Callable(self, "_on_save_failed")
	if save.has_signal(&"save_failed") and not save.is_connected(&"save_failed", failure):
		save.connect(&"save_failed", failure)


func _populate_paints() -> void:
	paint_option.clear()
	var names := ["CYAN ION", "CORAIL", "VERT NEXUS", "JAUNE SOLAIRE", "VIOLET PHASE", "MAGENTA", "BLANC CERAMIQUE", "GRAPHITE"]
	for index in range(GameDatabase.DEFAULT_PAINTS.size()):
		paint_option.add_item(names[index] if index < names.size() else "PEINTURE %02d" % (index + 1))
		paint_option.set_item_metadata(index, GameDatabase.DEFAULT_PAINTS[index])


func _show_chassis(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var chassis := _entries[index]
	_current_id = String(chassis.get("id", ""))
	chassis_category.text = String(chassis.get("category", "ARCHITECTURE")).to_upper()
	chassis_name.text = String(chassis.get("name", _current_id)).to_upper()
	chassis_subtitle.text = String(chassis.get("subtitle", "Configuration de course"))
	chassis_description.text = String(chassis.get("description", ""))
	ability_name.text = String(chassis.get("ability", "Système propriétaire")).to_upper()
	ability_description.text = String(chassis.get("ability_description", ""))
	var stats: Dictionary = chassis.get("stats", {})
	_set_stat(speed_bar, stats.get("speed", 0))
	_set_stat(acceleration_bar, stats.get("acceleration", 0))
	_set_stat(handling_bar, stats.get("handling", 0))
	_set_stat(armor_bar, stats.get("armor", 0))
	_set_stat(stability_bar, stats.get("stability", 0))
	_set_stat(reactor_bar, stats.get("reactor", 0))

	var selected_id := _string(_profile, "selected_chassis", "biped")
	var is_selected := _current_id == selected_id
	selected_badge.text = "ACTIF" if is_selected else "DISPONIBLE"
	selected_badge.theme_type_variation = &"MetricLabel" if is_selected else &"MutedLabel"
	select_button.disabled = is_selected or not _is_unlocked(_current_id)
	select_button.text = "CHÂSSIS ACTIF" if is_selected else "ÉQUIPER CE CHÂSSIS"
	_sync_paint(chassis)
	_refresh_upgrades()
	status_message.text = "ARCHITECTURE %02d / %02d" % [index + 1, _entries.size()]


func _activate_chassis(index: int) -> void:
	_show_chassis(index)
	_select_current()


func _select_current() -> void:
	if _current_id.is_empty() or not _is_unlocked(_current_id):
		return
	var save := _save_system()
	if save != null and save.has_method(&"select_chassis"):
		save.call(&"select_chassis", _current_id)
	_profile["selected_chassis"] = _current_id
	status_message.text = "%s // CHÂSSIS ÉQUIPÉ" % chassis_name.text
	refresh()


func _on_paint_selected(index: int) -> void:
	if index < 0:
		return
	var paint := String(paint_option.get_item_metadata(index))
	paint_preview.color = Color(paint)
	var save := _save_system()
	if save != null and save.has_method(&"set_paint"):
		save.call(&"set_paint", _current_id, paint)
	status_message.text = "PEINTURE %s APPLIQUÉE" % paint_option.get_item_text(index)


func _sync_paint(chassis: Dictionary) -> void:
	var paints: Dictionary = _profile.get("paints", {})
	var paint := String(paints.get(_current_id, chassis.get("paint", "#5EE7FF")))
	var closest := 0
	for index in range(paint_option.item_count):
		if String(paint_option.get_item_metadata(index)).to_upper() == paint.to_upper():
			closest = index
			break
	paint_option.select(closest)
	paint_preview.color = Color(paint)


func _buy_upgrade(upgrade_id: String) -> void:
	var upgrade := GameDatabase.get_upgrade(upgrade_id)
	var level := _upgrade_level(upgrade_id)
	var costs: Array = upgrade.get("costs", [])
	if level >= costs.size():
		status_message.text = "%s // NIVEAU MAXIMUM" % String(upgrade.get("name", upgrade_id)).to_upper()
		return
	var cost := int(costs[level])
	if int(_number(_profile, "credits", 0.0)) < cost:
		status_message.text = "CRÉDITS INSUFFISANTS // %d CR REQUIS" % cost
		status_message.theme_type_variation = &"WarningLabel"
		return
	var save := _save_system()
	if save != null and save.has_method(&"buy_upgrade"):
		var result: Variant = save.call(&"buy_upgrade", upgrade_id)
		if result is bool and not result:
			status_message.text = "AMÉLIORATION REFUSÉE"
			status_message.theme_type_variation = &"WarningLabel"
			return
	status_message.theme_type_variation = &"MutedLabel"
	status_message.text = "%s // INSTALLATION TERMINÉE" % String(upgrade.get("name", upgrade_id)).to_upper()
	refresh()


func _refresh_upgrades() -> void:
	_update_upgrade_ui("engine", engine_level, engine_button)
	_update_upgrade_ui("servos", servos_level, servos_button)
	_update_upgrade_ui("reactor", reactor_level, reactor_button)
	_update_upgrade_ui("armor", armor_level, armor_button)


func _update_upgrade_ui(upgrade_id: String, level_label: Label, button: Button) -> void:
	var upgrade := GameDatabase.get_upgrade(upgrade_id)
	var level := _upgrade_level(upgrade_id)
	var costs: Array = upgrade.get("costs", [])
	level_label.text = "NIVEAU %d / %d" % [level, costs.size()]
	if level >= costs.size():
		button.text = "MAXIMUM"
		button.disabled = true
	else:
		button.text = "INSTALLER  •  %d CR" % int(costs[level])
		button.disabled = false


func _upgrade_level(upgrade_id: String) -> int:
	var upgrades: Variant = _profile.get("upgrades", {})
	if upgrades is Dictionary:
		var upgrades_dictionary: Dictionary = upgrades
		var chassis_upgrades: Variant = upgrades_dictionary.get(_current_id, {})
		if chassis_upgrades is Dictionary:
			var chassis_upgrade_dictionary: Dictionary = chassis_upgrades
			if not chassis_upgrade_dictionary.is_empty():
				return int(chassis_upgrade_dictionary.get(upgrade_id, 0))
		return int(upgrades_dictionary.get(upgrade_id, 0))
	return 0


func _is_unlocked(chassis_id: String) -> bool:
	var unlocked: Variant = _profile.get("unlocked_chassis", _profile.get("unlockedChassis", []))
	if unlocked is Array:
		var unlocked_chassis: Array = unlocked
		if not unlocked_chassis.is_empty():
			return chassis_id in unlocked_chassis
	return true


func _first_unlocked_index() -> int:
	for index in range(_entries.size()):
		if _is_unlocked(String(_entries[index].get("id", ""))):
			return index
	return 0


func _set_stat(bar: ProgressBar, value: Variant) -> void:
	bar.value = clampf(float(value), 0.0, 100.0)
	bar.tooltip_text = "%s sur 100" % roundi(bar.value)


func _configure_focus() -> void:
	ThemeFactory.connect_focus_chain([
		chassis_list, select_button, paint_option,
		engine_button, servos_button, reactor_button, armor_button, back_button,
	])
	chassis_list.grab_focus()


func _on_profile_changed(_data: Dictionary = {}) -> void:
	refresh()


func _on_save_failed(message: String = "Sauvegarde indisponible") -> void:
	status_message.text = "ALERTE SAUVEGARDE // %s" % message.to_upper()
	status_message.theme_type_variation = &"WarningLabel"


func _save_system() -> Node:
	return get_node_or_null("/root/SaveSystem")


func _read_profile() -> Dictionary:
	var save := _save_system()
	if save == null:
		return {}
	var value: Variant = save.get("profile")
	if value is Dictionary:
		var profile_dictionary: Dictionary = value
		return profile_dictionary.duplicate(true)
	return {}


func _settings() -> Dictionary:
	var profile := _read_profile()
	var value: Variant = profile.get("settings", {})
	return value if value is Dictionary else {}


func _string(source: Dictionary, key: String, fallback: String) -> String:
	if source.has(key):
		return str(source[key])
	var camel := key.get_slice("_", 0)
	for part_index in range(1, key.get_slice_count("_")):
		camel += key.get_slice("_", part_index).capitalize()
	return str(source.get(camel, fallback))


func _number(source: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = source.get(key, fallback)
	return float(value) if value is int or value is float else fallback


func _format_number(value: float) -> String:
	var raw := str(roundi(value))
	var output := ""
	while raw.length() > 3:
		output = " %s%s" % [raw.right(3), output]
		raw = raw.left(raw.length() - 3)
	return raw + output
