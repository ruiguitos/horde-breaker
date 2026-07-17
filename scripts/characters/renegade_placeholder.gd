extends "res://scripts/characters/player.gd"

@onready var inherited_firearm: Node3D = $VisualRoot/WeaponPivot/AssaultRifle


func _ready() -> void:
	super()
	inherited_firearm.process_mode = Node.PROCESS_MODE_DISABLED
	inherited_firearm.hide()
	inherited_firearm.remove_from_group(&"player_weapon")
