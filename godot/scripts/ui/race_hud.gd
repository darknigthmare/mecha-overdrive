extends Control
class_name RaceHUD

signal pause_requested(paused: bool)
signal retry_requested
signal menu_requested
signal mobile_control_changed(action: StringName, strength: float)
signal mobile_action_triggered(action: StringName)

const ThemeFactory = preload("res://scripts/ui/ui_theme.gd")
const RaceBroadcast = preload("res://scripts/data/race_broadcast.gd")
const MobileTouchControlsType = preload("res://scripts/input/mobile_touch_controls.gd")

var _config: Dictionary = {}
var _paused := false
var _built := false
var _countdown_revision := 0
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
var _race_layout: Control
var _briefing_overlay: Control
var _briefing_eyebrow: Label
var _briefing_track: Label
var _briefing_region: Label
var _briefing_session: Label
var _briefing_rules: Label
var _briefing_grid: Label
var _briefing_announcer: Label
var _briefing_lore: Label
var _briefing_conditions: Label
var _countdown_panel: PanelContainer
var _countdown_label: Label
var _countdown_stage_label: Label
var _countdown_notice_label: Label
var _finish_overlay: Control
var _finish_title: Label
var _finish_position: Label
var _finish_callout: Label
var _finish_venue: Label
var _pause_overlay: Control
var _resume_button: Button
var _retry_button: Button
var _menu_button: Button
var _mobile_controls: MobileTouchControls


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
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"race_pause"):
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
	_countdown_notice_label.visible = false
	_race_layout.visible = true
	_briefing_overlay.visible = false
	_finish_overlay.visible = false
	show_countdown(null)
	show_pause(false)
	if _mobile_controls != null:
		_mobile_controls.configure(bool(config.get("force_touch_controls", false)))


func show_race_briefing(config: Dictionary, grid_entries: Array = []) -> void:
	if not is_node_ready() or not _built:
		return
	var briefing: Dictionary = RaceBroadcast.briefing(config)
	_briefing_eyebrow.text = String(briefing.get("eyebrow", "NEXUS RACING NETWORK"))
	_briefing_track.text = String(briefing.get("track_name", "CIRCUIT ZERO"))
	_briefing_region.text = String(briefing.get("region", "SECTEUR NEXUS"))
	_briefing_session.text = String(briefing.get("session", "COURSE RAPIDE"))
	_briefing_rules.text = String(briefing.get("rules", "RÈGLEMENT STANDARD")) + "\n" + String(briefing.get("rules_detail", ""))
	_briefing_grid.text = _grid_text(grid_entries)
	_briefing_announcer.text = "DIRECT // « %s »" % String(briefing.get("announcer", "Grille scellée."))
	_briefing_lore.text = String(briefing.get("lore", "Circuit homologué par le Nexus."))
	_briefing_conditions.text = "%s\n%s" % [String(briefing.get("objective", "OBJECTIF // VICTOIRE")), String(briefing.get("conditions", "CIRCUIT HOMOLOGUÉ"))]
	_briefing_overlay.visible = true
	_finish_overlay.visible = false
	_countdown_panel.visible = false
	if _mobile_controls != null:
		_mobile_controls.set_suppressed(true)
	var duration := ThemeFactory.motion_duration(_settings(), 0.22)
	if duration > 0.0:
		_briefing_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
		create_tween().tween_property(_briefing_overlay, "modulate", Color.WHITE, duration)
	else:
		_briefing_overlay.modulate = Color.WHITE


func hide_race_briefing() -> void:
	if is_instance_valid(_briefing_overlay):
		_briefing_overlay.visible = false
	if _mobile_controls != null:
		_mobile_controls.set_suppressed(false)
		_mobile_controls.configure(bool(_config.get("force_touch_controls", false)))


func is_briefing_visible() -> bool:
	return is_instance_valid(_briefing_overlay) and _briefing_overlay.visible


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
		var held_item: Dictionary = item
		item_name = String(held_item.get("short", held_item.get("name", "MODULE"))).to_upper()
	elif not String(item).is_empty():
		var item_data := GameDatabase.get_item(String(item))
		item_name = String(item_data.get("short", item_data.get("name", item))).to_upper()
	var charges := int(snapshot.get("item_charges", snapshot.get("charges", 1)))
	var view_name := "COCKPIT" if String(snapshot.get("camera_view", "tps")) == "fps" else "TPS"
	_item_label.text = "MODULE  //  %s%s   •   VUE %s  [V]" % [item_name, "  ×%d" % charges if item_name != "VIDE" and charges > 1 else "", view_name]

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
	if _mobile_controls != null:
		_mobile_controls.update_context(snapshot)


