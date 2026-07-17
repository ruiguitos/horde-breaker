extends Control

const PLAYER_GROUP := &"player"
const PLAYER_WEAPON_GROUP := &"player_weapon"
const WAVE_MANAGER_GROUP := &"wave_manager"

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var ammunition_label: Label = %AmmunitionLabel
@onready var wave_label: Label = %WaveLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var aim_point: Control = %AimPoint

var _weapon: Node


func _ready() -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	_weapon = get_tree().get_first_node_in_group(PLAYER_WEAPON_GROUP)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if player == null or wave_manager == null:
		push_error("GameHUD requires the player and wave_manager groups.")
		return

	player.connect(&"health_changed", _update_health)
	wave_manager.connect(&"wave_started", _update_wave)
	wave_manager.connect(&"enemy_count_changed", _update_enemy_count)
	wave_manager.connect(&"intermission_started", _show_intermission)

	_update_health(
		float(player.get("current_health")), float(player.get("maximum_health"))
	)
	if _weapon == null:
		aim_point.hide()
		ammunition_label.text = "Arma: Worn Sword — combate no Milestone 13"
	else:
		_weapon.connect(&"ammunition_changed", _update_ammunition)
		_weapon.connect(&"reload_started", _show_reloading)
		_update_ammunition(
			int(_weapon.get("current_ammunition")), int(_weapon.get("magazine_size"))
		)
	_update_wave(int(wave_manager.get("current_wave")))
	_update_enemy_count(int(wave_manager.get("alive_enemy_count")))


func _update_health(current_health: float, maximum_health: float) -> void:
	health_bar.max_value = maximum_health
	health_bar.value = current_health
	health_label.text = "Vida: %d / %d" % [roundi(current_health), roundi(maximum_health)]


func _update_ammunition(current_ammunition: int, magazine_size: int) -> void:
	ammunition_label.text = "Munição: %d / %d" % [current_ammunition, magazine_size]


func _show_reloading(_duration: float) -> void:
	ammunition_label.text = "Munição: %d / %d — a recarregar" % [
		int(_weapon.get("current_ammunition")), int(_weapon.get("magazine_size"))
	]


func _update_wave(wave_number: int) -> void:
	wave_label.text = "Ronda: %d" % wave_number


func _update_enemy_count(remaining_enemies: int) -> void:
	enemies_label.text = "Inimigos: %d" % remaining_enemies


func _show_intermission(next_wave: int, duration: float) -> void:
	wave_label.text = "Ronda %d em %d s" % [next_wave, ceili(duration)]
