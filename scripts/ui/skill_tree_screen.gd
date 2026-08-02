extends Control

## Skill screen: five tiers, two options each, drawn as a tree.
##
## The tree is a spine with a pair of branches at every tier. Taking a side
## lights its connector and fills its node, and the spine lights as far down as
## the deepest tier already chosen — so how far a build has come reads without
## being read. SkillTreeCanvas draws all of that; the buttons here are
## transparent hit areas sitting on the diamonds.
##
## Clicking a node takes it. Clicking the node already taken clears the tier.
## There is no confirmation and no cost: choices can be rearranged between runs,
## so a wrong pick costs a click rather than a character. The version this
## replaced needed a confirmation dialog precisely because a pick was permanent.

const ACCENT_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const MUTED_COLOR := Color(0.62, 0.665, 0.7, 1.0)
const LOCKED_COLOR := Color(0.46, 0.5, 0.55, 1.0)
const ACTIVE_COLOR := Color(0.93, 0.95, 0.97, 1.0)
const CARD_TITLE_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const LABEL_WIDTH := 176.0
const LABEL_OFFSET := 40.0
const CANVAS_MINIMUM := Vector2(760.0, 560.0)

@onready var title_label: Label = %TitleLabel
@onready var points_label: Label = %PointsLabel
@onready var branches_container: HBoxContainer = %Branches
@onready var back_button: Button = %BackButton

var _canvas: SkillTreeCanvas
var _detail_title: Label
var _detail_body: Label
var _node_buttons: Dictionary[StringName, Button] = {}
var _accent := ACCENT_COLOR


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(GameManager.open_character_selection)
	SaveManager.skill_points_changed.connect(_on_skills_changed)
	SaveManager.character_progress_changed.connect(_on_character_progress_changed)
	_build_layout()
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
	column.add_theme_constant_override(&"separation", 10)
	branches_container.add_child(column)

	_canvas = SkillTreeCanvas.new()
	_canvas.name = "TreeCanvas"
	_canvas.custom_minimum_size = CANVAS_MINIMUM
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_canvas)

	# One detail panel under the tree, rather than text crowded around ten nodes.
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


func _on_skills_changed(_character_id: StringName) -> void:
	_rebuild()


func _on_character_progress_changed(
	_character_id: StringName, _level: int, _xp: int
) -> void:
	_rebuild()


func _rebuild() -> void:
	var character_id := SaveManager.get_selected_character()
	var level := SaveManager.get_character_level(character_id)
	var tree := SkillTree.get_class_tree(character_id)
	_accent = UiVisualCatalog.get_character_color(character_id)

	title_label.text = "%s  ·  SKILLS" % String(
		tree.get("title", character_id)
	).to_upper()
	title_label.add_theme_color_override(&"font_color", _accent)
	points_label.text = _build_status_text(character_id, level)
	_set_detail(String(tree.get("tagline", "")), "")

	for button in _node_buttons.values():
		button.queue_free()
	_node_buttons.clear()
	for child in _canvas.get_children():
		child.queue_free()
	if tree.is_empty():
		_canvas.tiers = []
		_canvas.queue_redraw()
		_set_detail("NO SKILL TREE", "This operative has no tree yet.")
		return

	var chosen := Array(SaveManager.get_skill_choices(character_id))
	var tiers: Array[Dictionary] = []
	for tier in range(1, SkillTree.TIER_COUNT + 1):
		var required := SkillTree.get_required_level_for_tier(tier)
		var is_open := level >= required
		var active_id := SkillTree.get_choice_for_tier(chosen, character_id, tier)
		var taken := 0
		var options := SkillTree.get_tier_options(character_id, tier)
		for option_index in options.size():
			var side := -1 if option_index == 0 else 1
			if options[option_index]["id"] == active_id:
				taken = side
		tiers.append({"open": is_open, "taken": taken})
	_canvas.accent = _accent
	_canvas.tiers = tiers
	_canvas.custom_minimum_size.y = maxf(
		CANVAS_MINIMUM.y, _canvas.get_required_height()
	)
	_canvas.queue_redraw()
	# Positions come from the canvas geometry, so the hit areas can never drift
	# away from the diamonds they belong to.
	_canvas.call_deferred(&"queue_redraw")
	await get_tree().process_frame
	_place_nodes(character_id, level, chosen)


