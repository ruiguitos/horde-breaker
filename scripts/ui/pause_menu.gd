extends Control

signal pause_changed(is_paused: bool)

const SETTINGS_SCENE := preload("res://scenes/menus/settings_menu.tscn")
const REFERENCE_SIZE := Vector2(1152.0, 648.0)
const MIN_UI_SCALE := 0.82
const MAX_UI_SCALE := 1.9

@onready var panel_container: PanelContainer = %PausePanel
@onready var background: ColorRect = %Background
@onready var depth_shade: ColorRect = %DepthShade
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

const ACCENT_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const MUTED_COLOR := Color(0.62, 0.665, 0.7, 1.0)
const SUMMARY_COLOR := Color(0.79, 0.82, 0.84, 1.0)
## Upgrades are laid out in columns rather than one list. A single column ran off
## the panel and had to be cut with a "+3 more", which hid exactly the thing the
## player opened the pause menu to check. Columns fit the whole loadout.
## Two columns of six hold the entire catalogue, so the list is never cut.
const UPGRADES_PER_COLUMN := 6
const MAX_UPGRADE_COLUMNS := 2

var _settings_overlay: Control
var _run_card: PanelContainer
var _run_margin: MarginContainer
var _run_content: VBoxContainer
var _run_heading: Label
var _upgrades_divider: HSeparator

var _summary_label: Label
var _upgrades_title: Label
var _upgrades_columns: HBoxContainer
var _upgrade_font_size := 14


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_build_run_summary()
	resume_button.pressed.connect(resume_game)
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	settings_button.pressed.connect(_open_settings)
	main_menu_button.pressed.connect(_open_main_menu)
	quit_button.pressed.connect(GameManager.quit_game)
	UiAnimations.enhance_buttons(self)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	var camp_builder := get_tree().get_first_node_in_group(&"camp_builder")
	if camp_builder != null and bool(camp_builder.call(&"is_build_mode_active")):
		return
	if _is_settings_open():
		return
	if visible:
		resume_game()
	elif not get_tree().paused:
		pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	if get_tree().paused:
		return
	_refresh_run_summary()
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()
	UiAnimations.fade_in(background, 0.0, 0.18)
	UiAnimations.fade_in(depth_shade, 0.05, 0.22)
	UiAnimations.pop_in(panel_container, 0.24)
	pause_changed.emit(true)
	UiAnimations.pop_in(_run_card, 0.28)


func resume_game() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_changed.emit(false)


func _build_run_summary() -> void:
	# Its own panel on the right, mirroring the menu on the left. Stacking it
	# above the buttons squeezed the whole screen into one column and left the
	# other half empty.
	var card := PanelContainer.new()
	card.name = "RunCard"
	_run_card = card
	card.theme_type_variation = &"MenuPanel"
	card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.offset_left = -400.0
	card.offset_right = -64.0
	card.offset_top = -220.0
	card.offset_bottom = 220.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	var margin := MarginContainer.new()
	margin.name = "Body"
	_run_margin = margin
	margin.add_theme_constant_override(&"margin_left", 24)
	margin.add_theme_constant_override(&"margin_top", 22)
	margin.add_theme_constant_override(&"margin_right", 24)
	margin.add_theme_constant_override(&"margin_bottom", 22)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	_run_content = content
	content.add_theme_constant_override(&"separation", 10)
	margin.add_child(content)

	var heading := Label.new()
	heading.theme_type_variation = &"EyebrowLabel"
	_run_heading = heading
	heading.add_theme_color_override(&"font_color", ACCENT_COLOR)
	heading.text = "CURRENT RUN"
	content.add_child(heading)

	_summary_label = Label.new()
	_summary_label.name = "RunSummary"
	_summary_label.theme_type_variation = &"MutedLabel"
	_summary_label.add_theme_font_size_override(&"font_size", 15)
	content.add_child(_summary_label)
	_summary_label.add_theme_color_override(&"font_color", SUMMARY_COLOR)
	_summary_label.add_theme_constant_override(&"line_spacing", 5)

	var divider := HSeparator.new()
	content.add_child(divider)

	_upgrades_divider = divider
	_upgrades_title = Label.new()
	_upgrades_title.name = "UpgradesTitle"
	_upgrades_title.theme_type_variation = &"EyebrowLabel"
	_upgrades_title.add_theme_color_override(&"font_color", ACCENT_COLOR)
	_upgrades_title.text = "UPGRADES"
	content.add_child(_upgrades_title)

	_upgrades_columns = HBoxContainer.new()
	_upgrades_columns.name = "UpgradesColumns"
	_upgrades_columns.add_theme_constant_override(&"separation", 22)
	content.add_child(_upgrades_columns)


