extends Control

const PLAYER_GROUP := &"player"
const CAMP_ECONOMY_GROUP := &"camp_economy"
const WEAPON_CONTROLLER_GROUP := &"weapon_controller"
const WAVE_MANAGER_GROUP := &"wave_manager"
const RUN_PROGRESSION_GROUP := &"run_progression"
const RUN_OBJECTIVE_GROUP := &"run_objective"
const EXTRACTION_WARNING_SECONDS := 60.0
const MINIMAP_SCRIPT := preload("res://scripts/ui/minimap.gd")
## Top-right, below the Scrap readout. Kept clear of the crosshair and of the
## ammo counter bottom-right.
const MINIMAP_SIZE := 168.0
const MINIMAP_MARGIN := Vector2(30.0, 74.0)

const HEALTH_GOOD_COLOR := Color(0.74, 0.91, 0.79, 1.0)
const HEALTH_WARNING_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const HEALTH_DANGER_COLOR := Color(0.91, 0.4, 0.36, 1.0)
const BAR_GOOD_COLOR := Color(0.294, 0.698, 0.465, 1.0)
const BAR_WARNING_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const BAR_DANGER_COLOR := Color(0.91, 0.4, 0.36, 1.0)
const HIT_MARKER_COLOR := Color(1.0, 0.62, 0.2, 1.0)
const MAX_FEEDBACK_MESSAGES := 3
const VIGNETTE_PULSE_BOOST := 0.35
const VIGNETTE_MAX_INTENSITY := 0.85
const HEALTH_INTERPOLATION_SPEED := 12.0
const LOW_AMMO_RATIO := 0.25
const LOW_AMMO_COLOR := Color(1.0, 0.68, 0.3, 1.0)

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var active_weapon_label: Label = %ActiveWeaponLabel
@onready var active_weapon_icon: TextureRect = %ActiveWeaponIcon
@onready var ammunition_label: Label = %AmmunitionLabel
@onready var threat_label: Label = %ThreatLabel
@onready var hostiles_label: Label = %HostilesLabel
@onready var carried_scrap_label: Label = %CarriedScrapLabel
@onready var feedback_feed: VBoxContainer = %FeedbackFeed
@onready var aim_point: Control = %AimPoint
@onready var reload_bar: ProgressBar = %ReloadBar
@onready var wave_banner: VBoxContainer = %WaveBanner
@onready var banner_caption: Label = %BannerCaption
@onready var banner_title: Label = %BannerTitle
@onready var damage_vignette: ColorRect = %DamageVignette
@onready var run_xp_bar: ProgressBar = %RunXpBar
@onready var run_level_label: Label = %RunLevelLabel
@onready var extraction_label: Label = %ExtractionLabel

var _weapon: Node
var _weapon_controller: Node
var _last_player_health: float = -1.0
var _displayed_health: float = -1.0
var _target_health: float = 0.0
var _displayed_maximum_health: float = 1.0
var _vignette_base_intensity: float = 0.0
var _vignette_tween: Tween
var _hit_marker_tween: Tween
var _reload_tween: Tween
var _banner_tween: Tween
var _ammo_pulse_tween: Tween
var _threat_pulse_tween: Tween
var _last_threat_level := -1
var _bar_fill_styles: Dictionary[Color, StyleBoxFlat] = {}


