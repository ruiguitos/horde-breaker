extends SceneTree

## Measures the frame cost of a large horde and isolates what dominates it.
## Usage: <godot> --path . --rendering-driver opengl3 --script
##        res://tests/bench_horde.gd -- <count> <variant>
## Variants: baseline | no_overlay | no_animation | no_overlay_no_animation

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const ZOMBIE_SCENE := "res://scenes/enemies/normal_zombie.tscn"
const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 240
## Ring the horde is packed into, around the player.
const SPAWN_MIN_RADIUS := 6.0
const SPAWN_MAX_RADIUS := 26.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var arguments := OS.get_cmdline_user_args()
	var count := int(arguments[0]) if arguments.size() > 0 else 140
	var variant := String(arguments[1]) if arguments.size() > 1 else "baseline"
	DisplayServer.window_set_size(Vector2i(1152, 648))
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("bench could not load the arena")
		quit(1)
		return
	await scene_changed
	var overlay := root.get_node_or_null("FpsOverlay") as CanvasLayer
	if overlay != null:
		overlay.visible = false
	# Let streaming and navigation settle before adding the horde.
	await _wait_frames(120)

	var player := get_first_node_in_group(&"player") as Node3D
	if player == null:
		push_error("bench found no player")
		quit(1)
		return
	# The wave director would keep adding to the count mid-measurement, and the
	# player's auto-fire would thin the horde out while it is being measured.
	var wave_manager := get_first_node_in_group(&"wave_manager")
	if wave_manager != null:
		wave_manager.set_process(false)
		wave_manager.set_physics_process(false)
	var weapon_pivot := player.get_node_or_null("VisualRoot/WeaponPivot")
	if weapon_pivot != null:
		weapon_pivot.process_mode = Node.PROCESS_MODE_DISABLED
	# With its weapons off the player dies in seconds, the defeat panel pauses
	# the tree and the measurement ends up sampling an empty scene.
	player.set(&"maximum_health", 1.0e9)
	player.set(&"current_health", 1.0e9)
	for existing in get_nodes_in_group(&"enemy"):
		existing.queue_free()
	await _wait_frames(5)

	var zombie_scene: PackedScene = load(ZOMBIE_SCENE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260725
	var spawned: Array[Node3D] = []
	for index in count:
		var zombie := zombie_scene.instantiate() as Node3D
		# Set before _ready so current_health picks it up: the horde has to stay
		# at full strength for the whole sample.
		zombie.set(&"maximum_health", 1.0e9)
		current_scene.add_child(zombie)
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(SPAWN_MIN_RADIUS, SPAWN_MAX_RADIUS)
		zombie.global_position = player.global_position + Vector3(
			cos(angle) * radius, 0.6, sin(angle) * radius
		)
		spawned.append(zombie)
	await _wait_frames(10)
	_apply_variant(spawned, variant)
	await _wait_frames(WARMUP_FRAMES)

	var frame_times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for _frame in SAMPLE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
	_report(count, variant, frame_times, get_nodes_in_group(&"enemy").size())
	quit(0)


func _apply_variant(zombies: Array[Node3D], variant: String) -> void:
	var drop_overlay := variant.contains("no_overlay")
	var stop_animation := variant.contains("no_animation")
	# Unbinding the skeleton keeps the mesh on screen but renders it in bind
	# pose, which is what separates "skinning is expensive" from "this much
	# geometry is expensive".
	var drop_skeleton := variant.contains("no_skin")
	var hide_models := variant.contains("hidden")
	for zombie in zombies:
		for mesh_value in zombie.find_children("*", "MeshInstance3D", true, false):
			var instance := mesh_value as MeshInstance3D
			if drop_overlay:
				instance.material_overlay = null
			if drop_skeleton:
				instance.skeleton = NodePath()
			if hide_models and instance.is_visible_in_tree():
				instance.visible = false
		if stop_animation:
			for player_value in zombie.find_children("*", "AnimationPlayer", true, false):
				(player_value as AnimationPlayer).active = false


func _report(
	count: int, variant: String, frame_times: Array[float], alive: int
) -> void:
	frame_times.sort()
	var total := 0.0
	for value in frame_times:
		total += value
	var average := total / float(frame_times.size())
	var median := frame_times[frame_times.size() / 2]
	var percentile_95 := frame_times[int(float(frame_times.size()) * 0.95)]
	var worst := frame_times[frame_times.size() - 1]
	print("BENCH: variant=%s enemies=%d alive=%d" % [variant, count, alive])
	print("BENCH: avg=%.2f ms (%.1f FPS)" % [average, 1000.0 / average])
	print("BENCH: median=%.2f ms  p95=%.2f ms  worst=%.2f ms" % [
		median, percentile_95, worst
	])
	print("BENCH: draw_calls=%d primitives=%d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	])


func _wait_frames(frame_count: int) -> void:
	for _frame_index in frame_count:
		await process_frame
