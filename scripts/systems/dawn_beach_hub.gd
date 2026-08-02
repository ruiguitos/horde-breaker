class_name DawnBeachHub
extends Node3D

signal status_changed(message: String)
signal power_cell_collected(current_count: int, required_count: int)
signal route_selected(route_id: StringName)

const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")
const TENT_SCENE := preload("res://assets/models/kenney_mini_forest/tent.glb")
const FLAG_SCENE := preload("res://assets/models/kenney_mini_forest/flag.glb")
const FENCE_SCENE := preload("res://assets/models/kenney_mini_forest/fence.glb")
const CONTAINER_SCENE := preload(
	"res://assets/models/quaternius_zombie_apocalypse/environment/Container_Green.gltf"
)
const BARREL_SCENE := preload(
	"res://assets/models/quaternius_zombie_apocalypse/environment/Barrel.gltf"
)
const PALLET_SCENE := preload(
	"res://assets/models/quaternius_zombie_apocalypse/environment/Pallet.gltf"
)

const ROUTE_A_ID := &"shallow_reef"
const ROUTE_B_ID := &"sea_cave"
const REQUIRED_POWER_CELLS := 3
const CAMP_CENTER := Vector3(120.0, 0.0, 390.0)
const POWER_CELL_POSITIONS := [
	Vector3(86.0, 0.0, 376.0),
	Vector3(151.0, 0.0, 404.0),
	Vector3(116.0, 0.0, 438.0),
]

var cave_gate: ArchipelagoRouteGate
var collected_power_cells := 0
var selected_route_id: StringName = &""
var visual_prop_count := 0
var _power_cells: Array[DawnBeachPowerCell] = []
var _terminals: Dictionary[StringName, DawnRouteTerminal] = {}
var _core_label: Label3D
var _route_a_blocker: StaticBody3D
var _route_a_collision: CollisionShape3D


func _ready() -> void:
	_build_camp()
	_build_power_cells()
	_build_route_terminals()
	_build_route_a_blocker()
	_refresh_state()


func configure(route_b_gate: ArchipelagoRouteGate) -> void:
	cave_gate = route_b_gate
	if cave_gate != null:
		cave_gate.set_unlocked(false)
	_refresh_state()


func request_route_activation(route_id: StringName) -> bool:
	if route_id != ROUTE_A_ID and route_id != ROUTE_B_ID:
		return false
	if selected_route_id != &"":
		status_changed.emit(
			"ROUTE ALREADY LOCKED IN // %s" % _route_display_name(selected_route_id)
		)
		return false
	if collected_power_cells < REQUIRED_POWER_CELLS:
		status_changed.emit(
			"CAMP POWER OFFLINE // RECOVER %d MORE POWER CELL%s"
			% [
				REQUIRED_POWER_CELLS - collected_power_cells,
				"" if REQUIRED_POWER_CELLS - collected_power_cells == 1 else "S",
			]
		)
		return false

	selected_route_id = route_id
	if selected_route_id == ROUTE_A_ID:
		_set_route_a_open(true)
		if cave_gate != null:
			cave_gate.set_unlocked(false)
	else:
		_set_route_a_open(false)
		if cave_gate != null:
			cave_gate.set_unlocked(true)
	_refresh_state()
	status_changed.emit(
		"%s ACTIVE // %s OPEN"
		% [_route_display_name(route_id), _route_mechanic_name(route_id)]
	)
	route_selected.emit(route_id)
	return true


func get_power_cells() -> Array[DawnBeachPowerCell]:
	return _power_cells


func get_collected_power_cell_count() -> int:
	return collected_power_cells


func get_selected_route_id() -> StringName:
	return selected_route_id


func is_route_a_open() -> bool:
	return selected_route_id == ROUTE_A_ID


func get_objective_text() -> String:
	if selected_route_id != &"":
		return "%s ACTIVE // TRAVEL TO %s" % [
			_route_display_name(selected_route_id),
			_route_mechanic_name(selected_route_id),
		]
	if collected_power_cells >= REQUIRED_POWER_CELLS:
		return "CAMP POWER RESTORED // CHOOSE ROUTE A OR ROUTE B"
	return "DAWN BEACH // RECOVER POWER CELLS %d / %d" % [
		collected_power_cells, REQUIRED_POWER_CELLS
	]


