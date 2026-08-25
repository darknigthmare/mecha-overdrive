extends RefCounted
class_name MechaUITheme

## Central visual language for every Circuit Zero interface.
## The theme deliberately keeps the web branch's cyan/yellow industrial identity
## while guaranteeing large targets, visible focus and a high-contrast variant.

const BACKGROUND := Color("#05070d")
const SURFACE := Color("#0a111c")
const SURFACE_RAISED := Color("#101b2a")
const TEXT := Color("#edf8ff")
const MUTED := Color("#9fb4c2")
const CYAN := Color("#61e7ff")
const YELLOW := Color("#ffd95a")
const ORANGE := Color("#ff8a48")
const RED := Color("#ff6478")
const GREEN := Color("#6df7ad")


static func create_theme(settings: Dictionary = {}) -> Theme:
	var high_contrast: bool = bool(_setting(settings, "high_contrast", "highContrast", false))
	var large_text: bool = bool(_setting(settings, "large_text", "largeText", false))
	var scale := 1.18 if large_text else 1.0
	var palette := _palette(high_contrast)
	var theme := Theme.new()

	theme.set_default_font_size(roundi(17.0 * scale))
	theme.set_color(&"font_color", &"Label", palette.text)
	theme.set_color(&"font_shadow_color", &"Label", Color(0.0, 0.0, 0.0, 0.72))
	theme.set_constant(&"shadow_offset_x", &"Label", 1)
	theme.set_constant(&"shadow_offset_y", &"Label", 2)

	_add_label_variations(theme, palette, scale)
	_add_panel_variations(theme, palette)
	_add_button_variations(theme, palette, scale)
	_add_form_controls(theme, palette, scale)
	return theme


static func motion_duration(settings: Dictionary, normal_duration: float = 0.22) -> float:
	return 0.0 if bool(_setting(settings, "reduced_motion", "reducedMotion", false)) else normal_duration


static func connect_focus_chain(controls: Array[Control], horizontal: bool = false) -> void:
	var usable: Array[Control] = []
	for control in controls:
		if is_instance_valid(control) and control.visible and not control.is_queued_for_deletion():
			control.focus_mode = Control.FOCUS_ALL
			usable.append(control)
	if usable.is_empty():
		return

	for index in usable.size():
		var current := usable[index]
		var previous := usable[(index - 1 + usable.size()) % usable.size()]
		var following := usable[(index + 1) % usable.size()]
		current.focus_previous = current.get_path_to(previous)
		current.focus_next = current.get_path_to(following)
		if horizontal:
			current.focus_neighbor_left = current.get_path_to(previous)
			current.focus_neighbor_right = current.get_path_to(following)
		else:
			current.focus_neighbor_top = current.get_path_to(previous)
			current.focus_neighbor_bottom = current.get_path_to(following)


static func _palette(high_contrast: bool) -> Dictionary:
	if high_contrast:
		return {
			"background": Color.BLACK,
			"surface": Color("#05070b"),
			"raised": Color("#101820"),
			"text": Color.WHITE,
			"muted": Color("#d7e2e8"),
			"line": Color(1.0, 1.0, 1.0, 0.58),
			"focus": YELLOW,
		}
	return {
		"background": BACKGROUND,
		"surface": SURFACE,
		"raised": SURFACE_RAISED,
		"text": TEXT,
		"muted": MUTED,
		"line": Color(0.38, 0.91, 1.0, 0.28),
		"focus": CYAN,
	}


static func _add_label_variations(theme: Theme, palette: Dictionary, scale: float) -> void:
	_set_variation(theme, &"DisplayLabel", &"Label")
	theme.set_font_size(&"font_size", &"DisplayLabel", roundi(58.0 * scale))
	theme.set_color(&"font_color", &"DisplayLabel", palette.text)

	_set_variation(theme, &"TitleLabel", &"Label")
	theme.set_font_size(&"font_size", &"TitleLabel", roundi(34.0 * scale))
	theme.set_color(&"font_color", &"TitleLabel", palette.text)

	_set_variation(theme, &"SectionLabel", &"Label")
	theme.set_font_size(&"font_size", &"SectionLabel", roundi(22.0 * scale))
	theme.set_color(&"font_color", &"SectionLabel", palette.text)

	_set_variation(theme, &"EyebrowLabel", &"Label")
	theme.set_font_size(&"font_size", &"EyebrowLabel", roundi(13.0 * scale))
	theme.set_color(&"font_color", &"EyebrowLabel", CYAN)

	_set_variation(theme, &"MutedLabel", &"Label")
	theme.set_font_size(&"font_size", &"MutedLabel", roundi(15.0 * scale))
	theme.set_color(&"font_color", &"MutedLabel", palette.muted)

	_set_variation(theme, &"MetricLabel", &"Label")
	theme.set_font_size(&"font_size", &"MetricLabel", roundi(24.0 * scale))
	theme.set_color(&"font_color", &"MetricLabel", YELLOW)

	_set_variation(theme, &"WarningLabel", &"Label")
	theme.set_color(&"font_color", &"WarningLabel", RED)


