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
		"id": "foundry", "name": "Fonderie Néon", "region": "MONDE-FORGE MERIDIAN", "difficulty": 2, "base_grip": 1.0, "layout_profile": "industrial_loop", "texture_set": "industrial", "prop_set": "industrial",
		"default_laps": 3, "par_time": 77.0, "seed": 1707, "radius": 112.0, "width": 36.0,
		"verticality": 5.5, "fog_density": 0.014, "description": "Ouverture du Grand Tour entre fours stellaires, docks-portes et transferts magnétiques.",
		"tags": ["TECHNIQUE", "CHALEUR", "3,8 KM"], "hazards": ["vent", "debris"],
		"palette": {"primary": "#FF6A42", "secondary": "#F2C84B", "fog": "#6F3429", "sky": "#130A12", "ground": "#241015", "road": "#201D22", "shoulder": "#752D1F", "glow": "#FF5B31", "accent": "#F2C84B", "key": "#FFB46A"},
	},
	{
		"id": "dunes", "name": "Faille Écarlate", "region": "PLANÈTE VERMILLON", "difficulty": 3, "base_grip": 0.91, "layout_profile": "speed_bowls", "texture_set": "desert", "prop_set": "desert",
		"default_laps": 3, "par_time": 86.0, "seed": 3229, "radius": 154.0, "width": 42.0,
		"verticality": 13.0, "fog_density": 0.021, "description": "Lignes intercontinentales, dunes aveuglantes et berceau clandestin de Mara Vex.",
		"tags": ["VITESSE", "SABLE", "5,1 KM"], "hazards": ["sand", "debris"],
		"palette": {"primary": "#F26D3D", "secondary": "#FFD45B", "fog": "#D8693D", "sky": "#3E1518", "ground": "#6E2C1D", "road": "#33221D", "shoulder": "#C6532B", "glow": "#FF7C3D", "accent": "#FFD45B", "key": "#FFE0A3"},
	},
	{
		"id": "glacier", "name": "Arc Polaire", "region": "LUNE CRYO KHEPRI", "difficulty": 4, "base_grip": 0.82, "layout_profile": "technical_ridges", "texture_set": "glacier", "prop_set": "ice",
		"default_laps": 3, "par_time": 81.0, "seed": 4811, "radius": 124.0, "width": 35.0,
		"verticality": 8.0, "fog_density": 0.028, "description": "Épingles lissées autour de la première Porte intergalactique stable et vents latéraux.",
		"tags": ["GLACE", "ÉPINGLES", "4,2 KM"], "hazards": ["ice", "debris"],
		"palette": {"primary": "#65E9FF", "secondary": "#A9F3FF", "fog": "#8CC9DA", "sky": "#061A2B", "ground": "#B9DCE4", "road": "#193544", "shoulder": "#6AAEC2", "glow": "#51E9FF", "accent": "#D8FAFF", "key": "#F4FFFF"},
	},
	{
		"id": "orbital", "name": "Cimetière Orbital", "region": "ANNEAU DE MORRIGAN", "difficulty": 5, "base_grip": 0.88, "layout_profile": "orbital_wave", "texture_set": "orbital", "prop_set": "orbital",
		"default_laps": 3, "par_time": 84.0, "seed": 7709, "radius": 142.0, "width": 36.0,
		"verticality": 22.0, "fog_density": 0.006, "description": "Mémorial de trois galaxies, épaves en apesanteur et virages suspendus au-dessus du vide.",
		"tags": ["EXPERT", "VIDE", "4,7 KM"], "hazards": ["gravity", "debris"],
		"palette": {"primary": "#D85BFF", "secondary": "#40DFFC", "fog": "#191A42", "sky": "#02030D", "ground": "#090B1D", "road": "#15172B", "shoulder": "#3D245C", "glow": "#D85BFF", "accent": "#40DFFC", "key": "#D8EEFF"},
	},
	{
		"id": "canopy", "name": "Canopée d’Azura", "region": "FORÊT-MONDE ELYSIA", "biome": "living_jungle", "difficulty": 3, "base_grip": 0.86, "layout_profile": "jungle_switchback", "texture_set": "jungle", "prop_set": "jungle",
		"default_laps": 3, "par_time": 88.0, "seed": 9203, "radius": 134.0, "width": 36.0,
		"verticality": 16.0, "fog_density": 0.032, "description": "Ruban vivant, boue bioluminescente et raccourcis écologiques qui suivent la canopée.",
		"tags": ["TOUT-TERRAIN", "VIVANT", "4,5 KM"], "hazards": ["mud", "spores"], "mechanic": {"id": "living_shortcuts", "name": "Raccourcis vivants"},
		"palette": {"primary": "#54F28B", "secondary": "#C8FF6A", "fog": "#235A48", "sky": "#071D19", "ground": "#173C2C", "road": "#1A2E28", "shoulder": "#3A7A46", "glow": "#52FFB2", "accent": "#D7FF72", "key": "#E5FFD0"},
	},
	{
		"id": "tempest", "name": "Couronne Tempête", "region": "MÉGALOPOLE STRATOS", "biome": "storm_city", "difficulty": 4, "base_grip": 0.90, "layout_profile": "urban_chicane", "texture_set": "wet", "prop_set": "urban",
		"default_laps": 3, "par_time": 83.0, "seed": 11437, "radius": 146.0, "width": 38.0,
		"verticality": 28.0, "fog_density": 0.019, "description": "Capitale médiatique du Tour, toits détrempés et rafales qui déplacent la trajectoire idéale.",
		"tags": ["VERTICAL", "ORAGE", "4,9 KM"], "hazards": ["rain", "crosswind"], "mechanic": {"id": "crosswind_windows", "name": "Fenêtres de vent"},
		"palette": {"primary": "#55B9FF", "secondary": "#F4E85B", "fog": "#53677C", "sky": "#081321", "ground": "#182332", "road": "#202D3A", "shoulder": "#385D79", "glow": "#64D6FF", "accent": "#FFE95C", "key": "#D9F3FF"},
	},
	{
		"id": "abyss", "name": "Tranchée Hadale", "region": "OCÉAN DE NÉRÉIDE", "biome": "abyssal_ocean", "difficulty": 5, "base_grip": 0.84, "layout_profile": "abyss_spiral", "texture_set": "abyss", "prop_set": "abyss",
		"default_laps": 3, "par_time": 91.0, "seed": 15061, "radius": 136.0, "width": 36.0,
		"verticality": 19.0, "fog_density": 0.041, "description": "Avant-dernière escale, tunnels pressurisés et sas qui alternent adhérence et faible gravité.",
		"tags": ["PRESSION", "COURANTS", "4,4 KM"], "hazards": ["current", "pressure"], "mechanic": {"id": "pressure_tides", "name": "Marées de pression"},
		"palette": {"primary": "#2DE2E6", "secondary": "#7B61FF", "fog": "#12384B", "sky": "#010A14", "ground": "#09212D", "road": "#102D3B", "shoulder": "#174E5F", "glow": "#32F6E8", "accent": "#9A7BFF", "key": "#B9FFF7"},
	},
	{
		"id": "caldera", "name": "Circuit Zero", "region": "CALDEIRA IX // TRACÉ ORIGINEL", "biome": "volcanic_reactor", "difficulty": 5, "base_grip": 0.92, "layout_profile": "volcanic_crown", "texture_set": "volcanic", "prop_set": "volcanic",
		"default_laps": 3, "par_time": 89.0, "seed": 18793, "radius": 154.0, "width": 40.0,
		"verticality": 24.0, "fog_density": 0.024, "description": "Finale de la Couronne autour du réacteur tellurique, entre plasma et éruptions cycliques.",
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
	{"id": "vex", "name": "Mara Vex", "callsign": "VEX", "paint": "#FF5E7D", "trait": "aggressive", "team": "Meridian Apex", "origin": "Vermillon", "bio": "Double championne, défense tardive et précision brutale. Elle veut imposer un standard unique à la Ligue."},
	{"id": "k17", "name": "K-17 Sol", "callsign": "K17", "paint": "#62DBFF", "trait": "technical", "team": "Free Relay", "origin": "Khepri", "bio": "Synthétique de navigation devenu pilote, expert des trajectoires cryogéniques."},
	{"id": "rook", "name": "Rook Calder", "callsign": "ROOK", "paint": "#FFC45C", "trait": "defensive", "team": "Free Relay", "origin": "Meridian", "bio": "Vétéran des châssis lourds, il transforme la défense en pression constante."},
	{"id": "nyx", "name": "Nyx Amani", "callsign": "NYX", "paint": "#B891FF", "trait": "opportunist", "team": "Umbra Lab", "origin": "Néréide", "bio": "Ingénieure des champs de phase, toujours prête à exploiter la moindre ouverture."},
	{"id": "tao", "name": "Tao Mercer", "callsign": "TAO", "paint": "#6EFFA7", "trait": "clean_line", "team": "Argon Vector", "origin": "Elysia", "bio": "Spécialiste de la ligne propre et ambassadeur du protocole écologique d’Elysia."},
	{"id": "sable", "name": "Sable-9", "callsign": "SABLE", "paint": "#F0F3F7", "trait": "adaptive", "team": "Umbra Lab", "origin": "Inconnu", "bio": "Pilote masqué dont le style change à chaque monde et défie toute télémétrie."},
	{"id": "brakk", "name": "Brakk Orlov", "callsign": "BRAKK", "paint": "#FF8D4F", "trait": "rammer", "team": "Meridian Apex", "origin": "Caldeira IX", "bio": "Équipier de Vex et spécialiste du contact sur les pistes thermiques."},
	{"id": "iris", "name": "Iris Quell", "callsign": "IRIS", "paint": "#FF72D2", "trait": "strategist", "team": "Argon Vector", "origin": "Stratos", "bio": "Stratège médiatique qui conserve ses systèmes pour les derniers secteurs."},
	{"id": "echo", "name": "Echo Vale", "callsign": "ECHO", "paint": "#5B8CFF", "trait": "drifter", "team": "Indépendant", "origin": "Morrigan", "bio": "Indépendant orbital, il fait de chaque dérive un hommage aux convois disparus."},
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
	{"id": "command", "name": "Commandement", "short": "CMD", "description": "Cadres polyvalents; la locomotion choisie ne change pas leur division.", "color": "#5EE7FF", "chassis_ids": ["biped", "centurion"]},
	{"id": "stabilized", "name": "Stabilisés", "short": "STB", "description": "Cadres d’appui qui privilégient cap, relance et contrôle.", "color": "#9B8CFF", "chassis_ids": ["tripod", "quadruped"]},
	{"id": "swarm", "name": "Essaim", "short": "ESM", "description": "Cadres multi-appuis précis sur terrains complexes.", "color": "#68F29C", "chassis_ids": ["hexapod", "octopod"]},
	{"id": "ground", "name": "Sol", "short": "SOL", "description": "Cadres mécaniques spécialisés dans le couple et la dérive.", "color": "#F4B84A", "chassis_ids": ["tracked", "monowheel"]},
	{"id": "experimental", "name": "Expérimental", "short": "EXP", "description": "Cadres prototypes à sustentation ou inertie non conventionnelle.", "color": "#4FA9FF", "chassis_ids": ["hover", "orb"]},
]

