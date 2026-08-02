class_name ShadowForestNest
extends StaticBody3D

## A zombie nest in the Shadow Forest: shot until it collapses, and it gives up a
## winch part when it does.
##
## Damageable rather than interactable on purpose. The island's identity in
## docs/ARCHIPELAGO_GAMEPLAY_PLAN.md is low visibility and short ambushes, and an
## objective you *clear* fits that where one you walk up to and press F does not.
## The bridge next door already works this way, so the damage path is the one the
## world objects here share.

signal health_changed(current_health: float, maximum_health: float)
signal cleared(nest_id: StringName)

@export_range(20.0, 2000.0, 10.0) var maximum_health: float = 320.0

var nest_id: StringName = &""
var current_health: float = 0.0
var is_cleared := false

var _label: Label3D
var _mound: MeshInstance3D
var _glow: OmniLight3D


func _ready() -> void:
	# Layer 1 so shots and the navigation bake both see it; it never chases
	# anything, so it masks nothing.
	collision_layer = 1
	collision_mask = 0
	current_health = maximum_health
	add_to_group(&"shadow_forest_nest")
	_refresh_label()


func configure(id: StringName, health: float = 0.0) -> void:
	nest_id = id
	if health > 0.0:
		maximum_health = health
	current_health = maximum_health
	if is_node_ready():
		_refresh_label()


## Returns the damage actually taken, matching the enemy contract so the same
## weapon code can hit either without knowing the difference.
func take_damage(amount: float) -> float:
	if amount <= 0.0 or is_cleared:
		return 0.0
	var applied := minf(amount, current_health)
	current_health -= applied
	health_changed.emit(current_health, maximum_health)
	_refresh_label()
	if is_zero_approx(current_health):
		_collapse()
	return applied


func get_health_ratio() -> float:
	return current_health / maximum_health if maximum_health > 0.0 else 0.0


func build_visuals() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.13, 0.16, 0.12)
	material.emission_enabled = true
	material.emission = Color(0.36, 0.72, 0.24)
	material.emission_energy_multiplier = 1.4
	material.roughness = 0.85

	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 2.1
	mound_mesh.height = 2.8
	mound_mesh.radial_segments = 12
	mound_mesh.rings = 6
	mound_mesh.material = material
	_mound = MeshInstance3D.new()
	_mound.name = "NestMound"
	_mound.position.y = 0.9
	_mound.mesh = mound_mesh
	add_child(_mound)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	collision.position.y = 1.0
	collision.shape = shape
	add_child(collision)

	_glow = OmniLight3D.new()
	_glow.name = "NestGlow"
	_glow.position.y = 1.4
	_glow.light_color = Color(0.42, 0.85, 0.3)
	_glow.light_energy = 1.6
	_glow.omni_range = 8.0
	_glow.shadow_enabled = false
	add_child(_glow)

	_label = Label3D.new()
	_label.name = "InfoLabel"
	_label.position.y = 3.4
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Scales with distance and lets the terrain hide it. fixed_size keeps a
	# label the same size on screen however far away it is, which with
	# no_depth_test meant every label on every island was drawn at full size
	# on top of the player, piled on each other and unreadable.
	_label.no_depth_test = false
	_label.fixed_size = false
	_label.pixel_size = 0.011
	_label.visibility_range_end = 70.0
	_label.visibility_range_end_margin = 12.0
	_label.font_size = 18
	_label.outline_size = 7
	_label.modulate = Color(0.6, 1.0, 0.45)
	add_child(_label)
	_refresh_label()


func _collapse() -> void:
	is_cleared = true
	if _mound != null:
		_mound.scale = Vector3(1.15, 0.25, 1.15)
	if _glow != null:
		_glow.light_energy = 0.35
	# The nest stays solid once cleared: it is cover, and removing collision
	# under a player standing on it is the kind of surprise nobody enjoys.
	_refresh_label()
	cleared.emit(nest_id)


func _refresh_label() -> void:
	if _label == null:
		return
	if is_cleared:
		_label.text = "NEST CLEARED"
		_label.modulate = Color(0.5, 0.6, 0.55)
		return
	_label.text = "ZOMBIE NEST\n%d%%" % roundi(get_health_ratio() * 100.0)
