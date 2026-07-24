class_name PropPlacementRules
extends Resource

@export_range(0, 15, 1) var maximum_collidable_props: int = 15
@export_range(0, 40, 1) var maximum_visual_props: int = 40
@export_range(0.0, 1.0, 0.05) var ac_unit_chance_per_building: float = 0.3
@export_range(0.0, 1.0, 0.05) var drain_chance_per_building: float = 0.65
@export_range(0, 4, 1) var abandoned_car_minimum: int = 1
@export_range(0, 4, 1) var abandoned_car_maximum: int = 2
@export_range(0, 20, 1) var trash_pile_minimum: int = 4
@export_range(0, 40, 1) var trash_pile_maximum: int = 10
