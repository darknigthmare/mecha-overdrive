extends Control
class_name CodexScreen

signal back_requested

const ThemeFactory = preload("res://scripts/ui/ui_theme.gd")
const LoreData = preload("res://scripts/data/lore_database.gd")

@onready var chassis_tab: Button = %ChassisTab
@onready var tracks_tab: Button = %TracksTab
@onready var items_tab: Button = %ItemsTab
@onready var lore_tab: Button = %LoreTab
@onready var entries_list: ItemList = %EntriesList
@onready var count_summary: Label = %CountSummary
@onready var detail_eyebrow: Label = %DetailEyebrow
@onready var detail_title: Label = %DetailTitle
@onready var detail_subtitle: Label = %DetailSubtitle
@onready var detail_description: Label = %DetailDescription
@onready var feature_name: Label = %FeatureName
@onready var feature_description: Label = %FeatureDescription
@onready var telemetry_label: Label = %TelemetryLabel
@onready var index_value: Label = %IndexValue
@onready var back_button: Button = %BackButton

var _category := &"chassis"
var _entries: Array[Dictionary] = []


func _ready() -> void:
	theme = ThemeFactory.create_theme(_settings())
	chassis_tab.pressed.connect(_set_category.bind(&"chassis"))
	tracks_tab.pressed.connect(_set_category.bind(&"tracks"))
	items_tab.pressed.connect(_set_category.bind(&"items"))
	lore_tab.pressed.connect(_set_category.bind(&"lore"))
	entries_list.item_selected.connect(_show_entry)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	_set_category(&"chassis")
	call_deferred("_configure_focus")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and is_node_ready():
		theme = ThemeFactory.create_theme(_settings())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event.is_action_pressed(&"ui_page_up"):
		get_viewport().set_input_as_handled()
		_cycle_category(-1)
	elif event.is_action_pressed(&"ui_page_down"):
		get_viewport().set_input_as_handled()
		_cycle_category(1)


func refresh() -> void:
	theme = ThemeFactory.create_theme(_settings())
	_set_category(_category)


func _set_category(category: StringName) -> void:
	_category = category
	match category:
		&"tracks": _entries = GameDatabase.get_all_tracks()
		&"items": _entries = GameDatabase.get_all_items()
		&"lore": _entries = LoreData.get_all()
		_: _entries = GameDatabase.get_all_chassis()
	chassis_tab.set_pressed_no_signal(category == &"chassis")
	tracks_tab.set_pressed_no_signal(category == &"tracks")
	items_tab.set_pressed_no_signal(category == &"items")
	lore_tab.set_pressed_no_signal(category == &"lore")
	_populate_list()


func _cycle_category(direction: int) -> void:
	var categories: Array[StringName] = [&"chassis", &"tracks", &"items", &"lore"]
	var index := categories.find(_category)
	_set_category(categories[posmod(index + direction, categories.size())])
	entries_list.grab_focus()


func _populate_list() -> void:
	entries_list.clear()
	for index in range(_entries.size()):
		var entry := _entries[index]
		entries_list.add_item(_entry_label(entry, index))
		entries_list.set_item_metadata(index, String(entry.get("id", "")))
	count_summary.text = "%d ARCHITECTURES   •   500 CONFIGS   •   %d CIRCUITS   •   %d ARCHIVES" % [
		GameDatabase.CHASSIS.size(), GameDatabase.TRACKS.size(), LoreData.ENTRIES.size(),
	]
	if not _entries.is_empty():
		entries_list.select(0)
		_show_entry(0)


func _entry_label(entry: Dictionary, index: int) -> String:
	match _category:
		&"tracks":
			return "%02d  //  %s\n%s" % [index + 1, String(entry.get("name", "CIRCUIT")).to_upper(), String(entry.get("region", "SECTEUR"))]
		&"items":
			return "%02d  //  %s\n%s" % [index + 1, String(entry.get("name", "OBJET")).to_upper(), String(entry.get("kind", "système")).to_upper()]
		&"lore":
			return "%02d  //  %s\n%s" % [index + 1, String(entry.get("title", "ARCHIVE")).to_upper(), String(entry.get("epoch", "NEXUS"))]
		_:
			return "%02d  //  %s\n%s" % [index + 1, String(entry.get("category", "ARCHITECTURE")), String(entry.get("name", "CHÂSSIS")).to_upper()]


