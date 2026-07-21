extends Control

const PLAYER_GROUP := &"player"
const CAMP_CORE_GROUP := &"camp_core"
const CAMP_ECONOMY_GROUP := &"camp_economy"
const WEAPON_CONTROLLER_GROUP := &"weapon_controller"
const WAVE_MANAGER_GROUP := &"wave_manager"
const HEALTH_GOOD_COLOR := Color(0.74, 0.91, 0.79, 1.0)
const HEALTH_WARNING_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const HEALTH_DANGER_COLOR := Color(0.91, 0.4, 0.36, 1.0)
const BAR_GOOD_COLOR := Color(0.294, 0.698, 0.465, 1.0)
const BAR_WARNING_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const BAR_DANGER_COLOR := Color(0.91, 0.4, 0.36, 1.0)
const HIT_MARKER_COLOR := Color(1.0, 0.62, 0.2, 1.0)
const MAX_FEEDBACK_MESSAGES := 4
const VIGNETTE_PULSE_BOOST := 0.35
const VIGNETTE_MAX_INTENSITY := 0.85

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var camp_health_bar: ProgressBar = %CampHealthBar
@onready var camp_health_label: Label = %CampHealthLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var ammunition_label: Label = %AmmunitionLabel
@onready var wave_caption: Label = %WaveCaption
@onready var wave_label: Label = %WaveLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var surge_label: Label = %SurgeLabel
@onready var carried_scrap_label: Label = %CarriedScrapLabel
@onready var stored_scrap_label: Label = %StoredScrapLabel
@onready var feedback_feed: VBoxContainer = %FeedbackFeed
@onready var aim_point: Control = %AimPoint
@onready var reload_bar: ProgressBar = %ReloadBar
@onready var wave_banner: VBoxContainer = %WaveBanner
@onready var banner_caption: Label = %BannerCaption
@onready var banner_title: Label = %BannerTitle
@onready var damage_vignette: ColorRect = %DamageVignette

var _weapon: Node
var _weapon_controller: Node
var _last_player_health: float = -1.0
var _vignette_base_intensity: float = 0.0
var _vignette_tween: Tween
var _hit_marker_tween: Tween
var _reload_tween: Tween
var _banner_tween: Tween
var _bar_fill_styles: Dictionary[Color, StyleBoxFlat] = {}