func _refresh_run_summary() -> void:
	_summary_label.text = _build_summary_text()
	var progression := get_tree().get_first_node_in_group(&"run_progression")
	var taken: Array = (
		progression.call(&"get_taken_upgrades")
		if progression != null and progression.has_method(&"get_taken_upgrades")
		else []
	)
	for child in _upgrades_columns.get_children():
		child.queue_free()
	if taken.is_empty():
		_upgrades_columns.add_child(_build_upgrade_label("NO UPGRADES ACQUIRED", MUTED_COLOR))
		return

	# Fill each column before starting the next, so the list still reads top to
	# bottom rather than snaking across the panel.
	var per_column := maxi(
		UPGRADES_PER_COLUMN, ceili(float(taken.size()) / float(MAX_UPGRADE_COLUMNS))
	)
	var column: VBoxContainer = null
	for index in taken.size():
		if index % per_column == 0:
			column = VBoxContainer.new()
			column.add_theme_constant_override(&"separation", 4)
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_upgrades_columns.add_child(column)
		var upgrade: Dictionary = taken[index]
		var level := int(upgrade["level"])
		var maximum := int(upgrade["max_level"])
		# The level is what the player is really checking, and a maxed card is
		# worth calling out because it will never be offered again.
		var suffix := "MAX" if level >= maximum else "LV %d" % level
		column.add_child(_build_upgrade_label(
			"%s  ·  %s" % [String(upgrade["name"]), suffix], upgrade["colour"]
		))


func _build_upgrade_label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.add_theme_font_size_override(&"font_size", _upgrade_font_size)
	label.add_theme_color_override(&"font_color", colour)
	label.text = text
	return label




func _apply_responsive_layout() -> void:
	var ui_scale := _get_ui_scale()
	var panel_margin := $PausePanel/Margin as MarginContainer
	var panel_content := $PausePanel/Margin/Content as VBoxContainer
	var title := $PausePanel/Margin/Content/Title as Label
	var hint := $PausePanel/Margin/Content/Hint as Label
	var actions := $PausePanel/Margin/Content/ActionsLabel as Label
	var footer := $PausePanel/Margin/Content/Footer as Label
	var panel_width := 448.0 * ui_scale

	panel_container.offset_right = panel_width
	depth_shade.anchor_left = 0.0
	depth_shade.offset_left = panel_width
	_set_margin(panel_margin, 48.0, 56.0, 40.0, ui_scale)
	panel_content.add_theme_constant_override(&"separation", roundi(12.0 * ui_scale))
	title.add_theme_font_size_override(&"font_size", roundi(56.0 * ui_scale))
	hint.add_theme_font_size_override(&"font_size", roundi(15.0 * ui_scale))
	actions.add_theme_font_size_override(&"font_size", roundi(12.0 * ui_scale))
	_set_button_height(resume_button, 58.0, ui_scale)
	_set_button_height(settings_button, 52.0, ui_scale)
	_set_button_height(main_menu_button, 52.0, ui_scale)
	_set_button_height(quit_button, 48.0, ui_scale)
	footer.add_theme_font_size_override(&"font_size", roundi(14.0 * ui_scale))
	if _run_card == null:
		return
	# Wider than the 400 it used to be: the upgrades sit in two columns now, and
	# a column narrower than "MAGNETIC FIELD  ·  LV 3" wraps mid-name.
	_run_card.offset_left = -534.0 * ui_scale
	_run_card.offset_right = -64.0 * ui_scale
	_run_card.offset_top = -210.0 * ui_scale
	_run_card.offset_bottom = 210.0 * ui_scale
	_set_margin(_run_margin, 26.0, 24.0, 24.0, ui_scale)
	_run_content.add_theme_constant_override(&"separation", roundi(11.0 * ui_scale))
	_run_heading.add_theme_font_size_override(&"font_size", roundi(13.0 * ui_scale))
	_summary_label.add_theme_font_size_override(&"font_size", roundi(17.0 * ui_scale))
	_summary_label.add_theme_constant_override(&"line_spacing", roundi(6.0 * ui_scale))
	_upgrades_title.add_theme_font_size_override(&"font_size", roundi(12.0 * ui_scale))
	_upgrade_font_size = roundi(14.0 * ui_scale)
	_apply_upgrade_font_size()


