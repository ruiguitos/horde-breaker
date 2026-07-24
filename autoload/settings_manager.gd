extends Node

signal display_settings_applied(fullscreen: bool, resolution: Vector2i)
signal bindings_changed

const SETTINGS_PATH := "user://horde_breaker_settings.cfg"
# Boots windowed at a low resolution by default so the prototype stays
# comfortable to test; fullscreen and higher resolutions are opt-in via the
# settings menu and persist across runs.
const DEFAULT_RESOLUTION := Vector2i(1152, 648)
const DEFAULT_FULLSCREEN := false

## Actions the player can rebind in the settings menu. `pause` stays fixed on
## Esc so a bad binding can never lock the player out of the menus.
const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": &"move_forward", "label": "MOVE FORWARD"},
	{"action": &"move_backward", "label": "MOVE BACKWARD"},
	{"action": &"move_left", "label": "MOVE LEFT"},
	{"action": &"move_right", "label": "MOVE RIGHT"},
	{"action": &"jump", "label": "JUMP"},
	{"action": &"sprint", "label": "SPRINT"},
	{"action": &"crouch", "label": "CROUCH"},
	{"action": &"interact", "label": "INTERACT"},
	{"action": &"reload", "label": "RELOAD"},
	{"action": &"attack", "label": "ATTACK"},
	{"action": &"aim", "label": "AIM"},
	{"action": &"weapon_primary", "label": "WEAPON SLOT 1"},
	{"action": &"weapon_secondary", "label": "WEAPON SLOT 2"},
	{"action": &"camera_front", "label": "FRONT CAMERA"},
	{"action": &"toggle_map", "label": "TACTICAL MAP"},
	{"action": &"toggle_fps", "label": "FPS OVERLAY"},
	{"action": &"build_mode_toggle", "label": "BUILD MODE"},
	{"action": &"build_confirm", "label": "BUILD CONFIRM"},
	{"action": &"build_cancel", "label": "BUILD CANCEL"},
	{"action": &"build_rotate", "label": "BUILD ROTATE"},
	{"action": &"structure_demolish", "label": "DEMOLISH STRUCTURE"},
]

var storage_path: String = SETTINGS_PATH
var _config := ConfigFile.new()
var _target_fullscreen := true
var _display_refresh_running := false
var _display_refresh_queued := false


func _ready() -> void:
	var load_error := _config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("SettingsManager could not load settings: %s" % load_error)
	_apply_vsync()
	_apply_master_volume()
	_apply_saved_bindings()
	# The project boots windowed on purpose: launching straight into native
	# fullscreen with a viewport equal to the monitor resolution leaves the
	# window unable to return to windowed mode reliably on Windows. The saved
	# mode is applied after the root Window has a valid restore rectangle.
	_target_fullscreen = bool(
		_config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN)
	)
	call_deferred(&"_refresh_display")


func is_fullscreen() -> bool:
	return _target_fullscreen


func set_fullscreen(enabled: bool) -> void:
	_target_fullscreen = enabled
	_config.set_value("display", "fullscreen", enabled)
	_save()
	_refresh_display()


func get_resolution() -> Vector2i:
	return Vector2i(_config.get_value("display", "resolution", DEFAULT_RESOLUTION))


func get_active_resolution() -> Vector2i:
	var window := get_window()
	if _target_fullscreen:
		var screen_index := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen_index)
		if screen_size.x > 0 and screen_size.y > 0:
			return screen_size
	if (
		window != null
		and window.mode == Window.MODE_WINDOWED
		and window.size.x > 0
		and window.size.y > 0
	):
		return window.size
	return get_resolution()


func set_resolution(resolution: Vector2i) -> void:
	if resolution.x <= 0 or resolution.y <= 0:
		push_error("SettingsManager received an invalid resolution: %s" % resolution)
		return
	_config.set_value("display", "resolution", resolution)
	_save()
	_refresh_display()


func is_vsync_enabled() -> bool:
	return bool(_config.get_value("display", "vsync", true))


func set_vsync_enabled(enabled: bool) -> void:
	_config.set_value("display", "vsync", enabled)
	_save()
	_apply_vsync()


func get_mouse_sensitivity_multiplier() -> float:
	return clampf(
		float(_config.get_value("controls", "mouse_sensitivity", 1.0)), 0.2, 3.0
	)


func set_mouse_sensitivity_multiplier(multiplier: float) -> void:
	_config.set_value("controls", "mouse_sensitivity", clampf(multiplier, 0.2, 3.0))
	_save()