func _build_camp() -> void:
	var camp_root := Node3D.new()
	camp_root.name = "ExpeditionCamp"
	add_child(camp_root)

	var core_body := StaticBody3D.new()
	core_body.name = "RoutePowerCore"
	core_body.collision_layer = 1
	core_body.collision_mask = 0
	core_body.position = _on_land(CAMP_CENTER)
	camp_root.add_child(core_body)

	var core_material := _emissive_material(
		Color(0.11, 0.15, 0.17), Color(1.0, 0.34, 0.06), 2.6
	)
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.35
	base_mesh.bottom_radius = 1.65
	base_mesh.height = 0.45
	base_mesh.radial_segments = 12
	base_mesh.material = core_material
	var base := MeshInstance3D.new()
	base.name = "CoreBase"
	base.position.y = 0.25
	base.mesh = base_mesh
	core_body.add_child(base)

	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.42
	column_mesh.bottom_radius = 0.58
	column_mesh.height = 2.2
	column_mesh.radial_segments = 12
	column_mesh.material = core_material
	var column := MeshInstance3D.new()
	column.name = "EnergyColumn"
	column.position.y = 1.45
	column.mesh = column_mesh
	core_body.add_child(column)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.55
	shape.height = 2.8
	collision.position.y = 1.4
	collision.shape = shape
	core_body.add_child(collision)

	var core_light := OmniLight3D.new()
	core_light.name = "CoreLight"
	core_light.position.y = 2.2
	core_light.light_color = Color(1.0, 0.42, 0.08)
	core_light.light_energy = 2.2
	core_light.omni_range = 13.0
	core_light.shadow_enabled = false
	core_body.add_child(core_light)

	_core_label = Label3D.new()
	_core_label.name = "CampStatusLabel"
	_core_label.position = _on_land(CAMP_CENTER) + Vector3.UP * 4.1
	_core_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_core_label.no_depth_test = true
	_core_label.fixed_size = false
	# Landmark signage, readable across its own island but not from another
	# one: no_depth_test draws it through the terrain from anywhere without
	# a range to stop it.
	_core_label.visibility_range_end = 170.0
	_core_label.visibility_range_end_margin = 24.0
	_core_label.pixel_size = 0.008
	_core_label.font_size = 38
	_core_label.outline_size = 7
	_core_label.modulate = Color(1.0, 0.62, 0.16)
	camp_root.add_child(_core_label)

	_add_model(camp_root, TENT_SCENE, Vector3(102.0, 0.0, 392.0), 0.25, 1.8, "CommandTent")
	_add_model(camp_root, FLAG_SCENE, Vector3(106.0, 0.0, 382.0), -0.25, 2.4, "CampFlag")
	_add_model(camp_root, CONTAINER_SCENE, Vector3(137.0, 0.0, 398.0), -0.18, 0.85, "SupplyContainer")
	_add_model(camp_root, PALLET_SCENE, Vector3(132.0, 0.0, 407.0), 0.3, 1.2, "SupplyPallet")
	for index in range(3):
		_add_model(
			camp_root,
			BARREL_SCENE,
			Vector3(128.0 + float(index) * 2.0, 0.0, 407.0),
			float(index) * 0.35,
			0.9,
			"SupplyBarrel%02d" % (index + 1)
		)
	for entry in [
		{"position": Vector3(98.0, 0.0, 382.0), "rotation": 0.0},
		{"position": Vector3(142.0, 0.0, 384.0), "rotation": 0.0},
		{"position": Vector3(98.0, 0.0, 405.0), "rotation": PI},
		{"position": Vector3(142.0, 0.0, 407.0), "rotation": PI},
	]:
		_add_model(
			camp_root,
			FENCE_SCENE,
			entry["position"],
			float(entry["rotation"]),
			1.55,
			"PerimeterFence%02d" % visual_prop_count
		)


func _build_power_cells() -> void:
	var cells_root := Node3D.new()
	cells_root.name = "PowerCells"
	add_child(cells_root)
	for index in POWER_CELL_POSITIONS.size():
		var cell := DawnBeachPowerCell.new()
		cell.name = "PowerCell%02d" % (index + 1)
		cell.configure(&"power_cell_%02d" % (index + 1), "DAWN POWER CELL")
		cell.position = _on_land(POWER_CELL_POSITIONS[index]) + Vector3.UP * 0.75
		_build_power_cell_nodes(cell)
		cells_root.add_child(cell)
		cell.collected.connect(_on_power_cell_collected)
		_power_cells.append(cell)


