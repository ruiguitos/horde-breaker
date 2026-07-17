extends Control

signal pause_changed(is_paused: bool)

@onready var resume_button: Button = %ResumeButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(resume_game)
	main_menu_button.pressed.connect(_open_main_menu)
	quit_button.pressed.connect(GameManager.quit_game)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		resume_game()
	elif not get_tree().paused:
		pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	if get_tree().paused:
		return
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()
	pause_changed.emit(true)


func resume_game() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_changed.emit(false)


func _open_main_menu() -> void:
	hide()
	GameManager.open_main_menu()
