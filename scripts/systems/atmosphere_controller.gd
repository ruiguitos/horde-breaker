class_name AtmosphereController
extends Node

const WAVE_MANAGER_GROUP := &"wave_manager"
const PRESETS: Dictionary[StringName, Environment] = {
	&"calm": preload("res://resources/atmosphere_presets/calm.tres"),
	&"threat_5": preload("res://resources/atmosphere_presets/threat_5.tres"),
	&"threat_10": preload("res://resources/atmosphere_presets/threat_10.tres"),
	&"nightmare": preload("res://resources/atmosphere_presets/nightmare.tres"),
}

@export var world_environment_path: NodePath
@export var directional_light_path: NodePath
@export_range(0.1, 8.0, 0.1) var transition_duration: float = 1.8

@onready var world_environment: WorldEnvironment = get_node(world_environment_path) as WorldEnvironment
@onready var directional_light: DirectionalLight3D = get_node(directional_light_path) as DirectionalLight3D

var _active_preset: StringName = &""
var _light_tween: Tween


func _ready() -> void:
	if world_environment == null or directional_light == null:
		push_error("AtmosphereController requires a WorldEnvironment and DirectionalLight3D.")
		return
	apply_preset(0)
	call_deferred(&"_connect_wave_manager")


func apply_preset(threat_level: int) -> void:
	var preset_name := _get_preset_name(threat_level)
	if preset_name == _active_preset:
		return
	_active_preset = preset_name
	var preset: Environment = PRESETS[preset_name]
	world_environment.environment = preset.duplicate(true) as Environment
	var target_pitch := deg_to_rad(-24.0)
	var target_color := Color(1.0, 0.94, 0.84, 1.0)
	var target_energy := 1.0
	match preset_name:
		&"threat_5":
			target_pitch = deg_to_rad(-34.0)
			target_color = Color(1.0, 0.77, 0.55, 1.0)
			target_energy = 1.15
		&"threat_10":
			target_pitch = deg_to_rad(-43.0)
			target_color = Color(1.0, 0.57, 0.3, 1.0)
			target_energy = 1.28
		&"nightmare":
			target_pitch = deg_to_rad(-52.0)
			target_color = Color(0.95, 0.25, 0.13, 1.0)
			target_energy = 1.05
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = create_tween().set_parallel(true)
	_light_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_light_tween.tween_property(
		directional_light, "rotation:x", target_pitch, transition_duration
	)
	_light_tween.tween_property(
		directional_light, "light_color", target_color, transition_duration
	)
	_light_tween.tween_property(
		directional_light, "light_energy", target_energy, transition_duration
	)


func _get_preset_name(threat_level: int) -> StringName:
	if threat_level >= 15:
		return &"nightmare"
	if threat_level >= 10:
		return &"threat_10"
	if threat_level >= 5:
		return &"threat_5"
	return &"calm"


func _connect_wave_manager() -> void:
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager == null:
		return
	var callable := Callable(self, "apply_preset")
	if not wave_manager.is_connected(&"wave_started", callable):
		wave_manager.connect(&"wave_started", callable)
	apply_preset(int(wave_manager.get("current_wave")))
