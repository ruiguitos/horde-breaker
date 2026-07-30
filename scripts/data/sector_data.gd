class_name SectorData
extends Resource

## Hand-placed content for one sector of the open world.
##
## The generator scatters loot and spawns at random inside whatever the map
## painter left free, which is fine for sixty-odd sectors nobody has looked at
## and useless for the handful worth designing: an ambush behind a specific
## corner, a cache down a specific alley. A sector with a file at
## `res://data/sectors/sector_<x>_<y>.tres` uses these positions instead.
##
## Every list falls back on its own. Authoring the spawns leaves the loot
## scattered as before, so a sector can be taken over a piece at a time without
## the other sixty-three noticing.
##
## Positions are in metres from the sector centre, on the XZ plane. A sector is
## 64 m across, so they run from -32 to 32; the generator drops anything further
## out rather than placing content in the neighbouring sector.

## Where enemies come from when this sector is ambushed. Empty means scattered.
@export var enemy_spawns: Array[Vector2] = []
## Scrap caches. The run remembers which of these were collected, by index, so
## reordering the list moves what has already been taken.
@export var scrap_caches: Array[Vector2] = []
## Ammunition. Only the first entry is used today; the list keeps the shape of
## the others so it can grow without a migration.
@export var ammunition_boxes: Array[Vector2] = []
## Weapon crates. Placing one here overrides the roughly one-in-three chance the
## generator rolls, so an authored sector always holds its weapon.
@export var weapon_crates: Array[Vector2] = []


func has_enemy_spawns() -> bool:
	return not enemy_spawns.is_empty()


func has_scrap_caches() -> bool:
	return not scrap_caches.is_empty()


func has_ammunition() -> bool:
	return not ammunition_boxes.is_empty()


func has_weapon_crates() -> bool:
	return not weapon_crates.is_empty()
