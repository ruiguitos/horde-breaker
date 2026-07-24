class_name StructureBase
extends StaticBody3D

signal health_changed(current_health: int, maximum_health: int)
signal structure_destroyed(structure: StructureBase)

const GHOST_VALID_COLOR := Color(0.18, 0.95, 0.42, 0.48)
const GHOST_INVALID_COLOR := Color(1.0, 0.2, 0.16, 0.48)

@export var data: StructureData
@export var is_ghost: bool = false

var current_health: int = -1
var grid_position: Vector2i = Vector2i.ZERO
var rotation_steps: int = 0
var _ghost_material: StandardMaterial3D
var _ghost_valid_state: int = -1


func _ready() -> void:
	if data == null:
		push_error("StructureBase requires StructureData before entering the scene tree.")
		return
	if current_health < 0:
		current_health = data.max_health
	if is_ghost:
		_configure_as_ghost()
	else:
		add_to_group(&"navigation_blocker")
		add_to_group(&"built_structure")


func take_damage(amount: int) -> void:
	if amount <= 0 or is_ghost or current_health <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, data.max_health)
	if current_health <= 0:
		destroy()


func repair(amount: int) -> int:
	if amount <= 0 or is_ghost or data == null:
		return 0
	var repaired := mini(amount, data.max_health - current_health)
	current_health += repaired
	if repaired > 0:
		health_changed.emit(current_health, data.max_health)
	return repaired


func destroy() -> void:
	if is_ghost:
		queue_free()
		return
	structure_destroyed.emit(self)
	queue_free()


func set_ghost_valid(valid: bool) -> void:
	if not is_ghost:
		return
	var next_state := 1 if valid else 0
	if next_state == _ghost_valid_state:
		return
	_ghost_valid_state = next_state
	if _ghost_material == null:
		_ghost_material = _create_ghost_material()
	_ghost_material.albedo_color = (
		GHOST_VALID_COLOR if valid else GHOST_INVALID_COLOR
	)


func _configure_as_ghost() -> void:
	collision_layer = 0
	collision_mask = 0
	for node in find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision != null:
			collision.disabled = true
	for node in find_children("*", "Area3D", true, false):
		var area := node as Area3D
		if area == null:
			continue
		area.monitoring = false
		area.monitorable = false
	for node in find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light != null:
			light.visible = false
	_ghost_material = _create_ghost_material()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.material_override = _ghost_material
	set_ghost_valid(true)


func _create_ghost_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GHOST_VALID_COLOR
	material.no_depth_test = true
	return material
