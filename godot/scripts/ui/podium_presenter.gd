class_name PodiumPresenter
extends HBoxContainer

## Reusable top-three podium. Only validated finishers may occupy a card.

var _cards: Array[PanelContainer] = []
var _rank_labels: Array[Label] = []
var _pilot_labels: Array[Label] = []
var _detail_labels: Array[Label] = []
var _top_three: Array[Dictionary] = []


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	alignment = BoxContainer.ALIGNMENT_CENTER
	if _cards.is_empty():
		_build()


func present(entries_value: Variant, player_position: int, player_dnf: bool, mode: String = "quick") -> void:
	if _cards.is_empty():
		_build()
	_hide_all_cards()
	_top_three.clear()
	if mode == "time_trial":
		return
	var entries: Array = entries_value if entries_value is Array else []
	var normalized: Array[Dictionary] = []
	for index in range(entries.size()):
		if entries[index] is Dictionary:
			var entry: Dictionary = Dictionary(entries[index]).duplicate(true)
			entry["position"] = int(entry.get("position", entry.get("rank", index + 1)))
			if not _is_valid_podium_entry(entry):
				continue
			normalized.append(entry)
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("position", 99)) < int(b.get("position", 99)))
	_top_three = normalized.slice(0, 3)
	var card_by_rank := {1: 1, 2: 0, 3: 2}
	for entry: Dictionary in _top_three:
		var rank := int(entry.get("position", 0))
		if not card_by_rank.has(rank):
			continue
		var card_index := int(card_by_rank[rank])
		var pilot := String(entry.get("pilot", entry.get("name", entry.get("display_name", "PILOTE %02d" % rank)))).to_upper()
		var chassis_id := String(entry.get("chassis_id", ""))
		var chassis := GameDatabase.get_chassis(chassis_id)
		var chassis_name := String(chassis.get("name", chassis_id if not chassis_id.is_empty() else "MÉCHA HOMOLOGUÉ")).to_upper()
		var is_player := not player_dnf and (bool(entry.get("player", entry.get("is_player", false))) or String(entry.get("racer_id", "")) == "player" or rank == player_position)
		_rank_labels[card_index].text = "CHAMPION // 1RE" if rank == 1 else ("ARGENT // 2E" if rank == 2 else "BRONZE // 3E")
		_pilot_labels[card_index].text = ("VOUS • " if is_player else "") + pilot
		_detail_labels[card_index].text = chassis_name
		_cards[card_index].modulate = Color("9ff5ff") if is_player else Color.WHITE
		var card_stack := _cards[card_index].get_parent() as Control
		if card_stack != null:
			card_stack.visible = true


func top_three() -> Array[Dictionary]:
	return _top_three.duplicate(true)


func winner_name() -> String:
	for entry: Dictionary in _top_three:
		if int(entry.get("position", 0)) == 1:
			return String(entry.get("pilot", entry.get("name", entry.get("display_name", ""))))
	return ""


func visible_card_count() -> int:
	var count := 0
	for card: PanelContainer in _cards:
		var card_stack := card.get_parent() as Control
		if card_stack != null and card_stack.visible:
			count += 1
	return count


func _is_valid_podium_entry(entry: Dictionary) -> bool:
	var rank := int(entry.get("position", 0))
	return rank >= 1 and rank <= 3 \
		and (bool(entry.get("finished", false)) or bool(entry.get("classified", false))) \
		and not bool(entry.get("dnf", entry.get("did_not_finish", false))) \
		and not bool(entry.get("eliminated", false))


func _hide_all_cards() -> void:
	for card: PanelContainer in _cards:
		var card_stack := card.get_parent() as Control
		if card_stack != null:
			card_stack.visible = false
		card.modulate = Color.WHITE


func _build() -> void:
	for child: Node in get_children():
		child.queue_free()
	_cards.clear()
	_rank_labels.clear()
	_pilot_labels.clear()
	_detail_labels.clear()
	for visual_rank: int in [2, 1, 3]:
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.alignment = BoxContainer.ALIGNMENT_END
		add_child(stack)
		if visual_rank != 1:
			var lift := Control.new()
			lift.custom_minimum_size.y = 18.0 if visual_rank == 2 else 30.0
			stack.add_child(lift)
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"CardPanel"
		panel.custom_minimum_size = Vector2(118.0, 126.0 if visual_rank == 1 else 108.0)
		stack.add_child(panel)
		var content := VBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override(&"separation", 4)
		panel.add_child(content)
		var rank_label := _label("CHAMPION // 1RE", &"EyebrowLabel")
		var pilot_label := _label("PILOTE", &"SectionLabel")
		var detail_label := _label("MÉCHA HOMOLOGUÉ", &"MutedLabel")
		pilot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(rank_label)
		content.add_child(pilot_label)
		content.add_child(detail_label)
		_cards.append(panel)
		_rank_labels.append(rank_label)
		_pilot_labels.append(pilot_label)
		_detail_labels.append(detail_label)
	_hide_all_cards()


func _label(text_value: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text_value
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
