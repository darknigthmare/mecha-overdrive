extends Control
class_name GarageScreen

signal back_requested

const ThemeFactory = preload("res://scripts/ui/ui_theme.gd")
const STAT_IDS: Array[String] = ["speed", "acceleration", "handling", "armor", "stability", "reactor"]
const PRESETS: Dictionary = {
	"balanced": {"core": "core_balanced", "mobility": "mobility_vector", "utility": "utility_coolant"},
	"speed": {"core": "core_overdrive", "mobility": "mobility_sprint", "utility": "utility_scanner"},
	"control": {"core": "core_balanced", "mobility": "mobility_adaptive", "utility": "utility_scanner"},
	"armor": {"core": "core_bastion", "mobility": "mobility_adaptive", "utility": "utility_aegis"},
}

@onready var credits_value: Label = %CreditsValue
@onready var division_filter: OptionButton = %DivisionFilter
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
@onready var locomotion_option: OptionButton = %LocomotionOption
@onready var locomotion_detail: Label = %LocomotionDetail
@onready var core_option: OptionButton = %CoreOption
@onready var mobility_option: OptionButton = %MobilityOption
@onready var utility_option: OptionButton = %UtilityOption
@onready var module_detail: Label = %ModuleDetail
@onready var module_summary: Label = %ModuleSummary
@onready var purchase_summary: Label = %PurchaseSummary
@onready var apply_button: Button = %ApplyButton
@onready var cancel_button: Button = %CancelButton
@onready var select_button: Button = %SelectButton
@onready var back_button: Button = %BackButton
@onready var status_message: Label = %StatusMessage
@onready var garage_preview: Control = %GaragePreview
@onready var preset_balanced: Button = %PresetBalanced
@onready var preset_speed: Button = %PresetSpeed
@onready var preset_control: Button = %PresetControl
@onready var preset_armor: Button = %PresetArmor

@onready var speed_bar: ProgressBar = %SpeedBar
@onready var acceleration_bar: ProgressBar = %AccelerationBar
@onready var handling_bar: ProgressBar = %HandlingBar
@onready var armor_bar: ProgressBar = %ArmorBar
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var reactor_bar: ProgressBar = %ReactorBar
@onready var speed_value: Label = %SpeedValue
@onready var acceleration_value: Label = %AccelerationValue
@onready var handling_value: Label = %HandlingValue
@onready var armor_value: Label = %ArmorValue
@onready var stability_value: Label = %StabilityValue
@onready var reactor_value: Label = %ReactorValue

@onready var engine_level: Label = %EngineLevel
@onready var servos_level: Label = %ServosLevel
@onready var reactor_level: Label = %ReactorLevel
@onready var armor_level: Label = %ArmorLevel
@onready var engine_button: Button = %EngineButton
@onready var servos_button: Button = %ServosButton
@onready var reactor_button: Button = %ReactorButton
@onready var armor_button: Button = %ArmorButton

var _all_entries: Array[Dictionary] = []
var _entries: Array[Dictionary] = []
var _current_id := ""
var _profile: Dictionary = {}
var _drafts: Dictionary = {}
var _draft_paint := "#5EE7FF"
var _draft_loadout: Dictionary = {}
var _draft_locomotion_id := ""
var _focused_slot := "core"
var _syncing := false


func _ready() -> void:
	theme = ThemeFactory.create_theme(_settings())
	_bind_actions()
	_populate_divisions()
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
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		var handled := true
		match key_event.keycode:
			KEY_Q:
				_preview_call(&"rotate_left")
			KEY_E:
				_preview_call(&"rotate_right")
			KEY_MINUS, KEY_KP_SUBTRACT:
				_preview_call(&"zoom_out")
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_preview_call(&"zoom_in")
			KEY_R:
				_preview_call(&"reset_view")
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()


func refresh() -> void:
	_profile = _read_profile()
	theme = ThemeFactory.create_theme(_settings())
	credits_value.text = "%s CR" % _format_number(_number(_profile, "credits", 0.0))
	_all_entries = GameDatabase.get_all_chassis()
	_refresh_roster()


