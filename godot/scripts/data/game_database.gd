class_name GameDatabase
extends RefCounted
## Immutable canonical catalogue. Public getters always return deep copies.

static var CHASSIS: Array[Dictionary] = [
	_chassis("biped", "BIPÈDE", "Raptor R2", "Polyvalence tactique", "Gyro-correction", "Réduit de 40 % les pertes de contrôle causées par les impacts.", "#5EE7FF", "#D9FBFF", [74, 75, 78, 64, 72, 74], [1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00]),
	_chassis("tripod", "TRIPODE", "Triarch T3", "Stabilité absolue", "Ancrage vectoriel", "Résiste aux impacts et conserve son cap dans les courbes rapides.", "#9B8CFF", "#EFEAFF", [68, 66, 80, 80, 97, 65], [0.94, 0.91, 1.05, 1.18, 1.04, 0.98, 1.25]),
	_chassis("quadruped", "QUADRUPÈDE", "Fenrir Q4", "Sprint prédateur", "Foulée prédatrice", "Déclenche une reprise temporaire après freinage, impact ou retour en piste.", "#FF765E", "#FFE2D9", [81, 91, 84, 58, 84, 70], [1.05, 1.20, 1.08, 0.91, 1.13, 1.04, 0.90]),
	_chassis("hexapod", "HEXAPODE", "Mantis H6", "Précision arachnéenne", "Pas adaptatifs", "Réduit fortement la pénalité hors-piste et améliore le braquage à basse vitesse.", "#68F29C", "#E2FFEC", [71, 74, 96, 65, 92, 69], [0.97, 1.01, 1.23, 1.01, 1.42, 0.99, 1.05]),
	_chassis("octopod", "OCTOPODE", "Arachne O8", "Forteresse mobile", "Bélier réparti", "Inflige davantage de dégâts de contact et conserve mieux son élan.", "#F253AD", "#FFE1F3", [66, 61, 72, 97, 99, 62], [0.91, 0.84, 0.92, 1.45, 1.16, 0.95, 1.55]),
	_chassis("hover", "AÉROGLISSEUR", "Wraith V0", "Vitesse sans contact", "Coussin magnétique", "Ignore les mines au sol et conserve sa vitesse sur les terrains meubles.", "#4FA9FF", "#DCEEFF", [98, 78, 59, 48, 51, 94], [1.19, 1.04, 0.83, 0.73, 1.30, 1.20, 0.72]),
	_chassis("tracked", "CHENILLES", "Bastion C2", "Couple de siège", "Transmission lourde", "Ignore le sable et les débris légers, avec une poussée de contact supérieure.", "#F4B84A", "#FFF1CF", [63, 58, 54, 100, 91, 59], [0.88, 0.80, 0.76, 1.55, 1.55, 0.90, 1.75]),
	_chassis("monowheel", "MONOROUE", "Cyclops M1", "Dérive gyroscopique", "Gyro-drift", "La dérive refroidit le réacteur et déclenche une micro-poussée à sa sortie.", "#FFE15B", "#FFF8CF", [91, 86, 90, 45, 47, 84], [1.13, 1.12, 1.14, 0.68, 0.83, 1.12, 0.76]),
	_chassis("orb", "SPHÈRE", "Orb S7", "Inertie omnidirectionnelle", "Rebond inertiel", "Convertit une partie des impacts latéraux en poussée et résiste aux renversements.", "#FF9F43", "#FFF0D8", [86, 80, 76, 82, 94, 73], [1.08, 1.05, 0.98, 1.22, 1.15, 1.02, 1.18]),
	_chassis("centurion", "MYRIAPODE", "Centurion S12", "Douze appuis synchronisés", "Onde de marche", "Conserve adhérence et motricité sur les débris et sous gravité variable.", "#B8FF5E", "#F0FFD9", [77, 73, 92, 74, 96, 78], [1.01, 0.99, 1.18, 1.10, 1.35, 0.96, 1.16]),
]

