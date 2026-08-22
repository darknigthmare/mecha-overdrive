class_name GameDatabase
extends RefCounted
## Immutable canonical catalogue. Public getters always return deep copies.

static var CHASSIS: Array[Dictionary] = [
	_chassis("biped", "BIPÈDE", "command", Vector3(0.0, 2.65, 0.10), "Raptor R2", "Polyvalence tactique", "Gyro-correction", "Réduit de 40 % les pertes de contrôle causées par les impacts.", "#5EE7FF", "#D9FBFF", [74, 75, 78, 64, 72, 74], [1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00]),
	_chassis("tripod", "TRIPODE", "stabilized", Vector3(0.0, 2.45, 0.20), "Triarch T3", "Stabilité absolue", "Ancrage vectoriel", "Résiste aux impacts et conserve son cap dans les courbes rapides.", "#9B8CFF", "#EFEAFF", [68, 66, 80, 80, 97, 65], [0.94, 0.91, 1.05, 1.18, 1.04, 0.98, 1.25]),
	_chassis("quadruped", "QUADRUPÈDE", "stabilized", Vector3(0.0, 2.05, 0.25), "Fenrir Q4", "Sprint prédateur", "Foulée prédatrice", "Déclenche une reprise temporaire après freinage, impact ou retour en piste.", "#FF765E", "#FFE2D9", [81, 91, 84, 58, 84, 70], [1.05, 1.20, 1.08, 0.91, 1.13, 1.04, 0.90]),
	_chassis("hexapod", "HEXAPODE", "swarm", Vector3(0.0, 1.85, 0.20), "Mantis H6", "Précision arachnéenne", "Pas adaptatifs", "Réduit fortement la pénalité hors-piste et améliore le braquage à basse vitesse.", "#68F29C", "#E2FFEC", [71, 74, 96, 65, 92, 69], [0.97, 1.01, 1.23, 1.01, 1.42, 0.99, 1.05]),
	_chassis("octopod", "OCTOPODE", "swarm", Vector3(0.0, 1.95, 0.15), "Arachne O8", "Forteresse mobile", "Bélier réparti", "Inflige davantage de dégâts de contact et conserve mieux son élan.", "#F253AD", "#FFE1F3", [66, 61, 72, 97, 99, 62], [0.91, 0.84, 0.92, 1.45, 1.16, 0.95, 1.55]),
	_chassis("hover", "AÉROGLISSEUR", "experimental", Vector3(0.0, 1.65, 0.35), "Wraith V0", "Vitesse sans contact", "Coussin magnétique", "Ignore les mines au sol et conserve sa vitesse sur les terrains meubles.", "#4FA9FF", "#DCEEFF", [98, 78, 59, 48, 51, 94], [1.19, 1.04, 0.83, 0.73, 1.30, 1.20, 0.72]),
	_chassis("tracked", "CHENILLES", "ground", Vector3(0.0, 1.85, 0.05), "Bastion C2", "Couple de siège", "Transmission lourde", "Ignore le sable et les débris légers, avec une poussée de contact supérieure.", "#F4B84A", "#FFF1CF", [63, 58, 54, 100, 91, 59], [0.88, 0.80, 0.76, 1.55, 1.55, 0.90, 1.75]),
	_chassis("monowheel", "MONOROUE", "ground", Vector3(0.0, 2.25, 0.00), "Cyclops M1", "Dérive gyroscopique", "Gyro-drift", "La dérive refroidit le réacteur et déclenche une micro-poussée à sa sortie.", "#FFE15B", "#FFF8CF", [91, 86, 90, 45, 47, 84], [1.13, 1.12, 1.14, 0.68, 0.83, 1.12, 0.76]),
	_chassis("orb", "SPHÈRE", "experimental", Vector3(0.0, 1.90, 0.15), "Orb S7", "Inertie omnidirectionnelle", "Rebond inertiel", "Convertit une partie des impacts latéraux en poussée et résiste aux renversements.", "#FF9F43", "#FFF0D8", [86, 80, 76, 82, 94, 73], [1.08, 1.05, 0.98, 1.22, 1.15, 1.02, 1.18]),
	_chassis("centurion", "MYRIAPODE", "command", Vector3(0.0, 2.10, 0.30), "Centurion S12", "Douze appuis synchronisés", "Onde de marche", "Conserve adhérence et motricité sur les débris et sous gravité variable.", "#B8FF5E", "#F0FFD9", [77, 73, 92, 74, 96, 78], [1.01, 0.99, 1.18, 1.10, 1.35, 0.96, 1.16]),
]