func get_master_volume() -> float:
	return clampf(float(_config.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)


func set_master_volume(volume: float) -> void:
	_config.set_value("audio", "master_volume", clampf(volume, 0.0, 1.0))
	_save()
	_apply_master_volume()


func _refresh_display() -> void:
	# Window mode and size changes cannot land on the same frame on Windows;
	# this coroutine applies them step by step and coalesces repeated calls.
	if _display_refresh_running:
		_display_refresh_queued = true
		return
	_display_refresh_running = true
	while true:
		_display_refresh_queued = false
		await _apply_display_state()
		if not _display_refresh_queued:
			break
	_display_refresh_running = false


func _apply_display_state() -> void:
	await get_tree().process_frame
	var window := get_window()
	if window == null:
		return
	# The root Window caches its own mode and re-asserts it over any change
	# made directly through DisplayServer, so the mode must be set here.
	var target_mode := (
		Window.MODE_FULLSCREEN if _target_fullscreen else Window.MODE_WINDOWED
	)
	if window.mode != target_mode:
		window.mode = target_mode
		await get_tree().process_frame
	if _target_fullscreen:
		display_settings_applied.emit(true, get_active_resolution())
		return
	if window.size != get_resolution():
		window.size = get_resolution()
		await get_tree().process_frame
	window.move_to_center()
	display_settings_applied.emit(false, get_active_resolution())


func _apply_vsync() -> void:
	var vsync_mode := (
		DisplayServer.VSYNC_ENABLED
		if is_vsync_enabled()
		else DisplayServer.VSYNC_DISABLED
	)
	DisplayServer.window_set_vsync_mode(vsync_mode)


func _apply_master_volume() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return
	var volume := get_master_volume()
	AudioServer.set_bus_mute(master_bus, volume <= 0.005)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(volume, 0.005)))


func load_settings(path_override: String) -> void:
	# Test hook mirroring SaveManager.load_progress: isolates the config file.
	storage_path = path_override
	_config = ConfigFile.new()
	var load_error := _config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("SettingsManager could not load settings: %s" % load_error)
	_apply_saved_bindings()


func get_action_binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	return _describe_event(events[0])


func rebind_action(action: StringName, event: InputEvent) -> StringName:
	# Assigns the captured event to the action. If another rebindable action
	# already uses that input, the two actions swap bindings so no action is
	# ever left without a key. Returns the swapped action (or &"" if none).
	if not _is_supported_binding(event):
		return &""
	var previous_events := InputMap.action_get_events(action)
	var previous_event: InputEvent = (
		previous_events[0] if not previous_events.is_empty() else null
	)
	var conflicting_action := _find_conflicting_action(action, event)
	_assign_action_event(action, event)
	if conflicting_action != &"" and previous_event != null:
		_assign_action_event(conflicting_action, previous_event)
		_store_binding(conflicting_action, previous_event)
	_store_binding(action, event)
	_save()
	bindings_changed.emit()
	return conflicting_action


func reset_bindings() -> void:
	InputMap.load_from_project_settings()
	if _config.has_section("input"):
		_config.erase_section("input")
	_save()
	bindings_changed.emit()


func _apply_saved_bindings() -> void:
	if not _config.has_section("input"):
		return
	for action_key in _config.get_section_keys("input"):
		var action := StringName(action_key)
		if not InputMap.has_action(action):
			continue
		var stored: Dictionary = _config.get_value("input", action_key, {})
		var event := _deserialize_event(stored)
		if event != null:
			_assign_action_event(action, event)
	bindings_changed.emit()


func _assign_action_event(action: StringName, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


func _find_conflicting_action(
	action: StringName, event: InputEvent
) -> StringName:
	for entry in REBINDABLE_ACTIONS:
		var candidate: StringName = entry["action"]
		if candidate == action or not InputMap.has_action(candidate):
			continue
		for existing in InputMap.action_get_events(candidate):
			if _events_match(existing, event):
				return candidate
	return &""


func _events_match(event_a: InputEvent, event_b: InputEvent) -> bool:
	if event_a is InputEventKey and event_b is InputEventKey:
		return _key_code_of(event_a) == _key_code_of(event_b)
	if event_a is InputEventMouseButton and event_b is InputEventMouseButton:
		return (
			(event_a as InputEventMouseButton).button_index
			== (event_b as InputEventMouseButton).button_index
		)
	return false


func _key_code_of(event: InputEventKey) -> int:
	# Physical keycodes keep WASD in place on any keyboard layout.
	if event.physical_keycode != KEY_NONE:
		return int(event.physical_keycode)
	return int(event.keycode)


func _is_supported_binding(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


func _describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.physical_keycode != KEY_NONE:
			# The headless display server cannot translate physical keycodes.
			if DisplayServer.get_name() != "headless":
				var visible_keycode := DisplayServer.keyboard_get_keycode_from_physical(
					key_event.physical_keycode
				)
				if visible_keycode != KEY_NONE:
					return OS.get_keycode_string(visible_keycode)
			return OS.get_keycode_string(key_event.physical_keycode)
		return OS.get_keycode_string(key_event.keycode)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "MOUSE LEFT"
			MOUSE_BUTTON_RIGHT:
				return "MOUSE RIGHT"
			MOUSE_BUTTON_MIDDLE:
				return "MOUSE MIDDLE"
			MOUSE_BUTTON_WHEEL_UP:
				return "WHEEL UP"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "WHEEL DOWN"
			_:
				return "MOUSE %d" % (event as InputEventMouseButton).button_index
	return event.as_text()


func _store_binding(action: StringName, event: InputEvent) -> void:
	_config.set_value("input", String(action), _serialize_event(event))


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": _key_code_of(event as InputEventKey)}
	if event is InputEventMouseButton:
		return {
			"type": "mouse",
			"code": int((event as InputEventMouseButton).button_index),
		}
	return {}


func _deserialize_event(stored: Dictionary) -> InputEvent:
	var code := int(stored.get("code", 0))
	if code <= 0:
		return null
	match String(stored.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = code as Key
			return key_event
		"mouse":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = code as MouseButton
			return mouse_event
	return null


func _save() -> void:
	var save_error := _config.save(storage_path)
	if save_error != OK:
		push_error("SettingsManager could not save settings: %s" % save_error)