const MODULE_SLOTS: Array[Dictionary] = [
	{
		"id": "core", "name": "Noyau", "description": "Architecture énergétique principale.", "default_option_id": "core_balanced",
		"options": [
			{
				"id": "core_balanced", "name": "Noyau Synchrone", "description": "Répartition neutre, fiable dans toutes les divisions.",
				"cost": 0, "tier": 0, "power_draw": 0,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "core_dual_cell", "texture_set": "module_energy", "manufacturer": "Nexus Standard Works",
				"role": "Équilibre énergétique", "lore": "Le noyau de référence de la Ligue synchronise propulsion, refroidissement et commandes sans privilégier un sous-système.",
				"stats": {"speed": 0, "acceleration": 0, "handling": 0, "armor": 0, "stability": 0, "reactor": 0},
			},
			{
				"id": "core_overdrive", "name": "Cœur Overdrive", "description": "Davantage de vitesse et de réacteur au prix du blindage.",
				"cost": 1400, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "core_twin_reactor", "texture_set": "module_energy", "manufacturer": "Nexus Experimental Lab",
				"role": "Pointe et surcharge", "lore": "Deux chambres couplées libèrent une poussée brutale, au prix de panneaux de protection sacrifiés autour du réacteur.",
				"stats": {"speed": 6, "acceleration": 3, "handling": 0, "armor": -5, "stability": -2, "reactor": 7},
			},
			{
				"id": "core_bastion", "name": "Cœur Bastion", "description": "Renforce blindage et stabilité en sacrifiant la pointe.",
				"cost": 1400, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "core_side_bulwark", "texture_set": "module_energy", "manufacturer": "Calder Groundworks",
				"role": "Protection lourde", "lore": "Issu des engins telluriques Calder, ce cœur enferme ses cellules dans deux caissons capables d'encaisser les contacts de peloton.",
				"stats": {"speed": -5, "acceleration": -2, "handling": 0, "armor": 8, "stability": 6, "reactor": 0},
			},
			{
				"id": "core_tactical_relay", "name": "Relais Tactique", "description": "Répartit les corrections entre les appuis, mais exige une coque plus légère.",
				"cost": 1650, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "stabilized", "experimental"],
				"visual_profile": "core_relay_ring", "texture_set": "module_energy", "manufacturer": "Aster Command Systems",
				"role": "Contrôle coordonné", "lore": "Le relais Aster fusionne la télémétrie des appuis avant de renvoyer une correction commune à toute l'architecture.",
				"stats": {"speed": -2, "acceleration": 0, "handling": 4, "armor": -2, "stability": 3, "reactor": 5},
			},
			{
				"id": "core_hive_capacitor", "name": "Condensateur Ruche", "description": "Des cellules parallèles favorisent relance et intégrité au prix de la précision.",
				"cost": 1750, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["swarm", "ground"],
				"visual_profile": "core_capacitor_cluster", "texture_set": "module_energy", "manufacturer": "Mantis Collective",
				"role": "Relance distribuée", "lore": "Six cellules indépendantes partagent charge et dégâts comme une ruche mécanique qui refuse de perdre toute sa puissance d'un seul coup.",
				"stats": {"speed": -1, "acceleration": 6, "handling": -3, "armor": 4, "stability": -2, "reactor": 3},
			},
			{
				"id": "core_phase_lattice", "name": "Réseau de Phase", "description": "Découple brièvement masse et alimentation pour gagner en pointe, avec une structure très fragile.",
				"cost": 2500, "tier": 2, "power_draw": 3,
				"allowed_divisions": ["experimental", "command"],
				"visual_profile": "core_phase_lattice", "texture_set": "module_energy", "manufacturer": "Nexus Experimental Lab",
				"role": "Découplage de phase", "lore": "Trois anneaux maintiennent le réacteur entre deux états inertiels; la Ligue ne l'autorise qu'en homologation Prototype.",
				"stats": {"speed": 5, "acceleration": 0, "handling": 4, "armor": -6, "stability": -3, "reactor": 6},
			},
		],
	},
	{
		"id": "mobility", "name": "Mobilité", "description": "Train de déplacement et contrôle de trajectoire.", "default_option_id": "mobility_vector",
		"options": [
			{
				"id": "mobility_vector", "name": "Servos Vectoriels", "description": "Configuration polyvalente sans compromis statistique.",
				"cost": 0, "tier": 0, "power_draw": 0,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "mobility_vector_pods", "texture_set": "module_mobility", "manufacturer": "Valkyr Stabilisation",
				"role": "Mobilité polyvalente", "lore": "Ces servos constituent l'interface mécanique commune sur laquelle la Ligue a bâti ses normes de mobilité.",
				"stats": {"speed": 0, "acceleration": 0, "handling": 0, "armor": 0, "stability": 0, "reactor": 0},
			},
			{
				"id": "mobility_sprint", "name": "Articulations Sprint", "description": "Relances explosives et vitesse accrue, stabilité réduite.",
				"cost": 1200, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "mobility_sprint_pistons", "texture_set": "module_mobility", "manufacturer": "Valkyr Stabilisation",
				"role": "Accélération explosive", "lore": "Des accumulateurs tendent les articulations au freinage puis restituent l'énergie dès que le pilote rouvre les gaz.",
				"stats": {"speed": 3, "acceleration": 8, "handling": 1, "armor": -2, "stability": -5, "reactor": 0},
			},
			{
				"id": "mobility_adaptive", "name": "Appuis Adaptatifs", "description": "Braquage et stabilité supérieurs sur les secteurs techniques.",
				"cost": 1200, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "mobility_adaptive_skids", "texture_set": "module_mobility", "manufacturer": "Mantis Collective",
				"role": "Terrain technique", "lore": "Chaque patin lit le relief séparément et transmet sa réponse au calculateur central avant le prochain contact.",
				"stats": {"speed": -3, "acceleration": 0, "handling": 8, "armor": 0, "stability": 6, "reactor": -2},
			},
			{
				"id": "mobility_gyro_rail", "name": "Rail Gyrovectoriel", "description": "Deux volants inertiels stabilisent la dérive, avec une relance plus lente.",
				"cost": 1550, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "ground", "experimental"],
				"visual_profile": "mobility_gyro_flywheels", "texture_set": "module_mobility", "manufacturer": "Calder Groundworks",
				"role": "Dérive contrôlée", "lore": "Les volants Calder déplacent leur inertie d'un flanc à l'autre pour tenir une ligne que la masse devrait rendre impossible.",
				"stats": {"speed": 2, "acceleration": -2, "handling": 6, "armor": -2, "stability": 5, "reactor": -1},
			},
			{
				"id": "mobility_multileg", "name": "Train Multi-appuis", "description": "Des appuis supplémentaires sécurisent les secteurs accidentés au détriment de la pointe.",
				"cost": 1650, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["stabilized", "swarm"],
				"visual_profile": "mobility_multileg_outriggers", "texture_set": "module_mobility", "manufacturer": "Mantis Collective",
				"role": "Motricité distribuée", "lore": "Des jambes auxiliaires se déploient uniquement sous charge, transformant chaque irrégularité en point de poussée supplémentaire.",
				"stats": {"speed": -4, "acceleration": 4, "handling": 5, "armor": 0, "stability": 5, "reactor": -2},
			},
			{
				"id": "mobility_phase_skates", "name": "Patins de Phase", "description": "Une poussée sans contact extrêmement vive devient instable sous les impacts.",
				"cost": 2350, "tier": 2, "power_draw": 3,
				"allowed_divisions": ["experimental", "stabilized"],
				"visual_profile": "mobility_phase_skates", "texture_set": "module_mobility", "manufacturer": "Nexus Experimental Lab",
				"role": "Mobilité sans contact", "lore": "Quatre patins maintiennent une pellicule de phase sous le châssis; un choc mal absorbé peut décaler tout le champ porteur.",
				"stats": {"speed": 6, "acceleration": 6, "handling": 3, "armor": -3, "stability": -7, "reactor": -2},
			},
		],
	},
	{
		"id": "utility", "name": "Utilitaire", "description": "Sous-système tactique complémentaire.", "default_option_id": "utility_coolant",
		"options": [
			{
				"id": "utility_coolant", "name": "Boucle Cryo", "description": "Refroidissement standard et comportement prévisible.",
				"cost": 0, "tier": 0, "power_draw": 0,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "utility_cryo_fins", "texture_set": "module_utility", "manufacturer": "Nexus Standard Works",
				"role": "Refroidissement standard", "lore": "La boucle Cryo maintient la température réglementaire sans modifier le comportement prévu par le constructeur.",
				"stats": {"speed": 0, "acceleration": 0, "handling": 0, "armor": 0, "stability": 0, "reactor": 0},
			},
			{
				"id": "utility_aegis", "name": "Plaques Aegis", "description": "Blindage modulaire compact, avec une légère masse additionnelle.",
				"cost": 1100, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "utility_shield_rings", "texture_set": "module_utility", "manufacturer": "Calder Groundworks",
				"role": "Défense modulaire", "lore": "Les plaques segmentées dévient l'énergie des contacts vers deux anneaux sacrificiels remplaçables entre les manches.",
				"stats": {"speed": -2, "acceleration": -3, "handling": 0, "armor": 7, "stability": 3, "reactor": 0},
			},
			{
				"id": "utility_scanner", "name": "Scanner Apex", "description": "Anticipation de ligne et réponse plus précise du châssis.",
				"cost": 1100, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "stabilized", "swarm", "ground", "experimental"],
				"visual_profile": "utility_scanner_mast", "texture_set": "module_utility", "manufacturer": "Aster Command Systems",
				"role": "Lecture de trajectoire", "lore": "Apex compare relief, trafic et chaleur de piste pour proposer une correction avant même que le pilote ne voie le danger.",
				"stats": {"speed": 0, "acceleration": 2, "handling": 6, "armor": -3, "stability": 0, "reactor": 3},
			},
			{
				"id": "utility_command_uplink", "name": "Liaison Stratège", "description": "Fusionne télémétrie et trajectoire au prix d'une protection réduite.",
				"cost": 1350, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["command", "stabilized", "experimental"],
				"visual_profile": "utility_uplink_array", "texture_set": "module_utility", "manufacturer": "Aster Command Systems",
				"role": "Coordination tactique", "lore": "La liaison Stratège transforme les balises de la piste et les signatures rivales en une carte prédictive constamment révisée.",
				"stats": {"speed": 0, "acceleration": 0, "handling": 3, "armor": -3, "stability": 3, "reactor": 3},
			},
			{
				"id": "utility_impact_ram", "name": "Éperon Inertiel", "description": "Absorbe et restitue les contacts, mais alourdit le braquage.",
				"cost": 1450, "tier": 1, "power_draw": 2,
				"allowed_divisions": ["swarm", "ground"],
				"visual_profile": "utility_impact_ram", "texture_set": "module_utility", "manufacturer": "Calder Groundworks",
				"role": "Contact offensif", "lore": "Son ossature accumule une fraction de l'impact frontal avant de la rendre à la transmission lors de la relance.",
				"stats": {"speed": -1, "acceleration": 3, "handling": -4, "armor": 5, "stability": 4, "reactor": -2},
			},
			{
				"id": "utility_phase_sink", "name": "Dissipateur de Phase", "description": "Une dissipation réacteur extrême rend le comportement latéral plus nerveux.",
				"cost": 2200, "tier": 2, "power_draw": 3,
				"allowed_divisions": ["experimental", "swarm"],
				"visual_profile": "utility_phase_sink_petals", "texture_set": "module_utility", "manufacturer": "Nexus Experimental Lab",
				"role": "Dissipation extrême", "lore": "Ses pétales rejettent la chaleur dans une couche de phase instable qui se referme derrière le mécha comme une traînée lumineuse.",
				"stats": {"speed": 2, "acceleration": -3, "handling": -2, "armor": 3, "stability": -4, "reactor": 8},
			},
		],
	},
]