const TRACKS: Array[Dictionary] = [
	{
		"id": "foundry", "name": "Fonderie Néon", "region": "NEXUS INDUSTRIEL 7", "difficulty": 2, "base_grip": 1.0, "layout_profile": "industrial_loop", "texture_set": "industrial", "prop_set": "industrial",
		"default_laps": 3, "par_time": 77.0, "seed": 1707, "radius": 92.0, "width": 15.0,
		"verticality": 5.5, "fog_density": 0.014, "description": "Courbes techniques, fours ouverts et transferts magnétiques.",
		"tags": ["TECHNIQUE", "CHALEUR", "3,8 KM"], "hazards": ["vent", "debris"],
		"palette": {"primary": "#FF6A42", "secondary": "#F2C84B", "fog": "#6F3429", "sky": "#130A12", "ground": "#241015", "road": "#201D22", "shoulder": "#752D1F", "glow": "#FF5B31", "accent": "#F2C84B", "key": "#FFB46A"},
	},
	{
		"id": "dunes", "name": "Faille Écarlate", "region": "DÉSERT DE VERMILLON", "difficulty": 3, "base_grip": 0.91, "layout_profile": "speed_bowls", "texture_set": "desert", "prop_set": "desert",
		"default_laps": 3, "par_time": 86.0, "seed": 3229, "radius": 126.0, "width": 18.0,
		"verticality": 13.0, "fog_density": 0.021, "description": "Longues lignes, dunes aveuglantes et ravins à haute vitesse.",
		"tags": ["VITESSE", "SABLE", "5,1 KM"], "hazards": ["sand", "debris"],
		"palette": {"primary": "#F26D3D", "secondary": "#FFD45B", "fog": "#D8693D", "sky": "#3E1518", "ground": "#6E2C1D", "road": "#33221D", "shoulder": "#C6532B", "glow": "#FF7C3D", "accent": "#FFD45B", "key": "#FFE0A3"},
	},
	{
		"id": "glacier", "name": "Arc Polaire", "region": "LUNE CRYO KHEPRI", "difficulty": 4, "base_grip": 0.82, "layout_profile": "technical_ridges", "texture_set": "glacier", "prop_set": "ice",
		"default_laps": 3, "par_time": 81.0, "seed": 4811, "radius": 101.0, "width": 13.5,
		"verticality": 8.0, "fog_density": 0.028, "description": "Épingles sur glace, tunnels bleus et vents latéraux.",
		"tags": ["GLACE", "ÉPINGLES", "4,2 KM"], "hazards": ["ice", "debris"],
		"palette": {"primary": "#65E9FF", "secondary": "#A9F3FF", "fog": "#8CC9DA", "sky": "#061A2B", "ground": "#B9DCE4", "road": "#193544", "shoulder": "#6AAEC2", "glow": "#51E9FF", "accent": "#D8FAFF", "key": "#F4FFFF"},
	},
	{
		"id": "orbital", "name": "Cimetière Orbital", "region": "ANNEAU DE MORRIGAN", "difficulty": 5, "base_grip": 0.88, "layout_profile": "orbital_wave", "texture_set": "orbital", "prop_set": "orbital",
		"default_laps": 3, "par_time": 84.0, "seed": 7709, "radius": 114.0, "width": 12.0,
		"verticality": 22.0, "fog_density": 0.006, "description": "Épaves en apesanteur et virages suspendus au-dessus du vide.",
		"tags": ["EXPERT", "VIDE", "4,7 KM"], "hazards": ["gravity", "debris"],
		"palette": {"primary": "#D85BFF", "secondary": "#40DFFC", "fog": "#191A42", "sky": "#02030D", "ground": "#090B1D", "road": "#15172B", "shoulder": "#3D245C", "glow": "#D85BFF", "accent": "#40DFFC", "key": "#D8EEFF"},
	},
	{
		"id": "canopy", "name": "Canopée d’Azura", "region": "FORÊT-MONDE ELYSIA", "biome": "living_jungle", "difficulty": 3, "base_grip": 0.86, "layout_profile": "jungle_switchback", "texture_set": "jungle", "prop_set": "jungle",
		"default_laps": 3, "par_time": 88.0, "seed": 9203, "radius": 108.0, "width": 14.5,
		"verticality": 16.0, "fog_density": 0.032, "description": "Racines mobiles, boue bioluminescente et raccourcis qui s’ouvrent au rythme de la canopée.",
		"tags": ["TOUT-TERRAIN", "VIVANT", "4,5 KM"], "hazards": ["mud", "spores"], "mechanic": {"id": "living_shortcuts", "name": "Raccourcis vivants"},
		"palette": {"primary": "#54F28B", "secondary": "#C8FF6A", "fog": "#235A48", "sky": "#071D19", "ground": "#173C2C", "road": "#1A2E28", "shoulder": "#3A7A46", "glow": "#52FFB2", "accent": "#D7FF72", "key": "#E5FFD0"},
	},
	{
		"id": "tempest", "name": "Couronne Tempête", "region": "MÉGALOPOLE STRATOS", "biome": "storm_city", "difficulty": 4, "base_grip": 0.90, "layout_profile": "urban_chicane", "texture_set": "wet", "prop_set": "urban",
		"default_laps": 3, "par_time": 83.0, "seed": 11437, "radius": 118.0, "width": 13.0,
		"verticality": 28.0, "fog_density": 0.019, "description": "Toits détrempés, rails aériens et rafales qui déplacent la trajectoire idéale.",
		"tags": ["VERTICAL", "ORAGE", "4,9 KM"], "hazards": ["rain", "crosswind"], "mechanic": {"id": "crosswind_windows", "name": "Fenêtres de vent"},
		"palette": {"primary": "#55B9FF", "secondary": "#F4E85B", "fog": "#53677C", "sky": "#081321", "ground": "#182332", "road": "#202D3A", "shoulder": "#385D79", "glow": "#64D6FF", "accent": "#FFE95C", "key": "#D9F3FF"},
	},
	{
		"id": "abyss", "name": "Tranchée Hadale", "region": "OCÉAN DE NÉRÉIDE", "biome": "abyssal_ocean", "difficulty": 5, "base_grip": 0.84, "layout_profile": "abyss_spiral", "texture_set": "abyss", "prop_set": "abyss",
		"default_laps": 3, "par_time": 91.0, "seed": 15061, "radius": 104.0, "width": 12.5,
		"verticality": 19.0, "fog_density": 0.041, "description": "Tunnels pressurisés, courants latéraux et sas qui alternent adhérence et faible gravité.",
		"tags": ["PRESSION", "COURANTS", "4,4 KM"], "hazards": ["current", "pressure"], "mechanic": {"id": "pressure_tides", "name": "Marées de pression"},
		"palette": {"primary": "#2DE2E6", "secondary": "#7B61FF", "fog": "#12384B", "sky": "#010A14", "ground": "#09212D", "road": "#102D3B", "shoulder": "#174E5F", "glow": "#32F6E8", "accent": "#9A7BFF", "key": "#B9FFF7"},
	},
	{
		"id": "caldera", "name": "Caldeira Zéro", "region": "RÉACTEUR TELLURIQUE IX", "biome": "volcanic_reactor", "difficulty": 5, "base_grip": 0.92, "layout_profile": "volcanic_crown", "texture_set": "volcanic", "prop_set": "volcanic",
		"default_laps": 3, "par_time": 89.0, "seed": 18793, "radius": 121.0, "width": 14.0,
		"verticality": 24.0, "fog_density": 0.024, "description": "Ponts thermiques, coulées de plasma et éruptions cycliques qui redessinent les zones sûres.",
		"tags": ["EXTRÊME", "PLASMA", "5,0 KM"], "hazards": ["lava", "eruption"], "mechanic": {"id": "eruption_cycles", "name": "Cycles d’éruption"},
		"palette": {"primary": "#FF4D32", "secondary": "#FFB12E", "fog": "#713326", "sky": "#160507", "ground": "#35100D", "road": "#241817", "shoulder": "#7C2418", "glow": "#FF3B20", "accent": "#FFC13D", "key": "#FFD7A1"},
	},
]

