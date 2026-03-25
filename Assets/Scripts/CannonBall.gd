# CannonBall.gd — Splash-damage projectile for the Cannon tower.
# Travels toward its primary target at SPEED and, on contact,
# deals full damage to the target plus SPLASH_FACTOR × damage to
# every other enemy within SPLASH_RADIUS pixels.
extends Node2D

const SPEED: float = 300.0
const SPLASH_RADIUS: float = 40.0
const SPLASH_FACTOR: float = 0.5   # splash neighbours take 50 % of full damage

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

	if global_position.distance_to(_target.global_position) < 6.0:
		_explode()

func _explode() -> void:
	# Primary target takes full damage.
	if is_instance_valid(_target):
		_target.take_damage(_damage)

	# All other enemies within the splash radius take reduced damage.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == _target:
			continue
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= SPLASH_RADIUS:
			enemy.take_damage(_damage * SPLASH_FACTOR)

	queue_free()
