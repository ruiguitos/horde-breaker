@tool
class_name Terrain3DPersistentMount
extends Node3D

signal terrain_ready

const TERRAIN_SCENE := preload("res://addons/terrain_3d/tools/importer.tscn")
const DEFAULT_TERRAIN_ASSETS := preload(
	"res://data/terrain3d_prototype/assets/terrain_assets.tres"
)
const DEFAULT_DATA_DIRECTORY := "res://data/terrain3d_prototype/regions"

@export_dir var data_directory: String = DEFAULT_DATA_DIRECTORY
@export var terrain_assets: Terrain3DAssets = DEFAULT_TERRAIN_ASSETS
@export var select_in_editor := true

@export_tool_button("Select editable Terrain3D")
var select_terrain_action: Callable = _select_terrain
@export_tool_button("Save Terrain3D regions")
var save_terrain_action: Callable = _save_terrain

var _terrain: Terrain3D


func _ready() -> void:
	call_deferred(&"_mount_terrain")


func get_terrain() -> Terrain3D:
	return _terrain


func _mount_terrain() -> void:
	if not is_inside_tree():
		return
	var existing := get_node_or_null("Terrain3D") as Terrain3D
	if existing != null:
		_terrain = existing
		terrain_ready.emit()
		return
	_terrain = TERRAIN_SCENE.instantiate() as Terrain3D
	if _terrain == null:
		push_error("Terrain3D mount could not instantiate its persistent node scene.")
		return
	_terrain.name = "Terrain3D"
	_terrain.free_editor_textures = false
	add_child(_terrain)
	if terrain_assets == null:
		push_error("Terrain3D mount requires a Terrain3DAssets resource.")
		_terrain.queue_free()
		_terrain = null
		return
	_terrain.assets = terrain_assets
	_terrain.material.show_checkered = false
	_terrain.material.world_background = Terrain3DMaterial.NONE
	_terrain.material.auto_shader = true
	_terrain.material.set_shader_param(&"auto_base_texture", 0)
	_terrain.material.set_shader_param(&"auto_overlay_texture", 1)
	_terrain.material.set_shader_param(&"auto_slope", 2.2)
	_terrain.material.set_shader_param(&"blend_sharpness", 0.92)
	# Loading the data after the native node enters the tree avoids a Terrain3D
	# 1.0.2/Godot 4.7 crash caused by serialising data_directory on the node.
	_terrain.data_directory = data_directory
	if Engine.is_editor_hint() and select_in_editor:
		_select_terrain()
	terrain_ready.emit()


func _select_terrain() -> void:
	if not Engine.is_editor_hint() or not is_instance_valid(_terrain):
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(_terrain)


func _save_terrain() -> void:
	if not Engine.is_editor_hint() or not is_instance_valid(_terrain):
		return
	_terrain.data.save_directory(data_directory)
	print("Terrain3D mount: saved editable regions to %s" % data_directory)
