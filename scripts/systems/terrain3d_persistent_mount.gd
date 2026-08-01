@tool
class_name Terrain3DPersistentMount
extends Node3D

signal terrain_ready

const TERRAIN_SCENE := preload("res://addons/terrain_3d/tools/importer.tscn")
const TERRAIN_ASSETS := preload(
	"res://data/terrain3d_prototype/assets/terrain_assets.tres"
)
const DATA_DIRECTORY := "res://data/terrain3d_prototype/regions"

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
	_terrain.assets = TERRAIN_ASSETS
	_terrain.material.show_checkered = false
	_terrain.material.world_background = Terrain3DMaterial.NONE
	_terrain.material.auto_shader = true
	_terrain.material.set_shader_param(&"auto_base_texture", 0)
	_terrain.material.set_shader_param(&"auto_overlay_texture", 1)
	_terrain.material.set_shader_param(&"auto_slope", 2.2)
	_terrain.material.set_shader_param(&"blend_sharpness", 0.92)
	# Loading the data after the native node enters the tree avoids a Terrain3D
	# 1.0.2/Godot 4.7 crash caused by serialising data_directory on the node.
	_terrain.data_directory = DATA_DIRECTORY
	if Engine.is_editor_hint():
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
	_terrain.data.save_directory(DATA_DIRECTORY)
	print("Terrain3D mount: saved editable regions to %s" % DATA_DIRECTORY)
