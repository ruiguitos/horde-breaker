extends Node3D

signal sector_loaded(sector_id: StringName)
signal sector_unloaded(sector_id: StringName)
signal sector_state_changed(sector_id: StringName)

const PLAYER_GROUP := &"player"
const EAST_SECTOR_ID := &"east"

@export var east_sector_scene: PackedScene
@export var east_sector_position := Vector3(64, 0, 0)
@export_range(0.0, 32.0, 0.5) var load_trigger_x: float = 18.0
@export_range(-16.0, 32.0, 0.5) var unload_trigger_x: float = 8.0

var _player: Node3D
var _east_sector: Node3D
var _east_beacon_activated := false


func _ready() -> void:
	if unload_trigger_x >= load_trigger_x:
		push_error("WorldStreamer unload trigger must be lower than its load trigger.")
	call_deferred(&"_find_player")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()
	if not is_instance_valid(_player):
		return
	if _player.global_position.x >= load_trigger_x:
		load_east_sector()
	elif _player.global_position.x <= unload_trigger_x:
		unload_east_sector()


func load_east_sector() -> bool:
	if is_instance_valid(_east_sector):
		return false
	if east_sector_scene == null:
		push_error("WorldStreamer requires an east sector scene.")
		return false
	var sector := east_sector_scene.instantiate() as Node3D
	if sector == null:
		push_error("WorldStreamer sector scenes must use a Node3D root.")
		return false
	sector.name = "EastSector"
	add_child(sector)
	sector.global_position = east_sector_position
	_east_sector = sector
	_configure_east_beacon()
	sector_loaded.emit(EAST_SECTOR_ID)
	return true


func unload_east_sector() -> bool:
	if not is_instance_valid(_east_sector):
		return false
	var sector := _east_sector
	_east_sector = null
	remove_child(sector)
	sector.queue_free()
	sector_unloaded.emit(EAST_SECTOR_ID)
	return true


func is_east_sector_loaded() -> bool:
	return is_instance_valid(_east_sector)


func get_loaded_sector_count() -> int:
	return 1 if is_east_sector_loaded() else 0


func get_east_sector() -> Node3D:
	return _east_sector if is_instance_valid(_east_sector) else null


func is_east_beacon_activated() -> bool:
	return _east_beacon_activated


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D


func _configure_east_beacon() -> void:
	var beacon := _east_sector.get_node_or_null("%ExpeditionBeacon") as Area3D
	if beacon == null or not beacon.has_method(&"configure"):
		push_error("East sector requires a unique ExpeditionBeacon node.")
		return
	beacon.call(&"configure", _east_beacon_activated)
	beacon.connect(&"activated", _on_east_beacon_activated)


func _on_east_beacon_activated() -> void:
	if _east_beacon_activated:
		return
	_east_beacon_activated = true
	sector_state_changed.emit(EAST_SECTOR_ID)
