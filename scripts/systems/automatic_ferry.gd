class_name AutomaticFerry
extends AnimatableBody3D

signal trip_started(destination_index: int)
signal trip_completed(destination_index: int)

@export_range(1.0, 12.0, 0.25) var travel_duration := 4.5
@export var passenger_offset := Vector3(0.0, 1.35, 0.0)

var current_dock_index := 0
var _dock_positions: Array[Vector3] = []
var _disembark_positions: Array[Vector3] = []
var _passenger: CharacterBody3D
var _start_position := Vector3.ZERO
var _elapsed := 0.0
var _destination_index := 0
var _saved_collision_layer := 0
var _saved_collision_mask := 0
var _moving := false


func _ready() -> void:
	_build_low_poly_ferry()
	set_physics_process(false)


func configure(
	dock_positions: Array[Vector3], disembark_positions: Array[Vector3]
) -> void:
	if dock_positions.size() != 2 or disembark_positions.size() != 2:
		push_error("AutomaticFerry requires exactly two docks and two landing points.")
		return
	_dock_positions = dock_positions
	_disembark_positions = disembark_positions
	current_dock_index = 0
	global_position = _dock_positions[0]


func request_trip(destination_index: int, player: Node) -> bool:
	if (
		_moving
		or destination_index < 0
		or destination_index >= _dock_positions.size()
		or destination_index == current_dock_index
		or not player is CharacterBody3D
	):
		return false
	_passenger = player as CharacterBody3D
	_destination_index = destination_index
	_start_position = global_position
	_elapsed = 0.0
	_moving = true
	_saved_collision_layer = _passenger.collision_layer
	_saved_collision_mask = _passenger.collision_mask
	_passenger.collision_layer = 0
	_passenger.collision_mask = 0
	_passenger.velocity = Vector3.ZERO
	if _passenger.has_method(&"set_gameplay_input_enabled"):
		_passenger.call(&"set_gameplay_input_enabled", false)
	_passenger.set_physics_process(false)
	_place_passenger()
	set_physics_process(true)
	trip_started.emit(destination_index)
	return true


func is_moving() -> bool:
	return _moving


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / maxf(travel_duration, 0.01), 0.0, 1.0)
	var eased_progress := smoothstep(0.0, 1.0, progress)
	global_position = _start_position.lerp(
		_dock_positions[_destination_index], eased_progress
	)
	_place_passenger()
	if progress >= 1.0:
		_complete_trip()


func _place_passenger() -> void:
	if is_instance_valid(_passenger):
		_passenger.global_position = global_position + passenger_offset
		_passenger.global_rotation.y = global_rotation.y


func _complete_trip() -> void:
	_moving = false
	set_physics_process(false)
	current_dock_index = _destination_index
	global_position = _dock_positions[current_dock_index]
	if is_instance_valid(_passenger):
		_passenger.global_position = _disembark_positions[current_dock_index]
		_passenger.velocity = Vector3.ZERO
		_passenger.collision_layer = _saved_collision_layer
		_passenger.collision_mask = _saved_collision_mask
		_passenger.set_physics_process(true)
		if _passenger.has_method(&"set_gameplay_input_enabled"):
			_passenger.call(&"set_gameplay_input_enabled", true)
	_passenger = null
	trip_completed.emit(current_dock_index)


func _build_low_poly_ferry() -> void:
	var hull_material := StandardMaterial3D.new()
	hull_material.albedo_color = Color(0.18, 0.08, 0.035, 1.0)
	hull_material.roughness = 0.88
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _create_hull_mesh(hull_material)
	add_child(hull)

	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color(0.48, 0.29, 0.11, 1.0)
	deck_material.roughness = 0.95
	var deck := MeshInstance3D.new()
	deck.name = "Deck"
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(5.2, 0.18, 2.25)
	deck_mesh.material = deck_material
	deck.mesh = deck_mesh
	deck.position.y = 0.12
	add_child(deck)

	var cabin_material := StandardMaterial3D.new()
	cabin_material.albedo_color = Color(0.78, 0.42, 0.08, 1.0)
	cabin_material.roughness = 0.8
	var cabin := MeshInstance3D.new()
	cabin.name = "Cabin"
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.5, 0.9, 1.55)
	cabin_mesh.material = cabin_material
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(-1.25, 0.65, 0.0)
	add_child(cabin)

	var collision := CollisionShape3D.new()
	collision.name = "HullCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.8, 1.0, 2.7)
	collision.shape = shape
	collision.position.y = -0.15
	add_child(collision)


func _create_hull_mesh(material: Material) -> ArrayMesh:
	var top := [
		Vector3(3.4, 0.0, 0.0), Vector3(2.0, 0.0, -1.4),
		Vector3(-2.9, 0.0, -1.2), Vector3(-2.9, 0.0, 1.2),
		Vector3(2.0, 0.0, 1.4),
	]
	var bottom := [
		Vector3(2.55, -0.85, 0.0), Vector3(1.45, -0.85, -0.72),
		Vector3(-2.35, -0.85, -0.65), Vector3(-2.35, -0.85, 0.65),
		Vector3(1.45, -0.85, 0.72),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(top.size()):
		var next := (index + 1) % top.size()
		_add_triangle(surface, top[index], bottom[index], bottom[next])
		_add_triangle(surface, top[index], bottom[next], top[next])
	_add_triangle(surface, bottom[0], bottom[2], bottom[1])
	_add_triangle(surface, bottom[0], bottom[3], bottom[2])
	_add_triangle(surface, bottom[0], bottom[4], bottom[3])
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _add_triangle(
	surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3
) -> void:
	surface.add_vertex(first)
	surface.add_vertex(second)
	surface.add_vertex(third)
