class_name IslandData
extends Resource

@export var island_id: StringName = &""
@export var display_name := ""
@export var terrain_type := ""
@export var difficulty := ""
@export_multiline var description := ""
@export var world_position := Vector2.ZERO
@export var map_position := Vector2.ZERO
@export var connection_ids: Array[StringName] = []


func connects_to(destination_id: StringName) -> bool:
	return destination_id in connection_ids