func _bind_actions() -> void:
	division_filter.item_selected.connect(_on_division_filter_selected)
	chassis_list.item_selected.connect(_show_chassis)
	chassis_list.item_activated.connect(_activate_chassis)
	paint_option.item_selected.connect(_on_paint_selected)
	locomotion_option.item_selected.connect(_on_locomotion_selected)
	core_option.item_selected.connect(_on_module_selected.bind("core", core_option))
	mobility_option.item_selected.connect(_on_module_selected.bind("mobility", mobility_option))
	utility_option.item_selected.connect(_on_module_selected.bind("utility", utility_option))
	preset_balanced.pressed.connect(_apply_preset.bind("balanced"))
	preset_speed.pressed.connect(_apply_preset.bind("speed"))
	preset_control.pressed.connect(_apply_preset.bind("control"))
	preset_armor.pressed.connect(_apply_preset.bind("armor"))
	apply_button.pressed.connect(_apply_draft)
	cancel_button.pressed.connect(_cancel_draft)
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
	for signal_name: StringName in [&"profile_loaded", &"profile_changed"]:
		if save.has_signal(signal_name) and not save.is_connected(signal_name, callback):
			save.connect(signal_name, callback)
	var failure := Callable(self, "_on_save_failed")
	if save.has_signal(&"save_failed") and not save.is_connected(&"save_failed", failure):
		save.connect(&"save_failed", failure)


func _populate_divisions() -> void:
	division_filter.clear()
	division_filter.add_item("TOUTES LES DIVISIONS")
	division_filter.set_item_metadata(0, "")
	for division: Dictionary in GameDatabase.get_all_divisions():
		var index := division_filter.item_count
		division_filter.add_item("%s  //  %s" % [String(division.get("short", "DIV")), String(division.get("name", "DIVISION")).to_upper()])
		division_filter.set_item_metadata(index, String(division.get("id", "")))


func _populate_paints() -> void:
	paint_option.clear()
	var names := ["CYAN ION", "CORAIL", "VERT NEXUS", "JAUNE SOLAIRE", "VIOLET PHASE", "MAGENTA", "BLANC CÉRAMIQUE", "GRAPHITE"]
	for index in range(GameDatabase.DEFAULT_PAINTS.size()):
		paint_option.add_item(names[index] if index < names.size() else "PEINTURE %02d" % (index + 1))
		paint_option.set_item_metadata(index, GameDatabase.DEFAULT_PAINTS[index])


func _on_division_filter_selected(_index: int) -> void:
	_store_current_draft()
	_refresh_roster()


func _refresh_roster() -> void:
	var filter_id := ""
	if division_filter.selected >= 0:
		filter_id = String(division_filter.get_item_metadata(division_filter.selected))
	var previous_id := _current_id if not _current_id.is_empty() else _string(_profile, "selected_chassis", "biped")
	_entries.clear()
	chassis_list.clear()
	var selection_index := -1
	for chassis: Dictionary in _all_entries:
		if not filter_id.is_empty() and String(chassis.get("division_id", "")) != filter_id:
			continue
		var chassis_id := String(chassis.get("id", ""))
		var division := GameDatabase.get_division(String(chassis.get("division_id", "")))
		var locked := not _is_unlocked(chassis_id)
		_entries.append(chassis)
		var index := _entries.size() - 1
		var prefix := "VERROUILLÉ  //  " if locked else ""
		chassis_list.add_item("%s%s  //  %s  •  %s" % [
			prefix, String(chassis.get("name", chassis_id)).to_upper(),
			String(chassis.get("category", "ARCHITECTURE")), String(division.get("short", "DIV")),
		])
		chassis_list.set_item_metadata(index, chassis_id)
		chassis_list.set_item_disabled(index, locked)
		chassis_list.set_item_tooltip(index, String(chassis.get("subtitle", "")))
		if chassis_id == previous_id:
			selection_index = index
	if _entries.is_empty():
		return
	if selection_index < 0 or chassis_list.is_item_disabled(selection_index):
		selection_index = _first_unlocked_index()
	chassis_list.select(selection_index)
	_show_chassis(selection_index)


