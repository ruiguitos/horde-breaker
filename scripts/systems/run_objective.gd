extends Node

## Survivors-like run structure in five beats:
##   1. survive the clock                    4. summary of the run
##   2. extraction window opens (return to   5. option to extend for a bigger
##      camp while the horde surges)            payout
##   3. extract in the zone, or miss it for a reduced reward

signal time_changed(seconds_remaining: float, total_seconds: float)
signal extraction_window_opened(seconds_remaining: float)
signal run_finished(stats: Dictionary)
signal run_extended(added_seconds: float, reward_multiplier: float)

const CAMP_ECONOMY_GROUP := &"camp_economy"
const CAMP_CORE_GROUP := &"camp_core"
const PLAYER_GROUP := &"player"
const WAVE_MANAGER_GROUP := &"wave_manager"
const RUN_PROGRESSION_GROUP := &"run_progression"

@export_range(60.0, 3600.0, 30.0) var survival_seconds: float = 600.0
## Final stretch: the extraction zone opens and the horde surges.
@export_range(15.0, 300.0, 5.0) var extraction_window_seconds: float = 60.0
@export_range(4.0, 40.0, 1.0) var extraction_radius: float = 14.0
@export_range(0, 10000, 25) var extraction_credits: int = 300
## Missing the pickup still pays, just far less.
@export_range(0.0, 1.0, 0.05) var missed_reward_ratio: float = 0.35
@export_range(60.0, 900.0, 30.0) var extension_seconds: float = 300.0
@export_range(1.0, 5.0, 0.25) var extension_reward_multiplier: float = 2.0
@export var warning_marks: Array[int] = [300, 120, 30, 10]

var seconds_remaining: float = 0.0
var is_finished: bool = false
var extensions: int = 0
var kills: int = 0

var _total_seconds: float = 0.0
var _elapsed: float = 0.0
var _window_open := false
var _announced_marks: Dictionary[int, bool] = {}


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
	seconds_remaining = maxf(seconds_remaining - delta, 0.0)
	_elapsed += delta
	time_changed.emit(seconds_remaining, _total_seconds)
	_announce_marks()
	if not _window_open and seconds_remaining <= extraction_window_seconds:
		_open_extraction_window()
	if seconds_remaining <= 0.0:
		_finish()


func get_time_text() -> String:
	var total := int(ceil(seconds_remaining))
	return "%d:%02d" % [total / 60, total % 60]


func is_extraction_window_open() -> bool:
	return _window_open


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
	# Phase 5: push your luck for a bigger payout on a harder clock.
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
	_request_feedback("EXTRACTION INBOUND  •  RETURN TO CAMP", 5.0)


func _announce_marks() -> void:
	for mark in warning_marks:
		if _announced_marks.has(mark) or seconds_remaining > float(mark):
			continue
		_announced_marks[mark] = true
		if mark >= 60:
			_request_feedback("EXTRACTION IN %d MINUTES" % (mark / 60))
		else:
			_request_feedback("EXTRACTION IN %d SECONDS" % mark)


func _finish() -> void:
	if is_finished:
		return
	is_finished = true
	set_process(false)
	_set_horde_surge(false)
	var extracted := is_player_in_extraction_zone()
	var reward := int(round(
		extraction_credits * get_reward_multiplier()
		* (1.0 if extracted else missed_reward_ratio)
	))
	SaveManager.add_credits(reward)
	run_finished.emit(_build_stats(extracted, reward, false))


func _on_player_died(_source: Variant = null) -> void:
	if is_finished:
		return
	is_finished = true
	set_process(false)
	_set_horde_surge(false)
	run_finished.emit(_build_stats(false, 0, true))


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
