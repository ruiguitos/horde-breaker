class_name CharacterData
extends Resource

@export var character_id: StringName = &""
@export var display_name: String = ""
## Squad roster switch. Turning this off hides the class from the selection
## screen and from spawning without deleting anything, so it can come back the
## day the squad grows again.
@export var is_selectable: bool = true
@export_range(1, 100, 1) var maximum_level: int = 10
@export_range(0, 100000, 1) var unlock_cost: int = 0
@export_range(1.0, 1000.0, 1.0) var base_health: float = 100.0
@export var primary_weapon_id: StringName = &""
@export var secondary_weapon_id: StringName = &""
@export_range(0.1, 2.0, 0.05) var reload_duration_multiplier: float = 1.0
@export_range(0.0, 100.0, 0.5) var health_regeneration_rate: float = 1.0
@export_range(0.0, 30.0, 0.5) var health_regeneration_delay: float = 6.0
@export_multiline var class_description: String = ""
@export var character_scene: PackedScene
