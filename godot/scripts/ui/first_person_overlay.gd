class_name FirstPersonOverlay
extends Control

## Presentation-only FPS layer. Physical cockpit geometry remains in 3D; this
## overlay adds restrained instruments for crewed machines and a complete,
## touch-transparent sensorium for racing bodies without an onboard pilot.

const SENSOR_COLOR := Color("72F7D4")
const COCKPIT_COLOR := Color("70DFFF")
const PANEL_COLOR := Color(0.008, 0.035, 0.052, 0.72)
const COMPACT_WIDTH := 900.0
const COMPACT_HEIGHT := 500.0

var _spec: Dictionary = {}
var _chassis_id := "biped"
var _chassis_name := "RAPTOR R2"
var _camera_mode := "tps"
var _built := false

var _cockpit_layer: Control
var _cockpit_label: Label
var _sensor_layer: Control
var _sensor_header: Label
var _sensor_left: Label
var _sensor_right: Label
var _sensor_footer: Label
var _sensor_left_panel: Control
var _sensor_right_panel: Control
var _reticle: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	get_viewport().size_changed.connect(_layout)
	_apply_visibility()


func configure(chassis: Dictionary) -> void:
	_chassis_id = String(chassis.get("id", "biped"))
	_chassis_name = String(chassis.get("name", _chassis_id)).to_upper()
	_spec = Dictionary(chassis.get("first_person", {})).duplicate(true) if chassis.get("first_person", {}) is Dictionary else {}
	if not _built:
		return
	var label := String(_spec.get("label", "COCKPIT TACTIQUE")).to_upper()
	_cockpit_label.text = "HABITACLE // %s // %s" % [_chassis_name, label]
	_sensor_header.text = "LIAISON SENSORIUM // %s" % _chassis_name
	_sensor_footer.text = "%s // PILOTE DISTANT HOMOLOGUÉ" % label
	_apply_visibility()


func set_camera_mode(mode: String) -> void:
	_camera_mode = "fps" if mode.to_lower() == "fps" else "tps"
	_apply_visibility()


func update_telemetry(snapshot: Dictionary) -> void:
	if not _built:
		return
	var speed := maxf(float(snapshot.get("speed", snapshot.get("speed_kmh", 0.0))), 0.0)
	var heat := _percent(snapshot.get("heat", snapshot.get("heat_ratio", 0.0)))
	var integrity := _integrity(snapshot)
	var steer := clampf(float(snapshot.get("steer", 0.0)), -1.0, 1.0)
	var link_quality := clampi(roundi(integrity * 0.72 + (100.0 - heat) * 0.28), 0, 100)
	_sensor_left.text = "NODE  // %s\nLINK  // %03d %%\nCORE  // %03d %%" % [_chassis_id.to_upper(), link_quality, roundi(heat)]
	_sensor_right.text = "VECTOR // %+.2f\nVITESSE // %03d\nCOQUE   // %03d %%" % [steer, mini(roundi(speed), 999), roundi(integrity)]
	var reticle_state := "LOCK" if speed >= 1.0 else "SYNC"
	_reticle.text = "◇\n┼\n%s" % reticle_state


func interface_mode() -> String:
	if _camera_mode != "fps":
		return "tps"
	return String(_spec.get("mode", "cockpit"))


func sensor_overlay_visible() -> bool:
	return is_instance_valid(_sensor_layer) and _sensor_layer.visible and visible


func _build() -> void:
	if _built:
		return
	_built = true

	_cockpit_layer = Control.new()
	_cockpit_layer.name = "CockpitInstrumentationOverlay"
	_cockpit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cockpit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cockpit_layer)
	_cockpit_label = _label(COCKPIT_COLOR, 13, HORIZONTAL_ALIGNMENT_CENTER)
	_cockpit_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cockpit_label.offset_left = -260.0
	_cockpit_label.offset_right = 260.0
	_cockpit_label.offset_top = 116.0
	_cockpit_label.offset_bottom = 146.0
	_cockpit_layer.add_child(_cockpit_label)

	_sensor_layer = Control.new()
	_sensor_layer.name = "SensoriumOverlay"
	_sensor_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sensor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sensor_layer.add_to_group("mecha_sensorium_hud")
	add_child(_sensor_layer)

	_sensor_header = _label(SENSOR_COLOR, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_sensor_header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sensor_header.offset_left = -270.0
	_sensor_header.offset_right = 270.0
	_sensor_header.offset_top = 116.0
	_sensor_header.offset_bottom = 150.0
	_sensor_layer.add_child(_sensor_header)

	_sensor_left_panel = _diagnostic_panel(Control.PRESET_CENTER_LEFT, Vector2(24.0, -94.0), Vector2(270.0, 94.0))
	_sensor_layer.add_child(_sensor_left_panel)
	_sensor_left = _label(SENSOR_COLOR, 15, HORIZONTAL_ALIGNMENT_LEFT)
	_sensor_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sensor_left_panel.add_child(_sensor_left)
	_sensor_left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)

	_sensor_right_panel = _diagnostic_panel(Control.PRESET_CENTER_RIGHT, Vector2(-270.0, -94.0), Vector2(-24.0, 94.0))
	_sensor_layer.add_child(_sensor_right_panel)
	_sensor_right = _label(SENSOR_COLOR, 15, HORIZONTAL_ALIGNMENT_RIGHT)
	_sensor_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sensor_right_panel.add_child(_sensor_right)
	_sensor_right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)

	var horizon := ColorRect.new()
	horizon.color = Color(SENSOR_COLOR, 0.62)
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizon.set_anchors_preset(Control.PRESET_CENTER)
	horizon.offset_left = -132.0
	horizon.offset_right = 132.0
	horizon.offset_top = -1.0
	horizon.offset_bottom = 1.0
	_sensor_layer.add_child(horizon)
	_reticle = _label(SENSOR_COLOR, 20, HORIZONTAL_ALIGNMENT_CENTER)
	_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.offset_left = -70.0
	_reticle.offset_right = 70.0
	_reticle.offset_top = -58.0
	_reticle.offset_bottom = 70.0
	_sensor_layer.add_child(_reticle)

	_sensor_footer = _label(SENSOR_COLOR, 12, HORIZONTAL_ALIGNMENT_CENTER)
	_sensor_footer.set_anchors_preset(Control.PRESET_CENTER)
	_sensor_footer.offset_left = -270.0
	_sensor_footer.offset_right = 270.0
	_sensor_footer.offset_top = 92.0
	_sensor_footer.offset_bottom = 120.0
	_sensor_layer.add_child(_sensor_footer)
	_add_corner_brackets()
	_layout()


