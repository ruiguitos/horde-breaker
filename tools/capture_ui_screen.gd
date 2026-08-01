extends SceneTree

const MENU_SCENES := {
	"main_menu": "res://scenes/menus/main_menu.tscn",
	"character_selection": "res://scenes/menus/character_selection.tscn",
	"armory": "res://scenes/menus/armory_screen.tscn",
	"skill_tree": "res://scenes/menus/skill_tree_screen.tscn",
	"settings": "res://scenes/menus/settings_menu.tscn",
}
const ARENA_SCENE := "res://scenes/world/test_arena.tscn"


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	await process_frame
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 4:
		push_error(
			"Usage: capture_ui_screen.gd -- <target> <output.png> <width> <height>"
		)
		quit(1)
		return
	var target := arguments[0]
	var output_path := arguments[1]
	var capture_size := Vector2i(int(arguments[2]), int(arguments[3]))
	# Go through SettingsManager: it owns the window and would otherwise reassert
	# the player's saved resolution over anything set here. An isolated config
	# file keeps the capture from rewriting the real settings.
	var settings := root.get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.call(&"load_settings", "user://horde_breaker_capture_settings.cfg")
		settings.call(&"set_fullscreen", false)
		settings.call(&"set_resolution", capture_size)
		await settings.display_settings_applied
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(capture_size)
	var scene_path := String(MENU_SCENES.get(target, ARENA_SCENE))
	var scene_error := change_scene_to_file(scene_path)
	if scene_error != OK:
		push_error("UI capture could not load %s." % scene_path)
		quit(1)
		return
	await scene_changed
	var fps_overlay := root.get_node_or_null("FpsOverlay") as CanvasLayer
	if fps_overlay != null:
		fps_overlay.visible = false
	await _wait_frames(35 if MENU_SCENES.has(target) else 100)
	if not MENU_SCENES.has(target):
		if not _prepare_arena_target(target):
			quit(1)
			return
	# Tweens use elapsed time, not frame count. Waiting briefly keeps captures
	# deterministic even when the renderer runs hundreds of frames per second.
	await create_timer(0.65, true).timeout
	await _wait_frames(2)
	var image := root.get_texture().get_image()
	var output_directory := output_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		push_error("UI capture could not create %s." % output_directory)
		quit(1)
		return
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("UI capture could not save %s." % output_path)
		quit(1)
		return
	print("CAPTURE: %s (%d x %d)" % [output_path, image.get_width(), image.get_height()])
	quit(0)


## A believable mid-run loadout: several cards at different levels, one of them
## maxed, spread across the rarities so the colours are visible in the capture.
func _grant_sample_upgrades() -> void:
	var progression := get_first_node_in_group(&"run_progression")
	if progression == null:
		return
	var sample := {
		&"magazine": 5, &"damage": 3, &"ammo_reserve": 2, &"pickup_radius": 2,
		&"move_speed": 1, &"max_health": 1, &"reload": 1, &"xp_gain": 1,
		&"regeneration": 1, &"lifesteal": 1,
	}
	for upgrade_id: StringName in sample:
		for level in int(sample[upgrade_id]):
			progression.call(&"apply_upgrade", upgrade_id)


func _prepare_arena_target(target: String) -> bool:
	if current_scene == null:
		return false
	if target == "terrain_world_overview":
		var world := get_first_node_in_group(&"terrain3d_world") as Node3D
		if world == null:
			push_error("Terrain overview requires the Terrain3D world.")
			return false
		var wave_manager := get_first_node_in_group(&"wave_manager")
		if wave_manager != null:
			wave_manager.set_process(false)
			wave_manager.set_physics_process(false)
		var hud_layer := current_scene.get_node_or_null("HUDLayer") as CanvasLayer
		if hud_layer != null:
			hud_layer.visible = false
		var overview_camera := Camera3D.new()
		overview_camera.name = "TerrainOverviewCamera"
		overview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		overview_camera.size = 590.0
		overview_camera.far = 1000.0
		overview_camera.position = Vector3(32.0, 420.0, 32.0)
		overview_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		current_scene.add_child(overview_camera)
		overview_camera.current = true
		return true
	if target == "terrain_world" or target == "terrain_pilot":
		var terrain_world := get_first_node_in_group(&"terrain3d_world") as Node3D
		var player := get_first_node_in_group(&"player") as CharacterBody3D
		if terrain_world == null or player == null:
			push_error("Terrain world capture requires Terrain3D and the player.")
			return false
		var wave_manager := get_first_node_in_group(&"wave_manager")
		if wave_manager != null:
			wave_manager.set_process(false)
			wave_manager.set_physics_process(false)
		for enemy in get_nodes_in_group(&"enemy"):
			if enemy is Node3D:
				(enemy as Node3D).visible = false
		for pickup in get_nodes_in_group(&"pickup"):
			if pickup is Node3D:
				(pickup as Node3D).visible = false
		player.visible = false
		var camp := current_scene.get_node_or_null("CampSector") as Node3D
		if camp != null:
			camp.visible = false
		var hud := current_scene.find_child("GameHUD", true, false) as Control
		if hud != null:
			hud.visible = false
		var scenic_camera := Camera3D.new()
		scenic_camera.name = "TerrainScenicCamera"
		scenic_camera.far = 500.0
		scenic_camera.position = Vector3(-104.0, 13.0, -94.0)
		current_scene.add_child(scenic_camera)
		scenic_camera.look_at(Vector3(-55.0, 2.0, -151.0), Vector3.UP)
		scenic_camera.current = true
		return true
	if target == "hud":
		var hud := current_scene.find_child("GameHUD", true, false)
		if hud == null:
			push_error("UI capture could not find GameHUD.")
			return false
		hud.call(&"_update_health", 62.0, 100.0)
		hud.call(&"_update_ammunition", 5, 30, 60)
		hud.call(&"_pulse_threat", 5)
		hud.call(&"_show_feedback", "SECTOR CACHE SECURED", 5.0)
		return true
	if target == "pause":
		var pause_menu := current_scene.find_child("PauseMenu", true, false)
		if pause_menu == null:
			push_error("UI capture could not find PauseMenu.")
			return false
		# A pause screen with no upgrades shows none of what the panel is for.
		_grant_sample_upgrades()
		pause_menu.call(&"pause_game")
		return true
	if target == "upgrades":
		var progression := get_first_node_in_group(&"run_progression")
		if progression == null:
			push_error("UI capture could not find the run progression.")
			return false
		_grant_sample_upgrades()
		progression.emit_signal(
			&"run_level_gained", 7, progression.call(&"draw_choices")
		)
		return true
	if target == "defeat":
		var defeat := current_scene.find_child("GameOverPanel", true, false)
		if defeat == null:
			push_error("UI capture could not find GameOverPanel.")
			return false
		defeat.call(
			&"_show_game_over",
			"The horde took your operative down.\nRegroup and try again."
		)
		return true
	if target == "map":
		var tactical_map := current_scene.find_child("TacticalMap", true, false)
		if tactical_map == null:
			push_error("UI capture could not find TacticalMap.")
			return false
		tactical_map.visible = true
		tactical_map.call(&"_refresh_references")
		tactical_map.queue_redraw()
		return true
	push_error("Unknown UI capture target: %s" % target)
	return false


func _wait_frames(frame_count: int) -> void:
	for _frame_index in frame_count:
		await process_frame
