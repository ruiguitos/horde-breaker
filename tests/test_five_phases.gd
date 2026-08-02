extends SceneTree

## Headless check of the five-beat run structure in run_objective.gd:
##
##   1. survive the clock                  4. reach the extraction zone
##   2. the horde surges, then the tap     5. push on for a bigger payout
##      closes: LAST STAND
##   3. clear every zombie left alive
##
## The clock used to *end* the run wherever the player stood. It now only starts
## the ending, so the two things worth guarding are that zero does not finish
## anything and that the zone will not take a player who has left enemies alive.
##
## Stubs stand in for the camp core, the player and the wave director; the
## objective is stepped by hand so the test does not have to wait for the real
## clock.

## run_objective.gd cannot be preloaded here: it references the SaveManager
## autoload, which only exists after the first process_frame of a --script run.
const RUN_OBJECTIVE_PATH := "res://scripts/systems/run_objective.gd"
const WAVE_MANAGER_PATH := "res://scripts/systems/wave_manager.gd"
## A stand-in director whose enemy count the test can set directly.
const DIRECTOR_STUB := """
extends Node
signal enemy_defeated(xp_reward: int)
var final_phase := false
var surge := false
var living := 0
func begin_final_phase() -> void:
	final_phase = true
func end_final_phase() -> void:
	final_phase = false
func is_final_phase() -> bool:
	return final_phase
func get_living_enemy_count() -> int:
	return living
func set_surge_active(active: bool) -> void:
	surge = active
"""

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

	var director_script := GDScript.new()
	director_script.source_code = DIRECTOR_STUB
	director_script.reload()
	var director := Node.new()
	director.name = "WaveManager"
	director.set_script(director_script)
	director.add_to_group(&"wave_manager")
	world.add_child(director)

	var objective := Node.new()
	objective.name = "RunObjective"
	objective.set_script(load(RUN_OBJECTIVE_PATH))
	objective.set(&"survival_seconds", 120.0)
	objective.set(&"extraction_window_seconds", 60.0)
	objective.set(&"extraction_radius", 14.0)
	objective.set(&"extraction_credits", 300)
	objective.set(&"extension_seconds", 300.0)
	objective.set(&"extension_reward_multiplier", 2.0)
	world.add_child(objective)
	# Stepped by hand: the automatic _process would race the assertions.
	objective.process_mode = Node.PROCESS_MODE_DISABLED
	objective.connect(&"run_finished", _on_run_finished)
	await process_frame

	# Beat 1 — the clock runs down.
	_check("beat 1: clock starts full", objective.get(&"seconds_remaining") == 120.0)
	_step(objective, 10.0)
	_check(
		"beat 1: clock counts down",
		is_equal_approx(float(objective.get(&"seconds_remaining")), 110.0)
	)
	_check("beat 1: time text", String(objective.call(&"get_time_text")) == "1:50")
	_check("beat 1: objective reads as the clock",
		String(objective.call(&"get_objective_text")) == "1:50")

	# Beat 2 — the surge window, then the tap closes.
	_check(
		"beat 2: window still closed",
		not bool(objective.call(&"is_extraction_window_open"))
	)
	_step(objective, 55.0)
	_check(
		"beat 2: window opens under 60 s",
		bool(objective.call(&"is_extraction_window_open"))
	)
	_check("beat 2: the horde surges", bool(director.get(&"surge")))

	# Beat 3 — the clock runs out with the horde still alive. This is the whole
	# point of the change: zero is the start of the ending, not the ending.
	director.set(&"living", 7)
	player.global_position = Vector3.ZERO
	_step(objective, 60.0)
	_check("beat 3: the clock did not finish the run", not bool(objective.get(&"is_finished")))
	_check("beat 3: the last stand began", int(objective.get(&"phase")) == 1)
	_check("beat 3: the director stopped spawning", bool(director.get(&"final_phase")))
	_check("beat 3: the surge is off", not bool(director.get(&"surge")))
	_check("beat 3: the objective counts the horde",
		String(objective.call(&"get_objective_text")) == "CLEAR  7")
	# Standing in the zone with enemies alive must do nothing at all.
	_step(objective, 5.0)
	_check(
		"beat 3: the zone will not take a player who left the horde alive",
		not bool(objective.get(&"is_finished"))
	)
	_check("beat 3: extraction is not ready", not bool(objective.call(&"is_extraction_ready")))

	# Beat 4 — clear the map, then walk to the zone.
	director.set(&"living", 0)
	_step(objective, 1.0)
	_check("beat 4: extraction opens once clear", bool(objective.call(&"is_extraction_ready")))
	_check("beat 4: the objective says to extract",
		String(objective.call(&"get_objective_text")) == "EXTRACT")
	player.global_position = Vector3(40.0, 0.0, 0.0)
	_step(objective, 3.0)
	_check("beat 4: away from the zone the run continues", not bool(objective.get(&"is_finished")))
	player.global_position = Vector3.ZERO
	_step(objective, 1.0)
	_check("beat 4: reaching the zone finishes the run", bool(objective.get(&"is_finished")))
	_check("beat 4: the director is released", not bool(director.get(&"final_phase")))

	_check("beat 4: one summary emitted", _finished_stats.size() == 1)
	var first: Dictionary = _finished_stats[0] if not _finished_stats.is_empty() else {}
	_check("beat 4: extracted", bool(first.get("extracted", false)))
	_check("beat 4: full reward", int(first.get("credits", 0)) == 300)
	_check("beat 4: can extend", bool(first.get("can_extend", false)))

	# Beat 5 — PUSH ON. The real button unpauses before calling extend_run();
	# reproduce that here so a paused tree cannot mask the result.
	paused = true
	paused = false
	objective.call(&"extend_run")
	_check("beat 5: run resumed", not bool(objective.get(&"is_finished")))
	_check("beat 5: back to surviving", int(objective.get(&"phase")) == 0)
	_check(
		"beat 5: clock refilled",
		is_equal_approx(float(objective.get(&"seconds_remaining")), 300.0)
	)
	_check(
		"beat 5: reward multiplier doubled",
		is_equal_approx(float(objective.call(&"get_reward_multiplier")), 2.0)
	)

	# Beat 5 → 3 → 4 again: the second ending pays double.
	director.set(&"living", 2)
	_step(objective, 300.0)
	_check("beat 5: a second last stand", int(objective.get(&"phase")) == 1)
	director.set(&"living", 0)
	_step(objective, 2.0)
	_check("beat 5: second summary emitted", _finished_stats.size() == 2)
	var second: Dictionary = _finished_stats[1] if _finished_stats.size() > 1 else {}
	_check("beat 5: extracted again", bool(second.get("extracted", false)))
	_check(
		"beat 5: reward doubled (300 x2 = 600)", int(second.get("credits", 0)) == 600
	)
	_check("beat 5: extensions counted", int(second.get("extensions", 0)) == 1)

	world.queue_free()
	await process_frame
	_test_director_final_phase()

	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The real director, not the stub: closing the tap has to stop the sector
## ambushes and POI encounters too, or the map can never be cleared.
func _test_director_final_phase() -> void:
	var director: Node = load(WAVE_MANAGER_PATH).new()
	_check(
		"director: encounters are open during a normal run",
		bool(director.call(&"is_preparation_active"))
	)
	_check("director: not in the last stand yet", not bool(director.call(&"is_final_phase")))
	director.call(&"begin_final_phase")
	_check("director: the last stand latches", bool(director.call(&"is_final_phase")))
	_check(
		"director: ambushes and POI encounters are shut off",
		not bool(director.call(&"is_preparation_active"))
	)
	director.call(&"end_final_phase")
	_check(
		"director: extending the run reopens the tap",
		bool(director.call(&"is_preparation_active"))
	)
	director.free()


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
