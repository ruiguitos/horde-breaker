class_name ShadowForestHub
extends Node3D

## The Shadow Forest objective, per docs/ARCHIPELAGO_GAMEPLAY_PLAN.md: clear
## three zombie nests, recover the winch parts they leave, and use them to repair
## the Rope Bridge on to Volcano Peak.
##
## The plan's hard rule for this island is that no destructible route may create
## a soft-lock. Two things enforce it here. The winch keeps working after the
## first repair, so a bridge broken again can be fixed again; and clearing a nest
## that has already dropped its part cannot consume it twice, so the parts needed
## can never exceed the parts obtainable.
##
## Built the same way as DawnBeachHub — a Node3D that assembles itself in _ready
## and reports through signals — so the two islands read alike in the prototype.

signal status_changed(message: String)
signal winch_part_recovered(current_count: int, required_count: int)
signal nest_cleared(nest_id: StringName, cleared_count: int, total_count: int)
signal bridge_repaired

const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")

const REQUIRED_WINCH_PARTS := 3
## Spread across the island so clearing them is a patrol, not a single fight.
const NEST_POSITIONS := [
	Vector3(92.0, 0.0, 112.0),
	Vector3(148.0, 0.0, 121.0),
	Vector3(118.0, 0.0, 163.0),
]
## The winch sits at the forest end of the bridge, so the walk back is the reward.
const WINCH_POSITION := Vector3(176.0, 0.0, 135.0)

var rope_bridge: DestructibleRouteBridge
var cleared_nests := 0
var recovered_parts := 0
var bridge_repairs := 0

var _nests: Array[ShadowForestNest] = []
var _parts: Array[DawnBeachPowerCell] = []
var _winch_label: Label3D
var _dropped_parts: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_build_nests()
	_build_winch()
	_refresh_state()


func configure(bridge: DestructibleRouteBridge) -> void:
	rope_bridge = bridge
	if rope_bridge != null and not rope_bridge.destroyed.is_connected(_on_bridge_destroyed):
		rope_bridge.destroyed.connect(_on_bridge_destroyed)
	_refresh_state()


func get_nests() -> Array[ShadowForestNest]:
	return _nests


## The winch parts on the ground. One appears per nest cleared, so this grows as
## the island is worked through rather than being laid out up front.
func get_available_parts() -> Array[DawnBeachPowerCell]:
	return _parts


func get_cleared_nest_count() -> int:
	return cleared_nests


func get_recovered_part_count() -> int:
	return recovered_parts


func is_bridge_repaired() -> bool:
	return rope_bridge != null and not rope_bridge.is_destroyed


## Runs the winch. Allowed whenever the parts are in hand and the bridge is
## actually down — repeatedly, because a bridge that can break twice has to be
## repairable twice or the island becomes a dead end.
func request_bridge_repair() -> bool:
	if rope_bridge == null:
		return false
	if not rope_bridge.is_destroyed:
		status_changed.emit("ROPE BRIDGE ALREADY STANDING")
		return false
	if recovered_parts < REQUIRED_WINCH_PARTS:
		status_changed.emit(
			"WINCH INCOMPLETE // %d MORE PART%s"
			% [
				REQUIRED_WINCH_PARTS - recovered_parts,
				"" if REQUIRED_WINCH_PARTS - recovered_parts == 1 else "S",
			]
		)
		return false
	rope_bridge.reset_bridge()
	bridge_repairs += 1
	_refresh_state()
	status_changed.emit("ROPE BRIDGE REPAIRED // VOLCANO PEAK OPEN")
	bridge_repaired.emit()
	return true


func get_objective_text() -> String:
	if cleared_nests < NEST_POSITIONS.size():
		return "SHADOW FOREST // CLEAR NESTS %d / %d" % [
			cleared_nests, NEST_POSITIONS.size()
		]
	if recovered_parts < REQUIRED_WINCH_PARTS:
		return "SHADOW FOREST // RECOVER WINCH PARTS %d / %d" % [
			recovered_parts, REQUIRED_WINCH_PARTS
		]
	if rope_bridge != null and rope_bridge.is_destroyed:
		return "WINCH READY // REPAIR THE ROPE BRIDGE"
	return "ROPE BRIDGE STANDING // CROSS TO VOLCANO PEAK"


func _build_nests() -> void:
	var nests_root := Node3D.new()
	nests_root.name = "ZombieNests"
	add_child(nests_root)
	for index in NEST_POSITIONS.size():
		var nest := ShadowForestNest.new()
		nest.name = "ZombieNest%02d" % (index + 1)
		nest.position = DESIGN.position_on_land(NEST_POSITIONS[index])
		nests_root.add_child(nest)
		nest.configure(&"nest_%02d" % (index + 1))
		nest.build_visuals()
		nest.cleared.connect(_on_nest_cleared)
		_nests.append(nest)


