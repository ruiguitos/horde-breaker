class_name WaveData
extends Resource

@export_range(0, 100, 1) var normal_zombie_count: int = 0
@export_range(0, 100, 1) var runner_zombie_count: int = 0


func get_total_enemy_count() -> int:
	return normal_zombie_count + runner_zombie_count