const TRACKS: Array[Dictionary] = [
	{
		"id": "foundry", "name": "Fonderie Néon", "region": "NEXUS INDUSTRIEL 7", "difficulty": 2,
		"default_laps": 3, "par_time": 77.0, "seed": 1707, "radius": 92.0, "width": 15.0,
		"verticality": 5.5, "fog_density": 0.014, "description": "Courbes techniques, fours ouverts et transferts magnétiques.",
		"tags": ["TECHNIQUE", "CHALEUR", "3,8 KM"], "hazards": ["vent", "debris"],
		"palette": {"primary": "#FF6A42", "secondary": "#F2C84B", "fog": "#6F3429", "sky": "#130A12", "ground": "#241015", "road": "#201D22", "shoulder": "#752D1F", "glow": "#FF5B31", "accent": "#F2C84B", "key": "#FFB46A"},
	},
	{
		"id": "dunes", "name": "Faille Écarlate", "region": "DÉSERT DE VERMILLON", "difficulty": 3,
		"default_laps": 3, "par_time": 86.0, "seed": 3229, "radius": 126.0, "width": 18.0,
		"verticality": 13.0, "fog_density": 0.021, "description": "Longues lignes, dunes aveuglantes et ravins à haute vitesse.",
		"tags": ["VITESSE", "SABLE", "5,1 KM"], "hazards": ["sand", "debris"],
		"palette": {"primary": "#F26D3D", "secondary": "#FFD45B", "fog": "#D8693D", "sky": "#3E1518", "ground": "#6E2C1D", "road": "#33221D", "shoulder": "#C6532B", "glow": "#FF7C3D", "accent": "#FFD45B", "key": "#FFE0A3"},
	},
	{
		"id": "glacier", "name": "Arc Polaire", "region": "LUNE CRYO KHEPRI", "difficulty": 4,
		"default_laps": 3, "par_time": 81.0, "seed": 4811, "radius": 101.0, "width": 13.5,
		"verticality": 8.0, "fog_density": 0.028, "description": "Épingles sur glace, tunnels bleus et vents latéraux.",
		"tags": ["GLACE", "ÉPINGLES", "4,2 KM"], "hazards": ["ice", "debris"],
		"palette": {"primary": "#65E9FF", "secondary": "#A9F3FF", "fog": "#8CC9DA", "sky": "#061A2B", "ground": "#B9DCE4", "road": "#193544", "shoulder": "#6AAEC2", "glow": "#51E9FF", "accent": "#D8FAFF", "key": "#F4FFFF"},
	},
	{
		"id": "orbital", "name": "Cimetière Orbital", "region": "ANNEAU DE MORRIGAN", "difficulty": 5,
		"default_laps": 3, "par_time": 84.0, "seed": 7709, "radius": 114.0, "width": 12.0,
		"verticality": 22.0, "fog_density": 0.006, "description": "Épaves en apesanteur et virages suspendus au-dessus du vide.",
		"tags": ["EXPERT", "VIDE", "4,7 KM"], "hazards": ["gravity", "debris"],
		"palette": {"primary": "#D85BFF", "secondary": "#40DFFC", "fog": "#191A42", "sky": "#02030D", "ground": "#090B1D", "road": "#15172B", "shoulder": "#3D245C", "glow": "#D85BFF", "accent": "#40DFFC", "key": "#D8EEFF"},
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
	id: String, category: String, display_name: String, subtitle: String,
	ability: String, ability_description: String, paint: String, accent: String,
	stat_values: Array, physics_values: Array
) -> Dictionary:
	return {
		"id": id, "category": category, "name": display_name, "subtitle": subtitle,
		"description": ability_description, "ability": ability, "ability_description": ability_description,
		"paint": paint, "accent": accent,
		"stats": {"speed": stat_values[0], "acceleration": stat_values[1], "handling": stat_values[2], "armor": stat_values[3], "stability": stat_values[4], "reactor": stat_values[5]},
		"physics": {"top_speed": physics_values[0], "acceleration": physics_values[1], "handling": physics_values[2], "armor": physics_values[3], "offroad": physics_values[4], "heat": physics_values[5], "mass": physics_values[6]},
	}
