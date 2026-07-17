extends StaticBody3D

signal health_changed(current_health: float, maximum_health: float)
signal destroyed

@export_range(1.0, 5000.0, 1.0) var maximum_health: float = 500.0
@export_range(0.1, 5.0, 0.1) var attack_target_radius: float = 1.1

@onready var health_label: Label3D = %HealthLabel
@onready var core_light: OmniLight3D = %CoreLight

var current_health: float
var _is_destroyed: bool = false


func _ready() -> void:
	current_health = maximum_health
	_update_world_label()


func take_enemy_damage(amount: float) -> float:
	if amount <= 0.0 or _is_destroyed:
		return 0.0

	var applied_damage := minf(amount, current_health)
	current_health -= applied_damage
	health_changed.emit(current_health, maximum_health)
	_update_world_label()
	if is_zero_approx(current_health):
		_is_destroyed = true
		remove_from_group(&"enemy_target")
		core_light.light_color = Color(0.75, 0.08, 0.04, 1.0)
		destroyed.emit()
	return applied_damage


func get_attack_target_radius() -> float:
	return attack_target_radius


func _update_world_label() -> void:
	health_label.text = "CAMP CORE\n%d / %d" % [
		roundi(current_health), roundi(maximum_health)
	]
