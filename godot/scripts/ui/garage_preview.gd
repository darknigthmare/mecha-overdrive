class_name GaragePreview
extends PanelContainer

## Self-contained, Web-friendly 3D garage preview. The component owns exactly
## one SubViewport and rebuilds the same procedural model used during races.

signal configured(chassis_id: String)

const MechaFactoryType := preload("res://scripts/mecha/mecha_factory.gd")
const ThemeFactory := preload("res://scripts/ui/ui_theme.gd")

const DEFAULT_PAINT := Color("5EE7FF")
const DEFAULT_YAW := -0.34
const ROTATION_STEP := PI / 8.0
const PLATFORM_TOP := 0.27
const MIN_ZOOM := 0.68
const MAX_ZOOM := 1.52
const DEFAULT_ZOOM := 0.82

@export_range(0.0, 1.0, 0.01) var auto_rotation_speed := 0.22
@export var reduced_motion := false

@onready var _viewport_container: SubViewportContainer = %ViewportContainer
@onready var _preview_viewport: SubViewport = %PreviewViewport
@onready var _world_environment: WorldEnvironment = %WorldEnvironment
@onready var _turntable: Node3D = %Turntable
@onready var _mecha_anchor: Node3D = %MechaAnchor
@onready var _camera: Camera3D = %PreviewCamera
@onready var _caption: Label = %PreviewCaption
@onready var _motion_state: Label = %MotionState
@onready var _rotate_left_button: Button = %RotateLeftButton
@onready var _rotate_right_button: Button = %RotateRightButton
@onready var _zoom_out_button: Button = %ZoomOutButton
@onready var _zoom_in_button: Button = %ZoomInButton
@onready var _reset_button: Button = %ResetButton

var _chassis: Dictionary = {}
var _paint := DEFAULT_PAINT
var _loadout: Dictionary = {}
var _visual: RacerVisual
var _camera_target := Vector3(0.0, 2.1, 0.0)
var _base_camera_distance := 8.5
var _zoom_factor := DEFAULT_ZOOM
var _dragging := false
var _manual_rotation_pause := 0.0


func _ready() -> void:
	var settings := _settings()
	theme = ThemeFactory.create_theme(settings)
	reduced_motion = bool(settings.get("reduced_motion", settings.get("reducedMotion", reduced_motion)))
	_configure_environment()
	_bind_controls()
	_refresh_motion_state()
	_reset_view(false)
	if not _chassis.is_empty():
		_rebuild_visual()


func _process(delta: float) -> void:
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
	if not is_visible_in_tree() or reduced_motion or _dragging or not is_instance_valid(_visual):
		return
	_manual_rotation_pause = maxf(0.0, _manual_rotation_pause - delta)
	if _manual_rotation_pause <= 0.0:
		_turntable.rotate_y(auto_rotation_speed * delta)


## Rebuilds the preview with the same chassis, paint and loadout contract used
## by RaceController. It is safe to call before the scene enters the tree.
func configure(chassis: Dictionary, paint_value: Variant, loadout: Dictionary = {}) -> void:
	_chassis = chassis.duplicate(true)
	var fallback_text := String(_chassis.get("paint", DEFAULT_PAINT.to_html(false)))
	var fallback := Color(fallback_text) if Color.html_is_valid(fallback_text) else DEFAULT_PAINT
	_paint = _coerce_color(paint_value, fallback)
	var modules_value: Variant = loadout.get("modules", loadout)
	_loadout = {}
	if modules_value is Dictionary:
		var modules: Dictionary = modules_value
		_loadout = modules.duplicate(true)
	if is_node_ready():
		_rebuild_visual()


## Positive values rotate the turntable clockwise in radians.
func rotate(amount: float) -> void:
	if not is_node_ready():
		return
	_turntable.rotate_y(amount)
	_manual_rotation_pause = 2.5


func rotate_left() -> void:
	rotate(-ROTATION_STEP)


func rotate_right() -> void:
	rotate(ROTATION_STEP)


## Positive values zoom in; negative values zoom out.
func zoom(amount: float) -> void:
	_zoom_factor = clampf(_zoom_factor - amount, MIN_ZOOM, MAX_ZOOM)
	_manual_rotation_pause = 2.5
	_apply_camera()


func zoom_in() -> void:
	zoom(0.10)


func zoom_out() -> void:
	zoom(-0.10)


func reset() -> void:
	_reset_view(true)


func reset_view() -> void:
	reset()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if is_instance_valid(_visual):
		_visual.set_accessibility(reduced_motion)
	if is_node_ready():
		_refresh_motion_state()


## Rebuilds the local theme when accessibility settings change while the
## garage remains open. The SubViewport controls do not inherit this reliably.
func refresh_theme(settings: Dictionary = {}) -> void:
	var effective_settings := settings if not settings.is_empty() else _settings()
	theme = ThemeFactory.create_theme(effective_settings)


func current_visual() -> RacerVisual:
	return _visual


func preview_texture() -> ViewportTexture:
	return _preview_viewport.get_texture() if is_node_ready() else null


