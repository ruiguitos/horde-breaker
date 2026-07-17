extends "res://scripts/characters/player.gd"

@onready var placeholder_firearm: Node3D = $VisualRoot/WeaponPivot/AssaultRifle


func _ready() -> void:
	super()
	placeholder_firearm.process_mode = Node.PROCESS_MODE_DISABLED
	placeholder_firearm.hide()
	placeholder_firearm.remove_from_group(&"player_weapon")
