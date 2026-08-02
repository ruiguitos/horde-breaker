class_name HighCliffsHub
extends Node3D

## The High Cliffs objective, per docs/ARCHIPELAGO_GAMEPLAY_PLAN.md: bring three
## signal relays online, holding each one while it charges, and the stairway into
## the Ancient Ruins opens.
##
## The three relays sit at deliberately different heights. Verticality is the
## island's identity in the plan, and putting the objective on three levels is
## what makes the player climb rather than walk a circle.
##
## Built like DawnBeachHub and ShadowForestHub — a Node3D that assembles itself
## in _ready and reports through signals — so all three islands read alike.

signal status_changed(message: String)
signal relay_online(relay_id: StringName, online_count: int, total_count: int)
signal relay_lost(relay_id: StringName, online_count: int, total_count: int)
signal ruins_opened

const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")

## Horizontal placements; the terrain decides the height, and the cliff mesa
## makes these three genuinely different elevations.
const RELAY_POSITIONS := [
	Vector3(360.0, 0.0, 366.0),
	Vector3(408.0, 0.0, 381.0),
	Vector3(384.0, 0.0, 424.0),
]
## Across the foot of the ruins stairway, which starts at RUINS_START.
const BARRIER_POSITION := Vector3(385.0, 0.0, 322.0)

var online_relays := 0
var ruins_open := false

var _relays: Array[HighCliffsRelay] = []
var _barrier: StaticBody3D
var _barrier_collision: CollisionShape3D
var _barrier_label: Label3D


func _ready() -> void:
	_build_relays()
	_build_ruins_barrier()
	_refresh_state()


func get_relays() -> Array[HighCliffsRelay]:
	return _relays


func get_online_relay_count() -> int:
	return online_relays


func is_ruins_open() -> bool:
	return ruins_open


func get_objective_text() -> String:
	if ruins_open:
		return "ANCIENT RUINS OPEN // CLIMB TO VOLCANO PEAK"
	return "HIGH CLIFFS // RELAYS ONLINE %d / %d" % [
		online_relays, RELAY_POSITIONS.size()
	]


func _build_relays() -> void:
	var relays_root := Node3D.new()
	relays_root.name = "SignalRelays"
	add_child(relays_root)
	for index in RELAY_POSITIONS.size():
		var relay := HighCliffsRelay.new()
		relay.name = "SignalRelay%02d" % (index + 1)
		relay.position = DESIGN.position_on_land(RELAY_POSITIONS[index])
		relays_root.add_child(relay)
		relay.configure(&"relay_%02d" % (index + 1))
		relay.build_visuals()
		relay.came_online.connect(_on_relay_online)
		relay.knocked_offline.connect(_on_relay_knocked_offline)
		_relays.append(relay)


func _build_ruins_barrier() -> void:
	_barrier = StaticBody3D.new()
	_barrier.name = "RuinsBarrier"
	_barrier.collision_layer = 1
	_barrier.collision_mask = 0
	_barrier.position = DESIGN.position_on_land(BARRIER_POSITION)
	add_child(_barrier)

	_barrier_collision = CollisionShape3D.new()
	_barrier_collision.name = "BarrierCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(12.0, 5.0, 1.2)
	_barrier_collision.position.y = 2.4
	_barrier_collision.shape = shape
	_barrier.add_child(_barrier_collision)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.2, 0.34, 0.4)
	material.emission_enabled = true
	material.emission = Color(0.5, 0.34, 0.95)
	material.emission_energy_multiplier = 2.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.4
	var mesh := BoxMesh.new()
	mesh.size = Vector3(11.6, 4.6, 0.2)
	mesh.material = material
	var pane := MeshInstance3D.new()
	pane.name = "WardPane"
	pane.position.y = 2.4
	pane.mesh = mesh
	_barrier.add_child(pane)

	_barrier_label = Label3D.new()
	_barrier_label.name = "BarrierLabel"
	_barrier_label.position.y = 6.0
	_barrier_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_barrier_label.no_depth_test = true
	_barrier_label.fixed_size = false
	# A gate marker, meant to be read from across its own island but not from
	# another one. Without a range it draws through the terrain from anywhere.
	_barrier_label.visibility_range_end = 160.0
	_barrier_label.visibility_range_end_margin = 24.0
	_barrier_label.pixel_size = 0.008
	_barrier_label.font_size = 34
	_barrier_label.outline_size = 7
	_barrier_label.modulate = Color(0.72, 0.55, 1.0)
	_barrier.add_child(_barrier_label)


func _on_relay_online(relay_id: StringName) -> void:
	online_relays = mini(online_relays + 1, RELAY_POSITIONS.size())
	_refresh_state()
	relay_online.emit(relay_id, online_relays, RELAY_POSITIONS.size())
	if online_relays >= RELAY_POSITIONS.size():
		_open_ruins()
	else:
		status_changed.emit(
			"RELAY ONLINE // %d / %d" % [online_relays, RELAY_POSITIONS.size()]
		)


func _on_relay_knocked_offline(relay_id: StringName) -> void:
	# Only a charging relay can be lost, so this never reduces the count below
	# what is actually standing; it exists to report the setback.
	_refresh_state()
	relay_lost.emit(relay_id, online_relays, RELAY_POSITIONS.size())
	status_changed.emit("RELAY KNOCKED OFFLINE // RESTART IT")


func _open_ruins() -> void:
	if ruins_open:
		return
	ruins_open = true
	if _barrier != null:
		_barrier.visible = false
	if _barrier_collision != null:
		_barrier_collision.set_deferred(&"disabled", true)
	_refresh_state()
	status_changed.emit("ALL RELAYS ONLINE // ANCIENT RUINS OPEN")
	ruins_opened.emit()


func _refresh_state() -> void:
	if _barrier_label == null:
		return
	if ruins_open:
		_barrier_label.text = "ANCIENT RUINS OPEN"
		_barrier_label.modulate = Color(0.4, 1.0, 0.55)
		return
	_barrier_label.text = "ANCIENT RUINS SEALED\nRELAYS %d / %d" % [
		online_relays, RELAY_POSITIONS.size()
	]
	_barrier_label.modulate = Color(0.72, 0.55, 1.0)
