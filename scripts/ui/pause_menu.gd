extends Control

signal pause_changed(is_paused: bool)

const SETTINGS_SCENE := preload("res://scenes/menus/settings_menu.tscn")

@onready var panel_container: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

var _settings_overlay: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(resume_game)
	settings_button.pressed.connect(_open_settings)
	main_menu_button.pressed.connect(_open_main_menu)
	quit_button.pressed.connect(GameManager.quit_game)
	UiAnimations.enhance_buttons(self)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _is_settings_open():
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
	UiAnimations.slide_in_left(panel_container)
	pause_changed.emit(true)


func resume_game() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_changed.emit(false)


func _open_settings() -> void:
	if _is_settings_open():
		return
	_settings_overlay = SETTINGS_SCENE.instantiate() as Control
	if _settings_overlay == null:
		push_error("PauseMenu could not instantiate the settings menu.")
		return
	add_child(_settings_overlay)
	_settings_overlay.tree_exited.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	_settings_overlay = null
	if visible:
		resume_button.grab_focus()


func _is_settings_open() -> bool:
	return _settings_overlay != null and is_instance_valid(_settings_overlay)


func _open_main_menu() -> void:
	hide()
	GameManager.open_main_menu()
