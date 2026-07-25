extends Marker3D

const RECRUIT_DATA: CharacterData = preload("res://data/characters/recruit.tres")
const RENEGADE_DATA: CharacterData = preload("res://data/characters/renegade.tres")
const MEDIC_DATA: CharacterData = preload("res://data/characters/medic.tres")


func _ready() -> void:
	var character_data := _get_selected_character_data()
	if character_data.character_scene == null:
		push_error("PlayerSpawner requires a character scene in CharacterData.")
		return

	var player := character_data.character_scene.instantiate() as CharacterBody3D
	if player == null:
		push_error("PlayerSpawner character scenes must use CharacterBody3D as root.")
		return
	if not player.has_method(&"configure_character"):
		push_error("Player scenes must implement configure_character(CharacterData).")
		return
	player.call(
		&"configure_character",
		character_data,
		SaveManager.get_primary_weapon(character_data.character_id),
		SaveManager.get_secondary_weapon(character_data.character_id)
	)
	add_child(player)


func _get_selected_character_data() -> CharacterData:
	var selected_character := SaveManager.get_selected_character()
	if (
		selected_character == RENEGADE_DATA.character_id
		and RENEGADE_DATA.is_selectable
		and SaveManager.is_character_unlocked(selected_character)
	):
		return RENEGADE_DATA
	if (
		selected_character == MEDIC_DATA.character_id
		and MEDIC_DATA.is_selectable
		and SaveManager.is_character_unlocked(selected_character)
	):
		return MEDIC_DATA
	return RECRUIT_DATA
