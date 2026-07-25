extends Area3D

signal collected

const CAMP_ECONOMY_GROUP := &"camp_economy"
const PLAYER_GROUP := &"player"

@export_range(1, 500, 1) var scrap_amount: int = 25
@export_range(0.0, 300.0, 0.5) var despawn_seconds: float = 0.0
@export_range(0.0, 20.0, 0.5) var magnet_radius: float = 4.0

var _collected := false
var _magnet := PickupMagnet.new()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_magnet.base_radius = magnet_radius
	if despawn_seconds > 0.0:
		_schedule_despawn()


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if _magnet.update(self, delta):
		_collect(null)


func _schedule_despawn() -> void:
	var pickup_reference: WeakRef = weakref(self)
	get_tree().create_timer(despawn_seconds).timeout.connect(
		func() -> void:
			var pickup: Node = pickup_reference.get_ref() as Node
			if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
				pickup.queue_free()
	)


func _on_body_entered(body: Node3D) -> void:
	# Auto-pickup: walking over the cache collects it, no key press needed.
	if body != null and body.is_in_group(PLAYER_GROUP):
		_collect(body)


func interact(player: Node) -> bool:
	return _collect(player)


func _collect(_player: Node) -> bool:
	if _collected:
		return false
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy == null or not camp_economy.has_method(&"add_carried_scrap"):
		push_error("ScrapPickup requires a camp_economy node.")
		return false
	var collected_scrap := int(
		camp_economy.call(&"add_carried_scrap", scrap_amount)
	)
	if collected_scrap <= 0:
		return false
	_collected = true
	camp_economy.call(
		&"request_feedback", "+%d SCRAP CARRIED" % collected_scrap
	)
	collected.emit()
	queue_free()
	return true
