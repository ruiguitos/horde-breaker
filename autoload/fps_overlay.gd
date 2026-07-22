extends CanvasLayer

## Lightweight always-on-top FPS counter for playtesting. Toggle with F3.
## Colour-coded so frame-rate drops are obvious at a glance.

const UPDATE_INTERVAL := 0.25
const GOOD_COLOR := Color(0.55, 0.9, 0.62, 1.0)
const WARNING_COLOR := Color(0.96, 0.78, 0.34, 1.0)
const DANGER_COLOR := Color(0.95, 0.42, 0.4, 1.0)
const NUMERIC_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const WORLD_STREAMER_GROUP := &"world_streamer"

var _label: Label
var _accumulated_time := 0.0
var _world_streamer: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(8, 6)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override(&"panel", style)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override(&"font", NUMERIC_FONT)
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.text = "-- FPS"
	panel.add_child(_label)
	add_child(panel)
	_update_label()


func _process(delta: float) -> void:
	_accumulated_time += delta
	if _accumulated_time < UPDATE_INTERVAL:
		return
	_accumulated_time = 0.0
	_update_label()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps") and not event.is_echo():
		visible = not visible
		get_viewport().set_input_as_handled()


func _update_label() -> void:
	var fps := Engine.get_frames_per_second()
	var text := "%d FPS" % fps
	# Streaming metrics show up whenever a world streamer is active in-game.
	if not is_instance_valid(_world_streamer):
		_world_streamer = get_tree().get_first_node_in_group(WORLD_STREAMER_GROUP)
	if is_instance_valid(_world_streamer):
		text += "  ·  SECTORS %d" % int(
			_world_streamer.call(&"get_loaded_sector_count")
		)
		var build_ms := float(_world_streamer.get(&"last_build_ms"))
		if build_ms > 0.0:
			text += "  ·  BUILD %.0f ms" % build_ms
	_label.text = text
	if fps >= 55:
		_label.add_theme_color_override(&"font_color", GOOD_COLOR)
	elif fps >= 30:
		_label.add_theme_color_override(&"font_color", WARNING_COLOR)
	else:
		_label.add_theme_color_override(&"font_color", DANGER_COLOR)