func _bind_controls() -> void:
	_rotate_left_button.pressed.connect(rotate_left)
	_rotate_right_button.pressed.connect(rotate_right)
	_zoom_out_button.pressed.connect(zoom_out)
	_zoom_in_button.pressed.connect(zoom_in)
	_reset_button.pressed.connect(reset)
	_viewport_container.gui_input.connect(_on_viewport_input)


func _rebuild_visual() -> void:
	_clear_visual()
	if _chassis.is_empty():
		_caption.text = "APERÇU 3D // EN ATTENTE"
		return

	var visual: RacerVisual = MechaFactoryType.build(_chassis, _paint, true, _loadout)
	_visual = visual
	_mecha_anchor.add_child(_visual)
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_visual.set_accessibility(reduced_motion)
	_visual.set_motion(0.12, 0.0, false, 0.0)
	_visual.set_camera_mode("tps")
	_fit_visual()
	_reset_view(false)
	_caption.text = "APERÇU 3D // %s" % String(_chassis.get("name", _chassis.get("id", "CHÂSSIS"))).to_upper()
	configured.emit(String(_chassis.get("id", "")))


func _clear_visual() -> void:
	if not is_instance_valid(_visual):
		_visual = null
		return
	if _visual.get_parent() != null:
		_visual.get_parent().remove_child(_visual)
	_visual.queue_free()
	_visual = null


func _fit_visual() -> void:
	var bounds := _visual_bounds()
	if bounds.size.length_squared() <= 0.0001:
		bounds = AABB(Vector3(-2.0, 0.0, -2.0), Vector3(4.0, 4.0, 4.0))

	var center := bounds.get_center()
	_mecha_anchor.position = Vector3(-center.x, PLATFORM_TOP - bounds.position.y, -center.z)
	var height := maxf(bounds.size.y, 2.0)
	var horizontal_radius := maxf(1.5, Vector2(bounds.size.x, bounds.size.z).length() * 0.5)
	var viewport_size := _preview_viewport.size
	var aspect := maxf(1.0, float(viewport_size.x) / maxf(1.0, float(viewport_size.y)))
	var vertical_fov := deg_to_rad(_camera.fov)
	var horizontal_fov := 2.0 * atan(tan(vertical_fov * 0.5) * aspect)
	var vertical_distance := (height * 0.55) / maxf(0.1, tan(vertical_fov * 0.5))
	var horizontal_distance := horizontal_radius / maxf(0.1, tan(horizontal_fov * 0.5))
	_base_camera_distance = maxf(5.5, maxf(vertical_distance, horizontal_distance) * 1.28)
	_camera_target = Vector3(0.0, PLATFORM_TOP + height * 0.48, 0.0)
	_apply_camera()


func _visual_bounds() -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for candidate: Node in _visual.find_children("*", "MeshInstance3D", true, false):
		var part := candidate as MeshInstance3D
		if part == null or part.mesh == null or not part.visible:
			continue
		var relative_transform := _mecha_anchor.global_transform.affine_inverse() * part.global_transform
		var part_bounds: AABB = relative_transform * part.get_aabb()
		bounds = bounds.merge(part_bounds) if has_bounds else part_bounds
		has_bounds = true
	return bounds


func _apply_camera() -> void:
	if not is_node_ready():
		return
	var view_direction := Vector3(0.64, 0.36, 1.0).normalized()
	_camera.position = _camera_target + view_direction * (_base_camera_distance * _zoom_factor)
	_camera.look_at(_camera_target, Vector3.UP)


func _reset_view(mark_as_manual: bool) -> void:
	if not is_node_ready():
		return
	_turntable.rotation = Vector3(0.0, DEFAULT_YAW, 0.0)
	_zoom_factor = DEFAULT_ZOOM
	_manual_rotation_pause = 2.5 if mark_as_manual else 0.0
	_apply_camera()


func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_button.pressed
			if mouse_button.pressed:
				_viewport_container.grab_focus()
				if mouse_button.double_click:
					reset()
			_viewport_container.accept_event()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			_viewport_container.accept_event()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			_viewport_container.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mouse_motion := event as InputEventMouseMotion
		rotate(-mouse_motion.relative.x * 0.012)
		_viewport_container.accept_event()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_LEFT:
				rotate_left()
			KEY_RIGHT:
				rotate_right()
			KEY_R:
				reset()
			_:
				return
		_viewport_container.accept_event()


func _configure_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050911")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6f93ab")
	environment.ambient_light_energy = 0.74
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_world_environment.environment = environment


func _refresh_motion_state() -> void:
	_motion_state.text = "MOUVEMENT RÉDUIT" if reduced_motion else "ROTATION AUTO"
	_motion_state.tooltip_text = "Rotation automatique désactivée" if reduced_motion else "Glissez pour tourner, molette pour zoomer"


func _coerce_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		var color_value: Color = value
		return color_value
	var text := String(value)
	return Color(text) if Color.html_is_valid(text) else fallback


func _settings() -> Dictionary:
	var save := get_node_or_null("/root/SaveSystem")
	if save == null:
		return {}
	var profile_value: Variant = save.get("profile")
	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		var settings_value: Variant = profile.get("settings", {})
		if settings_value is Dictionary:
			return settings_value
	return {}
