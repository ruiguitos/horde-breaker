extends Area3D

signal collected

const WEAPON_CONTROLLER_GROUP := &"weapon_controller"
const CAMP_ECONOMY_GROUP := &"camp_economy"

@export var weapon_id: StringName = &"shotgun"
@export var weapon_display_name: String = "Shotgun"

# Fetched leniently: the world streamer attaches a generated sector's nodes a
# few per frame, so a crate can reach _ready before its own children have been
# re-parented, and $Label would error out.
@onready var label: Label3D = get_node_or_null("Label") as Label3D

var _collected := false


func _ready() -> void:
	_update_label()


func configure(new_weapon_id: StringName, new_display_name: String) -> void:
	weapon_id = new_weapon_id
	weapon_display_name = new_display_name
	if is_node_ready():
		_update_label()


func interact(_player: Node) -> bool:
	# Deliberate F pickup: it swaps your secondary weapon, so it is not
	# auto-collected on walk-over like scrap and ammo.
	if _collected:
		return false
	var weapon_controller := get_tree().get_first_node_in_group(
		WEAPON_CONTROLLER_GROUP
	)
	if (
		weapon_controller == null
		or not weapon_controller.has_method(&"equip_field_weapon")
	):
		return false
	if not bool(weapon_controller.call(&"equip_field_weapon", weapon_id)):
		return false
	_collected = true
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null and camp_economy.has_method(&"request_feedback"):
		camp_economy.call(
			&"request_feedback", "EQUIPPED  •  %s  [2]" % weapon_display_name
		)
	collected.emit()
	queue_free()
	return true


func _update_label() -> void:
	if label != null:
		label.text = "%s\n[F] EQUIP" % weapon_display_name.to_upper()
