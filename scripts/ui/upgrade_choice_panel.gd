extends Control

const WAVE_MANAGER_GROUP := &"wave_manager"
const RUN_UPGRADES_GROUP := &"run_upgrades"

@onready var choice_column: VBoxContainer = %ChoiceColumn
@onready var card_titles: Array[Label] = [%Card1Title, %Card2Title, %Card3Title]
@onready var card_descriptions: Array[Label] = [
	%Card1Description, %Card2Description, %Card3Description
]
@onready var card_buttons: Array[Button] = [
	%Card1Button, %Card2Button, %Card3Button
]
@onready var hint_label: Label = %Hint

var _run_upgrades: Node
var _current_choices: Array[Dictionary] = []


func _ready() -> void:
	hide()
	_run_upgrades = get_tree().get_first_node_in_group(RUN_UPGRADES_GROUP)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if _run_upgrades == null or wave_manager == null:
		push_error(
			"UpgradeChoicePanel requires run_upgrades and wave_manager nodes."
		)
		return
	wave_manager.connect(&"intermission_started", _on_intermission_started)
	wave_manager.connect(&"wave_started", _on_wave_started)
	for button_index in card_buttons.size():
		card_buttons[button_index].pressed.connect(
			_on_choice_pressed.bind(button_index)
		)


func _on_intermission_started(_next_wave: int, _duration: float) -> void:
	_open_choices()


func _on_wave_started(_wave_number: int) -> void:
	_close()


func _open_choices() -> void:
	if _run_upgrades == null:
		return
	_current_choices = _run_upgrades.call(&"get_random_choices", card_buttons.size())
	for card_index in card_buttons.size():
		if card_index >= _current_choices.size():
			continue
		var choice: Dictionary = _current_choices[card_index]
		card_titles[card_index].text = String(choice["title"])
		card_descriptions[card_index].text = String(choice["description"])
	_update_hint()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UiAnimations.fade_in(choice_column, 0.0, 0.2)
	card_buttons[0].grab_focus()


func _update_hint() -> void:
	var unlocked_count: int = _run_upgrades.call(&"get_unlocked_upgrades").size()
	var total_count: int = _run_upgrades.call(&"get_total_upgrade_count")
	if unlocked_count < total_count:
		hint_label.text = (
			"Upgrades unlocked %d / %d  •  Level up your class to unlock more.  •  This run only."
			% [unlocked_count, total_count]
		)
	else:
		hint_label.text = "The upgrade lasts for this run only.  •  You can keep exploring and choose later."


func _on_choice_pressed(card_index: int) -> void:
	if card_index < _current_choices.size():
		_run_upgrades.call(&"apply_upgrade", _current_choices[card_index]["id"])
	_close()


func _close() -> void:
	if not visible:
		return
	hide()
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
