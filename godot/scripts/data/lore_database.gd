extends RefCounted
class_name LoreDatabase

## Original setting bible exposed by the in-game Codex. These entries keep the
## stakes readable without borrowing names, factions or designs from existing IP.

const ENTRIES: Array[Dictionary] = [
	{
		"id": "corridor_collapse",
		"title": "LE SILENCE DES CORRIDORS",
		"epoch": "2089 // ARCHIVE FONDATRICE",
		"subtitle": "Quand les routes énergétiques du Nexus se sont tues",
		"description": "La Rupture a désaccordé les corridors qui alimentaient les cités-frontières. Des millions d’habitants ont survécu grâce à Circuit Zero, un anneau technique capable de réveiller brièvement les lignes mortes.",
		"protocol": "ENJEU CIVIL",
		"protocol_description": "Chaque saison distribue des quotas de transit, de réparation et d’énergie aux communautés représentées par les écuries.",
		"telemetry": "STATUT  RECONSTRUCTION\nRISQUE   EFFONDREMENT DE PHASE\nMANDAT   ROUVRIR LE NEXUS",
	},
	{
		"id": "circuit_zero",
		"title": "CIRCUIT ZERO",
		"epoch": "2096 // PREMIÈRE SYNCHRONISATION",
		"subtitle": "Un championnat qui remet le monde en mouvement",
		"description": "Les noyaux des méchas produisent une signature de résonance unique. Huit signatures lancées à vitesse de course peuvent réaligner un corridor mieux que n’importe quel réacteur statique.",
		"protocol": "LA COURSE EST LE RITUEL",
		"protocol_description": "Tours, dépassements et impacts sont convertis en impulsions contrôlées. Gagner apporte la gloire; terminer contribue déjà à la reconstruction.",
		"telemetry": "GRILLE   8 PILOTES\nFORMAT   5 DIVISIONS + OPEN\nRÉSEAU   8 CIRCUITS ACTIFS",
	},
	{
		"id": "nexus_authority",
		"title": "NEXUS RACING AUTHORITY",
		"epoch": "LICENCE NRA-CZ // ACTIVE",
		"subtitle": "Sport, sécurité et arbitrage du réseau",
		"description": "La NRA homologue les châssis, limite les armes de course et protège les zones habitées. Ses commissaires publient les grilles fermées par division et les rares épreuves Open.",
		"protocol": "COURSE RESPONSABLE",
		"protocol_description": "Blindages sacrificiels, décharges plafonnées et récupération automatique rendent la compétition spectaculaire sans la transformer en guerre.",
		"telemetry": "ARBITRAGE   TEMPS RÉEL\nSECOURS     DRONES AEGIS\nSANCTION    DISQUALIFICATION",
	},
	{
		"id": "five_divisions",
		"title": "LES CINQ DIVISIONS",
		"epoch": "ACCORD DE CONVERGENCE // 2101",
		"subtitle": "Des architectures comparables, des identités intactes",
		"description": "Commandement, Stabilisés, Essaim, Sol et Expérimental regroupent des locomotions aux performances comparables. Les coupes dédiées garantissent une rivalité lisible; le Grand Open autorise tous les croisements.",
		"protocol": "HOMOLOGATION MODULAIRE",
		"protocol_description": "Chaque architecture accepte cinquante configurations locomotrices et des modules de noyau, mobilité et utilité, sous contrôle de masse et de puissance.",
		"telemetry": "DIVISIONS       5\nARCHITECTURES   10\nCONFIGURATIONS  500",
	},
	{
		"id": "hangar_08",
		"title": "HANGAR 08",
		"epoch": "DOSSIER PILOTE // AUTORISATION PROVISOIRE",
		"subtitle": "Votre atelier, votre équipage, votre signature",
		"description": "Ancienne station de maintenance sauvée de la Rupture, le Hangar 08 engage un pilote indépendant. Ses mécaniciens reconstruisent des unités abandonnées et refusent de céder leurs quotas aux conglomérats.",
		"protocol": "OBJECTIF DE SAISON",
		"protocol_description": "Remporter une coupe de division, qualifier trois architectures et obtenir une place au Grand Open du Nexus.",
		"telemetry": "BUDGET     LIMITÉ\nRÉPUTATION EN HAUSSE\nDEVISE     PERSONNE NE RESTE IMMOBILE",
	},
	{
		"id": "aether_twin_drive",
		"title": "BI-PROPULSEUR AETHER",
		"epoch": "BREVET H08-AE // HOMOLOGUÉ",
		"subtitle": "Deux nacelles, un lien d’énergie, aucune roue",
		"description": "Deux propulseurs antigravité indépendants tirent un cockpit central par un champ Aether souple. Le pilote équilibre la poussée différentielle comme un funambule lancé à pleine vitesse.",
		"protocol": "CONCEPTION ORIGINALE",
		"protocol_description": "Silhouette, vocabulaire et technologie appartiennent à l’univers de MECHA OVERDRIVE; l’ensemble ne reprend aucun véhicule ou emblème sous licence tierce.",
		"telemetry": "APPUI      ANTIGRAVITÉ\nCONTRÔLE   POUSSÉE DIFFÉRENTIELLE\nCLASSE     PROTOTYPE",
	},
	{
		"id": "rival_stables",
		"title": "LES ÉCURIES DU NEXUS",
		"epoch": "SAISON 03 // GRILLE OFFICIELLE",
		"subtitle": "Alliés sur le réseau, rivaux sous les projecteurs",
		"description": "Les Sentinelles d’Argon privilégient la précision, Kestrel Forge la vitesse brute, Verdant Relay la survie des colonies et le Collectif Umbra les prototypes interdits de la première Rupture.",
		"protocol": "RIVALITÉS DYNAMIQUES",
		"protocol_description": "Les profils IA défendent leur ligne, mémorisent les contacts et adaptent leurs objets à la position, au danger et à leur tempérament.",
		"telemetry": "ÉCURIES MAJEURES  4\nPILOTES LICENCIÉS  16\nTENSION MÉDIATIQUE  ÉLEVÉE",
	},
	{
		"id": "season_three",
		"title": "SAISON 03 // RECONQUÊTE",
		"epoch": "TRANSMISSION EN DIRECT",
		"subtitle": "Le dernier corridor stable mène au cœur de la Rupture",
		"description": "Circuit Zero diffuse une route inconnue à chaque arrivée. Le podium final déterminera qui conduira l’expédition et quelle population recevra la première arche de transit reconstruite.",
		"protocol": "PRENEZ LA GRILLE",
		"protocol_description": "Choisissez une division, adaptez votre locomotion au circuit et bâtissez une réputation capable de survivre au Grand Open.",
		"telemetry": "SIGNAL      97 %\nDESTINATION INCONNUE\nDÉPART      IMMINENT",
	},
]


static func get_all() -> Array[Dictionary]:
	var entries := ENTRIES.duplicate(true)
	var names := division_names()
	for entry: Dictionary in entries:
		if String(entry.get("id", "")) == "five_divisions":
			entry["description"] = "%s regroupent des locomotions aux performances comparables. Les coupes dédiées garantissent une rivalité lisible; le Grand Open autorise tous les croisements." % _french_list(names)
			entry["telemetry"] = "DIVISIONS       %d\nARCHITECTURES   10\nCONFIGURATIONS  500" % names.size()
	return entries


static func division_names() -> Array[String]:
	var names: Array[String] = []
	for division: Dictionary in GameDatabase.DIVISIONS:
		names.append(String(division.get("name", "")))
	return names


static func _french_list(values: Array[String]) -> String:
	if values.is_empty():
		return ""
	if values.size() == 1:
		return values[0]
	return ", ".join(PackedStringArray(values.slice(0, values.size() - 1))) + " et " + values[-1]
