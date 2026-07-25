extends Area3D

signal collected

const PLAYER_GROUP := &"player"
const WAVE_MANAGER_GROUP := &"wave_manager"
const CAMP_ECONOMY_GROUP := &"camp_economy"
# Deeper runs burn far more ammunition, so boxes grow with the threat level
# (base + 4 per level past the first, capped at 4x the base amount).
const AMMO_PER_THREAT_LEVEL := 4
const MAX_SCALE_MULTIPLIER := 4.0

## Once the reserve is full the box refuses collection and would otherwise sit
## on the ground for the rest of the run; it now clears itself out.
const FULL_RESERVE_DESPAWN_SECONDS := 20.0

@export_range(1, 200, 1) var ammunition_amount: int = 12
@export_range(0.0, 20.0, 0.5) var magnet_radius: float = 4.0

var _collected := false
var _despawn_scheduled := false
var _magnet := PickupMagnet.new()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_magnet.base_radius = magnet_radius


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if _magnet.update(self, delta):
		_collect(_magnet_player())


func _magnet_player() -> Node:
	return get_tree().get_first_node_in_group(PLAYER_GROUP)


func _on_body_entered(body: Node3D) -> void:
	# Auto-pickup: walking over the box collects it, no key press needed.
	if body != null and body.is_in_group(PLAYER_GROUP):
		_collect(body)


func interact(player: Node) -> bool:
	return _collect(player)


func get_scaled_amount() -> int:
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager == null:
		return ammunition_amount
	var threat_level := maxi(int(wave_manager.get(&"current_wave")), 1)
	var scaled := ammunition_amount + AMMO_PER_THREAT_LEVEL * (threat_level - 1)
	return mini(scaled, roundi(ammunition_amount * MAX_SCALE_MULTIPLIER))


func _collect(player: Node) -> bool:
	if _collected or player == null or not player.has_method(&"add_ammunition"):
		return false
	var added_ammunition := int(
		player.call(&"add_ammunition", get_scaled_amount())
	)
	if added_ammunition <= 0:
		# Reserve full: the box is useless from here on, so start its clock
		# instead of leaving it lying around.
		_schedule_full_reserve_despawn()
		return false
	_collected = true
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null and camp_economy.has_method(&"request_feedback"):
		camp_economy.call(&"request_feedback", "+%d AMMO" % added_ammunition)
	collected.emit()
	queue_free()
	return true


func _schedule_full_reserve_despawn() -> void:
	if _despawn_scheduled:
		return
	_despawn_scheduled = true
	var pickup_reference: WeakRef = weakref(self)
	get_tree().create_timer(FULL_RESERVE_DESPAWN_SECONDS).timeout.connect(
		func() -> void:
			var pickup: Node = pickup_reference.get_ref() as Node
			if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
				pickup.queue_free()
	)
