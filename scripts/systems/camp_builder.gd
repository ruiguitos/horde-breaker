class_name CampBuilder
extends Node

signal build_mode_changed(active: bool)
signal structure_placed(structure: StructureBase)

const PLAYER_GROUP := &"player"
const CAMP_ECONOMY_GROUP := &"camp_economy"
const ARENA_NAVIGATION_GROUP := &"arena_navigation"

enum State { IDLE, CATALOG, PLACING }

@export var build_grid_path: NodePath
@export var ghost_container_path: NodePath
@export var built_container_path: NodePath
@export var build_catalog_path: NodePath
@export_range(4.0, 50.0, 1.0) var maximum_build_distance: float = 18.0

@onready var build_grid: BuildGrid = get_node(build_grid_path) as BuildGrid
@onready var ghost_container: Node3D = get_node(ghost_container_path) as Node3D
@onready var built_container: Node3D = get_node(built_container_path) as Node3D
@onready var build_catalog: BuildCatalog = get_node(build_catalog_path) as BuildCatalog

var current_state: State = State.IDLE
var selected_structure: StructureData
var ghost_instance: StructureBase
var current_grid_position: Vector2i
var rotation_steps: int = 0
var _placement_valid: bool = false
var _player: CharacterBody3D
var _camera: Camera3D
var _economy: Node
var _ignore_catalog_close: bool = false
var _layout_loaded: bool = false
var _layout_save_pending: bool = false


func _ready() -> void:
	add_to_group(&"camp_builder")
	if build_grid == null or ghost_container == null or built_container == null:
		push_error("CampBuilder requires valid grid and structure containers.")
		return
	if build_catalog == null:
		push_error("CampBuilder requires a BuildCatalog.")
		return
	build_catalog.structure_selected.connect(select_structure)
	build_catalog.closed.connect(_on_catalog_closed)
	call_deferred(&"_bind_runtime_nodes")
	call_deferred(&"load_base_layout")


func _physics_process(_delta: float) -> void:
	if current_state != State.PLACING:
		return
	if not is_instance_valid(_camera):
		_bind_runtime_nodes()
	if not is_instance_valid(_camera) or ghost_instance == null:
		return
	_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode_toggle"):
		if current_state == State.IDLE:
			enter_build_mode()
		else:
			exit_build_mode()
		get_viewport().set_input_as_handled()
		return
	if current_state == State.IDLE:
		return
	if event.is_action_pressed("build_cancel"):
		if current_state == State.PLACING:
			_open_catalog()
		else:
			exit_build_mode()
		get_viewport().set_input_as_handled()
		return
	if current_state != State.PLACING:
		return
	if event.is_action_pressed("build_rotate"):
		rotation_steps = posmod(rotation_steps + 1, 4)
		_update_ghost()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_confirm"):
		_confirm_build()
		get_viewport().set_input_as_handled()


func is_build_mode_active() -> bool:
	return current_state != State.IDLE


func enter_build_mode() -> void:
	if current_state != State.IDLE:
		return
	_bind_runtime_nodes()
	if not is_instance_valid(_player) or _economy == null:
		_request_feedback("BUILD MODE UNAVAILABLE")
		return
	if _player.global_position.distance_to(build_grid.global_position) > maximum_build_distance:
		_request_feedback("RETURN TO CAMP TO BUILD")
		return
	_set_player_build_mode(true)
	build_grid.set_grid_visible(true)
	current_state = State.CATALOG
	build_catalog.open(_economy)
	build_mode_changed.emit(true)


func select_structure(data: StructureData) -> void:
	if data == null or data.scene == null:
		_request_feedback("INVALID STRUCTURE DATA")
		return
	selected_structure = data
	rotation_steps = 0
	_ignore_catalog_close = true
	build_catalog.close()
	_ignore_catalog_close = false
	current_state = State.PLACING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_spawn_ghost()


