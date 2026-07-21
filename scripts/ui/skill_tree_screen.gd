extends Control

const UNLOCKED_COLOR := Color(0.44, 0.82, 0.59, 1.0)
const LOCKED_COLOR := Color(0.55, 0.6, 0.65, 1.0)
const ACCENT_COLOR := Color(0.957, 0.694, 0.31, 1.0)

@onready var title_label: Label = %TitleLabel
@onready var points_label: Label = %PointsLabel
@onready var branches_container: HBoxContainer = %Branches
@onready var back_button: Button = %BackButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(GameManager.open_character_selection)
	SaveManager.skill_points_changed.connect(_on_skill_points_changed)
	_rebuild()
	back_button.grab_focus()


func _on_skill_points_changed(_character_id: StringName) -> void:
	_rebuild()


func _rebuild() -> void:
	var character_id := SaveManager.get_selected_character()
	var character_data := SaveManager.get_character_data(character_id)
	var character_name := (
		character_data.display_name if character_data != null else String(character_id)
	)
	title_label.text = "%s  —  SKILL TREE" % character_name
	points_label.text = "SKILL POINTS  ·  %d" % SaveManager.get_available_skill_points(
		character_id
	)
	for child in branches_container.get_children():
		child.queue_free()
	for branch in SkillTree.BRANCHES:
		branches_container.add_child(_build_branch_column(character_id, branch))


func _build_branch_column(
	character_id: StringName, branch: Dictionary
) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 8)
	var branch_title := Label.new()
	branch_title.theme_type_variation = &"SectionTitle"
	branch_title.text = String(branch["title"])
	branch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(branch_title)
	for node_definition in SkillTree.get_branch_nodes(branch["id"]):
		column.add_child(_build_node_card(character_id, node_definition))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	return column


func _build_node_card(
	character_id: StringName, node_definition: Dictionary
) -> PanelContainer:
	var node_id: StringName = node_definition["id"]
	var unlocked := SaveManager.is_skill_node_unlocked(character_id, node_id)
	var can_unlock := SaveManager.can_unlock_skill_node(character_id, node_id)

	var card := PanelContainer.new()
	card.theme_type_variation = &"SelectedCard" if unlocked else &"CardPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 12)
	margin.add_theme_constant_override(&"margin_top", 7)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_bottom", 7)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 3)
	margin.add_child(content)

	var title := Label.new()
	title.add_theme_font_size_override(&"font_size", 16)
	title.add_theme_color_override(&"font_color", Color(0.965, 0.949, 0.91, 1.0))
	title.text = "%d · %s" % [int(node_definition["tier"]), String(node_definition["title"])]
	content.add_child(title)

	var description := Label.new()
	description.theme_type_variation = &"MutedLabel"
	description.add_theme_font_size_override(&"font_size", 13)
	description.text = String(node_definition["description"])
	content.add_child(description)

	if unlocked:
		content.add_child(_make_state_label("UNLOCKED", UNLOCKED_COLOR))
	elif can_unlock:
		var button := Button.new()
		button.theme_type_variation = &"PrimaryButton"
		button.custom_minimum_size = Vector2(0, 32)
		button.text = "UNLOCK  ·  1 PT"
		button.pressed.connect(_on_unlock_pressed.bind(node_id))
		content.add_child(button)
	else:
		content.add_child(_make_state_label("LOCKED", LOCKED_COLOR))
	return card


func _make_state_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", 13)
	label.add_theme_color_override(&"font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 32)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = text
	return label


func _on_unlock_pressed(node_id: StringName) -> void:
	SaveManager.unlock_skill_node(SaveManager.get_selected_character(), node_id)
	# _rebuild runs via the skill_points_changed signal.
