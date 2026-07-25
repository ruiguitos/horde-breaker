extends Area3D

## XP orb dropped by enemies. It flies toward the player once inside the magnet
## radius (scaled by the MAGNETIC FIELD upgrade) and is collected on contact,
## feeding the survivors-like run level.

signal collected

const PLAYER_GROUP := &"player"
const RUN_PROGRESSION_GROUP := &"run_progression"
const ORB_GROUP := &"xp_orb"
const MAX_ACTIVE_ORBS := 120
const LIFETIME_SECONDS := 30.0

@export_range(1, 100, 1) var xp_amount: int = 1
@export_range(1.0, 20.0, 0.5) var magnet_radius: float = 5.0
@export_range(1.0, 40.0, 0.5) var magnet_speed: float = 12.0

var _player: Node3D
var _progression: Node
var _collected := false


func _ready() -> void:
	add_to_group(ORB_GROUP)
	body_entered.connect(_on_body_entered)
	_progression = get_tree().get_first_node_in_group(RUN_PROGRESSION_GROUP)
	# Cheap safety valve: heavy hordes could otherwise flood the scene.
	var orbs := get_tree().get_nodes_in_group(ORB_GROUP)
	if orbs.size() > MAX_ACTIVE_ORBS:
		var oldest: Node = orbs[0]
		if is_instance_valid(oldest) and oldest != self:
			oldest.queue_free()
	get_tree().create_timer(LIFETIME_SECONDS).timeout.connect(_expire)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
		if not is_instance_valid(_player):
			return
	var radius := magnet_radius
	if is_instance_valid(_progression):
		radius *= float(_progression.get(&"pickup_radius_multiplier"))
	var target := _player.global_position + Vector3.UP * 0.5
	var distance := global_position.distance_to(target)
	if distance > radius:
		return
	# Accelerate as it gets closer so collection feels snappy.
	var speed := magnet_speed * (1.0 + (1.0 - distance / maxf(radius, 0.01)))
	global_position = global_position.move_toward(target, speed * delta)
	if distance <= 0.6:
		_collect()


func _on_body_entered(body: Node3D) -> void:
	if body != null and body.is_in_group(PLAYER_GROUP):
		_collect()


func _collect() -> void:
	if _collected:
		return
	if not is_instance_valid(_progression):
		_progression = get_tree().get_first_node_in_group(RUN_PROGRESSION_GROUP)
	if is_instance_valid(_progression):
		_progression.call(&"add_run_xp", xp_amount)
	_collected = true
	collected.emit()
	queue_free()


func _expire() -> void:
	if not _collected and is_instance_valid(self):
		queue_free()