const ITEMS: Array[Dictionary] = [
	{"id": "ion", "name": "Décharge ion", "short": "ION", "kind": "projectile", "description": "Décharge ciblée contre le rival le plus proche devant."},
	{"id": "emp", "name": "Impulsion EMP", "short": "EMP", "kind": "area", "description": "Perturbe le réacteur et la direction des rivaux proches."},
	{"id": "shield", "name": "Bouclier phase", "short": "BOUCLIER", "kind": "defense", "description": "Absorbe les impacts pendant une durée limitée."},
	{"id": "overdrive", "name": "Cellule Overdrive", "short": "OVERDRIVE", "kind": "mobility", "description": "Refroidit puis surcharge temporairement le réacteur."},
	{"id": "mine", "name": "Charge gravitique", "short": "MINE", "kind": "trap", "description": "Déclenche une charge sur le rival le plus proche derrière."},
	{"id": "repair", "name": "Drone réparateur", "short": "RÉPARATION", "kind": "repair", "description": "Restaure une partie du blindage maximal."},
	{"id": "shockwave", "name": "Onde cinétique", "short": "ONDE", "kind": "area", "description": "Repousse et endommage les machines voisines."},
	{"id": "rail", "name": "Railburst", "short": "RAIL", "kind": "projectile", "description": "Frappe frontale instantanée qui récompense l’alignement."},
]

