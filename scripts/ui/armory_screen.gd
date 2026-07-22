extends Control

const ACCENT_COLOR := Color(0.957, 0.694, 0.31, 1.0)

@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var credits_label: Label = %CreditsLabel
@onready var class_label: Label = %ClassLabel
@onready var level_label: Label = %LevelLabel
@onready var primary_weapon_label: Label = %PrimaryWeaponLabel
@onready var secondary_weapon_label: Label = %SecondaryWeaponLabel
@onready var weapons_list: VBoxContainer = %WeaponsList

var _displayed_credits := 0
var _rebuild_pending := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(GameManager.open_character_selection)
	SaveManager.credits_changed.connect(_on_credits_changed)
	SaveManager.weapon_purchased.connect(_on_weapon_purchased)
	SaveManager.selected_loadout_changed.connect(_on_selected_loadout_changed)
	SaveManager.character_progress_changed.connect(_on_character_progress_changed)
	_rebuild()
	back_button.grab_focus()
	UiAnimations.enhance_buttons(self)
	$PageMargin/Content/TopBar.modulate.a = 0.0
	$PageMargin/Content/Body.modulate.a = 0.0
	await get_tree().process_frame
	UiAnimations.slide_fade_in(
		$PageMargin/Content/TopBar, Vector2(0.0, -18.0), 0.0
	)
	UiAnimations.slide_fade_in(
		$PageMargin/Content/Body, Vector2(24.0, 0.0), 0.08
	)


func _rebuild() -> void:
	var character_id := SaveManager.get_selected_character()
	var character_data := SaveManager.get_character_data(character_id)
	if character_data == null:
		push_error("Armory requires a valid selected character.")
		return
	var credits := SaveManager.get_credits()
	UiAnimations.count_integer(
		credits_label, _displayed_credits, credits, "CREDITS  -  "
	)
	_displayed_credits = credits
	title_label.text = "%s ARMORY" % character_data.display_name.to_upper()
	class_label.text = character_data.display_name
	level_label.text = "LEVEL %d  -  PERMANENT LOADOUT" % (
		SaveManager.get_character_level(character_id)
	)
	primary_weapon_label.text = _get_weapon_name(
		SaveManager.get_primary_weapon(character_id)
	)
	secondary_weapon_label.text = _get_weapon_name(
		SaveManager.get_secondary_weapon(character_id)
	)
	for child in weapons_list.get_children():
		child.queue_free()
	for weapon_data in WeaponCatalog.get_compatible_weapons(character_id):
		if weapon_data.is_playable:
			weapons_list.add_child(_build_weapon_card(character_id, weapon_data))
	UiAnimations.enhance_buttons(weapons_list)


func _build_weapon_card(
	character_id: StringName, weapon_data: WeaponData
) -> PanelContainer:
	var primary_weapon := SaveManager.get_primary_weapon(character_id)
	var secondary_weapon := SaveManager.get_secondary_weapon(character_id)
	var is_equipped := (
		weapon_data.weapon_id == primary_weapon
		or weapon_data.weapon_id == secondary_weapon
	)
	var card := PanelContainer.new()
	card.theme_type_variation = &"SelectedCard" if is_equipped else &"CardPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 16)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 16)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	card.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override(&"separation", 18)
	margin.add_child(content)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override(&"separation", 4)
	content.add_child(details)
	var name_label := Label.new()
	name_label.add_theme_font_size_override(&"font_size", 20)
	name_label.add_theme_color_override(&"font_color", ACCENT_COLOR)
	name_label.text = weapon_data.display_name.to_upper()
	details.add_child(name_label)
	var role_label := Label.new()
	role_label.theme_type_variation = &"MutedLabel"
	role_label.text = "%s  -  %s" % [
		_get_weapon_role(weapon_data.weapon_id),
		(
			"OWNED"
			if SaveManager.is_weapon_purchased(character_id, weapon_data.weapon_id)
			else "REQUIRES LEVEL %d" % weapon_data.required_level
		),
	]
	details.add_child(role_label)

	var actions := HBoxContainer.new()
	actions.custom_minimum_size = Vector2(330, 0)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override(&"separation", 10)
	content.add_child(actions)
	if SaveManager.is_weapon_purchased(character_id, weapon_data.weapon_id):
		actions.add_child(
			_make_equip_button(
				character_id, weapon_data, &"primary", weapon_data.weapon_id == primary_weapon
			)
		)
		actions.add_child(
			_make_equip_button(
				character_id,
				weapon_data,
				&"secondary",
				weapon_data.weapon_id == secondary_weapon
			)
		)
	else:
		actions.add_child(_make_purchase_button(character_id, weapon_data))
	return card


func _make_equip_button(
	character_id: StringName,
	weapon_data: WeaponData,
	slot: StringName,
	is_equipped: bool
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(152, 42)
	button.text = (
		"EQUIPPED [%s]" if is_equipped else "EQUIP [%s]"
	) % ("1" if slot == &"primary" else "2")
	button.disabled = is_equipped
	if not is_equipped:
		button.pressed.connect(
			_on_equip_pressed.bind(character_id, weapon_data, slot)
		)
	return button


func _make_purchase_button(
	character_id: StringName, weapon_data: WeaponData
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220, 42)
	var character_level := SaveManager.get_character_level(character_id)
	if character_level < weapon_data.required_level:
		button.text = "REQUIRES LEVEL %d" % weapon_data.required_level
		button.disabled = true
	elif SaveManager.get_credits() < weapon_data.credit_cost:
		button.text = "NEED %d MORE CREDITS" % (
			weapon_data.credit_cost - SaveManager.get_credits()
		)
		button.disabled = true
	else:
		button.theme_type_variation = &"PrimaryButton"
		button.text = "BUY  -  %d CREDITS" % weapon_data.credit_cost
		button.pressed.connect(
			_on_purchase_pressed.bind(character_id, weapon_data)
		)
	return button


func _get_weapon_name(weapon_id: StringName) -> String:
	var weapon_data := WeaponCatalog.get_weapon_data(weapon_id)
	return weapon_data.display_name if weapon_data != null else "-"


func _get_weapon_role(weapon_id: StringName) -> String:
	if weapon_id == &"assault_rifle":
		return "AUTOMATIC RIFLE"
	if weapon_id == &"pistol":
		return "SIDEARM"
	if weapon_id == &"shotgun":
		return "CLOSE-RANGE FIREARM"
	if weapon_id == &"worn_sword":
		return "MELEE - SLASH"
	if weapon_id == &"spear":
		return "MELEE - THRUST"
	return "WEAPON"


func _on_purchase_pressed(
	character_id: StringName, weapon_data: WeaponData
) -> void:
	SaveManager.purchase_weapon(character_id, weapon_data)


func _on_equip_pressed(
	character_id: StringName, weapon_data: WeaponData, slot: StringName
) -> void:
	SaveManager.select_weapon_for_slot(character_id, weapon_data, slot)


func _on_credits_changed(_credits: int) -> void:
	_queue_rebuild()


func _on_weapon_purchased(
	_character_id: StringName, _weapon_id: StringName
) -> void:
	_queue_rebuild()


func _on_selected_loadout_changed(
	_character_id: StringName,
	_primary_weapon_id: StringName,
	_secondary_weapon_id: StringName
) -> void:
	_queue_rebuild()


func _on_character_progress_changed(
	_character_id: StringName, _level: int, _xp: int
) -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild_deferred.call_deferred()


func _rebuild_deferred() -> void:
	_rebuild_pending = false
	_rebuild()
