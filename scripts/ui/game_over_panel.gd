extends Control

const PLAYER_GROUP := &"player"
const SUCCESS_COLOR := Color(0.35, 0.78, 0.5, 1.0)
const SUCCESS_TITLE_COLOR := Color(0.88, 0.97, 0.9, 1.0)

@onready var panel_container: PanelContainer = %PanelContainer
@onready var background: ColorRect = %Background
@onready var depth_shade: ColorRect = %DepthShade
@onready var message_label: Label = %Message
@onready var eyebrow_label: Label = %Eyebrow
@onready var title_label: Label = %Title
@onready var accent_line: ColorRect = %AccentLine
@onready var top_rail: ColorRect = %TopRail
@onready var bottom_rail: ColorRect = %BottomRail
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton

var _objective: Node
var _continue_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	restart_button.pressed.connect(_restart_current_scene)
	main_menu_button.pressed.connect(GameManager.open_main_menu)
	UiAnimations.enhance_buttons(self)

	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		push_error("GameOverPanel requires a node in the player group.")
		return
	if not player.has_signal(&"died"):
		push_error("GameOverPanel requires the player to expose a died signal.")
		return
	player.connect(&"died", _show_player_defeat)
	_objective = get_tree().get_first_node_in_group(&"run_objective")
	if _objective != null and _objective.has_signal(&"run_finished"):
		_objective.connect(&"run_finished", _show_run_result)


func _show_run_result(stats: Dictionary) -> void:
	# Phase 4: one summary screen for every ending, with the run's numbers.
	var extracted := bool(stats.get("extracted", false))
	var died := bool(stats.get("died", false))
	if died:
		_apply_outcome_style(
			"OPERATION TERMINATED", "DEFEAT",
			Color(0.78, 0.34, 0.3), Color(0.965, 0.88, 0.84)
		)
		restart_button.text = "TRY AGAIN"
	elif extracted:
		_apply_outcome_style(
			"OPERATION COMPLETE", "EXTRACTED", SUCCESS_COLOR, SUCCESS_TITLE_COLOR
		)
		restart_button.text = "NEW RUN"
	else:
		_apply_outcome_style(
			"EXTRACTION MISSED", "LEFT BEHIND",
			Color(0.9, 0.66, 0.28), Color(0.97, 0.93, 0.85)
		)
		restart_button.text = "NEW RUN"
	_setup_continue_button(stats)
	_show_game_over(_build_summary(stats, extracted, died))


func _build_summary(stats: Dictionary, extracted: bool, died: bool) -> String:
	var seconds_survived := float(stats.get("seconds_survived", 0.0))
	var headline := "You held the line and made it out."
	if died:
		headline = "The horde took your operative down."
	elif not extracted:
		headline = "The dropship left without you."
	var extensions := int(stats.get("extensions", 0))
	var extension_line := (
		"
Extensions  %d" % extensions if extensions > 0 else ""
	)
	return "%s

Survived  %d:%02d      Kills  %d
Run level  %d      Scrap  %d%s
+%d Credits" % [
		headline,
		int(seconds_survived) / 60,
		int(seconds_survived) % 60,
		int(stats.get("kills", 0)),
		int(stats.get("run_level", 1)),
		int(stats.get("scrap", 0)),
		extension_line,
		int(stats.get("credits", 0)),
	]


func _setup_continue_button(stats: Dictionary) -> void:
	# Phase 5: push your luck — more time, harder horde, bigger payout.
	var can_extend := (
		bool(stats.get("can_extend", false))
		and _objective != null
		and _objective.has_method(&"extend_run")
	)
	if _continue_button == null and can_extend:
		_continue_button = Button.new()
		_continue_button.custom_minimum_size = Vector2(0, 46)
		_continue_button.theme_type_variation = &"PrimaryButton"
		_continue_button.pressed.connect(_on_continue_pressed)
		restart_button.get_parent().add_child(_continue_button)
		restart_button.get_parent().move_child(
			_continue_button, restart_button.get_index()
		)
	if _continue_button == null:
		return
	_continue_button.visible = can_extend
	if can_extend:
		var multiplier := float(_objective.call(&"get_reward_multiplier"))
		_continue_button.text = "PUSH ON  ·  +5 MIN  ·  REWARD x%.1f" % (
			multiplier * float(_objective.get(&"extension_reward_multiplier"))
		)


func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _objective != null:
		_objective.call(&"extend_run")


func _apply_outcome_style(
	eyebrow: String, title: String, accent: Color, title_color: Color
) -> void:
	# The panel is authored for defeat; extraction restyles it as a victory.
	eyebrow_label.text = eyebrow
	eyebrow_label.add_theme_color_override(&"font_color", accent)
	title_label.text = title
	title_label.add_theme_color_override(&"font_color", title_color)
	accent_line.color = accent
	top_rail.color = Color(accent.r, accent.g, accent.b, 0.95)
	bottom_rail.color = Color(accent.r, accent.g, accent.b, 0.55)
	# The panel frame is red in the theme; recolour a copy so the whole card
	# reads as a win.
	var panel_style := panel_container.get_theme_stylebox(&"panel")
	var flat_style := panel_style.duplicate() as StyleBoxFlat
	if flat_style != null:
		flat_style.border_color = accent
		flat_style.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
		panel_container.add_theme_stylebox_override(&"panel", flat_style)


func _show_player_defeat() -> void:
	# run_objective listens to the same `died` signal and answers with the far
	# richer run_finished summary. Deferring lets that one win regardless of the
	# order the two listeners were connected in; this stays as the fallback for
	# scenes without a run objective.
	_show_defeat_fallback.call_deferred()


func _show_defeat_fallback() -> void:
	if visible:
		return
	_show_game_over(
		"The horde took your operative down.\nRegroup and try again."
	)


func _show_game_over(message: String) -> void:
	if visible:
		return
	message_label.text = message
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	restart_button.grab_focus()
	get_tree().paused = true
	UiAnimations.fade_in(background, 0.0, 0.22)
	UiAnimations.fade_in(depth_shade, 0.06, 0.28)
	UiAnimations.pop_in(panel_container)


func _restart_current_scene() -> void:
	get_tree().paused = false
	var reload_error := get_tree().reload_current_scene()
	if reload_error != OK:
		push_error("GameOverPanel could not reload the current scene.")