static func _add_panel_variations(theme: Theme, palette: Dictionary) -> void:
	theme.set_stylebox(&"panel", &"PanelContainer", _panel_box(palette.surface, palette.line, 10, 22))

	_set_variation(theme, &"HeroPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"HeroPanel", _panel_box(Color(palette.surface, 0.96), Color(CYAN, 0.42), 12, 32))

	_set_variation(theme, &"CardPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"CardPanel", _panel_box(Color(palette.raised, 0.94), Color(palette.line, 0.72), 8, 18))

	_set_variation(theme, &"GarageHudPanel", &"PanelContainer")
	var garage_hud_alpha := 0.96 if palette.background == Color.BLACK else 0.80
	theme.set_stylebox(&"panel", &"GarageHudPanel", _panel_box(Color(palette.raised, garage_hud_alpha), Color(CYAN, 0.48), 8, 18))

	_set_variation(theme, &"GarageStagePanel", &"PanelContainer")
	var stage_alpha := 0.62 if palette.background == Color.BLACK else 0.22
	theme.set_stylebox(&"panel", &"GarageStagePanel", _panel_box(Color(palette.surface, stage_alpha), Color(CYAN, 0.18), 10, 18))

	_set_variation(theme, &"DangerPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"DangerPanel", _panel_box(Color(RED, 0.08), Color(RED, 0.55), 8, 18))


static func _add_button_variations(theme: Theme, palette: Dictionary, scale: float) -> void:
	var normal := _button_box(Color(palette.raised, 0.88), Color(palette.line, 0.82), 8)
	var hover := _button_box(Color("#172b3d"), Color(CYAN, 0.78), 8)
	var pressed := _button_box(Color("#0b202c"), CYAN, 8)
	var disabled := _button_box(Color(palette.surface, 0.6), Color(palette.line, 0.28), 8)
	var focus := _focus_box(palette.focus, 8)

	var button_states: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled", &"focus"]
	for state: StringName in button_states:
		var style: StyleBox = normal
		if state == &"hover": style = hover
		elif state == &"pressed": style = pressed
		elif state == &"disabled": style = disabled
		elif state == &"focus": style = focus
		theme.set_stylebox(state, &"Button", style)
	theme.set_font_size(&"font_size", &"Button", roundi(17.0 * scale))
	theme.set_color(&"font_color", &"Button", palette.text)
	theme.set_color(&"font_hover_color", &"Button", Color.WHITE)
	theme.set_color(&"font_pressed_color", &"Button", CYAN)
	theme.set_color(&"font_disabled_color", &"Button", Color(palette.muted, 0.5))
	theme.set_constant(&"outline_size", &"Button", 0)

	_set_variation(theme, &"PrimaryButton", &"Button")
	theme.set_stylebox(&"normal", &"PrimaryButton", _button_box(YELLOW, Color("#fff2aa"), 8))
	theme.set_stylebox(&"hover", &"PrimaryButton", _button_box(Color("#ffe77d"), Color.WHITE, 8))
	theme.set_stylebox(&"pressed", &"PrimaryButton", _button_box(ORANGE, YELLOW, 8))
	theme.set_stylebox(&"focus", &"PrimaryButton", _focus_box(CYAN, 8))
	theme.set_color(&"font_color", &"PrimaryButton", Color("#171004"))
	theme.set_color(&"font_hover_color", &"PrimaryButton", Color("#171004"))
	theme.set_color(&"font_pressed_color", &"PrimaryButton", Color("#171004"))

	_set_variation(theme, &"DangerButton", &"Button")
	theme.set_stylebox(&"normal", &"DangerButton", _button_box(Color(RED, 0.14), Color(RED, 0.58), 8))
	theme.set_stylebox(&"hover", &"DangerButton", _button_box(Color(RED, 0.26), RED, 8))
	theme.set_stylebox(&"pressed", &"DangerButton", _button_box(Color(RED, 0.36), Color.WHITE, 8))
	theme.set_stylebox(&"focus", &"DangerButton", _focus_box(YELLOW, 8))
	theme.set_color(&"font_color", &"DangerButton", Color("#ffabb7"))

	_set_variation(theme, &"CardButton", &"Button")
	theme.set_stylebox(&"normal", &"CardButton", _button_box(Color(palette.surface, 0.82), Color(palette.line, 0.58), 8, 18))
	theme.set_stylebox(&"hover", &"CardButton", _button_box(Color("#132838"), CYAN, 8, 18))
	theme.set_stylebox(&"pressed", &"CardButton", _button_box(Color("#09202a"), YELLOW, 8, 18))
	theme.set_stylebox(&"focus", &"CardButton", _focus_box(palette.focus, 8))


static func _add_form_controls(theme: Theme, palette: Dictionary, scale: float) -> void:
	var form_control_types: Array[StringName] = [&"CheckButton", &"OptionButton", &"LineEdit"]
	for type_name: StringName in form_control_types:
		theme.set_font_size(&"font_size", type_name, roundi(17.0 * scale))
		theme.set_color(&"font_color", type_name, palette.text)
		theme.set_color(&"font_hover_color", type_name, Color.WHITE)
		theme.set_color(&"font_focus_color", type_name, Color.WHITE)

	theme.set_stylebox(&"normal", &"LineEdit", _button_box(Color(palette.surface, 0.92), Color(palette.line, 0.72), 8))
	theme.set_stylebox(&"focus", &"LineEdit", _focus_box(palette.focus, 8))
	theme.set_stylebox(&"normal", &"OptionButton", _button_box(Color(palette.surface, 0.92), Color(palette.line, 0.72), 8))
	theme.set_stylebox(&"hover", &"OptionButton", _button_box(Color("#132838"), CYAN, 8))
	theme.set_stylebox(&"pressed", &"OptionButton", _button_box(Color("#09202a"), YELLOW, 8))
	theme.set_stylebox(&"focus", &"OptionButton", _focus_box(palette.focus, 8))

	theme.set_stylebox(&"background", &"ProgressBar", _button_box(Color(1.0, 1.0, 1.0, 0.08), Color.TRANSPARENT, 4, 0))
	theme.set_stylebox(&"fill", &"ProgressBar", _button_box(CYAN, Color.TRANSPARENT, 4, 0))
	theme.set_color(&"font_color", &"ProgressBar", palette.text)
	theme.set_font_size(&"font_size", &"ProgressBar", roundi(14.0 * scale))

	theme.set_stylebox(&"panel", &"ItemList", _panel_box(Color(palette.surface, 0.78), Color(palette.line, 0.56), 8, 8))
	theme.set_stylebox(&"selected", &"ItemList", _button_box(Color(CYAN, 0.16), CYAN, 6, 8))
	theme.set_stylebox(&"selected_focus", &"ItemList", _button_box(Color(CYAN, 0.2), YELLOW, 6, 8))
	theme.set_stylebox(&"focus", &"ItemList", _focus_box(palette.focus, 8))
	theme.set_color(&"font_color", &"ItemList", palette.text)
	theme.set_color(&"font_selected_color", &"ItemList", Color.WHITE)
	theme.set_font_size(&"font_size", &"ItemList", roundi(16.0 * scale))


static func _panel_box(color: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_top = padding
	box.content_margin_right = padding
	box.content_margin_bottom = padding
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
	box.shadow_size = 14
	return box


static func _button_box(color: Color, border: Color, radius: int, padding: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_top = 12
	box.content_margin_right = padding
	box.content_margin_bottom = 12
	return box


static func _focus_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.expand_margin_left = 2.0
	box.expand_margin_top = 2.0
	box.expand_margin_right = 2.0
	box.expand_margin_bottom = 2.0
	return box


static func _set_variation(theme: Theme, variation: StringName, base_type: StringName) -> void:
	theme.set_type_variation(variation, base_type)


static func _setting(settings: Dictionary, snake_case: String, camel_case: String, fallback: Variant) -> Variant:
	if settings.has(snake_case):
		return settings[snake_case]
	if settings.has(camel_case):
		return settings[camel_case]
	return fallback