func _show_chassis(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_store_current_draft()
	var chassis := _entries[index]
	_current_id = String(chassis.get("id", ""))
	var division := GameDatabase.get_division(String(chassis.get("division_id", "command")))
	chassis_category.text = "%s  //  DIVISION %s" % [
		String(chassis.get("category", "ARCHITECTURE")).to_upper(),
		String(division.get("name", "DIVISION")).to_upper(),
	]
	chassis_name.text = String(chassis.get("name", _current_id)).to_upper()
	chassis_subtitle.text = String(chassis.get("subtitle", "Configuration de course"))
	chassis_description.text = "%s  //  %s\n%s" % [
		String(chassis.get("manufacturer", "NEXUS WORKS")).to_upper(),
		String(division.get("short", "DIV")),
		String(chassis.get("lore", chassis.get("description", ""))),
	]
	ability_name.text = String(chassis.get("ability", "Système propriétaire")).to_upper()
	ability_description.text = String(chassis.get("ability_description", ""))
	var selected_id := _string(_profile, "selected_chassis", "biped")
	var is_selected := _current_id == selected_id
	selected_badge.text = "ACTIF" if is_selected else "PRÊT"
	selected_badge.theme_type_variation = &"MetricLabel" if is_selected else &"MutedLabel"
	select_button.disabled = is_selected or not _is_unlocked(_current_id)
	select_button.text = "CHÂSSIS ACTIF" if is_selected else "ÉQUIPER CE CHÂSSIS"
	_load_draft(chassis)
	_populate_locomotions_for_current()
	_populate_modules_for_current()
	_refresh_configuration()
	_refresh_upgrades()
	status_message.theme_type_variation = &"MutedLabel"
	status_message.text = "ARCHITECTURE %02d / %02d  //  Q E : ROTATION  •  MOLETTE : ZOOM" % [index + 1, _entries.size()]


func _load_draft(chassis: Dictionary) -> void:
	var paints: Dictionary = _profile.get("paints", {}) if _profile.get("paints", {}) is Dictionary else {}
	var all_loadouts: Dictionary = _profile.get("loadouts", {}) if _profile.get("loadouts", {}) is Dictionary else {}
	var all_locomotions: Dictionary = _profile.get("locomotions", {}) if _profile.get("locomotions", {}) is Dictionary else {}
	var saved_paint := String(paints.get(_current_id, chassis.get("paint", "#5EE7FF")))
	var saved_loadout: Dictionary = all_loadouts.get(_current_id, chassis.get("default_loadout", {})) if all_loadouts.get(_current_id, {}) is Dictionary else {}
	var saved_locomotion := String(all_locomotions.get(_current_id, LocomotionCatalog.get_default_configuration_id(_current_id)))
	var draft: Dictionary = _drafts.get(_current_id, {}) if _drafts.get(_current_id, {}) is Dictionary else {}
	_draft_paint = String(draft.get("paint", saved_paint))
	_draft_loadout = Dictionary(draft.get("loadout", saved_loadout)).duplicate(true)
	var requested_locomotion := String(draft.get("locomotion_id", saved_locomotion))
	_draft_locomotion_id = String(LocomotionCatalog.resolve_configuration(chassis, {"locomotion_id": requested_locomotion}).get("id", ""))
	_sync_paint()


func _store_current_draft() -> void:
	if _current_id.is_empty() or _draft_loadout.is_empty():
		return
	_drafts[_current_id] = {
		"paint": _draft_paint,
		"loadout": _draft_loadout.duplicate(true),
		"locomotion_id": _draft_locomotion_id,
	}


func _sync_paint() -> void:
	var closest := 0
	for index in range(paint_option.item_count):
		if String(paint_option.get_item_metadata(index)).to_upper() == _draft_paint.to_upper():
			closest = index
			break
	_syncing = true
	paint_option.select(closest)
	_syncing = false
	paint_preview.color = Color(_draft_paint)


func _populate_modules_for_current() -> void:
	_syncing = true
	_populate_module_option("core", core_option)
	_populate_module_option("mobility", mobility_option)
	_populate_module_option("utility", utility_option)
	_syncing = false


func _populate_locomotions_for_current() -> void:
	_syncing = true
	locomotion_option.clear()
	var configurations := LocomotionCatalog.get_configurations_for_chassis(_current_id)
	for configuration: Dictionary in configurations:
		var index := locomotion_option.item_count
		var configuration_id := String(configuration.get("id", ""))
		var owned := _is_locomotion_owned(configuration_id)
		var ownership := "POSSÉDÉ" if owned else "%d CR" % int(configuration.get("cost", 0))
		locomotion_option.add_item("%02d  //  %s  •  T%d  •  %s" % [
			index + 1,
			String(configuration.get("short_name", configuration.get("name", "LOCOMOTION"))),
			int(configuration.get("tier", 0)),
			ownership,
		])
		locomotion_option.set_item_metadata(index, configuration_id)
		locomotion_option.set_item_tooltip(index, "%s  //  %s  //  PUISSANCE %d" % [
			String(configuration.get("description", "")),
			_format_deltas(configuration.get("stats", {})),
			int(configuration.get("power_draw", 0)),
		])
	_select_locomotion_value(_draft_locomotion_id)
	if locomotion_option.selected >= 0:
		_draft_locomotion_id = String(locomotion_option.get_item_metadata(locomotion_option.selected))
	_syncing = false


func _select_locomotion_value(locomotion_id: String) -> void:
	for index in range(locomotion_option.item_count):
		if String(locomotion_option.get_item_metadata(index)) == locomotion_id:
			locomotion_option.select(index)
			return
	if locomotion_option.item_count > 0:
		locomotion_option.select(0)


func _populate_module_option(slot_id: String, option_button: OptionButton) -> void:
	option_button.clear()
	var slot := GameDatabase.get_module_slot(slot_id)
	var chassis := GameDatabase.get_chassis(_current_id)
	var division_id := String(chassis.get("division_id", ""))
	for option: Dictionary in slot.get("options", []):
		var module_id := String(option.get("id", ""))
		if not GameDatabase.is_module_allowed_for_division(module_id, division_id):
			continue
		var owned := _is_module_owned(module_id)
		var label := String(option.get("name", "MODULE")).to_upper()
		if not owned:
			label += "  //  %d CR" % int(option.get("cost", 0))
		var index := option_button.item_count
		option_button.add_item(label)
		option_button.set_item_metadata(index, module_id)
		option_button.set_item_tooltip(index, String(option.get("description", "")))
	var requested := String(_draft_loadout.get(slot_id, slot.get("default_option_id", "")))
	_select_module_value(option_button, requested)
	_draft_loadout[slot_id] = _selected_module_id(option_button)


func _select_module_value(option_button: OptionButton, module_id: String) -> void:
	for index in range(option_button.item_count):
		if String(option_button.get_item_metadata(index)) == module_id:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)


