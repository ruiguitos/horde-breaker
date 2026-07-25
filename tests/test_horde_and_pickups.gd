extends SceneTree

## Covers the stranded-horde bug (enemies left behind kept occupying the alive
## cap, so the HUD read a full count with nothing in sight), the pickup magnet
## now shared by scrap and ammo, and the wider ground weapon pool.

const WAVE_MANAGER_PATH := "res://scripts/systems/wave_manager.gd"
const SECTOR_GENERATOR_PATH := "res://scripts/systems/sector_generator.gd"
const ZOMBIE_SCENE := "res://scenes/enemies/normal_zombie.tscn"
const SCRAP_SCENE := "res://scenes/pickups/scrap_pickup.tscn"
const AMMO_SCENE := "res://scenes/pickups/ammo_pickup.tscn"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await _test_enemy_recycling()
	await _test_magnet()
	await _test_ammo_despawn()
	_test_weapon_pool()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _build_director(world: Node3D) -> Node:
	# Children, owners and script all set before entering the tree: the % unique
	# names the manager relies on only resolve against an owner, and @onready
	# only runs when the node enters the tree with its script already attached.
	var director := Node.new()
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	director.add_child(spawns)
	spawns.owner = director
	spawns.unique_name_in_owner = true
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	director.add_child(enemies)
	enemies.owner = director
	enemies.unique_name_in_owner = true
	director.set_script(load(WAVE_MANAGER_PATH))
	director.add_to_group(&"wave_manager")
	# Nothing here is testing the spawn loop; keep it from running.
	director.set_physics_process(false)
	world.add_child(director)
	director.set_physics_process(false)
	return director


func _test_enemy_recycling() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	player.global_position = Vector3.ZERO

	var director := _build_director(world)
	await process_frame
	var spawns: Node3D = director.get_node("EnemySpawns")
	var enemies: Node3D = director.get_node("Enemies")
	var marker := Marker3D.new()
	spawns.add_child(marker)
	marker.global_position = Vector3(20.0, 0.0, 0.0)

	var zombie_scene: PackedScene = load(ZOMBIE_SCENE)
	# Three close, two stranded far behind the player.
	var stranded: Array[Node3D] = []
	for index in 5:
		var zombie := zombie_scene.instantiate() as Node3D
		enemies.add_child(zombie)
		zombie.add_to_group(&"horde_enemy")
		zombie.set_physics_process(false)
		if index < 3:
			zombie.global_position = Vector3(float(index) * 2.0, 0.0, 5.0)
		else:
			zombie.global_position = Vector3(400.0, 0.0, float(index))
			stranded.append(zombie)
	# An encounter enemy: not the director's, must never be moved.
	var guard := zombie_scene.instantiate() as Node3D
	enemies.add_child(guard)
	guard.set_physics_process(false)
	guard.global_position = Vector3(500.0, 0.0, 0.0)
	var guard_position := guard.global_position

	director.set(&"alive_enemy_count", 140)
	await process_frame
	director.call(&"_recycle_distant_enemies")
	await process_frame

	_check(
		"recycle: the counter is reconciled with reality (%d)" % int(
			director.get(&"alive_enemy_count")
		),
		int(director.get(&"alive_enemy_count")) == 5
	)
	var moved := 0
	for zombie in stranded:
		if zombie.global_position.distance_to(marker.global_position) < 6.0:
			moved += 1
	_check("recycle: stranded enemies are brought back", moved == stranded.size())
	_check(
		"recycle: encounter enemies stay put",
		guard.global_position.is_equal_approx(guard_position)
	)

	# With no spawn points left there is nowhere to send them, so they go away
	# rather than holding a slot forever.
	marker.queue_free()
	await process_frame
	var lost := zombie_scene.instantiate() as Node3D
	enemies.add_child(lost)
	lost.add_to_group(&"horde_enemy")
	lost.set_physics_process(false)
	lost.global_position = Vector3(900.0, 0.0, 0.0)
	await process_frame
	director.call(&"_recycle_distant_enemies")
	await process_frame
	# is_instance_valid, not is_queued_for_deletion: by now the free may already
	# have been processed, and the freed reference cannot be touched.
	_check(
		"recycle: unreachable enemies are dropped",
		not is_instance_valid(lost) or lost.is_queued_for_deletion()
	)
	world.queue_free()
	await process_frame


