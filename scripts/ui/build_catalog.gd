class_name BuildCatalog
extends Control

signal structure_selected(data: StructureData)
signal closed

const ITEM_SCENE := preload("res://scenes/ui/build_catalog_item.tscn")

@onready var defense_grid: GridContainer = %DefenseGrid
@onready var utility_grid: GridContainer = %UtilityGrid
@onready var decoration_grid: GridContainer = %DecorationGrid
@onready var scrap_label: Label = %ScrapLabel
@onready var close_button: Button = %CloseButton

var _economy: Node
var _items: Array[BuildCatalogItem] = []


func _ready() -> void:
	hide()
	close_button.pressed.connect(close)


func open(economy: Node) -> void:
	_economy = economy
	_rebuild_items()
	_refresh_scrap()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	close_button.grab_focus()
	if _economy != null and _economy.has_signal(&"scrap_changed"):
		var callable := Callable(self, "_on_scrap_changed")
		if not _economy.is_connected(&"scrap_changed", callable):
			_economy.connect(&"scrap_changed", callable)


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func refresh_unlocks() -> void:
	for item in _items:
		if is_instance_valid(item):
			item.call_deferred(&"_refresh")


func _rebuild_items() -> void:
	for grid in [defense_grid, utility_grid, decoration_grid]:
		for child in grid.get_children():
			child.queue_free()
	_items.clear()
	for data in StructureCatalog.get_all():
		var item := ITEM_SCENE.instantiate() as BuildCatalogItem
		if item == null:
			continue
		item.setup(data, _economy)
		item.structure_selected.connect(_on_structure_selected)
		_get_grid(data.category).add_child(item)
		_items.append(item)


func _get_grid(category: StringName) -> GridContainer:
	match category:
		&"utility":
			return utility_grid
		&"decoration":
			return decoration_grid
		_:
			return defense_grid


func _on_structure_selected(data: StructureData) -> void:
	structure_selected.emit(data)


func _on_scrap_changed(_carried: int, _stored: int) -> void:
	_refresh_scrap()
	for item in _items:
		if is_instance_valid(item):
			item.call_deferred(&"_refresh")


func _refresh_scrap() -> void:
	var stored := 0
	if _economy != null and _economy.has_method(&"get_stored_scrap"):
		stored = int(_economy.call(&"get_stored_scrap"))
	scrap_label.text = "STORED SCRAP  %d" % stored
