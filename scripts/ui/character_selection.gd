extends Control

const RECRUIT_DATA: CharacterData = preload("res://data/characters/recruit.tres")
const RENEGADE_DATA: CharacterData = preload("res://data/characters/renegade.tres")
const MEDIC_DATA: CharacterData = preload("res://data/characters/medic.tres")
const SELECTED_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const UNLOCKED_COLOR := Color(0.44, 0.82, 0.59, 1.0)
const LOCKED_COLOR := Color(0.62, 0.665, 0.7, 1.0)

@onready var credits_label: Label = %CreditsLabel
@onready var recruit_panel: PanelContainer = %RecruitPanel
@onready var recruit_stats_label: Label = %RecruitStatsLabel
@onready var recruit_progress_label: Label = %RecruitProgressLabel
@onready var recruit_status_label: Label = %RecruitStatusLabel
@onready var recruit_button: Button = %RecruitButton
@onready var renegade_panel: PanelContainer = %RenegadePanel
@onready var renegade_stats_label: Label = %RenegadeStatsLabel
@onready var renegade_progress_label: Label = %RenegadeProgressLabel
@onready var renegade_status_label: Label = %RenegadeStatusLabel
@onready var renegade_button: Button = %RenegadeButton
@onready var medic_panel: PanelContainer = %MedicPanel
@onready var medic_stats_label: Label = %MedicStatsLabel
@onready var medic_progress_label: Label = %MedicProgressLabel
@onready var medic_status_label: Label = %MedicStatusLabel
@onready var medic_button: Button = %MedicButton
@onready var weapon_context_label: Label = %WeaponContextLabel
@onready var primary_weapon_label: Label = %PrimaryWeaponLabel
@onready var secondary_weapon_label: Label = %SecondaryWeaponLabel
@onready var back_button: Button = %BackButton
@onready var skill_tree_button: Button = %SkillTreeButton
@onready var armory_button: Button = %ArmoryButton
@onready var character_preview: Node3D = %CharacterPreview
@onready var roster_count_label: Label = %RosterCountLabel
@onready var roster_selection_label: Label = %RosterSelectionLabel

var _displayed_credits := 0
var _variant_label: Label
var _variant_button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_unselectable_classes()
	back_button.pressed.connect(GameManager.open_main_menu)
	skill_tree_button.pressed.connect(GameManager.open_skill_tree)
	armory_button.pressed.connect(GameManager.open_armory)
	recruit_button.pressed.connect(_on_character_pressed.bind(RECRUIT_DATA))
	renegade_button.pressed.connect(_on_character_pressed.bind(RENEGADE_DATA))
	medic_button.pressed.connect(_on_character_pressed.bind(MEDIC_DATA))
	SaveManager.credits_changed.connect(_on_save_changed)
	SaveManager.character_progress_changed.connect(_on_character_progress_changed)
	SaveManager.character_purchased.connect(_on_character_purchased)
	SaveManager.selected_character_changed.connect(_on_selected_character_changed)
	SaveManager.variant_changed.connect(_on_variant_changed)
	_build_variant_row()
	_refresh()
	back_button.grab_focus()
	UiAnimations.enhance_buttons(self)
	$PageMargin/Content/TopBar.modulate.a = 0.0
	$PageMargin/Content/Characters.modulate.a = 0.0
	$PageMargin/Content/LoadoutPanel.modulate.a = 0.0
	await get_tree().process_frame
	UiAnimations.slide_fade_in(
		$PageMargin/Content/TopBar, Vector2(0.0, -18.0), 0.0
	)
	UiAnimations.slide_fade_in(
		$PageMargin/Content/Characters, Vector2(-24.0, 0.0), 0.08
	)
	UiAnimations.slide_fade_in(
		$PageMargin/Content/LoadoutPanel, Vector2(0.0, 18.0), 0.16
	)


