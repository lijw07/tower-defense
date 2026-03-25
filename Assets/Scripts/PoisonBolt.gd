# PoisonBolt.gd — Damage-over-time projectile for the Poison tower.
# The `damage` value passed from TowerData is treated as DPS (damage per second).
# On contact, the enemy is poisoned for POISON_DURATION seconds.
extends Node2D

const SPEED: float = 300.0
const POISON_DURATION: float = 4.0   # seconds the poison lasts

var _target: Node2D = null
var _damage: float = 10.0   # used as DPS

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
		if _target.has_method("apply_poison"):
			_target.apply_poison(_damage, POISON_DURATION)
		else:
			# Fallback: deal damage directly if enemy lacks poison support.
			_target.take_damage(_damage)
	queue_free()