## The upgrade labels are rebuilt every time the menu opens, so the scaled size
## is kept here and re-applied rather than being read back off a node.
func _apply_upgrade_font_size() -> void:
	for column in _upgrades_columns.get_children():
		var label := column as Label
		if label != null:
			label.add_theme_font_size_override(&"font_size", _upgrade_font_size)
			continue
		for child in column.get_children():
			var entry := child as Label
			if entry != null:
				entry.add_theme_font_size_override(&"font_size", _upgrade_font_size)


func _get_ui_scale() -> float:
	var viewport_size := get_viewport_rect().size
	var width_scale := viewport_size.x / REFERENCE_SIZE.x
	var height_scale := viewport_size.y / REFERENCE_SIZE.y
	return clampf(minf(width_scale, height_scale), MIN_UI_SCALE, MAX_UI_SCALE)


func _set_button_height(button: Button, base_height: float, ui_scale: float) -> void:
	button.custom_minimum_size.y = base_height * ui_scale
	button.add_theme_font_size_override(&"font_size", roundi(17.0 * ui_scale))


func _set_margin(
	margin: MarginContainer,
	horizontal: float,
	top: float,
	bottom: float,
	ui_scale: float
) -> void:
	margin.add_theme_constant_override(&"margin_left", roundi(horizontal * ui_scale))
	margin.add_theme_constant_override(&"margin_right", roundi(horizontal * ui_scale))
	margin.add_theme_constant_override(&"margin_top", roundi(top * ui_scale))
	margin.add_theme_constant_override(&"margin_bottom", roundi(bottom * ui_scale))
func _build_summary_text() -> String:
	var parts: PackedStringArray = []
	var objective := get_tree().get_first_node_in_group(&"run_objective")
	if objective != null:
		var elapsed := float(objective.get(&"_elapsed"))
		parts.append("SURVIVED  %d:%02d" % [int(elapsed) / 60, int(elapsed) % 60])
		# Phase-aware: once the clock runs out it no longer says anything useful,
		# and the run is then about the kill count and the walk back to camp.
		if objective.has_method(&"get_objective_text"):
			var stage := int(objective.get(&"phase"))
			var label := "LAST STAND" if stage == 1 else (
				"EXTRACTION" if stage >= 2 else "LAST STAND IN"
			)
			parts.append("%s  %s" % [
				label, String(objective.call(&"get_objective_text"))
			])
		elif objective.has_method(&"get_time_text"):
			parts.append("EXTRACTION IN  %s" % String(objective.call(&"get_time_text")))
		parts.append("KILLS  %d" % int(objective.get(&"kills")))
	var wave_manager := get_tree().get_first_node_in_group(&"wave_manager")
	if wave_manager != null:
		parts.append("THREAT  %d" % int(wave_manager.get(&"current_wave")))
	var progression := get_tree().get_first_node_in_group(&"run_progression")
	if progression != null:
		parts.append("RUN LEVEL  %d  (%d/%d XP)" % [
			int(progression.get(&"run_level")),
			int(progression.get(&"run_xp")),
			int(progression.call(&"get_required_xp")),
		])
	var economy := get_tree().get_first_node_in_group(&"camp_economy")
	if economy != null:
		parts.append("SCRAP  %d carried · %d stored" % [
			int(economy.get(&"carried_scrap")), int(economy.get(&"stored_scrap"))
		])
	return "\n".join(parts)


func _open_settings() -> void:
	if _is_settings_open():
		return
	_settings_overlay = SETTINGS_SCENE.instantiate() as Control
	if _settings_overlay == null:
		push_error("PauseMenu could not instantiate the settings menu.")
		return
	add_child(_settings_overlay)
	_settings_overlay.tree_exited.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	_settings_overlay = null
	if visible:
		resume_button.grab_focus()


func _is_settings_open() -> bool:
	return _settings_overlay != null and is_instance_valid(_settings_overlay)


func _open_main_menu() -> void:
	hide()
	GameManager.open_main_menu()
