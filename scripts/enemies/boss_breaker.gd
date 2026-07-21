extends "res://scripts/enemies/normal_zombie.gd"

## The Breaker: a tanky boss that knocks the player back and periodically
## summons minions around itself while the fight drags on.

const ENEMY_GROUP := &"enemy"
const SUMMON_ENEMY_CAP := 24

@export var summon_scene: PackedScene
@export_range(4.0, 30.0, 0.5) var summon_interval: float = 12.0
@export_range(1, 6, 1) var summon_count: int = 2
@export_range(1.5, 6.0, 0.25) var summon_radius: float = 3.0

var _summon_time: float = 0.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if summon_scene == null or not is_instance_valid(_target):
		return
	_summon_time += delta
	if _summon_time >= summon_interval:
		_summon_time = 0.0
		_summon_minions()


func _summon_minions() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Keep the arena from snowballing while the boss is alive.
	if get_tree().get_nodes_in_group(ENEMY_GROUP).size() >= SUMMON_ENEMY_CAP:
		return
	for minion_index in summon_count:
		var minion := summon_scene.instantiate() as Node3D
		if minion == null:
			continue
		parent.add_child(minion)
		var angle := TAU * float(minion_index) / float(summon_count)
		minion.global_position = global_position + Vector3(
			cos(angle) * summon_radius, 0.0, sin(angle) * summon_radius
		)
