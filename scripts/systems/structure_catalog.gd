class_name StructureCatalog
extends RefCounted

const STRUCTURES: Array[StructureData] = [
	preload("res://data/structures/barricade.tres"),
	preload("res://data/structures/scrap_wall.tres"),
	preload("res://data/structures/watch_tower.tres"),
	preload("res://data/structures/generator.tres"),
	preload("res://data/structures/spotlight.tres"),
]


static func get_all() -> Array[StructureData]:
	return STRUCTURES.duplicate()


static func get_structure(structure_id: StringName) -> StructureData:
	for structure in STRUCTURES:
		if structure != null and structure.id == structure_id:
			return structure
	return null