func _on_paint_selected(index: int) -> void:
	if _syncing or _current_id.is_empty() or index < 0:
		return
	_draft_paint = String(paint_option.get_item_metadata(index))
	paint_preview.color = Color(_draft_paint)
	_store_current_draft()
	_refresh_configuration()
	status_message.theme_type_variation = &"MutedLabel"
	status_message.text = "APERÇU PEINTURE // APPLIQUEZ POUR SAUVEGARDER"


func _on_module_selected(index: int, slot_id: String, option_button: OptionButton) -> void:
	if _syncing or _current_id.is_empty() or index < 0 or index >= option_button.item_count:
		return
	_focused_slot = slot_id
	_draft_loadout[slot_id] = String(option_button.get_item_metadata(index))
	_store_current_draft()
	_refresh_configuration()
	status_message.theme_type_variation = &"MutedLabel"
	status_message.text = "%s // APERÇU INSTALLÉ, VALIDATION EN ATTENTE" % option_button.get_item_text(index)


func _on_locomotion_selected(index: int) -> void:
	if _syncing or _current_id.is_empty() or index < 0 or index >= locomotion_option.item_count:
		return
	_draft_locomotion_id = String(locomotion_option.get_item_metadata(index))
	_store_current_draft()
	_refresh_configuration()
	status_message.theme_type_variation = &"MutedLabel"
	status_message.text = "%s // APERÇU 3D INSTANTANÉ, VALIDATION EN ATTENTE" % locomotion_option.get_item_text(index)


func _apply_preset(preset_id: String) -> void:
	var preset: Dictionary = PRESETS.get(preset_id, {})
	if preset.is_empty():
		return
	for slot_id: String in preset.keys():
		_draft_loadout[slot_id] = preset[slot_id]
	_populate_modules_for_current()
	_store_current_draft()
	_refresh_configuration()
	status_message.text = "PRÉRÉGLAGE %s // APERÇU PRÊT" % preset_id.to_upper()


func _refresh_configuration() -> void:
	_update_preview()
	_refresh_stats()
	_refresh_locomotion_detail()
	_refresh_module_detail()
	_refresh_module_summary()
	_refresh_apply_state()