const PILOTS: Array[Dictionary] = [
	{"id": "vex", "name": "Mara Vex", "callsign": "VEX", "paint": "#FF5E7D", "trait": "aggressive"},
	{"id": "k17", "name": "K-17 Sol", "callsign": "K17", "paint": "#62DBFF", "trait": "technical"},
	{"id": "rook", "name": "Rook Calder", "callsign": "ROOK", "paint": "#FFC45C", "trait": "defensive"},
	{"id": "nyx", "name": "Nyx Amani", "callsign": "NYX", "paint": "#B891FF", "trait": "opportunist"},
	{"id": "tao", "name": "Tao Mercer", "callsign": "TAO", "paint": "#6EFFA7", "trait": "clean_line"},
	{"id": "sable", "name": "Sable-9", "callsign": "SABLE", "paint": "#F0F3F7", "trait": "adaptive"},
	{"id": "brakk", "name": "Brakk Orlov", "callsign": "BRAKK", "paint": "#FF8D4F", "trait": "rammer"},
	{"id": "iris", "name": "Iris Quell", "callsign": "IRIS", "paint": "#FF72D2", "trait": "strategist"},
	{"id": "echo", "name": "Echo Vale", "callsign": "ECHO", "paint": "#5B8CFF", "trait": "drifter"},
]

const DIFFICULTIES: Array[Dictionary] = [
	{"id": "rookie", "name": "Recrue", "speed": 0.90, "skill": 0.48, "aggression": 0.22, "reward": 0.80},
	{"id": "pilot", "name": "Pilote", "speed": 0.99, "skill": 0.69, "aggression": 0.50, "reward": 1.00},
	{"id": "ace", "name": "As", "speed": 1.055, "skill": 0.89, "aggression": 0.82, "reward": 1.30},
]

