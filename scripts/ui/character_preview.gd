extends Node3D

const CHARACTER_MODELS := {
	&"recruit": preload(
		"res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Matt.gltf"
	),
	&"renegade": preload(
		"res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Lis.gltf"
	),
	&"medic": preload(
		"res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Sam.gltf"
	),
}
const EMBEDDED_WEAPON_NAMES: Array[StringName] = [
	&"Axe",
	&"Guitar",
	&"Knife",
	&"Pistol",
	&"Rifle",
	&"Shotgun",
	&"SMG",
	&"Spear",
	&"WoodenBat_Barbed",
	&"WoodenBat_Saw",
]
const PREVIEW_WEAPONS := {
	&"recruit": &"Rifle",
	&"renegade": &"Shotgun",
	&"medic": &"Pistol",
}

@export_range(0.0, 30.0, 0.1) var rotation_speed_degrees: float = 8.0

@onready var model_anchor: Node3D = %ModelAnchor

var _character_id: StringName = &""


func _process(delta: float) -> void:
	model_anchor.rotate_y(deg_to_rad(rotation_speed_degrees) * delta)


func show_character(character_id: StringName) -> void:
	if character_id == _character_id or not CHARACTER_MODELS.has(character_id):
		return
	_character_id = character_id
	for child in model_anchor.get_children():
		model_anchor.remove_child(child)
		child.queue_free()
	var model_scene: PackedScene = CHARACTER_MODELS[character_id]
	var model := model_scene.instantiate()
	model_anchor.rotation.y = deg_to_rad(-12.0)
	model_anchor.add_child(model)
	_configure_embedded_weapon(model, PREVIEW_WEAPONS[character_id])
	_play_idle_animation(model)


func _configure_embedded_weapon(model: Node, visible_weapon: StringName) -> void:
	for weapon_name in EMBEDDED_WEAPON_NAMES:
		var weapon_mesh := model.find_child(weapon_name, true, false) as GeometryInstance3D
		if weapon_mesh != null:
			weapon_mesh.visible = weapon_name == visible_weapon


func _play_idle_animation(model: Node) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("CharacterPreview requires an AnimationPlayer in the imported model.")
		return
	var animation_player := players[0] as AnimationPlayer
	var idle_animation := &"Idle_Gun" if animation_player.has_animation(&"Idle_Gun") else &"Idle"
	if not animation_player.has_animation(idle_animation):
		push_error("CharacterPreview could not find an Idle animation.")
		return
	var animation := animation_player.get_animation(idle_animation)
	animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(idle_animation)
