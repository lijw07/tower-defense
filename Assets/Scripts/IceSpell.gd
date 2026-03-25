# IceSpell.gd — Slowing projectile for the Ice Wizard tower.
# Deals damage on contact and applies a speed-reducing slow effect
# to the enemy for SLOW_DURATION seconds.
extends Node2D

const SPEED: float = 300.0
const SLOW_FACTOR: float = 0.4    # enemy moves at 40 % of base speed
const SLOW_DURATION: float = 2.0  # seconds the slow lasts

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
		_hit()

func _hit() -> void:
	if is_instance_valid(_target):
		_target.take_damage(_damage)
		if _target.has_method("apply_slow"):
			_target.apply_slow(SLOW_FACTOR, SLOW_DURATION)
	queue_free()
