extends Control

const RECRUIT_DATA: CharacterData = preload("res://data/characters/recruit.tres")
const RENEGADE_DATA: CharacterData = preload("res://data/characters/renegade.tres")
const MEDIC_DATA: CharacterData = preload("res://data/characters/medic.tres")
const SELECTED_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const UNLOCKED_COLOR := Color(0.44, 0.82, 0.59, 1.0)
const LOCKED_COLOR := Color(0.62, 0.665, 0.7, 1.0)

@onready var credits_label: Label = %CreditsLabel
@onready var recruit_panel: PanelContainer = %RecruitPanel
@onready var recruit_progress_label: Label = %RecruitProgressLabel
@onready var recruit_status_label: Label = %RecruitStatusLabel
@onready var recruit_button: Button = %RecruitButton
@onready var renegade_panel: PanelContainer = %RenegadePanel
@onready var renegade_progress_label: Label = %RenegadeProgressLabel
@onready var renegade_status_label: Label = %RenegadeStatusLabel
@onready var renegade_button: Button = %RenegadeButton
@onready var medic_panel: PanelContainer = %MedicPanel
@onready var medic_progress_label: Label = %MedicProgressLabel
@onready var medic_status_label: Label = %MedicStatusLabel
@onready var medic_button: Button = %MedicButton
@onready var weapon_context_label: Label = %WeaponContextLabel
@onready var primary_weapon_label: Label = %PrimaryWeaponLabel
@onready var secondary_weapon_label: Label = %SecondaryWeaponLabel
@onready var back_button: Button = %BackButton
@onready var skill_tree_button: Button = %SkillTreeButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(GameManager.open_main_menu)
	skill_tree_button.pressed.connect(GameManager.open_skill_tree)
	recruit_button.pressed.connect(_on_character_pressed.bind(RECRUIT_DATA))
	renegade_button.pressed.connect(_on_character_pressed.bind(RENEGADE_DATA))
	medic_button.pressed.connect(_on_character_pressed.bind(MEDIC_DATA))
	SaveManager.credits_changed.connect(_on_save_changed)
	SaveManager.character_progress_changed.connect(_on_character_progress_changed)
	SaveManager.character_purchased.connect(_on_character_purchased)
	SaveManager.selected_character_changed.connect(_on_selected_character_changed)
	_refresh()
	back_button.grab_focus()
	UiAnimations.fade_in($PageMargin/Content/TopBar, 0.0)
	UiAnimations.fade_in($PageMargin/Content/Characters, 0.1)
	UiAnimations.fade_in($PageMargin/Content/LoadoutPanel, 0.2)


func _refresh() -> void:
	credits_label.text = "CREDITS  ·  %d" % SaveManager.get_credits()
	_configure_character(
		RECRUIT_DATA,
		recruit_panel,
		recruit_progress_label,
		recruit_status_label,
		recruit_button
	)
	_configure_character(
		RENEGADE_DATA,
		renegade_panel,
		renegade_progress_label,
		renegade_status_label,
		renegade_button
	)
	_configure_character(
		MEDIC_DATA,
		medic_panel,
		medic_progress_label,
		medic_status_label,
		medic_button
	)

	var selected_data := SaveManager.get_character_data(
		SaveManager.get_selected_character()
	)
	if selected_data == null:
		return
	weapon_context_label.text = "%s  —  %s" % [
		selected_data.display_name, selected_data.class_description
	]
	primary_weapon_label.text = _get_weapon_name(
		selected_data.primary_weapon_id
	)
	secondary_weapon_label.text = _get_weapon_name(
		selected_data.secondary_weapon_id
	)


func _configure_character(
	character_data: CharacterData,
	panel: PanelContainer,
	progress_label: Label,
	status_label: Label,
	button: Button
) -> void:
	progress_label.text = _get_progress_text(character_data)
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


func _get_progress_text(character_data: CharacterData) -> String:
	var level := SaveManager.get_character_level(character_data.character_id)
	var xp := SaveManager.get_character_xp(character_data.character_id)
	return "LEVEL %d  •  XP %d / %d" % [
		level, xp, SaveManager.get_xp_required_for_next_level(level)
	]


func _get_weapon_name(weapon_id: StringName) -> String:
	if weapon_id == &"assault_rifle":
		return "Assault Rifle"
	if weapon_id == &"pistol":
		return "Pistol"
	if weapon_id == &"shotgun":
		return "Shotgun"
	if weapon_id == &"worn_sword":
		return "Worn Sword"
	return "—"


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