const UPGRADES: Dictionary = {
	"engine": {"id": "engine", "name": "Moteur vectoriel", "description": "Vitesse de pointe", "per_level": 0.035, "costs": [650, 1150, 1950, 3150]},
	"servos": {"id": "servos", "name": "Servomoteurs", "description": "Direction et accélération", "per_level": 0.045, "costs": [600, 1050, 1800, 2900]},
	"reactor": {"id": "reactor", "name": "Refroidissement", "description": "Surcharge plus durable", "per_level": 0.055, "costs": [700, 1250, 2100, 3300]},
	"armor": {"id": "armor", "name": "Blindage composite", "description": "Résistance et intégrité", "per_level": 0.060, "costs": [600, 1100, 1850, 3000]},
}

const CHAMPIONSHIP_POINTS: Array[int] = [15, 12, 10, 8, 6, 5, 4, 3, 2, 1]
const DEFAULT_PAINTS: Array[String] = ["#5EE7FF", "#FF765E", "#68F29C", "#FFE15B", "#A58CFF", "#F253AD", "#F4F6FB", "#242A35"]
const DIVISIONS: Array[Dictionary] = [
	{"id": "command", "name": "Commandement", "short": "CMD", "description": "Unités polyvalentes capables d’adapter leur plan de course.", "color": "#5EE7FF", "chassis_ids": ["biped", "centurion"]},
	{"id": "stabilized", "name": "Stabilisés", "short": "STB", "description": "Plateformes d’appui qui privilégient cap, relance et contrôle.", "color": "#9B8CFF", "chassis_ids": ["tripod", "quadruped"]},
	{"id": "swarm", "name": "Essaim", "short": "ESM", "description": "Architectures multi-appuis précises sur terrains complexes.", "color": "#68F29C", "chassis_ids": ["hexapod", "octopod"]},
	{"id": "ground", "name": "Sol", "short": "SOL", "description": "Machines mécaniques spécialisées dans le couple et la dérive.", "color": "#F4B84A", "chassis_ids": ["tracked", "monowheel"]},
	{"id": "experimental", "name": "Expérimental", "short": "EXP", "description": "Prototypes à sustentation ou inertie non conventionnelle.", "color": "#4FA9FF", "chassis_ids": ["hover", "orb"]},
]

