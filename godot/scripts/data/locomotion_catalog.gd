class_name LocomotionCatalog
extends RefCounted

## Data-driven locomotion catalogue.
##
## Each of the ten homologated chassis families receives ten propulsion systems
## and five mounting geometries: 50 tangible combinations per family, 500 in
## total.  Nothing is persisted here, so an older save with no locomotion_id
## keeps the constructor default selected by get_default_configuration_id().

const FAMILY_IDS: Array[String] = [
	"biped", "tripod", "quadruped", "hexapod", "octopod",
	"hover", "tracked", "monowheel", "orb", "centurion",
]

const DRIVE_OPTIONS: Array[Dictionary] = [
	{
		"id": "mecha_legs", "name": "Jambes mécaniques", "short": "JAMBES",
		"manufacturer": "Valkyr Articulation", "tier": 0, "power_draw": 0,
		"description": "Articulations à rappel actif, talons amortis et vérins de relance.",
		"lore": "Dérivées des premiers marcheurs industriels du Nexus, ces jambes restent réparables dans chaque paddock de la Ligue.",
		"stats": {"speed": 0, "acceleration": 2, "handling": 3, "armor": 0, "stability": 2, "reactor": -1},
	},
	{
		"id": "wheels", "name": "Roues vectorielles", "short": "ROUES",
		"manufacturer": "Calder Motion", "tier": 1, "power_draw": 1,
		"description": "Moyeux indépendants, carrossage dynamique et pneus sans air.",
		"lore": "Chaque moyeu corrige son angle avant le contact, donnant aux architectures les plus hautes une précision de prototype routier.",
		"stats": {"speed": 6, "acceleration": 4, "handling": 2, "armor": -2, "stability": -1, "reactor": 0},
	},
	{
		"id": "treads", "name": "Chenilles segmentées", "short": "CHENILLES",
		"manufacturer": "Calder Groundworks", "tier": 1, "power_draw": 1,
		"description": "Deux trains chenillés compacts à tension adaptative.",
		"lore": "Les patins emboîtés répartissent les impacts sur tout le flanc et continuent d'entraîner le châssis même après la perte d'un segment.",
		"stats": {"speed": -4, "acceleration": 3, "handling": -2, "armor": 6, "stability": 7, "reactor": -1},
	},
	{
		"id": "multi_support", "name": "Appuis distribués", "short": "MULTI-APPUIS",
		"manufacturer": "Mantis Collective", "tier": 1, "power_draw": 2,
		"description": "Bras auxiliaires synchronisés et patins de lecture du relief.",
		"lore": "Le calculateur Mantis délègue chaque contact à un nœud local; le châssis avance comme un essaim qui partagerait une seule intention.",
		"stats": {"speed": -2, "acceleration": 2, "handling": 6, "armor": 1, "stability": 6, "reactor": -2},
	},
	{
		"id": "sphere_drive", "name": "Sphères omnidirectionnelles", "short": "SPHÈRES",
		"manufacturer": "Nexus Inertia Lab", "tier": 1, "power_draw": 2,
		"description": "Contacts sphériques capables de pousser dans toutes les directions.",
		"lore": "Des anneaux magnétiques déplacent le point d'appui autour de chaque sphère sans interrompre la motricité.",
		"stats": {"speed": 2, "acceleration": 1, "handling": 7, "armor": -2, "stability": 3, "reactor": -2},
	},
	{
		"id": "mono_gyro", "name": "Gyro-roue tandem", "short": "GYRO",
		"manufacturer": "Aster Gyrodynamics", "tier": 1, "power_draw": 2,
		"description": "Anneaux gyroscopiques tandem avec récupération de dérive.",
		"lore": "Deux volants opposés annulent les oscillations parasites tout en conservant l'énergie accumulée pendant une longue dérive.",
		"stats": {"speed": 5, "acceleration": 2, "handling": 5, "armor": -3, "stability": -1, "reactor": 1},
	},
	{
		"id": "hover_skids", "name": "Patins magnétiques", "short": "MAG-PATINS",
		"manufacturer": "Nexus Fieldworks", "tier": 1, "power_draw": 2,
		"description": "Patins sans contact et stabilisateurs de lacet.",
		"lore": "Le champ porteur suit les balises de piste et efface la plupart des irrégularités, au prix d'une consommation constante.",
		"stats": {"speed": 5, "acceleration": 3, "handling": 1, "armor": -3, "stability": 2, "reactor": -3},
	},
	{
		"id": "twin_antigrav", "name": "Bi-propulseur Aether", "short": "BI-PROPULSEUR",
		"manufacturer": "Aether Independent Racing", "tier": 2, "power_draw": 3,
		"description": "Deux nacelles antigravité distantes reliées par des bras de contrôle.",
		"lore": "Aether a séparé la poussée du cockpit afin que chaque nacelle puisse chercher sa propre ligne. Cette architecture originale est née sur le Circuit Zéro.",
		"stats": {"speed": 9, "acceleration": 5, "handling": -2, "armor": -5, "stability": -4, "reactor": -4},
	},
	{
		"id": "articulated_rail", "name": "Rails articulés", "short": "RAILS",
		"manufacturer": "Valkyr Transit Lab", "tier": 1, "power_draw": 2,
		"description": "Lames motrices articulées pour accélérations rectilignes.",
		"lore": "Les rails sont composés de plaques qui se verrouillent à haute vitesse puis se désolidarisent pour rendre le braquage au pilote.",
		"stats": {"speed": 7, "acceleration": 3, "handling": -3, "armor": 0, "stability": 3, "reactor": -2},
	},
	{
		"id": "ducted_fans", "name": "Turbines carénées", "short": "TURBINES",
		"manufacturer": "Pelagos Vector", "tier": 2, "power_draw": 3,
		"description": "Turbines réversibles carénées et aubes de poussée froide.",
		"lore": "Conçues pour les pistes noyées de Pelagos, les turbines déplacent aussi bien l'air que les fluides denses sans exposer leurs pales.",
		"stats": {"speed": 4, "acceleration": 6, "handling": 2, "armor": -3, "stability": 0, "reactor": -3},
	},
]

