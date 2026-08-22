extends Control
class_name RaceHUD

signal pause_requested(paused: bool)
signal retry_requested
signal menu_requested

const ThemeFactory = preload("res://scripts/ui/ui_theme.gd")

var _config: Dictionary = {}
var _paused := false
var _built := false
var _focus_before_pause: Control

var _mode_label: Label
var _track_label: Label
var _lap_label: Label
var _objective_label: Label
var _position_label: Label
var _time_label: Label
var _speed_value: Label
var _heat_bar: ProgressBar
var _armor_bar: ProgressBar
var _item_label: Label
var _warning_label: Label
var _countdown_panel: PanelContainer
var _countdown_label: Label
var _pause_overlay: Control
var _resume_button: Button
var _retry_button: Button
var _menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	theme = ThemeFactory.create_theme(_settings())
	if not _config.is_empty():
		configure(_config)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		show_pause(not _paused)
		pause_requested.emit(_paused)


func configure(config: Dictionary) -> void:
	_config = config.duplicate(true)
	if not is_node_ready() or not _built:
		return
	theme = ThemeFactory.create_theme(_settings())
	var mode := String(config.get("mode", "quick"))
	var track_id := String(config.get("track_id", config.get("track", "foundry")))
	var track := GameDatabase.get_track(track_id)
	_mode_label.text = _mode_name(mode)
	_track_label.text = String(config.get("track_name", track.get("name", track_id))).to_upper()
	_lap_label.text = "TOUR 1 / %d" % int(config.get("laps", track.get("default_laps", 3)))
	_objective_label.text = _objective(mode, config)
	_position_label.text = "01 / %02d" % int(config.get("racer_count", 8))
	_time_label.text = "00:00.000"
	_speed_value.text = "000"
	_heat_bar.value = 0.0
	_armor_bar.value = 100.0
	_item_label.text = "MODULE  //  VIDE"
	_warning_label.visible = false
	show_countdown(null)
	show_pause(false)


func update_race(snapshot: Dictionary) -> void:
	if not is_node_ready() or not _built:
		return
	var lap := int(snapshot.get("lap", snapshot.get("current_lap", 1)))
	var laps := int(snapshot.get("laps", snapshot.get("total_laps", _config.get("laps", 3))))
	_lap_label.text = "TOUR %d / %d" % [clampi(lap, 1, maxi(laps, 1)), maxi(laps, 1)]
	var position := int(snapshot.get("position", snapshot.get("rank", 1)))
	var racers := int(snapshot.get("racers", snapshot.get("racer_count", 8)))
	_position_label.text = "%02d / %02d" % [maxi(position, 1), maxi(racers, 1)]
	_time_label.text = _format_time(float(snapshot.get("time", snapshot.get("elapsed", 0.0))))
	var speed := maxf(float(snapshot.get("speed", snapshot.get("speed_kmh", 0.0))), 0.0)
	_speed_value.text = "%03d" % mini(roundi(speed), 999)
	_heat_bar.value = _as_percent(snapshot.get("heat", 0.0))
	_armor_bar.value = _integrity_percent(snapshot)

	var item: Variant = snapshot.get("item", snapshot.get("item_id", ""))
	var item_name := "VIDE"
	if item is Dictionary:
		item_name = String(item.get("short", item.get("name", "MODULE"))).to_upper()
	elif not String(item).is_empty():
		var item_data := GameDatabase.get_item(String(item))
		item_name = String(item_data.get("short", item_data.get("name", item))).to_upper()
	var charges := int(snapshot.get("item_charges", snapshot.get("charges", 1)))
	_item_label.text = "MODULE  //  %s%s" % [item_name, "  ×%d" % charges if item_name != "VIDE" and charges > 1 else ""]

	var warning := String(snapshot.get("warning", ""))
	if bool(snapshot.get("eliminated", false)):
		warning = "ÉLIMINÉ // COURSE INTERROMPUE"
	elif _heat_bar.value >= 92.0 and warning.is_empty():
		warning = "SURCHAUFFE RÉACTEUR"
	elif _armor_bar.value <= 25.0 and warning.is_empty():
		warning = "INTÉGRITÉ CRITIQUE"
	_warning_label.text = warning.to_upper()
	_warning_label.visible = not warning.is_empty()
	if snapshot.has("objective"):
		_objective_label.text = String(snapshot.objective).to_upper()
	if snapshot.has("countdown"):
		show_countdown(snapshot.countdown)