func _ready() -> void:
	set_process(false)
	_build_minimap()
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	_weapon_controller = get_tree().get_first_node_in_group(WEAPON_CONTROLLER_GROUP)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if (
		player == null
		or camp_economy == null
		or _weapon_controller == null
		or wave_manager == null
	):
		push_error(
			"GameHUD requires player, camp_economy, weapon_controller and wave_manager groups."
		)
		return

	player.connect(&"health_changed", _update_health)
	wave_manager.connect(&"wave_started", _on_wave_started)
	wave_manager.connect(&"enemy_count_changed", _update_enemy_count)
	camp_economy.connect(&"scrap_changed", _update_scrap)
	camp_economy.connect(&"feedback_requested", _show_feedback)
	_weapon_controller.connect(&"active_weapon_changed", _show_weapon)
	_connect_run_progression()
	_connect_run_objective()

	_update_health(
		float(player.get("current_health")), float(player.get("maximum_health"))
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


func _build_minimap() -> void:
	if get_node_or_null("Minimap") != null:
		return
	var minimap := Control.new()
	minimap.name = "Minimap"
	minimap.set_script(MINIMAP_SCRIPT)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.offset_left = -MINIMAP_SIZE - MINIMAP_MARGIN.x
	minimap.offset_right = -MINIMAP_MARGIN.x
	minimap.offset_top = MINIMAP_MARGIN.y
	minimap.offset_bottom = MINIMAP_MARGIN.y + MINIMAP_SIZE
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(minimap)

func _process(delta: float) -> void:
	var interpolation_weight := 1.0 - exp(-HEALTH_INTERPOLATION_SPEED * delta)
	_displayed_health = lerpf(
		_displayed_health, _target_health, interpolation_weight
	)
	if absf(_displayed_health - _target_health) <= 0.05:
		_displayed_health = _target_health
		set_process(false)
	_set_health_display(_displayed_health)


func _update_health(current_health: float, maximum_health: float) -> void:
	_target_health = current_health
	_displayed_maximum_health = maxf(maximum_health, 1.0)
	health_bar.max_value = _displayed_maximum_health
	if _displayed_health < 0.0:
		_displayed_health = current_health
		_set_health_display(_displayed_health)
	else:
		set_process(true)
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


func _set_health_display(value: float) -> void:
	health_bar.value = clampf(value, 0.0, _displayed_maximum_health)
	health_label.text = "%d" % roundi(value)


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
	current_ammunition: int, magazine_size: int, reserve_ammunition: int
) -> void:
	ammunition_label.add_theme_font_size_override(&"font_size", 44)
	ammunition_label.text = "%d / %d" % [
		current_ammunition, reserve_ammunition
	]
	_set_low_ammo_pulse(
		magazine_size > 0
		and float(current_ammunition) / float(magazine_size) < LOW_AMMO_RATIO
	)
	_hide_reload_bar()


func _show_weapon(active_weapon: Node3D, slot: int) -> void:
	_disconnect_weapon_signals()
	_weapon = active_weapon
	_hide_reload_bar()
	_stop_low_ammo_pulse()
	var active_name := (
		String(_weapon_controller.call("get_primary_weapon_name"))
		if slot == 0
		else String(_weapon_controller.call("get_secondary_weapon_name"))
	)
	active_weapon_label.text = active_name
	var weapon_id := (
		StringName(_weapon.get(&"weapon_id")) if _weapon != null else &""
	)
	active_weapon_icon.texture = UiVisualCatalog.get_weapon_icon(weapon_id)
	active_weapon_icon.visible = active_weapon_icon.texture != null
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
	_stop_low_ammo_pulse()
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
	var threat_increased := (
		_last_threat_level >= 0 and threat_level > _last_threat_level
	)
	_update_wave(threat_level)
	if threat_increased:
		_pulse_threat(threat_level)
	if threat_level > 1:
		_show_banner("THE HORDE GROWS", "THREAT LEVEL %02d" % threat_level)


func _update_wave(threat_level: int) -> void:
	threat_label.text = "THREAT %02d" % threat_level
	_last_threat_level = threat_level


func _set_low_ammo_pulse(is_low: bool) -> void:
	if not is_low:
		_stop_low_ammo_pulse()
		return
	if _ammo_pulse_tween != null and _ammo_pulse_tween.is_valid():
		return
	ammunition_label.pivot_offset = ammunition_label.size * 0.5
	_ammo_pulse_tween = create_tween()
	_ammo_pulse_tween.set_loops()
	_ammo_pulse_tween.set_trans(Tween.TRANS_SINE)
	_ammo_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_ammo_pulse_tween.set_parallel(true)
	_ammo_pulse_tween.tween_property(
		ammunition_label, "modulate", LOW_AMMO_COLOR, 0.48
	)
	_ammo_pulse_tween.tween_property(
		ammunition_label, "scale", Vector2(1.035, 1.035), 0.48
	)
	_ammo_pulse_tween.chain().set_parallel(true)
	_ammo_pulse_tween.tween_property(
		ammunition_label, "modulate", Color.WHITE, 0.48
	)
	_ammo_pulse_tween.tween_property(
		ammunition_label, "scale", Vector2.ONE, 0.48
	)


