extends SceneTree

## Times the arena's cold start stage by stage.
##
## An 8 x 8 world once made a headless validation overrun 600 s and nobody knew
## which part was expensive: parsing a .tscn that now carries a few thousand
## painted cells per layer, instancing it, baking navigation for every resident
## sector, or a run that simply never reached its quit. Guessing led to a
## proposal to drop `load_distance` to 48 m, which would have opened holes in
## front of the player without touching the real cost. This measures instead.
##
## Run:  <godot> --headless --path . --script res://tests/bench_arena_startup.gd

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const WORLD_STREAMER_GROUP := &"world_streamer"
## Give streaming a generous ceiling; the point is to report what it took, not
## to hang if it never settles.
const SETTLE_FRAME_LIMIT := 600


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var boot_ms := Time.get_ticks_msec()

	var parse_start := Time.get_ticks_usec()
	var packed: PackedScene = load(ARENA_SCENE)
	var parse_ms := _elapsed_ms(parse_start)
	if packed == null:
		push_error("bench could not load the arena")
		quit(1)
		return

	var instance_start := Time.get_ticks_usec()
	var detached := packed.instantiate()
	var instance_ms := _elapsed_ms(instance_start)
	detached.free()

	var change_start := Time.get_ticks_usec()
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("bench could not enter the arena")
		quit(1)
		return
	await scene_changed
	var enter_ms := _elapsed_ms(change_start)

	var streamer := get_first_node_in_group(WORLD_STREAMER_GROUP)
	if streamer == null:
		push_error("bench found no world streamer")
		quit(1)
		return
	# Streaming is asynchronous: sectors are built on worker threads and attached
	# a few nodes per frame. "Settled" means a frame went by without the resident
	# count changing, which is the first moment the world is actually playable.
	var settle_start := Time.get_ticks_usec()
	var frames := 0
	var loaded := 0
	var stable_frames := 0
	while frames < SETTLE_FRAME_LIMIT and stable_frames < 30:
		await process_frame
		frames += 1
		var current := int(streamer.call(&"get_loaded_sector_count"))
		if current == loaded and current > 0:
			stable_frames += 1
		else:
			stable_frames = 0
		loaded = current
	var settle_ms := _elapsed_ms(settle_start)

	print("BENCH: engine boot to first frame  %d ms" % boot_ms)
	print("BENCH: parse arena .tscn           %.1f ms" % parse_ms)
	print("BENCH: instantiate arena           %.1f ms" % instance_ms)
	print("BENCH: enter the tree (_ready)     %.1f ms" % enter_ms)
	print("BENCH: streaming settled           %.1f ms over %d frames" % [
		settle_ms, frames
	])
	print("BENCH: sectors resident            %d" % loaded)
	print("BENCH: last sector build           %.1f ms" % float(
		streamer.get(&"last_build_ms")
	))
	print("BENCH: total to playable           %.1f ms" % (
		float(boot_ms) + parse_ms + instance_ms + enter_ms + settle_ms
	))
	quit(0)


func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0