func _update_preview() -> void:
	var chassis := GameDatabase.get_chassis(_current_id)
	if chassis.is_empty():
		return
	var settings := _settings()
	if garage_preview.has_method(&"refresh_theme"):
		garage_preview.call(&"refresh_theme", settings)
	if garage_preview.has_method(&"configure"):
		var customization := _draft_loadout.duplicate(true)
		customization["locomotion_id"] = _draft_locomotion_id
		garage_preview.call(&"configure", chassis, Color(_draft_paint), customization)
	if garage_preview.has_method(&"set_reduced_motion"):
		garage_preview.call(&"set_reduced_motion", bool(settings.get("reduced_motion", false)))


func _refresh_stats() -> void:
	var chassis := GameDatabase.get_chassis(_current_id)
	var base: Dictionary = chassis.get("stats", {}) if chassis.get("stats", {}) is Dictionary else {}
	var totals := GameDatabase.calculate_module_totals(_draft_loadout)
	var locomotion := LocomotionCatalog.get_configuration(_draft_locomotion_id)
	var locomotion_stats: Dictionary = locomotion.get("stats", {}) if locomotion.get("stats", {}) is Dictionary else {}
	var final_values: Dictionary = {}
	for stat_id: String in STAT_IDS:
		final_values[stat_id] = int(base.get(stat_id, 0)) + int(totals.get(stat_id, 0)) + int(locomotion_stats.get(stat_id, 0))
	var engine := _upgrade_level("engine")
	var servos := _upgrade_level("servos")
	var cooling := _upgrade_level("reactor")
	var armor_upgrade := _upgrade_level("armor")
	final_values["speed"] += roundi(float(base.get("speed", 0)) * 0.035 * engine)
	final_values["acceleration"] += roundi(float(base.get("acceleration", 0)) * 0.045 * servos)
	final_values["handling"] += roundi(float(base.get("handling", 0)) * 0.035 * servos)
	final_values["armor"] += roundi(float(base.get("armor", 0)) * 0.060 * armor_upgrade)
	final_values["reactor"] += roundi(float(base.get("reactor", 0)) * 0.055 * cooling)
	_set_stat(speed_bar, speed_value, int(base.get("speed", 0)), int(final_values["speed"]))
	_set_stat(acceleration_bar, acceleration_value, int(base.get("acceleration", 0)), int(final_values["acceleration"]))
	_set_stat(handling_bar, handling_value, int(base.get("handling", 0)), int(final_values["handling"]))
	_set_stat(armor_bar, armor_value, int(base.get("armor", 0)), int(final_values["armor"]))
	_set_stat(stability_bar, stability_value, int(base.get("stability", 0)), int(final_values["stability"]))
	_set_stat(reactor_bar, reactor_value, int(base.get("reactor", 0)), int(final_values["reactor"]))


func _set_stat(bar: ProgressBar, value_label: Label, base_value: int, configured_value: int) -> void:
	var final_value := clampi(configured_value, 0, 100)
	var delta := final_value - base_value
	bar.value = final_value
	bar.tooltip_text = "Base %d, configuration %d, variation %+d" % [base_value, final_value, delta]
	value_label.text = "%d > %d  (%+d)" % [base_value, final_value, delta]
	value_label.theme_type_variation = &"MetricLabel" if delta >= 0 else &"WarningLabel"


func _refresh_module_detail() -> void:
	var option_button := _option_for_slot(_focused_slot)
	var module_id := _selected_module_id(option_button)
	var option := GameDatabase.get_module_option(_focused_slot, module_id)
	if option.is_empty():
		module_detail.text = "Sélectionnez un module pour afficher sa fiche."
		return
	var allowed: Array = option.get("allowed_divisions", [])
	var division_names := PackedStringArray()
	for division_id: Variant in allowed:
		var division := GameDatabase.get_division(String(division_id))
		division_names.append(String(division.get("short", division_id)).to_upper())
	var affinity := "TOUTES DIVISIONS" if division_names.is_empty() else "AFFINITÉ " + " / ".join(division_names)
	var state := "POSSÉDÉ" if _is_module_owned(module_id) else "À ACQUÉRIR • %d CR" % int(option.get("cost", 0))
	module_detail.text = "%s  //  %s\n%s  •  TIER %d  •  %s\n%s\n%s\n%s" % [
		String(option.get("name", module_id)).to_upper(),
		String(option.get("manufacturer", "NEXUS RACING")).to_upper(),
		String(option.get("role", "Polyvalent")).to_upper(),
		int(option.get("tier", 0)),
		state,
		String(option.get("description", "")),
		_format_deltas(option.get("stats", {})),
		affinity,
	]


