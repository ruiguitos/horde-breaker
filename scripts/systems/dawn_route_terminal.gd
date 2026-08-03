class_name DawnRouteTerminal
extends Area3D

signal activation_requested(route_id: StringName)

enum TerminalState {
	LOCKED,
	AVAILABLE,
	SELECTED,
	DISABLED,
}

var route_id: StringName = &""
var route_name := "ROUTE"
var mechanic_name := "PASSAGE"
var collected_cells := 0
var required_cells := 3
var state := TerminalState.LOCKED

@onready var info_label := get_node("InfoLabel") as Label3D
@onready var status_light := get_node("StatusLight") as OmniLight3D
@onready var screen := get_node("Visual/Screen") as MeshInstance3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	info_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_visuals()


func configure(
	id: StringName,
	display_name: String,
	mechanic_display_name: String
) -> void:
	route_id = id
	route_name = display_name
	mechanic_name = mechanic_display_name
	if is_node_ready():
		_refresh_visuals()


func set_progress(current_cells: int, target_cells: int, selected_route: StringName) -> void:
	collected_cells = current_cells
	required_cells = target_cells
	if selected_route == route_id:
		state = TerminalState.SELECTED
	elif selected_route != &"":
		state = TerminalState.DISABLED
	elif collected_cells >= required_cells:
		state = TerminalState.AVAILABLE
	else:
		state = TerminalState.LOCKED
	_refresh_visuals()


func interact(_player: Node) -> bool:
	var was_available := state == TerminalState.AVAILABLE
	activation_requested.emit(route_id)
	return was_available


func _refresh_visuals() -> void:
	if info_label == null or status_light == null or screen == null:
		return
	var colour := Color(0.92, 0.25, 0.08)
	var action := "POWER CELLS %d / %d" % [collected_cells, required_cells]
	match state:
		TerminalState.AVAILABLE:
			colour = Color(1.0, 0.62, 0.12)
			action = "[F] ACTIVATE ROUTE"
		TerminalState.SELECTED:
			colour = Color(0.22, 1.0, 0.48)
			action = "ACTIVE // PASSAGE OPEN"
		TerminalState.DISABLED:
			colour = Color(0.28, 0.31, 0.34)
			action = "OFFLINE // OTHER ROUTE ACTIVE"
	info_label.text = "%s\n%s\n%s" % [route_name, mechanic_name, action]
	info_label.modulate = colour
	status_light.light_color = colour
	status_light.light_energy = 2.0 if state != TerminalState.DISABLED else 0.35
	var material := screen.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = colour.darkened(0.55)
		material.emission = colour


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		info_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		info_label.visible = false
