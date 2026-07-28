extends Control

const RECRUIT_ID := &"recruit"
# The editor test profile now starts from a clean slate (level 1, 0 Credits)
# so the game can be playtested from scratch. Raise these to seed a head start.
const ENABLE_TEST_PROGRESS := true
const TEST_SAVE_PATH := "user://horde_breaker_test.cfg"
const TEST_STARTING_CREDITS := 0
const TEST_RECRUIT_XP := 0
const REFERENCE_SIZE := Vector2(1152.0, 648.0)
const MIN_UI_SCALE := 0.82
const MAX_UI_SCALE := 1.9

@onready var credits_label: Label = %CreditsLabel
@onready var selection_label: Label = %SelectionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var notice_label: Label = %NoticeLabel
@onready var operative_portrait: TextureRect = %OperativePortrait
@onready var start_button: Button = %StartButton
@onready var selection_button: Button = %SelectionButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

var _using_test_progress := false
var _displayed_credits := 0


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_load_test_progress_if_enabled()
	start_button.pressed.connect(GameManager.start_game)
	selection_button.pressed.connect(GameManager.open_character_selection)
	settings_button.pressed.connect(GameManager.open_settings)
	quit_button.pressed.connect(GameManager.quit_game)
	SaveManager.credits_changed.connect(_on_credits_changed)
	SaveManager.selected_character_changed.connect(_on_selected_character_changed)
	_refresh()
	start_button.grab_focus()
	UiAnimations.enhance_buttons(self)
	%BrandColumn.modulate.a = 0.0
	%SummaryColumn.modulate.a = 0.0
	await get_tree().process_frame
	UiAnimations.slide_fade_in(%BrandColumn, Vector2(-28.0, 0.0), 0.0)
	UiAnimations.slide_fade_in(%SummaryColumn, Vector2(28.0, 0.0), 0.1)


func _refresh() -> void:
	var character_id := SaveManager.get_selected_character()
	var character_data := SaveManager.get_character_data(character_id)
	if character_data == null:
		push_error("MainMenu could not find the selected CharacterData.")
		return
	var level := SaveManager.get_character_level(character_id)
	var xp := SaveManager.get_character_xp(character_id)
	var test_suffix := "  ·  TEST" if _using_test_progress else ""
	var credits := SaveManager.get_credits()
	UiAnimations.count_integer(
		credits_label,
		_displayed_credits,
		credits,
		"CREDITS  ·  ",
		test_suffix
	)
	_displayed_credits = credits
	var primary_weapon_id := SaveManager.get_primary_weapon(character_id)
	var secondary_weapon_id := SaveManager.get_secondary_weapon(character_id)
	operative_portrait.texture = UiVisualCatalog.get_character_icon(character_id)
	selection_label.text = "%s\n[1] %s   •   [2] %s" % [
		character_data.display_name,
		_get_weapon_name(primary_weapon_id),
		_get_weapon_name(secondary_weapon_id),
	]
	var available_points := SaveManager.get_available_skill_points(character_id)
	if available_points > 0:
		progress_label.text = "LEVEL %d  •  %d SKILL POINTS" % [level, available_points]
	else:
		progress_label.text = "LEVEL %d  •  XP %d / %d" % [
			level, xp, SaveManager.get_xp_required_for_next_level(level)
		]
	notice_label.text = character_data.class_description



