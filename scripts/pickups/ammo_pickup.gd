extends Area3D

signal collected

@export_range(1, 200, 1) var ammunition_amount: int = 12


func interact(player: Node) -> bool:
	if player == null or not player.has_method(&"add_ammunition"):
		return false
	var added_ammunition := int(
		player.call(&"add_ammunition", ammunition_amount)
	)
	if added_ammunition <= 0:
		return false
	collected.emit()
	queue_free()
	return true
