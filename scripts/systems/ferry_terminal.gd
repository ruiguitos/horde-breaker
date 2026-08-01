class_name FerryTerminal
extends Area3D

@export_range(0, 1, 1) var destination_index := 1
@export var destination_name := "SHIPWRECK ROCKS"

@onready var info_label := get_node("InfoLabel") as Label3D

var _ferry: AutomaticFerry


func _ready() -> void:
	info_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func configure(ferry: AutomaticFerry) -> void:
	_ferry = ferry
	if not _ferry.trip_started.is_connected(_on_ferry_state_changed):
		_ferry.trip_started.connect(_on_ferry_state_changed)
	if not _ferry.trip_completed.is_connected(_on_ferry_state_changed):
		_ferry.trip_completed.connect(_on_ferry_state_changed)
	_refresh_label()


func interact(player: Node) -> bool:
	if _ferry == null:
		return false
	var accepted := _ferry.request_trip(destination_index, player)
	_refresh_label()
	return accepted


func _on_ferry_state_changed(_dock_index: int) -> void:
	_refresh_label()


func _refresh_label() -> void:
	if info_label == null:
		return
	var action := "FERRY IN TRANSIT"
	if _ferry != null and not _ferry.is_moving():
		action = (
			"[F] TRAVEL TO %s" % destination_name
			if _ferry.current_dock_index != destination_index
			else "FERRY AT OTHER DOCK"
		)
	info_label.text = "AUTOMATIC FERRY\n%s" % action


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		info_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		info_label.visible = false
