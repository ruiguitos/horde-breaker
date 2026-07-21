extends Area3D

const PLAYER_GROUP := &"player"

@export_range(2.0, 40.0, 0.5) var speed: float = 14.0
@export_range(0.5, 3.0, 0.1) var lifetime: float = 3.5

var _direction := Vector3.FORWARD
var _damage: float = 8.0
var _elapsed: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(direction: Vector3, damage: float) -> void:
	_direction = direction.normalized()
	_damage = damage


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == null:
		return
	if body.is_in_group(PLAYER_GROUP) and body.has_method(&"take_damage"):
		body.call(&"take_damage", _damage)
	# Any solid body (player or world) stops the spit.
	queue_free()
