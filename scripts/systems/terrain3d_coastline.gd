class_name Terrain3DCoastline
extends Node3D

const DESIGN := preload("res://scripts/systems/terrain3d_world_design.gd")
const FOAM_SHADER := preload(
	"res://assets/materials/terrain3d_coast_foam.gdshader"
)
const WORLD_COLLISION_LAYER := 1

@export_range(32, 256, 8) var barrier_segments := 128
@export_range(64, 512, 8) var foam_segments := 256
@export_range(0.2, 4.0, 0.1) var barrier_thickness := 1.2
## The shoreline stays readable and enterable. This backstop sits in the sea,
## far enough from the foam that touching water does not feel like a world edge.
@export_range(8.0, 32.0, 1.0) var barrier_offshore_distance := 24.0
@export_range(2.0, 12.0, 0.5) var barrier_height := 8.0
@export_range(0.0, 3.0, 0.25) var barrier_seabed_margin := 1.0
@export_range(0.5, 8.0, 0.1) var foam_width := 3.4

var barrier_body: StaticBody3D
var foam_mesh_instance: MeshInstance3D
var barrier_shape_count := 0


func _ready() -> void:
	_build_barrier()
	_build_foam()


func _build_barrier() -> void:
	barrier_body = StaticBody3D.new()
	barrier_body.name = "ShorelineBoundary"
	barrier_body.collision_layer = WORLD_COLLISION_LAYER
	barrier_body.collision_mask = 0
	barrier_body.add_to_group(&"shoreline_boundary")
	add_child(barrier_body)
	var points := _get_closed_coastline(
		barrier_segments, barrier_offshore_distance
	)
	var barrier_bottom := DESIGN.SEABED_HEIGHT - barrier_seabed_margin
	var barrier_top := DESIGN.WATER_HEIGHT + barrier_height
	for index in barrier_segments:
		var start := points[index]
		var end := points[index + 1]
		var direction := end - start
		var collision := CollisionShape3D.new()
		collision.name = "Segment%03d" % index
		var shape := BoxShape3D.new()
		shape.size = Vector3(
			direction.length() + barrier_thickness,
			barrier_top - barrier_bottom,
			barrier_thickness
		)
		collision.shape = shape
		var middle := (start + end) * 0.5
		collision.position = Vector3(
			middle.x,
			(barrier_bottom + barrier_top) * 0.5,
			middle.y
		)
		collision.rotation.y = -direction.angle()
		barrier_body.add_child(collision)
	barrier_shape_count = barrier_segments


func _build_foam() -> void:
	var points := _get_closed_coastline(foam_segments, 0.0)
	var vertices := PackedVector3Array()
	var texture_coordinates := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in range(foam_segments + 1):
		var point := points[index]
		var radial := (point - DESIGN.ISLAND_CENTER).normalized()
		var inner := point - radial * foam_width * 0.5
		var outer := point + radial * foam_width * 0.5
		var progress := float(index) / float(foam_segments)
		vertices.append(Vector3(inner.x, DESIGN.WATER_HEIGHT + 0.035, inner.y))
		vertices.append(Vector3(outer.x, DESIGN.WATER_HEIGHT + 0.035, outer.y))
		texture_coordinates.append(Vector2(progress, 0.0))
		texture_coordinates.append(Vector2(progress, 1.0))
	for index in foam_segments:
		var first := index * 2
		indices.append_array(PackedInt32Array([
			first, first + 2, first + 1,
			first + 1, first + 2, first + 3,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = texture_coordinates
	arrays[Mesh.ARRAY_INDEX] = indices
	var foam_mesh := ArrayMesh.new()
	foam_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = FOAM_SHADER
	foam_mesh.surface_set_material(0, material)
	foam_mesh_instance = MeshInstance3D.new()
	foam_mesh_instance.name = "CoastlineFoam"
	foam_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam_mesh_instance.mesh = foam_mesh
	foam_mesh_instance.add_to_group(&"terrain3d_coast_foam")
	add_child(foam_mesh_instance)


func _get_closed_coastline(
	segment_count: int, offshore_distance: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segment_count + 1):
		var angle := TAU * float(index % segment_count) / float(segment_count)
		points.append(DESIGN.coastline_point_at(angle, -offshore_distance))
	return points
