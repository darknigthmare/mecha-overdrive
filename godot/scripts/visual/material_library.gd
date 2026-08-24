class_name MaterialLibrary
extends RefCounted

## Shared, Web-friendly textured materials. Every texture has a color fallback,
## so source scenes remain runnable while generated assets are being imported.

const MECHA_ARMOR := "res://assets/textures/openai/mecha_armor.png"
const MECHA_ARMOR_LIGHT := "res://assets/textures/openai/mecha_armor_light.png"
const MECHA_ARMOR_HEAVY := "res://assets/textures/openai/mecha_armor_heavy.png"
const TRACK_SURFACE := "res://assets/textures/openai/track_surface.png"
const TRACK_CRYO := "res://assets/textures/openai/track_cryo.png"
const TRACK_THERMAL := "res://assets/textures/openai/track_thermal.png"
const COCKPIT_COMPOSITE := "res://assets/textures/openai/cockpit_composite.png"
const ENVIRONMENT_PANELS := "res://assets/textures/openai/environment_panels.png"
const MODULE_ENERGY := "res://assets/textures/openai/module_energy.png"
const MODULE_MOBILITY := "res://assets/textures/openai/module_mobility.png"
const MODULE_UTILITY := "res://assets/textures/openai/module_utility.png"
const GARAGE_BAY := "res://assets/textures/openai/garage_bay.png"
const PROP_INDUSTRIAL := "res://assets/textures/openai/prop_industrial.png"
const PROP_BIOME := "res://assets/textures/openai/prop_biome.png"
const PROP_URBAN_WET := "res://assets/textures/openai/prop_urban_wet.png"
const RACE_CEREMONIAL := "res://assets/textures/openai/race_ceremonial.png"
const LOCOMOTION_ANTIGRAV := "res://assets/textures/openai/locomotion_antigrav.png"

static var _textures: Dictionary = {}


static func mecha(color: Color, metallic: float = 0.82, roughness: float = 0.26, repeat: float = 2.0) -> StandardMaterial3D:
	return textured(color, metallic, roughness, MECHA_ARMOR, Vector3(repeat, repeat, 1.0))


static func mecha_for(chassis: Dictionary, color: Color, layer: String = "primary") -> StandardMaterial3D:
	var division_id := String(chassis.get("division_id", "")).to_lower()
	var preferred_path := ""
	match division_id:
		"command", "experimental", "swarm": preferred_path = MECHA_ARMOR_LIGHT
		"ground", "stabilized": preferred_path = MECHA_ARMOR_HEAVY
	var secondary := layer.to_lower() in ["secondary", "dark"]
	return textured(
		color,
		0.9 if secondary else 0.82,
		0.31 if secondary else 0.24,
		_available_path(preferred_path, MECHA_ARMOR),
		Vector3(2.4, 2.4, 1.0) if secondary else Vector3(1.8, 1.8, 1.0)
	)


static func module_for(slot_id: String, color: Color) -> StandardMaterial3D:
	var preferred_path := ""
	var fallback_path := MECHA_ARMOR
	var metallic := 0.82
	var roughness := 0.3
	var repeat := 2.4
	match slot_id.to_lower():
		"core", "energy":
			preferred_path = MODULE_ENERGY
			metallic = 0.76
			roughness = 0.24
			repeat = 2.0
		"mobility":
			preferred_path = MODULE_MOBILITY
			fallback_path = COCKPIT_COMPOSITE
			metallic = 0.86
			roughness = 0.34
			repeat = 3.0
		"utility":
			preferred_path = MODULE_UTILITY
			fallback_path = ENVIRONMENT_PANELS
			metallic = 0.68
			roughness = 0.4
	return textured(color, metallic, roughness, _available_path(preferred_path, fallback_path), Vector3(repeat, repeat, 1.0))


static func joint(color: Color = Color("18212c")) -> StandardMaterial3D:
	return textured(color, 0.88, 0.3, ENVIRONMENT_PANELS, Vector3(3.0, 3.0, 1.0))