func _refresh() -> void:
	roster_count_label.text = "ROSTER  //  %02d ACTIVE OPERATIVES" % (
		3 if MEDIC_DATA.is_selectable else 2
	)
	var credits := SaveManager.get_credits()
	UiAnimations.count_integer(
		credits_label, _displayed_credits, credits, "CREDITS  ·  "
	)
	_displayed_credits = credits
	_configure_character(
		RECRUIT_DATA,
		recruit_panel,
		recruit_stats_label,
		recruit_progress_label,
		recruit_status_label,
		recruit_button
	)
	_configure_character(
		RENEGADE_DATA,
		renegade_panel,
		renegade_stats_label,
		renegade_progress_label,
		renegade_status_label,
		renegade_button
	)
	if MEDIC_DATA.is_selectable:
		_configure_character(
			MEDIC_DATA,
			medic_panel,
			medic_stats_label,
			medic_progress_label,
			medic_status_label,
			medic_button
		)

	var selected_data := SaveManager.get_character_data(
		SaveManager.get_selected_character()
	)
	if selected_data == null:
		return
	roster_selection_label.text = "SELECTED  //  %s" % (
		selected_data.display_name.to_upper()
	)
	character_preview.call(&"show_character", selected_data.character_id)
	weapon_context_label.text = "%s  —  %s\n%s" % [
		selected_data.display_name,
		selected_data.class_description,
		_get_mastery_detail(selected_data.character_id),
	]
	primary_weapon_label.text = _get_weapon_name(
		SaveManager.get_primary_weapon(selected_data.character_id)
	)
	secondary_weapon_label.text = _get_weapon_name(
		SaveManager.get_secondary_weapon(selected_data.character_id)
	)
	_refresh_variant_row(selected_data.character_id)


func _unhandled_input(event: InputEvent) -> void:
	# Esc mirrors the BACK button, like every other menu page.
	if event.is_action_pressed(&"ui_cancel"):
		GameManager.open_main_menu()
		get_viewport().set_input_as_handled()


func _hide_unselectable_classes() -> void:
	# The squad is Recruit + Renegade for now. A class parked with
	# `is_selectable = false` keeps its data, save entries and scenes, but never
	# reaches the roster — and a save that still points at it falls back.
	if MEDIC_DATA.is_selectable:
		return
	medic_panel.visible = false
	if SaveManager.get_selected_character() == MEDIC_DATA.character_id:
		SaveManager.select_character(RECRUIT_DATA.character_id)


func _build_variant_row() -> void:
	# The variant controls live under the class context in the loadout panel;
	# built in code so the scene keeps its current layout untouched.
	var context := weapon_context_label.get_parent()
	var row := HBoxContainer.new()
	row.name = "VariantRow"
	row.add_theme_constant_override(&"separation", 16)
	_variant_label = Label.new()
	_variant_label.theme_type_variation = &"MutedLabel"
	_variant_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_variant_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_variant_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_variant_label)
	_variant_button = Button.new()
	_variant_button.custom_minimum_size = Vector2(190, 36)
	_variant_button.pressed.connect(_on_variant_button_pressed)
	row.add_child(_variant_button)
	context.add_child(row)


func _refresh_variant_row(character_id: StringName) -> void:
	if _variant_label == null:
		return
	var variant := CharacterVariants.get_variant(character_id)
	var row := _variant_label.get_parent() as Control
	if variant.is_empty():
		row.visible = false
		return
	row.visible = true
	var variant_name := String(variant["name"])
	if not SaveManager.is_variant_unlocked(character_id):
		_variant_label.text = (
			"VARIANT %s  —  complete all mastery objectives to unlock."
			% variant_name
		)
		_variant_button.text = "LOCKED"
		_variant_button.disabled = true
		_variant_button.remove_theme_color_override(&"font_color")
		return
	var is_active := SaveManager.is_variant_active(character_id)
	_variant_label.text = "VARIANT %s  —  %s" % [
		variant_name, String(variant["description"])
	]
	_variant_button.disabled = false
	_variant_button.text = (
		"%s: ON" % variant_name if is_active else "%s: OFF" % variant_name
	)
	if is_active:
		_variant_button.add_theme_color_override(&"font_color", SELECTED_COLOR)
	else:
		_variant_button.remove_theme_color_override(&"font_color")


func _on_variant_button_pressed() -> void:
	var character_id := SaveManager.get_selected_character()
	SaveManager.set_variant_active(
		character_id, not SaveManager.is_variant_active(character_id)
	)


func _on_variant_changed(_character_id: StringName) -> void:
	_refresh()


