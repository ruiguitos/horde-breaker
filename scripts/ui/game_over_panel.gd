extends Control

const PLAYER_GROUP := &"player"
const CAMP_CORE_GROUP := &"camp_core"

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

	var camp_core := get_tree().get_first_node_in_group(CAMP_CORE_GROUP)
	if camp_core == null:
		push_error("GameOverPanel requires a node in the camp_core group.")
		return
	if not camp_core.has_signal(&"destroyed"):
		push_error("GameOverPanel requires the camp core to expose a destroyed signal.")
		return
	camp_core.connect(&"destroyed", _show_camp_defeat)


func _show_player_defeat() -> void:
	_show_game_over(
		"A horda derrubou o teu operacional.\nReagrupa e volta a tentar."
	)


func _show_camp_defeat() -> void:
	_show_game_over(
		"O núcleo do acampamento foi destruído.\nA posição deixou de ser defensável."
	)


func _show_game_over(message: String) -> void:
	if visible:
		return
	message_label.text = message
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	restart_button.grab_focus()
	get_tree().paused = true


func _restart_current_scene() -> void:
	get_tree().paused = false
	var reload_error := get_tree().reload_current_scene()
	if reload_error != OK:
		push_error("GameOverPanel could not reload the current scene.")