func exit_build_mode() -> void:
	if current_state == State.IDLE:
		return
	current_state = State.IDLE
	selected_structure = null
	_clear_ghost()
	build_grid.set_grid_visible(false)
	_ignore_catalog_close = true
	build_catalog.close()
	_ignore_catalog_close = false
	_set_player_build_mode(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	build_mode_changed.emit(false)


func _open_catalog() -> void:
	_clear_ghost()
	selected_structure = null
	current_state = State.CATALOG
	build_catalog.open(_economy)


func _spawn_ghost() -> void:
	_clear_ghost()
	if selected_structure == null or selected_structure.scene == null:
		return
	ghost_instance = selected_structure.scene.instantiate() as StructureBase
	if ghost_instance == null:
		push_error("Structure scenes must inherit StructureBase.")
		return
	ghost_instance.data = selected_structure
	ghost_instance.is_ghost = true
	ghost_container.add_child(ghost_instance)
	_update_ghost()


func _clear_ghost() -> void:
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
	ghost_instance = null
	_placement_valid = false


func _update_ghost() -> void:
	if ghost_instance == null or selected_structure == null or _camera == null:
		return
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := _camera.project_ray_origin(viewport_center)
	var ray_direction := _camera.project_ray_normal(viewport_center)
	var placement_plane := Plane(Vector3.UP, build_grid.global_position.y)
	var intersection: Variant = placement_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		ghost_instance.visible = false
		_placement_valid = false
		return
	var world_position: Vector3 = intersection
	current_grid_position = build_grid.world_to_grid(world_position)
	var footprint := build_grid.get_rotated_size(
		selected_structure.grid_size, rotation_steps
	)
	ghost_instance.global_position = build_grid.get_placement_world(
		current_grid_position, footprint
	)
	ghost_instance.rotation.y = rotation_steps * PI * 0.5
	var player_close_enough := (
		_player != null
		and _player.global_position.distance_to(ghost_instance.global_position)
		<= maximum_build_distance
	)
	_placement_valid = (
		player_close_enough
		and build_grid.is_cell_free(current_grid_position, footprint)
	)
	ghost_instance.visible = true
	ghost_instance.set_ghost_valid(_placement_valid)


func _confirm_build() -> void:
	if not _placement_valid or selected_structure == null:
		_request_feedback("INVALID BUILD POSITION")
		return
	if _economy == null or not bool(
		_economy.call(&"spend_stored_scrap", selected_structure.scrap_cost)
	):
		_request_feedback(
			"NOT ENOUGH STORED SCRAP: %d NEEDED" % selected_structure.scrap_cost
		)
		return
	var real := _spawn_real_structure(
		selected_structure, current_grid_position, rotation_steps, -1
	)
	if real == null:
		return
	_request_feedback(
		"%s BUILT  •  COST %d SCRAP"
		% [selected_structure.display_name.to_upper(), selected_structure.scrap_cost]
	)
	_schedule_layout_save()
	_rebuild_navigation()
	structure_placed.emit(real)
	_spawn_ghost()


func _spawn_real_structure(
	data: StructureData,
	grid_position: Vector2i,
	steps: int,
	health: int
) -> StructureBase:
	var real := data.scene.instantiate() as StructureBase
	if real == null:
		push_error("Structure scenes must inherit StructureBase: %s" % data.id)
		return null
	real.data = data
	real.grid_position = grid_position
	real.rotation_steps = posmod(steps, 4)
	if health >= 0:
		real.current_health = mini(health, data.max_health)
	built_container.add_child(real)
	var footprint := build_grid.get_rotated_size(data.grid_size, real.rotation_steps)
	real.global_position = build_grid.get_placement_world(grid_position, footprint)
	real.rotation.y = real.rotation_steps * PI * 0.5
	build_grid.occupy_cells(grid_position, footprint, real)
	real.structure_destroyed.connect(_on_structure_destroyed)
	real.health_changed.connect(_on_structure_health_changed)
	return real


func load_base_layout() -> void:
	if _layout_loaded or build_grid == null or built_container == null:
		return
	_layout_loaded = true
	var layout: Array = SaveManager.get_base_layout()
	for entry_variant in layout:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var data := StructureCatalog.get_structure(StringName(entry.get("id", "")))
		if data == null or data.scene == null:
			continue
		var grid_position := Vector2i(
			int(entry.get("grid_x", 0)), int(entry.get("grid_y", 0))
		)
		var steps := int(entry.get("rotation_steps", 0))
		var footprint := build_grid.get_rotated_size(data.grid_size, steps)
		if not build_grid.is_cell_free(grid_position, footprint):
			push_warning("Skipped overlapping saved structure: %s" % data.id)
			continue
		_spawn_real_structure(
			data, grid_position, steps, int(entry.get("health", data.max_health))
		)
	_rebuild_navigation()


func _save_all_structures() -> void:
	var layout: Array[Dictionary] = []
	for child in built_container.get_children():
		var structure := child as StructureBase
		if (
			structure == null
			or structure.data == null
			or structure.is_queued_for_deletion()
		):
			continue
		layout.append({
			"id": String(structure.data.id),
			"grid_x": structure.grid_position.x,
			"grid_y": structure.grid_position.y,
			"rotation_steps": structure.rotation_steps,
			"health": structure.current_health,
		})
	SaveManager.save_base_layout(layout)


func _on_structure_destroyed(structure: StructureBase) -> void:
	build_grid.free_structure(structure)
	_schedule_layout_save()
	call_deferred(&"_rebuild_navigation")


func _on_structure_health_changed(_current: int, _maximum: int) -> void:
	_schedule_layout_save()


func _schedule_layout_save() -> void:
	if _layout_save_pending:
		return
	_layout_save_pending = true
	call_deferred(&"_flush_layout_save")


func _flush_layout_save() -> void:
	_layout_save_pending = false
	_save_all_structures()


func _bind_runtime_nodes() -> void:
	_economy = get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	_player = get_tree().get_first_node_in_group(PLAYER_GROUP) as CharacterBody3D
	if _player != null:
		_camera = _player.get_node_or_null(
			"CameraPivot/ShoulderOffset/SpringArm3D/Camera3D"
		) as Camera3D


func _set_player_build_mode(active: bool) -> void:
	if _player == null:
		return
	# Construction is an in-world activity: movement remains active in the
	# catalogue and placement states, while the captured-mouse placement state
	# also keeps normal camera control. Combat and regular interactions are
	# suspended to prevent input conflicts.
	if _player.has_method(&"set_build_mode_active"):
		_player.call(&"set_build_mode_active", active)
	var weapon_controller := _player.get_node_or_null("VisualRoot/WeaponPivot")
	if weapon_controller != null:
		weapon_controller.process_mode = (
			Node.PROCESS_MODE_DISABLED if active else Node.PROCESS_MODE_INHERIT
		)


func _rebuild_navigation() -> void:
	# Several streamed sectors can have their own navigation region. Rebuild only
	# the one that contains the camp grid instead of whichever region registered
	# first (or every loaded sector).
	for navigation in get_tree().get_nodes_in_group(ARENA_NAVIGATION_GROUP):
		if not navigation.has_method(&"build_navigation_mesh"):
			continue
		var region := navigation as Node3D
		if region == null:
			continue
		var local_grid_position := region.to_local(build_grid.global_position)
		var half_extent := float(region.get(&"navigation_half_extent"))
		if (
			absf(local_grid_position.x) <= half_extent
			and absf(local_grid_position.z) <= half_extent
		):
			navigation.call(&"build_navigation_mesh")


func _request_feedback(message: String) -> void:
	if _economy != null and _economy.has_method(&"request_feedback"):
		_economy.call(&"request_feedback", message)


func _on_catalog_closed() -> void:
	if not _ignore_catalog_close and current_state == State.CATALOG:
		exit_build_mode()
