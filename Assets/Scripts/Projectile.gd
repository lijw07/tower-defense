extends Node2D

const SPEED: float = 300.0

var _target: Node2D = null
var _damage: float = 10.0

func initialize(target: Node2D, damage: float) -> void:
	_target = target
	_damage = damage

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	var direction = (_target.global_position - global_position).normalized()
	global_position += direction * SPEED * delta
	rotation = direction.angle()

	if global_position.distance_to(_target.global_position) < 4.0:
		_target.take_damage(_damage)
		queue_free()
