class_name RaceBroadcast
extends RefCounted

## Targeted race-day copy used by the start grid, announcer and finish show.
## Keeping it outside GameDatabase prevents presentation lore from changing
## simulation contracts or save migrations.

const TRACK_LORE := {
	"foundry": "Les docks-portes de Meridian relient la piste aux ateliers où chaque mécha reçoit son sceau intergalactique.",
	"dunes": "Vermillon a révélé Mara Vex dans ses ligues clandestines. La Faille réclame toujours le même courage à pleine vitesse.",
	"glacier": "L’Arc Polaire entoure la première Porte stable entre trois galaxies; K-17 y lit la glace comme une carte stellaire.",
	"orbital": "Morrigan est un mémorial autant qu’un circuit. Echo Vale dérive entre les épaves pour saluer les convois disparus.",
	"canopy": "Elysia n’autorise la course que si les réacteurs respectent le rythme lumineux de sa forêt-monde vivante.",
	"tempest": "Stratos diffuse la Ligue à travers trois galaxies; ses rafales départagent les pilotes des simples calculateurs.",
	"abyss": "Les sas de pression de Néréide font céder les configurations fragilisées et récompensent les trajectoires disciplinées.",
	"caldera": "Circuit Zero est le tracé originel de la Caldeira IX. Sa fenêtre de plasma a décidé plus d’une Couronne.",
}

const ANNOUNCER_OPENERS := {
	"quick": "Contrôle course à toutes les unités : grille scellée, télémétrie en direct.",
	"time_trial": "Canal chrono ouvert. Une machine, une trajectoire, aucune excuse.",
	"elimination": "Alerte élimination : à chaque seuil, la dernière signature quittera la grille.",
	"grand_prix": "Transmission championnat : chaque position comptera jusqu’au titre.",
}


static func briefing(config: Dictionary) -> Dictionary:
	var track_id := String(config.get("track_id", config.get("track", "foundry")))
	var track := GameDatabase.get_track(track_id)
	var mode := String(config.get("mode", "quick"))
	var championship_id := String(config.get("championship_id", config.get("cup_id", "")))
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
		"eyebrow": "NEXUS GRAND LEAGUE // GRILLE OFFICIELLE",
		"track_name": String(track.get("name", track_id)).to_upper(),
		"region": String(track.get("region", "SECTEUR INTERGALACTIQUE")).to_upper(),
		"session": "%s  //  %d TOURS  //  %02d PARTANTS" % [_mode_name(mode), laps, entrants],
		"rules": "%s  //  CLASSE %s" % [String(ruleset.get("name", ruleset_id)).to_upper(), String(performance.get("name", "TUNED")).to_upper()],
		"rules_detail": String(ruleset.get("description", "Règlement standard de la Ligue.")),
		"objective": _objective(mode),
		"announcer": _announcer_opener(mode, championship_id),
		"lore": String(TRACK_LORE.get(track_id, track.get("description", "Circuit homologué par la Ligue."))),
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
			callout = "La Ligue valide une nouvelle référence intergalactique !" if new_record else "Chrono validé : la télémétrie rejoint les archives officielles."
		else:
			title = "VICTOIRE INTERGALACTIQUE" if position == 1 else "ARRIVÉE HOMOLOGUÉE"
			callout = "Le drapeau tombe : victoire et nouvelle référence de grille !" if position == 1 else "Drapeau à damier : %s place validée par le contrôle course." % _ordinal(position)
	return {
		"title": title,
		"position": "DNF" if dnf else ("RECORD" if mode == "time_trial" and new_record else ("CHRONO VALIDÉ" if mode == "time_trial" else "%s / %02d" % [_ordinal(position), maxi(1, int(result.get("total_racers", result.get("racer_count", 8))))])),
		"callout": callout,
		"venue": "%s // %s" % [String(track.get("name", track_id)).to_upper(), String(track.get("region", "NEXUS GRAND LEAGUE")).to_upper()],
	}


static func _announcer_opener(mode: String, championship_id: String) -> String:
	if mode != "grand_prix":
		return String(ANNOUNCER_OPENERS.get(mode, ANNOUNCER_OPENERS["quick"]))
	var championship := GameDatabase.get_championship(championship_id)
	if championship_id == "nexus_open":
		return "Transmission Grand Open : huit mondes, dix catégories; chaque position comptera jusqu’à Circuit Zero."
	if not championship.is_empty():
		return "Transmission %s : chaque position compte pour le titre de catégorie et l’invitation au Grand Open." % String(championship.get("name", "Coupe de catégorie")).to_upper()
	return String(ANNOUNCER_OPENERS["grand_prix"])
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