func show_countdown(value: Variant) -> void:
	if not is_node_ready() or not _built:
		return
	if value == null or String(value).is_empty():
		_countdown_panel.visible = false
		return
	var text := String(value).to_upper()
	if value is int or value is float:
		text = "OVERDRIVE !" if float(value) <= 0.0 else str(ceili(float(value)))
	_countdown_label.text = text
	_countdown_panel.visible = true
	_countdown_panel.modulate = Color.WHITE
	var duration := ThemeFactory.motion_duration(_settings(), 0.12)
	if duration > 0.0:
		_countdown_panel.scale = Vector2(1.18, 1.18)
		_countdown_panel.pivot_offset = _countdown_panel.size * 0.5
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_countdown_panel, "scale", Vector2.ONE, duration)


func show_pause(paused: bool) -> void:
	_paused = paused
	if not is_node_ready() or not _built:
		return
	_pause_overlay.visible = paused
	if paused:
		_focus_before_pause = get_viewport().gui_get_focus_owner()
		_resume_button.call_deferred("grab_focus")
	else:
		if is_instance_valid(_focus_before_pause):
			_focus_before_pause.call_deferred("grab_focus")


func _build_interface() -> void:
	if _built:
		return
	_built = true

	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		safe_margin.add_theme_constant_override(side, 32)
	add_child(safe_margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override(&"separation", 16)
	safe_margin.add_child(layout)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override(&"separation", 14)
	layout.add_child(top)
	var left_panel := _panel()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left_panel)
	var left := VBoxContainer.new()
	left_panel.add_child(left)
	_mode_label = _label("COURSE RAPIDE", &"EyebrowLabel")
	_track_label = _label("FONDERIE NÉON", &"SectionLabel")
	left.add_child(_mode_label)
	left.add_child(_track_label)

	var center_panel := _panel()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(center_panel)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center_panel.add_child(center)
	_lap_label = _label("TOUR 1 / 3", &"SectionLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_objective_label = _label("FRANCHISSEZ LA LIGNE", &"MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(_lap_label)
	center.add_child(_objective_label)

	var right_panel := _panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right_panel)
	var right := VBoxContainer.new()
	right_panel.add_child(right)
	_position_label = _label("01 / 08", &"MetricLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_time_label = _label("00:00.000", &"SectionLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_position_label)
	right.add_child(_time_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)

	_warning_label = _label("SURCHAUFFE RÉACTEUR", &"WarningLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_warning_label.custom_minimum_size.y = 46.0
	_warning_label.visible = false
	layout.add_child(_warning_label)

	var bottom_panel := _panel()
	layout.add_child(bottom_panel)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 24)
	bottom_panel.add_child(bottom)
	var speed_stack := VBoxContainer.new()
	speed_stack.custom_minimum_size.x = 150.0
	bottom.add_child(speed_stack)
	speed_stack.add_child(_label("VITESSE // KM/H", &"EyebrowLabel"))
	_speed_value = _label("000", &"DisplayLabel")
	speed_stack.add_child(_speed_value)

	var systems := VBoxContainer.new()
	systems.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(systems)
	systems.add_child(_label("TEMPÉRATURE RÉACTEUR", &"MutedLabel"))
	_heat_bar = ProgressBar.new()
	_heat_bar.max_value = 100.0
	_heat_bar.show_percentage = true
	_heat_bar.custom_minimum_size.y = 24.0
	systems.add_child(_heat_bar)
	systems.add_child(_label("INTÉGRITÉ BLINDAGE", &"MutedLabel"))
	_armor_bar = ProgressBar.new()
	_armor_bar.max_value = 100.0
	_armor_bar.value = 100.0
	_armor_bar.show_percentage = true
	_armor_bar.custom_minimum_size.y = 24.0
	systems.add_child(_armor_bar)

	_item_label = _label("MODULE  //  VIDE", &"SectionLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_item_label.custom_minimum_size.x = 330.0
	_item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_item_label)

	var countdown_center := CenterContainer.new()
	countdown_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(countdown_center)
	_countdown_panel = PanelContainer.new()
	_countdown_panel.theme_type_variation = &"HeroPanel"
	_countdown_panel.custom_minimum_size = Vector2(300.0, 170.0)
	_countdown_panel.visible = false
	countdown_center.add_child(_countdown_panel)
	_countdown_label = _label("3", &"DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_panel.add_child(_countdown_label)

	_build_pause_overlay()


func _build_pause_overlay() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	add_child(_pause_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.04, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HeroPanel"
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 14)
	panel.add_child(stack)
	stack.add_child(_label("COURSE SUSPENDUE", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label("Le chronomètre et la simulation sont en pause.", &"MutedLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_resume_button = Button.new()
	_resume_button.text = "REPRENDRE"
	_resume_button.theme_type_variation = &"PrimaryButton"
	_resume_button.custom_minimum_size.y = 58.0
	_resume_button.pressed.connect(_resume)
	stack.add_child(_resume_button)
	_retry_button = Button.new()
	_retry_button.text = "RECOMMENCER LA COURSE"
	_retry_button.custom_minimum_size.y = 54.0
	_retry_button.pressed.connect(func() -> void: retry_requested.emit())
	stack.add_child(_retry_button)
	_menu_button = Button.new()
	_menu_button.text = "ABANDONNER VERS LE MENU"
	_menu_button.theme_type_variation = &"DangerButton"
	_menu_button.custom_minimum_size.y = 54.0
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	stack.add_child(_menu_button)
	ThemeFactory.connect_focus_chain([_resume_button, _retry_button, _menu_button])


func _resume() -> void:
	show_pause(false)
	pause_requested.emit(false)


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _label(text_value: String, variation: StringName, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.theme_type_variation = variation
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _as_percent(value: Variant) -> float:
	var number := float(value) if value is int or value is float else 0.0
	return clampf(number * 100.0 if number <= 1.0 else number, 0.0, 100.0)


func _integrity_percent(snapshot: Dictionary) -> float:
	var current := float(snapshot.get("integrity", snapshot.get("armor", snapshot.get("health", 100.0))))
	var maximum := float(snapshot.get("max_integrity", snapshot.get("max_armor", snapshot.get("max_health", 100.0))))
	if maximum <= 0.0:
		return 0.0
	return clampf(current / maximum * 100.0, 0.0, 100.0)


func _objective(mode: String, config: Dictionary) -> String:
	match mode:
		"time_trial": return "BATTEZ LE TEMPS DE RÉFÉRENCE"
		"elimination": return "ÉVITEZ LA DERNIÈRE POSITION"
		"grand_prix": return "MARQUEZ DES POINTS DE CHAMPIONNAT"
		_: return "FRANCHISSEZ LA LIGNE EN TÊTE"


func _mode_name(mode: String) -> String:
	match mode:
		"time_trial": return "CONTRE-LA-MONTRE"
		"elimination": return "ÉLIMINATION"
		"grand_prix": return "GRAND PRIX"
		_: return "COURSE RAPIDE"


func _format_time(seconds: float) -> String:
	var safe := maxf(seconds, 0.0)
	var minutes := floori(safe / 60.0)
	var remainder := safe - minutes * 60.0
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
