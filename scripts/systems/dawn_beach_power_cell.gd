class_name DawnBeachPowerCell
extends Area3D

signal collected(cell_id: StringName)

var cell_id: StringName = &""
var display_name := "POWER CELL"
var is_collected := false

@onready var info_label := get_node("InfoLabel") as Label3D
@onready var visual := get_node("Visual") as Node3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	info_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_label()


func configure(id: StringName, item_display_name: String = "POWER CELL") -> void:
	cell_id = id
	display_name = item_display_name
	if is_node_ready():
		_refresh_label()


func interact(_player: Node) -> bool:
	if is_collected:
		return false
	is_collected = true
	visual.visible = false
	info_label.text = "%s RECOVERED" % display_name
	var collision := get_node("CollisionShape3D") as CollisionShape3D
	collision.set_deferred(&"disabled", true)
	collected.emit(cell_id)
	return true


func _refresh_label() -> void:
	if info_label == null:
		return
	info_label.text = "%s\n[F] RECOVER" % display_name


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		info_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		info_label.visible = false
