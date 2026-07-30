extends Control

## Survivors-like level-up panel: pauses the run and offers three upgrade cards.
## Cards are built in code so the catalogue can grow without touching the scene.
##
## The panel does not wait forever. Ten seconds in it picks one of the three at
## random and carries on — a level-up is a decision under pressure, not a
## timeout, and a run should never stall because the player stepped away mid
## horde. The bar and the footer both count down so the deadline is never a
## surprise.

const RUN_PROGRESSION_GROUP := &"run_progression"
const CARD_MINIMUM_SIZE := Vector2(240, 210)
## Long enough to read three cards, short enough that the horde still matters.
const AUTO_PICK_SECONDS := 10.0
## Below this the countdown turns urgent.
const URGENT_SECONDS := 3.0
const URGENT_COLOR := Color(1.0, 0.42, 0.32)

@onready var level_label: Label = %LevelLabel
@onready var cards_row: HBoxContainer = %CardsRow
@onready var timer_bar: ProgressBar = %TimerBar
@onready var footer_label: Label = %Footer

var _progression: Node
var _pending_levels: Array = []
var _is_open := false
var _time_left := 0.0
var _offered: Array = []
var _rng := RandomNumberGenerator.new()
var _footer_color: Color


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_rng.randomize()
	_footer_color = footer_label.get_theme_color(&"font_color")
	_progression = get_tree().get_first_node_in_group(RUN_PROGRESSION_GROUP)
	if _progression == null:
		push_error("UpgradeChoicePanel requires a run_progression node.")
		return
	_progression.connect(&"run_level_gained", _on_run_level_gained)


func _process(delta: float) -> void:
	if not _is_open:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_refresh_countdown()
	if _time_left <= 0.0:
		_pick_at_random()


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
	_offered = entry["choices"]
	for choice in _offered:
		cards_row.add_child(_build_card(choice))
	_time_left = AUTO_PICK_SECONDS
	_refresh_countdown()
	await get_tree().process_frame
	if cards_row.get_child_count() > 0:
		(cards_row.get_child(0) as Button).grab_focus()


func _refresh_countdown() -> void:
	timer_bar.value = _time_left / AUTO_PICK_SECONDS
	footer_label.text = "AUTO-PICK IN %d s  ·  the upgrade lasts for this run only" % (
		ceili(_time_left)
	)
	footer_label.add_theme_color_override(
		&"font_color",
		URGENT_COLOR if _time_left <= URGENT_SECONDS else _footer_color
	)


func _pick_at_random() -> void:
	if _offered.is_empty():
		_open_next()
		return
	var choice: Dictionary = _offered[_rng.randi_range(0, _offered.size() - 1)]
	_on_card_pressed(StringName(choice["id"]))


func _build_card(upgrade: Dictionary) -> Button:
	var upgrade_id := StringName(upgrade["id"])
	var rarity := RunUpgrades.get_rarity(upgrade_id)
	var colour: Color = rarity["colour"]
	var level := 0
	if _progression != null and _progression.has_method(&"get_upgrade_level"):
		level = int(_progression.call(&"get_upgrade_level", upgrade_id))

	var card := Button.new()
	card.custom_minimum_size = CARD_MINIMUM_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.text = "%s\n%s\n\nLVL %d → %d\n\n%s" % [
		String(rarity["name"]),
		String(upgrade["name"]),
		level,
		level + 1,
		String(upgrade["effect"]),
	]
	# Tinting the whole card is what makes the rarity readable at a glance; the
	# focus and hover states have to be overridden too or the card flips back to
	# the theme colour the moment it is selected.
	for state in [
		&"font_color", &"font_hover_color", &"font_focus_color",
		&"font_pressed_color",
	]:
		card.add_theme_color_override(state, colour)
	card.pressed.connect(_on_card_pressed.bind(upgrade_id))
	return card


func _on_card_pressed(upgrade_id: StringName) -> void:
	if _progression != null:
		_progression.call(&"apply_upgrade", upgrade_id)
	_offered = []
	_open_next()


func _close() -> void:
	_is_open = false
	visible = false
	_offered = []
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
