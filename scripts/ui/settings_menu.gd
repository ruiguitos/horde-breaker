extends Control

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var back_button: Button = %BackButton
@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var background: ColorRect = $Background

var _available_resolutions: Array[Vector2i] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_window_modes()
	_load_current_values()
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	SettingsManager.display_settings_applied.connect(_on_display_settings_applied)
	vsync_check.toggled.connect(SettingsManager.set_vsync_enabled)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(_close)
	UiAnimations.enhance_buttons(self)
	back_button.grab_focus()
	background.modulate.a = 0.0
	panel_container.modulate.a = 0.0
	await get_tree().process_frame
	UiAnimations.fade_in(background, 0.0, 0.2)
	UiAnimations.pop_in(panel_container, 0.24)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	_close()
	get_viewport().set_input_as_handled()


func _populate_window_modes() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("Windowed")
	window_mode_option.add_item("Fullscreen")


func _populate_resolutions(selected_resolution: Vector2i) -> void:
	_available_resolutions.assign(RESOLUTIONS)
	if selected_resolution not in _available_resolutions:
		_available_resolutions.append(selected_resolution)
		_available_resolutions.sort_custom(
			func(a: Vector2i, b: Vector2i) -> bool:
				return a.x * a.y < b.x * b.y
		)
	resolution_option.clear()
	for resolution in _available_resolutions:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])


func _load_current_values() -> void:
	_refresh_display_controls()
	vsync_check.button_pressed = SettingsManager.is_vsync_enabled()
	sensitivity_slider.value = SettingsManager.get_mouse_sensitivity_multiplier()
	_update_sensitivity_value(sensitivity_slider.value)
	volume_slider.value = SettingsManager.get_master_volume() * 100.0
	_update_volume_value(volume_slider.value)


func _refresh_display_controls() -> void:
	var fullscreen := SettingsManager.is_fullscreen()
	var active_resolution := SettingsManager.get_active_resolution()
	window_mode_option.select(1 if fullscreen else 0)
	_populate_resolutions(active_resolution)
	resolution_option.select(_available_resolutions.find(active_resolution))
	resolution_option.disabled = fullscreen
	resolution_option.tooltip_text = (
		"Fullscreen uses the monitor's current resolution."
		if fullscreen
		else "The selected resolution is applied to the window immediately."
	)


func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_fullscreen(index == 1)
	_refresh_display_controls()


func _on_resolution_selected(index: int) -> void:
	if SettingsManager.is_fullscreen():
		return
	if index < 0 or index >= _available_resolutions.size():
		return
	SettingsManager.set_resolution(_available_resolutions[index])


func _on_display_settings_applied(
	_fullscreen: bool, _resolution: Vector2i
) -> void:
	_refresh_display_controls()


func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity_multiplier(value)
	_update_sensitivity_value(value)


func _on_volume_changed(value: float) -> void:
	SettingsManager.set_master_volume(value / 100.0)
	_update_volume_value(value)


func _update_sensitivity_value(value: float) -> void:
	sensitivity_value.text = "%.2f ×" % value


func _update_volume_value(value: float) -> void:
	volume_value.text = "%d %%" % roundi(value)


func _close() -> void:
	if get_tree().current_scene == self:
		GameManager.open_main_menu()
	else:
		queue_free()
