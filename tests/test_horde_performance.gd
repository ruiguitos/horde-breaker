extends SceneTree

## Guards the two frame-cost fixes, both of which are invisible in normal play
## and easy to undo by accident:
##   1. the hit-flash overlay must not be attached while the enemy is unhurt,
##      because an attached overlay renders a second pass every frame;
##   2. only a bounded number of models may animate at once, no matter how
##      tightly the horde packs around the player.

const ZOMBIE_SCENE := "res://scenes/enemies/normal_zombie.tscn"
const ANIMATION_SCRIPT := "res://scripts/characters/imported_model_animation.gd"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await _test_hit_flash_overlay()
	await _test_animation_budget()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_hit_flash_overlay() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var zombie := (load(ZOMBIE_SCENE) as PackedScene).instantiate() as Node3D
	world.add_child(zombie)
	await process_frame
	var meshes: Array[MeshInstance3D] = []
	for value in zombie.find_children("*", "MeshInstance3D", true, false):
		var instance := value as MeshInstance3D
		if instance.visible:
			meshes.append(instance)
	_check("flash: the enemy has visible meshes", not meshes.is_empty())
	var attached := 0
	for instance in meshes:
		if instance.material_overlay != null:
			attached += 1
	_check("flash: no overlay while unhurt (%d attached)" % attached, attached == 0)

	zombie.call(&"take_damage", 10.0)
	await process_frame
	attached = 0
	for instance in meshes:
		if instance.material_overlay != null:
			attached += 1
	_check("flash: overlay attaches on damage", attached == meshes.size())

	# The tween runs on 0.16 s; give it room and confirm it detaches again.
	await create_timer(0.5).timeout
	await process_frame
	attached = 0
	for instance in meshes:
		if instance.material_overlay != null:
			attached += 1
	_check("flash: overlay detaches afterwards (%d left)" % attached, attached == 0)
	world.queue_free()
	await process_frame


func _test_animation_budget() -> void:
	var animation_script: GDScript = load(ANIMATION_SCRIPT)
	var budget := int(animation_script.get(&"ANIMATION_BUDGET"))
	_check("budget: a budget is defined", budget > 0 and budget < 60)

	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	player.global_position = Vector3.ZERO

	# Pack far more enemies than the budget into a tight ring: distance-based
	# LOD alone would let every one of them keep animating.
	var count := budget * 3
	var zombie_scene: PackedScene = load(ZOMBIE_SCENE)
	var zombies: Array[Node3D] = []
	for index in count:
		var zombie := zombie_scene.instantiate() as Node3D
		world.add_child(zombie)
		var angle := TAU * float(index) / float(count)
		var radius := 4.0 + float(index) * 0.1
		zombie.global_position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		zombie.set_physics_process(false)
		zombies.append(zombie)
	# The LOD check runs on its own interval; wait for it to come around.
	for _frame in 8:
		await process_frame
	await create_timer(1.0).timeout
	await process_frame

	var animating := 0
	for zombie in zombies:
		for value in zombie.find_children("*", "AnimationPlayer", true, false):
			if (value as AnimationPlayer).active:
				animating += 1
			break
	_check(
		"budget: %d enemies within reach, %d animating" % [count, animating],
		animating <= budget
	)
	_check("budget: the closest ones still animate", animating > 0)
	world.queue_free()
	await process_frame


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