func _refresh_locomotion_detail() -> void:
	var configuration := LocomotionCatalog.get_configuration(_draft_locomotion_id)
	if configuration.is_empty():
		locomotion_detail.text = "Sélectionnez une locomotion pour afficher sa fiche."
		return
	var ownership := "POSSÉDÉ" if _is_locomotion_owned(_draft_locomotion_id) else "À ACQUÉRIR • %d CR" % int(configuration.get("cost", 0))
	locomotion_detail.text = "%s  //  %s  •  TIER %d  •  %s\n%s\n%s  •  PUISSANCE %d" % [
		String(configuration.get("name", "LOCOMOTION")).to_upper(),
		String(configuration.get("manufacturer", "NEXUS RACING")).to_upper(),
		int(configuration.get("tier", 0)),
		ownership,
		String(configuration.get("description", "")),
		_format_deltas(configuration.get("stats", {})),
		int(configuration.get("power_draw", 0)),
	]


func _refresh_module_summary() -> void:
	var names := PackedStringArray()
	for slot_id: String in ["core", "mobility", "utility"]:
		var option := GameDatabase.get_module_option(slot_id, String(_draft_loadout.get(slot_id, "")))
		names.append(String(option.get("name", "MODULE")).to_upper())
	var locomotion := LocomotionCatalog.get_configuration(_draft_locomotion_id)
	names.append(String(locomotion.get("short_name", "LOCOMOTION")).to_upper())
	var totals := GameDatabase.calculate_module_totals(_draft_loadout)
	var locomotion_stats: Dictionary = locomotion.get("stats", {}) if locomotion.get("stats", {}) is Dictionary else {}
	for stat_id: String in STAT_IDS:
		totals[stat_id] = int(totals.get(stat_id, 0)) + int(locomotion_stats.get(stat_id, 0))
	module_summary.text = "%s\nTOTAL CONFIGURATION  //  %s" % ["  /  ".join(names), _format_deltas(totals)]


func _refresh_apply_state() -> void:
	var cost := _current_loadout_cost()
	var dirty := _is_draft_dirty()
	var credits := int(_number(_profile, "credits", 0.0))
	apply_button.disabled = not dirty or cost < 0 or cost > credits
	cancel_button.disabled = not dirty
	if cost < 0:
		apply_button.text = "CONFIGURATION INCOMPATIBLE"
		purchase_summary.text = "Cette combinaison ne peut pas être homologuée pour la division technique active."
	elif cost > credits:
		apply_button.text = "CRÉDITS INSUFFISANTS"
		purchase_summary.text = "Coût %d CR  •  Solde %d CR  •  Manque %d CR" % [cost, credits, cost - credits]
	elif cost > 0:
		apply_button.text = "ACHETER + APPLIQUER  •  %d CR" % cost
		purchase_summary.text = "Achat définitif des nouveaux modules, peinture et montage inclus."
	elif dirty:
		apply_button.text = "APPLIQUER LA CONFIGURATION"
		purchase_summary.text = "Tous les modules sélectionnés sont possédés."
	else:
		apply_button.text = "CONFIGURATION ACTIVE"
		purchase_summary.text = "Aucune modification en attente."


func _apply_draft() -> void:
	if _current_id.is_empty() or not _is_draft_dirty():
		return
	var save := _save_system()
	if save == null or not save.has_method(&"purchase_and_apply_garage"):
		_show_error("SERVICE GARAGE INDISPONIBLE")
		return
	var retained := {
		"paint": _draft_paint,
		"loadout": _draft_loadout.duplicate(true),
		"locomotion_id": _draft_locomotion_id,
	}
	_drafts.erase(_current_id)
	var result: Variant = save.call(&"purchase_and_apply_garage", _current_id, _draft_paint, _draft_loadout.duplicate(true), _draft_locomotion_id)
	if not (result is bool and result):
		_drafts[_current_id] = retained
		_show_error("ACHAT OU MONTAGE REFUSÉ")
		return
	status_message.theme_type_variation = &"MetricLabel"
	status_message.text = "CONFIGURATION SAUVEGARDÉE // MÉCHA PRÊT POUR LA COURSE"
	refresh()


