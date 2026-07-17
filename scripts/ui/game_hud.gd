extends Control

const PLAYER_GROUP := &"player"
const WEAPON_CONTROLLER_GROUP := &"weapon_controller"
const WAVE_MANAGER_GROUP := &"wave_manager"
const HEALTH_GOOD_COLOR := Color(0.74, 0.91, 0.79, 1.0)
const HEALTH_WARNING_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const HEALTH_DANGER_COLOR := Color(0.91, 0.4, 0.36, 1.0)

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var ammunition_label: Label = %AmmunitionLabel
@onready var wave_label: Label = %WaveLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var aim_point: Control = %AimPoint

var _weapon: Node
var _weapon_controller: Node


func _ready() -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	_weapon_controller = get_tree().get_first_node_in_group(WEAPON_CONTROLLER_GROUP)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if player == null or _weapon_controller == null or wave_manager == null:
		push_error("GameHUD requires player, weapon_controller and wave_manager groups.")
		return

	player.connect(&"health_changed", _update_health)
	wave_manager.connect(&"wave_started", _update_wave)
	wave_manager.connect(&"enemy_count_changed", _update_enemy_count)
	wave_manager.connect(&"intermission_started", _show_intermission)
	_weapon_controller.connect(&"active_weapon_changed", _show_weapon)

	_update_health(
		float(player.get("current_health")), float(player.get("maximum_health"))
	)
	_show_weapon(
		_weapon_controller.call("get_active_weapon"),
		int(_weapon_controller.call("get_active_slot"))
	)
	_update_wave(int(wave_manager.get("current_wave")))
	_update_enemy_count(int(wave_manager.get("alive_enemy_count")))


func _update_health(current_health: float, maximum_health: float) -> void:
	health_bar.max_value = maximum_health
	health_bar.value = current_health
	health_label.text = "%d / %d" % [roundi(current_health), roundi(maximum_health)]
	var health_ratio := current_health / maximum_health if maximum_health > 0.0 else 0.0
	var health_color := HEALTH_GOOD_COLOR
	if health_ratio <= 0.25:
		health_color = HEALTH_DANGER_COLOR
	elif health_ratio <= 0.5:
		health_color = HEALTH_WARNING_COLOR
	health_label.add_theme_color_override(&"font_color", health_color)


func _update_ammunition(
	current_ammunition: int, _magazine_size: int, reserve_ammunition: int
) -> void:
	ammunition_label.add_theme_font_size_override(&"font_size", 26)
	ammunition_label.text = "%d / %d" % [
		current_ammunition, reserve_ammunition
	]


func _show_weapon(active_weapon: Node3D, slot: int) -> void:
	_disconnect_weapon_signals()
	_weapon = active_weapon
	var primary_name := String(_weapon_controller.call("get_primary_weapon_name"))
	var secondary_name := String(_weapon_controller.call("get_secondary_weapon_name"))
	if slot == 0:
		primary_name = "ATIVA  •  " + primary_name
	else:
		secondary_name = "ATIVA  •  " + secondary_name
	weapon_label.text = "[1] %s    [2] %s" % [primary_name, secondary_name]
	if _weapon == null:
		aim_point.hide()
		ammunition_label.add_theme_font_size_override(&"font_size", 17)
		ammunition_label.text = "INDISPONÍVEL"
		return
	if _weapon.has_signal(&"ammunition_changed"):
		aim_point.show()
		_weapon.connect(&"ammunition_changed", _update_ammunition)
		_weapon.connect(&"reload_started", _show_reloading)
		_update_ammunition(
			int(_weapon.get("current_ammunition")),
			int(_weapon.get("magazine_size")),
			int(_weapon.get("reserve_ammunition"))
		)
	else:
		aim_point.show()
		ammunition_label.add_theme_font_size_override(&"font_size", 17)
		ammunition_label.text = "CORPO A CORPO"


func _disconnect_weapon_signals() -> void:
	if _weapon == null:
		return
	if _weapon.has_signal(&"ammunition_changed"):
		if _weapon.is_connected(&"ammunition_changed", _update_ammunition):
			_weapon.disconnect(&"ammunition_changed", _update_ammunition)
		if _weapon.is_connected(&"reload_started", _show_reloading):
			_weapon.disconnect(&"reload_started", _show_reloading)


func _show_reloading(_duration: float) -> void:
	ammunition_label.add_theme_font_size_override(&"font_size", 16)
	ammunition_label.text = "A RECARREGAR  •  %d / %d" % [
		int(_weapon.get("current_ammunition")),
		int(_weapon.get("reserve_ammunition"))
	]


func _update_wave(wave_number: int) -> void:
	wave_label.text = "%02d" % wave_number


func _update_enemy_count(remaining_enemies: int) -> void:
	enemies_label.text = "%02d" % remaining_enemies


func _show_intermission(next_wave: int, duration: float) -> void:
	wave_label.text = "%02d  ·  %ds" % [next_wave, ceili(duration)]
