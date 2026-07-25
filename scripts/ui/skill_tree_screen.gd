extends Control

## Skill screen laid out as three separate trees, one per branch, drawn the way
## progression trees usually read: a trunk that forks into two paths and diamond
## nodes wired together by lines that light up as they unlock.
##
## Clicking a node is what spends a point, via a confirmation dialog. An earlier
## version put an UNLOCK button in a detail panel below the trees, which turned
## out to be unusable: hovering a node selected it, so dragging the cursor down
## to the button crossed other nodes and silently changed the selection on the
## way. Hover now only previews; the click decides.

const UNLOCKED_COLOR := Color(0.44, 0.82, 0.59, 1.0)
const LOCKED_COLOR := Color(0.55, 0.6, 0.65, 1.0)
const ACCENT_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const CARD_TITLE_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
const BRANCH_COLORS := {
	SkillTree.BRANCH_OFFENSE: Color(0.91, 0.4, 0.36, 1.0),
	SkillTree.BRANCH_SURVIVAL: Color(0.44, 0.82, 0.59, 1.0),
	SkillTree.BRANCH_EXPEDITION: Color(0.36, 0.68, 0.88, 1.0),
}

## Tree geometry, in pixels inside each branch panel.
const NODE_SIZE := Vector2(46.0, 46.0)
const TIER_SPACING := 52.0
const COLUMN_SPACING := 84.0
const TREE_TOP_MARGIN := 26.0
const TREE_SIZE := Vector2(264.0, 364.0)

@onready var title_label: Label = %TitleLabel
@onready var points_label: Label = %PointsLabel
@onready var branches_container: HBoxContainer = %Branches
@onready var back_button: Button = %BackButton

var _detail_title: Label
var _detail_body: Label
var _detail_state: Label
var _confirm_dialog: ConfirmationDialog
var _focused_node_id: StringName = &""
var _pending_node_id: StringName = &""
var _node_buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(GameManager.open_character_selection)
	SaveManager.skill_points_changed.connect(_on_skill_points_changed)
	SaveManager.character_progress_changed.connect(_on_character_progress_changed)
	_build_detail_panel()
	_build_confirm_dialog()
	_rebuild()
	back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Esc mirrors the BACK button, like every other menu page.
	if event.is_action_pressed(&"ui_cancel"):
		GameManager.open_character_selection()
		get_viewport().set_input_as_handled()


func _on_skill_points_changed(_character_id: StringName) -> void:
	_rebuild()


func _on_character_progress_changed(
	_character_id: StringName, _level: int, _xp: int
) -> void:
	_rebuild()


func _build_detail_panel() -> void:
	# Built in code so the existing scene keeps its layout: a single panel under
	# the trees describes whichever node the cursor is on, which is what keeps
	# the nodes themselves free of text.
	var panel := PanelContainer.new()
	panel.name = "DetailPanel"
	panel.theme_type_variation = &"MenuPanel"
	panel.custom_minimum_size = Vector2(0, 84)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 20)
	margin.add_child(row)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override(&"separation", 3)
	row.add_child(text_column)
	_detail_title = Label.new()
	_detail_title.add_theme_font_override(&"font", CARD_TITLE_FONT)
	_detail_title.add_theme_font_size_override(&"font_size", 18)
	text_column.add_child(_detail_title)
	_detail_body = Label.new()
	_detail_body.theme_type_variation = &"MutedLabel"
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_column.add_child(_detail_body)
	_detail_state = Label.new()
	_detail_state.theme_type_variation = &"MutedLabel"
	text_column.add_child(_detail_state)
	branches_container.get_parent().add_child(panel)
	_show_detail(&"")


func _build_confirm_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "UNLOCK SKILL"
	_confirm_dialog.ok_button_text = "YES"
	_confirm_dialog.cancel_button_text = "NO"
	_confirm_dialog.dialog_autowrap = true
	_confirm_dialog.min_size = Vector2i(420, 0)
	_confirm_dialog.confirmed.connect(_on_unlock_confirmed)
	add_child(_confirm_dialog)


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
	_node_buttons.clear()
	for branch in SkillTree.BRANCHES:
		branches_container.add_child(_build_branch_panel(character_id, branch))
	_show_detail(_focused_node_id)


func _build_branch_panel(
	character_id: StringName, branch: Dictionary
) -> PanelContainer:
	var branch_id: StringName = branch["id"]
	var branch_color: Color = BRANCH_COLORS.get(branch_id, ACCENT_COLOR)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MenuPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	margin.add_child(column)

	var branch_title := Label.new()
	branch_title.theme_type_variation = &"SectionTitle"
	branch_title.add_theme_color_override(&"font_color", branch_color)
	branch_title.text = String(branch["title"])
	branch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(branch_title)
	var tagline := Label.new()
	tagline.theme_type_variation = &"MutedLabel"
	tagline.add_theme_font_size_override(&"font_size", 12)
	tagline.text = String(branch["tagline"])
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)

	var canvas := _make_tree_canvas(character_id, branch_id, branch_color)
	column.add_child(canvas)
	return panel


