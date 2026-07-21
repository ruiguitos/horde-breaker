extends Area3D

signal activated

const PLAYER_GROUP := &"player"
const CAMP_ECONOMY_GROUP := &"camp_economy"

@onready var status_label: Label3D = %StatusLabel
@onready var beacon_light: OmniLight3D = %BeaconLight

var _is_activated := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_state()


func configure(is_activated: bool) -> void:
	_is_activated = is_activated
	_apply_state()


func activate() -> bool:
	if _is_activated:
		return false
	_is_activated = true
	_apply_state()
	_request_feedback("RECON BEACON ACTIVATED")
	activated.emit()
	return true


func is_activated() -> bool:
	return _is_activated


func _on_body_entered(body: Node3D) -> void:
	if body != null and body.is_in_group(PLAYER_GROUP):
		activate()


func _apply_state() -> void:
	if not is_node_ready():
		return
	status_label.text = (
		"BEACON ACTIVE" if _is_activated else "RECON BEACON"
	)
	status_label.modulate = (
		Color(0.35, 1.0, 0.55, 1.0)
		if _is_activated
		else Color(1.0, 0.72, 0.2, 1.0)
	)
	beacon_light.light_color = (
		Color(0.3, 1.0, 0.48, 1.0)
		if _is_activated
		else Color(1.0, 0.42, 0.12, 1.0)
	)
	set_deferred(&"monitoring", not _is_activated)


func _request_feedback(message: String) -> void:
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null and camp_economy.has_method(&"request_feedback"):
		camp_economy.call(&"request_feedback", message)
