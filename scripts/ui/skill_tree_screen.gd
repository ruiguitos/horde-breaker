extends Control

## Skill screen: the selected class's three categories, drawn as columns.
##
## Nodes are bought with skill points and accumulate — buying one never removes
## another. Because a point is spent and not refunded, a click asks first. The
## detail panel under the tree carries the description, the cost and the reason a
## node cannot be taken yet, so nothing has to be crowded around the diamonds.

const ACCENT_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const MUTED_COLOR := Color(0.62, 0.665, 0.7, 1.0)
const LOCKED_COLOR := Color(0.46, 0.5, 0.55, 1.0)
const CARD_TITLE_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const CANVAS_MINIMUM := Vector2(820.0, 560.0)

@onready var title_label: Label = %TitleLabel
@onready var points_label: Label = %PointsLabel
@onready var branches_container: HBoxContainer = %Branches
@onready var back_button: Button = %BackButton

var _canvas: SkillTreeCanvas
var _detail_title: Label
var _detail_body: Label
var _confirm_dialog: ConfirmationDialog
var _pending_node_id: StringName = &""
var _node_buttons: Dictionary[StringName, Button] = {}
var _accent := ACCENT_COLOR


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(GameManager.open_character_selection)
	SaveManager.skill_points_changed.connect(_on_skills_changed)
	SaveManager.character_progress_changed.connect(_on_character_progress_changed)
	_build_layout()
	_build_confirm_dialog()
	_rebuild()
	back_button.grab_focus()
	UiAnimations.enhance_buttons(self)
	$PageMargin/Content/TopBar.modulate.a = 0.0
	branches_container.modulate.a = 0.0
	await get_tree().process_frame
	UiAnimations.slide_fade_in(
		$PageMargin/Content/TopBar, Vector2(0.0, -18.0), 0.0
	)
	UiAnimations.slide_fade_in(branches_container, Vector2(0.0, 18.0), 0.06)


func _unhandled_input(event: InputEvent) -> void:
	# Esc mirrors the BACK button, like every other menu page.
	if event.is_action_pressed(&"ui_cancel"):
		GameManager.open_character_selection()
		get_viewport().set_input_as_handled()


func _build_layout() -> void:
	for child in branches_container.get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.name = "TreeColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 8)
	branches_container.add_child(column)

	var headings := HBoxContainer.new()
	headings.name = "CategoryHeadings"
	column.add_child(headings)

	_canvas = SkillTreeCanvas.new()
	_canvas.name = "TreeCanvas"
	_canvas.custom_minimum_size = CANVAS_MINIMUM
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_canvas)

	var panel := PanelContainer.new()
	panel.name = "Detail"
	column.add_child(panel)
	var margin := MarginContainer.new()
	for side in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, 18)
	for side in [&"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 4)
	margin.add_child(body)
	_detail_title = Label.new()
	_detail_title.theme_type_variation = &"EyebrowLabel"
	body.add_child(_detail_title)
	_detail_body = Label.new()
	_detail_body.theme_type_variation = &"MutedLabel"
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_detail_body)


func _build_confirm_dialog() -> void:
	# A point is spent and never refunded, so the click asks first. The panel the
	# old version put the button in could not be reached without the cursor
	# crossing other nodes and changing the selection on the way.
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "UNLOCK SKILL"
	_confirm_dialog.ok_button_text = "UNLOCK"
	_confirm_dialog.cancel_button_text = "CANCEL"
	_confirm_dialog.confirmed.connect(_on_unlock_confirmed)
	add_child(_confirm_dialog)


func _on_skills_changed(_character_id: StringName) -> void:
	_rebuild()


func _on_character_progress_changed(
	_character_id: StringName, _level: int, _xp: int
) -> void:
	_rebuild()


func _rebuild() -> void:
	var character_id := SaveManager.get_selected_character()
	var tree := SkillTree.get_class_tree(character_id)
	_accent = UiVisualCatalog.get_character_color(character_id)

	title_label.text = "%s  ·  SKILLS" % String(
		tree.get("title", character_id)
	).to_upper()
	title_label.add_theme_color_override(&"font_color", _accent)
	points_label.text = _build_status_text(character_id)
	_set_detail(
		String(tree.get("tagline", "")),
		"Hover a skill to read it. Points are spent permanently."
	)

	_node_buttons.clear()
	for child in _canvas.get_children():
		child.queue_free()
	var headings := branches_container.get_node_or_null("TreeColumn/CategoryHeadings")
	if headings != null:
		for child in headings.get_children():
			child.queue_free()

	var categories := SkillTree.get_categories(character_id)
	if categories.is_empty():
		_canvas.columns = []
		_canvas.queue_redraw()
		_set_detail("NO SKILL TREE", "This operative has no tree yet.")
		return

	var unlocked := Array(SaveManager.get_unlocked_skill_nodes(character_id))
	var columns: Array[Dictionary] = []
	for category in categories:
		var nodes: Array = []
		for node in SkillTree.get_category_nodes(character_id, category["id"]):
			nodes.append({
				"tier": int(node["tier"]),
				"column": int(node["column"]),
				"unlocked": StringName(node["id"]) in unlocked
					or String(node["id"]) in unlocked,
				"available": SaveManager.can_unlock_skill_node(
					character_id, node["id"]
				),
			})
		columns.append({"nodes": nodes})
		if headings != null:
			headings.add_child(_build_category_heading(category))
	_canvas.accent = _accent
	_canvas.columns = columns
	_canvas.custom_minimum_size.y = maxf(
		CANVAS_MINIMUM.y, _canvas.get_required_height()
	)
	_canvas.queue_redraw()
	await get_tree().process_frame
	_place_nodes(character_id, categories, unlocked)


