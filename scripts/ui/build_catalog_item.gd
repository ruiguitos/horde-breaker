class_name BuildCatalogItem
extends Button

signal structure_selected(data: StructureData)

@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel
@onready var description_label: Label = %DescriptionLabel
@onready var lock_label: Label = %LockLabel

var structure_data: StructureData
var _economy: Node


func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh()


func setup(data: StructureData, economy: Node) -> void:
	structure_data = data
	_economy = economy
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if structure_data == null or not is_node_ready():
		return
	name_label.text = structure_data.display_name.to_upper()
	cost_label.text = "%d SCRAP" % structure_data.scrap_cost
	description_label.text = structure_data.description
	var requirement := get_requirement_text()
	var unlocked := is_unlocked()
	lock_label.visible = not unlocked
	lock_label.text = "LOCKED — %s" % requirement
	disabled = not unlocked
	tooltip_text = structure_data.description


func is_unlocked() -> bool:
	if structure_data == null or structure_data.requires_upgrade == &"":
		return true
	if _economy == null or not _economy.has_method(&"get_upgrade_level"):
		return false
	var parsed := _parse_requirement(structure_data.requires_upgrade)
	return int(_economy.call(&"get_upgrade_level", parsed[0])) >= int(parsed[1])


func get_requirement_text() -> String:
	if structure_data == null or structure_data.requires_upgrade == &"":
		return ""
	var parsed := _parse_requirement(structure_data.requires_upgrade)
	return "%s LV %d" % [String(parsed[0]).replace("_", " ").to_upper(), int(parsed[1])]


func _parse_requirement(requirement: StringName) -> Array:
	var text := String(requirement)
	var separator := text.rfind("_")
	if separator < 0:
		return [requirement, 1]
	var level_text := text.substr(separator + 1)
	if not level_text.is_valid_int():
		return [requirement, 1]
	return [StringName(text.left(separator)), level_text.to_int()]


func _on_pressed() -> void:
	if structure_data != null and is_unlocked():
		structure_selected.emit(structure_data)
