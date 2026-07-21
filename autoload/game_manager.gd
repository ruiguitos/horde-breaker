extends Node

const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const CHARACTER_SELECTION_SCENE := "res://scenes/menus/character_selection.tscn"
const SETTINGS_SCENE := "res://scenes/menus/settings_menu.tscn"
const TEST_ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const FADE_OUT_DURATION := 0.18
const FADE_IN_DURATION := 0.3

var _fade_rect: ColorRect
var _is_transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_fade_overlay()


func open_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func open_character_selection() -> void:
	_change_scene(CHARACTER_SELECTION_SCENE)


func open_settings() -> void:
	_change_scene(SETTINGS_SCENE)


func start_game() -> void:
	_change_scene(TEST_ARENA_SCENE)


func quit_game() -> void:
	get_tree().quit()


func _change_scene(scene_path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_to(1.0, FADE_OUT_DURATION)
	get_tree().paused = false
	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error("GameManager could not open scene: %s" % scene_path)
	await _fade_to(0.0, FADE_IN_DURATION)
	_is_transitioning = false


func _create_fade_overlay() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade_rect)
	add_child(fade_layer)


func _fade_to(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", target_alpha, duration)
	await tween.finished