func _apply_responsive_layout() -> void:
	var ui_scale := _get_ui_scale()
	var page_margin := $PageMargin as MarginContainer
	var columns := $PageMargin/Columns as HBoxContainer
	var brand_column := %BrandColumn as VBoxContainer
	var summary_column := %SummaryColumn as VBoxContainer
	var title := $PageMargin/Columns/BrandColumn/Title as Label
	var subtitle := $PageMargin/Columns/BrandColumn/Subtitle as Label
	var brand_spacer := $PageMargin/Columns/BrandColumn/Spacer as Control
	var credits_plate := $PageMargin/Columns/SummaryColumn/CreditsPlate as PanelContainer
	var summary_card := $PageMargin/Columns/SummaryColumn/SummaryCard as PanelContainer
	var summary_margin := $PageMargin/Columns/SummaryColumn/SummaryCard/Margin as MarginContainer
	var summary_content := $PageMargin/Columns/SummaryColumn/SummaryCard/Margin/Content as VBoxContainer
	var summary_eyebrow := $PageMargin/Columns/SummaryColumn/SummaryCard/Margin/Content/Eyebrow as Label
	var selection_row := $PageMargin/Columns/SummaryColumn/SummaryCard/Margin/Content/SelectionRow as HBoxContainer
	var build_badge := $PageMargin/Columns/SummaryColumn/BuildBadge as Label
	var footer := $Footer as Label

	page_margin.offset_left = 48.0 * ui_scale
	page_margin.offset_top = 28.0 * ui_scale
	page_margin.offset_right = -48.0 * ui_scale
	page_margin.offset_bottom = -52.0 * ui_scale
	columns.add_theme_constant_override(&"separation", roundi(24.0 * ui_scale))
	brand_column.custom_minimum_size = Vector2(480.0 * ui_scale, 0.0)
	summary_column.custom_minimum_size = Vector2(460.0 * ui_scale, 0.0)
	brand_column.add_theme_constant_override(&"separation", roundi(12.0 * ui_scale))
	summary_column.add_theme_constant_override(&"separation", roundi(12.0 * ui_scale))
	($PageMargin/Columns/BrandColumn/Eyebrow as Label).add_theme_font_size_override(
		&"font_size", roundi(12.0 * ui_scale)
	)
	title.add_theme_font_size_override(&"font_size", roundi(68.0 * ui_scale))
	subtitle.add_theme_font_size_override(&"font_size", roundi(20.0 * ui_scale))
	brand_spacer.custom_minimum_size = Vector2(0.0, 18.0 * ui_scale)
	_set_button_size(start_button, Vector2(420.0, 58.0), ui_scale)
	_set_button_size(selection_button, Vector2(420.0, 52.0), ui_scale)
	_set_button_size(settings_button, Vector2(420.0, 52.0), ui_scale)
	_set_button_size(quit_button, Vector2(420.0, 48.0), ui_scale)
	credits_label.add_theme_font_size_override(&"font_size", roundi(16.0 * ui_scale))
	credits_plate.custom_minimum_size = Vector2(0.0, 34.0 * ui_scale)
	summary_card.custom_minimum_size = Vector2(0.0, 176.0 * ui_scale)
	_set_margin(summary_margin, 24.0, 22.0, ui_scale)
	summary_content.add_theme_constant_override(&"separation", roundi(11.0 * ui_scale))
	summary_eyebrow.add_theme_font_size_override(&"font_size", roundi(12.0 * ui_scale))
	selection_row.add_theme_constant_override(&"separation", roundi(16.0 * ui_scale))
	_scale_emblem(ui_scale)
	selection_label.add_theme_font_size_override(&"font_size", roundi(22.0 * ui_scale))
	progress_label.add_theme_font_size_override(&"font_size", roundi(16.0 * ui_scale))
	notice_label.add_theme_font_size_override(&"font_size", roundi(15.0 * ui_scale))
	notice_label.custom_minimum_size = Vector2(0.0, 58.0 * ui_scale)
	build_badge.add_theme_font_size_override(&"font_size", roundi(14.0 * ui_scale))
	footer.add_theme_font_size_override(&"font_size", roundi(14.0 * ui_scale))


func _get_ui_scale() -> float:
	var viewport_size := get_viewport_rect().size
	var width_scale := viewport_size.x / REFERENCE_SIZE.x
	var height_scale := viewport_size.y / REFERENCE_SIZE.y
	return clampf(minf(width_scale, height_scale), MIN_UI_SCALE, MAX_UI_SCALE)


func _set_button_size(button: Button, base_size: Vector2, ui_scale: float) -> void:
	button.custom_minimum_size = base_size * ui_scale
	button.add_theme_font_size_override(&"font_size", roundi(17.0 * ui_scale))


func _set_margin(margin: MarginContainer, horizontal: float, vertical: float, ui_scale: float) -> void:
	margin.add_theme_constant_override(&"margin_left", roundi(horizontal * ui_scale))
	margin.add_theme_constant_override(&"margin_right", roundi(horizontal * ui_scale))
	margin.add_theme_constant_override(&"margin_top", roundi(vertical * ui_scale))
	margin.add_theme_constant_override(&"margin_bottom", roundi(vertical * ui_scale))


func _scale_emblem(ui_scale: float) -> void:
	var emblem_holder := $PageMargin/Columns/SummaryColumn/SummaryCard/Margin/Content/SelectionRow/EmblemHolder as Control
	var emblem_diamond := emblem_holder.get_node("EmblemDiamond") as ColorRect
	var emblem_core := emblem_holder.get_node("EmblemCore") as ColorRect
	emblem_holder.custom_minimum_size = Vector2(92.0, 92.0) * ui_scale
	emblem_diamond.position = Vector2(18.0, 16.0) * ui_scale
	emblem_diamond.size = Vector2(56.0, 56.0) * ui_scale
	emblem_diamond.pivot_offset = Vector2(28.0, 28.0) * ui_scale
	emblem_core.position = Vector2(30.0, 28.0) * ui_scale
	emblem_core.size = Vector2(32.0, 32.0) * ui_scale
	emblem_core.pivot_offset = Vector2(16.0, 16.0) * ui_scale

func _load_test_progress_if_enabled() -> void:
	if not ENABLE_TEST_PROGRESS or not OS.has_feature("editor"):
		return
	var should_seed_profile := not FileAccess.file_exists(TEST_SAVE_PATH)
	SaveManager.load_progress(TEST_SAVE_PATH)
	_using_test_progress = true
	if should_seed_profile:
		SaveManager.add_credits(TEST_STARTING_CREDITS)
		SaveManager.add_character_xp(RECRUIT_ID, TEST_RECRUIT_XP)


func _get_weapon_name(weapon_id: StringName) -> String:
	var weapon_data := WeaponCatalog.get_weapon_data(weapon_id)
	return weapon_data.display_name if weapon_data != null else "—"


func _on_credits_changed(_credits: int) -> void:
	_refresh()


func _on_selected_character_changed(_character_id: StringName) -> void:
	_refresh()
