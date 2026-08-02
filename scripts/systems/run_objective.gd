extends Node

## Run structure. The clock no longer ends the run — it decides when the ending
## *starts*:
##
##   1. survive the clock                  4. reach the extraction zone
##   2. the horde surges, then the tap     5. summary, and the option to push on
##      closes: LAST STAND                    for a bigger payout
##   3. clear every zombie left alive
##
## The old version handed the run to you the moment the timer hit zero, wherever
## you happened to be standing, which made the last minute matter less than any
## other. Now zero is the start of the fight: nothing new spawns, and what is on
## the map is a finite number you have to bring to zero before the extraction
## opens at all.

signal time_changed(seconds_remaining: float, total_seconds: float)
signal extraction_window_opened(seconds_remaining: float)
signal run_finished(stats: Dictionary)
signal run_extended(added_seconds: float, reward_multiplier: float)
## The clock ran out; the horde is now finite. Carries what is left to kill.
signal last_stand_started(remaining_enemies: int)
signal horde_remaining_changed(remaining_enemies: int)
## Everything is dead. The zone is live and the run ends when the player reaches it.
signal extraction_ready()
signal phase_changed(phase: int)

enum Phase {
	## The clock is running and the director is spawning.
	SURVIVING,
	## No more spawns; kill what is left.
	LAST_STAND,
	## Map clear; walk to the zone.
	EXTRACTING,
	## Extracted, or dead.
	FINISHED,
}

const CAMP_ECONOMY_GROUP := &"camp_economy"
const CAMP_CORE_GROUP := &"camp_core"
const PLAYER_GROUP := &"player"
const WAVE_MANAGER_GROUP := &"wave_manager"
const RUN_PROGRESSION_GROUP := &"run_progression"

@export_range(60.0, 3600.0, 30.0) var survival_seconds: float = 600.0
## Final stretch of the clock: the horde surges before the tap closes.
@export_range(15.0, 300.0, 5.0) var extraction_window_seconds: float = 60.0
@export_range(4.0, 40.0, 1.0) var extraction_radius: float = 14.0
@export_range(0, 10000, 25) var extraction_credits: int = 300
@export_range(60.0, 900.0, 30.0) var extension_seconds: float = 300.0
@export_range(1.0, 5.0, 0.25) var extension_reward_multiplier: float = 2.0
@export var warning_marks: Array[int] = [300, 120, 30, 10]

var seconds_remaining: float = 0.0
var is_finished: bool = false
var extensions: int = 0
var kills: int = 0
var phase: Phase = Phase.SURVIVING

var _total_seconds: float = 0.0
var _elapsed: float = 0.0
var _window_open := false
var _announced_marks: Dictionary[int, bool] = {}
var _remaining_enemies: int = 0


func _ready() -> void:
	add_to_group(&"run_objective")
	seconds_remaining = survival_seconds
	_total_seconds = survival_seconds
	time_changed.emit(seconds_remaining, _total_seconds)
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player != null and player.has_signal(&"died"):
		player.connect(&"died", _on_player_died)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager != null and wave_manager.has_signal(&"enemy_defeated"):
		wave_manager.connect(&"enemy_defeated", _on_enemy_defeated)


func _process(delta: float) -> void:
	if is_finished:
		return
	match phase:
		Phase.SURVIVING:
			_advance_clock(delta)
		Phase.LAST_STAND:
			_advance_last_stand()
		Phase.EXTRACTING:
			if is_player_in_extraction_zone():
				_finish()


func _advance_clock(delta: float) -> void:
	seconds_remaining = maxf(seconds_remaining - delta, 0.0)
	_elapsed += delta
	time_changed.emit(seconds_remaining, _total_seconds)
	_announce_marks()
	if not _window_open and seconds_remaining <= extraction_window_seconds:
		_open_extraction_window()
	if seconds_remaining <= 0.0:
		_begin_last_stand()


func _advance_last_stand() -> void:
	_elapsed += get_process_delta_time()
	var remaining := get_remaining_enemies()
	if remaining != _remaining_enemies:
		_remaining_enemies = remaining
		horde_remaining_changed.emit(remaining)
	if remaining <= 0:
		_begin_extraction()


func get_time_text() -> String:
	var total := int(ceil(seconds_remaining))
	return "%d:%02d" % [total / 60, total % 60]


## What the HUD puts where the clock goes. The clock reading 0:00 for the whole
## endgame told the player nothing about what to do next.
func get_objective_text() -> String:
	match phase:
		Phase.LAST_STAND:
			return "CLEAR  %d" % get_remaining_enemies()
		Phase.EXTRACTING:
			return "EXTRACT"
		Phase.FINISHED:
			return "COMPLETE"
	return get_time_text()


func get_remaining_enemies() -> int:
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager != null and wave_manager.has_method(&"get_living_enemy_count"):
		return int(wave_manager.call(&"get_living_enemy_count"))
	return get_tree().get_nodes_in_group(&"enemy").size()


func is_extraction_window_open() -> bool:
	return _window_open