const MODULE_SLOTS: Array[Dictionary] = [
	{
		"id": "core", "name": "Noyau", "description": "Architecture énergétique principale.", "default_option_id": "core_balanced",
		"options": [
			{"id": "core_balanced", "name": "Noyau Synchrone", "description": "Répartition neutre, fiable dans toutes les divisions.", "cost": 0, "stats": {"speed": 0, "acceleration": 0, "handling": 0, "armor": 0, "stability": 0, "reactor": 0}},
			{"id": "core_overdrive", "name": "Cœur Overdrive", "description": "Davantage de vitesse et de réacteur au prix du blindage.", "cost": 1400, "stats": {"speed": 6, "acceleration": 3, "handling": 0, "armor": -5, "stability": -2, "reactor": 7}},
			{"id": "core_bastion", "name": "Cœur Bastion", "description": "Renforce blindage et stabilité en sacrifiant la pointe.", "cost": 1400, "stats": {"speed": -5, "acceleration": -2, "handling": 0, "armor": 8, "stability": 6, "reactor": 0}},
		],
	},
	{
		"id": "mobility", "name": "Mobilité", "description": "Train de déplacement et contrôle de trajectoire.", "default_option_id": "mobility_vector",
		"options": [
			{"id": "mobility_vector", "name": "Servos Vectoriels", "description": "Configuration polyvalente sans compromis statistique.", "cost": 0, "stats": {"speed": 0, "acceleration": 0, "handling": 0, "armor": 0, "stability": 0, "reactor": 0}},
			{"id": "mobility_sprint", "name": "Articulations Sprint", "description": "Relances explosives et vitesse accrue, stabilité réduite.", "cost": 1200, "stats": {"speed": 3, "acceleration": 8, "handling": 1, "armor": -2, "stability": -5, "reactor": 0}},
			{"id": "mobility_adaptive", "name": "Appuis Adaptatifs", "description": "Braquage et stabilité supérieurs sur les secteurs techniques.", "cost": 1200, "stats": {"speed": -3, "acceleration": 0, "handling": 8, "armor": 0, "stability": 6, "reactor": -2}},
		],
	},
	{
		"id": "utility", "name": "Utilitaire", "description": "Sous-système tactique complémentaire.", "default_option_id": "utility_coolant",
		"options": [
			{"id": "utility_coolant", "name": "Boucle Cryo", "description": "Refroidissement standard et comportement prévisible.", "cost": 0, "stats": {"speed": 0, "acceleration": 0, "handling": 0, "armor": 0, "stability": 0, "reactor": 0}},
			{"id": "utility_aegis", "name": "Plaques Aegis", "description": "Blindage modulaire compact, avec une légère masse additionnelle.", "cost": 1100, "stats": {"speed": -2, "acceleration": -3, "handling": 0, "armor": 7, "stability": 3, "reactor": 0}},
			{"id": "utility_scanner", "name": "Scanner Apex", "description": "Anticipation de ligne et réponse plus précise du châssis.", "cost": 1100, "stats": {"speed": 0, "acceleration": 2, "handling": 6, "armor": -3, "stability": 0, "reactor": 3}},
		],
	},
]

const PERFORMANCE_CLASSES: Array[Dictionary] = [
	{"id": "stock", "name": "Série", "description": "Châssis homologués avec modules standards.", "max_upgrade_level": 0, "module_policy": "defaults_only"},
	{"id": "tuned", "name": "Préparé", "description": "Réglages et modules libres dans une enveloppe contrôlée.", "max_upgrade_level": 2, "module_policy": "all"},
	{"id": "unlimited", "name": "Prototype", "description": "Toutes améliorations et configurations autorisées.", "max_upgrade_level": 4, "module_policy": "all"},
]

const RACE_RULESETS: Array[Dictionary] = [
	{"id": "division_locked", "name": "Division dédiée", "description": "La grille reste dans la division du joueur.", "mixed_divisions": false, "division_policy": "selected", "items_enabled": true, "performance_class_id": "tuned"},
	{"id": "open_mixed", "name": "Open mixte", "description": "Toutes les divisions peuvent partager la grille.", "mixed_divisions": true, "division_policy": "open", "items_enabled": true, "performance_class_id": "tuned"},
	{"id": "elite_open", "name": "Open Prototype", "description": "Grille mixte, puissance illimitée et pression maximale.", "mixed_divisions": true, "division_policy": "open", "items_enabled": true, "performance_class_id": "unlimited"},
]

const CHAMPIONSHIPS: Array[Dictionary] = [
	{"id": "command_cup", "name": "Coupe Commandement", "description": "Série tactique réservée aux unités Commandement.", "division_id": "command", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["foundry", "tempest", "glacier", "orbital"], "mixed_divisions": false},
	{"id": "stabilized_cup", "name": "Coupe Stabilisée", "description": "Quatre manches de précision pour les plateformes Stabilisé.", "division_id": "stabilized", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["dunes", "canopy", "foundry", "abyss"], "mixed_divisions": false},
	{"id": "swarm_cup", "name": "Coupe Essaim", "description": "Terrains complexes réservés aux architectures Essaim.", "division_id": "swarm", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["canopy", "glacier", "abyss", "caldera"], "mixed_divisions": false},
	{"id": "ground_cup", "name": "Coupe Sol", "description": "Couple, impact et dérive pour les spécialistes mécaniques.", "division_id": "ground", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["dunes", "foundry", "caldera", "tempest"], "mixed_divisions": false},
	{"id": "experimental_cup", "name": "Coupe Expérimentale", "description": "Une série à haute énergie pour les prototypes.", "division_id": "experimental", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["orbital", "tempest", "abyss", "caldera"], "mixed_divisions": false},
	{"id": "nexus_open", "name": "Grand Open du Nexus", "description": "Championnat majeur explicitement mixte réunissant les cinq divisions.", "division_id": "", "ruleset_id": "elite_open", "performance_class_id": "unlimited", "track_ids": ["foundry", "dunes", "glacier", "orbital", "canopy", "tempest", "abyss", "caldera"], "mixed_divisions": true},
]