const MOUNT_OPTIONS: Array[Dictionary] = [
	{
		"id": "compact", "name": "Compact", "width": 0.78, "length": 0.82, "height": 0.88,
		"description": "Empattement court pour les circuits serrés.", "cost_scale": 0.85,
		"stats": {"speed": -1, "acceleration": 3, "handling": 4, "armor": -2, "stability": -1, "reactor": 0},
	},
	{
		"id": "balanced", "name": "Équilibré", "width": 1.0, "length": 1.0, "height": 1.0,
		"description": "Géométrie constructeur polyvalente.", "cost_scale": 1.0,
		"stats": {"speed": 0, "acceleration": 0, "handling": 0, "armor": 0, "stability": 0, "reactor": 0},
	},
	{
		"id": "wide", "name": "Voie large", "width": 1.28, "length": 1.05, "height": 0.94,
		"description": "Voie élargie et centre de roulis abaissé.", "cost_scale": 1.12,
		"stats": {"speed": -1, "acceleration": -1, "handling": 3, "armor": 1, "stability": 5, "reactor": 0},
	},
	{
		"id": "endurance", "name": "Endurance", "width": 1.08, "length": 1.24, "height": 1.05,
		"description": "Montage renforcé et refroidi pour les longues manches.", "cost_scale": 1.22,
		"stats": {"speed": -2, "acceleration": -1, "handling": -1, "armor": 4, "stability": 3, "reactor": 4},
	},
	{
		"id": "racing", "name": "Pointe", "width": 0.92, "length": 1.18, "height": 0.82,
		"description": "Montage allégé privilégiant la vitesse de pointe.", "cost_scale": 1.35,
		"stats": {"speed": 5, "acceleration": 2, "handling": -2, "armor": -4, "stability": -3, "reactor": -1},
	},
]

const DEFAULT_DRIVE_BY_FAMILY := {
	"biped": "mecha_legs", "tripod": "mecha_legs", "quadruped": "mecha_legs",
	"hexapod": "multi_support", "octopod": "multi_support", "hover": "hover_skids",
	"tracked": "treads", "monowheel": "mono_gyro", "orb": "sphere_drive",
	"centurion": "multi_support",
}


static func get_family_ids() -> Array[String]:
	return FAMILY_IDS.duplicate()


static func get_drive_options() -> Array[Dictionary]:
	return DRIVE_OPTIONS.duplicate(true)


static func get_mount_options() -> Array[Dictionary]:
	return MOUNT_OPTIONS.duplicate(true)


static func get_configuration_count_for_family(family_id: String) -> int:
	return DRIVE_OPTIONS.size() * MOUNT_OPTIONS.size() if family_id in FAMILY_IDS else 0


static func get_total_configuration_count() -> int:
	return FAMILY_IDS.size() * DRIVE_OPTIONS.size() * MOUNT_OPTIONS.size()


static func get_configurations_for_family(family_id: String) -> Array[Dictionary]:
	var configurations: Array[Dictionary] = []
	if family_id not in FAMILY_IDS:
		return configurations
	for drive: Dictionary in DRIVE_OPTIONS:
		for mount: Dictionary in MOUNT_OPTIONS:
			configurations.append(_compose(family_id, drive, mount))
	return configurations