func show_countdown(value: Variant) -> void:
	if not is_node_ready() or not _built:
		return
	_countdown_revision += 1
	var revision := _countdown_revision
	if value == null or str(value).is_empty():
		_countdown_panel.visible = false
		return
	var text := str(value).to_upper()
	if value is int or value is float:
		text = "GO !" if float(value) <= 0.0 else str(ceili(float(value)))
		_countdown_stage_label.text = "PROPULSEURS LIBÉRÉS" if float(value) <= 0.0 else "DÉPART VERROUILLÉ // FEUX %d / 3" % (4 - clampi(ceili(float(value)), 1, 3))
	else:
		_countdown_stage_label.text = "CONTRÔLE COURSE"
	_countdown_label.text = text
	_countdown_panel.visible = true
	_countdown_panel.modulate = Color.WHITE
	var duration := ThemeFactory.motion_duration(_settings(), 0.12)
	if duration > 0.0:
		_countdown_panel.scale = Vector2(1.18, 1.18)
		_countdown_panel.pivot_offset = _countdown_panel.size * 0.5
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_countdown_panel, "scale", Vector2.ONE, duration)
	if (value is int or value is float) and float(value) <= 0.0:
		_hide_countdown_after_delay(revision)


func show_false_start(penalty_seconds: float) -> void:
	if not is_node_ready() or not _built:
		return
	_countdown_notice_label.text = "FAUX DÉPART // PROPULSEURS VERROUILLÉS %.1f S" % penalty_seconds
	_countdown_notice_label.visible = true
	_warning_label.text = "FAUX DÉPART DÉTECTÉ // PÉNALITÉ DE GRILLE"
	_warning_label.visible = true


func show_finish(result: Dictionary) -> void:
	if not is_node_ready() or not _built:
		return
	var call: Dictionary = RaceBroadcast.finish_call(result)
	_race_layout.visible = false
	_briefing_overlay.visible = false
	_countdown_panel.visible = false
	_finish_title.text = String(call.get("title", "ARRIVÉE HOMOLOGUÉE"))
	_finish_position.text = String(call.get("position", "-- / 08"))
	_finish_callout.text = String(call.get("callout", "Drapeau à damier."))
	_finish_venue.text = String(call.get("venue", "NEXUS RACING NETWORK"))
	_finish_overlay.visible = true
	if _mobile_controls != null:
		_mobile_controls.set_suppressed(true)
	var duration := ThemeFactory.motion_duration(_settings(), 0.24)
	if duration > 0.0:
		_finish_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var panel := _finish_overlay.get_node_or_null("Center/Panel") as Control
		if panel != null:
			panel.scale = Vector2(0.92, 0.92)
			panel.pivot_offset = panel.size * 0.5
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(panel, "scale", Vector2.ONE, duration)
		create_tween().tween_property(_finish_overlay, "modulate", Color.WHITE, duration)
	else:
		_finish_overlay.modulate = Color.WHITE


func is_finish_visible() -> bool:
	return is_instance_valid(_finish_overlay) and _finish_overlay.visible


func _hide_countdown_after_delay(revision: int) -> void:
	await get_tree().create_timer(0.85, true, false, true).timeout
	if revision == _countdown_revision and is_instance_valid(_countdown_panel):
		_countdown_panel.visible = false