func _test_magnet() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	player.global_position = Vector3.ZERO
	var economy := Node.new()
	economy.add_to_group(&"camp_economy")
	world.add_child(economy)

	var scrap := (load(SCRAP_SCENE) as PackedScene).instantiate() as Area3D
	world.add_child(scrap)
	scrap.global_position = Vector3(3.0, 0.0, 0.0)
	var ammo := (load(AMMO_SCENE) as PackedScene).instantiate() as Area3D
	world.add_child(ammo)
	ammo.global_position = Vector3(0.0, 0.0, 3.0)
	var scrap_start := scrap.global_position.distance_to(player.global_position)
	var ammo_start := ammo.global_position.distance_to(player.global_position)
	await process_frame
	for _frame in 12:
		await physics_frame
	_check(
		"magnet: scrap is pulled in",
		scrap.global_position.distance_to(player.global_position) < scrap_start
	)
	_check(
		"magnet: ammo is pulled in",
		ammo.global_position.distance_to(player.global_position) < ammo_start
	)

	# Out of range it must stay put, otherwise every pickup on the map slides.
	var distant := (load(SCRAP_SCENE) as PackedScene).instantiate() as Area3D
	world.add_child(distant)
	distant.global_position = Vector3(40.0, 0.0, 0.0)
	var distant_start := distant.global_position
	for _frame in 8:
		await physics_frame
	_check(
		"magnet: distant pickups stay put",
		distant.global_position.is_equal_approx(distant_start)
	)
	world.queue_free()
	await process_frame


func _test_ammo_despawn() -> void:
	var ammo_script: GDScript = load("res://scripts/pickups/ammo_pickup.gd")
	var constants := ammo_script.get_script_constant_map()
	_check(
		"ammo: a full-reserve despawn delay is defined",
		float(constants.get("FULL_RESERVE_DESPAWN_SECONDS", 0.0)) > 0.0
	)
	var world := Node3D.new()
	root.add_child(world)
	var ammo := (load(AMMO_SCENE) as PackedScene).instantiate() as Area3D
	world.add_child(ammo)
	await process_frame
	# A player whose reserve is full returns 0 from add_ammunition.
	_check(
		"ammo: collection fails when the reserve is full",
		not bool(ammo.call(&"interact", _make_full_player(world)))
	)
	_check("ammo: the despawn clock starts", bool(ammo.get(&"_despawn_scheduled")))
	world.queue_free()
	await process_frame


func _make_full_player(world: Node3D) -> Node:
	var script := GDScript.new()
	script.source_code = (
		"extends Node\nfunc add_ammunition(_amount: int) -> int:\n\treturn 0\n"
	)
	script.reload()
	var stub := Node.new()
	stub.set_script(script)
	world.add_child(stub)
	return stub


func _test_weapon_pool() -> void:
	var generator: GDScript = load(SECTOR_GENERATOR_PATH)
	var pool: Array = generator.get(&"WEAPON_POOL")
	var ids: Array[StringName] = []
	for entry in pool:
		ids.append(entry["id"])
		_check(
			"pool: %s is a real weapon" % entry["id"],
			WeaponCatalog.get_weapon_data(entry["id"]) != null
		)
		_check("pool: %s has a weight" % entry["id"], float(entry["weight"]) > 0.0)
	_check("pool: more than the original three", ids.size() > 3)
	_check("pool: includes the machine gun", ids.has(&"machine_gun"))
	_check("pool: includes a melee option", ids.has(&"fire_axe"))
	# The rare heavy must actually be reachable, and stay rare.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var minigun_draws := 0
	for _draw in 4000:
		if generator.call(&"_pick_weapon", rng)["id"] == &"minigun":
			minigun_draws += 1
	_check("pool: the minigun can be drawn (%d/4000)" % minigun_draws, minigun_draws > 0)
	_check("pool: the minigun stays rare", float(minigun_draws) / 4000.0 < 0.05)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
