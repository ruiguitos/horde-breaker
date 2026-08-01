@tool
class_name Terrain3DWorld
extends Node3D

signal world_ready

const DESIGN := preload("res://scripts/systems/terrain3d_world_design.gd")
const WORLD_SHADER := preload(
	"res://assets/materials/terrain3d_world_low_poly.gdshader"
)
const RUNTIME_MESH_LODS := 4
const RUNTIME_MESH_SIZE := 32
const COLLISION_RADIUS := 48

@onready var terrain_mount: Node3D = %TerrainMount

var terrain: Terrain3D
var is_ready := false
var loaded_persistent_data := false
var setup_duration_ms := 0.0


func _ready() -> void:
	call_deferred(&"_setup_world")


func get_terrain() -> Terrain3D:
	return terrain


func get_terrain_height(world_position: Vector3) -> float:
	if is_instance_valid(terrain):
		var height := terrain.data.get_height(world_position)
		if not is_nan(height):
			return height
	return DESIGN.height_at(world_position.x, world_position.z)


func _setup_world() -> void:
	var started_usec := Time.get_ticks_usec()
	terrain = terrain_mount.call(&"get_terrain") as Terrain3D
	if terrain == null:
		await Signal(terrain_mount, &"terrain_ready")
		terrain = terrain_mount.call(&"get_terrain") as Terrain3D
	if terrain == null:
		push_error("Terrain3D world mount did not provide a terrain node.")
		return
	if terrain.data.get_region_count() != DESIGN.EXPECTED_REGION_COUNT:
		push_error(
			"Terrain3D world expected %d regions in %s, found %d."
			% [
				DESIGN.EXPECTED_REGION_COUNT,
				terrain.data_directory,
				terrain.data.get_region_count(),
			]
		)
		return
	loaded_persistent_data = true
	if not Engine.is_editor_hint():
		# Four clipmap LODs cover well beyond the 80 m atmospheric visibility
		# range while dropping four distant rings from the importer default.
		# Dynamic collision builds only around the active camera and is needed by
		# the player. Enemies query the height map instead of colliding with every
		# terrain facet, so a 48 m radius is ample and keeps large hordes cheap.
		terrain.material.shader_override = WORLD_SHADER
		terrain.material.shader_override_enabled = true
		terrain.material.update()
		terrain.mesh_size = RUNTIME_MESH_SIZE
		terrain.mesh_lods = RUNTIME_MESH_LODS
		terrain.collision.mode = Terrain3DCollision.DYNAMIC_GAME
		terrain.collision.radius = COLLISION_RADIUS
		terrain.collision.build()
		await get_tree().physics_frame
	setup_duration_ms = (Time.get_ticks_usec() - started_usec) / 1000.0
	is_ready = true
	print(
		"Terrain3D world: %d regions ready in %.1f ms."
		% [terrain.data.get_region_count(), setup_duration_ms]
	)
	world_ready.emit()