func _build_power_cell_nodes(cell: DawnBeachPowerCell) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 1.65
	collision.shape = shape
	cell.add_child(collision)

	var visual := Node3D.new()
	visual.name = "Visual"
	cell.add_child(visual)
	var material := _emissive_material(
		Color(0.08, 0.18, 0.2), Color(0.2, 0.88, 1.0), 3.4
	)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.75, 0.9, 0.55)
	mesh.material = material
	var case := MeshInstance3D.new()
	case.name = "EnergyCase"
	case.mesh = mesh
	visual.add_child(case)
	var light := OmniLight3D.new()
	light.name = "CellLight"
	light.light_color = Color(0.2, 0.88, 1.0)
	light.light_energy = 1.8
	light.omni_range = 6.5
	light.shadow_enabled = false
	visual.add_child(light)

	var label := Label3D.new()
	label.name = "InfoLabel"
	label.position.y = 2.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 20
	label.outline_size = 7
	label.modulate = Color(0.3, 0.9, 1.0)
	cell.add_child(label)


func _build_route_terminals() -> void:
	var terminals_root := Node3D.new()
	terminals_root.name = "RouteTerminals"
	add_child(terminals_root)
	_create_terminal(
		terminals_root,
		ROUTE_A_ID,
		"ROUTE A // SHALLOW REEF",
		"TIDE BEACON",
		Vector3(111.0, 0.0, 382.0)
	)
	_create_terminal(
		terminals_root,
		ROUTE_B_ID,
		"ROUTE B // SEA CAVE",
		"DRAINAGE PUMPS",
		Vector3(129.0, 0.0, 382.0)
	)


func _create_terminal(
	parent: Node3D,
	route_id: StringName,
	display_name: String,
	mechanic_name: String,
	position: Vector3
) -> void:
	var terminal := DawnRouteTerminal.new()
	terminal.name = "RouteATerminal" if route_id == ROUTE_A_ID else "RouteBTerminal"
	terminal.configure(route_id, display_name, mechanic_name)
	terminal.position = _on_land(position)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	collision.position.y = 1.0
	collision.shape = shape
	terminal.add_child(collision)

	var visual := Node3D.new()
	visual.name = "Visual"
	terminal.add_child(visual)
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.5, 1.9, 1.05)
	body_mesh.material = _emissive_material(
		Color(0.08, 0.1, 0.11), Color(0.2, 0.08, 0.03), 0.7
	)
	var body := MeshInstance3D.new()
	body.name = "TerminalBody"
	body.position.y = 0.95
	body.mesh = body_mesh
	visual.add_child(body)
	var screen_material := _emissive_material(
		Color(0.22, 0.05, 0.02), Color(0.92, 0.25, 0.08), 2.6
	)
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(1.12, 0.72, 0.08)
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	screen.position = Vector3(0.0, 1.25, -0.56)
	screen.mesh = screen_mesh
	screen.material_override = screen_material
	visual.add_child(screen)

	var light := OmniLight3D.new()
	light.name = "StatusLight"
	light.position = Vector3(0.0, 1.45, -0.65)
	light.omni_range = 6.0
	light.shadow_enabled = false
	terminal.add_child(light)

	var label := Label3D.new()
	label.name = "InfoLabel"
	label.position.y = 3.25
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 18
	label.outline_size = 7
	terminal.add_child(label)

	parent.add_child(terminal)
	terminal.activation_requested.connect(request_route_activation)
	_terminals[route_id] = terminal


