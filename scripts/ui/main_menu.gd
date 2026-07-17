extends Control

const RECRUIT_ID := &"recruit"
const RENEGADE_ID := &"renegade"
const ASSAULT_RIFLE_ID := &"assault_rifle"
const SHOTGUN_ID := &"shotgun"
const WORN_SWORD_ID := &"worn_sword"
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
	SaveManager.selected_weapon_changed.connect(_on_selected_weapon_changed)
	_refresh()
	start_button.grab_focus()


func _refresh() -> void:
	var character_id := SaveManager.get_selected_character()
	var weapon_id := SaveManager.get_selected_weapon(character_id)
	var level := SaveManager.get_character_level(character_id)
	var xp := SaveManager.get_character_xp(character_id)
	var test_suffix := " — TESTE" if _using_test_progress else ""
	credits_label.text = "Credits: %d%s" % [SaveManager.get_credits(), test_suffix]
	selection_label.text = "Personagem: %s    Arma: %s" % [
		_get_character_name(character_id), _get_weapon_name(weapon_id)
	]
	if level >= 10:
		progress_label.text = "Nível %d — máximo" % level
	else:
		progress_label.text = "Nível %d — XP %d / %d" % [
			level, xp, SaveManager.get_xp_required_for_next_level(level)
		]
	if character_id == RENEGADE_ID:
		notice_label.text = "O Renegade e a Worn Sword estão prontos para jogar."
	else:
		notice_label.text = "O Recruit e a Assault Rifle estão prontos para jogar."


func _load_test_progress_if_enabled() -> void:
	if not ENABLE_TEST_PROGRESS or not OS.has_feature("editor"):
		return
	var should_seed_profile := not FileAccess.file_exists(TEST_SAVE_PATH)
	SaveManager.load_progress(TEST_SAVE_PATH)
	_using_test_progress = true
	if should_seed_profile:
		SaveManager.add_credits(TEST_STARTING_CREDITS)
		SaveManager.add_character_xp(RECRUIT_ID, TEST_RECRUIT_XP)


func _get_character_name(character_id: StringName) -> String:
	return "Renegade" if character_id == RENEGADE_ID else "Recruit"


func _get_weapon_name(weapon_id: StringName) -> String:
	if weapon_id == SHOTGUN_ID:
		return "Shotgun"
	if weapon_id == WORN_SWORD_ID:
		return "Worn Sword"
	return "Assault Rifle"


func _on_credits_changed(_credits: int) -> void:
	_refresh()


func _on_selected_character_changed(_character_id: StringName) -> void:
	_refresh()


func _on_selected_weapon_changed(
	_character_id: StringName, _weapon_id: StringName
) -> void:
	_refresh()