static func cockpit(color: Color = Color("63889a")) -> StandardMaterial3D:
	return textured(color, 0.72, 0.18, COCKPIT_COMPOSITE, Vector3(1.35, 1.35, 1.0))


static func road(color: Color, metallic: float = 0.56, roughness: float = 0.4, vertex_color: bool = true) -> StandardMaterial3D:
	return textured(color, metallic, roughness, TRACK_SURFACE, Vector3(1.0, 0.055, 1.0), vertex_color)


static func road_for(track: Dictionary, color: Color, vertex_color: bool = true) -> StandardMaterial3D:
	var preferred_path := ""
	match String(track.get("id", "")).to_lower():
		"glacier", "abyss": preferred_path = TRACK_CRYO
		"foundry", "caldera": preferred_path = TRACK_THERMAL
	return textured(color, 0.56, 0.4, _available_path(preferred_path, TRACK_SURFACE), Vector3(1.0, 0.055, 1.0), vertex_color)


static func environment(color: Color, metallic: float = 0.56, roughness: float = 0.52, repeat: float = 2.0) -> StandardMaterial3D:
	return textured(color, metallic, roughness, ENVIRONMENT_PANELS, Vector3(repeat, repeat, 1.0))


static func prop_for(track: Dictionary, color: Color = Color.WHITE, repeat: float = 2.4) -> StandardMaterial3D:
	var prop_set := String(track.get("prop_set", "industrial")).to_lower()
	var texture_path := PROP_INDUSTRIAL
	var metallic := 0.66
	var roughness := 0.46
	if prop_set in ["jungle", "ice", "abyss", "desert", "volcanic"]:
		texture_path = PROP_BIOME
		metallic = 0.24
		roughness = 0.68
	elif prop_set in ["urban", "city", "wet"]:
		texture_path = PROP_URBAN_WET
		metallic = 0.54
		roughness = 0.24
	return textured(color, metallic, roughness, _available_path(texture_path, ENVIRONMENT_PANELS), Vector3(repeat, repeat, 1.0))


static func ceremonial(color: Color = Color.WHITE, repeat: float = 2.0) -> StandardMaterial3D:
	return textured(color, 0.78, 0.24, _available_path(RACE_CEREMONIAL, ENVIRONMENT_PANELS), Vector3(repeat, repeat, 1.0))


static func locomotion_for(drive_id: String, color: Color) -> StandardMaterial3D:
	var normalized_drive := drive_id.to_lower()
	var use_antigrav := normalized_drive in ["twin_antigrav", "antigrav", "twin_engine", "remote_thruster", "aeroglider"]
	var texture_path := _available_path(LOCOMOTION_ANTIGRAV, MODULE_MOBILITY) if use_antigrav else MODULE_MOBILITY
	var material := textured(color, 0.84, 0.27, texture_path, Vector3(2.6, 2.6, 1.0))
	material.set_meta("locomotion_drive_id", normalized_drive)
	material.set_meta("texture_path", texture_path)
	material.set_meta("uses_antigrav_texture", use_antigrav and texture_path == LOCOMOTION_ANTIGRAV)
	return material


static func garage_surface() -> StandardMaterial3D:
	return textured(Color.WHITE, 0.58, 0.46, _available_path(GARAGE_BAY, ENVIRONMENT_PANELS), Vector3(2.0, 2.0, 1.0))


static func textured(color: Color, metallic: float, roughness: float, path: String, uv_scale: Vector3 = Vector3.ONE, vertex_color: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.vertex_color_use_as_albedo = vertex_color
	var bitmap := texture(path)
	if bitmap != null:
		material.albedo_texture = bitmap
		material.uv1_scale = uv_scale
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func _available_path(preferred_path: String, fallback_path: String) -> String:
	if not preferred_path.is_empty() and texture(preferred_path) != null:
		return preferred_path
	return fallback_path


static func emissive(color: Color, energy: float = 2.5, path: String = ENVIRONMENT_PANELS) -> StandardMaterial3D:
	var material := textured(color, 0.62, 0.22, path, Vector3(2.0, 2.0, 1.0))
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		_textures[path] = resource
		return resource as Texture2D
	return null