func _make_tree_canvas(
	character_id: StringName, branch_id: StringName, branch_color: Color
) -> Control:
	var canvas := Control.new()
	canvas.custom_minimum_size = TREE_SIZE
	# Shrink-centre rather than expand: node positions are computed against
	# TREE_SIZE, so the canvas has to keep exactly that width to stay centred.
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	var links := _TreeLinks.new()
	links.set_anchors_preset(Control.PRESET_FULL_RECT)
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.branch_color = branch_color
	canvas.add_child(links)

	var nodes := SkillTree.get_branch_nodes(branch_id)
	var positions: Dictionary[StringName, Vector2] = {}
	for node_definition in nodes:
		var node_id: StringName = node_definition["id"]
		positions[node_id] = _get_node_position(node_definition)
		var button := _build_node_button(
			character_id, node_definition, branch_color
		)
		button.position = positions[node_id] - NODE_SIZE * 0.5
		canvas.add_child(button)
		_node_buttons[node_id] = button
	# Links are described in canvas space and drawn behind the buttons.
	for node_definition in nodes:
		var node_id: StringName = node_definition["id"]
		for prerequisite_value in node_definition["requires"]:
			var prerequisite := StringName(prerequisite_value)
			if not positions.has(prerequisite):
				continue
			links.links.append({
				"from": positions[prerequisite],
				"to": positions[node_id],
				"active": SaveManager.is_skill_node_unlocked(
					character_id, prerequisite
				),
			})
	return canvas


func _get_node_position(node_definition: Dictionary) -> Vector2:
	var tier := int(node_definition["tier"])
	var node_column := int(node_definition["column"])
	return Vector2(
		TREE_SIZE.x * 0.5 + float(node_column) * COLUMN_SPACING * 0.5,
		TREE_TOP_MARGIN + float(tier - 1) * TIER_SPACING
	)


func _build_node_button(
	character_id: StringName,
	node_definition: Dictionary,
	branch_color: Color
) -> Button:
	var node_id: StringName = node_definition["id"]
	var unlocked := SaveManager.is_skill_node_unlocked(character_id, node_id)
	var can_unlock := SaveManager.can_unlock_skill_node(character_id, node_id)
	var button := Button.new()
	button.size = NODE_SIZE
	button.custom_minimum_size = NODE_SIZE
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	var state_text := (
		"UNLOCKED" if unlocked
		else "AVAILABLE — click to unlock" if can_unlock
		else "LOCKED — %s" % _get_requirement_text(character_id, node_id)
	)
	button.tooltip_text = "%s\n%s\n%s" % [
		String(node_definition["title"]),
		String(node_definition["description"]),
		state_text,
	]
	button.add_child(
		_make_node_diamond(node_definition, unlocked, can_unlock, branch_color)
	)
	# Hover only previews; the click is what commits, so moving the cursor can
	# never change what a click is about to spend a point on.
	button.mouse_entered.connect(_show_detail.bind(node_id))
	button.pressed.connect(_on_node_pressed.bind(node_id))
	return button


func _on_node_pressed(node_id: StringName) -> void:
	_show_detail(node_id)
	var character_id := SaveManager.get_selected_character()
	if SaveManager.is_skill_node_unlocked(character_id, node_id):
		return
	if not SaveManager.can_unlock_skill_node(character_id, node_id):
		return
	var node_definition := SkillTree.get_node_definition(node_id)
	_pending_node_id = node_id
	_confirm_dialog.dialog_text = "%s\n\n%s\n\nSpend 1 skill point?" % [
		String(node_definition["title"]).to_upper(),
		String(node_definition["description"]),
	]
	_confirm_dialog.popup_centered()


func _on_unlock_confirmed() -> void:
	if _pending_node_id == &"":
		return
	SaveManager.unlock_skill_node(
		SaveManager.get_selected_character(), _pending_node_id
	)
	_pending_node_id = &""
	# _rebuild runs via the skill_points_changed signal.


func _make_node_diamond(
	node_definition: Dictionary,
	unlocked: bool,
	can_unlock: bool,
	branch_color: Color
) -> Control:
	var diamond := _NodeDiamond.new()
	diamond.set_anchors_preset(Control.PRESET_FULL_RECT)
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diamond.branch_color = branch_color
	diamond.unlocked = unlocked
	diamond.can_unlock = can_unlock
	diamond.tier_text = str(int(node_definition["tier"]))
	return diamond


