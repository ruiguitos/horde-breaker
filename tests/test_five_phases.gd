extends SceneTree

## Headless check of the five-phase run structure in run_objective.gd, including
## the extraction that happens after PUSH ON. Stubs stand in for the camp core,
## the player and the wave manager; the objective is stepped by hand so the test
## does not have to wait for the real clock.

## run_objective.gd cannot be preloaded here: it references the SaveManager
## autoload, which only exists after the first process_frame of a --script run.
const RUN_OBJECTIVE_PATH := "res://scripts/systems/run_objective.gd"

var _passed := 0
var _failed := 0
var _finished_stats: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var world := Node.new()
	world.name = "TestWorld"
	root.add_child(world)

	var camp_core := Node3D.new()
	camp_core.name = "CampCore"
	camp_core.add_to_group(&"camp_core")
	world.add_child(camp_core)
	camp_core.global_position = Vector3.ZERO

	var player := Node3D.new()
	player.name = "Player"
	player.add_to_group(&"player")
	world.add_child(player)
	player.global_position = Vector3.ZERO

	var wave_manager := Node.new()
	wave_manager.name = "WaveManager"
	wave_manager.add_to_group(&"wave_manager")
	world.add_child(wave_manager)

	var objective := Node.new()
	objective.name = "RunObjective"
	objective.set_script(load(RUN_OBJECTIVE_PATH))
	objective.set(&"survival_seconds", 120.0)
	objective.set(&"extraction_window_seconds", 60.0)
	objective.set(&"extraction_radius", 14.0)
	objective.set(&"extraction_credits", 300)
	objective.set(&"missed_reward_ratio", 0.35)
	objective.set(&"extension_seconds", 300.0)
	objective.set(&"extension_reward_multiplier", 2.0)
	world.add_child(objective)
	# Stepped by hand: the automatic _process would race the assertions.
	objective.process_mode = Node.PROCESS_MODE_DISABLED
	objective.connect(&"run_finished", _on_run_finished)
	await process_frame

	# Phase 1 — the clock runs down.
	_check("phase 1: clock starts full", objective.get(&"seconds_remaining") == 120.0)
	_step(objective, 10.0)
	_check(
		"phase 1: clock counts down",
		is_equal_approx(float(objective.get(&"seconds_remaining")), 110.0)
	)
	_check("phase 1: time text", String(objective.call(&"get_time_text")) == "1:50")

	# Phase 2 — the extraction window opens and the horde surges.
	_check(
		"phase 2: window still closed",
		not bool(objective.call(&"is_extraction_window_open"))
	)
	_step(objective, 55.0)
	_check(
		"phase 2: window opens under 60 s",
		bool(objective.call(&"is_extraction_window_open"))
	)

	# Phase 3 — extracting inside the zone.
	_check(
		"phase 3: player inside the zone",
		bool(objective.call(&"is_player_in_extraction_zone"))
	)
	player.global_position = Vector3(40.0, 0.0, 0.0)
	_check(
		"phase 3: player outside the zone",
		not bool(objective.call(&"is_player_in_extraction_zone"))
	)
	player.global_position = Vector3.ZERO
	_step(objective, 60.0)
	_check("phase 3: run finished", bool(objective.get(&"is_finished")))
	_check("phase 4: one summary emitted", _finished_stats.size() == 1)
	var first: Dictionary = _finished_stats[0] if not _finished_stats.is_empty() else {}
	_check("phase 4: extracted", bool(first.get("extracted", false)))
	_check("phase 4: full reward", int(first.get("credits", 0)) == 300)
	_check("phase 4: can extend", bool(first.get("can_extend", false)))

	# Phase 5 — PUSH ON. The real button unpauses before calling extend_run();
	# reproduce that here so a paused tree cannot mask the result.
	paused = true
	paused = false
	objective.call(&"extend_run")
	_check("phase 5: run resumed", not bool(objective.get(&"is_finished")))
	_check(
		"phase 5: clock refilled",
		is_equal_approx(float(objective.get(&"seconds_remaining")), 300.0)
	)
	_check(
		"phase 5: reward multiplier doubled",
		is_equal_approx(float(objective.call(&"get_reward_multiplier")), 2.0)
	)

	# Phase 5 → 3 again: the extraction after the extension must pay double.
	_step(objective, 250.0)
	_check(
		"phase 5: window reopens",
		bool(objective.call(&"is_extraction_window_open"))
	)
	player.global_position = Vector3(40.0, 0.0, 0.0)
	_step(objective, 60.0)
	_check("phase 5: second summary emitted", _finished_stats.size() == 2)
	var second: Dictionary = _finished_stats[1] if _finished_stats.size() > 1 else {}
	_check("phase 5: left behind", not bool(second.get("extracted", true)))
	_check(
		"phase 5: reduced reward doubled (300 x2 x0.35 = 210)",
		int(second.get("credits", 0)) == 210
	)
	_check("phase 5: extensions counted", int(second.get("extensions", 0)) == 1)

	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _step(objective: Node, seconds: float) -> void:
	# One second per call keeps the warning marks and the window threshold
	# firing at the same points the real frame loop would hit.
	var remaining := seconds
	while remaining > 0.0:
		var delta := minf(remaining, 1.0)
		objective.call(&"_process", delta)
		remaining -= delta


func _on_run_finished(stats: Dictionary) -> void:
	_finished_stats.append(stats)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