func _build_route_a_blocker() -> void:
	_route_a_blocker = StaticBody3D.new()
	_route_a_blocker.name = "RouteABlocker"
	_route_a_blocker.collision_layer = 1
	_route_a_blocker.collision_mask = 0
	_route_a_blocker.position = _on_land(Vector3(120.0, 0.0, 337.0))
	add_child(_route_a_blocker)

	_route_a_collision = CollisionShape3D.new()
	_route_a_collision.name = "BarrierCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(17.0, 5.0, 1.2)
	_route_a_collision.position.y = 2.3
	_route_a_collision.shape = shape
	_route_a_blocker.add_child(_route_a_collision)

	var barrier_material := _emissive_material(
		Color(0.32, 0.04, 0.015, 0.38), Color(1.0, 0.18, 0.03), 2.4
	)
	barrier_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var barrier_mesh := BoxMesh.new()
	barrier_mesh.size = Vector3(16.5, 4.5, 0.18)
	barrier_mesh.material = barrier_material
	var barrier := MeshInstance3D.new()
	barrier.name = "EnergyBarrier"
	barrier.position.y = 2.3
	barrier.mesh = barrier_mesh
	_route_a_blocker.add_child(barrier)
	for side in [-1.0, 1.0]:
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.28
		post_mesh.bottom_radius = 0.4
		post_mesh.height = 5.2
		post_mesh.radial_segments = 8
		post_mesh.material = barrier_material
		var post := MeshInstance3D.new()
		post.name = "BarrierPostLeft" if side < 0.0 else "BarrierPostRight"
		post.position = Vector3(side * 8.5, 2.4, 0.0)
		post.mesh = post_mesh
		_route_a_blocker.add_child(post)

	var label := Label3D.new()
	label.name = "BarrierLabel"
	label.position = Vector3(0.0, 5.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	# Landmark signage, readable across its own island but not from another
	# one: no_depth_test draws it through the terrain from anywhere without
	# a range to stop it.
	label.visibility_range_end = 160.0
	label.visibility_range_end_margin = 24.0
	label.pixel_size = 0.008
	label.font_size = 36
	label.outline_size = 7
	label.modulate = Color(1.0, 0.32, 0.08)
	label.text = "ROUTE A LOCKED\nRESTORE CAMP POWER"
	_route_a_blocker.add_child(label)


func _on_power_cell_collected(_cell_id: StringName) -> void:
	collected_power_cells = mini(collected_power_cells + 1, REQUIRED_POWER_CELLS)
	_refresh_state()
	power_cell_collected.emit(collected_power_cells, REQUIRED_POWER_CELLS)
	if collected_power_cells >= REQUIRED_POWER_CELLS:
		status_changed.emit("CAMP POWER RESTORED // RETURN AND CHOOSE ROUTE A OR B")
	else:
		status_changed.emit(
			"POWER CELL RECOVERED // %d / %d" % [
				collected_power_cells, REQUIRED_POWER_CELLS
			]
		)


func _refresh_state() -> void:
	if _core_label != null:
		_core_label.text = "DAWN EXPEDITION CAMP\n%s" % get_objective_text()
		_core_label.modulate = (
			Color(0.28, 1.0, 0.5)
			if collected_power_cells >= REQUIRED_POWER_CELLS
			else Color(1.0, 0.62, 0.16)
		)
	for terminal in _terminals.values():
		terminal.set_progress(
			collected_power_cells, REQUIRED_POWER_CELLS, selected_route_id
		)


func _set_route_a_open(is_open: bool) -> void:
	if _route_a_blocker == null or _route_a_collision == null:
		return
	_route_a_blocker.visible = not is_open
	_route_a_collision.set_deferred(&"disabled", is_open)


func _route_display_name(route_id: StringName) -> String:
	return "ROUTE A" if route_id == ROUTE_A_ID else "ROUTE B"


func _route_mechanic_name(route_id: StringName) -> String:
	return "SHALLOW REEF" if route_id == ROUTE_A_ID else "SEA CAVE"


func _on_land(horizontal_position: Vector3) -> Vector3:
	return DESIGN.position_on_land(horizontal_position)


func _add_model(
	parent: Node3D,
	source: PackedScene,
	horizontal_position: Vector3,
	y_rotation: float,
	scale_factor: float,
	model_name: String
) -> void:
	var instance := source.instantiate() as Node3D
	if instance == null:
		return
	instance.name = model_name
	instance.position = _on_land(horizontal_position)
	instance.rotation.y = y_rotation
	instance.scale = Vector3.ONE * scale_factor
	parent.add_child(instance)
	visual_prop_count += 1


func _emissive_material(
	albedo: Color, emission: Color, emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.42
	return material
