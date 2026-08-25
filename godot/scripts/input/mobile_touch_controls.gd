class_name MobileTouchControls
extends Control

## Responsive multi-touch command surface for the race scene.
##
## It deliberately emits a separate deterministic control state instead of
## faking InputMap events. Keyboard and gamepad therefore remain active while
## several fingers can steer, accelerate and drift at the same time.

signal control_changed(action: StringName, strength: float)
signal action_triggered(action: StringName)
signal touch_mode_changed(enabled: bool)
signal layout_changed

const HOLD_ACTIONS: Array[StringName] = [
	&"race_left", &"race_right", &"race_accelerate",
	&"race_brake", &"race_drift", &"race_boost",
]
const PULSE_ACTIONS: Array[StringName] = [
	&"race_item", &"race_reset", &"race_camera", &"race_pause",
]
const MIN_TOUCH_TARGET := 88.0
const LANDSCAPE_TOUCH_TARGET := 104.0
const COMPACT_LANDSCAPE_MAX_WIDTH := 1080.0
const COMPACT_LANDSCAPE_MAX_HEIGHT := 600.0
const COMPACT_CLUSTER_GAP := 10.0

var _forced_visible := false
var _touch_detected := false
var _suppressed := false
var _built := false
var _hold_strengths: Dictionary[StringName, float] = {}
var _buttons: Dictionary[StringName, Button] = {}
var _steering_cluster: HBoxContainer
var _action_cluster: GridContainer
var _utility_cluster: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	get_viewport().size_changed.connect(_layout_controls)
	_refresh_visibility()
	_layout_controls()


func _exit_tree() -> void:
	_release_all_controls()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _touch_detected:
			_touch_detected = true
			_refresh_visibility()


## Desktop QA and accessibility settings can explicitly expose the surface.
func configure(force_visible: bool = false) -> void:
	_forced_visible = force_visible
	_refresh_visibility()
	_layout_controls()


func set_suppressed(suppressed: bool) -> void:
	if _suppressed == suppressed:
		return
	_suppressed = suppressed
	_refresh_visibility()


func is_touch_mode() -> bool:
	return visible


func hold_strength(action: StringName) -> float:
	return clampf(float(_hold_strengths.get(action, 0.0)), 0.0, 1.0)


func controls_snapshot() -> Dictionary:
	return {
		"left": hold_strength(&"race_left"),
		"right": hold_strength(&"race_right"),
		"throttle": hold_strength(&"race_accelerate"),
		"brake": hold_strength(&"race_brake"),
		"drift": hold_strength(&"race_drift") > 0.5,
		"boost": hold_strength(&"race_boost") > 0.5,
	}


func update_context(snapshot: Dictionary) -> void:
	if not _built:
		return
	var item_id := String(snapshot.get("item", ""))
	_set_button_available(&"race_item", not item_id.is_empty())
	_set_button_available(&"race_reset", bool(snapshot.get("can_reset", false)))
	var boost_available := float(snapshot.get("boost_energy", 0.0)) > 0.015 and float(snapshot.get("heat", 0.0)) < 0.96
	_set_button_available(&"race_boost", boost_available)


func button_count() -> int:
	return _buttons.size()


func release_controls() -> void:
	_release_all_controls()


