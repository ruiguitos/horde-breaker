class_name StructureData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(0, 10000, 1) var scrap_cost: int = 0
@export var scene: PackedScene
@export var grid_size: Vector2i = Vector2i(1, 1)
@export_range(0.0, 60.0, 0.1) var build_time: float = 0.0
@export_range(1, 10000, 1) var max_health: int = 100
@export var requires_upgrade: StringName = &""
@export var icon: Texture2D
@export var category: StringName = &"defense"