const PERFORMANCE_CLASSES: Array[Dictionary] = [
	{"id": "stock", "name": "Série", "description": "Châssis homologués avec modules standards.", "max_upgrade_level": 0, "max_module_tier": 0, "module_power_budget": 0, "module_policy": "defaults_only"},
	{"id": "tuned", "name": "Préparé", "description": "Réglages et modules libres dans une enveloppe contrôlée.", "max_upgrade_level": 2, "max_module_tier": 1, "module_power_budget": 6, "module_policy": "all"},
	{"id": "unlimited", "name": "Prototype", "description": "Toutes améliorations et configurations autorisées.", "max_upgrade_level": 4, "max_module_tier": 2, "module_power_budget": 9, "module_policy": "all"},
]

const RACE_RULESETS: Array[Dictionary] = [
	{"id": "division_locked", "name": "Division dédiée", "description": "La grille reste dans la division du joueur.", "mixed_divisions": false, "division_policy": "selected", "items_enabled": true, "performance_class_id": "tuned"},
	{"id": "open_mixed", "name": "Open mixte", "description": "Toutes les divisions peuvent partager la grille.", "mixed_divisions": true, "division_policy": "open", "items_enabled": true, "performance_class_id": "tuned"},
	{"id": "elite_open", "name": "Open Prototype", "description": "Grille mixte, puissance illimitée et pression maximale.", "mixed_divisions": true, "division_policy": "open", "items_enabled": true, "performance_class_id": "unlimited"},
]