func _build_interface() -> void:
	if _built:
		return
	_built = true
	_steering_cluster = HBoxContainer.new()
	_steering_cluster.name = "SteeringCluster"
	_steering_cluster.add_theme_constant_override(&"separation", 12)
	add_child(_steering_cluster)
	_add_hold_button(_steering_cluster, &"race_left", "<\nGAUCHE", "Diriger le mécha vers la gauche")
	_add_hold_button(_steering_cluster, &"race_right", ">\nDROITE", "Diriger le mécha vers la droite")

	_action_cluster = GridContainer.new()
	_action_cluster.name = "ActionCluster"
	_action_cluster.columns = 3
	_action_cluster.add_theme_constant_override(&"h_separation", 10)
	_action_cluster.add_theme_constant_override(&"v_separation", 10)
	add_child(_action_cluster)
	_add_hold_button(_action_cluster, &"race_drift", "DRIFT", "Maintenir pour dériver et recharger le réacteur")
	_add_hold_button(_action_cluster, &"race_boost", "SURCHARGE", "Maintenir pour activer la surcharge")
	_add_pulse_button(_action_cluster, &"race_item", "OBJET", "Utiliser le module de course équipé")
	_add_hold_button(_action_cluster, &"race_brake", "FREIN", "Freiner et stabiliser le mécha")
	_add_hold_button(_action_cluster, &"race_accelerate", "GAZ", "Accélérer")

	_utility_cluster = HBoxContainer.new()
	_utility_cluster.name = "UtilityCluster"
	_utility_cluster.add_theme_constant_override(&"separation", 10)
	add_child(_utility_cluster)
	_add_pulse_button(_utility_cluster, &"race_reset", "RECENTRER", "Replacer le mécha au dernier point sûr")
	_add_pulse_button(_utility_cluster, &"race_camera", "CAMÉRA", "Basculer entre les vues TPS et cockpit")
	_add_pulse_button(_utility_cluster, &"race_pause", "PAUSE", "Suspendre la course")


func _add_hold_button(parent: Container, action: StringName, label: String, hint: String) -> void:
	var button := _button(label, hint)
	button.button_down.connect(_set_hold.bind(action, 1.0))
	button.button_up.connect(_set_hold.bind(action, 0.0))
	button.mouse_exited.connect(func() -> void:
		if not button.button_pressed:
			_set_hold(action, 0.0)
	)
	parent.add_child(button)
	_buttons[action] = button
	_hold_strengths[action] = 0.0


func _add_pulse_button(parent: Container, action: StringName, label: String, hint: String) -> void:
	var button := _button(label, hint)
	button.pressed.connect(_trigger_action.bind(action))
	parent.add_child(button)
	_buttons[action] = button