static func get_configurations_for_chassis(chassis_id: String) -> Array[Dictionary]:
	return get_configurations_for_family(chassis_id)


static func get_configuration(configuration_id: String) -> Dictionary:
	var parts := configuration_id.split("__", false)
	if parts.size() != 3 or parts[0] not in FAMILY_IDS:
		return {}
	var drive := _find(DRIVE_OPTIONS, parts[1])
	var mount := _find(MOUNT_OPTIONS, parts[2])
	return _compose(parts[0], drive, mount) if not drive.is_empty() and not mount.is_empty() else {}


static func get_default_configuration_id(chassis_id: String) -> String:
	var family_id := chassis_id if chassis_id in FAMILY_IDS else "biped"
	return "%s__%s__balanced" % [family_id, String(DEFAULT_DRIVE_BY_FAMILY.get(family_id, "mecha_legs"))]


static func resolve_configuration(chassis: Dictionary, customization: Dictionary = {}) -> Dictionary:
	var chassis_id := String(chassis.get("id", "biped"))
	var requested: Variant = customization.get("locomotion_id", customization.get("locomotion", ""))
	if requested is Dictionary:
		var requested_dictionary: Dictionary = requested
		requested = requested_dictionary.get("id", "")
	var configuration := get_configuration(String(requested))
	if configuration.is_empty() or String(configuration.get("family_id", "")) != chassis_id:
		configuration = get_configuration(get_default_configuration_id(chassis_id))
	return configuration


static func is_configuration_allowed_for_class(configuration: Dictionary, performance_class: Dictionary) -> bool:
	if configuration.is_empty() or performance_class.is_empty():
		return false
	var family_id := String(configuration.get("family_id", "biped"))
	if String(performance_class.get("module_policy", "all")) == "defaults_only":
		return String(configuration.get("id", "")) == get_default_configuration_id(family_id)
	var max_tier := maxi(0, int(performance_class.get("max_module_tier", 0)))
	var power_budget := maxi(0, int(performance_class.get("module_power_budget", 0)))
	return int(configuration.get("tier", 0)) <= max_tier and int(configuration.get("power_draw", 0)) <= power_budget


static func homologate_configuration(chassis: Dictionary, requested_id: String, performance_class: Dictionary) -> Dictionary:
	var requested := resolve_configuration(chassis, {"locomotion_id": requested_id})
	if is_configuration_allowed_for_class(requested, performance_class):
		return requested
	return get_configuration(get_default_configuration_id(String(chassis.get("id", "biped"))))


static func _compose(family_id: String, drive: Dictionary, mount: Dictionary) -> Dictionary:
	var drive_id := String(drive.get("id", ""))
	var mount_id := String(mount.get("id", ""))
	var stats := _merge_stats(drive.get("stats", {}), mount.get("stats", {}))
	var tier := maxi(int(drive.get("tier", 0)), 1 if mount_id in ["endurance", "racing"] else 0)
	var base_cost := 450 + int(drive.get("tier", 0)) * 850
	return {
		"id": "%s__%s__%s" % [family_id, drive_id, mount_id],
		"family_id": family_id,
		"chassis_id": family_id,
		"drive_id": drive_id,
		"mount_id": mount_id,
		"name": "%s · %s" % [String(drive.get("name", drive_id)), String(mount.get("name", mount_id))],
		"short_name": "%s / %s" % [String(drive.get("short", drive_id)), String(mount.get("name", mount_id)).to_upper()],
		"description": "%s %s" % [String(drive.get("description", "")), String(mount.get("description", ""))],
		"manufacturer": String(drive.get("manufacturer", "Nexus Racing Works")),
		"lore": String(drive.get("lore", "")),
		"tier": tier,
		"power_draw": int(drive.get("power_draw", 0)) + (1 if mount_id == "racing" else 0),
		"cost": int(round(float(base_cost) * float(mount.get("cost_scale", 1.0)))),
		"stats": stats,
		"visual": {
			"drive_id": drive_id,
			"mount_id": mount_id,
			"width": float(mount.get("width", 1.0)),
			"length": float(mount.get("length", 1.0)),
			"height": float(mount.get("height", 1.0)),
		},
	}


static func _merge_stats(first_value: Variant, second_value: Variant) -> Dictionary:
	var first: Dictionary = first_value if first_value is Dictionary else {}
	var second: Dictionary = second_value if second_value is Dictionary else {}
	var merged := {}
	for key: String in ["speed", "acceleration", "handling", "armor", "stability", "reactor"]:
		merged[key] = int(first.get(key, 0)) + int(second.get(key, 0))
	return merged


static func _find(entries: Array[Dictionary], requested_id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if String(entry.get("id", "")) == requested_id:
			return entry
	return {}