func _stop_low_ammo_pulse() -> void:
	if _ammo_pulse_tween != null and _ammo_pulse_tween.is_valid():
		_ammo_pulse_tween.kill()
	_ammo_pulse_tween = null
	ammunition_label.modulate = Color.WHITE
	ammunition_label.scale = Vector2.ONE


func _pulse_threat(threat_level: int) -> void:
	if _threat_pulse_tween != null and _threat_pulse_tween.is_valid():
		_threat_pulse_tween.kill()
	threat_label.pivot_offset = threat_label.size * 0.5
	threat_label.scale = Vector2(1.16, 1.16)
	threat_label.modulate = (
		HEALTH_DANGER_COLOR if threat_level % 5 == 0 else LOW_AMMO_COLOR
	)
	_threat_pulse_tween = create_tween()
	_threat_pulse_tween.set_parallel(true)
	_threat_pulse_tween.set_trans(Tween.TRANS_BACK)
	_threat_pulse_tween.set_ease(Tween.EASE_OUT)
	_threat_pulse_tween.tween_property(
		threat_label, "scale", Vector2.ONE, 0.42
	)
	_threat_pulse_tween.tween_property(
		threat_label, "modulate", Color.WHITE, 0.42
	)


func _update_enemy_count(remaining_enemies: int) -> void:
	hostiles_label.text = "%02d HOSTILES" % remaining_enemies


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


func _update_scrap(carried_scrap: int, _stored_scrap: int) -> void:
	carried_scrap_label.text = "%03d" % carried_scrap


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


func _connect_run_progression() -> void:
	# Survivors-like run level: the bar fills with XP orbs and each level opens
	# the upgrade cards. Hidden when the scene has no run progression node.
	var progression := get_tree().get_first_node_in_group(RUN_PROGRESSION_GROUP)
	if progression == null:
		run_xp_bar.visible = false
		run_level_label.visible = false
		return
	progression.connect(&"run_xp_changed", _update_run_xp)
	progression.connect(&"run_level_gained", _on_run_level_gained)
	_update_run_xp(
		int(progression.get(&"run_xp")),
		int(progression.call(&"get_required_xp")),
		int(progression.get(&"run_level"))
	)


func _update_run_xp(current_xp: int, required_xp: int, level: int) -> void:
	run_xp_bar.value = float(current_xp) / maxf(float(required_xp), 1.0)
	run_level_label.text = "LV %d" % level


func _on_run_level_gained(level: int, _choices: Array) -> void:
	run_level_label.text = "LV %d" % level
	run_xp_bar.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var level_tween := run_xp_bar.create_tween()
	level_tween.tween_property(run_xp_bar, "modulate", Color.WHITE, 0.4)


func _connect_run_objective() -> void:
	# Extraction clock: the run has an end, survivors-like style.
	var objective := get_tree().get_first_node_in_group(RUN_OBJECTIVE_GROUP)
	if objective == null:
		extraction_label.visible = false
		return
	objective.connect(&"time_changed", _update_extraction_clock)
	_update_extraction_clock(
		float(objective.get(&"seconds_remaining")),
		float(objective.get(&"survival_seconds"))
	)


func _update_extraction_clock(
	seconds_remaining: float, _total_seconds: float
) -> void:
	var whole := int(ceil(seconds_remaining))
	extraction_label.text = "%d:%02d" % [whole / 60, whole % 60]
	extraction_label.add_theme_color_override(
		&"font_color",
		LOW_AMMO_COLOR if seconds_remaining <= EXTRACTION_WARNING_SECONDS
		else Color(0.965, 0.955, 0.94, 1.0)
	)