static func get_division(division_id: String) -> Dictionary:
	return _find_by_id(DIVISIONS, division_id)


static func get_module_slot(slot_id: String) -> Dictionary:
	return _find_by_id(MODULE_SLOTS, slot_id)


static func get_module_option(slot_id: String, option_id: String) -> Dictionary:
	var slot: Dictionary = get_module_slot(slot_id)
	for option: Dictionary in slot.get("options", []):
		if String(option.get("id", "")) == option_id:
			return option.duplicate(true)
	return {}


static func get_performance_class(class_id: String) -> Dictionary:
	return _find_by_id(PERFORMANCE_CLASSES, class_id)


static func get_ruleset(ruleset_id: String) -> Dictionary:
	return _find_by_id(RACE_RULESETS, ruleset_id)


static func get_championship(championship_id: String) -> Dictionary:
	return _find_by_id(CHAMPIONSHIPS, championship_id)


static func get_all_divisions() -> Array[Dictionary]:
	return DIVISIONS.duplicate(true)


static func get_all_module_slots() -> Array[Dictionary]:
	return MODULE_SLOTS.duplicate(true)


static func get_all_performance_classes() -> Array[Dictionary]:
	return PERFORMANCE_CLASSES.duplicate(true)


static func get_all_rulesets() -> Array[Dictionary]:
	return RACE_RULESETS.duplicate(true)


static func get_all_championships() -> Array[Dictionary]:
	return CHAMPIONSHIPS.duplicate(true)


