class_name MaterialLibrary
extends RefCounted

## Shared, Web-friendly textured materials. Every texture has a color fallback,
## so source scenes remain runnable while generated assets are being imported.

const MECHA_ARMOR := "res://assets/textures/openai/mecha_armor.png"
const TRACK_SURFACE := "res://assets/textures/openai/track_surface.png"
const COCKPIT_COMPOSITE := "res://assets/textures/openai/cockpit_composite.png"
const ENVIRONMENT_PANELS := "res://assets/textures/openai/environment_panels.png"

static var _textures: Dictionary = {}


static func mecha(color: Color, metallic: float = 0.82, roughness: float = 0.26, repeat: float = 2.0) -> StandardMaterial3D:
	return textured(color, metallic, roughness, MECHA_ARMOR, Vector3(repeat, repeat, 1.0))


static func joint(color: Color = Color("18212c")) -> StandardMaterial3D:
	return textured(color, 0.88, 0.3, ENVIRONMENT_PANELS, Vector3(3.0, 3.0, 1.0))


static func cockpit(color: Color = Color("63889a")) -> StandardMaterial3D:
	return textured(color, 0.72, 0.18, COCKPIT_COMPOSITE, Vector3(1.35, 1.35, 1.0))


static func road(color: Color, metallic: float = 0.56, roughness: float = 0.4, vertex_color: bool = true) -> StandardMaterial3D:
	return textured(color, metallic, roughness, TRACK_SURFACE, Vector3(1.0, 0.055, 1.0), vertex_color)


static func environment(color: Color, metallic: float = 0.56, roughness: float = 0.52, repeat: float = 2.0) -> StandardMaterial3D:
	return textured(color, metallic, roughness, ENVIRONMENT_PANELS, Vector3(repeat, repeat, 1.0))


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