func show_pause(paused: bool) -> void:
	_paused = paused
	if not is_node_ready() or not _built:
		return
	_pause_overlay.visible = paused
	if _mobile_controls != null:
		var presentation_blocked := (_briefing_overlay != null and _briefing_overlay.visible) or (_finish_overlay != null and _finish_overlay.visible)
		_mobile_controls.set_suppressed(paused or presentation_blocked)
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
	_race_layout = safe_margin
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
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

	_build_briefing_overlay()

	var countdown_center := CenterContainer.new()
	countdown_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(countdown_center)
	_countdown_panel = PanelContainer.new()
	_countdown_panel.theme_type_variation = &"HeroPanel"
	_countdown_panel.custom_minimum_size = Vector2(390.0, 205.0)
	_countdown_panel.visible = false
	countdown_center.add_child(_countdown_panel)
	var countdown_stack := VBoxContainer.new()
	countdown_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	countdown_stack.add_theme_constant_override(&"separation", 4)
	_countdown_panel.add_child(countdown_stack)
	_countdown_stage_label = _label("DÉPART VERROUILLÉ", &"EyebrowLabel", HORIZONTAL_ALIGNMENT_CENTER)
	countdown_stack.add_child(_countdown_stage_label)
	_countdown_label = _label("3", &"DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_stack.add_child(_countdown_label)
	_countdown_notice_label = _label("FAUX DÉPART", &"WarningLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_countdown_notice_label.visible = false
	countdown_stack.add_child(_countdown_notice_label)

	_build_finish_overlay()

	_build_mobile_controls()
	_build_pause_overlay()


func _build_briefing_overlay() -> void:
	_briefing_overlay = Control.new()
	_briefing_overlay.name = "RaceBriefingOverlay"
	_briefing_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_briefing_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing_overlay.visible = false
	add_child(_briefing_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.006, 0.016, 0.03, 0.90)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing_overlay.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 92)
	margin.add_theme_constant_override(&"margin_top", 56)
	margin.add_theme_constant_override(&"margin_right", 92)
	margin.add_theme_constant_override(&"margin_bottom", 56)
	_briefing_overlay.add_child(margin)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HeroPanel"
	margin.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", 8)
	panel.add_child(content)
	_briefing_eyebrow = _label("NEXUS RACING NETWORK // GRILLE OFFICIELLE", &"EyebrowLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_briefing_track = _label("FONDERIE NÉON", &"DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_briefing_region = _label("NEXUS INDUSTRIEL 7", &"SectionLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_briefing_session = _label("COURSE RAPIDE // 3 TOURS // 08 PARTANTS", &"SectionLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_briefing_eyebrow)
	content.add_child(_briefing_track)
	content.add_child(_briefing_region)
	content.add_child(_briefing_session)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override(&"separation", 12)
	content.add_child(cards)
	var rules_panel := _panel()
	rules_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(rules_panel)
	_briefing_rules = _label("DIVISION DÉDIÉE", &"MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_briefing_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_rules.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rules_panel.add_child(_briefing_rules)
	var grid_panel := _panel()
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(grid_panel)
	_briefing_grid = _label("GRILLE // 01 VOUS", &"MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_briefing_grid.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_grid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid_panel.add_child(_briefing_grid)
	_briefing_announcer = _label("DIRECT // GRILLE SCELLÉE", &"SectionLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_briefing_announcer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_lore = _label("Circuit homologué par le Nexus.", &"MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_briefing_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_conditions = _label("OBJECTIF // VICTOIRE", &"EyebrowLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_briefing_conditions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_briefing_announcer)
	content.add_child(_briefing_lore)
	content.add_child(_briefing_conditions)


func _build_finish_overlay() -> void:
	_finish_overlay = Control.new()
	_finish_overlay.name = "FinishBroadcastOverlay"
	_finish_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_finish_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finish_overlay.visible = false
	add_child(_finish_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.015, 0.03, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finish_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_finish_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"HeroPanel"
	panel.custom_minimum_size = Vector2(720.0, 330.0)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override(&"separation", 10)
	panel.add_child(stack)
	stack.add_child(_label("NEXUS RACING NETWORK // DRAPEAU À DAMIER", &"EyebrowLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_finish_title = _label("ARRIVÉE HOMOLOGUÉE", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_finish_position = _label("1RE / 08", &"DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_finish_callout = _label("Drapeau à damier.", &"SectionLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_finish_venue = _label("CIRCUIT ZERO // NEXUS", &"MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_finish_callout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_finish_title)
	stack.add_child(_finish_position)
	stack.add_child(_finish_callout)
	stack.add_child(_finish_venue)


func _grid_text(entries: Array) -> String:
	var lines := PackedStringArray(["GRILLE // APERÇU DES PARTANTS"])
	for index in range(mini(entries.size(), 4)):
		if not entries[index] is Dictionary:
			continue
		var entry: Dictionary = entries[index]
		var name := String(entry.get("display_name", entry.get("name", "PILOTE %02d" % (index + 1)))).to_upper()
		var chassis := GameDatabase.get_chassis(String(entry.get("chassis_id", "")))
		var marker := "VOUS" if bool(entry.get("is_player", entry.get("player", false))) else String(chassis.get("name", "MÉCHA")).to_upper()
		lines.append("%02d  %-14s  %s" % [index + 1, name, marker])
	if entries.size() > 4:
		lines.append("+ %d AUTRES SIGNATURES HOMOLOGUÉES" % (entries.size() - 4))
	return "\n".join(lines)


func _build_mobile_controls() -> void:
	_mobile_controls = MobileTouchControlsType.new()
	_mobile_controls.name = "MobileTouchControls"
	_mobile_controls.control_changed.connect(func(action: StringName, strength: float) -> void:
		mobile_control_changed.emit(action, strength)
	)
	_mobile_controls.action_triggered.connect(func(action: StringName) -> void:
		mobile_action_triggered.emit(action)
	)
	add_child(_mobile_controls)


func mobile_controls_visible() -> bool:
	return _mobile_controls != null and _mobile_controls.is_touch_mode()


func force_mobile_controls(enabled: bool) -> void:
	if _mobile_controls != null:
		_mobile_controls.configure(enabled)


func release_mobile_controls() -> void:
	if _mobile_controls != null:
		_mobile_controls.release_controls()


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
		var profile_data: Dictionary = profile
		var value: Variant = profile_data.get("settings", {})
		return value if value is Dictionary else {}
	return {}