func _button(label: String, hint: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(MIN_TOUCH_TARGET, MIN_TOUCH_TARGET)
	return button


func _set_hold(action: StringName, strength: float) -> void:
	if not action in HOLD_ACTIONS:
		return
	var normalized := clampf(strength, 0.0, 1.0)
	if is_equal_approx(float(_hold_strengths.get(action, 0.0)), normalized):
		return
	_hold_strengths[action] = normalized
	if normalized > 0.0:
		Input.vibrate_handheld(18, 0.35)
	control_changed.emit(action, normalized)


func _trigger_action(action: StringName) -> void:
	if not action in PULSE_ACTIONS:
		return
	Input.vibrate_handheld(24, 0.45)
	action_triggered.emit(action)


func _set_button_available(action: StringName, enabled: bool) -> void:
	var button: Button = _buttons.get(action)
	if button == null:
		return
	if button.disabled == not enabled:
		return
	button.disabled = not enabled
	if not enabled and action in HOLD_ACTIONS:
		_set_hold(action, 0.0)


func _refresh_visibility() -> void:
	var platform_touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var next_visible := not _suppressed and (_forced_visible or _touch_detected or platform_touch)
	if visible == next_visible:
		return
	visible = next_visible
	if not visible:
		_release_all_controls()
	touch_mode_changed.emit(visible)


func _layout_controls() -> void:
	if not _built:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var landscape := viewport_size.x >= viewport_size.y
	var short_edge := minf(viewport_size.x, viewport_size.y)
	var safe_margin := clampf(short_edge * 0.03, 22.0, 48.0)
	var safe_insets := _safe_area_insets(viewport_size)
	var left_margin := maxf(safe_margin, safe_insets.x + 12.0)
	var top_margin := maxf(safe_margin, safe_insets.y + 12.0)
	var right_margin := maxf(safe_margin, safe_insets.z + 12.0)
	var bottom_margin := maxf(safe_margin, safe_insets.w + 12.0)
	var target := clampf(short_edge * (0.096 if landscape else 0.090), MIN_TOUCH_TARGET, LANDSCAPE_TOUCH_TARGET if landscape else 112.0)
	for button: Button in _buttons.values():
		button.custom_minimum_size = Vector2(target * (1.28 if button.text == "GAZ" else 1.0), target)

	_steering_cluster.reset_size()
	_action_cluster.reset_size()
	_utility_cluster.reset_size()
	var steering_size := _steering_cluster.get_combined_minimum_size()
	var action_size := _action_cluster.get_combined_minimum_size()
	var utility_size := _utility_cluster.get_combined_minimum_size()
	if landscape:
		var compact_landscape := (
			viewport_size.x < COMPACT_LANDSCAPE_MAX_WIDTH
			or viewport_size.y < COMPACT_LANDSCAPE_MAX_HEIGHT
		)
		if compact_landscape:
			# Short 19.5:9 phones need three explicit, non-intersecting zones.
			# Use measured container sizes because the wide GAZ target makes the
			# action grid wider than a simple three-target estimate.
			var bottom_edge := viewport_size.y - bottom_margin
			_steering_cluster.position = Vector2(left_margin, bottom_edge - steering_size.y)
			_action_cluster.position = Vector2(viewport_size.x - right_margin - action_size.x, bottom_edge - action_size.y)
			_utility_cluster.position = Vector2(
				left_margin,
				maxf(top_margin, _steering_cluster.position.y - COMPACT_CLUSTER_GAP - utility_size.y)
			)
		else:
			_steering_cluster.position = Vector2(left_margin, viewport_size.y - bottom_margin - steering_size.y)
			_action_cluster.position = Vector2(viewport_size.x - right_margin - action_size.x, viewport_size.y - bottom_margin - action_size.y)
			# Utility actions sit below the race header instead of covering position
			# and timing. Their centred vertical band also remains reachable by thumb.
			_utility_cluster.position = Vector2(
				viewport_size.x - right_margin - utility_size.x,
				maxf(top_margin + target * 1.20, viewport_size.y * 0.27)
			)
	else:
		# Portrait previously stacked steering and the 3x2 action grid on the
		# same pixels. Give each cluster a dedicated horizontal band.
		_steering_cluster.position = Vector2(left_margin, viewport_size.y - bottom_margin - steering_size.y)
		_action_cluster.position = Vector2(
			maxf(left_margin, viewport_size.x - right_margin - action_size.x),
			viewport_size.y - bottom_margin - target * 3.25
		)
		_utility_cluster.position = Vector2(
			clampf((viewport_size.x - utility_size.x) * 0.5, left_margin, viewport_size.x - right_margin - utility_size.x),
			maxf(top_margin + target * 1.40, viewport_size.y * 0.19)
		)
	layout_changed.emit()


func control_regions() -> Dictionary:
	return {
		"steering": Rect2(_steering_cluster.position, _steering_cluster.size) if _steering_cluster != null else Rect2(),
		"actions": Rect2(_action_cluster.position, _action_cluster.size) if _action_cluster != null else Rect2(),
		"utilities": Rect2(_utility_cluster.position, _utility_cluster.size) if _utility_cluster != null else Rect2(),
	}


## Insets are converted from physical-window pixels to the logical viewport.
func _safe_area_insets(viewport_size: Vector2) -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return Vector4.ZERO
	var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	return Vector4(
		maxf(0.0, safe_rect.position.x * scale.x),
		maxf(0.0, safe_rect.position.y * scale.y),
		maxf(0.0, (window_size.x - safe_rect.end.x) * scale.x),
		maxf(0.0, (window_size.y - safe_rect.end.y) * scale.y)
	)


func _release_all_controls() -> void:
	for action: StringName in HOLD_ACTIONS:
		if float(_hold_strengths.get(action, 0.0)) > 0.0:
			_hold_strengths[action] = 0.0
			control_changed.emit(action, 0.0)
