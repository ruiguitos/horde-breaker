extends SceneTree

## The melee auto-attack used to swing at enemies it could not reach: the box
## volume authored in each scene was shorter and offset sideways compared to the
## range that triggers the swing. This locks the two together and proves a
## dummy standing at the edge of the range actually takes damage.

const MELEE_SCENES: Array[String] = [
	"res://scenes/weapons/worn_sword.tscn",
	"res://scenes/weapons/cleaver.tscn",
	"res://scenes/weapons/fire_axe.tscn",
	"res://scenes/weapons/spear.tscn",
]
## The zombie strikes from 1.4 m, so anything shorter than this is a losing
## trade for the player.
const MINIMUM_REACH := 3.5

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	for scene_path in MELEE_SCENES:
		await _test_weapon(world, scene_path)
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_weapon(world: Node3D, scene_path: String) -> void:
	var weapon := (load(scene_path) as PackedScene).instantiate() as Node3D
	world.add_child(weapon)
	weapon.global_position = Vector3.ZERO
	await process_frame
	var name := scene_path.get_file().get_basename()
	var reach := float(weapon.get(&"proximity_auto_attack_range"))
	_check("%s: reach beats the zombie's 1.4 m" % name, reach >= MINIMUM_REACH)

	var collision := weapon.get_node("AttackArea/AttackCollision") as CollisionShape3D
	var area := weapon.get_node("AttackArea") as Area3D
	var box := collision.shape as BoxShape3D
	_check("%s: volume depth matches the reach" % name, is_equal_approx(box.size.z, reach))
	_check("%s: volume is centred on the weapon axis" % name, is_zero_approx(area.position.x))
	# Front face at 0, back face at -reach: the whole trigger range is covered.
	var far_edge := area.position.z - box.size.z * 0.5
	_check(
		"%s: volume covers the full range (%.2f m)" % [name, absf(far_edge)],
		far_edge <= -reach + 0.01
	)

	# A dummy hitbox at the very edge of the range must be inside the volume.
	var dummy := Area3D.new()
	dummy.collision_layer = 4
	dummy.collision_mask = 0
	var dummy_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	dummy_shape.shape = capsule
	dummy.add_child(dummy_shape)
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -(reach - 0.15))
	await process_frame
	await physics_frame

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = area.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := world.get_world_3d().direct_space_state.intersect_shape(query)
	_check("%s: an enemy at the edge is inside the swing" % name, hits.size() > 0)

	dummy.queue_free()
	weapon.queue_free()
	await process_frame


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