func _build_category_heading(category: Dictionary) -> Control:
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override(&"separation", 2)
	var title := Label.new()
	title.theme_type_variation = &"EyebrowLabel"
	title.add_theme_color_override(&"font_color", _accent)
	title.text = String(category["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(title)
	var tagline := Label.new()
	tagline.theme_type_variation = &"MutedLabel"
	tagline.add_theme_font_size_override(&"font_size", 12)
	tagline.text = String(category["tagline"])
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(tagline)
	return holder


func _place_nodes(
	character_id: StringName, categories: Array[Dictionary], unlocked: Array
) -> void:
	if not is_instance_valid(_canvas):
		return
	for column_index in categories.size():
		var category: Dictionary = categories[column_index]
		for node in SkillTree.get_category_nodes(character_id, category["id"]):
			_add_node(character_id, node, column_index, unlocked)


func _add_node(
	character_id: StringName,
	node: Dictionary,
	column_index: int,
	unlocked: Array
) -> void:
	var node_id: StringName = node["id"]
	var centre := _canvas.get_node_centre(
		column_index, int(node["tier"]), int(node["column"])
	)
	var radius := SkillTreeCanvas.NODE_RADIUS
	var is_unlocked := node_id in unlocked or String(node_id) in unlocked
	var can_unlock := SaveManager.can_unlock_skill_node(character_id, node_id)

	var button := Button.new()
	button.name = String(node_id)
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.size = Vector2(radius * 2.0, radius * 2.0)
	button.position = centre - Vector2(radius, radius)
	button.tooltip_text = "%s — %s" % [node["title"], node["description"]]
	_canvas.add_child(button)
	_node_buttons[node_id] = button

	var label := Label.new()
	label.name = "%s_label" % node_id
	label.add_theme_font_override(&"font", CARD_TITLE_FONT)
	label.add_theme_font_size_override(&"font_size", 12)
	label.text = String(node["title"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var colour := LOCKED_COLOR
	if is_unlocked:
		colour = _accent
	elif can_unlock:
		colour = MUTED_COLOR
	label.add_theme_color_override(&"font_color", colour)
	_canvas.add_child(label)
	label.size = Vector2(radius * 5.0, 16.0)
	label.position = Vector2(centre.x - radius * 2.5, centre.y + radius + 2.0)

	var detail := _build_detail_text(character_id, node, is_unlocked, can_unlock)
	button.mouse_entered.connect(
		_set_detail.bind(String(node["title"]).to_upper(), detail)
	)
	button.focus_entered.connect(
		_set_detail.bind(String(node["title"]).to_upper(), detail)
	)
	if can_unlock:
		button.pressed.connect(_on_node_pressed.bind(node_id))
	else:
		button.disabled = is_unlocked or not can_unlock


## Why a node is, or is not, available — the question the player is actually
## asking when they hover a locked diamond.
func _build_detail_text(
	character_id: StringName,
	node: Dictionary,
	is_unlocked: bool,
	can_unlock: bool
) -> String:
	var description := String(node["description"])
	if is_unlocked:
		return "%s\nUNLOCKED" % description
	if can_unlock:
		return "%s\nCosts 1 skill point." % description
	var level := SaveManager.get_character_level(character_id)
	if level < int(node["required_level"]):
		return "%s\nNeeds character level %d." % [
			description, int(node["required_level"])
		]
	if not SkillTree.is_prerequisite_met(
		node["id"], Array(SaveManager.get_unlocked_skill_nodes(character_id))
	):
		return "%s\nNeeds the skill above it first." % description
	return "%s\nNo skill points left." % description


func _set_detail(title: String, body: String) -> void:
	if not is_instance_valid(_detail_title):
		return
	_detail_title.text = title
	_detail_title.add_theme_color_override(&"font_color", _accent)
	_detail_body.text = body


func _build_status_text(character_id: StringName) -> String:
	var level := SaveManager.get_character_level(character_id)
	var points := SaveManager.get_available_skill_points(character_id)
	if points > 0:
		return "LEVEL %d  •  %d SKILL %s" % [
			level, points, "POINT" if points == 1 else "POINTS"
		]
	return "LEVEL %d  •  NEXT POINT AT LEVEL %d" % [
		level, SaveManager.get_next_skill_point_level(character_id)
	]


func _on_node_pressed(node_id: StringName) -> void:
	var node := SkillTree.get_node_definition(node_id)
	if node.is_empty():
		return
	_pending_node_id = node_id
	_confirm_dialog.dialog_text = "Spend 1 skill point on %s?\n\n%s" % [
		String(node["title"]).to_upper(), node["description"]
	]
	_confirm_dialog.popup_centered()


func _on_unlock_confirmed() -> void:
	if _pending_node_id == &"":
		return
	SaveManager.unlock_skill_node(
		SaveManager.get_selected_character(), _pending_node_id
	)
	_pending_node_id = &""
