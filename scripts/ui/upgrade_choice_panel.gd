extends Control

## Survivors-like level-up panel: pauses the run and offers three upgrade cards.
## Cards are built in code so the catalogue can grow without touching the scene.

const RUN_PROGRESSION_GROUP := &"run_progression"
const CARD_MINIMUM_SIZE := Vector2(240, 210)

@onready var level_label: Label = %LevelLabel
@onready var cards_row: HBoxContainer = %CardsRow

var _progression: Node
var _pending_levels: Array = []
var _is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_progression = get_tree().get_first_node_in_group(RUN_PROGRESSION_GROUP)
	if _progression == null:
		push_error("UpgradeChoicePanel requires a run_progression node.")
		return
	_progression.connect(&"run_level_gained", _on_run_level_gained)


func _on_run_level_gained(level: int, choices: Array) -> void:
	# Several levels can arrive at once from a big XP burst; queue them.
	_pending_levels.append({"level": level, "choices": choices})
	if not _is_open:
		_open_next()


func _open_next() -> void:
	if _pending_levels.is_empty():
		_close()
		return
	var entry: Dictionary = _pending_levels.pop_front()
	_is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	level_label.text = "LEVEL %d" % int(entry["level"])
	for child in cards_row.get_children():
		child.queue_free()
	var choices: Array = entry["choices"]
	for choice in choices:
		cards_row.add_child(_build_card(choice))
	await get_tree().process_frame
	if cards_row.get_child_count() > 0:
		(cards_row.get_child(0) as Button).grab_focus()


func _build_card(upgrade: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_MINIMUM_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.text = "%s\n\n%s" % [
		String(upgrade["name"]), String(upgrade["description"])
	]
	card.pressed.connect(_on_card_pressed.bind(StringName(upgrade["id"])))
	return card


func _on_card_pressed(upgrade_id: StringName) -> void:
	if _progression != null:
		_progression.call(&"apply_upgrade", upgrade_id)
	_open_next()


func _close() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