func _diagnostic_panel(preset: LayoutPreset, top_left: Vector2, bottom_right: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(preset)
	panel.offset_left = top_left.x
	panel.offset_top = top_left.y
	panel.offset_right = bottom_right.x
	panel.offset_bottom = bottom_right.y
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(SENSOR_COLOR, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override(&"panel", style)
	return panel


func _add_corner_brackets() -> void:
	for horizontal_right: bool in [false, true]:
		for vertical_bottom: bool in [false, true]:
			var horizontal := ColorRect.new()
			horizontal.color = Color(SENSOR_COLOR, 0.72)
			horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
			horizontal.set_anchors_preset(_corner_preset(horizontal_right, vertical_bottom))
			horizontal.offset_left = -54.0 if horizontal_right else 24.0
			horizontal.offset_right = -24.0 if horizontal_right else 54.0
			horizontal.offset_top = -26.0 if vertical_bottom else 24.0
			horizontal.offset_bottom = -24.0 if vertical_bottom else 26.0
			_sensor_layer.add_child(horizontal)
			var vertical := ColorRect.new()
			vertical.color = Color(SENSOR_COLOR, 0.72)
			vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vertical.set_anchors_preset(_corner_preset(horizontal_right, vertical_bottom))
			vertical.offset_left = -26.0 if horizontal_right else 24.0
			vertical.offset_right = -24.0 if horizontal_right else 26.0
			vertical.offset_top = -54.0 if vertical_bottom else 24.0
			vertical.offset_bottom = -24.0 if vertical_bottom else 54.0
			_sensor_layer.add_child(vertical)


func _corner_preset(right: bool, bottom: bool) -> LayoutPreset:
	if right:
		return Control.PRESET_BOTTOM_RIGHT if bottom else Control.PRESET_TOP_RIGHT
	return Control.PRESET_BOTTOM_LEFT if bottom else Control.PRESET_TOP_LEFT


func _label(color: Color, font_size: int, alignment: HorizontalAlignment) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.horizontal_alignment = alignment
	result.add_theme_color_override(&"font_color", color)
	result.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.08, 0.10, 0.92))
	result.add_theme_constant_override(&"shadow_offset_x", 1)
	result.add_theme_constant_override(&"shadow_offset_y", 2)
	result.add_theme_font_size_override(&"font_size", font_size)
	return result


func _layout() -> void:
	if not _built or _sensor_left_panel == null:
		return
	var size := get_viewport_rect().size
	# Web stretch can keep the logical project resolution while the browser
	# canvas is physically smaller. Use the tightest surface so mobile sensor
	# diagnostics never shrink into unreadable edge panels.
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0 and window_size.y > 0.0:
		size.x = minf(size.x, window_size.x)
		size.y = minf(size.y, window_size.y)
	var compact := size.x < COMPACT_WIDTH or size.y < COMPACT_HEIGHT
	_sensor_left_panel.visible = not compact
	_sensor_right_panel.visible = not compact
	_sensor_header.offset_top = 152.0
	_sensor_header.offset_bottom = _sensor_header.offset_top + 30.0
	_sensor_header.add_theme_font_size_override(&"font_size", 18 if compact else 15)
	_cockpit_label.offset_top = 152.0
	_cockpit_label.offset_bottom = _cockpit_label.offset_top + 28.0
	_cockpit_label.add_theme_font_size_override(&"font_size", 16 if compact else 13)
	_sensor_footer.visible = not compact


func _apply_visibility() -> void:
	if not _built:
		return
	var fps := _camera_mode == "fps"
	var sensorium := String(_spec.get("mode", "cockpit")) == "sensorium"
	visible = fps
	_cockpit_layer.visible = fps and not sensorium
	_sensor_layer.visible = fps and sensorium


func _percent(value: Variant) -> float:
	var number := float(value)
	return clampf(number * 100.0 if number <= 1.0 else number, 0.0, 100.0)


func _integrity(snapshot: Dictionary) -> float:
	if snapshot.has("armor_ratio"):
		return _percent(snapshot.get("armor_ratio", 1.0))
	var armor := float(snapshot.get("armor", 100.0))
	var maximum := maxf(float(snapshot.get("max_armor", 100.0)), 0.001)
	return clampf(armor / maximum * 100.0, 0.0, 100.0)
