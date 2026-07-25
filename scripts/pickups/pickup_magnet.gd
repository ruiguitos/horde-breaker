class_name PickupMagnet
extends RefCounted

## Shared magnet behaviour for ground pickups. XP orbs had this to themselves;
## scrap, ammo and health now use the same routine so the MAGNETIC FIELD upgrade
## (and the Expedition skill of the same name) pulls in everything, not just XP.
##
## Held by the pickup and stepped from its _physics_process — a RefCounted
## helper rather than a node, so nothing is added to the scene tree per pickup.

const PLAYER_GROUP := &"player"
const RUN_PROGRESSION_GROUP := &"run_progression"
## Distance at which the pickup is considered to have reached the player.
const REACH_DISTANCE := 0.6

var base_radius: float = 4.0
var speed: float = 11.0

var _player: Node3D
var _progression: Node


## Moves `pickup` toward the player when in range. Returns true once it has
## arrived, which is the caller's cue to collect itself.
func update(pickup: Node3D, delta: float) -> bool:
	if not is_instance_valid(_player):
		_player = pickup.get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
		if not is_instance_valid(_player):
			return false
	var radius := base_radius * get_radius_multiplier(pickup)
	var target := _player.global_position + Vector3.UP * 0.5
	var distance := pickup.global_position.distance_to(target)
	if distance > radius:
		return false
	# Accelerates as it closes in, so collection feels snappy rather than floaty.
	var closing_speed := speed * (1.0 + (1.0 - distance / maxf(radius, 0.01)))
	pickup.global_position = pickup.global_position.move_toward(
		target, closing_speed * delta
	)
	return distance <= REACH_DISTANCE


func get_radius_multiplier(pickup: Node3D) -> float:
	if not is_instance_valid(_progression):
		_progression = pickup.get_tree().get_first_node_in_group(
			RUN_PROGRESSION_GROUP
		)
		if not is_instance_valid(_progression):
			return 1.0
	return float(_progression.get(&"pickup_radius_multiplier"))
