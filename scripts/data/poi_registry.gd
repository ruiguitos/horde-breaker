class_name POIRegistry
extends Resource

@export var entries: Array[POIEntry] = []


func get_entry(poi_id: StringName) -> POIEntry:
	for entry in entries:
		if entry != null and entry.id == poi_id:
			return entry
	return null


func get_entry_at(index: int) -> POIEntry:
	if entries.is_empty():
		return null
	return entries[posmod(index, entries.size())]
