extends Node

signal display_settings_applied(fullscreen: bool, resolution: Vector2i)

const SETTINGS_PATH := "user://horde_breaker_settings.cfg"
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const DEFAULT_FULLSCREEN := true

var _config := ConfigFile.new()
var _target_fullscreen := true
var _display_refresh_running := false
var _display_refresh_queued := false


func _ready() -> void:
	var load_error := _config.load(SETTINGS_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("SettingsManager could not load settings: %s" % load_error)
	_apply_vsync()
	_apply_master_volume()
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


func _save() -> void:
	var save_error := _config.save(SETTINGS_PATH)
	if save_error != OK:
		push_error("SettingsManager could not save settings: %s" % save_error)
