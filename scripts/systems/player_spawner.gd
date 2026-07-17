extends Marker3D

const RECRUIT_DATA: CharacterData = preload("res://data/characters/recruit.tres")
const RENEGADE_DATA: CharacterData = preload("res://data/characters/renegade.tres")


func _ready() -> void:
	var character_data := _get_selected_character_data()
	if character_data.character_scene == null:
		push_error("PlayerSpawner requires a character scene in CharacterData.")
		return

	var player := character_data.character_scene.instantiate() as CharacterBody3D
	if player == null:
		push_error("PlayerSpawner character scenes must use CharacterBody3D as root.")
		return
	add_child(player)


func _get_selected_character_data() -> CharacterData:
	var selected_character := SaveManager.get_selected_character()
	if (
		selected_character == RENEGADE_DATA.character_id
		and SaveManager.is_character_unlocked(selected_character)
	):
		return RENEGADE_DATA
	return RECRUIT_DATA
