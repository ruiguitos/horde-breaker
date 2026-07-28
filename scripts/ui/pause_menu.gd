extends Control

signal pause_changed(is_paused: bool)

const SETTINGS_SCENE := preload("res://scenes/menus/settings_menu.tscn")

@onready var panel_container: PanelContainer = %PausePanel
@onready var background: ColorRect = %Background
@onready var depth_shade: ColorRect = %DepthShade
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

const ACCENT_COLOR := Color(0.957, 0.694, 0.31, 1.0)
const MUTED_COLOR := Color(0.62, 0.665, 0.7, 1.0)
## Beyond this the list is summarised, so the panel cannot outgrow the screen on
## a long run.
const MAX_LISTED_UPGRADES := 8

var _settings_overlay: Control
var _summary_label: Label
var _upgrades_title: Label
var _upgrades_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_build_run_summary()
	resume_button.pressed.connect(resume_game)
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


func resume_game() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_changed.emit(false)


func _build_run_summary() -> void:
	# Built in code and inserted above the existing spacer, so the scene keeps
	# its authored layout.
	var content := panel_container.get_node("Margin/Content") as VBoxContainer
	var spacer := content.get_node_or_null("Spacer")
	var insert_at := spacer.get_index() if spacer != null else content.get_child_count()

	_summary_label = Label.new()
	_summary_label.name = "RunSummary"
	_summary_label.theme_type_variation = &"MutedLabel"
	_summary_label.add_theme_font_size_override(&"font_size", 14)
	content.add_child(_summary_label)
	content.move_child(_summary_label, insert_at)

	_upgrades_title = Label.new()
	_upgrades_title.name = "UpgradesTitle"
	_upgrades_title.theme_type_variation = &"EyebrowLabel"
	_upgrades_title.add_theme_color_override(&"font_color", ACCENT_COLOR)
	_upgrades_title.text = "UPGRADES"
	content.add_child(_upgrades_title)
	content.move_child(_upgrades_title, insert_at + 1)

	_upgrades_label = Label.new()
	_upgrades_label.name = "UpgradesList"
	_upgrades_label.theme_type_variation = &"MutedLabel"
	_upgrades_label.add_theme_font_size_override(&"font_size", 13)
	_upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_upgrades_label)
	content.move_child(_upgrades_label, insert_at + 2)


func _refresh_run_summary() -> void:
	_summary_label.text = _build_summary_text()
	var progression := get_tree().get_first_node_in_group(&"run_progression")
	var taken: Array = (
		progression.call(&"get_taken_upgrades")
		if progression != null and progression.has_method(&"get_taken_upgrades")
		else []
	)
	var has_upgrades := not taken.is_empty()
	_upgrades_title.visible = has_upgrades
	_upgrades_label.visible = has_upgrades
	if not has_upgrades:
		return
	var lines: PackedStringArray = []
	for index in mini(taken.size(), MAX_LISTED_UPGRADES):
		var upgrade: Dictionary = taken[index]
		var count := int(upgrade["count"])
		lines.append(
			"%s%s" % [
				String(upgrade["name"]),
				"  ×%d" % count if count > 1 else "",
			]
		)
	if taken.size() > MAX_LISTED_UPGRADES:
		lines.append("+%d more" % (taken.size() - MAX_LISTED_UPGRADES))
	_upgrades_label.text = "\n".join(lines)


func _build_summary_text() -> String:
	var parts: PackedStringArray = []
	var objective := get_tree().get_first_node_in_group(&"run_objective")
	if objective != null:
		var elapsed := float(objective.get(&"_elapsed"))
		parts.append("SURVIVED  %d:%02d" % [int(elapsed) / 60, int(elapsed) % 60])
		if objective.has_method(&"get_time_text"):
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
