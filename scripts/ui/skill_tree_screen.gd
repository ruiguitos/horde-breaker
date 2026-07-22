extends Control

const UNLOCKED_COLOR := Color(0.44, 0.82, 0.59, 1.0)
const LOCKED_COLOR := Color(0.55, 0.6, 0.65, 1.0)
const ACCENT_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const CARD_TITLE_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
const BRANCH_COLORS := {
	SkillTree.BRANCH_OFFENSE: Color(0.91, 0.4, 0.36, 1.0),
	SkillTree.BRANCH_SURVIVAL: Color(0.44, 0.82, 0.59, 1.0),
	SkillTree.BRANCH_EXPEDITION: Color(0.36, 0.68, 0.88, 1.0),
}

@onready var title_label: Label = %TitleLabel
@onready var points_label: Label = %PointsLabel
@onready var branches_container: HBoxContainer = %Branches
@onready var back_button: Button = %BackButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(GameManager.open_character_selection)
	SaveManager.skill_points_changed.connect(_on_skill_points_changed)
	SaveManager.character_progress_changed.connect(_on_character_progress_changed)
	_rebuild()
	back_button.grab_focus()


func _on_skill_points_changed(_character_id: StringName) -> void:
	_rebuild()


func _on_character_progress_changed(
	_character_id: StringName, _level: int, _xp: int
) -> void:
	_rebuild()


func _rebuild() -> void:
	var character_id := SaveManager.get_selected_character()
	var character_data := SaveManager.get_character_data(character_id)
	var character_name := (
		character_data.display_name if character_data != null else String(character_id)
	)
	title_label.text = "%s  —  SKILL TREE" % character_name
	var level := SaveManager.get_character_level(character_id)
	points_label.text = "LV %d  ·  %d PTS  ·  NEXT LV %d" % [
		level,
		SaveManager.get_available_skill_points(character_id),
		SaveManager.get_next_skill_point_level(character_id),
	]
	for child in branches_container.get_children():
		branches_container.remove_child(child)
		child.queue_free()
	for branch in SkillTree.BRANCHES:
		branches_container.add_child(_build_branch_column(character_id, branch))
	UiAnimations.enhance_buttons(self)


func _build_branch_column(
	character_id: StringName, branch: Dictionary
) -> VBoxContainer:
	var branch_id: StringName = branch["id"]
	var branch_color: Color = BRANCH_COLORS.get(branch_id, ACCENT_COLOR)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 0)
	var branch_title := Label.new()
	branch_title.theme_type_variation = &"SectionTitle"
	branch_title.add_theme_color_override(&"font_color", branch_color)
	branch_title.text = String(branch["title"])
	branch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(branch_title)
	var branch_nodes := SkillTree.get_branch_nodes(branch_id)
	for node_index in branch_nodes.size():
		var node_definition: Dictionary = branch_nodes[node_index]
		column.add_child(
			_build_node_card(character_id, node_definition, branch_color)
		)
		if node_index < branch_nodes.size() - 1:
			column.add_child(
				_build_connector(character_id, node_definition, branch_color)
			)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	return column


func _build_node_card(
	character_id: StringName,
	node_definition: Dictionary,
	branch_color: Color
) -> PanelContainer:
	var node_id: StringName = node_definition["id"]
	var unlocked := SaveManager.is_skill_node_unlocked(character_id, node_id)
	var can_unlock := SaveManager.can_unlock_skill_node(character_id, node_id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override(
		&"panel", _make_node_style(unlocked, can_unlock, branch_color)
	)
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
	title.add_theme_font_override(&"font", CARD_TITLE_FONT)
	title.add_theme_color_override(
		&"font_color",
		ACCENT_COLOR if unlocked else branch_color if can_unlock else LOCKED_COLOR
	)
	title.text = "%d · %s  [LV %d]" % [
		int(node_definition["tier"]),
		String(node_definition["title"]),
		SkillTree.get_required_level(node_id),
	]
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
		content.add_child(
			_make_state_label(
				_get_locked_reason(character_id, node_id), LOCKED_COLOR
			)
		)
	return card


func _build_connector(
	character_id: StringName,
	previous_node: Dictionary,
	branch_color: Color
) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0.0, 8.0)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(3.0, 8.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var previous_id: StringName = previous_node["id"]
	line.color = (
		branch_color.darkened(0.12)
		if SaveManager.is_skill_node_unlocked(character_id, previous_id)
		else Color(0.25, 0.29, 0.32, 0.55)
	)
	holder.add_child(line)
	return holder


func _make_node_style(
	unlocked: bool, can_unlock: bool, branch_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.052, 0.068, 0.97)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	if unlocked:
		style.bg_color = Color(0.095, 0.075, 0.045, 0.98)
		style.border_color = ACCENT_COLOR
		style.shadow_color = Color(0.957, 0.694, 0.31, 0.22)
		style.shadow_size = 7
	elif can_unlock:
		style.bg_color = Color(
			branch_color.r * 0.12,
			branch_color.g * 0.12,
			branch_color.b * 0.12,
			0.98
		)
		style.border_color = branch_color
		style.shadow_color = Color(
			branch_color.r, branch_color.g, branch_color.b, 0.28
		)
		style.shadow_size = 8
	else:
		style.bg_color = Color(0.022, 0.032, 0.043, 0.92)
		style.border_color = Color(
			branch_color.r, branch_color.g, branch_color.b, 0.24
		)
	return style


func _get_locked_reason(character_id: StringName, node_id: StringName) -> String:
	var required_level := SkillTree.get_required_level(node_id)
	if SaveManager.get_character_level(character_id) < required_level:
		return "REQUIRES LEVEL %d" % required_level
	var prerequisite := SkillTree.get_prerequisite_id(node_id)
	if (
		prerequisite != &""
		and not SaveManager.is_skill_node_unlocked(character_id, prerequisite)
	):
		return "REQUIRES PREVIOUS SKILL"
	if SaveManager.get_available_skill_points(character_id) <= 0:
		return "NO SKILL POINTS"
	return "LOCKED"


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