const CHAMPIONSHIPS: Array[Dictionary] = [
	{"id": "command_cup", "name": "Coupe Commandement", "description": "Série tactique réservée aux unités Commandement.", "division_id": "command", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["foundry", "tempest", "glacier", "orbital"], "mixed_divisions": false},
	{"id": "stabilized_cup", "name": "Coupe Stabilisée", "description": "Quatre manches de précision pour les plateformes Stabilisé.", "division_id": "stabilized", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["dunes", "canopy", "foundry", "abyss"], "mixed_divisions": false},
	{"id": "swarm_cup", "name": "Coupe Essaim", "description": "Terrains complexes réservés aux architectures Essaim.", "division_id": "swarm", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["canopy", "glacier", "abyss", "orbital"], "mixed_divisions": false},
	{"id": "ground_cup", "name": "Coupe Sol", "description": "Couple, impact et dérive pour les spécialistes mécaniques.", "division_id": "ground", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["dunes", "foundry", "tempest", "abyss"], "mixed_divisions": false},
	{"id": "experimental_cup", "name": "Coupe Expérimentale", "description": "Une série à haute énergie pour les prototypes.", "division_id": "experimental", "ruleset_id": "division_locked", "performance_class_id": "tuned", "track_ids": ["orbital", "tempest", "abyss", "glacier"], "mixed_divisions": false},
	{
		"id": "nexus_open",
		"name": "Grand Open des Huit Mondes",
		"description": "Tournée intergalactique mixte; Circuit Zero conclut les huit manches.",
		"division_id": "",
		"ruleset_id": "elite_open",
		"performance_class_id": "unlimited",
		"track_ids": ["foundry", "dunes", "glacier", "orbital", "canopy", "tempest", "abyss", "caldera"],
		"mixed_divisions": true,
		"unlock_requirement": {
			"stat": "championships",
			"minimum": 1,
			"locked_badge": "VERROUILLÉ",
			"resume_badge": "REPRISE",
			"locked_label": "GRAND OPEN VERROUILLÉ",
			"locked_tooltip": "Remportez au moins une Coupe de division pour obtenir l’invitation au Grand Open.",
			"locked_status": "SAISON 03 // GRAND OPEN VERROUILLÉ • REMPORTEZ UNE COUPE DE DIVISION",
			"unlocked_tooltip": "Invitation obtenue : démarrez le Grand Open mixte sur huit mondes.",
			"unlocked_status": "SAISON 03 // INVITATION ACQUISE • LE GRAND OPEN VOUS ATTEND",
		},
	},
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

static func championship_access(championship_id: String, stats: Dictionary = {}, active_championship: Dictionary = {}) -> Dictionary:
	var definition := get_championship(championship_id)
	if definition.is_empty():
		return {
			"available": false,
			"unlocked": false,
			"resume": false,
			"current": 0,
			"minimum": 0,
		}
	var requirement_value: Variant = definition.get("unlock_requirement", {})
	var requirement: Dictionary = Dictionary(requirement_value).duplicate(true) if requirement_value is Dictionary else {}
	var stat_id := String(requirement.get("stat", ""))
	var minimum := maxi(0, int(requirement.get("minimum", 0)))
	var current := minimum if stat_id.is_empty() else maxi(0, int(stats.get(stat_id, 0)))
	var active_id := String(active_championship.get("championship_id", active_championship.get("cup_id", "")))
	var resume_active := bool(active_championship.get("active", false)) and active_id == championship_id
	var naturally_unlocked := requirement.is_empty() or stat_id.is_empty() or current >= minimum
	return {
		"available": naturally_unlocked or resume_active,
		"unlocked": naturally_unlocked,
		"resume": resume_active,
		"current": current,
		"minimum": minimum,
		"locked_badge": String(requirement.get("locked_badge", "VERROUILLÉ")),
		"resume_badge": String(requirement.get("resume_badge", "REPRISE")),
		"locked_label": String(requirement.get("locked_label", "CHAMPIONNAT VERROUILLÉ")),
		"locked_tooltip": String(requirement.get("locked_tooltip", "Remportez une Coupe de division pour déverrouiller ce championnat.")),
		"locked_status": String(requirement.get("locked_status", "CHAMPIONNAT VERROUILLÉ")),
		"unlocked_tooltip": String(requirement.get("unlocked_tooltip", definition.get("description", "Championnat disponible."))),
		"unlocked_status": String(requirement.get("unlocked_status", "CHAMPIONNAT DISPONIBLE")),
	}



static func get_all_divisions() -> Array[Dictionary]:
	return DIVISIONS.duplicate(true)


static func get_all_module_slots() -> Array[Dictionary]:
	return MODULE_SLOTS.duplicate(true)


static func get_all_module_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for slot: Dictionary in MODULE_SLOTS:
		for option: Dictionary in slot.get("options", []):
			options.append(option.duplicate(true))
	return options


static func get_module_count() -> int:
	var count := 0
	for slot: Dictionary in MODULE_SLOTS:
		count += Array(slot.get("options", [])).size()
	return count


static func calculate_module_totals(loadout: Dictionary) -> Dictionary:
	var totals: Dictionary = {
		"speed": 0,
		"acceleration": 0,
		"handling": 0,
		"armor": 0,
		"stability": 0,
		"reactor": 0,
	}
	for slot: Dictionary in MODULE_SLOTS:
		var slot_id := String(slot.get("id", ""))
		var option_id := String(loadout.get(slot_id, ""))
		var option := get_module_option(slot_id, option_id)
		if option.is_empty():
			continue
		var stats: Dictionary = option.get("stats", {}) if option.get("stats", {}) is Dictionary else {}
		for stat_id: String in totals.keys():
			totals[stat_id] = int(totals[stat_id]) + int(stats.get(stat_id, 0))
	return totals


static func is_module_allowed_for_division(module_id: String, division_id: String) -> bool:
	if get_division(division_id).is_empty():
		return false
	for option: Dictionary in get_all_module_options():
		if String(option.get("id", "")) != module_id:
			continue
		var allowed_divisions: Array = option.get("allowed_divisions", [])
		return division_id in allowed_divisions
	return false


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
		_: return "Architecture de compétition homologuée par la Nexus Grand League."


static func _default_loadout_for(chassis_id: String) -> Dictionary:
	match chassis_id:
		"tripod", "octopod", "tracked": return {"core": "core_bastion", "mobility": "mobility_adaptive", "utility": "utility_aegis"}
		"quadruped", "hover", "monowheel": return {"core": "core_overdrive", "mobility": "mobility_sprint", "utility": "utility_coolant"}
		"hexapod", "centurion": return {"core": "core_balanced", "mobility": "mobility_adaptive", "utility": "utility_scanner"}
		_: return {"core": "core_balanced", "mobility": "mobility_vector", "utility": "utility_scanner"}
