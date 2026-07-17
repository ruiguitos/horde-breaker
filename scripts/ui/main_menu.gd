extends Control

const RECRUIT_ID := &"recruit"
const ENABLE_TEST_PROGRESS := true
const TEST_SAVE_PATH := "user://horde_breaker_test.cfg"
const TEST_STARTING_CREDITS := 2000
const TEST_RECRUIT_XP := 700

@onready var credits_label: Label = %CreditsLabel
@onready var selection_label: Label = %SelectionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var notice_label: Label = %NoticeLabel
@onready var start_button: Button = %StartButton
@onready var selection_button: Button = %SelectionButton
@onready var quit_button: Button = %QuitButton

var _using_test_progress := false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_load_test_progress_if_enabled()
	start_button.pressed.connect(GameManager.start_game)
	selection_button.pressed.connect(GameManager.open_character_selection)
	quit_button.pressed.connect(GameManager.quit_game)
	SaveManager.credits_changed.connect(_on_credits_changed)
	SaveManager.selected_character_changed.connect(_on_selected_character_changed)
	_refresh()
	start_button.grab_focus()


func _refresh() -> void:
	var character_id := SaveManager.get_selected_character()
	var character_data := SaveManager.get_character_data(character_id)
	if character_data == null:
		push_error("MainMenu could not find the selected CharacterData.")
		return
	var level := SaveManager.get_character_level(character_id)
	var xp := SaveManager.get_character_xp(character_id)
	var test_suffix := "  ·  TESTE" if _using_test_progress else ""
	credits_label.text = "CREDITS  ·  %d%s" % [SaveManager.get_credits(), test_suffix]
	selection_label.text = "%s\n[1] %s   •   [2] %s" % [
		character_data.display_name,
		_get_weapon_name(character_data.primary_weapon_id),
		_get_weapon_name(character_data.secondary_weapon_id),
	]
	if level >= 10:
		progress_label.text = "NÍVEL %d  •  MÁXIMO" % level
	else:
		progress_label.text = "NÍVEL %d  •  XP %d / %d" % [
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
	if weapon_id == &"assault_rifle":
		return "Assault Rifle"
	if weapon_id == &"pistol":
		return "Pistol"
	if weapon_id == &"shotgun":
		return "Shotgun"
	if weapon_id == &"worn_sword":
		return "Worn Sword"
	return "—"


func _on_credits_changed(_credits: int) -> void:
	_refresh()


func _on_selected_character_changed(_character_id: StringName) -> void:
	_refresh()