func _cancel_draft() -> void:
	_drafts.erase(_current_id)
	# Prevent _show_chassis() from persisting the outgoing draft again before it
	# reloads the saved profile configuration.
	_draft_loadout.clear()
	_draft_locomotion_id = ""
	var index := chassis_list.get_selected_items()[0] if not chassis_list.get_selected_items().is_empty() else 0
	_show_chassis(index)
	status_message.text = "MODIFICATIONS ANNULÉES // CONFIGURATION SAUVEGARDÉE RESTAURÉE"


func _current_loadout_cost() -> int:
	var save := _save_system()
	if save != null and save.has_method(&"get_garage_cost"):
		return int(save.call(&"get_garage_cost", _current_id, _draft_loadout, _draft_locomotion_id))
	return 0


func _is_draft_dirty() -> bool:
	var chassis := GameDatabase.get_chassis(_current_id)
	var paints: Dictionary = _profile.get("paints", {}) if _profile.get("paints", {}) is Dictionary else {}
	var saved_paint := String(paints.get(_current_id, chassis.get("paint", "#5EE7FF")))
	if saved_paint.to_upper() != _draft_paint.to_upper():
		return true
	var all_loadouts: Dictionary = _profile.get("loadouts", {}) if _profile.get("loadouts", {}) is Dictionary else {}
	var saved: Dictionary = all_loadouts.get(_current_id, chassis.get("default_loadout", {})) if all_loadouts.get(_current_id, {}) is Dictionary else {}
	for slot_id: String in ["core", "mobility", "utility"]:
		if String(saved.get(slot_id, "")) != String(_draft_loadout.get(slot_id, "")):
			return true
	var all_locomotions: Dictionary = _profile.get("locomotions", {}) if _profile.get("locomotions", {}) is Dictionary else {}
	var saved_locomotion := String(all_locomotions.get(_current_id, LocomotionCatalog.get_default_configuration_id(_current_id)))
	if saved_locomotion != _draft_locomotion_id:
		return true
	return false


func _activate_chassis(index: int) -> void:
	_show_chassis(index)
	_select_current()


func _select_current() -> void:
	if _current_id.is_empty() or not _is_unlocked(_current_id):
		return
	var save := _save_system()
	if save == null or not save.has_method(&"select_chassis") or not bool(save.call(&"select_chassis", _current_id)):
		_show_error("SÉLECTION DU CHÂSSIS IMPOSSIBLE")
		return
	status_message.theme_type_variation = &"MetricLabel"
	status_message.text = "%s // CHÂSSIS ACTIF" % chassis_name.text


func _buy_upgrade(upgrade_id: String) -> void:
	var upgrade := GameDatabase.get_upgrade(upgrade_id)
	var level := _upgrade_level(upgrade_id)
	var costs: Array = upgrade.get("costs", [])
	if level >= costs.size():
		status_message.text = "%s // NIVEAU MAXIMUM" % String(upgrade.get("name", upgrade_id)).to_upper()
		return
	var cost := int(costs[level])
	if int(_number(_profile, "credits", 0.0)) < cost:
		_show_error("CRÉDITS INSUFFISANTS // %d CR REQUIS" % cost)
		return
	var save := _save_system()
	if not _purchase_current_upgrade(save, upgrade_id):
		_show_error("AMÉLIORATION REFUSÉE")
		return
	status_message.theme_type_variation = &"MetricLabel"
	status_message.text = "%s // INSTALLATION TERMINÉE" % String(upgrade.get("name", upgrade_id)).to_upper()


func _purchase_current_upgrade(save_system: Node, upgrade_id: String) -> bool:
	if save_system == null or not save_system.has_method(&"buy_upgrade"):
		return false
	var result: Variant = save_system.call(&"buy_upgrade", upgrade_id, _current_id)
	return result is bool and result


func _refresh_upgrades() -> void:
	_update_upgrade_ui("engine", engine_level, engine_button)
	_update_upgrade_ui("servos", servos_level, servos_button)
	_update_upgrade_ui("reactor", reactor_level, reactor_button)
	_update_upgrade_ui("armor", armor_level, armor_button)


