extends Control

const RECRUIT_DATA: CharacterData = preload("res://data/characters/recruit.tres")
const RENEGADE_DATA: CharacterData = preload("res://data/characters/renegade.tres")
const ASSAULT_RIFLE_DATA: WeaponData = preload("res://data/weapons/assault_rifle.tres")
const SHOTGUN_DATA: WeaponData = preload("res://data/weapons/shotgun.tres")
const WORN_SWORD_DATA: WeaponData = preload("res://data/weapons/worn_sword.tres")

@onready var credits_label: Label = %CreditsLabel
@onready var recruit_progress_label: Label = %RecruitProgressLabel
@onready var recruit_status_label: Label = %RecruitStatusLabel
@onready var recruit_button: Button = %RecruitButton
@onready var renegade_progress_label: Label = %RenegadeProgressLabel
@onready var renegade_status_label: Label = %RenegadeStatusLabel
@onready var renegade_button: Button = %RenegadeButton
@onready var weapon_context_label: Label = %WeaponContextLabel
@onready var assault_rifle_button: Button = %AssaultRifleButton
@onready var shotgun_button: Button = %ShotgunButton
@onready var worn_sword_button: Button = %WornSwordButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(GameManager.open_main_menu)
	recruit_button.pressed.connect(_on_recruit_pressed)
	renegade_button.pressed.connect(_on_renegade_pressed)
	assault_rifle_button.pressed.connect(
		_on_weapon_pressed.bind(ASSAULT_RIFLE_DATA)
	)
	shotgun_button.pressed.connect(_on_weapon_pressed.bind(SHOTGUN_DATA))
	worn_sword_button.pressed.connect(_on_weapon_pressed.bind(WORN_SWORD_DATA))
	SaveManager.credits_changed.connect(_on_credits_changed)
	SaveManager.character_progress_changed.connect(_on_character_progress_changed)
	SaveManager.character_purchased.connect(_on_character_purchased)
	SaveManager.selected_character_changed.connect(_on_selected_character_changed)
	SaveManager.weapon_purchased.connect(_on_weapon_purchased)
	SaveManager.selected_weapon_changed.connect(_on_selected_weapon_changed)
	_refresh()
	back_button.grab_focus()


func _refresh() -> void:
	var selected_character := SaveManager.get_selected_character()
	credits_label.text = "Credits: %d" % SaveManager.get_credits()
	recruit_progress_label.text = _get_progress_text(RECRUIT_DATA)
	renegade_progress_label.text = _get_progress_text(RENEGADE_DATA)
	_configure_character_button(RECRUIT_DATA, recruit_status_label, recruit_button)
	_configure_character_button(RENEGADE_DATA, renegade_status_label, renegade_button)
	if selected_character == RENEGADE_DATA.character_id:
		weapon_context_label.text = (
			"Armas do Renegade — a Worn Sword fica selecionada; "
			+ "o ataque chega no Milestone 13."
		)
	else:
		weapon_context_label.text = (
			"Armas do Recruit — a Shotgun pode ser comprada, mas só será "
			+ "equipável quando a respetiva arma jogável existir."
		)
	_configure_weapon_button(assault_rifle_button, ASSAULT_RIFLE_DATA)
	_configure_weapon_button(shotgun_button, SHOTGUN_DATA)
	_configure_weapon_button(worn_sword_button, WORN_SWORD_DATA)


func _get_progress_text(character_data: CharacterData) -> String:
	var level := SaveManager.get_character_level(character_data.character_id)
	var xp := SaveManager.get_character_xp(character_data.character_id)
	if level >= character_data.maximum_level:
		return "Nível %d — máximo" % level
	return "Nível %d — XP %d / %d" % [
		level, xp, SaveManager.get_xp_required_for_next_level(level)
	]


func _configure_character_button(
	character_data: CharacterData, status_label: Label, button: Button
) -> void:
	var character_id := character_data.character_id
	var is_unlocked := SaveManager.is_character_unlocked(character_id)
	var is_selected := SaveManager.get_selected_character() == character_id
	if is_selected:
		status_label.text = "Desbloqueado e selecionado"
		button.text = "Selecionado"
		button.disabled = true
		return
	if is_unlocked:
		status_label.text = "Desbloqueado"
		button.text = "Selecionar"
		button.disabled = false
		return
	status_label.text = "Bloqueado — custo: %d Credits" % character_data.unlock_cost
	button.text = "Desbloquear — %d Credits" % character_data.unlock_cost
	button.disabled = not SaveManager.can_purchase_character(character_data)


func _configure_weapon_button(button: Button, weapon_data: WeaponData) -> void:
	var character_id := SaveManager.get_selected_character()
	button.visible = weapon_data.required_character_id == character_id
	if not button.visible:
		return

	var is_purchased := SaveManager.is_weapon_purchased(
		character_id, weapon_data.weapon_id
	)
	var is_selected := SaveManager.get_selected_weapon(character_id) == weapon_data.weapon_id
	if is_selected:
		button.text = "%s — selecionada" % weapon_data.display_name
		button.disabled = true
		return
	if is_purchased and not weapon_data.is_playable:
		button.text = "%s — comprada; jogável mais tarde" % weapon_data.display_name
		button.disabled = true
		return
	if is_purchased:
		button.text = "Selecionar %s" % weapon_data.display_name
		button.disabled = false
		return

	var level := SaveManager.get_character_level(character_id)
	if level < weapon_data.required_level:
		button.text = "%s — requer nível %d" % [
			weapon_data.display_name, weapon_data.required_level
		]
		button.disabled = true
		return
	button.text = "Comprar %s — %d Credits" % [
		weapon_data.display_name, weapon_data.credit_cost
	]
	button.disabled = not SaveManager.can_purchase_weapon(character_id, weapon_data)


func _on_recruit_pressed() -> void:
	SaveManager.select_character(RECRUIT_DATA.character_id)
	_refresh()


func _on_renegade_pressed() -> void:
	if SaveManager.is_character_unlocked(RENEGADE_DATA.character_id):
		SaveManager.select_character(RENEGADE_DATA.character_id)
	else:
		SaveManager.purchase_character(RENEGADE_DATA)
	_refresh()


func _on_weapon_pressed(weapon_data: WeaponData) -> void:
	var character_id := SaveManager.get_selected_character()
	if SaveManager.is_weapon_purchased(character_id, weapon_data.weapon_id):
		SaveManager.select_weapon(character_id, weapon_data)
	else:
		SaveManager.purchase_weapon(character_id, weapon_data)
	_refresh()


func _on_credits_changed(_credits: int) -> void:
	_refresh()


func _on_character_progress_changed(
	_character_id: StringName, _level: int, _xp: int
) -> void:
	_refresh()


func _on_character_purchased(_character_id: StringName) -> void:
	_refresh()


func _on_selected_character_changed(_character_id: StringName) -> void:
	_refresh()


func _on_weapon_purchased(
	_character_id: StringName, _weapon_id: StringName
) -> void:
	_refresh()


func _on_selected_weapon_changed(
	_character_id: StringName, _weapon_id: StringName
) -> void:
	_refresh()