func _show_detail(node_id: StringName) -> void:
	_focused_node_id = node_id
	var character_id := SaveManager.get_selected_character()
	var node_definition := SkillTree.get_node_definition(node_id)
	if node_definition.is_empty():
		_detail_title.text = "SELECT A SKILL"
		_detail_title.add_theme_color_override(&"font_color", LOCKED_COLOR)
		_detail_body.text = (
			"Click a node to spend a point on it. Each branch forks in two after "
			+ "the first skill; the capstone opens from either path."
		)
		_detail_state.text = ""
		return
	var branch_color: Color = BRANCH_COLORS.get(
		node_definition["branch"], ACCENT_COLOR
	)
	var unlocked := SaveManager.is_skill_node_unlocked(character_id, node_id)
	var can_unlock := SaveManager.can_unlock_skill_node(character_id, node_id)
	_detail_title.text = "%s  ·  TIER %d" % [
		String(node_definition["title"]).to_upper(), int(node_definition["tier"])
	]
	_detail_title.add_theme_color_override(
		&"font_color", ACCENT_COLOR if unlocked else branch_color
	)
	_detail_body.text = String(node_definition["description"])
	if unlocked:
		_detail_state.text = "UNLOCKED"
		_detail_state.add_theme_color_override(&"font_color", UNLOCKED_COLOR)
		return
	if can_unlock:
		_detail_state.text = "AVAILABLE  ·  click the node to spend 1 point"
		_detail_state.add_theme_color_override(&"font_color", branch_color)
		return
	_detail_state.text = "LOCKED  ·  %s" % _get_requirement_text(
		character_id, node_id
	)
	_detail_state.add_theme_color_override(&"font_color", LOCKED_COLOR)


func _get_requirement_text(
	character_id: StringName, node_id: StringName
) -> String:
	var required_level := SkillTree.get_required_level(node_id)
	if SaveManager.get_character_level(character_id) < required_level:
		return "REQUIRES LEVEL %d" % required_level
	var unlocked_ids := Array(SaveManager.get_unlocked_skill_nodes(character_id))
	if not SkillTree.is_prerequisite_met(node_id, unlocked_ids):
		var names: PackedStringArray = []
		for prerequisite in SkillTree.get_prerequisites(node_id):
			var definition := SkillTree.get_node_definition(
				StringName(prerequisite)
			)
			if not definition.is_empty():
				names.append(String(definition["title"]).to_upper())
		return "REQUIRES %s" % " OR ".join(names)
	if SaveManager.get_available_skill_points(character_id) <= 0:
		return "NO SKILL POINTS  ·  NEXT AT LEVEL %d" % (
			SaveManager.get_next_skill_point_level(character_id)
		)
	return "LEVEL %d REQUIRED" % required_level


## Draws the wiring between nodes behind the buttons.
class _TreeLinks:
	extends Control

	const INACTIVE_COLOR := Color(0.25, 0.29, 0.32, 0.75)

	var links: Array[Dictionary] = []
	var branch_color := Color.WHITE

	func _draw() -> void:
		for link in links:
			var from: Vector2 = link["from"]
			var to: Vector2 = link["to"]
			var active: bool = link["active"]
			var color := (
				branch_color.darkened(0.1) if active else INACTIVE_COLOR
			)
			var width := 4.0 if active else 2.0
			# Elbow routing: down, across, then down again, so forks read as
			# branches instead of diagonal spaghetti.
			var midpoint_y := (from.y + to.y) * 0.5
			draw_line(from, Vector2(from.x, midpoint_y), color, width, true)
			draw_line(
				Vector2(from.x, midpoint_y), Vector2(to.x, midpoint_y),
				color, width, true
			)
			draw_line(Vector2(to.x, midpoint_y), to, color, width, true)


## A single skill node: a diamond that reads as locked, available or unlocked.
class _NodeDiamond:
	extends Control

	const TIER_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
	const LOCKED_FILL := Color(0.05, 0.07, 0.09, 0.95)
	const LOCKED_LINE := Color(0.3, 0.34, 0.38, 0.7)

	var branch_color := Color.WHITE
	var unlocked := false
	var can_unlock := false
	var tier_text := ""

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		])
		var fill := LOCKED_FILL
		var line := LOCKED_LINE
		var line_width := 2.0
		if unlocked:
			fill = Color(branch_color.r, branch_color.g, branch_color.b, 0.35)
			line = branch_color
			line_width = 3.0
		elif can_unlock:
			fill = Color(branch_color.r, branch_color.g, branch_color.b, 0.14)
			line = branch_color
			line_width = 3.0
		draw_colored_polygon(points, fill)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, line, line_width, true)
		# An unlocked node gets a filled core, the way spent points usually read.
		if unlocked:
			var core := PackedVector2Array([
				center + Vector2(0.0, -radius * 0.42),
				center + Vector2(radius * 0.42, 0.0),
				center + Vector2(0.0, radius * 0.42),
				center + Vector2(-radius * 0.42, 0.0),
			])
			draw_colored_polygon(core, branch_color)
			return
		var font := TIER_FONT
		var text_size := font.get_string_size(tier_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(
			font,
			center + Vector2(-text_size.x * 0.5, text_size.y * 0.32),
			tier_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			line
		)