func _build_winch() -> void:
	var winch_root := StaticBody3D.new()
	winch_root.name = "BridgeWinch"
	winch_root.collision_layer = 1
	winch_root.collision_mask = 0
	winch_root.position = DESIGN.position_on_land(WINCH_POSITION)
	add_child(winch_root)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.14, 0.11)
	material.emission_enabled = true
	material.emission = Color(0.85, 0.55, 0.12)
	material.emission_energy_multiplier = 1.1
	material.roughness = 0.5

	var drum_mesh := CylinderMesh.new()
	drum_mesh.top_radius = 0.9
	drum_mesh.bottom_radius = 0.9
	drum_mesh.height = 1.6
	drum_mesh.radial_segments = 10
	drum_mesh.material = material
	var drum := MeshInstance3D.new()
	drum.name = "WinchDrum"
	drum.position.y = 1.1
	drum.rotation.z = PI * 0.5
	drum.mesh = drum_mesh
	winch_root.add_child(drum)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.0, 1.8)
	collision.position.y = 1.0
	collision.shape = shape
	winch_root.add_child(collision)

	_winch_label = Label3D.new()
	_winch_label.name = "WinchLabel"
	_winch_label.position.y = 3.2
	_winch_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_winch_label.no_depth_test = true
	_winch_label.fixed_size = true
	_winch_label.font_size = 19
	_winch_label.outline_size = 7
	_winch_label.modulate = Color(1.0, 0.72, 0.2)
	winch_root.add_child(_winch_label)


## One part per nest, dropped where the nest stood. Guarded by id so a nest that
## somehow reports twice cannot mint a second part — the count of parts in the
## world has to stay equal to the count of nests cleared.
func _on_nest_cleared(nest_id: StringName) -> void:
	if _dropped_parts.has(nest_id):
		return
	_dropped_parts[nest_id] = true
	cleared_nests = mini(cleared_nests + 1, NEST_POSITIONS.size())
	_drop_winch_part(nest_id)
	_refresh_state()
	nest_cleared.emit(nest_id, cleared_nests, NEST_POSITIONS.size())
	status_changed.emit(
		"NEST CLEARED // WINCH PART DROPPED  %d / %d"
		% [cleared_nests, NEST_POSITIONS.size()]
	)


func _drop_winch_part(nest_id: StringName) -> void:
	var source: ShadowForestNest = null
	for nest in _nests:
		if nest.nest_id == nest_id:
			source = nest
	if source == null:
		return
	# Reuses the Dawn Beach pickup rather than duplicating it: it is already a
	# labelled, one-shot, interactable collectible, and the name is the only part
	# of it that is island-specific.
	var part := DawnBeachPowerCell.new()
	part.name = "WinchPart_%s" % nest_id
	part.position = source.position + Vector3(0.0, 1.1, 2.6)
	_build_part_nodes(part)
	add_child(part)
	part.configure(StringName("winch_part_%s" % nest_id), "WINCH PART")
	part.collected.connect(_on_winch_part_collected)
	_parts.append(part)


func _build_part_nodes(part: DawnBeachPowerCell) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	collision.shape = shape
	part.add_child(collision)

	var visual := Node3D.new()
	visual.name = "Visual"
	part.add_child(visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.14, 0.08)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.68, 0.15)
	material.emission_energy_multiplier = 3.0
	material.roughness = 0.4
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.5, 0.7)
	mesh.material = material
	var body := MeshInstance3D.new()
	body.name = "PartBody"
	body.mesh = mesh
	visual.add_child(body)
	var light := OmniLight3D.new()
	light.name = "PartLight"
	light.light_color = Color(1.0, 0.7, 0.2)
	light.light_energy = 1.6
	light.omni_range = 5.5
	light.shadow_enabled = false
	visual.add_child(light)

	var label := Label3D.new()
	label.name = "InfoLabel"
	label.position.y = 1.9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 18
	label.outline_size = 7
	label.modulate = Color(1.0, 0.75, 0.25)
	part.add_child(label)


func _on_winch_part_collected(_part_id: StringName) -> void:
	recovered_parts = mini(recovered_parts + 1, REQUIRED_WINCH_PARTS)
	_refresh_state()
	winch_part_recovered.emit(recovered_parts, REQUIRED_WINCH_PARTS)
	if recovered_parts >= REQUIRED_WINCH_PARTS:
		status_changed.emit("WINCH ASSEMBLED // REPAIR THE ROPE BRIDGE")
	else:
		status_changed.emit(
			"WINCH PART RECOVERED // %d / %d" % [recovered_parts, REQUIRED_WINCH_PARTS]
		)


func _on_bridge_destroyed() -> void:
	_refresh_state()
	if recovered_parts >= REQUIRED_WINCH_PARTS:
		status_changed.emit("ROPE BRIDGE DOWN // WINCH READY TO REPAIR IT")
	else:
		status_changed.emit("ROPE BRIDGE DOWN // RECOVER THE WINCH PARTS")


func _refresh_state() -> void:
	if _winch_label == null:
		return
	_winch_label.text = "BRIDGE WINCH\n%s" % get_objective_text()
	var ready_to_use := (
		recovered_parts >= REQUIRED_WINCH_PARTS
		and rope_bridge != null
		and rope_bridge.is_destroyed
	)
	_winch_label.modulate = (
		Color(0.35, 1.0, 0.5) if ready_to_use else Color(1.0, 0.72, 0.2)
	)
