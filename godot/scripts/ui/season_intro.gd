extends Control
class_name SeasonIntroScreen

signal completed(mark_seen: bool)

const ThemeFactory = preload("res://scripts/ui/ui_theme.gd")

const CHAPTERS: Array[Dictionary] = [
	{
		"stage": "ARCHIVE 01 // LA RUPTURE",
		"heading": "LES CORRIDORS SE SONT TUS.",
		"narrative": "En 2089, le réseau du Nexus s’est effondré. Les cités-frontières ont perdu leurs routes, leur énergie et jusqu’au bruit des convois.",
		"role": "Un anneau a continué de répondre : CIRCUIT ZERO.",
	},
	{
		"stage": "ARCHIVE 02 // LA RÉSONANCE",
		"heading": "LA VITESSE PEUT RÉVEILLER LE RÉSEAU.",
		"narrative": "Les noyaux de huit méchas lancés ensemble réalignent les lignes mortes. La Nexus Racing Authority a transformé cette découverte en championnat mondial.",
		"role": "Chaque arrivée rallume une route. Chaque podium décide qui en reçoit l’énergie.",
	},
	{
		"stage": "DOSSIER 08 // VOTRE LICENCE",
		"heading": "PERSONNE NE RESTE IMMOBILE.",
		"narrative": "Le Hangar 08 vous confie sa dernière unité. Roues, jambes, chenilles, sphères ou bi-propulseur Aether : construisez votre signature et affrontez les cinq divisions.",
		"role": "SAISON 03 // RECONQUÊTE — PRENEZ LA GRILLE.",
	},
]

@onready var stage_label: Label = %StageLabel
@onready var heading: Label = %Heading
@onready var narrative: Label = %Narrative
@onready var role_label: Label = %RoleLabel
@onready var progress_value: Label = %ProgressValue
@onready var skip_button: Button = %SkipButton
@onready var continue_button: Button = %ContinueButton
@onready var story_panel: PanelContainer = %StoryPanel

var _chapter_index := 0
var _finished := false


func _ready() -> void:
	theme = ThemeFactory.create_theme(_settings())
	skip_button.pressed.connect(_finish.bind(true))
	continue_button.pressed.connect(_advance)
	ThemeFactory.connect_focus_chain([skip_button, continue_button], true)
	_show_chapter(0, false)
	continue_button.call_deferred(&"grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(true)


func complete_now(mark_seen: bool = true) -> void:
	## Public seam used by automated flow verification and accessibility tools.
	_finish(mark_seen)


func _advance() -> void:
	if _chapter_index >= CHAPTERS.size() - 1:
		_finish(true)
		return
	_show_chapter(_chapter_index + 1, true)


func _show_chapter(index: int, animate: bool) -> void:
	_chapter_index = clampi(index, 0, CHAPTERS.size() - 1)
	var chapter := CHAPTERS[_chapter_index]
	stage_label.text = String(chapter.get("stage", "TRANSMISSION"))
	heading.text = String(chapter.get("heading", "MECHA OVERDRIVE"))
	narrative.text = String(chapter.get("narrative", ""))
	role_label.text = String(chapter.get("role", ""))
	progress_value.text = "%02d / %02d" % [_chapter_index + 1, CHAPTERS.size()]
	continue_button.text = "ENTRER DANS LE NEXUS" if _chapter_index == CHAPTERS.size() - 1 else "CONTINUER  //  %02d" % [_chapter_index + 2]
	if not animate:
		return
	var duration := ThemeFactory.motion_duration(_settings(), 0.22)
	if duration <= 0.0:
		story_panel.modulate = Color.WHITE
		return
	story_panel.modulate = Color(0.72, 0.92, 1.0, 0.2)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(story_panel, "modulate", Color.WHITE, duration)


func _finish(mark_seen: bool) -> void:
	if _finished:
		return
	_finished = true
	completed.emit(mark_seen)


func _settings() -> Dictionary:
	var save := get_node_or_null("/root/SaveSystem")
	if save == null:
		return {}
	var profile_value: Variant = save.get("profile")
	if profile_value is Dictionary:
		var settings_value: Variant = Dictionary(profile_value).get("settings", {})
		return Dictionary(settings_value).duplicate(true) if settings_value is Dictionary else {}
	return {}