func _configure_character(
	character_data: CharacterData,
	panel: PanelContainer,
	stats_label: Label,
	progress_label: Label,
	status_label: Label,
	button: Button
) -> void:
	stats_label.text = "HEALTH %d  //  RELOAD +%d%%  //  REGEN %.1f/S" % [
		roundi(character_data.base_health),
		roundi((1.0 - character_data.reload_duration_multiplier) * 100.0),
		character_data.health_regeneration_rate,
	]
	progress_label.text = _get_progress_text(character_data)
	_build_identity_block(panel, character_data)
	var character_id := character_data.character_id
	var is_unlocked := SaveManager.is_character_unlocked(character_id)
	var is_selected := SaveManager.get_selected_character() == character_id
	panel.theme_type_variation = &"SelectedCard" if is_selected else &"CardPanel"
	if is_selected:
		status_label.text = "SELECTED"
		status_label.add_theme_color_override(&"font_color", SELECTED_COLOR)
		button.text = "SELECTED"
		button.disabled = true
		return
	if is_unlocked:
		status_label.text = "UNLOCKED"
		status_label.add_theme_color_override(&"font_color", UNLOCKED_COLOR)
		button.text = "SELECT"
		button.disabled = false
		return
	status_label.text = "LOCKED  •  %d CREDITS" % character_data.unlock_cost
	status_label.add_theme_color_override(&"font_color", LOCKED_COLOR)
	button.text = "UNLOCK  ·  %d" % character_data.unlock_cost
	button.disabled = not SaveManager.can_purchase_character(character_data)


## Fills the empty middle of a class card with what actually distinguishes the
## class: how far its skill tree has been taken, which capstone is running, and
## the loadout it fights with.
##
## The card used to jump straight from the base profile to the level line, with
## roughly a third of its height blank — so three operatives sitting side by side
## showed almost nothing to choose between them.
func _build_identity_block(panel: PanelContainer, character_data: CharacterData) -> void:
	var content := panel.get_node_or_null("Margin/Content") as VBoxContainer
	if content == null:
		return
	var spacer := content.get_node_or_null("Spacer") as Control
	var existing := content.get_node_or_null("ClassIdentity")
	if existing != null:
		content.remove_child(existing)
		existing.queue_free()

	var character_id := character_data.character_id
	var colour := UiVisualCatalog.get_character_color(character_id)
	var block := VBoxContainer.new()
	block.name = "ClassIdentity"
	block.add_theme_constant_override(&"separation", 6)
	content.add_child(block)
	if spacer != null:
		content.move_child(block, spacer.get_index())

	block.add_child(_build_caption("SKILLS", colour))
	block.add_child(_build_tier_pips(character_id, colour))
	block.add_child(_build_body_label(_get_capstone_text(character_id)))

	block.add_child(_build_caption("LOADOUT", colour))
	block.add_child(_build_loadout_row(character_data))

	# Mastery was only ever shown for the operative already selected, at the
	# bottom of the page — which is the one case where you do not need it. Put
	# on the cards it becomes the third thing you can compare across the roster.
	block.add_child(_build_caption("MASTERY", colour))
	block.add_child(_build_body_label(_get_mastery_objectives(character_id)))
	# The spacer keeps doing its job — pushing the level and the button to the
	# bottom — it just has far less room to give away now.
	if spacer != null:
		spacer.custom_minimum_size.y = 0.0
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _build_caption(text: String, colour: Color) -> Label:
	var caption := Label.new()
	caption.theme_type_variation = &"EyebrowLabel"
	caption.add_theme_color_override(&"font_color", colour)
	caption.text = text
	return caption


