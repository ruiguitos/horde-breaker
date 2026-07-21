extends Control

const PLAYER_GROUP := &"player"

@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var message_label: Label = %Message
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	restart_button.pressed.connect(_restart_current_scene)
	main_menu_button.pressed.connect(GameManager.open_main_menu)

	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		push_error("GameOverPanel requires a node in the player group.")
		return
	if not player.has_signal(&"died"):
		push_error("GameOverPanel requires the player to expose a died signal.")
		return
	player.connect(&"died", _show_player_defeat)


func _show_player_defeat() -> void:
	_show_game_over(
		"A horda derrubou o teu operacional.\nReagrupa e volta a tentar."
	)


func _show_game_over(message: String) -> void:
	if visible:
		return
	message_label.text = message
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	restart_button.grab_focus()
	get_tree().paused = true
	UiAnimations.pop_in(panel_container)


func _restart_current_scene() -> void:
	get_tree().paused = false
	var reload_error := get_tree().reload_current_scene()
	if reload_error != OK:
		push_error("GameOverPanel could not reload the current scene.")
