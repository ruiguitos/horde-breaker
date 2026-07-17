extends Node3D

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

@export var idle_animation: StringName = &"Idle"
@export var move_animation: StringName = &"Run"
@export var run_animation: StringName = &"Run"
@export var crouch_animation: StringName = &"Duck"
@export var airborne_animation: StringName = &"Jump_Idle"
@export_range(0.01, 10.0, 0.01) var movement_threshold: float = 0.1
@export_range(0.0, 1.0, 0.01) var crouch_pose_ratio: float = 0.08
@export var hide_embedded_weapons: bool = true

var _animation_player: AnimationPlayer
var _movement_body: CharacterBody3D
var _embedded_weapon_meshes: Dictionary[StringName, GeometryInstance3D] = {}
var _active_weapon: Node3D
var _action_animation: StringName = &""


func _ready() -> void:
	if hide_embedded_weapons:
		_cache_embedded_weapons()
	_animation_player = _find_animation_player()
	_movement_body = _find_movement_body()
	if _animation_player == null:
		push_error("Imported model requires an AnimationPlayer child.")
		set_process(false)
		return
	_animation_player.animation_finished.connect(_on_animation_finished)
	_set_animation_loop(idle_animation)
	_set_animation_loop(move_animation)
	_set_animation_loop(run_animation)
	_set_animation_loop(airborne_animation)
	_play_animation(idle_animation)
	call_deferred(&"_connect_weapon_controller")


func _process(_delta: float) -> void:
	if _movement_body == null or _action_animation != &"":
		return
	_play_animation(_get_locomotion_animation())


func _find_animation_player() -> AnimationPlayer:
	var players := find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null


func _cache_embedded_weapons() -> void:
	for weapon_name in EMBEDDED_WEAPON_NAMES:
		var weapon_mesh := find_child(weapon_name, true, false) as GeometryInstance3D
		if weapon_mesh != null:
			weapon_mesh.visible = false
			_embedded_weapon_meshes[weapon_name] = weapon_mesh


func _connect_weapon_controller() -> void:
	if _movement_body == null or _embedded_weapon_meshes.is_empty():
		return
	var weapon_controller := _movement_body.get_node_or_null(
		"VisualRoot/WeaponPivot"
	)
	if weapon_controller == null:
		return
	var callback := Callable(self, &"_on_active_weapon_changed")
	if (
		weapon_controller.has_signal(&"active_weapon_changed")
		and not weapon_controller.is_connected(&"active_weapon_changed", callback)
	):
		weapon_controller.connect(&"active_weapon_changed", callback)
	if weapon_controller.has_method(&"get_active_weapon"):
		_on_active_weapon_changed(
			weapon_controller.call(&"get_active_weapon") as Node3D,
			0
		)


func _on_active_weapon_changed(active_weapon: Node3D, _slot: int) -> void:
	_disconnect_active_weapon()
	_active_weapon = active_weapon
	_action_animation = &""
	for weapon_mesh in _embedded_weapon_meshes.values():
		weapon_mesh.visible = false
	if active_weapon == null:
		return
	if active_weapon.has_signal(&"attack_performed"):
		active_weapon.connect(&"attack_performed", _play_melee_attack)
	var weapon_id := StringName(active_weapon.get(&"weapon_id"))
	var embedded_weapon_name := _get_embedded_weapon_name(weapon_id)
	if _embedded_weapon_meshes.has(embedded_weapon_name):
		_embedded_weapon_meshes[embedded_weapon_name].visible = true
	if weapon_id == &"worn_sword":
		idle_animation = &"Idle"
		move_animation = &"Walk"
		run_animation = &"Run_Stab"
	else:
		idle_animation = &"Idle_Gun"
		move_animation = &"Walk_Gun"
		run_animation = &"Run_Gun"
	_set_animation_loop(idle_animation)
	_set_animation_loop(move_animation)
	_set_animation_loop(run_animation)
	_play_animation(idle_animation)


func _get_embedded_weapon_name(weapon_id: StringName) -> StringName:
	if weapon_id == &"assault_rifle":
		return &"Rifle"
	if weapon_id == &"pistol":
		return &"Pistol"
	if weapon_id == &"shotgun":
		return &"Shotgun"
	if weapon_id == &"worn_sword":
		return &"Knife"
	return &""


func _get_locomotion_animation() -> StringName:
	if not _movement_body.is_on_floor():
		return airborne_animation
	if (
		_movement_body.has_method(&"is_crouching")
		and bool(_movement_body.call(&"is_crouching"))
	):
		return crouch_animation
	var horizontal_speed := Vector2(
		_movement_body.velocity.x,
		_movement_body.velocity.z
	).length()
	if horizontal_speed <= movement_threshold:
		return idle_animation
	if (
		_movement_body.has_method(&"is_sprinting")
		and bool(_movement_body.call(&"is_sprinting"))
	):
		return run_animation
	return move_animation


func _play_melee_attack(_hit_count: int) -> void:
	if not _animation_player.has_animation(&"Slash"):
		return
	_action_animation = &"Slash"
	_animation_player.play(_action_animation)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == _action_animation:
		_action_animation = &""


func _disconnect_active_weapon() -> void:
	if (
		_active_weapon != null
		and _active_weapon.has_signal(&"attack_performed")
		and _active_weapon.is_connected(&"attack_performed", _play_melee_attack)
	):
		_active_weapon.disconnect(&"attack_performed", _play_melee_attack)


func _find_movement_body() -> CharacterBody3D:
	var current_node := get_parent()
	while current_node != null:
		if current_node is CharacterBody3D:
			return current_node as CharacterBody3D
		current_node = current_node.get_parent()
	return null


func _set_animation_loop(animation_name: StringName) -> void:
	if not _animation_player.has_animation(animation_name):
		push_error("Imported model is missing animation: %s" % animation_name)
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR


func _play_animation(animation_name: StringName) -> void:
	if not _animation_player.has_animation(animation_name):
		return
	if animation_name == crouch_animation:
		_play_crouch_pose()
		return
	if (
		_animation_player.current_animation == animation_name
		and _animation_player.is_playing()
	):
		return
	_animation_player.play(animation_name)


func _play_crouch_pose() -> void:
	if (
		_animation_player.current_animation == crouch_animation
		and not _animation_player.is_playing()
	):
		return
	var animation := _animation_player.get_animation(crouch_animation)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	_animation_player.play(crouch_animation)
	_animation_player.seek(animation.length * crouch_pose_ratio, true)
	_animation_player.pause()
