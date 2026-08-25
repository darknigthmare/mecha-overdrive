extends RefCounted
class_name LoreDatabase

## Original setting bible exposed by the in-game Codex. These entries keep the
## stakes readable without borrowing names, factions or designs from existing IP.

const ENTRIES: Array[Dictionary] = [
	{
		"id": "grand_tour",
		"title": "LE GRAND TOUR DES HUIT MONDES",
		"epoch": "SAISON 03 // NEXUS GRAND LEAGUE",
		"subtitle": "La même grille, trois galaxies, huit mondes",
		"description": "Les Portes du Nexus transportent paddocks et méchas d’un monde à l’autre en quelques heures. Cinq Coupes révèlent les spécialistes; le Grand Open réunit toutes les architectures sur la tournée complète.",
		"protocol": "CHAMPIONNAT INTERGALACTIQUE",
		"protocol_description": "Chaque position homologuée à l’arrivée rapporte des points. La Couronne récompense la constance sur une saison entière, pas seulement la vitesse sur un tour.",
		"telemetry": "MONDES    8\nGALAXIES  3\nFINALE    CIRCUIT ZERO",
	},
	{
		"id": "circuit_zero",
		"title": "CIRCUIT ZERO",
		"epoch": "CALDEIRA IX // TRACÉ ORIGINEL",
		"subtitle": "La piste qui a donné son nom à la légende",
		"description": "Le premier tracé libre encercle un réacteur tellurique instable. Reconstruit avant chaque saison, il ne s’ouvre que pendant une brève accalmie de plasma et conclut le Grand Open.",
		"protocol": "FINALE DE LA COURONNE",
		"protocol_description": "Adhérence, refroidissement, stabilité et vitesse y sont tous mis à l’épreuve. Aucune architecture n’y possède un avantage permanent.",
		"telemetry": "MANCHE       08 / 08\nDANGER       5 / 5\nFENÊTRE SÛRE 09 MIN",
	},
	{
		"id": "third_crown_clause",
		"title": "LA CLAUSE DE LA TROISIÈME COURONNE",
		"epoch": "CONTRAT MERIDIAN // CONTESTÉ",
		"subtitle": "Le titre qui pourrait fermer la grille",
		"description": "Meridian Apex finance une part décisive de la Ligue. Si Mara Vex obtient un troisième titre consécutif, une option lui accorde le marché exclusif des châssis pour dix cycles.",
		"protocol": "ENJEU DE SAISON",
		"protocol_description": "Battre Vex protège la Charte libre et donne au Hangar 08 un siège au Conseil des constructeurs.",
		"telemetry": "TITRES VEX   2\nSEUIL        3\nGRILLE LIBRE MENACÉE",
	},
	{
		"id": "five_divisions",
		"title": "LES CINQ DIVISIONS",
		"epoch": "CHARTE LIBRE // HOMOLOGATION",
		"subtitle": "Cinq cadres structurels, cinq philosophies de course",
		"description": "Commandement, Stabilisés, Essaim, Sol et Expérimental classent le cadre, la masse et l’enveloppe énergétique du châssis. La locomotion choisie ne change pas sa division.",
		"protocol": "HOMOLOGATION DU CADRE",
		"protocol_description": "Chaque architecture accepte cinquante configurations locomotrices; la classe de performance contrôle la puissance réellement autorisée.",
		"telemetry": "DIVISIONS       5\nARCHITECTURES   10\nCONFIGURATIONS  500",
	},
	{
		"id": "hangar_08",
		"title": "HANGAR 08",
		"epoch": "LICENCE INDÉPENDANTE // DERNIÈRE ACTIVE",
		"subtitle": "Une place, un pilote, cinq cents réponses",
		"description": "Installé dans une ancienne navette-paddock, le Hangar 08 refuse les châssis propriétaires. Son équipage récupère, adapte et homologue chaque pièce pour défendre l’ingénierie ouverte.",
		"protocol": "OBJECTIF PILOTE",
		"protocol_description": "Remporter une Coupe, obtenir l’invitation au Grand Open et ramener la Couronne au dernier paddock indépendant.",
		"telemetry": "BUDGET       LIMITÉ\nPLACE        10 / 10\nDEVISE       AUCUNE FORME UNIQUE",
	},
	{
		"id": "mara_vex",
		"title": "MARA VEX // DOUBLE CHAMPIONNE",
		"epoch": "MERIDIAN APEX // VOITURE 01",
		"subtitle": "La rivale que trois galaxies regardent",
		"description": "Vex pilote avec une précision brutale et transforme chaque contact en avantage. Elle veut gagner assez nettement pour démontrer qu’une technologie unique vaut mieux qu’une grille libre.",
		"protocol": "RIVALE PRINCIPALE",
		"protocol_description": "Elle défend tôt, attaque tard et conserve ses systèmes offensifs pour les derniers secteurs.",
		"telemetry": "COURONNES     2\nTEMPÉRAMENT   AGRESSIF\nOBJECTIF      TROISIÈME TITRE",
	},
	{
		"id": "grid_ten",
		"title": "LA GRILLE DES DIX",
		"epoch": "ROSTER OFFICIEL // SAISON 03",
		"subtitle": "Neuf rivaux et votre place",
		"description": "Vex et Brakk défendent Meridian Apex; Iris et Tao courent pour Argon Vector; K-17 et Rook représentent Free Relay; Nyx et Sable-9 sortent d’Umbra Lab; Echo Vale reste indépendant. Le dixième siège appartient au Hangar 08.",
		"protocol": "RIVALITÉS DYNAMIQUES",
		"protocol_description": "Chaque pilote possède une origine, une équipe, une ligne préférée et un comportement tactique identifiable.",
		"telemetry": "PILOTES      10\nÉCURIES      6\nINDÉPENDANTS 2",
	},
	{
		"id": "season_three",
		"title": "SAISON 03 // LA COURONNE LIBRE",
		"epoch": "TRANSMISSION EN DIRECT",
		"subtitle": "La saison où la grille choisira son avenir",
		"description": "La tournée commence à la Fonderie Néon, traverse Vermillon, Khepri, Morrigan, Elysia, Stratos et Néréide, puis rejoint Circuit Zero sur la Caldeira IX.",
		"protocol": "PRENEZ LA GRILLE",
		"protocol_description": "Choisissez un cadre, bâtissez votre configuration et faites de votre style une signature reconnue dans trois galaxies.",
		"telemetry": "MANCHE       01 / 08\nRIVALE       MARA VEX\nCOURONNE     EN JEU",
	},
]


static func get_all() -> Array[Dictionary]:
	var entries := ENTRIES.duplicate(true)
	var names := division_names()
	for entry: Dictionary in entries:
		if String(entry.get("id", "")) == "five_divisions":
			entry["description"] = "%s classent le cadre, la masse et l’enveloppe énergétique du châssis. La locomotion choisie ne change pas sa division; le Grand Open autorise tous les croisements." % _french_list(names)
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
