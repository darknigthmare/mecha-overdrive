class_name RaceBroadcast
extends RefCounted

## Targeted race-day copy used by the start grid, announcer and finish show.
## Keeping it outside GameDatabase prevents presentation lore from changing
## simulation contracts or save migrations.

const TRACK_LORE := {
	"foundry": "La Fonderie 7 a forgé les premières armatures civiles du Nexus. Aujourd’hui, ses fours servent de juges de paix aux pilotes.",
	"dunes": "La Faille Écarlate suit une ancienne route d’extraction. Les balises rouges marquent encore les convois disparus sous Vermillon.",
	"glacier": "Sur Khepri, chaque virage est taillé dans une glace plus ancienne que les colonies humaines du secteur.",
	"orbital": "L’anneau de Morrigan est un mémorial autant qu’un circuit : dépasser une épave, c’est saluer son équipage.",
	"canopy": "La Canopée d’Azura tolère la course tant que les réacteurs respectent le rythme lumineux de la forêt-monde.",
	"tempest": "Stratos a bâti sa couronne sportive au-dessus des nuages, là où les rafales départagent les pilotes des calculateurs.",
	"abyss": "La Tranchée Hadale fut ouverte par les cartographes de Néréide. Ses sas de pression sont devenus la frontière ultime du contrôle.",
	"caldera": "Le Réacteur IX alimente trois colonies. La course n’y est autorisée qu’entre deux cycles d’éruption surveillés par le Nexus.",
}

const ANNOUNCER_OPENERS := {
	"quick": "Contrôle course à toutes les unités : grille scellée, télémétrie en direct.",
	"time_trial": "Canal chrono ouvert. Une machine, une trajectoire, aucune excuse.",
	"elimination": "Alerte élimination : à chaque seuil, la dernière signature quittera la grille.",
	"grand_prix": "Transmission championnat : chaque position comptera jusqu’au dernier tour.",
}


static func briefing(config: Dictionary) -> Dictionary:
	var track_id := String(config.get("track_id", config.get("track", "foundry")))
	var track := GameDatabase.get_track(track_id)
	var mode := String(config.get("mode", "quick"))
	var ruleset_id := String(config.get("ruleset_id", "division_locked"))
	var ruleset := GameDatabase.get_ruleset(ruleset_id)
	var performance := GameDatabase.get_performance_class(String(config.get("performance_class_id", ruleset.get("performance_class_id", "tuned"))))
	var laps := maxi(1, int(config.get("laps", track.get("default_laps", 3))))
	var entrants := maxi(1, int(config.get("racer_count", 8)))
	var mechanic: Variant = track.get("mechanic", {})
	var mechanic_name := "AUCUNE VARIABLE DE SECTEUR"
	if mechanic is Dictionary and not Dictionary(mechanic).is_empty():
		mechanic_name = String(Dictionary(mechanic).get("name", "VARIABLE DE SECTEUR")).to_upper()
	var tags: Array = track.get("tags", [])
	var tag_line := "  /  ".join(PackedStringArray(tags)) if not tags.is_empty() else "CIRCUIT HOMOLOGUÉ"
	var conditions := "%s  //  %s" % [tag_line, mechanic_name]
	var homologation_notice := String(config.get("homologation_notice", "")).strip_edges()
	if not homologation_notice.is_empty():
		conditions += "\n%s" % homologation_notice
	return {
		"eyebrow": "NEXUS RACING NETWORK // GRILLE OFFICIELLE",
		"track_name": String(track.get("name", track_id)).to_upper(),
		"region": String(track.get("region", "SECTEUR NEXUS")).to_upper(),
		"session": "%s  //  %d TOURS  //  %02d PARTANTS" % [_mode_name(mode), laps, entrants],
		"rules": "%s  //  CLASSE %s" % [String(ruleset.get("name", ruleset_id)).to_upper(), String(performance.get("name", "TUNED")).to_upper()],
		"rules_detail": String(ruleset.get("description", "Règlement standard du Nexus.")),
		"objective": _objective(mode),
		"announcer": String(ANNOUNCER_OPENERS.get(mode, ANNOUNCER_OPENERS["quick"])),
		"lore": String(TRACK_LORE.get(track_id, track.get("description", "Circuit homologué par le Nexus."))),
		"conditions": conditions,
	}


static func finish_call(result: Dictionary) -> Dictionary:
	var dnf := bool(result.get("dnf", result.get("eliminated", false)))
	var position := maxi(1, int(result.get("position", 1)))
	var mode := String(result.get("mode", "quick"))
	var new_record := bool(result.get("new_record", result.get("record", false)))
	var track_id := String(result.get("track_id", "foundry"))
	var track := GameDatabase.get_track(track_id)
	var title := "COURSE INTERROMPUE"
	var callout := "La direction de course conserve la télémétrie pour expertise."
	if not dnf:
		if mode == "time_trial":
			title = "NOUVEAU RECORD" if new_record else "CHRONO HOMOLOGUÉ"
			callout = "Le Nexus valide une nouvelle référence chronométrique !" if new_record else "Chrono validé : la télémétrie rejoint les archives officielles."
		else:
			title = "VICTOIRE AU NEXUS" if position == 1 else "ARRIVÉE HOMOLOGUÉE"
			callout = "Le drapeau tombe : victoire et nouvelle référence de grille !" if position == 1 else "Drapeau à damier : %s place validée par le contrôle course." % _ordinal(position)
	return {
		"title": title,
		"position": "DNF" if dnf else ("RECORD" if mode == "time_trial" and new_record else ("CHRONO VALIDÉ" if mode == "time_trial" else "%s / %02d" % [_ordinal(position), maxi(1, int(result.get("total_racers", result.get("racer_count", 8))))])),
		"callout": callout,
		"venue": "%s // %s" % [String(track.get("name", track_id)).to_upper(), String(track.get("region", "NEXUS")).to_upper()],
	}


static func _mode_name(mode: String) -> String:
	match mode:
		"time_trial": return "CONTRE-LA-MONTRE"
		"elimination": return "ÉLIMINATION"
		"grand_prix": return "GRAND PRIX"
		_: return "COURSE RAPIDE"


static func _objective(mode: String) -> String:
	match mode:
		"time_trial": return "OBJECTIF // BATTRE LE TEMPS DE RÉFÉRENCE"
		"elimination": return "OBJECTIF // SURVIVRE À CHAQUE SEUIL"
		"grand_prix": return "OBJECTIF // MARQUER DES POINTS DE CHAMPIONNAT"
		_: return "OBJECTIF // FRANCHIR LA LIGNE EN TÊTE"


static func _ordinal(value: int) -> String:
	return "1RE" if value == 1 else "%dE" % maxi(1, value)
