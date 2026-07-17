extends Control

const WAVE_MANAGER_GROUP := &"wave_manager"

@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	restart_button.pressed.connect(_restart_current_scene)

	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager == null:
		push_error("WaveCompletePanel requires a node in the wave_manager group.")
		return
	if not wave_manager.has_signal(&"all_waves_completed"):
		push_error("WaveCompletePanel requires an all_waves_completed signal.")
		return
	wave_manager.connect(&"all_waves_completed", _show_victory)


func _show_victory() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	restart_button.grab_focus()
	get_tree().paused = true


func _restart_current_scene() -> void:
	get_tree().paused = false
	var reload_error := get_tree().reload_current_scene()
	if reload_error != OK:
		push_error("WaveCompletePanel could not reload the current scene.")