static func get_chassis_for_division(division_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for chassis: Dictionary in CHASSIS:
		if String(chassis.get("division_id", "")) == division_id:
			entries.append(chassis.duplicate(true))
	return entries
static func get_chassis(chassis_id: String) -> Dictionary:
	return _find_by_id(CHASSIS, chassis_id)


static func get_track(track_id: String) -> Dictionary:
	return _find_by_id(TRACKS, track_id)


static func get_item(item_id: String) -> Dictionary:
	return _find_by_id(ITEMS, item_id)


static func get_pilot(pilot_id: String) -> Dictionary:
	return _find_by_id(PILOTS, pilot_id)


static func get_difficulty(difficulty_id: String) -> Dictionary:
	return _find_by_id(DIFFICULTIES, difficulty_id)


static func get_upgrade(upgrade_id: String) -> Dictionary:
	var entry: Dictionary = UPGRADES.get(upgrade_id, {})
	return entry.duplicate(true)


static func get_all_chassis() -> Array[Dictionary]:
	return CHASSIS.duplicate(true)


static func get_all_tracks() -> Array[Dictionary]:
	return TRACKS.duplicate(true)


static func get_all_items() -> Array[Dictionary]:
	return ITEMS.duplicate(true)


static func get_all_pilots() -> Array[Dictionary]:
	return PILOTS.duplicate(true)


static func get_all_difficulties() -> Array[Dictionary]:
	return DIFFICULTIES.duplicate(true)


static func has_chassis(chassis_id: String) -> bool:
	return not get_chassis(chassis_id).is_empty()


static func has_track(track_id: String) -> bool:
	return not get_track(track_id).is_empty()


static func has_difficulty(difficulty_id: String) -> bool:
	return not get_difficulty(difficulty_id).is_empty()


static func get_upgrade_ids() -> Array[String]:
	var ids: Array[String] = []
	for upgrade_id: String in UPGRADES.keys():
		ids.append(upgrade_id)
	return ids


static func _find_by_id(entries: Array[Dictionary], requested_id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if String(entry.get("id", "")) == requested_id:
			return entry.duplicate(true)
	return {}


static func _chassis(
	id: String, category: String, division_id: String, cockpit_offset: Vector3, display_name: String, subtitle: String,
	ability: String, ability_description: String, paint: String, accent: String,
	stat_values: Array, physics_values: Array
) -> Dictionary:
	return {
		"id": id, "category": category, "name": display_name, "subtitle": subtitle,
		"division_id": division_id, "cockpit_offset": cockpit_offset,
		"manufacturer": _manufacturer(id), "lore": _lore(id),
		"description": _lore(id), "ability": ability, "ability_description": ability_description,
		"texture_set": "openai_mecha_armor", "default_loadout": _default_loadout_for(id),
		"paint": paint, "accent": accent,
		"stats": {"speed": stat_values[0], "acceleration": stat_values[1], "handling": stat_values[2], "armor": stat_values[3], "stability": stat_values[4], "reactor": stat_values[5]},
		"physics": {"top_speed": physics_values[0], "acceleration": physics_values[1], "handling": physics_values[2], "armor": physics_values[3], "offroad": physics_values[4], "heat": physics_values[5], "mass": physics_values[6]},
	}



static func _manufacturer(chassis_id: String) -> String:
	match chassis_id:
		"biped", "centurion": return "Aster Command Systems"
		"tripod", "quadruped": return "Valkyr Stabilisation"
		"hexapod", "octopod": return "Mantis Collective"
		"tracked", "monowheel": return "Calder Groundworks"
		_: return "Nexus Experimental Lab"


static func _lore(chassis_id: String) -> String:
	match chassis_id:
		"biped": return "Premier châssis homologué du Circuit Zéro, le Raptor reste la référence des pilotes qui changent de ligne au dernier instant."
		"tripod": return "Le Triarch fut conçu pour les plateformes minières orbitales; ses trois appuis lisent les vibrations avant que la piste ne cède."
		"quadruped": return "Fenrir convertit chaque freinage en tension mécanique, puis libère cette énergie dans une relance prédatrice."
		"hexapod": return "Les six jambes du Mantis négocient indépendamment boue, glace et débris, comme un seul calculateur distribué."
		"octopod": return "Arachne protège son pilote dans un noyau central entouré de huit vecteurs d’impact capables d’ouvrir une trajectoire."
		"hover": return "Wraith est un prototype sans contact dont le coussin magnétique transforme les sols hostiles en lignes de vitesse."
		"tracked": return "Bastion descend des engins de siège telluriques; son couple maintient la poussée lorsque le reste de la grille décroche."
		"monowheel": return "Cyclops enferme son pilote dans un gyroscope actif et fait de chaque dérive une réserve d’énergie."
		"orb": return "Orb S7 recompose son inertie autour d’un cœur mobile, absorbant les chocs latéraux pour les restituer en accélération."
		"centurion": return "Les douze appuis synchronisés du Centurion furent créés pour franchir les épaves mouvantes de l’Anneau de Morrigan."
		_: return "Architecture de compétition homologuée par la Nexus Racing Authority."


static func _default_loadout_for(chassis_id: String) -> Dictionary:
	match chassis_id:
		"tripod", "octopod", "tracked": return {"core": "core_bastion", "mobility": "mobility_adaptive", "utility": "utility_aegis"}
		"quadruped", "hover", "monowheel": return {"core": "core_overdrive", "mobility": "mobility_sprint", "utility": "utility_coolant"}
		"hexapod", "centurion": return {"core": "core_balanced", "mobility": "mobility_adaptive", "utility": "utility_scanner"}
		_: return {"core": "core_balanced", "mobility": "mobility_vector", "utility": "utility_scanner"}
