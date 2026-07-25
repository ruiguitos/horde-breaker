extends Control

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const REBIND_ARM_DELAY_MSEC := 150
const BINDINGS_HINT_DEFAULT := (
	"Click a binding, then press the new key or mouse button. Esc cancels."
)

@onready var display_tab: Button = %DisplayTab
@onready var controls_tab: Button = %ControlsTab
@onready var audio_tab: Button = %AudioTab
@onready var display_page: VBoxContainer = %DisplayPage
@onready var controls_page: VBoxContainer = %ControlsPage
@onready var audio_page: VBoxContainer = %AudioPage
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue
@onready var bindings_hint: Label = %BindingsHint
@onready var bindings_list: VBoxContainer = %BindingsList
@onready var reset_bindings_button: Button = %ResetBindingsButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var back_button: Button = %BackButton
@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var background: ColorRect = $Background

var _available_resolutions: Array[Vector2i] = []
var _binding_buttons: Dictionary[StringName, Button] = {}
var _awaiting_action: StringName = &""
var _rebind_armed_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_window_modes()
	_build_binding_rows()
	_load_current_values()
	display_tab.pressed.connect(_show_page.bind(0))
	controls_tab.pressed.connect(_show_page.bind(1))
	audio_tab.pressed.connect(_show_page.bind(2))
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	SettingsManager.display_settings_applied.connect(_on_display_settings_applied)
	SettingsManager.bindings_changed.connect(_refresh_binding_buttons)
	vsync_check.toggled.connect(SettingsManager.set_vsync_enabled)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	reset_bindings_button.pressed.connect(_on_reset_bindings_pressed)
	back_button.pressed.connect(_close)
	UiAnimations.enhance_buttons(self)
	_show_page(0)
	back_button.grab_focus()
	background.modulate.a = 0.0
	panel_container.modulate.a = 0.0
	await get_tree().process_frame
	UiAnimations.fade_in(background, 0.0, 0.2)
	UiAnimations.pop_in(panel_container, 0.24)


func _input(event: InputEvent) -> void:
	# Esc always backs out of the settings screen (main menu or pause overlay).
	# Handled here rather than in _unhandled_input so a focused control can
	# never swallow it first.
	if _awaiting_action == &"":
		if event.is_action_pressed("pause") and not event.is_echo():
			get_viewport().set_input_as_handled()
			_close()
		return
	if Time.get_ticks_msec() - _rebind_armed_msec < REBIND_ARM_DELAY_MSEC:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		get_viewport().set_input_as_handled()
		var key_event := event as InputEventKey
		if (
			key_event.keycode == KEY_ESCAPE
			or key_event.physical_keycode == KEY_ESCAPE
		):
			_cancel_rebind()
			return
		_finish_rebind(key_event)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		_finish_rebind(event)




func _show_page(page_index: int) -> void:
	if _awaiting_action != &"":
		_cancel_rebind()
	display_page.visible = page_index == 0
	controls_page.visible = page_index == 1
	audio_page.visible = page_index == 2
	display_tab.set_pressed_no_signal(page_index == 0)
	controls_tab.set_pressed_no_signal(page_index == 1)
	audio_tab.set_pressed_no_signal(page_index == 2)


func _build_binding_rows() -> void:
	for entry in SettingsManager.REBINDABLE_ACTIONS:
		var action: StringName = entry["action"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 16)
		var caption := Label.new()
		caption.theme_type_variation = &"MutedLabel"
		caption.text = String(entry["label"])
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(caption)
		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(170, 34)
		bind_button.text = SettingsManager.get_action_binding_text(action)
		bind_button.pressed.connect(_on_bind_button_pressed.bind(action))
		row.add_child(bind_button)
		bindings_list.add_child(row)
		_binding_buttons[action] = bind_button


func _on_bind_button_pressed(action: StringName) -> void:
	if _awaiting_action != &"":
		_cancel_rebind()
	_awaiting_action = action
	_rebind_armed_msec = Time.get_ticks_msec()
	_binding_buttons[action].text = "PRESS A KEY..."
	bindings_hint.text = "Listening…  press the new key or mouse button. Esc cancels."


func _finish_rebind(event: InputEvent) -> void:
	var action := _awaiting_action
	_awaiting_action = &""
	var swapped := SettingsManager.rebind_action(action, event)
	_refresh_binding_buttons()
	if swapped != &"":
		bindings_hint.text = "Key already in use — bindings were swapped with %s." % (
			_get_action_label(swapped)
		)
	else:
		bindings_hint.text = BINDINGS_HINT_DEFAULT


func _cancel_rebind() -> void:
	_awaiting_action = &""
	_refresh_binding_buttons()
	bindings_hint.text = BINDINGS_HINT_DEFAULT


func _refresh_binding_buttons() -> void:
	for action in _binding_buttons:
		_binding_buttons[action].text = SettingsManager.get_action_binding_text(action)


func _get_action_label(action: StringName) -> String:
	for entry in SettingsManager.REBINDABLE_ACTIONS:
		if entry["action"] == action:
			return String(entry["label"])
	return String(action)


func _on_reset_bindings_pressed() -> void:
	if _awaiting_action != &"":
		_cancel_rebind()
	SettingsManager.reset_bindings()
	bindings_hint.text = "Bindings restored to defaults."


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
	_refresh_binding_buttons()


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
	if _awaiting_action != &"":
		_cancel_rebind()
	if get_tree().current_scene == self:
		GameManager.open_main_menu()
	else:
		queue_free()
