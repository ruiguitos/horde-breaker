extends Area3D

signal collected

const PLAYER_GROUP := &"player"

@export_range(1, 200, 1) var ammunition_amount: int = 12

var _collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Auto-pickup: walking over the box collects it, no key press needed.
	if body != null and body.is_in_group(PLAYER_GROUP):
		_collect(body)


func interact(player: Node) -> bool:
	return _collect(player)


func _collect(player: Node) -> bool:
	if _collected or player == null or not player.has_method(&"add_ammunition"):
		return false
	var added_ammunition := int(
		player.call(&"add_ammunition", ammunition_amount)
	)
	if added_ammunition <= 0:
		return false
	_collected = true
	collected.emit()
	queue_free()
	return true
