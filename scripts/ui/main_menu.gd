extends Control

const RECRUIT_ID := &"recruit"
# The editor test profile now starts from a clean slate (level 1, 0 Credits)
# so the game can be playtested from scratch. Raise these to seed a head start.
const ENABLE_TEST_PROGRESS := true
const TEST_SAVE_PATH := "user://horde_breaker_test.cfg"
const TEST_STARTING_CREDITS := 0
const TEST_RECRUIT_XP := 0

@onready var credits_label: Label = %CreditsLabel
@onready var selection_label: Label = %SelectionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var notice_label: Label = %NoticeLabel
@onready var start_button: Button = %StartButton
@onready var selection_button: Button = %SelectionButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

var _using_test_progress := false
var _displayed_credits := 0


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_load_test_progress_if_enabled()
	start_button.pressed.connect(GameManager.start_game)
	selection_button.pressed.connect(GameManager.open_character_selection)
	settings_button.pressed.connect(GameManager.open_settings)
	quit_button.pressed.connect(GameManager.quit_game)
	SaveManager.credits_changed.connect(_on_credits_changed)
	SaveManager.selected_character_changed.connect(_on_selected_character_changed)
	_refresh()
	start_button.grab_focus()
	UiAnimations.enhance_buttons(self)
	%BrandColumn.modulate.a = 0.0
	%SummaryColumn.modulate.a = 0.0
	await get_tree().process_frame
	UiAnimations.slide_fade_in(%BrandColumn, Vector2(-28.0, 0.0), 0.0)
	UiAnimations.slide_fade_in(%SummaryColumn, Vector2(28.0, 0.0), 0.1)


func _refresh() -> void:
	var character_id := SaveManager.get_selected_character()
	var character_data := SaveManager.get_character_data(character_id)
	if character_data == null:
		push_error("MainMenu could not find the selected CharacterData.")
		return
	var level := SaveManager.get_character_level(character_id)
	var xp := SaveManager.get_character_xp(character_id)
	var test_suffix := "  ·  TEST" if _using_test_progress else ""
	var credits := SaveManager.get_credits()
	UiAnimations.count_integer(
		credits_label,
		_displayed_credits,
		credits,
		"CREDITS  ·  ",
		test_suffix
	)
	_displayed_credits = credits
	var primary_weapon_id := SaveManager.get_primary_weapon(character_id)
	var secondary_weapon_id := SaveManager.get_secondary_weapon(character_id)
	selection_label.text = "%s\n[1] %s   •   [2] %s" % [
		character_data.display_name,
		_get_weapon_name(primary_weapon_id),
		_get_weapon_name(secondary_weapon_id),
	]
	var available_points := SaveManager.get_available_skill_points(character_id)
	if available_points > 0:
		progress_label.text = "LEVEL %d  •  %d SKILL POINTS" % [level, available_points]
	else:
		progress_label.text = "LEVEL %d  •  XP %d / %d" % [
			level, xp, SaveManager.get_xp_required_for_next_level(level)
		]
	notice_label.text = character_data.class_description


func _load_test_progress_if_enabled() -> void:
	if not ENABLE_TEST_PROGRESS or not OS.has_feature("editor"):
		return
	var should_seed_profile := not FileAccess.file_exists(TEST_SAVE_PATH)
	SaveManager.load_progress(TEST_SAVE_PATH)
	_using_test_progress = true
	if should_seed_profile:
		SaveManager.add_credits(TEST_STARTING_CREDITS)
		SaveManager.add_character_xp(RECRUIT_ID, TEST_RECRUIT_XP)


func _get_weapon_name(weapon_id: StringName) -> String:
	var weapon_data := WeaponCatalog.get_weapon_data(weapon_id)
	return weapon_data.display_name if weapon_data != null else "—"


func _on_credits_changed(_credits: int) -> void:
	_refresh()


func _on_selected_character_changed(_character_id: StringName) -> void:
	_refresh()