func _build_body_label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.add_theme_font_size_override(&"font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	return label


## One mark per tier: filled when a side has been taken, outlined when the tier
## is open and waiting, dark when the level for it has not been reached.
func _build_tier_pips(character_id: StringName, colour: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var level := SaveManager.get_character_level(character_id)
	var chosen := Array(SaveManager.get_skill_choices(character_id))
	for tier in range(1, SkillTree.TIER_COUNT + 1):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22.0, 5.0)
		var is_open := level >= SkillTree.get_required_level_for_tier(tier)
		var taken := SkillTree.get_choice_for_tier(chosen, character_id, tier) != &""
		if taken:
			pip.color = colour
		elif is_open:
			pip.color = colour * Color(1.0, 1.0, 1.0, 0.38)
		else:
			pip.color = Color(0.22, 0.25, 0.29, 1.0)
		row.add_child(pip)
	return row


func _get_capstone_text(character_id: StringName) -> String:
	if not SkillTree.has_tree(character_id):
		return "No skill tree yet."
	var chosen := Array(SaveManager.get_skill_choices(character_id))
	var capstone := SkillTree.get_choice_for_tier(
		chosen, character_id, SkillTree.TIER_COUNT
	)
	if capstone != &"":
		var node := SkillTree.get_node_definition(capstone)
		return "%s — %s" % [String(node["title"]).to_upper(), node["description"]]
	var pending := SaveManager.get_pending_skill_choices(character_id)
	if pending > 0:
		return "%d %s waiting." % [
			pending, "choice" if pending == 1 else "choices"
		]
	var required := SkillTree.get_required_level_for_tier(SkillTree.TIER_COUNT)
	return "Defining skill unlocks at level %d." % required


func _build_loadout_row(character_data: CharacterData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	for entry in [
		{"slot": "1", "weapon": character_data.primary_weapon_id},
		{"slot": "2", "weapon": character_data.secondary_weapon_id},
	]:
		var weapon_id := StringName(entry["weapon"])
		var slot := HBoxContainer.new()
		slot.add_theme_constant_override(&"separation", 6)
		var icon := TextureRect.new()
		icon.texture = UiVisualCatalog.get_weapon_icon(weapon_id)
		icon.custom_minimum_size = Vector2(26.0, 26.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)
		var label := Label.new()
		label.theme_type_variation = &"MutedLabel"
		label.add_theme_font_size_override(&"font_size", 13)
		label.text = "[%s] %s" % [entry["slot"], _get_weapon_name(weapon_id)]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(label)
		row.add_child(slot)
	return row


func _get_progress_text(character_data: CharacterData) -> String:
	var level := SaveManager.get_character_level(character_data.character_id)
	var xp := SaveManager.get_character_xp(character_data.character_id)
	return "LV %d  •  XP %d/%d  •  %s" % [
		level,
		xp,
		SaveManager.get_xp_required_for_next_level(level),
		_get_mastery_summary(character_data.character_id),
	]


func _get_mastery_summary(character_id: StringName) -> String:
	var completed := 0
	for objective_id in CharacterMastery.OBJECTIVES:
		if SaveManager.is_mastery_completed(character_id, objective_id):
			completed += 1
	return "MASTERY %d/%d" % [completed, CharacterMastery.OBJECTIVES.size()]


func _get_mastery_detail(character_id: StringName) -> String:
	return "MASTERY  ·  " + _get_mastery_objectives(character_id)


## The objectives on their own, for the class cards, which put their own heading
## above them and do not want the word twice.
func _get_mastery_objectives(character_id: StringName) -> String:
	var parts: PackedStringArray = []
	for objective_id in CharacterMastery.OBJECTIVES:
		var objective := CharacterMastery.get_objective(objective_id)
		parts.append("%s %d/%d" % [
			String(objective["name"]),
			SaveManager.get_mastery_progress(character_id, objective_id),
			int(objective["goal"]),
		])
	return "  ·  ".join(parts)


func _get_weapon_name(weapon_id: StringName) -> String:
	var weapon_data := WeaponCatalog.get_weapon_data(weapon_id)
	return weapon_data.display_name if weapon_data != null else "—"


func _on_character_pressed(character_data: CharacterData) -> void:
	if SaveManager.is_character_unlocked(character_data.character_id):
		SaveManager.select_character(character_data.character_id)
	else:
		if SaveManager.purchase_character(character_data):
			SaveManager.select_character(character_data.character_id)
	_refresh()


func _on_save_changed(_value: int) -> void:
	_refresh()


func _on_character_progress_changed(
	_character_id: StringName, _level: int, _xp: int
) -> void:
	_refresh()


func _on_character_purchased(_character_id: StringName) -> void:
	_refresh()


func _on_selected_character_changed(_character_id: StringName) -> void:
	_refresh()
