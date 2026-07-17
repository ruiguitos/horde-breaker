class_name CharacterData
extends Resource

@export var character_id: StringName = &""
@export var display_name: String = ""
@export_range(1, 100, 1) var maximum_level: int = 10
@export_range(1.0, 1000.0, 1.0) var base_health: float = 100.0
@export var starting_weapon_id: StringName = &""
