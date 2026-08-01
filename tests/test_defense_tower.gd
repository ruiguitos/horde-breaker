extends SceneTree

const TOWER_SCENE := preload("res://scenes/world/defense_tower_site.tscn")
const ZOMBIE_SCENE := preload("res://scenes/enemies/normal_zombie.tscn")
const SPIT_SCENE := preload("res://scenes/enemies/spit_projectile.tscn")

var _passed := 0
var _failed := 0


class FakeEconomy extends Node:
	var carried_scrap: int = 0
	var stored_scrap: int = 1000
	var last_feedback: String = ""

	func spend_stored_scrap(amount: int) -> bool:
		if amount <= 0 or stored_scrap < amount:
			return false
		stored_scrap -= amount
		return true

	func request_feedback(message: String, _duration: float = 2.5) -> void:
		last_feedback = message


class FakeWaveManager extends Node:
	func is_preparation_active() -> bool:
		return true


class FakeProgression extends Node:
	var run_level: int = 1


class FakeTarget extends StaticBody3D:
	var current_health: float = 100.0

	func take_damage(amount: float) -> float:
		var applied := minf(amount, current_health)
		current_health -= applied
		return applied


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var world := Node3D.new()
	world.name = "DefenseTowerTestWorld"
	root.add_child(world)
	current_scene = world

	var economy := FakeEconomy.new()
	economy.add_to_group(&"camp_economy")
	world.add_child(economy)
	var wave_manager := FakeWaveManager.new()
	wave_manager.add_to_group(&"wave_manager")
	world.add_child(wave_manager)
	var progression := FakeProgression.new()
	progression.add_to_group(&"run_progression")
	world.add_child(progression)

	var tower := TOWER_SCENE.instantiate() as StaticBody3D
	world.add_child(tower)
	await process_frame

	_check("tower begins as an unbuilt site", int(tower.call(&"get_tower_level")) == 0)
	_check("unbuilt tower is not an enemy target", not tower.is_in_group(&"enemy_target"))
	_check("level one can be built", bool(tower.call(&"interact", null)))
	await process_frame
	_check("build spends 45 stored Scrap", economy.stored_scrap == 955)
	_check("built tower becomes an enemy target", tower.is_in_group(&"enemy_target"))
	_check("level one health is 200", is_equal_approx(float(tower.call(&"get_maximum_health")), 200.0))
	_check("level one damage is 12", is_equal_approx(float(tower.call(&"get_damage")), 12.0))
	_check("level one range is 14", is_equal_approx(float(tower.call(&"get_attack_range")), 14.0))

	_check("level two is locked below run level five", not bool(tower.call(&"interact", null)))
	_check("locked upgrade does not spend Scrap", economy.stored_scrap == 955)
	_check("lock feedback states the required level", economy.last_feedback == "RUN LEVEL 5 REQUIRED")
	progression.run_level = 5
	_check("run level five unlocks level two", bool(tower.call(&"interact", null)))
	_check("level two spends 90 Scrap", economy.stored_scrap == 865)
	_check("level two damage is 18", is_equal_approx(float(tower.call(&"get_damage")), 18.0))
	progression.run_level = 10
	_check("run level ten unlocks level three", bool(tower.call(&"interact", null)))
	_check("level three spends 150 Scrap", economy.stored_scrap == 715)
	_check("level three health is 475", is_equal_approx(float(tower.call(&"get_maximum_health")), 475.0))
	_check("level three damage is 28", is_equal_approx(float(tower.call(&"get_damage")), 28.0))
	_check("level three fires every half second", is_equal_approx(float(tower.call(&"get_fire_interval")), 0.5))

	tower.call(&"take_damage", 100.0)
	_check("tower takes incoming damage", is_equal_approx(float(tower.get(&"current_health")), 375.0))
	_check("interaction repairs a damaged tower before any upgrade", bool(tower.call(&"interact", null)))
	_check("one repair restores at most 75 HP", is_equal_approx(float(tower.get(&"current_health")), 450.0))
	_check("repair costs 15 Scrap", economy.stored_scrap == 700)

	var enemy := FakeTarget.new()
	enemy.add_to_group(&"enemy")
	world.add_child(enemy)
	enemy.global_position = tower.global_position + Vector3(0.0, 0.0, -8.0)
	for _frame in 3:
		await physics_frame
	_check("tower automatically damages a nearby enemy", enemy.current_health <= 72.0)
	_check("tower has a reusable muzzle flash", tower.get_node_or_null("TowerVisual/TurretPivot/Muzzle/MuzzleFlash") != null)
	_check("tower has a reusable impact flash", tower.get_node_or_null("ImpactFlash") != null)

	var health_before_spit := float(tower.get(&"current_health"))
	var spit := SPIT_SCENE.instantiate() as Area3D
	world.add_child(spit)
	spit.call(&"_on_body_entered", tower)
	_check("ranged enemy projectiles damage an active tower", float(tower.get(&"current_health")) < health_before_spit)

	var player_target := FakeTarget.new()
	player_target.add_to_group(&"enemy_target")
	world.add_child(player_target)
	player_target.global_position = Vector3(30.0, 0.0, 0.0)
	var zombie := ZOMBIE_SCENE.instantiate() as CharacterBody3D
	world.add_child(zombie)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(2.0, 0.0, 0.0)
	_check("a zombie selects the nearer active tower", zombie.call(&"_find_closest_target") == tower)

	tower.call(&"take_damage", 9999.0)
	await process_frame
	_check("destroyed tower returns to an unbuilt site", int(tower.call(&"get_tower_level")) == 0)
	_check("destroyed tower leaves the enemy target group", not tower.is_in_group(&"enemy_target"))
	_check("zombie falls back to the player target", zombie.call(&"_find_closest_target") == player_target)
	_report()


func _report() -> void:
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
