extends Control

const RECRUIT_ID := &"recruit"
const RENEGADE_ID := &"renegade"
const ASSAULT_RIFLE_ID := &"assault_rifle"
const SHOTGUN_ID := &"shotgun"
const WORN_SWORD_ID := &"worn_sword"

@onready var credits_label: Label = %CreditsLabel
@onready var selection_label: Label = %SelectionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var notice_label: Label = %NoticeLabel
@onready var start_button: Button = %StartButton
@onready var selection_button: Button = %SelectionButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	credits_label.text = "Credits: %d" % SaveManager.get_credits()
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
		notice_label.text = (
			"O Renegade já pode ser selecionado e movimentado. "
			+ "O combate de espada será implementado no Milestone 13."
		)
	else:
		notice_label.text = "O Recruit e a Assault Rifle estão prontos para jogar."


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