func _update_upgrade_ui(upgrade_id: String, level_label: Label, button: Button) -> void:
	var upgrade := GameDatabase.get_upgrade(upgrade_id)
	var level := _upgrade_level(upgrade_id)
	var costs: Array = upgrade.get("costs", [])
	level_label.text = "NIVEAU %d / %d  //  %s" % [level, costs.size(), String(upgrade.get("description", ""))]
	if level >= costs.size():
		button.text = "MAXIMUM"
		button.disabled = true
	else:
		button.text = "INSTALLER  •  %d CR" % int(costs[level])
		button.disabled = false


func _upgrade_level(upgrade_id: String) -> int:
	var upgrades: Variant = _profile.get("upgrades", {})
	if upgrades is Dictionary:
		var chassis_upgrades: Variant = Dictionary(upgrades).get(_current_id, {})
		if chassis_upgrades is Dictionary:
			return int(Dictionary(chassis_upgrades).get(upgrade_id, 0))
	return 0


func _is_module_owned(module_id: String) -> bool:
	var owned: Variant = _profile.get("owned_modules", [])
	return owned is Array and module_id in owned


func _is_locomotion_owned(locomotion_id: String) -> bool:
	var owned: Variant = _profile.get("owned_locomotions", [])
	return owned is Array and locomotion_id in owned


func _selected_module_id(option_button: OptionButton) -> String:
	return String(option_button.get_item_metadata(option_button.selected)) if option_button != null and option_button.selected >= 0 else ""


func _option_for_slot(slot_id: String) -> OptionButton:
	match slot_id:
		"mobility": return mobility_option
		"utility": return utility_option
		_: return core_option


func _format_deltas(value: Variant) -> String:
	var stats: Dictionary = value if value is Dictionary else {}
	return "VIT %+d  •  ACC %+d  •  MAN %+d  •  ARM %+d  •  STB %+d  •  RÉA %+d" % [
		int(stats.get("speed", 0)), int(stats.get("acceleration", 0)),
		int(stats.get("handling", 0)), int(stats.get("armor", 0)),
		int(stats.get("stability", 0)), int(stats.get("reactor", 0)),
	]


func _preview_call(method_name: StringName) -> void:
	if garage_preview != null and garage_preview.has_method(method_name):
		garage_preview.call(method_name)


func _is_unlocked(chassis_id: String) -> bool:
	var unlocked: Variant = _profile.get("owned_chassis", _profile.get("unlocked_chassis", _profile.get("unlockedChassis", [])))
	if unlocked is Array and not Array(unlocked).is_empty():
		return chassis_id in unlocked
	return true


func _first_unlocked_index() -> int:
	for index in range(_entries.size()):
		if _is_unlocked(String(_entries[index].get("id", ""))):
			return index
	return 0


func _configure_focus() -> void:
	var focus_chain: Array[Control] = [division_filter, chassis_list]
	if garage_preview != null and garage_preview.has_method(&"focus_controls"):
		var preview_controls: Variant = garage_preview.call(&"focus_controls")
		if preview_controls is Array:
			for value: Variant in preview_controls:
				if value is Control:
					focus_chain.append(value)
	focus_chain.append_array([
		select_button, paint_option,
		preset_balanced, preset_speed, preset_control, preset_armor,
		locomotion_option, core_option, mobility_option, utility_option, apply_button, cancel_button,
		engine_button, servos_button, reactor_button, armor_button, back_button,
	])
	ThemeFactory.connect_focus_chain(focus_chain)
	chassis_list.grab_focus()


func _on_profile_changed(_data: Dictionary = {}) -> void:
	refresh()


func _on_save_failed(message: String = "Sauvegarde indisponible") -> void:
	_show_error("ALERTE SAUVEGARDE // %s" % message.to_upper())


func _show_error(message: String) -> void:
	status_message.text = message
	status_message.theme_type_variation = &"WarningLabel"


func _save_system() -> Node:
	return get_node_or_null("/root/SaveSystem")


func _read_profile() -> Dictionary:
	var save := _save_system()
	if save == null:
		return {}
	var value: Variant = save.get("profile")
	return Dictionary(value).duplicate(true) if value is Dictionary else {}


func _settings() -> Dictionary:
	var value: Variant = _profile.get("settings", {}) if not _profile.is_empty() else _read_profile().get("settings", {})
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