## True once the map is clear and the zone will actually take the player.
func is_extraction_ready() -> bool:
	return phase == Phase.EXTRACTING


func get_extraction_position() -> Vector3:
	var core := get_tree().get_first_node_in_group(CAMP_CORE_GROUP) as Node3D
	return core.global_position if core != null else Vector3.ZERO


func is_player_in_extraction_zone() -> bool:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player == null:
		return false
	var flat_player := Vector2(player.global_position.x, player.global_position.z)
	var zone := get_extraction_position()
	return flat_player.distance_to(Vector2(zone.x, zone.z)) <= extraction_radius


func extend_run() -> void:
	# Push your luck: back to a running clock and a spawning director, for a
	# bigger payout on the next ending.
	if not is_finished:
		return
	extensions += 1
	is_finished = false
	_window_open = false
	_announced_marks.clear()
	seconds_remaining = extension_seconds
	_total_seconds = extension_seconds
	set_process(true)
	_set_horde_surge(false)
	_end_final_phase()
	_set_phase(Phase.SURVIVING)
	time_changed.emit(seconds_remaining, _total_seconds)
	run_extended.emit(extension_seconds, get_reward_multiplier())
	_request_feedback(
		"RUN EXTENDED  •  REWARD x%.1f" % get_reward_multiplier(), 4.0
	)


func get_reward_multiplier() -> float:
	return pow(extension_reward_multiplier, float(extensions))


func _open_extraction_window() -> void:
	_window_open = true
	_set_horde_surge(true)
	extraction_window_opened.emit(seconds_remaining)
	_request_feedback("HORDE SURGING  •  LAST STAND INBOUND", 5.0)


func _begin_last_stand() -> void:
	_set_phase(Phase.LAST_STAND)
	_set_horde_surge(false)
	# Closing the tap is what makes the rest of this possible: with the director
	# still spawning, "kill them all" would never finish.
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager != null and wave_manager.has_method(&"begin_final_phase"):
		wave_manager.call(&"begin_final_phase")
	_remaining_enemies = get_remaining_enemies()
	last_stand_started.emit(_remaining_enemies)
	horde_remaining_changed.emit(_remaining_enemies)
	_request_feedback(
		"LAST STAND  •  CLEAR THE HORDE  (%d LEFT)" % _remaining_enemies, 6.0
	)


func _begin_extraction() -> void:
	_set_phase(Phase.EXTRACTING)
	extraction_ready.emit()
	_request_feedback("MAP CLEAR  •  EXTRACTION OPEN AT CAMP", 6.0)


func _finish() -> void:
	if is_finished:
		return
	is_finished = true
	_set_phase(Phase.FINISHED)
	set_process(false)
	_set_horde_surge(false)
	_end_final_phase()
	# Reaching the zone is now the only way to complete a run, so it always pays
	# in full; the partial payout for being caught out of position went with the
	# clock that used to end the run wherever the player stood.
	var reward := int(round(extraction_credits * get_reward_multiplier()))
	SaveManager.add_credits(reward)
	run_finished.emit(_build_stats(true, reward, false))


func _on_player_died(_source: Variant = null) -> void:
	if is_finished:
		return
	is_finished = true
	_set_phase(Phase.FINISHED)
	set_process(false)
	_set_horde_surge(false)
	_end_final_phase()
	run_finished.emit(_build_stats(false, 0, true))


func _set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(int(phase))


func _end_final_phase() -> void:
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager != null and wave_manager.has_method(&"end_final_phase"):
		wave_manager.call(&"end_final_phase")


func _announce_marks() -> void:
	for mark in warning_marks:
		if _announced_marks.has(mark) or seconds_remaining > float(mark):
			continue
		_announced_marks[mark] = true
		if mark >= 60:
			_request_feedback("LAST STAND IN %d MINUTES" % (mark / 60))
		else:
			_request_feedback("LAST STAND IN %d SECONDS" % mark)


func _build_stats(extracted: bool, reward: int, died: bool) -> Dictionary:
	var scrap := 0
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null:
		scrap = (
			int(camp_economy.get(&"carried_scrap"))
			+ int(camp_economy.get(&"stored_scrap"))
		)
	var run_level := 1
	var progression := get_tree().get_first_node_in_group(RUN_PROGRESSION_GROUP)
	if progression != null:
		run_level = int(progression.get(&"run_level"))
	return {
		"extracted": extracted,
		"died": died,
		"seconds_survived": _elapsed,
		"credits": reward,
		"kills": kills,
		"scrap": scrap,
		"run_level": run_level,
		"extensions": extensions,
		"can_extend": not died,
	}


func _on_enemy_defeated(_xp_reward: int) -> void:
	kills += 1


func _set_horde_surge(active: bool) -> void:
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager != null and wave_manager.has_method(&"set_surge_active"):
		wave_manager.call(&"set_surge_active", active)


func _request_feedback(message: String, duration: float = 3.5) -> void:
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null and camp_economy.has_method(&"request_feedback"):
		camp_economy.call(&"request_feedback", message, duration)
