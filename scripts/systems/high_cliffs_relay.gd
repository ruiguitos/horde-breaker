class_name HighCliffsRelay
extends Area3D

## A signal relay on High Cliffs. Switched on by hand, then it charges for a
## while — and it can be knocked back offline before it finishes.
##
## That two-step is the island's objective in one object. The plan gives High
## Cliffs "activate the relays, defend them", and a relay that completed the
## instant you touched it would only be the first half. Charging gives the horde
## a window to interrupt, which is what makes holding the ground the point.

signal charge_changed(progress: float)
signal came_online(relay_id: StringName)
signal knocked_offline(relay_id: StringName)

enum State { IDLE, CHARGING, ONLINE }

## Long enough to be a stand, short enough not to be a chore. A playtest target,
## like every other duration in the plan.
@export_range(1.0, 120.0, 0.5) var charge_seconds: float = 12.0

var relay_id: StringName = &""
var state: State = State.IDLE
var charge_progress: float = 0.0

var _label: Label3D
var _beacon: MeshInstance3D
var _light: OmniLight3D
var _player_inside := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	set_process(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_label()


func configure(id: StringName) -> void:
	relay_id = id
	if is_node_ready():
		_refresh_label()


func _process(delta: float) -> void:
	if state != State.CHARGING:
		return
	charge_progress = minf(charge_progress + delta / charge_seconds, 1.0)
	charge_changed.emit(charge_progress)
	_refresh_label()
	if charge_progress >= 1.0:
		_come_online()


## Starts the charge. Refused once the relay is online — there is nothing left to
## do to it — and harmless if it is already charging.
func interact(_player: Node) -> bool:
	if state == State.ONLINE or state == State.CHARGING:
		return false
	state = State.CHARGING
	charge_progress = 0.0
	set_process(true)
	_refresh_label()
	return true


## Knocks a charging relay back to idle. An online relay is finished and cannot
## be lost — otherwise a late hit could reopen an island the player had already
## paid for, which is the soft-lock rule read the other way round.
func take_damage(amount: float) -> float:
	if amount <= 0.0 or state != State.CHARGING:
		return 0.0
	state = State.IDLE
	charge_progress = 0.0
	set_process(false)
	_refresh_label()
	knocked_offline.emit(relay_id)
	return amount


func is_online() -> bool:
	return state == State.ONLINE


func build_visuals() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 2.6
	collision.position.y = 1.2
	collision.shape = shape
	add_child(collision)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14, 0.16, 0.19)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.62, 0.95)
	material.emission_energy_multiplier = 1.2
	material.roughness = 0.45

	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.16
	mast_mesh.bottom_radius = 0.34
	mast_mesh.height = 4.6
	mast_mesh.radial_segments = 8
	mast_mesh.material = material
	var mast := MeshInstance3D.new()
	mast.name = "RelayMast"
	mast.position.y = 2.3
	mast.mesh = mast_mesh
	add_child(mast)

	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.55
	beacon_mesh.height = 1.1
	beacon_mesh.radial_segments = 10
	beacon_mesh.rings = 5
	beacon_mesh.material = material
	_beacon = MeshInstance3D.new()
	_beacon.name = "RelayBeacon"
	_beacon.position.y = 4.9
	_beacon.mesh = beacon_mesh
	add_child(_beacon)

	_light = OmniLight3D.new()
	_light.name = "RelayLight"
	_light.position.y = 4.9
	_light.light_color = Color(0.4, 0.68, 1.0)
	_light.light_energy = 1.2
	_light.omni_range = 9.0
	_light.shadow_enabled = false
	add_child(_light)

	_label = Label3D.new()
	_label.name = "InfoLabel"
	_label.position.y = 6.2
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.font_size = 18
	_label.outline_size = 7
	add_child(_label)
	_refresh_label()


func _come_online() -> void:
	state = State.ONLINE
	charge_progress = 1.0
	set_process(false)
	_refresh_label()
	came_online.emit(relay_id)


func _refresh_label() -> void:
	if _label == null:
		return
	match state:
		State.ONLINE:
			_label.text = "RELAY ONLINE"
			_label.modulate = Color(0.4, 1.0, 0.55)
		State.CHARGING:
			_label.text = "RELAY CHARGING // %d%%\nHOLD THE GROUND" % roundi(
				charge_progress * 100.0
			)
			_label.modulate = Color(1.0, 0.78, 0.24)
		_:
			_label.text = (
				"SIGNAL RELAY\n[F] ACTIVATE" if _player_inside else "SIGNAL RELAY"
			)
			_label.modulate = Color(0.55, 0.78, 1.0)
	if _light != null:
		_light.light_color = _label.modulate
		_light.light_energy = 2.4 if state == State.ONLINE else 1.2
	if _beacon != null:
		_beacon.scale = Vector3.ONE * (1.25 if state == State.ONLINE else 1.0)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_player_inside = true
		_refresh_label()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_player_inside = false
		_refresh_label()