func _place_nodes(character_id: StringName, level: int, chosen: Array) -> void:
	if not is_instance_valid(_canvas):
		return
	for tier in range(1, SkillTree.TIER_COUNT + 1):
		var required := SkillTree.get_required_level_for_tier(tier)
		var is_open := level >= required
		var active_id := SkillTree.get_choice_for_tier(chosen, character_id, tier)
		var options := SkillTree.get_tier_options(character_id, tier)
		for option_index in options.size():
			var option: Dictionary = options[option_index]
			var side := -1 if option_index == 0 else 1
			_add_node(option, tier - 1, side, is_open, option["id"] == active_id, required)
		_add_tier_marker(tier - 1, required, is_open)


func _add_tier_marker(tier_index: int, required: int, is_open: bool) -> void:
	var marker := Label.new()
	marker.name = "TierMark%d" % tier_index
	marker.theme_type_variation = &"EyebrowLabel"
	marker.add_theme_font_size_override(&"font_size", 11)
	marker.text = "T%d" % (tier_index + 1) if is_open else "LV %d" % required
	marker.add_theme_color_override(
		&"font_color", _accent if is_open else LOCKED_COLOR
	)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(marker)
	marker.size = Vector2(64.0, 16.0)
	var centre := _canvas.get_tier_centre(tier_index)
	marker.position = centre + Vector2(-32.0, -34.0)


func _add_node(
	option: Dictionary,
	tier_index: int,
	side: int,
	is_open: bool,
	is_active: bool,
	required: int
) -> void:
	var node_id: StringName = option["id"]
	var centre := _canvas.get_node_centre(tier_index, side)
	var radius := SkillTreeCanvas.NODE_RADIUS

	# Transparent hit area over the drawn diamond.
	var button := Button.new()
	button.name = String(node_id)
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.size = Vector2(radius * 2.0, radius * 2.0)
	button.position = centre - Vector2(radius, radius)
	button.tooltip_text = "%s — %s" % [option["title"], option["description"]]
	button.disabled = not is_open
	_canvas.add_child(button)
	_node_buttons[node_id] = button

	var label := Label.new()
	label.name = "%s_label" % node_id
	label.add_theme_font_override(&"font", CARD_TITLE_FONT)
	label.add_theme_font_size_override(&"font_size", 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = String(option["title"]).to_upper()
	var colour := LOCKED_COLOR
	if is_active:
		colour = ACTIVE_COLOR
	elif is_open:
		colour = MUTED_COLOR
	label.add_theme_color_override(&"font_color", colour)
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT if side < 0 else HORIZONTAL_ALIGNMENT_LEFT
	)
	_canvas.add_child(label)
	label.size = Vector2(LABEL_WIDTH, 40.0)
	label.position = Vector2(
		centre.x - LABEL_WIDTH - LABEL_OFFSET if side < 0
		else centre.x + LABEL_OFFSET,
		centre.y - 20.0
	)

	if not is_open:
		button.mouse_entered.connect(
			_set_detail.bind(
				String(option["title"]).to_upper(),
				"Locked until level %d." % required
			)
		)
		return
	button.pressed.connect(_on_node_pressed.bind(node_id))
	var state := "ACTIVE — click to clear" if is_active else "click to take"
	button.mouse_entered.connect(
		_set_detail.bind(
			String(option["title"]).to_upper(),
			"%s\n%s" % [option["description"], state]
		)
	)
	button.focus_entered.connect(
		_set_detail.bind(
			String(option["title"]).to_upper(),
			"%s\n%s" % [option["description"], state]
		)
	)


func _set_detail(title: String, body: String) -> void:
	if not is_instance_valid(_detail_title):
		return
	_detail_title.text = title
	_detail_title.add_theme_color_override(&"font_color", _accent)
	_detail_body.text = body


func _build_status_text(character_id: StringName, level: int) -> String:
	var pending := SaveManager.get_pending_skill_choices(character_id)
	if pending > 0:
		return "LEVEL %d  •  %d %s WAITING" % [
			level, pending, "CHOICE" if pending == 1 else "CHOICES"
		]
	var next_level := SaveManager.get_next_skill_tier_level(character_id)
	if next_level > 0:
		return "LEVEL %d  •  NEXT TIER AT LEVEL %d" % [level, next_level]
	return "LEVEL %d  •  ALL TIERS OPEN  •  SWAP FREELY" % level


func _on_node_pressed(node_id: StringName) -> void:
	# set_skill_choice replaces the tier's pick, or clears it when the node
	# pressed is the one already active. It saves and re-emits, and
	# _on_skills_changed rebuilds the page.
	SaveManager.set_skill_choice(SaveManager.get_selected_character(), node_id)