func _show_entry(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var entry := _entries[index]
	index_value.text = "%02d / %02d" % [index + 1, _entries.size()]
	match _category:
		&"tracks": _show_track(entry)
		&"items": _show_item(entry)
		&"lore": _show_lore(entry)
		_: _show_chassis(entry)


func _show_chassis(entry: Dictionary) -> void:
	detail_eyebrow.text = "ARCHITECTURE // %s" % String(entry.get("category", "INCONNUE"))
	detail_title.text = String(entry.get("name", "CHÂSSIS")).to_upper()
	detail_subtitle.text = String(entry.get("subtitle", "Configuration de course"))
	detail_description.text = String(entry.get("description", ""))
	feature_name.text = String(entry.get("ability", "SYSTÈME PROPRIÉTAIRE")).to_upper()
	feature_description.text = String(entry.get("ability_description", ""))
	var stats: Dictionary = entry.get("stats", {})
	telemetry_label.text = "VITESSE  %3d     ACCÉL.  %3d     MANIABILITÉ  %3d\nBLINDAGE %3d     STABILITÉ %3d     RÉACTEUR     %3d\nCONFIGURATIONS LOCOMOTRICES  50" % [
		int(stats.get("speed", 0)), int(stats.get("acceleration", 0)), int(stats.get("handling", 0)),
		int(stats.get("armor", 0)), int(stats.get("stability", 0)), int(stats.get("reactor", 0)),
	]


func _show_track(entry: Dictionary) -> void:
	detail_eyebrow.text = "CIRCUIT // %s" % String(entry.get("region", "SECTEUR NON CARTOGRAPHIÉ"))
	detail_title.text = String(entry.get("name", "CIRCUIT")).to_upper()
	var tags: Array = entry.get("tags", [])
	detail_subtitle.text = "   •   ".join(PackedStringArray(tags))
	detail_description.text = String(entry.get("description", ""))
	feature_name.text = "DANGER %d / 5" % int(entry.get("difficulty", 1))
	var hazards: Array = entry.get("hazards", [])
	feature_description.text = "Dangers identifiés : %s." % ", ".join(PackedStringArray(hazards)).to_upper()
	telemetry_label.text = "TOURS STANDARD  %d\nTEMPS DE RÉFÉRENCE  %s\nPROTOCOLES  RAPIDE • CHRONO • ÉLIMINATION • GRAND PRIX" % [
		int(entry.get("default_laps", 3)), _format_time(float(entry.get("par_time", 0.0))),
	]


func _show_item(entry: Dictionary) -> void:
	detail_eyebrow.text = "ARSENAL DE COURSE // %s" % String(entry.get("kind", "système")).to_upper()
	detail_title.text = String(entry.get("name", "OBJET")).to_upper()
	detail_subtitle.text = "IDENTIFIANT TACTIQUE : %s" % String(entry.get("short", entry.get("id", "--"))).to_upper()
	detail_description.text = String(entry.get("description", ""))
	feature_name.text = _item_role(String(entry.get("kind", "")))
	feature_description.text = "Activation instantanée. Un seul module peut être conservé à la fois. La distribution favorise les pilotes distancés."
	telemetry_label.text = "COMPATIBILITÉ  10 / 10 CHÂSSIS\nHOMOLOGATION   CIRCUIT ZERO\nSÉCURITÉ       DÉCHARGE À ÉNERGIE LIMITÉE"


func _show_lore(entry: Dictionary) -> void:
	detail_eyebrow.text = String(entry.get("epoch", "ARCHIVE DU NEXUS"))
	detail_title.text = String(entry.get("title", "ARCHIVE")).to_upper()
	detail_subtitle.text = String(entry.get("subtitle", "Dossier de Circuit Zero"))
	detail_description.text = String(entry.get("description", ""))
	feature_name.text = String(entry.get("protocol", "PROTOCOLE")).to_upper()
	feature_description.text = String(entry.get("protocol_description", ""))
	telemetry_label.text = String(entry.get("telemetry", "DONNÉES CLASSIFIÉES"))


func _item_role(kind: String) -> String:
	match kind:
		"projectile": return "INTERCEPTION À DISTANCE"
		"area": return "CONTRÔLE DE PELOTON"
		"defense": return "PROTECTION ACTIVE"
		"mobility": return "SURCHARGE DE MOBILITÉ"
		"trap": return "CONTRÔLE DE TRAJECTOIRE"
		"repair": return "RESTAURATION D’INTÉGRITÉ"
		_: return "SYSTÈME DE COURSE"


func _configure_focus() -> void:
	ThemeFactory.connect_focus_chain([chassis_tab, tracks_tab, items_tab, lore_tab, entries_list, back_button])
	ThemeFactory.connect_focus_chain([chassis_tab, tracks_tab, items_tab, lore_tab], true)
	entries_list.grab_focus()


func _format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	var remainder := seconds - minutes * 60.0
	return "%02d:%05.2f" % [minutes, remainder]


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
