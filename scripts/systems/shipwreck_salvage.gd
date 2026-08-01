class_name ShipwreckSalvage
extends Area3D

signal recovered(item_name: String)

@export var item_name := "IRONWORKS NAVIGATION CHART"

@onready var info_label := get_node("InfoLabel") as Label3D

var is_recovered := false


func _ready() -> void:
	info_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact(_player: Node) -> bool:
	if is_recovered:
		return false
	is_recovered = true
	var visual := get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.visible = false
	if info_label != null:
		info_label.text = "EXCLUSIVE SALVAGE\n%s RECOVERED" % item_name
	recovered.emit(item_name)
	return true


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		info_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		info_label.visible = false
