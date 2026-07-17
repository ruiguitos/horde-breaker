extends Node

const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const CHARACTER_SELECTION_SCENE := "res://scenes/menus/character_selection.tscn"
const TEST_ARENA_SCENE := "res://scenes/world/test_arena.tscn"


func open_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func open_character_selection() -> void:
	_change_scene(CHARACTER_SELECTION_SCENE)


func start_game() -> void:
	_change_scene(TEST_ARENA_SCENE)


func quit_game() -> void:
	get_tree().quit()


func _change_scene(scene_path: String) -> void:
	get_tree().paused = false
	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error("GameManager could not open scene: %s" % scene_path)