func _ready() -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	var camp_core := get_tree().get_first_node_in_group(CAMP_CORE_GROUP)
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	_weapon_controller = get_tree().get_first_node_in_group(WEAPON_CONTROLLER_GROUP)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if (
		player == null
		or camp_core == null
		or camp_economy == null
		or _weapon_controller == null
		or wave_manager == null
	):
		push_error(
			"GameHUD requires player, camp_core, camp_economy, weapon_controller and wave_manager groups."
		)
		return

	player.connect(&"health_changed", _update_health)
	camp_core.connect(&"health_changed", _update_camp_health)
	wave_manager.connect(&"wave_started", _on_wave_started)
	wave_manager.connect(&"enemy_count_changed", _update_enemy_count)
	wave_manager.connect(
		&"preparation_time_changed", _update_surge_countdown
	)
	camp_economy.connect(&"scrap_changed", _update_scrap)
	camp_economy.connect(&"feedback_requested", _show_feedback)
	_weapon_controller.connect(&"active_weapon_changed", _show_weapon)

	_update_health(
		float(player.get("current_health")), float(player.get("maximum_health"))
	)
	_update_camp_health(
		float(camp_core.get("current_health")),
		float(camp_core.get("maximum_health"))
	)
	_update_scrap(
		int(camp_economy.get("carried_scrap")),
		int(camp_economy.get("stored_scrap"))
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
	var health_color := _get_state_color(
		health_ratio, HEALTH_GOOD_COLOR, HEALTH_WARNING_COLOR, HEALTH_DANGER_COLOR
	)
	health_label.add_theme_color_override(&"font_color", health_color)
	_apply_bar_fill_color(health_bar, health_ratio)
	var took_damage := (
		_last_player_health >= 0.0 and current_health < _last_player_health
	)
	_last_player_health = current_health
	_vignette_base_intensity = clampf((0.5 - health_ratio) * 1.4, 0.0, 0.7)
	if took_damage:
		_pulse_damage_vignette()
	else:
		_set_vignette_intensity(_vignette_base_intensity)


func _update_camp_health(current_health: float, maximum_health: float) -> void:
	camp_health_bar.max_value = maximum_health
	camp_health_bar.value = current_health
	camp_health_label.text = "%d / %d" % [
		roundi(current_health), roundi(maximum_health)
	]
	var health_ratio := current_health / maximum_health if maximum_health > 0.0 else 0.0
	var health_color := _get_state_color(
		health_ratio, HEALTH_GOOD_COLOR, HEALTH_WARNING_COLOR, HEALTH_DANGER_COLOR
	)
	camp_health_label.add_theme_color_override(&"font_color", health_color)
	_apply_bar_fill_color(camp_health_bar, health_ratio)


func _get_state_color(
	ratio: float, good: Color, warning: Color, danger: Color
) -> Color:
	if ratio <= 0.25:
		return danger
	if ratio <= 0.5:
		return warning
	return good


func _apply_bar_fill_color(bar: ProgressBar, ratio: float) -> void:
	var fill_color := _get_state_color(
		ratio, BAR_GOOD_COLOR, BAR_WARNING_COLOR, BAR_DANGER_COLOR
	)
	if not _bar_fill_styles.has(fill_color):
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.skew = Vector2(0.12, 0.0)
		_bar_fill_styles[fill_color] = fill_style
	bar.add_theme_stylebox_override(&"fill", _bar_fill_styles[fill_color])


func _set_vignette_intensity(intensity: float) -> void:
	var vignette_material := damage_vignette.material as ShaderMaterial
	if vignette_material == null:
		return
	vignette_material.set_shader_parameter(&"intensity", intensity)


func _pulse_damage_vignette() -> void:
	var vignette_material := damage_vignette.material as ShaderMaterial
	if vignette_material == null:
		return
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	var pulse_intensity := minf(
		_vignette_base_intensity + VIGNETTE_PULSE_BOOST, VIGNETTE_MAX_INTENSITY
	)
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(
		_set_vignette_intensity,
		float(vignette_material.get_shader_parameter(&"intensity")),
		pulse_intensity,
		0.06
	)
	_vignette_tween.tween_method(
		_set_vignette_intensity, pulse_intensity, _vignette_base_intensity, 0.5
	)


func _update_ammunition(
	current_ammunition: int, _magazine_size: int, reserve_ammunition: int
) -> void:
	ammunition_label.add_theme_font_size_override(&"font_size", 42)
	ammunition_label.text = "%d / %d" % [
		current_ammunition, reserve_ammunition
	]
	_hide_reload_bar()


func _show_weapon(active_weapon: Node3D, slot: int) -> void:
	_disconnect_weapon_signals()
	_weapon = active_weapon
	_hide_reload_bar()
	var primary_name := String(_weapon_controller.call("get_primary_weapon_name"))
	var secondary_name := String(_weapon_controller.call("get_secondary_weapon_name"))
	if slot == 0:
		primary_name = "ACTIVE  •  " + primary_name
	else:
		secondary_name = "ACTIVE  •  " + secondary_name
	weapon_label.text = "[1] %s    [2] %s" % [primary_name, secondary_name]
	if _weapon == null:
		aim_point.hide()
		ammunition_label.add_theme_font_size_override(&"font_size", 18)
		ammunition_label.text = "UNAVAILABLE"
		return
	if _weapon.has_signal(&"shot_fired"):
		_weapon.connect(&"shot_fired", _on_shot_fired)
	if _weapon.has_signal(&"attack_performed"):
		_weapon.connect(&"attack_performed", _on_melee_attack_performed)
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
		ammunition_label.add_theme_font_size_override(&"font_size", 18)
		ammunition_label.text = "MELEE"


func _disconnect_weapon_signals() -> void:
	if _weapon == null:
		return
	if (
		_weapon.has_signal(&"shot_fired")
		and _weapon.is_connected(&"shot_fired", _on_shot_fired)
	):
		_weapon.disconnect(&"shot_fired", _on_shot_fired)
	if (
		_weapon.has_signal(&"attack_performed")
		and _weapon.is_connected(&"attack_performed", _on_melee_attack_performed)
	):
		_weapon.disconnect(&"attack_performed", _on_melee_attack_performed)
	if _weapon.has_signal(&"ammunition_changed"):
		if _weapon.is_connected(&"ammunition_changed", _update_ammunition):
			_weapon.disconnect(&"ammunition_changed", _update_ammunition)
		if _weapon.is_connected(&"reload_started", _show_reloading):
			_weapon.disconnect(&"reload_started", _show_reloading)


func _on_shot_fired(_hit_position: Vector3, hit_collider: Object) -> void:
	if hit_collider == null:
		return
	if (
		hit_collider.has_method(&"get_damage_target")
		or hit_collider.has_method(&"take_damage")
	):
		_flash_hit_marker()


func _on_melee_attack_performed(hit_count: int) -> void:
	if hit_count > 0:
		_flash_hit_marker()


func _flash_hit_marker() -> void:
	if _hit_marker_tween != null and _hit_marker_tween.is_valid():
		_hit_marker_tween.kill()
	aim_point.scale = Vector2(1.35, 1.35)
	aim_point.modulate = HIT_MARKER_COLOR
	_hit_marker_tween = create_tween()
	_hit_marker_tween.set_parallel(true)
	_hit_marker_tween.tween_property(aim_point, "scale", Vector2.ONE, 0.18)
	_hit_marker_tween.tween_property(aim_point, "modulate", Color.WHITE, 0.18)


func _show_reloading(duration: float) -> void:
	ammunition_label.add_theme_font_size_override(&"font_size", 16)
	ammunition_label.text = "RELOADING  •  %d / %d" % [
		int(_weapon.get("current_ammunition")),
		int(_weapon.get("reserve_ammunition"))
	]
	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
	reload_bar.value = 0.0
	reload_bar.show()
	_reload_tween = create_tween()
	_reload_tween.tween_property(
		reload_bar, "value", 1.0, maxf(duration, 0.05)
	)
	_reload_tween.tween_callback(reload_bar.hide)


func _hide_reload_bar() -> void:
	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
	reload_bar.hide()


func _on_wave_started(threat_level: int) -> void:
	_update_wave(threat_level)
	if threat_level > 1:
		_show_banner("THE HORDE GROWS", "THREAT LEVEL %02d" % threat_level)


func _update_wave(threat_level: int) -> void:
	wave_caption.text = "THREAT LEVEL"
	wave_label.text = "%02d" % threat_level


func _update_enemy_count(remaining_enemies: int) -> void:
	enemies_label.text = "%02d" % remaining_enemies


func _show_banner(caption: String, title: String) -> void:
	banner_caption.text = caption
	banner_title.text = title
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	wave_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(1.7)
	_banner_tween.tween_property(wave_banner, "modulate:a", 0.0, 0.6)


func _update_surge_countdown(seconds_remaining: int) -> void:
	if seconds_remaining <= 0:
		surge_label.text = "THREAT RISING"
		return
	surge_label.text = "NEXT THREAT  ·  %ds" % seconds_remaining


func _update_scrap(carried_scrap: int, stored_scrap: int) -> void:
	carried_scrap_label.text = "%03d" % carried_scrap
	stored_scrap_label.text = "%03d" % stored_scrap


func _show_feedback(message: String, duration: float) -> void:
	var message_panel := PanelContainer.new()
	message_panel.theme_type_variation = &"HudPanel"
	message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var message_label := Label.new()
	message_label.theme_type_variation = &"EyebrowLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.text = message
	message_panel.add_child(message_label)
	feedback_feed.add_child(message_panel)
	if feedback_feed.get_child_count() > MAX_FEEDBACK_MESSAGES:
		var oldest_message := feedback_feed.get_child(0)
		feedback_feed.remove_child(oldest_message)
		oldest_message.queue_free()
	var message_tween := message_panel.create_tween()
	message_tween.tween_interval(maxf(duration, 0.1))
	message_tween.tween_property(message_panel, "modulate:a", 0.0, 0.4)
	message_tween.tween_callback(message_panel.queue_free)
