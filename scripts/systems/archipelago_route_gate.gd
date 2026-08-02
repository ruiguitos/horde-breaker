class_name ArchipelagoRouteGate
extends Area3D

signal route_traversed(route_id: StringName, destination_island_id: StringName)

var route_data: IslandRouteData
var destination_position := Vector3.ZERO
var _info_label: Label3D
var _busy := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	_build_interaction_shape()
	_build_label()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func configure(data: IslandRouteData, destination: Vector3) -> void:
	route_data = data
	destination_position = destination
	_refresh_label()


func interact(player: Node) -> bool:
	if _busy or route_data == null or not player is CharacterBody3D:
		return false
	_busy = true
	var passenger := player as CharacterBody3D
	passenger.velocity = Vector3.ZERO
	passenger.global_position = destination_position
	route_traversed.emit(route_data.route_id, route_data.destination_island_id)
	# The destination is outside this trigger. Waiting one physics frame protects
	# against two interaction events arriving in the same input dispatch.
	_unlock_after_frame.call_deferred()
	return true


func _unlock_after_frame() -> void:
	await get_tree().physics_frame
	_busy = false


func _build_interaction_shape() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := SphereShape3D.new()
	shape.radius = 3.2
	collision.shape = shape
	add_child(collision)


func _build_label() -> void:
	_info_label = Label3D.new()
	_info_label.name = "InfoLabel"
	_info_label.position.y = 3.2
	_info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_info_label.no_depth_test = true
	_info_label.fixed_size = true
	_info_label.font_size = 19
	_info_label.outline_size = 6
	_info_label.modulate = Color(0.34, 0.82, 1.0)
	_info_label.visible = false
	add_child(_info_label)
	_refresh_label()


func _refresh_label() -> void:
	if _info_label == null or route_data == null:
		return
	_info_label.text = "%s\n[F] ENTER FLOODED TUNNEL" % route_data.display_name.to_upper()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_info_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_info_label.visible = false
