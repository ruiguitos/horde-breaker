class_name DestructibleRouteBridge
extends StaticBody3D

signal health_changed(current_health: float, maximum_health: float)
signal destroyed

@export_range(1.0, 5000.0, 1.0) var maximum_health := 400.0

var current_health := 400.0
var is_destroyed := false
var _planks: MultiMeshInstance3D
var _ropes: MeshInstance3D
var _collision: CollisionShape3D
var _status_label: Label3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	current_health = maximum_health


func configure(start: Vector3, end: Vector3) -> void:
	var horizontal := Vector3(end.x - start.x, 0.0, end.z - start.z)
	var length := horizontal.length()
	if length <= 1.0:
		push_error("DestructibleRouteBridge requires two distinct endpoints.")
		return
	global_position = (start + end) * 0.5
	rotation.y = atan2(-horizontal.normalized().z, horizontal.normalized().x)
	_build_planks(length)
	_build_ropes(length)
	_build_collision(length)
	_build_status_label(length)


func take_damage(amount: float) -> float:
	if amount <= 0.0 or is_destroyed:
		return 0.0
	var applied := minf(amount, current_health)
	current_health -= applied
	health_changed.emit(current_health, maximum_health)
	_update_status_label()
	if is_zero_approx(current_health):
		_collapse()
	return applied


func reset_bridge() -> void:
	is_destroyed = false
	current_health = maximum_health
	if _planks != null:
		_planks.visible = true
	if _ropes != null:
		_ropes.visible = true
	if _collision != null:
		# Deferred, to match _collapse(). Setting it directly meant a bridge
		# destroyed and repaired inside one frame ended the frame with the
		# collapse's deferred "disabled = true" landing *after* this, so the
		# bridge stood there looking whole with nothing to walk on — the soft-lock
		# the archipelago plan forbids, wearing a repaired bridge as a disguise.
		_collision.set_deferred(&"disabled", false)
	_update_status_label()
	health_changed.emit(current_health, maximum_health)


func _collapse() -> void:
	is_destroyed = true
	_planks.visible = false
	_ropes.visible = false
	_collision.set_deferred(&"disabled", true)
	_update_status_label()
	destroyed.emit()


func _build_planks(length: float) -> void:
	var plank_material := StandardMaterial3D.new()
	plank_material.albedo_color = Color(0.29, 0.14, 0.055)
	plank_material.roughness = 0.96
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(1.12, 0.16, 3.4)
	plank_mesh.material = plank_material
	var plank_count := maxi(2, floori(length / 1.25))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = plank_mesh
	multimesh.instance_count = plank_count
	for index in range(plank_count):
		var progress := float(index) / float(plank_count - 1)
		var sag := sin(progress * PI) * -0.16
		multimesh.set_instance_transform(
			index,
			Transform3D(Basis.IDENTITY, Vector3(lerpf(-length * 0.5, length * 0.5, progress), sag, 0.0))
		)
	_planks = MultiMeshInstance3D.new()
	_planks.name = "Planks"
	_planks.multimesh = multimesh
	add_child(_planks)


func _build_ropes(length: float) -> void:
	var rope_material := StandardMaterial3D.new()
	rope_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_material.albedo_color = Color(0.18, 0.09, 0.035)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for side in [-1.0, 1.0]:
		for index in range(24):
			var progress_a := float(index) / 24.0
			var progress_b := float(index + 1) / 24.0
			for progress in [progress_a, progress_b]:
				surface.add_vertex(Vector3(
					lerpf(-length * 0.5, length * 0.5, progress),
					0.85 - sin(progress * PI) * 0.75,
					side * 1.75
				))
	_ropes = MeshInstance3D.new()
	_ropes.name = "Ropes"
	_ropes.mesh = surface.commit()
	_ropes.material_override = rope_material
	add_child(_ropes)


func _build_collision(length: float) -> void:
	_collision = CollisionShape3D.new()
	_collision.name = "BridgeCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 0.22, 3.35)
	_collision.shape = shape
	_collision.position.y = -0.35
	add_child(_collision)


func _build_status_label(length: float) -> void:
	_status_label = Label3D.new()
	_status_label.name = "StatusLabel"
	_status_label.position = Vector3(-length * 0.42, 2.2, 0.0)
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.fixed_size = false
	_status_label.font_size = 42
	_status_label.pixel_size = 0.008
	_status_label.outline_size = 8
	_status_label.modulate = Color(0.95, 0.72, 0.34)
	add_child(_status_label)
	_update_status_label()


func _update_status_label() -> void:
	if _status_label == null:
		return
	_status_label.text = (
		"ROUTE C // BRIDGE DESTROYED"
		if is_destroyed
		else "ROUTE C // ROPE BRIDGE // %d HP" % roundi(current_health)
	)
