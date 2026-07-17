class_name WeaponData
extends Resource

@export var weapon_id: StringName = &""
@export var display_name: String = ""
@export var required_character_id: StringName = &""
@export_range(1, 100, 1) var required_level: int = 1
@export_range(0, 100000, 1) var credit_cost: int = 0
@export var is_playable: bool = false
